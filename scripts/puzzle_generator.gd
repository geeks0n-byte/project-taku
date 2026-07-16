class_name PuzzleGenerator
extends RefCounted

static func generate_random_layout(width: int, height: int, _allowed_tiles: Array) -> Dictionary:
	var layout = {}
	
	# 1. Initialize an empty board
	for y in range(height):
		for x in range(width):
			layout[Vector2i(x, y)] = -1

	# 2. Place random corner walls (0 to 3 walls max)
	# By explicitly restricting walls to the absolute outer corners, 
	# we guarantee they NEVER split the board or get trapped inside playable tiles!
	var corners = [Vector2i(0,0), Vector2i(width-1, 0), Vector2i(0, height-1), Vector2i(width-1, height-1)]
	corners.shuffle()
	var num_walls = randi() % 4 
	for i in range(num_walls):
		layout[corners[i]] = -2

	# 3. Gather all empty playable cells
	var empty_cells = []
	for c in layout.keys():
		if layout[c] == -1: 
			empty_cells.append(c)
	empty_cells.shuffle()

	# 4. Generate Shifters (75% chance to include a Shifter pair)
	var shifters = []
	var has_shifter = (randi() % 100 < 75)
	var shifter_a = Vector2i(-1, -1)
	var shifter_b = Vector2i(-1, -1)
	
	if has_shifter and empty_cells.size() >= 2:
		shifter_a = empty_cells.pop_back()
		shifter_b = empty_cells.pop_back()
		layout[shifter_a] = 3 # Hard-lock the Shifter into the solved board
		empty_cells.append(shifter_b) # The partner space must be solved normally
		empty_cells.shuffle()

	# 5. Run the Backtracking Solver to generate a valid finished board
	# We force [0, 1, 2] so the solver can always use Jokers to balance odd-sized grids
	var solver_tiles = [0, 1, 2] 
	var iter_tracker = {"count": 0}
	_solve(layout, empty_cells, 0, width, height, solver_tiles, iter_tracker)

	# 6. Generate Constraints (1 to 4 random pairs)
	var constraints = []
	var adjacent_pairs = []
	for y in range(height):
		for x in range(width):
			var c = Vector2i(x, y)
			# Only place constraints between Yellow (0) and Blue (1) to keep clues strictly logical
			if layout[c] == 0 or layout[c] == 1:
				var right = c + Vector2i(1, 0)
				var down = c + Vector2i(0, 1)
				if layout.has(right) and (layout[right] == 0 or layout[right] == 1):
					adjacent_pairs.append({"a": c, "b": right})
				if layout.has(down) and (layout[down] == 0 or layout[down] == 1):
					adjacent_pairs.append({"a": c, "b": down})

	adjacent_pairs.shuffle()
	var num_constraints = randi_range(1, 4)
	for i in range(min(num_constraints, adjacent_pairs.size())):
		var p = adjacent_pairs[i]
		var type = "equals" if layout[p.a] == layout[p.b] else "not_equals"
		constraints.append({"a": p.a, "b": p.b, "type": type})

	# 7. Punch Holes in the board to turn it into a puzzle!
	# We want to leave as FEW tiles as possible (around 15% to 20%)
	var filled_cells = []
	for c in layout.keys():
		if layout[c] >= 0 and layout[c] != 3: 
			filled_cells.append(c)
			
	filled_cells.shuffle()
	var keep_count = max(2, int(filled_cells.size() * 0.15)) 
	
	var clues = []
	for i in range(keep_count):
		clues.append(filled_cells[i])

	# 8. Compile the Final Layout
	var final_layout = {}
	for c in layout.keys():
		if layout[c] == -2:
			final_layout[c] = -2
		elif clues.has(c):
			final_layout[c] = layout[c] # Keep this tile as a locked clue
		else:
			final_layout[c] = -1 # Erase for the player to figure out
			
	if has_shifter:
		# Randomize where the Shifter physically starts so the player might have to move it
		var active_node = shifter_a if randi() % 2 == 0 else shifter_b
		shifters.append({"a": shifter_a, "b": shifter_b, "active": active_node})
		final_layout[shifter_a] = -1
		final_layout[shifter_b] = -1

	return {
		"layout": final_layout,
		"shifters": shifters,
		"constraints": constraints
	}

# --- THE BACKTRACKING SOLVER ALGORITHM ---
static func _solve(layout: Dictionary, empty_cells: Array, index: int, w: int, h: int, allowed: Array, iter: Dictionary) -> bool:
	if index >= empty_cells.size(): return true
	
	iter.count += 1
	# Failsafe: Abort solver if stuck in an impossible math loop to prevent game freeze
	if iter.count > 5000: return true 
	
	var coord = empty_cells[index]
	var shuffled_allowed = allowed.duplicate()
	shuffled_allowed.shuffle() # Randomize tile tests so boards aren't always 0-heavy
	
	for val in shuffled_allowed:
		if _is_valid_placement(coord, val, layout, w, h):
			layout[coord] = val
			if _solve(layout, empty_cells, index + 1, w, h, allowed, iter):
				return true
			layout[coord] = -1 # Backtrack
			
	return false

static func _is_valid_placement(coord: Vector2i, val: int, layout: Dictionary, w: int, h: int) -> bool:
	# Rule 1: Max 1 Joker per row/col
	if val == 2:
		var joker_col = 0
		var joker_row = 0
		for y in range(h): if layout.get(Vector2i(coord.x, y), -1) == 2: joker_col += 1
		for x in range(w): if layout.get(Vector2i(x, coord.y), -1) == 2: joker_row += 1
		if joker_col > 0 or joker_row > 0: return false

	layout[coord] = val 
	
	# Rule 2: Max 2 of the same color in a row (Jokers act as Wildcards)
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

	# Rule 3: Strict Equality Parity
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

	layout[coord] = -1 
	return true
