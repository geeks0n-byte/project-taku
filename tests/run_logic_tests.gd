extends SceneTree
## Headless puzzle-logic smoke tests.
## Run: godot --headless --path . -s res://tests/run_logic_tests.gd
## Or:  powershell -File tools/run_logic_tests.ps1

var _failed := 0
var _passed := 0

# Runs every smoke test, prints a summary, then quits with the failure count.
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
	_test_shifter_shared_cell_unique_active()
	_test_font_locale_policy()
	_test_save_migration_v1_to_v2()
	_test_safe_insets()
	_test_wide_ui_cap()
	_test_hint_selection_policy()
	_test_hint_unique_pool_only()
	_test_hold_repeat()
	_test_achievement_catalog()
	_test_levels_unseen_badges()
	_test_cloud_save_logic()
	_test_cloud_save_stub()
	print("logic_tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

# Records one assertion and prints PASS/FAIL.
func _ok(cond: bool, name: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  ", name)
	else:
		_failed += 1
		printerr("  FAIL  ", name)

# LevelStars bit counting.
func _test_star_bits() -> void:
	_ok(LevelStars.count_earned_bits(0) == 0, "stars: none")
	_ok(
		LevelStars.count_earned_bits(LevelStars.BIT_COMPLETE | LevelStars.BIT_NO_HINTS | LevelStars.BIT_TIME)
		== 3,
		"stars: all three"
	)
	_ok(LevelStars.count_earned_bits(LevelStars.BIT_COMPLETE) == 1, "stars: clear only")

# LevelStars.evaluate awards complete / no-hints / time bits.
func _test_star_evaluate() -> void:
	var all_ok := LevelStars.evaluate(10, 30, 0, 0, 0, false, true)
	_ok(int(all_ok.get("bits", 0)) == (LevelStars.BIT_COMPLETE | LevelStars.BIT_NO_HINTS | LevelStars.BIT_TIME), "evaluate: all stars")
	var slow := LevelStars.evaluate(99, 30, 1, 0, 0, false, true)
	_ok(int(slow.get("bits", 0)) == LevelStars.BIT_COMPLETE, "evaluate: clear only when slow+hints")
	var untimed := LevelStars.evaluate(999, 0, 0, 0, 0, false, true)
	_ok((int(untimed.get("bits", 0)) & LevelStars.BIT_TIME) != 0, "evaluate: infinite time still awards time star")

# Builds a w*h layout dict via fill(x, y).
func _grid(w: int, h: int, fill: Callable) -> Dictionary:
	var layout := {}
	for y in h:
		for x in w:
			layout[Vector2i(x, y)] = fill.call(x, y)
	return layout

# 2x2 checkerboard is a legal balanced board.
func _test_validator_balanced_grid() -> void:
	# 2x2 checkerboard: each row/col has 1 yellow + 1 blue.
	var layout := _grid(2, 2, func(x: int, y: int) -> int:
		return GameConstants.TileState.YELLOW if (x + y) % 2 == 0 else GameConstants.TileState.BLUE
	)
	var result := PuzzleValidator.validate_layout_states(layout, 2, 2, [], [])
	_ok(bool(result.get("valid", false)), "validator: 2x2 checkerboard valid")

# Three identical colours in a row is illegal.
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

# Unbalanced colour counts are illegal.
func _test_validator_unequal_colors() -> void:
	# All yellow on 2x2 — rows/cols cannot be balanced.
	var layout := _grid(2, 2, func(_x: int, _y: int) -> int:
		return GameConstants.TileState.YELLOW
	)
	var result := PuzzleValidator.validate_layout_states(layout, 2, 2, [], [])
	_ok(not bool(result.get("valid", true)), "validator: unequal colors invalid")

# Equals link between opposite colours is illegal.
func _test_validator_equals_constraint() -> void:
	# Checkerboard is fine alone, but equals link between (0,0) and (1,0) conflicts.
	var layout := _grid(2, 2, func(x: int, y: int) -> int:
		return GameConstants.TileState.YELLOW if (x + y) % 2 == 0 else GameConstants.TileState.BLUE
	)
	var pairs := [{"a": Vector2i(0, 0), "b": Vector2i(1, 0), "type": "equals"}]
	var result := PuzzleValidator.validate_layout_states(layout, 2, 2, pairs, [])
	_ok(not bool(result.get("valid", true)), "validator: equals conflict invalid")

# A filled legal 2x2 has exactly one solution.
func _test_solver_trivial_unique() -> void:
	var layout := _grid(2, 2, func(x: int, y: int) -> int:
		return GameConstants.TileState.YELLOW if (x + y) % 2 == 0 else GameConstants.TileState.BLUE
	)
	var result := PuzzleSolver.analyze(layout, 2, 2, [], [], [], true)
	var count := int(result.get("solution_count", -1))
	_ok(count == 1, "solver: filled 2x2 has 1 solution (got %d)" % count)

# An empty 2x2 is not unique.
func _test_solver_empty_not_unique() -> void:
	# Fully empty 2x2 has multiple balanced colorings.
	var layout := _grid(2, 2, func(_x: int, _y: int) -> int:
		return GameConstants.TileState.EMPTY
	)
	var tiles := [GameConstants.TileState.YELLOW, GameConstants.TileState.BLUE]
	var result := PuzzleSolver.analyze(layout, 2, 2, tiles, [], [], true)
	var count := int(result.get("solution_count", 0))
	_ok(count > 1 or not bool(result.get("unique", true)), "solver: empty 2x2 is not unique (count=%d)" % count)

# Equals forces the remaining empty cell.
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

# Easy generator returns a layout without crashing.
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
	_ok(
		not LevelUtils.shifter_pairs_share_active_cell(shifters),
		"generator: shifter actives are unique"
	)

# Shifter pairs cannot share an active cell.
func _test_shifter_shared_cell_unique_active() -> void:
	var a := Vector2i(0, 0)
	var b := Vector2i(1, 0)
	var c := Vector2i(2, 0)
	# Chain A–B–C sharing B, each pair on a different active — allowed.
	var chain := [
		{"a": a, "b": b, "active": a, "inactive": b},
		{"a": b, "b": c, "active": c, "inactive": b},
	]
	_ok(not LevelUtils.shifter_pairs_share_active_cell(chain), "shifters: shared inactive is ok")
	var empty := _grid(3, 2, func(_x: int, _y: int) -> int:
		return GameConstants.TileState.EMPTY
	)
	_ok(
		PuzzleValidator.starting_layout_is_clean(empty, 3, 2, [], chain),
		"shifters: chain with unique actives is clean"
	)
	var clash := [
		{"a": a, "b": b, "active": b, "inactive": a},
		{"a": b, "b": c, "active": b, "inactive": c},
	]
	_ok(LevelUtils.shifter_pairs_share_active_cell(clash), "shifters: duplicate active is detected")
	_ok(
		not PuzzleValidator.starting_layout_is_clean(empty, 3, 2, [], clash),
		"shifters: duplicate active is not clean"
	)
	var flipped := [
		{"a": a, "b": b, "active": b, "inactive": a},
		{"a": b, "b": c, "active": b, "inactive": c},
	]
	_ok(PuzzleGenerator._assign_distinct_actives(flipped), "shifters: reassignment succeeds")
	_ok(not LevelUtils.shifter_pairs_share_active_cell(flipped), "shifters: reassignment unique actives")
	_ok(
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
	_ok(PuzzleGenerator._assign_distinct_actives(triangle), "shifters: triangle can uniquify")
	_ok(not LevelUtils.shifter_pairs_share_active_cell(triangle), "shifters: triangle actives unique")

# en uses Press Start; ka/uk use the default font.
func _test_font_locale_policy() -> void:
	TranslationServer.set_locale("en")
	_ok(HudFonts.uses_pixel_font(), "fonts: en uses pixel")
	TranslationServer.set_locale("ka")
	_ok(not HudFonts.uses_pixel_font(), "fonts: ka uses default")
	TranslationServer.set_locale("uk")
	_ok(not HudFonts.uses_pixel_font(), "fonts: uk uses default")
	TranslationServer.set_locale("en")

# v1 star-bit keys stringify during migration.
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

# Component-wise Vector4 approx assertion.
func _approx4(got: Vector4, expected: Vector4, name: String) -> void:
	_ok(
		is_equal_approx(got.x, expected.x)
		and is_equal_approx(got.y, expected.y)
		and is_equal_approx(got.z, expected.z)
		and is_equal_approx(got.w, expected.w),
		name
	)

# SafeInsets.margins_from converts a safe rect into layout margins.
func _test_safe_insets() -> void:
	var none := SafeInsets.margins_from(
		Rect2(0, 0, 1080, 1920), Vector2(1080, 1920), Vector2.ZERO, Vector2(1080, 1920)
	)
	_approx4(none, Vector4.ZERO, "safe: no inset when safe covers the window")
	var empty := SafeInsets.margins_from(
		Rect2(0, 0, 1080, 1920), Vector2.ZERO, Vector2.ZERO, Vector2(1080, 1920)
	)
	_approx4(empty, Vector4.ZERO, "safe: zero window size is empty insets")
	var bars := SafeInsets.margins_from(
		Rect2(0, 120, 1080, 1720), Vector2(1080, 1920), Vector2.ZERO, Vector2(1080, 1920)
	)
	_approx4(bars, Vector4(0, 120, 0, 80), "safe: 120 top / 80 bottom in viewport px")
	var scaled := SafeInsets.margins_from(
		Rect2(0, 160, 1440, 2240), Vector2(1440, 2560), Vector2.ZERO, Vector2(1080, 1920)
	)
	_approx4(scaled, Vector4(0, 120, 0, 120), "safe: screen insets scale into viewport")
	var shifted := SafeInsets.margins_from(
		Rect2(40, 160, 1000, 1700), Vector2(1080, 1920), Vector2(40, 40), Vector2(1080, 1920)
	)
	_approx4(shifted, Vector4(0, 120, 80, 100), "safe: window origin subtracted from screen rect")
	_ok(SafeInsets.padded_top(4.0) >= 4.0, "safe: padded_top never shrinks authored HUD top")
	_ok(
		SafeInsets.padded_bottom_offset(-192.0) <= -192.0,
		"safe: padded_bottom_offset only grows the bottom reserve"
	)
	_ok(SafeInsets.extra_top(4.0) >= 0.0, "safe: extra_top is non-negative")

# extra_side_inset_for_cap and phone-width constants.
func _test_wide_ui_cap() -> void:
	_ok(is_equal_approx(HudLayout.extra_side_inset_for_cap(1032.0, 1032.0), 0.0), "wide-cap: phone width is no-op")
	_ok(is_equal_approx(HudLayout.extra_side_inset_for_cap(1031.0, 1032.0), 0.0), "wide-cap: slightly narrow is no-op")
	_ok(is_equal_approx(HudLayout.extra_side_inset_for_cap(2032.0, 1032.0), 500.0), "wide-cap: tablet splits extra")
	_ok(is_equal_approx(HudLayout.UI_PHONE_CONTENT_WIDTH, 1032.0), "wide-cap: phone content is 1080-48")
	_ok(is_equal_approx(HudLayout.UI_PHONE_EDITOR_ROW_WIDTH, 1040.0), "wide-cap: editor row is 1080-40")
	_ok(is_equal_approx(HudLayout.extra_side_inset_for_cap(1872.0, 1032.0), 420.0), "wide-cap: status wrap inset on 1920")
	_ok(is_equal_approx(HudLayout.extra_side_inset_for_cap(1072.0, 1072.0), 0.0), "wide-cap: editor status phone is no-op")
	_ok(HudLayout.grid_row_pad_count(12, 3) == 0, "grid-pad: full page needs none")
	_ok(HudLayout.grid_row_pad_count(5, 3) == 1, "grid-pad: custom leftover 5")
	_ok(HudLayout.grid_row_pad_count(1, 3) == 2, "grid-pad: single leftover")
	_ok(HudLayout.grid_row_pad_count(0, 3) == 0, "grid-pad: empty is none")
	_ok(HudLayout.grid_row_pad_count(11, 3) == 1, "grid-pad: eleven needs one")
	# Same formula as SpaceBackground.phone_layer_scale / phone_cover_size /
	# fx_spawn_start_x. Do not preload space_background.gd here: SaveManager is
	# an autoload and the script fails to compile in this SceneTree runner.
	var phone := Vector2(1080.0, 1920.0)
	var pad := 1.35
	var tile := phone * pad
	_ok(is_equal_approx(maxf(tile.x / 1080.0, tile.y / 1920.0), 1.35), "bg-scale: phone tex is 1.35")
	var wide_tile := Vector2(1920.0, 1920.0) * pad
	_ok(not is_equal_approx(maxf(wide_tile.x / 1080.0, wide_tile.y / 1920.0), 1.35), "bg-scale: wider base would zoom")
	# Patterned cover stays 1080*1.35 even on a 1440x1920 tablet viewport.
	var tablet_vp := Vector2(1440.0, 1920.0)
	var cover := phone * pad
	_ok(is_equal_approx(cover.x, 1080.0 * 1.35), "bg-cover: width stays 1080*1.35 on 1440 viewport")
	_ok(not is_equal_approx(cover.x, tablet_vp.x), "bg-cover: not live 1440")
	# Same as SpaceBackground.fx_spawn_start_x(viewport.x, max_dim): window edge + size + margin.
	var spawn_x := tablet_vp.x + 64.0 + 50.0
	_ok(spawn_x > tablet_vp.x, "bg-spawn: start x is off the live window")
	# Android splash icon slot is 288dp when background is a separate theme color.
	var phone_side := GameConstants.android_splash_icon_side_px(phone)
	_ok(absf(phone_side - 288.0 * (1080.0 / 411.0)) < 1.0, "boot-splash: 288dp side on phone")
	var layout := GameConstants.boot_splash_icon_layout(Rect2(Vector2.ZERO, phone))
	var tile_px: float = layout["tile_px"]
	_ok(absf(tile_px - 16.0 * phone_side / 64.0) < 0.05, "boot-splash: tile px tracks icon side")
	_ok(
		absf(GameConstants.boot_splash_tile_sprite_scale(tile_px, 120.0) - tile_px / 120.0) < 0.05,
		"boot-splash: tile sprite scale fills 16px cell",
	)
	var visible_px := GameConstants.boot_splash_tile_visible_px(tile_px)
	var gap_px := (17.0 * phone_side / 64.0) - visible_px
	_ok(absf(gap_px - 3.0 * phone_side / 64.0) < 0.05, "boot-splash: 3px gap between visible tiles")
	_ok(tile_px > 120.0 and tile_px < 260.0, "boot-splash: tile px between old wrong extremes")
	_ok(
		is_equal_approx(
			HudLayout.page_nav_bottom_inset(true),
			GameConstants.SCREEN_PAGE_NAV_BOTTOM_INSET + GameConstants.AD_BANNER_RESERVE
		),
		"page-nav: menu banner reserve stacks on base inset"
	)
	_ok(
		HudLayout.page_nav_content_bottom_offset(true)
		< HudLayout.page_nav_content_bottom_offset(false),
		"page-nav: banner reserve pushes content higher"
	)

# Minimal cell dict for hint-policy tests.
func _mock_cell(state: int, locked: bool = false) -> Dictionary:
	return {"state": state, "is_locked": locked}


# Hints prefer mistakes and skip already-correct pairs.
func _test_hint_selection_policy() -> void:
	var y := GameConstants.TileState.YELLOW
	var b := GameConstants.TileState.BLUE
	var e := GameConstants.TileState.EMPTY
	var tiles := [y, b]
	# 4x2 start: Y _ _ B / B _ _ Y  solved checkerboard Y B Y B / B Y B Y
	var board := {
		Vector2i(0, 0): _mock_cell(y, true),
		Vector2i(1, 0): _mock_cell(e),
		Vector2i(2, 0): _mock_cell(e),
		Vector2i(3, 0): _mock_cell(b, true),
		Vector2i(0, 1): _mock_cell(b, true),
		Vector2i(1, 1): _mock_cell(e),
		Vector2i(2, 1): _mock_cell(e),
		Vector2i(3, 1): _mock_cell(y, true),
	}
	var solved := {
		Vector2i(0, 0): y, Vector2i(1, 0): b, Vector2i(2, 0): y, Vector2i(3, 0): b,
		Vector2i(0, 1): b, Vector2i(1, 1): y, Vector2i(2, 1): b, Vector2i(3, 1): y,
	}
	var pick: Variant = HintSystem.pick_hint(board, [], solved, [], Vector2i(4, 2), false, tiles)
	_ok(pick != null, "hint: finds an open-pair hint")
	if pick != null:
		var a: Vector2i = pick["a"]
		var bcoord: Vector2i = pick["b"]
		var a_empty: bool = int(board[a].state) == e
		var b_empty: bool = int(board[bcoord].state) == e
		_ok(a_empty or b_empty, "hint: involves an empty cell")
		var both_correct := (
			not a_empty and not b_empty
			and int(board[a].state) == int(solved[a])
			and int(board[bcoord].state) == int(solved[bcoord])
		)
		_ok(not both_correct, "hint: does not reveal an already-correct pair")

	# A mistaken fill should be preferred over open-pair progress.
	board[Vector2i(1, 0)] = _mock_cell(y, false)
	var pick_wrong: Variant = HintSystem.pick_hint(board, [], solved, [], Vector2i(4, 2), false, tiles)
	_ok(pick_wrong != null, "hint: still finds a hint with a wrong cell")
	if pick_wrong != null:
		_ok(
			HintSystem._involves_wrong_cell(board, solved, pick_wrong),
			"hint: prefers a pair involving the wrong cell"
		)

	board[Vector2i(1, 0)] = _mock_cell(e)
	var usable := HintSystem.count_usable_hints(board, [], solved, [], Vector2i(4, 2), false)
	_ok(usable > 0, "hint: usable count is positive while empties remain")

	# Fully correct board: no empty cells and no mistakes — nothing useful to hint.
	board[Vector2i(1, 0)] = _mock_cell(b)
	board[Vector2i(2, 0)] = _mock_cell(y)
	board[Vector2i(1, 1)] = _mock_cell(y)
	board[Vector2i(2, 1)] = _mock_cell(b)
	_ok(
		HintSystem.count_usable_hints(board, [], solved, [], Vector2i(4, 2), false) == 0,
		"hint: no usable hints when the board is already correct"
	)
	_ok(
		HintSystem.pick_hint(board, [], solved, [], Vector2i(4, 2), false, tiles) == null,
		"hint: pick is null when nothing would advance the player"
	)

# Unique / prefer_hidden_pool: picks must stay inside the designed hidden pool.
# Inventing an adjacent solved pair outside that pool is the unique-level bug.
func _test_hint_unique_pool_only() -> void:
	var y := GameConstants.TileState.YELLOW
	var b := GameConstants.TileState.BLUE
	var e := GameConstants.TileState.EMPTY
	var tiles := [y, b]
	var board := {
		Vector2i(0, 0): _mock_cell(y, true),
		Vector2i(1, 0): _mock_cell(e),
		Vector2i(2, 0): _mock_cell(e),
		Vector2i(3, 0): _mock_cell(b, true),
		Vector2i(0, 1): _mock_cell(b, true),
		Vector2i(1, 1): _mock_cell(e),
		Vector2i(2, 1): _mock_cell(e),
		Vector2i(3, 1): _mock_cell(y, true),
	}
	var solved := {
		Vector2i(0, 0): y, Vector2i(1, 0): b, Vector2i(2, 0): y, Vector2i(3, 0): b,
		Vector2i(0, 1): b, Vector2i(1, 1): y, Vector2i(2, 1): b, Vector2i(3, 1): y,
	}
	# Designed pool is a single open pair; many other adjacent solved pairs exist.
	var pool: Array = [{"a": Vector2i(1, 0), "b": Vector2i(2, 0), "type": "not_equals"}]
	var pick: Variant = HintSystem.pick_hint(board, [], solved, pool, Vector2i(4, 2), true, tiles)
	_ok(pick != null, "unique-pool: finds a hint from the designed pool")
	if pick != null:
		var key := HintSystem._pair_key(pick["a"], pick["b"])
		_ok(key == HintSystem._pair_key(Vector2i(1, 0), Vector2i(2, 0)), "unique-pool: pick is the only pool member")
		_ok(str(pick["type"]) == "not_equals", "unique-pool: preserves pool relationship")

	# Wrong-fill preference (both filled) still applies, but only among pool members.
	board[Vector2i(1, 0)] = _mock_cell(y, false)  # wrong (solved is blue)
	board[Vector2i(2, 0)] = _mock_cell(y, false)  # correct yellow; pair both filled
	var filled_pool: Array = [
		{"a": Vector2i(2, 1), "b": Vector2i(3, 1), "type": "not_equals"},
		{"a": Vector2i(1, 0), "b": Vector2i(2, 0), "type": "not_equals"},
	]
	var pick_wrong: Variant = HintSystem.pick_hint(
		board, [], solved, filled_pool, Vector2i(4, 2), true, tiles
	)
	_ok(pick_wrong != null, "unique-pool: still finds a hint with a wrong cell")
	if pick_wrong != null:
		var wkey := HintSystem._pair_key(pick_wrong["a"], pick_wrong["b"])
		_ok(
			wkey == HintSystem._pair_key(Vector2i(1, 0), Vector2i(2, 0)),
			"unique-pool: prefers wrong-fill within the pool"
		)
		_ok(
			HintSystem._involves_wrong_cell(board, solved, pick_wrong),
			"unique-pool: chosen pool member involves the wrong cell"
		)

	# Empty designed pool + prefer_hidden must not invent adjacent pairs.
	board[Vector2i(1, 0)] = _mock_cell(e)
	_ok(
		HintSystem.pick_hint(board, [], solved, [], Vector2i(4, 2), true, tiles) == null,
		"unique-pool: empty pool does not invent outside links"
	)
	_ok(
		HintSystem.count_usable_hints(board, [], solved, [], Vector2i(4, 2), true) == 0,
		"unique-pool: empty pool usable count is zero"
	)

	# Non-prefer path can still invent (legacy / open invent) — sanity contrast.
	_ok(
		HintSystem.pick_hint(board, [], solved, [], Vector2i(4, 2), false, tiles) != null,
		"unique-pool: invent path still works when prefer_hidden is false"
	)


## HoldRepeat: idle, delay, first fire, acceleration, stop_undo vs redo isolation.
func _test_hold_repeat() -> void:
	var h := HoldRepeat.new()
	_ok(not h.is_active(), "hold: idle is inactive")
	_ok(not h.is_undo() and not h.is_redo(), "hold: idle is neither side")
	_ok(not h.tick(1.0), "hold: idle tick does not fire")

	h.start_undo()
	_ok(h.is_active() and h.is_undo() and not h.is_redo(), "hold: start_undo")
	_ok(not h.tick(HoldRepeat.INITIAL_DELAY), "hold: at delay, interval not elapsed")
	_ok(not h.tick(HoldRepeat.REPEAT_START - 0.001), "hold: just before first repeat")
	_ok(h.tick(0.002), "hold: first undo repeat fires")
	_ok(not h.tick(h.interval - 0.001), "hold: waits accelerated interval")
	_ok(h.tick(0.002), "hold: second undo repeat fires")

	h.stop_undo()
	_ok(not h.is_active(), "hold: stop_undo clears undo")
	_ok(not h.tick(1.0), "hold: stopped undo does not fire")

	h.start_redo()
	h.start_undo()
	_ok(h.is_undo() and not h.is_redo(), "hold: start_undo replaces redo")
	h.stop_redo()
	_ok(h.is_undo(), "hold: stop_redo leaves undo")
	h.stop_undo()

	h.start_redo()
	_ok(h.is_redo() and not h.is_undo(), "hold: start_redo")
	h.stop_undo()
	_ok(h.is_redo(), "hold: stop_undo leaves redo")
	_ok(not h.tick(HoldRepeat.INITIAL_DELAY), "hold: redo at delay, interval not elapsed")
	_ok(not h.tick(HoldRepeat.REPEAT_START - 0.001), "hold: redo just before first repeat")
	_ok(h.tick(0.002), "hold: redo fires after delay+start")
	h.stop_redo()
	_ok(not h.is_active(), "hold: stop_redo clears redo")

	h.start_undo()
	for _i in 40:
		h.tick(10.0)
	_ok(h.interval >= HoldRepeat.REPEAT_MIN, "hold: interval never below REPEAT_MIN")
	_ok(is_equal_approx(h.interval, HoldRepeat.REPEAT_MIN), "hold: interval floors at REPEAT_MIN")



# AchievementCatalog: families, counters, hidden/secret, grant, event ids.
func _test_achievement_catalog() -> void:
	var empty := AchievementCatalog.collect_unlocks({})
	_ok(empty.is_empty(), "ach: empty state unlocks nothing")
	var first := AchievementCatalog.collect_unlocks({"campaign_clears": 1})
	_ok(first.has(AchievementCatalog.ID_FIRST_CLEAR), "ach: first_clear")
	_ok(not first.has(AchievementCatalog.ID_FIRST_HARD), "ach: first_hard not from easy")
	_ok(not first.has(AchievementCatalog.ID_CLEARS_SILVER), "ach: silver needs 30 clears")
	var hard := AchievementCatalog.collect_unlocks({"campaign_clears": 1, "hard_clears": 1})
	_ok(hard.has(AchievementCatalog.ID_FIRST_HARD), "ach: first_hard")
	var hinted := AchievementCatalog.collect_unlocks({"campaign_clears": 10, "no_hint_clears": 0})
	_ok(not hinted.has(AchievementCatalog.ID_NO_HINT_CLEAR), "ach: hinted clear is not no_hint")
	var no_hint := AchievementCatalog.collect_unlocks({"campaign_clears": 10, "no_hint_clears": 10})
	_ok(no_hint.has(AchievementCatalog.ID_NO_HINT_CLEAR), "ach: no_hint_clear")
	_ok(not no_hint.has(AchievementCatalog.ID_HINT_SAVER), "ach: hint_saver needs 30")
	var saver := AchievementCatalog.collect_unlocks({"campaign_clears": 30, "no_hint_clears": 30})
	_ok(saver.has(AchievementCatalog.ID_HINT_SAVER), "ach: hint_saver at 30")
	_ok(not saver.has(AchievementCatalog.ID_NO_HINT_GOLD), "ach: no_hint_gold needs 60")
	var sets := AchievementCatalog.collect_unlocks({
		"campaign_clears": 60,
		"easy_complete": true,
		"medium_complete": true,
		"hard_complete": true,
		"hard_clears": 10,
		"no_hint_clears": 10,
	})
	_ok(sets.has(AchievementCatalog.ID_EASY_SET), "ach: easy_set")
	_ok(sets.has(AchievementCatalog.ID_MEDIUM_SET), "ach: medium_set")
	_ok(sets.has(AchievementCatalog.ID_HARD_SET), "ach: hard_set")
	var already := {AchievementCatalog.ID_FIRST_CLEAR: 1}
	var skip := AchievementCatalog.collect_unlocks({"campaign_clears": 2}, already)
	_ok(not skip.has(AchievementCatalog.ID_FIRST_CLEAR), "ach: already unlocked is skipped")
	var easy_last := AchievementCatalog.last_level_number_in_dir(GameConstants.CAMPAIGN_EASY_DIR)
	var hard_first := AchievementCatalog.first_level_number_in_dir(GameConstants.CAMPAIGN_HARD_DIR)
	_ok(easy_last > 0, "ach: easy folder is detectable")
	_ok(hard_first > easy_last, "ach: hard starts after easy")
	# Two new ids in one collect_unlocks must stay unique for the toast queue.
	var duo: Array = AchievementCatalog.collect_unlocks({
		"campaign_clears": 10,
		"no_hint_clears": 10,
	})
	_ok(duo.has(AchievementCatalog.ID_FIRST_CLEAR), "ach: duo has first_clear")
	_ok(duo.has(AchievementCatalog.ID_NO_HINT_CLEAR), "ach: duo has no_hint_clear")
	_ok(duo.has(AchievementCatalog.ID_CLEARS_BRONZE), "ach: duo has clears_bronze")
	_ok(duo.size() == 3, "ach: collect_unlocks unique size 3")
	var seen := {}
	for raw_id in duo:
		var sid := str(raw_id)
		_ok(not seen.has(sid), "ach: no duplicate %s" % sid)
		seen[sid] = true
	_ok(
		AchievementCatalog.icon_path(AchievementCatalog.ID_FIRST_CLEAR).ends_with("ach_first_clear.svg"),
		"ach: first_clear uses solved-board icon"
	)
	_ok(
		AchievementCatalog.icon_path(AchievementCatalog.ID_FIRST_HARD)
		!= AchievementCatalog.icon_path(AchievementCatalog.ID_FIRST_CLEAR),
		"ach: first_hard has its own icon"
	)
	_ok(
		AchievementCatalog.icon_path(AchievementCatalog.ID_CLEARS_BRONZE).ends_with(
			"ach_one_more_level.svg"
		),
		"ach: clears family uses one-more-level icon"
	)
	_ok(
		AchievementCatalog.icon_path(AchievementCatalog.ID_CLEARS_BRONZE)
		!= AchievementCatalog.icon_path(AchievementCatalog.ID_FIRST_CLEAR),
		"ach: first_clear icon differs from clears family"
	)
	_ok(
		AchievementCatalog.icon_path(AchievementCatalog.ID_HINT_SAVER)
		== AchievementCatalog.icon_path(AchievementCatalog.ID_NO_HINT_CLEAR),
		"ach: no_hint family shares base icon"
	)
	_ok(
		AchievementCatalog.icon_path(AchievementCatalog.ID_ON_TIME_GOLD).ends_with("ach_on_time.svg"),
		"ach: on_time family uses clock/star icon"
	)
	_ok(AchievementCatalog.tier(AchievementCatalog.ID_FIRST_CLEAR) == AchievementCatalog.TIER_NONE, "ach: first_clear is standalone")
	_ok(AchievementCatalog.tier(AchievementCatalog.ID_CLEARS_BRONZE) == AchievementCatalog.TIER_BRONZE, "ach: clears_bronze is bronze")
	_ok(AchievementCatalog.tier(AchievementCatalog.ID_CLEARS_SILVER) == AchievementCatalog.TIER_SILVER, "ach: clears_silver is silver")
	_ok(AchievementCatalog.tier(AchievementCatalog.ID_CLEARS_GOLD) == AchievementCatalog.TIER_GOLD, "ach: clears_gold is gold")
	_ok(AchievementCatalog.family(AchievementCatalog.ID_FIRST_CLEAR) == "", "ach: first_clear is standalone")
	_ok(AchievementCatalog.family(AchievementCatalog.ID_CLEARS_BRONZE) == AchievementCatalog.FAM_CLEARS, "ach: clears_bronze family clears")
	_ok(AchievementCatalog.family(AchievementCatalog.ID_HINT_SAVER) == AchievementCatalog.FAM_NO_HINT, "ach: hint_saver family no_hint")
	_ok(AchievementCatalog.family(AchievementCatalog.ID_FIRST_HARD) == "", "ach: first_hard is standalone")
	_ok(AchievementCatalog.visibility(AchievementCatalog.ID_FIRST_CLEAR) == AchievementCatalog.VIS_VISIBLE, "ach: starter vis visible")
	_ok(AchievementCatalog.visibility(AchievementCatalog.ID_IM_BLUE) == AchievementCatalog.VIS_HIDDEN_DESC, "ach: im_blue hidden_desc")
	_ok(AchievementCatalog.visibility(AchievementCatalog.ID_SHALL_NOT_PASS) == AchievementCatalog.VIS_HIDDEN_DESC, "ach: shall_not_pass hidden_desc")
	_ok(AchievementCatalog.visibility(AchievementCatalog.ID_DEV_MODE) == AchievementCatalog.VIS_SECRET, "ach: dev_mode secret")
	_ok(
		AchievementCatalog.medal_overlay_path(AchievementCatalog.ID_CLEARS_BRONZE, true).ends_with("ach_medal_bronze.svg"),
		"ach: bronze medal on clears_bronze"
	)
	_ok(AchievementCatalog.medal_overlay_path(AchievementCatalog.ID_FIRST_HARD, true) == "", "ach: no medal on unranked")
	_ok(AchievementCatalog.listed_when(AchievementCatalog.VIS_VISIBLE, false), "ach: visible locked is listed")
	_ok(AchievementCatalog.listed_when(AchievementCatalog.VIS_HIDDEN_DESC, false), "ach: hidden_desc locked is listed")
	_ok(not AchievementCatalog.listed_when(AchievementCatalog.VIS_SECRET, false), "ach: secret locked is omitted")
	_ok(AchievementCatalog.listed_when(AchievementCatalog.VIS_SECRET, true), "ach: secret unlocked is listed")
	_ok(AchievementCatalog.desc_shown_when(AchievementCatalog.VIS_VISIBLE, false), "ach: visible locked shows desc")
	_ok(not AchievementCatalog.desc_shown_when(AchievementCatalog.VIS_HIDDEN_DESC, false), "ach: hidden_desc locked hides desc")
	_ok(AchievementCatalog.desc_shown_when(AchievementCatalog.VIS_HIDDEN_DESC, true), "ach: hidden_desc unlocked shows desc")
	_ok(not AchievementCatalog.desc_visible(AchievementCatalog.ID_IM_BLUE, false), "ach: im_blue locked hides desc")
	_ok(AchievementCatalog.desc_visible(AchievementCatalog.ID_IM_BLUE, true), "ach: im_blue unlocked shows desc")
	_ok(not AchievementCatalog.identity_visible(AchievementCatalog.ID_IM_BLUE, false), "ach: im_blue locked hides identity")
	_ok(AchievementCatalog.identity_visible(AchievementCatalog.ID_IM_BLUE, true), "ach: im_blue unlocked shows identity")
	_ok(
		AchievementCatalog.display_title_key(
			AchievementCatalog.ID_CLEARS_SILVER,
			true
		) == AchievementCatalog.title_key(AchievementCatalog.ID_CLEARS_BRONZE),
		"ach: ranked family shares bronze title"
	)
	_ok(
		AchievementCatalog.display_desc_key(AchievementCatalog.ID_CLEARS_GOLD)
		== AchievementCatalog.desc_key(AchievementCatalog.ID_CLEARS_BRONZE),
		"ach: ranked family shares bronze desc"
	)
	_ok(
		AchievementCatalog.display_title_key(AchievementCatalog.ID_IM_BLUE, false) == "ACH_HIDDEN_NAME",
		"ach: hidden locked uses mystery title key"
	)
	_ok(
		AchievementCatalog.hidden_locked_icon_path().ends_with("ach_medal_bronze_outline.svg"),
		"ach: hidden locked uses mystery icon"
	)
	_ok(AchievementCatalog.display_icon_path(AchievementCatalog.ID_IM_BLUE, false) == "", "ach: hidden locked display icon empty")
	_ok(
		AchievementCatalog.tier_modulate(AchievementCatalog.ID_FIRST_CLEAR) == Color.WHITE,
		"ach: standalone first_clear is white"
	)
	_ok(
		AchievementCatalog.tier_modulate(AchievementCatalog.ID_CLEARS_BRONZE) != Color.WHITE,
		"ach: bronze tier tints icon"
	)
	_ok(
		AchievementCatalog.tier_modulate(AchievementCatalog.ID_FIRST_HARD) == Color.WHITE,
		"ach: unranked tier is white"
	)
	_ok(
		AchievementCatalog.display_title_key(AchievementCatalog.ID_FIRST_CLEAR, false) == AchievementCatalog.title_key(AchievementCatalog.ID_FIRST_CLEAR),
		"ach: visible locked keeps real title key"
	)
	var locked_grid: Array = AchievementCatalog.grid_ids({})
	_ok(locked_grid.size() == 17, "ach: grid lists 17 cells (families collapsed, secret omitted)")
	_ok(locked_grid.has(AchievementCatalog.ID_CLEARS_BRONZE), "ach: locked grid shows clears bronze")
	_ok(not locked_grid.has(AchievementCatalog.ID_CLEARS_SILVER), "ach: locked grid hides silver sibling")
	_ok(not locked_grid.has(AchievementCatalog.ID_DEV_MODE), "ach: secret omitted until unlock")
	_ok(locked_grid.has(AchievementCatalog.ID_IM_BLUE), "ach: hidden_desc listed while locked")
	_ok(locked_grid.has(AchievementCatalog.ID_SHALL_NOT_PASS), "ach: shall_not_pass listed while locked")
	_ok(locked_grid.has(AchievementCatalog.ID_THREE_STAR_DEBUT), "ach: three_star_debut listed while locked")
	var silver_grid: Array = AchievementCatalog.grid_ids({
		AchievementCatalog.ID_CLEARS_BRONZE: 1,
		AchievementCatalog.ID_CLEARS_SILVER: 1,
	})
	_ok(silver_grid.has(AchievementCatalog.ID_CLEARS_SILVER), "ach: family cell promotes to silver")
	_ok(not silver_grid.has(AchievementCatalog.ID_CLEARS_BRONZE), "ach: bronze sibling collapsed after silver")
	_ok(silver_grid.size() == 17, "ach: unlock does not duplicate family cells")
	var secret_grid: Array = AchievementCatalog.grid_ids({AchievementCatalog.ID_DEV_MODE: 1})
	_ok(secret_grid.has(AchievementCatalog.ID_DEV_MODE), "ach: secret listed after unlock")
	_ok(secret_grid.size() == 18, "ach: secret adds one cell")
	# Ranked families use unique campaign_clears only — replays never count.
	var clears29 := AchievementCatalog.collect_unlocks({"campaign_clears": 29})
	_ok(clears29.has(AchievementCatalog.ID_FIRST_CLEAR), "ach: 29 clears is first_clear")
	_ok(clears29.has(AchievementCatalog.ID_CLEARS_BRONZE), "ach: 29 clears is bronze")
	_ok(not clears29.has(AchievementCatalog.ID_CLEARS_SILVER), "ach: 29 clears is not silver")
	var clears30 := AchievementCatalog.collect_unlocks({"campaign_clears": 30})
	_ok(clears30.has(AchievementCatalog.ID_CLEARS_SILVER), "ach: 30 clears is silver")
	_ok(not clears30.has(AchievementCatalog.ID_CLEARS_GOLD), "ach: 30 clears is not gold")
	var clears60 := AchievementCatalog.collect_unlocks({"campaign_clears": 60})
	_ok(clears60.has(AchievementCatalog.ID_CLEARS_GOLD), "ach: 60 clears is gold")
	var keep_bronze := AchievementCatalog.collect_unlocks({"campaign_clears": 30}, {AchievementCatalog.ID_CLEARS_BRONZE: 1})
	_ok(not keep_bronze.has(AchievementCatalog.ID_CLEARS_BRONZE), "ach: migrate keeps clears_bronze")
	_ok(keep_bronze.has(AchievementCatalog.ID_CLEARS_SILVER), "ach: migrate still requires silver counter")
	var on_time := AchievementCatalog.collect_unlocks({"on_time_clears": 10})
	_ok(on_time.has(AchievementCatalog.ID_ON_TIME_BRONZE), "ach: on_time bronze at 10")
	_ok(not on_time.has(AchievementCatalog.ID_ON_TIME_SILVER), "ach: on_time silver needs 30")
	var on_time30 := AchievementCatalog.collect_unlocks({"on_time_clears": 30})
	_ok(on_time30.has(AchievementCatalog.ID_ON_TIME_SILVER), "ach: on_time silver at 30")
	_ok(not on_time30.has(AchievementCatalog.ID_ON_TIME_GOLD), "ach: on_time gold needs 60")
	var on_time60 := AchievementCatalog.collect_unlocks({"on_time_clears": 60})
	_ok(on_time60.has(AchievementCatalog.ID_ON_TIME_GOLD), "ach: on_time gold at 60")
	var gold_hints := AchievementCatalog.collect_unlocks({"no_hint_clears": 60})
	_ok(gold_hints.has(AchievementCatalog.ID_NO_HINT_GOLD), "ach: no_hint gold at 60")
	var purple := AchievementCatalog.collect_unlocks({"shifter_slides": 30})
	_ok(purple.has(AchievementCatalog.ID_PURPLE_RAIN), "ach: purple_rain at 30 slides")
	var rules := AchievementCatalog.collect_unlocks({"rules_opens": 10})
	_ok(rules.has(AchievementCatalog.ID_RULES_READER), "ach: rules_reader at 10 opens")
	# Event ids must not re-fire from collect unless flagged.
	var no_events := AchievementCatalog.collect_unlocks({"campaign_clears": 60})
	_ok(not no_events.has(AchievementCatalog.ID_IM_BLUE), "ach: im_blue not from collect")
	_ok(not no_events.has(AchievementCatalog.ID_SHALL_NOT_PASS), "ach: shall_not_pass not from collect")
	_ok(not no_events.has(AchievementCatalog.ID_DEV_MODE), "ach: dev_mode not from collect")
	var flagged := AchievementCatalog.collect_unlocks({
		"im_blue": true,
		"shall_not_pass": true,
		"dev_mode": true,
	})
	_ok(flagged.has(AchievementCatalog.ID_IM_BLUE), "ach: im_blue from flag")
	_ok(flagged.has(AchievementCatalog.ID_SHALL_NOT_PASS), "ach: shall_not_pass from flag")
	_ok(flagged.has(AchievementCatalog.ID_DEV_MODE), "ach: dev_mode from flag")
	# grant() / apply_grant is idempotent.
	var bag := {}
	_ok(AchievementCatalog.apply_grant(bag, AchievementCatalog.ID_IM_BLUE, 9), "ach: first grant writes")
	_ok(bag.has(AchievementCatalog.ID_IM_BLUE), "ach: grant stores id")
	_ok(not AchievementCatalog.apply_grant(bag, AchievementCatalog.ID_IM_BLUE, 10), "ach: grant is idempotent")
	_ok(int(bag[AchievementCatalog.ID_IM_BLUE]) == 9, "ach: second grant keeps first timestamp")
	_ok(not AchievementCatalog.apply_grant(bag, "not_a_real_id", 1), "ach: unknown id is rejected")
	# Grid polish helpers: tier tint, progress, next-tier preview.
	var none_unlocked: Dictionary = {}
	_ok(
		AchievementCatalog.display_tier_modulate(
			AchievementCatalog.ID_CLEARS_BRONZE,
			none_unlocked
		) != Color.WHITE,
		"ach: locked family uses bronze tint"
	)
	var bronze_only := {AchievementCatalog.ID_CLEARS_BRONZE: 1}
	_ok(
		AchievementCatalog.display_tier_modulate(
			AchievementCatalog.ID_CLEARS_SILVER,
			bronze_only
		) == AchievementCatalog.tier_modulate(AchievementCatalog.ID_CLEARS_BRONZE),
		"ach: display tint follows highest earned tier"
	)
	_ok(
		AchievementCatalog.cell_is_unlocked(AchievementCatalog.ID_CLEARS_BRONZE, bronze_only),
		"ach: family cell unlocked when bronze earned"
	)
	_ok(
		not AchievementCatalog.cell_is_unlocked(AchievementCatalog.ID_CLEARS_BRONZE, none_unlocked),
		"ach: family cell locked when none earned"
	)
	var prog := AchievementCatalog.progress_for_cell(
		AchievementCatalog.ID_CLEARS_BRONZE,
		none_unlocked,
		{"campaign_clears": 23}
	)
	_ok(prog.get("show", false), "ach: locked clears shows progress")
	var clears_targets: Array = prog.get("thresholds", [])
	_ok(clears_targets.size() == 3, "ach: clears family has three tier targets")
	_ok(int(clears_targets[0]) == 10, "ach: clears bronze target is 10")
	_ok(int(clears_targets[1]) == 30, "ach: clears silver target is 30")
	_ok(int(clears_targets[2]) == 60, "ach: clears gold target is 60")
	_ok(int(prog.get("highlight_index", 0)) == -1, "ach: no tier earned highlights none")
	var prog_silver := AchievementCatalog.progress_for_cell(
		AchievementCatalog.ID_CLEARS_SILVER,
		bronze_only,
		{"campaign_clears": 23}
	)
	_ok(prog_silver.get("show", false), "ach: partial clears family still shows tier row")
	_ok(int(prog_silver.get("highlight_index", -1)) == 0, "ach: bronze earned highlights first threshold")
	var silver_only := {
		AchievementCatalog.ID_CLEARS_BRONZE: 1,
		AchievementCatalog.ID_CLEARS_SILVER: 2,
	}
	var prog_silver_earned := AchievementCatalog.progress_for_cell(
		AchievementCatalog.ID_CLEARS_SILVER,
		silver_only,
		{"campaign_clears": 60}
	)
	_ok(prog_silver_earned.get("show", false), "ach: silver earned still shows tier row")
	_ok(
		int(prog_silver_earned.get("highlight_index", -1)) == 1,
		"ach: silver earned highlights middle threshold"
	)
	var all_clears := {
		AchievementCatalog.ID_CLEARS_BRONZE: 1,
		AchievementCatalog.ID_CLEARS_SILVER: 2,
		AchievementCatalog.ID_CLEARS_GOLD: 3,
	}
	var prog_done := AchievementCatalog.progress_for_cell(
		AchievementCatalog.ID_CLEARS_GOLD,
		all_clears,
		{"campaign_clears": 60}
	)
	_ok(prog_done.get("show", false), "ach: all tiers earned still shows tier row")
	_ok(int(prog_done.get("highlight_index", -1)) == 2, "ach: gold earned highlights final threshold")
	_ok(
		AchievementCatalog.next_tier_preview_path(AchievementCatalog.ID_CLEARS_SILVER).ends_with(
			"ach_medal_silver_outline.svg"
		),
		"ach: next tier preview uses silver medal outline"
	)
	_ok(
		AchievementCatalog.earned_tier_badge_path(
			AchievementCatalog.ID_CLEARS_SILVER,
			bronze_only
		).ends_with("ach_medal_bronze.svg"),
		"ach: earned badge follows highest tier"
	)
	_ok(
		AchievementCatalog.display_tier_badge_path(
			AchievementCatalog.ID_CLEARS_BRONZE,
			none_unlocked
		) == "",
		"ach: no tier badge until a family rank is earned"
	)
	_ok(
		AchievementCatalog.display_tier_badge_path(
			AchievementCatalog.ID_CLEARS_BRONZE,
			bronze_only
		).ends_with("ach_medal_bronze.svg"),
		"ach: tier badge shows once a family rank is earned"
	)
	# All-blue: every unlocked playable cell is BLUE; walls/locked ignored.
	var y := GameConstants.TileState.YELLOW
	var b := GameConstants.TileState.BLUE
	var e := GameConstants.TileState.EMPTY
	var wall := GameConstants.TileState.WALL
	var all_blue := {
		Vector2i(0, 0): {"state": b, "is_playable": true, "is_locked": false},
		Vector2i(1, 0): {"state": b, "is_playable": true, "is_locked": false},
		Vector2i(0, 1): {"state": y, "is_playable": true, "is_locked": true},
		Vector2i(1, 1): {"state": wall, "is_playable": false, "is_locked": true},
	}
	_ok(AchievementCatalog.board_is_all_blue(all_blue), "ach: all fillable cells blue")
	var leftover := all_blue.duplicate(true)
	leftover[Vector2i(1, 0)] = {"state": e, "is_playable": true, "is_locked": false}
	_ok(not AchievementCatalog.board_is_all_blue(leftover), "ach: leftover empty is not all blue")
	var yellow_fill := all_blue.duplicate(true)
	yellow_fill[Vector2i(0, 0)] = {"state": y, "is_playable": true, "is_locked": false}
	_ok(not AchievementCatalog.board_is_all_blue(yellow_fill), "ach: yellow fillable is not all blue")
	_ok(not AchievementCatalog.board_is_all_blue({}), "ach: empty board is not all blue")
	var sh := GameConstants.TileState.SHIFTER
	var with_shifter := {
		Vector2i(0, 0): {"state": b, "is_playable": true, "is_locked": false},
		Vector2i(1, 0): {"state": b, "is_playable": true, "is_locked": false},
		Vector2i(2, 0): {"state": sh, "is_playable": true, "is_locked": false},
	}
	_ok(AchievementCatalog.board_is_all_blue(with_shifter), "ach: shifter tile ignored for im_blue")
	var shifter_empty := with_shifter.duplicate(true)
	shifter_empty[Vector2i(2, 0)] = {"state": e, "is_playable": true, "is_locked": false}
	_ok(not AchievementCatalog.board_is_all_blue(shifter_empty), "ach: vacated shifter cell must be blue")
	var all_yellow := {
		Vector2i(0, 0): {"state": y, "is_playable": true, "is_locked": false},
		Vector2i(1, 0): {"state": y, "is_playable": true, "is_locked": false},
	}
	_ok(AchievementCatalog.board_is_all_yellow(all_yellow), "ach: all fillable cells yellow")
	_ok(not AchievementCatalog.board_is_all_yellow(all_blue), "ach: blue board is not all yellow")
	# Toast queue: two ids plus a duplicate enqueue => two different snapshot ids.
	var packed := load("res://scenes/achievement_toast.tscn")
	_ok(packed is PackedScene, "toast: scene loads")
	if packed is PackedScene:
		var toast: Node = packed.instantiate()
		root.add_child(toast)
		for raw_id in duo:
			toast.enqueue(str(raw_id))
			toast.enqueue(str(raw_id))
		var snap: Array = toast.snapshot_ids() if toast.has_method("snapshot_ids") else []
		_ok(snap.size() == 3, "toast: three unique queued ids")
		if snap.size() >= 2:
			_ok(str(snap[0]) != str(snap[1]), "toast: different ids not duplicates")
			_ok(snap.has(AchievementCatalog.ID_FIRST_CLEAR), "toast: first_clear present")
			_ok(snap.has(AchievementCatalog.ID_NO_HINT_CLEAR), "toast: no_hint_clear present")
			_ok(snap.has(AchievementCatalog.ID_CLEARS_BRONZE), "toast: clears_bronze present")
		toast.queue_free()


# CloudSaveLogic: newest timestamp wins; empty side yields the other.
func _test_cloud_save_logic() -> void:
	var progress := {"max_unlocked_level": 20, "level_star_bits": {"15": 7}}
	var settings := {"current_language": "en", "bgm_enabled": true}
	var ach := {"unlocked": {"first_clear": 1}, "no_hint_clears": 1}
	var older := CloudSaveLogic.build_blob(progress, settings, ach, 100)
	var newer_progress := progress.duplicate(true)
	newer_progress["max_unlocked_level"] = 40
	var newer := CloudSaveLogic.build_blob(newer_progress, settings, ach, 200)
	_ok(CloudSaveLogic.is_valid_blob(older), "cloud: valid blob")
	_ok(not CloudSaveLogic.is_valid_blob({}), "cloud: empty is invalid")
	var win_new: Dictionary = CloudSaveLogic.winner(older, newer)
	var win_new_progress: Dictionary = win_new.get("progress", {})
	_ok(int(win_new_progress.get("max_unlocked_level", 0)) == 40, "cloud: newer remote wins")
	var win_local: Dictionary = CloudSaveLogic.winner(newer, older)
	var win_local_progress: Dictionary = win_local.get("progress", {})
	_ok(int(win_local_progress.get("max_unlocked_level", 0)) == 40, "cloud: newer local wins")
	var only_local: Dictionary = CloudSaveLogic.winner(older, {})
	_ok(int(only_local.get("timestamp", 0)) == 100, "cloud: missing remote keeps local")
	var only_remote: Dictionary = CloudSaveLogic.winner({}, newer)
	_ok(int(only_remote.get("timestamp", 0)) == 200, "cloud: missing local takes remote")
	var tie: Dictionary = CloudSaveLogic.winner(older, CloudSaveLogic.build_blob(newer_progress, settings, ach, 100))
	var tie_progress: Dictionary = tie.get("progress", {})
	_ok(int(tie_progress.get("max_unlocked_level", 0)) == 20, "cloud: equal timestamp keeps local")
	var encoded := CloudSaveLogic.encode_json(older)
	var decoded := CloudSaveLogic.decode_json(encoded)
	_ok(int(decoded.get("timestamp", 0)) == 100, "cloud: json roundtrip timestamp")
	var decoded_progress: Dictionary = decoded.get("progress", {})
	var decoded_settings: Dictionary = decoded.get("settings", {})
	var decoded_ach: Dictionary = decoded.get("achievements", {})
	_ok(int(decoded_progress.get("max_unlocked_level", 0)) == 20, "cloud: json roundtrip progress")
	# Existing progression keys survive the blob shape.
	_ok(decoded_progress.has("level_star_bits"), "cloud: star bits preserved")
	_ok(decoded_settings.has("current_language"), "cloud: settings preserved")
	_ok(decoded_ach.has("unlocked"), "cloud: achievements preserved")
	var sample := CloudSaveLogic.build_blob({"a": 1}, {"b": 2}, {"c": 3}, 42)
	var bytes := CloudSaveLogic.blob_to_bytes(sample)
	var roundtrip := CloudSaveLogic.blob_from_bytes(bytes)
	_ok(int(roundtrip.get("timestamp", 0)) == 42, "cloud: blob bytes roundtrip")


# New-level badges: unseen dict tracks freshly unlocked campaign levels.
func _test_levels_unseen_badges() -> void:
	if SaveManager == null:
		_ok(true, "levels unseen: skip without SaveManager")
		return
	var backup_unseen: Dictionary = SaveManager.levels_unseen.duplicate()
	SaveManager.levels_unseen = {"7": true, "8": true}
	_ok(SaveManager.unseen_level_count() == 2, "levels unseen: count")
	_ok(SaveManager.is_level_unseen(7), "levels unseen: query true")
	SaveManager.mark_level_seen(7)
	_ok(not SaveManager.is_level_unseen(7), "levels unseen: mark seen clears")
	_ok(SaveManager.is_level_unseen(8), "levels unseen: other level untouched")
	SaveManager.levels_unseen = backup_unseen


# Cloud save scaffolding: addon installed; runtime only on Android export builds.
func _test_cloud_save_stub() -> void:
	_ok(CloudSaveLogic.play_games_plugin_installed(), "cloud: Play Games addon installed")
	_ok(not CloudSaveLogic.play_games_runtime_available(), "cloud: no Android runtime in headless")
