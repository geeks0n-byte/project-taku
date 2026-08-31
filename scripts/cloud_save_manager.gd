extends Node
## Autoload for cloud-save scaffolding. Hooks Play Games when a plugin is present;
## otherwise a desktop stub writes user://cloud_snapshot.json and never crashes.

signal signed_in_changed
signal sync_finished(ok: bool, message: String)

const SNAPSHOT_PATH := "user://cloud_snapshot.json"

## Known plugin.cfg locations — do not ship a new addon from this scaffolding.
const _PLUGIN_CFGS: PackedStringArray = [
	"res://addons/godot-play-games-services/plugin.cfg",
	"res://addons/GodotPlayGameServices/plugin.cfg",
	"res://addons/play_games_services/plugin.cfg",
	"res://addons/godot_play_games_services/plugin.cfg",
]

var is_signed_in: bool = false
var last_error: String = ""
var _plugin_kind: String = ""

## Detects Play Games once. Desktop / missing plugin stays on the local stub.
func _ready() -> void:
	_plugin_kind = "plugin" if CloudSaveLogic.play_games_plugin_present() else ""


## True when a Play Games plugin or engine singleton is available.
func is_play_games_available() -> bool:
	return not _plugin_kind.is_empty()


## True when this session uses the local JSON stub (desktop / no plugin).
func is_stub() -> bool:
	return not is_play_games_available()


## Attempts sign-in. Stub always fails so the Options row stays disabled.
func sign_in() -> bool:
	last_error = ""
	if is_stub():
		last_error = "Play Games needed"
		is_signed_in = false
		signed_in_changed.emit()
		return false
	# Plugin path: keep a no-op hook so a future addon can replace this block.
	is_signed_in = _plugin_sign_in()
	signed_in_changed.emit()
	return is_signed_in


## Writes `blob` to Play Games or the local snapshot file.
func save_blob(blob: Dictionary) -> bool:
	last_error = ""
	if not CloudSaveLogic.is_valid_blob(blob):
		last_error = "invalid blob"
		return false
	if is_play_games_available() and is_signed_in:
		return _plugin_save_blob(blob)
	return _write_snapshot(blob)


## Loads the remote (or stub) blob. Empty dict when nothing is stored.
func load_blob() -> Dictionary:
	last_error = ""
	if is_play_games_available() and is_signed_in:
		return _plugin_load_blob()
	return _read_snapshot()


## Merges local SaveManager state with remote using newest timestamp.
func sync_now() -> bool:
	var sm := get_node_or_null("/root/SaveManager")
	if sm == null or not sm.has_method("export_cloud_payload"):
		last_error = "no SaveManager"
		sync_finished.emit(false, last_error)
		return false
	var local: Dictionary = sm.export_cloud_payload()
	var remote: Dictionary = load_blob()
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
	var ok := save_blob(chosen)
	sync_finished.emit(ok, last_error)
	return ok


## Local snapshot write used by the desktop stub (and as a plugin fallback).
func _write_snapshot(blob: Dictionary) -> bool:
	var text := CloudSaveLogic.encode_json(blob)
	if text.is_empty():
		last_error = "encode failed"
		return false
	var file := FileAccess.open(SNAPSHOT_PATH, FileAccess.WRITE)
	if file == null:
		last_error = "snapshot write failed"
		return false
	file.store_string(text)
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
	var text := file.get_as_text()
	file.close()
	var blob := CloudSaveLogic.decode_json(text)
	if blob.is_empty():
		last_error = "snapshot parse failed"
	return blob


## Returns a short plugin kind string, or "" when none is present.
func _detect_play_games() -> String:
	for singleton_name in ["GodotPlayGamesServices", "PlayGamesServices", "PlayGames"]:
		if Engine.has_singleton(singleton_name):
			return singleton_name
	for cfg in _PLUGIN_CFGS:
		if ResourceLoader.exists(cfg) or FileAccess.file_exists(cfg):
			return cfg
	return ""


## Plugin sign-in hook. Returns false until a real client is wired.
func _plugin_sign_in() -> bool:
	# Intentionally conservative: presence of the addon is not a signed-in session.
	last_error = "Play Games sign-in not wired"
	return false


## Plugin save hook. Falls back to the local snapshot so desktop never crashes.
func _plugin_save_blob(blob: Dictionary) -> bool:
	return _write_snapshot(blob)


## Plugin load hook. Falls back to the local snapshot.
func _plugin_load_blob() -> Dictionary:
	return _read_snapshot()
