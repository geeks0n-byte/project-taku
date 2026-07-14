extends Node2D

# ==========================================
# CONSTANTS & PATHS
# ==========================================
# Saves mobile design drafts to the writeable sandboxed user directory.
const DEV_LEVELS_DIR = "user://levels/"

# ==========================================
# NODE REFERENCES
# ==========================================
@onready var ui_manager: EditorUIManager = $EditorUIManager
@onready var canvas_manager: EditorCanvasManager = $EditorCanvasManager

# ==========================================
# STATE VARIABLES
# ==========================================
var current_brush_state: int = -1 
var is_playtesting: bool = false
var playtest_snapshot: Dictionary = {}

var overwrite_dialog: ConfirmationDialog

# ==========================================
# INITIALIZATION
# ==========================================
func _ready():
	_bind_signals()
	
	overwrite_dialog = ConfirmationDialog.new()
	overwrite_dialog.title = "Overwrite Level?"
	overwrite_dialog.dialog_text = "You already have a custom draft for this level. Overwrite it?"
	overwrite_dialog.confirmed.connect(_execute_save)
	add_child(overwrite_dialog)
	
	ui_manager.setup_ui(canvas_manager.grid_width, canvas_manager.grid_height, canvas_manager.CELL_SIZE)
	canvas_manager.generate_blank_canvas(canvas_manager.grid_width, canvas_manager.grid_height)

# ==========================================
# SIGNAL BINDINGS
# ==========================================
func _bind_signals():
	ui_manager.brush_changed.connect(_on_brush_changed)
	ui_manager.save_requested.connect(_on_save_level)
	ui_manager.load_requested.connect(_on_load_level) 
	ui_manager.clear_requested.connect(_on_clear_board) 
	ui_manager.main_menu_requested.connect(_on_main_menu)
	ui_manager.test_mode_entered.connect(_on_test_mode_entered)
	ui_manager.test_mode_exited.connect(_on_test_mode_exited)
	ui_manager.grid_size_changed.connect(_on_grid_size_changed) 
	canvas_manager.canvas_cell_clicked.connect(_on_canvas_cell_clicked)

# ==========================================
# GRID & BRUSH CONTROLS
# ==========================================
func _on_grid_size_changed(new_width: int, new_height: int):
	if is_playtesting: return
	canvas_manager.generate_blank_canvas(new_width, new_height)
	ui_manager.update_status("Grid resized to %d x %d" % [new_width, new_height], Color.WHITE)

func _on_brush_changed(state_id: int, brush_name: String):
	if is_playtesting: return
	current_brush_state = state_id
	ui_manager.update_status("Selected Tool: " + brush_name, Color.WHITE)

# ==========================================
# BOARD INTERACTION (DRAW / PLAYTEST)
# ==========================================
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

# ==========================================
# PLAYTEST SYSTEMS
# ==========================================
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
	
	var results = PuzzleValidator.validate_board(canvas_manager.board_cells, canvas_manager.cached_lines)
	
	if not results["valid"]:
		ui_manager.update_status("\n".join(results["errors"]), Color(1.0, 0.3, 0.3))
	else:
		ui_manager.update_status("Puzzle looks perfectly valid so far!", Color(0.4, 1.0, 0.4))
		
	if results["valid"] and canvas_manager.is_board_full():
		_trigger_playtest_victory()

# ==========================================
# VICTORY OVERLAY LOADER
# ==========================================
func _trigger_playtest_victory():
	ui_manager.update_status("PLAYTEST COMPLETE: Level successfully solved!", Color.GOLD)
	ui_manager.display_victory_overlay("GOOD JOB!\nLEVEL IS SOLVABLE")

# ==========================================
# UTILITY ACTIONS
# ==========================================
func _on_clear_board():
	if is_playtesting: return
	
	for coord in canvas_manager.board_cells:
		var cell = canvas_manager.board_cells[coord]
		cell.state = -1
		cell.is_playable = true
		cell.is_locked = false
		cell.update_visuals()
		
	ui_manager.update_status("Board cleared!", Color.WHITE)

# ==========================================
# STRICT LEVEL SAVING PROCESSOR
# ==========================================
func _on_save_level():
	if is_playtesting: return
	var level_num = ui_manager.get_level_number()
	
	var dev_path = DEV_LEVELS_DIR + "level_%d.tres" % level_num
	var official_path = "res://levels/level_%d.tres" % level_num
	
	# PROTECTION: Check if an official level already exists and is NOT a blank canvas
	if ResourceLoader.exists(official_path):
		var official_level = load(official_path) as LevelData
		if official_level and not _is_layout_empty(official_level.layout):
			ui_manager.update_status("ERROR: Cannot override a completed official level! Clear the board first.", Color(1.0, 0.3, 0.3))
			return
			
	# If it's a blank template, or no official level exists, check if a custom draft exists
	if ResourceLoader.exists(dev_path):
		overwrite_dialog.popup_centered()
		return
			
	_execute_save()

func _is_layout_empty(layout: Dictionary) -> bool:
	for coord in layout:
		if layout[coord] != -1:
			return false
	return true

func _execute_save():
	var level_num = ui_manager.get_level_number()
	var output_layout = {}
	
	for coord in canvas_manager.board_cells:
		output_layout[coord] = canvas_manager.board_cells[coord].state
	
	var new_level_resource = LevelData.new()
	new_level_resource.level_number = level_num
	new_level_resource.width = canvas_manager.grid_width
	new_level_resource.height = canvas_manager.grid_height
	new_level_resource.layout = output_layout
	
	if not DirAccess.dir_exists_absolute(DEV_LEVELS_DIR):
		DirAccess.make_dir_absolute(DEV_LEVELS_DIR)
		
	var target_save_path = DEV_LEVELS_DIR + "level_%d.tres" % level_num
	var save_result = ResourceSaver.save(new_level_resource, target_save_path)
	
	if save_result == OK:
		ui_manager.update_status("SUCCESS: Saved custom level to: " + target_save_path, Color(0.4, 1.0, 0.4))
	else:
		ui_manager.update_status("ERROR: Resource save failed: " + error_string(save_result), Color(1.0, 0.3, 0.3))

# ==========================================
# LEVEL LOADING PROCESSOR
# ==========================================
func _on_load_level():
	if is_playtesting: return
	var level_num = ui_manager.get_level_number()
	
	var dev_path = DEV_LEVELS_DIR + "level_%d.tres" % level_num
	var official_path = "res://levels/level_%d.tres" % level_num
	
	var target_load_path = ""
	if ResourceLoader.exists(dev_path):
		target_load_path = dev_path
	elif ResourceLoader.exists(official_path):
		target_load_path = official_path

	if target_load_path != "":
		var loaded_level = load(target_load_path) as LevelData
		if loaded_level:
			canvas_manager.load_layout(loaded_level.width, loaded_level.height, loaded_level.layout)
			ui_manager.sync_size_displays(loaded_level.width, loaded_level.height)
			ui_manager.update_status("SUCCESS: Loaded level " + str(level_num), Color(0.4, 1.0, 0.4))
		else:
			ui_manager.update_status("ERROR: Failed to parse LevelData resource.", Color(1.0, 0.3, 0.3))
	else:
		ui_manager.update_status("ERROR: No saved data found for Level " + str(level_num), Color(1.0, 0.6, 0.2))

func _on_main_menu():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
