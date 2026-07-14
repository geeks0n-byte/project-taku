class_name UIManager
extends Node

# ==========================================
# SIGNALS
# ==========================================
signal pause_requested
signal reset_requested
signal how_to_play_requested 
signal resume_from_tutorial_requested 
signal next_level_requested  
signal play_again_requested  

# ==========================================
# NODE REFERENCES
# ==========================================
# 1. Main HUD (Gameplay Screen)
@onready var level_label = $"../LevelLabel"
@onready var status_label = $"../StatusLabel"
@onready var pause_button = $"../PauseButton"
@onready var reset_button = $"../ResetButton"
@onready var how_to_play_button = $"../HowToPlayButton" 
@onready var timer_label = $"../TimerLabel"

# 2. Victory Screen Overlay
@onready var victory_panel = $"../VictoryLayer/VictoryPanel"
@onready var restart_button = $"../VictoryLayer/VictoryPanel/RestartButton"
@onready var main_menu_button = $"../VictoryLayer/VictoryPanel/MainMenuButton"
@onready var time_result_label = $"../VictoryLayer/VictoryPanel/TimeResultLabel"
@onready var win_label = $"../VictoryLayer/VictoryPanel/WinLabel"

# 3. Tutorial Screen Overlay
@onready var how_to_play_container = $"../HowToPlayLayer/CenterContainer"
@onready var how_to_play_panel = $"../HowToPlayLayer/CenterContainer/HowToPlayPanel" 
@onready var rules_label = $"../HowToPlayLayer/CenterContainer/HowToPlayPanel/RichTextLabel"
@onready var tutorial_back_button = $"../HowToPlayLayer/CenterContainer/HowToPlayPanel/BackButton"

var _is_last_level_completed: bool = false

# ==========================================
# UI INITIALIZATION & LAYOUT MATH
# ==========================================
func setup_ui(_show_debug_tools: bool, cell_size: float):
	
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
		
	if how_to_play_button:
		how_to_play_button.global_position = Vector2(440, 40)
		how_to_play_button.size = Vector2(60, 60)
		
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

	var tutorial_size = Vector2(700, 800)
	
	if how_to_play_panel:
		how_to_play_panel.custom_minimum_size = tutorial_size
		how_to_play_panel.size = tutorial_size
		
	if rules_label:
		rules_label.position = Vector2(30, 30)
		rules_label.size = Vector2(640, 680) 
		
	if tutorial_back_button:
		var btn_size = Vector2(140, 50)
		tutorial_back_button.size = btn_size
		var btn_x = (tutorial_size.x - btn_size.x) / 2
		var btn_y = tutorial_size.y - btn_size.y - 30
		tutorial_back_button.position = Vector2(btn_x, btn_y)
		tutorial_back_button.show()

	_connect_signals()

# ==========================================
# HUD STATE CONTROLLER
# ==========================================
func set_hud_buttons_disabled(is_disabled: bool):
	if pause_button:
		pause_button.disabled = is_disabled
	if reset_button:
		reset_button.disabled = is_disabled
	if how_to_play_button:
		how_to_play_button.disabled = is_disabled

# ==========================================
# BUTTON WIRING
# ==========================================
func _connect_signals():
	if pause_button:
		pause_button.pressed.connect(func(): pause_requested.emit())
	if reset_button:
		reset_button.pressed.connect(func(): reset_requested.emit())
	if how_to_play_button:
		how_to_play_button.pressed.connect(func(): how_to_play_requested.emit())
		
	if restart_button:
		restart_button.pressed.connect(_on_victory_button_pressed)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)

	if tutorial_back_button:
		tutorial_back_button.pressed.connect(_on_tutorial_back_pressed)

# ==========================================
# ACTION CALLBACKS
# ==========================================
func _on_tutorial_back_pressed():
	if how_to_play_container:
		how_to_play_container.visible = false
	set_hud_buttons_disabled(false)
	resume_from_tutorial_requested.emit()

func _on_victory_button_pressed():
	if _is_last_level_completed:
		play_again_requested.emit()
	else:
		next_level_requested.emit()

func _on_main_menu_pressed():
	get_tree().paused = false 
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# ==========================================
# DISPLAY UPDATERS (NEW: CUSTOM LABELS)
# ==========================================
func update_timer(formatted_time: String):
	if timer_label: timer_label.text = "Time: " + formatted_time

func display_level(num: int, is_custom: bool = false):
	if level_label: 
		if is_custom:
			level_label.text = "Custom Level %d" % num
		else:
			level_label.text = "Level %d" % num

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
	if how_to_play_container: how_to_play_container.visible = false 
	set_hud_buttons_disabled(false)

func show_how_to_play():
	if how_to_play_container:
		how_to_play_container.visible = true
	set_hud_buttons_disabled(true)

func show_victory(display_num: int, is_last_level: bool, formatted_time: String, is_custom: bool = false):
	_is_last_level_completed = is_last_level
	set_hud_buttons_disabled(true)
	
	if status_label:
		status_label.modulate = Color(1.0, 0.84, 0.0)
		status_label.text = "Puzzle Solved!"
	
	if win_label:
		if is_last_level:
			win_label.text = "All Levels Completed!\nYou Win!" 
		else:
			if is_custom:
				win_label.text = "Custom Level %d Completed!" % display_num
			else:
				win_label.text = "Level %d Completed!" % display_num
		
	if restart_button:
		restart_button.text = "Play Again" if is_last_level else "Next Level"
		
	if time_result_label:
		time_result_label.text = "Completion Time: %s" % formatted_time
		
	if victory_panel:
		victory_panel.visible = true
