class_name TutorialScripts
extends RefCounted

# Static data store for all tutorial step sequences.
# Each tutorial is identified by a script_id (derived from the level file name)
# and returns an ordered Array of step Dictionaries consumed by TutorialDirector.

# Default pixel size for tile icons embedded in BBCode status messages.
const ICON_SIZE := 44
# Lock icons are taller, so they use a larger size and a crop region.
const LOCK_ICON_SIZE := 56

# Converts a level file path (e.g. "res://levels/level_1.tres") to the
# corresponding tutorial script ID ("level_1") by stripping directory and extension.
static func script_id_from_path(path: String) -> String:
	var p := path.strip_edges()
	if p.is_empty():
		return ""
	var base := p.get_file()
	if base.is_empty():
		return ""
	return base.get_basename()

# Returns true when a tutorial sequence exists for the given script_id.
static func has_script(script_id: String) -> bool:
	return not steps_for(script_id).is_empty()

# Returns the step array for the given script_id, or an empty array if unknown.
# Add new tutorial scripts here as additional match arms.
static func steps_for(script_id: String) -> Array:
	match script_id:
		"level_1":
			return _level_1()
		_:
			return []

# Produces the BBCode [img] tag for a named icon token.
# The lock icon uses a crop region to trim its transparent padding.
# size defaults to LOCK_ICON_SIZE for "lock" and ICON_SIZE for everything else.
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

# Maps a short token name to its resource path. Returns "" for unknown tokens
# so callers can safely skip icon substitution when the token is unrecognised.
static func _icon_path(token: String) -> String:
	match token:
		"lock":  return GameConstants.TILE_LOCK
		"yellow": return GameConstants.TILE_YELLOW
		"blue":   return GameConstants.TILE_BLUE
		"green":  return GameConstants.TILE_GREEN
		"shifter": return GameConstants.TILE_SHIFTER
		"reset":  return "res://resources/icons/icon_reset.svg"
		"rules":  return "res://resources/icons/icon_rules.svg"
		"hint":   return GameConstants.ICON_HINT_ON
		"undo":   return "res://resources/icons/icon_undo.svg"
		"redo":   return "res://resources/icons/icon_redo.svg"
		_:        return ""

# Defines the full step sequence for the Level 1 tutorial.
# Steps teach: locked tiles, the three-in-a-row rule, the balance rule,
# joker tiles and their odd-row behaviour, shifter mechanics (blocked/unblocked),
# equals/not-equals constraint links, and the HUD tool buttons.
# Short aliases avoid repetition in the layout tables below.
static func _level_1() -> Array:
	var y := GameConstants.TileState.YELLOW
	var b := GameConstants.TileState.BLUE
	var g := GameConstants.TileState.JOKER
	var e := GameConstants.TileState.EMPTY

	var row1_all := [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]
	var row3_all := [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)]
	var locked_part1 := [
		Vector2i(0, 0), Vector2i(3, 0),
		Vector2i(1, 1), Vector2i(2, 1),
		Vector2i(0, 2), Vector2i(3, 2),
		Vector2i(1, 3), Vector2i(2, 3),
	]

	var green_layout := {
		Vector2i(0, 0): e, Vector2i(1, 0): e, Vector2i(2, 0): e, Vector2i(3, 0): g, Vector2i(4, 0): e,
		Vector2i(0, 1): e, Vector2i(1, 1): y, Vector2i(2, 1): g, Vector2i(3, 1): e, Vector2i(4, 1): y,
		Vector2i(0, 2): y, Vector2i(1, 2): e, Vector2i(2, 2): b, Vector2i(3, 2): y, Vector2i(4, 2): b,
		Vector2i(0, 3): g, Vector2i(1, 3): e, Vector2i(2, 3): e, Vector2i(3, 3): e, Vector2i(4, 3): e,
		Vector2i(0, 4): e, Vector2i(1, 4): e, Vector2i(2, 4): e, Vector2i(3, 4): e, Vector2i(4, 4): e,
	}
	var greens_on_board := [Vector2i(3, 0), Vector2i(2, 1), Vector2i(0, 3)]
	var row_green_dual := [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)]
	var row_odd_balance := [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)]

	var shifter_layout := {
		Vector2i(0, 0): e, Vector2i(1, 0): e, Vector2i(2, 0): e, Vector2i(3, 0): y, Vector2i(4, 0): e,
		Vector2i(0, 1): e, Vector2i(1, 1): e, Vector2i(2, 1): e, Vector2i(3, 1): e, Vector2i(4, 1): b,
		Vector2i(0, 2): e, Vector2i(1, 2): e, Vector2i(2, 2): e, Vector2i(3, 2): e, Vector2i(4, 2): e,
		Vector2i(0, 3): y, Vector2i(1, 3): e, Vector2i(2, 3): e, Vector2i(3, 3): e, Vector2i(4, 3): e,
		Vector2i(0, 4): e, Vector2i(1, 4): e, Vector2i(2, 4): b, Vector2i(3, 4): e, Vector2i(4, 4): y,
	}
	# Each shifter pair: "a"/"b" are the two cells it occupies, "active" is where
	# the shifter token currently sits, "home" is where it needs to end up for
	# the player to be able to place a tile on the inactive cell.
	var shifter_pairs := [
		{"a": Vector2i(0, 0), "b": Vector2i(1, 0), "active": Vector2i(1, 0), "home": Vector2i(0, 0)},
		{"a": Vector2i(1, 2), "b": Vector2i(2, 2), "active": Vector2i(2, 2), "home": Vector2i(1, 2)},
		{"a": Vector2i(2, 1), "b": Vector2i(3, 1), "active": Vector2i(3, 1), "home": Vector2i(2, 1)},
		{"a": Vector2i(3, 1), "b": Vector2i(3, 2), "active": Vector2i(3, 2), "home": Vector2i(3, 1)},
	]
	var shifter_highlight := [
		Vector2i(0, 0), Vector2i(1, 0),
		Vector2i(1, 2), Vector2i(2, 2),
		Vector2i(2, 1), Vector2i(3, 1), Vector2i(3, 2),
	]
	var shifter_shared_highlight := [Vector2i(2, 1), Vector2i(3, 1), Vector2i(3, 2)]

	var constraint_layout := {
		Vector2i(0, 0): y, Vector2i(1, 0): e, Vector2i(2, 0): b, Vector2i(3, 0): e,
		Vector2i(0, 1): b, Vector2i(1, 1): y, Vector2i(2, 1): e, Vector2i(3, 1): y,
		Vector2i(0, 2): y, Vector2i(1, 2): b, Vector2i(2, 2): y, Vector2i(3, 2): b,
		Vector2i(0, 3): b, Vector2i(1, 3): b, Vector2i(2, 3): y, Vector2i(3, 3): y,
	}
	var constraint_pairs := [
		{"a": Vector2i(1, 0), "b": Vector2i(1, 1), "type": "equals"},
		{"a": Vector2i(2, 1), "b": Vector2i(3, 1), "type": "not_equals"},
	]
	var constraint_all_links := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]
	var constraint_equals := [Vector2i(1, 0), Vector2i(1, 1)]
	var constraint_not_equals := [Vector2i(2, 1), Vector2i(3, 1)]

	return [
		{
			"type": "message",
			"text_key": "TUT1_LOCKS",
			"icons": ["lock"],
			"show_next": true,
			"mask": locked_part1.duplicate(),
			"red": locked_part1.duplicate(),
		},
		{
			"type": "message",
			"text_key": "TUT_INTRO_TAP",
			"free_place": true,
			"allow_board": true,
			"show_next": true,
			"suppress_errors": true,
		},
		{
			"type": "message",
			"text_key": "TUT_RULE_TWO",
			"show_next": true,
			"mask": row1_all.duplicate(),
			"red": row1_all.duplicate(),
		},
		{
			"type": "practice",
			"text_key": "TUT_PLACE_BLUE",
			"wrong_key": "TUT_WRONG_BLUE",
			"success_key": "TUT_GOOD",
			"coord": Vector2i(0, 1),
			"state": b,
			"cycle": [y, b, g],
			"mask": [Vector2i(0, 1)],
			"red": [Vector2i(0, 1)],
		},
		{
			"type": "message",
			"text_key": "TUT_BALANCE",
			"show_next": true,
			"mask": row3_all.duplicate(),
			"red": row3_all.duplicate(),
		},
		{
			"type": "practice",
			"text_key": "TUT_PLACE_YELLOW",
			"wrong_key": "TUT_WRONG_YELLOW",
			"success_key": "TUT_GOOD",
			"coord": Vector2i(0, 3),
			"state": y,
			"cycle": [y, b, g],
			"mask": [Vector2i(0, 3)],
			"red": [Vector2i(0, 3)],
		},
		{
			"type": "rebuild_board",
			"pending_key": "TUT_NEXT_GREEN",
			"text_key": "TUT_GREEN_INTRO",
			"show_next": true,
			"layout": green_layout,
			"tiles": [y, b, g],
			"mask": greens_on_board.duplicate(),
			"red": greens_on_board.duplicate(),
		},
		{
			"type": "message",
			"text_key": "TUT_GREEN_RULE_TWO",
			"show_next": true,
			"mask": row_green_dual.duplicate(),
			"red": row_green_dual.duplicate(),
		},
		{
			"type": "practice",
			"text_key": "TUT_GREEN_PLACE_BLUE",
			"wrong_key": "TUT_GREEN_WRONG_BLUE",
			"success_key": "TUT_GOOD",
			"coord": Vector2i(3, 1),
			"state": b,
			"cycle": [y, b, g],
			"mask": [Vector2i(3, 1)],
			"red": [Vector2i(3, 1)],
		},
		{
			"type": "message",
			"text_key": "TUT_GREEN_ODD_BALANCE",
			"show_next": true,
			"mask": row_odd_balance.duplicate(),
			"red": row_odd_balance.duplicate(),
		},
		{
			"type": "practice",
			"text_key": "TUT_GREEN_PLACE_GREEN",
			"wrong_key": "TUT_GREEN_WRONG_GREEN",
			"success_key": "TUT_GOOD",
			"coord": Vector2i(1, 2),
			"state": g,
			"cycle": [y, b, g],
			"mask": [Vector2i(1, 2)],
			"red": [Vector2i(1, 2)],
		},
		{
			"type": "message",
			"text_key": "TUT_GREEN_LIMIT",
			"show_next": true,
			"mask": [Vector2i(1, 2), Vector2i(3, 0), Vector2i(2, 1), Vector2i(0, 3)],
			"red": [Vector2i(1, 2), Vector2i(3, 0), Vector2i(2, 1), Vector2i(0, 3)],
		},
		{
			"type": "rebuild_board",
			"pending_key": "TUT_NEXT_PURPLE",
			"text_key": "TUT_SHIFTER_INTRO",
			"show_next": true,
			"layout": shifter_layout,
			"tiles": [y, b, g],
			"shifter_pairs": shifter_pairs,
			"mask": shifter_highlight.duplicate(),
			"red": shifter_highlight.duplicate(),
		},
		{
			"type": "message",
			"text_key": "TUT_SHIFTER_BLOCK",
			"show_next": true,
			"mask": shifter_shared_highlight.duplicate(),
			"red": shifter_shared_highlight.duplicate(),
		},
		{
			"type": "practice",
			"text_key": "TUT_SHIFTER_TRY_BLOCK",
			"wrong_key": "TUT_SHIFTER_TRY_BLOCK",
			"wait_blocked_shifter": true,
			"coord": Vector2i(3, 2),
			"from": Vector2i(3, 2),
			"mask": [Vector2i(3, 2)],
			"red": [Vector2i(3, 2)],
		},
		{
			"type": "practice",
			"text_key": "TUT_SHIFTER_MOVE_BLOCKER",
			"wrong_key": "TUT_SHIFTER_MOVE_BLOCKER",
			"success_key": "TUT_GOOD",
			"coord": Vector2i(2, 1),
			"from": Vector2i(3, 1),
			"wait_shifter": true,
			"mask": [Vector2i(3, 1)],
			"red": [Vector2i(3, 1)],
		},
		{
			"type": "practice",
			"text_key": "TUT_SHIFTER_MOVE_UNBLOCKED",
			"wrong_key": "TUT_SHIFTER_MOVE_UNBLOCKED",
			"success_key": "TUT_GOOD",
			"coord": Vector2i(3, 1),
			"from": Vector2i(3, 2),
			"wait_shifter": true,
			"mask": [Vector2i(3, 2)],
			"red": [Vector2i(3, 2)],
		},
		{
			"type": "practice",
			"text_key": "TUT_SHIFTER_MOVE_1",
			"wrong_key": "TUT_SHIFTER_MOVE_1",
			"success_key": "TUT_GOOD",
			"coord": Vector2i(0, 0),
			"from": Vector2i(1, 0),
			"wait_shifter": true,
			"mask": [Vector2i(1, 0)],
			"red": [Vector2i(1, 0)],
		},
		{
			"type": "practice",
			"text_key": "TUT_SHIFTER_FILL_1",
			"wrong_key": "TUT_SHIFTER_FILL_WRONG",
			"success_key": "TUT_GOOD",
			"coord": Vector2i(1, 0),
			"state": b,
			"cycle": [y, b, g],
			"mask": [Vector2i(1, 0)],
			"red": [Vector2i(1, 0)],
		},
		{
			"type": "practice",
			"text_key": "TUT_SHIFTER_MOVE_2",
			"wrong_key": "TUT_SHIFTER_MOVE_2",
			"success_key": "TUT_GOOD",
			"coord": Vector2i(1, 2),
			"from": Vector2i(2, 2),
			"wait_shifter": true,
			"mask": [Vector2i(2, 2)],
			"red": [Vector2i(2, 2)],
		},
		{
			"type": "practice",
			"text_key": "TUT_SHIFTER_FILL_2",
			"wrong_key": "TUT_SHIFTER_FILL_WRONG",
			"success_key": "TUT_GOOD",
			"coord": Vector2i(2, 2),
			"state": b,
			"cycle": [y, b, g],
			"mask": [Vector2i(2, 2)],
			"red": [Vector2i(2, 2)],
		},
		{
			"type": "rebuild_board",
			"pending_key": "TUT_NEXT_CONSTRAINTS",
			"text_key": "TUT_CONSTRAINTS_INTRO",
			"show_next": true,
			"layout": constraint_layout,
			"tiles": [y, b],
			"constraint_pairs": constraint_pairs,
			"mask": constraint_all_links.duplicate(),
			"red": constraint_all_links.duplicate(),
		},
		{
			"type": "message",
			"text_key": "TUT_EQUALS_RULE",
			"show_next": true,
			"mask": constraint_equals.duplicate(),
			"red": constraint_equals.duplicate(),
		},
		{
			"type": "practice",
			"text_key": "TUT_EQUALS_PLACE",
			"wrong_key": "TUT_EQUALS_WRONG",
			"success_key": "TUT_GOOD",
			"coord": Vector2i(1, 0),
			"state": y,
			"cycle": [y, b],
			"mask": [Vector2i(1, 0)],
			"red": [Vector2i(1, 0)],
		},
		{
			"type": "message",
			"text_key": "TUT_NOTEQUALS_RULE",
			"show_next": true,
			"mask": constraint_not_equals.duplicate(),
			"red": constraint_not_equals.duplicate(),
		},
		{
			"type": "practice",
			"text_key": "TUT_NOTEQUALS_PLACE",
			"wrong_key": "TUT_NOTEQUALS_WRONG",
			"success_key": "TUT_GOOD",
			"coord": Vector2i(2, 1),
			"state": b,
			"cycle": [y, b],
			"mask": [Vector2i(2, 1)],
			"red": [Vector2i(2, 1)],
		},
		{
			"type": "message",
			"text_key": "TUT_PART3_INTRO",
			"show_next": true,
		},
		{
			"type": "hud_button",
			"button": "reset",
			"text_key": "TUT_UI_RESET",
		},
		{
			"type": "hud_button",
			"button": "how_to_play",
			"text_key": "TUT_UI_RULES",
		},
		{
			"type": "hud_button",
			"button": "hint",
			"text_key": "TUT_UI_HINT",
		},
		{
			"type": "hud_button",
			"button": "undo",
			"text_key": "TUT_UI_UNDO",
		},
		{
			"type": "hud_button",
			"button": "redo",
			"text_key": "TUT_UI_REDO",
		},
		{
			"type": "done",
			"text_key": "TUT_FINAL_FREE_PLAY",
		},
	]
