class_name PuzzleGenerator
extends RefCounted

static func generate_random_layout(width: int, height: int, allowed_tiles: Array) -> Dictionary:
	var attempt = 0
	var gen_start_time = Time.get_ticks_msec()
	
	# The solver MUST have access to Jokers (2) to satisfy the odd-parity rules, 
	# even if the user unchecked it, otherwise mathematically impossible grids would infinite-loop.
	var solver_tiles = allowed_tiles.duplicate()
	if not (2 in solver_tiles): solver_tiles.append(2)
	if not (0 in solver_tiles): solver_tiles.append(0)
	if not (1 in solver_tiles): solver_tiles.append(1)
	
	while attempt < 200: 
		attempt += 1
		var force_easy = (attempt > 40) or (Time.get_ticks_msec() - gen_start_time > 3000)
		
		# ==========================================
		# STEP 1: Generate board using width and height
		# ==========================================
		var layout = {}
		for y in range(height):
			for x in range(width):
				layout[Vector2i(x, y)] = -1

		var all_cells = layout.keys()
		all_cells.shuffle()
		
		# ==========================================
		# STEP 2: Randomly change cells to walls
		# ==========================================
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
		# STEP 3: Fill remaining cells with Yellow, Blue, Green, and Purple tiles
		# ==========================================
		
		# 3A. Place Purple Shifters (State 3) first to establish parity
		var shifters = []
		var has_shifter = false if force_easy else (randi() % 100 < 75)
		var shifter_a = Vector2i(-1, -1)
		var shifter_b = Vector2i(-1, -1)
		
		if has_shifter:
			var found_pair = false
			for i in range(empty_cells.size()):
				var candidate_a = empty_cells[i]
				var neighbors = [
					candidate_a + Vector2i(1, 0), candidate_a + Vector2i(-1, 0),
					candidate_a + Vector2i(0, 1), candidate_a + Vector2i(0, -1)
				]
				neighbors.shuffle()
				
				for candidate_b in neighbors:
					var b_index = empty_cells.find(candidate_b)
					if b_index != -1:
						
						# VALIDATE SHIFTER PLACEMENT (Parity Rules)
						layout[candidate_a] = 3
						layout[candidate_b] = 3
						var placement_valid = true
						for c in [candidate_a, candidate_b]:
							var p_r = 0; var s_r = 0
							for x in range(width):
								var st = layout[Vector2i(x, c.y)]
								if st != -2: p_r += 1
								if st == 3: s_r += 1
							if p_r % 2 == 1 and s_r > 1: placement_valid = false
							
							var p_c = 0; var s_c = 0
							for y in range(height):
								var st = layout[Vector2i(c.x, y)]
								if st != -2: p_c += 1
								if st == 3: s_c += 1
							if p_c % 2 == 1 and s_c > 1: placement_valid = false
							
						layout[candidate_a] = -1
						layout[candidate_b] = -1
						
						if not placement_valid:
							continue
							
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

		# 3B. Solve the rest of the board with Yellow, Blue, Green (0, 1, 2)
		var iter_tracker = {"count": 0}
		var success = _solve(layout, empty_cells.duplicate(), width, height, solver_tiles, iter_tracker)
		if not success: continue 
			
		var solved_layout = layout.duplicate()

		# Finalize Shifter Logic for Editor format
		# (This turns them to -1 in the layout dictionary so they are physically immune to being overwritten)
		if has_shifter:
			var active_node = shifter_a if randi() % 2 == 0 else shifter_b
			shifters.append({"a": shifter_a, "b": shifter_b, "active": active_node})
			layout[shifter_a] = -1
			layout[shifter_b] = -1

		# ==========================================
		# STEP 4: Create as much hints as possible
		# ==========================================
		var constraints = []
		for y in range(height):
			for x in range(width):
				var c = Vector2i(x, y)
				# Only generate hints between confirmed Yellow (0) or Blue (1) tiles
				if solved_layout[c] in [0, 1]:
					var right = c + Vector2i(1, 0)
					var down = c + Vector2i(0, 1)
					
					# Check Right Neighbor
					if solved_layout.has(right) and solved_layout[right] in [0, 1]:
						var type = "equals" if solved_layout[c] == solved_layout[right] else "not_equals"
						constraints.append({"a": c, "b": right, "type": type})
							
					# Check Down Neighbor
					if solved_layout.has(down) and solved_layout[down] in [0, 1]:
						var type = "equals" if solved_layout[c] == solved_layout[down] else "not_equals"
						constraints.append({"a": c, "b": down, "type": type})

		# ==========================================
		# STEP 5: Randomly change at least 67% of remaining tiles to 'clear state'
		# (Must leave at least 1 green tile. Purple tiles are already immune).
		# ==========================================
		var all_filled_cells = []
		var green_cells = []
		
		for c in layout.keys():
			# Collect all cells that are currently 0, 1, or 2 (Purple shifters are already -1)
			if layout[c] >= 0: 
				all_filled_cells.append(c)
				if layout[c] == 2:
					green_cells.append(c)
					
		var clearable_cells = all_filled_cells.duplicate()
		
		# Protect at least 1 Green tile if any were generated
		if green_cells.size() > 0:
			green_cells.shuffle()
			var protected_green_cell = green_cells[0]
			clearable_cells.erase(protected_green_cell)
			
		clearable_cells.shuffle()
		
		# Calculate the 67% threshold based on the TOTAL filled cells
		var total_filled_count = all_filled_cells.size()
		var min_clear_count = int(ceil(total_filled_count * 0.67))
		var max_clear_count = int(total_filled_count * 0.85)
		
		# Failsafe bounds checks
		if min_clear_count > clearable_cells.size():
			min_clear_count = clearable_cells.size()
		if max_clear_count > clearable_cells.size():
			max_clear_count = clearable_cells.size()
		if min_clear_count > max_clear_count:
			max_clear_count = min_clear_count
			
		var target_to_clear = 0
		if max_clear_count > 0:
			target_to_clear = randi_range(min_clear_count, max_clear_count)
		
		# Erase the selected cells
		for i in range(target_to_clear):
			layout[clearable_cells[i]] = -1

		# SUCCESS! Return the generated puzzle data
		return {
			"layout": layout,
			"shifters": shifters,
			"constraints": constraints 
		}
		
	push_error("Generator failed: Board dimensions or generated walls may be mathematically impossible with the strict parity rules.")
	return {} 

static func _solve(layout: Dictionary, empty_cells: Array, w: int, h: int, allowed: Array, iter: Dictionary) -> bool:
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
			if _is_valid_placement(test_coord, val, layout, w, h):
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
		if _solve(layout, empty_cells, w, h, allowed, iter):
			return true
		layout[best_coord] = -1 
		
	empty_cells.insert(best_idx, best_coord) 
	return false

# --- MATHEMATICALLY PERFECT PARITY VALIDATION ---
static func _is_valid_placement(coord: Vector2i, val: int, layout: Dictionary, w: int, h: int) -> bool:
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

	# 2. Row Strict Parity Enforcement
	var p_row = 0; var s_row = 0; var j_row = 0; var empty_row = 0
	var b0_row = 0; var b1_row = 0
	for x in range(w):
		var st = layout.get(Vector2i(x, coord.y), -1)
		if st != -2:
			p_row += 1
			if st == -1: empty_row += 1
			elif st == 3: s_row += 1
			elif st == 2: j_row += 1
			elif st == 0: b0_row += 1
			elif st == 1: b1_row += 1
			
	var req_j_row = 0
	if p_row % 2 == 1: # ODD Playable
		if s_row == 0: req_j_row = 1
		elif s_row == 1: req_j_row = 0
		else: 
			layout[coord] = -1
			return false
	else: # EVEN Playable
		if s_row == 0: req_j_row = 0
		elif s_row == 1: req_j_row = 1
		elif s_row == 2: req_j_row = 0
		else: 
			layout[coord] = -1
			return false
			
	# Enforce Joker Limits
	if j_row > req_j_row:
		layout[coord] = -1
		return false
	if empty_row == 0 and j_row != req_j_row:
		layout[coord] = -1
		return false
		
	# Enforce Yellow/Blue exact equality remaining
	var target_0_row = int((p_row - req_j_row - s_row) / 2.0)
	if b0_row > target_0_row or b1_row > target_0_row:
		layout[coord] = -1
		return false
		
	# 3. Column Strict Parity Enforcement
	var p_col = 0; var s_col = 0; var j_col = 0; var empty_col = 0
	var b0_col = 0; var b1_col = 0
	for y in range(h):
		var st = layout.get(Vector2i(coord.x, y), -1)
		if st != -2:
			p_col += 1
			if st == -1: empty_col += 1
			elif st == 3: s_col += 1
			elif st == 2: j_col += 1
			elif st == 0: b0_col += 1
			elif st == 1: b1_col += 1
			
	var req_j_col = 0
	if p_col % 2 == 1: # ODD Playable
		if s_col == 0: req_j_col = 1
		elif s_col == 1: req_j_col = 0
		else: 
			layout[coord] = -1
			return false
	else: # EVEN Playable
		if s_col == 0: req_j_col = 0
		elif s_col == 1: req_j_col = 1
		elif s_col == 2: req_j_col = 0
		else: 
			layout[coord] = -1
			return false
			
	# Enforce Joker Limits
	if j_col > req_j_col:
		layout[coord] = -1
		return false
	if empty_col == 0 and j_col != req_j_col:
		layout[coord] = -1
		return false
		
	# Enforce Yellow/Blue exact equality remaining
	var target_0_col = int((p_col - req_j_col - s_col) / 2.0)
	if b0_col > target_0_col or b1_col > target_0_col:
		layout[coord] = -1
		return false

	layout[coord] = -1 
	return true
