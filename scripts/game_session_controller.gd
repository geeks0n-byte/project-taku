class_name GameSessionController
extends Node
## Debounced session autosave and restore for the gameplay scene.


const AUTOSAVE_DEBOUNCE_SEC := 0.35

var _game: GameMain
var _autosave_generation: int = 0


func setup(game: GameMain) -> void:
	_game = game


func autosave() -> void:
	request_autosave()


func autosave_now() -> void:
	_autosave_generation += 1
	_flush_autosave()


func request_autosave() -> void:
	if not _should_autosave():
		return
	_autosave_generation += 1
	var generation := _autosave_generation
	var tree := get_tree()
	if tree == null:
		_flush_autosave()
		return
	var timer := tree.create_timer(AUTOSAVE_DEBOUNCE_SEC, true, false, true)
	timer.timeout.connect(func() -> void:
		if generation != _autosave_generation:
			return
		_flush_autosave()
	, CONNECT_ONE_SHOT)


func build_payload() -> Dictionary:
	if _game == null:
		return {}
	if _game.levels.is_empty() or _game.current_level_index < 0 or _game.current_level_index >= _game.levels.size():
		return {}
	if _game._run_layout.is_empty():
		return {}
	var board_manager := _game.board_manager
	if board_manager == null:
		return {}
	var level: LevelData = _game.levels[_game.current_level_index]
	var cells := {}
	for coord in board_manager.board_cells:
		var cell = board_manager.board_cells[coord]
		cells[coord] = {
			"state": cell.state,
			"shifter_direction": cell.shifter_direction,
		}
	return {
		"level_path": level.resource_path,
		"level_number": level.level_number,
		"elapsed_seconds": _game.elapsed_seconds,
		"shifter_move_count": _game.shifter_move_count,
		"hints_used": _game.hints_used,
		"required_jokers": _game.required_jokers,
		"required_shifter_moves": _game.required_shifter_moves,
		"has_shifters": _game._has_shifters,
		"challenges_disabled": _game._challenges_disabled,
		"prefer_hidden_hints": _game.prefer_hidden_hints,
		"star_time_limit": _game.star_time_limit,
		"hints_remaining": _game.hints_remaining,
		"has_hints_remaining": true,
		"available_tiles": _game._run_available_tiles.duplicate(),
		"layout": _game._run_layout.duplicate(true),
		"shifter_pairs": _game._run_shifter_pairs.duplicate(true),
		"active_constraint_pairs": board_manager.active_constraint_pairs.duplicate(true),
		"hidden_reference_constraints": _game.hidden_reference_constraints.duplicate(true),
		"solved_solution_reference": _game.solved_solution_reference.duplicate(true),
		"cells": cells,
		"undo_history": _game.game_undo.export_history(),
	}


func restore() -> void:
	if _game == null:
		return
	var data := SaveManager.load_session()
	if data.is_empty():
		_game.generate_board()
		return

	var current_level_resource: LevelData = _game.levels[_game.current_level_index]
	var session_path := str(data.get("level_path", ""))
	if not session_path.is_empty() and session_path != current_level_resource.resource_path:
		SaveManager.clear_session()
		_game.generate_board()
		return

	if _game.tutorial_director:
		_game.tutorial_director.stop()
	var ui_manager := _game.ui_manager
	ui_manager.set_overlays_hidden()
	if _game.pause_menu:
		_game.pause_menu.hide()
	if _game.options_menu:
		_game.options_menu.visible = false

	var is_custom = current_level_resource.resource_path.begins_with("user://")
	_game._run_layout = data.get("layout", {}).duplicate(true)
	_game._run_shifter_pairs = data.get("shifter_pairs", []).duplicate(true)
	_game._run_available_tiles = LevelUtils.normalize_available_tiles(
		data.get("available_tiles", [0, 1, 2])
	)
	if _game._run_layout.is_empty():
		SaveManager.clear_session()
		_game.generate_board()
		return

	var challenges_disabled := bool(
		data.get(
			"challenges_disabled",
			LevelUtils.is_campaign_tutorial(current_level_resource)
		)
	)
	_game._challenges_disabled = challenges_disabled
	_game.star_time_limit = 0 if challenges_disabled else int(data.get("star_time_limit", 0))
	_game.elapsed_seconds = int(data.get("elapsed_seconds", 0))
	_game.shifter_move_count = int(data.get("shifter_move_count", 0))
	_game.hints_used = int(data.get("hints_used", 0))
	_game.required_jokers = 0 if challenges_disabled else int(data.get("required_jokers", 0))
	_game.required_shifter_moves = (
		0 if challenges_disabled else int(data.get("required_shifter_moves", 0))
	)
	_game._has_shifters = bool(data.get("has_shifters", false))
	_game.prefer_hidden_hints = true
	if bool(data.get("has_hints_remaining", false)):
		_game.hints_remaining = int(
			data.get("hints_remaining", GameConstants.HINT_LIMIT_UNLIMITED)
		)
	else:
		_game._reset_hint_quota(current_level_resource)
	_game.hidden_reference_constraints = data.get(
		"hidden_reference_constraints", []
	).duplicate(true)
	_game.solved_solution_reference = data.get(
		"solved_solution_reference", {}
	).duplicate(true)

	ui_manager.set_joker_counter_visibility(false)
	ui_manager.set_move_counter_visibility(false)
	var is_tutorial := LevelUtils.is_campaign_tutorial(current_level_resource)
	ui_manager.set_reset_mode_restart(LevelUtils.level_has_preset_tiles(current_level_resource))
	ui_manager.display_level(
		LevelUtils.get_display_level_number(current_level_resource),
		is_custom,
		is_tutorial
	)
	_game._update_timer_display()

	var board_manager := _game.board_manager
	var active_constraints: Array = data.get("active_constraint_pairs", []).duplicate(true)
	board_manager.build_grid(
		_game._run_layout,
		_game._run_available_tiles,
		_game._run_shifter_pairs,
		active_constraints
	)

	var saved_cells: Dictionary = data.get("cells", {})
	for coord in saved_cells:
		if not board_manager.board_cells.has(coord):
			continue
		var cell = board_manager.board_cells[coord]
		var entry: Dictionary = saved_cells[coord]
		cell.state = int(entry.get("state", cell.state))
		cell.shifter_direction = entry.get("shifter_direction", Vector2i.ZERO)
		cell.update_visuals()

	GameBoardLayout.apply_from_level(
		board_manager,
		ui_manager,
		current_level_resource,
		_game.get_viewport_rect().size.y
	)
	ui_manager.update_move_counter(
		_game.shifter_move_count,
		_game.required_shifter_moves
	)
	_game._update_joker_count()

	_game.is_game_active = true
	_game.is_paused = false
	board_manager.process_mode = Node.PROCESS_MODE_INHERIT
	_game._set_board_and_hud_visible(true)
	ui_manager.set_hud_buttons_disabled(false)
	var history: Dictionary = data.get("undo_history", {})
	if history is Dictionary and not history.is_empty() and history.has("current"):
		_game.game_undo.import_history(history)
	else:
		_game.game_undo.reset(_game._create_game_snapshot())
	ui_manager.update_undo_redo_buttons(
		_game.game_undo.can_undo(),
		_game.game_undo.can_redo()
	)
	_game._run_validation_pass()
	if _game.timer_node and not challenges_disabled:
		_game.timer_node.start()
	_game._refresh_hint_button()


func _should_autosave() -> bool:
	if _game == null:
		return false
	if not _game.is_game_active and not _game.is_paused:
		return false
	if _game._is_generating_board:
		return false
	if _game.tutorial_director and _game.tutorial_director.is_active():
		return false
	return true


func _flush_autosave() -> void:
	if not _should_autosave():
		return
	var payload := build_payload()
	if payload.is_empty():
		return
	SaveManager.save_session(payload)
