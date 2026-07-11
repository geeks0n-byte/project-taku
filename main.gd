extends Node2D

@export var cell_scene: PackedScene = preload("res://cell.tscn")
@onready var grid_container = $GridContainer2D

# Editor Debug Configuration
@export var show_debug_tools: bool = true 

# Level Progression Array (Drag & drop your .tres level resources here in the Inspector!)
@export var levels: Array[LevelData] = []

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
@onready var pause_how_to_play_button = $PauseLayer/PausePanel/HowToPlayButton

# How To Play UI References (Inside HowToPlayLayer)
@onready var how_to_play_panel = $HowToPlayLayer/HowToPlayPanel
@onready var how_to_play_label = $HowToPlayLayer/HowToPlayPanel/HowToPlayLabel
@onready var how_to_play_back_button = $HowToPlayLayer/HowToPlayPanel/BackButton

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
var current_level_index: int = 0

# Dictionary to hold active cell nodes: { Vector2i(x, y): CellNode }
var board_cells = {}
var error_messages = []

func _ready():
	# 1. Check if a level resource was passed globally from the Level Select grid menu
	if GlobalGameManager.selected_level_resource != null:
		var custom_level = GlobalGameManager.selected_level_resource
		print("Gameplay Engine: Intercepted level selection resource for Level ", custom_level.level_number)
		
		# Immediately clear the global courier reference to maintain clean transitions
		GlobalGameManager.selected_level_resource = null
		
		# Synchronize the selection with your campaign array index if it exists there
		var found_index = -1
		for i in range(levels.size()):
			if levels[i].level_number == custom_level.level_number:
				found_index = i
				break
				
		if found_index != -1:
			current_level_index = found_index
		else:
			# If a completely loose custom file was loaded, append it so things don't crash
			levels.append(custom_level)
			current_level_index = levels.size() - 1

	# Verification step to ensure maps are assigned safely before game loops start
	if levels.size() == 0:
		push_error("No level resources assigned to the Level manager array inside the Main Inspector panel!")
		return
		
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	
	pause_button.pressed.connect(_on_pause_pressed)
	pause_resume_button.pressed.connect(_on_resume_pressed)
	pause_reset_button.pressed.connect(_on_reset_pressed)
	pause_main_menu_button.pressed.connect(_on_main_menu_pressed)
	pause_how_to_play_button.pressed.connect(_on_how_to_play_pressed)
	how_to_play_back_button.pressed.connect(_on_how_to_play_back_pressed)
	
	if pause_auto_win_button:
		pause_auto_win_button.pressed.connect(_on_auto_win_pressed)
		pause_auto_win_button.visible = show_debug_tools
	
	if timer_node:
		timer_node.timeout.connect(_on_timer_timeout)
		
	setup_ui_elements()
	generate_board()

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

func _on_how_to_play_pressed():
	if pause_panel: pause_panel.visible = false
	if how_to_play_panel: how_to_play_panel.visible = true

func _on_how_to_play_back_pressed():
	if how_to_play_panel: how_to_play_panel.visible = false
	if pause_panel: pause_panel.visible = true

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
		pause_panel.visible = false 
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
		level_label.add_theme_font_size_override("font_size", 32)
		level_label.modulate = Color(1.0, 1.0, 1.0)
		level_label.position = Vector2(120, 120)
		level_label.size = Vector2(400, 50)

	var panel_size = Vector2(400, 500)
	var square_panel_size = Vector2(400, 450)
	var panel_pos = Vector2(340, 300)
	var menu_button_size = Vector2(300, 60)
	var button_center_x = (panel_size.x - menu_button_size.x) / 2 
	var spacing_y = 80 

	if pause_panel:
		pause_panel.custom_minimum_size = panel_size
		pause_panel.position = panel_pos
		pause_panel.set_deferred("size", panel_size)

	var p_start_y = 35

	if pause_resume_button:
		pause_resume_button.text = "Resume"
		pause_resume_button.add_theme_font_size_override("font_size", 28)
		pause_resume_button.position = Vector2(button_center_x, p_start_y)
		pause_resume_button.size = menu_button_size
	p_start_y += spacing_y

	if pause_reset_button:
		pause_reset_button.text = "Reset"
		pause_reset_button.add_theme_font_size_override("font_size", 28)
		pause_reset_button.position = Vector2(button_center_x, p_start_y)
		pause_reset_button.size = menu_button_size
	p_start_y += spacing_y

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
		how_to_play_panel.position = panel_pos
		how_to_play_panel.set_deferred("size", panel_size)

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
		victory_panel.position = panel_pos 
		victory_panel.set_deferred("size", square_panel_size)

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
	if current_level_index >= levels.size(): return
	if victory_panel: victory_panel.visible = false
	if pause_panel: pause_panel.visible = false
	if how_to_play_panel: how_to_play_panel.visible = false
	
	elapsed_seconds = 0
	is_game_active = true
	is_paused = false
	update_timer_display()
	if timer_node:
		timer_node.start()
	
	grid_container.position = Vector2(120, 180) 
	
	var current_level_resource = levels[current_level_index]
	var active_level_data = current_level_resource.layout
	var display_num = current_level_resource.level_number
	
	if level_label:
		level_label.text = "Level %d" % display_num
	
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
	
	var display_num = levels[current_level_index].level_number
	
	if current_level_index < levels.size() - 1:
		if win_label: win_label.text = "Level %d Completed!" % display_num
		restart_button.text = "Next Level"
	else:
		if win_label: win_label.text = "All Levels Completed!\nYou Win!"
		restart_button.text = "Play Again"
		
	if time_result_label:
		time_result_label.text = "Completion Time: %s" % get_formatted_time()
		
	if victory_panel:
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
