class_name GameUndoController
extends Node
## Undo/redo snapshots and stack for the gameplay scene.


var _game: GameMain


func setup(game: GameMain) -> void:
	_game = game


func create_snapshot() -> Dictionary:
	if _game == null or _game.board_manager == null:
		return {"cells": {}, "moves": 0}
	var snap := {}
	for coord in _game.board_manager.board_cells:
		var cell = _game.board_manager.board_cells[coord]
		snap[coord] = {"state": cell.state, "shifter_direction": cell.shifter_direction}
	return {
		"cells": snap,
		"moves": _game.shifter_move_count
	}


func apply_snapshot(snap: Dictionary) -> void:
	if _game == null:
		return
	_game.shifter_move_count = snap["moves"]
	_game.ui_manager.update_move_counter(_game.shifter_move_count, _game.required_shifter_moves)
	for coord in snap["cells"]:
		var cell = _game.board_manager.board_cells[coord]
		cell.state = snap["cells"][coord]["state"]
		cell.shifter_direction = snap["cells"][coord]["shifter_direction"]
		cell.update_visuals()
	update_joker_count()
	_game.board_manager.trigger_redraw()
	_game.run_validation_pass()


func on_tutorial_board_layout_changed() -> void:
	if _game == null:
		return
	_game.game_undo.reset(create_snapshot())
	var dims := LevelUtils.get_dimensions_from_cells(_game.board_manager.board_cells)
	var centered_board_y := LevelUtils.center_board_y(
		dims.y, GameConstants.CELL_SIZE, _game.get_viewport_rect().size.y
	)
	_game.board_manager.position.y = centered_board_y
	if _game.ui_manager:
		_game.ui_manager.update_dynamic_layout(centered_board_y, dims.y * GameConstants.CELL_SIZE)
		_game.ui_manager.update_undo_redo_buttons(
			_game.game_undo.can_undo(), _game.game_undo.can_redo()
		)


func record_action() -> void:
	if _game == null:
		return
	_game._is_recording_action = false
	_game.game_undo.record(create_snapshot())
	_game.ui_manager.update_undo_redo_buttons(_game.game_undo.can_undo(), _game.game_undo.can_redo())
	_game._autosave_session()


func on_undo_requested() -> void:
	if _game == null:
		return
	if _game.tutorial_director and _game.tutorial_director.consume_hud_action("undo"):
		return
	if not _game.is_game_active or _game.is_paused or not _game.game_undo.can_undo():
		return
	if _game.tutorial_director and _game.tutorial_director.is_active():
		return
	apply_snapshot(_game.game_undo.undo())
	_game._run_used_undo = true
	if AchievementManager:
		AchievementManager.notify_undo()
	_game.ui_manager.update_undo_redo_buttons(_game.game_undo.can_undo(), _game.game_undo.can_redo())
	_game._autosave_session()


func on_redo_requested() -> void:
	if _game == null:
		return
	if _game.tutorial_director and _game.tutorial_director.consume_hud_action("redo"):
		return
	if not _game.is_game_active or _game.is_paused or not _game.game_undo.can_redo():
		return
	if _game.tutorial_director and _game.tutorial_director.is_active():
		return
	apply_snapshot(_game.game_undo.redo())
	if AchievementManager:
		AchievementManager.notify_redo()
	_game.ui_manager.update_undo_redo_buttons(_game.game_undo.can_undo(), _game.game_undo.can_redo())
	_game._autosave_session()


func update_joker_count() -> void:
	if _game == null or _game.ui_manager == null or _game.board_manager == null:
		return
	_game.ui_manager.update_joker_counter(
		LevelUtils.count_jokers_on_board(_game.board_manager.board_cells),
		_game.required_jokers
	)
