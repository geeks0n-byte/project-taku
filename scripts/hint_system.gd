class_name HintSystem
extends RefCounted

# Stateless utility class for selecting and counting constraint hints.
# A "hint" is a pair of adjacent cells with a known relationship (equals or
# not_equals) derived from the solved reference board. Hints are surfaced to
# the player as visual link overlays on the active board.
#
# Two candidate pools exist:
#   open pool   – at least one cell in the pair is still EMPTY
#   filled pool – both cells are already filled (used to correct mistakes)
#
# "hidden_reference_constraints" are extra constraints that were stripped from
# the published level to reduce information; they still come from a valid
# solution and can be offered as bonus hints.


# Returns the total number of hints that could currently be shown: open pairs
# (at least one empty cell) plus filled pairs that involve a player mistake.
# Already-correct filled pairs are not counted — they do not help the player.
static func count_usable_hints(
	board_cells: Dictionary,
	active_constraints: Array,
	solved_reference: Dictionary,
	hidden_reference_constraints: Array = [],
	grid_size: Vector2i = Vector2i.ZERO,
	prefer_hidden_pool: bool = false
) -> int:
	var open := _collect_candidates(
		board_cells,
		active_constraints,
		solved_reference,
		hidden_reference_constraints,
		grid_size,
		prefer_hidden_pool,
		false
	)
	var filled := _collect_candidates(
		board_cells,
		active_constraints,
		solved_reference,
		hidden_reference_constraints,
		grid_size,
		prefer_hidden_pool,
		true
	)
	var wrong_n := 0
	for candidate in filled:
		if _involves_wrong_cell(board_cells, solved_reference, candidate):
			wrong_n += 1
	return open.size() + wrong_n

# Selects the single best hint to show. Priority order:
#   1. A filled pair where at least one cell is wrong (corrective hint)
#   2. An open-pair constraint that creates a new forced cell or reduces options
#      on a stuck empty cell (a useful next deduction from the current board)
#   3. Fallback open-pair priority (locked neighbour, existing links, ...)
# Correctly filled pairs are never hinted — they do not advance a stuck player.
# Returns null when no suitable hint exists.
static func pick_hint(
	board_cells: Dictionary,
	active_constraints: Array,
	solved_reference: Dictionary,
	hidden_reference_constraints: Array = [],
	grid_size: Vector2i = Vector2i.ZERO,
	prefer_hidden_pool: bool = false,
	available_tiles: Array = []
) -> Variant:
	var filled: Array = _collect_candidates(
		board_cells,
		active_constraints,
		solved_reference,
		hidden_reference_constraints,
		grid_size,
		prefer_hidden_pool,
		true
	)
	var wrong_filled: Variant = _pick_both_filled(
		board_cells, active_constraints, solved_reference, filled, prefer_hidden_pool, true
	)
	if wrong_filled != null:
		return wrong_filled

	var open: Array = _collect_candidates(
		board_cells,
		active_constraints,
		solved_reference,
		hidden_reference_constraints,
		grid_size,
		prefer_hidden_pool,
		false
	)
	return _pick_progress_hint(
		board_cells,
		active_constraints,
		solved_reference,
		open,
		prefer_hidden_pool,
		available_tiles
	)

# Picks the open-pair hint that most helps the current board: prefers a
# constraint that turns a stuck cell (2+ options) into a naked single.
static func _pick_progress_hint(
	board_cells: Dictionary,
	active_constraints: Array,
	solved_reference: Dictionary,
	candidates: Array,
	prefer_hidden_pool: bool,
	available_tiles: Array
) -> Variant:
	if candidates.is_empty():
		return null
	var usable: Array = []
	for candidate in candidates:
		if not prefer_hidden_pool and not solved_reference.is_empty() and not _reference_satisfies(solved_reference, candidate):
			continue
		usable.append(candidate)
	if usable.is_empty():
		return null

	var tiles := _hint_tiles(available_tiles)
	var layout := {}
	var empty_cells: Array = []
	for coord in board_cells:
		var st := int(board_cells[coord].state)
		layout[coord] = st
		if st == GameConstants.TileState.EMPTY:
			empty_cells.append(coord)
	var size := LevelUtils.get_dimensions_from_cells(board_cells)
	var before := {}
	var stuck := {}
	if not empty_cells.is_empty():
		var base_ctx := PuzzleGenerator._prepare_solver_ctx(layout, size.x, size.y, active_constraints)
		for coord in empty_cells:
			var n := PuzzleGenerator._fast_option_count(base_ctx, coord.y * size.x + coord.x, tiles, true)
			before[coord] = n
			if n > 1:
				stuck[coord] = true

	var best_score := -1
	var best: Array = []
	for candidate in usable:
		var score := _score_hint_candidate(
			candidate, layout, empty_cells, before, stuck, size, tiles, active_constraints
		)
		if score > best_score:
			best_score = score
			best = [candidate]
		elif score == best_score:
			best.append(candidate)
	if best_score > 0 and not best.is_empty():
		return best.pick_random()

	if not stuck.is_empty():
		var touching: Array = []
		for candidate in usable:
			if stuck.has(candidate["a"]) or stuck.has(candidate["b"]):
				touching.append(candidate)
		if not touching.is_empty():
			return touching.pick_random()

	return _pick_by_priority(board_cells, active_constraints, solved_reference, usable, prefer_hidden_pool)


static func _hint_tiles(available_tiles: Array) -> Array:
	var tiles: Array = []
	for tile in available_tiles:
		var state := int(tile)
		if state == GameConstants.TileState.SHIFTER:
			continue
		if not tiles.has(state):
			tiles.append(state)
	if tiles.is_empty():
		return [
			GameConstants.TileState.YELLOW,
			GameConstants.TileState.BLUE,
			GameConstants.TileState.JOKER,
		]
	return tiles


static func _score_hint_candidate(
	candidate: Dictionary,
	layout: Dictionary,
	empty_cells: Array,
	before: Dictionary,
	stuck: Dictionary,
	size: Vector2i,
	tiles: Array,
	active_constraints: Array
) -> int:
	if empty_cells.is_empty():
		return 0
	var trial: Array = active_constraints.duplicate()
	trial.append(candidate)
	var ctx := PuzzleGenerator._prepare_solver_ctx(layout, size.x, size.y, trial)
	var score := 0
	for coord in empty_cells:
		var after := PuzzleGenerator._fast_option_count(ctx, coord.y * size.x + coord.x, tiles, true)
		var bcnt := int(before.get(coord, 0))
		if after < bcnt:
			score += (bcnt - after) * 10
		if bcnt > 1 and after == 1:
			score += 100
		if bcnt > 0 and after == 0:
			score -= 1000
	if stuck.has(candidate["a"]) or stuck.has(candidate["b"]):
		score += 5
	return score


# Runs a quick solve on the board in its current state (respecting existing
# locked tiles) to produce a reference solution on demand, e.g. when the level
# has no pre-computed reference. Returns an empty dict if unsolvable.
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

# Solves the board from scratch and rebuilds the hidden-hint pool from the
# resulting solution. Useful after the board state changes significantly (e.g.
# after a shifter move). Returns an empty array if no solution is found.
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

# Enumerates all adjacent cell pairs in the solved grid and records each
# relationship as a hidden hint, provided the pair is not already an active
# (visible) constraint and both cells hold hintable tile states.
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

# Builds the list of hint candidates for the given pool type.
# When prefer_hidden_pool is true the hidden constraints are used exclusively.
# When solved_reference is empty we also fall back to the hidden pool.
# Otherwise, candidates are derived from every adjacent pair in the grid,
# followed by any hidden constraints not already covered.
# both_filled_only controls whether to collect open pairs or filled pairs.
static func _collect_candidates(
	board_cells: Dictionary,
	active_constraints: Array,
	solved_reference: Dictionary,
	hidden_reference_constraints: Array,
	grid_size: Vector2i,
	prefer_hidden_pool: bool,
	both_filled_only: bool
) -> Array:
	var candidates: Array = []
	var seen: Dictionary = {}

	if prefer_hidden_pool:
		for hidden in hidden_reference_constraints:
			var key := _pair_key(hidden["a"], hidden["b"])
			if seen.has(key):
				continue
			if not _is_pool_hint_usable(board_cells, active_constraints, hidden, both_filled_only):
				continue
			seen[key] = true
			candidates.append(hidden)
		return candidates

	if solved_reference.is_empty():
		for hidden in hidden_reference_constraints:
			var key := _pair_key(hidden["a"], hidden["b"])
			if seen.has(key):
				continue
			if not _is_pool_hint_usable(board_cells, active_constraints, hidden, both_filled_only):
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
					board_cells,
					active_constraints,
					solved_reference,
					coord,
					neighbor,
					both_filled_only
				)
				if candidate == null:
					continue
				var key := _pair_key(candidate["a"], candidate["b"])
				if seen.has(key):
					continue
				seen[key] = true
				candidates.append(candidate)

	for hidden in hidden_reference_constraints:
		var key := _pair_key(hidden["a"], hidden["b"])
		if seen.has(key):
			continue
		if not _is_pool_hint_usable(board_cells, active_constraints, hidden, both_filled_only):
			continue
		if not _reference_satisfies(solved_reference, hidden):
			continue
		seen[key] = true
		candidates.append(hidden)

	return candidates

# Tries to construct a hint candidate for two adjacent cells.
# Returns null if either cell is a wall, outside the solved reference, already
# linked by an active constraint, or doesn't match the both_filled_only filter.
static func _make_candidate(
	board_cells: Dictionary,
	active_constraints: Array,
	solved_reference: Dictionary,
	coord_a: Vector2i,
	coord_b: Vector2i,
	both_filled_only: bool
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
	if both_filled_only:
		if a_empty or b_empty:
			return null
	elif not a_empty and not b_empty:
		return null

	var hint_type := "equals" if sol_a == sol_b else "not_equals"
	return {"a": coord_a, "b": coord_b, "type": hint_type}

# Validates a hidden-pool hint: checks that both cells exist, neither is a
# wall, the pair isn't already constrained, and the fill-state matches the
# requested pool (open or filled).
static func _is_pool_hint_usable(
	board_cells: Dictionary,
	active_constraints: Array,
	hint: Dictionary,
	both_filled_only: bool
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
	if both_filled_only:
		if a_empty or b_empty:
			return false
	elif not a_empty and not b_empty:
		return false
	return true

# Returns true when the solved reference agrees with the hint's relationship:
# "equals" requires both cells to share the same tile state, "not_equals" requires them to differ.
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

# Selects the best open-pair hint from the candidate list using a five-bucket
# priority system. Picks randomly within the highest-occupied bucket so the
# player doesn't always see the same hint on repeated presses.
# Priority buckets (highest to lowest):
#   p0 – one empty, the other is wrong
#   p1 – one empty, the other is locked/fixed
#   p2 – one empty, the other is correctly placed
#   p3 – one or both empty, and either cell already has a visible constraint
#   p4 – both empty, no other context
static func _pick_by_priority(
	board_cells: Dictionary,
	active_constraints: Array,
	solved_reference: Dictionary,
	candidates: Array,
	prefer_hidden_pool: bool = false
) -> Variant:
	var priority_0: Array = []
	var priority_1: Array = []
	var priority_2: Array = []
	var priority_3: Array = []
	var priority_4: Array = []

	for candidate in candidates:
		if not prefer_hidden_pool and not solved_reference.is_empty() and not _reference_satisfies(solved_reference, candidate):
			continue
		_bucket_candidate(
			board_cells, active_constraints, solved_reference, candidate,
			priority_0, priority_1, priority_2, priority_3, priority_4
		)

	if priority_0.size() > 0:
		return priority_0.pick_random()
	if priority_1.size() > 0:
		return priority_1.pick_random()
	if priority_2.size() > 0:
		return priority_2.pick_random()
	if priority_3.size() > 0:
		return priority_3.pick_random()
	if priority_4.size() > 0:
		return priority_4.pick_random()
	return null

# Selects a hint from the filled-pair pool. Prefers pairs that involve at
# least one incorrectly-placed cell (corrective), then falls back to any other
# filled pair unless wrong_only is set (in which case null is returned).
static func _pick_both_filled(
	board_cells: Dictionary,
	_active_constraints: Array,
	solved_reference: Dictionary,
	candidates: Array,
	prefer_hidden_pool: bool,
	wrong_only: bool = false
) -> Variant:
	var involving_wrong: Array = []
	var other: Array = []
	for candidate in candidates:
		if not prefer_hidden_pool and not solved_reference.is_empty() and not _reference_satisfies(solved_reference, candidate):
			continue
		if _involves_wrong_cell(board_cells, solved_reference, candidate):
			involving_wrong.append(candidate)
		else:
			other.append(candidate)
	if involving_wrong.size() > 0:
		return involving_wrong.pick_random()
	if wrong_only:
		return null
	if other.size() > 0:
		return other.pick_random()
	return null

# Returns true if either cell in the candidate pair is currently filled with a
# tile that contradicts the solved reference (i.e. the player has a mistake there).
static func _involves_wrong_cell(
	board_cells: Dictionary,
	solved_reference: Dictionary,
	candidate: Dictionary
) -> bool:
	if solved_reference.is_empty():
		return false
	for coord in [candidate["a"], candidate["b"]]:
		if not board_cells.has(coord) or not solved_reference.has(coord):
			continue
		var cell = board_cells[coord]
		if cell.state == GameConstants.TileState.EMPTY or cell.state == GameConstants.TileState.WALL:
			continue
		if cell.state == GameConstants.TileState.SHIFTER:
			continue
		var expected = int(solved_reference[coord])
		if expected < 0:
			continue
		if int(cell.state) != expected:
			return true
	return false

# Checks whether a single filled (non-empty, non-wall, non-shifter) cell
# disagrees with the solved reference. Returns false when no reference exists.
static func _cell_is_wrong(
	board_cells: Dictionary,
	solved_reference: Dictionary,
	coord: Vector2i
) -> bool:
	if solved_reference.is_empty() or not board_cells.has(coord) or not solved_reference.has(coord):
		return false
	var cell = board_cells[coord]
	if cell.state == GameConstants.TileState.EMPTY or cell.state == GameConstants.TileState.WALL:
		return false
	if cell.state == GameConstants.TileState.SHIFTER:
		return false
	var expected = int(solved_reference[coord])
	if expected < 0:
		return false
	return int(cell.state) != expected

# Classifies a single open-pair candidate into one of five priority buckets
# (p0–p4) based on the fill/correctness/lock state of its two cells.
# See _pick_by_priority for the full bucket semantics.
static func _bucket_candidate(
	board_cells: Dictionary,
	active_constraints: Array,
	solved_reference: Dictionary,
	candidate: Dictionary,
	p0: Array,
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

	var a_wrong := _cell_is_wrong(board_cells, solved_reference, coord_a)
	var b_wrong := _cell_is_wrong(board_cells, solved_reference, coord_b)

	var a_has_hint := _cell_has_any_constraint(coord_a, active_constraints)
	var b_has_hint := _cell_has_any_constraint(coord_b, active_constraints)

	if (a_empty and b_wrong) or (b_empty and a_wrong):
		p0.append(candidate)
		return
	if (a_empty and b_fixed) or (b_empty and a_fixed):
		p1.append(candidate)
		return
	if (a_empty and b_correct) or (b_empty and a_correct):
		p2.append(candidate)
		return
	if (a_empty or b_empty) and (a_has_hint or b_has_hint):
		p3.append(candidate)
		return
	if a_empty and b_empty:
		p4.append(candidate)

# Returns true if the given cell is part of at least one active visible constraint.
static func _cell_has_any_constraint(coord: Vector2i, constraints: Array) -> bool:
	for constraint in constraints:
		if constraint["a"] == coord or constraint["b"] == coord:
			return true
	return false

# Produces a canonical string key for an unordered cell pair so that (a, b)
# and (b, a) map to the same key, preventing duplicate candidates.
static func _pair_key(a: Vector2i, b: Vector2i) -> String:
	if a.x < b.x or (a.x == b.x and a.y <= b.y):
		return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]
	return "%d,%d|%d,%d" % [b.x, b.y, a.x, a.y]
