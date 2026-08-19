extends Control

signal resume_pressed
signal restart_pressed
signal settings_pressed
signal level_select_pressed
signal auto_win_pressed
signal quit_pressed

const MENU_BTN_SIZE := Vector2(720, 118)
const MENU_BTN_FONT := 48

@onready var resume_btn: Button = $CenterContainer/VBoxContainer/ResumeButton
@onready var restart_btn: Button = $CenterContainer/VBoxContainer/RestartButton
@onready var settings_btn: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var level_select_btn: Button = $CenterContainer/VBoxContainer/LevelSelectButton
@onready var auto_win_btn: Button = $CenterContainer/VBoxContainer/AutoWinButton
@onready var quit_btn: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var title_label: Label = $TitleLabel
@onready var _btn_vbox: VBoxContainer = $CenterContainer/VBoxContainer
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
	if SaveManager and not SaveManager.language_changed.is_connected(_on_language_changed):
		SaveManager.language_changed.connect(_on_language_changed)
	# Deferred so all autoload tree-walk font passes have finished first,
	# ensuring our overrides are applied last and win.
	call_deferred("_style_header")
	call_deferred("_fit_menu_buttons")

func _style_header() -> void:
	if not title_label:
		return
	HudLayout._bind_header_translation_key(title_label, "PAUSED")
	HudLayout.apply_screen_header_style(title_label)

func _fit_menu_buttons() -> void:
	if _btn_vbox:
		_btn_vbox.add_theme_constant_override("separation", 20)
	if restart_btn:
		restart_btn.text = _restart_label_key
	if quit_btn:
		quit_btn.text = "UI_MAIN_MENU"
	for btn in [resume_btn, restart_btn, level_select_btn, settings_btn, quit_btn, auto_win_btn]:
		_apply_pause_button(btn)
	if title_label:
		HudLayout._bind_header_translation_key(title_label, "PAUSED")
		HudLayout.apply_screen_header_style(title_label)

func _apply_pause_button(button: Button) -> void:
	if not button or not button.visible:
		return
	_clear_pause_icon(button)
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
	var empty := StyleBoxEmpty.new()
	for style_name in ["normal", "pressed", "hover", "disabled", "focus"]:
		button.add_theme_stylebox_override(style_name, empty)
	button.set_meta("_use_default_font", not HudLayout.uses_pixel_font())
	button.custom_minimum_size = Vector2(0, MENU_BTN_SIZE.y)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.clip_text = false
	HudLayout.apply_locale_font_to_control(button)
	button.add_theme_font_size_override("font_size", MENU_BTN_FONT)
	HudLayout.apply_safe_outline(button, GameConstants.MENU_TEXT_OUTLINE)

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
