class_name PuzzleValidator
extends RefCounted

static func validate_board(board_cells: Dictionary, cached_lines: Array, constraint_pairs: Array, _max_jokers: int = -1) -> Dictionary:
	var errors = []
	var is_valid = true

	for pair in constraint_pairs:
		if board_cells.has(pair["a"]) and board_cells.has(pair["b"]):
			var cell_a = board_cells[pair["a"]]
			var cell_b = board_cells[pair["b"]]
			
			var state_a = cell_a.state
			var state_b = cell_b.state

			if state_a < 0 or state_b < 0:
				continue

			var can_be_equal = false
			var can_be_not_equal = false

			if state_a == GameConstants.TileState.SHIFTER or state_b == GameConstants.TileState.SHIFTER:
				if state_a == state_b:
					can_be_equal = true
					can_be_not_equal = false
				else:
					can_be_equal = false
					can_be_not_equal = true
			elif state_a == 2 or state_b == 2:
				can_be_equal = true
				can_be_not_equal = true
			else:
				if state_a == state_b:
					can_be_equal = true
					can_be_not_equal = false
				else:
					can_be_equal = false
					can_be_not_equal = true

			if pair["type"] == "equals" and not can_be_equal:
				is_valid = false
				var msg = "ERR_CONSTRAINT_EQUALS"
				if not errors.has(msg):
					errors.append(msg)
				if cell_a.has_method("set_error_highlight"): cell_a.set_error_highlight()
				if cell_b.has_method("set_error_highlight"): cell_b.set_error_highlight()
			elif pair["type"] == "not_equals" and not can_be_not_equal:
				is_valid = false
				var msg = "ERR_CONSTRAINT_NOT_EQUALS"
				if not errors.has(msg):
					errors.append(msg)
				if cell_a.has_method("set_error_highlight"): cell_a.set_error_highlight()
				if cell_b.has_method("set_error_highlight"): cell_b.set_error_highlight()

	for line_data in cached_lines:
		var coords = line_data["coords"]
		var is_row: bool = bool(line_data.get("is_horizontal", true))
		var count_0 = 0
		var count_1 = 0
		var count_jokers = 0
		var line_vals = []
		
		for c in coords:
			var cell = board_cells[c]
			var st = cell.state
				
			line_vals.append(st)
			
			if st == 0: count_0 += 1
			elif st == 1: count_1 += 1
			elif st == 2: count_jokers += 1

		if count_jokers > 1:
			is_valid = false
			var msg = "ERR_MAX_GREEN_PER_ROW" if is_row else "ERR_MAX_GREEN_PER_COLUMN"
			if not errors.has(msg):
				errors.append(msg)
			for c in coords:
				var cell = board_cells[c]
				if cell.state == 2 and cell.has_method("set_error_highlight"):
					cell.set_error_highlight()

		for i in range(line_vals.size() - 2):
			var v1 = line_vals[i]
			var v2 = line_vals[i+1]
			var v3 = line_vals[i+2]
			
			var is_filled = v1 >= 0 and v1 <= 2 and v2 >= 0 and v2 <= 2 and v3 >= 0 and v3 <= 2
			
			if is_filled:
				var all_zeros = (v1 == 0 or v1 == 2) and (v2 == 0 or v2 == 2) and (v3 == 0 or v3 == 2)
				var all_ones = (v1 == 1 or v1 == 2) and (v2 == 1 or v2 == 2) and (v3 == 1 or v3 == 2)
				var has_joker = (v1 == 2 or v2 == 2 or v3 == 2)
				
				if all_zeros:
					is_valid = false
					var msg: String
					if has_joker:
						msg = "ERR_GREEN_THREE_YELLOW_ROW" if is_row else "ERR_GREEN_THREE_YELLOW_COLUMN"
					else:
						msg = "ERR_THREE_YELLOW_ROW" if is_row else "ERR_THREE_YELLOW_COLUMN"
					if not errors.has(msg):
						errors.append(msg)
					for j in range(3):
						var cell = board_cells[coords[i+j]]
						if cell.has_method("set_error_highlight"):
							cell.set_error_highlight()
							
				if all_ones:
					is_valid = false
					var msg: String
					if has_joker:
						msg = "ERR_GREEN_THREE_BLUE_ROW" if is_row else "ERR_GREEN_THREE_BLUE_COLUMN"
					else:
						msg = "ERR_THREE_BLUE_ROW" if is_row else "ERR_THREE_BLUE_COLUMN"
					if not errors.has(msg):
						errors.append(msg)
					for j in range(3):
						var cell = board_cells[coords[i+j]]
						if cell.has_method("set_error_highlight"):
							cell.set_error_highlight()

		var playable_count = 0
		var filled_count = 0
		
		for v in line_vals:
			if v != -2: 
				playable_count += 1
				if v >= 0: 
					filled_count += 1
					
		if playable_count > 0 and filled_count == playable_count:
			if count_0 != count_1:
				is_valid = false
				var msg := _unequal_status_key(is_row, count_0, count_1)
				if not _has_unequal_for(errors, is_row):
					errors.append(msg)
				for c in coords:
					var cell = board_cells[c]
					if cell.state != -2 and cell.has_method("set_error_highlight"):
						cell.set_error_highlight()
						
	return {"valid": is_valid, "errors": errors}

## Validates a raw layout dict (coord -> TileState int), including active shifters.
static func validate_layout_states(
	layout: Dictionary,
	width: int,
	height: int,
	constraint_pairs: Array = [],
	shifter_pairs: Array = []
) -> Dictionary:
	var states := layout.duplicate()
	for pair in shifter_pairs:
		if typeof(pair) != TYPE_DICTIONARY:
			continue
		var active: Vector2i = pair.get("active", Vector2i(-999, -999))
		if states.has(active):
			states[active] = GameConstants.TileState.SHIFTER
	var lines := _build_lines_from_layout(states, width, height)
	return _validate_state_map(states, lines, constraint_pairs)

static func starting_layout_is_clean(
	layout: Dictionary,
	width: int,
	height: int,
	constraint_pairs: Array = [],
	shifter_pairs: Array = []
) -> bool:
	var result := validate_layout_states(layout, width, height, constraint_pairs, shifter_pairs)
	return bool(result.get("valid", false))

static func _build_lines_from_layout(states: Dictionary, width: int, height: int) -> Array:
	var lines: Array = []
	for y in height:
		var row: Array = []
		for x in width:
			var c := Vector2i(x, y)
			if states.has(c):
				row.append(c)
		if row.size() > 0:
			lines.append({"coords": row, "is_horizontal": true})
	for x in width:
		var col: Array = []
		for y in height:
			var c := Vector2i(x, y)
			if states.has(c):
				col.append(c)
		if col.size() > 0:
			lines.append({"coords": col, "is_horizontal": false})
	return lines

static func _validate_state_map(states: Dictionary, cached_lines: Array, constraint_pairs: Array) -> Dictionary:
	var errors = []
	var is_valid = true

	for pair in constraint_pairs:
		if not states.has(pair["a"]) or not states.has(pair["b"]):
			continue
		var state_a: int = int(states[pair["a"]])
		var state_b: int = int(states[pair["b"]])
		if state_a < 0 or state_b < 0:
			continue
		var can_be_equal := false
		var can_be_not_equal := false
		if state_a == GameConstants.TileState.SHIFTER or state_b == GameConstants.TileState.SHIFTER:
			can_be_equal = state_a == state_b
			can_be_not_equal = state_a != state_b
		elif state_a == GameConstants.TileState.JOKER or state_b == GameConstants.TileState.JOKER:
			can_be_equal = true
			can_be_not_equal = true
		else:
			can_be_equal = state_a == state_b
			can_be_not_equal = state_a != state_b
		if pair["type"] == "equals" and not can_be_equal:
			is_valid = false
			if not errors.has("ERR_CONSTRAINT_EQUALS"):
				errors.append("ERR_CONSTRAINT_EQUALS")
		elif pair["type"] == "not_equals" and not can_be_not_equal:
			is_valid = false
			if not errors.has("ERR_CONSTRAINT_NOT_EQUALS"):
				errors.append("ERR_CONSTRAINT_NOT_EQUALS")

	for line_data in cached_lines:
		var coords = line_data["coords"]
		var is_row: bool = bool(line_data.get("is_horizontal", true))
		var count_0 := 0
		var count_1 := 0
		var count_jokers := 0
		var line_vals: Array = []
		for c in coords:
			var st: int = int(states[c])
			line_vals.append(st)
			if st == GameConstants.TileState.YELLOW:
				count_0 += 1
			elif st == GameConstants.TileState.BLUE:
				count_1 += 1
			elif st == GameConstants.TileState.JOKER:
				count_jokers += 1

		if count_jokers > 1:
			is_valid = false
			var msg = "ERR_MAX_GREEN_PER_ROW" if is_row else "ERR_MAX_GREEN_PER_COLUMN"
			if not errors.has(msg):
				errors.append(msg)

		for i in range(line_vals.size() - 2):
			var v1: int = line_vals[i]
			var v2: int = line_vals[i + 1]
			var v3: int = line_vals[i + 2]
			var is_filled := (
				v1 >= 0 and v1 <= 2 and v2 >= 0 and v2 <= 2 and v3 >= 0 and v3 <= 2
			)
			if not is_filled:
				continue
			var all_zeros := (
				(v1 == 0 or v1 == 2) and (v2 == 0 or v2 == 2) and (v3 == 0 or v3 == 2)
			)
			var all_ones := (
				(v1 == 1 or v1 == 2) and (v2 == 1 or v2 == 2) and (v3 == 1 or v3 == 2)
			)
			var has_joker := v1 == 2 or v2 == 2 or v3 == 2
			if all_zeros:
				is_valid = false
				var msg: String
				if has_joker:
					msg = "ERR_GREEN_THREE_YELLOW_ROW" if is_row else "ERR_GREEN_THREE_YELLOW_COLUMN"
				else:
					msg = "ERR_THREE_YELLOW_ROW" if is_row else "ERR_THREE_YELLOW_COLUMN"
				if not errors.has(msg):
					errors.append(msg)
			if all_ones:
				is_valid = false
				var msg2: String
				if has_joker:
					msg2 = "ERR_GREEN_THREE_BLUE_ROW" if is_row else "ERR_GREEN_THREE_BLUE_COLUMN"
				else:
					msg2 = "ERR_THREE_BLUE_ROW" if is_row else "ERR_THREE_BLUE_COLUMN"
				if not errors.has(msg2):
					errors.append(msg2)

		var playable_count := 0
		var filled_count := 0
		for v in line_vals:
			if int(v) != GameConstants.TileState.WALL:
				playable_count += 1
				if int(v) >= 0:
					filled_count += 1
		if playable_count > 0 and filled_count == playable_count and count_0 != count_1:
			is_valid = false
			var unequal := _unequal_status_key(is_row, count_0, count_1)
			if not _has_unequal_for(errors, is_row):
				errors.append(unequal)

	return {"valid": is_valid, "errors": errors}

static func _unequal_status_key(is_row: bool, yellow_count: int, blue_count: int) -> String:
	var axis := "ROW" if is_row else "COLUMN"
	if yellow_count > blue_count:
		return "ERR_UNEQUAL_MORE_YELLOW_%s|%d|%d" % [axis, yellow_count, blue_count]
	return "ERR_UNEQUAL_MORE_BLUE_%s|%d|%d" % [axis, blue_count, yellow_count]

static func _has_unequal_for(errors: Array, is_row: bool) -> bool:
	var needle := "_ROW" if is_row else "_COLUMN"
	for e in errors:
		var s := String(e)
		if s.begins_with("ERR_UNEQUAL_") and s.find(needle) >= 0:
			return true
	return false
