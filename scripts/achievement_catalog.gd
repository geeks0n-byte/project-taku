class_name AchievementCatalog
extends RefCounted
## Stateless achievement ids, copy keys, icons, tiers, and unlock rules (headless-safe).

const ID_FIRST_CLEAR := "first_clear"
const ID_CLEARS_BRONZE := "clears_bronze"
const ID_CLEARS_SILVER := "clears_silver"
const ID_CLEARS_GOLD := "clears_gold"
const ID_FIRST_HARD := "first_hard"
const ID_NO_HINT_CLEAR := "no_hint_clear"
const ID_HINT_SAVER := "hint_saver"
const ID_NO_HINT_GOLD := "no_hint_gold"
const ID_ON_TIME_BRONZE := "on_time_bronze"
const ID_ON_TIME_SILVER := "on_time_silver"
const ID_ON_TIME_GOLD := "on_time_gold"
const ID_EASY_SET := "easy_set"
const ID_MEDIUM_SET := "medium_set"
const ID_HARD_SET := "hard_set"
const ID_THREE_STAR_DEBUT := "three_star_debut"
const ID_UNDO_NOTHING := "undo_nothing"
const ID_AD_FRIEND := "ad_friend"
const ID_IM_BLUE := "im_blue"
const ID_SHALL_NOT_PASS := "shall_not_pass"
const ID_RULES_READER := "rules_reader"
const ID_PURPLE_RAIN := "purple_rain"
const ID_YELLOW_SUBMARINE := "yellow_submarine"
const ID_PAUSE_THINKER := "pause_thinker"
const ID_DEV_MODE := "dev_mode"

const FAM_CLEARS := "clears"
const FAM_NO_HINT := "no_hint"
const FAM_ON_TIME := "on_time"

## Display / save order. Tiered families list bronze, then silver, then gold.
const ORDERED_IDS: Array[String] = [
	ID_FIRST_CLEAR,
	ID_CLEARS_BRONZE,
	ID_CLEARS_SILVER,
	ID_CLEARS_GOLD,
	ID_FIRST_HARD,
	ID_NO_HINT_CLEAR,
	ID_HINT_SAVER,
	ID_NO_HINT_GOLD,
	ID_ON_TIME_BRONZE,
	ID_ON_TIME_SILVER,
	ID_ON_TIME_GOLD,
	ID_EASY_SET,
	ID_MEDIUM_SET,
	ID_HARD_SET,
	ID_THREE_STAR_DEBUT,
	ID_UNDO_NOTHING,
	ID_AD_FRIEND,
	ID_IM_BLUE,
	ID_SHALL_NOT_PASS,
	ID_RULES_READER,
	ID_PURPLE_RAIN,
	ID_YELLOW_SUBMARINE,
	ID_PAUSE_THINKER,
	ID_DEV_MODE,
]

## Unique campaign clears / no-hint / on-time tier thresholds (replays never count).
const CLEARS_BRONZE_TARGET := 10
const CLEARS_SILVER_TARGET := 30
const CLEARS_GOLD_TARGET := 60
const NO_HINT_BRONZE_TARGET := 10
const HINT_SAVER_TARGET := 30
const NO_HINT_GOLD_TARGET := 60
const ON_TIME_BRONZE_TARGET := 10
const ON_TIME_SILVER_TARGET := 30
const ON_TIME_GOLD_TARGET := 60
const RULES_READER_TARGET := 10
const PURPLE_RAIN_TARGET := 30
const PAUSE_THINKER_SEC := 180.0

const TIER_NONE := "none"
const TIER_BRONZE := "bronze"
const TIER_SILVER := "silver"
const TIER_GOLD := "gold"

const VIS_VISIBLE := "visible"
const VIS_HIDDEN_DESC := "hidden_desc"
const VIS_SECRET := "secret"

const _ICON_FIRST_CLEAR := "res://resources/icons/ach_first_clear.svg"
const _ICON_ONE_MORE_LEVEL := "res://resources/icons/ach_one_more_level.svg"
const _ICON_STAR := "res://resources/icons/icon_star_on.svg"
const _ICON_FIRST_HARD := "res://resources/icons/ach_first_hard.svg"
const _ICON_NO_HINT := "res://resources/icons/ach_no_hint_clear.svg"
const _ICON_ON_TIME := "res://resources/icons/ach_on_time.svg"
const _ICON_EASY_SET := "res://resources/icons/ach_easy_set.svg"
const _ICON_MEDIUM_SET := "res://resources/icons/ach_medium_set.svg"
const _ICON_HARD_SET := "res://resources/icons/ach_hard_set.svg"
const _ICON_THREE_STAR := "res://resources/icons/ach_three_star_debut.svg"
const _ICON_UNDO_NOTHING := "res://resources/icons/ach_undo_nothing.svg"
const _ICON_AD_FRIEND := "res://resources/icons/ach_ad_friend.svg"
const _ICON_IM_BLUE := "res://resources/icons/ach_im_blue.svg"
const _ICON_SHALL_NOT_PASS := "res://resources/icons/ach_shall_not_pass.svg"
const _ICON_RULES_READER := "res://resources/icons/ach_rules_reader.svg"
const _ICON_PURPLE_RAIN := "res://resources/icons/ach_purple_rain.svg"
const _ICON_YELLOW_SUBMARINE := "res://resources/icons/ach_yellow_submarine.svg"
const _ICON_PAUSE_THINKER := "res://resources/icons/ach_pause_thinker.svg"
const _ICON_DEV_MODE := "res://resources/icons/ach_dev_mode.svg"

const _MEDAL_BRONZE := "res://resources/icons/ach_medal_bronze.svg"
const _MEDAL_SILVER := "res://resources/icons/ach_medal_silver.svg"
const _MEDAL_GOLD := "res://resources/icons/ach_medal_gold.svg"
const _MEDAL_BRONZE_OUTLINE := "res://resources/icons/ach_medal_bronze_outline.svg"
const _MEDAL_SILVER_OUTLINE := "res://resources/icons/ach_medal_silver_outline.svg"
const _MEDAL_GOLD_OUTLINE := "res://resources/icons/ach_medal_gold_outline.svg"
const _ICON_MYSTERY := _MEDAL_BRONZE_OUTLINE

## Per-id metadata. Keep old save ids so existing unlocks still count.
## Keys: tier (none/bronze/silver/gold), family ("" or shared family id), visibility.
const _META := {
	"first_clear": {"tier": "none", "family": "", "visibility": "visible"},
	"clears_bronze": {"tier": "bronze", "family": "clears", "visibility": "visible"},
	"clears_silver": {"tier": "silver", "family": "clears", "visibility": "visible"},
	"clears_gold": {"tier": "gold", "family": "clears", "visibility": "visible"},
	"first_hard": {"tier": "none", "family": "", "visibility": "visible"},
	"no_hint_clear": {"tier": "bronze", "family": "no_hint", "visibility": "visible"},
	"hint_saver": {"tier": "silver", "family": "no_hint", "visibility": "visible"},
	"no_hint_gold": {"tier": "gold", "family": "no_hint", "visibility": "visible"},
	"on_time_bronze": {"tier": "bronze", "family": "on_time", "visibility": "visible"},
	"on_time_silver": {"tier": "silver", "family": "on_time", "visibility": "visible"},
	"on_time_gold": {"tier": "gold", "family": "on_time", "visibility": "visible"},
	"easy_set": {"tier": "none", "family": "", "visibility": "visible"},
	"medium_set": {"tier": "none", "family": "", "visibility": "visible"},
	"hard_set": {"tier": "none", "family": "", "visibility": "visible"},
	"three_star_debut": {"tier": "none", "family": "", "visibility": "visible"},
	"undo_nothing": {"tier": "none", "family": "", "visibility": "visible"},
	"ad_friend": {"tier": "none", "family": "", "visibility": "visible"},
	"im_blue": {"tier": "none", "family": "", "visibility": "hidden_desc"},
	"shall_not_pass": {"tier": "none", "family": "", "visibility": "hidden_desc"},
	"rules_reader": {"tier": "none", "family": "", "visibility": "hidden_desc"},
	"purple_rain": {"tier": "none", "family": "", "visibility": "hidden_desc"},
	"yellow_submarine": {"tier": "none", "family": "", "visibility": "hidden_desc"},
	"pause_thinker": {"tier": "none", "family": "", "visibility": "hidden_desc"},
	"dev_mode": {"tier": "none", "family": "", "visibility": "secret"},
}


## True when `id` is a catalogued achievement.
static func is_known(id: String) -> bool:
	return ORDERED_IDS.has(str(id))


## i18n key for the achievement title.
static func title_key(id: String) -> String:
	return "ACH_%s_NAME" % str(id).to_upper()


## i18n key for the achievement description.
static func desc_key(id: String) -> String:
	return "ACH_%s_DESC" % str(id).to_upper()


## Bronze-tier catalog id used for shared family copy (title + description).
static func family_display_id(id: String) -> String:
	var fam := family(id)
	if fam.is_empty():
		return str(id)
	var members: Array = family_members(fam)
	if members.is_empty():
		return str(id)
	return str(members[0])


## i18n key for grid/toast title — ranked families share the bronze tier name.
static func display_title_key(id: String, is_unlocked: bool) -> String:
	if identity_visible(id, is_unlocked):
		return title_key(family_display_id(id))
	return "ACH_HIDDEN_NAME"


## i18n key for grid description — ranked families share the bronze tier blurb.
static func display_desc_key(id: String) -> String:
	return desc_key(family_display_id(id))


## Catalog metadata for `id` (missing ids get visible / no-tier defaults).
static func entry(id: String) -> Dictionary:
	var key := str(id)
	if _META.has(key):
		return (_META[key] as Dictionary).duplicate()
	return {"tier": TIER_NONE, "family": "", "visibility": VIS_VISIBLE}


## bronze/silver/gold, or none when this id is not part of a ranked family.
static func tier(id: String) -> String:
	return str(entry(id).get("tier", TIER_NONE))


## Shared family id for ranked medals; empty string means a standalone achievement.
static func family(id: String) -> String:
	return str(entry(id).get("family", ""))


## visible: full row always. hidden_desc: mystery slot until unlock. secret: omitted until unlock.
static func visibility(id: String) -> String:
	return str(entry(id).get("visibility", VIS_VISIBLE))


## True when the real icon and title may be shown (hidden_desc stays mystery until unlock).
static func identity_visible(id: String, is_unlocked: bool) -> bool:
	if is_unlocked:
		return true
	return visibility(id) == VIS_VISIBLE


## Icon path for list/toast; hidden locked cells use no icon (lock + ??? only).
static func display_icon_path(id: String, is_unlocked: bool) -> String:
	if identity_visible(id, is_unlocked):
		return icon_path(id)
	return ""


## Generic mystery outline for hidden locked grid cells (dimmed like other locked icons).
static func hidden_locked_icon_path() -> String:
	return _ICON_MYSTERY


## Multiplicative tint for ranked-family icons (bronze/silver/gold). White when unranked.
static func tier_modulate(id: String) -> Color:
	match tier(id):
		TIER_BRONZE:
			return Color(1.35, 0.88, 0.48, 1.0)
		TIER_SILVER:
			return Color(1.18, 1.18, 1.32, 1.0)
		TIER_GOLD:
			return Color(1.42, 1.18, 0.42, 1.0)
		_:
			return Color.WHITE


## True when a row with this visibility should appear in the grid.
static func listed_when(vis: String, is_unlocked: bool) -> bool:
	if vis == VIS_SECRET:
		return is_unlocked
	return true


## True when the description line should be shown (hidden_desc waits for unlock).
static func desc_visible(id: String, is_unlocked: bool) -> bool:
	return desc_shown_when(visibility(id), is_unlocked)


## Visibility helper so tests can cover hidden/secret without extra live ids.
static func desc_shown_when(vis: String, is_unlocked: bool) -> bool:
	if is_unlocked:
		return true
	return vis == VIS_VISIBLE


## HUD-style 64x64 SVG path for this id (locked cells still use this, then dim).
## Ranked families share one base icon; medal overlay distinguishes bronze/silver/gold.
static func icon_path(id: String) -> String:
	var fam := family(id)
	if fam == FAM_CLEARS:
		return _ICON_ONE_MORE_LEVEL
	if fam == FAM_NO_HINT:
		return _ICON_NO_HINT
	if fam == FAM_ON_TIME:
		return _ICON_ON_TIME
	match str(id):
		ID_FIRST_CLEAR:
			return _ICON_FIRST_CLEAR
		ID_FIRST_HARD:
			return _ICON_FIRST_HARD
		ID_EASY_SET:
			return _ICON_EASY_SET
		ID_MEDIUM_SET:
			return _ICON_MEDIUM_SET
		ID_HARD_SET:
			return _ICON_HARD_SET
		ID_THREE_STAR_DEBUT:
			return _ICON_THREE_STAR
		ID_UNDO_NOTHING:
			return _ICON_UNDO_NOTHING
		ID_AD_FRIEND:
			return _ICON_AD_FRIEND
		ID_IM_BLUE:
			return _ICON_IM_BLUE
		ID_SHALL_NOT_PASS:
			return _ICON_SHALL_NOT_PASS
		ID_RULES_READER:
			return _ICON_RULES_READER
		ID_PURPLE_RAIN:
			return _ICON_PURPLE_RAIN
		ID_YELLOW_SUBMARINE:
			return _ICON_YELLOW_SUBMARINE
		ID_PAUSE_THINKER:
			return _ICON_PAUSE_THINKER
		ID_DEV_MODE:
			return _ICON_DEV_MODE
		_:
			return _ICON_STAR


## Tint for grid/toast icons: highest earned tier in a family, or the family bronze when none earned.
static func display_tier_modulate(id: String, unlocked_map: Dictionary) -> Color:
	var fam := family(id)
	if fam != "":
		var earned_id := ""
		for mid in family_members(fam):
			if unlocked_map.has(str(mid)):
				earned_id = str(mid)
		if not earned_id.is_empty():
			return tier_modulate(earned_id)
		var members: Array = family_members(fam)
		if not members.is_empty():
			return tier_modulate(str(members[0]))
	return tier_modulate(id)


## True when the grid cell should read as earned (any tier in a ranked family counts).
static func cell_is_unlocked(id: String, unlocked_map: Dictionary) -> bool:
	var fam := family(id)
	if fam != "":
		for mid in family_members(fam):
			if unlocked_map.has(str(mid)):
				return true
		return false
	return unlocked_map.has(id)


## First unearned member in a ranked family, or empty when every tier is earned.
static func next_unearned_in_family(fam: String, unlocked_map: Dictionary) -> String:
	for mid in family_members(fam):
		if not unlocked_map.has(str(mid)):
			return str(mid)
	return ""


## Counter target for a tier id (0 when not tiered / not tracked).
static func progress_target_for_id(id: String) -> int:
	match str(id):
		ID_CLEARS_BRONZE, ID_NO_HINT_CLEAR, ID_ON_TIME_BRONZE:
			return CLEARS_BRONZE_TARGET
		ID_CLEARS_SILVER, ID_HINT_SAVER, ID_ON_TIME_SILVER:
			return CLEARS_SILVER_TARGET
		ID_CLEARS_GOLD, ID_NO_HINT_GOLD, ID_ON_TIME_GOLD:
			return CLEARS_GOLD_TARGET
		_:
			return 0


## Tiered cells: show bronze/silver/gold thresholds; highlight the last earned tier.
static func progress_for_cell(display_id: String, unlocked_map: Dictionary, _state: Dictionary) -> Dictionary:
	var fam := family(display_id)
	if fam.is_empty():
		return {"show": false, "thresholds": [], "highlight_index": -1}
	var thresholds := family_tier_targets(fam)
	if thresholds.is_empty():
		return {"show": false, "thresholds": [], "highlight_index": -1}
	return {
		"show": true,
		"thresholds": thresholds,
		"highlight_index": last_earned_tier_index(fam, unlocked_map),
	}


## Bronze → gold clear counts for a ranked family (e.g. [10, 30, 60]).
static func family_tier_targets(fam: String) -> Array:
	var out: Array = []
	for mid in family_members(fam):
		var target := progress_target_for_id(str(mid))
		if target > 0:
			out.append(target)
	return out


## Index of the highest earned tier in `fam`, or -1 when none are earned.
static func last_earned_tier_index(fam: String, unlocked_map: Dictionary) -> int:
	var last := -1
	var members: Array = family_members(fam)
	for i in members.size():
		if unlocked_map.has(str(members[i])):
			last = i
	return last


## Small filled medal for an earned tier id.
static func tier_badge_path(id: String) -> String:
	return medal_overlay_path(id, true)


## Medal for the highest earned tier in a ranked family; empty when none earned.
static func earned_tier_badge_path(id: String, unlocked_map: Dictionary) -> String:
	var fam := family(id)
	if fam.is_empty():
		return ""
	var earned_id := ""
	for mid in family_members(fam):
		if unlocked_map.has(str(mid)):
			earned_id = str(mid)
	if earned_id.is_empty():
		return ""
	return tier_badge_path(earned_id)


## Dim outline medal preview for the next unearned tier in a ranked family.
static func next_tier_badge_path(next_id: String) -> String:
	match tier(next_id):
		TIER_BRONZE:
			return _MEDAL_BRONZE_OUTLINE
		TIER_SILVER:
			return _MEDAL_SILVER_OUTLINE
		TIER_GOLD:
			return _MEDAL_GOLD_OUTLINE
		_:
			return ""


## Dimmed next-tier medal preview for partially progressed ranked families.
static func next_tier_preview_path(next_id: String) -> String:
	return next_tier_badge_path(next_id)


## Corner badge for achievement grid icons; empty until a family tier is earned.
static func display_tier_badge_path(id: String, unlocked_map: Dictionary) -> String:
	if family(id).is_empty():
		return ""
	if not cell_is_unlocked(id, unlocked_map):
		return ""
	return earned_tier_badge_path(id, unlocked_map)


## Small medal overlay path, or empty when the id is not ranked.
static func medal_overlay_path(id: String, is_unlocked: bool) -> String:
	var t := tier(id)
	if t == TIER_NONE or t.is_empty():
		return ""
	if not is_unlocked:
		return _MEDAL_BRONZE_OUTLINE
	match t:
		TIER_BRONZE:
			return _MEDAL_BRONZE
		TIER_SILVER:
			return _MEDAL_SILVER
		TIER_GOLD:
			return _MEDAL_GOLD
		_:
			return ""


## Catalog ids that share `fam`, in ORDERED_IDS order (bronze → gold).
static func family_members(fam: String) -> Array:
	var out: Array = []
	if fam.is_empty():
		return out
	for id in ORDERED_IDS:
		if family(str(id)) == fam:
			out.append(str(id))
	return out


## Highest earned member of `fam`, or the bronze (first) member when none earned.
static func display_id_for_family(fam: String, unlocked: Dictionary) -> String:
	var members: Array = family_members(fam)
	if members.is_empty():
		return ""
	var best := str(members[0])
	for id in members:
		if unlocked.has(str(id)):
			best = str(id)
	return best


## Grid display ids: catalog order, secrets omitted until unlock, families collapsed to one cell.
static func grid_ids(unlocked: Dictionary = {}) -> Array:
	var out: Array = []
	var seen_families: Dictionary = {}
	for raw in ORDERED_IDS:
		var id := str(raw)
		var fam := family(id)
		if fam != "":
			if seen_families.has(fam):
				continue
			seen_families[fam] = true
			var any_earned := false
			for mid in family_members(fam):
				if unlocked.has(str(mid)):
					any_earned = true
					break
			var display := display_id_for_family(fam, unlocked)
			if display.is_empty():
				continue
			if not listed_when(visibility(display), any_earned):
				continue
			out.append(display)
			continue
		if not listed_when(visibility(id), unlocked.has(id)):
			continue
		out.append(id)
	return out


## Adds `id` when it is not already present in `already` or `out`.
static func _maybe_add(out: Array, id: String, already: Dictionary) -> void:
	if already.has(id):
		return
	if out.has(id):
		return
	out.append(id)


## Writes `id` into `already` once. Returns true when this call is the first grant.
static func apply_grant(already: Dictionary, id: String, timestamp: int = 0) -> bool:
	var sid := str(id).strip_edges()
	if sid.is_empty() or not is_known(sid) or already.has(sid):
		return false
	already[sid] = timestamp
	return true


## True when every player-fillable cell on the board is BLUE.
## Ignores walls, locked starters, shifter tiles, and off-board pool cells.
## Needs at least one fillable cell. `cells` values may be Cell nodes or dict snapshots.
static func board_is_all_blue(cells: Dictionary) -> bool:
	return _board_is_all_tile_state(cells, GameConstants.TileState.BLUE)


## True when every player-fillable cell on the board is YELLOW.
static func board_is_all_yellow(cells: Dictionary) -> bool:
	return _board_is_all_tile_state(cells, GameConstants.TileState.YELLOW)


static func _board_is_all_tile_state(cells: Dictionary, want_state: int) -> bool:
	var fillable := 0
	for key in cells:
		var cell: Variant = cells[key]
		var playable := bool(_cell_field(cell, "is_playable", true))
		var locked := bool(_cell_field(cell, "is_locked", false))
		var state := int(_cell_field(cell, "state", GameConstants.TileState.EMPTY))
		if not playable or locked:
			continue
		if state == GameConstants.TileState.WALL or state == GameConstants.TileState.SHIFTER:
			continue
		fillable += 1
		if state != want_state:
			return false
	return fillable > 0


## Reads a property from a Cell node or a dictionary snapshot.
static func _cell_field(cell: Variant, key: String, fallback: Variant) -> Variant:
	if cell == null:
		return fallback
	if typeof(cell) == TYPE_DICTIONARY:
		return (cell as Dictionary).get(key, fallback)
	if cell is Object:
		var got: Variant = (cell as Object).get(key)
		if got == null:
			return fallback
		return got
	return fallback


## Returns newly earned ids for the given progress snapshot (unique, catalog order).
## `state` keys:
##   campaign_clears (int, unique clears only — replays never count),
##   hard_clears (int), no_hint_clears (int), on_time_clears (int),
##   shifter_slides (int), rules_opens (int),
##   easy_complete / medium_complete / hard_complete (bool),
##   three_star_debut / undo_nothing / ad_friend / pause_thinker (bool flags),
##   im_blue / yellow_submarine / shall_not_pass / dev_mode (bool flags; grant() bypasses collect)
## `already` maps unlocked id -> unix timestamp (or any truthy value).
static func collect_unlocks(state: Dictionary, already: Dictionary = {}) -> Array:
	var out: Array = []
	var unique_clears := int(state.get("campaign_clears", 0))
	if unique_clears >= 1:
		_maybe_add(out, ID_FIRST_CLEAR, already)
	if unique_clears >= CLEARS_BRONZE_TARGET:
		_maybe_add(out, ID_CLEARS_BRONZE, already)
	if unique_clears >= CLEARS_SILVER_TARGET:
		_maybe_add(out, ID_CLEARS_SILVER, already)
	if unique_clears >= CLEARS_GOLD_TARGET:
		_maybe_add(out, ID_CLEARS_GOLD, already)
	if int(state.get("hard_clears", 0)) >= 1:
		_maybe_add(out, ID_FIRST_HARD, already)
	var no_hint := int(state.get("no_hint_clears", 0))
	if no_hint >= NO_HINT_BRONZE_TARGET:
		_maybe_add(out, ID_NO_HINT_CLEAR, already)
	if no_hint >= HINT_SAVER_TARGET:
		_maybe_add(out, ID_HINT_SAVER, already)
	if no_hint >= NO_HINT_GOLD_TARGET:
		_maybe_add(out, ID_NO_HINT_GOLD, already)
	var on_time := int(state.get("on_time_clears", 0))
	if on_time >= ON_TIME_BRONZE_TARGET:
		_maybe_add(out, ID_ON_TIME_BRONZE, already)
	if on_time >= ON_TIME_SILVER_TARGET:
		_maybe_add(out, ID_ON_TIME_SILVER, already)
	if on_time >= ON_TIME_GOLD_TARGET:
		_maybe_add(out, ID_ON_TIME_GOLD, already)
	if int(state.get("shifter_slides", 0)) >= PURPLE_RAIN_TARGET:
		_maybe_add(out, ID_PURPLE_RAIN, already)
	if int(state.get("rules_opens", 0)) >= RULES_READER_TARGET:
		_maybe_add(out, ID_RULES_READER, already)
	if bool(state.get("easy_complete", false)):
		_maybe_add(out, ID_EASY_SET, already)
	if bool(state.get("medium_complete", false)):
		_maybe_add(out, ID_MEDIUM_SET, already)
	if bool(state.get("hard_complete", false)):
		_maybe_add(out, ID_HARD_SET, already)
	if bool(state.get(ID_THREE_STAR_DEBUT, false)):
		_maybe_add(out, ID_THREE_STAR_DEBUT, already)
	if bool(state.get(ID_UNDO_NOTHING, false)):
		_maybe_add(out, ID_UNDO_NOTHING, already)
	if bool(state.get(ID_AD_FRIEND, false)):
		_maybe_add(out, ID_AD_FRIEND, already)
	if bool(state.get(ID_PAUSE_THINKER, false)):
		_maybe_add(out, ID_PAUSE_THINKER, already)
	# Event jokes: only when explicitly flagged. grant() writes the id directly.
	if bool(state.get(ID_IM_BLUE, false)):
		_maybe_add(out, ID_IM_BLUE, already)
	if bool(state.get(ID_YELLOW_SUBMARINE, false)):
		_maybe_add(out, ID_YELLOW_SUBMARINE, already)
	if bool(state.get(ID_SHALL_NOT_PASS, false)):
		_maybe_add(out, ID_SHALL_NOT_PASS, already)
	if bool(state.get(ID_DEV_MODE, false)):
		_maybe_add(out, ID_DEV_MODE, already)
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
