extends RefCounted

const LogicTestRunner := preload("res://tests/logic_test_runner.gd")

static func run(r: LogicTestRunner) -> void:
	_test_star_bits(r)
	_test_star_evaluate(r)
	_test_validator_balanced_grid(r)
	_test_validator_three_in_a_row(r)
	_test_validator_unequal_colors(r)
	_test_validator_equals_constraint(r)
	_test_validator_not_equals_constraint(r)
	_test_validator_joker_cap(r)
	_test_validator_shifter_equals(r)
	_test_solver_trivial_unique(r)
	_test_solver_empty_not_unique(r)
	_test_solver_equals_forces_match(r)
	_test_generator_smoke_easy(r)
	_test_shifter_shared_cell_unique_active(r)

static func _test_star_bits(r: LogicTestRunner) -> void:
	r.ok(LevelStars.count_earned_bits(0) == 0, "stars: none")
	r.ok(
		LevelStars.count_earned_bits(LevelStars.BIT_COMPLETE | LevelStars.BIT_NO_HINTS | LevelStars.BIT_TIME)
		== 3,
		"stars: all three"
	)
	r.ok(LevelStars.count_earned_bits(LevelStars.BIT_COMPLETE) == 1, "stars: clear only")
	r.ok(
		not LevelStars.has_perfect_clear_in_bits_dict({"12": LevelStars.BIT_COMPLETE | LevelStars.BIT_NO_HINTS}),
		"stars: perfect clear rejects two-bit save"
	)
	r.ok(
		LevelStars.has_perfect_clear_in_bits_dict({
			"5": LevelStars.BIT_COMPLETE | LevelStars.BIT_NO_HINTS | LevelStars.BIT_TIME,
		}),
		"stars: perfect clear detects three-bit save"
	)
	r.ok(not LevelStars.has_perfect_clear_in_bits_dict({"5": LevelStars.BIT_COMPLETE}), "stars: perfect clear rejects one-bit save")

static func _test_star_evaluate(r: LogicTestRunner) -> void:
	var all_ok := LevelStars.evaluate(10, 30, 0, 0, 0, false, true)
	r.ok(int(all_ok.get("bits", 0)) == (LevelStars.BIT_COMPLETE | LevelStars.BIT_NO_HINTS | LevelStars.BIT_TIME), "evaluate: all stars")
	var slow := LevelStars.evaluate(99, 30, 1, 0, 0, false, true)
	r.ok(int(slow.get("bits", 0)) == LevelStars.BIT_COMPLETE, "evaluate: clear only when slow+hints")
	var untimed := LevelStars.evaluate(999, 0, 0, 0, 0, false, true)
	r.ok((int(untimed.get("bits", 0)) & LevelStars.BIT_TIME) != 0, "evaluate: infinite time still awards time star")

static func _test_validator_balanced_grid(r: LogicTestRunner) -> void:
	var layout := r.grid(2, 2, func(x: int, y: int) -> int:
		return GameConstants.TileState.YELLOW if (x + y) % 2 == 0 else GameConstants.TileState.BLUE
	)
	var result := PuzzleValidator.validate_layout_states(layout, 2, 2, [], [])
	r.ok(bool(result.get("valid", false)), "validator: 2x2 checkerboard valid")

static func _test_validator_three_in_a_row(r: LogicTestRunner) -> void:
	var layout := {
		Vector2i(0, 0): GameConstants.TileState.YELLOW,
		Vector2i(1, 0): GameConstants.TileState.YELLOW,
		Vector2i(2, 0): GameConstants.TileState.YELLOW,
		Vector2i(3, 0): GameConstants.TileState.BLUE,
		Vector2i(0, 1): GameConstants.TileState.BLUE,
		Vector2i(1, 1): GameConstants.TileState.BLUE,
		Vector2i(2, 1): GameConstants.TileState.YELLOW,
		Vector2i(3, 1): GameConstants.TileState.YELLOW,
	}
	for y in range(2, 4):
		for x in 4:
			layout[Vector2i(x, y)] = (
				GameConstants.TileState.YELLOW if (x + y) % 2 == 0 else GameConstants.TileState.BLUE
			)
	var result := PuzzleValidator.validate_layout_states(layout, 4, 4, [], [])
	r.ok(not bool(result.get("valid", true)), "validator: three-in-a-row invalid")

static func _test_validator_unequal_colors(r: LogicTestRunner) -> void:
	var layout := r.grid(2, 2, func(_x: int, _y: int) -> int:
		return GameConstants.TileState.YELLOW
	)
	var result := PuzzleValidator.validate_layout_states(layout, 2, 2, [], [])
	r.ok(not bool(result.get("valid", true)), "validator: unequal colors invalid")

static func _test_validator_equals_constraint(r: LogicTestRunner) -> void:
	var layout := r.grid(2, 2, func(x: int, y: int) -> int:
		return GameConstants.TileState.YELLOW if (x + y) % 2 == 0 else GameConstants.TileState.BLUE
	)
	var pairs := [{"a": Vector2i(0, 0), "b": Vector2i(1, 0), "type": "equals"}]
	var result := PuzzleValidator.validate_layout_states(layout, 2, 2, pairs, [])
	r.ok(not bool(result.get("valid", true)), "validator: equals conflict invalid")


static func _test_validator_not_equals_constraint(r: LogicTestRunner) -> void:
	var y := GameConstants.TileState.YELLOW
	var b := GameConstants.TileState.BLUE
	var balanced := {
		Vector2i(0, 0): y,
		Vector2i(1, 0): b,
		Vector2i(0, 1): b,
		Vector2i(1, 1): y,
	}
	var pairs := [{"a": Vector2i(0, 0), "b": Vector2i(1, 0), "type": "not_equals"}]
	var ok := PuzzleValidator.validate_layout_states(balanced, 2, 2, pairs, [])
	r.ok(bool(ok.get("valid", false)), "validator: not_equals accepts different colors")
	var same := balanced.duplicate(true)
	same[Vector2i(1, 0)] = y
	var bad := PuzzleValidator.validate_layout_states(same, 2, 2, pairs, [])
	var errors: Array = bad.get("errors", [])
	r.ok(errors.has("ERR_CONSTRAINT_NOT_EQUALS"), "validator: not_equals rejects same color")


static func _test_validator_joker_cap(r: LogicTestRunner) -> void:
	var layout := {
		Vector2i(0, 0): GameConstants.TileState.JOKER,
		Vector2i(1, 0): GameConstants.TileState.JOKER,
		Vector2i(2, 0): GameConstants.TileState.YELLOW,
		Vector2i(3, 0): GameConstants.TileState.BLUE,
	}
	for y in range(1, 4):
		for x in 4:
			layout[Vector2i(x, y)] = (
				GameConstants.TileState.YELLOW if (x + y) % 2 == 0 else GameConstants.TileState.BLUE
			)
	var result := PuzzleValidator.validate_layout_states(layout, 4, 4, [], [])
	r.ok(not bool(result.get("valid", true)), "validator: two jokers in one row invalid")


static func _test_validator_shifter_equals(r: LogicTestRunner) -> void:
	var sh := GameConstants.TileState.SHIFTER
	var y := GameConstants.TileState.YELLOW
	var matching := {
		Vector2i(0, 0): sh,
		Vector2i(1, 0): sh,
	}
	var pairs := [{"a": Vector2i(0, 0), "b": Vector2i(1, 0), "type": "equals"}]
	var ok := PuzzleValidator.validate_layout_states(matching, 2, 1, pairs, [])
	r.ok(bool(ok.get("valid", false)), "validator: shifter equals same tile ok")
	var clash := {
		Vector2i(0, 0): sh,
		Vector2i(1, 0): y,
	}
	var bad := PuzzleValidator.validate_layout_states(clash, 2, 1, pairs, [])
	r.ok(not bool(bad.get("valid", true)), "validator: shifter equals mismatch invalid")

static func _test_solver_trivial_unique(r: LogicTestRunner) -> void:
	var layout := r.grid(2, 2, func(x: int, y: int) -> int:
		return GameConstants.TileState.YELLOW if (x + y) % 2 == 0 else GameConstants.TileState.BLUE
	)
	var result := PuzzleSolver.analyze(layout, 2, 2, [], [], [], true)
	var count := int(result.get("solution_count", -1))
	r.ok(count == 1, "solver: filled 2x2 has 1 solution (got %d)" % count)

static func _test_solver_empty_not_unique(r: LogicTestRunner) -> void:
	var layout := r.grid(2, 2, func(_x: int, _y: int) -> int:
		return GameConstants.TileState.EMPTY
	)
	var tiles := [GameConstants.TileState.YELLOW, GameConstants.TileState.BLUE]
	var result := PuzzleSolver.analyze(layout, 2, 2, tiles, [], [], true)
	var count := int(result.get("solution_count", 0))
	r.ok(count > 1 or not bool(result.get("unique", true)), "solver: empty 2x2 is not unique (count=%d)" % count)

static func _test_solver_equals_forces_match(r: LogicTestRunner) -> void:
	var layout := {
		Vector2i(0, 0): GameConstants.TileState.YELLOW,
		Vector2i(1, 0): GameConstants.TileState.BLUE,
		Vector2i(0, 1): GameConstants.TileState.EMPTY,
		Vector2i(1, 1): GameConstants.TileState.YELLOW,
	}
	var pairs := [{"a": Vector2i(0, 1), "b": Vector2i(1, 0), "type": "equals"}]
	var tiles := [GameConstants.TileState.YELLOW, GameConstants.TileState.BLUE]
	var result := PuzzleSolver.analyze(layout, 2, 2, tiles, pairs, [], true)
	r.ok(bool(result.get("solvable", false)), "solver: equals-forced cell solvable")
	r.ok(bool(result.get("unique", false)), "solver: equals-forced cell unique")
	var solution: Dictionary = result.get("solution", {})
	r.ok(
		int(solution.get(Vector2i(0, 1), -99)) == GameConstants.TileState.BLUE,
		"solver: equals-forced cell is blue"
	)

static func _test_generator_smoke_easy(r: LogicTestRunner) -> void:
	seed(42)
	var tiles := [
		GameConstants.TileState.YELLOW,
		GameConstants.TileState.BLUE,
		GameConstants.TileState.JOKER,
	]
	var generated := PuzzleGenerator.generate_random_layout(
		4, 4, tiles, {}, true, false, PuzzleGenerator.Difficulty.EASY
	)
	r.ok(not generated.is_empty(), "generator: easy 4x4 returns a layout")
	if generated.is_empty():
		return
	var layout: Dictionary = generated.get("layout", {})
	var constraints: Array = generated.get("constraints", [])
	var shifters: Array = generated.get("shifters", [])
	var analysis := PuzzleSolver.analyze(
		layout, 4, 4, tiles, constraints, shifters, true
	)
	r.ok(bool(analysis.get("solvable", false)), "generator: result is solvable")
	r.ok(bool(analysis.get("unique", false)), "generator: result is unique")
	r.ok(
		PuzzleValidator.starting_layout_is_clean(layout, 4, 4, constraints, shifters),
		"generator: starting layout is clean"
	)
	r.ok(
		not LevelUtils.shifter_pairs_share_active_cell(shifters),
		"generator: shifter actives are unique"
	)

static func _test_shifter_shared_cell_unique_active(r: LogicTestRunner) -> void:
	var a := Vector2i(0, 0)
	var b := Vector2i(1, 0)
	var c := Vector2i(2, 0)
	var chain := [
		{"a": a, "b": b, "active": a, "inactive": b},
		{"a": b, "b": c, "active": c, "inactive": b},
	]
	r.ok(not LevelUtils.shifter_pairs_share_active_cell(chain), "shifters: shared inactive is ok")
	var empty := r.grid(3, 2, func(_x: int, _y: int) -> int:
		return GameConstants.TileState.EMPTY
	)
	r.ok(
		PuzzleValidator.starting_layout_is_clean(empty, 3, 2, [], chain),
		"shifters: chain with unique actives is clean"
	)
	var clash := [
		{"a": a, "b": b, "active": b, "inactive": a},
		{"a": b, "b": c, "active": b, "inactive": c},
	]
	r.ok(LevelUtils.shifter_pairs_share_active_cell(clash), "shifters: duplicate active is detected")
	r.ok(
		not PuzzleValidator.starting_layout_is_clean(empty, 3, 2, [], clash),
		"shifters: duplicate active is not clean"
	)
	var flipped := [
		{"a": a, "b": b, "active": b, "inactive": a},
		{"a": b, "b": c, "active": b, "inactive": c},
	]
	r.ok(PuzzleGenerator._assign_distinct_actives(flipped), "shifters: reassignment succeeds")
	r.ok(not LevelUtils.shifter_pairs_share_active_cell(flipped), "shifters: reassignment unique actives")
	r.ok(
		(flipped[0].active == a or flipped[0].active == b)
		and (flipped[1].active == b or flipped[1].active == c)
		and flipped[0].active != flipped[1].active,
		"shifters: each pair stays on its own cells"
	)
	var triangle := [
		{"a": a, "b": b, "active": a, "inactive": b},
		{"a": b, "b": c, "active": a, "inactive": c},
		{"a": c, "b": a, "active": a, "inactive": c},
	]
	r.ok(PuzzleGenerator._assign_distinct_actives(triangle), "shifters: triangle can uniquify")
	r.ok(not LevelUtils.shifter_pairs_share_active_cell(triangle), "shifters: triangle actives unique")
