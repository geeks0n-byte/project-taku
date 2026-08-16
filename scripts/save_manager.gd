extends Node

const SAVE_PATH = "user://progression.cfg"
const SUPPORTED_LANGUAGES := ["en", "es", "de", "fr", "pl", "ka", "uk"]

signal language_changed

var max_unlocked_level: int = 1
var current_language: String = "en"
var background_static: bool = false
var bgm_enabled: bool = true
var sfx_enabled: bool = true
var tutorial_intro_answered: bool = false
var level_star_bits: Dictionary = {}
var session_data: Dictionary = {}
var ads_wins_since_interstitial: int = 0

func _ready() -> void:
	_sync_translations_from_csv()
	load_progress()
	_apply_background_mode()
	if not get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.connect(_on_tree_node_added)
	call_deferred("apply_locale_fonts")

func _sync_translations_from_csv() -> void:
	# Exported builds use imported .translation from Project Settings.
	# Reading translations.csv only works reliably in the editor; on device the
	# CSV is often missing/remapped, which left keys untranslated and broke % formatting.
	if not OS.has_feature("editor"):
		return
	const CSV_PATH := "res://resources/localization/translations.csv"
	if not FileAccess.file_exists(CSV_PATH):
		return
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return
	var headers: PackedStringArray = file.get_csv_line()
	if headers.size() < 2 or headers[0] != "keys":
		return
	# Rebuild plain Translation objects from CSV so editor picks up CSV edits
	# without waiting for reimport. OptimizedTranslation ignores add_message().
	var locale_translations: Dictionary = {}
	for i in range(1, headers.size()):
		var locale := String(headers[i]).strip_edges()
		if locale.is_empty():
			continue
		while true:
			var existing := TranslationServer.get_translation_object(locale)
			if existing == null:
				break
			TranslationServer.remove_translation(existing)
		var translation := Translation.new()
		translation.locale = locale
		TranslationServer.add_translation(translation)
		locale_translations[i] = translation
	var expected_cols := headers.size()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.is_empty():
			continue
		var key := String(row[0]).strip_edges()
		if key.is_empty() or key == "keys":
			continue
		if row.size() != expected_cols:
			push_warning("translations.csv: skipped %s (got %d cols, expected %d)" % [key, row.size(), expected_cols])
			continue
		for i in locale_translations.keys():
			var idx := int(i)
			if idx >= row.size():
				continue
			var message := String(row[idx])
			if message.is_empty():
				continue
			(locale_translations[idx] as Translation).add_message(key, message.c_unescape())
	file.close()

func get_campaign_start_unlock() -> int:
	var easy_paths := LevelUtils.scan_directory(GameConstants.CAMPAIGN_EASY_DIR)
	LevelUtils.sort_level_paths(easy_paths)
	for path in easy_paths:
		var resource = load(path)
		if resource is LevelData:
			return int(resource.level_number)
	return 1

func _ensure_campaign_start_unlock() -> void:
	var start := get_campaign_start_unlock()
	if max_unlocked_level < start:
		max_unlocked_level = start
		save_progress()

func load_progress() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)

	if err == OK:
		max_unlocked_level = config.get_value("Progression", "max_unlocked_level", 1)
		current_language = config.get_value("Progression", "current_language", "en")
		background_static = bool(config.get_value("Progression", "background_static", false))
		bgm_enabled = bool(config.get_value("Progression", "bgm_enabled", true))
		sfx_enabled = bool(config.get_value("Progression", "sfx_enabled", true))
		if config.has_section_key("Progression", "tutorial_intro_answered"):
			tutorial_intro_answered = bool(config.get_value("Progression", "tutorial_intro_answered", false))
		else:
			tutorial_intro_answered = true
		level_star_bits = config.get_value("Progression", "level_star_bits", {})
		if typeof(level_star_bits) != TYPE_DICTIONARY:
			level_star_bits = {}
		session_data = config.get_value("Session", "data", {})
		if typeof(session_data) != TYPE_DICTIONARY:
			session_data = {}
		ads_wins_since_interstitial = int(config.get_value("Ads", "wins_since_interstitial", 0))
		if not SUPPORTED_LANGUAGES.has(current_language):
			current_language = "en"
		TranslationServer.set_locale(current_language)
	else:
		current_language = _detect_system_language()
		TranslationServer.set_locale(current_language)
		session_data = {}
		tutorial_intro_answered = false
		ads_wins_since_interstitial = 0
		max_unlocked_level = get_campaign_start_unlock()
		save_progress()
	_ensure_campaign_start_unlock()

func _detect_system_language() -> String:
	var lang := OS.get_locale_language().to_lower()
	if SUPPORTED_LANGUAGES.has(lang):
		return lang
	var full := OS.get_locale().to_lower()
	if full.length() >= 2:
		var code := full.substr(0, 2)
		if SUPPORTED_LANGUAGES.has(code):
			return code
	return "en"

func save_progress() -> void:
	var config = ConfigFile.new()
	config.set_value("Progression", "max_unlocked_level", max_unlocked_level)
	config.set_value("Progression", "current_language", current_language)
	config.set_value("Progression", "background_static", background_static)
	config.set_value("Progression", "bgm_enabled", bgm_enabled)
	config.set_value("Progression", "sfx_enabled", sfx_enabled)
	config.set_value("Progression", "tutorial_intro_answered", tutorial_intro_answered)
	config.set_value("Progression", "level_star_bits", level_star_bits)
	config.set_value("Ads", "wins_since_interstitial", ads_wins_since_interstitial)
	if session_data.is_empty():
		if config.has_section("Session"):
			config.erase_section("Session")
	else:
		config.set_value("Session", "data", session_data)
	config.save(SAVE_PATH)

func record_ad_win() -> void:
	ads_wins_since_interstitial += 1
	save_progress()

func should_show_interstitial(every_n: int) -> bool:
	return every_n > 0 and ads_wins_since_interstitial >= every_n

func consume_interstitial_wins() -> void:
	ads_wins_since_interstitial = 0
	save_progress()

func set_language(lang_code: String) -> void:
	current_language = lang_code
	TranslationServer.set_locale(lang_code)
	HudLayout.clear_pixel_text_cache()
	save_progress()
	apply_locale_fonts()
	language_changed.emit()

func apply_locale_fonts() -> void:
	var tree := get_tree()
	if tree and tree.root:
		HudLayout.apply_locale_fonts_to_tree(tree.root)

func _on_tree_node_added(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not (
		node is Button
		or node is Label
		or node is LineEdit
		or node is OptionButton
		or node is RichTextLabel
	):
		return
	# Direct apply — call_deferred(String, Node) hits Godot's Object→Object bug.
	HudLayout.apply_locale_font_to_control(node)

func set_background_static(is_static: bool) -> void:
	background_static = is_static
	save_progress()
	_apply_background_mode()

func set_bgm_enabled(enabled: bool) -> void:
	bgm_enabled = enabled
	save_progress()
	if BgmManager and BgmManager.has_method("apply_enabled"):
		BgmManager.apply_enabled()

func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	save_progress()

func _apply_background_mode() -> void:
	if SpaceBackground and SpaceBackground.has_method("set_static_mode"):
		SpaceBackground.set_static_mode(background_static)

func unlock_level(level_num: int) -> void:
	if level_num > max_unlocked_level:
		max_unlocked_level = level_num
		save_progress()

func unlock_all_levels() -> void:
	var highest := get_campaign_start_unlock()
	for path in LevelUtils.scan_campaign_levels():
		var resource = load(path)
		if resource and resource is LevelData:
			highest = maxi(highest, int(resource.level_number))
	if highest > max_unlocked_level:
		max_unlocked_level = highest
		save_progress()

func is_level_unlocked(level_num: int) -> bool:
	return level_num <= max_unlocked_level

func get_level_star_bits(level_num: int) -> int:
	var bits := int(level_star_bits.get(str(level_num), 0))
	# Cleared levels always count the completion star (bit 4 / legacy moves bit).
	if level_num < max_unlocked_level:
		bits |= LevelStars.BIT_COMPLETE
	return bits

func record_level_stars(level_num: int, bits: int) -> int:
	var key := str(level_num)
	var merged := get_level_star_bits(level_num) | bits
	level_star_bits[key] = merged
	save_progress()
	return merged

func has_session() -> bool:
	return not session_data.is_empty() and str(session_data.get("level_path", "")) != ""

func has_session_for(level: LevelData) -> bool:
	if level == null or not has_session():
		return false
	return str(session_data.get("level_path", "")) == level.resource_path

func load_session() -> Dictionary:
	if not has_session():
		return {}
	return _deserialize_session(session_data)

func save_session(data: Dictionary) -> void:
	session_data = _serialize_session(data)
	save_progress()

func clear_session() -> void:
	if session_data.is_empty():
		return
	session_data = {}
	save_progress()

func delete_save_file() -> void:
	max_unlocked_level = get_campaign_start_unlock()
	level_star_bits.clear()
	session_data = {}
	tutorial_intro_answered = false
	ads_wins_since_interstitial = 0
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	save_progress()

func set_tutorial_intro_answered(answered: bool = true) -> void:
	tutorial_intro_answered = answered
	save_progress()

static func _coord_key(v: Vector2i) -> String:
	return "%d,%d" % [v.x, v.y]

static func _parse_coord_key(s: String) -> Vector2i:
	var parts := str(s).split(",")
	if parts.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))

static func _serialize_vec(v: Vector2i) -> Array:
	return [v.x, v.y]

static func _deserialize_vec(val: Variant) -> Vector2i:
	if typeof(val) == TYPE_VECTOR2I:
		return val
	if typeof(val) == TYPE_ARRAY and val.size() >= 2:
		return Vector2i(int(val[0]), int(val[1]))
	return Vector2i.ZERO

static func _serialize_coord_dict(src: Dictionary) -> Dictionary:
	var out := {}
	for key in src:
		var k: String = str(key) if typeof(key) == TYPE_STRING else _coord_key(key as Vector2i)
		out[k] = src[key]
	return out

static func _deserialize_coord_dict(src: Dictionary) -> Dictionary:
	var out := {}
	for key in src:
		out[_parse_coord_key(str(key))] = src[key]
	return out

static func _serialize_pairs(pairs: Array) -> Array:
	var out: Array = []
	for pair in pairs:
		if typeof(pair) != TYPE_DICTIONARY:
			continue
		var d := {}
		for key in pair:
			var val = pair[key]
			if typeof(val) == TYPE_VECTOR2I:
				d[key] = _serialize_vec(val)
			else:
				d[key] = val
		out.append(d)
	return out

static func _deserialize_pairs(pairs: Array) -> Array:
	var out: Array = []
	for pair in pairs:
		if typeof(pair) != TYPE_DICTIONARY:
			continue
		var d := {}
		for key in pair:
			var val = pair[key]
			if key == "type" or key == "state":
				d[key] = val
			elif typeof(val) == TYPE_ARRAY or typeof(val) == TYPE_VECTOR2I:
				d[key] = _deserialize_vec(val)
			else:
				d[key] = val
		out.append(d)
	return out

static func _serialize_cells(cells: Dictionary) -> Dictionary:
	var out := {}
	for key in cells:
		var k: String = str(key) if typeof(key) == TYPE_STRING else _coord_key(key as Vector2i)
		var entry = cells[key]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var dir_val = entry.get("shifter_direction", Vector2i.ZERO)
		var dir: Vector2i = dir_val if typeof(dir_val) == TYPE_VECTOR2I else _deserialize_vec(dir_val)
		out[k] = {
			"state": int(entry.get("state", 0)),
			"shifter_direction": _serialize_vec(dir),
		}
	return out

static func _deserialize_cells(cells: Dictionary) -> Dictionary:
	var out := {}
	for key in cells:
		var entry = cells[key]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		out[_parse_coord_key(str(key))] = {
			"state": int(entry.get("state", 0)),
			"shifter_direction": _deserialize_vec(entry.get("shifter_direction", [0, 0])),
		}
	return out

static func _serialize_session(data: Dictionary) -> Dictionary:
	return {
		"level_path": str(data.get("level_path", "")),
		"level_number": int(data.get("level_number", 0)),
		"elapsed_seconds": int(data.get("elapsed_seconds", 0)),
		"shifter_move_count": int(data.get("shifter_move_count", 0)),
		"hints_used": int(data.get("hints_used", 0)),
		"required_jokers": int(data.get("required_jokers", 0)),
		"required_shifter_moves": int(data.get("required_shifter_moves", 0)),
		"has_shifters": bool(data.get("has_shifters", false)),
		"prefer_hidden_hints": bool(data.get("prefer_hidden_hints", false)),
		"challenges_disabled": bool(data.get("challenges_disabled", false)),
		"star_time_limit": int(data.get("star_time_limit", 0)),
		"hints_remaining": int(data.get("hints_remaining", GameConstants.HINT_LIMIT_UNLIMITED)),
		"available_tiles": data.get("available_tiles", [0, 1, 2]).duplicate(),
		"layout": _serialize_coord_dict(data.get("layout", {})),
		"shifter_pairs": _serialize_pairs(data.get("shifter_pairs", [])),
		"active_constraint_pairs": _serialize_pairs(data.get("active_constraint_pairs", [])),
		"hidden_reference_constraints": _serialize_pairs(data.get("hidden_reference_constraints", [])),
		"solved_solution_reference": _serialize_coord_dict(data.get("solved_solution_reference", {})),
		"cells": _serialize_cells(data.get("cells", {})),
		"undo_history": _serialize_undo_history(data.get("undo_history", {})),
	}

static func _deserialize_session(data: Dictionary) -> Dictionary:
	return {
		"level_path": str(data.get("level_path", "")),
		"level_number": int(data.get("level_number", 0)),
		"elapsed_seconds": int(data.get("elapsed_seconds", 0)),
		"shifter_move_count": int(data.get("shifter_move_count", 0)),
		"hints_used": int(data.get("hints_used", 0)),
		"required_jokers": int(data.get("required_jokers", 0)),
		"required_shifter_moves": int(data.get("required_shifter_moves", 0)),
		"has_shifters": bool(data.get("has_shifters", false)),
		"prefer_hidden_hints": bool(data.get("prefer_hidden_hints", false)),
		"challenges_disabled": bool(data.get("challenges_disabled", false)),
		"star_time_limit": int(data.get("star_time_limit", 0)),
		"hints_remaining": int(data.get("hints_remaining", GameConstants.HINT_LIMIT_UNLIMITED)),
		"has_hints_remaining": data.has("hints_remaining"),
		"available_tiles": data.get("available_tiles", [0, 1, 2]).duplicate(),
		"layout": _deserialize_coord_dict(data.get("layout", {})),
		"shifter_pairs": _deserialize_pairs(data.get("shifter_pairs", [])),
		"active_constraint_pairs": _deserialize_pairs(data.get("active_constraint_pairs", [])),
		"hidden_reference_constraints": _deserialize_pairs(data.get("hidden_reference_constraints", [])),
		"solved_solution_reference": _deserialize_coord_dict(data.get("solved_solution_reference", {})),
		"cells": _deserialize_cells(data.get("cells", {})),
		"undo_history": _deserialize_undo_history(data.get("undo_history", {})),
	}

static func _serialize_undo_history(history: Dictionary) -> Dictionary:
	if history.is_empty():
		return {}
	return {
		"current": _serialize_game_snapshot(history.get("current", {})),
		"undo": _serialize_snapshot_list(history.get("undo", [])),
		"redo": _serialize_snapshot_list(history.get("redo", [])),
	}

static func _deserialize_undo_history(history: Dictionary) -> Dictionary:
	if history.is_empty():
		return {}
	return {
		"current": _deserialize_game_snapshot(history.get("current", {})),
		"undo": _deserialize_snapshot_list(history.get("undo", [])),
		"redo": _deserialize_snapshot_list(history.get("redo", [])),
	}

static func _serialize_snapshot_list(snaps: Array) -> Array:
	var out: Array = []
	for snap in snaps:
		if snap is Dictionary:
			out.append(_serialize_game_snapshot(snap))
	return out

static func _deserialize_snapshot_list(snaps: Array) -> Array:
	var out: Array = []
	for snap in snaps:
		if snap is Dictionary:
			out.append(_deserialize_game_snapshot(snap))
	return out

static func _serialize_game_snapshot(snap: Dictionary) -> Dictionary:
	return {
		"moves": int(snap.get("moves", 0)),
		"cells": _serialize_cells(snap.get("cells", {})),
	}

static func _deserialize_game_snapshot(snap: Dictionary) -> Dictionary:
	return {
		"moves": int(snap.get("moves", 0)),
		"cells": _deserialize_cells(snap.get("cells", {})),
	}
