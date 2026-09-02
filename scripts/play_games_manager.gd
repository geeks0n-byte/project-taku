extends Node
## Android Play Games bridge: init plugin, sign-in, and snapshot clients for cloud save.

signal sign_in_finished(ok: bool, message: String)
signal snapshot_load_finished(ok: bool, blob: Dictionary, message: String)
signal snapshot_save_finished(ok: bool, message: String)
signal achievement_sync_finished(ok: bool, message: String)

const SNAPSHOT_FILE := "spaceblox_progress"
const SNAPSHOT_DESC := "Spaceblox campaign progress"
const _SignInClient := preload("res://addons/GodotPlayGameServices/scripts/sign_in/sign_in_client.gd")
const _SnapshotsClient := preload("res://addons/GodotPlayGameServices/scripts/snapshots/snapshots_client.gd")
const _AchievementsClient := preload("res://addons/GodotPlayGameServices/scripts/achievements/achievements_client.gd")
const _MAX_CONFLICT_RETRIES := 2

var is_signed_in: bool = false
var last_error: String = ""

var _sign_in_client: PlayGamesSignInClient
var _snapshots_client: PlayGamesSnapshotsClient
var _achievements_client: PlayGamesAchievementsClient
var _runtime_ready: bool = false
var _sign_in_pending: bool = false
var _load_pending: bool = false
var _save_pending: bool = false
var _pending_save_blob: Dictionary = {}
var _conflict_retries: int = 0
var _pull_achievements_pending: bool = false
var _achievement_sync_pending: bool = false


func _ready() -> void:
	PlayGamesAchievementMap.reload()
	if not CloudSaveLogic.play_games_plugin_installed():
		return
	if GameConstants.is_headless_run():
		return
	call_deferred("_boot_runtime")


## True when the Android singleton is initialized (not editor/desktop stub).
func is_runtime_available() -> bool:
	return _runtime_ready


func _boot_runtime() -> void:
	if _runtime_ready:
		return
	var gpgs := _gpgs()
	if gpgs == null:
		return
	if not gpgs.has_method("initialize"):
		last_error = "Play Games autoload missing initialize()"
		return
	var init_err: int = int(gpgs.initialize())
	if init_err != 0:
		last_error = "Play Games plugin init failed"
		return
	if gpgs.get("android_plugin") == null:
		last_error = "Play Games android plugin missing"
		return
	_runtime_ready = true
	_mount_clients()
	_bind_achievement_push()
	if _sign_in_client != null:
		_sign_in_client.is_authenticated()


func _mount_clients() -> void:
	if _sign_in_client != null:
		return
	_sign_in_client = _SignInClient.new() as PlayGamesSignInClient
	_sign_in_client.name = "SignInClient"
	add_child(_sign_in_client)
	if not _sign_in_client.user_authenticated.is_connected(_on_user_authenticated):
		_sign_in_client.user_authenticated.connect(_on_user_authenticated)
	_snapshots_client = _SnapshotsClient.new() as PlayGamesSnapshotsClient
	_snapshots_client.name = "SnapshotsClient"
	add_child(_snapshots_client)
	if not _snapshots_client.game_loaded.is_connected(_on_game_loaded):
		_snapshots_client.game_loaded.connect(_on_game_loaded)
	if not _snapshots_client.game_saved.is_connected(_on_game_saved):
		_snapshots_client.game_saved.connect(_on_game_saved)
	if not _snapshots_client.conflict_emitted.is_connected(_on_conflict_emitted):
		_snapshots_client.conflict_emitted.connect(_on_conflict_emitted)
	_achievements_client = _AchievementsClient.new() as PlayGamesAchievementsClient
	_achievements_client.name = "AchievementsClient"
	add_child(_achievements_client)
	if not _achievements_client.achievements_loaded.is_connected(_on_achievements_loaded):
		_achievements_client.achievements_loaded.connect(_on_achievements_loaded)


func _bind_achievement_push() -> void:
	if AchievementManager == null:
		return
	if not AchievementManager.unlocked.is_connected(_on_local_achievement_unlocked):
		AchievementManager.unlocked.connect(_on_local_achievement_unlocked)


func _on_local_achievement_unlocked(catalog_id: String) -> void:
	if AchievementManager != null and AchievementManager.is_play_games_push_suppressed():
		return
	push_catalog_unlock(catalog_id)


## Starts interactive sign-in. Result arrives via [signal sign_in_finished].
func request_sign_in() -> void:
	last_error = ""
	if not _ensure_runtime():
		sign_in_finished.emit(false, last_error)
		return
	if is_signed_in:
		sign_in_finished.emit(true, "")
		return
	_sign_in_pending = true
	_sign_in_client.sign_in()


## Loads the cloud snapshot asynchronously.
func load_snapshot_blob() -> void:
	last_error = ""
	if not _ensure_runtime() or not is_signed_in:
		if last_error.is_empty():
			last_error = "Not signed in"
		snapshot_load_finished.emit(false, {}, last_error)
		return
	if _snapshots_client == null:
		last_error = "Snapshots client missing"
		snapshot_load_finished.emit(false, {}, last_error)
		return
	_load_pending = true
	_snapshots_client.load_game(SNAPSHOT_FILE, true)


## Saves the blob to Play Games asynchronously.
func save_snapshot_blob(blob: Dictionary) -> void:
	last_error = ""
	if not CloudSaveLogic.is_valid_blob(blob):
		last_error = "invalid blob"
		snapshot_save_finished.emit(false, last_error)
		return
	if not _ensure_runtime() or not is_signed_in:
		if last_error.is_empty():
			last_error = "Not signed in"
		snapshot_save_finished.emit(false, last_error)
		return
	if _snapshots_client == null:
		last_error = "Snapshots client missing"
		snapshot_save_finished.emit(false, last_error)
		return
	var bytes := CloudSaveLogic.blob_to_bytes(blob)
	if bytes.is_empty():
		last_error = "encode failed"
		snapshot_save_finished.emit(false, last_error)
		return
	_save_pending = true
	_pending_save_blob = blob.duplicate(true)
	_snapshots_client.save_game(SNAPSHOT_FILE, SNAPSHOT_DESC, bytes, 0, 0)


## Re-checks auth without showing the manual sign-in UI.
func refresh_auth_state() -> void:
	if _ensure_runtime() and _sign_in_client != null:
		_sign_in_client.is_authenticated()


## Pushes one local unlock or tier steps to Play Games when mapped and signed in.
func push_catalog_unlock(catalog_id: String) -> void:
	if not PlayGamesAchievementSyncLogic.should_sync_catalog_id(catalog_id):
		return
	if not _ensure_runtime() or not is_signed_in or _achievements_client == null:
		return
	var play_id := PlayGamesAchievementMap.play_id_for_catalog(catalog_id)
	if play_id.is_empty():
		return
	if PlayGamesAchievementSyncLogic.is_incremental_catalog_id(catalog_id):
		_push_catalog_steps(catalog_id, play_id)
		return
	_achievements_client.unlock_achievement(play_id)


func _push_catalog_steps(catalog_id: String, play_id: String) -> void:
	if SaveManager == null:
		return
	var state := _achievement_progress_state()
	var steps := PlayGamesAchievementSyncLogic.steps_for_catalog_id(catalog_id, state)
	if steps <= 0:
		return
	_achievements_client.set_achievement_steps(play_id, steps)


func _achievement_progress_state() -> Dictionary:
	var start := SaveManager.get_campaign_start_unlock()
	return PlayGamesAchievementSyncLogic.progress_state_from_save(
		SaveManager.max_unlocked_level,
		start,
		SaveManager.no_hint_clears,
		SaveManager.on_time_clears
	)


## Pushes every locally mapped achievement / tier progress to Play Games.
func push_all_local_unlocks() -> void:
	if SaveManager == null:
		return
	var state := _achievement_progress_state()
	for catalog_id in PlayGamesAchievementMap.configured_catalog_ids():
		var sid := str(catalog_id)
		if PlayGamesAchievementSyncLogic.is_incremental_catalog_id(sid):
			var play_id := PlayGamesAchievementMap.play_id_for_catalog(sid)
			if play_id.is_empty():
				continue
			var steps := PlayGamesAchievementSyncLogic.steps_for_catalog_id(sid, state)
			if steps > 0 and _achievements_client != null:
				_achievements_client.set_achievement_steps(play_id, steps)
			continue
		if SaveManager.achievements_unlocked.has(sid):
			push_catalog_unlock(sid)


## Loads remote Play achievements and merges unlocks into SaveManager.
func pull_remote_unlocks() -> void:
	if not _ensure_runtime() or not is_signed_in or _achievements_client == null:
		achievement_sync_finished.emit(false, "Not signed in")
		return
	if not PlayGamesAchievementMap.is_configured():
		achievement_sync_finished.emit(true, "")
		return
	_pull_achievements_pending = true
	if _achievements_client.has_method("load_achievements"):
		_achievements_client.load_achievements(true)


## Push local unlocks, then pull remote unlocks (async completion via signal).
func sync_achievements() -> void:
	if GameConstants.is_headless_run():
		return
	if not _ensure_runtime() or not is_signed_in:
		achievement_sync_finished.emit(false, "Not signed in")
		return
	if not PlayGamesAchievementMap.is_configured():
		achievement_sync_finished.emit(true, "")
		return
	_achievement_sync_pending = true
	push_all_local_unlocks()
	pull_remote_unlocks()


func _ensure_runtime() -> bool:
	if _runtime_ready:
		return true
	_boot_runtime()
	if not _runtime_ready:
		if last_error.is_empty():
			last_error = "Play Games not available on this platform"
		return false
	return true


func _on_user_authenticated(authenticated: bool) -> void:
	var changed := authenticated != is_signed_in
	is_signed_in = authenticated
	if _sign_in_pending:
		_sign_in_pending = false
		if authenticated:
			last_error = ""
			sign_in_finished.emit(true, "")
			call_deferred("sync_achievements")
		else:
			if last_error.is_empty():
				last_error = "Sign-in failed or cancelled"
			sign_in_finished.emit(false, last_error)
	elif changed and not authenticated:
		last_error = "Signed out"


func _on_game_loaded(snapshot: Variant) -> void:
	if not _load_pending:
		return
	_load_pending = false
	var blob := _blob_from_snapshot(snapshot)
	if blob.is_empty() and _snapshot_had_bytes(snapshot):
		last_error = "Cloud snapshot parse failed"
		snapshot_load_finished.emit(false, {}, last_error)
		return
	snapshot_load_finished.emit(true, blob, "")


func _on_game_saved(is_saved: bool, _save_data_name: String, _save_data_description: String) -> void:
	if not _save_pending:
		return
	_save_pending = false
	_pending_save_blob = {}
	_conflict_retries = 0
	if not is_saved and last_error.is_empty():
		last_error = "Cloud save failed"
	snapshot_save_finished.emit(is_saved, last_error if not is_saved else "")


func _on_conflict_emitted(conflict: Variant) -> void:
	if conflict == null:
		return
	if _conflict_retries >= _MAX_CONFLICT_RETRIES:
		_abort_pending("Cloud save conflict")
		return
	_conflict_retries += 1
	var server_blob := _blob_from_snapshot(_conflict_field(conflict, "server_snapshot"))
	var conflicting_blob := _blob_from_snapshot(_conflict_field(conflict, "conflicting_snapshot"))
	var merged := CloudSaveLogic.merge_blobs(server_blob, conflicting_blob)
	if _save_pending and not _pending_save_blob.is_empty():
		merged = CloudSaveLogic.merge_blobs(_pending_save_blob, merged)
	if merged.is_empty():
		_abort_pending("Cloud save conflict")
		return
	save_snapshot_blob(merged)


func _abort_pending(message: String) -> void:
	last_error = message
	if _load_pending:
		_load_pending = false
		snapshot_load_finished.emit(false, {}, message)
	if _save_pending:
		_save_pending = false
		_pending_save_blob = {}
		snapshot_save_finished.emit(false, message)


func _conflict_field(conflict: Variant, field_name: String) -> Variant:
	if conflict is Object:
		return conflict.get(field_name)
	return null


func _blob_from_snapshot(snapshot: Variant) -> Dictionary:
	if snapshot == null:
		return {}
	var content := PackedByteArray()
	if snapshot is Object:
		var raw: Variant = snapshot.get("content")
		if raw is PackedByteArray:
			content = raw
	return CloudSaveLogic.blob_from_bytes(content)


func _snapshot_had_bytes(snapshot: Variant) -> bool:
	if snapshot == null or not (snapshot is Object):
		return false
	var raw: Variant = snapshot.get("content")
	return raw is PackedByteArray and not (raw as PackedByteArray).is_empty()


func _on_achievements_loaded(achievements: Array) -> void:
	if not _pull_achievements_pending:
		return
	_pull_achievements_pending = false
	if AchievementManager != null:
		for entry in achievements:
			if entry == null:
				continue
			var play_id := ""
			var state := -1
			if entry is Object:
				play_id = str(entry.get("achievement_id"))
				state = int(entry.get("state"))
			var catalog_id := PlayGamesAchievementMap.catalog_id_for_play_id(play_id)
			if catalog_id.is_empty():
				continue
			if not PlayGamesAchievementSyncLogic.play_achievement_is_unlocked(state):
				continue
			AchievementManager.import_remote_unlock(catalog_id)
	if _achievement_sync_pending:
		_achievement_sync_pending = false
		achievement_sync_finished.emit(true, "")


func _gpgs() -> Node:
	return get_node_or_null("/root/GodotPlayGameServices")
