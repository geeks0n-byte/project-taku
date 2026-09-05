extends RefCounted

const LogicTestRunner := preload("res://tests/logic_test_runner.gd")
const SessionSerialization := preload("res://scripts/session_serialization.gd")


static func run(r: LogicTestRunner) -> void:
	_test_session_roundtrip(r)


static func _test_session_roundtrip(r: LogicTestRunner) -> void:
	var layout := {
		Vector2i(0, 0): 1,
		Vector2i(1, 0): 2,
	}
	var cells := {
		Vector2i(0, 0): {"state": 1, "shifter_direction": Vector2i.ZERO},
		Vector2i(1, 0): {"state": 2, "shifter_direction": Vector2i(1, 0)},
	}
	var payload := {
		"level_path": "res://levels/easy/level_01.tres",
		"level_number": 1,
		"elapsed_seconds": 42,
		"shifter_move_count": 3,
		"hints_used": 1,
		"required_jokers": 0,
		"required_shifter_moves": 2,
		"has_shifters": true,
		"prefer_hidden_hints": true,
		"challenges_disabled": false,
		"star_time_limit": 120,
		"hints_remaining": 2,
		"available_tiles": [0, 1, 2],
		"layout": layout,
		"shifter_pairs": [],
		"active_constraint_pairs": [],
		"hidden_reference_constraints": [],
		"solved_solution_reference": {},
		"cells": cells,
		"undo_history": {},
	}
	var stored: Dictionary = SessionSerialization.serialize_session(payload)
	r.ok(not stored.is_empty(), "session: serialize non-empty")
	var restored: Dictionary = SessionSerialization.deserialize_session(stored)
	r.ok(str(restored.get("level_path", "")) == payload["level_path"], "session: level_path roundtrip")
	r.ok(int(restored.get("elapsed_seconds", 0)) == 42, "session: elapsed roundtrip")
	r.ok(restored.get("layout", {}) is Dictionary, "session: layout dict")
	r.ok((restored.get("layout", {}) as Dictionary).has(Vector2i(0, 0)), "session: layout Vector2i key")
	r.ok(restored.get("cells", {}) is Dictionary, "session: cells dict")
	var cell: Dictionary = (restored.get("cells", {}) as Dictionary).get(Vector2i(1, 0), {})
	r.ok(int(cell.get("state", 0)) == 2, "session: cell state")
	var dir: Vector2i = cell.get("shifter_direction", Vector2i.ZERO)
	r.ok(dir == Vector2i(1, 0), "session: shifter direction")
