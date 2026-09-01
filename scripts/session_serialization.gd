class_name SessionSerialization
extends RefCounted
## ConfigFile-safe serialize/deserialize for in-progress game sessions.


static func serialize_session(data: Dictionary) -> Dictionary:
	return {
		"level_path": str(data.get("level_path", "")),
		"level_number": int(data.get("level_number", 0)),
		"elapsed_seconds": int(data.get("elapsed_seconds", 0)),
		"shifter_move_count": int(data.get("shifter_move_count", 0)),
		"hints_used": int(data.get("hints_used", 0)),
		"required_jokers": int(data.get("required_jokers", 0)),
		"required_shifter_moves": int(data.get("required_shifter_moves", 0)),
		"has_shifters": bool(data.get("has_shifters", false)),
		"prefer_hidden_hints": bool(data.get("prefer_hidden_hints", false)),
		"challenges_disabled": bool(data.get("challenges_disabled", false)),
		"star_time_limit": int(data.get("star_time_limit", 0)),
		"hints_remaining": int(data.get("hints_remaining", GameConstants.HINT_LIMIT_UNLIMITED)),
		"available_tiles": data.get("available_tiles", [0, 1, 2]).duplicate(),
		"layout": _serialize_coord_dict(data.get("layout", {})),
		"shifter_pairs": _serialize_pairs(data.get("shifter_pairs", [])),
		"active_constraint_pairs": _serialize_pairs(data.get("active_constraint_pairs", [])),
		"hidden_reference_constraints": _serialize_pairs(data.get("hidden_reference_constraints", [])),
		"solved_solution_reference": _serialize_coord_dict(data.get("solved_solution_reference", {})),
		"cells": _serialize_cells(data.get("cells", {})),
		"undo_history": _serialize_undo_history(data.get("undo_history", {})),
	}


static func deserialize_session(data: Dictionary) -> Dictionary:
	return {
		"level_path": str(data.get("level_path", "")),
		"level_number": int(data.get("level_number", 0)),
		"elapsed_seconds": int(data.get("elapsed_seconds", 0)),
		"shifter_move_count": int(data.get("shifter_move_count", 0)),
		"hints_used": int(data.get("hints_used", 0)),
		"required_jokers": int(data.get("required_jokers", 0)),
		"required_shifter_moves": int(data.get("required_shifter_moves", 0)),
		"has_shifters": bool(data.get("has_shifters", false)),
		"prefer_hidden_hints": bool(data.get("prefer_hidden_hints", false)),
		"challenges_disabled": bool(data.get("challenges_disabled", false)),
		"star_time_limit": int(data.get("star_time_limit", 0)),
		"hints_remaining": int(data.get("hints_remaining", GameConstants.HINT_LIMIT_UNLIMITED)),
		"has_hints_remaining": data.has("hints_remaining"),
		"available_tiles": data.get("available_tiles", [0, 1, 2]).duplicate(),
		"layout": _deserialize_coord_dict(data.get("layout", {})),
		"shifter_pairs": _deserialize_pairs(data.get("shifter_pairs", [])),
		"active_constraint_pairs": _deserialize_pairs(data.get("active_constraint_pairs", [])),
		"hidden_reference_constraints": _deserialize_pairs(data.get("hidden_reference_constraints", [])),
		"solved_solution_reference": _deserialize_coord_dict(data.get("solved_solution_reference", {})),
		"cells": _deserialize_cells(data.get("cells", {})),
		"undo_history": _deserialize_undo_history(data.get("undo_history", {})),
	}


static func _coord_key(v: Vector2i) -> String:
	return "%d,%d" % [v.x, v.y]


static func _parse_coord_key(s: String) -> Vector2i:
	var parts := str(s).split(",")
	if parts.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


static func _serialize_vec(v: Vector2i) -> Array:
	return [v.x, v.y]


static func _deserialize_vec(val: Variant) -> Vector2i:
	if typeof(val) == TYPE_VECTOR2I:
		return val
	if typeof(val) == TYPE_ARRAY and val.size() >= 2:
		return Vector2i(int(val[0]), int(val[1]))
	return Vector2i.ZERO


static func _serialize_coord_dict(src: Dictionary) -> Dictionary:
	var out := {}
	for key in src:
		var k: String = str(key) if typeof(key) == TYPE_STRING else _coord_key(key as Vector2i)
		out[k] = src[key]
	return out


static func _deserialize_coord_dict(src: Dictionary) -> Dictionary:
	var out := {}
	for key in src:
		out[_parse_coord_key(str(key))] = src[key]
	return out


static func _serialize_pairs(pairs: Array) -> Array:
	var out: Array = []
	for pair in pairs:
		if typeof(pair) != TYPE_DICTIONARY:
			continue
		var d := {}
		for key in pair:
			var val = pair[key]
			if typeof(val) == TYPE_VECTOR2I:
				d[key] = _serialize_vec(val)
			else:
				d[key] = val
		out.append(d)
	return out


static func _deserialize_pairs(pairs: Array) -> Array:
	var out: Array = []
	for pair in pairs:
		if typeof(pair) != TYPE_DICTIONARY:
			continue
		var d := {}
		for key in pair:
			var val = pair[key]
			if key == "type" or key == "state":
				d[key] = val
			elif typeof(val) == TYPE_ARRAY or typeof(val) == TYPE_VECTOR2I:
				d[key] = _deserialize_vec(val)
			else:
				d[key] = val
		out.append(d)
	return out


static func _serialize_cells(cells: Dictionary) -> Dictionary:
	var out := {}
	for key in cells:
		var k: String = str(key) if typeof(key) == TYPE_STRING else _coord_key(key as Vector2i)
		var entry = cells[key]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var dir_val = entry.get("shifter_direction", Vector2i.ZERO)
		var dir: Vector2i = dir_val if typeof(dir_val) == TYPE_VECTOR2I else _deserialize_vec(dir_val)
		out[k] = {
			"state": int(entry.get("state", 0)),
			"shifter_direction": _serialize_vec(dir),
		}
	return out


static func _deserialize_cells(cells: Dictionary) -> Dictionary:
	var out := {}
	for key in cells:
		var entry = cells[key]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		out[_parse_coord_key(str(key))] = {
			"state": int(entry.get("state", 0)),
			"shifter_direction": _deserialize_vec(entry.get("shifter_direction", [0, 0])),
		}
	return out


static func _serialize_undo_history(history: Dictionary) -> Dictionary:
	if history.is_empty():
		return {}
	return {
		"current": _serialize_game_snapshot(history.get("current", {})),
		"undo": _serialize_snapshot_list(history.get("undo", [])),
		"redo": _serialize_snapshot_list(history.get("redo", [])),
	}


static func _deserialize_undo_history(history: Dictionary) -> Dictionary:
	if history.is_empty():
		return {}
	return {
		"current": _deserialize_game_snapshot(history.get("current", {})),
		"undo": _deserialize_snapshot_list(history.get("undo", [])),
		"redo": _deserialize_snapshot_list(history.get("redo", [])),
	}


static func _serialize_snapshot_list(snaps: Array) -> Array:
	var out: Array = []
	for snap in snaps:
		if snap is Dictionary:
			out.append(_serialize_game_snapshot(snap))
	return out


static func _deserialize_snapshot_list(snaps: Array) -> Array:
	var out: Array = []
	for snap in snaps:
		if snap is Dictionary:
			out.append(_deserialize_game_snapshot(snap))
	return out


static func _serialize_game_snapshot(snap: Dictionary) -> Dictionary:
	return {
		"moves": int(snap.get("moves", 0)),
		"cells": _serialize_cells(snap.get("cells", {})),
	}


static func _deserialize_game_snapshot(snap: Dictionary) -> Dictionary:
	return {
		"moves": int(snap.get("moves", 0)),
		"cells": _deserialize_cells(snap.get("cells", {})),
	}
