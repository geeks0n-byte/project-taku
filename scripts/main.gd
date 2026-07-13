extends Node2D

@export var show_debug_tools: bool = true 
@export var levels: Array[LevelData] = []

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

# ==========================================
# GAME STATE VARIABLES
# ==========================================
var elapsed_seconds: int = 0
var is_game_active: bool = true
var is_paused: bool = false 
var current_level_index: int = 0
var levels_dict: Dictionary = {}

# ==========================================
# INITIALIZATION
# ==========================================
func _ready():
	_load_all_levels_from_storage()
	_intercept_global_selection()
	
	if levels.size() == 0:
		push_error("No level resources found in res://levels/ or assigned via inspector!")
		return

	ui_manager.setup_ui(show_debug_tools, board_manager.CELL_SIZE)
	_bind_submanager_signals()
	
	pause_menu.auto_win_button.visible = show_debug_tools
	
	if timer_node:
		timer_node.timeout.connect(_on_timer_timeout)
		
	generate_board()

# ==========================================
# SIGNAL ROUTING
# ==========================================
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
# LEVEL LOADING & DATA MANAGEMENT
# ==========================================
func _load_all_levels_from_storage() -> void:
	levels.clear()
	levels_dict.clear()
	
	var raw_paths = []
	raw_paths.append_array(_scan_directory(DEV_DIR))
	raw_paths.append_array(_scan_directory(CAMPAIGN_DIR))
	
	# Priority Sort: Orders numerically, but ensures user:// drafts always beat res:// 
	raw_paths.sort_custom(func(a, b):
		var num_a = int(a.get_file().get_basename().replace("level_", ""))
		var num_b = int(b.get_file().get_basename().replace("level_", ""))
		if num_a == num_b:
			return a.begins_with("user://") 
		return num_a < num_b
	)
	
	var processed_numbers = {}
	
	for path in raw_paths:
		var res = load(path)
		if res and res is LevelData: 
			# Skips duplicates if the user:// draft was already loaded
			if processed_numbers.has(res.level_number):
				continue
			processed_numbers[res.level_number] = true
			
			levels.append(res)
			levels_dict[res.level_number] = levels.size() - 1

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

func _intercept_global_selection():
	if GlobalGameManager.selected_level_resource != null:
		var custom_level = GlobalGameManager.selected_level_resource
		GlobalGameManager.selected_level_resource = null
		
		if levels_dict.has(custom_level.level_number):
			current_level_index = levels_dict[custom_level.level_number]
		else:
			levels.append(custom_level)
			current_level_index = levels.size() - 1
			levels_dict[custom_level.level_number] = current_level_index
	else:
		var target_level = SaveManager.max_unlocked_level
		if levels_dict.has(target_level):
			current_level_index = levels_dict[target_level]
		else:
			current_level_index = levels.size() - 1
			if current_level_index < 0:
				current_level_index = 0

# ==========================================
# GAMEPLAY LOOP & VALIDATION
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
	ui_manager.display_level(current_level_resource.level_number)
	board_manager.build_grid(current_level_resource.layout)
	
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
	
	var is_last = current_level_index >= levels.size() - 1
	var display_num = levels[current_level_index].level_number
	
	var next_level_to_unlock = display_num + 1
	SaveManager.unlock_level(next_level_to_unlock)
	
	ui_manager.show_victory(display_num, is_last, _get_formatted_time())

# ==========================================
# OVERLAY CONTROLLERS (Pause & Tutorial)
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

# ==========================================
# LEVEL MANAGEMENT CALLBACKS
# ==========================================
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

# ==========================================
# TIMER HELPERS
# ==========================================
func _on_timer_timeout():
	if is_game_active and not is_paused:
		elapsed_seconds += 1
		_update_timer_display()

func _update_timer_display():
	ui_manager.update_timer(_get_formatted_time())

func _get_formatted_time() -> String:
	return "%02d:%02d" % [int(elapsed_seconds / 60.0), elapsed_seconds % 60]
