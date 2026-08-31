extends Node
## Autoload for local achievements: persist via SaveManager, toast on unlock, list overlay.

signal unlocked(id: String)
signal list_closed

const _TOAST_SCENE := preload("res://scenes/achievement_toast.tscn")
const _LIST_SCENE := preload("res://scenes/achievements_list.tscn")

var _toast: CanvasLayer = null
var _list: CanvasLayer = null
var _list_return: Callable = Callable()
var _backfill_done: bool = false

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
	var newly := _apply_state(false)
	if not newly.is_empty():
		SaveManager.save_progress()


## Raises no_hint_clears to the count of campaign levels that already have the no-hint star.
func _sync_no_hint_counter_from_stars() -> void:
	var counted := 0
	var bits: Dictionary = SaveManager.level_star_bits
	for key in bits:
		if (int(bits[key]) & LevelStars.BIT_NO_HINTS) != 0:
			counted += 1
	if counted > SaveManager.no_hint_clears:
		SaveManager.no_hint_clears = counted


## Records a campaign (or skipped) clear from main.gd's win path. Returns newly unlocked ids.
func record_level_clear(
	level: LevelData,
	hints_used: int,
	_difficulty: int,
	is_tutorial: bool,
	is_custom: bool
) -> Array:
	if is_custom or is_tutorial or level == null:
		return []
	if SaveManager == null:
		return []
	# Campaign clear: first_clear and set completion use max_unlocked_level already updated.
	if hints_used <= 0:
		SaveManager.no_hint_clears += 1
	var newly := _apply_state(true)
	if not newly.is_empty() or hints_used <= 0:
		SaveManager.save_progress()
	return newly


## Builds the current progress snapshot and grants any missing ids.
func _apply_state(show_toast: bool) -> Array:
	var already: Dictionary = SaveManager.achievements_unlocked
	var state := {
		"campaign_clears": _campaign_clear_count(),
		"hard_clears": 1 if _has_cleared_any_in_dir(GameConstants.CAMPAIGN_HARD_DIR) else 0,
		"no_hint_clears": SaveManager.no_hint_clears,
		"easy_complete": _folder_complete(GameConstants.CAMPAIGN_EASY_DIR),
		"medium_complete": _folder_complete(GameConstants.CAMPAIGN_MEDIUM_DIR),
		"hard_complete": _folder_complete(GameConstants.CAMPAIGN_HARD_DIR),
	}
	var newly: Array = AchievementCatalog.collect_unlocks(state, already)
	if newly.is_empty():
		return []
	var now := int(Time.get_unix_time_from_system())
	for id in newly:
		SaveManager.achievements_unlocked[str(id)] = now
		unlocked.emit(str(id))
		if show_toast:
			_show_toast(str(id))
	if _list and is_instance_valid(_list) and _list.visible and _list.has_method("refresh"):
		_list.refresh()
	return newly


## Campaign puzzles cleared: max_unlocked above the first easy number.
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
	SaveManager.no_hint_clears = 0


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


## True while the achievements list is on screen.
func is_list_open() -> bool:
	return _list != null and is_instance_valid(_list) and _list.visible


## Queues a toast unless running headless (logic tests).
func _show_toast(id: String) -> void:
	if OS.has_feature("headless"):
		return
	_ensure_toast()
	if _toast and _toast.has_method("enqueue"):
		_toast.enqueue(id)


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
