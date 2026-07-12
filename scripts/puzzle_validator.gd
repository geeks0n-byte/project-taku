class_name PuzzleValidator
extends RefCounted

static func validate_board(board_cells: Dictionary) -> Dictionary:
	var rows = {}
	var cols = {}
	var syntax_pass = true
	var error_messages: Array[String] = []
	
	for coord in board_cells:
		if coord.y not in rows: rows[coord.y] = []
		if coord.x not in cols: cols[coord.x] = []
		rows[coord.y].append(coord)
		cols[coord.x].append(coord)

	for r in rows:
		if not check_line_validity(board_cells, rows[r], true, r, error_messages): 
			syntax_pass = false
			
	for c in cols:
		if not check_line_validity(board_cells, cols[c], false, c, error_messages): 
			syntax_pass = false
		
	return {"valid": syntax_pass, "errors": error_messages}

static func check_line_validity(board_cells: Dictionary, coords: Array, is_horizontal: bool, index: int, error_messages: Array[String]) -> bool:
	coords.sort_custom(func(a, b): return a.x < b.x if is_horizontal else a.y < b.y)
	var line_is_valid = true
	var line_name = "Row " + str(index + 1) if is_horizontal else "Column " + str(index + 1)
	
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
			if board_cells[coord].is_playable:
				board_cells[coord].highlight_error()
		line_is_valid = false
		error_messages.append(line_name + " does not have an equal amount of 0s and 1s!")
		
	return line_is_valid
