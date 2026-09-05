class_name PlayGamesAchievementMap
extends RefCounted
## Maps local AchievementCatalog ids to Google Play Games achievement ids.

const CONFIG_PATH := "res://resources/play_games/play_games_achievement_ids.json"
const EXAMPLE_PATH := "res://resources/play_games/play_games_achievement_ids.example.json"

static var _catalog_to_play: Dictionary = {}
static var _play_to_catalog: Dictionary = {}
static var _loaded: bool = false


static func reload() -> void:
	_catalog_to_play.clear()
	_play_to_catalog.clear()
	_loaded = true
	var path := CONFIG_PATH if FileAccess.file_exists(CONFIG_PATH) else EXAMPLE_PATH
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for catalog_id in AchievementCatalog.ORDERED_IDS:
		var sid := str(catalog_id)
		if not parsed.has(sid):
			continue
		var play_id := str(parsed.get(sid, "")).strip_edges()
		if play_id.is_empty() or play_id.begins_with("_"):
			continue
		_catalog_to_play[sid] = play_id
		_play_to_catalog[play_id] = sid


static func is_configured() -> bool:
	_ensure_loaded()
	return not _catalog_to_play.is_empty()


static func play_id_for_catalog(catalog_id: String) -> String:
	_ensure_loaded()
	return str(_catalog_to_play.get(str(catalog_id), ""))


static func catalog_id_for_play_id(play_id: String) -> String:
	_ensure_loaded()
	return str(_play_to_catalog.get(str(play_id), ""))


static func configured_catalog_ids() -> Array[String]:
	_ensure_loaded()
	var ids: Array[String] = []
	for key in _catalog_to_play:
		ids.append(str(key))
	return ids


static func _ensure_loaded() -> void:
	if not _loaded:
		reload()
