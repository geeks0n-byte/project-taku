class_name PuzzleValidator
extends RefCounted

static func validate_board(board_cells: Dictionary, cached_lines: Array, constraint_pairs: Array, max_jokers: int = -1) -> Dictionary:
	var errors = []
	var is_valid = true

	# 1. Constraints Check
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

	# 2. Line Checks (Rows & Columns)
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

		# Max 1 Green Tile per row/column
		if count_jokers > 1:
			is_valid = false
			var msg = "ERR_MAX_GREEN_PER_LINE"
			if not errors.has(msg):
				errors.append(msg)
			for c in coords:
				var cell = board_cells[c]
				if cell.state == 2 and cell.has_method("set_error_highlight"):
					cell.set_error_highlight()

		# 3-in-a-row Check
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
					var msg = "ERR_GREEN_THREE_YELLOW" if has_joker else "ERR_THREE_YELLOW"
					if not errors.has(msg):
						errors.append(msg)
					for j in range(3):
						var cell = board_cells[coords[i+j]]
						if cell.has_method("set_error_highlight"):
							cell.set_error_highlight()
							
				if all_ones:
					is_valid = false
					var msg = "ERR_GREEN_THREE_BLUE" if has_joker else "ERR_THREE_BLUE"
					if not errors.has(msg):
						errors.append(msg)
					for j in range(3):
						var cell = board_cells[coords[i+j]]
						if cell.has_method("set_error_highlight"):
							cell.set_error_highlight()

		# Balance Check (Only validates on completed lines)
		var playable_count = 0
		var filled_count = 0
		
		for v in line_vals:
			if v != -2: 
				playable_count += 1
				if v >= 0: 
					filled_count += 1
					
		if playable_count > 0 and filled_count == playable_count:
			# STRICT EQUALITY RULE: 0s and 1s must be exactly equal
			if count_0 != count_1:
				is_valid = false
				var msg = "ERR_UNEQUAL_LINE"
				if not errors.has(msg):
					errors.append(msg)
				for c in coords:
					var cell = board_cells[c]
					# Walls (-2) are explicitly skipped from being highlighted
					if cell.state != -2 and cell.has_method("set_error_highlight"):
						cell.set_error_highlight()
						
	# 3. Global green quota (exact count on a finished board)
	if max_jokers >= 0:
		var placed_jokers = 0
		for coord in board_cells:
			if board_cells[coord].state == GameConstants.TileState.JOKER:
				placed_jokers += 1
		var board_full := BoardRenderer.is_board_full(board_cells)

		if placed_jokers > max_jokers:
			is_valid = false
			var msg = "ERR_TOO_MANY_GREEN"
			if not errors.has(msg):
				errors.append(msg)
			for coord in board_cells:
				var cell = board_cells[coord]
				if cell.state == GameConstants.TileState.JOKER and cell.has_method("set_error_highlight"):
					cell.set_error_highlight()
		elif board_full and max_jokers > 0 and placed_jokers < max_jokers:
			is_valid = false
			var msg = "ERR_TOO_FEW_GREEN"
			if not errors.has(msg):
				errors.append(msg)

	return {"valid": is_valid, "errors": errors}
