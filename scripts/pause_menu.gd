extends Control

signal resume_pressed
signal restart_pressed
signal settings_pressed
signal auto_win_pressed
signal quit_pressed

const MENU_BTN_FONT := 64
const MENU_BTN_OUTLINE := GameConstants.MENU_TEXT_OUTLINE

@onready var resume_btn: Button = $CenterContainer/VBoxContainer/ResumeButton
@onready var restart_btn: Button = $CenterContainer/VBoxContainer/RestartButton
@onready var settings_btn: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var auto_win_btn: Button = $CenterContainer/VBoxContainer/AutoWinButton
@onready var auto_lose_btn: Button = $CenterContainer/VBoxContainer/AutoLoseButton
@onready var quit_btn: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var center_container: CenterContainer = $CenterContainer
var _restart_label_key: String = "UI_NEW_LAYOUT"

func _ready() -> void:
	if resume_btn:
		resume_btn.pressed.connect(_on_resume)
	if restart_btn:
		restart_btn.pressed.connect(_on_restart)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings)
	if auto_win_btn:
		auto_win_btn.pressed.connect(_on_auto_win)
	if auto_lose_btn:
		auto_lose_btn.visible = false
	if quit_btn:
		quit_btn.pressed.connect(_on_quit)
	_mount_header()
	_fit_menu_buttons()
	if SaveManager and not SaveManager.language_changed.is_connected(_on_language_changed):
		SaveManager.language_changed.connect(_on_language_changed)

func _mount_header() -> void:
	if not title_label:
		return
	# Match Options / other screen headers (72), not the smaller default 64.
	title_label.set_meta("_screen_header_font_size", 72)
	title_label.set_meta("_screen_header_outline", GameConstants.SCREEN_HEADER_OUTLINE)
	HudLayout.mount_screen_header(self, title_label)
	if center_container:
		HudLayout.pin_menu_body_below_header(center_container, 1100.0)
	var spacer := get_node_or_null("CenterContainer/VBoxContainer/Spacer") as Control
	if spacer:
		spacer.custom_minimum_size.y = 0.0
		spacer.visible = false

func _fit_menu_buttons() -> void:
	if restart_btn:
		restart_btn.text = _restart_label_key
	if quit_btn:
		quit_btn.text = "UI_MAIN_MENU"
	for btn in [resume_btn, restart_btn, settings_btn, quit_btn, auto_win_btn]:
		_apply_pause_menu_button(btn)
	if title_label:
		title_label.set_meta("_screen_header_font_size", 72)
		title_label.set_meta("_screen_header_outline", GameConstants.SCREEN_HEADER_OUTLINE)
		HudLayout.apply_screen_header_style(title_label)

## Text-only rows matching the updated main menu / options style.
func _apply_pause_menu_button(button: Button) -> void:
	if not button:
		return
	var empty := StyleBoxEmpty.new()
	for style_name in ["normal", "pressed", "hover", "disabled", "focus"]:
		button.add_theme_stylebox_override(style_name, empty)
	button.flat = true
	var is_resume: bool = button == resume_btn
	var is_main_menu: bool = button == quit_btn
	var row_h := 180.0 if is_resume else 150.0
	var row_w := 780.0 if is_resume else 720.0
	var font_size := 76 if is_resume else MENU_BTN_FONT
	var min_font := 36 if is_resume else 32
	button.custom_minimum_size = Vector2(row_w, row_h)
	button.add_theme_constant_override("outline_size", MENU_BTN_OUTLINE + (2 if is_resume else 0))
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	if is_main_menu:
		# Keep MAIN MENU on one line.
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.clip_text = false
		HudLayout.apply_locale_font_to_control(button)
		var font: Font = HudLayout.ui_font()
		var display := String(TranslationServer.translate(button.text))
		var fitted := HudLayout.scaled_font_size(font_size)
		var min_font_size := HudLayout.scaled_font_size(min_font)
		var target_w := maxf(40.0, button.custom_minimum_size.x - 28.0)
		while fitted > min_font_size:
			var measured := font.get_string_size(display, HORIZONTAL_ALIGNMENT_CENTER, -1, fitted)
			if measured.x <= target_w + 2.0:
				break
			fitted -= 2
		button.add_theme_font_size_override("font_size", fitted)
	else:
		HudLayout.fit_text_button(button, font_size, min_font)

func set_restart_label_key(key: String) -> void:
	_restart_label_key = key if not key.is_empty() else "UI_NEW_LAYOUT"
	if restart_btn:
		restart_btn.text = _restart_label_key
		_apply_pause_menu_button(restart_btn)

func _on_language_changed() -> void:
	_fit_menu_buttons()

func set_debug_tools_visible(visible_state: bool) -> void:
	if auto_win_btn:
		auto_win_btn.visible = visible_state
	if auto_lose_btn:
		auto_lose_btn.visible = false

func _on_resume() -> void:
	resume_pressed.emit()

func _on_restart() -> void:
	restart_pressed.emit()

func _on_settings() -> void:
	settings_pressed.emit()

func _on_auto_win() -> void:
	auto_win_pressed.emit()

func _on_quit() -> void:
	quit_pressed.emit()
