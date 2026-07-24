class_name PuzzleSolver
extends RefCounted

## Public solvability / uniqueness facade over PuzzleGenerator's backtracker.
## solution_count: 0 | 1 | 2+ (capped) | SOLUTIONS_UNKNOWN (-1)
##
## Shifter pairs may occupy either linked cell; the other cell is filled with a color.
## Analysis tries every combination of shifter sides under one shared iteration budget.

const SOLUTIONS_UNKNOWN := PuzzleGenerator.SOLUTIONS_UNKNOWN
## Shared across all shifter-side configs (not reset per mask).
const MOBILITY_ITER_BUDGET := 120000
## Soft cap so 2^n stays bounded (8 pairs → 256 configs).
const MAX_SHIFTER_PAIRS_FOR_MOBILITY := 8

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
		# Solvable-only stops at 1; uniqueness needs to prove 2+.
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
		var branch := LevelUtils.count_solutions(
			configured, empties, width, height, tiles, constraints, shared_iter
		)
		if branch == SOLUTIONS_UNKNOWN:
			timed_out = true
			break
		if branch >= 1 and first_solution.is_empty() and shared_iter.has("solution"):
			first_solution = shared_iter["solution"]
		total += branch
		# Solvable-only: stop at first solution. Unique: stop once multi is proven.
		if not require_unique and total >= 1:
			break
		if total > 1:
			total = 2
			break

	if timed_out and total < 1:
		return _result(SOLUTIONS_UNKNOWN, first_solution, true)
	if timed_out and require_unique and total == 1:
		# Could not prove uniqueness within budget.
		return _result(SOLUTIONS_UNKNOWN, first_solution, true)
	return _result(total, first_solution, false)

static func _analyze_prepared(
	layout: Dictionary,
	empty_cells: Array,
	width: int,
	height: int,
	tiles: Array,
	constraints: Array,
	shared_iter: Dictionary
) -> Dictionary:
	var count := LevelUtils.count_solutions(
		layout, empty_cells, width, height, tiles, constraints, shared_iter
	)
	if count == SOLUTIONS_UNKNOWN:
		return _result(SOLUTIONS_UNKNOWN, {}, true)
	var solution: Dictionary = {}
	if count >= 1 and shared_iter.has("solution"):
		solution = shared_iter["solution"]
	elif count >= 1:
		solution = LevelUtils.solve_reference(
			layout, empty_cells, width, height, tiles, constraints
		)
	return _result(count, solution, false)

## Ensure pair endpoints are empty so each config can place the shifter on either side.
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
		# Skip pairs whose endpoints are locked to a non-empty color.
		pairs.append({"a": cell_a, "b": cell_b})
	return pairs

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

static func _result(solution_count: int, solution: Dictionary, timed_out: bool) -> Dictionary:
	var solvable := solution_count >= 1
	return {
		"solvable": solvable,
		"unique": solution_count == 1,
		"solution_count": solution_count,
		"solution": solution,
		"timed_out": timed_out,
	}
