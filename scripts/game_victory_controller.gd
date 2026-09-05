class_name GameVictoryController
extends Node
## Victory flow, unlocks, and post-win navigation with interstitial gating.


var _game: GameMain


func setup(game: GameMain) -> void:
	_game = game


func trigger_victory() -> void:
	if _game == null:
		return
	if not _game.is_game_active:
		return
	if _game.tutorial_director:
		_game.tutorial_director.stop()
	_game.is_game_active = false
	_game._timer_paused_for_ad = false
	if _game.timer_node:
		_game.timer_node.stop()
	var board_manager := _game.board_manager
	board_manager.process_mode = Node.PROCESS_MODE_DISABLED
	SaveManager.clear_session()

	var level: LevelData = _game.levels[_game.current_level_index]
	var is_custom = level.resource_path.begins_with("user://")
	var is_last = _game.current_level_index >= _game.levels.size() - 1
	var display_num = LevelUtils.get_display_level_number(level)
	var unlock_num = level.level_number
	var challenges_disabled: bool = _game._challenges_disabled
	var time_limit := 0 if challenges_disabled else _game.star_time_limit
	var star_result := LevelStars.evaluate(
		_game.elapsed_seconds,
		time_limit,
		0 if challenges_disabled else _game.hints_used
	)
	if challenges_disabled:
		star_result["untimed"] = true
		star_result["goals"] = []
		star_result["total_count"] = 0
		star_result["earned_count"] = 0
	var won_tutorial := LevelUtils.is_campaign_tutorial(level)
	if not is_custom:
		if won_tutorial:
			SaveManager.unlock_level(LevelUtils.first_campaign_level_number())
			var script_id := TutorialScripts.script_id_from_path(level.resource_path)
			if not script_id.is_empty():
				SaveManager.mark_tutorial_script_complete(script_id)
		else:
			SaveManager.unlock_level(unlock_num + 1)
		if not challenges_disabled:
			SaveManager.record_level_stars(unlock_num, int(star_result.get("bits", 0)))
	if not is_custom and AchievementManager:
		_game._end_pause_timer()
		AchievementManager.record_level_clear(
			level,
			0 if challenges_disabled else _game.hints_used,
			_game._difficulty_for_level(level),
			won_tutorial,
			is_custom,
			int(star_result.get("bits", 0)),
			not challenges_disabled,
			_game._run_used_undo,
			_game._pause_accumulated_sec
		)
	_game._set_board_and_hud_visible(false)
	if board_manager.has_method("sync_shifter_directions"):
		board_manager.sync_shifter_directions()
	var solved_preview := LevelPreview.make_texture_from_board_cells(board_manager.board_cells, 320)
	if AdsManager:
		AdsManager.record_level_win(won_tutorial)
	var ui_manager := _game.ui_manager
	ui_manager.show_victory(
		display_num,
		is_last,
		star_result,
		is_custom,
		won_tutorial,
		solved_preview
	)
	if InAppReview and SaveManager:
		var session_sec := AdsManager.session_age_sec() if AdsManager else 0.0
		var unique_clears := maxi(
			0,
			SaveManager.max_unlocked_level - LevelUtils.first_campaign_level_number()
		)
		InAppReview.maybe_prompt_after_victory(
			won_tutorial,
			is_custom,
			int(star_result.get("earned_count", 0)),
			unique_clears,
			session_sec
		)


func on_next_level() -> void:
	SaveManager.clear_session()
	_run_after_interstitial(_do_next_level)


func on_play_again() -> void:
	SaveManager.clear_session()
	_run_after_interstitial(_do_play_again)


func _do_next_level() -> void:
	if _game.current_level_index < _game.levels.size() - 1:
		_game.current_level_index += 1
	_game._begin_level_entry()


func _do_play_again() -> void:
	_game._begin_level_entry()


func _run_after_interstitial(callback: Callable) -> void:
	if AdsManager and not LevelUtils.should_skip_level_interstitial(
		_game.levels,
		_game.current_level_index
	):
		AdsManager.show_interstitial_if_ready(callback)
	else:
		callback.call()
