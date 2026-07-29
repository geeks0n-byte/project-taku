class_name TutorialScripts
extends RefCounted

## Step kinds:
## message — tip with Next; board frozen (optional white masks / borders)
## practice — only highlighted cells clickable; auto-advances on correct tap
## done — unlock tools, clear guides, let player finish freely

const ICON_SIZE := 44
const LOCK_ICON_SIZE := 56

static func script_id_from_path(path: String) -> String:
	var p := path.strip_edges()
	if p.is_empty():
		return ""
	var base := p.get_file()
	if base.is_empty():
		return ""
	return base.get_basename()

static func has_script(script_id: String) -> bool:
	return not steps_for(script_id).is_empty()

static func steps_for(script_id: String) -> Array:
	match script_id:
		"level_1":
			return _level_1()
		_:
			return []

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

static func _level_1() -> Array:
	# Part 1 board: 4x4, Yellow/Blue prefill; player can still cycle Green.
	# Locked prefill:
	#   (0,0)=Y  (3,0)=B
	#   (1,1)=Y  (2,1)=Y          ← two Yellows in row 1 → Rule of Two moment
	#   (0,2)=B  (3,2)=Y
	#   (1,3)=B  (2,3)=B          ← two Blues in row 3 → Equal Balance moment
	var y := GameConstants.TileState.YELLOW
	var b := GameConstants.TileState.BLUE
	var g := GameConstants.TileState.JOKER
	var e := GameConstants.TileState.EMPTY

	# Row 1: two Yellows locked, player fills (0,1) → must be Blue to avoid 3-in-a-row.
	var row1_all := [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]
	# Row 3: two Blues locked, player fills (0,3) → must be Yellow for equal balance.
	var row3_all := [Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)]
	var locked_part1 := [
		Vector2i(0, 0), Vector2i(3, 0),
		Vector2i(1, 1), Vector2i(2, 1),
		Vector2i(0, 2), Vector2i(3, 2),
		Vector2i(1, 3), Vector2i(2, 3),
	]

	# Part 2a board: Green behavior and one-Green-per-line.
	var green_layout := {
		Vector2i(0, 0): y, Vector2i(1, 0): b, Vector2i(2, 0): y, Vector2i(3, 0): g, Vector2i(4, 0): e,
		Vector2i(0, 1): b, Vector2i(1, 1): y, Vector2i(2, 1): g, Vector2i(3, 1): e, Vector2i(4, 1): y,
		Vector2i(0, 2): y, Vector2i(1, 2): e, Vector2i(2, 2): b, Vector2i(3, 2): y, Vector2i(4, 2): b,
		Vector2i(0, 3): g, Vector2i(1, 3): b, Vector2i(2, 3): e, Vector2i(3, 3): b, Vector2i(4, 3): y,
		Vector2i(0, 4): b, Vector2i(1, 4): y, Vector2i(2, 4): b, Vector2i(3, 4): y, Vector2i(4, 4): e,
	}
	var greens_on_board := [Vector2i(3, 0), Vector2i(2, 1), Vector2i(0, 3)]
	var row_green_dual := [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)]
	var row_odd_balance := [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)]

	# Part 2b board: Shifter behavior.
	var shifter_layout := {
		Vector2i(0, 0): e, Vector2i(1, 0): e, Vector2i(2, 0): y,
		Vector2i(0, 1): b, Vector2i(1, 1): y, Vector2i(2, 1): g,
		Vector2i(0, 2): y, Vector2i(1, 2): e, Vector2i(2, 2): e,
	}
	var shifter_pairs := [
		{"a": Vector2i(0, 0), "b": Vector2i(1, 0), "active": Vector2i(1, 0), "home": Vector2i(0, 0)},
		{"a": Vector2i(1, 2), "b": Vector2i(2, 2), "active": Vector2i(2, 2), "home": Vector2i(1, 2)},
	]

	# Part 2c board: Constraints (= and x).
	var constraint_layout := {
		Vector2i(0, 0): y, Vector2i(1, 0): e, Vector2i(2, 0): b, Vector2i(3, 0): e,
		Vector2i(0, 1): b, Vector2i(1, 1): y, Vector2i(2, 1): e, Vector2i(3, 1): y,
		Vector2i(0, 2): y, Vector2i(1, 2): b, Vector2i(2, 2): y, Vector2i(3, 2): b,
	}
	var constraint_pairs := [
		{"a": Vector2i(1, 0), "b": Vector2i(1, 1), "type": "equals"},
		{"a": Vector2i(2, 1), "b": Vector2i(3, 1), "type": "not_equals"},
	]

	return [
		# Step 1 — explain locks first.
		{
			"type": "message",
			"text_key": "TUT1_LOCKS",
			"icons": ["lock"],
			"show_next": true,
			"mask": locked_part1.duplicate(),
			"red": locked_part1.duplicate(),
		},
		# Step 2 — tap anything (free practice on one cell to learn controls).
		{
			"type": "message",
			"text_key": "TUT_INTRO_TAP",
			"show_next": true,
			"allow_board": true,
			"suppress_errors": true,
		},
		# Step 2 — Rule of Two: row 1 already has two Yellows, place Blue.
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
		# Step 3 — Equal Balance: row 3 has two Blues, place Yellow.
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
		# --- Part 2: Green + Shifter + Constraints ---
		{
			"type": "message",
			"text_key": "TUT_PART2_INTRO",
			"show_next": true,
		},
		{
			"type": "rebuild_board",
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
			"text_key": "TUT_GREEN_LIMIT",
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
			"type": "rebuild_board",
			"text_key": "TUT_SHIFTER_INTRO",
			"show_next": true,
			"layout": shifter_layout,
			"tiles": [y, b, g],
			"shifter_pairs": shifter_pairs,
			"mask": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 2), Vector2i(2, 2)],
			"red": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 2), Vector2i(2, 2)],
		},
		{
			"type": "message",
			"text_key": "TUT_SHIFTER_BLOCK",
			"show_next": true,
			"mask": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 2), Vector2i(2, 2)],
			"red": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 2), Vector2i(2, 2)],
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
			"text_key": "TUT_CONSTRAINTS_INTRO",
			"show_next": true,
			"layout": constraint_layout,
			"tiles": [y, b],
			"constraint_pairs": constraint_pairs,
			"mask": [Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
			"red": [Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
		},
		{
			"type": "message",
			"text_key": "TUT_EQUALS_RULE",
			"show_next": true,
			"mask": [Vector2i(1, 0), Vector2i(1, 1)],
			"red": [Vector2i(1, 0), Vector2i(1, 1)],
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
			"mask": [Vector2i(2, 1), Vector2i(3, 1)],
			"red": [Vector2i(2, 1), Vector2i(3, 1)],
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
		# --- Part 3: Top bar UI ---
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
		# Done — final free play until solved.
		{
			"type": "done",
			"text_key": "TUT_FINAL_FREE_PLAY",
		},
	]
