extends Node2D

# ==========================================
# CONSTANTS & PATHS
# ==========================================
const CAMPAIGN_DIR = "res://levels/"
const DEV_LEVELS_DIR = "user://levels/"

# ==========================================
# NODE REFERENCES
# ==========================================
@onready var ui_manager: EditorUIManager = $EditorUIManager
@onready var canvas_manager: EditorCanvasManager = $EditorCanvasManager
@onready var core_levels_container = find_child("CoreLevelsContainer", true, false)

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
	
	_recenter_editor_layout(canvas_manager.grid_width, canvas_manager.grid_height)
	_populate_core_levels_container()

# ==========================================
# CALCULATE DYNAMIC EDITOR CENTERING
# ==========================================
func _recenter_editor_layout(width: int, height: int) -> void:
	canvas_manager.generate_blank_canvas(width, height)
	var board_pixel_height = height * canvas_manager.CELL_SIZE
	var screen_height = get_viewport_rect().size.y
	
	var centered_board_y = (screen_height - board_pixel_height) / 3.0
	canvas_manager.global_position.y = centered_board_y
	
	if ui_manager.has_method("update_dynamic_editor_layout"):
		ui_manager.update_dynamic_editor_layout(centered_board_y, board_pixel_height)
	else:
		if ui_manager.has_node("StatusLabel"):
			ui_manager.get_node("StatusLabel").global_position.y = centered_board_y + board_pixel_height + 30

# ==========================================
# DYNAMIC CORE LEVELS UI BUILDER
# ==========================================
func _populate_core_levels_container():
	if not core_levels_container:
		push_warning("CoreLevelsContainer not found in scene tree. Skipping Core Levels bar generation.")
		return
		
	for child in core_levels_container.get_children():
		child.queue_free()
		
	var title_lbl = Label.new()
	title_lbl.text = "CORE LEVELS:"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.modulate = Color(0.4, 1.0, 0.4)
	core_levels_container.add_child(title_lbl)
	
	var raw_paths = _scan_directory(CAMPAIGN_DIR)
	raw_paths.sort_custom(func(a, b):
		var num_a = int(a.get_file().get_basename().replace("level_", ""))
		var num_b = int(b.get_file().get_basename().replace("level_", ""))
		return num_a < num_b
	)
	
	var valid_count = 0
	for path in raw_paths:
		var res = load(path) as LevelData
		if res and not _is_layout_empty(res.layout):
			valid_count += 1
			var btn = Button.new()
			btn.text = str(res.level_number)
			btn.custom_minimum_size = Vector2(70, 70)
			btn.add_theme_font_size_override("font_size", 28)
			btn.pressed.connect(func(): _load_core_level(res))
			core_levels_container.add_child(btn)
			
	if valid_count == 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "No playable core levels found."
		core_levels_container.add_child(empty_lbl)

func _load_core_level(res: LevelData):
	if is_playtesting: return
	canvas_manager.load_layout(res.width, res.height, res.layout)
	_recenter_editor_layout(res.width, res.height)
	
	# NEW: Read available tiles and set checkboxes
	var tiles_list: Array[int] = [0, 1]
	if "available_tiles" in res and res.available_tiles.size() > 0:
		tiles_list = res.available_tiles
	ui_manager.set_allowed_tiles(tiles_list)
	
	ui_manager.sync_size_displays(res.width, res.height)
	ui_manager.update_status("SUCCESS: Loaded CORE Level " + str(res.level_number) + " as a template.", Color(0.4, 1.0, 0.4))

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
	_recenter_editor_layout(new_width, new_height)
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
		
		# FIXED: Playtest clicks now respect your checkbox configuration!
		var allowed = ui_manager.get_allowed_tiles()
		
		if cell.state == -1:
			cell.state = allowed[0] # Jump to first allowed tile
		else:
			var current_idx = allowed.find(cell.state)
			if current_idx == -1 or current_idx == allowed.size() - 1:
				cell.state = -1 # Go back to empty if at the end of the allowed list
			else:
				cell.state = allowed[current_idx + 1] # Cycle to next allowed tile
		
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
	
	if core_levels_container:
		core_levels_container.visible = false 
	
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
	
	if core_levels_container:
		core_levels_container.visible = true 
	
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

func _is_layout_empty(layout: Dictionary) -> bool:
	for coord in layout:
		if layout[coord] != -1:
			return false
	return true

func _scan_directory(path_to_scan: String) -> Array:
	var found_files = []
	if not DirAccess.dir_exists_absolute(path_to_scan):
		return found_files
		
	var dir = DirAccess.open(path_to_scan)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.ends_with(".tres"):
					found_files.append(path_to_scan + file_name)
				elif file_name.ends_with(".tres.remap"):
					found_files.append(path_to_scan + file_name.replace(".remap", ""))
			file_name = dir.get_next()
		dir.list_dir_end()
	return found_files

# ==========================================
# LEVEL SAVING PROCESSOR (CUSTOM ONLY)
# ==========================================
func _on_save_level():
	if is_playtesting: return
	var level_num = ui_manager.get_level_number()
	var dev_path = DEV_LEVELS_DIR + "level_%d.tres" % level_num
	
	if ResourceLoader.exists(dev_path):
		overwrite_dialog.popup_centered()
		return
			
	_execute_save()

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
	
	# NEW: Save the active checkboxes down into the Resource file!
	new_level_resource.available_tiles = ui_manager.get_allowed_tiles()
	
	if not DirAccess.dir_exists_absolute(DEV_LEVELS_DIR):
		DirAccess.make_dir_absolute(DEV_LEVELS_DIR)
		
	var target_save_path = DEV_LEVELS_DIR + "level_%d.tres" % level_num
	var save_result = ResourceSaver.save(new_level_resource, target_save_path)
	
	if save_result == OK:
		ui_manager.update_status("SUCCESS: Saved custom level to: " + target_save_path, Color(0.4, 1.0, 0.4))
	else:
		ui_manager.update_status("ERROR: Resource save failed: " + error_string(save_result), Color(1.0, 0.3, 0.3))

# ==========================================
# LEVEL LOADING PROCESSOR (CUSTOM ONLY)
# ==========================================
func _on_load_level():
	if is_playtesting: return
	var level_num = ui_manager.get_level_number()
	var target_load_path = DEV_LEVELS_DIR + "level_%d.tres" % level_num

	if ResourceLoader.exists(target_load_path):
		var loaded_level = load(target_load_path) as LevelData
		if loaded_level:
			canvas_manager.load_layout(loaded_level.width, loaded_level.height, loaded_level.layout)
			_recenter_editor_layout(loaded_level.width, loaded_level.height)
			
			# NEW: Read available tiles and set checkboxes
			var tiles_list: Array[int] = [0, 1]
			if "available_tiles" in loaded_level and loaded_level.available_tiles.size() > 0:
				tiles_list = loaded_level.available_tiles
			ui_manager.set_allowed_tiles(tiles_list)
			
			ui_manager.sync_size_displays(loaded_level.width, loaded_level.height)
			ui_manager.update_status("SUCCESS: Loaded Custom Level " + str(level_num), Color(0.4, 1.0, 0.4))
		else:
			ui_manager.update_status("ERROR: Failed to parse LevelData resource.", Color(1.0, 0.3, 0.3))
	else:
		ui_manager.update_status("ERROR: No custom data found for Level " + str(level_num), Color(1.0, 0.6, 0.2))

func _on_main_menu():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
