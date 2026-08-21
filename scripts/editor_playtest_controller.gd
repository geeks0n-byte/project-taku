# Runs an in-editor playable simulation of the current custom board without
# leaving the editor scene. Handles playtest HUD, validation, hints, timer, and undo.
class_name EditorPlaytestController
extends Node

# Scene collaborators injected by setup().
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
var hints_used: int = 0

var _timer: Timer
var _undo_stack := UndoStack.new()

# Injects dependencies and creates the 1-second timer used by playtest clock.
func setup(canvas: EditorCanvasManager, playtest_ui: PlaytestUIManager, editor: EditorUIManager) -> void:
	canvas_manager = canvas
	pt_ui = playtest_ui
	editor_ui = editor
	_undo_stack.max_size = 0

	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)

# Switches from edit mode to playtest mode, captures a snapshot for restore,
# computes hint reference/hidden pool, and starts timer+validation.
func enter(current_level_required_jokers: int) -> void:
	is_active = true
	canvas_manager.set_playtest_input_mode(true)
	playtest_snapshot.clear()

	for coord in canvas_manager.board_cells:
		var cell = canvas_manager.board_cells[coord]
		playtest_snapshot[coord] = {
			"state": cell.state,
			"shifter_direction": cell.shifter_direction
		}
		LevelUtils.apply_playtest_cell_locks(cell)
		cell.is_editor_mode = false
		cell.allowed_cycle_tiles = LevelUtils.normalize_available_tiles(editor_ui.get_allowed_tiles())
		cell.update_visuals()

	playtest_start_constraints = canvas_manager.loaded_constraint_pairs.duplicate(true)
	prefer_hidden_hints = not editor_ui.is_unique_solution_required()
	playtest_hint_pool = canvas_manager.hidden_constraint_pairs.duplicate(true)

	var built := LevelUtils.build_solve_layout(canvas_manager.board_cells)
	var tiles: Array = LevelUtils.normalize_available_tiles(editor_ui.get_allowed_tiles())
	var solve_constraints: Array = []

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
	hints_used = 0
	pt_ui.toggle_playtest_visibility(true)
	_update_hud()
	_timer.start()
	canvas_manager.trigger_redraw()
	_run_validation()

# Leaves playtest mode and restores original editor board state and constraints.
func exit() -> void:
	is_active = false
	canvas_manager.set_playtest_input_mode(false)
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
	canvas_manager.move_child(canvas_manager.grid_drawer, -1)
	canvas_manager.move_child(canvas_manager.constraint_drawer, -1)
	canvas_manager.trigger_redraw()
	pt_ui.toggle_playtest_visibility(false)

# Resets playtest to the captured start snapshot without leaving playtest mode.
func reset() -> void:
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
	hints_used = 0
	_update_hud()
	_timer.start()
	canvas_manager.trigger_redraw()
	_run_validation()

# Cell already cycled itself on release — refresh HUD / validation / undo.
func handle_cell_played(coord: Vector2i) -> void:
	if not is_active:
		return
	canvas_manager.clear_highlights()
	var cell = canvas_manager.board_cells.get(coord)
	if cell == null or cell.is_locked:
		return
	cell.update_visuals()
	_after_player_board_change()


# Hold-to-clear finished on a player-placed tile.
func handle_cell_hold_cleared(coord: Vector2i) -> void:
	if not is_active:
		return
	canvas_manager.clear_highlights()
	var cell = canvas_manager.board_cells.get(coord)
	if cell == null:
		return
	cell.update_visuals()
	_after_player_board_change()


# Shifter tap — swap active/inactive partner like the main game.
func handle_shifter_toggled(coord: Vector2i) -> void:
	if not is_active:
		return
	canvas_manager.clear_highlights()
	var cell = canvas_manager.board_cells.get(coord)
	if cell == null or cell.is_locked:
		return
	if cell.state != GameConstants.TileState.SHIFTER:
		return
	var partner_coord = coord + cell.shifter_direction
	if canvas_manager.board_cells.has(partner_coord):
		var partner = canvas_manager.board_cells[partner_coord]
		if partner.state == GameConstants.TileState.SHIFTER:
			partner.set_error_highlight()
			cell.play_blocked_shake()
			pt_ui.update_playtest_status("ERR_SHIFTER_BLOCKED", Color.WHITE)
			return
		cell.state = GameConstants.TileState.EMPTY
		cell.shifter_direction = Vector2i.ZERO
		partner.state = GameConstants.TileState.SHIFTER
		partner.shifter_direction = coord - partner_coord
		partner.update_visuals()
		cell.update_visuals()
		playtest_shifter_moves += 1
		if UiSfx:
			UiSfx.play_click()
	_after_player_board_change()


func _after_player_board_change() -> void:
	_update_hud()
	_update_joker_count()
	_run_validation()
	_undo_stack.record(_create_snapshot())
	pt_ui.update_playtest_undo_redo_buttons(_undo_stack.can_undo(), _undo_stack.can_redo())
	canvas_manager.trigger_redraw()


# Legacy press-on-interceptor path (unused while playtest input mode is on).
func handle_cell_click(coord: Vector2i) -> void:
	handle_cell_played(coord)

# Undo/redo actions inside playtest mode.
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

# Reveals one hidden hint constraint and updates counters/validation.
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
		for i in range(playtest_hint_pool.size() - 1, -1, -1):
			var pooled = playtest_hint_pool[i]
			if (pooled["a"] == hint["a"] and pooled["b"] == hint["b"]) or (pooled["a"] == hint["b"] and pooled["b"] == hint["a"]):
				playtest_hint_pool.remove_at(i)
		hints_used += 1
		if hints_remaining > 0:
			hints_remaining -= 1
		canvas_manager.trigger_redraw()
		_run_validation()
	else:
		_refresh_hint_button()

# Hint availability check for playtest HUD button state.
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

# Used when opening pause/settings overlays during playtest.
func pause_timer() -> void:
	_timer.stop()

func resume_timer() -> void:
	if is_active:
		_timer.start()
		pt_ui.update_playtest_undo_redo_buttons(_undo_stack.can_undo(), _undo_stack.can_redo())
		_refresh_hint_button()

# Captures board cells + shifter move count for undo stack.
func _create_snapshot() -> Dictionary:
	var snap := {}
	for coord in canvas_manager.board_cells:
		var cell = canvas_manager.board_cells[coord]
		snap[coord] = {"state": cell.state, "shifter_direction": cell.shifter_direction}
	return {"cells": snap, "moves": playtest_shifter_moves}

# Restores an undo snapshot and reruns validation.
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

# Restores the original pre-playtest editor snapshot.
func _restore_snapshot(cells_snapshot: Dictionary) -> void:
	for coord in cells_snapshot:
		var cell = canvas_manager.board_cells[coord]
		var restored = cells_snapshot[coord]
		cell.state = restored["state"]
		cell.shifter_direction = restored["shifter_direction"]
		LevelUtils.apply_playtest_cell_locks(cell)
		cell.is_editor_mode = false
		cell.update_visuals()

# Syncs green-tile progress counter in playtest HUD.
func _update_joker_count() -> void:
	pt_ui.update_playtest_joker_counter(
		LevelUtils.count_jokers_on_board(canvas_manager.board_cells),
		playtest_required_jokers
	)

# Syncs timer/move counters in playtest HUD.
func _update_hud() -> void:
	pt_ui.update_playtest_hud(
		playtest_elapsed_seconds,
		playtest_shifter_moves,
		0,
		playtest_required_shifter_moves
	)

# Validates board and either shows error status or triggers playtest victory.
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

# Ends playtest run and opens the playtest victory overlay with preview texture.
func _trigger_victory() -> void:
	is_active = false
	_timer.stop()
	var solved_preview := LevelPreview.make_texture_from_board_cells(canvas_manager.board_cells, 320)
	if canvas_manager:
		canvas_manager.visible = false
	var stats := _build_end_stats()
	stats["solved_preview"] = solved_preview
	pt_ui.show_victory_overlay(stats)

# Builds the stats payload consumed by PlaytestUIManager victory overlay.
func _build_end_stats() -> Dictionary:
	var has_shifters := canvas_manager.loaded_shifter_pairs.size() > 0
	HudLayout.begin_force_pixel_font()
	var star_result := LevelStars.evaluate(
		playtest_elapsed_seconds,
		playtest_star_time_limit,
		hints_used,
		0,
		0,
		false,
		true
	)
	HudLayout.end_force_pixel_font()
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

# 1-second playtest clock tick.
func _on_timer_timeout() -> void:
	if not is_active:
		return
	playtest_elapsed_seconds += 1
	_update_hud()
