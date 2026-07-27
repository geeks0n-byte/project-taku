class_name LevelUtils
extends RefCounted

static func is_shape_only_layout(layout: Dictionary) -> bool:
	for coord in layout:
		if int(layout[coord]) >= 0:
			return false
	return true

## Player-cycle / generator tile set. Empty input → full Y/B/G.
static func normalize_available_tiles(raw: Array) -> Array[int]:
	var out: Array[int] = []
	var seen: Dictionary = {}
	for tile in raw:
		var t := int(tile)
		if t < GameConstants.TileState.YELLOW or t > GameConstants.TileState.JOKER:
			continue
		if seen.has(t):
			continue
		seen[t] = true
		out.append(t)
	if out.is_empty():
		return [
			GameConstants.TileState.YELLOW,
			GameConstants.TileState.BLUE,
			GameConstants.TileState.JOKER,
		] as Array[int]
	return out

static func tiles_allow_joker(tiles: Array) -> bool:
	for tile in tiles:
		if int(tile) == GameConstants.TileState.JOKER:
			return true
	return false

static func tiles_include(tiles: Array, state: int) -> bool:
	var want := int(state)
	for tile in tiles:
		if int(tile) == want:
			return true
	return false

static func make_empty_layout(width: int, height: int) -> Dictionary:
	var layout := {}
	for y in range(height):
		for x in range(width):
			layout[Vector2i(x, y)] = GameConstants.TileState.EMPTY
	return layout

static func ensure_layout_covers_grid(layout: Dictionary, width: int, height: int) -> Dictionary:
	var filled: Dictionary = layout.duplicate()
	for y in range(height):
		for x in range(width):
			var coord := Vector2i(x, y)
			if not filled.has(coord):
				filled[coord] = GameConstants.TileState.EMPTY
	return filled

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

static func count_jokers_on_board(board_cells: Dictionary) -> int:
	var count := 0
	for coord in board_cells:
		if board_cells[coord].state == GameConstants.TileState.JOKER:
			count += 1
	return count

static func count_unlocked_jokers(board_cells: Dictionary) -> int:
	var count := 0
	for coord in board_cells:
		var cell = board_cells[coord]
		if cell.state == GameConstants.TileState.JOKER and not cell.is_locked:
			count += 1
	return count

## Absolute green-tile quota for a finished board (not "remaining to place").
static func resolve_required_jokers(saved_required: int, grid_w: int, grid_h: int) -> int:
	if saved_required < 0:
		return mini(grid_w, grid_h)
	return saved_required

static func compute_required_shifter_moves(shifter_pairs: Array) -> int:
	var required := 0
	for pair in shifter_pairs:
		if typeof(pair) != TYPE_DICTIONARY:
			continue
		var start: Vector2i = pair.get("active", Vector2i(-1, -1))
		var home: Vector2i = pair.get("home", start)
		if start != home:
			required += 1
	return required

static func build_solve_layout(board_cells: Dictionary) -> Dictionary:
	var solve_layout := {}
	var empty_cells: Array = []
	for coord in board_cells:
		var cell = board_cells[coord]
		# Keep shifters fixed in place — they occupy a cell and are not color-filled.
		solve_layout[coord] = cell.state
		if cell.state == GameConstants.TileState.EMPTY:
			empty_cells.append(coord)
	return {"layout": solve_layout, "empty_cells": empty_cells}

## Place shifters on their home cells so the solver fills only true empties.
static func layout_with_shifters_for_solve(layout: Dictionary, shifter_pairs: Array) -> Dictionary:
	var solve_layout: Dictionary = layout.duplicate()
	for pair in shifter_pairs:
		if typeof(pair) != TYPE_DICTIONARY:
			continue
		if not pair.has("a") or not pair.has("b"):
			continue
		var cell_a: Vector2i = pair["a"]
		var cell_b: Vector2i = pair["b"]
		var home: Vector2i = pair.get("home", pair.get("active", cell_a))
		if home != cell_a and home != cell_b:
			home = pair.get("active", cell_a)
		var other: Vector2i = cell_b if home == cell_a else cell_a
		if solve_layout.has(home):
			solve_layout[home] = GameConstants.TileState.SHIFTER
		if solve_layout.has(other) and solve_layout[other] == GameConstants.TileState.SHIFTER:
			solve_layout[other] = GameConstants.TileState.EMPTY
	return solve_layout

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

## Returns 0, 1, 2+ (capped), or PuzzleGenerator.SOLUTIONS_UNKNOWN on timeout.
## Pass a shared `iter` Dictionary to accumulate budget across multiple calls.
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

static func empty_cells_from_layout(layout: Dictionary) -> Array:
	var empty_cells: Array = []
	for coord in layout:
		if layout[coord] == GameConstants.TileState.EMPTY:
			empty_cells.append(coord)
	return empty_cells

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
	var base := path_to_scan if path_to_scan.ends_with("/") else path_to_scan + "/"
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			if file_name.ends_with(".tres"):
				found_files.append(base + file_name)
			elif file_name.ends_with(".tres.remap"):
				found_files.append(base + file_name.replace(".remap", ""))
		file_name = dir.get_next()
	dir.list_dir_end()
	return found_files

static func sort_level_paths(paths: Array) -> void:
	paths.sort_custom(func(a, b):
		var num_a = int(String(a).get_file().get_basename().replace("level_", ""))
		var num_b = int(String(b).get_file().get_basename().replace("level_", ""))
		return num_a < num_b
	)

## Campaign levels in progression order: tutorials → easy → medium → hard.
static func scan_campaign_levels() -> Array:
	var found: Array = []
	for folder in [
		GameConstants.CAMPAIGN_TUTORIALS_DIR,
		GameConstants.CAMPAIGN_EASY_DIR,
		GameConstants.CAMPAIGN_MEDIUM_DIR,
		GameConstants.CAMPAIGN_HARD_DIR,
	]:
		var folder_paths := scan_directory(folder)
		sort_level_paths(folder_paths)
		found.append_array(folder_paths)
	return found

## Highest tutorial `level_number` (0 if none). Used to map playable IDs → display 1+.
static func highest_tutorial_level_number() -> int:
	var highest := 0
	for path in scan_directory(GameConstants.CAMPAIGN_TUTORIALS_DIR):
		var resource = load(path)
		if resource is LevelData:
			highest = maxi(highest, int(resource.level_number))
	return highest

## Player-facing level label number. Tutorials / custom keep authored numbers;
## campaign playable levels (easy→hard) start at 1 after tutorials.
static func get_display_level_number(level: LevelData) -> int:
	if level == null:
		return 0
	var path := String(level.resource_path)
	if path.begins_with(GameConstants.CAMPAIGN_TUTORIALS_DIR):
		return int(level.level_number)
	if (
		path.begins_with(GameConstants.CAMPAIGN_EASY_DIR)
		or path.begins_with(GameConstants.CAMPAIGN_MEDIUM_DIR)
		or path.begins_with(GameConstants.CAMPAIGN_HARD_DIR)
	):
		return maxi(1, int(level.level_number) - highest_tutorial_level_number())
	return int(level.level_number)
