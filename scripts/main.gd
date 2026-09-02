# Root game scene script. Owns board, HUD, and level progression logic.
# Delegates UI to UIManager and board logic to BoardManager; wires them together.
class_name GameMain
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
@onready var _loading_overlay: LoadingOverlay = $LoadingOverlay

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
var _run_used_undo: bool = false
var _pause_accumulated_sec: float = 0.0
var _pause_started_msec: int = 0
var current_level_index: int = 0
# A fully solved copy of the board layout, used as reference for hint generation.
var solved_solution_reference: Dictionary = {}
# Constraint pairs not shown to the player that can be revealed as hints.
var hidden_reference_constraints: Array = []
# When true, hints come only from hidden_reference_constraints (designed pool).
# Unique and non-unique boards both use this: never invent adjacent pairs outside the pool.
var prefer_hidden_hints: bool = true
var required_jokers: int = 0
var hints_remaining: int = GameConstants.HINT_LIMIT_UNLIMITED
var hints_used: int = 0
var game_undo := UndoStack.new()
# Guards against recording multiple snapshots for a single cell interaction.
var _is_recording_action: bool = false
# True while a fullscreen ad is visible so the timer stays paused.
var _timer_paused_for_ad: bool = false
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
var _session_ctrl: GameSessionController
var _victory_ctrl: GameVictoryController
var _hint_ctrl: GameHintController
var _board_setup_ctrl: GameBoardSetupController
var _pause_ctrl: GamePauseController
var _undo_ctrl: GameUndoController
var _validation_ctrl: GameValidationController

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

# Sets hints_remaining based on level type. Tutorials and debug-tools sessions
# get unlimited hints; campaign levels get a difficulty-based quota.
func _reset_hint_quota(level: LevelData) -> void:
	if _hint_ctrl:
		_hint_ctrl.reset_quota(level)


# Pre-warms the rewarded ad when hints are almost exhausted, then updates the
# hint button's icon and enabled state through UIManager.
func _refresh_hint_button() -> void:
	if _hint_ctrl:
		_hint_ctrl.refresh_button()

# Bootstraps ads, tutorial director, level lists, and first level/session entry.
func _ready():
	if AdsManager:
		AdsManager.show_menu_banner()
		AdsManager.warm_rewarded_hint()
		if not AdsManager.fullscreen_ad_started.is_connected(_on_fullscreen_ad_started):
			AdsManager.fullscreen_ad_started.connect(_on_fullscreen_ad_started)
		if not AdsManager.fullscreen_ad_finished.is_connected(_on_fullscreen_ad_finished):
			AdsManager.fullscreen_ad_finished.connect(_on_fullscreen_ad_finished)
	tutorial_director = TutorialDirector.new()
	tutorial_director.name = "TutorialDirector"
	add_child(tutorial_director)
	_session_ctrl = GameSessionController.new()
	_session_ctrl.name = "GameSessionController"
	add_child(_session_ctrl)
	_session_ctrl.setup(self)
	_victory_ctrl = GameVictoryController.new()
	_victory_ctrl.name = "GameVictoryController"
	add_child(_victory_ctrl)
	_victory_ctrl.setup(self)
	_hint_ctrl = GameHintController.new()
	_hint_ctrl.name = "GameHintController"
	add_child(_hint_ctrl)
	_hint_ctrl.setup(self)
	_board_setup_ctrl = GameBoardSetupController.new()
	_board_setup_ctrl.name = "GameBoardSetupController"
	add_child(_board_setup_ctrl)
	_board_setup_ctrl.setup(self)
	_pause_ctrl = GamePauseController.new()
	_pause_ctrl.name = "GamePauseController"
	add_child(_pause_ctrl)
	_pause_ctrl.setup(self)
	_undo_ctrl = GameUndoController.new()
	_undo_ctrl.name = "GameUndoController"
	add_child(_undo_ctrl)
	_undo_ctrl.setup(self)
	_validation_ctrl = GameValidationController.new()
	_validation_ctrl.name = "GameValidationController"
	add_child(_validation_ctrl)
	_validation_ctrl.setup(self)
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
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	if SaveManager and not SaveManager.color_blind_patterns_changed.is_connected(_on_color_blind_patterns_changed):
		SaveManager.color_blind_patterns_changed.connect(_on_color_blind_patterns_changed)
	_begin_level_entry()

## Refreshes color-blind overlays on the live board after an options toggle.
func _on_color_blind_patterns_changed() -> void:
	if board_manager == null or board_manager.board_cells.is_empty():
		return
	ColorBlindTiles.refresh_board_cells(board_manager.board_cells)

## Recenters the live board vertically when the viewport size changes.
func _on_viewport_resized() -> void:
	if board_manager == null or board_manager.board_cells.is_empty():
		return
	var dims := LevelUtils.get_dimensions_from_cells(board_manager.board_cells)
	var centered_board_y := LevelUtils.center_board_y(
		dims.y, GameConstants.CELL_SIZE, get_viewport_rect().size.y
	)
	board_manager.position.y = centered_board_y
	if ui_manager:
		ui_manager.update_dynamic_layout(centered_board_y, dims.y * GameConstants.CELL_SIZE)

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
	if AchievementManager and AchievementManager.is_list_open():
		AchievementManager.hide_list()
		return
	if options_menu and options_menu.visible:
		if options_menu.has_method("handle_system_back"):
			options_menu.handle_system_back()
		elif options_menu.has_method("hide_menu"):
			options_menu.hide_menu()
		return
	if ui_manager and ui_manager.how_to_play_container and ui_manager.how_to_play_container.visible:
		_pause_ctrl.on_resume()
		return
	if ui_manager and ui_manager.reset_confirm_panel and ui_manager.reset_confirm_panel.visible:
		ui_manager.hide_reset_confirm()
		_pause_ctrl.on_reset_cancelled()
		return
	if ui_manager and ui_manager.resume_panel and ui_manager.resume_panel.visible:
		_on_session_back()
		return
	if ui_manager and ui_manager.victory_panel and ui_manager.victory_panel.visible:
		_on_quit_to_menu()
		return
	if is_paused:
		_pause_ctrl.on_resume()
		return
	if is_game_active:
		_pause_ctrl.on_pause()
		return
	_on_quit_to_menu()

# Wires UIManager and BoardManager signals to main.gd handlers.
# Called once after both managers are confirmed non-null.
func _bind_submanager_signals():
	if not ui_manager or not board_manager:
		return
	ui_manager.pause_requested.connect(_pause_ctrl.on_pause)
	ui_manager.reset_requested.connect(_pause_ctrl.on_reset)
	ui_manager.reset_confirmed.connect(_pause_ctrl.on_reset_confirmed)
	ui_manager.reset_cancelled.connect(_pause_ctrl.on_reset_cancelled)
	ui_manager.how_to_play_requested.connect(_pause_ctrl.on_how_to_play)
	ui_manager.resume_from_tutorial_requested.connect(_pause_ctrl.on_resume)
	ui_manager.hint_requested.connect(_hint_ctrl.on_requested)
	ui_manager.undo_requested.connect(_undo_ctrl.on_undo_requested)
	ui_manager.redo_requested.connect(_undo_ctrl.on_redo_requested)
	board_manager.cell_changed.connect(_validation_ctrl.on_cell_changed)
	board_manager.cell_hold_cleared.connect(_validation_ctrl.on_cell_changed)
	board_manager.shifter_move_made.connect(_validation_ctrl.on_shifter_move_made)
	board_manager.invalid_move_attempted.connect(_validation_ctrl.on_invalid_move_attempted)
	if tutorial_director and not tutorial_director.finished.is_connected(_on_tutorial_finished):
		tutorial_director.finished.connect(_on_tutorial_finished)
	if tutorial_director and not tutorial_director.tools_unlocked.is_connected(_on_tutorial_tools_unlocked):
		tutorial_director.tools_unlocked.connect(_on_tutorial_tools_unlocked)
	if tutorial_director and not tutorial_director.board_layout_changed.is_connected(_on_tutorial_board_layout_changed):
		tutorial_director.board_layout_changed.connect(_on_tutorial_board_layout_changed)
	if pause_menu:
		pause_menu.resume_pressed.connect(_pause_ctrl.on_resume)
		pause_menu.restart_pressed.connect(_pause_ctrl.on_restart_level)
		pause_menu.settings_pressed.connect(_pause_ctrl.on_pause_settings)
		if pause_menu.has_signal("achievements_pressed"):
			pause_menu.achievements_pressed.connect(_pause_ctrl.on_pause_achievements)
		pause_menu.level_select_pressed.connect(_on_quit_to_level_select)
		pause_menu.auto_win_pressed.connect(_on_auto_win)
		pause_menu.quit_pressed.connect(_on_quit_to_menu)
	if options_menu:
		options_menu.back_requested.connect(_pause_ctrl.on_options_back_from_pause)
	ui_manager.next_level_requested.connect(_victory_ctrl.on_next_level)
	ui_manager.play_again_requested.connect(_victory_ctrl.on_play_again)
	ui_manager.session_continue_requested.connect(_on_session_continue)
	ui_manager.session_restart_requested.connect(_on_session_restart)
	ui_manager.session_back_requested.connect(_on_session_back)
	ui_manager.locale_refresh_requested.connect(_on_locale_refresh)

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
func generate_board() -> void:
	_board_setup_ctrl.generate_board()

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

## Restores undo/redo and re-runs validation after the tutorial script ends.
func _on_tutorial_finished() -> void:
	if not is_game_active or is_paused:
		return
	ui_manager.update_undo_redo_buttons(game_undo.can_undo(), game_undo.can_redo())
	run_validation_pass()

## Restores undo/redo and the hint button when the tutorial unlocks HUD tools.
func _on_tutorial_tools_unlocked() -> void:
	if not is_game_active or is_paused:
		return
	ui_manager.update_undo_redo_buttons(game_undo.can_undo(), game_undo.can_redo())
	_refresh_hint_button()

# Fired when TutorialDirector changes the board layout (e.g. reveals locked cells).
func _on_tutorial_board_layout_changed() -> void:
	_undo_ctrl.on_tutorial_board_layout_changed()

func _create_game_snapshot() -> Dictionary:
	return _undo_ctrl.create_snapshot()

func _apply_game_snapshot(snap: Dictionary) -> void:
	_undo_ctrl.apply_snapshot(snap)

func _record_game_action() -> void:
	_undo_ctrl.record_action()

func _update_joker_count() -> void:
	_undo_ctrl.update_joker_count()

func run_validation_pass() -> void:
	_validation_ctrl.run_validation_pass()

func _run_validation_pass() -> void:
	run_validation_pass()

# Ends the run, computes stars/unlocks, records ad cadence, and opens victory UI.
func trigger_victory() -> void:
	_victory_ctrl.trigger_victory()

# Toggles gameplay visuals (board + HUD layer) together.
func _set_board_and_hud_visible(should_show: bool) -> void:
	if board_manager:
		board_manager.visible = should_show
	if hud_layer:
		hud_layer.visible = should_show


func _begin_pause_timer() -> void:
	if _pause_started_msec <= 0:
		_pause_started_msec = Time.get_ticks_msec()


func _end_pause_timer() -> void:
	if _pause_started_msec <= 0:
		return
	_pause_accumulated_sec += float(Time.get_ticks_msec() - _pause_started_msec) / 1000.0
	_pause_started_msec = 0

# Shared continuation after ad flow completes (callback from AdsManager).
func _finish_reset_confirmed() -> void:
	_pause_ctrl.finish_reset_confirmed()

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
	_session_ctrl.autosave_now()
	GlobalGameManager.go_to_scene("res://scenes/main_menu.tscn")

# Leaves gameplay to level-select, persisting session first.
func _on_quit_to_level_select() -> void:
	if _is_generating_board or (_loading_overlay and _loading_overlay.is_busy()):
		return
	_session_ctrl.autosave_now()
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
		ui_manager.set_reset_mode_restart(LevelUtils.level_has_preset_tiles(level))
		ui_manager.show_session_resume_prompt()
		return
	if SaveManager.has_session():
		SaveManager.clear_session()
	generate_board()

# Session prompt actions.
func _on_session_continue() -> void:
	_session_ctrl.restore()

# NEW PUZZLE from resume → confirm first; Yes runs _execute_session_restart.
func _on_session_restart() -> void:
	_reset_confirm_from_session_resume = true
	_reset_confirm_return_to_pause = false
	ui_manager.show_reset_confirm()

## Clears the saved session, maybe shows an interstitial, then rebuilds the board.
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

## Shows board/HUD again and generates a fresh layout after restart.
func _finish_session_restart() -> void:
	_set_board_and_hud_visible(true)
	generate_board()

## Leaves the run and returns to the main menu.
func _on_session_back() -> void:
	GlobalGameManager.go_to_scene("res://scenes/main_menu.tscn")

# Rebuilds timer and tutorial strings after UI locale/font refresh.
func _on_locale_refresh() -> void:
	_update_timer_display()
	if tutorial_director and tutorial_director.is_active():
		tutorial_director.refresh_for_locale()

# Writes a resumable snapshot when the run is in a stable state.
func _autosave_session() -> void:
	_session_ctrl.request_autosave()

# Restores a previously autosaved run via GameSessionController.
func restore_session() -> void:
	_session_ctrl.restore()

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
