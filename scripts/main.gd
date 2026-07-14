extends Node2D

@export var show_debug_tools: bool = true 

# We now maintain two separate background tracks to prevent Next Level crossover
var core_levels: Array[LevelData] = []
var custom_levels: Array[LevelData] = []
var levels: Array[LevelData] = [] # The active playlist for the current session

# ==========================================
# CONSTANTS & PATHS
# ==========================================
const CAMPAIGN_DIR = "res://levels/"
const DEV_DIR = "user://levels/"

# ==========================================
# NODE REFERENCES
# ==========================================
@onready var ui_manager: UIManager = $UIManager
@onready var board_manager: BoardManager = $BoardManager
@onready var timer_node = $Timer
@onready var pause_menu: PauseMenu = $PauseMenu  

var elapsed_seconds: int = 0
var is_game_active: bool = true
var is_paused: bool = false 
var current_level_index: int = 0

# ==========================================
# INITIALIZATION
# ==========================================
func _ready():
	_load_all_levels_from_storage()
	_intercept_global_selection()
	
	if levels.size() == 0:
		push_error("No playable level resources found for the selected track!")
		return

	ui_manager.setup_ui(show_debug_tools, board_manager.CELL_SIZE)
	_bind_submanager_signals()
	
	pause_menu.auto_win_button.visible = show_debug_tools
	if timer_node:
		timer_node.timeout.connect(_on_timer_timeout)
		
	generate_board()

func _bind_submanager_signals():
	ui_manager.pause_requested.connect(_on_pause)
	ui_manager.reset_requested.connect(_on_reset)
	ui_manager.how_to_play_requested.connect(_on_how_to_play)
	ui_manager.resume_from_tutorial_requested.connect(_on_resume)
	board_manager.cell_changed.connect(_on_cell_changed)
	pause_menu.resume_pressed.connect(_on_resume)
	pause_menu.restart_pressed.connect(_on_restart_level)
	pause_menu.auto_win_pressed.connect(_on_auto_win)
	pause_menu.quit_pressed.connect(_on_quit_to_menu)
	ui_manager.next_level_requested.connect(_on_next_level)
	ui_manager.play_again_requested.connect(_on_play_again)

# ==========================================
# RECONFIGURED LOADER (DUAL-TRACK & SANITIZED)
# ==========================================
func _load_all_levels_from_storage() -> void:
	core_levels.clear()
	custom_levels.clear()
	levels.clear()
	
	var core_paths = _scan_directory(CAMPAIGN_DIR)
	var custom_paths = _scan_directory(DEV_DIR)
	
	var numeric_sort = func(a, b):
		var num_a = int(a.get_file().get_basename().replace("level_", ""))
		var num_b = int(b.get_file().get_basename().replace("level_", ""))
		return num_a < num_b
		
	core_paths.sort_custom(numeric_sort)
	custom_paths.sort_custom(numeric_sort)
	
	for path in core_paths:
		var res = load(path)
		if res and res is LevelData and not _is_layout_empty(res.layout):
			core_levels.append(res)
			
	for path in custom_paths:
		var res = load(path)
		if res and res is LevelData and not _is_layout_empty(res.layout):
			custom_levels.append(res)

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
# TRACK SELECTION LOGIC
# ==========================================
func _intercept_global_selection():
	if GlobalGameManager.selected_level_resource != null:
		var selected_resource = GlobalGameManager.selected_level_resource
		GlobalGameManager.selected_level_resource = null
		
		if selected_resource.resource_path.begins_with("user://"):
			levels = custom_levels.duplicate()
		else:
			levels = core_levels.duplicate()
		
		var found_idx = -1
		for i in range(levels.size()):
			if levels[i].resource_path == selected_resource.resource_path:
				found_idx = i
				break
				
		if found_idx != -1:
			current_level_index = found_idx
		else:
			levels.append(selected_resource)
			current_level_index = levels.size() - 1
			
	else:
		levels = core_levels.duplicate()
		var target_level = SaveManager.max_unlocked_level
		var found_idx = -1
		
		for i in range(levels.size()):
			if levels[i].level_number == target_level:
				found_idx = i
				break
				
		if found_idx != -1:
			current_level_index = found_idx
		else:
			current_level_index = levels.size() - 1
			if current_level_index < 0: current_level_index = 0

# ==========================================
# GAMEPLAY LOOP
# ==========================================
func generate_board():
	if current_level_index >= levels.size(): return
	ui_manager.set_overlays_hidden()
	
	elapsed_seconds = 0
	is_game_active = true
	is_paused = false
	_update_timer_display()
	if timer_node: timer_node.start()
	
	board_manager.process_mode = Node.PROCESS_MODE_INHERIT
	
	var current_level_resource = levels[current_level_index]
	var is_custom = current_level_resource.resource_path.begins_with("user://")
	
	ui_manager.display_level(current_level_resource.level_number, is_custom)
	board_manager.build_grid(current_level_resource.layout)
	
	# --- FIXED: 1/3 Y-ALIGNMENT ---
	var board_pixel_height = current_level_resource.height * board_manager.CELL_SIZE
	var screen_height = get_viewport_rect().size.y
	
	# Snaps to upper 1/3 of available screen space instead of the direct middle
	var new_board_y = (screen_height - board_pixel_height) / 3.0
	board_manager.global_position.y = new_board_y
	
	ui_manager.update_dynamic_layout(new_board_y, board_pixel_height)
	# ------------------------------
	
	_run_validation_pass()

func _on_cell_changed(_coord: Vector2i):
	if not is_game_active or is_paused: return
	_run_validation_pass()

func _run_validation_pass():
	board_manager.clear_highlights()
	var results = PuzzleValidator.validate_board(board_manager.board_cells, board_manager.cached_lines)
	
	if not results["valid"]:
		ui_manager.show_status_errors(results["errors"])
	else:
		ui_manager.show_status_valid()
		
	if results["valid"] and board_manager.is_board_full():
		trigger_victory()

func trigger_victory():
	is_game_active = false
	if timer_node: timer_node.stop()
	board_manager.process_mode = Node.PROCESS_MODE_DISABLED
	
	var is_custom = levels[current_level_index].resource_path.begins_with("user://")
	var is_last = current_level_index >= levels.size() - 1
	var display_num = levels[current_level_index].level_number
	
	if not is_custom:
		var next_level_to_unlock = display_num + 1
		SaveManager.unlock_level(next_level_to_unlock)
	
	ui_manager.show_victory(display_num, is_last, _get_formatted_time(), is_custom)

# ==========================================
# OVERLAYS & CALLBACKS
# ==========================================
func _on_pause():
	if not is_game_active or is_paused: return
	is_paused = true
	if timer_node: timer_node.stop()
	board_manager.process_mode = Node.PROCESS_MODE_DISABLED
	ui_manager.set_hud_buttons_disabled(true)
	pause_menu.show() 

func _on_how_to_play():
	if not is_game_active or is_paused: return
	is_paused = true
	if timer_node: timer_node.stop()
	board_manager.process_mode = Node.PROCESS_MODE_DISABLED
	if ui_manager.has_method("show_how_to_play"):
		ui_manager.show_how_to_play()

func _on_resume():
	if not is_paused: return
	is_paused = false
	if timer_node: timer_node.start()
	board_manager.process_mode = Node.PROCESS_MODE_INHERIT
	ui_manager.set_hud_buttons_disabled(false)
	pause_menu.hide() 

func _on_reset():
	is_paused = false
	generate_board()

func _on_restart_level():
	is_paused = false
	generate_board()

func _on_next_level():
	if current_level_index < levels.size() - 1:
		current_level_index += 1
	generate_board()

func _on_play_again():
	current_level_index = 0
	generate_board()

func _on_auto_win():
	if not is_game_active: return
	is_paused = false
	pause_menu.hide() 
	trigger_victory()

func _on_quit_to_menu():
	get_tree().paused = false 
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_timer_timeout():
	if is_game_active and not is_paused:
		elapsed_seconds += 1
		_update_timer_display()

func _update_timer_display():
	ui_manager.update_timer(_get_formatted_time())

func _get_formatted_time() -> String:
	return "%02d:%02d" % [int(elapsed_seconds / 60.0), elapsed_seconds % 60]
