class_name LevelUtils
extends RefCounted

static func get_dimensions_from_layout(layout: Dictionary, fallback_w: int = 6, fallback_h: int = 6) -> Vector2i:
	if layout.is_empty():
		return Vector2i(fallback_w, fallback_h)
	var max_x := 0
	var max_y := 0
	for coord in layout.keys():
		if coord.x > max_x:
			max_x = coord.x
		if coord.y > max_y:
			max_y = coord.y
	return Vector2i(max_x + 1, max_y + 1)

static func get_dimensions_from_level(level: LevelData) -> Vector2i:
	if level.layout.size() > 0:
		return get_dimensions_from_layout(level.layout)
	return Vector2i(level.width, level.height)

static func get_dimensions_from_cells(board_cells: Dictionary) -> Vector2i:
	var max_x := 0
	var max_y := 0
	for coord in board_cells.keys():
		if coord.x > max_x:
			max_x = coord.x
		if coord.y > max_y:
			max_y = coord.y
	return Vector2i(max_x + 1, max_y + 1)

static func count_jokers_in_layout(layout: Dictionary) -> int:
	var count := 0
	for coord in layout:
		if layout[coord] == GameConstants.TileState.JOKER:
			count += 1
	return count

static func count_unlocked_jokers(board_cells: Dictionary) -> int:
	var count := 0
	for coord in board_cells:
		var cell = board_cells[coord]
		if cell.state == GameConstants.TileState.JOKER and not cell.is_locked:
			count += 1
	return count

static func calculate_required_jokers(saved_required: int, grid_w: int, grid_h: int, prefilled: int) -> int:
	var total := saved_required
	if total == -1:
		total = mini(grid_w, grid_h)
	return maxi(0, total - prefilled)

static func build_solve_layout(board_cells: Dictionary) -> Dictionary:
	var solve_layout := {}
	var empty_cells: Array = []
	for coord in board_cells:
		var cell = board_cells[coord]
		if cell.state == GameConstants.TileState.SHIFTER:
			solve_layout[coord] = GameConstants.TileState.EMPTY
			empty_cells.append(coord)
		else:
			solve_layout[coord] = cell.state
			if cell.state == GameConstants.TileState.EMPTY:
				empty_cells.append(coord)
	return {"layout": solve_layout, "empty_cells": empty_cells}

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

static func is_constraint_in_list(a: Vector2i, b: Vector2i, list: Array) -> bool:
	for pair in list:
		if (pair["a"] == a and pair["b"] == b) or (pair["a"] == b and pair["b"] == a):
			return true
	return false

static func center_board_y(grid_height: int, cell_size: float, screen_height: float) -> float:
	var board_pixel_height := grid_height * cell_size
	if grid_height <= 7:
		var centered := (screen_height / 3.0) - (board_pixel_height / 2.0)
		return maxf(centered, GameConstants.TOP_HUD_BOTTOM + GameConstants.BOARD_GAP)
	return GameConstants.TOP_HUD_BOTTOM + GameConstants.BOARD_GAP

static func center_board_x(grid_width: int, cell_size: float, screen_width: float) -> float:
	var board_pixel_width := grid_width * cell_size
	return (screen_width - board_pixel_width) / 2.0

static func get_shifter_pairs(level: LevelData) -> Array:
	if "shifter_pairs" in level:
		return level.shifter_pairs
	if "red_pairs" in level:
		return level.red_pairs
	return []

static func apply_playtest_cell_locks(cell) -> void:
	if cell.state == GameConstants.TileState.WALL:
		cell.is_playable = false
		cell.is_locked = true
	elif cell.state != GameConstants.TileState.EMPTY and cell.state != GameConstants.TileState.SHIFTER:
		cell.is_playable = true
		cell.is_locked = true
	else:
		cell.is_playable = true
		cell.is_locked = false

static func scan_directory(path_to_scan: String) -> Array:
	var found_files: Array = []
	if not DirAccess.dir_exists_absolute(path_to_scan):
		return found_files
	var dir := DirAccess.open(path_to_scan)
	if not dir:
		return found_files
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			if file_name.ends_with(".tres"):
				found_files.append(path_to_scan + file_name)
			elif file_name.ends_with(".tres.remap"):
				found_files.append(path_to_scan + file_name.replace(".remap", ""))
		file_name = dir.get_next()
	dir.list_dir_end()
	return found_files
