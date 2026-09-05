extends Node
## Autoload for local achievements: persist via SaveManager, toast on unlock, list overlay.

signal unlocked(id: String)
signal list_closed
signal unseen_count_changed(count: int)

const _TOAST_SCENE := preload("res://scenes/achievement_toast.tscn")
const _LIST_SCENE := preload("res://scenes/achievements_list.tscn")

var _toast: CanvasLayer = null
var _list: CanvasLayer = null
var _list_return: Callable = Callable()
var _backfill_done: bool = false
var _play_games_push_suppress_depth: int = 0

## Wires after SaveManager so existing progress can silently unlock starter ids.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Headless logic tests must not rewrite the player's progression.cfg.
	if OS.has_feature("headless"):
		_backfill_done = true
		return
	call_deferred("_backfill_from_save")


## Silent grants from existing progression (no toast). Safe to call more than once.
func _backfill_from_save() -> void:
	if _backfill_done:
		return
	_backfill_done = true
	if SaveManager == null:
		return
	_sync_no_hint_counter_from_stars()
	_sync_on_time_counter_from_stars()
	var stripped := _strip_unearned_undo_nothing()
	var newly := _apply_state(false)
	if stripped or not newly.is_empty():
		SaveManager.save_progress()


## Raises no_hint_clears to the count of campaign levels that already have the no-hint star.
func _sync_no_hint_counter_from_stars() -> void:
	var counted := _count_star_bit(LevelStars.BIT_NO_HINTS)
	if counted > SaveManager.no_hint_clears:
		SaveManager.no_hint_clears = counted


## Raises on_time_clears to the count of campaign levels that already have the time star.
func _sync_on_time_counter_from_stars() -> void:
	var counted := _count_star_bit(LevelStars.BIT_TIME)
	if counted > SaveManager.on_time_clears:
		SaveManager.on_time_clears = counted


## Counts unique saved levels whose star mask includes `bit`.
func _count_star_bit(bit: int) -> int:
	var counted := 0
	var bits: Dictionary = SaveManager.level_star_bits
	for key in bits:
		if (int(bits[key]) & bit) != 0:
			counted += 1
	return counted


## Records a campaign clear from main.gd's win path. Returns newly unlocked ids.
## Replays never count — counters sync from unique star bits / max_unlocked. Skips tutorial/custom.
func record_level_clear(
	level: LevelData,
	_hints_used: int,
	difficulty: int,
	is_tutorial: bool,
	is_custom: bool,
	star_bits: int = 0,
	challenges_enabled: bool = false,
	run_used_undo: bool = false,
	pause_seconds: float = 0.0
) -> Array:
	if is_custom or is_tutorial or level == null:
		return []
	if SaveManager == null:
		return []
	_sync_no_hint_counter_from_stars()
	_sync_on_time_counter_from_stars()
	var event_flags := {}
	if challenges_enabled and LevelStars.count_earned_bits(star_bits) >= 3:
		event_flags[AchievementCatalog.ID_THREE_STAR_DEBUT] = true
	if AchievementCatalog.qualifies_undo_nothing(difficulty, run_used_undo):
		event_flags[AchievementCatalog.ID_UNDO_NOTHING] = true
	if pause_seconds >= AchievementCatalog.PAUSE_THINKER_SEC:
		event_flags[AchievementCatalog.ID_PAUSE_THINKER] = true
	var newly := _apply_state(true, 0.0, event_flags)
	SaveManager.save_progress()
	return newly


## Lifetime shifter slides (purple_rain).
func notify_shifter_slide() -> void:
	if SaveManager == null or OS.has_feature("headless"):
		return
	SaveManager.shifter_slides += 1
	var newly := _apply_state(true)
	if not newly.is_empty():
		SaveManager.save_progress()


## Lifetime undo uses (ctrl_z).
func notify_undo() -> void:
	if SaveManager == null or OS.has_feature("headless"):
		return
	SaveManager.undo_uses += 1
	var newly := _apply_state(true)
	if not newly.is_empty():
		SaveManager.save_progress()


## Lifetime redo uses (ctrl_y).
func notify_redo() -> void:
	if SaveManager == null or OS.has_feature("headless"):
		return
	SaveManager.redo_uses += 1
	var newly := _apply_state(true)
	if not newly.is_empty():
		SaveManager.save_progress()


## Rules overlay opened on a campaign level (rules_reader).
func notify_rules_opened(level: LevelData = null) -> void:
	if SaveManager == null or OS.has_feature("headless"):
		return
	var recorded := false
	if level != null:
		recorded = SaveManager.record_rules_opened(level)
	var newly := _apply_state(true)
	if recorded or not newly.is_empty():
		SaveManager.save_progress()


## Rewarded ad watched for hints (ad_friend).
func notify_rewarded_ad_watched() -> void:
	grant(AchievementCatalog.ID_AD_FRIEND)


## One-shot grant: toast, persist, emit. Idempotent — a second call is a no-op.
## Event achievements (im_blue, shall_not_pass, dev_mode) use this instead of collect_unlocks.
func grant(id: String) -> bool:
	if SaveManager == null:
		return false
	var now := int(Time.get_unix_time_from_system())
	if not AchievementCatalog.apply_grant(SaveManager.achievements_unlocked, id, now):
		return false
	if not OS.has_feature("headless"):
		SaveManager.save_progress()
	unlocked.emit(id)
	_notify_unseen_changed()
	_show_toast(id)
	_refresh_open_list()
	return true


## Silent grant from Play Games pull merge. No toast and no [signal unlocked] (avoids re-push).
func import_remote_unlock(id: String) -> bool:
	if SaveManager == null:
		return false
	if (
		id == AchievementCatalog.ID_UNDO_NOTHING
		and not _has_cleared_any_in_dir(GameConstants.CAMPAIGN_HARD_DIR)
	):
		return false
	var now := int(Time.get_unix_time_from_system())
	if not AchievementCatalog.apply_grant(SaveManager.achievements_unlocked, id, now):
		return false
	if not OS.has_feature("headless"):
		SaveManager.save_progress()
	_notify_unseen_changed()
	_refresh_open_list()
	return true


## Grants im_blue when every player-fillable cell is BLUE (shifters/locked starters ignored).
func check_all_blue(cells: Dictionary) -> bool:
	if cells.is_empty() or is_unlocked(AchievementCatalog.ID_IM_BLUE):
		return false
	if not AchievementCatalog.board_is_all_blue(cells):
		return false
	return grant(AchievementCatalog.ID_IM_BLUE)


## Grants yellow_submarine when every player-fillable cell is YELLOW.
func check_all_yellow(cells: Dictionary) -> bool:
	if cells.is_empty() or is_unlocked(AchievementCatalog.ID_YELLOW_SUBMARINE):
		return false
	if not AchievementCatalog.board_is_all_yellow(cells):
		return false
	return grant(AchievementCatalog.ID_YELLOW_SUBMARINE)


## Grants green_screen when every player-fillable cell is a green (joker) tile.
func check_all_green(cells: Dictionary) -> bool:
	if cells.is_empty() or is_unlocked(AchievementCatalog.ID_GREEN_SCREEN):
		return false
	if not AchievementCatalog.board_is_all_green(cells):
		return false
	return grant(AchievementCatalog.ID_GREEN_SCREEN)


## Grants shall_not_pass when a shifter hop is blocked by another shifter.
func notify_invalid_move(message: String) -> bool:
	if str(message) != "ERR_SHIFTER_BLOCKED":
		return false
	return grant(AchievementCatalog.ID_SHALL_NOT_PASS)


## Debug: grants every catalog achievement with unlock toasts. Returns count newly unlocked.
func debug_unlock_all() -> int:
	if SaveManager == null or OS.has_feature("headless"):
		return 0
	_push_play_games_push_suppressed(true)
	var now := int(Time.get_unix_time_from_system())
	var granted := 0
	var delay := 0.0
	const TOAST_GAP := 0.35
	for id in AchievementCatalog.ORDERED_IDS:
		var sid := str(id)
		if not AchievementCatalog.apply_grant(SaveManager.achievements_unlocked, sid, now):
			continue
		granted += 1
		unlocked.emit(sid)
		_show_toast(sid, delay)
		delay += TOAST_GAP
	if granted > 0:
		SaveManager.save_progress()
		_notify_unseen_changed()
		_refresh_open_list()
	_push_play_games_push_suppressed(false)
	return granted


## Re-evaluates achievement eligibility from the current save (e.g. debug unlock all levels).
func sync_from_progress(show_toast: bool = false, suppress_play_games_push: bool = false) -> Array:
	if SaveManager == null or OS.has_feature("headless"):
		return []
	if suppress_play_games_push:
		_push_play_games_push_suppressed(true)
	_sync_no_hint_counter_from_stars()
	_sync_on_time_counter_from_stars()
	var newly := _apply_state(show_toast)
	if newly.is_empty():
		if suppress_play_games_push:
			_push_play_games_push_suppressed(false)
		return newly
	SaveManager.save_progress()
	_notify_unseen_changed()
	if suppress_play_games_push:
		_push_play_games_push_suppressed(false)
	return newly


## True while debug grants should not push to Play Games (see PlayGamesManager).
func is_play_games_push_suppressed() -> bool:
	return _play_games_push_suppress_depth > 0


func push_play_games_push_suppressed(enabled: bool) -> void:
	_push_play_games_push_suppressed(enabled)


func _push_play_games_push_suppressed(enabled: bool) -> void:
	if enabled:
		_play_games_push_suppress_depth += 1
	else:
		_play_games_push_suppress_depth = maxi(0, _play_games_push_suppress_depth - 1)


## Builds the current progress snapshot and grants any missing ids.
func _apply_state(
	show_toast: bool,
	toast_delay_sec: float = 0.0,
	event_flags: Dictionary = {}
) -> Array:
	var already: Dictionary = SaveManager.achievements_unlocked
	var state := {
		"campaign_clears": _campaign_clear_count(),
		"hard_clears": 1 if _has_cleared_any_in_dir(GameConstants.CAMPAIGN_HARD_DIR) else 0,
		"no_hint_clears": SaveManager.no_hint_clears,
		"on_time_clears": SaveManager.on_time_clears,
		"shifter_slides": SaveManager.shifter_slides,
		"undo_uses": SaveManager.undo_uses,
		"redo_uses": SaveManager.redo_uses,
		"rules_open_levels": SaveManager.rules_open_level_count(),
		"easy_complete": _folder_complete(GameConstants.CAMPAIGN_EASY_DIR),
		"medium_complete": _folder_complete(GameConstants.CAMPAIGN_MEDIUM_DIR),
		"hard_complete": _folder_complete(GameConstants.CAMPAIGN_HARD_DIR),
	}
	for key in event_flags:
		state[str(key)] = event_flags[key]
	var newly: Array = AchievementCatalog.collect_unlocks(state, already)
	if newly.is_empty():
		return []
	var now := int(Time.get_unix_time_from_system())
	var granted: Array = []
	var toast_delay := toast_delay_sec
	for id in newly:
		var sid := str(id)
		if not AchievementCatalog.apply_grant(already, sid, now):
			continue
		granted.append(sid)
		unlocked.emit(sid)
		if show_toast:
			_show_toast(sid, toast_delay)
			toast_delay += 0.35
	if granted.is_empty():
		return []
	if show_toast:
		_notify_unseen_changed()
	_refresh_open_list()
	return granted


## Reloads the overlay grid when it is already on screen.
func _refresh_open_list() -> void:
	if _list and is_instance_valid(_list) and _list.visible and _list.has_method("refresh"):
		_list.refresh()


## Campaign puzzles cleared: max_unlocked above the first easy number (unique, caps at folder size).
func _campaign_clear_count() -> int:
	var first := AchievementCatalog.first_level_number_in_dir(GameConstants.CAMPAIGN_EASY_DIR)
	if first <= 0:
		first = SaveManager.get_campaign_start_unlock() if SaveManager else 1
	return maxi(0, SaveManager.max_unlocked_level - first)


## True when every level in `dir` is implied-cleared (max_unlocked past the last number).
func _folder_complete(dir: String) -> bool:
	var last := AchievementCatalog.last_level_number_in_dir(dir)
	if last <= 0:
		return false
	return SaveManager.max_unlocked_level > last


## True when at least the first puzzle in `dir` has been cleared.
func _has_cleared_any_in_dir(dir: String) -> bool:
	var first := AchievementCatalog.first_level_number_in_dir(dir)
	if first <= 0:
		return false
	return SaveManager.max_unlocked_level > first


## Drops undo_nothing if it was granted before Hard-only was enforced.
func _strip_unearned_undo_nothing() -> bool:
	if SaveManager == null:
		return false
	if not SaveManager.achievements_unlocked.has(AchievementCatalog.ID_UNDO_NOTHING):
		return false
	if _has_cleared_any_in_dir(GameConstants.CAMPAIGN_HARD_DIR):
		return false
	SaveManager.achievements_unlocked.erase(AchievementCatalog.ID_UNDO_NOTHING)
	SaveManager.achievements_seen.erase(AchievementCatalog.ID_UNDO_NOTHING)
	_notify_unseen_changed()
	return true


## True when this id is in the save.
func is_unlocked(id: String) -> bool:
	if SaveManager == null:
		return false
	return SaveManager.achievements_unlocked.has(id)


## Ordered catalog ids for the list UI.
func all_ids() -> Array:
	return AchievementCatalog.ORDERED_IDS.duplicate()


## Drops local achievement progress (called from SaveManager.delete_save_file).
func reset_local() -> void:
	if SaveManager == null:
		return
	SaveManager.achievements_unlocked.clear()
	SaveManager.achievements_seen.clear()
	SaveManager.no_hint_clears = 0
	SaveManager.on_time_clears = 0
	SaveManager.shifter_slides = 0
	SaveManager.undo_uses = 0
	SaveManager.redo_uses = 0
	SaveManager.rules_open_levels.clear()


## Opens the achievements overlay. `on_close` is invoked after the player backs out.
func show_list(on_close: Callable = Callable()) -> void:
	_list_return = on_close
	_ensure_list()
	if _list == null:
		return
	if _list.has_method("refresh"):
		_list.refresh()
	_list.visible = true


## Closes the list overlay if it is open.
func hide_list() -> void:
	if _list == null or not is_instance_valid(_list) or not _list.visible:
		return
	_list.visible = false
	var cb := _list_return
	_list_return = Callable()
	list_closed.emit()
	if cb.is_valid():
		cb.call()
	_notify_unseen_changed()


## True while the achievements list is on screen.
func is_list_open() -> bool:
	return _list != null and is_instance_valid(_list) and _list.visible


## Count of unlocks the player has not opened the achievements list since earning.
func unseen_count() -> int:
	if SaveManager == null:
		return 0
	return SaveManager.unseen_achievement_count()


## Re-emits the menu badge count (e.g. after a profile wipe).
func notify_unseen_changed() -> void:
	_notify_unseen_changed()


func _notify_unseen_changed() -> void:
	unseen_count_changed.emit(unseen_count())


## Queues a toast unless running headless (logic tests).
func _show_toast(id: String, delay_sec: float = 0.0) -> void:
	if OS.has_feature("headless"):
		return
	_ensure_toast()
	if _toast and _toast.has_method("enqueue"):
		_toast.enqueue(id, maxf(0.0, delay_sec))


func _ensure_toast() -> void:
	if _toast != null and is_instance_valid(_toast):
		return
	if OS.has_feature("headless"):
		return
	_toast = _TOAST_SCENE.instantiate()
	add_child(_toast)


func _ensure_list() -> void:
	if _list != null and is_instance_valid(_list):
		return
	if OS.has_feature("headless"):
		return
	_list = _LIST_SCENE.instantiate()
	add_child(_list)
	if _list.has_signal("back_requested") and not _list.back_requested.is_connected(hide_list):
		_list.back_requested.connect(hide_list)
