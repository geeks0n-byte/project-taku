class_name TutorialScripts
extends RefCounted

## Step kinds:
## message — tip with Next; board frozen (optional white masks / borders)
## practice — only highlighted cells clickable; status updates on wrong/right
## hud_button — glow a top-bar tool; tap it or Next to advance
## wait_cell / wait_shifter — legacy auto-advance waits
## done — unlock tools, clear gates, keep a free-play tip until solved
##
## Focus fields:
## mask / highlight — white breathing cell masks (LinkHighlight)
## red / border — white breathing focus borders

const ICON_SIZE := 44
const LOCK_ICON_SIZE := 56

## Script ids match tutorial level basenames under CAMPAIGN_TUTORIALS_DIR
## (e.g. res://levels/tutorials/level_1.tres → "level_1").
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
		"level_2":
			return _level_2()
		"level_3":
			return _level_3()
		"level_4":
			return _level_4()
		"level_5":
			return _level_5()
		"level_6":
			return _level_6()
		_:
			return []

static func icon_bbcode(token: String, size: int = -1) -> String:
	var path := _icon_path(token)
	if path.is_empty():
		return ""
	var icon_size := size
	if icon_size < 0:
		icon_size = LOCK_ICON_SIZE if token == "lock" else ICON_SIZE
	# tile_lock.svg is a small glyph in a padded 16x16 cell; crop so text sits close.
	if token == "lock":
		return "[img height=%d region=36,36,56,64]%s[/img]" % [icon_size, path]
	return "[img=%dx%d]%s[/img]" % [icon_size, icon_size, path]

static func _icon_path(token: String) -> String:
	match token:
		"lock":
			return GameConstants.TILE_LOCK
		"yellow":
			return GameConstants.TILE_YELLOW
		"blue":
			return GameConstants.TILE_BLUE
		"green":
			return GameConstants.TILE_GREEN
		"shifter":
			return GameConstants.TILE_SHIFTER
		"reset":
			return "res://resources/icons/icon_reset.svg"
		"rules":
			return "res://resources/icons/icon_rules.svg"
		"hint":
			return GameConstants.ICON_HINT_ON
		"undo":
			return "res://resources/icons/icon_undo.svg"
		"redo":
			return "res://resources/icons/icon_redo.svg"
		_:
			return ""

static func _level_1() -> Array:
	# YYEE / BBEE / BYYB / YBBY — empties (2,0)(3,0)=Blue, (2,1)(3,1)=Yellow.
	var y := GameConstants.TileState.YELLOW
	var b := GameConstants.TileState.BLUE
	var locked: Array = [
		Vector2i(0, 0), Vector2i(1, 0),
		Vector2i(0, 1), Vector2i(1, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2),
		Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
	]
	return [
		{
			"type": "message",
			"text_key": "TUT1_WELCOME",
			"icons": ["yellow", "blue"],
		},
		{
			"type": "message",
			"text_key": "TUT1_LOCKS",
			"icons": ["lock"],
			"mask": locked,
			"red": locked,
		},
		{
			"type": "practice",
			"text_key": "TUT1_CYCLE",
			"wrong_key": "TUT1_WRONG_PLACE",
			"success_key": "TUT_GOOD",
			"icons": ["yellow", "blue"],
			"wrong_icons": ["blue"],
			"success_icons": [],
			"coord": Vector2i(2, 0),
			"state": b,
			"cycle": [y, b],
			"mask": [Vector2i(2, 0)],
			"red": [Vector2i(2, 0)],
		},
		{
			"type": "message",
			"text_key": "TUT1_RULE_OF_TWO",
			"icons": ["yellow", "blue"],
			"mask": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
			"red": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		},
		{
			"type": "message",
			"text_key": "TUT1_BALANCE",
			"icons": ["yellow", "blue"],
			"mask": [
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
			],
			"red": [
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
			],
		},
		{
			"type": "practice",
			"text_key": "TUT1_PLACE_NEXT",
			"wrong_key": "TUT1_WRONG_PLACE",
			"success_key": "TUT_GOOD",
			"icons": ["blue"],
			"wrong_icons": ["blue"],
			"coord": Vector2i(3, 0),
			"state": b,
			"cycle": [y, b],
			"mask": [Vector2i(3, 0)],
			"red": [Vector2i(3, 0)],
		},
		{
			"type": "practice",
			"text_key": "TUT1_PLACE_NEXT",
			"wrong_key": "TUT1_WRONG_PLACE",
			"success_key": "TUT_GOOD",
			"icons": ["yellow"],
			"wrong_icons": ["yellow"],
			"coord": Vector2i(2, 1),
			"state": y,
			"cycle": [y, b],
			"mask": [Vector2i(2, 1)],
			"red": [Vector2i(2, 1)],
		},
		{
			"type": "practice",
			"text_key": "TUT1_PLACE_NEXT",
			"wrong_key": "TUT1_WRONG_PLACE",
			"success_key": "TUT1_GOOD_BOARD",
			"icons": ["yellow"],
			"wrong_icons": ["yellow"],
			"success_icons": ["yellow", "blue"],
			"coord": Vector2i(3, 1),
			"state": y,
			"cycle": [y, b],
			"mask": [Vector2i(3, 1)],
			"red": [Vector2i(3, 1)],
		},
		{
			"type": "done",
			"text_key": "TUT_PLAY_FREE",
		},
	]

static func _level_2() -> Array:
	# 4x4: Rule of Two then Equal Balance. Empties (2,0)=B and (2,1)=Y.
	var y := GameConstants.TileState.YELLOW
	var b := GameConstants.TileState.BLUE
	return [
		{
			"type": "message",
			"text_key": "TUT2_RULE_INTRO",
			"icons": ["yellow", "blue"],
			"mask": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
			"red": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		},
		{
			"type": "practice",
			"text_key": "TUT2_RULE_PRACTICE",
			"wrong_key": "TUT2_WRONG_THREE",
			"success_key": "TUT2_GOOD_RULE",
			"icons": ["blue"],
			"wrong_icons": ["yellow", "blue"],
			"success_icons": ["blue"],
			"coord": Vector2i(2, 0),
			"state": b,
			"cycle": [y, b],
			"mask": [Vector2i(2, 0)],
			"red": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		},
		{
			"type": "message",
			"text_key": "TUT2_BALANCE_INTRO",
			"icons": ["yellow", "blue"],
			"mask": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
			"red": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
		},
		{
			"type": "practice",
			"text_key": "TUT2_BALANCE_PRACTICE",
			"wrong_key": "TUT2_WRONG_BALANCE",
			"success_key": "TUT2_GOOD_BALANCE",
			"icons": ["yellow"],
			"wrong_icons": ["yellow"],
			"success_icons": ["yellow", "blue"],
			"coord": Vector2i(2, 1),
			"state": y,
			"cycle": [y, b],
			"mask": [Vector2i(2, 1)],
			"red": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
		},
		{
			"type": "done",
			"text_key": "TUT_PLAY_FREE",
		},
	]

static func _level_3() -> Array:
	# 3x3 green lesson. Solved: YBG / BGY / GYB.
	# Empties: (1,0)=Blue (dual-as-yellow), (1,1)=Green (max-one + balance).
	var g := GameConstants.TileState.JOKER
	var y := GameConstants.TileState.YELLOW
	var b := GameConstants.TileState.BLUE
	return [
		{
			"type": "message",
			"text_key": "TUT3_INTRO",
			"icons": ["green"],
			"mask": [Vector2i(2, 0), Vector2i(0, 2)],
			"red": [Vector2i(2, 0), Vector2i(0, 2)],
		},
		{
			"type": "message",
			"text_key": "TUT3_GREEN_DUAL",
			"icons": ["green", "yellow"],
			"mask": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
			"red": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		},
		{
			"type": "practice",
			"text_key": "TUT3_DUAL_PRACTICE",
			"wrong_key": "TUT3_DUAL_WRONG",
			"success_key": "TUT3_DUAL_GOOD",
			"icons": ["blue", "yellow", "green"],
			"wrong_icons": ["green", "yellow", "blue"],
			"success_icons": ["blue"],
			"coord": Vector2i(1, 0),
			"state": b,
			"cycle": [y, b, g],
			"mask": [Vector2i(1, 0)],
			"red": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		},
		{
			"type": "message",
			"text_key": "TUT3_GREEN_MAX",
			"icons": ["green"],
			"mask": [Vector2i(2, 0), Vector2i(0, 2)],
			"red": [Vector2i(2, 0), Vector2i(0, 2)],
		},
		{
			"type": "practice",
			"text_key": "TUT3_MAX_PRACTICE",
			"wrong_key": "TUT3_WRONG_COLOR",
			"success_key": "TUT3_GOOD_GREEN",
			"icons": ["green"],
			"wrong_icons": ["green", "yellow", "blue"],
			"success_icons": ["green"],
			"coord": Vector2i(1, 1),
			"state": g,
			"cycle": [y, b, g],
			"mask": [Vector2i(1, 1)],
			"red": [Vector2i(1, 1)],
		},
		{
			"type": "done",
			"text_key": "TUT_PLAY_FREE",
		},
	]

static func _level_4() -> Array:
	# 3x3 with two purple pairs. Solved: SBY / BYG / YSB.
	# Pair1 (0,0)-(1,0) active at (1,0); Pair2 (1,2)-(2,2) active at (2,2).
	# After hops: fill (1,0)=Blue and (2,2)=Blue.
	var y := GameConstants.TileState.YELLOW
	var b := GameConstants.TileState.BLUE
	var g := GameConstants.TileState.JOKER
	return [
		{
			"type": "message",
			"text_key": "TUT4_INTRO",
			"icons": ["shifter"],
			"mask": [
				Vector2i(0, 0), Vector2i(1, 0),
				Vector2i(1, 2), Vector2i(2, 2),
			],
			"red": [
				Vector2i(0, 0), Vector2i(1, 0),
				Vector2i(1, 2), Vector2i(2, 2),
			],
		},
		{
			"type": "practice",
			"text_key": "TUT4_MOVE_SHIFTER",
			"wrong_key": "TUT4_MOVE_SHIFTER",
			"success_key": "TUT4_GOOD_SHIFTER",
			"icons": ["shifter"],
			"wrong_icons": ["shifter"],
			"success_icons": ["shifter"],
			"coord": Vector2i(0, 0),
			"from": Vector2i(1, 0),
			"wait_shifter": true,
			"mask": [Vector2i(1, 0)],
			"red": [Vector2i(1, 0)],
		},
		{
			"type": "practice",
			"text_key": "TUT4_PLACE_FILL",
			"wrong_key": "TUT4_WRONG_FILL",
			"success_key": "TUT4_GOOD_FILL",
			"icons": ["blue"],
			"wrong_icons": ["blue"],
			"success_icons": ["blue"],
			"coord": Vector2i(1, 0),
			"state": b,
			"cycle": [y, b, g],
			"mask": [Vector2i(1, 0)],
			"red": [Vector2i(1, 0)],
		},
		{
			"type": "practice",
			"text_key": "TUT4_MOVE_SHIFTER_2",
			"wrong_key": "TUT4_MOVE_SHIFTER_2",
			"success_key": "TUT4_GOOD_SHIFTER",
			"icons": ["shifter"],
			"wrong_icons": ["shifter"],
			"success_icons": ["shifter"],
			"coord": Vector2i(1, 2),
			"from": Vector2i(2, 2),
			"wait_shifter": true,
			"mask": [Vector2i(2, 2)],
			"red": [Vector2i(2, 2)],
		},
		{
			"type": "practice",
			"text_key": "TUT4_PLACE_FILL_2",
			"wrong_key": "TUT4_WRONG_FILL",
			"success_key": "TUT4_GOOD_FILL",
			"icons": ["blue"],
			"wrong_icons": ["blue"],
			"success_icons": ["blue"],
			"coord": Vector2i(2, 2),
			"state": b,
			"cycle": [y, b, g],
			"mask": [Vector2i(2, 2)],
			"red": [Vector2i(2, 2)],
		},
		{
			"type": "done",
			"text_key": "TUT_PLAY_FREE",
		},
	]

static func _level_5() -> Array:
	# 4x4 constraints: vertical = and horizontal ×. Empties (1,0), (2,1), (3,0).
	var y := GameConstants.TileState.YELLOW
	var b := GameConstants.TileState.BLUE
	return [
		{
			"type": "message",
			"text_key": "TUT5_EQUALS_INTRO",
			"mask": [Vector2i(1, 0), Vector2i(1, 1)],
			"red": [Vector2i(1, 0), Vector2i(1, 1)],
		},
		{
			"type": "practice",
			"text_key": "TUT5_EQUALS_PRACTICE",
			"wrong_key": "TUT5_WRONG_EQUALS",
			"success_key": "TUT5_GOOD_EQUALS",
			"icons": ["yellow"],
			"wrong_icons": ["yellow"],
			"success_icons": ["yellow"],
			"coord": Vector2i(1, 0),
			"state": y,
			"cycle": [y, b],
			"mask": [Vector2i(1, 0)],
			"red": [Vector2i(1, 0), Vector2i(1, 1)],
		},
		{
			"type": "message",
			"text_key": "TUT5_NOTEQUALS_INTRO",
			"mask": [Vector2i(2, 1), Vector2i(3, 1)],
			"red": [Vector2i(2, 1), Vector2i(3, 1)],
		},
		{
			"type": "practice",
			"text_key": "TUT5_NOTEQUALS_PRACTICE",
			"wrong_key": "TUT5_WRONG_NOTEQUALS",
			"success_key": "TUT5_GOOD_NOTEQUALS",
			"icons": ["yellow", "blue"],
			"wrong_icons": ["blue"],
			"success_icons": ["blue"],
			"coord": Vector2i(2, 1),
			"state": b,
			"cycle": [y, b],
			"mask": [Vector2i(2, 1)],
			"red": [Vector2i(2, 1), Vector2i(3, 1)],
		},
		{
			"type": "practice",
			"text_key": "TUT5_FINISH",
			"wrong_key": "TUT5_WRONG_FINISH",
			"success_key": "TUT5_GOOD_FINISH",
			"icons": ["blue"],
			"wrong_icons": ["blue"],
			"success_icons": ["yellow", "blue"],
			"coord": Vector2i(3, 0),
			"state": b,
			"cycle": [y, b],
			"mask": [Vector2i(3, 0)],
			"red": [Vector2i(3, 0)],
		},
		{
			"type": "done",
			"text_key": "TUT_PLAY_FREE",
		},
	]

static func _level_6() -> Array:
	# Teach each top-bar tool with a glowing highlight. Tools unlock after done.
	return [
		{
			"type": "message",
			"text_key": "TUT6_INTRO",
		},
		{
			"type": "hud_button",
			"button": "reset",
			"text_key": "TUT6_RESET",
			"icons": ["reset"],
		},
		{
			"type": "hud_button",
			"button": "how_to_play",
			"text_key": "TUT6_RULES",
			"icons": ["rules"],
		},
		{
			"type": "hud_button",
			"button": "hint",
			"text_key": "TUT6_HINT",
			"icons": ["hint"],
		},
		{
			"type": "hud_button",
			"button": "undo",
			"text_key": "TUT6_UNDO",
			"icons": ["undo"],
		},
		{
			"type": "hud_button",
			"button": "redo",
			"text_key": "TUT6_REDO",
			"icons": ["redo"],
		},
		{
			"type": "done",
			"text_key": "TUT6_COMPLETE",
		},
	]
