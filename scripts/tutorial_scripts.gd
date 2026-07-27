class_name TutorialScripts
extends RefCounted

## Step kinds:
## message — tip with Next; board frozen (optional white masks / borders)
## apply_locks — set locked cells mid-tutorial, then tip with Next
## discover_rules — free fill; on first validation break teach that rule then the other
## practice — only highlighted cells clickable; status updates on wrong/right
## hud_button — highlight a top-bar tool; tap it or Next to advance
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
	# Empty 4×4 → place Y/B → lock clues like old L1 → discover rules on red errors → HUD → finish.
	var y := GameConstants.TileState.YELLOW
	var b := GameConstants.TileState.BLUE
	var locked_layout := {
		Vector2i(0, 0): y, Vector2i(1, 0): y, Vector2i(2, 0): GameConstants.TileState.EMPTY, Vector2i(3, 0): GameConstants.TileState.EMPTY,
		Vector2i(0, 1): b, Vector2i(1, 1): b, Vector2i(2, 1): GameConstants.TileState.EMPTY, Vector2i(3, 1): GameConstants.TileState.EMPTY,
		Vector2i(0, 2): b, Vector2i(1, 2): y, Vector2i(2, 2): y, Vector2i(3, 2): b,
		Vector2i(0, 3): y, Vector2i(1, 3): b, Vector2i(2, 3): b, Vector2i(3, 3): y,
	}
	var locked_cells: Array = [
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
			"type": "practice",
			"text_key": "TUT1_CYCLE",
			"wrong_key": "TUT1_WRONG_PLACE",
			"success_key": "TUT_GOOD",
			"icons": ["yellow", "blue"],
			"wrong_icons": [],
			"success_icons": [],
			"coord": Vector2i(1, 1),
			"state": b,
			"cycle": [y, b],
			"mask": [Vector2i(1, 1)],
			"red": [Vector2i(1, 1)],
		},
		{
			"type": "apply_locks",
			"text_key": "TUT1_LOCKS",
			"icons": ["lock"],
			"layout": locked_layout,
			"mask": locked_cells,
			"red": locked_cells,
		},
		{
			"type": "discover_rules",
			"text_key": "TUT1_FILL_TRY",
			"rule_two_key": "TUT1_RULE_OF_TWO",
			"balance_key": "TUT1_BALANCE",
			"rule_two_icons": ["yellow", "blue"],
			"balance_icons": ["yellow", "blue"],
		},
		{
			"type": "message",
			"text_key": "TUT6_TOOLS_INTRO",
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

static func _level_2() -> Array:
	# Green lesson (former level_4).
	var g := GameConstants.TileState.JOKER
	var y := GameConstants.TileState.YELLOW
	var b := GameConstants.TileState.BLUE
	var greens := [
		Vector2i(3, 0), Vector2i(2, 1), Vector2i(0, 3),
	]
	return [
		{
			"type": "message",
			"text_key": "TUT4_INTRO",
			"icons": ["green", "yellow", "blue"],
			"mask": greens.duplicate(),
			"red": greens.duplicate(),
		},
		{
			"type": "message",
			"text_key": "TUT4_GREEN_DUAL",
			"icons": ["green", "yellow"],
			"mask": [
				Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1),
			],
			"red": [
				Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1),
			],
		},
		{
			"type": "practice",
			"text_key": "TUT4_DUAL_PRACTICE",
			"wrong_key": "TUT4_DUAL_WRONG",
			"success_key": "TUT4_DUAL_GOOD",
			"icons": ["blue", "yellow", "green"],
			"wrong_icons": ["green", "yellow", "blue"],
			"success_icons": ["blue"],
			"coord": Vector2i(3, 1),
			"state": b,
			"cycle": [y, b, g],
			"mask": [Vector2i(3, 1)],
			"red": [
				Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1),
			],
		},
		{
			"type": "message",
			"text_key": "TUT4_GREEN_MAX",
			"icons": ["green"],
			"mask": greens.duplicate(),
			"red": greens.duplicate(),
		},
		{
			"type": "message",
			"text_key": "TUT4_ODD_BALANCE",
			"icons": ["green"],
			"mask": [
				Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
			],
			"red": [
				Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
			],
		},
		{
			"type": "practice",
			"text_key": "TUT4_MAX_PRACTICE",
			"wrong_key": "TUT4_WRONG_COLOR",
			"success_key": "TUT4_GOOD_GREEN",
			"icons": ["green"],
			"wrong_icons": ["green", "yellow", "blue"],
			"success_icons": ["green"],
			"coord": Vector2i(1, 2),
			"state": g,
			"cycle": [y, b, g],
			"mask": [Vector2i(1, 2)],
			"red": [
				Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
			],
		},
		{
			"type": "message",
			"text_key": "TUT4_GREEN_MAX_2",
			"icons": ["green"],
			"mask": [
				Vector2i(3, 0), Vector2i(2, 1), Vector2i(1, 2), Vector2i(0, 3), Vector2i(4, 4),
			],
			"red": [
				Vector2i(3, 0), Vector2i(2, 1), Vector2i(1, 2), Vector2i(0, 3), Vector2i(4, 4),
			],
		},
		{
			"type": "practice",
			"text_key": "TUT4_MAX_PRACTICE_2",
			"wrong_key": "TUT4_WRONG_COLOR",
			"success_key": "TUT4_GOOD_GREEN",
			"icons": ["green"],
			"wrong_icons": ["green", "yellow", "blue"],
			"success_icons": ["green"],
			"coord": Vector2i(4, 4),
			"state": g,
			"cycle": [y, b, g],
			"mask": [Vector2i(4, 4)],
			"red": [
				Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4),
			],
		},
		{
			"type": "done",
			"text_key": "TUT_PLAY_FREE",
		},
	]

static func _level_3() -> Array:
	# Purple hop + fill (former level_5).
	var y := GameConstants.TileState.YELLOW
	var b := GameConstants.TileState.BLUE
	var g := GameConstants.TileState.JOKER
	return [
		{
			"type": "message",
			"text_key": "TUT5_INTRO",
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
			"type": "message",
			"text_key": "TUT5_ODD_BALANCE",
			"icons": ["green", "shifter"],
			"mask": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
			"red": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
		},
		{
			"type": "practice",
			"text_key": "TUT5_MOVE_SHIFTER",
			"wrong_key": "TUT5_MOVE_SHIFTER",
			"success_key": "TUT5_GOOD_SHIFTER",
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
			"text_key": "TUT5_PLACE_FILL",
			"wrong_key": "TUT5_WRONG_FILL",
			"success_key": "TUT5_GOOD_FILL",
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
			"text_key": "TUT5_MOVE_SHIFTER_2",
			"wrong_key": "TUT5_MOVE_SHIFTER_2",
			"success_key": "TUT5_GOOD_SHIFTER",
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
			"text_key": "TUT5_PLACE_FILL_2",
			"wrong_key": "TUT5_WRONG_FILL",
			"success_key": "TUT5_GOOD_FILL",
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
