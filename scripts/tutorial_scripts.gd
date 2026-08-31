class_name TutorialScripts
extends RefCounted

# Static data store for all tutorial step sequences.
# Each tutorial is identified by a script_id (derived from the level file name)
# and returns an ordered Array of step Dictionaries consumed by TutorialDirector.

const ICON_SIZE := 44
const LOCK_ICON_SIZE := 56

## Basename of a level path without extension (e.g. levels/tutorials/level_1.tres → level_1).
static func script_id_from_path(path: String) -> String:
	var p := path.strip_edges()
	if p.is_empty():
		return ""
	var base := p.get_file()
	if base.is_empty():
		return ""
	return base.get_basename()

## True when steps_for returns a non-empty sequence for this id.
static func has_script(script_id: String) -> bool:
	return not steps_for(script_id).is_empty()

## Ordered TutorialDirector steps for a script id; unknown ids return [].
static func steps_for(script_id: String) -> Array:
	match script_id:
		"level_1":
			return _level_1()
		_:
			return []

## Returns the tutorial level when its script is not yet complete, otherwise level_1 for replay.
static func first_incomplete_level() -> LevelData:
	var paths := LevelUtils.scan_directory(GameConstants.CAMPAIGN_TUTORIALS_DIR)
	LevelUtils.sort_level_paths(paths)
	var fallback: LevelData = null
	for path in paths:
		var resource = load(path)
		if resource is LevelData:
			if fallback == null:
				fallback = resource
			var script_id := script_id_from_path(path)
			if not has_script(script_id):
				continue
			if SaveManager and SaveManager.is_tutorial_script_complete(script_id):
				continue
			return resource
	return fallback

## [img] tag for a tutorial token; lock uses a cropped region, others square.
static func icon_bbcode(token: String, size: int = -1) -> String:
	var path := _icon_path(token)
	if path.is_empty():
		return ""
	var icon_size := size
	if icon_size < 0:
		icon_size = LOCK_ICON_SIZE if token == "lock" else ICON_SIZE
	if token == "lock":
		return "[img height=%d region=36,36,56,64]%s[/img]" % [icon_size, path]
	return "[img=%dx%d]%s[/img]" % [icon_size, icon_size, path]

## Texture path for a tutorial icon token, or empty when unknown.
static func _icon_path(token: String) -> String:
	match token:
		"lock":  return GameConstants.TILE_LOCK
		"empty":  return GameConstants.TILE_EMPTY
		"yellow": return GameConstants.TILE_YELLOW
		"blue":   return GameConstants.TILE_BLUE
		"green":  return GameConstants.TILE_GREEN
		"shifter": return GameConstants.TILE_SHIFTER
		"reset":  return "res://resources/icons/icon_reset.svg"
		"rules":  return "res://resources/icons/icon_rules.svg"
		"hint":   return GameConstants.ICON_HINT_ON
		"undo":   return "res://resources/icons/icon_undo.svg"
		"redo":   return "res://resources/icons/icon_redo.svg"
		"star":   return "res://resources/icons/icon_star_on.svg"
		_:        return ""

# One continuous tutorial: the board rebuilds between phases while the player stays
# in the same level. Phases — basics → Green → Purple → links → hold/stars/tools → solve.
static func _level_1() -> Array:
	var y := GameConstants.TileState.YELLOW
	var b := GameConstants.TileState.BLUE
	var g := GameConstants.TileState.JOKER
	var e := GameConstants.TileState.EMPTY

	var yb := ["yellow", "blue"]

	# --- Phase 1: starter 4×4 (matches levels/tutorials/level_1.tres) ---
	var locked_p1 := [
		Vector2i(0, 0), Vector2i(3, 0),
		Vector2i(1, 1), Vector2i(2, 1),
		Vector2i(0, 2), Vector2i(3, 2),
		Vector2i(1, 3), Vector2i(2, 3),
	]
	var empty_p1 := [
		Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(0, 1), Vector2i(3, 1),
		Vector2i(1, 2), Vector2i(2, 2),
		Vector2i(0, 3), Vector2i(3, 3),
	]
	var rule_row_p1 := [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]
	var bal_row_p1 := [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)]

	# --- Phase 2: Green on 5×5 ---
	var green_layout := {
		Vector2i(0, 0): e, Vector2i(1, 0): e, Vector2i(2, 0): e, Vector2i(3, 0): g, Vector2i(4, 0): e,
		Vector2i(0, 1): e, Vector2i(1, 1): y, Vector2i(2, 1): g, Vector2i(3, 1): e, Vector2i(4, 1): y,
		Vector2i(0, 2): y, Vector2i(1, 2): e, Vector2i(2, 2): b, Vector2i(3, 2): y, Vector2i(4, 2): b,
		Vector2i(0, 3): g, Vector2i(1, 3): e, Vector2i(2, 3): e, Vector2i(3, 3): e, Vector2i(4, 3): e,
		Vector2i(0, 4): e, Vector2i(1, 4): e, Vector2i(2, 4): e, Vector2i(3, 4): e, Vector2i(4, 4): e,
	}
	var greens_on_board := [Vector2i(3, 0), Vector2i(2, 1), Vector2i(0, 3)]
	var row_green_dual := [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)]

	# --- Phase 3: two Purple shifters on 5×5 ---
	var shifter_layout := {
		Vector2i(0, 0): e, Vector2i(1, 0): e, Vector2i(2, 0): e, Vector2i(3, 0): y, Vector2i(4, 0): e,
		Vector2i(0, 1): e, Vector2i(1, 1): e, Vector2i(2, 1): e, Vector2i(3, 1): e, Vector2i(4, 1): b,
		Vector2i(0, 2): e, Vector2i(1, 2): e, Vector2i(2, 2): e, Vector2i(3, 2): e, Vector2i(4, 2): e,
		Vector2i(0, 3): y, Vector2i(1, 3): e, Vector2i(2, 3): e, Vector2i(3, 3): e, Vector2i(4, 3): e,
		Vector2i(0, 4): e, Vector2i(1, 4): e, Vector2i(2, 4): b, Vector2i(3, 4): e, Vector2i(4, 4): y,
	}
	var shifter_pairs := [
		{"a": Vector2i(0, 0), "b": Vector2i(1, 0), "active": Vector2i(1, 0), "home": Vector2i(0, 0)},
		{"a": Vector2i(1, 2), "b": Vector2i(2, 2), "active": Vector2i(2, 2), "home": Vector2i(1, 2)},
	]
	var shifter_highlight := [
		Vector2i(0, 0), Vector2i(1, 0),
		Vector2i(1, 2), Vector2i(2, 2),
	]

	# --- Phase 4: = and × links on 4×4 ---
	var links_layout := {
		Vector2i(0, 0): y, Vector2i(1, 0): e, Vector2i(2, 0): b, Vector2i(3, 0): e,
		Vector2i(0, 1): b, Vector2i(1, 1): y, Vector2i(2, 1): e, Vector2i(3, 1): y,
		Vector2i(0, 2): y, Vector2i(1, 2): b, Vector2i(2, 2): y, Vector2i(3, 2): b,
		Vector2i(0, 3): b, Vector2i(1, 3): b, Vector2i(2, 3): y, Vector2i(3, 3): y,
	}
	var link_pairs := [
		{"a": Vector2i(1, 0), "b": Vector2i(1, 1), "type": "equals"},
		{"a": Vector2i(2, 1), "b": Vector2i(3, 1), "type": "not_equals"},
	]
	var link_all := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]
	var link_equals := [Vector2i(1, 0), Vector2i(1, 1)]
	var link_not_equals := [Vector2i(2, 1), Vector2i(3, 1)]
	# Empty in layout — player fills this in × practice, so it stays unlocked for hold-to-clear.
	var hold_cell := Vector2i(2, 1)

	return [
		# Phase 1 — locks, Rule of Two, Equal Balance
		{
			"type": "message",
			"text_key": "TUT1_WELCOME",
			"icons": ["empty", "yellow", "blue"],
			"show_next": true,
			"mask": empty_p1.duplicate(),
			"red": empty_p1.duplicate(),
		},
		{
			"type": "message",
			"text_key": "TUT1_LOCKS",
			"icons": ["lock"],
			"show_next": true,
			"mask": locked_p1.duplicate(),
			"red": locked_p1.duplicate(),
		},
		{
			"type": "message",
			"text_key": "TUT2_RULE_INTRO",
			"icons": ["yellow"],
			"show_next": true,
			"mask": rule_row_p1.duplicate(),
			"red": rule_row_p1.duplicate(),
		},
		{
			"type": "practice",
			"text_key": "TUT2_RULE_PRACTICE",
			"icons": ["blue"],
			"wrong_key": "TUT2_WRONG_THREE",
			"wrong_icons": ["yellow", "blue"],
			"success_key": "TUT2_GOOD_RULE",
			"coord": Vector2i(0, 1),
			"state": b,
			"cycle": [y, b],
			"mask": [Vector2i(0, 1)],
			"red": [Vector2i(0, 1)],
		},
		{
			"type": "message",
			"text_key": "TUT3_BALANCE_INTRO_2",
			"icons": yb,
			"show_next": true,
			"mask": bal_row_p1.duplicate(),
			"red": bal_row_p1.duplicate(),
		},
		{
			"type": "practice",
			"text_key": "TUT3_BALANCE_PRACTICE_Y",
			"icons": ["yellow"],
			"wrong_key": "TUT3_WRONG_BALANCE_Y",
			"wrong_icons": ["yellow"],
			"success_key": "TUT3_GOOD_BALANCE",
			"success_icons": yb,
			"coord": Vector2i(0, 3),
			"state": y,
			"cycle": [y, b],
			"mask": [Vector2i(0, 3)],
			"red": [Vector2i(0, 3)],
		},

		# Phase 2 — Green tiles
		{
			"type": "rebuild_board",
			"pending_key": "TUT_NEXT_GREEN",
			"text_key": "TUT4_INTRO",
			"icons": ["green", "yellow", "blue"],
			"show_next": true,
			"layout": green_layout,
			"tiles": [y, b, g],
			"mask": greens_on_board.duplicate(),
			"red": greens_on_board.duplicate(),
		},
		{
			"type": "message",
			"text_key": "TUT4_GREEN_DUAL",
			"icons": ["green", "yellow"],
			"show_next": true,
			"mask": row_green_dual.duplicate(),
			"red": row_green_dual.duplicate(),
		},
		{
			"type": "practice",
			"text_key": "TUT4_DUAL_PRACTICE",
			"icons": ["blue", "yellow", "green"],
			"wrong_key": "TUT4_DUAL_WRONG",
			"wrong_icons": ["green", "yellow", "blue"],
			"success_key": "TUT4_DUAL_GOOD",
			"success_icons": ["blue"],
			"coord": Vector2i(3, 1),
			"state": b,
			"cycle": [y, b, g],
			"mask": [Vector2i(3, 1)],
			"red": [Vector2i(3, 1)],
		},
		{
			"type": "message",
			"text_key": "TUT4_ODD_BALANCE",
			"icons": ["green"],
			"show_next": true,
			"mask": [Vector2i(1, 2), Vector2i(0, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)],
			"red": [Vector2i(1, 2), Vector2i(0, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)],
		},
		{
			"type": "practice",
			"text_key": "TUT4_MAX_PRACTICE",
			"icons": ["green"],
			"wrong_key": "TUT4_WRONG_COLOR",
			"wrong_icons": ["green", "yellow", "blue"],
			"success_key": "TUT4_GOOD_GREEN",
			"coord": Vector2i(1, 2),
			"state": g,
			"cycle": [y, b, g],
			"mask": [Vector2i(1, 2)],
			"red": [Vector2i(1, 2)],
		},

		# Phase 3 — Purple shifters (two hops + two fills)
		{
			"type": "rebuild_board",
			"pending_key": "TUT_NEXT_PURPLE",
			"text_key": "TUT5_INTRO",
			"icons": ["shifter"],
			"show_next": true,
			"layout": shifter_layout,
			"tiles": [y, b, g],
			"shifter_pairs": shifter_pairs,
			"mask": shifter_highlight.duplicate(),
			"red": shifter_highlight.duplicate(),
		},
		{
			"type": "practice",
			"text_key": "TUT5_MOVE_SHIFTER",
			"icons": ["shifter"],
			"success_key": "TUT5_GOOD_SHIFTER",
			"success_icons": ["shifter"],
			"coord": Vector2i(0, 0),
			"from": Vector2i(1, 0),
			"wait_shifter": true,
			"mask": [Vector2i(1, 0)],
			"red": [Vector2i(1, 0)],
		},
		{
			"type": "practice",
			"text_key": "TUT5_PLACE_FILL",
			"icons": ["blue"],
			"wrong_key": "TUT5_WRONG_FILL",
			"wrong_icons": ["blue"],
			"success_key": "TUT5_GOOD_FILL",
			"coord": Vector2i(1, 0),
			"state": b,
			"cycle": [y, b, g],
			"mask": [Vector2i(1, 0)],
			"red": [Vector2i(1, 0)],
		},
		{
			"type": "practice",
			"text_key": "TUT5_MOVE_SHIFTER_2",
			"icons": ["shifter"],
			"success_key": "TUT5_GOOD_SHIFTER",
			"success_icons": ["shifter"],
			"coord": Vector2i(1, 2),
			"from": Vector2i(2, 2),
			"wait_shifter": true,
			"mask": [Vector2i(2, 2)],
			"red": [Vector2i(2, 2)],
		},
		{
			"type": "practice",
			"text_key": "TUT5_PLACE_FILL_2",
			"icons": ["blue"],
			"wrong_key": "TUT5_WRONG_FILL",
			"wrong_icons": ["blue"],
			"success_key": "TUT5_GOOD_FILL",
			"coord": Vector2i(2, 2),
			"state": b,
			"cycle": [y, b, g],
			"mask": [Vector2i(2, 2)],
			"red": [Vector2i(2, 2)],
		},

		# Phase 4 — cell links
		{
			"type": "rebuild_board",
			"pending_key": "TUT_NEXT_CONSTRAINTS",
			"text_key": "TUT_CONSTRAINTS_INTRO",
			"show_next": true,
			"layout": links_layout,
			"tiles": [y, b],
			"constraint_pairs": link_pairs,
			"mask": link_all.duplicate(),
			"red": link_all.duplicate(),
		},
		{
			"type": "message",
			"text_key": "TUT6_EQUALS_INTRO",
			"show_next": true,
			"mask": link_equals.duplicate(),
			"red": link_equals.duplicate(),
		},
		{
			"type": "practice",
			"text_key": "TUT6_EQUALS_PRACTICE",
			"icons": ["yellow"],
			"wrong_key": "TUT6_WRONG_EQUALS",
			"wrong_icons": ["yellow"],
			"success_key": "TUT6_GOOD_EQUALS",
			"coord": Vector2i(1, 0),
			"state": y,
			"cycle": [y, b],
			"mask": [Vector2i(1, 0)],
			"red": [Vector2i(1, 0)],
		},
		{
			"type": "message",
			"text_key": "TUT6_NOTEQUALS_INTRO",
			"show_next": true,
			"mask": link_not_equals.duplicate(),
			"red": link_not_equals.duplicate(),
		},
		{
			"type": "practice",
			"text_key": "TUT6_NOTEQUALS_PRACTICE",
			"icons": ["yellow", "blue"],
			"wrong_key": "TUT6_WRONG_NOTEQUALS",
			"wrong_icons": ["blue"],
			"success_key": "TUT6_GOOD_NOTEQUALS",
			"coord": Vector2i(2, 1),
			"state": b,
			"cycle": [y, b],
			"mask": [Vector2i(2, 1)],
			"red": [Vector2i(2, 1)],
		},

		# Phase 5 — hold-to-remove, star goals, tools, final solve
		{
			"type": "message",
			"text_key": "TUT2_HOLD_INTRO",
			"show_next": true,
			"mask": [hold_cell],
			"red": [hold_cell],
		},
		{
			"type": "practice",
			"text_key": "TUT2_HOLD_CLEAR",
			"success_key": "TUT2_HOLD_CLEAR_OK",
			"coord": hold_cell,
			"wait_hold_clear": true,
			"mask": [hold_cell],
			"red": [hold_cell],
		},
		{
			"type": "message",
			"text_key": "TUT2_STARS",
			"icons": ["star", "star", "star"],
			"show_next": true,
		},
		{
			"type": "message",
			"text_key": "TUT6_TOOLS_INTRO",
			"show_next": true,
		},
		{
			"type": "message",
			"text_key": "TUT_UI_OVERVIEW",
			"icons": ["reset", "rules", "hint", "undo", "redo"],
			"show_next": true,
		},
		{
			"type": "done",
			"text_key": "TUTF_CONTINUE_TO_NEXT",
		},
	]
