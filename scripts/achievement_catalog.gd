class_name AchievementCatalog
extends RefCounted
## Stateless achievement ids, copy keys, and unlock rules (safe for headless tests).

const ID_FIRST_CLEAR := "first_clear"
const ID_FIRST_HARD := "first_hard"
const ID_NO_HINT_CLEAR := "no_hint_clear"
const ID_EASY_SET := "easy_set"
const ID_MEDIUM_SET := "medium_set"
const ID_HARD_SET := "hard_set"
const ID_HINT_SAVER := "hint_saver"

## Display / save order for the achievements list.
const ORDERED_IDS: Array[String] = [
	ID_FIRST_CLEAR,
	ID_FIRST_HARD,
	ID_NO_HINT_CLEAR,
	ID_EASY_SET,
	ID_MEDIUM_SET,
	ID_HARD_SET,
	ID_HINT_SAVER,
]

## Number of no-hint campaign clears required for hint_saver.
const HINT_SAVER_TARGET := 10

## i18n key for the achievement title.
static func title_key(id: String) -> String:
	return "ACH_%s_NAME" % str(id).to_upper()


## i18n key for the achievement description.
static func desc_key(id: String) -> String:
	return "ACH_%s_DESC" % str(id).to_upper()


## Adds `id` when it is not already present in `already` (id -> timestamp dict).
static func _maybe_add(out: Array, id: String, already: Dictionary) -> void:
	if already.has(id):
		return
	out.append(id)


## Returns newly earned ids for the given progress snapshot.
## `state` keys:
##   campaign_clears (int), hard_clears (int), no_hint_clears (int),
##   easy_complete (bool), medium_complete (bool), hard_complete (bool)
## `already` maps unlocked id -> unix timestamp (or any truthy value).
static func collect_unlocks(state: Dictionary, already: Dictionary = {}) -> Array:
	var out: Array = []
	if int(state.get("campaign_clears", 0)) >= 1:
		_maybe_add(out, ID_FIRST_CLEAR, already)
	if int(state.get("hard_clears", 0)) >= 1:
		_maybe_add(out, ID_FIRST_HARD, already)
	if int(state.get("no_hint_clears", 0)) >= 1:
		_maybe_add(out, ID_NO_HINT_CLEAR, already)
	if bool(state.get("easy_complete", false)):
		_maybe_add(out, ID_EASY_SET, already)
	if bool(state.get("medium_complete", false)):
		_maybe_add(out, ID_MEDIUM_SET, already)
	if bool(state.get("hard_complete", false)):
		_maybe_add(out, ID_HARD_SET, already)
	if int(state.get("no_hint_clears", 0)) >= HINT_SAVER_TARGET:
		_maybe_add(out, ID_HINT_SAVER, already)
	return out


## Highest `level_N` filename number in a campaign folder, or 0 if empty/missing.
static func last_level_number_in_dir(dir: String) -> int:
	var paths: Array = LevelUtils.scan_directory(dir)
	if paths.is_empty():
		return 0
	LevelUtils.sort_level_paths(paths)
	return _level_number_from_path(str(paths[paths.size() - 1]))


## Lowest `level_N` filename number in a campaign folder, or 0 if empty/missing.
static func first_level_number_in_dir(dir: String) -> int:
	var paths: Array = LevelUtils.scan_directory(dir)
	if paths.is_empty():
		return 0
	LevelUtils.sort_level_paths(paths)
	return _level_number_from_path(str(paths[0]))


## Parses level_42.tres → 42.
static func _level_number_from_path(path: String) -> int:
	return int(String(path).get_file().get_basename().replace("level_", ""))
