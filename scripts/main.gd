extends Node2D

@export var show_debug_tools: bool = true

var core_levels: Array[LevelData] = []
var custom_levels: Array[LevelData] = []
var levels: Array[LevelData] = []

@onready var ui_manager: UIManager = find_child("UIManager", true, false)
@onready var board_manager: BoardManager = find_child("BoardManager", true, false)
@onready var timer_node: Timer = find_child("Timer", true, false)
@onready var pause_menu = find_child("PauseMenu", true, false)
@onready var hud_layer = find_child("HUDLayer", true, false)

var starting_time_limit: int = 120
var time_remaining: int = 120
var shifter_move_count: int = 0
var is_game_active: bool = true
var is_paused: bool = false
var current_level_index: int = 0
var solved_solution_reference: Dictionary = {}
var hidden_reference_constraints: Array = []
var required_jokers: int = 0
var game_undo := UndoStack.new()
var _is_recording_action: bool = false

func _ready():
	_load_all_levels_from_storage()
	_intercept_global_selection()
	if levels.is_empty():
		return
	if ui_manager and board_manager:
		ui_manager.setup_ui(show_debug_tools, GameConstants.CELL_SIZE)
		_bind_submanager_signals()
	if pause_menu and pause_menu.get("auto_win_button"):
		pause_menu.auto_win_button.visible = show_debug_tools
	if timer_node:
		timer_node.timeout.connect(_on_timer_timeout)
	generate_board()

func _bind_submanager_signals():
	if not ui_manager or not board_manager:
		return
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
	if pause_menu:
		pause_menu.resume_pressed.connect(_on_resume)
		pause_menu.restart_pressed.connect(_on_restart_level)
		pause_menu.auto_win_pressed.connect(_on_auto_win)
		pause_menu.quit_pressed.connect(_on_quit_to_menu)
	ui_manager.next_level_requested.connect(_on_next_level)
	ui_manager.play_again_requested.connect(_on_play_again)

func _on_invalid_move_attempted(msg: String):
	if not is_game_active or is_paused:
		return
	var results = PuzzleValidator.validate_board(
		board_manager.board_cells,
		board_manager.cached_lines,
		board_manager.active_constraint_pairs,
		required_jokers
	)
	var combined_errors = results["errors"].duplicate()
	if not combined_errors.has(msg):
		combined_errors.append(msg)
	ui_manager.show_status_errors(combined_errors)

func _load_all_levels_from_storage() -> void:
	core_levels.clear()
	custom_levels.clear()
	levels.clear()
	var core_paths = LevelUtils.scan_directory(GameConstants.CAMPAIGN_DIR)
	var custom_paths = LevelUtils.scan_directory(GameConstants.DEV_LEVELS_DIR)
	var numeric_sort = func(a, b):
		var num_a = int(a.get_file().get_basename().replace("level_", ""))
		var num_b = int(b.get_file().get_basename().replace("level_", ""))
		return num_a < num_b
	core_paths.sort_custom(numeric_sort)
	custom_paths.sort_custom(numeric_sort)
	for path in core_paths:
		var res = load(path)
		if res and res is LevelData:
			core_levels.append(res)
	for path in custom_paths:
		var res = load(path)
		if res and res is LevelData:
			custom_levels.append(res)

func _intercept_global_selection():
	if GlobalGameManager.selected_level_resource != null:
		var selected_resource = GlobalGameManager.selected_level_resource
		GlobalGameManager.selected_level_resource = null
		levels = custom_levels.duplicate() if selected_resource.resource_path.begins_with("user://") else core_levels.duplicate()
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
			current_level_index = maxi(0, levels.size() - 1)

func generate_board():
	if current_level_index >= levels.size():
		return

	ui_manager.set_overlays_hidden()
	if board_manager:
		board_manager.visible = true
	if hud_layer:
		hud_layer.visible = true
	is_game_active = true
	is_paused = false

	var current_level_resource = levels[current_level_index]
	var is_custom = current_level_resource.resource_path.begins_with("user://")
	var is_unique_solution = current_level_resource.get("is_unique_solution") if "is_unique_solution" in current_level_resource else true
	var dims := LevelUtils.get_dimensions_from_level(current_level_resource)

	starting_time_limit = current_level_resource.get("time_limit") if "time_limit" in current_level_resource else 120
	time_remaining = starting_time_limit
	shifter_move_count = 0
	ui_manager.update_move_counter(shifter_move_count)
	_update_timer_display()
	if timer_node:
		timer_node.start()
	board_manager.process_mode = Node.PROCESS_MODE_INHERIT

	var tiles_list: Array = [0, 1, 2]
	if "available_tiles" in current_level_resource and current_level_resource.available_tiles.size() > 0:
		tiles_list = current_level_resource.available_tiles

	var s_pairs := LevelUtils.get_shifter_pairs(current_level_resource)
	var solve_constraints: Array = []
	var c_pairs: Array = []
	if "constraint_pairs" in current_level_resource:
		solve_constraints = current_level_resource.constraint_pairs.duplicate(true)
		if is_unique_solution:
			c_pairs = current_level_resource.constraint_pairs.duplicate(true)
	hidden_reference_constraints = solve_constraints.duplicate(true)

	var is_tutorial_level := false
	for coord in current_level_resource.layout:
		if current_level_resource.layout[coord] >= 0:
			is_tutorial_level = true
			break
	if s_pairs.size() > 0 or solve_constraints.size() > 0:
		is_tutorial_level = true

	var fresh_layout := {}
	var final_s_pairs: Array = []
	var final_c_pairs: Array = []

	if is_tutorial_level:
		fresh_layout = current_level_resource.layout.duplicate()
		final_s_pairs = s_pairs.duplicate()
		final_c_pairs = c_pairs.duplicate()
		ui_manager.set_move_counter_visibility(final_s_pairs.size() > 0)
		var prefilled = LevelUtils.count_jokers_in_layout(fresh_layout)
		var saved_req = current_level_resource.get("required_jokers") if "required_jokers" in current_level_resource else -1
		required_jokers = LevelUtils.calculate_required_jokers(saved_req, dims.x, dims.y, prefilled)
		solved_solution_reference = _solve_layout(fresh_layout, tiles_list, solve_constraints, dims)
	else:
		var generated := {}
		for attempt in range(5):
			generated = PuzzleGenerator.generate_random_layout(
				dims.x, dims.y, tiles_list, current_level_resource.layout, is_unique_solution, true
			)
			if not generated.is_empty():
				break
		if generated.is_empty():
			is_game_active = false
			if timer_node:
				timer_node.stop()
			ui_manager.show_status_errors([tr("ERROR_INVALID_SHAPE")])
			return
		fresh_layout = generated["layout"]
		final_s_pairs = generated["shifters"]
		solve_constraints = generated["constraints"].duplicate(true)
		hidden_reference_constraints = solve_constraints.duplicate(true)
		final_c_pairs = generated["constraints"].duplicate(true) if is_unique_solution else []
		ui_manager.set_move_counter_visibility(final_s_pairs.size() > 0)
		var prefilled = LevelUtils.count_jokers_in_layout(fresh_layout)
		required_jokers = maxi(0, generated["total_jokers"] - prefilled)
		solved_solution_reference = _solve_layout(fresh_layout, tiles_list, solve_constraints, dims)

	ui_manager.set_joker_counter_visibility(GameConstants.TileState.JOKER in tiles_list and required_jokers > 0)
	ui_manager.display_level(current_level_resource.level_number, is_custom)
	board_manager.build_grid(fresh_layout, tiles_list, final_s_pairs, final_c_pairs)
	_update_joker_count()

	var centered_board_y := LevelUtils.center_board_y(dims.y, GameConstants.CELL_SIZE, get_viewport_rect().size.y)
	board_manager.position.y = centered_board_y
	ui_manager.update_dynamic_layout(centered_board_y, dims.y * GameConstants.CELL_SIZE)
	game_undo.reset(_create_game_snapshot())
	_run_validation_pass()

func _solve_layout(layout: Dictionary, tiles_list: Array, constraints: Array, dims: Vector2i) -> Dictionary:
	var empty_cells: Array = []
	for c in layout:
		if layout[c] == GameConstants.TileState.EMPTY:
			empty_cells.append(c)
	return LevelUtils.solve_reference(layout, empty_cells, dims.x, dims.y, tiles_list, constraints)

func _create_game_snapshot() -> Dictionary:
	var snap := {}
	for coord in board_manager.board_cells:
		var cell = board_manager.board_cells[coord]
		snap[coord] = {"state": cell.state, "shifter_direction": cell.shifter_direction}
	return {
		"cells": snap,
		"constraints": board_manager.active_constraint_pairs.duplicate(true),
		"moves": shifter_move_count
	}

func _apply_game_snapshot(snap: Dictionary):
	shifter_move_count = snap["moves"]
	ui_manager.update_move_counter(shifter_move_count)
	for coord in snap["cells"]:
		var cell = board_manager.board_cells[coord]
		cell.state = snap["cells"][coord]["state"]
		cell.shifter_direction = snap["cells"][coord]["shifter_direction"]
		cell.update_visuals()
	board_manager.active_constraint_pairs = snap.get("constraints", []).duplicate(true)
	_update_joker_count()
	board_manager.trigger_redraw()
	_run_validation_pass()

func _record_game_action():
	_is_recording_action = false
	game_undo.record(_create_game_snapshot())
	ui_manager.update_undo_redo_buttons(game_undo.can_undo(), game_undo.can_redo())

func _on_undo_requested():
	if not is_game_active or is_paused or not game_undo.can_undo():
		return
	_apply_game_snapshot(game_undo.undo())
	ui_manager.update_undo_redo_buttons(game_undo.can_undo(), game_undo.can_redo())

func _on_redo_requested():
	if not is_game_active or is_paused or not game_undo.can_redo():
		return
	_apply_game_snapshot(game_undo.redo())
	ui_manager.update_undo_redo_buttons(game_undo.can_undo(), game_undo.can_redo())

func _update_joker_count():
	ui_manager.update_joker_counter(
		LevelUtils.count_unlocked_jokers(board_manager.board_cells),
		required_jokers
	)

func _on_hint_requested():
	if not is_game_active or is_paused:
		return
	if solved_solution_reference.is_empty():
		var current_res = levels[current_level_index]
		var tiles_list = current_res.available_tiles if current_res.available_tiles.size() > 0 else [0, 1, 2]
		solved_solution_reference = HintSystem.attempt_dynamic_solve(
			board_manager.board_cells,
			board_manager.active_constraint_pairs,
			tiles_list
		)
	var hint = HintSystem.pick_hint(
		board_manager.board_cells,
		board_manager.active_constraint_pairs,
		solved_solution_reference,
		hidden_reference_constraints,
		LevelUtils.get_dimensions_from_cells(board_manager.board_cells),
		true
	)
	if hint != null:
		board_manager.active_constraint_pairs.append(hint)
		board_manager.trigger_redraw()
		_run_validation_pass()
	else:
		ui_manager.show_status_errors([tr("ERROR_NO_HINTS")])

func _on_cell_changed(_coord: Vector2i):
	if not is_game_active or is_paused:
		return
	_update_joker_count()
	_run_validation_pass()
	if not _is_recording_action:
		_is_recording_action = true
		call_deferred("_record_game_action")

func _on_shifter_move_made():
	if not is_game_active or is_paused:
		return
	shifter_move_count += 1
	ui_manager.update_move_counter(shifter_move_count)
	if not _is_recording_action:
		_is_recording_action = true
		call_deferred("_record_game_action")

func _run_validation_pass():
	board_manager.clear_highlights()
	var results = PuzzleValidator.validate_board(
		board_manager.board_cells,
		board_manager.cached_lines,
		board_manager.active_constraint_pairs,
		required_jokers
	)
	ui_manager.set_hint_button_disabled(
		HintSystem.count_usable_hints(
			board_manager.board_cells,
			board_manager.active_constraint_pairs,
			solved_solution_reference,
			hidden_reference_constraints
		) == 0
	)
	ui_manager.update_undo_redo_buttons(game_undo.can_undo(), game_undo.can_redo())
	if not results["valid"]:
		ui_manager.show_status_errors(results["errors"])
	else:
		ui_manager.show_status_valid()
	if results["valid"] and board_manager.is_board_full():
		trigger_victory()

func trigger_victory():
	is_game_active = false
	if timer_node:
		timer_node.stop()
	board_manager.process_mode = Node.PROCESS_MODE_DISABLED
	var is_custom = levels[current_level_index].resource_path.begins_with("user://")
	var is_last = current_level_index >= levels.size() - 1
	var display_num = levels[current_level_index].level_number
	if not is_custom:
		SaveManager.unlock_level(display_num + 1)
	var elapsed = starting_time_limit - time_remaining
	if starting_time_limit == 0:
		elapsed = 0
	var formatted_elapsed = tr("UNLIMITED") if starting_time_limit == 0 else "%02d:%02d" % [int(elapsed / 60.0), elapsed % 60]
	ui_manager.show_victory(display_num, is_last, formatted_elapsed, is_custom)

func trigger_defeat():
	is_game_active = false
	if timer_node:
		timer_node.stop()
	board_manager.process_mode = Node.PROCESS_MODE_DISABLED
	ui_manager.show_defeat()

func _on_pause():
	if not is_game_active or is_paused:
		return
	is_paused = true
	if timer_node:
		timer_node.stop()
	board_manager.process_mode = Node.PROCESS_MODE_DISABLED
	if board_manager:
		board_manager.visible = false
	if hud_layer:
		hud_layer.visible = false
	ui_manager.set_hud_buttons_disabled(true)
	if pause_menu:
		pause_menu.show()

func _on_how_to_play():
	if not is_game_active or is_paused:
		return
	is_paused = true
	if timer_node:
		timer_node.stop()
	board_manager.process_mode = Node.PROCESS_MODE_DISABLED
	if ui_manager.has_method("show_how_to_play"):
		ui_manager.show_how_to_play()

func _on_resume():
	if not is_paused:
		return
	is_paused = false
	if timer_node:
		timer_node.start()
	board_manager.process_mode = Node.PROCESS_MODE_INHERIT
	if board_manager:
		board_manager.visible = true
	if hud_layer:
		hud_layer.visible = true
	ui_manager.set_hud_buttons_disabled(false)
	ui_manager.update_undo_redo_buttons(game_undo.can_undo(), game_undo.can_redo())
	ui_manager.set_hint_button_disabled(
		HintSystem.count_usable_hints(
			board_manager.board_cells,
			board_manager.active_constraint_pairs,
			solved_solution_reference,
			hidden_reference_constraints
		) == 0
	)
	if pause_menu:
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
	if not is_game_active:
		return
	is_paused = false
	if pause_menu:
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
	var minutes = maxi(0, int(time_remaining / 60.0))
	var seconds = maxi(0, time_remaining % 60)
	ui_manager.update_timer("%02d:%02d" % [minutes, seconds])
