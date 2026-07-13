extends Control
class_name PauseMenu

# 1. Add this signal at the top alongside your other signals
signal resume_pressed
signal restart_pressed
signal quit_pressed
signal auto_win_pressed # <--- ADD THIS

# 2. Get a reference to the button using its unique name
@onready var resume_button: Button = $%ResumeButton
@onready var restart_button: Button = $%RestartButton
@onready var quit_button: Button = $%QuitButton
@onready var auto_win_button: Button = $%AutoWinButton # <--- ADD THIS

func _ready() -> void:
	hide()
	
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# 3. Connect the new button's pressed event
	if auto_win_button:
		auto_win_button.pressed.connect(_on_auto_win_pressed)

func _on_resume_pressed() -> void:
	hide()
	resume_pressed.emit()

func _on_restart_pressed() -> void:
	hide()
	restart_pressed.emit()

# 4. Add this function to emit the auto-win signal and hide the menu
func _on_auto_win_pressed() -> void:
	hide()
	auto_win_pressed.emit()

func _on_quit_pressed() -> void:
	get_tree().quit()
