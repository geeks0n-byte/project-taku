extends Control

signal resume_pressed
signal restart_pressed
signal auto_win_pressed
signal quit_pressed

@onready var resume_btn = find_child("ResumeButton", true, false)
@onready var restart_btn = find_child("RestartButton", true, false)
@onready var auto_win_btn = find_child("AutoWinButton", true, false)
@onready var quit_btn = find_child("QuitButton", true, false)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if resume_btn and not resume_btn.pressed.is_connected(_on_resume):
		resume_btn.pressed.connect(_on_resume)
	if restart_btn and not restart_btn.pressed.is_connected(_on_restart):
		restart_btn.pressed.connect(_on_restart)
	if auto_win_btn and not auto_win_btn.pressed.is_connected(_on_auto_win):
		auto_win_btn.pressed.connect(_on_auto_win)
	if quit_btn and not quit_btn.pressed.is_connected(_on_quit):
		quit_btn.pressed.connect(_on_quit)

func _on_resume() -> void:
	resume_pressed.emit()

func _on_restart() -> void:
	restart_pressed.emit()

func _on_auto_win() -> void:
	auto_win_pressed.emit()

func _on_quit() -> void:
	quit_pressed.emit()
