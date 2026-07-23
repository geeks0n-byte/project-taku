extends Control

signal resume_pressed
signal restart_pressed
signal settings_pressed
signal auto_win_pressed
signal auto_lose_pressed
signal quit_pressed

@onready var resume_btn: Button = $CenterContainer/VBoxContainer/ResumeButton
@onready var restart_btn: Button = $CenterContainer/VBoxContainer/RestartButton
@onready var settings_btn: Button = $CenterContainer/VBoxContainer/SettingsButton
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
	if auto_win_btn:
		auto_win_btn.pressed.connect(_on_auto_win)
	if auto_lose_btn:
		auto_lose_btn.pressed.connect(_on_auto_lose)
	if quit_btn:
		quit_btn.pressed.connect(_on_quit)
	_mount_header()

func _mount_header() -> void:
	if not title_label:
		return
	HudLayout.mount_screen_header(self, title_label)
	if center_container:
		HudLayout.pin_menu_body_below_header(center_container, 980.0)
	var spacer := get_node_or_null("CenterContainer/VBoxContainer/Spacer") as Control
	if spacer:
		spacer.custom_minimum_size.y = 0.0
		spacer.visible = false

func set_debug_tools_visible(visible_state: bool) -> void:
	if auto_win_btn:
		auto_win_btn.visible = visible_state
	if auto_lose_btn:
		auto_lose_btn.visible = visible_state

func _on_resume() -> void:
	resume_pressed.emit()

func _on_restart() -> void:
	restart_pressed.emit()

func _on_settings() -> void:
	settings_pressed.emit()

func _on_auto_win() -> void:
	auto_win_pressed.emit()

func _on_auto_lose() -> void:
	auto_lose_pressed.emit()

func _on_quit() -> void:
	quit_pressed.emit()
