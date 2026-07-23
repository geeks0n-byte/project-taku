class_name EditorPlaytestController
extends Node

signal playtest_finished

var canvas_manager: EditorCanvasManager
var pt_ui: PlaytestUIManager
var editor_ui: EditorUIManager

var is_active: bool = false
var playtest_snapshot: Dictionary = {}
var playtest_hidden_constraints: Array = []
var solved_solution_reference: Dictionary = {}
var playtest_required_jokers: int = 0
var playtest_time_remaining: int = 0
var playtest_shifter_moves: int = 0

var _timer: Timer
var _undo_stack := UndoStack.new()

func setup(canvas: EditorCanvasManager, playtest_ui: PlaytestUIManager, editor: EditorUIManager) -> void:
	canvas_manager = canvas
	pt_ui = playtest_ui
	editor_ui = editor

	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)

func enter(current_level_required_jokers: int) -> void:
	is_active = true
	canvas_manager.is_playtesting = true
	playtest_snapshot.clear()

	var prefilled_jokers := 0
	for coord in canvas_manager.board_cells:
		var cell = canvas_manager.board_cells[coord]
		playtest_snapshot[coord] = {
			"state": cell.state,
			"shifter_direction": cell.shifter_direction
		}
		if cell.state == GameConstants.TileState.JOKER:
			prefilled_jokers += 1
		LevelUtils.apply_playtest_cell_locks(cell)
		cell.is_editor_mode = false
		cell.update_visuals()

	playtest_hidden_constraints = canvas_manager.loaded_constraint_pairs.duplicate(true)

	var built := LevelUtils.build_solve_layout(canvas_manager.board_cells)
	solved_solution_reference = LevelUtils.solve_reference(
		built["layout"],
		built["empty_cells"],
		canvas_manager.grid_width,
		canvas_manager.grid_height,
		editor_ui.get_allowed_tiles(),
		canvas_manager.loaded_constraint_pairs
	)

	playtest_time_remaining = editor_ui.get_time_limit()
	playtest_shifter_moves = 0
	pt_ui.set_playtest_move_counter_visibility(canvas_manager.loaded_shifter_pairs.size() > 0)

	var saved_required := current_level_required_jokers
	if saved_required == -1:
		saved_required = mini(canvas_manager.grid_width, canvas_manager.grid_height)
	playtest_required_jokers = maxi(0, saved_required - prefilled_jokers)

	var has_jokers := GameConstants.TileState.JOKER in editor_ui.get_allowed_tiles() and playtest_required_jokers > 0
	pt_ui.set_playtest_joker_counter_visibility(has_jokers)
	_update_joker_count()

	_undo_stack.reset(_create_snapshot())
	pt_ui.toggle_playtest_visibility(true)
	_update_hud()
	_timer.start()
	canvas_manager.trigger_redraw()
	_run_validation()

func exit() -> void:
	is_active = false
	canvas_manager.is_playtesting = false
	_timer.stop()
	pt_ui.hide_victory_overlay()

	for coord in canvas_manager.board_cells:
		var cell = canvas_manager.board_cells[coord]
		cell.clear_highlight()
		var restored = playtest_snapshot[coord]
		cell.state = restored["state"]
		cell.shifter_direction = restored["shifter_direction"]
		LevelUtils.apply_playtest_cell_locks(cell)
		cell.is_editor_mode = true
		cell.update_visuals()

	canvas_manager.loaded_constraint_pairs = playtest_hidden_constraints.duplicate(true)
	canvas_manager.trigger_redraw()
	pt_ui.toggle_playtest_visibility(false)

func reset() -> void:
	if not is_active:
		return
	_timer.stop()
	pt_ui.hide_victory_overlay()
	_restore_snapshot(playtest_snapshot)
	canvas_manager.loaded_constraint_pairs = playtest_hidden_constraints.duplicate(true)
	playtest_time_remaining = editor_ui.get_time_limit()
	playtest_shifter_moves = 0
	pt_ui.set_playtest_move_counter_visibility(canvas_manager.loaded_shifter_pairs.size() > 0)
	_update_joker_count()
	_undo_stack.reset(_create_snapshot())
	_update_hud()
	_timer.start()
	canvas_manager.trigger_redraw()
	_run_validation()

func handle_cell_click(coord: Vector2i) -> void:
	if not is_active:
		return

	canvas_manager.clear_highlights()
	var cell = canvas_manager.board_cells[coord]
	if cell.is_locked:
		return

	var allowed = editor_ui.get_allowed_tiles()
	if cell.state == GameConstants.TileState.SHIFTER:
		var partner_coord = coord + cell.shifter_direction
		if canvas_manager.board_cells.has(partner_coord):
			var partner = canvas_manager.board_cells[partner_coord]
			if partner.state == GameConstants.TileState.SHIFTER:
				partner.set_error_highlight()
				pt_ui.update_playtest_status(
					"No space to move! The cell is occupied by another [color=#9c27b0]Purple[/color] tile.",
					Color.WHITE
				)
				return
			cell.state = GameConstants.TileState.EMPTY
			cell.shifter_direction = Vector2i.ZERO
			partner.state = GameConstants.TileState.SHIFTER
			partner.shifter_direction = coord - partner_coord
			partner.update_visuals()
			playtest_shifter_moves += 1
			_update_hud()
			canvas_manager.trigger_redraw()
	else:
		if cell.state == GameConstants.TileState.EMPTY:
			cell.state = allowed[0]
		else:
			var current_idx = allowed.find(cell.state)
			if current_idx == -1 or current_idx == allowed.size() - 1:
				cell.state = GameConstants.TileState.EMPTY
			else:
				cell.state = allowed[current_idx + 1]

	cell.update_visuals()
	_update_joker_count()
	_run_validation()
	_undo_stack.record(_create_snapshot())
	pt_ui.update_playtest_undo_redo_buttons(_undo_stack.can_undo(), _undo_stack.can_redo())

func undo() -> void:
	if not is_active or not _undo_stack.can_undo():
		return
	_apply_snapshot(_undo_stack.undo())
	pt_ui.update_playtest_undo_redo_buttons(_undo_stack.can_undo(), _undo_stack.can_redo())

func redo() -> void:
	if not is_active or not _undo_stack.can_redo():
		return
	_apply_snapshot(_undo_stack.redo())
	pt_ui.update_playtest_undo_redo_buttons(_undo_stack.can_undo(), _undo_stack.can_redo())

func request_hint() -> void:
	if not is_active or solved_solution_reference.is_empty():
		return
	var hint = HintSystem.pick_hint(
		canvas_manager.board_cells,
		canvas_manager.loaded_constraint_pairs,
		solved_solution_reference,
		[],
		Vector2i(canvas_manager.grid_width, canvas_manager.grid_height),
		false
	)
	if hint != null:
		canvas_manager.loaded_constraint_pairs.append(hint)
		canvas_manager.trigger_redraw()
		_run_validation()

func pause_timer() -> void:
	_timer.stop()

func resume_timer() -> void:
	if is_active:
		_timer.start()
		pt_ui.update_playtest_undo_redo_buttons(_undo_stack.can_undo(), _undo_stack.can_redo())
		pt_ui.set_playtest_hint_button_disabled(_get_usable_hints_count() == 0)

func _create_snapshot() -> Dictionary:
	var snap := {}
	for coord in canvas_manager.board_cells:
		var cell = canvas_manager.board_cells[coord]
		snap[coord] = {"state": cell.state, "shifter_direction": cell.shifter_direction}
	return {"cells": snap, "moves": playtest_shifter_moves}

func _apply_snapshot(snap: Dictionary) -> void:
	playtest_shifter_moves = snap["moves"]
	for coord in snap["cells"]:
		var cell = canvas_manager.board_cells[coord]
		cell.state = snap["cells"][coord]["state"]
		cell.shifter_direction = snap["cells"][coord]["shifter_direction"]
		cell.update_visuals()
	_update_joker_count()
	_update_hud()
	canvas_manager.trigger_redraw()
	_run_validation()

func _restore_snapshot(cells_snapshot: Dictionary) -> void:
	for coord in cells_snapshot:
		var cell = canvas_manager.board_cells[coord]
		var restored = cells_snapshot[coord]
		cell.state = restored["state"]
		cell.shifter_direction = restored["shifter_direction"]
		LevelUtils.apply_playtest_cell_locks(cell)
		cell.is_editor_mode = false
		cell.update_visuals()

func _update_joker_count() -> void:
	pt_ui.update_playtest_joker_counter(
		LevelUtils.count_unlocked_jokers(canvas_manager.board_cells),
		playtest_required_jokers
	)

func _update_hud() -> void:
	pt_ui.update_playtest_hud(playtest_time_remaining, playtest_shifter_moves, editor_ui.get_time_limit())

func _get_usable_hints_count() -> int:
	return HintSystem.count_usable_hints(
		canvas_manager.board_cells,
		canvas_manager.loaded_constraint_pairs,
		solved_solution_reference,
		[],
		Vector2i(canvas_manager.grid_width, canvas_manager.grid_height)
	)

func _run_validation() -> void:
	canvas_manager.clear_highlights()
	var results = PuzzleValidator.validate_board(
		canvas_manager.board_cells,
		canvas_manager.cached_lines,
		canvas_manager.loaded_constraint_pairs,
		playtest_required_jokers
	)
	pt_ui.set_playtest_hint_button_disabled(_get_usable_hints_count() == 0)
	pt_ui.update_playtest_undo_redo_buttons(_undo_stack.can_undo(), _undo_stack.can_redo())
	if not results["valid"]:
		pt_ui.update_playtest_status("\n".join(results["errors"]), Color.WHITE)
	else:
		pt_ui.update_playtest_status("Fill the empty spaces on the board.", Color.WHITE)
	if results["valid"] and canvas_manager.is_board_full():
		_trigger_victory()

func _trigger_victory() -> void:
	is_active = false
	_timer.stop()
	pt_ui.update_playtest_status("Puzzle solved!", Color(1.0, 0.84, 0.0))
	pt_ui.display_victory_overlay("GOOD JOB!\nLEVEL IS SOLVABLE")

func _trigger_defeat() -> void:
	is_active = false
	_timer.stop()
	pt_ui.update_playtest_status("Time's up! The puzzle remains unsolved.", Color(1.0, 0.3, 0.3))
	pt_ui.display_victory_overlay("DEFEAT!\nTIME RAN OUT")

func _on_timer_timeout() -> void:
	if not is_active:
		return
	if editor_ui.get_time_limit() == 0:
		return
	playtest_time_remaining -= 1
	_update_hud()
	if playtest_time_remaining <= 0:
		_trigger_defeat()
