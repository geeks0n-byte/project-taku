class_name PuzzleValidator

static func validate_board(board_cells: Dictionary, cached_lines: Array, constraint_pairs: Array) -> Dictionary:
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

			if state_a == 3 or state_b == 3:
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
				if not errors.has("Equal constraint violated."):
					errors.append("Equal constraint violated.")
				if cell_a.has_method("set_error_highlight"): cell_a.set_error_highlight()
				if cell_b.has_method("set_error_highlight"): cell_b.set_error_highlight()
			elif pair["type"] == "not_equals" and not can_be_not_equal:
				is_valid = false
				if not errors.has("Not Equal constraint violated."):
					errors.append("Not Equal constraint violated.")
				if cell_a.has_method("set_error_highlight"): cell_a.set_error_highlight()
				if cell_b.has_method("set_error_highlight"): cell_b.set_error_highlight()

	for line_data in cached_lines:
		var coords = line_data["coords"]
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

		# Max 1 Joker per row/column
		if count_jokers > 1:
			is_valid = false
			if not errors.has("Max 1 Joker allowed per row and column."):
				errors.append("Max 1 Joker allowed per row and column.")
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
				
				if all_zeros or all_ones:
					is_valid = false
					if not errors.has("Three identical numbers (or Jokers) in a row."):
						errors.append("Three identical numbers (or Jokers) in a row.")
					for j in range(3):
						var cell = board_cells[coords[i+j]]
						if cell.has_method("set_error_highlight"):
							cell.set_error_highlight()

		var playable_count = 0
		var filled_count = 0
		var colorable_tiles = 0
		
		for v in line_vals:
			if v != -2: 
				playable_count += 1
				if v >= 0: 
					filled_count += 1
				# Green tiles are excluded from this color parity math
				if v == 0 or v == 1:
					colorable_tiles += 1
					
		if playable_count > 0 and filled_count == playable_count:
			var max_allowed = int(ceil(colorable_tiles / 2.0))
			if count_0 > max_allowed or count_1 > max_allowed:
				is_valid = false
				if not errors.has("Unequal 0s and 1s in a completed line."):
					errors.append("Unequal 0s and 1s in a completed line.")
				for c in coords:
					var cell = board_cells[c]
					var local_st = cell.state
						
					if local_st >= 0 and local_st <= 1 and cell.has_method("set_error_highlight"):
						cell.set_error_highlight()

	return {"valid": is_valid, "errors": errors}
