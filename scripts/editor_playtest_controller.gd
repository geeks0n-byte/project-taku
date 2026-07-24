class_name EditorPlaytestController
extends Node

var canvas_manager: EditorCanvasManager
var pt_ui: PlaytestUIManager
var editor_ui: EditorUIManager

var is_active: bool = false
var playtest_snapshot: Dictionary = {}
var playtest_start_constraints: Array = []
var playtest_hint_pool: Array = []
var prefer_hidden_hints: bool = false
var solved_solution_reference: Dictionary = {}
var playtest_required_jokers: int = 0
var playtest_required_shifter_moves: int = 0
var playtest_elapsed_seconds: int = 0
var playtest_star_time_limit: int = 0
var playtest_shifter_moves: int = 0
var hints_remaining: int = GameConstants.HINT_LIMIT_UNLIMITED

var _timer: Timer
var _undo_stack := UndoStack.new()

func setup(canvas: EditorCanvasManager, playtest_ui: PlaytestUIManager, editor: EditorUIManager) -> void:
	canvas_manager = canvas
	pt_ui = playtest_ui
	editor_ui = editor
	_undo_stack.max_size = 0

	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)

func enter(current_level_required_jokers: int) -> void:
	is_active = true
	canvas_manager.is_playtesting = true
	playtest_snapshot.clear()

	for coord in canvas_manager.board_cells:
		var cell = canvas_manager.board_cells[coord]
		playtest_snapshot[coord] = {
			"state": cell.state,
			"shifter_direction": cell.shifter_direction
		}
		LevelUtils.apply_playtest_cell_locks(cell)
		cell.is_editor_mode = false
		cell.update_visuals()

	playtest_start_constraints = canvas_manager.loaded_constraint_pairs.duplicate(true)
	prefer_hidden_hints = not editor_ui.is_unique_solution_required()
	playtest_hint_pool = canvas_manager.hidden_constraint_pairs.duplicate(true)

	var built := LevelUtils.build_solve_layout(canvas_manager.board_cells)
	var tiles: Array = editor_ui.get_allowed_tiles()
	var solve_constraints: Array = []

	# Match main.gd hint wiring:
	# - unique: show start constraints; hidden pool feeds fallbacks / rebuild if empty
	# - non-unique: hide constraints and use them only as the hint pool
	if prefer_hidden_hints:
		if playtest_hint_pool.is_empty() and not playtest_start_constraints.is_empty():
			playtest_hint_pool = playtest_start_constraints.duplicate(true)
		canvas_manager.loaded_constraint_pairs.clear()
		solve_constraints = playtest_hint_pool.duplicate(true)
	else:
		solve_constraints = playtest_start_constraints.duplicate(true)

	solved_solution_reference = LevelUtils.solve_reference(
		built["layout"],
		built["empty_cells"],
		canvas_manager.grid_width,
		canvas_manager.grid_height,
		tiles,
		solve_constraints
	)

	# Always ensure a hidden hint pool for unique / loaded boards.
	if playtest_hint_pool.is_empty() and not solved_solution_reference.is_empty():
		playtest_hint_pool = HintSystem.hidden_hints_from_solved(
			solved_solution_reference,
			canvas_manager.loaded_constraint_pairs if not prefer_hidden_hints else [],
			canvas_manager.grid_width,
			canvas_manager.grid_height
		)
	elif playtest_hint_pool.is_empty():
		playtest_hint_pool = HintSystem.rebuild_hidden_hints(
			canvas_manager.board_cells,
			canvas_manager.loaded_constraint_pairs if not prefer_hidden_hints else [],
			canvas_manager.grid_width,
			canvas_manager.grid_height,
			tiles
		)

	if not prefer_hidden_hints:
		# Unique: solve with shown + hidden so the reference matches the intended unique board.
		var full_constraints: Array = playtest_start_constraints.duplicate(true)
		full_constraints.append_array(playtest_hint_pool)
		var full_solved := LevelUtils.solve_reference(
			built["layout"],
			built["empty_cells"],
			canvas_manager.grid_width,
			canvas_manager.grid_height,
			tiles,
			full_constraints
		)
		if not full_solved.is_empty():
			solved_solution_reference = full_solved

	playtest_star_time_limit = editor_ui.get_time_limit()
	playtest_elapsed_seconds = 0
	playtest_shifter_moves = 0
	pt_ui.set_playtest_move_counter_visibility(false)
	playtest_required_shifter_moves = LevelUtils.compute_required_shifter_moves(
		canvas_manager.loaded_shifter_pairs
	)

	var saved_required := current_level_required_jokers
	if saved_required < 0:
		saved_required = mini(canvas_manager.grid_width, canvas_manager.grid_height)
	playtest_required_jokers = maxi(0, saved_required)

	pt_ui.set_playtest_joker_counter_visibility(false)
	_update_joker_count()

	_undo_stack.reset(_create_snapshot())
	hints_remaining = GameConstants.hint_limit_for_difficulty(editor_ui.editor_difficulty)
	pt_ui.toggle_playtest_visibility(true)
	_update_hud()
	_timer.start()
	canvas_manager.trigger_redraw()
	_run_validation()

func exit() -> void:
	is_active = false
	canvas_manager.is_playtesting = false
	_timer.stop()
	if canvas_manager:
		canvas_manager.visible = true
	pt_ui.hide_end_overlays()

	for coord in canvas_manager.board_cells:
		var cell = canvas_manager.board_cells[coord]
		cell.clear_highlight()
		var restored = playtest_snapshot[coord]
		cell.state = restored["state"]
		cell.shifter_direction = restored["shifter_direction"]
		LevelUtils.apply_playtest_cell_locks(cell)
		cell.is_editor_mode = true
		cell.update_visuals()

	canvas_manager.loaded_constraint_pairs = playtest_start_constraints.duplicate(true)
	# Keep grid/constraints above cell controls after playtest.
	canvas_manager.move_child(canvas_manager.grid_drawer, -1)
	canvas_manager.move_child(canvas_manager.constraint_drawer, -1)
	canvas_manager.trigger_redraw()
	pt_ui.toggle_playtest_visibility(false)

func reset() -> void:
	# Allow restart from victory overlay (is_active is false there).
	if not canvas_manager.is_playtesting:
		return
	is_active = true
	_timer.stop()
	if canvas_manager:
		canvas_manager.visible = true
	pt_ui.set_playtest_chrome_visible(true)
	pt_ui.hide_end_overlays()
	_restore_snapshot(playtest_snapshot)
	canvas_manager.loaded_constraint_pairs = playtest_start_constraints.duplicate(true)
	playtest_star_time_limit = editor_ui.get_time_limit()
	playtest_elapsed_seconds = 0
	playtest_shifter_moves = 0
	pt_ui.set_playtest_move_counter_visibility(false)
	pt_ui.set_playtest_joker_counter_visibility(false)
	_update_joker_count()
	_undo_stack.reset(_create_snapshot())
	hints_remaining = GameConstants.hint_limit_for_difficulty(editor_ui.editor_difficulty)
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
				pt_ui.update_playtest_status("ERR_SHIFTER_BLOCKED", Color.WHITE)
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
	if not is_active:
		return
	if hints_remaining == 0:
		_refresh_hint_button()
		return
	var result = HintController.reveal_hint(
		canvas_manager.board_cells,
		canvas_manager.loaded_constraint_pairs,
		solved_solution_reference,
		playtest_hint_pool,
		editor_ui.get_allowed_tiles(),
		prefer_hidden_hints
	)
	solved_solution_reference = result["solved_reference"]
	# Refresh pool once we have a newly solved reference.
	if playtest_hint_pool.is_empty() and not solved_solution_reference.is_empty():
		playtest_hint_pool = HintSystem.hidden_hints_from_solved(
			solved_solution_reference,
			canvas_manager.loaded_constraint_pairs if not prefer_hidden_hints else [],
			canvas_manager.grid_width,
			canvas_manager.grid_height
		)
		if result["hint"] == null:
			result = HintController.reveal_hint(
				canvas_manager.board_cells,
				canvas_manager.loaded_constraint_pairs,
				solved_solution_reference,
				playtest_hint_pool,
				editor_ui.get_allowed_tiles(),
				prefer_hidden_hints
			)
	var hint = result["hint"]
	if hint != null:
		canvas_manager.loaded_constraint_pairs.append(hint)
		# Revealed hints leave the hidden pool.
		for i in range(playtest_hint_pool.size() - 1, -1, -1):
			var pooled = playtest_hint_pool[i]
			if (pooled["a"] == hint["a"] and pooled["b"] == hint["b"]) or (pooled["a"] == hint["b"] and pooled["b"] == hint["a"]):
				playtest_hint_pool.remove_at(i)
		if hints_remaining > 0:
			hints_remaining -= 1
		canvas_manager.trigger_redraw()
		_run_validation()
	else:
		_refresh_hint_button()

func _can_use_hint() -> bool:
	if hints_remaining == 0:
		return false
	return HintController.has_usable_hints(
		canvas_manager.board_cells,
		canvas_manager.loaded_constraint_pairs,
		solved_solution_reference,
		playtest_hint_pool,
		Vector2i(canvas_manager.grid_width, canvas_manager.grid_height),
		prefer_hidden_hints
	)

func _refresh_hint_button() -> void:
	pt_ui.set_playtest_hint_remaining(hints_remaining)
	pt_ui.set_playtest_hint_button_disabled(not _can_use_hint())

func pause_timer() -> void:
	_timer.stop()

func resume_timer() -> void:
	if is_active:
		_timer.start()
		pt_ui.update_playtest_undo_redo_buttons(_undo_stack.can_undo(), _undo_stack.can_redo())
		_refresh_hint_button()

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
		LevelUtils.count_jokers_on_board(canvas_manager.board_cells),
		playtest_required_jokers
	)

func _update_hud() -> void:
	pt_ui.update_playtest_hud(
		playtest_elapsed_seconds,
		playtest_shifter_moves,
		0,
		playtest_required_shifter_moves
	)

func _run_validation() -> void:
	canvas_manager.clear_highlights()
	var results = PuzzleValidator.validate_board(
		canvas_manager.board_cells,
		canvas_manager.cached_lines,
		canvas_manager.loaded_constraint_pairs,
		-1
	)
	_refresh_hint_button()
	pt_ui.update_playtest_undo_redo_buttons(_undo_stack.can_undo(), _undo_stack.can_redo())
	if not results["valid"]:
		pt_ui.update_playtest_status("\n".join(results["errors"]), Color.WHITE)
	else:
		pt_ui.update_playtest_status("MSG_FILL_EMPTY", Color.WHITE)
	if results["valid"] and canvas_manager.is_board_full():
		_trigger_victory()

func _trigger_victory() -> void:
	is_active = false
	_timer.stop()
	if canvas_manager:
		canvas_manager.visible = false
	pt_ui.show_victory_overlay(_build_end_stats())

func _build_end_stats() -> Dictionary:
	var has_shifters := canvas_manager.loaded_shifter_pairs.size() > 0
	var star_result := LevelStars.evaluate(
		playtest_elapsed_seconds,
		playtest_star_time_limit,
		LevelUtils.count_jokers_on_board(canvas_manager.board_cells),
		playtest_required_jokers,
		playtest_shifter_moves,
		playtest_required_shifter_moves,
		has_shifters
	)
	return {
		"star_result": star_result,
		"time_text": LevelStars.format_clock(playtest_elapsed_seconds),
		"green_current": LevelUtils.count_jokers_on_board(canvas_manager.board_cells),
		"green_required": playtest_required_jokers,
		"show_green": playtest_required_jokers > 0,
		"moves": playtest_shifter_moves,
		"moves_required": playtest_required_shifter_moves,
		"show_moves": has_shifters and playtest_required_shifter_moves > 0,
	}

func _on_timer_timeout() -> void:
	if not is_active:
		return
	playtest_elapsed_seconds += 1
	_update_hud()
