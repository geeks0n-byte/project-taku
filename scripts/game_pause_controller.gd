class_name GamePauseController
extends Node
## Pause menu, reset confirm, and overlay navigation for the gameplay scene.


var _game: GameMain


func setup(game: GameMain) -> void:
	_game = game


func on_pause() -> void:
	if _game == null:
		return
	if _game.tutorial_director and _game.tutorial_director.consume_hud_action("pause"):
		return
	if _game._is_generating_board or (_game._loading_overlay and _game._loading_overlay.is_busy()):
		return
	if not _game.is_game_active or _game.is_paused:
		return
	_game.is_paused = true
	_game._begin_pause_timer()
	_game._timer_paused_for_ad = false
	if _game.timer_node:
		_game.timer_node.stop()
	_game._autosave_session()
	_game.board_manager.process_mode = Node.PROCESS_MODE_DISABLED
	_game._set_board_and_hud_visible(false)
	_game.ui_manager.set_hud_buttons_disabled(true)
	if _game.pause_menu:
		if _game.pause_menu.has_method("set_restart_label_key"):
			var restart_label := "UI_RESTART"
			if (
				_game.levels.is_empty()
				or _game.current_level_index < 0
				or _game.current_level_index >= _game.levels.size()
			):
				restart_label = "UI_NEW_LAYOUT"
			elif not LevelUtils.level_has_preset_tiles(_game.levels[_game.current_level_index]):
				restart_label = "UI_NEW_LAYOUT"
			_game.pause_menu.set_restart_label_key(restart_label)
		_game.pause_menu.show()
		if _game.pause_menu.has_method("on_shown"):
			_game.pause_menu.on_shown()


func on_how_to_play() -> void:
	if _game == null:
		return
	if _game.tutorial_director and _game.tutorial_director.consume_hud_action("how_to_play"):
		return
	if not _game.is_game_active or _game.is_paused:
		return
	_game.is_paused = true
	_game._begin_pause_timer()
	_game._timer_paused_for_ad = false
	if _game.timer_node:
		_game.timer_node.stop()
	_game.board_manager.process_mode = Node.PROCESS_MODE_DISABLED
	_game._set_board_and_hud_visible(false)
	if _game.ui_manager.has_method("show_how_to_play"):
		_game.ui_manager.show_how_to_play()
	if AchievementManager:
		var level: LevelData = null
		if _game.current_level_index >= 0 and _game.current_level_index < _game.levels.size():
			level = _game.levels[_game.current_level_index]
		AchievementManager.notify_rules_opened(level)


func on_resume() -> void:
	if _game == null or not _game.is_paused:
		return
	_game._end_pause_timer()
	_game.is_paused = false
	if _game.timer_node and not _game._challenges_disabled:
		_game.timer_node.start()
	_game.board_manager.process_mode = Node.PROCESS_MODE_INHERIT
	_game._set_board_and_hud_visible(true)
	_game.ui_manager.set_hud_buttons_disabled(false)
	if _game.tutorial_director and _game.tutorial_director.is_active():
		_game.tutorial_director.refresh_tool_gates()
	else:
		_game.ui_manager.update_undo_redo_buttons(
			_game.game_undo.can_undo(), _game.game_undo.can_redo()
		)
		_game._refresh_hint_button()
	if _game.options_menu:
		_game.options_menu.visible = false
	if _game.pause_menu:
		_game.pause_menu.hide()
	if _game.ui_manager.has_method("set_overlays_hidden"):
		_game.ui_manager.set_overlays_hidden()
	if _game.tutorial_director and _game.tutorial_director.is_active():
		_game.tutorial_director.refresh_tool_gates()


func on_reset() -> void:
	if _game == null:
		return
	if _game.tutorial_director and _game.tutorial_director.consume_hud_action("reset"):
		return
	if not _game.is_game_active or _game.is_paused:
		return
	_game.is_paused = true
	_game._begin_pause_timer()
	if _game.timer_node:
		_game.timer_node.stop()
	_game.board_manager.process_mode = Node.PROCESS_MODE_DISABLED
	_game._reset_confirm_return_to_pause = false
	_game._reset_confirm_from_session_resume = false
	_game._set_board_and_hud_visible(false)
	_game.ui_manager.set_hud_buttons_disabled(true)
	_game.ui_manager.show_reset_confirm()


func on_reset_confirmed() -> void:
	if _game == null:
		return
	if _game._reset_confirm_from_session_resume:
		_game._reset_confirm_from_session_resume = false
		_game._execute_session_restart()
		return
	_game._reset_confirm_return_to_pause = false
	_game.is_paused = false
	if _game.pause_menu:
		_game.pause_menu.hide()
	if _game.options_menu:
		_game.options_menu.visible = false
	SaveManager.clear_session()
	var is_tutorial := (
		not _game.levels.is_empty()
		and _game.current_level_index >= 0
		and _game.current_level_index < _game.levels.size()
		and _game._is_campaign_tutorial(_game.levels[_game.current_level_index])
	)
	if AdsManager:
		AdsManager.record_level_restart(is_tutorial)
		if not is_tutorial:
			AdsManager.show_interstitial_if_ready(finish_reset_confirmed)
			return
	finish_reset_confirmed()


func finish_reset_confirmed() -> void:
	if _game == null:
		return
	_game._set_board_and_hud_visible(true)
	_game.generate_board()


func on_reset_cancelled() -> void:
	if _game == null:
		return
	if _game._reset_confirm_from_session_resume:
		_game._reset_confirm_from_session_resume = false
		_game.ui_manager.show_session_resume_prompt()
		return
	if _game._reset_confirm_return_to_pause:
		_game._reset_confirm_return_to_pause = false
		_game._set_board_and_hud_visible(false)
		_game.ui_manager.set_hud_buttons_disabled(true)
		if _game.pause_menu:
			_game.pause_menu.show()
			if _game.pause_menu.has_method("on_shown"):
				_game.pause_menu.on_shown()
		return
	on_resume()


func on_restart_level() -> void:
	if _game == null:
		return
	if _game.pause_menu:
		_game.pause_menu.hide()
	_game._reset_confirm_return_to_pause = true
	_game._reset_confirm_from_session_resume = false
	_game._set_board_and_hud_visible(false)
	_game.ui_manager.set_hud_buttons_disabled(true)
	_game.ui_manager.show_reset_confirm()


func on_pause_achievements() -> void:
	if _game == null:
		return
	if _game.pause_menu:
		_game.pause_menu.hide()
	_game._set_board_and_hud_visible(false)
	if AchievementManager:
		AchievementManager.show_list(on_achievements_back_to_pause)


func on_achievements_back_to_pause() -> void:
	if _game == null or not _game.is_paused:
		return
	_game._set_board_and_hud_visible(false)
	if _game.pause_menu:
		_game.pause_menu.show()
		if _game.pause_menu.has_method("on_shown"):
			_game.pause_menu.on_shown()
		if _game.pause_menu.has_method("refresh_notification_badges"):
			_game.pause_menu.refresh_notification_badges()


func on_pause_settings() -> void:
	if _game == null:
		return
	if _game.pause_menu:
		_game.pause_menu.hide()
	_game._set_board_and_hud_visible(false)
	if _game.options_menu:
		_game.options_menu.show_menu()


func on_options_back_from_pause() -> void:
	if _game == null or not _game.is_paused:
		return
	_game._set_board_and_hud_visible(false)
	if _game.pause_menu:
		_game.pause_menu.show()
		if _game.pause_menu.has_method("on_shown"):
			_game.pause_menu.on_shown()
