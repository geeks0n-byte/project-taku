class_name UIManager
extends Node

# Signals required by Main for HUD interactions
signal pause_requested
signal reset_requested
signal restart_requested

@onready var level_label = $"../LevelLabel"
@onready var status_label = $"../StatusLabel"
@onready var pause_button = $"../PauseButton"
@onready var reset_button = $"../ResetButton"
@onready var timer_label = $"../TimerLabel"

# Victory screen overlays (Kept here as it's part of the end-game HUD flow)
@onready var victory_panel = $"../VictoryLayer/VictoryPanel"
@onready var restart_button = $"../VictoryLayer/VictoryPanel/RestartButton"
@onready var main_menu_button = $"../VictoryLayer/VictoryPanel/MainMenuButton"
@onready var time_result_label = $"../VictoryLayer/VictoryPanel/TimeResultLabel"
@onready var win_label = $"../VictoryLayer/VictoryPanel/WinLabel"

func setup_ui(_show_debug_tools: bool, cell_size: float):
	# 1. Main HUD Elements Setup
	if timer_label:
		timer_label.add_theme_font_size_override("font_size", 32)
		timer_label.modulate = Color(0.9, 0.9, 0.9)
		timer_label.global_position = Vector2(650, 40)
		timer_label.size = Vector2(300, 50)
		
	if pause_button:
		pause_button.text = "Pause"
		pause_button.add_theme_font_size_override("font_size", 28)
		pause_button.global_position = Vector2(120, 40) 
		pause_button.size = Vector2(140, 60)

	if reset_button:
		reset_button.text = "Reset"
		reset_button.add_theme_font_size_override("font_size", 28)
		reset_button.global_position = Vector2(280, 40)
		reset_button.size = Vector2(140, 60)
		
	if level_label:
		level_label.add_theme_font_size_override("font_size", 32)
		level_label.modulate = Color(1.0, 1.0, 1.0)
		level_label.global_position = Vector2(120, 120)
		level_label.size = Vector2(400, 50)

	if status_label:
		status_label.text = "Fill the board following the rules!"
		status_label.modulate = Color(1.0, 1.0, 1.0)
		status_label.add_theme_font_size_override("font_size", 32)
		status_label.global_position = Vector2(120, 180 + (7 * cell_size) + 40)
		status_label.size = Vector2(7 * cell_size, 160)
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD

	# 2. Victory Panel Setup Layout
	var square_panel_size = Vector2(400, 450)
	var panel_pos = Vector2(340, 300)
	var menu_button_size = Vector2(300, 60)
	var button_center_x = (square_panel_size.x - menu_button_size.x) / 2 
	var spacing_y = 80 

	if victory_panel:
		victory_panel.custom_minimum_size = square_panel_size
		victory_panel.global_position = panel_pos 
		victory_panel.size = square_panel_size

	if win_label:
		win_label.add_theme_font_size_override("font_size", 32) 
		win_label.modulate = Color(1.0, 0.84, 0.0)
		win_label.size = Vector2(square_panel_size.x, 70) 
		win_label.position = Vector2(0, 20)
		win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER 
		win_label.autowrap_mode = TextServer.AUTOWRAP_WORD 
		
	if time_result_label:
		time_result_label.add_theme_font_size_override("font_size", 24)
		time_result_label.modulate = Color(0.9, 0.9, 0.9)
		time_result_label.size = Vector2(square_panel_size.x, 40)
		time_result_label.position = Vector2(0, 115)
		time_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER 

	var v_start_y = 210 

	if restart_button:
		restart_button.add_theme_font_size_override("font_size", 28)
		restart_button.position = Vector2(button_center_x, v_start_y)
		restart_button.size = menu_button_size
	v_start_y += spacing_y

	if main_menu_button:
		main_menu_button.text = "Main Menu"
		main_menu_button.add_theme_font_size_override("font_size", 28)
		main_menu_button.position = Vector2(button_center_x, v_start_y)
		main_menu_button.size = menu_button_size

	_connect_signals()

func _connect_signals():
	if pause_button:
		pause_button.pressed.connect(func(): pause_requested.emit())
	
	if reset_button:
		reset_button.pressed.connect(func(): reset_requested.emit())
		
	if restart_button:
		restart_button.pressed.connect(func(): restart_requested.emit())
	
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)

func _on_main_menu_pressed():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func update_timer(formatted_time: String):
	if timer_label: timer_label.text = "Time: " + formatted_time

func display_level(num: int):
	if level_label: level_label.text = "Level %d" % num

func show_status_valid():
	if status_label:
		status_label.modulate = Color(0.4, 1.0, 0.4)
		status_label.text = "Looks good so far! Keep going."

func show_status_errors(errors: Array):
	if status_label:
		status_label.modulate = Color(1.0, 0.3, 0.3)
		status_label.text = "\n".join(errors)

func set_overlays_hidden():
	if victory_panel: victory_panel.visible = false

func show_victory(display_num: int, is_last_level: bool, formatted_time: String):
	if status_label:
		status_label.modulate = Color(1.0, 0.84, 0.0)
		status_label.text = "Puzzle Solved!"
	
	if win_label:
		win_label.text = ("All Levels Completed!\nYou Win!" if is_last_level 
		else "Level %d Completed!" % display_num)
	if restart_button:
		restart_button.text = "Play Again" if is_last_level else "Next Level"
	if time_result_label:
		time_result_label.text = "Completion Time: %s" % formatted_time
	if victory_panel:
		victory_panel.visible = true
