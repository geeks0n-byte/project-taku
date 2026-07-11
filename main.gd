extends Node2D

@export var cell_scene: PackedScene = preload("res://cell.tscn")
@onready var grid_container = $GridContainer2D

# UI Node References
@onready var victory_panel = $VictoryLayer/VictoryPanel
@onready var restart_button = $VictoryLayer/VictoryPanel/RestartButton
@onready var time_result_label = $VictoryLayer/VictoryPanel/TimeResultLabel
@onready var status_label = $StatusLabel

# New UI & Timer System References
@onready var reset_button = $ResetButton
@onready var timer_node = $Timer
@onready var timer_label = $TimerLabel

const CELL_SIZE = 120 

# Time Tracking Variables
var elapsed_seconds: int = 0
var is_game_active: bool = true

# Dictionary to hold active cell nodes: { Vector2i(x, y): CellNode }
var board_cells = {}

# Array lists to accumulate feedback messages per frame
var error_messages = []

# Updated board layout with custom blank (b) configuration
var level_7x7_data = {
	# Row 0: bb2bbbb
	Vector2i(0,0): -1, Vector2i(1,0): -1, Vector2i(2,0): 2,  Vector2i(3,0): -1, Vector2i(4,0): -1, Vector2i(5,0): -1, Vector2i(6,0): -1,
	# Row 1: bbbb2bb
	Vector2i(0,1): -1, Vector2i(1,1): -1, Vector2i(2,1): -1, Vector2i(3,1): -1, Vector2i(4,1): 2,  Vector2i(5,1): -1, Vector2i(6,1): -1,
	# Row 2: 2b1bb0b
	Vector2i(0,2): 2,  Vector2i(1,2): -1, Vector2i(2,2): 0,  Vector2i(3,2): -1, Vector2i(4,2): -1, Vector2i(5,2): -1,  Vector2i(6,2): -1,
	# Row 3: bbbbb2b
	Vector2i(0,3): -1, Vector2i(1,3): -1, Vector2i(2,3): -1, Vector2i(3,3): -1, Vector2i(4,3): -1, Vector2i(5,3): 2,  Vector2i(6,3): -1,
	# Row 4: bbb2bbb
	Vector2i(0,4): -1, Vector2i(1,4): -1, Vector2i(2,4): -1, Vector2i(3,4): 2,  Vector2i(4,4): -1, Vector2i(5,4): -1, Vector2i(6,4): -1,
	# Row 5: 1bbbb12
	Vector2i(0,5): 1,  Vector2i(1,5): -1, Vector2i(2,5): -1, Vector2i(3,5): -1, Vector2i(4,5): -1, Vector2i(5,5): 1,  Vector2i(6,5): 2,
	# Row 6: b2b0bbb
	Vector2i(0,6): -1, Vector2i(1,6): 2,  Vector2i(2,6): -1, Vector2i(3,6): 0,  Vector2i(4,6): -1, Vector2i(5,6): -1, Vector2i(6,6): -1,
}

func _ready():
	restart_button.pressed.connect(_on_restart_pressed)
	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)
	
	if timer_node:
		timer_node.timeout.connect(_on_timer_timeout)
		
	setup_timer_ui()
	generate_board()

func _on_restart_pressed():
	generate_board()

func _on_reset_pressed():
	generate_board()

func setup_timer_ui():
	if timer_label:
		timer_label.add_theme_font_size_override("font_size", 32)
		timer_label.modulate = Color(0.9, 0.9, 0.9)
		timer_label.position = Vector2(650, 40)
		timer_label.size = Vector2(300, 50)
		
	if reset_button:
		reset_button.add_theme_font_size_override("font_size", 28)
		reset_button.position = Vector2(120, 40)
		reset_button.size = Vector2(180, 60)

func _on_timer_timeout():
	if is_game_active:
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
	victory_panel.visible = false
	
	elapsed_seconds = 0
	is_game_active = true
	update_timer_display()
	if timer_node:
		timer_node.start()
	
	grid_container.position = Vector2(120, 180) 
	
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

	for coord in level_7x7_data:
		var starting_state = level_7x7_data[coord]
		
		var cell = cell_scene.instantiate()
		cell.coord = coord
		cell.position = Vector2(float(coord.x * CELL_SIZE), float(coord.y * CELL_SIZE))
		cell.cell_clicked.connect(_on_cell_changed)
		
		if starting_state != -1:
			cell.state = starting_state
			cell.is_locked = true
		else:
			cell.state = -1
			cell.is_locked = false
			
		grid_container.add_child(cell)
		board_cells[coord] = cell
		cell.update_visuals()

func _on_cell_changed(_coord: Vector2i):
	if not is_game_active:
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
		is_game_active = false
		if timer_node:
			timer_node.stop()
			
		status_label.modulate = Color(1.0, 0.84, 0.0)
		status_label.text = "Puzzle Solved!"
		
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
		if board_cells[coord].state == -1:
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
	
	# Rule A: Check 3 consecutive identical symbols (Chameleon Wildcards)
	var found_consecutive = false
	var virtual_test_states = [0, 1]
	
	for test_val in virtual_test_states:
		for i in range(coords.size() - 2):
			var s1 = board_cells[coords[i]].state
			var s2 = board_cells[coords[i+1]].state
			var s3 = board_cells[coords[i+2]].state
			
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

	# Rule B: Check balanced proportions (ignoring wildcards completely)
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
				board_cells[coord].highlight_error()
			line_is_valid = false
			error_messages.append(line_name + " does not have an equal amount of 0s and 1s!")
		
	return line_is_valid
