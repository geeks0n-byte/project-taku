class_name GameValidationController
extends Node
## Board validation, cell-change reactions, and invalid-move feedback.


var _game: GameMain


func setup(game: GameMain) -> void:
	_game = game


func on_invalid_move_attempted(msg: String) -> void:
	if _game == null:
		return
	if not _game.is_game_active or _game.is_paused:
		return
	if AchievementManager:
		AchievementManager.notify_invalid_move(msg)
	if _game.tutorial_director and _game.tutorial_director.is_active():
		if _game.tutorial_director.on_invalid_move(msg):
			return
	var results = PuzzleValidator.validate_board(
		_game.board_manager.board_cells,
		_game.board_manager.cached_lines,
		_game.board_manager.active_constraint_pairs,
		-1
	)
	var combined_errors = results["errors"].duplicate()
	if not combined_errors.has(msg):
		combined_errors.append(msg)
	_game.ui_manager.show_status_errors(combined_errors)
	_game.board_manager.refresh_error_bridges()


func on_cell_changed(_coord: Vector2i) -> void:
	if _game == null:
		return
	if not _game.is_game_active or _game.is_paused:
		return
	if _game._undo_ctrl:
		_game._undo_ctrl.update_joker_count()
	if _game.tutorial_director and _game.tutorial_director.is_active():
		_game.tutorial_director.on_board_changed(_coord)
	if AchievementManager and _game.board_manager:
		AchievementManager.check_all_blue(_game.board_manager.board_cells)
		AchievementManager.check_all_yellow(_game.board_manager.board_cells)
		AchievementManager.check_all_green(_game.board_manager.board_cells)
	run_validation_pass()
	if not _game._is_recording_action:
		_game._is_recording_action = true
		_game.call_deferred("_record_game_action")


func on_shifter_move_made() -> void:
	if _game == null:
		return
	if not _game.is_game_active or _game.is_paused:
		return
	_game.shifter_move_count += 1
	if AchievementManager:
		AchievementManager.notify_shifter_slide()
	_game.ui_manager.update_move_counter(_game.shifter_move_count, _game.required_shifter_moves)
	if _game.tutorial_director and _game.tutorial_director.is_active():
		_game.tutorial_director.on_board_changed()
	if not _game._is_recording_action:
		_game._is_recording_action = true
		_game.call_deferred("_record_game_action")


func run_validation_pass() -> void:
	if _game == null or _game.board_manager == null:
		return
	_game.board_manager.clear_highlights()
	var results = PuzzleValidator.validate_board(
		_game.board_manager.board_cells,
		_game.board_manager.cached_lines,
		_game.board_manager.active_constraint_pairs,
		-1
	)
	var tutorial_running := _game.tutorial_director != null and _game.tutorial_director.is_active()
	if tutorial_running:
		_game.tutorial_director.refresh_tool_gates()
	else:
		_game._refresh_hint_button()
		_game.ui_manager.update_undo_redo_buttons(
			_game.game_undo.can_undo(), _game.game_undo.can_redo()
		)
	if not results["valid"]:
		var suppress_tutorial_errors := (
			tutorial_running
			and _game.tutorial_director
			and _game.tutorial_director.suppress_validation_errors()
		)
		if not suppress_tutorial_errors:
			_game.ui_manager.show_status_errors(results["errors"])
			_game.board_manager.refresh_error_bridges()
	else:
		_game.ui_manager.show_status_valid()
	if tutorial_running:
		_game.tutorial_director.on_validation_result(results)
	if results["valid"] and _game.board_manager.is_board_full():
		if tutorial_running:
			_game.tutorial_director.on_board_solved()
		else:
			_game.trigger_victory()
