extends Control
class_name PauseMenu

signal resume_pressed
signal restart_pressed
signal quit_pressed
signal auto_win_pressed 

@onready var resume_button: TextureButton = $%ResumeButton
@onready var restart_button: TextureButton = $%RestartButton
@onready var quit_button: TextureButton = $%QuitButton
@onready var auto_win_button: TextureButton = $%AutoWinButton 

func _ready() -> void:
	hide()
	
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	if auto_win_button:
		auto_win_button.pressed.connect(_on_auto_win_pressed)

func _on_resume_pressed() -> void:
	hide()
	resume_pressed.emit()

func _on_restart_pressed() -> void:
	hide()
	restart_pressed.emit()

func _on_auto_win_pressed() -> void:
	hide()
	auto_win_pressed.emit()

func _on_quit_pressed() -> void:
	hide()
	quit_pressed.emit()
