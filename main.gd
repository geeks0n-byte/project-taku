extends Node2D

@export var cell_scene: PackedScene = preload("res://cell.tscn")
@onready var grid_container = $GridContainer2D

# Editor Debug Configuration
@export var show_debug_tools: bool = true 

# Main Screen UI References
@onready var level_label = $LevelLabel 
@onready var status_label = $StatusLabel
@onready var pause_button = $PauseButton 
@onready var timer_node = $Timer
@onready var timer_label = $TimerLabel

# Pause Menu UI References (Inside PauseLayer)
@onready var pause_panel = $PauseLayer/PausePanel
@onready var pause_resume_button = $PauseLayer/PausePanel/ResumeButton
@onready var pause_reset_button = $PauseLayer/PausePanel/ResetButton
@onready var pause_main_menu_button = $PauseLayer/PausePanel/MainMenuButton
@onready var pause_auto_win_button = $PauseLayer/PausePanel/AutoWinButton

# Victory Panel UI References (Inside VictoryLayer)
@onready var victory_panel = $VictoryLayer/VictoryPanel
@onready var restart_button = $VictoryLayer/VictoryPanel/RestartButton
@onready var main_menu_button = $VictoryLayer/VictoryPanel/MainMenuButton 
@onready var time_result_label = $VictoryLayer/VictoryPanel/TimeResultLabel
@onready var win_label = $VictoryLayer/VictoryPanel/WinLabel 

const CELL_SIZE = 120 

# State Management Variables
var elapsed_seconds: int = 0
var is_game_active: bool = true
var is_paused: bool = false 

# Level Progression Variables
var current_level_index: int = 0
var levels: Array = []

# Dictionary to hold active cell nodes: { Vector2i(x, y): CellNode }
var board_cells = {}

# Array lists to accumulate feedback messages per frame
var error_messages = []

func _ready():
	setup_levels_data()
	
	# Connect Main Victory Screen Connections
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	
	# Connect Core Pause Menu Triggers
	pause_button.pressed.connect(_on_pause_pressed)
	pause_resume_button.pressed.connect(_on_resume_pressed)
	pause_reset_button.pressed.connect(_on_reset_pressed)
	pause_main_menu_button.pressed.connect(_on_main_menu_pressed)
	
	if pause_auto_win_button:
		pause_auto_win_button.pressed.connect(_on_auto_win_pressed)
		pause_auto_win_button.visible = show_debug_tools
	
	if timer_node:
		timer_node.timeout.connect(_on_timer_timeout)
		
	setup_ui_elements()
	generate_board()

func setup_levels_data():
	# LEVEL 1
	var level_1 = {
		Vector2i(0,0): -1, Vector2i(1,0): -1, Vector2i(2,0): 2,  Vector2i(3,0): -1, Vector2i(4,0): -1, Vector2i(5,0): -1, Vector2i(6,0): -1,
		Vector2i(0,1): -1, Vector2i(1,1): -1, Vector2i(2,1): -1, Vector2i(3,1): -1, Vector2i(4,1): 2,  Vector2i(5,1): -1, Vector2i(6,1): -1,
		Vector2i(0,2): 2,  Vector2i(1,2): -1, Vector2i(2,2): 0,  Vector2i(3,2): -1, Vector2i(4,2): -1, Vector2i(5,2): -1,  Vector2i(6,2): -1,
		Vector2i(0,3): -1, Vector2i(1,3): -1, Vector2i(2,3): -1, Vector2i(3,3): -1, Vector2i(4,3): -1, Vector2i(5,3): -2,  Vector2i(6,3): -1,
		Vector2i(0,4): -1, Vector2i(1,4): -1, Vector2i(2,4): -1, Vector2i(3,4): -2,  Vector2i(4,4): -1, Vector2i(5,4): -1, Vector2i(6,4): -1,
		Vector2i(0,5): 1,  Vector2i(1,5): -1, Vector2i(2,5): -1, Vector2i(3,5): -1, Vector2i(4,5): -1, Vector2i(5,5): 1,  Vector2i(6,5): 2,
		Vector2i(0,6): -1, Vector2i(1,6): 2,  Vector2i(2,6): -1, Vector2i(3,6): 0,  Vector2i(4,6): -1, Vector2i(5,6): -1, Vector2i(6,6): -1,
	}
	
	# LEVEL 2
	var level_2 = {
		Vector2i(0,0): -1, Vector2i(1,0): -1, Vector2i(2,0): -1, Vector2i(3,0): -1, Vector2i(4,0): 1,  Vector2i(5,0): -1, Vector2i(6,0): -1,
		Vector2i(0,1): -1, Vector2i(1,1): -2, Vector2i(2,1): -1, Vector2i(3,1): 2,  Vector2i(4,1): -1, Vector2i(5,1): -1, Vector2i(6,1): -1,
		Vector2i(0,2): 0,  Vector2i(1,2): -1, Vector2i(2,2): -1, Vector2i(3,2): -1, Vector2i(4,2): -1, Vector2i(5,2): 2,  Vector2i(6,2): -1,
		Vector2i(0,3): -1, Vector2i(1,3): -1, Vector2i(2,3): 1,  Vector2i(3,3): -1, Vector2i(4,3): 0,  Vector2i(5,3): -1, Vector2i(6,3): -1,
		Vector2i(0,4): -1, Vector2i(1,4): 2,  Vector2i(2,4): -1, Vector2i(3,4): -1, Vector2i(4,4): -1, Vector2i(5,4): -1, Vector2i(6,4): 0,
		Vector2i(0,5): -1, Vector2i(1,5): -1, Vector2i(2,5): -1, Vector2i(3,5): 0,  Vector2i(4,5): -1, Vector2i(5,5): -2, Vector2i(6,5): -1,
		Vector2i(0,6): -1, Vector2i(1,6): -1, Vector2i(2,6): -1, Vector2i(3,6): -1, Vector2i(4,6): -1, Vector2i(5,6): -1, Vector2i(6,6): 1,
	}
	
	levels = [level_1, level_2]

func _on_pause_pressed():
	if not is_game_active or is_paused: return
	is_paused = true
	if timer_node: timer_node.stop()
	if pause_panel: pause_panel.visible = true

func _on_resume_pressed():
	if not is_paused: return
	is_paused = false
	if timer_node: timer_node.start()
	if pause_panel: pause_panel.visible = false

func _on_reset_pressed():
	is_paused = false
	generate_board()

func _on_restart_pressed():
	if not is_game_active:
		if current_level_index < levels.size() - 1:
			current_level_index += 1
		else:
			current_level_index = 0 
	generate_board()

func _on_main_menu_pressed():
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _on_auto_win_pressed():
	if not is_game_active: return
	is_paused = false
	if pause_panel: 
		pause_panel.visible = false # Explicitly hide pause menu panel cleanly here
	trigger_victory()

func setup_ui_elements():
	if timer_label:
		timer_label.add_theme_font_size_override("font_size", 32)
		timer_label.modulate = Color(0.9, 0.9, 0.9)
		timer_label.position = Vector2(650, 40)
		timer_label.size = Vector2(300, 50)
		
	if pause_button:
		pause_button.text = "Pause"
		pause_button.add_theme_font_size_override("font_size", 28)
		pause_button.position = Vector2(120, 40) 
		pause_button.size = Vector2(180, 60)
		
	if level_label:
		level_label.add_theme_font_size_override("font_size", 36)
		level_label.modulate = Color(1.0, 1.0, 1.0)
		level_label.position = Vector2(120, 120)
		level_label.size = Vector2(400, 50)

	if win_label:
		win_label.add_theme_font_size_override("font_size", 36)
		win_label.modulate = Color(1.0, 0.84, 0.0)

	if restart_button:
		restart_button.add_theme_font_size_override("font_size", 28)

	if main_menu_button:
		main_menu_button.text = "Main Menu"
		main_menu_button.add_theme_font_size_override("font_size", 28)

	if pause_panel:
		pause_panel.custom_minimum_size = Vector2(400, 450)
		pause_panel.size = Vector2(400, 450)
		pause_panel.position = Vector2(340, 300)

	var start_y = 40
	var spacing_y = 90
	var p_button_size = Vector2(300, 60)
	var center_x = (pause_panel.size.x - p_button_size.x) / 2 

	if pause_resume_button:
		pause_resume_button.text = "Resume"
		pause_resume_button.add_theme_font_size_override("font_size", 28)
		pause_resume_button.position = Vector2(center_x, start_y)
		pause_resume_button.size = p_button_size
	start_y += spacing_y

	if pause_reset_button:
		pause_reset_button.text = "Reset"
		pause_reset_button.add_theme_font_size_override("font_size", 28)
		pause_reset_button.position = Vector2(center_x, start_y)
		pause_reset_button.size = p_button_size
	start_y += spacing_y

	if pause_main_menu_button:
		pause_main_menu_button.text = "Main Menu"
		pause_main_menu_button.add_theme_font_size_override("font_size", 28)
		pause_main_menu_button.position = Vector2(center_x, start_y)
		pause_main_menu_button.size = p_button_size
	start_y += spacing_y

	if pause_auto_win_button:
		pause_auto_win_button.text = "DEBUG: Auto-Win"
		pause_auto_win_button.add_theme_font_size_override("font_size", 20)
		pause_auto_win_button.position = Vector2(center_x, start_y)
		pause_auto_win_button.size = p_button_size

func _on_timer_timeout():
	if is_game_active and not is_paused:
		elapsed_seconds += 1
		update_timer_display()

func update_timer_display():
	if timer_label:
		timer_label.text = "Time: %s" % get_formatted_time()

func get_formatted_time() -> String:
	var minutes = int(elapsed_seconds / 60.0)
	var seconds = elapsed_seconds % 60
	return "%02d:%02d" % [minutes, seconds]

func generate_board():
	if victory_panel: victory_panel.visible = false
	if pause_panel: pause_panel.visible = false
	
	elapsed_seconds = 0
	is_game_active = true
	is_paused = false
	update_timer_display()
	if timer_node:
		timer_node.start()
	
	grid_container.position = Vector2(120, 180) 
	
	if level_label:
		level_label.text = "Level %d" % [current_level_index + 1]
	
	if status_label:
		status_label.text = "Fill the board following the rules!"
		status_label.modulate = Color(1.0, 1.0, 1.0)
		status_label.add_theme_font_size_override("font_size", 32)
		status_label.position = Vector2(120, 180 + (7 * CELL_SIZE) + 40)
		status_label.size = Vector2(7 * CELL_SIZE, 160)
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	
	for child in grid_container.get_children():
		child.queue_free()
	board_cells.clear()

	var active_level_data = levels[current_level_index]

	for coord in active_level_data:
		var starting_state = active_level_data[coord]
		
		var cell = cell_scene.instantiate()
		cell.coord = coord
		cell.position = Vector2(float(coord.x * CELL_SIZE), float(coord.y * CELL_SIZE))
		cell.cell_clicked.connect(_on_cell_changed)
		
		cell.state = starting_state
		if starting_state == -2:
			cell.is_playable = false
			cell.is_locked = true
		elif starting_state != -1:
			cell.is_playable = true
			cell.is_locked = true
		else:
			cell.is_playable = true
			cell.is_locked = false
			
		grid_container.add_child(cell)
		board_cells[coord] = cell
		cell.update_visuals()
		
	queue_redraw()

func _on_cell_changed(_coord: Vector2i):
	if not is_game_active or is_paused:
		return
		
	for coord in board_cells:
		board_cells[coord].clear_highlight()
	error_messages.clear()
		
	var all_lines_valid = validate_lines()
	
	if not all_lines_valid:
		status_label.modulate = Color(1.0, 0.3, 0.3)
		status_label.text = "\n".join(error_messages)
	else:
		status_label.modulate = Color(0.4, 1.0, 0.4)
		status_label.text = "Looks good so far! Keep going."
		
	if check_win_condition(all_lines_valid):
		trigger_victory()

func trigger_victory():
	is_game_active = false
	if timer_node:
		timer_node.stop()
		
	status_label.modulate = Color(1.0, 0.84, 0.0)
	status_label.text = "Puzzle Solved!"
	
	if current_level_index < levels.size() - 1:
		if win_label: win_label.text = "Level Completed!"
		restart_button.text = "Next Level"
	else:
		if win_label: win_label.text = "All Puzzles Solved! You Win!"
		restart_button.text = "Play Again"
		
	if time_result_label:
		time_result_label.add_theme_font_size_override("font_size", 28)
		time_result_label.text = "Completion Time: %s" % get_formatted_time()
		
	victory_panel.custom_minimum_size = Vector2(600, 400)
	victory_panel.size = Vector2(600, 400)
	victory_panel.position = Vector2(60, 400)
	victory_panel.visible = true

func check_win_condition(all_lines_valid: bool) -> bool:
	var board_full = true
	for coord in board_cells:
		if board_cells[coord].is_playable and board_cells[coord].state == -1:
			board_full = false
			break
			
	return all_lines_valid and board_full

func validate_lines() -> bool:
	var rows = {}
	var cols = {}
	var syntax_pass = true
	
	for coord in board_cells:
		if coord.y not in rows:
			rows[coord.y] = []
		if coord.x not in cols:
			cols[coord.x] = []
			
		rows[coord.y].append(coord)
		cols[coord.x].append(coord)

	for r in rows:
		if not check_line_validity(rows[r], true, r): 
			syntax_pass = false
			
	for c in cols:
		if not check_line_validity(cols[c], false, c): 
			syntax_pass = false
		
	return syntax_pass

func check_line_validity(coords: Array, is_horizontal: bool, index: int) -> bool:
	coords.sort_custom(func(a, b): return a.x < b.x if is_horizontal else a.y < b.y)
	var line_is_valid = true
	var line_name = "Row " + str(index + 1) if is_horizontal else "Column " + str(index + 1)
	
	var found_consecutive = false
	var virtual_test_states = [0, 1]
	
	for test_val in virtual_test_states:
		for i in range(coords.size() - 2):
			var s1 = board_cells[coords[i]].state
			var s2 = board_cells[coords[i+1]].state
			var s3 = board_cells[coords[i+2]].state
			
			if s1 == -2 or s2 == -2 or s3 == -2:
				continue
				
			if s1 == 2: s1 = test_val
			if s2 == 2: s2 = test_val
			if s3 == 2: s3 = test_val
			
			if s1 == -1 or s2 == -1 or s3 == -1:
				continue
				
			if s1 == s2 and s2 == s3:
				board_cells[coords[i]].highlight_error()
				board_cells[coords[i+1]].highlight_error()
				board_cells[coords[i+2]].highlight_error()
				line_is_valid = false
				found_consecutive = true
					
	if found_consecutive:
		error_messages.append(line_name + " has 3 identical symbols in a row!")

	var zeros = 0
	var ones = 0
	var empty_count = 0
	
	for coord in coords:
		match board_cells[coord].state:
			-1: empty_count += 1
			0: zeros += 1
			1: ones += 1
			
	if empty_count == 0:
		if zeros != ones:
			for coord in coords:
				if board_cells[coord].is_playable:
					board_cells[coord].highlight_error()
			line_is_valid = false
			error_messages.append(line_name + " does not have an equal amount of 0s and 1s!")
		
	return line_is_valid

func _draw():
	var offset = grid_container.position
	var line_color = Color.BLACK
	var line_width = 4.0 
	
	for coord in board_cells:
		var cell = board_cells[coord]
		if cell.is_playable:
			var cell_pos = offset + Vector2(coord.x * CELL_SIZE, coord.y * CELL_SIZE)
			var rect = Rect2(cell_pos, Vector2(CELL_SIZE, CELL_SIZE))
			draw_rect(rect, line_color, false, line_width)
