class_name HintSystem
extends RefCounted

## Hint contractions between two adjacent playable cells.
## Priority (highest first):
## 1) involves a fixed (locked) cell
## 2) involves a correctly filled cell
## 3) involves a cell that already has a hint
## 4) both cells empty
## Never links a wall. Type always matches the solved reference so the puzzle stays solvable.
## Contraction tiles: Yellow, Blue, Green, Purple (shifter).

static func count_usable_hints(
	board_cells: Dictionary,
	active_constraints: Array,
	solved_reference: Dictionary,
	hidden_reference_constraints: Array = [],
	grid_size: Vector2i = Vector2i.ZERO,
	prefer_hidden_pool: bool = false
) -> int:
	return _collect_candidates(
		board_cells,
		active_constraints,
		solved_reference,
		hidden_reference_constraints,
		grid_size,
		prefer_hidden_pool
	).size()

static func pick_hint(
	board_cells: Dictionary,
	active_constraints: Array,
	solved_reference: Dictionary,
	hidden_reference_constraints: Array = [],
	grid_size: Vector2i = Vector2i.ZERO,
	prefer_hidden_pool: bool = false
) -> Variant:
	var candidates: Array = _collect_candidates(
		board_cells,
		active_constraints,
		solved_reference,
		hidden_reference_constraints,
		grid_size,
		prefer_hidden_pool
	)
	return _pick_by_priority(board_cells, active_constraints, solved_reference, candidates, prefer_hidden_pool)

static func attempt_dynamic_solve(
	board_cells: Dictionary,
	active_constraints: Array,
	tiles_list: Array
) -> Dictionary:
	var built := LevelUtils.build_solve_layout(board_cells)
	var size := LevelUtils.get_dimensions_from_cells(board_cells)
	return LevelUtils.solve_reference(
		built["layout"],
		built["empty_cells"],
		size.x,
		size.y,
		tiles_list,
		active_constraints
	)

static func rebuild_hidden_hints(
	board_cells: Dictionary,
	active_constraints: Array,
	width: int,
	height: int,
	tiles: Array
) -> Array:
	var built := LevelUtils.build_solve_layout(board_cells)
	var solved := LevelUtils.solve_reference(
		built["layout"],
		built["empty_cells"],
		width,
		height,
		tiles,
		active_constraints
	)
	if solved.is_empty():
		return []
	return hidden_hints_from_solved(solved, active_constraints, width, height)

static func hidden_hints_from_solved(
	solved: Dictionary,
	active_constraints: Array,
	width: int,
	height: int
) -> Array:
	var hidden: Array = []
	if solved.is_empty():
		return hidden
	for y in range(height):
		for x in range(width):
			var coord := Vector2i(x, y)
			if not solved.has(coord) or not GameConstants.is_hintable_tile(solved[coord]):
				continue
			for offset in [Vector2i(1, 0), Vector2i(0, 1)]:
				var neighbor: Vector2i = coord + offset
				if not solved.has(neighbor) or not GameConstants.is_hintable_tile(solved[neighbor]):
					continue
				var hint_type := "equals" if solved[coord] == solved[neighbor] else "not_equals"
				if not LevelUtils.is_constraint_in_list(coord, neighbor, active_constraints):
					hidden.append({"a": coord, "b": neighbor, "type": hint_type})
	return hidden

static func _collect_candidates(
	board_cells: Dictionary,
	active_constraints: Array,
	solved_reference: Dictionary,
	hidden_reference_constraints: Array,
	grid_size: Vector2i,
	prefer_hidden_pool: bool
) -> Array:
	var candidates: Array = []
	var seen: Dictionary = {}

	if prefer_hidden_pool:
		for hidden in hidden_reference_constraints:
			var key := _pair_key(hidden["a"], hidden["b"])
			if seen.has(key):
				continue
			if not _is_pool_hint_usable(board_cells, active_constraints, hidden):
				continue
			seen[key] = true
			candidates.append(hidden)
		return candidates

	if solved_reference.is_empty():
		# Fall back to the hidden pool when we have no solved reference yet.
		for hidden in hidden_reference_constraints:
			var key := _pair_key(hidden["a"], hidden["b"])
			if seen.has(key):
				continue
			if not _is_pool_hint_usable(board_cells, active_constraints, hidden):
				continue
			seen[key] = true
			candidates.append(hidden)
		return candidates

	var size := grid_size
	if size == Vector2i.ZERO:
		size = LevelUtils.get_dimensions_from_cells(board_cells)

	for y in range(size.y):
		for x in range(size.x):
			var coord := Vector2i(x, y)
			for offset in [Vector2i(1, 0), Vector2i(0, 1)]:
				var neighbor: Vector2i = coord + offset
				var candidate: Variant = _make_candidate(
					board_cells, active_constraints, solved_reference, coord, neighbor
				)
				if candidate == null:
					continue
				var key := _pair_key(candidate["a"], candidate["b"])
				if seen.has(key):
					continue
				seen[key] = true
				candidates.append(candidate)

	# Solution-consistent extras from the hidden pool as lower-priority fodder.
	for hidden in hidden_reference_constraints:
		var key := _pair_key(hidden["a"], hidden["b"])
		if seen.has(key):
			continue
		if not _is_pool_hint_usable(board_cells, active_constraints, hidden):
			continue
		if not _reference_satisfies(solved_reference, hidden):
			continue
		seen[key] = true
		candidates.append(hidden)

	return candidates

static func _make_candidate(
	board_cells: Dictionary,
	active_constraints: Array,
	solved_reference: Dictionary,
	coord_a: Vector2i,
	coord_b: Vector2i
) -> Variant:
	if not board_cells.has(coord_a) or not board_cells.has(coord_b):
		return null
	if not solved_reference.has(coord_a) or not solved_reference.has(coord_b):
		return null

	var cell_a = board_cells[coord_a]
	var cell_b = board_cells[coord_b]
	if cell_a.state == GameConstants.TileState.WALL or cell_b.state == GameConstants.TileState.WALL:
		return null

	var sol_a = solved_reference[coord_a]
	var sol_b = solved_reference[coord_b]
	if not GameConstants.is_hintable_tile(sol_a) or not GameConstants.is_hintable_tile(sol_b):
		return null

	if LevelUtils.is_constraint_in_list(coord_a, coord_b, active_constraints):
		return null

	var a_empty: bool = cell_a.state == GameConstants.TileState.EMPTY
	var b_empty: bool = cell_b.state == GameConstants.TileState.EMPTY
	# Need at least one empty cell to teach; both filled is not a useful hint.
	if not a_empty and not b_empty:
		return null

	var hint_type := "equals" if sol_a == sol_b else "not_equals"
	return {"a": coord_a, "b": coord_b, "type": hint_type}

static func _is_pool_hint_usable(
	board_cells: Dictionary,
	active_constraints: Array,
	hint: Dictionary
) -> bool:
	if not hint.has("a") or not hint.has("b") or not hint.has("type"):
		return false
	var coord_a: Vector2i = hint["a"]
	var coord_b: Vector2i = hint["b"]
	if not board_cells.has(coord_a) or not board_cells.has(coord_b):
		return false
	var cell_a = board_cells[coord_a]
	var cell_b = board_cells[coord_b]
	if cell_a.state == GameConstants.TileState.WALL or cell_b.state == GameConstants.TileState.WALL:
		return false
	if LevelUtils.is_constraint_in_list(coord_a, coord_b, active_constraints):
		return false
	var a_empty: bool = cell_a.state == GameConstants.TileState.EMPTY
	var b_empty: bool = cell_b.state == GameConstants.TileState.EMPTY
	if not a_empty and not b_empty:
		return false
	return true

static func _reference_satisfies(solved_reference: Dictionary, hint: Dictionary) -> bool:
	if not solved_reference.has(hint["a"]) or not solved_reference.has(hint["b"]):
		return false
	var sol_a = solved_reference[hint["a"]]
	var sol_b = solved_reference[hint["b"]]
	if not GameConstants.is_hintable_tile(sol_a) or not GameConstants.is_hintable_tile(sol_b):
		return false
	if hint["type"] == "equals":
		return sol_a == sol_b
	return sol_a != sol_b

static func _pick_by_priority(
	board_cells: Dictionary,
	active_constraints: Array,
	solved_reference: Dictionary,
	candidates: Array,
	prefer_hidden_pool: bool = false
) -> Variant:
	var priority_1: Array = []
	var priority_2: Array = []
	var priority_3: Array = []
	var priority_4: Array = []

	for candidate in candidates:
		# Pool-only mode trusts the stored contractions; don't reject on a re-solved board.
		if not prefer_hidden_pool and not solved_reference.is_empty() and not _reference_satisfies(solved_reference, candidate):
			continue
		_bucket_candidate(
			board_cells, active_constraints, solved_reference, candidate,
			priority_1, priority_2, priority_3, priority_4
		)

	if priority_1.size() > 0:
		return priority_1.pick_random()
	if priority_2.size() > 0:
		return priority_2.pick_random()
	if priority_3.size() > 0:
		return priority_3.pick_random()
	if priority_4.size() > 0:
		return priority_4.pick_random()
	return null

static func _bucket_candidate(
	board_cells: Dictionary,
	active_constraints: Array,
	solved_reference: Dictionary,
	candidate: Dictionary,
	p1: Array,
	p2: Array,
	p3: Array,
	p4: Array
) -> void:
	var coord_a: Vector2i = candidate["a"]
	var coord_b: Vector2i = candidate["b"]
	var cell_a = board_cells[coord_a]
	var cell_b = board_cells[coord_b]

	var a_empty: bool = cell_a.state == GameConstants.TileState.EMPTY
	var b_empty: bool = cell_b.state == GameConstants.TileState.EMPTY
	var a_fixed: bool = cell_a.is_locked and cell_a.state != GameConstants.TileState.WALL
	var b_fixed: bool = cell_b.is_locked and cell_b.state != GameConstants.TileState.WALL

	var a_correct := false
	var b_correct := false
	if not solved_reference.is_empty():
		if not a_empty and solved_reference.has(coord_a):
			a_correct = cell_a.state == solved_reference[coord_a]
		if not b_empty and solved_reference.has(coord_b):
			b_correct = cell_b.state == solved_reference[coord_b]

	var a_has_hint := _cell_has_any_constraint(coord_a, active_constraints)
	var b_has_hint := _cell_has_any_constraint(coord_b, active_constraints)

	# 1) contraction involving a fixed cell
	if (a_empty and b_fixed) or (b_empty and a_fixed):
		p1.append(candidate)
		return
	# 2) contraction involving a correctly filled cell
	if (a_empty and b_correct) or (b_empty and a_correct):
		p2.append(candidate)
		return
	# 3) contraction involving a cell that already has a hint
	if (a_empty or b_empty) and (a_has_hint or b_has_hint):
		p3.append(candidate)
		return
	# 4) both empty
	if a_empty and b_empty:
		p4.append(candidate)

static func _cell_has_any_constraint(coord: Vector2i, constraints: Array) -> bool:
	for constraint in constraints:
		if constraint["a"] == coord or constraint["b"] == coord:
			return true
	return false

static func _pair_key(a: Vector2i, b: Vector2i) -> String:
	if a.x < b.x or (a.x == b.x and a.y <= b.y):
		return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]
	return "%d,%d|%d,%d" % [b.x, b.y, a.x, a.y]
