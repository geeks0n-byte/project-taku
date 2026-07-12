extends Node2D

@export var cell_scene: PackedScene = preload("res://cell.tscn")

# UI Node References matching your Scene Tree hierarchy
@onready var grid_container = $GridContainer2D
@onready var level_spin_box = $EditorUI/ControlPanel/ConfigContainer/LevelSpinBox
@onready var status_label = $EditorUI/ControlPanel/StatusLabel

# Brush Tool Selection Button References
@onready var empty_button = $EditorUI/ControlPanel/BrushContainer/EmptyButton
@onready var wall_button = $EditorUI/ControlPanel/BrushContainer/WallButton
@onready var zero_button = $EditorUI/ControlPanel/BrushContainer/ZeroButton
@onready var one_button = $EditorUI/ControlPanel/BrushContainer/OneButton
@onready var joker_button = $EditorUI/ControlPanel/BrushContainer/JokerButton

# Layout Action Configuration References
@onready var save_button = $EditorUI/ControlPanel/ConfigContainer/SaveButton
@onready var main_menu_button = $EditorUI/ControlPanel/ConfigContainer/MainMenuButton
@onready var test_button = $EditorUI/ControlPanel/ConfigContainer/TestButton
@onready var exit_test_button = $EditorUI/ControlPanel/ConfigContainer/ExitTestButton

# Playtest Overlay References
@onready var brush_container = $EditorUI/ControlPanel/BrushContainer
@onready var playtest_victory_panel = $EditorUI/PlaytestVictoryPanel
@onready var layout_text_edit = $EditorUI/PlaytestVictoryPanel/LayoutTextEdit
@onready var return_button = $EditorUI/PlaytestVictoryPanel/ReturnButton

const CELL_SIZE = 120
const GRID_WIDTH = 7
const GRID_HEIGHT = 7

# Mode Flags and Snapshots
var current_brush_state: int = -1 
var board_cells = {}
var is_playtesting: bool = false
var playtest_snapshot: Dictionary = {}
var error_messages = []

func _ready():
	# Connect brush click signals to inline state modifiers
	empty_button.pressed.connect(func(): _set_brush(-1, "Empty (Clear)"))
	wall_button.pressed.connect(func(): _set_brush(-2, "Wall"))
	zero_button.pressed.connect(func(): _set_brush(0, "Prefilled 0"))
	one_button.pressed.connect(func(): _set_brush(1, "Prefilled 1"))
	joker_button.pressed.connect(func(): _set_brush(2, "Joker"))
	
	# Connect execution routines
	save_button.pressed.connect(_on_save_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	test_button.connect("pressed", _on_test_mode_entered)
	exit_test_button.connect("pressed", _on_test_mode_exited)
	return_button.connect("pressed", _on_test_mode_exited)
	
	setup_editor_ui()
	generate_blank_canvas()

func _set_brush(state_id: int, brush_name: String):
	if is_playtesting: return
	current_brush_state = state_id
	_update_status("Selected Tool: " + brush_name, Color.WHITE)

func setup_editor_ui():
	_set_brush(-1, "Empty (Clear)")
	
	# Dynamically calculate position beneath the 7x7 grid footprint
	var board_bottom_y = 180 + (GRID_HEIGHT * CELL_SIZE) 
	var ui_margin_y = 30
	
	# 1. Expand the main panel to match the full 840px width of your game board
	var panel_width = GRID_WIDTH * CELL_SIZE # 7 * 120 = 840
	$EditorUI/ControlPanel.position = Vector2(120, board_bottom_y + ui_margin_y)
	$EditorUI/ControlPanel.set_deferred("size", Vector2(panel_width, 280))
	
	# 2. Stretch the Brush Container and force buttons to distribute evenly
	brush_container.position = Vector2(20, 30)
	brush_container.set_deferred("size", Vector2(panel_width - 40, 50))
	for btn in brush_container.get_children():
		if btn is Button:
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.add_theme_font_size_override("font_size", 20)
			
	# 3. Stretch the Config Container and force elements to distribute cleanly
	var config_container = $EditorUI/ControlPanel/ConfigContainer
	config_container.position = Vector2(20, 100)
	config_container.set_deferred("size", Vector2(panel_width - 40, 50))
	for child in config_container.get_children():
		if child is Control:
			child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if child is Button or child is Label:
				child.add_theme_font_size_override("font_size", 18)
				
	# 4. Position the Status feedback box at the bottom of the panel
	status_label.position = Vector2(20, 170)
	status_label.set_deferred("size", Vector2(panel_width - 40, 90))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Setup Victory Overlay Panels Hidden on Startup
	playtest_victory_panel.visible = false
	playtest_victory_panel.position = Vector2(120, 250)
	playtest_victory_panel.set_deferred("size", Vector2(500, 450))
	layout_text_edit.set_deferred("custom_minimum_size", Vector2(460, 300))
	layout_text_edit.position = Vector2(20, 20)
	layout_text_edit.editable = false
	return_button.position = Vector2(100, 360)
	return_button.set_deferred("size", Vector2(300, 50))
	
	exit_test_button.visible = false
	
	empty_button.text = "Empty"
	wall_button.text = "Wall (-2)"
	zero_button.text = "Fixed 0"
	one_button.text = "Fixed 1"
	joker_button.text = "Joker (2)"
	save_button.text = "SAVE LEVEL"
	main_menu_button.text = "Main Menu"
	test_button.text = "TEST LEVEL"
	exit_test_button.text = "EXIT TEST"

func generate_blank_canvas():
	for child in grid_container.get_children():
		child.queue_free()
	board_cells.clear()
	
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var coord = Vector2i(x, y)
			var cell = cell_scene.instantiate()
			
			cell.coord = coord
			cell.position = Vector2(float(x * CELL_SIZE), float(y * CELL_SIZE))
			
			cell.state = -1
			cell.is_playable = true
			cell.is_locked = false
			
			grid_container.add_child(cell)
			board_cells[coord] = cell
			cell.update_visuals()
			
			# Input interceptor overlay to bypass structural lock conflicts
			var input_interceptor = Control.new()
			input_interceptor.size = Vector2(CELL_SIZE, CELL_SIZE)
			input_interceptor.position = cell.position
			input_interceptor.mouse_filter = Control.MOUSE_FILTER_STOP 
			
			input_interceptor.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_on_canvas_cell_clicked(coord)
			)
			grid_container.add_child(input_interceptor)
			
	queue_redraw()

func _on_canvas_cell_clicked(coord: Vector2i):
	var cell = board_cells[coord]
	
	if is_playtesting:
		if cell.is_locked: return 
		
		if cell.state == -1: cell.state = 0
		elif cell.state == 0: cell.state = 1
		else: cell.state = -1
		
		cell.update_visuals()
		_run_playtest_validation_pass()
	else:
		cell.state = current_brush_state
		if current_brush_state == -2:
			cell.is_playable = false
			cell.is_locked = true
		elif current_brush_state != -1:
			cell.is_playable = true
			cell.is_locked = true
		else:
			cell.is_playable = true
			cell.is_locked = false
		cell.update_visuals()

func _on_test_mode_entered():
	is_playtesting = true
	playtest_snapshot.clear()
	
	for coord in board_cells:
		playtest_snapshot[coord] = board_cells[coord].state
		
		var s = board_cells[coord].state
		if s == -2:
			board_cells[coord].is_playable = false
			board_cells[coord].is_locked = true
		elif s != -1:
			board_cells[coord].is_playable = true
			board_cells[coord].is_locked = true
		else:
			board_cells[coord].is_playable = true
			board_cells[coord].is_locked = false
		board_cells[coord].update_visuals()
		
	brush_container.visible = false
	save_button.visible = false
	test_button.visible = false
	main_menu_button.visible = false
	level_spin_box.visible = false
	exit_test_button.visible = true
	
	_update_status("PLAYTEST ACTIVE: Click empty tiles to cycle values!", Color.YELLOW)

func _on_test_mode_exited():
	is_playtesting = false
	playtest_victory_panel.visible = false
	
	for coord in board_cells:
		board_cells[coord].clear_highlight()
		var restored_state = playtest_snapshot[coord]
		board_cells[coord].state = restored_state
		
		if restored_state == -2:
			board_cells[coord].is_playable = false
			board_cells[coord].is_locked = true
		elif restored_state != -1:
			board_cells[coord].is_playable = true
			board_cells[coord].is_locked = true
		else:
			board_cells[coord].is_playable = true
			board_cells[coord].is_locked = false
		board_cells[coord].update_visuals()
		
	brush_container.visible = true
	save_button.visible = true
	test_button.visible = true
	main_menu_button.visible = true
	level_spin_box.visible = true
	exit_test_button.visible = false
	
	_set_brush(current_brush_state, "Designer Mode Restored")

func _run_playtest_validation_pass():
	for coord in board_cells:
		board_cells[coord].clear_highlight()
	error_messages.clear()
	
	var pass_syntax = validate_lines()
	
	if not pass_syntax:
		_update_status("\n".join(error_messages), Color(1.0, 0.3, 0.3))
	else:
		_update_status("Puzzle looks perfectly valid so far!", Color(0.4, 1.0, 0.4))
		
	if pass_syntax and check_win_condition(pass_syntax):
		_trigger_playtest_victory()

func _trigger_playtest_victory():
	_update_status("PLAYTEST COMPLETE: Level successfully solved!", Color.GOLD)
	layout_text_edit.text = _compile_dictionary_to_plaintext()
	playtest_victory_panel.visible = true

func _compile_dictionary_to_plaintext() -> String:
	var out = "{\n"
	var keys = playtest_snapshot.keys()
	keys.sort_custom(func(a, b): return a.x < b.x if a.y == b.y else a.y < b.y)
	
	var row_buffer = []
	var current_row = keys[0].y
	
	for key in keys:
		if key.y != current_row:
			out += "\t" + ", ".join(row_buffer) + ",\n"
			row_buffer.clear()
			current_row = key.y
		row_buffer.append("Vector2i(%d,%d): %d" % [key.x, key.y, playtest_snapshot[key]])
		
	if row_buffer.size() > 0:
		out += "\t" + ", ".join(row_buffer) + "\n"
	out += "}"
	return out

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
		if coord.y not in rows: rows[coord.y] = []
		if coord.x not in cols: cols[coord.x] = []
		rows[coord.y].append(coord)
		cols[coord.x].append(coord)

	for r in rows:
		if not check_line_validity(rows[r], true, r): syntax_pass = false
	for c in cols:
		if not check_line_validity(cols[c], false, c): syntax_pass = false
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
			
			if s1 == -2 or s2 == -2 or s3 == -2: continue
			if s1 == 2: s1 = test_val
			if s2 == 2: s2 = test_val
			if s3 == 2: s3 = test_val
			if s1 == -1 or s2 == -1 or s3 == -1: continue
				
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
			
	if empty_count == 0 and zeros != ones:
		for coord in coords:
			if board_cells[coord].is_playable:
				board_cells[coord].highlight_error()
		line_is_valid = false
		error_messages.append(line_name + " does not have an equal amount of 0s and 1s!")
		
	return line_is_valid

func _on_save_pressed():
	if is_playtesting: return
	var level_num = int(level_spin_box.value)
	var output_layout = {}
	
	for coord in board_cells:
		output_layout[coord] = board_cells[coord].state
	
	var new_level_resource = LevelData.new()
	new_level_resource.level_number = level_num
	new_level_resource.layout = output_layout
	
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("levels"):
		dir.make_dir("levels")
		
	var target_save_path = "res://levels/level_%d.tres" % level_num
	var save_result = ResourceSaver.save(new_level_resource, target_save_path)
	
	if save_result == OK:
		_update_status("SUCCESS: Saved level file to: " + target_save_path, Color(0.4, 1.0, 0.4))
	else:
		_update_status("ERROR: Resource save failed: " + error_string(save_result), Color(1.0, 0.3, 0.3))

func _on_main_menu_pressed():
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _update_status(msg: String, text_color: Color):
	status_label.text = msg
	status_label.modulate = text_color
	status_label.add_theme_font_size_override("font_size", 22)

func _draw():
	var offset = grid_container.position
	for coord in board_cells:
		var cell_pos = offset + Vector2(coord.x * CELL_SIZE, coord.y * CELL_SIZE)
		draw_rect(Rect2(cell_pos, Vector2(CELL_SIZE, CELL_SIZE)), Color.BLACK, false, 2.0)
