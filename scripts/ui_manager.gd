class_name UIManager
extends Node

signal pause_requested
signal reset_requested
signal how_to_play_requested 
signal resume_from_tutorial_requested 
signal next_level_requested  
signal play_again_requested  
signal hint_requested 

# --- NEW SIGNALS FOR UNDO / REDO ---
signal undo_requested
signal redo_requested

@onready var level_label = $"../LevelLabel"
@onready var status_label = $"../StatusLabel"
@onready var pause_button = $"../PauseButton"
@onready var reset_button = $"../ResetButton"
@onready var how_to_play_button = $"../HowToPlayButton" 
@onready var timer_label = $"../TimerLabel"
@onready var move_counter_label = get_node_or_null("../MoveCounterLabel")

@onready var victory_panel = $"../EndLayer/VictoryPanel"
@onready var restart_button = $"../EndLayer/VictoryPanel/RestartButton"
@onready var main_menu_button = $"../EndLayer/VictoryPanel/MainMenuButton"
@onready var time_result_label = $"../EndLayer/VictoryPanel/TimeResultLabel"
@onready var win_label = $"../EndLayer/VictoryPanel/WinLabel"

@onready var defeat_panel = get_node_or_null("../EndLayer/DefeatPanel")
var defeat_restart_button: Button
var defeat_main_menu_button: Button
var defeat_label: Label 

@onready var how_to_play_container = $"../HowToPlayLayer/CenterContainer"
@onready var how_to_play_panel = $"../HowToPlayLayer/CenterContainer/HowToPlayPanel" 
@onready var rules_label = $"../HowToPlayLayer/CenterContainer/HowToPlayPanel/RulesLabel"
@onready var tutorial_back_button = $"../HowToPlayLayer/CenterContainer/HowToPlayPanel/BackButton"

var hint_button: Button 
var undo_button: Button
var redo_button: Button
var joker_counter_label: Label 
var current_hint_count: int = 0

var _is_last_level_completed: bool = false

func setup_ui(_show_debug_tools: bool, cell_size: float):
	
	if pause_button:
		pause_button.text = "Pause"
		pause_button.add_theme_font_size_override("font_size", 24)
		pause_button.global_position = Vector2(160, 40) 
		pause_button.size = Vector2(130, 60)

	if reset_button:
		reset_button.text = "Reset"
		reset_button.add_theme_font_size_override("font_size", 24)
		reset_button.global_position = Vector2(310, 40)
		reset_button.size = Vector2(130, 60)
		
	if how_to_play_button:
		how_to_play_button.text = "Rules" 
		how_to_play_button.add_theme_font_size_override("font_size", 24)
		how_to_play_button.global_position = Vector2(460, 40)
		how_to_play_button.size = Vector2(130, 60) 

	var root_parent = get_parent()
	
	# --- HINT BUTTON ---
	hint_button = root_parent.get_node_or_null("HintButton")
	if not hint_button:
		hint_button = Button.new()
		hint_button.name = "HintButton"
		root_parent.add_child(hint_button)
		
	hint_button.add_theme_font_size_override("font_size", 24)
	hint_button.global_position = Vector2(610, 40) 
	hint_button.size = Vector2(140, 60) 
	
	# --- NEW: UNDO BUTTON ---
	undo_button = root_parent.get_node_or_null("UndoButton")
	if not undo_button:
		undo_button = Button.new()
		undo_button.name = "UndoButton"
		root_parent.add_child(undo_button)
	
	undo_button.text = "⟲ Undo"
	undo_button.add_theme_font_size_override("font_size", 24)
	undo_button.global_position = Vector2(770, 40) 
	undo_button.size = Vector2(130, 60)
	
	# --- NEW: REDO BUTTON ---
	redo_button = root_parent.get_node_or_null("RedoButton")
	if not redo_button:
		redo_button = Button.new()
		redo_button.name = "RedoButton"
		root_parent.add_child(redo_button)
		
	redo_button.text = "Redo ⟳"
	redo_button.add_theme_font_size_override("font_size", 24)
	redo_button.global_position = Vector2(920, 40) 
	redo_button.size = Vector2(130, 60)
	
	if level_label:
		level_label.add_theme_font_size_override("font_size", 28)
		level_label.modulate = Color(1.0, 1.0, 1.0)
		level_label.global_position = Vector2(780, 115) 
		level_label.size = Vector2(280, 50)
		
	if timer_label:
		timer_label.add_theme_font_size_override("font_size", 28)
		timer_label.modulate = Color(0.9, 0.9, 0.9)
		timer_label.global_position = Vector2(120, 115) 
		timer_label.size = Vector2(280, 50) 
		
	joker_counter_label = root_parent.get_node_or_null("JokerCounterLabel")
	if not joker_counter_label:
		joker_counter_label = Label.new()
		joker_counter_label.name = "JokerCounterLabel"
		root_parent.add_child(joker_counter_label)
	joker_counter_label.add_theme_font_size_override("font_size", 28)
	joker_counter_label.modulate = Color(0.4, 1.0, 0.4) 
	joker_counter_label.global_position = Vector2(440, 115)
	joker_counter_label.size = Vector2(280, 50)

	if move_counter_label:
		move_counter_label.add_theme_font_size_override("font_size", 28)
		move_counter_label.modulate = Color(1.0, 0.6, 0.2)
		move_counter_label.global_position = Vector2(760, 115) 
		move_counter_label.size = Vector2(280, 50)

	if status_label:
		status_label.text = "Fill the board following the rules!"
		status_label.modulate = Color(1.0, 1.0, 1.0)
		status_label.add_theme_font_size_override("font_size", 32)
		status_label.global_position.x = 120
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
		
	if defeat_panel:
		defeat_panel.custom_minimum_size = square_panel_size
		defeat_panel.global_position = panel_pos
		defeat_panel.size = square_panel_size
		
		defeat_restart_button = defeat_panel.find_child("RestartButton", true, false)
		if not defeat_restart_button:
			defeat_restart_button = defeat_panel.find_child("TryAgainButton", true, false)
		defeat_main_menu_button = defeat_panel.find_child("MainMenuButton", true, false)
		
		defeat_label = defeat_panel.find_child("DefeatLabel", true, false)
		if not defeat_label:
			defeat_label = defeat_panel.find_child("Label", true, false)
		
		if defeat_restart_button: defeat_restart_button.text = "Try Again"

	if win_label:
		win_label.add_theme_font_size_override("font_size", 32) 
		win_label.modulate = Color(1.0, 0.84, 0.0)
		win_label.size = Vector2(square_panel_size.x, 70) 
		win_label.position = Vector2(0, 20)
		win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER 
		win_label.autowrap_mode = TextServer.AUTOWRAP_WORD 
		
	if defeat_label:
		defeat_label.add_theme_font_size_override("font_size", 32)
		defeat_label.modulate = Color(1.0, 0.3, 0.3) 
		defeat_label.size = Vector2(square_panel_size.x, 70)
		defeat_label.position = Vector2(0, 20)
		defeat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		defeat_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		
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
	if defeat_restart_button:
		defeat_restart_button.add_theme_font_size_override("font_size", 28)
		defeat_restart_button.position = Vector2(button_center_x, v_start_y)
		defeat_restart_button.size = menu_button_size
		
	v_start_y += spacing_y

	if main_menu_button:
		main_menu_button.text = "Main Menu"
		main_menu_button.add_theme_font_size_override("font_size", 28)
		main_menu_button.position = Vector2(button_center_x, v_start_y)
		main_menu_button.size = menu_button_size
	if defeat_main_menu_button:
		defeat_main_menu_button.text = "Main Menu"
		defeat_main_menu_button.add_theme_font_size_override("font_size", 28)
		defeat_main_menu_button.position = Vector2(button_center_x, v_start_y)
		defeat_main_menu_button.size = menu_button_size

	var tutorial_size = Vector2(850, 1200) 
	if how_to_play_panel:
		how_to_play_panel.custom_minimum_size = tutorial_size
		how_to_play_panel.size = tutorial_size
		var solid_style = StyleBoxFlat.new()
		solid_style.bg_color = Color(0.12, 0.12, 0.12, 1.0) 
		how_to_play_panel.add_theme_stylebox_override("panel", solid_style)
		
	if rules_label:
		rules_label.position = Vector2(30, 30)
		rules_label.size = Vector2(790, 1090) 
		
	if tutorial_back_button:
		var btn_size = Vector2(140, 50)
		tutorial_back_button.size = btn_size
		var btn_x = (tutorial_size.x - btn_size.x) / 2
		var btn_y = tutorial_size.y - btn_size.y - 30
		tutorial_back_button.position = Vector2(btn_x, btn_y)
		tutorial_back_button.show()

	_connect_signals()

func update_undo_redo_buttons(can_undo: bool, can_redo: bool):
	if undo_button: undo_button.disabled = not can_undo
	if redo_button: redo_button.disabled = not can_redo

func update_joker_counter(current: int, required: int):
	if joker_counter_label:
		joker_counter_label.text = "%d/%d Jokers used" % [current, required]

func set_joker_counter_visibility(is_visible: bool):
	if joker_counter_label:
		joker_counter_label.visible = is_visible

func set_move_counter_visibility(is_visible: bool):
	if move_counter_label:
		move_counter_label.visible = is_visible

func update_hint_count(count: int):
	current_hint_count = count
	if hint_button:
		hint_button.text = "💡 Hint (" + str(count) + ")"
		hint_button.disabled = (count <= 0)

func update_dynamic_layout(board_y: float, board_height: float):
	if status_label:
		# CORRECTLY ANCHORS ERROR TEXT BELOW THE BOARD
		status_label.global_position.y = board_y + board_height + 40

func set_hud_buttons_disabled(is_disabled: bool):
	if pause_button: pause_button.disabled = is_disabled
	if reset_button: reset_button.disabled = is_disabled
	if how_to_play_button: how_to_play_button.disabled = is_disabled
	if hint_button: hint_button.disabled = is_disabled or (current_hint_count <= 0) 
	if undo_button: undo_button.disabled = is_disabled
	if redo_button: redo_button.disabled = is_disabled

func _connect_signals():
	if pause_button: pause_button.pressed.connect(func(): pause_requested.emit())
	if reset_button: reset_button.pressed.connect(func(): reset_requested.emit())
	if how_to_play_button: how_to_play_button.pressed.connect(func(): how_to_play_requested.emit())
	if hint_button and not hint_button.pressed.is_connected(_on_hint_pressed):
		hint_button.pressed.connect(_on_hint_pressed)
		
	if undo_button and not undo_button.pressed.is_connected(func(): undo_requested.emit()):
		undo_button.pressed.connect(func(): undo_requested.emit())
		
	if redo_button and not redo_button.pressed.is_connected(func(): redo_requested.emit()):
		redo_button.pressed.connect(func(): redo_requested.emit())
		
	if restart_button: restart_button.pressed.connect(_on_victory_button_pressed)
	if main_menu_button: main_menu_button.pressed.connect(_on_main_menu_pressed)
	if tutorial_back_button: tutorial_back_button.pressed.connect(_on_tutorial_back_pressed)
	
	if defeat_restart_button: defeat_restart_button.pressed.connect(func(): reset_requested.emit())
	if defeat_main_menu_button: defeat_main_menu_button.pressed.connect(_on_main_menu_pressed)

func _on_hint_pressed():
	hint_requested.emit()

func _on_tutorial_back_pressed():
	if how_to_play_container: how_to_play_container.visible = false
	set_hud_buttons_disabled(false)
	resume_from_tutorial_requested.emit()

func _on_victory_button_pressed():
	if _is_last_level_completed: play_again_requested.emit()
	else: next_level_requested.emit()

func _on_main_menu_pressed():
	get_tree().paused = false 
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func update_timer(formatted_time: String):
	if timer_label: timer_label.text = "Time left: " + formatted_time

func update_move_counter(moves: int):
	if move_counter_label: move_counter_label.text = "Shifter Moves: %d" % moves

func display_level(num: int, is_custom: bool = false):
	if level_label: 
		level_label.text = ("Custom Level %d" if is_custom else "Level %d") % num

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
	if defeat_panel: defeat_panel.visible = false
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
		if is_last_level: win_label.text = "All Levels Completed!\nYou Win!" 
		else: win_label.text = ("Custom Level %d Completed!" if is_custom else "Level %d Completed!") % display_num
		
	if restart_button: restart_button.text = "Play Again" if is_last_level else "Next Level"
	if time_result_label: time_result_label.text = "Completion Time: %s" % formatted_time
	if victory_panel: victory_panel.visible = true

func show_defeat():
	set_hud_buttons_disabled(true)
	if status_label:
		status_label.modulate = Color(1.0, 0.3, 0.3)
		status_label.text = "Time's up! The puzzle remains unsolved."
	if defeat_panel: defeat_panel.visible = true
