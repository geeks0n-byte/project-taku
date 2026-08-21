extends SceneTree
## Headless puzzle-logic smoke tests.
## Run: godot --headless --path . -s res://tests/run_logic_tests.gd
## Or:  powershell -File tools/run_logic_tests.ps1

var _failed := 0
var _passed := 0

func _init() -> void:
	_test_star_bits()
	_test_star_evaluate()
	_test_validator_balanced_grid()
	_test_validator_three_in_a_row()
	_test_validator_unequal_colors()
	_test_validator_equals_constraint()
	_test_solver_trivial_unique()
	_test_solver_empty_not_unique()
	_test_solver_equals_forces_match()
	_test_generator_smoke_easy()
	_test_font_locale_policy()
	_test_save_migration_v1_to_v2()
	print("logic_tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _ok(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", name)
	else:
		_failed += 1
		printerr("  FAIL  ", name)

func _test_star_bits() -> void:
	_ok(LevelStars.count_earned_bits(0) == 0, "stars: none")
	_ok(
		LevelStars.count_earned_bits(LevelStars.BIT_COMPLETE | LevelStars.BIT_NO_HINTS | LevelStars.BIT_TIME)
		== 3,
		"stars: all three"
	)
	_ok(LevelStars.count_earned_bits(LevelStars.BIT_COMPLETE) == 1, "stars: clear only")

func _test_star_evaluate() -> void:
	var all_ok := LevelStars.evaluate(10, 30, 0, 0, 0, false, true)
	_ok(int(all_ok.get("bits", 0)) == (LevelStars.BIT_COMPLETE | LevelStars.BIT_NO_HINTS | LevelStars.BIT_TIME), "evaluate: all stars")
	var slow := LevelStars.evaluate(99, 30, 1, 0, 0, false, true)
	_ok(int(slow.get("bits", 0)) == LevelStars.BIT_COMPLETE, "evaluate: clear only when slow+hints")
	var untimed := LevelStars.evaluate(999, 0, 0, 0, 0, false, true)
	_ok((int(untimed.get("bits", 0)) & LevelStars.BIT_TIME) != 0, "evaluate: infinite time still awards time star")

func _grid(w: int, h: int, fill: Callable) -> Dictionary:
	var layout := {}
	for y in h:
		for x in w:
			layout[Vector2i(x, y)] = fill.call(x, y)
	return layout

func _test_validator_balanced_grid() -> void:
	# 2x2 checkerboard: each row/col has 1 yellow + 1 blue.
	var layout := _grid(2, 2, func(x: int, y: int) -> int:
		return GameConstants.TileState.YELLOW if (x + y) % 2 == 0 else GameConstants.TileState.BLUE
	)
	var result := PuzzleValidator.validate_layout_states(layout, 2, 2, [], [])
	_ok(bool(result.get("valid", false)), "validator: 2x2 checkerboard valid")

func _test_validator_three_in_a_row() -> void:
	# 4-wide row of three yellows then blue — illegal three-in-a-row.
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
	_ok(not bool(result.get("valid", true)), "validator: three-in-a-row invalid")

func _test_validator_unequal_colors() -> void:
	# All yellow on 2x2 — rows/cols cannot be balanced.
	var layout := _grid(2, 2, func(_x: int, _y: int) -> int:
		return GameConstants.TileState.YELLOW
	)
	var result := PuzzleValidator.validate_layout_states(layout, 2, 2, [], [])
	_ok(not bool(result.get("valid", true)), "validator: unequal colors invalid")

func _test_validator_equals_constraint() -> void:
	# Checkerboard is fine alone, but equals link between (0,0) and (1,0) conflicts.
	var layout := _grid(2, 2, func(x: int, y: int) -> int:
		return GameConstants.TileState.YELLOW if (x + y) % 2 == 0 else GameConstants.TileState.BLUE
	)
	var pairs := [{"a": Vector2i(0, 0), "b": Vector2i(1, 0), "type": "equals"}]
	var result := PuzzleValidator.validate_layout_states(layout, 2, 2, pairs, [])
	_ok(not bool(result.get("valid", true)), "validator: equals conflict invalid")

func _test_solver_trivial_unique() -> void:
	var layout := _grid(2, 2, func(x: int, y: int) -> int:
		return GameConstants.TileState.YELLOW if (x + y) % 2 == 0 else GameConstants.TileState.BLUE
	)
	var result := PuzzleSolver.analyze(layout, 2, 2, [], [], [], true)
	var count := int(result.get("solution_count", -1))
	_ok(count == 1, "solver: filled 2x2 has 1 solution (got %d)" % count)

func _test_solver_empty_not_unique() -> void:
	# Fully empty 2x2 has multiple balanced colorings.
	var layout := _grid(2, 2, func(_x: int, _y: int) -> int:
		return GameConstants.TileState.EMPTY
	)
	var tiles := [GameConstants.TileState.YELLOW, GameConstants.TileState.BLUE]
	var result := PuzzleSolver.analyze(layout, 2, 2, tiles, [], [], true)
	var count := int(result.get("solution_count", 0))
	_ok(count > 1 or not bool(result.get("unique", true)), "solver: empty 2x2 is not unique (count=%d)" % count)

func _test_solver_equals_forces_match() -> void:
	# Prefill three cells of a checkerboard; equals links the empty cell to a blue.
	var layout := {
		Vector2i(0, 0): GameConstants.TileState.YELLOW,
		Vector2i(1, 0): GameConstants.TileState.BLUE,
		Vector2i(0, 1): GameConstants.TileState.EMPTY,
		Vector2i(1, 1): GameConstants.TileState.YELLOW,
	}
	var pairs := [{"a": Vector2i(0, 1), "b": Vector2i(1, 0), "type": "equals"}]
	var tiles := [GameConstants.TileState.YELLOW, GameConstants.TileState.BLUE]
	var result := PuzzleSolver.analyze(layout, 2, 2, tiles, pairs, [], true)
	_ok(bool(result.get("solvable", false)), "solver: equals-forced cell solvable")
	_ok(bool(result.get("unique", false)), "solver: equals-forced cell unique")
	var solution: Dictionary = result.get("solution", {})
	_ok(
		int(solution.get(Vector2i(0, 1), -99)) == GameConstants.TileState.BLUE,
		"solver: equals-forced cell is blue"
	)

func _test_generator_smoke_easy() -> void:
	seed(42)
	var tiles := [
		GameConstants.TileState.YELLOW,
		GameConstants.TileState.BLUE,
		GameConstants.TileState.JOKER,
	]
	var generated := PuzzleGenerator.generate_random_layout(
		4, 4, tiles, {}, true, false, PuzzleGenerator.Difficulty.EASY
	)
	_ok(not generated.is_empty(), "generator: easy 4x4 returns a layout")
	if generated.is_empty():
		return
	var layout: Dictionary = generated.get("layout", {})
	var constraints: Array = generated.get("constraints", [])
	var shifters: Array = generated.get("shifters", [])
	var analysis := PuzzleSolver.analyze(
		layout, 4, 4, tiles, constraints, shifters, true
	)
	_ok(bool(analysis.get("solvable", false)), "generator: result is solvable")
	_ok(bool(analysis.get("unique", false)), "generator: result is unique")
	_ok(
		PuzzleValidator.starting_layout_is_clean(layout, 4, 4, constraints, shifters),
		"generator: starting layout is clean"
	)

func _test_font_locale_policy() -> void:
	TranslationServer.set_locale("en")
	_ok(HudFonts.uses_pixel_font(), "fonts: en uses pixel")
	TranslationServer.set_locale("ka")
	_ok(not HudFonts.uses_pixel_font(), "fonts: ka uses default")
	TranslationServer.set_locale("uk")
	_ok(not HudFonts.uses_pixel_font(), "fonts: uk uses default")
	TranslationServer.set_locale("en")

func _test_save_migration_v1_to_v2() -> void:
	const Migration := preload("res://scripts/save_migration.gd")
	var cfg := ConfigFile.new()
	cfg.set_value("Progression", "max_unlocked_level", 3)
	cfg.set_value("Progression", "current_language", "en")
	cfg.set_value("Progression", "level_star_bits", {1: 7, 2: 4})
	Migration.migrate_config(cfg, 1)
	var bits = cfg.get_value("Progression", "level_star_bits", {})
	_ok(typeof(bits) == TYPE_DICTIONARY, "migrate: bits dict")
	_ok(bits.has("1") and int(bits["1"]) == 7, "migrate: key 1 stringified")
	_ok(bits.has("2") and int(bits["2"]) == 4, "migrate: key 2 stringified")
	_ok(int(Migration.FORMAT_VERSION) >= 2, "migrate: format version is 2+")
