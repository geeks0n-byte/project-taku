extends Node
## Android Play Games bridge: init plugin, sign-in, and snapshot clients for cloud save.

signal sign_in_finished(ok: bool, message: String)
signal snapshot_load_finished(ok: bool, blob: Dictionary, message: String)
signal snapshot_save_finished(ok: bool, message: String)

const SNAPSHOT_FILE := "spaceblox_progress"
const SNAPSHOT_DESC := "Spaceblox campaign progress"
const _SIGN_IN_SCRIPT := "res://addons/GodotPlayGameServices/scripts/sign_in/sign_in_client.gd"
const _SNAPSHOTS_SCRIPT := "res://addons/GodotPlayGameServices/scripts/snapshots/snapshots_client.gd"
const _MAX_CONFLICT_RETRIES := 2

var is_signed_in: bool = false
var last_error: String = ""

var _sign_in_client: Node
var _snapshots_client: Node
var _runtime_ready: bool = false
var _sign_in_pending: bool = false
var _load_pending: bool = false
var _save_pending: bool = false
var _pending_save_blob: Dictionary = {}
var _conflict_retries: int = 0


func _ready() -> void:
	if not CloudSaveLogic.play_games_plugin_installed():
		return
	if OS.has_feature("headless"):
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
	var init_err: int = int(gpgs.call("initialize"))
	if init_err != 0:
		last_error = "Play Games plugin init failed"
		return
	if gpgs.get("android_plugin") == null:
		last_error = "Play Games android plugin missing"
		return
	_runtime_ready = true
	_mount_clients()
	if _sign_in_client != null and _sign_in_client.has_method("is_authenticated"):
		_sign_in_client.call("is_authenticated")


func _mount_clients() -> void:
	if _sign_in_client != null:
		return
	var sign_in_script: Script = load(_SIGN_IN_SCRIPT) as Script
	if sign_in_script == null:
		last_error = "Play Games sign-in script missing"
		return
	_sign_in_client = sign_in_script.new() as Node
	_sign_in_client.name = "SignInClient"
	add_child(_sign_in_client)
	if _sign_in_client.has_signal("user_authenticated"):
		if not _sign_in_client.user_authenticated.is_connected(_on_user_authenticated):
			_sign_in_client.user_authenticated.connect(_on_user_authenticated)
	var snapshots_script: Script = load(_SNAPSHOTS_SCRIPT) as Script
	if snapshots_script == null:
		last_error = "Play Games snapshots script missing"
		return
	_snapshots_client = snapshots_script.new() as Node
	_snapshots_client.name = "SnapshotsClient"
	add_child(_snapshots_client)
	if _snapshots_client.has_signal("game_loaded"):
		if not _snapshots_client.game_loaded.is_connected(_on_game_loaded):
			_snapshots_client.game_loaded.connect(_on_game_loaded)
	if _snapshots_client.has_signal("game_saved"):
		if not _snapshots_client.game_saved.is_connected(_on_game_saved):
			_snapshots_client.game_saved.connect(_on_game_saved)
	if _snapshots_client.has_signal("conflict_emitted"):
		if not _snapshots_client.conflict_emitted.is_connected(_on_conflict_emitted):
			_snapshots_client.conflict_emitted.connect(_on_conflict_emitted)


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
	if _sign_in_client != null and _sign_in_client.has_method("sign_in"):
		_sign_in_client.call("sign_in")


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
	_snapshots_client.call("load_game", SNAPSHOT_FILE, true)


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
	_snapshots_client.call("save_game", SNAPSHOT_FILE, SNAPSHOT_DESC, bytes, 0, 0)


## Re-checks auth without showing the manual sign-in UI.
func refresh_auth_state() -> void:
	if _ensure_runtime() and _sign_in_client != null and _sign_in_client.has_method("is_authenticated"):
		_sign_in_client.call("is_authenticated")


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
	snapshot_load_finished.emit(true, _blob_from_snapshot(snapshot), "")


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
	var merged := CloudSaveLogic.winner(server_blob, conflicting_blob)
	if _save_pending and not _pending_save_blob.is_empty():
		merged = CloudSaveLogic.winner(_pending_save_blob, merged)
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


func _gpgs() -> Node:
	return get_node_or_null("/root/GodotPlayGameServices")
