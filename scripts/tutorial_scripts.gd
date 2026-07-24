class_name TutorialScripts
extends RefCounted

## Step kinds:
## message — tip with Next; board stays interactive (optional focus)
## practice — interactive focus cell; status updates on wrong/right, Next on success
## hud_button — highlight a HUD tool (red), Next or tapping it advances
## wait_cell / wait_shifter — legacy auto-advance waits
## done — unlock tools / clear gates (victory can follow)
##
## Focus fields:
## mask / highlight — white cell masks (LinkHighlight)
## red — red cell borders (ErrorHighlight / focus)

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
	# Cycle first; after the first correct place, teach Rule of Two + Equal Balance.
	var y := GameConstants.TileState.YELLOW
	var b := GameConstants.TileState.BLUE
	return [
		{
			"type": "message",
			"text_key": "TUT1_LOCKS",
			"icons": ["lock"],
			"mask": [Vector2i(0, 0)],
			"red": [Vector2i(0, 0)],
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
		},
		{
			"type": "message",
			"text_key": "TUT1_RULE_OF_TWO",
			"icons": ["yellow", "blue"],
		},
		{
			"type": "message",
			"text_key": "TUT1_BALANCE",
			"icons": ["yellow", "blue"],
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
		},
		{
			"type": "done",
			"text_key": "TUT_COMPLETE",
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
			"red": [Vector2i(0, 0), Vector2i(1, 0)],
			"mask": [Vector2i(2, 0)],
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
			"red": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(3, 1)],
			"mask": [Vector2i(2, 1)],
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
			"red": [Vector2i(2, 1)],
		},
		{
			"type": "done",
			"text_key": "TUT_COMPLETE",
		},
	]

static func _level_3() -> Array:
	# 3x3 green joker lesson. Empty center (1,1).
	var g := GameConstants.TileState.JOKER
	var y := GameConstants.TileState.YELLOW
	var b := GameConstants.TileState.BLUE
	return [
		{
			"type": "message",
			"text_key": "TUT3_INTRO",
			"icons": ["green"],
			"red": [Vector2i(2, 0), Vector2i(0, 2)],
			"mask": [Vector2i(2, 0), Vector2i(0, 2)],
		},
		{
			"type": "message",
			"text_key": "TUT3_GREEN_DUAL",
			"icons": ["green", "yellow", "blue"],
			"red": [Vector2i(2, 0), Vector2i(0, 2)],
		},
		{
			"type": "practice",
			"text_key": "TUT3_GREEN_MAX",
			"wrong_key": "TUT3_WRONG_COLOR",
			"success_key": "TUT3_GOOD_GREEN",
			"icons": ["green", "green"],
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
			"text_key": "TUT_COMPLETE",
		},
	]

static func _level_4() -> Array:
	# 3x3 shifter lesson (bottom row walls). Active at (2,1); hop to (2,0), fill with green.
	var g := GameConstants.TileState.JOKER
	return [
		{
			"type": "message",
			"text_key": "TUT4_INTRO",
			"icons": ["shifter"],
			"red": [Vector2i(2, 0), Vector2i(2, 1)],
			"mask": [Vector2i(2, 0), Vector2i(2, 1)],
		},
		{
			"type": "practice",
			"text_key": "TUT4_MOVE_SHIFTER",
			"wrong_key": "TUT4_MOVE_SHIFTER",
			"success_key": "TUT4_GOOD_SHIFTER",
			"icons": ["shifter"],
			"wrong_icons": ["shifter"],
			"success_icons": ["shifter"],
			"coord": Vector2i(2, 0),
			"wait_shifter": true,
			"mask": [Vector2i(2, 1)],
			"red": [Vector2i(2, 1)],
		},
		{
			"type": "practice",
			"text_key": "TUT4_PLACE_FILL",
			"wrong_key": "TUT4_WRONG_FILL",
			"success_key": "TUT4_GOOD_FILL",
			"icons": ["green"],
			"wrong_icons": ["yellow", "blue", "green"],
			"success_icons": ["green"],
			"coord": Vector2i(2, 1),
			"state": g,
			"cycle": [
				GameConstants.TileState.YELLOW,
				GameConstants.TileState.BLUE,
				g,
			],
			"mask": [Vector2i(2, 1)],
			"red": [Vector2i(2, 1)],
		},
		{
			"type": "done",
			"text_key": "TUT_COMPLETE",
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
			"red": [Vector2i(1, 0), Vector2i(1, 1)],
			"mask": [Vector2i(1, 0), Vector2i(1, 1)],
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
			"red": [Vector2i(2, 1), Vector2i(3, 1)],
			"mask": [Vector2i(2, 1), Vector2i(3, 1)],
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
			"text_key": "TUT_COMPLETE",
		},
	]

static func _level_6() -> Array:
	# Teach HUD tools one by one with red button highlight. Board is playable after done.
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
