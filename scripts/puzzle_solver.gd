class_name PuzzleSolver
extends RefCounted

# Public solver façade. Answers "is this puzzle solvable / unique?" while
# accounting for shifter mobility: each shifter pair can be in one of two
# positions, so the analyser must test all 2^N configurations.
#
# Also the public door for the fast option-count context used by hints, and
# for count/solve used by LevelUtils. Callers should not poke PuzzleGenerator
# privates (_prepare_solver_ctx, _fast_option_count, _count_solutions, _solve).

const SOLUTIONS_UNKNOWN := PuzzleGenerator.SOLUTIONS_UNKNOWN
# Shared iteration budget across all shifter configurations in one analysis call.
const MOBILITY_ITER_BUDGET := 120000
# Cap on the number of shifter pairs enumerated for mobility; beyond this the
# combinatorial explosion makes analysis impractical.
const MAX_SHIFTER_PAIRS_FOR_MOBILITY := 8

# Primary entry point: analyses a raw layout dict. Delegates to the mobility-aware
# variant which iterates over all shifter configurations.
static func analyze(
	layout: Dictionary,
	width: int,
	height: int,
	available_tiles: Array,
	constraints: Array,
	shifter_pairs: Array = [],
	require_unique: bool = true
) -> Dictionary:
	return _analyze_with_shifter_mobility(
		layout, width, height, available_tiles, constraints, shifter_pairs, require_unique
	)

# Convenience overload that accepts the live board_cells dict (as used by
# BoardManager) and converts it to a layout before calling the main analyser.
static func analyze_board_cells(
	board_cells: Dictionary,
	width: int,
	height: int,
	available_tiles: Array,
	constraints: Array,
	shifter_pairs: Array = [],
	require_unique: bool = true
) -> Dictionary:
	var built := LevelUtils.build_solve_layout(board_cells)
	return _analyze_with_shifter_mobility(
		built["layout"],
		width,
		height,
		available_tiles,
		constraints,
		shifter_pairs,
		require_unique
	)

# Convenience overload that unpacks a LevelData resource and calls analyze().
# Defaults to all three tile types when the level has no tile list set.
static func analyze_level(level: LevelData, require_unique: bool = true) -> Dictionary:
	if level == null:
		return _result(0, {}, true)
	var tiles: Array = level.available_tiles if level.available_tiles.size() > 0 else [
		GameConstants.TileState.YELLOW,
		GameConstants.TileState.BLUE,
		GameConstants.TileState.JOKER,
	]
	return analyze(
		level.layout,
		level.width,
		level.height,
		tiles,
		level.constraint_pairs,
		LevelUtils.get_shifter_pairs(level),
		require_unique
	)

# Builds the opaque fast-solver context used by option_count. Callers should
# treat the dict as a black box and only pass it back into option_count.
static func prepare_ctx(
	layout: Dictionary,
	width: int,
	height: int,
	constraints: Array
) -> Dictionary:
	return PuzzleGenerator._prepare_solver_ctx(layout, width, height, constraints)

# Legal tile count at coord on a prepared ctx. Early-exits at 2 because
# callers only need 0 / 1 / many. skip_shifter matches hint scoring (shifters
# are mobility, not a colour the player would place on an empty cell).
static func option_count(
	ctx: Dictionary,
	coord: Vector2i,
	tiles: Array,
	skip_shifter: bool = true
) -> int:
	if ctx.is_empty():
		return 0
	var w := int(ctx.get("w", 0))
	if w <= 0:
		return 0
	return PuzzleGenerator._fast_option_count(ctx, coord.y * w + coord.x, tiles, skip_shifter)

# Counts solutions up to the solver cap (usually 2). Pass an existing tracker
# dict as iter to share a budget across shifter configs. Duplicates layout so
# the fast search cannot leak placements back to the caller.
static func count_solutions(
	layout: Dictionary,
	empty_cells: Array,
	width: int,
	height: int,
	tiles: Array,
	constraints: Array,
	iter: Variant = null
) -> int:
	var test_layout = layout.duplicate()
	var test_empty = empty_cells.duplicate()
	var tracker: Dictionary = iter if typeof(iter) == TYPE_DICTIONARY else {"count": 0}
	if not tracker.has("count"):
		tracker["count"] = 0
	return PuzzleGenerator._count_solutions(
		test_layout, test_empty, width, height, tiles, constraints, tracker
	)

# Returns the first found solution layout, or {} if unsolvable / budget hit.
# Copies the input so the caller's layout is left unchanged.
static func solve_reference(
	layout: Dictionary,
	empty_cells: Array,
	width: int,
	height: int,
	tiles: Array,
	constraints: Array
) -> Dictionary:
	var test_layout = layout.duplicate()
	var test_empty = empty_cells.duplicate()
	if PuzzleGenerator._solve(test_layout, test_empty, width, height, tiles, constraints, {"count": 0}):
		return test_layout
	return {}

# Core analysis loop. Iterates over every combination of shifter positions
# (2^N configs via bitmask), runs the solution counter for each, and
# accumulates the total. A shared iteration budget prevents runaway search.
# Uniqueness is determined across all configurations combined: if any two
# configs together yield more than one solution the puzzle is not unique.
static func _analyze_with_shifter_mobility(
	layout: Dictionary,
	width: int,
	height: int,
	available_tiles: Array,
	constraints: Array,
	shifter_pairs: Array,
	require_unique: bool
) -> Dictionary:
	var tiles := _normalize_tiles(available_tiles)
	var pairs := _normalized_shifter_pairs(shifter_pairs)
	if pairs.size() > MAX_SHIFTER_PAIRS_FOR_MOBILITY:
		pairs = pairs.slice(0, MAX_SHIFTER_PAIRS_FOR_MOBILITY)
	var base := _layout_with_pair_cells_cleared(layout, pairs)
	var shared_iter := {
		"count": 0,
		"budget": MOBILITY_ITER_BUDGET,
		"max_needed": 1 if not require_unique else 2,
	}

	if pairs.is_empty():
		return _analyze_prepared(
			base,
			LevelUtils.empty_cells_from_layout(base),
			width,
			height,
			tiles,
			constraints,
			shared_iter
		)

	var total := 0
	var timed_out := false
	var first_solution: Dictionary = {}
	# Each bit in mask represents one shifter pair's position (0 = A side, 1 = B side).
	var config_count := 1 << pairs.size()
	for mask in range(config_count):
		if int(shared_iter["count"]) > MOBILITY_ITER_BUDGET:
			timed_out = true
			break
		var configured := base.duplicate()
		for i in range(pairs.size()):
			var pair: Dictionary = pairs[i]
			var cell_a: Vector2i = pair["a"]
			var cell_b: Vector2i = pair["b"]
			var shifter_on_a := (mask & (1 << i)) == 0
			var home: Vector2i = cell_a if shifter_on_a else cell_b
			var other: Vector2i = cell_b if shifter_on_a else cell_a
			if configured.has(home):
				configured[home] = GameConstants.TileState.SHIFTER
			if configured.has(other):
				configured[other] = GameConstants.TileState.EMPTY

		var empties := LevelUtils.empty_cells_from_layout(configured)
		var branch := PuzzleSolver.count_solutions(
			configured, empties, width, height, tiles, constraints, shared_iter
		)
		if branch == SOLUTIONS_UNKNOWN:
			timed_out = true
			break
		if branch >= 1 and first_solution.is_empty() and shared_iter.has("solution"):
			first_solution = shared_iter["solution"]
		total += branch
		if not require_unique and total >= 1:
			break
		if total > 1:
			total = 2
			break

	if timed_out and total < 1:
		return _result(SOLUTIONS_UNKNOWN, first_solution, true)
	if timed_out and require_unique and total == 1:
		return _result(SOLUTIONS_UNKNOWN, first_solution, true)
	return _result(total, first_solution, false)

# Runs the solution count on a layout that has already been prepared (empty cells
# extracted). If the count phase doesn't produce a solution dict, falls back to
# a dedicated solve call to populate the reference solution.
static func _analyze_prepared(
	layout: Dictionary,
	empty_cells: Array,
	width: int,
	height: int,
	tiles: Array,
	constraints: Array,
	shared_iter: Dictionary
) -> Dictionary:
	var count := PuzzleSolver.count_solutions(
		layout, empty_cells, width, height, tiles, constraints, shared_iter
	)
	if count == SOLUTIONS_UNKNOWN:
		return _result(SOLUTIONS_UNKNOWN, {}, true)
	var solution: Dictionary = {}
	if count >= 1 and shared_iter.has("solution"):
		solution = shared_iter["solution"]
	elif count >= 1:
		solution = PuzzleSolver.solve_reference(
			layout, empty_cells, width, height, tiles, constraints
		)
	return _result(count, solution, false)

# Returns a copy of the layout with both cells of every shifter pair set to
# EMPTY, so the mobility loop can place the shifter on whichever side it needs.
static func _layout_with_pair_cells_cleared(layout: Dictionary, pairs: Array) -> Dictionary:
	var out: Dictionary = layout.duplicate()
	for pair in pairs:
		var cell_a: Vector2i = pair["a"]
		var cell_b: Vector2i = pair["b"]
		for cell in [cell_a, cell_b]:
			if not out.has(cell):
				continue
			var state: int = int(out[cell])
			if state == GameConstants.TileState.SHIFTER or state == GameConstants.TileState.EMPTY:
				out[cell] = GameConstants.TileState.EMPTY
	return out

# Strips invalid entries from the raw shifter_pairs list: keeps only dicts with
# "a" and "b" keys pointing to distinct coordinates.
static func _normalized_shifter_pairs(shifter_pairs: Array) -> Array:
	var pairs: Array = []
	for raw in shifter_pairs:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		if not raw.has("a") or not raw.has("b"):
			continue
		var cell_a: Vector2i = raw["a"]
		var cell_b: Vector2i = raw["b"]
		if cell_a == cell_b:
			continue
		pairs.append({"a": cell_a, "b": cell_b})
	return pairs

# Deduplicates the tile list and falls back to all three types when empty,
# preventing a degenerate solver state.
static func _normalize_tiles(available_tiles: Array) -> Array:
	var tiles: Array = []
	for tile in available_tiles:
		var state := int(tile)
		if not tiles.has(state):
			tiles.append(state)
	if tiles.is_empty():
		return [
			GameConstants.TileState.YELLOW,
			GameConstants.TileState.BLUE,
			GameConstants.TileState.JOKER,
		]
	return tiles

# Builds the standardised result dict returned by all public analyse methods.
static func _result(solution_count: int, solution: Dictionary, timed_out: bool) -> Dictionary:
	var solvable := solution_count >= 1
	return {
		"solvable": solvable,
		"unique": solution_count == 1,
		"solution_count": solution_count,
		"solution": solution,
		"timed_out": timed_out,
	}
