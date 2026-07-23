extends CanvasLayer

signal save_deleted

const LANGUAGES = ["en", "es", "de", "fr", "pl", "ka", "uk"]
const LANG_NAMES = ["ENGLISH", "ESPAÑOL", "DEUTSCH", "FRANÇAIS", "POLSKI", "ქართული", "УКРАЇНСЬКА"]
@onready var lang_label = find_child("LanguageLabel", true, false)
@onready var prev_btn = find_child("PrevLangButton", true, false)
@onready var next_btn = find_child("NextLangButton", true, false)
@onready var del_save_btn = find_child("DeleteSaveButton", true, false)
@onready var del_custom_btn = find_child("DeleteCustomButton", true, false)
@onready var close_btn = find_child("CloseOptionsButton", true, false)
@onready var status_label = find_child("StatusLabel", true, false)

func _ready():
	visible = false
	if prev_btn: prev_btn.pressed.connect(_on_prev_lang)
	if next_btn: next_btn.pressed.connect(_on_next_lang)
	if del_save_btn: del_save_btn.pressed.connect(_on_delete_save)
	if del_custom_btn: del_custom_btn.pressed.connect(_on_delete_custom)
	if close_btn: close_btn.pressed.connect(hide_menu)
	_update_lang_label()

func show_menu():
	_update_lang_label()
	if status_label: status_label.text = ""
	visible = true

func hide_menu():
	visible = false

func _update_lang_label():
	if not lang_label: return
	var current_locale = TranslationServer.get_locale().substr(0, 2)
	var idx = LANGUAGES.find(current_locale)
	if idx == -1: idx = 0
	lang_label.text = LANG_NAMES[idx]

func _on_prev_lang():
	var current_locale = TranslationServer.get_locale().substr(0, 2)
	var idx = LANGUAGES.find(current_locale)
	if idx == -1: idx = 0
	idx = (idx - 1 + LANGUAGES.size()) % LANGUAGES.size()
	SaveManager.set_language(LANGUAGES[idx])
	_update_lang_label()

func _on_next_lang():
	var current_locale = TranslationServer.get_locale().substr(0, 2)
	var idx = LANGUAGES.find(current_locale)
	if idx == -1: idx = 0
	idx = (idx + 1) % LANGUAGES.size()
	SaveManager.set_language(LANGUAGES[idx])
	_update_lang_label()

func _on_delete_save():
	SaveManager.delete_save_file()
	if status_label:
		status_label.text = tr("SAVE_DELETED")
		status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	save_deleted.emit()

func _on_delete_custom():
	if DirAccess.dir_exists_absolute(GameConstants.DEV_LEVELS_DIR):
		var dir = DirAccess.open(GameConstants.DEV_LEVELS_DIR)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".remap")):
					DirAccess.remove_absolute(GameConstants.DEV_LEVELS_DIR + file_name)
				file_name = dir.get_next()
			dir.list_dir_end()
	if status_label:
		status_label.text = tr("CUSTOM_DELETED")
		status_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
