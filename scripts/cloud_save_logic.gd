class_name CloudSaveLogic
extends RefCounted
## JSON cloud-save blob helpers and newest-timestamp conflict resolution.

const SCHEMA_VERSION := 1

## Known plugin.cfg paths — scaffolding never ships a new addon.
const PLUGIN_CFGS: PackedStringArray = [
	"res://addons/godot-play-games-services/plugin.cfg",
	"res://addons/GodotPlayGameServices/plugin.cfg",
	"res://addons/play_games_services/plugin.cfg",
	"res://addons/godot_play_games_services/plugin.cfg",
]


## True when the Godot Play Games addon is present in the project tree.
static func play_games_plugin_installed() -> bool:
	for cfg in PLUGIN_CFGS:
		if ResourceLoader.exists(cfg) or FileAccess.file_exists(cfg):
			return true
	return false


## True when the Android engine singleton exists (device/export build only).
static func play_games_runtime_available() -> bool:
	if OS.get_name() != "Android":
		return false
	return Engine.has_singleton("GodotPlayGameServices")


## Back-compat alias for callers that mean "installed or runtime".
static func play_games_plugin_present() -> bool:
	return play_games_plugin_installed() or play_games_runtime_available()


## Builds the portable cloud blob. `timestamp` is unix seconds.
static func build_blob(
	progress: Dictionary,
	settings: Dictionary,
	achievements: Dictionary,
	timestamp: int
) -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"timestamp": int(timestamp),
		"progress": progress.duplicate(true),
		"settings": settings.duplicate(true),
		"achievements": achievements.duplicate(true),
	}


## True when a blob has the expected top-level dictionaries.
static func is_valid_blob(blob: Dictionary) -> bool:
	if blob.is_empty():
		return false
	return (
		blob.has("progress")
		and typeof(blob.get("progress")) == TYPE_DICTIONARY
		and blob.has("settings")
		and typeof(blob.get("settings")) == TYPE_DICTIONARY
		and blob.has("achievements")
		and typeof(blob.get("achievements")) == TYPE_DICTIONARY
	)


## Newest timestamp wins. Tie (or missing timestamps) keeps `local`.
## Empty / invalid remote → local. Empty / invalid local → remote.
static func winner(local: Dictionary, remote: Dictionary) -> Dictionary:
	var local_ok := is_valid_blob(local)
	var remote_ok := is_valid_blob(remote)
	if not remote_ok:
		return local.duplicate(true) if local_ok else {}
	if not local_ok:
		return remote.duplicate(true)
	var local_ts := int(local.get("timestamp", 0))
	var remote_ts := int(remote.get("timestamp", 0))
	if remote_ts > local_ts:
		return remote.duplicate(true)
	return local.duplicate(true)


## Dictionary → pretty JSON string (empty string on failure).
static func encode_json(blob: Dictionary) -> String:
	var text := JSON.stringify(blob, "\t")
	return text if typeof(text) == TYPE_STRING else ""


## JSON string → dictionary (empty dict on failure).
static func decode_json(text: String) -> Dictionary:
	if str(text).strip_edges().is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


## Snapshot bytes → blob dictionary.
static func blob_from_bytes(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return {}
	return decode_json(bytes.get_string_from_utf8())


## Blob dictionary → UTF-8 bytes for Play Games snapshots.
static func blob_to_bytes(blob: Dictionary) -> PackedByteArray:
	if not is_valid_blob(blob):
		return PackedByteArray()
	var text := encode_json(blob)
	if text.is_empty():
		return PackedByteArray()
	return text.to_utf8_buffer()
