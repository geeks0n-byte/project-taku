class_name PuzzleGenerator
extends RefCounted

static func generate_random_layout(width: int, height: int, allowed_tiles: Array) -> Dictionary:
	var layout = {}
	
	# 1. Initialize an empty board
	for y in range(height):
		for x in range(width):
			layout[Vector2i(x, y)] = -1

	# 2. Place random corner walls (0 to 3 walls)
	# By restricting walls strictly to the absolute corners, we guarantee they 
	# NEVER split the board and NEVER sit inside the playable area!
	var corners = [Vector2i(0,0), Vector2i(width-1, 0), Vector2i(0, height-1), Vector2i(width-1, height-1)]
	corners.shuffle()
	var num_walls = randi() % 4 
	for i in range(num_walls):
		layout[corners[i]] = -2

	# 3. Gather all empty playable cells
	var empty_cells = []
	for y in range(height):
		for x in range(width):
			if layout[Vector2i(x, y)] == -1:
				empty_cells.append(Vector2i(x, y))

	# Shuffle to ensure the solver fills the board in a highly randomized pattern
	empty_cells.shuffle() 
	
	# 4. Run the Backtracking Solver to generate a valid finished board
	var iter_tracker = {"count": 0}
	_solve(layout, empty_cells, 0, width, height, allowed_tiles, iter_tracker)

	# 5. Punch Holes in the board to turn it into a puzzle
	# We want to leave about 40% of the tiles on the board as clues.
	var playable_count = empty_cells.size()
	var keep_count = int(playable_count * 0.4) 
	
	var filled_cells = []
	for c in layout.keys():
		if layout[c] >= 0:
			filled_cells.append(c)
			
	filled_cells.shuffle()
	
	# Turn the remaining 60% of the cells into empty playable spaces (-1)
	for i in range(filled_cells.size()):
		if i >= keep_count:
			layout[filled_cells[i]] = -1

	return layout

static func _solve(layout: Dictionary, empty_cells: Array, index: int, w: int, h: int, allowed: Array, iter: Dictionary) -> bool:
	if index >= empty_cells.size(): return true
	
	iter.count += 1
	# Failsafe: If the strict equality rules make a board mathematically impossible 
	# (e.g. 5x5 board with NO jokers), abort the solver after 5000 attempts and return 
	# the partially solved board to prevent the game from freezing.
	if iter.count > 5000: return true 
	
	var coord = empty_cells[index]
	
	# Shuffle allowed tiles so we don't always favor 0s over 1s
	var shuffled_allowed = allowed.duplicate()
	shuffled_allowed.shuffle()
	
	for val in shuffled_allowed:
		if _is_valid_placement(coord, val, layout, w, h):
			layout[coord] = val
			if _solve(layout, empty_cells, index + 1, w, h, allowed, iter):
				return true
			layout[coord] = -1 # Backtrack
			
	return false

static func _is_valid_placement(coord: Vector2i, val: int, layout: Dictionary, w: int, h: int) -> bool:
	# Check 1: Max 1 Joker per line
	if val == 2:
		var joker_col = 0
		var joker_row = 0
		for y in range(h): if layout.get(Vector2i(coord.x, y), -1) == 2: joker_col += 1
		for x in range(w): if layout.get(Vector2i(x, coord.y), -1) == 2: joker_row += 1
		if joker_col > 0 or joker_row > 0: return false

	layout[coord] = val # Temporarily place it to run visual checks
	
	# Check 2: Max 2 of the same color in a row (Jokers act as Wildcards)
	for x in range(max(0, coord.x - 2), min(w - 2, coord.x + 1)):
		var v1 = layout.get(Vector2i(x, coord.y), -1)
		var v2 = layout.get(Vector2i(x+1, coord.y), -1)
		var v3 = layout.get(Vector2i(x+2, coord.y), -1)
		if v1 >= 0 and v2 >= 0 and v3 >= 0 and v1 != -2 and v2 != -2 and v3 != -2:
			var is_zero = (v1==0 or v1==2) and (v2==0 or v2==2) and (v3==0 or v3==2)
			var is_one = (v1==1 or v1==2) and (v2==1 or v2==2) and (v3==1 or v3==2)
			if is_zero or is_one:
				layout[coord] = -1
				return false
				
	for y in range(max(0, coord.y - 2), min(h - 2, coord.y + 1)):
		var v1 = layout.get(Vector2i(coord.x, y), -1)
		var v2 = layout.get(Vector2i(coord.x, y+1), -1)
		var v3 = layout.get(Vector2i(coord.x, y+2), -1)
		if v1 >= 0 and v2 >= 0 and v3 >= 0 and v1 != -2 and v2 != -2 and v3 != -2:
			var is_zero = (v1==0 or v1==2) and (v2==0 or v2==2) and (v3==0 or v3==2)
			var is_one = (v1==1 or v1==2) and (v2==1 or v2==2) and (v3==1 or v3==2)
			if is_zero or is_one:
				layout[coord] = -1
				return false

	# Check 3: Strict Equality Parity (Only check if line is completed)
	var col_playable = 0; var col_filled = 0; var col_0 = 0; var col_1 = 0
	for y in range(h):
		var st = layout.get(Vector2i(coord.x, y), -1)
		if st != -2:
			col_playable += 1
			if st >= 0:
				col_filled += 1
				if st == 0: col_0 += 1
				elif st == 1: col_1 += 1
	if col_playable > 0 and col_playable == col_filled:
		if col_0 != col_1:
			layout[coord] = -1
			return false
			
	var row_playable = 0; var row_filled = 0; var row_0 = 0; var row_1 = 0
	for x in range(w):
		var st = layout.get(Vector2i(x, coord.y), -1)
		if st != -2:
			row_playable += 1
			if st >= 0:
				row_filled += 1
				if st == 0: row_0 += 1
				elif st == 1: row_1 += 1
	if row_playable > 0 and row_playable == row_filled:
		if row_0 != row_1:
			layout[coord] = -1
			return false

	layout[coord] = -1 # Revert test placement
	return true
