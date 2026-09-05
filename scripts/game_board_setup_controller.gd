class_name GameBoardSetupController
extends Node
## Builds or generates the board for the current level and starts the run.


var _game: GameMain


func setup(game: GameMain) -> void:
	_game = game


static func solve_layout(
	layout: Dictionary,
	tiles_list: Array,
	constraints: Array,
	dims: Vector2i,
	shifter_pairs: Array = []
) -> Dictionary:
	var layout_for_solve := LevelUtils.layout_with_shifters_for_solve(layout, shifter_pairs)
	var empty_cells: Array = LevelUtils.empty_cells_from_layout(layout_for_solve)
	return LevelUtils.solve_reference(
		layout_for_solve, empty_cells, dims.x, dims.y, tiles_list, constraints
	)


func generate_board() -> void:
	if _game == null:
		return
	if _game.current_level_index >= _game.levels.size():
		return
	if _game._is_generating_board:
		return
	_game._is_generating_board = true

	if _game.tutorial_director:
		_game.tutorial_director.stop()
	var ui_manager := _game.ui_manager
	ui_manager.set_overlays_hidden()
	ui_manager.set_status_visible(false)
	ui_manager.set_top_bar_visible(false)
	if _game.pause_menu:
		_game.pause_menu.hide()
	if _game.options_menu:
		_game.options_menu.visible = false
	if _game.board_manager:
		_game.board_manager.visible = true
	if _game.hud_layer:
		_game.hud_layer.visible = true
	_game.is_game_active = true
	_game.is_paused = false
	_game._timer_paused_for_ad = false

	var current_level_resource: LevelData = _game.levels[_game.current_level_index]
	if SaveManager and current_level_resource is LevelData:
		SaveManager.mark_level_seen(current_level_resource.level_number)
	var is_custom := current_level_resource.resource_path.begins_with("user://")
	var is_unique_solution: bool = current_level_resource.is_unique_solution
	_game.prefer_hidden_hints = true
	var dims := LevelUtils.get_dimensions_from_level(current_level_resource)

	_game._challenges_disabled = _game._is_campaign_tutorial(current_level_resource)
	_game.star_time_limit = 0 if _game._challenges_disabled else int(
		current_level_resource.get("time_limit") if "time_limit" in current_level_resource else 0
	)
	_game._reset_hint_quota(current_level_resource)
	if AdsManager:
		AdsManager.warm_rewarded_hint()
	_game.elapsed_seconds = 0
	_game.shifter_move_count = 0
	_game.hints_used = 0
	_game._run_used_undo = false
	_game._pause_accumulated_sec = 0.0
	_game._pause_started_msec = 0
	_game.required_shifter_moves = 0
	_game.required_jokers = 0
	_game._has_shifters = false
	ui_manager.set_joker_counter_visibility(false)
	ui_manager.set_move_counter_visibility(false)
	ui_manager.set_timer_visibility(not _game._challenges_disabled)
	_game._update_timer_display()
	if _game.timer_node:
		_game.timer_node.stop()
	_game.board_manager.process_mode = Node.PROCESS_MODE_INHERIT

	var tiles_list: Array = LevelUtils.normalize_available_tiles(
		current_level_resource.available_tiles if (
			current_level_resource.available_tiles.size() > 0
		) else [0, 1, 2]
	)

	var s_pairs := LevelUtils.get_shifter_pairs(current_level_resource)
	var solve_constraints: Array = []
	var c_pairs: Array = []
	var saved_constraints: Array = []
	if current_level_resource.constraint_pairs.size() > 0:
		saved_constraints = current_level_resource.constraint_pairs.duplicate(true)
		solve_constraints = saved_constraints.duplicate(true)
		if is_unique_solution:
			c_pairs = saved_constraints.duplicate(true)
			_game.hidden_reference_constraints = []
		else:
			_game.hidden_reference_constraints = saved_constraints.duplicate(true)
	else:
		_game.hidden_reference_constraints = []

	var base_layout: Dictionary = current_level_resource.layout.duplicate(true)
	if base_layout.is_empty():
		base_layout = LevelUtils.make_empty_layout(dims.x, dims.y)
	else:
		base_layout = LevelUtils.ensure_layout_covers_grid(base_layout, dims.x, dims.y)

	var is_tutorial_level := not LevelUtils.is_shape_only_layout(base_layout)

	var fresh_layout := {}
	var final_s_pairs: Array = []
	var final_c_pairs: Array = []

	if is_tutorial_level:
		fresh_layout = base_layout
		final_s_pairs = s_pairs.duplicate()
		final_c_pairs = c_pairs.duplicate()
		_game._has_shifters = final_s_pairs.size() > 0
		if _game._challenges_disabled:
			_game.required_jokers = 0
			_game.required_shifter_moves = 0
		else:
			var saved_req := (
				current_level_resource.required_jokers
				if "required_jokers" in current_level_resource
				else -1
			)
			_game.required_jokers = LevelUtils.resolve_required_jokers(saved_req, dims.x, dims.y)
			_game.required_shifter_moves = current_level_resource.required_shifter_moves
			if _game.required_shifter_moves <= 0 and _game._has_shifters:
				_game.required_shifter_moves = LevelUtils.compute_required_shifter_moves(final_s_pairs)
		_game.solved_solution_reference = GameBoardSetupController.solve_layout(
			fresh_layout, tiles_list, solve_constraints, dims, final_s_pairs
		)
	else:
		var wall_layout: Dictionary = base_layout
		var keep_walls := current_level_resource.keep_walls
		var gen_difficulty := _game._difficulty_for_level(current_level_resource)
		var generated: Variant = await _game._loading_overlay.run_async(_game, func():
			var result := {}
			var attempts := 25 if is_unique_solution else 10
			for _attempt in attempts:
				result = PuzzleGenerator.generate_random_layout(
					dims.x,
					dims.y,
					tiles_list,
					wall_layout,
					is_unique_solution,
					keep_walls,
					gen_difficulty
				)
				if not result.is_empty():
					break
			return result
		)
		if not is_instance_valid(_game) or not _game.is_inside_tree():
			return
		if typeof(generated) != TYPE_DICTIONARY or (generated as Dictionary).is_empty():
			_game._is_generating_board = false
			_game.is_game_active = false
			ui_manager.set_top_bar_visible(true)
			ui_manager.show_status_errors(["ERROR_INVALID_SHAPE"])
			return
		var generated_dict: Dictionary = generated
		fresh_layout = generated_dict["layout"]
		final_s_pairs = generated_dict["shifters"]
		var gen_constraints: Array = generated_dict.get("constraints", []).duplicate(true)
		var gen_hidden: Array = generated_dict.get("hidden_hints", []).duplicate(true)
		if is_unique_solution:
			final_c_pairs = gen_constraints
			solve_constraints = gen_constraints.duplicate(true)
			solve_constraints.append_array(gen_hidden)
			_game.hidden_reference_constraints = gen_hidden
		else:
			final_c_pairs = []
			solve_constraints = gen_hidden.duplicate(true)
			_game.hidden_reference_constraints = gen_hidden
		_game._has_shifters = final_s_pairs.size() > 0
		_game.required_jokers = maxi(0, int(generated_dict.get("total_jokers", 0)))
		_game.required_shifter_moves = maxi(0, int(generated_dict.get("required_shifter_moves", 0)))
		if _game.required_shifter_moves <= 0 and _game._has_shifters:
			_game.required_shifter_moves = LevelUtils.compute_required_shifter_moves(final_s_pairs)
		_game.solved_solution_reference = GameBoardSetupController.solve_layout(
			fresh_layout, tiles_list, solve_constraints, dims, final_s_pairs
		)

	ui_manager.set_joker_counter_visibility(false)
	ui_manager.set_move_counter_visibility(false)
	var is_tutorial := _game._is_campaign_tutorial(current_level_resource)
	ui_manager.set_reset_mode_restart(LevelUtils.level_has_preset_tiles(current_level_resource))
	ui_manager.display_level(
		LevelUtils.get_display_level_number(current_level_resource),
		is_custom,
		is_tutorial
	)
	_game._run_layout = fresh_layout.duplicate(true)
	_game._run_shifter_pairs = final_s_pairs.duplicate(true)
	_game._run_available_tiles = tiles_list.duplicate()
	_game.board_manager.build_grid(fresh_layout, tiles_list, final_s_pairs, final_c_pairs)

	if (
		is_unique_solution
		and _game.hidden_reference_constraints.is_empty()
		and not _game.solved_solution_reference.is_empty()
	):
		_game.hidden_reference_constraints = HintSystem.hidden_hints_from_solved(
			_game.solved_solution_reference,
			_game.board_manager.active_constraint_pairs,
			dims.x,
			dims.y
		)
	if _game.solved_solution_reference.is_empty():
		_game.solved_solution_reference = HintSystem.attempt_dynamic_solve(
			_game.board_manager.board_cells,
			_game.board_manager.active_constraint_pairs,
			tiles_list
		)
		if (
			is_unique_solution
			and _game.hidden_reference_constraints.is_empty()
			and not _game.solved_solution_reference.is_empty()
		):
			_game.hidden_reference_constraints = HintSystem.hidden_hints_from_solved(
				_game.solved_solution_reference,
				_game.board_manager.active_constraint_pairs,
				dims.x,
				dims.y
			)
	_game._update_joker_count()

	var centered_board_y := LevelUtils.center_board_y(
		dims.y, GameConstants.CELL_SIZE, _game.get_viewport_rect().size.y
	)
	_game.board_manager.position.y = centered_board_y
	ui_manager.update_dynamic_layout(centered_board_y, dims.y * GameConstants.CELL_SIZE)
	_game.game_undo.reset(_game._create_game_snapshot())
	_game._is_generating_board = false
	ui_manager.set_top_bar_visible(true)
	_game._start_tutorial_if_needed(tiles_list)
	_game._run_validation_pass()
	if _game.timer_node and _game.is_game_active and not _game._challenges_disabled:
		_game.timer_node.start()
