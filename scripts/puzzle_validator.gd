class_name PuzzleValidator
extends RefCounted

# UPDATED: Now accepts constraint_pairs
static func validate_board(board_cells: Dictionary, cached_lines: Array, constraint_pairs: Array = []) -> Dictionary:
	var syntax_pass = true
	var error_messages: Array[String] = []
	
	for line in cached_lines:
		if not check_line_validity(board_cells, line["coords"], line["is_horizontal"], line["index"], error_messages): 
			syntax_pass = false
			
	# --- NEW: Evaluate Relationship Constraints (= and x) ---
	for pair in constraint_pairs:
		var a = pair["a"]
		var b = pair["b"]
		
		var state_a = board_cells[a].state
		var state_b = board_cells[b].state
		
		# Ignore empty cells or walls during constraint validation
		if state_a < 0 or state_b < 0 or state_a == 3 or state_b == 3:
			continue
			
		var is_match = (state_a == state_b) or (state_a == 2) or (state_b == 2)
		
		if pair["type"] == "equals" and not is_match:
			syntax_pass = false
			board_cells[a].highlight_error()
			board_cells[b].highlight_error()
			if not "Equals (=) constraint violated!" in error_messages:
				error_messages.append("Equals (=) constraint violated!")
				
		if pair["type"] == "not_equals" and is_match:
			syntax_pass = false
			board_cells[a].highlight_error()
			board_cells[b].highlight_error()
			if not "Not-Equals (×) constraint violated!" in error_messages:
				error_messages.append("Not-Equals (×) constraint violated!")
	# --------------------------------------------------------
			
	return {"valid": syntax_pass, "errors": error_messages}

static func check_line_validity(board_cells: Dictionary, coords: Array, is_horizontal: bool, index: int, error_messages: Array[String]) -> bool:
	var line_is_valid = true
	var line_name = "Row " + str(index + 1) if is_horizontal else "Column " + str(index + 1)
	
	var joker_count = 0
	for coord in coords:
		if board_cells[coord].state == 2:
			joker_count += 1
			
	if joker_count > 1:
		for coord in coords:
			if board_cells[coord].state == 2:
				board_cells[coord].highlight_error()
		line_is_valid = false
		error_messages.append(line_name + " contains more than ONE Joker wildcard!")

	var found_consecutive = false
	var virtual_test_states = [0, 1]
	
	for test_val in virtual_test_states:
		for i in range(coords.size() - 2):
			var s1 = board_cells[coords[i]].state
			var s2 = board_cells[coords[i+1]].state
			var s3 = board_cells[coords[i+2]].state
			
			if s1 == -2 or s2 == -2 or s3 == -2: continue
				
			if s1 == 2: s1 = test_val
			if s2 == 2: s2 = test_val
			if s3 == 2: s3 = test_val
			
			if s1 == -1 or s2 == -1 or s3 == -1: continue
				
			if s1 == s2 and s2 == s3:
				board_cells[coords[i]].highlight_error()
				board_cells[coords[i+1]].highlight_error()
				board_cells[coords[i+2]].highlight_error()
				line_is_valid = false
				found_consecutive = true
					
	if found_consecutive:
		error_messages.append(line_name + " has 3 identical symbols in a row!")

	var zeros = 0
	var ones = 0
	var empty_count = 0
	
	for coord in coords:
		match board_cells[coord].state:
			-1: empty_count += 1
			0: zeros += 1
			1: ones += 1
			
	if empty_count == 0 and zeros != ones:
		for coord in coords:
			if board_cells[coord].is_playable and board_cells[coord].state != 3:
				board_cells[coord].highlight_error()
		line_is_valid = false
		error_messages.append(line_name + " does not have an equal amount of Zero and One blocks!")
		
	return line_is_valid
