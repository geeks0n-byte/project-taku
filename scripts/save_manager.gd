extends Node

const SAVE_PATH = "user://progression.cfg"
const SUPPORTED_LANGUAGES := ["en", "es", "de", "fr", "pl", "ka", "uk"]

signal language_changed

var max_unlocked_level: int = 1
var current_language: String = "en"
var background_static: bool = false

func _ready() -> void:
	load_progress()
	_apply_background_mode()
	if not get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.connect(_on_tree_node_added)
	call_deferred("apply_locale_fonts")

func load_progress() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)

	if err == OK:
		max_unlocked_level = config.get_value("Progression", "max_unlocked_level", 1)
		current_language = config.get_value("Progression", "current_language", "en")
		background_static = bool(config.get_value("Progression", "background_static", false))
		if not SUPPORTED_LANGUAGES.has(current_language):
			current_language = "en"
		TranslationServer.set_locale(current_language)
	else:
		current_language = _detect_system_language()
		TranslationServer.set_locale(current_language)
		save_progress()

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
	config.save(SAVE_PATH)

func set_language(lang_code: String) -> void:
	current_language = lang_code
	TranslationServer.set_locale(lang_code)
	save_progress()
	apply_locale_fonts()
	language_changed.emit()

func apply_locale_fonts() -> void:
	var tree := get_tree()
	if tree and tree.root:
		HudLayout.apply_locale_fonts_to_tree(tree.root)

func _on_tree_node_added(node: Node) -> void:
	HudLayout.apply_locale_font_to_control(node)

func set_background_static(is_static: bool) -> void:
	background_static = is_static
	save_progress()
	_apply_background_mode()

func _apply_background_mode() -> void:
	if SpaceBackground and SpaceBackground.has_method("set_static_mode"):
		SpaceBackground.set_static_mode(background_static)

func unlock_level(level_num: int) -> void:
	if level_num > max_unlocked_level:
		max_unlocked_level = level_num
		save_progress()

func is_level_unlocked(level_num: int) -> bool:
	return level_num <= max_unlocked_level

func delete_save_file() -> void:
	max_unlocked_level = 1
	# Keep language and background preference across progress reset.
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	save_progress()
