extends Node2D

@onready var ui_manager: EditorUIManager = $EditorUIManager
@onready var canvas_manager: EditorCanvasManager = $EditorCanvasManager

var current_brush_state: int = -1 
var is_playtesting: bool = false
var playtest_snapshot: Dictionary = {}

func _ready():
	_bind_signals()
	ui_manager.setup_ui(canvas_manager.GRID_WIDTH, canvas_manager.GRID_HEIGHT, canvas_manager.CELL_SIZE)
	canvas_manager.generate_blank_canvas()

func _bind_signals():
	ui_manager.brush_changed.connect(_on_brush_changed)
	ui_manager.save_requested.connect(_on_save_level)
	ui_manager.main_menu_requested.connect(_on_main_menu)
	ui_manager.test_mode_entered.connect(_on_test_mode_entered)
	ui_manager.test_mode_exited.connect(_on_test_mode_exited)
	canvas_manager.canvas_cell_clicked.connect(_on_canvas_cell_clicked)

func _on_brush_changed(state_id: int, brush_name: String):
	if is_playtesting: return
	current_brush_state = state_id
	ui_manager.update_status("Selected Tool: " + brush_name, Color.WHITE)

func _on_canvas_cell_clicked(coord: Vector2i):
	var cell = canvas_manager.board_cells[coord]
	
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
	
	for coord in canvas_manager.board_cells:
		var cell = canvas_manager.board_cells[coord]
		playtest_snapshot[coord] = cell.state
		
		if cell.state == -2:
			cell.is_playable = false
			cell.is_locked = true
		elif cell.state != -1:
			cell.is_playable = true
			cell.is_locked = true
		else:
			cell.is_playable = true
			cell.is_locked = false
		cell.update_visuals()
		
	ui_manager.toggle_playtest_visibility(true)
	ui_manager.update_status("PLAYTEST ACTIVE: Click empty tiles to cycle values!", Color.YELLOW)

func _on_test_mode_exited():
	is_playtesting = false
	ui_manager.hide_victory_overlay()
	
	for coord in canvas_manager.board_cells:
		var cell = canvas_manager.board_cells[coord]
		cell.clear_highlight()
		var restored_state = playtest_snapshot[coord]
		cell.state = restored_state
		
		if restored_state == -2:
			cell.is_playable = false
			cell.is_locked = true
		elif restored_state != -1:
			cell.is_playable = true
			cell.is_locked = true
		else:
			cell.is_playable = true
			cell.is_locked = false
		cell.update_visuals()
		
	ui_manager.toggle_playtest_visibility(false)
	_on_brush_changed(current_brush_state, "Designer Mode Restored")

func _run_playtest_validation_pass():
	canvas_manager.clear_highlights()
	
	var results = PuzzleValidator.validate_board(canvas_manager.board_cells)
	
	if not results["valid"]:
		ui_manager.update_status("\n".join(results["errors"]), Color(1.0, 0.3, 0.3))
	else:
		ui_manager.update_status("Puzzle looks perfectly valid so far!", Color(0.4, 1.0, 0.4))
		
	if results["valid"] and canvas_manager.is_board_full():
		_trigger_playtest_victory()

func _trigger_playtest_victory():
	ui_manager.update_status("PLAYTEST COMPLETE: Level successfully solved!", Color.GOLD)
	var compiled_text = _compile_dictionary_to_plaintext()
	ui_manager.display_victory_overlay(compiled_text)

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

func _on_save_level():
	if is_playtesting: return
	var level_num = ui_manager.get_level_number()
	var output_layout = {}
	
	for coord in canvas_manager.board_cells:
		output_layout[coord] = canvas_manager.board_cells[coord].state
	
	var new_level_resource = LevelData.new()
	new_level_resource.level_number = level_num
	new_level_resource.layout = output_layout
	
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("levels"):
		dir.make_dir("levels")
		
	var target_save_path = "res://levels/level_%d.tres" % level_num
	var save_result = ResourceSaver.save(new_level_resource, target_save_path)
	
	if save_result == OK:
		ui_manager.update_status("SUCCESS: Saved level file to: " + target_save_path, Color(0.4, 1.0, 0.4))
	else:
		ui_manager.update_status("ERROR: Resource save failed: " + error_string(save_result), Color(1.0, 0.3, 0.3))

func _on_main_menu():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
