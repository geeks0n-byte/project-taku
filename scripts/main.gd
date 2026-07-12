extends Node2D

@export var show_debug_tools: bool = true 
@export var levels: Array[LevelData] = []

@onready var ui_manager: UIManager = $UIManager
@onready var board_manager: BoardManager = $BoardManager
@onready var timer_node = $Timer

var elapsed_seconds: int = 0
var is_game_active: bool = true
var is_paused: bool = false 
var current_level_index: int = 0

func _ready():
	_load_all_levels_from_storage()
	_intercept_global_selection()
	
	if levels.size() == 0:
		push_error("No level resources found in res://levels/ or assigned via inspector!")
		return

	ui_manager.setup_ui(show_debug_tools, board_manager.CELL_SIZE)
	_bind_submanager_signals()
	
	if timer_node:
		timer_node.timeout.connect(_on_timer_timeout)
		
	generate_board()

func _bind_submanager_signals():
	ui_manager.pause_requested.connect(_on_pause)
	ui_manager.resume_requested.connect(_on_resume)
	ui_manager.reset_requested.connect(_on_reset)
	ui_manager.restart_requested.connect(_on_restart)
	ui_manager.auto_win_requested.connect(_on_auto_win)
	board_manager.cell_changed.connect(_on_cell_changed)

func _load_all_levels_from_storage() -> void:
	levels.clear()
	var levels_dir = "res://levels/"
	if not DirAccess.dir_exists_absolute(levels_dir): return
	var dir = DirAccess.open(levels_dir)
	if dir:
		var raw_paths = []
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.ends_with(".tres"):
					raw_paths.append(levels_dir + file_name)
				elif file_name.ends_with(".tres.remap"):
					raw_paths.append(levels_dir + file_name.replace(".remap", ""))
			file_name = dir.get_next()
		dir.list_dir_end()
		
		raw_paths.sort_custom(func(a, b):
			var num_a = int(a.get_file().get_basename().replace("level_", ""))
			var num_b = int(b.get_file().get_basename().replace("level_", ""))
			return num_a < num_b
		)
		for path in raw_paths:
			var res = load(path)
			if res and res is LevelData: levels.append(res)

func _intercept_global_selection():
	if GlobalGameManager.selected_level_resource != null:
		var custom_level = GlobalGameManager.selected_level_resource
		GlobalGameManager.selected_level_resource = null
		
		var found_index = -1
		for i in range(levels.size()):
			if levels[i].level_number == custom_level.level_number:
				found_index = i
				break
		if found_index != -1:
			current_level_index = found_index
		else:
			levels.append(custom_level)
			current_level_index = levels.size() - 1
	else:
		current_level_index = 0

func generate_board():
	if current_level_index >= levels.size(): return
	ui_manager.set_overlays_hidden()
	
	elapsed_seconds = 0
	is_game_active = true
	is_paused = false
	_update_timer_display()
	if timer_node: timer_node.start()
	
	var current_level_resource = levels[current_level_index]
	ui_manager.display_level(current_level_resource.level_number)
	board_manager.build_grid(current_level_resource.layout)

func _on_cell_changed(_coord: Vector2i):
	if not is_game_active or is_paused: return
		
	board_manager.clear_highlights()
	var results = PuzzleValidator.validate_board(board_manager.board_cells)
	
	if not results["valid"]:
		ui_manager.show_status_errors(results["errors"])
	else:
		ui_manager.show_status_valid()
		
	if results["valid"] and board_manager.is_board_full():
		trigger_victory()

func trigger_victory():
	is_game_active = false
	if timer_node: timer_node.stop()
	
	var is_last = current_level_index >= levels.size() - 1
	var display_num = levels[current_level_index].level_number
	ui_manager.show_victory(display_num, is_last, _get_formatted_time())

func _on_pause():
	if not is_game_active or is_paused: return
	is_paused = true
	if timer_node: timer_node.stop()
	ui_manager.show_pause_menu(true)

func _on_resume():
	if not is_paused: return
	is_paused = false
	if timer_node: timer_node.start()
	ui_manager.show_pause_menu(false)

func _on_reset():
	is_paused = false
	generate_board()

func _on_restart():
	if not is_game_active:
		current_level_index = current_level_index + 1 if current_level_index < levels.size() - 1 else 0
	generate_board()

func _on_auto_win():
	if not is_game_active: return
	is_paused = false
	ui_manager.show_pause_menu(false)
	trigger_victory()

func _on_timer_timeout():
	if is_game_active and not is_paused:
		elapsed_seconds += 1
		_update_timer_display()

func _update_timer_display():
	ui_manager.update_timer(_get_formatted_time())

func _get_formatted_time() -> String:
	return "%02d:%02d" % [int(elapsed_seconds / 60.0), elapsed_seconds % 60]
