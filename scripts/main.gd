extends Node2D

@export var show_debug_tools: bool = true 

var core_levels: Array[LevelData] = []
var custom_levels: Array[LevelData] = []
var levels: Array[LevelData] = [] 

const CAMPAIGN_DIR = "res://levels/"
const DEV_DIR = "user://levels/"

@onready var ui_manager: UIManager = $UIManager
@onready var board_manager: BoardManager = $BoardManager
@onready var timer_node = $Timer
@onready var pause_menu: PauseMenu = $%PauseMenu  

var starting_time_limit: int = 120 
var time_remaining: int = 120
var shifter_move_count: int = 0
var is_game_active: bool = true
var is_paused: bool = false 
var current_level_index: int = 0

var pending_hints: Array = [] 
var solved_solution_reference: Dictionary = {}

var required_jokers: int = 0 

var undo_stack: Array = []
var redo_stack: Array = []
var current_game_state: Dictionary = {}
var _is_recording_action: bool = false

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
	ui_manager.hint_requested.connect(_on_hint_requested) 
	
	if ui_manager.has_signal("undo_requested"):
		ui_manager.undo_requested.connect(_on_undo_requested)
	if ui_manager.has_signal("redo_requested"):
		ui_manager.redo_requested.connect(_on_redo_requested)
	
	board_manager.cell_changed.connect(_on_cell_changed)
	board_manager.shifter_move_made.connect(_on_shifter_move_made)
	board_manager.invalid_move_attempted.connect(_on_invalid_move_attempted)
	
	pause_menu.resume_pressed.connect(_on_resume)
	pause_menu.restart_pressed.connect(_on_restart_level)
	pause_menu.auto_win_pressed.connect(_on_auto_win)
	pause_menu.quit_pressed.connect(_on_quit_to_menu)
	ui_manager.next_level_requested.connect(_on_next_level)
	ui_manager.play_again_requested.connect(_on_play_again)

func _on_invalid_move_attempted(msg: String):
	if not is_game_active or is_paused: return
	ui_manager.show_status_errors([msg])

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

func generate_board():
	if current_level_index >= levels.size(): return
	ui_manager.set_overlays_hidden()
	
	is_game_active = true
	is_paused = false
	
	var current_level_resource = levels[current_level_index]
	var is_custom = current_level_resource.resource_path.begins_with("user://")
	
	var actual_w = 6
	var actual_h = 6
	if current_level_resource.layout.size() > 0:
		var max_x = 0
		var max_y = 0
		for coord in current_level_resource.layout.keys():
			if coord.x > max_x: max_x = coord.x
			if coord.y > max_y: max_y = coord.y
		actual_w = max_x + 1
		actual_h = max_y + 1
	else:
		if "width" in current_level_resource: actual_w = current_level_resource.width
		if "height" in current_level_resource: actual_h = current_level_resource.height
	
	starting_time_limit = current_level_resource.get("time_limit") if "time_limit" in current_level_resource else 120
	time_remaining = starting_time_limit
	shifter_move_count = 0
	
	ui_manager.update_move_counter(shifter_move_count)
	_update_timer_display()
	if timer_node: timer_node.start()
	
	board_manager.process_mode = Node.PROCESS_MODE_INHERIT
	
	var tiles_list: Array = [0, 1, 2] 
	if "available_tiles" in current_level_resource and current_level_resource.available_tiles.size() > 0:
		tiles_list = current_level_resource.available_tiles
		
	var s_pairs: Array = []
	if "shifter_pairs" in current_level_resource:
		s_pairs = current_level_resource.shifter_pairs
	elif "red_pairs" in current_level_resource:
		s_pairs = current_level_resource.red_pairs
		
	ui_manager.set_move_counter_visibility(s_pairs.size() > 0)
	
	var prefilled_jokers = 0
	for coord in current_level_resource.layout:
		if current_level_resource.layout[coord] == 2:
			prefilled_jokers += 1
			
	var saved_req_jokers = current_level_resource.get("required_jokers") if "required_jokers" in current_level_resource else -1
	
	if saved_req_jokers == -1:
		required_jokers = min(actual_w, actual_h)
	else:
		required_jokers = saved_req_jokers
		
	required_jokers = max(0, required_jokers - prefilled_jokers)
	
	var has_jokers = (required_jokers > 0)
	ui_manager.set_joker_counter_visibility(has_jokers)
		
	var c_pairs: Array = []
	if "constraint_pairs" in current_level_resource:
		c_pairs = current_level_resource.constraint_pairs.duplicate()
		
	solved_solution_reference = current_level_resource.layout.duplicate()
	
	pending_hints = c_pairs.duplicate()
	pending_hints.shuffle()
	
	ui_manager.display_level(current_level_resource.level_number, is_custom)
	board_manager.build_grid(current_level_resource.layout, tiles_list, s_pairs, [])
	
	_update_joker_count()
	
	var board_pixel_height = actual_h * board_manager.CELL_SIZE
	var screen_height = get_viewport_rect().size.y
	var centered_board_y = 0.0
	
	var top_hud_bottom = 195.0
	var fixed_gap = 40.0
	
	if actual_h <= 7:
		centered_board_y = (screen_height / 3.0) - (board_pixel_height / 2.0)
		if centered_board_y < (top_hud_bottom + fixed_gap):
			centered_board_y = top_hud_bottom + fixed_gap
	else:
		centered_board_y = top_hud_bottom + fixed_gap
	
	board_manager.position.y = centered_board_y 
	ui_manager.update_dynamic_layout(centered_board_y, board_pixel_height)
	
	undo_stack.clear()
	redo_stack.clear()
	current_game_state = _create_game_snapshot()
	
	_run_validation_pass()

func _create_game_snapshot() -> Dictionary:
	var snap = {}
	for coord in board_manager.board_cells:
		var cell = board_manager.board_cells[coord]
		snap[coord] = {
			"state": cell.state,
			"shifter_direction": cell.shifter_direction
		}
	return {
		"cells": snap,
		"moves": shifter_move_count
	}

func _apply_game_snapshot(snap: Dictionary):
	shifter_move_count = snap["moves"]
	ui_manager.update_move_counter(shifter_move_count)
	
	var cells = snap["cells"]
	for coord in cells:
		var cell = board_manager.board_cells[coord]
		cell.state = cells[coord]["state"]
		cell.shifter_direction = cells[coord]["shifter_direction"]
		cell.update_visuals()
		
	_update_joker_count()
	if board_manager.has_method("trigger_redraw"):
		board_manager.trigger_redraw()
	_run_validation_pass()

func _record_game_action():
	_is_recording_action = false
	var new_state = _create_game_snapshot()
	undo_stack.append(current_game_state)
	redo_stack.clear()
	current_game_state = new_state
	ui_manager.update_undo_redo_buttons(undo_stack.size() > 0, false)

func _on_undo_requested():
	if not is_game_active or is_paused or undo_stack.is_empty(): return
	redo_stack.append(current_game_state)
	var prev_state = undo_stack.pop_back()
	_apply_game_snapshot(prev_state)
	current_game_state = prev_state
	ui_manager.update_undo_redo_buttons(undo_stack.size() > 0, redo_stack.size() > 0)

func _on_redo_requested():
	if not is_game_active or is_paused or redo_stack.is_empty(): return
	undo_stack.append(current_game_state)
	var next_state = redo_stack.pop_back()
	_apply_game_snapshot(next_state)
	current_game_state = next_state
	ui_manager.update_undo_redo_buttons(undo_stack.size() > 0, redo_stack.size() > 0)

func _update_joker_count():
	var current_jokers = 0
	for coord in board_manager.board_cells:
		if board_manager.board_cells[coord].state == 2 and not board_manager.board_cells[coord].is_locked:
			current_jokers += 1
	ui_manager.update_joker_counter(current_jokers, required_jokers)

func _get_usable_hints_count() -> int:
	var count = 0
	for candidate in pending_hints:
		var coord_a = candidate["a"]
		var coord_b = candidate["b"]
		var type = candidate["type"]
		
		var overlap = false
		for active in board_manager.active_constraint_pairs:
			if active["a"] == coord_a or active["b"] == coord_a or active["a"] == coord_b or active["b"] == coord_b:
				overlap = true; break
		if overlap: continue
		
		var current_a = board_manager.board_cells[coord_a].state if board_manager.board_cells.has(coord_a) else -1
		var current_b = board_manager.board_cells[coord_b].state if board_manager.board_cells.has(coord_b) else -1
		
		if current_a != -1 and current_b != -1:
			if type == "equals" and current_a == current_b: continue
			if type == "not_equals" and current_a != current_b: continue
			
		count += 1
	return count

func _on_hint_requested():
	if not is_game_active or is_paused: return
	
	var selected_hint = null
	var skipped_hints = []
	
	while pending_hints.size() > 0:
		var candidate = pending_hints.pop_back()
		var coord_a = candidate["a"]
		var coord_b = candidate["b"]
		var type = candidate["type"]
		
		var cell_already_has_hint = false
		for active_hint in board_manager.active_constraint_pairs:
			if active_hint["a"] == coord_a or active_hint["b"] == coord_a or active_hint["a"] == coord_b or active_hint["b"] == coord_b:
				cell_already_has_hint = true
				break
				
		if cell_already_has_hint:
			skipped_hints.append(candidate)
			continue
		
		var current_a = board_manager.board_cells[coord_a].state if board_manager.board_cells.has(coord_a) else -1
		var current_b = board_manager.board_cells[coord_b].state if board_manager.board_cells.has(coord_b) else -1
		
		var is_satisfied = false
		if current_a != -1 and current_b != -1:
			if type == "equals" and current_a == current_b:
				is_satisfied = true
			elif type == "not_equals" and current_a != current_b:
				is_satisfied = true
				
		if is_satisfied:
			skipped_hints.append(candidate) 
			continue
			
		selected_hint = candidate
		break
		
	pending_hints.append_array(skipped_hints)
	pending_hints.shuffle()
	
	if selected_hint != null:
		board_manager.active_constraint_pairs.append(selected_hint)
		board_manager.trigger_redraw()
		_run_validation_pass()

func _on_cell_changed(_coord: Vector2i):
	if not is_game_active or is_paused: return
	_update_joker_count() 
	_run_validation_pass()
	
	if not _is_recording_action:
		_is_recording_action = true
		call_deferred("_record_game_action")

func _on_shifter_move_made():
	if not is_game_active or is_paused: return
	shifter_move_count += 1
	ui_manager.update_move_counter(shifter_move_count)
	
	if not _is_recording_action:
		_is_recording_action = true
		call_deferred("_record_game_action")

func _run_validation_pass():
	board_manager.clear_highlights()
	var results = PuzzleValidator.validate_board(board_manager.board_cells, board_manager.cached_lines, board_manager.active_constraint_pairs)
	
	ui_manager.set_hint_button_disabled(_get_usable_hints_count() == 0)
	ui_manager.update_undo_redo_buttons(undo_stack.size() > 0, redo_stack.size() > 0)
	
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
	
	var elapsed = starting_time_limit - time_remaining
	if starting_time_limit == 0:
		elapsed = 0 
	var minutes = int(elapsed / 60.0)
	var seconds = elapsed % 60
	var formatted_elapsed = "%02d:%02d" % [minutes, seconds]
	if starting_time_limit == 0:
		formatted_elapsed = "Unlimited"
	
	ui_manager.show_victory(display_num, is_last, formatted_elapsed, is_custom)

func trigger_defeat():
	is_game_active = false
	if timer_node: timer_node.stop()
	board_manager.process_mode = Node.PROCESS_MODE_DISABLED
	ui_manager.show_defeat()

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
	ui_manager.update_undo_redo_buttons(undo_stack.size() > 0, redo_stack.size() > 0)
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
		if starting_time_limit == 0:
			return
			
		time_remaining -= 1
		_update_timer_display()
		
		if time_remaining <= 0:
			trigger_defeat()

func _update_timer_display():
	if starting_time_limit == 0:
		ui_manager.update_timer("∞")
		return
		
	var minutes = int(time_remaining / 60.0)
	var seconds = time_remaining % 60
	if minutes < 0: minutes = 0
	if seconds < 0: seconds = 0
	var f_time = "%02d:%02d" % [minutes, seconds]
	ui_manager.update_timer(f_time)
