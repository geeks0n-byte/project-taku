class_name TutorialScripts
extends RefCounted

## Step kinds:
## message — show tip, advance with Next
## wait_cell — wait until coord has target state (optional cycle restrict)
## wait_shifter — wait until shifter is on target coord
## done — clear gates (victory can follow naturally)

static func has_script(level_number: int) -> bool:
	return level_number >= 1 and level_number <= 3

static func steps_for(level_number: int) -> Array:
	match level_number:
		1:
			return _level_1()
		2:
			return _level_2()
		3:
			return _level_3()
		_:
			return []

static func _level_1() -> Array:
	# 4x2: mostly locked Y/B. Empties (3,0)=Blue, (3,1)=Yellow.
	return [
		{
			"type": "message",
			"text_key": "TUT1_INTRO",
		},
		{
			"type": "message",
			"text_key": "TUT1_CYCLE",
		},
		{
			"type": "wait_cell",
			"text_key": "TUT1_PLACE_BLUE",
			"coord": Vector2i(3, 0),
			"state": GameConstants.TileState.BLUE,
			"cycle": [GameConstants.TileState.BLUE],
			"highlight": [Vector2i(3, 0)],
			"whitelist": [Vector2i(3, 0)],
		},
		{
			"type": "message",
			"text_key": "TUT1_RULE_OF_TWO",
		},
		{
			"type": "wait_cell",
			"text_key": "TUT1_PLACE_YELLOW",
			"coord": Vector2i(3, 1),
			"state": GameConstants.TileState.YELLOW,
			"cycle": [GameConstants.TileState.YELLOW],
			"highlight": [Vector2i(3, 1)],
			"whitelist": [Vector2i(3, 1)],
		},
		{
			"type": "message",
			"text_key": "TUT1_BALANCE",
		},
		{"type": "done"},
	]

static func _level_2() -> Array:
	# 3x3: locked ring, empty center must be Green.
	return [
		{
			"type": "message",
			"text_key": "TUT2_INTRO",
		},
		{
			"type": "message",
			"text_key": "TUT2_GREEN_RULE",
		},
		{
			"type": "wait_cell",
			"text_key": "TUT2_PLACE_GREEN",
			"coord": Vector2i(1, 1),
			"state": GameConstants.TileState.JOKER,
			"cycle": [GameConstants.TileState.JOKER],
			"highlight": [Vector2i(1, 1)],
			"whitelist": [Vector2i(1, 1)],
		},
		{
			"type": "message",
			"text_key": "TUT2_LOCKS",
		},
		{"type": "done"},
	]

static func _level_3() -> Array:
	# 3x2: move shifter up, then place Green in the vacated cell.
	return [
		{
			"type": "message",
			"text_key": "TUT3_INTRO",
		},
		{
			"type": "wait_shifter",
			"text_key": "TUT3_MOVE_SHIFTER",
			"coord": Vector2i(2, 0),
			"highlight": [Vector2i(2, 1)],
			"whitelist": [Vector2i(2, 1)],
		},
		{
			"type": "message",
			"text_key": "TUT3_SHIFTER_DONE",
		},
		{
			"type": "wait_cell",
			"text_key": "TUT3_PLACE_GREEN",
			"coord": Vector2i(2, 1),
			"state": GameConstants.TileState.JOKER,
			"cycle": [GameConstants.TileState.JOKER],
			"highlight": [Vector2i(2, 1)],
			"whitelist": [Vector2i(2, 1)],
		},
		{
			"type": "message",
			"text_key": "TUT3_CONSTRAINTS",
		},
		{"type": "done"},
	]
