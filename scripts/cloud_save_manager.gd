extends Node
## Autoload for cloud-save scaffolding. Hooks Play Games when a plugin is present;
## otherwise a desktop stub writes user://cloud_snapshot.json and never crashes.

signal signed_in_changed
signal sync_started
signal sync_finished(ok: bool, message: String)

const SNAPSHOT_PATH := "user://cloud_snapshot.json"

var is_signed_in: bool = false
var is_syncing: bool = false
var last_error: String = ""
var _plugin_kind: String = ""
var _sync_local_payload: Dictionary = {}


## Detects Play Games once. Desktop / missing plugin stays on the local stub.
func _ready() -> void:
	_plugin_kind = "plugin" if CloudSaveLogic.play_games_plugin_installed() else ""
	var pgs := _play_games()
	if pgs != null:
		if pgs.has_signal("sign_in_finished") and not pgs.sign_in_finished.is_connected(_on_play_games_sign_in_finished):
			pgs.sign_in_finished.connect(_on_play_games_sign_in_finished)
		if pgs.has_signal("snapshot_load_finished") and not pgs.snapshot_load_finished.is_connected(_on_snapshot_load_finished):
			pgs.snapshot_load_finished.connect(_on_snapshot_load_finished)
		if pgs.has_signal("snapshot_save_finished") and not pgs.snapshot_save_finished.is_connected(_on_snapshot_save_finished):
			pgs.snapshot_save_finished.connect(_on_snapshot_save_finished)
		if pgs.get("is_signed_in") != null:
			is_signed_in = bool(pgs.get("is_signed_in"))


## True when the Play Games addon is installed in the project.
func is_play_games_available() -> bool:
	return not _plugin_kind.is_empty()


## True when this session uses the local JSON stub (desktop / no Android runtime).
func is_stub() -> bool:
	var pgs := _play_games()
	if pgs != null and pgs.has_method("is_runtime_available"):
		return not bool(pgs.call("is_runtime_available"))
	return not CloudSaveLogic.play_games_runtime_available()


## Attempts sign-in. On Android this is async; listen for [signal signed_in_changed].
func sign_in() -> bool:
	last_error = ""
	if is_stub():
		last_error = "Play Games needed"
		is_signed_in = false
		signed_in_changed.emit()
		return false
	var pgs := _play_games()
	if pgs != null:
		if bool(pgs.get("is_signed_in")):
			is_signed_in = true
			signed_in_changed.emit()
			return true
		if pgs.has_method("request_sign_in"):
			pgs.call("request_sign_in")
		return false
	is_signed_in = _plugin_sign_in()
	signed_in_changed.emit()
	return is_signed_in


## Writes `blob` to Play Games or the local snapshot file.
func save_blob(blob: Dictionary) -> bool:
	last_error = ""
	if not CloudSaveLogic.is_valid_blob(blob):
		last_error = "invalid blob"
		return false
	if not is_stub() and is_signed_in:
		return _plugin_save_blob(blob)
	return _write_snapshot(blob)


## Loads the remote (or stub) blob. Empty dict when nothing is stored.
func load_blob() -> Dictionary:
	last_error = ""
	if not is_stub() and is_signed_in:
		return _plugin_load_blob()
	return _read_snapshot()


## Merges local SaveManager state with remote using newest timestamp.
## Play Games path is async; result arrives via [signal sync_finished].
func sync_now() -> bool:
	if is_syncing:
		last_error = "Sync in progress"
		return false
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null or not sm.has_method("export_cloud_payload"):
		last_error = "no SaveManager"
		sync_finished.emit(false, last_error)
		return false
	if not is_stub() and not is_signed_in:
		last_error = "Not signed in"
		sync_finished.emit(false, last_error)
		return false
	is_syncing = true
	sync_started.emit()
	last_error = ""
	_sync_local_payload = sm.export_cloud_payload()
	if is_stub():
		_complete_sync(_read_snapshot())
		return false
	var pgs := _play_games()
	if pgs != null and pgs.has_method("load_snapshot_blob"):
		pgs.call("load_snapshot_blob")
		return false
	_fail_sync("Play Games snapshots not wired")
	return false


## Local snapshot write used by the desktop stub (and as a plugin fallback).
func _write_snapshot(blob: Dictionary) -> bool:
	var bytes := CloudSaveLogic.blob_to_bytes(blob)
	if bytes.is_empty():
		last_error = "encode failed"
		return false
	var file := FileAccess.open(SNAPSHOT_PATH, FileAccess.WRITE)
	if file == null:
		last_error = "snapshot write failed"
		return false
	file.store_buffer(bytes)
	file.close()
	return true


## Local snapshot read; empty dict when the file is missing or invalid.
func _read_snapshot() -> Dictionary:
	if not FileAccess.file_exists(SNAPSHOT_PATH):
		return {}
	var file := FileAccess.open(SNAPSHOT_PATH, FileAccess.READ)
	if file == null:
		last_error = "snapshot read failed"
		return {}
	var bytes := file.get_buffer(file.get_length())
	file.close()
	var blob := CloudSaveLogic.blob_from_bytes(bytes)
	if blob.is_empty() and not bytes.is_empty():
		last_error = "snapshot parse failed"
	return blob


func _complete_sync(remote: Dictionary) -> void:
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null:
		_fail_sync("no SaveManager")
		return
	var local: Dictionary = _sync_local_payload
	var chosen: Dictionary = CloudSaveLogic.winner(local, remote)
	if chosen.is_empty():
		chosen = local
	var applied_remote := (
		CloudSaveLogic.is_valid_blob(remote)
		and int(chosen.get("timestamp", 0)) == int(remote.get("timestamp", 0))
		and int(chosen.get("timestamp", 0)) > int(local.get("timestamp", 0))
	)
	if applied_remote and sm.has_method("apply_cloud_payload"):
		sm.apply_cloud_payload(chosen)
	if is_stub():
		var ok := _write_snapshot(chosen)
		_finish_sync(ok, "" if ok else last_error)
		return
	var pgs := _play_games()
	if pgs != null and pgs.has_method("save_snapshot_blob"):
		pgs.call("save_snapshot_blob", chosen)
		return
	_fail_sync("Play Games snapshots not wired")


func _on_snapshot_load_finished(ok: bool, remote: Dictionary, message: String) -> void:
	if not is_syncing:
		return
	if not ok:
		_fail_sync(message if not message.is_empty() else "Cloud load failed")
		return
	_complete_sync(remote)


func _on_snapshot_save_finished(ok: bool, message: String) -> void:
	if not is_syncing:
		return
	_finish_sync(ok, message)


func _finish_sync(ok: bool, message: String) -> void:
	is_syncing = false
	_sync_local_payload = {}
	if not message.is_empty():
		last_error = message
	sync_finished.emit(ok, last_error if not ok else "")


func _fail_sync(message: String) -> void:
	_finish_sync(false, message)


func _on_play_games_sign_in_finished(ok: bool, message: String) -> void:
	last_error = message
	var pgs := _play_games()
	is_signed_in = ok and pgs != null and bool(pgs.get("is_signed_in"))
	signed_in_changed.emit()


func _play_games() -> Node:
	return get_node_or_null("/root/PlayGamesManager")


## Plugin sign-in hook. Returns false until a real client is wired.
func _plugin_sign_in() -> bool:
	var pgs := _play_games()
	if pgs != null and pgs.has_method("request_sign_in"):
		pgs.call("request_sign_in")
		return bool(pgs.get("is_signed_in"))
	last_error = "Play Games sign-in not wired"
	return false


## Plugin save hook. Falls back to the local snapshot so desktop never crashes.
func _plugin_save_blob(blob: Dictionary) -> bool:
	return _write_snapshot(blob)


## Plugin load hook. Falls back to the local snapshot.
func _plugin_load_blob() -> Dictionary:
	return _read_snapshot()
