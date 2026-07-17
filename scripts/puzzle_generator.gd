class_name PuzzleGenerator
extends RefCounted

static func generate_random_layout(width: int, height: int, _allowed_tiles: Array) -> Dictionary:
	var attempt = 0
	var gen_start_time = Time.get_ticks_msec()
	
	# We wrap the generator in a retry loop. If a random placement of walls or shifters
	# creates a mathematically impossible board, it instantly aborts and tries again!
	while true:
		attempt += 1
		# Failsafe: If the requested size is extremely difficult to solve, or generation 
		# takes > 1.5 seconds overall, force easy mode to guarantee a playable standard puzzle.
		var force_easy = (attempt > 20) or (Time.get_ticks_msec() - gen_start_time > 1500)
		
		var layout = {}
		for y in range(height):
			for x in range(width):
				layout[Vector2i(x, y)] = -1

		var all_cells = layout.keys()
		all_cells.shuffle()
		
		# 1. Place random Walls
		var max_walls = 0 if force_easy else randi_range(0, int(all_cells.size() * 0.15))
		var num_walls_placed = 0
		
		var row_counts = {}
		var col_counts = {}
		for i in range(height): row_counts[i] = 0
		for i in range(width): col_counts[i] = 0

		for coord in all_cells:
			if num_walls_placed >= max_walls: break
			
			if row_counts[coord.y] >= width - 1 or col_counts[coord.x] >= height - 1:
				continue
				
			var neighbors = [
				coord + Vector2i(1, 0),
				coord + Vector2i(-1, 0),
				coord + Vector2i(0, 1),
				coord + Vector2i(0, -1)
			]
			
			var playable_count = 0
			for n in neighbors:
				if layout.has(n) and layout[n] != -2:
					playable_count += 1
					
			if playable_count == 4:
				continue 
				
			layout[coord] = -2
			row_counts[coord.y] += 1
			col_counts[coord.x] += 1
			num_walls_placed += 1

		# 2. Gather Empty Cells
		var empty_cells = []
		for c in layout.keys():
			if layout[c] == -1: 
				empty_cells.append(c)
		empty_cells.shuffle()

		# 3. Generate Shifters (75% chance)
		var shifters = []
		var has_shifter = false if force_easy else (randi() % 100 < 75)
		var shifter_a = Vector2i(-1, -1)
		var shifter_b = Vector2i(-1, -1)
		
		if has_shifter:
			var found_pair = false
			for i in range(empty_cells.size()):
				var candidate_a = empty_cells[i]
				var neighbors = [
					candidate_a + Vector2i(1, 0),
					candidate_a + Vector2i(-1, 0),
					candidate_a + Vector2i(0, 1),
					candidate_a + Vector2i(0, -1)
				]
				neighbors.shuffle()
				
				for candidate_b in neighbors:
					var b_index = empty_cells.find(candidate_b)
					if b_index != -1:
						shifter_a = candidate_a
						shifter_b = candidate_b
						
						empty_cells.remove_at(max(i, b_index))
						empty_cells.remove_at(min(i, b_index))
						
						layout[shifter_a] = 3 
						empty_cells.append(shifter_b) 
						empty_cells.shuffle()
						
						found_pair = true
						break
						
				if found_pair: break
			if not found_pair: has_shifter = false

		# 4. Solve the Board (Using ultra-fast MRV heuristic)
		var solver_tiles = [0, 1, 2] 
		var iter_tracker = {"count": 0}
		var success = _solve(layout, empty_cells.duplicate(), width, height, solver_tiles, iter_tracker)
		
		if not success:
			continue 
			
		var solved_layout = layout.duplicate()
			
		# 5. Uniqueness Hole-Punching with strict TIME LIMIT
		var filled_cells = []
		for c in layout.keys():
			if layout[c] >= 0 and layout[c] != 3: 
				filled_cells.append(c)
				
		filled_cells.shuffle()
		
		var hole_punch_start = Time.get_ticks_msec()
		var max_punch_time = 400 # Guarantees UI will NEVER freeze longer than 0.4 seconds!
		
		for c in filled_cells:
			# If checking uniqueness takes too long on big boards, stop erasing!
			# The puzzle will just have a few extra clues.
			if Time.get_ticks_msec() - hole_punch_start > max_punch_time:
				break
				
			var original_val = layout[c]
			layout[c] = -1 
			
			var current_empty = []
			for k in layout.keys():
				if layout[k] == -1: current_empty.append(k)
				
			var sols = _count_solutions(layout, current_empty, width, height, solver_tiles, {"count": 0})
			
			if sols != 1:
				layout[c] = original_val

		# 6. Finalize Shifter Display
		if has_shifter:
			var active_node = shifter_a if randi() % 2 == 0 else shifter_b
			shifters.append({"a": shifter_a, "b": shifter_b, "active": active_node})
			layout[shifter_a] = -1
			layout[shifter_b] = -1

		# 7. Generate Smart Hints
		var constraints = []
		var candidate_hint_pairs = []
		
		for y in range(height):
			for x in range(width):
				var c = Vector2i(x, y)
				if layout[c] != -2:
					var right = c + Vector2i(1, 0)
					var down = c + Vector2i(0, 1)
					
					if layout.has(right) and layout[right] != -2:
						if solved_layout[c] in [0, 1] and solved_layout[right] in [0, 1]:
							if layout[c] == -1 or layout[right] == -1:
								if c != shifter_a and c != shifter_b and right != shifter_a and right != shifter_b:
									candidate_hint_pairs.append({"a": c, "b": right})
					
					if layout.has(down) and layout[down] != -2:
						if solved_layout[c] in [0, 1] and solved_layout[down] in [0, 1]:
							if layout[c] == -1 or layout[down] == -1:
								if c != shifter_a and c != shifter_b and down != shifter_a and down != shifter_b:
									candidate_hint_pairs.append({"a": c, "b": down})

		candidate_hint_pairs.shuffle()
		var num_hints = randi_range(1, 3) 
		for i in range(min(num_hints, candidate_hint_pairs.size())):
			var p = candidate_hint_pairs[i]
			var type = "equals" if solved_layout[p.a] == solved_layout[p.b] else "not_equals"
			constraints.append({"a": p.a, "b": p.b, "type": type})

		return {
			"layout": layout,
			"shifters": shifters,
			"constraints": constraints 
		}

	return {} 

# --- ULTRA-FAST MRV SOLVER ---
static func _solve(layout: Dictionary, empty_cells: Array, w: int, h: int, allowed: Array, iter: Dictionary) -> bool:
	if empty_cells.size() == 0: return true
	
	iter.count += 1
	if iter.count > 2000: return false 
	
	# Minimum Remaining Values (MRV) Heuristic
	# Find the cell with the fewest possible valid tiles to prune dead-ends instantly
	var best_idx = -1
	var min_opts = 999
	var best_valid_vals = []

	for i in range(empty_cells.size()):
		var test_coord = empty_cells[i] # FIXED: Renamed to avoid shadowing
		var valid_vals = []
		for val in allowed:
			if _is_valid_placement(test_coord, val, layout, w, h):
				valid_vals.append(val)
				
		var c_opts = valid_vals.size()
		if c_opts < min_opts:
			min_opts = c_opts
			best_idx = i
			best_valid_vals = valid_vals
			if min_opts <= 1:
				break # 0 or 1 option is the absolute best we can do, stop searching!
				
	if min_opts == 0:
		return false # Dead end found early! Save thousands of iterations!

	var best_coord = empty_cells[best_idx] # FIXED: Distinct variable name
	empty_cells.remove_at(best_idx)
	best_valid_vals.shuffle() 
	
	for val in best_valid_vals:
		layout[best_coord] = val
		if _solve(layout, empty_cells, w, h, allowed, iter):
			return true
		layout[best_coord] = -1 
		
	empty_cells.insert(best_idx, best_coord) # Backtrack
	return false

# --- ULTRA-FAST MRV UNIQUENESS CHECKER ---
static func _count_solutions(layout: Dictionary, empty_cells: Array, w: int, h: int, allowed: Array, iter: Dictionary) -> int:
	if empty_cells.size() == 0: return 1
	
	iter.count += 1
	if iter.count > 3000: return 2 # Failsafe assumes non-unique if taking too long
	
	var best_idx = -1
	var min_opts = 999
	var best_valid_vals = []

	for i in range(empty_cells.size()):
		var test_coord = empty_cells[i] # FIXED: Renamed to avoid shadowing
		var valid_vals = []
		for val in allowed:
			if _is_valid_placement(test_coord, val, layout, w, h):
				valid_vals.append(val)
				
		var c_opts = valid_vals.size()
		if c_opts < min_opts:
			min_opts = c_opts
			best_idx = i
			best_valid_vals = valid_vals
			if min_opts <= 1:
				break

	if min_opts == 0:
		return 0

	var best_coord = empty_cells[best_idx] # FIXED: Distinct variable name
	empty_cells.remove_at(best_idx)
	
	var total_sols = 0
	for val in best_valid_vals:
		layout[best_coord] = val
		total_sols += _count_solutions(layout, empty_cells, w, h, allowed, iter)
		layout[best_coord] = -1 
		
		# Abort early if we already proved it's not unique!
		if total_sols > 1:
			break
			
	empty_cells.insert(best_idx, best_coord) # Backtrack
	return total_sols

# --- VALIDATION RULES ---
static func _is_valid_placement(coord: Vector2i, val: int, layout: Dictionary, w: int, h: int) -> bool:
	if val == 2:
		var joker_col = 0
		var joker_row = 0
		for y in range(h): if layout.get(Vector2i(coord.x, y), -1) == 2: joker_col += 1
		for x in range(w): if layout.get(Vector2i(x, coord.y), -1) == 2: joker_row += 1
		if joker_col > 0 or joker_row > 0: return false

	layout[coord] = val 
	
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
