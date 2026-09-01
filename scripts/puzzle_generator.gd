class_name PuzzleGenerator
extends RefCounted
## Builds unique Taku puzzles: place tiles, shifters, and constraints, then verify solvability.

# Sentinel returned by _count_solutions when the iteration budget is exhausted
# before the solver could determine the true count.
const SOLUTIONS_UNKNOWN := -1
# Maximum recursive iterations allowed when finding a single solution.
const SOLVE_ITER_BUDGET := 60000
# Higher budget for the solution-count pass (needs to find at least two solutions
# to determine non-uniqueness, so it explores more of the tree).
const COUNT_ITER_BUDGET := 80000

enum Difficulty { EASY, MEDIUM, HARD }

# Fraction of accepted clue-punches that are allowed to leave no obvious move,
# used by the MEDIUM difficulty gate in _punch_keeps_obvious_move.
const MEDIUM_SKIP_OBVIOUS_FRACTION := 0.30

# Attempts up to 2500 times to generate a valid, playable puzzle layout.
# Each attempt:
#   1. Builds a blank grid (preserving locked walls, or generating new ones).
#   2. Randomly places shifter pairs (only when jokers are allowed).
#   3. Checks parity: every row and column must have the same (playable+shifter) parity
#      so that a balanced solution is mathematically possible.
#   4. Solves the grid to prove at least one solution exists.
#   5. "Punches" clues (removes pre-filled tiles) while maintaining uniqueness and
#      difficulty-appropriate solvability.
#   6. Minimises visible constraints while keeping the solution unique (hidden hints).
#   7. Randomises final shifter positions.
#   8. Validates the result with PuzzleSolver and PuzzleValidator before returning.
# Returns an empty dict on failure (rare with 2500 attempts).
static func generate_random_layout(
	width: int,
	height: int,
	allowed_tiles: Array,
	current_layout: Dictionary = {},
	require_unique: bool = true,
	lock_walls: bool = false,
	difficulty: int = Difficulty.MEDIUM,
	quiet: bool = false
) -> Dictionary:
	var attempt = 0
	var punch_difficulty := clampi(difficulty, Difficulty.EASY, Difficulty.HARD)
	var normalized := LevelUtils.normalize_available_tiles(allowed_tiles)
	var allow_jokers := LevelUtils.tiles_allow_joker(normalized)

	var solver_tiles: Array = []
	for t in normalized:
		solver_tiles.append(int(t))
	if not LevelUtils.tiles_include(solver_tiles, GameConstants.TileState.YELLOW):
		solver_tiles.append(GameConstants.TileState.YELLOW)
	if not LevelUtils.tiles_include(solver_tiles, GameConstants.TileState.BLUE):
		solver_tiles.append(GameConstants.TileState.BLUE)
	
	while attempt < 2500: 
		attempt += 1
		# Late attempts drop random walls so parity-stuck boards can still solve.
		var force_no_walls: bool = attempt > 2000
		
		var layout = {}
		for y in range(height):
			for x in range(width):
				var c = Vector2i(x, y)
				if lock_walls and current_layout.has(c) and int(current_layout[c]) == -2:
					layout[c] = -2
				else:
					layout[c] = -1

		if not lock_walls and not force_no_walls:
			_place_random_walls(layout, width, height, punch_difficulty, attempt)

		var empty_cells = []
		for c in layout.keys():
			if layout[c] == -1: empty_cells.append(c)
		empty_cells.shuffle()

		var shifters = []
		var total_playable = empty_cells.size()

		# Target ~20 % of playable cells as shifter pairs (each pair uses 2 cells).
		# As attempt count grows we allow more pairs to escape local stuck states.
		var base_shifter_pairs = 0 if not allow_jokers else int(round((total_playable * 0.20) / 2.0))
		var target_shifter_pairs = base_shifter_pairs

		if allow_jokers:
			target_shifter_pairs += int(attempt / 75.0)

			# Always guarantee at least one shifter pair on large enough grids so
			# the mechanic is actually present in joker-enabled puzzles.
			if target_shifter_pairs <= 1 and total_playable >= 4:
				target_shifter_pairs = randi_range(1, 2)
			elif target_shifter_pairs < 1 and total_playable >= 2:
				target_shifter_pairs = 1

		target_shifter_pairs = mini(target_shifter_pairs, int(total_playable / 2.0))
		
		var pairs_placed = 0
		var available_starts = empty_cells.duplicate()
		available_starts.shuffle()
		# Pairs may share a cell (chain A–B–C). They must not share an *active* cell.
		var used_actives: Dictionary = {}
		
		while pairs_placed < target_shifter_pairs and available_starts.size() > 0:
			var candidate_a = available_starts.pop_back()
			if not layout.has(candidate_a) or layout[candidate_a] != -1:
				continue
			
			var neighbors = [
				candidate_a + Vector2i(1, 0), candidate_a + Vector2i(-1, 0),
				candidate_a + Vector2i(0, 1), candidate_a + Vector2i(0, -1)
			]
			neighbors.shuffle()
			
			var placed = false
			for candidate_b in neighbors:
				if not layout.has(candidate_b):
					continue
				# Partner may be empty or already another pair's active (shared cell / chain).
				if layout[candidate_b] != -1 and layout[candidate_b] != 3:
					continue
				if _pair_already_exists(shifters, candidate_a, candidate_b):
					continue
				var active_node = _pick_unused_active(candidate_a, candidate_b, used_actives)
				if active_node == null:
					continue
				var inactive_node: Vector2i = candidate_b if active_node == candidate_a else candidate_a
				
				layout[active_node] = 3
				if layout[inactive_node] != 3:
					layout[inactive_node] = -1
				
				shifters.append({"a": candidate_a, "b": candidate_b, "active": active_node, "inactive": inactive_node})
				empty_cells.erase(active_node)
				used_actives[active_node] = true
				available_starts.erase(candidate_b)
				placed = true
				pairs_placed += 1
				break
			if placed: continue

		if pairs_placed < target_shifter_pairs:
			continue
		if LevelUtils.shifter_pairs_share_active_cell(shifters):
			continue

		# Parity check: for a balanced solution to exist, every row and every column
		# must have an even number of playable + shifter cells (each line needs equal
		# yellow and blue counts). We accumulate the odd-parity line count for rows
		# (r_sum) and columns (c_sum); they must match for the layout to be viable.
		var r_sum = 0
		var c_sum = 0
		for yy in range(height):
			var p = 0; var s = 0
			for xx in range(width):
				var st = layout.get(Vector2i(xx, yy), -1)
				if st != -2:
					p += 1
					if st == GameConstants.TileState.SHIFTER: s += 1
			r_sum += (p + s) % 2
		for xx in range(width):
			var p = 0; var s = 0
			for yy in range(height):
				var st = layout.get(Vector2i(xx, yy), -1)
				if st != -2:
					p += 1
					if st == GameConstants.TileState.SHIFTER: s += 1
			c_sum += (p + s) % 2

		if r_sum != c_sum:
			continue 

		var iter_tracker = {"count": 0}
		var success = _solve(layout, empty_cells.duplicate(), width, height, solver_tiles, [], iter_tracker)
		if not success: continue 
			
		var solved_layout = layout.duplicate()
		
		var total_jokers_generated = 0
		for c in solved_layout.keys():
			if solved_layout[c] == GameConstants.TileState.JOKER:
				total_jokers_generated += 1

		var all_possible_constraints = []
		for y in range(height):
			for x in range(width):
				var c = Vector2i(x, y)
				if not GameConstants.is_hintable_tile(solved_layout[c]):
					continue
				var right = c + Vector2i(1, 0)
				var down = c + Vector2i(0, 1)

				if solved_layout.has(right) and GameConstants.is_hintable_tile(solved_layout[right]):
					var type_r = "equals" if solved_layout[c] == solved_layout[right] else "not_equals"
					all_possible_constraints.append({"a": c, "b": right, "type": type_r})

				if solved_layout.has(down) and GameConstants.is_hintable_tile(solved_layout[down]):
					var type_d = "equals" if solved_layout[c] == solved_layout[down] else "not_equals"
					all_possible_constraints.append({"a": c, "b": down, "type": type_d})

		for pair in shifters:
			layout[pair.inactive] = -1
			
		var all_filled_cells = []
		var green_cells = []
		var color_cells = [] 
		
		for c in layout.keys():
			if layout[c] >= 0 and layout[c] <= 2: 
				all_filled_cells.append(c)
				if layout[c] == 2:
					green_cells.append(c)
				elif layout[c] == 0 or layout[c] == 1:
					color_cells.append(c)
					
		var clearable_cells = all_filled_cells.duplicate()

		# Always keep at least one joker and one colour tile as visible clues so
		# the player has anchors for both tile types from the start.
		if green_cells.size() > 0:
			green_cells.shuffle()
			clearable_cells.erase(green_cells[0])
			
		if color_cells.size() > 0:
			color_cells.shuffle()
			clearable_cells.erase(color_cells[0])
			
		clearable_cells.shuffle()
		
		var total_filled_count = all_filled_cells.size()
		# Target clearing 67–85 % of the pre-filled cells to leave a partial puzzle.
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
		var count_budget_exhausted := false
		var accepted_punches := 0
		var punches_without_obvious := 0
		
		for c in clearable_cells:
			if cleared_count >= target_to_clear:
				break 
				
			var original_val = layout[c]
			layout[c] = -1
			current_empty.append(c)
			
			var punch_ok := true
			if require_unique:
				# Emptying a locally forced cell cannot add a second solution.
				if not _cell_is_locally_forced(
					c, layout, width, height, solver_tiles, all_possible_constraints
				):
					var sols = _count_solutions(layout, current_empty, width, height, solver_tiles, all_possible_constraints, {"count": 0})
					if sols == SOLUTIONS_UNKNOWN:
						layout[c] = original_val
						current_empty.resize(current_empty.size() - 1)
						count_budget_exhausted = true
						break
					if sols != 1:
						punch_ok = false

			var has_obvious := true
			if punch_ok and punch_difficulty != Difficulty.HARD:
				has_obvious = _has_obvious_move(
					layout, current_empty, width, height, solver_tiles, all_possible_constraints
				)
				if not _punch_accepts_obvious(punch_difficulty, has_obvious, accepted_punches, punches_without_obvious):
					punch_ok = false

			if not punch_ok:
				layout[c] = original_val
				current_empty.resize(current_empty.size() - 1)
			else:
				accepted_punches += 1
				if not has_obvious:
					punches_without_obvious += 1
				cleared_count += 1

		if count_budget_exhausted:
			continue
		if require_unique and min_clear_count > 0 and cleared_count < min_clear_count:
			continue
		if punch_difficulty == Difficulty.EASY and not current_empty.is_empty():
			if not _has_obvious_move(
				layout, current_empty, width, height, solver_tiles, all_possible_constraints
			):
				continue

		var final_constraints = []
		var hidden_hints = []
		
		# Constraint minimisation: iteratively try removing each constraint.
		# If the solution remains unique without it, the constraint becomes a hidden
		# hint (available to the hint system but not shown on the board by default).
		if require_unique:
			var current_constraints = all_possible_constraints.duplicate()
			current_constraints.shuffle()
			
			for i in range(current_constraints.size() - 1, -1, -1):
				var test_constraint = current_constraints[i]
				current_constraints.remove_at(i)
				# Constraint between two given colour tiles cannot affect remaining
				# empty cells, so it is redundant for uniqueness.
				var va := int(layout.get(test_constraint.a, -1))
				var vb := int(layout.get(test_constraint.b, -1))
				var a_given := va >= 0 and va != GameConstants.TileState.SHIFTER
				var b_given := vb >= 0 and vb != GameConstants.TileState.SHIFTER
				if a_given and b_given:
					hidden_hints.append(test_constraint)
					continue
				
				var sols = _count_solutions(layout, current_empty, width, height, solver_tiles, current_constraints, {"count": 0})
				if sols == SOLUTIONS_UNKNOWN or sols != 1:
					current_constraints.insert(i, test_constraint)
				else:
					hidden_hints.append(test_constraint)
					
			final_constraints = current_constraints
		else:
			# Non-unique mode: all constraints become hidden hints since we don't
			# need any to guarantee a unique solution.
			hidden_hints = all_possible_constraints.duplicate()

		# Randomly flip some shifter pairs so the active node is on the "wrong" side.
		# This forces the player to move shifters before placing tiles there.
		# required_shifter_moves tracks how many shifts are needed for metadata.
		# Pairs may share a cell; after flips, reassign so no two share the same active.
		var required_shifter_moves := 0
		for pair in shifters:
			pair["home"] = pair.active
			layout[pair.a] = -1
			layout[pair.b] = -1
			if randi() % 2 == 0:
				var temp = pair.active
				pair.active = pair.inactive
				pair.inactive = temp
		if not _assign_distinct_actives(shifters):
			continue
		for pair in shifters:
			if pair.active != pair.home:
				required_shifter_moves += 1

		var verify_constraints: Array = final_constraints if require_unique else []
		if not require_unique:
			verify_constraints = hidden_hints
		var analysis := PuzzleSolver.analyze(
			layout,
			width,
			height,
			solver_tiles,
			verify_constraints,
			shifters,
			require_unique
		)
		if analysis.get("timed_out", false):
			continue
		if not bool(analysis.get("solvable", false)):
			continue
		if require_unique and not bool(analysis.get("unique", false)):
			continue

		var start_constraints: Array = final_constraints if require_unique else []
		if not PuzzleValidator.starting_layout_is_clean(
			layout, width, height, start_constraints, shifters
		):
			continue

		return {
			"layout": layout,
			"shifters": shifters,
			"constraints": final_constraints,
			"hidden_hints": hidden_hints,
			"total_jokers": total_jokers_generated,
			"required_shifter_moves": required_shifter_moves
		}
		
	if not quiet:
		push_error("Generator failed: Generated walls may be mathematically impossible with the strict parity rules.")
	return {}

# Places a difficulty-scaled number of walls. Interior cells and 2×2 clusters are
# allowed; a row or column is never fully walled. Later attempts use the low end
# of the range so parity-stuck boards can still solve.
static func _place_random_walls(
	layout: Dictionary,
	width: int,
	height: int,
	difficulty: int,
	attempt: int
) -> void:
	if width <= 1 or height <= 1:
		return
	var area := width * height
	var min_frac := 0.12
	var max_frac := 0.24
	match clampi(difficulty, Difficulty.EASY, Difficulty.HARD):
		Difficulty.EASY:
			min_frac = 0.08
			max_frac = 0.18
		Difficulty.HARD:
			min_frac = 0.18
			max_frac = 0.32
		_:
			min_frac = 0.12
			max_frac = 0.24
	var line_cap := mini(width * (height - 1), height * (width - 1))
	var lo := clampi(int(round(float(area) * min_frac)), 1, line_cap)
	var hi := clampi(int(round(float(area) * max_frac)), lo, line_cap)
	if attempt > 1500:
		hi = lo
	var target := randi_range(lo, hi)
	var coords: Array = layout.keys()
	coords.shuffle()
	var row_counts := {}
	var col_counts := {}
	for i in range(height):
		row_counts[i] = 0
	for i in range(width):
		col_counts[i] = 0
	var placed := 0
	for coord in coords:
		if placed >= target:
			break
		if int(layout[coord]) == -2:
			continue
		if int(row_counts[coord.y]) >= width - 1 or int(col_counts[coord.x]) >= height - 1:
			continue
		layout[coord] = -2
		row_counts[coord.y] += 1
		col_counts[coord.x] += 1
		placed += 1

# Returns true if at least one empty cell in the layout has exactly one valid
# tile value, i.e. can be filled by pure logical deduction without guessing.
# Used to gate difficulty: EASY requires an obvious move after every punch.
static func _has_obvious_move(
	layout: Dictionary,
	empty_cells: Array,
	w: int,
	h: int,
	allowed: Array,
	constraints: Array
) -> bool:
	if empty_cells.is_empty():
		return false
	var ctx := _prepare_solver_ctx(layout, w, h, constraints)
	for coord in empty_cells:
		if _fast_option_count(ctx, coord.y * w + coord.x, allowed, true) == 1:
			return true
	return false

# Decides whether a candidate clue-removal (punch) is acceptable for the given
# difficulty. HARD always accepts; EASY rejects any punch that leaves no
# obvious move; MEDIUM allows up to MEDIUM_SKIP_OBVIOUS_FRACTION of punches to
# land without an obvious move, giving a moderate challenge without pure guessing.
static func _punch_keeps_obvious_move(
	difficulty: int,
	layout: Dictionary,
	empty_cells: Array,
	w: int,
	h: int,
	allowed: Array,
	constraints: Array,
	accepted_punches: int,
	punches_without_obvious: int
) -> bool:
	if difficulty == Difficulty.HARD:
		return true
	if empty_cells.is_empty():
		return true
	var has_obvious := _has_obvious_move(layout, empty_cells, w, h, allowed, constraints)
	if difficulty == Difficulty.EASY:
		return has_obvious
	if has_obvious:
		return true
	var next_accepted := accepted_punches + 1
	var next_without := punches_without_obvious + 1
	return float(next_without) / float(maxi(1, next_accepted)) <= MEDIUM_SKIP_OBVIOUS_FRACTION

# Recursive backtracking counter. Returns the number of distinct solutions up
# to max_needed (default 2), so callers only need to know "exactly 1" or ">1".
# Returns SOLUTIONS_UNKNOWN if the iteration budget is exhausted.
# Stores the first found solution in iter["solution"] for later use.
static func _count_solutions(
	layout: Dictionary,
	empty_cells: Array,
	w: int,
	h: int,
	allowed: Array,
	constraints: Array,
	iter: Dictionary
) -> int:
	var ctx := _prepare_solver_ctx(layout, w, h, constraints)
	return _count_solutions_fast(ctx, _empties_to_indices(empty_cells, w), allowed, iter)

# Recursive backtracking solver. Modifies layout in place and returns true
# when a complete valid assignment is found. Uses MRV (Minimum Remaining Values)
# to pick the most constrained empty cell first, reducing the search tree.
# Shuffles value order for randomised generation output.
static func _solve(
	layout: Dictionary,
	empty_cells: Array,
	w: int,
	h: int,
	allowed: Array,
	constraints: Array,
	iter: Dictionary
) -> bool:
	var ctx := _prepare_solver_ctx(layout, w, h, constraints)
	var ok := _solve_fast(ctx, _empties_to_indices(empty_cells, w), allowed, iter)
	if ok:
		_copy_ctx_to_layout(ctx, layout)
	return ok

# Minimum Remaining Values heuristic: finds the empty cell with the fewest
# valid placements. Choosing the most constrained cell first prunes the search
# tree aggressively. Returns an empty dict when any cell has zero options
# (dead end) or when the empty list is exhausted.
static func _pick_mrv_cell(
	layout: Dictionary,
	empty_cells: Array,
	w: int,
	h: int,
	allowed: Array,
	constraints: Array
) -> Dictionary:
	var best_idx := -1
	var min_opts := 999
	var best_valid_vals: Array = []
	for i in range(empty_cells.size()):
		var test_coord: Vector2i = empty_cells[i]
		var valid_vals: Array = []
		for val in allowed:
			if _is_valid_placement(test_coord, val, layout, w, h, constraints):
				valid_vals.append(val)
		var c_opts := valid_vals.size()
		if c_opts == 0:
			return {}
		if c_opts < min_opts:
			min_opts = c_opts
			best_idx = i
			best_valid_vals = valid_vals
			if min_opts <= 1:
				break
	if best_idx < 0:
		return {}
	return {"idx": best_idx, "vals": best_valid_vals}

# Tests whether placing val at coord would violate any game rule.
# Temporarily writes val into the layout so neighbour scans see the full picture,
# then restores the cell to -1 (empty) before returning.
# Checks in order: three-in-a-row horizontally, three-in-a-row vertically,
# row balance (joker quota + equal colour split), column balance, constraints.
# Joker (2) is treated as satisfying either colour for the run check.
static func _is_valid_placement(coord: Vector2i, val: int, layout: Dictionary, w: int, h: int, constraints: Array) -> bool:
	layout[coord] = val 
	
	# Horizontal three-in-a-row check: examine every window of 3 that includes coord.
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
				
	# Vertical three-in-a-row check.
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

	# Row balance check: count playable, shifter, joker, and colour tiles in this row.
	# req_j_row is 1 when the row has an odd number of playable+shifter cells, meaning
	# exactly one joker is required to maintain balance; otherwise 0.
	var p_row = 0; var s_row = 0; var j_row = 0; var empty_row = 0; var b0_row = 0; var b1_row = 0
	for x in range(w):
		var st = layout.get(Vector2i(x, coord.y), -1)
		if st != -2:
			p_row += 1
			if st == -1: empty_row += 1
			elif st == GameConstants.TileState.SHIFTER: s_row += 1
			elif st == 2: j_row += 1
			elif st == 0: b0_row += 1
			elif st == 1: b1_row += 1
			
	var req_j_row = (p_row + s_row) % 2
	
	if j_row > req_j_row: layout[coord] = -1; return false
	if empty_row == 0 and j_row != req_j_row: layout[coord] = -1; return false
		
	var target_0_row = int((p_row - req_j_row - s_row) / 2.0)
	if b0_row > target_0_row or b1_row > target_0_row: layout[coord] = -1; return false
		
	# Column balance check — same logic as the row check above.
	var p_col = 0; var s_col = 0; var j_col = 0; var empty_col = 0; var b0_col = 0; var b1_col = 0
	for y in range(h):
		var st = layout.get(Vector2i(coord.x, y), -1)
		if st != -2:
			p_col += 1
			if st == -1: empty_col += 1
			elif st == GameConstants.TileState.SHIFTER: s_col += 1
			elif st == 2: j_col += 1
			elif st == 0: b0_col += 1
			elif st == 1: b1_col += 1
			
	var req_j_col = (p_col + s_col) % 2
	
	if j_col > req_j_col: layout[coord] = -1; return false
	if empty_col == 0 and j_col != req_j_col: layout[coord] = -1; return false
		
	var target_0_col = int((p_col - req_j_col - s_col) / 2.0)
	if b0_col > target_0_col or b1_col > target_0_col: layout[coord] = -1; return false

	for c in constraints:
		if c.a == coord or c.b == coord:
			var other_coord = c.b if c.a == coord else c.a
			var other_val = layout.get(other_coord, -1)
			if other_val < 0:
				continue
			if val == GameConstants.TileState.JOKER or other_val == GameConstants.TileState.JOKER:
				continue
			if c.type == "equals" and val != other_val:
				layout[coord] = -1
				return false
			if c.type == "not_equals" and val == other_val:
				layout[coord] = -1
				return false

	layout[coord] = -1 
	return true

# True when this empty cell has exactly one legal colour under current clues.
# Punching a locally forced cell cannot introduce a second solution.
static func _cell_is_locally_forced(
	coord: Vector2i,
	layout: Dictionary,
	w: int,
	h: int,
	allowed: Array,
	constraints: Array
) -> bool:
	var ctx := _prepare_solver_ctx(layout, w, h, constraints)
	return _fast_option_count(ctx, coord.y * w + coord.x, allowed, true) == 1


# Difficulty gate using a precomputed obvious-move flag so the punch loop
# does not scan the board twice.
static func _punch_accepts_obvious(
	difficulty: int,
	has_obvious: bool,
	accepted_punches: int,
	punches_without_obvious: int
) -> bool:
	if difficulty == Difficulty.HARD:
		return true
	if difficulty == Difficulty.EASY:
		return has_obvious
	if has_obvious:
		return true
	var next_accepted := accepted_punches + 1
	var next_without := punches_without_obvious + 1
	return float(next_without) / float(maxi(1, next_accepted)) <= MEDIUM_SKIP_OBVIOUS_FRACTION


# Flat-grid solver state. Arrays are stored by reference in this dict so the
# recursive search can place/unplace without Dictionary[Vector2i] lookups.
static func _prepare_solver_ctx(layout: Dictionary, w: int, h: int, constraints: Array) -> Dictionary:
	var n := w * h
	var grid: Array = []
	grid.resize(n)
	var row_p: Array = []
	var row_s: Array = []
	var row_j: Array = []
	var row_empty: Array = []
	var row_b0: Array = []
	var row_b1: Array = []
	row_p.resize(h)
	row_s.resize(h)
	row_j.resize(h)
	row_empty.resize(h)
	row_b0.resize(h)
	row_b1.resize(h)
	var col_p: Array = []
	var col_s: Array = []
	var col_j: Array = []
	var col_empty: Array = []
	var col_b0: Array = []
	var col_b1: Array = []
	col_p.resize(w)
	col_s.resize(w)
	col_j.resize(w)
	col_empty.resize(w)
	col_b0.resize(w)
	col_b1.resize(w)
	for y in range(h):
		row_p[y] = 0
		row_s[y] = 0
		row_j[y] = 0
		row_empty[y] = 0
		row_b0[y] = 0
		row_b1[y] = 0
	for x in range(w):
		col_p[x] = 0
		col_s[x] = 0
		col_j[x] = 0
		col_empty[x] = 0
		col_b0[x] = 0
		col_b1[x] = 0
	for y in range(h):
		for x in range(w):
			var st := int(layout.get(Vector2i(x, y), GameConstants.TileState.EMPTY))
			var idx := y * w + x
			grid[idx] = st
			if st == GameConstants.TileState.WALL:
				continue
			row_p[y] += 1
			col_p[x] += 1
			if st == GameConstants.TileState.EMPTY:
				row_empty[y] += 1
				col_empty[x] += 1
			elif st == GameConstants.TileState.SHIFTER:
				row_s[y] += 1
				col_s[x] += 1
			elif st == GameConstants.TileState.JOKER:
				row_j[y] += 1
				col_j[x] += 1
			elif st == GameConstants.TileState.YELLOW:
				row_b0[y] += 1
				col_b0[x] += 1
			elif st == GameConstants.TileState.BLUE:
				row_b1[y] += 1
				col_b1[x] += 1
	var cons: Array = []
	var cons_at: Array = []
	cons_at.resize(n)
	for i in range(n):
		cons_at[i] = []
	for raw in constraints:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		if not raw.has("a") or not raw.has("b"):
			continue
		var cell_a: Vector2i = raw["a"]
		var cell_b: Vector2i = raw["b"]
		if cell_a.x < 0 or cell_a.y < 0 or cell_b.x < 0 or cell_b.y < 0:
			continue
		if cell_a.x >= w or cell_a.y >= h or cell_b.x >= w or cell_b.y >= h:
			continue
		var ai := cell_a.y * w + cell_a.x
		var bi := cell_b.y * w + cell_b.x
		var eq := String(raw.get("type", "")) == "equals"
		var ci := cons.size()
		cons.append({"ai": ai, "bi": bi, "eq": eq})
		cons_at[ai].append(ci)
		cons_at[bi].append(ci)
	return {
		"grid": grid,
		"w": w,
		"h": h,
		"row_p": row_p,
		"row_s": row_s,
		"row_j": row_j,
		"row_empty": row_empty,
		"row_b0": row_b0,
		"row_b1": row_b1,
		"col_p": col_p,
		"col_s": col_s,
		"col_j": col_j,
		"col_empty": col_empty,
		"col_b0": col_b0,
		"col_b1": col_b1,
		"cons": cons,
		"cons_at": cons_at,
	}


## Materializes a coord→state dictionary from the fast solver's flat grid.
static func _layout_from_ctx(ctx: Dictionary) -> Dictionary:
	var layout := {}
	var w: int = int(ctx.w)
	var h: int = int(ctx.h)
	var grid: Array = ctx.grid
	for y in range(h):
		for x in range(w):
			layout[Vector2i(x, y)] = int(grid[y * w + x])
	return layout


## Writes the fast solver grid back into an existing layout dictionary.
static func _copy_ctx_to_layout(ctx: Dictionary, layout: Dictionary) -> void:
	var w: int = int(ctx.w)
	var h: int = int(ctx.h)
	var grid: Array = ctx.grid
	for y in range(h):
		for x in range(w):
			layout[Vector2i(x, y)] = int(grid[y * w + x])


## Converts empty Vector2i cells to flat indices (y * width + x).
static func _empties_to_indices(empty_cells: Array, w: int) -> Array:
	var idxs: Array = []
	idxs.resize(empty_cells.size())
	for i in range(empty_cells.size()):
		var coord: Vector2i = empty_cells[i]
		idxs[i] = coord.y * w + coord.x
	return idxs


## Adds delta to a per-row/col count array stored on the fast-solver context.
static func _ctx_add(ctx: Dictionary, key: String, i: int, delta: int) -> void:
	var arr: Array = ctx[key]
	arr[i] = int(arr[i]) + delta
	ctx[key] = arr


## Writes a tile into the flat grid and updates row/col occupancy counts.
static func _place_fast(ctx: Dictionary, idx: int, val: int) -> void:
	var w: int = int(ctx.w)
	var x: int = idx % w
	var y: int = int(idx / float(w))
	var grid: Array = ctx.grid
	grid[idx] = val
	ctx.grid = grid
	_ctx_add(ctx, "row_empty", y, -1)
	_ctx_add(ctx, "col_empty", x, -1)
	if val == GameConstants.TileState.JOKER:
		_ctx_add(ctx, "row_j", y, 1)
		_ctx_add(ctx, "col_j", x, 1)
	elif val == GameConstants.TileState.YELLOW:
		_ctx_add(ctx, "row_b0", y, 1)
		_ctx_add(ctx, "col_b0", x, 1)
	elif val == GameConstants.TileState.BLUE:
		_ctx_add(ctx, "row_b1", y, 1)
		_ctx_add(ctx, "col_b1", x, 1)
	elif val == GameConstants.TileState.SHIFTER:
		_ctx_add(ctx, "row_s", y, 1)
		_ctx_add(ctx, "col_s", x, 1)


## Clears a flat-grid cell and rolls back the occupancy counts.
static func _unplace_fast(ctx: Dictionary, idx: int) -> void:
	var w: int = int(ctx.w)
	var x: int = idx % w
	var y: int = int(idx / float(w))
	var grid: Array = ctx.grid
	var val: int = int(grid[idx])
	grid[idx] = GameConstants.TileState.EMPTY
	ctx.grid = grid
	_ctx_add(ctx, "row_empty", y, 1)
	_ctx_add(ctx, "col_empty", x, 1)
	if val == GameConstants.TileState.JOKER:
		_ctx_add(ctx, "row_j", y, -1)
		_ctx_add(ctx, "col_j", x, -1)
	elif val == GameConstants.TileState.YELLOW:
		_ctx_add(ctx, "row_b0", y, -1)
		_ctx_add(ctx, "col_b0", x, -1)
	elif val == GameConstants.TileState.BLUE:
		_ctx_add(ctx, "row_b1", y, -1)
		_ctx_add(ctx, "col_b1", x, -1)
	elif val == GameConstants.TileState.SHIFTER:
		_ctx_add(ctx, "row_s", y, -1)
		_ctx_add(ctx, "col_s", x, -1)


## How many allowed values still fit this empty index (optional shifter skip).
static func _fast_option_count(ctx: Dictionary, idx: int, allowed: Array, skip_shifter: bool) -> int:
	var options := 0
	for val in allowed:
		if skip_shifter and int(val) == GameConstants.TileState.SHIFTER:
			continue
		if _fast_valid(ctx, idx, int(val)):
			options += 1
			if options > 1:
				return options
	return options


# Same rules as _is_valid_placement, using flat grid + incremental line stats.
static func _fast_valid(ctx: Dictionary, idx: int, val: int) -> bool:
	var w: int = int(ctx.w)
	var h: int = int(ctx.h)
	var x: int = idx % w
	var y: int = int(idx / float(w))
	var grid: Array = ctx.grid

	for sx in range(maxi(0, x - 2), mini(w - 2, x + 1)):
		var i1: int = y * w + sx
		var v1: int = val if i1 == idx else int(grid[i1])
		var v2: int = val if i1 + 1 == idx else int(grid[i1 + 1])
		var v3: int = val if i1 + 2 == idx else int(grid[i1 + 2])
		if v1 >= 0 and v2 >= 0 and v3 >= 0 and v1 != -2 and v2 != -2 and v3 != -2:
			var is_zero := (v1 == 0 or v1 == 2) and (v2 == 0 or v2 == 2) and (v3 == 0 or v3 == 2)
			var is_one := (v1 == 1 or v1 == 2) and (v2 == 1 or v2 == 2) and (v3 == 1 or v3 == 2)
			if is_zero or is_one:
				return false

	for sy in range(maxi(0, y - 2), mini(h - 2, y + 1)):
		var i1v: int = sy * w + x
		var vv1: int = val if i1v == idx else int(grid[i1v])
		var vv2: int = val if i1v + w == idx else int(grid[i1v + w])
		var vv3: int = val if i1v + w * 2 == idx else int(grid[i1v + w * 2])
		if vv1 >= 0 and vv2 >= 0 and vv3 >= 0 and vv1 != -2 and vv2 != -2 and vv3 != -2:
			var is_zero_v := (vv1 == 0 or vv1 == 2) and (vv2 == 0 or vv2 == 2) and (vv3 == 0 or vv3 == 2)
			var is_one_v := (vv1 == 1 or vv1 == 2) and (vv2 == 1 or vv2 == 2) and (vv3 == 1 or vv3 == 2)
			if is_zero_v or is_one_v:
				return false

	var s_row: int = int(ctx.row_s[y])
	var s_col: int = int(ctx.col_s[x])
	if val == GameConstants.TileState.SHIFTER:
		s_row += 1
		s_col += 1
	var empty_row: int = int(ctx.row_empty[y]) - 1
	var j_row: int = int(ctx.row_j[y])
	var b0_row: int = int(ctx.row_b0[y])
	var b1_row: int = int(ctx.row_b1[y])
	if val == GameConstants.TileState.JOKER:
		j_row += 1
	elif val == GameConstants.TileState.YELLOW:
		b0_row += 1
	elif val == GameConstants.TileState.BLUE:
		b1_row += 1
	var p_row: int = int(ctx.row_p[y])
	var req_j_row: int = (p_row + s_row) % 2
	if j_row > req_j_row:
		return false
	if empty_row == 0 and j_row != req_j_row:
		return false
	var target_0_row: int = int((p_row - req_j_row - s_row) / 2.0)
	if b0_row > target_0_row or b1_row > target_0_row:
		return false

	var empty_col: int = int(ctx.col_empty[x]) - 1
	var j_col: int = int(ctx.col_j[x])
	var b0_col: int = int(ctx.col_b0[x])
	var b1_col: int = int(ctx.col_b1[x])
	if val == GameConstants.TileState.JOKER:
		j_col += 1
	elif val == GameConstants.TileState.YELLOW:
		b0_col += 1
	elif val == GameConstants.TileState.BLUE:
		b1_col += 1
	var p_col: int = int(ctx.col_p[x])
	var req_j_col: int = (p_col + s_col) % 2
	if j_col > req_j_col:
		return false
	if empty_col == 0 and j_col != req_j_col:
		return false
	var target_0_col: int = int((p_col - req_j_col - s_col) / 2.0)
	if b0_col > target_0_col or b1_col > target_0_col:
		return false

	var cons: Array = ctx.cons
	for ci in ctx.cons_at[idx]:
		var c: Dictionary = cons[ci]
		var other: int = int(c.bi) if int(c.ai) == idx else int(c.ai)
		var other_val: int = int(grid[other])
		if other_val < 0:
			continue
		if val == GameConstants.TileState.JOKER or other_val == GameConstants.TileState.JOKER:
			continue
		if bool(c.eq) and val != other_val:
			return false
		if not bool(c.eq) and val == other_val:
			return false
	return true


## Minimum-remaining-values pick among empty indices for the fast solver.
static func _pick_mrv_fast(ctx: Dictionary, empty_cells: Array, allowed: Array) -> Dictionary:
	var best_idx := -1
	var min_opts := 999
	var best_valid_vals: Array = []
	for i in range(empty_cells.size()):
		var test_idx: int = empty_cells[i]
		var valid_vals: Array = []
		for val in allowed:
			if _fast_valid(ctx, test_idx, int(val)):
				valid_vals.append(int(val))
		var c_opts := valid_vals.size()
		if c_opts == 0:
			return {}
		if c_opts < min_opts:
			min_opts = c_opts
			best_idx = i
			best_valid_vals = valid_vals
			if min_opts <= 1:
				break
	if best_idx < 0:
		return {}
	return {"idx": best_idx, "vals": best_valid_vals}


## Counts solutions on the flat grid until two are found or the budget expires.
static func _count_solutions_fast(ctx: Dictionary, empty_cells: Array, allowed: Array, iter: Dictionary) -> int:
	if empty_cells.size() == 0:
		if not iter.has("solution"):
			iter["solution"] = _layout_from_ctx(ctx)
		return 1
	iter.count += 1
	var budget: int = int(iter.get("budget", COUNT_ITER_BUDGET))
	if iter.count > budget:
		return SOLUTIONS_UNKNOWN

	var pick := _pick_mrv_fast(ctx, empty_cells, allowed)
	if pick.is_empty():
		return 0
	var best_idx: int = pick["idx"]
	var best_valid_vals: Array = pick["vals"]
	var best_cell: int = empty_cells[best_idx]
	empty_cells.remove_at(best_idx)

	var total_sols := 0
	for val in best_valid_vals:
		_place_fast(ctx, best_cell, int(val))
		var branch := _count_solutions_fast(ctx, empty_cells, allowed, iter)
		_unplace_fast(ctx, best_cell)
		if branch == SOLUTIONS_UNKNOWN:
			empty_cells.insert(best_idx, best_cell)
			return SOLUTIONS_UNKNOWN
		total_sols += branch
		var max_needed: int = int(iter.get("max_needed", 2))
		if total_sols >= max_needed:
			break

	empty_cells.insert(best_idx, best_cell)
	return total_sols


## Finds one solution on the flat grid; false when the iteration budget is hit.
static func _solve_fast(ctx: Dictionary, empty_cells: Array, allowed: Array, iter: Dictionary) -> bool:
	if empty_cells.size() == 0:
		return true
	iter.count += 1
	var budget: int = int(iter.get("budget", SOLVE_ITER_BUDGET))
	if iter.count > budget:
		return false

	var pick := _pick_mrv_fast(ctx, empty_cells, allowed)
	if pick.is_empty():
		return false
	var best_idx: int = pick["idx"]
	var best_valid_vals: Array = pick["vals"]
	var best_cell: int = empty_cells[best_idx]
	empty_cells.remove_at(best_idx)
	best_valid_vals.shuffle()

	for val in best_valid_vals:
		_place_fast(ctx, best_cell, int(val))
		if _solve_fast(ctx, empty_cells, allowed, iter):
			return true
		_unplace_fast(ctx, best_cell)

	empty_cells.insert(best_idx, best_cell)
	return false


## True when a shifter pair already uses these two cells (order-insensitive).
static func _pair_already_exists(shifters: Array, a: Vector2i, b: Vector2i) -> bool:
	for p in shifters:
		if (p.a == a and p.b == b) or (p.a == b and p.b == a):
			return true
	return false

## Random unused endpoint for a new shifter, or null if both are taken.
static func _pick_unused_active(a: Vector2i, b: Vector2i, used_actives: Dictionary) -> Variant:
	var first: Vector2i = a if randi() % 2 == 0 else b
	var second: Vector2i = b if first == a else a
	if not used_actives.has(first):
		return first
	if not used_actives.has(second):
		return second
	return null

## Each pair picks one of its two cells as active; all actives must be unique.
## Prefers the current (post-flip) active when that still works.
static func _assign_distinct_actives(shifters: Array) -> bool:
	return _assign_distinct_actives_at(shifters, 0, {})

## Backtracking pass so each shifter's active cell is unique.
static func _assign_distinct_actives_at(shifters: Array, index: int, used: Dictionary) -> bool:
	if index >= shifters.size():
		return true
	var pair = shifters[index]
	var choices: Array = [pair.active, pair.inactive]
	for cell in choices:
		if used.has(cell):
			continue
		used[cell] = true
		var old_active = pair.active
		var old_inactive = pair.inactive
		pair.active = cell
		pair.inactive = old_inactive if cell == old_active else old_active
		if _assign_distinct_actives_at(shifters, index + 1, used):
			return true
		pair.active = old_active
		pair.inactive = old_inactive
		used.erase(cell)
	return false
