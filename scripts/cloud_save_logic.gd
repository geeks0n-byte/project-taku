class_name CloudSaveLogic
extends RefCounted
## JSON cloud-save blob helpers, progress merge, and conflict resolution.

const SCHEMA_VERSION := 1

enum SyncAction { APPLY, CHOOSE }

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


## Weighted progress score for tie-breaking and summaries.
static func progress_score(blob: Dictionary) -> int:
	if not is_valid_blob(blob):
		return 0
	var progress: Dictionary = blob.get("progress", {})
	var ach: Dictionary = blob.get("achievements", {})
	var score := int(progress.get("max_unlocked_level", 0)) * 1000
	var bits: Dictionary = progress.get("level_star_bits", {})
	for key in bits:
		score += LevelStars.count_earned_bits(int(bits[key]))
	var unlocked: Dictionary = ach.get("unlocked", {})
	score += unlocked.size() * 50
	score += int(ach.get("no_hint_clears", 0))
	score += int(ach.get("on_time_clears", 0))
	score += int(ach.get("shifter_slides", 0))
	return score


## Human-readable stats for cloud-save choice UI.
static func summarize_blob(blob: Dictionary) -> Dictionary:
	if not is_valid_blob(blob):
		return {}
	var progress: Dictionary = blob.get("progress", {})
	var ach: Dictionary = blob.get("achievements", {})
	var star_total := 0
	var bits: Dictionary = progress.get("level_star_bits", {})
	for key in bits:
		star_total += LevelStars.count_earned_bits(int(bits[key]))
	var unlocked: Dictionary = ach.get("unlocked", {})
	return {
		"max_level": int(progress.get("max_unlocked_level", 0)),
		"star_total": star_total,
		"achievement_count": unlocked.size(),
		"timestamp": int(blob.get("timestamp", 0)),
		"score": progress_score(blob),
	}


## OR-merges per-level star bit masks.
static func merge_star_bits(local_bits: Dictionary, remote_bits: Dictionary) -> Dictionary:
	var merged := local_bits.duplicate(true)
	for key in remote_bits:
		var k := str(key)
		var remote_val := int(remote_bits[key])
		var local_val := int(merged.get(k, 0))
		merged[k] = local_val | remote_val
	return merged


## Keeps the earliest unlock timestamp per achievement id.
static func merge_unlocked_maps(local_u: Dictionary, remote_u: Dictionary) -> Dictionary:
	var merged := local_u.duplicate(true)
	for key in remote_u:
		var k := str(key)
		if not merged.has(k):
			merged[k] = remote_u[key]
			continue
		merged[k] = mini(int(merged[k]), int(remote_u[key]))
	return merged


## Union of tutorial script ids preserving local order first.
static func merge_string_arrays(local_arr: Array, remote_arr: Array) -> Array:
	var out: Array = local_arr.duplicate()
	for entry in remote_arr:
		var sid := str(entry)
		if sid.is_empty() or out.has(sid):
			continue
		out.append(sid)
	return out


## Union of rules-open level keys.
static func merge_rules_open_levels(local_d: Dictionary, remote_d: Dictionary) -> Dictionary:
	var merged := local_d.duplicate(true)
	for key in remote_d:
		merged[str(key)] = true
	return merged


## Field-wise merge of two valid blobs; settings follow the newer timestamp.
static func merge_blobs(local: Dictionary, remote: Dictionary) -> Dictionary:
	if not is_valid_blob(local):
		return remote.duplicate(true) if is_valid_blob(remote) else {}
	if not is_valid_blob(remote):
		return local.duplicate(true)
	var local_ts := int(local.get("timestamp", 0))
	var remote_ts := int(remote.get("timestamp", 0))
	var local_p: Dictionary = local.get("progress", {})
	var remote_p: Dictionary = remote.get("progress", {})
	var local_a: Dictionary = local.get("achievements", {})
	var remote_a: Dictionary = remote.get("achievements", {})
	var merged_p := {
		"max_unlocked_level": maxi(
			int(local_p.get("max_unlocked_level", 0)),
			int(remote_p.get("max_unlocked_level", 0))
		),
		"level_star_bits": merge_star_bits(
			local_p.get("level_star_bits", {}),
			remote_p.get("level_star_bits", {})
		),
		"tutorial_intro_answered": (
			bool(local_p.get("tutorial_intro_answered", false))
			or bool(remote_p.get("tutorial_intro_answered", false))
		),
		"completed_tutorial_scripts": merge_string_arrays(
			local_p.get("completed_tutorial_scripts", []),
			remote_p.get("completed_tutorial_scripts", [])
		),
		"privacy_accepted": (
			bool(local_p.get("privacy_accepted", false))
			or bool(remote_p.get("privacy_accepted", false))
		),
	}
	var merged_a := {
		"unlocked": merge_unlocked_maps(
			local_a.get("unlocked", {}),
			remote_a.get("unlocked", {})
		),
		"no_hint_clears": maxi(
			int(local_a.get("no_hint_clears", 0)),
			int(remote_a.get("no_hint_clears", 0))
		),
		"on_time_clears": maxi(
			int(local_a.get("on_time_clears", 0)),
			int(remote_a.get("on_time_clears", 0))
		),
		"shifter_slides": maxi(
			int(local_a.get("shifter_slides", 0)),
			int(remote_a.get("shifter_slides", 0))
		),
		"rules_open_levels": merge_rules_open_levels(
			local_a.get("rules_open_levels", {}),
			remote_a.get("rules_open_levels", {})
		),
	}
	var settings_source: Dictionary = remote if remote_ts >= local_ts else local
	return build_blob(
		merged_p,
		settings_source.get("settings", {}).duplicate(true),
		merged_a,
		maxi(local_ts, remote_ts)
	)


## Resolves a sync: merge progress by default; ask the player when timestamps tie with equal scores.
static func resolve_sync(local: Dictionary, remote: Dictionary) -> Dictionary:
	var local_ok := is_valid_blob(local)
	var remote_ok := is_valid_blob(remote)
	if not remote_ok:
		return {"action": SyncAction.APPLY, "blob": local.duplicate(true) if local_ok else {}}
	if not local_ok:
		return {"action": SyncAction.APPLY, "blob": remote.duplicate(true)}
	var local_ts := int(local.get("timestamp", 0))
	var remote_ts := int(remote.get("timestamp", 0))
	if local_ts == remote_ts and progress_score(local) == progress_score(remote):
		return {
			"action": SyncAction.CHOOSE,
			"blob": merge_blobs(local, remote),
			"local": local.duplicate(true),
			"remote": remote.duplicate(true),
			"local_summary": summarize_blob(local),
			"remote_summary": summarize_blob(remote),
		}
	return {"action": SyncAction.APPLY, "blob": merge_blobs(local, remote)}


## Newest timestamp wins. Tie (or missing timestamps) keeps `local`.
## Prefer [method resolve_sync] for player-facing sync.
static func winner(local: Dictionary, remote: Dictionary) -> Dictionary:
	var resolved: Dictionary = resolve_sync(local, remote)
	if int(resolved.get("action", SyncAction.APPLY)) == SyncAction.CHOOSE:
		return local.duplicate(true)
	return resolved.get("blob", local.duplicate(true))


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
