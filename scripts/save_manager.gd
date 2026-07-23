extends Node

const SAVE_PATH = "user://progression.cfg"

var max_unlocked_level: int = 1
var current_language: String = "en"

func _ready() -> void:
	load_progress()

func load_progress() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	
	if err == OK:
		max_unlocked_level = config.get_value("Progression", "max_unlocked_level", 1)
		current_language = config.get_value("Progression", "current_language", "en")
		TranslationServer.set_locale(current_language)
	else:
		current_language = TranslationServer.get_locale().substr(0, 2)
		save_progress()

func save_progress() -> void:
	var config = ConfigFile.new()
	config.set_value("Progression", "max_unlocked_level", max_unlocked_level)
	config.set_value("Progression", "current_language", current_language)
	config.save(SAVE_PATH)

func set_language(lang_code: String) -> void:
	current_language = lang_code
	TranslationServer.set_locale(lang_code)
	save_progress()

func unlock_level(level_num: int) -> void:
	if level_num > max_unlocked_level:
		max_unlocked_level = level_num
		save_progress()

func is_level_unlocked(level_num: int) -> bool:
	return level_num <= max_unlocked_level

func delete_save_file() -> void:
	max_unlocked_level = 1
	current_language = "en"
	TranslationServer.set_locale("en")
	
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	save_progress()
