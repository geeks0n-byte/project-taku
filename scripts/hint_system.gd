class_name HintSystem
extends RefCounted

static func count_usable_hints(
	board_cells: Dictionary,
	active_constraints: Array,
	solved_reference: Dictionary,
	hidden_reference_constraints: Array = [],
	grid_size: Vector2i = Vector2i.ZERO
) -> int:
	var count := 0
	if not solved_reference.is_empty():
		var size := grid_size
		if size == Vector2i.ZERO:
			size = LevelUtils.get_dimensions_from_cells(board_cells)
		for y in range(size.y):
			for x in range(size.x):
				var coord := Vector2i(x, y)
				var right := coord + Vector2i(1, 0)
				var down := coord + Vector2i(0, 1)
				if is_hint_usable(board_cells, active_constraints, solved_reference, coord, right):
					count += 1
				if is_hint_usable(board_cells, active_constraints, solved_reference, coord, down):
					count += 1

	for hidden in hidden_reference_constraints:
		if not LevelUtils.is_constraint_in_list(hidden["a"], hidden["b"], active_constraints):
			count += 1
	return count

static func is_hint_usable(
	board_cells: Dictionary,
	active_constraints: Array,
	solved_reference: Dictionary,
	coord_a: Vector2i,
	coord_b: Vector2i
) -> bool:
	if not solved_reference.has(coord_a) or not solved_reference.has(coord_b):
		return false

	var cell_a = board_cells.get(coord_a)
	var cell_b = board_cells.get(coord_b)
	if not cell_a or not cell_b:
		return false
	if cell_a.state == GameConstants.TileState.WALL or cell_b.state == GameConstants.TileState.WALL:
		return false

	var sol_a = solved_reference[coord_a]
	var sol_b = solved_reference[coord_b]
	if sol_a == GameConstants.TileState.WALL or sol_b == GameConstants.TileState.WALL:
		return false
	if not GameConstants.is_solvable_tile(sol_a) or not GameConstants.is_solvable_tile(sol_b):
		return false

	if LevelUtils.is_constraint_in_list(coord_a, coord_b, active_constraints):
		return false

	var a_empty := cell_a.state == GameConstants.TileState.EMPTY
	var b_empty := cell_b.state == GameConstants.TileState.EMPTY
	if not a_empty and not b_empty:
		return false
	return true

static func pick_hint(
	board_cells: Dictionary,
	active_constraints: Array,
	solved_reference: Dictionary,
	hidden_reference_constraints: Array = [],
	grid_size: Vector2i = Vector2i.ZERO,
	use_advanced_priorities: bool = true
) -> Variant:
	if solved_reference.is_empty():
		return null

	var size := grid_size
	if size == Vector2i.ZERO:
		size = LevelUtils.get_dimensions_from_cells(board_cells)

	var priority_1: Array = []
	var priority_2: Array = []
	var priority_3: Array = []
	var priority_4: Array = []

	for y in range(size.y):
		for x in range(size.x):
			var coord := Vector2i(x, y)
			var right := coord + Vector2i(1, 0)
			var down := coord + Vector2i(0, 1)
			if use_advanced_priorities:
				_evaluate_advanced_candidate(
					board_cells, active_constraints, solved_reference,
					coord, right, priority_1, priority_2, priority_3, priority_4
				)
				_evaluate_advanced_candidate(
					board_cells, active_constraints, solved_reference,
					coord, down, priority_1, priority_2, priority_3, priority_4
				)
			else:
				_evaluate_simple_candidate(
					board_cells, active_constraints, solved_reference,
					coord, right, priority_1, priority_2, priority_3
				)
				_evaluate_simple_candidate(
					board_cells, active_constraints, solved_reference,
					coord, down, priority_1, priority_2, priority_3
				)

	if priority_1.size() > 0:
		return priority_1.pick_random()
	if priority_2.size() > 0:
		return priority_2.pick_random()
	if priority_3.size() > 0:
		return priority_3.pick_random()
	if use_advanced_priorities and priority_4.size() > 0:
		return priority_4.pick_random()
	return _get_fallback_hint(board_cells, active_constraints, solved_reference, hidden_reference_constraints, size)

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

static func _evaluate_simple_candidate(
	board_cells: Dictionary,
	active_constraints: Array,
	solved_reference: Dictionary,
	coord_a: Vector2i,
	coord_b: Vector2i,
	p1: Array,
	p2: Array,
	p3: Array
) -> void:
	if not solved_reference.has(coord_a) or not solved_reference.has(coord_b):
		return

	var sol_a = solved_reference[coord_a]
	var sol_b = solved_reference[coord_b]
	if not GameConstants.is_basic_tile(sol_a) or not GameConstants.is_basic_tile(sol_b):
		return

	if LevelUtils.is_constraint_in_list(coord_a, coord_b, active_constraints):
		return

	var type := "equals" if sol_a == sol_b else "not_equals"
	var candidate := {"a": coord_a, "b": coord_b, "type": type}

	var state_a = board_cells[coord_a].state
	var state_b = board_cells[coord_b].state
	var a_filled := GameConstants.is_basic_tile(state_a)
	var b_filled := GameConstants.is_basic_tile(state_b)
	var a_empty := state_a == GameConstants.TileState.EMPTY
	var b_empty := state_b == GameConstants.TileState.EMPTY

	if (state_a != GameConstants.TileState.EMPTY and not a_filled) or (state_b != GameConstants.TileState.EMPTY and not b_filled):
		p3.append(candidate)
		return

	if (a_filled and b_empty) or (b_filled and a_empty):
		p1.append(candidate)
	elif a_empty and b_empty:
		p2.append(candidate)
	elif a_filled and b_filled:
		var satisfied := (type == "equals" and state_a == state_b) or (type == "not_equals" and state_a != state_b)
		if not satisfied:
			p3.append(candidate)

static func _evaluate_advanced_candidate(
	board_cells: Dictionary,
	active_constraints: Array,
	solved_reference: Dictionary,
	coord_a: Vector2i,
	coord_b: Vector2i,
	p1: Array,
	p2: Array,
	p3: Array,
	p4: Array
) -> void:
	if not is_hint_usable(board_cells, active_constraints, solved_reference, coord_a, coord_b):
		return

	var cell_a = board_cells[coord_a]
	var cell_b = board_cells[coord_b]
	var sol_a = solved_reference[coord_a]
	var sol_b = solved_reference[coord_b]
	var type := "equals" if sol_a == sol_b else "not_equals"
	var candidate := {"a": coord_a, "b": coord_b, "type": type}

	var a_empty := cell_a.state == GameConstants.TileState.EMPTY
	var b_empty := cell_b.state == GameConstants.TileState.EMPTY
	var a_fixed := cell_a.is_locked
	var b_fixed := cell_b.is_locked
	var a_correct := cell_a.state == sol_a and not a_empty
	var b_correct := cell_b.state == sol_b and not b_empty
	var a_has_fixed := a_empty and _cell_has_contraction_to_fixed(coord_a, active_constraints, board_cells)
	var b_has_fixed := b_empty and _cell_has_contraction_to_fixed(coord_b, active_constraints, board_cells)

	if (a_empty and b_fixed and not a_has_fixed) or (b_empty and a_fixed and not b_has_fixed):
		p1.append(candidate)
	elif (a_empty and b_correct) or (b_empty and a_correct):
		p2.append(candidate)
	elif a_empty and b_empty:
		p3.append(candidate)
	elif a_empty or b_empty:
		p4.append(candidate)

static func _cell_has_contraction_to_fixed(
	coord: Vector2i,
	constraints: Array,
	cells_dict: Dictionary
) -> bool:
	for constraint in constraints:
		var other_coord := Vector2i(-1, -1)
		if constraint["a"] == coord:
			other_coord = constraint["b"]
		elif constraint["b"] == coord:
			other_coord = constraint["a"]
		if other_coord != Vector2i(-1, -1) and cells_dict.has(other_coord):
			if cells_dict[other_coord].is_locked:
				return true
	return false

static func _get_fallback_hint(
	board_cells: Dictionary,
	active_constraints: Array,
	solved_reference: Dictionary,
	hidden_reference_constraints: Array,
	grid_size: Vector2i
) -> Variant:
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			for offset in [Vector2i(1, 0), Vector2i(0, 1)]:
				var c1 := Vector2i(x, y)
				var c2 := c1 + offset
				if not solved_reference.has(c1) or not solved_reference.has(c2):
					continue
				var cell_1 = board_cells.get(c1)
				var cell_2 = board_cells.get(c2)
				if not cell_1 or not cell_2:
					continue
				if cell_1.state == GameConstants.TileState.WALL or cell_2.state == GameConstants.TileState.WALL:
					continue
				if cell_1.state != GameConstants.TileState.EMPTY and cell_2.state != GameConstants.TileState.EMPTY:
					continue
				if LevelUtils.is_constraint_in_list(c1, c2, active_constraints):
					continue
				var s1 = solved_reference[c1]
				var s2 = solved_reference[c2]
				if GameConstants.is_solvable_tile(s1) and GameConstants.is_solvable_tile(s2):
					var hint_type := "equals" if s1 == s2 else "not_equals"
					return {"a": c1, "b": c2, "type": hint_type}

	for hidden in hidden_reference_constraints:
		if not LevelUtils.is_constraint_in_list(hidden["a"], hidden["b"], active_constraints):
			return hidden
	return null

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

	var hidden: Array = []
	for y in range(height):
		for x in range(width):
			var coord := Vector2i(x, y)
			if not solved.has(coord) or not GameConstants.is_basic_tile(solved[coord]):
				continue
			for offset in [Vector2i(1, 0), Vector2i(0, 1)]:
				var neighbor := coord + offset
				if not solved.has(neighbor) or not GameConstants.is_basic_tile(solved[neighbor]):
					continue
				var hint_type := "equals" if solved[coord] == solved[neighbor] else "not_equals"
				if not LevelUtils.is_constraint_in_list(coord, neighbor, active_constraints):
					hidden.append({"a": coord, "b": neighbor, "type": hint_type})
	return hidden
