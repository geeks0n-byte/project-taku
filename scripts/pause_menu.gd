extends Control

# Signals emitted to main.gd, which owns the actual game logic.
# The pause menu itself does nothing — it just reports what the player chose.
signal resume_pressed
signal restart_pressed
signal settings_pressed
signal level_select_pressed
signal auto_win_pressed
signal quit_pressed

const MENU_BTN_WIDTH := 720.0
const MENU_BTN_ROW_H := 118.0
const MENU_BTN_ROW_H_MIN := 92.0
const MENU_BTN_SEP := 14
# Same font size as main menu buttons (main_menu.gd MENU_BTN_FONT).
const MENU_BTN_FONT := 64
const PAUSE_TITLE_FONT_SIZE := GameConstants.SCREEN_HEADER_FONT_SIZE + 2

@onready var resume_btn: Button = $CenterContainer/VBoxContainer/ResumeButton
@onready var restart_btn: Button = $CenterContainer/VBoxContainer/RestartButton
@onready var settings_btn: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var level_select_btn: Button = $CenterContainer/VBoxContainer/LevelSelectButton
@onready var auto_win_btn: Button = $CenterContainer/VBoxContainer/AutoWinButton
@onready var quit_btn: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var title_label: Label = $TitleLabel
@onready var _btn_vbox: VBoxContainer = $CenterContainer/VBoxContainer
@onready var _btn_host: Control = $CenterContainer

# The restart button label changes depending on game mode (restart vs new layout).
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
	# Deferred so SaveManager's tree-walk font pass finishes first —
	# our overrides must be applied last to win.
	call_deferred("_style_header")
	call_deferred("_fit_menu_buttons")

func _style_header() -> void:
	if not title_label:
		return
	title_label.set_meta("_screen_header_font_size", PAUSE_TITLE_FONT_SIZE)
	HudLayout._bind_header_translation_key(title_label, "PAUSED")
	HudLayout.apply_screen_header_style(title_label)

func _visible_menu_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for btn in [resume_btn, restart_btn, level_select_btn, settings_btn, quit_btn, auto_win_btn]:
		if btn and btn.visible:
			buttons.append(btn)
	return buttons

func _menu_row_height() -> float:
	var buttons := _visible_menu_buttons()
	var count := buttons.size()
	if count <= 0:
		return MENU_BTN_ROW_H
	var avail := _btn_host.size.y if _btn_host else 0.0
	if avail <= 0.0:
		return MENU_BTN_ROW_H
	var needed_sep := maxf(0, count - 1) * MENU_BTN_SEP
	var row_h := (avail - needed_sep) / float(count)
	if row_h >= MENU_BTN_ROW_H:
		return MENU_BTN_ROW_H
	return maxf(MENU_BTN_ROW_H_MIN, floor(row_h))

func _fit_menu_buttons() -> void:
	if _btn_vbox:
		_btn_vbox.add_theme_constant_override("separation", MENU_BTN_SEP)
	if restart_btn:
		restart_btn.text = _restart_label_key
		restart_btn.set_meta("_tr_key", _restart_label_key)
	if quit_btn:
		quit_btn.text = "UI_MAIN_MENU"
		quit_btn.set_meta("_tr_key", "UI_MAIN_MENU")
	var row_h := _menu_row_height()
	for btn in [resume_btn, restart_btn, level_select_btn, settings_btn, quit_btn]:
		_apply_pause_button(btn, row_h)
	_style_auto_win_button(row_h)
	if title_label:
		title_label.set_meta("_screen_header_font_size", PAUSE_TITLE_FONT_SIZE)
		HudLayout._bind_header_translation_key(title_label, "PAUSED")
		HudLayout.apply_screen_header_style(title_label)

# Keeps Auto Win in the same pause-menu slot, but fully invisible while still clickable.
func _style_auto_win_button(row_h: float = MENU_BTN_ROW_H) -> void:
	if not auto_win_btn or not auto_win_btn.visible:
		return
	_clear_pause_icon(auto_win_btn)
	HudLayout._clear_pixel_raster(auto_win_btn)
	auto_win_btn.remove_meta("_safe_pixel_label")
	auto_win_btn.focus_mode = Control.FOCUS_NONE
	auto_win_btn.flat = true
	auto_win_btn.text = ""
	auto_win_btn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	auto_win_btn.modulate = Color(1, 1, 1, 0)
	auto_win_btn.self_modulate = Color(1, 1, 1, 0)
	var empty := StyleBoxEmpty.new()
	for style_name in ["normal", "pressed", "hover", "disabled", "focus"]:
		auto_win_btn.add_theme_stylebox_override(style_name, empty)
	auto_win_btn.custom_minimum_size = Vector2(MENU_BTN_WIDTH, row_h)
	auto_win_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	auto_win_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	auto_win_btn.mouse_default_cursor_shape = Control.CURSOR_ARROW

func _apply_pause_button(button: Button, row_h: float = MENU_BTN_ROW_H) -> void:
	if not button or not button.visible:
		return
	_clear_pause_icon(button)
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
	var empty := StyleBoxEmpty.new()
	for style_name in ["normal", "pressed", "hover", "disabled", "focus"]:
		button.add_theme_stylebox_override(style_name, empty)
	button.set_meta("_use_default_font", not HudFonts.uses_pixel_font())
	button.custom_minimum_size = Vector2(MENU_BTN_WIDTH, row_h)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.clip_text = false
	var raw := button.text.strip_edges()
	var key := raw if not raw.is_empty() else String(button.get_meta("_tr_key", "")).strip_edges()
	if not key.is_empty():
		button.set_meta("_tr_key", key)
	var display := String(TranslationServer.translate(key)) if not key.is_empty() else button.text
	if display.is_empty():
		display = key
	if HudFonts.uses_pixel_font():
		HudLayout.apply_pixel_mono_button(button, display, MENU_BTN_FONT, Color.WHITE)
	else:
		HudLayout._clear_pixel_raster(button)
		button.remove_meta("_safe_pixel_label")
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
		button.text = key if not key.is_empty() else button.text
		HudLayout.apply_locale_font_to_control(button)
		button.add_theme_font_size_override("font_size", HudLayout.body_font_size(MENU_BTN_FONT))
		HudLayout.apply_safe_outline(button, GameConstants.MENU_TEXT_OUTLINE)

func _clear_pause_icon(button: Button) -> void:
	var host := button.get_node_or_null("PauseIcon") as TextureRect
	if host:
		host.queue_free()

func set_restart_label_key(key: String) -> void:
	_restart_label_key = key if not key.is_empty() else "UI_NEW_LAYOUT"
	if restart_btn:
		restart_btn.text = _restart_label_key
		restart_btn.set_meta("_tr_key", _restart_label_key)
		_apply_pause_button(restart_btn, _menu_row_height())

func _on_language_changed() -> void:
	_fit_menu_buttons()
	HudLayout.apply_locale_fonts_to_tree(self)

func set_debug_tools_visible(visible_state: bool) -> void:
	if auto_win_btn:
		auto_win_btn.visible = visible_state
	_fit_menu_buttons()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_fit_menu_buttons")

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
