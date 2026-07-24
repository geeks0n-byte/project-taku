extends Control

signal resume_pressed
signal restart_pressed
signal settings_pressed
signal level_select_pressed
signal auto_win_pressed
signal quit_pressed

@onready var resume_btn: Button = $CenterContainer/VBoxContainer/ResumeButton
@onready var restart_btn: Button = $CenterContainer/VBoxContainer/RestartButton
@onready var settings_btn: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var level_select_btn: Button = $CenterContainer/VBoxContainer/LevelSelectButton
@onready var auto_win_btn: Button = $CenterContainer/VBoxContainer/AutoWinButton
@onready var auto_lose_btn: Button = $CenterContainer/VBoxContainer/AutoLoseButton
@onready var quit_btn: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var center_container: CenterContainer = $CenterContainer

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
	HudLayout.mount_screen_header(self, title_label)
	if center_container:
		HudLayout.pin_menu_body_below_header(center_container, 1100.0)
	var spacer := get_node_or_null("CenterContainer/VBoxContainer/Spacer") as Control
	if spacer:
		spacer.custom_minimum_size.y = 0.0
		spacer.visible = false

func _fit_menu_buttons() -> void:
	for btn in [resume_btn, restart_btn, settings_btn, level_select_btn, quit_btn, auto_win_btn]:
		HudLayout.apply_primary_button(btn)
	if title_label:
		HudLayout.apply_screen_header_style(title_label)

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

func _on_level_select() -> void:
	level_select_pressed.emit()

func _on_auto_win() -> void:
	auto_win_pressed.emit()

func _on_quit() -> void:
	quit_pressed.emit()
