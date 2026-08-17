extends Control

signal resume_pressed
signal restart_pressed
signal settings_pressed
signal level_select_pressed
signal auto_win_pressed
signal quit_pressed

const _TILE_TEX := preload("res://resources/buttons/button_tile_gray_dark.svg")
const MENU_BTN_SIZE := Vector2(720, 150)
const MENU_BTN_FONT := 64

@onready var resume_btn: Button = $CenterContainer/VBoxContainer/ResumeButton
@onready var restart_btn: Button = $CenterContainer/VBoxContainer/RestartButton
@onready var settings_btn: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var level_select_btn: Button = $CenterContainer/VBoxContainer/LevelSelectButton
@onready var auto_win_btn: Button = $CenterContainer/VBoxContainer/AutoWinButton
@onready var quit_btn: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var title_label: Label = $TitleLabel
var _restart_label_key: String = "UI_NEW_LAYOUT"

func _ready() -> void:
	if resume_btn:
		resume_btn.pressed.connect(_on_resume)
	if restart_btn:
		restart_btn.pressed.connect(_on_restart)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings)
	if level_select_btn:
		level_select_btn.pressed.connect(_on_level_select)
	if auto_win_btn:
		auto_win_btn.pressed.connect(_on_auto_win)
	if quit_btn:
		quit_btn.pressed.connect(_on_quit)
	_style_header()
	_fit_menu_buttons()
	if SaveManager and not SaveManager.language_changed.is_connected(_on_language_changed):
		SaveManager.language_changed.connect(_on_language_changed)

func _style_header() -> void:
	if not title_label:
		return
	title_label.set_meta("_screen_header_font_size", 72)
	title_label.set_meta("_screen_header_outline", GameConstants.SCREEN_HEADER_OUTLINE)
	HudLayout._bind_header_translation_key(title_label, "PAUSED")
	HudLayout.apply_screen_header_style(title_label)

func _fit_menu_buttons() -> void:
	if restart_btn:
		restart_btn.text = _restart_label_key
	if quit_btn:
		quit_btn.text = "UI_MAIN_MENU"
	for btn in [resume_btn, restart_btn, level_select_btn, settings_btn, quit_btn, auto_win_btn]:
		_apply_pause_button(btn)
	if title_label:
		title_label.set_meta("_screen_header_font_size", 72)
		title_label.set_meta("_screen_header_outline", GameConstants.SCREEN_HEADER_OUTLINE)
		HudLayout._bind_header_translation_key(title_label, "PAUSED")
		HudLayout.apply_screen_header_style(title_label)

func _apply_pause_button(button: Button) -> void:
	if not button or not button.visible:
		return
	_clear_pause_icon(button)
	button.focus_mode = Control.FOCUS_NONE
	button.flat = false
	_apply_button_tile_styles(button)
	button.custom_minimum_size = MENU_BTN_SIZE
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.clip_text = false
	HudLayout.fit_text_button_single_line(button, MENU_BTN_FONT, 28)
	HudLayout.apply_safe_outline(button, GameConstants.MENU_TEXT_OUTLINE)

func _apply_button_tile_styles(button: Button) -> void:
	if not button:
		return
	for style_name in ["normal", "pressed", "hover", "disabled", "focus"]:
		var box := StyleBoxTexture.new()
		box.texture = _TILE_TEX
		box.texture_margin_left = 16.0
		box.texture_margin_top = 16.0
		box.texture_margin_right = 16.0
		box.texture_margin_bottom = 16.0
		box.content_margin_left = 8.0
		box.content_margin_top = 8.0
		box.content_margin_right = 8.0
		box.content_margin_bottom = 8.0
		if style_name == "hover":
			box.modulate_color = Color(1.2, 1.2, 1.2, 1.0)
		elif style_name == "pressed":
			box.modulate_color = Color(0.8, 0.8, 0.8, 1.0)
		elif style_name == "disabled":
			box.modulate_color = Color(0.55, 0.55, 0.55, 1.0)
		button.add_theme_stylebox_override(style_name, box)

func _clear_pause_icon(button: Button) -> void:
	var host := button.get_node_or_null("PauseIcon") as TextureRect
	if host:
		host.queue_free()

func set_restart_label_key(key: String) -> void:
	_restart_label_key = key if not key.is_empty() else "UI_NEW_LAYOUT"
	if restart_btn:
		restart_btn.text = _restart_label_key
		_apply_pause_button(restart_btn)

func _on_language_changed() -> void:
	HudLayout.apply_locale_fonts_to_tree(self)
	_fit_menu_buttons()

func set_debug_tools_visible(visible_state: bool) -> void:
	if auto_win_btn:
		auto_win_btn.visible = visible_state
	_fit_menu_buttons()

func _on_resume() -> void:
	resume_pressed.emit()

func _on_restart() -> void:
	restart_pressed.emit()

func _on_settings() -> void:
	settings_pressed.emit()

func _on_level_select() -> void:
	level_select_pressed.emit()

func _on_auto_win() -> void:
	auto_win_pressed.emit()

func _on_quit() -> void:
	quit_pressed.emit()
