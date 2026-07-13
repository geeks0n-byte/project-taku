class_name UIManager
extends Node

signal pause_requested
signal resume_requested
signal reset_requested
signal restart_requested
signal auto_win_requested

@onready var level_label = $"../LevelLabel"
@onready var status_label = $"../StatusLabel"
@onready var pause_button = $"../PauseButton"
@onready var reset_button = $"../ResetButton" # CHANGED: Now in the main HUD
@onready var timer_label = $"../TimerLabel"

@onready var pause_panel = $"../PauseLayer/PausePanel"
@onready var pause_resume_button = $"../PauseLayer/PausePanel/ResumeButton"
# Removed pause_reset_button from here
@onready var pause_main_menu_button = $"../PauseLayer/PausePanel/MainMenuButton"
@onready var pause_auto_win_button = $"../PauseLayer/PausePanel/AutoWinButton"
@onready var pause_how_to_play_button = $"../PauseLayer/PausePanel/HowToPlayButton"

@onready var how_to_play_panel = $"../HowToPlayLayer/HowToPlayPanel"
@onready var how_to_play_label = $"../HowToPlayLayer/HowToPlayPanel/HowToPlayLabel"
@onready var how_to_play_back_button = $"../HowToPlayLayer/HowToPlayPanel/BackButton"

@onready var victory_panel = $"../VictoryLayer/VictoryPanel"
@onready var restart_button = $"../VictoryLayer/VictoryPanel/RestartButton"
@onready var main_menu_button = $"../VictoryLayer/VictoryPanel/MainMenuButton"
@onready var time_result_label = $"../VictoryLayer/VictoryPanel/TimeResultLabel"
@onready var win_label = $"../VictoryLayer/VictoryPanel/WinLabel"

func setup_ui(show_debug_tools: bool, cell_size: float):
	if timer_label:
		timer_label.add_theme_font_size_override("font_size", 32)
		timer_label.modulate = Color(0.9, 0.9, 0.9)
		timer_label.global_position = Vector2(650, 40)
		timer_label.size = Vector2(300, 50)
		
	if pause_button:
		pause_button.text = "Pause"
		pause_button.add_theme_font_size_override("font_size", 28)
		pause_button.global_position = Vector2(120, 40) 
		pause_button.size = Vector2(140, 60) # Made slightly thinner to fit nicely

	# NEW: Set up the HUD Reset Button right next to the Pause Button
	if reset_button:
		reset_button.text = "Reset"
		reset_button.add_theme_font_size_override("font_size", 28)
		reset_button.global_position = Vector2(280, 40) # Positioned 20px to the right of Pause
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

	var panel_size = Vector2(400, 500)
	var square_panel_size = Vector2(400, 450)
	var panel_pos = Vector2(340, 300)
	var menu_button_size = Vector2(300, 60)
	var button_center_x = (panel_size.x - menu_button_size.x) / 2 
	var spacing_y = 80 

	if pause_panel:
		pause_panel.custom_minimum_size = panel_size
		pause_panel.global_position = panel_pos
		pause_panel.size = panel_size

	var p_start_y = 50 # Pushed the first button down slightly to center the list better

	if pause_resume_button:
		pause_resume_button.text = "Resume"
		pause_resume_button.add_theme_font_size_override("font_size", 28)
		pause_resume_button.position = Vector2(button_center_x, p_start_y)
		pause_resume_button.size = menu_button_size
	p_start_y += spacing_y

	# Removed Reset Button setup from here!

	if pause_how_to_play_button:
		pause_how_to_play_button.text = "How to Play"
		pause_how_to_play_button.add_theme_font_size_override("font_size", 28)
		pause_how_to_play_button.position = Vector2(button_center_x, p_start_y)
		pause_how_to_play_button.size = menu_button_size
	p_start_y += spacing_y

	if pause_main_menu_button:
		pause_main_menu_button.text = "Main Menu"
		pause_main_menu_button.add_theme_font_size_override("font_size", 28)
		pause_main_menu_button.position = Vector2(button_center_x, p_start_y)
		pause_main_menu_button.size = menu_button_size
	p_start_y += spacing_y

	if pause_auto_win_button:
		pause_auto_win_button.text = "DEBUG: Auto-Win"
		pause_auto_win_button.add_theme_font_size_override("font_size", 28) 
		pause_auto_win_button.position = Vector2(button_center_x, p_start_y)
		pause_auto_win_button.size = menu_button_size

	if how_to_play_panel:
		how_to_play_panel.custom_minimum_size = panel_size
		how_to_play_panel.global_position = panel_pos
		how_to_play_panel.size = panel_size

	if how_to_play_label:
		how_to_play_label.text = "RULES:\n\n1. Fill grid with 0s and 1s.\n2. Max 2 identical symbols in a row/col.\n3. Equal amount of 0s and 1s per line.\n4. Walls (-2) break lines.\n5. Jokers (2) match anything."
		how_to_play_label.add_theme_font_size_override("font_size", 20)
		how_to_play_label.modulate = Color(0.9, 0.9, 0.9)
		how_to_play_label.size = Vector2(panel_size.x - 40, 320)
		how_to_play_label.position = Vector2(20, 30)
		how_to_play_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		how_to_play_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if how_to_play_back_button:
		how_to_play_back_button.text = "Back"
		how_to_play_back_button.add_theme_font_size_override("font_size", 28)
		how_to_play_back_button.position = Vector2(button_center_x, 400)
		how_to_play_back_button.size = menu_button_size

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

	_connect_signals(show_debug_tools)

func _connect_signals(show_debug_tools: bool):
	pause_button.pressed.connect(func(): pause_requested.emit())
	
	# CHANGED: Listen to the new HUD reset button
	if reset_button:
		reset_button.pressed.connect(func(): reset_requested.emit())
		
	pause_resume_button.pressed.connect(func(): resume_requested.emit())
	restart_button.pressed.connect(func(): restart_requested.emit())
	pause_auto_win_button.pressed.connect(func(): auto_win_requested.emit())
	
	pause_main_menu_button.pressed.connect(_on_main_menu_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	
	pause_how_to_play_button.pressed.connect(func():
		pause_panel.visible = false
		how_to_play_panel.visible = true
	)
	how_to_play_back_button.pressed.connect(func():
		how_to_play_panel.visible = false
		pause_panel.visible = true
	)
	
	pause_auto_win_button.visible = show_debug_tools

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
	if pause_panel: pause_panel.visible = false
	if how_to_play_panel: how_to_play_panel.visible = false

func show_pause_menu(is_visible: bool):
	if pause_panel: pause_panel.visible = is_visible

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
