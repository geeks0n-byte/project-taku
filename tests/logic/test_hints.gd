extends RefCounted

const LogicTestRunner := preload("res://tests/logic_test_runner.gd")

static func run(r: LogicTestRunner) -> void:
	_test_hint_selection_policy(r)
	_test_hint_unique_pool_only(r)
	_test_hold_repeat(r)

static func _mock_cell(state: int, locked: bool = false) -> Dictionary:
	return {"state": state, "is_locked": locked}

static func _test_hint_selection_policy(r: LogicTestRunner) -> void:
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
	var pick: Variant = HintSystem.pick_hint(board, [], solved, [], Vector2i(4, 2), false, tiles)
	r.ok(pick != null, "hint: finds an open-pair hint")
	if pick != null:
		var a: Vector2i = pick["a"]
		var bcoord: Vector2i = pick["b"]
		var a_empty: bool = int(board[a].state) == e
		var b_empty: bool = int(board[bcoord].state) == e
		r.ok(a_empty or b_empty, "hint: involves an empty cell")
		var both_correct := (
			not a_empty and not b_empty
			and int(board[a].state) == int(solved[a])
			and int(board[bcoord].state) == int(solved[bcoord])
		)
		r.ok(not both_correct, "hint: does not reveal an already-correct pair")

	board[Vector2i(1, 0)] = _mock_cell(y, false)
	var pick_wrong: Variant = HintSystem.pick_hint(board, [], solved, [], Vector2i(4, 2), false, tiles)
	r.ok(pick_wrong != null, "hint: still finds a hint with a wrong cell")
	if pick_wrong != null:
		r.ok(
			HintSystem._involves_wrong_cell(board, solved, pick_wrong),
			"hint: prefers a pair involving the wrong cell"
		)

	board[Vector2i(1, 0)] = _mock_cell(e)
	var usable := HintSystem.count_usable_hints(board, [], solved, [], Vector2i(4, 2), false)
	r.ok(usable > 0, "hint: usable count is positive while empties remain")

	board[Vector2i(1, 0)] = _mock_cell(b)
	board[Vector2i(2, 0)] = _mock_cell(y)
	board[Vector2i(1, 1)] = _mock_cell(y)
	board[Vector2i(2, 1)] = _mock_cell(b)
	r.ok(
		HintSystem.count_usable_hints(board, [], solved, [], Vector2i(4, 2), false) == 0,
		"hint: no usable hints when the board is already correct"
	)
	r.ok(
		HintSystem.pick_hint(board, [], solved, [], Vector2i(4, 2), false, tiles) == null,
		"hint: pick is null when nothing would advance the player"
	)

static func _test_hint_unique_pool_only(r: LogicTestRunner) -> void:
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
	var pool: Array = [{"a": Vector2i(1, 0), "b": Vector2i(2, 0), "type": "not_equals"}]
	var pick: Variant = HintSystem.pick_hint(board, [], solved, pool, Vector2i(4, 2), true, tiles)
	r.ok(pick != null, "unique-pool: finds a hint from the designed pool")
	if pick != null:
		var key := HintSystem._pair_key(pick["a"], pick["b"])
		r.ok(key == HintSystem._pair_key(Vector2i(1, 0), Vector2i(2, 0)), "unique-pool: pick is the only pool member")
		r.ok(str(pick["type"]) == "not_equals", "unique-pool: preserves pool relationship")

	board[Vector2i(1, 0)] = _mock_cell(y, false)
	board[Vector2i(2, 0)] = _mock_cell(y, false)
	var filled_pool: Array = [
		{"a": Vector2i(2, 1), "b": Vector2i(3, 1), "type": "not_equals"},
		{"a": Vector2i(1, 0), "b": Vector2i(2, 0), "type": "not_equals"},
	]
	var pick_wrong: Variant = HintSystem.pick_hint(
		board, [], solved, filled_pool, Vector2i(4, 2), true, tiles
	)
	r.ok(pick_wrong != null, "unique-pool: still finds a hint with a wrong cell")
	if pick_wrong != null:
		var wkey := HintSystem._pair_key(pick_wrong["a"], pick_wrong["b"])
		r.ok(
			wkey == HintSystem._pair_key(Vector2i(1, 0), Vector2i(2, 0)),
			"unique-pool: prefers wrong-fill within the pool"
		)
		r.ok(
			HintSystem._involves_wrong_cell(board, solved, pick_wrong),
			"unique-pool: chosen pool member involves the wrong cell"
		)

	board[Vector2i(1, 0)] = _mock_cell(e)
	r.ok(
		HintSystem.pick_hint(board, [], solved, [], Vector2i(4, 2), true, tiles) == null,
		"unique-pool: empty pool does not invent outside links"
	)
	r.ok(
		HintSystem.count_usable_hints(board, [], solved, [], Vector2i(4, 2), true) == 0,
		"unique-pool: empty pool usable count is zero"
	)

	r.ok(
		HintSystem.pick_hint(board, [], solved, [], Vector2i(4, 2), false, tiles) != null,
		"unique-pool: invent path still works when prefer_hidden is false"
	)

static func _test_hold_repeat(r: LogicTestRunner) -> void:
	var h := HoldRepeat.new()
	r.ok(not h.is_active(), "hold: idle is inactive")
	r.ok(not h.is_undo() and not h.is_redo(), "hold: idle is neither side")
	r.ok(not h.tick(1.0), "hold: idle tick does not fire")

	h.start_undo()
	r.ok(h.is_active() and h.is_undo() and not h.is_redo(), "hold: start_undo")
	r.ok(not h.tick(HoldRepeat.INITIAL_DELAY), "hold: at delay, interval not elapsed")
	r.ok(not h.tick(HoldRepeat.REPEAT_START - 0.001), "hold: just before first repeat")
	r.ok(h.tick(0.002), "hold: first undo repeat fires")
	r.ok(not h.tick(h.interval - 0.001), "hold: waits accelerated interval")
	r.ok(h.tick(0.002), "hold: second undo repeat fires")

	h.stop_undo()
	r.ok(not h.is_active(), "hold: stop_undo clears undo")
	r.ok(not h.tick(1.0), "hold: stopped undo does not fire")

	h.start_redo()
	h.start_undo()
	r.ok(h.is_undo() and not h.is_redo(), "hold: start_undo replaces redo")
	h.stop_redo()
	r.ok(h.is_undo(), "hold: stop_redo leaves undo")
	h.stop_undo()

	h.start_redo()
	r.ok(h.is_redo() and not h.is_undo(), "hold: start_redo")
	h.stop_undo()
	r.ok(h.is_redo(), "hold: stop_undo leaves redo")
	r.ok(not h.tick(HoldRepeat.INITIAL_DELAY), "hold: redo at delay, interval not elapsed")
	r.ok(not h.tick(HoldRepeat.REPEAT_START - 0.001), "hold: redo just before first repeat")
	r.ok(h.tick(0.002), "hold: redo fires after delay+start")
	h.stop_redo()
	r.ok(not h.is_active(), "hold: stop_redo clears redo")

	h.start_undo()
	for _i in 40:
		h.tick(10.0)
	r.ok(h.interval >= HoldRepeat.REPEAT_MIN, "hold: interval never below REPEAT_MIN")
	r.ok(is_equal_approx(h.interval, HoldRepeat.REPEAT_MIN), "hold: interval floors at REPEAT_MIN")
