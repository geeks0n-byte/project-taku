class_name GameHintController
extends Node
## Hint quota, rewarded ads, and reveal flow for the gameplay scene.


var _game: GameMain


func setup(game: GameMain) -> void:
	_game = game


func reset_quota(level: LevelData) -> void:
	if _game == null:
		return
	if GlobalGameManager.debug_tools_enabled or _game._is_campaign_tutorial(level):
		_game.hints_remaining = GameConstants.HINT_LIMIT_UNLIMITED
	else:
		_game.hints_remaining = GameConstants.hint_limit_for_difficulty(
			_game._difficulty_for_level(level)
		)


func can_use_hint() -> bool:
	if _game == null:
		return false
	if _game.tutorial_director and _game.tutorial_director.is_active():
		return false
	var board_manager := _game.board_manager
	var board_ok := HintController.has_usable_hints(
		board_manager.board_cells if board_manager else {},
		board_manager.active_constraint_pairs if board_manager else [],
		_game.solved_solution_reference,
		_game.hidden_reference_constraints,
		Vector2i.ZERO,
		_game.prefer_hidden_hints
	)
	if not board_ok:
		return false
	if _game.hints_remaining != 0:
		return true
	return AdsManager != null and AdsManager.can_offer_rewarded_hint()


func refresh_button() -> void:
	if _game == null or _game.ui_manager == null:
		return
	if AdsManager and _game.hints_remaining <= 1:
		AdsManager.warm_rewarded_hint()
	_game.ui_manager.set_hint_remaining(_game.hints_remaining)
	_game.ui_manager.set_hint_button_disabled(not can_use_hint())


func on_requested() -> void:
	if _game == null:
		return
	if _game.tutorial_director and _game.tutorial_director.consume_hud_action("hint"):
		return
	if not _game.is_game_active or _game.is_paused:
		return
	if _game.hints_remaining == 0:
		if AdsManager == null:
			if _game.ui_manager:
				_game.ui_manager.show_status_errors(["ERROR_AD_HINT_UNAVAILABLE"])
			refresh_button()
			return
		AdsManager.warm_rewarded_hint()
		if AdsManager.show_rewarded_for_hint(on_rewarded_earned):
			if (
				_game.ui_manager
				and not AdsManager.is_rewarded_hint_ready()
				and AdsManager.is_rewarded_hint_loading()
			):
				_game.ui_manager.show_status_errors(["ERROR_AD_HINT_LOADING"])
			return
		if _game.ui_manager:
			_game.ui_manager.show_status_errors(["ERROR_AD_HINT_UNAVAILABLE"])
		refresh_button()
		return
	apply_hint()


func on_rewarded_earned() -> void:
	if _game == null:
		return
	_game.hints_remaining = GameConstants.HINTS_FROM_REWARDED_AD
	if AchievementManager:
		AchievementManager.notify_rewarded_ad_watched()
	if AdsManager:
		AdsManager.warm_rewarded_hint()
	apply_hint()


func apply_hint() -> void:
	if _game == null:
		return
	if not _game.is_game_active or _game.is_paused:
		return
	if _game.tutorial_director and _game.tutorial_director.is_active():
		return
	var board_manager := _game.board_manager
	if not board_manager or _game.levels.is_empty() or _game.current_level_index < 0:
		return
	var current_res: LevelData = _game.levels[_game.current_level_index]
	var tiles_list: Array = LevelUtils.normalize_available_tiles(
		current_res.available_tiles if current_res.available_tiles.size() > 0 else [0, 1, 2]
	)
	if _game.solved_solution_reference.is_empty():
		_game.solved_solution_reference = HintSystem.attempt_dynamic_solve(
			board_manager.board_cells,
			board_manager.active_constraint_pairs,
			tiles_list
		)
	if (
		_game.hidden_reference_constraints.is_empty()
		and not _game.prefer_hidden_hints
		and not _game.solved_solution_reference.is_empty()
	):
		var dims := LevelUtils.get_dimensions_from_cells(board_manager.board_cells)
		_game.hidden_reference_constraints = HintSystem.hidden_hints_from_solved(
			_game.solved_solution_reference,
			board_manager.active_constraint_pairs,
			dims.x,
			dims.y
		)
	var result = HintController.reveal_hint(
		board_manager.board_cells,
		board_manager.active_constraint_pairs,
		_game.solved_solution_reference,
		_game.hidden_reference_constraints,
		tiles_list,
		_game.prefer_hidden_hints
	)
	_game.solved_solution_reference = result["solved_reference"]
	var hint = result["hint"]
	if hint != null:
		board_manager.active_constraint_pairs.append(hint)
		for i in range(_game.hidden_reference_constraints.size() - 1, -1, -1):
			var pooled = _game.hidden_reference_constraints[i]
			if (pooled["a"] == hint["a"] and pooled["b"] == hint["b"]) or (
				pooled["a"] == hint["b"] and pooled["b"] == hint["a"]
			):
				_game.hidden_reference_constraints.remove_at(i)
		_game.hints_used += 1
		if _game.hints_remaining > 0:
			_game.hints_remaining -= 1
		board_manager.trigger_redraw()
		_game._run_validation_pass()
		_game._autosave_session()
		refresh_button()
	else:
		_game.ui_manager.show_status_errors(["ERROR_NO_HINTS"])
		refresh_button()
