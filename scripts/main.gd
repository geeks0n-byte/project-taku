# Root game scene script. Owns board, HUD, and level progression logic.
# Delegates UI to UIManager and board logic to BoardManager; wires them together.
extends Node2D

# Levels loaded from the campaign directory.
var core_levels: Array[LevelData] = []
# Levels from user:// (editor-created / imported).
var custom_levels: Array[LevelData] = []
# The active level list (either core_levels or custom_levels depending on context).
var levels: Array[LevelData] = []

@onready var ui_manager: UIManager = $UIManager
@onready var board_manager: BoardManager = $BoardManager
@onready var timer_node: Timer = $Timer
@onready var pause_menu = $PauseMenuLayer/PauseMenu
@onready var options_menu = $OptionsMenu
@onready var hud_layer = $HUDLayer

# Time limit in seconds for 3-star completion; 0 means untimed (tutorial levels).
var star_time_limit: int = 0
var elapsed_seconds: int = 0
var shifter_move_count: int = 0
var required_shifter_moves: int = 0
var _has_shifters: bool = false
# True for campaign tutorial levels — disables timer, move counter, and hint quota.
var _challenges_disabled: bool = false
var is_game_active: bool = true
var is_paused: bool = false
var current_level_index: int = 0
# A fully solved copy of the board layout, used as reference for hint generation.
var solved_solution_reference: Dictionary = {}
# Constraint pairs not shown to the player that can be revealed as hints.
var hidden_reference_constraints: Array = []
# When true, hints are drawn from hidden_reference_constraints instead of explicit ones.
var prefer_hidden_hints: bool = false
var required_jokers: int = 0
var hints_remaining: int = GameConstants.HINT_LIMIT_UNLIMITED
var hints_used: int = 0
var game_undo := UndoStack.new()
# Guards against recording multiple snapshots for a single cell interaction.
var _is_recording_action: bool = false
# True while a fullscreen ad is visible so the timer stays paused.
var _timer_paused_for_ad: bool = false
var _loading_overlay: LoadingOverlay
# Prevents input and state changes while async board generation is in progress.
var _is_generating_board: bool = false
var tutorial_director: TutorialDirector
# The layout and tile data used for the current run (saved for session autosave).
var _run_layout: Dictionary = {}
var _run_shifter_pairs: Array = []
var _run_available_tiles: Array = []
# When true, cancelling a reset from inside the pause menu returns to the pause menu.
var _reset_confirm_return_to_pause: bool = false
# True when NEW PUZZLE confirm was opened from the session-resume prompt.
var _reset_confirm_from_session_resume: bool = false

# Returns true when a level lives in the campaign tutorials directory.
# Tutorial levels disable the timer, move counter, and hint quota.
func _is_campaign_tutorial(level: LevelData) -> bool:
	if level == null:
		return false
	return String(level.resource_path).begins_with(GameConstants.CAMPAIGN_TUTORIALS_DIR)

# Maps a level's resource path to one of the PuzzleGenerator.Difficulty values
# based on which subdirectory it lives in (easy/medium/hard).
func _difficulty_for_level(level: LevelData) -> int:
	if level == null:
		return PuzzleGenerator.Difficulty.MEDIUM
	var path := String(level.resource_path)
	if path.begins_with(GameConstants.CAMPAIGN_EASY_DIR):
		return PuzzleGenerator.Difficulty.EASY
	if path.begins_with(GameConstants.CAMPAIGN_HARD_DIR):
		return PuzzleGenerator.Difficulty.HARD
	if path.begins_with(GameConstants.CAMPAIGN_MEDIUM_DIR):
		return PuzzleGenerator.Difficulty.MEDIUM
	return PuzzleGenerator.Difficulty.MEDIUM

# Sets hints_remaining based on level type. Tutorials get unlimited hints;
# campaign levels get a difficulty-based quota.
func _reset_hint_quota(level: LevelData) -> void:
	if _is_campaign_tutorial(level):
		hints_remaining = GameConstants.HINT_LIMIT_UNLIMITED
	else:
		hints_remaining = GameConstants.hint_limit_for_difficulty(_difficulty_for_level(level))

# Returns true when the player is allowed to use a hint right now:
# the board has a cell that can actually be hinted, the quota isn't zero,
# OR an ad-rewarded hint could be offered.
func _can_use_hint() -> bool:
	# Tutorial boards are rebuilt teaching layouts; campaign constraint hints
	# don't match them and can brick the last free-solve cells.
	if tutorial_director and tutorial_director.is_active():
		return false
	var board_ok := HintController.has_usable_hints(
		board_manager.board_cells if board_manager else {},
		board_manager.active_constraint_pairs if board_manager else [],
		solved_solution_reference,
		hidden_reference_constraints,
		Vector2i.ZERO,
		prefer_hidden_hints
	)
	if not board_ok:
		return false
	if hints_remaining != 0:
		return true
	return AdsManager != null and AdsManager.can_offer_rewarded_hint()

# Pre-warms the rewarded ad when hints are almost exhausted, then updates the
# hint button's icon and enabled state through UIManager.
func _refresh_hint_button() -> void:
	if AdsManager and hints_remaining <= 1:
		AdsManager.warm_rewarded_hint()
	if ui_manager:
		ui_manager.set_hint_remaining(hints_remaining)
		ui_manager.set_hint_button_disabled(not _can_use_hint())

# Bootstraps ads, tutorial director, level lists, and first level/session entry.
func _ready():
	if AdsManager:
		AdsManager.show_menu_banner()
		AdsManager.warm_rewarded_hint()
		if not AdsManager.fullscreen_ad_started.is_connected(_on_fullscreen_ad_started):
			AdsManager.fullscreen_ad_started.connect(_on_fullscreen_ad_started)
		if not AdsManager.fullscreen_ad_finished.is_connected(_on_fullscreen_ad_finished):
			AdsManager.fullscreen_ad_finished.connect(_on_fullscreen_ad_finished)
	_loading_overlay = LoadingOverlay.new()
	add_child(_loading_overlay)
	tutorial_director = TutorialDirector.new()
	tutorial_director.name = "TutorialDirector"
	add_child(tutorial_director)
	_load_all_levels_from_storage()
	_intercept_global_selection()
	if levels.is_empty():
		return
	if ui_manager and board_manager:
		ui_manager.setup_ui(GlobalGameManager.debug_tools_enabled, GameConstants.CELL_SIZE)
		tutorial_director.setup(board_manager, ui_manager)
		_bind_submanager_signals()
	_apply_debug_tools_visibility()
	if timer_node:
		timer_node.timeout.connect(_on_timer_timeout)
	_begin_level_entry()

# Pauses the game timer while a fullscreen ad is displayed.
# The timer only stops if the game is actually running and not already paused.
func _on_fullscreen_ad_started() -> void:
	if timer_node == null or _challenges_disabled:
		return
	if not is_game_active or is_paused:
		return
	if timer_node.is_stopped():
		return
	_timer_paused_for_ad = true
	timer_node.stop()

# Resumes the timer after an ad if it was paused by _on_fullscreen_ad_started.
func _on_fullscreen_ad_finished() -> void:
	if not _timer_paused_for_ad:
		return
	_timer_paused_for_ad = false
	if timer_node and is_game_active and not is_paused and not _challenges_disabled:
		timer_node.start()

# Routes OS back-button notifications into our stack-aware back handler.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_system_back()

# Handles the Android back button with a priority stack: options menu → HTP →
# reset confirm → resume prompt → victory → pause → in-game pause → main menu.
func _on_system_back() -> void:
	if GlobalGameManager == null or not GlobalGameManager.consume_system_back():
		return
	if _is_generating_board or (_loading_overlay and _loading_overlay.is_busy()):
		return
	if options_menu and options_menu.visible:
		if options_menu.has_method("handle_system_back"):
			options_menu.handle_system_back()
		elif options_menu.has_method("hide_menu"):
			options_menu.hide_menu()
		return
	if ui_manager and ui_manager.how_to_play_container and ui_manager.how_to_play_container.visible:
		_on_resume()
		return
	if ui_manager and ui_manager.reset_confirm_panel and ui_manager.reset_confirm_panel.visible:
		ui_manager.hide_reset_confirm()
		_on_reset_cancelled()
		return
	if ui_manager and ui_manager.resume_panel and ui_manager.resume_panel.visible:
		_on_session_back()
		return
	if ui_manager and ui_manager.victory_panel and ui_manager.victory_panel.visible:
		_on_quit_to_menu()
		return
	if is_paused:
		_on_resume()
		return
	if is_game_active:
		_on_pause()
		return
	_on_quit_to_menu()

# Wires UIManager and BoardManager signals to main.gd handlers.
# Called once after both managers are confirmed non-null.
func _bind_submanager_signals():
	if not ui_manager or not board_manager:
		return
	ui_manager.pause_requested.connect(_on_pause)
	ui_manager.reset_requested.connect(_on_reset)
	ui_manager.reset_confirmed.connect(_on_reset_confirmed)
	ui_manager.reset_cancelled.connect(_on_reset_cancelled)
	ui_manager.how_to_play_requested.connect(_on_how_to_play)
	ui_manager.resume_from_tutorial_requested.connect(_on_resume)
	ui_manager.hint_requested.connect(_on_hint_requested)
	ui_manager.undo_requested.connect(_on_undo_requested)
	ui_manager.redo_requested.connect(_on_redo_requested)
	board_manager.cell_changed.connect(_on_cell_changed)
	board_manager.cell_hold_cleared.connect(_on_cell_changed)
	board_manager.shifter_move_made.connect(_on_shifter_move_made)
	board_manager.invalid_move_attempted.connect(_on_invalid_move_attempted)
	if tutorial_director and not tutorial_director.finished.is_connected(_on_tutorial_finished):
		tutorial_director.finished.connect(_on_tutorial_finished)
	if tutorial_director and not tutorial_director.tools_unlocked.is_connected(_on_tutorial_tools_unlocked):
		tutorial_director.tools_unlocked.connect(_on_tutorial_tools_unlocked)
	if tutorial_director and not tutorial_director.board_layout_changed.is_connected(_on_tutorial_board_layout_changed):
		tutorial_director.board_layout_changed.connect(_on_tutorial_board_layout_changed)
	if pause_menu:
		pause_menu.resume_pressed.connect(_on_resume)
		pause_menu.restart_pressed.connect(_on_restart_level)
		pause_menu.settings_pressed.connect(_on_pause_settings)
		pause_menu.level_select_pressed.connect(_on_quit_to_level_select)
		pause_menu.auto_win_pressed.connect(_on_auto_win)
		pause_menu.quit_pressed.connect(_on_quit_to_menu)
	if options_menu:
		options_menu.back_requested.connect(_on_options_back_from_pause)
	ui_manager.next_level_requested.connect(_on_next_level)
	ui_manager.play_again_requested.connect(_on_play_again)
	ui_manager.session_continue_requested.connect(_on_session_continue)
	ui_manager.session_restart_requested.connect(_on_session_restart)
	ui_manager.session_back_requested.connect(_on_session_back)
	ui_manager.locale_refresh_requested.connect(_on_locale_refresh)

# Shows error feedback when the player attempts an illegal move.
# Gives the tutorial director first refusal so it can override the message.
func _on_invalid_move_attempted(msg: String):
	if not is_game_active or is_paused:
		return
	if tutorial_director and tutorial_director.is_active():
		if tutorial_director.on_invalid_move(msg):
			return
	var results = PuzzleValidator.validate_board(
		board_manager.board_cells,
		board_manager.cached_lines,
		board_manager.active_constraint_pairs,
		-1
	)
	var combined_errors = results["errors"].duplicate()
	if not combined_errors.has(msg):
		combined_errors.append(msg)
	ui_manager.show_status_errors(combined_errors)
	board_manager.refresh_error_bridges()

# Scans the campaign and user:// directories and populates core_levels/custom_levels.
# Called once in _ready before level selection logic runs.
func _load_all_levels_from_storage() -> void:
	core_levels.clear()
	custom_levels.clear()
	levels.clear()
	var core_paths = LevelUtils.scan_campaign_levels()
	var custom_paths = LevelUtils.scan_directory(GameConstants.DEV_LEVELS_DIR)
	LevelUtils.sort_level_paths(custom_paths)
	for path in core_paths:
		var res = load(path)
		if res and res is LevelData:
			core_levels.append(res)
	for path in custom_paths:
		var res = load(path)
		if res and res is LevelData:
			custom_levels.append(res)

# Checks GlobalGameManager for a level picked from the level-select screen,
# a saved session to resume, or falls back to the highest unlocked level.
# Sets current_level_index and populates the levels array accordingly.
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
		return

	# Main-menu RESUME: open the level from the saved session, not highest unlocked.
	if SaveManager and SaveManager.has_session():
		var session_path := str(SaveManager.session_data.get("level_path", ""))
		if not session_path.is_empty() and ResourceLoader.exists(session_path):
			var session_level := load(session_path) as LevelData
			if session_level:
				levels = (
					custom_levels.duplicate()
					if session_path.begins_with("user://")
					else core_levels.duplicate()
				)
				var session_idx := -1
				for i in range(levels.size()):
					if levels[i].resource_path == session_path:
						session_idx = i
						break
				if session_idx != -1:
					current_level_index = session_idx
					return
				levels.append(session_level)
				current_level_index = levels.size() - 1
				return

	levels = core_levels.duplicate()
	var target_level = SaveManager.max_unlocked_level
	var unlocked_idx = -1
	for i in range(levels.size()):
		if levels[i].level_number == target_level:
			unlocked_idx = i
			break
	if unlocked_idx != -1:
		current_level_index = unlocked_idx
	else:
		current_level_index = maxi(0, levels.size() - 1)

# Main board setup function. For tutorial levels uses the stored layout directly;
# for generated levels runs PuzzleGenerator asynchronously on the loading overlay.
# Solves a reference solution, positions the board, then starts the timer.
func generate_board():
	if current_level_index >= levels.size():
		return
	if _is_generating_board:
		return
	_is_generating_board = true

	if tutorial_director:
		tutorial_director.stop()
	ui_manager.set_overlays_hidden()
	ui_manager.set_status_visible(false)
	ui_manager.set_top_bar_visible(false)
	if pause_menu:
		pause_menu.hide()
	if options_menu:
		options_menu.visible = false
	if board_manager:
		board_manager.visible = true
	if hud_layer:
		hud_layer.visible = true
	is_game_active = true
	is_paused = false
	_timer_paused_for_ad = false

	var current_level_resource = levels[current_level_index]
	var is_custom = current_level_resource.resource_path.begins_with("user://")
	var is_unique_solution: bool = true
	if current_level_resource is LevelData:
		is_unique_solution = current_level_resource.is_unique_solution
	prefer_hidden_hints = not is_unique_solution
	var dims := LevelUtils.get_dimensions_from_level(current_level_resource)

	_challenges_disabled = _is_campaign_tutorial(current_level_resource)
	star_time_limit = 0 if _challenges_disabled else int(
		current_level_resource.get("time_limit") if "time_limit" in current_level_resource else 0
	)
	_reset_hint_quota(current_level_resource)
	if AdsManager:
		AdsManager.warm_rewarded_hint()
	elapsed_seconds = 0
	shifter_move_count = 0
	hints_used = 0
	required_shifter_moves = 0
	required_jokers = 0
	_has_shifters = false
	ui_manager.set_joker_counter_visibility(false)
	ui_manager.set_move_counter_visibility(false)
	ui_manager.set_timer_visibility(not _challenges_disabled)
	_update_timer_display()
	if timer_node:
		timer_node.stop()
	board_manager.process_mode = Node.PROCESS_MODE_INHERIT

	var tiles_list: Array = LevelUtils.normalize_available_tiles(
		current_level_resource.available_tiles if (
			"available_tiles" in current_level_resource
			and current_level_resource.available_tiles.size() > 0
		) else [0, 1, 2]
	)

	var s_pairs := LevelUtils.get_shifter_pairs(current_level_resource)
	var solve_constraints: Array = []
	var c_pairs: Array = []
	var saved_constraints: Array = []
	if "constraint_pairs" in current_level_resource:
		saved_constraints = current_level_resource.constraint_pairs.duplicate(true)
		solve_constraints = saved_constraints.duplicate(true)
		if is_unique_solution:
			c_pairs = saved_constraints.duplicate(true)
			hidden_reference_constraints = []
		else:
			hidden_reference_constraints = saved_constraints.duplicate(true)
	else:
		hidden_reference_constraints = []

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
		_has_shifters = final_s_pairs.size() > 0
		if _challenges_disabled:
			required_jokers = 0
			required_shifter_moves = 0
		else:
			var saved_req = current_level_resource.get("required_jokers") if "required_jokers" in current_level_resource else -1
			required_jokers = LevelUtils.resolve_required_jokers(saved_req, dims.x, dims.y)
			if current_level_resource is LevelData:
				required_shifter_moves = current_level_resource.required_shifter_moves
			if required_shifter_moves <= 0 and _has_shifters:
				required_shifter_moves = LevelUtils.compute_required_shifter_moves(final_s_pairs)
		solved_solution_reference = _solve_layout(fresh_layout, tiles_list, solve_constraints, dims, final_s_pairs)
	else:
		var wall_layout: Dictionary = base_layout
		var keep_walls := true
		if current_level_resource is LevelData:
			keep_walls = current_level_resource.keep_walls
		var gen_difficulty := _difficulty_for_level(current_level_resource)
		var generated: Variant = await _loading_overlay.run_async(self, func():
			var result := {}
			var attempts := 25 if is_unique_solution else 10
			for attempt in range(attempts):
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
		if not is_instance_valid(self) or not is_inside_tree():
			return
		if typeof(generated) != TYPE_DICTIONARY or (generated as Dictionary).is_empty():
			_is_generating_board = false
			is_game_active = false
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
			hidden_reference_constraints = gen_hidden
		else:
			final_c_pairs = []
			solve_constraints = gen_hidden.duplicate(true)
			hidden_reference_constraints = gen_hidden
		_has_shifters = final_s_pairs.size() > 0
		required_jokers = maxi(0, int(generated_dict.get("total_jokers", 0)))
		required_shifter_moves = maxi(0, int(generated_dict.get("required_shifter_moves", 0)))
		if required_shifter_moves <= 0 and _has_shifters:
			required_shifter_moves = LevelUtils.compute_required_shifter_moves(final_s_pairs)
		solved_solution_reference = _solve_layout(fresh_layout, tiles_list, solve_constraints, dims, final_s_pairs)

	ui_manager.set_joker_counter_visibility(false)
	ui_manager.set_move_counter_visibility(false)
	var is_tutorial := _is_campaign_tutorial(current_level_resource)
	ui_manager.set_reset_mode_restart(is_tutorial)
	ui_manager.display_level(
		LevelUtils.get_display_level_number(current_level_resource),
		is_custom,
		is_tutorial
	)
	_run_layout = fresh_layout.duplicate(true)
	_run_shifter_pairs = final_s_pairs.duplicate(true)
	_run_available_tiles = tiles_list.duplicate()
	board_manager.build_grid(fresh_layout, tiles_list, final_s_pairs, final_c_pairs)

	if is_unique_solution and hidden_reference_constraints.is_empty() and not solved_solution_reference.is_empty():
		hidden_reference_constraints = HintSystem.hidden_hints_from_solved(
			solved_solution_reference,
			board_manager.active_constraint_pairs,
			dims.x,
			dims.y
		)
	if solved_solution_reference.is_empty():
		solved_solution_reference = HintSystem.attempt_dynamic_solve(
			board_manager.board_cells,
			board_manager.active_constraint_pairs,
			tiles_list
		)
		if is_unique_solution and hidden_reference_constraints.is_empty() and not solved_solution_reference.is_empty():
			hidden_reference_constraints = HintSystem.hidden_hints_from_solved(
				solved_solution_reference,
				board_manager.active_constraint_pairs,
				dims.x,
				dims.y
			)
	_update_joker_count()

	var centered_board_y := LevelUtils.center_board_y(dims.y, GameConstants.CELL_SIZE, get_viewport_rect().size.y)
	board_manager.position.y = centered_board_y
	ui_manager.update_dynamic_layout(centered_board_y, dims.y * GameConstants.CELL_SIZE)
	game_undo.reset(_create_game_snapshot())
	_is_generating_board = false
	ui_manager.set_top_bar_visible(true)
	_start_tutorial_if_needed(tiles_list)
	_run_validation_pass()
	if timer_node and is_game_active and not _challenges_disabled:
		timer_node.start()

# Looks up a tutorial script for the current level and starts TutorialDirector
# if one exists. No-ops silently when the level has no associated script.
func _start_tutorial_if_needed(tiles_list: Array) -> void:
	if not tutorial_director:
		return
	if levels.is_empty() or current_level_index < 0 or current_level_index >= levels.size():
		return
	var level: LevelData = levels[current_level_index]
	if not _is_campaign_tutorial(level):
		return
	var script_id := TutorialScripts.script_id_from_path(String(level.resource_path))
	if not TutorialScripts.has_script(script_id):
		return
	tutorial_director.start(script_id, tiles_list)
	tutorial_director.refresh_tool_gates()

func _on_tutorial_finished() -> void:
	if not is_game_active or is_paused:
		return
	ui_manager.update_undo_redo_buttons(game_undo.can_undo(), game_undo.can_redo())
	_run_validation_pass()

func _on_tutorial_tools_unlocked() -> void:
	if not is_game_active or is_paused:
		return
	ui_manager.update_undo_redo_buttons(game_undo.can_undo(), game_undo.can_redo())
	_refresh_hint_button()

# Fired when TutorialDirector changes the board layout (e.g. reveals locked cells).
# Resets the undo stack so the player can't undo past the tutorial modification.
func _on_tutorial_board_layout_changed() -> void:
	game_undo.reset(_create_game_snapshot())
	var dims := LevelUtils.get_dimensions_from_cells(board_manager.board_cells)
	var centered_board_y := LevelUtils.center_board_y(
		dims.y, GameConstants.CELL_SIZE, get_viewport_rect().size.y
	)
	board_manager.position.y = centered_board_y
	if ui_manager:
		ui_manager.update_dynamic_layout(centered_board_y, dims.y * GameConstants.CELL_SIZE)
	if ui_manager:
		ui_manager.update_undo_redo_buttons(game_undo.can_undo(), game_undo.can_redo())

# Builds a flattened layout with shifters merged in and runs the backtracking solver.
# Returns the solved cell-state dictionary used as the hint reference.
func _solve_layout(
	layout: Dictionary,
	tiles_list: Array,
	constraints: Array,
	dims: Vector2i,
	shifter_pairs: Array = []
) -> Dictionary:
	var solve_layout := LevelUtils.layout_with_shifters_for_solve(layout, shifter_pairs)
	var empty_cells: Array = LevelUtils.empty_cells_from_layout(solve_layout)
	return LevelUtils.solve_reference(solve_layout, empty_cells, dims.x, dims.y, tiles_list, constraints)

# Captures the current cell states and shifter-move count into a snapshot
# dictionary suitable for UndoStack and session serialisation.
func _create_game_snapshot() -> Dictionary:
	var snap := {}
	for coord in board_manager.board_cells:
		var cell = board_manager.board_cells[coord]
		snap[coord] = {"state": cell.state, "shifter_direction": cell.shifter_direction}
	return {
		"cells": snap,
		"moves": shifter_move_count
	}

# Restores cell states and move count from a snapshot, updates visuals, and
# re-runs validation so the status label reflects the restored state.
func _apply_game_snapshot(snap: Dictionary):
	shifter_move_count = snap["moves"]
	ui_manager.update_move_counter(shifter_move_count, required_shifter_moves)
	for coord in snap["cells"]:
		var cell = board_manager.board_cells[coord]
		cell.state = snap["cells"][coord]["state"]
		cell.shifter_direction = snap["cells"][coord]["shifter_direction"]
		cell.update_visuals()
	_update_joker_count()
	board_manager.trigger_redraw()
	_run_validation_pass()

# Records the current state to the undo stack after the frame settles (deferred call).
# Clears the recording guard so the next interaction can schedule another record.
func _record_game_action():
	_is_recording_action = false
	game_undo.record(_create_game_snapshot())
	ui_manager.update_undo_redo_buttons(game_undo.can_undo(), game_undo.can_redo())
	_autosave_session()

# Gives the tutorial director first refusal on the undo action (it may intercept
# to show guidance), then pops the undo stack and autosaves.
func _on_undo_requested():
	if tutorial_director and tutorial_director.consume_hud_action("undo"):
		return
	if not is_game_active or is_paused or not game_undo.can_undo():
		return
	if tutorial_director and tutorial_director.is_active():
		return
	_apply_game_snapshot(game_undo.undo())
	ui_manager.update_undo_redo_buttons(game_undo.can_undo(), game_undo.can_redo())
	_autosave_session()

func _on_redo_requested():
	if tutorial_director and tutorial_director.consume_hud_action("redo"):
		return
	if not is_game_active or is_paused or not game_undo.can_redo():
		return
	if tutorial_director and tutorial_director.is_active():
		return
	_apply_game_snapshot(game_undo.redo())
	ui_manager.update_undo_redo_buttons(game_undo.can_undo(), game_undo.can_redo())
	_autosave_session()

func _update_joker_count():
	ui_manager.update_joker_counter(
		LevelUtils.count_jokers_on_board(board_manager.board_cells),
		required_jokers
	)

# Hint button flow: consume tutorial action, spend quota, or attempt rewarded ad.
func _on_hint_requested():
	if tutorial_director and tutorial_director.consume_hud_action("hint"):
		return
	if not is_game_active or is_paused:
		return
	if hints_remaining == 0:
		if AdsManager == null:
			if ui_manager:
				ui_manager.show_status_errors(["ERROR_AD_HINT_UNAVAILABLE"])
			_refresh_hint_button()
			return
		AdsManager.warm_rewarded_hint()
		if AdsManager.show_rewarded_for_hint(_on_rewarded_hint_earned):
			if ui_manager and not AdsManager.is_rewarded_hint_ready() and AdsManager.is_rewarded_hint_loading():
				ui_manager.show_status_errors(["ERROR_AD_HINT_LOADING"])
			return
		if ui_manager:
			ui_manager.show_status_errors(["ERROR_AD_HINT_UNAVAILABLE"])
		_refresh_hint_button()
		return
	_apply_hint()

# Reward callback grants a small hint bundle, then immediately applies one hint.
func _on_rewarded_hint_earned() -> void:
	hints_remaining = GameConstants.HINTS_FROM_REWARDED_AD
	if AdsManager:
		AdsManager.warm_rewarded_hint()
	_apply_hint()

# Reveals one constraint hint, updates pools/counters, redraws, validates, autosaves.
func _apply_hint() -> void:
	if not is_game_active or is_paused:
		return
	if tutorial_director and tutorial_director.is_active():
		return
	if not board_manager or levels.is_empty() or current_level_index < 0:
		return
	var current_res = levels[current_level_index]
	var tiles_list: Array = LevelUtils.normalize_available_tiles(
		current_res.available_tiles if current_res.available_tiles.size() > 0 else [0, 1, 2]
	)
	if solved_solution_reference.is_empty():
		solved_solution_reference = HintSystem.attempt_dynamic_solve(
			board_manager.board_cells,
			board_manager.active_constraint_pairs,
			tiles_list
		)
	if hidden_reference_constraints.is_empty() and not solved_solution_reference.is_empty():
		var dims := LevelUtils.get_dimensions_from_cells(board_manager.board_cells)
		hidden_reference_constraints = HintSystem.hidden_hints_from_solved(
			solved_solution_reference,
			board_manager.active_constraint_pairs if not prefer_hidden_hints else [],
			dims.x,
			dims.y
		)
	var result = HintController.reveal_hint(
		board_manager.board_cells,
		board_manager.active_constraint_pairs,
		solved_solution_reference,
		hidden_reference_constraints,
		tiles_list,
		prefer_hidden_hints
	)
	solved_solution_reference = result["solved_reference"]
	var hint = result["hint"]
	if hint != null:
		board_manager.active_constraint_pairs.append(hint)
		for i in range(hidden_reference_constraints.size() - 1, -1, -1):
			var pooled = hidden_reference_constraints[i]
			if (pooled["a"] == hint["a"] and pooled["b"] == hint["b"]) or (pooled["a"] == hint["b"] and pooled["b"] == hint["a"]):
				hidden_reference_constraints.remove_at(i)
		hints_used += 1
		if hints_remaining > 0:
			hints_remaining -= 1
		board_manager.trigger_redraw()
		_run_validation_pass()
		_autosave_session()
		_refresh_hint_button()
	else:
		ui_manager.show_status_errors(["ERROR_NO_HINTS"])
		_refresh_hint_button()

# Responds to any cell change: updates counters, tutorial hooks, validation, undo record.
func _on_cell_changed(_coord: Vector2i):
	if not is_game_active or is_paused:
		return
	_update_joker_count()
	if tutorial_director and tutorial_director.is_active():
		tutorial_director.on_board_changed(_coord)
	_run_validation_pass()
	if not _is_recording_action:
		_is_recording_action = true
		call_deferred("_record_game_action")

# Special handler for shifter swaps so move-goal counters stay accurate.
func _on_shifter_move_made():
	if not is_game_active or is_paused:
		return
	shifter_move_count += 1
	ui_manager.update_move_counter(shifter_move_count, required_shifter_moves)
	if tutorial_director and tutorial_director.is_active():
		tutorial_director.on_board_changed()
	if not _is_recording_action:
		_is_recording_action = true
		call_deferred("_record_game_action")

# Central validation pass: recompute errors, update tutorial gates/hint state,
# and trigger victory once board is valid and full.
func _run_validation_pass():
	board_manager.clear_highlights()
	var results = PuzzleValidator.validate_board(
		board_manager.board_cells,
		board_manager.cached_lines,
		board_manager.active_constraint_pairs,
		-1
	)
	var tutorial_running := tutorial_director != null and tutorial_director.is_active()
	if tutorial_running:
		tutorial_director.refresh_tool_gates()
	else:
		_refresh_hint_button()
		ui_manager.update_undo_redo_buttons(game_undo.can_undo(), game_undo.can_redo())
	if not results["valid"]:
		var suppress_tutorial_errors := (
			tutorial_running
			and tutorial_director
			and tutorial_director.suppress_validation_errors()
		)
		if not suppress_tutorial_errors:
			ui_manager.show_status_errors(results["errors"])
			board_manager.refresh_error_bridges()
	else:
		ui_manager.show_status_valid()
	if tutorial_running:
		tutorial_director.on_validation_result(results)
	if results["valid"] and board_manager.is_board_full():
		if tutorial_running:
			tutorial_director.on_board_solved()
		else:
			trigger_victory()

# Ends the run, computes stars/unlocks, records ad cadence, and opens victory UI.
func trigger_victory():
	if tutorial_director:
		tutorial_director.stop()
	is_game_active = false
	_timer_paused_for_ad = false
	if timer_node:
		timer_node.stop()
	board_manager.process_mode = Node.PROCESS_MODE_DISABLED
	SaveManager.clear_session()
	var is_custom = levels[current_level_index].resource_path.begins_with("user://")
	var is_last = current_level_index >= levels.size() - 1
	var display_num = LevelUtils.get_display_level_number(levels[current_level_index])
	var unlock_num = levels[current_level_index].level_number
	var time_limit := 0 if _challenges_disabled else star_time_limit
	var star_result := LevelStars.evaluate(
		elapsed_seconds,
		time_limit,
		0 if _challenges_disabled else hints_used
	)
	if _challenges_disabled:
		star_result["untimed"] = true
		star_result["goals"] = []
		star_result["total_count"] = 0
		star_result["earned_count"] = 0
	var won_tutorial := _is_campaign_tutorial(levels[current_level_index])
	if not is_custom:
		if won_tutorial:
			SaveManager.unlock_level(LevelUtils.first_campaign_level_number())
			var script_id := TutorialScripts.script_id_from_path(
				levels[current_level_index].resource_path
			)
			if not script_id.is_empty():
				SaveManager.mark_tutorial_script_complete(script_id)
		else:
			SaveManager.unlock_level(unlock_num + 1)
		if not _challenges_disabled:
			SaveManager.record_level_stars(unlock_num, int(star_result.get("bits", 0)))
	_set_board_and_hud_visible(false)
	var solved_preview := LevelPreview.make_texture_from_board_cells(board_manager.board_cells, 320)
	if AdsManager:
		AdsManager.record_level_win(won_tutorial)
	ui_manager.show_victory(
		display_num,
		is_last,
		star_result,
		is_custom,
		won_tutorial,
		solved_preview
	)

# Toggles gameplay visuals (board + HUD layer) together.
func _set_board_and_hud_visible(should_show: bool) -> void:
	if board_manager:
		board_manager.visible = should_show
	if hud_layer:
		hud_layer.visible = should_show

# Pauses gameplay and opens pause menu.
func _on_pause():
	if _is_generating_board or (_loading_overlay and _loading_overlay.is_busy()):
		return
	if not is_game_active or is_paused:
		return
	is_paused = true
	_timer_paused_for_ad = false
	if timer_node:
		timer_node.stop()
	_autosave_session()
	board_manager.process_mode = Node.PROCESS_MODE_DISABLED
	_set_board_and_hud_visible(false)
	ui_manager.set_hud_buttons_disabled(true)
	if pause_menu:
		if pause_menu.has_method("set_restart_label_key"):
			pause_menu.set_restart_label_key("UI_RESTART" if _challenges_disabled else "UI_NEW_LAYOUT")
		pause_menu.show()

# Opens in-game how-to-play overlay from active run.
func _on_how_to_play():
	if tutorial_director and tutorial_director.consume_hud_action("how_to_play"):
		return
	if not is_game_active or is_paused:
		return
	is_paused = true
	_timer_paused_for_ad = false
	if timer_node:
		timer_node.stop()
	board_manager.process_mode = Node.PROCESS_MODE_DISABLED
	_set_board_and_hud_visible(false)
	if ui_manager.has_method("show_how_to_play"):
		ui_manager.show_how_to_play()

# Resumes gameplay from pause/tutorial overlays and restores button states.
func _on_resume():
	if not is_paused:
		return
	is_paused = false
	if timer_node and not _challenges_disabled:
		timer_node.start()
	board_manager.process_mode = Node.PROCESS_MODE_INHERIT
	_set_board_and_hud_visible(true)
	ui_manager.set_hud_buttons_disabled(false)
	if tutorial_director and tutorial_director.is_active():
		tutorial_director.refresh_tool_gates()
	else:
		ui_manager.update_undo_redo_buttons(game_undo.can_undo(), game_undo.can_redo())
		_refresh_hint_button()
	if options_menu:
		options_menu.visible = false
	if pause_menu:
		pause_menu.hide()
	if ui_manager.has_method("set_overlays_hidden"):
		ui_manager.set_overlays_hidden()
	if tutorial_director and tutorial_director.is_active():
		tutorial_director.refresh_tool_gates()

# Opens reset/new-layout confirm overlay.
func _on_reset():
	if tutorial_director and tutorial_director.consume_hud_action("reset"):
		return
	if not is_game_active or is_paused:
		return
	is_paused = true
	if timer_node:
		timer_node.stop()
	board_manager.process_mode = Node.PROCESS_MODE_DISABLED
	_reset_confirm_return_to_pause = false
	_reset_confirm_from_session_resume = false
	_set_board_and_hud_visible(false)
	ui_manager.set_hud_buttons_disabled(true)
	ui_manager.show_reset_confirm()

# Handles confirmed reset, optionally showing an interstitial before regen.
func _on_reset_confirmed() -> void:
	if _reset_confirm_from_session_resume:
		_reset_confirm_from_session_resume = false
		_execute_session_restart()
		return
	_reset_confirm_return_to_pause = false
	is_paused = false
	if pause_menu:
		pause_menu.hide()
	if options_menu:
		options_menu.visible = false
	SaveManager.clear_session()
	var is_tutorial := (
		not levels.is_empty()
		and current_level_index >= 0
		and current_level_index < levels.size()
		and _is_campaign_tutorial(levels[current_level_index])
	)
	if AdsManager:
		AdsManager.record_level_restart(is_tutorial)
		if not is_tutorial:
			AdsManager.show_interstitial_if_ready(_finish_reset_confirmed)
			return
	_finish_reset_confirmed()

# Shared continuation after ad flow completes.
func _finish_reset_confirmed() -> void:
	_set_board_and_hud_visible(true)
	generate_board()

# Cancel from reset confirm returns to pause, session resume, or gameplay.
func _on_reset_cancelled() -> void:
	if _reset_confirm_from_session_resume:
		_reset_confirm_from_session_resume = false
		ui_manager.show_session_resume_prompt()
		return
	if _reset_confirm_return_to_pause:
		_reset_confirm_return_to_pause = false
		_set_board_and_hud_visible(false)
		ui_manager.set_hud_buttons_disabled(true)
		if pause_menu:
			pause_menu.show()
		return
	_on_resume()

# Pause-menu restart goes through the same reset confirm flow.
func _on_restart_level():
	if pause_menu:
		pause_menu.hide()
	_reset_confirm_return_to_pause = true
	_reset_confirm_from_session_resume = false
	_set_board_and_hud_visible(false)
	ui_manager.set_hud_buttons_disabled(true)
	ui_manager.show_reset_confirm()

# Opens options from pause while keeping gameplay hidden.
func _on_pause_settings() -> void:
	if pause_menu:
		pause_menu.hide()
	_set_board_and_hud_visible(false)
	if options_menu:
		options_menu.show_menu()

# Restores pause menu when backing out of options.
func _on_options_back_from_pause() -> void:
	if not is_paused:
		return
	_set_board_and_hud_visible(false)
	if pause_menu:
		pause_menu.show()

# Victory CTA: clear session and optionally show interstitial before advancing.
func _on_next_level():
	SaveManager.clear_session()
	var skip_ad := (
		not levels.is_empty()
		and current_level_index >= 0
		and current_level_index < levels.size()
		and _is_campaign_tutorial(levels[current_level_index])
	)
	if AdsManager and not skip_ad:
		AdsManager.show_interstitial_if_ready(_do_next_level)
	else:
		_do_next_level()

# Advances level index and starts entry flow.
func _do_next_level() -> void:
	if current_level_index < levels.size() - 1:
		current_level_index += 1
	_begin_level_entry()

# Victory CTA: replay current level (possibly after interstitial).
func _on_play_again():
	SaveManager.clear_session()
	var skip_ad := (
		not levels.is_empty()
		and current_level_index >= 0
		and current_level_index < levels.size()
		and _is_campaign_tutorial(levels[current_level_index])
	)
	if AdsManager and not skip_ad:
		AdsManager.show_interstitial_if_ready(_do_play_again)
	else:
		_do_play_again()

# Restarts current level entry flow.
func _do_play_again() -> void:
	_begin_level_entry()

# Pushes global debug-tools toggle into pause menu UI.
func _apply_debug_tools_visibility() -> void:
	if pause_menu and pause_menu.has_method("set_debug_tools_visible"):
		pause_menu.set_debug_tools_visible(GlobalGameManager.debug_tools_enabled)

# Debug shortcut from pause menu to instantly complete current level.
func _on_auto_win() -> void:
	if not is_game_active:
		return
	is_paused = false
	if pause_menu:
		pause_menu.hide()
	trigger_victory()

# Leaves gameplay to main menu, persisting session first.
func _on_quit_to_menu():
	if _is_generating_board or (_loading_overlay and _loading_overlay.is_busy()):
		return
	_autosave_session()
	GlobalGameManager.go_to_scene("res://scenes/main_menu.tscn")

# Leaves gameplay to level-select, persisting session first.
func _on_quit_to_level_select() -> void:
	if _is_generating_board or (_loading_overlay and _loading_overlay.is_busy()):
		return
	_autosave_session()
	GlobalGameManager.go_to_scene("res://scenes/level_select.tscn")

# Entry point for opening a level: either show resume prompt for an existing
# autosave, or clear stale session data and generate a fresh board.
func _begin_level_entry() -> void:
	if levels.is_empty() or current_level_index < 0 or current_level_index >= levels.size():
		return
	var level: LevelData = levels[current_level_index]
	if SaveManager.has_session_for(level):
		is_game_active = false
		is_paused = true
		if timer_node:
			timer_node.stop()
		if board_manager:
			board_manager.process_mode = Node.PROCESS_MODE_DISABLED
		_set_board_and_hud_visible(false)
		if pause_menu:
			pause_menu.hide()
		if options_menu:
			options_menu.visible = false
		ui_manager.show_session_resume_prompt()
		return
	if SaveManager.has_session():
		SaveManager.clear_session()
	generate_board()

# Session prompt actions.
func _on_session_continue() -> void:
	restore_session()

# NEW PUZZLE from resume → confirm first; Yes runs _execute_session_restart.
func _on_session_restart() -> void:
	_reset_confirm_from_session_resume = true
	_reset_confirm_return_to_pause = false
	ui_manager.show_reset_confirm()

func _execute_session_restart() -> void:
	SaveManager.clear_session()
	var is_tutorial := (
		not levels.is_empty()
		and current_level_index >= 0
		and current_level_index < levels.size()
		and _is_campaign_tutorial(levels[current_level_index])
	)
	if AdsManager:
		AdsManager.record_level_restart(is_tutorial)
		if not is_tutorial:
			AdsManager.show_interstitial_if_ready(_finish_session_restart)
			return
	_finish_session_restart()

func _finish_session_restart() -> void:
	_set_board_and_hud_visible(true)
	generate_board()

func _on_session_back() -> void:
	GlobalGameManager.go_to_scene("res://scenes/main_menu.tscn")

# Rebuilds timer and tutorial strings after UI locale/font refresh.
func _on_locale_refresh() -> void:
	_update_timer_display()
	if tutorial_director and tutorial_director.is_active():
		tutorial_director.refresh_for_locale()

# Serialises all runtime state needed to resume the exact in-progress puzzle.
func _build_session_payload() -> Dictionary:
	if levels.is_empty() or current_level_index < 0 or current_level_index >= levels.size():
		return {}
	if _run_layout.is_empty() or board_manager == null:
		return {}
	var level: LevelData = levels[current_level_index]
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
		"elapsed_seconds": elapsed_seconds,
		"shifter_move_count": shifter_move_count,
		"hints_used": hints_used,
		"required_jokers": required_jokers,
		"required_shifter_moves": required_shifter_moves,
		"has_shifters": _has_shifters,
		"challenges_disabled": _challenges_disabled,
		"prefer_hidden_hints": prefer_hidden_hints,
		"star_time_limit": star_time_limit,
		"hints_remaining": hints_remaining,
		"has_hints_remaining": true,
		"available_tiles": _run_available_tiles.duplicate(),
		"layout": _run_layout.duplicate(true),
		"shifter_pairs": _run_shifter_pairs.duplicate(true),
		"active_constraint_pairs": board_manager.active_constraint_pairs.duplicate(true),
		"hidden_reference_constraints": hidden_reference_constraints.duplicate(true),
		"solved_solution_reference": solved_solution_reference.duplicate(true),
		"cells": cells,
		"undo_history": game_undo.export_history(),
	}

# Writes a resumable snapshot when the run is in a stable state.
# Skips during generation and active tutorials to avoid partial/bad saves.
func _autosave_session() -> void:
	if not is_game_active and not is_paused:
		return
	if _is_generating_board:
		return
	if tutorial_director and tutorial_director.is_active():
		return
	var payload := _build_session_payload()
	if payload.is_empty():
		return
	SaveManager.save_session(payload)

# Restores a previously autosaved run, including board cells, constraints,
# timer/move counters, hint state, and undo history.
func restore_session() -> void:
	var data := SaveManager.load_session()
	if data.is_empty():
		generate_board()
		return
	if tutorial_director:
		tutorial_director.stop()
	ui_manager.set_overlays_hidden()
	if pause_menu:
		pause_menu.hide()
	if options_menu:
		options_menu.visible = false

	var current_level_resource: LevelData = levels[current_level_index]
	var is_custom = current_level_resource.resource_path.begins_with("user://")
	_run_layout = data.get("layout", {}).duplicate(true)
	_run_shifter_pairs = data.get("shifter_pairs", []).duplicate(true)
	_run_available_tiles = LevelUtils.normalize_available_tiles(
		data.get("available_tiles", [0, 1, 2])
	)
	if _run_layout.is_empty():
		SaveManager.clear_session()
		generate_board()
		return

	_challenges_disabled = bool(data.get("challenges_disabled", _is_campaign_tutorial(current_level_resource)))
	star_time_limit = 0 if _challenges_disabled else int(data.get("star_time_limit", 0))
	elapsed_seconds = int(data.get("elapsed_seconds", 0))
	shifter_move_count = int(data.get("shifter_move_count", 0))
	hints_used = int(data.get("hints_used", 0))
	required_jokers = 0 if _challenges_disabled else int(data.get("required_jokers", 0))
	required_shifter_moves = 0 if _challenges_disabled else int(data.get("required_shifter_moves", 0))
	_has_shifters = bool(data.get("has_shifters", false))
	prefer_hidden_hints = bool(data.get("prefer_hidden_hints", false))
	if bool(data.get("has_hints_remaining", false)):
		hints_remaining = int(data.get("hints_remaining", GameConstants.HINT_LIMIT_UNLIMITED))
	else:
		_reset_hint_quota(current_level_resource)
	hidden_reference_constraints = data.get("hidden_reference_constraints", []).duplicate(true)
	solved_solution_reference = data.get("solved_solution_reference", {}).duplicate(true)

	ui_manager.set_joker_counter_visibility(false)
	ui_manager.set_move_counter_visibility(false)
	var is_tutorial := _is_campaign_tutorial(current_level_resource)
	ui_manager.set_reset_mode_restart(is_tutorial)
	ui_manager.display_level(
		LevelUtils.get_display_level_number(current_level_resource),
		is_custom,
		is_tutorial
	)
	_update_timer_display()

	var active_constraints: Array = data.get("active_constraint_pairs", []).duplicate(true)
	board_manager.build_grid(_run_layout, _run_available_tiles, _run_shifter_pairs, active_constraints)

	var saved_cells: Dictionary = data.get("cells", {})
	for coord in saved_cells:
		if not board_manager.board_cells.has(coord):
			continue
		var cell = board_manager.board_cells[coord]
		var entry: Dictionary = saved_cells[coord]
		cell.state = int(entry.get("state", cell.state))
		cell.shifter_direction = entry.get("shifter_direction", Vector2i.ZERO)
		cell.update_visuals()

	var dims := LevelUtils.get_dimensions_from_level(current_level_resource)
	var centered_board_y := LevelUtils.center_board_y(dims.y, GameConstants.CELL_SIZE, get_viewport_rect().size.y)
	board_manager.position.y = centered_board_y
	ui_manager.update_dynamic_layout(centered_board_y, dims.y * GameConstants.CELL_SIZE)
	ui_manager.update_move_counter(shifter_move_count, required_shifter_moves)
	_update_joker_count()

	is_game_active = true
	is_paused = false
	board_manager.process_mode = Node.PROCESS_MODE_INHERIT
	_set_board_and_hud_visible(true)
	ui_manager.set_hud_buttons_disabled(false)
	var history: Dictionary = data.get("undo_history", {})
	if history is Dictionary and not history.is_empty() and history.has("current"):
		game_undo.import_history(history)
	else:
		game_undo.reset(_create_game_snapshot())
	ui_manager.update_undo_redo_buttons(game_undo.can_undo(), game_undo.can_redo())
	_run_validation_pass()
	if timer_node and not _challenges_disabled:
		timer_node.start()
	_refresh_hint_button()

# Per-second timer tick for timed levels.
func _on_timer_timeout():
	if _challenges_disabled:
		return
	if is_game_active and not is_paused:
		elapsed_seconds += 1
		_update_timer_display()

# Shows or hides the timer based on level rules and formats elapsed seconds.
func _update_timer_display():
	if _challenges_disabled:
		ui_manager.set_timer_visibility(false)
		return
	ui_manager.set_timer_visibility(true)
	ui_manager.update_timer(LevelStars.format_clock(elapsed_seconds))
