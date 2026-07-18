class_name PuzzleGenerator
extends RefCounted

static func generate_random_layout(width: int, height: int, allowed_tiles: Array, current_layout: Dictionary = {}, require_unique: bool = true) -> Dictionary:
	var attempt = 0
	
	# The solver MUST have access to Jokers (2) to satisfy odd-parity rules.
	var solver_tiles = allowed_tiles.duplicate()
	if not (2 in solver_tiles): solver_tiles.append(2)
	if not (0 in solver_tiles): solver_tiles.append(0)
	if not (1 in solver_tiles): solver_tiles.append(1)
	
	while attempt < 200: 
		attempt += 1
		var force_easy = (attempt > 40)
		
		# ==========================================
		# STEP 1: Generate board & respect existing walls
		# ==========================================
		var layout = {}
		var has_existing_walls = false
		for y in range(height):
			for x in range(width):
				var c = Vector2i(x, y)
				if current_layout.has(c) and current_layout[c] == -2:
					layout[c] = -2 
					has_existing_walls = true
				else:
					layout[c] = -1

		var all_cells = layout.keys()
		all_cells.shuffle()

		# STEP 1B: If "Keep Walls" was OFF, generate fresh random walls!
		if not has_existing_walls:
			var max_walls = 0 if force_easy else randi_range(0, int(all_cells.size() * 0.15))
			var num_walls_placed = 0
			var row_counts = {}; var col_counts = {}
			for i in range(height): row_counts[i] = 0
			for i in range(width): col_counts[i] = 0

			for coord in all_cells:
				if num_walls_placed >= max_walls: break
				if row_counts[coord.y] >= width - 1 or col_counts[coord.x] >= height - 1:
					continue
					
				var neighbors = [
					coord + Vector2i(1, 0), coord + Vector2i(-1, 0),
					coord + Vector2i(0, 1), coord + Vector2i(0, -1)
				]
				var playable_count = 0
				for n in neighbors:
					if layout.has(n) and layout[n] != -2: playable_count += 1
				if playable_count == 4: continue 
					
				layout[coord] = -2
				row_counts[coord.y] += 1
				col_counts[coord.x] += 1
				num_walls_placed += 1

		var empty_cells = []
		for c in layout.keys():
			if layout[c] == -1: empty_cells.append(c)
		empty_cells.shuffle()

		# ==========================================
		# STEP 2: Fill remaining cells with Shifters (~20% or AT LEAST 1)
		# ==========================================
		var shifters = []
		var total_playable = empty_cells.size()
		
		var target_shifter_pairs = int(round((total_playable * 0.20) / 2.0))
		if target_shifter_pairs < 1 and total_playable >= 2:
			target_shifter_pairs = 1
		
		var pairs_placed = 0
		var shifter_attempts = 0
		
		while pairs_placed < target_shifter_pairs and shifter_attempts < 100:
			shifter_attempts += 1
			if empty_cells.size() < 2: break
			
			var idx_a = randi() % empty_cells.size()
			var candidate_a = empty_cells[idx_a]
			
			var neighbors = [
				candidate_a + Vector2i(1, 0), candidate_a + Vector2i(-1, 0),
				candidate_a + Vector2i(0, 1), candidate_a + Vector2i(0, -1)
			]
			neighbors.shuffle()
			
			var placed = false
			for candidate_b in neighbors:
				var idx_b = empty_cells.find(candidate_b)
				if idx_b != -1:
					# FIX: Only the active node is 3 (Purple). 
					# The inactive node is left as -1 so the solver assigns it a normal color underneath!
					var active_node = candidate_a if randi() % 2 == 0 else candidate_b
					var inactive_node = candidate_b if active_node == candidate_a else candidate_a
					
					layout[active_node] = 3
					layout[inactive_node] = -1
					shifters.append({"a": candidate_a, "b": candidate_b, "active": active_node})
					
					# Erase only the active node so the solver fills the inactive one
					empty_cells.erase(active_node)
					placed = true
					pairs_placed += 1
					break
			if placed: continue

		# Solve the rest of the board with Yellow, Blue, Green (0, 1, 2)
		var iter_tracker = {"count": 0}
		var success = _solve(layout, empty_cells.duplicate(), width, height, solver_tiles, [], iter_tracker)
		if not success: continue 
			
		var solved_layout = layout.duplicate()
		
		# --- JOKER CALCULATION ---
		var total_jokers_generated = 0
		for c in solved_layout.keys():
			if solved_layout[c] == 2:
				total_jokers_generated += 1

		# ==========================================
		# STEP 3: Create as much hints as possible
		# ==========================================
		var constraints = []
		for y in range(height):
			for x in range(width):
				var c = Vector2i(x, y)
				if solved_layout[c] in [0, 1]:
					var right = c + Vector2i(1, 0)
					var down = c + Vector2i(0, 1)
					
					if solved_layout.has(right) and solved_layout[right] in [0, 1]:
						var type = "equals" if solved_layout[c] == solved_layout[right] else "not_equals"
						constraints.append({"a": c, "b": right, "type": type})
							
					if solved_layout.has(down) and solved_layout[down] in [0, 1]:
						var type = "equals" if solved_layout[c] == solved_layout[down] else "not_equals"
						constraints.append({"a": c, "b": down, "type": type})

		# ==========================================
		# STEP 4: Smart Hole Punching
		# ==========================================
		var all_filled_cells = []
		var green_cells = []
		
		for c in layout.keys():
			if layout[c] >= 0: 
				all_filled_cells.append(c)
				if layout[c] == 2:
					green_cells.append(c)
					
		var clearable_cells = all_filled_cells.duplicate()
		
		if green_cells.size() > 0:
			green_cells.shuffle()
			clearable_cells.erase(green_cells[0])
			
		clearable_cells.shuffle()
		
		var total_filled_count = all_filled_cells.size()
		var min_clear_count = int(ceil(total_filled_count * 0.67))
		var max_clear_count = int(total_filled_count * 0.85)
		
		if min_clear_count > clearable_cells.size(): min_clear_count = clearable_cells.size()
		if max_clear_count > clearable_cells.size(): max_clear_count = clearable_cells.size()
		if min_clear_count > max_clear_count: max_clear_count = min_clear_count
			
		var target_to_clear = 0
		if max_clear_count > 0:
			target_to_clear = randi_range(min_clear_count, max_clear_count)
		
		var current_empty = []
		for c in layout.keys():
			if layout[c] == -1: current_empty.append(c)
			
		var cleared_count = 0
		
		for c in clearable_cells:
			if not require_unique and cleared_count >= target_to_clear:
				break 
				
			var original_val = layout[c]
			layout[c] = -1
			current_empty.append(c)
			
			if require_unique:
				var sols = _count_solutions(layout, current_empty, width, height, solver_tiles, constraints, {"count": 0})
				
				if sols != 1:
					layout[c] = original_val
					current_empty.erase(c)
				else:
					cleared_count += 1
			else:
				cleared_count += 1

		# FIX: Set shifter active cell to -1 so Editor renders it dynamically
		for pair in shifters:
			layout[pair.active] = -1

		return {
			"layout": layout,
			"shifters": shifters,
			"constraints": constraints,
			"total_jokers": total_jokers_generated
		}
		
	push_error("Generator failed: Generated walls may be mathematically impossible with the strict parity rules.")
	return {} 

static func _solve(layout: Dictionary, empty_cells: Array, w: int, h: int, allowed: Array, constraints: Array, iter: Dictionary) -> bool:
	if empty_cells.size() == 0: return true
	iter.count += 1
	if iter.count > 10000: return false 
	
	var best_idx = -1
	var min_opts = 999
	var best_valid_vals = []

	for i in range(empty_cells.size()):
		var test_coord = empty_cells[i] 
		var valid_vals = []
		for val in allowed:
			if _is_valid_placement(test_coord, val, layout, w, h, constraints):
				valid_vals.append(val)
				
		var c_opts = valid_vals.size()
		if c_opts < min_opts:
			min_opts = c_opts
			best_idx = i
			best_valid_vals = valid_vals
			if min_opts <= 1: break 
				
	if min_opts == 0: return false 

	var best_coord = empty_cells[best_idx] 
	empty_cells.remove_at(best_idx)
	best_valid_vals.shuffle() 
	
	for val in best_valid_vals:
		layout[best_coord] = val
		if _solve(layout, empty_cells, w, h, allowed, constraints, iter):
			return true
		layout[best_coord] = -1 
		
	empty_cells.insert(best_idx, best_coord) 
	return false

static func _count_solutions(layout: Dictionary, empty_cells: Array, w: int, h: int, allowed: Array, constraints: Array, iter: Dictionary) -> int:
	if empty_cells.size() == 0: return 1
	iter.count += 1
	if iter.count > 5000: return 2 
	
	var best_idx = -1
	var min_opts = 999
	var best_valid_vals = []

	for i in range(empty_cells.size()):
		var test_coord = empty_cells[i] 
		var valid_vals = []
		for val in allowed:
			if _is_valid_placement(test_coord, val, layout, w, h, constraints):
				valid_vals.append(val)
				
		var c_opts = valid_vals.size()
		if c_opts < min_opts:
			min_opts = c_opts
			best_idx = i
			best_valid_vals = valid_vals
			if min_opts <= 1: break

	if min_opts == 0: return 0

	var best_coord = empty_cells[best_idx] 
	empty_cells.remove_at(best_idx)
	
	var total_sols = 0
	for val in best_valid_vals:
		layout[best_coord] = val
		total_sols += _count_solutions(layout, empty_cells, w, h, allowed, constraints, iter)
		layout[best_coord] = -1 
		if total_sols > 1: break
			
	empty_cells.insert(best_idx, best_coord) 
	return total_sols

# --- NEW PURE MATHEMATICAL PARITY VALIDATION ---
static func _is_valid_placement(coord: Vector2i, val: int, layout: Dictionary, w: int, h: int, constraints: Array) -> bool:
	layout[coord] = val 
	
	# 1. Block 3-in-a-row (Jokers actively act as both colors for this check)
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

	# 2. Perfect Row Parity (Natively handles your Odd/Even rules)
	var p_row = 0; var s_row = 0; var j_row = 0; var empty_row = 0; var b0_row = 0; var b1_row = 0
	for x in range(w):
		var st = layout.get(Vector2i(x, coord.y), -1)
		if st != -2:
			p_row += 1
			if st == -1: empty_row += 1
			elif st == 3: s_row += 1
			elif st == 2: j_row += 1
			elif st == 0: b0_row += 1
			elif st == 1: b1_row += 1
			
	var req_j_row = (p_row - s_row) % 2
	
	if j_row > req_j_row: layout[coord] = -1; return false # Guaranteed 0 or 1 Max!
	if empty_row == 0 and j_row != req_j_row: layout[coord] = -1; return false
		
	var target_0_row = int((p_row - req_j_row - s_row) / 2.0)
	if b0_row > target_0_row or b1_row > target_0_row: layout[coord] = -1; return false
		
	# 3. Perfect Column Parity (Natively handles your Odd/Even rules)
	var p_col = 0; var s_col = 0; var j_col = 0; var empty_col = 0; var b0_col = 0; var b1_col = 0
	for y in range(h):
		var st = layout.get(Vector2i(coord.x, y), -1)
		if st != -2:
			p_col += 1
			if st == -1: empty_col += 1
			elif st == 3: s_col += 1
			elif st == 2: j_col += 1
			elif st == 0: b0_col += 1
			elif st == 1: b1_col += 1
			
	var req_j_col = (p_col - s_col) % 2
	
	if j_col > req_j_col: layout[coord] = -1; return false # Guaranteed 0 or 1 Max!
	if empty_col == 0 and j_col != req_j_col: layout[coord] = -1; return false
		
	var target_0_col = int((p_col - req_j_col - s_col) / 2.0)
	if b0_col > target_0_col or b1_col > target_0_col: layout[coord] = -1; return false

	# 4. Check Constraints
	for c in constraints:
		if c.a == coord or c.b == coord:
			var other_coord = c.b if c.a == coord else c.a
			var other_val = layout.get(other_coord, -1)
			if val in [0, 1] and other_val in [0, 1]:
				if c.type == "equals" and val != other_val: layout[coord] = -1; return false
				if c.type == "not_equals" and val == other_val: layout[coord] = -1; return false

	layout[coord] = -1 
	return true
