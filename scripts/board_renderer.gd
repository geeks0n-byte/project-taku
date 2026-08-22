class_name BoardRenderer
extends RefCounted

# Pure-static rendering utilities. All drawing is done onto an external CanvasItem
# so these functions can be called from any draw callback without owning a scene node.

# Pre-sorts all cells into row and column groups for efficient row/column-aware operations.
# The returned array is cached and reused to avoid re-sorting every frame.
static func cache_board_lines(board_cells: Dictionary) -> Array:
	var cached_lines: Array = []
	var rows := {}
	var cols := {}
	for coord in board_cells:
		if not rows.has(coord.y):
			rows[coord.y] = []
		if not cols.has(coord.x):
			cols[coord.x] = []
		rows[coord.y].append(coord)
		cols[coord.x].append(coord)
	for r in rows:
		var row: Array = rows[r]
		row.sort_custom(func(a, b): return a.x < b.x)
		cached_lines.append({"coords": row, "is_horizontal": true, "index": r})
	for c in cols:
		var col: Array = cols[c]
		col.sort_custom(func(a, b): return a.y < b.y)
		cached_lines.append({"coords": col, "is_horizontal": false, "index": c})
	return cached_lines

# Clears any visual highlight overlays on all cells (e.g. after a hint or error flash).
static func clear_highlights(board_cells: Dictionary) -> void:
	for coord in board_cells:
		board_cells[coord].clear_highlight()

# A board is "full" only when every playable (non-wall) cell has been assigned a tile.
# Walls and non-playable cells are excluded from the check.
static func is_board_full(board_cells: Dictionary) -> bool:
	for coord in board_cells:
		var cell = board_cells[coord]
		if cell.is_playable and cell.state == GameConstants.TileState.EMPTY:
			return false
	return true

const GRID_LINE_WIDTH := 4.0

# Half-line inset applied to grid_drawer.position so outer corner caps are not
# clipped at the board origin (only the bottom-right cap was visible before).
static func grid_drawer_offset() -> Vector2:
	var half := GRID_LINE_WIDTH * 0.5
	return Vector2(half, half)

# Draws the grid border lines for all cells.
# full_grid=true (editor mode) always draws all interior lines.
# full_grid=false (play mode) omits borders between two wall cells to keep walls visually solid.
static func draw_grid(
	canvas: CanvasItem,
	board_cells: Dictionary,
	cell_size: float,
	full_grid: bool = false
) -> void:
	var line_color := Color.BLACK
	var line_width := GRID_LINE_WIDTH
	var half := line_width * 0.5
	# Pair with grid_drawer.position = grid_drawer_offset() on the drawer node.
	var draw_shift := -half

	for coord in board_cells:
		var cell = board_cells[coord]
		var is_playable: bool = cell.state != GameConstants.TileState.WALL

		var pos_tl := Vector2(coord.x * cell_size, coord.y * cell_size)
		pos_tl.x += draw_shift
		pos_tl.y += draw_shift
		var pos_tr := Vector2((coord.x + 1) * cell_size, coord.y * cell_size)
		pos_tr.x += draw_shift
		pos_tr.y += draw_shift
		var pos_bl := Vector2(coord.x * cell_size, (coord.y + 1) * cell_size)
		pos_bl.x += draw_shift
		pos_bl.y += draw_shift
		var pos_br := Vector2((coord.x + 1) * cell_size, (coord.y + 1) * cell_size)
		pos_br.x += draw_shift
		pos_br.y += draw_shift

		var draw_right: bool
		var draw_bottom: bool
		var draw_top: bool
		var draw_left: bool

		if full_grid:
			# In editor mode show all lines; only skip top/left when a neighbour exists
			# (avoids double-drawing shared edges).
			draw_right = true
			draw_bottom = true
			draw_top = not board_cells.has(coord + Vector2i(0, -1))
			draw_left = not board_cells.has(coord + Vector2i(-1, 0))
		else:
			# In play mode draw a border whenever at least one side of the edge is playable,
			# so wall-wall borders are suppressed but wall-playable borders remain visible.
			var right_playable := false
			if board_cells.has(coord + Vector2i(1, 0)):
				right_playable = board_cells[coord + Vector2i(1, 0)].state != GameConstants.TileState.WALL
			draw_right = is_playable or right_playable

			var bot_playable := false
			if board_cells.has(coord + Vector2i(0, 1)):
				bot_playable = board_cells[coord + Vector2i(0, 1)].state != GameConstants.TileState.WALL
			draw_bottom = is_playable or bot_playable

			draw_top = is_playable and not board_cells.has(coord + Vector2i(0, -1))
			draw_left = is_playable and not board_cells.has(coord + Vector2i(-1, 0))

		if draw_right:
			_draw_grid_v_edge(canvas, pos_tr.x, pos_tr.y, pos_br.y, line_width, line_color)
		if draw_bottom:
			_draw_grid_h_edge(canvas, pos_bl.x, pos_br.x, pos_bl.y, line_width, line_color)
		if draw_top:
			_draw_grid_h_edge(canvas, pos_tl.x, pos_tr.x, pos_tl.y, line_width, line_color)
		if draw_left:
			_draw_grid_v_edge(canvas, pos_tl.x, pos_tl.y, pos_bl.y, line_width, line_color)

static func _draw_grid_h_edge(
	canvas: CanvasItem, x0: float, x1: float, y: float, width: float, color: Color
) -> void:
	var half := width * 0.5
	var left := minf(x0, x1) - half
	var right := maxf(x0, x1) + half
	canvas.draw_rect(Rect2(left, y - half, right - left, width), color, true)

static func _draw_grid_v_edge(
	canvas: CanvasItem, x: float, y0: float, y1: float, width: float, color: Color
) -> void:
	var half := width * 0.5
	var top := minf(y0, y1) - half
	var bottom := maxf(y0, y1) + half
	canvas.draw_rect(Rect2(x - half, top, width, bottom - top), color, true)

# Draws "=" (equals) or "X" (not-equals) constraint symbols between adjacent cell pairs.
# Symbols are drawn at the midpoint of the shared edge with a black outline for readability.
static func draw_constraints(
	canvas: CanvasItem,
	board_cells: Dictionary,
	constraint_pairs: Array,
	cell_size: float
) -> void:
	var equals_color := Color(1.0, 1.0, 1.0, 0.9)
	var diff_color := Color(1.0, 1.0, 1.0, 0.9)
	var outline_color := Color(0.0, 0.0, 0.0, 1.0)

	for pair in constraint_pairs:
		var coord_a: Vector2i = pair["a"]
		var coord_b: Vector2i = pair["b"]
		if not (board_cells.has(coord_a) and board_cells.has(coord_b)):
			continue

		# Compute cell-center positions in canvas-local space.
		var pos_a := Vector2(
			coord_a.x * cell_size + cell_size / 2.0,
			coord_a.y * cell_size + cell_size / 2.0
		)
		var pos_b := Vector2(
			coord_b.x * cell_size + cell_size / 2.0,
			coord_b.y * cell_size + cell_size / 2.0
		)

		var midpoint := (pos_a + pos_b) / 2.0
		# dir points from a to b; perp is the axis orthogonal to the shared edge.
		var dir := (pos_b - pos_a).normalized()
		var perp := dir.orthogonal()

		if pair["type"] == "equals":
			# Two parallel bars rendered as thick outline + thinner white fill.
			var l1_s := midpoint + perp * 8.0 - dir * 16.0
			var l1_e := midpoint + perp * 8.0 + dir * 16.0
			var l2_s := midpoint - perp * 8.0 - dir * 16.0
			var l2_e := midpoint - perp * 8.0 + dir * 16.0

			canvas.draw_line(l1_s, l1_e, outline_color, 8.0, true)
			canvas.draw_line(l2_s, l2_e, outline_color, 8.0, true)

			# Shrink the white fill slightly so the outline is visible at both ends.
			var shrink := dir * 2.0
			canvas.draw_line(l1_s + shrink, l1_e - shrink, equals_color, 4.0, true)
			canvas.draw_line(l2_s + shrink, l2_e - shrink, equals_color, 4.0, true)

		elif pair["type"] == "not_equals":
			# Two diagonal lines forming an X, drawn the same outline+fill way.
			var l1_s := midpoint - dir * 12.0 - perp * 12.0
			var l1_e := midpoint + dir * 12.0 + perp * 12.0
			var l2_s := midpoint - dir * 12.0 + perp * 12.0
			var l2_e := midpoint + dir * 12.0 - perp * 12.0

			canvas.draw_line(l1_s, l1_e, outline_color, 8.0, true)
			canvas.draw_line(l2_s, l2_e, outline_color, 8.0, true)

			var shrink1 := (l1_e - l1_s).normalized() * 2.0
			var shrink2 := (l2_e - l2_s).normalized() * 2.0

			canvas.draw_line(l1_s + shrink1, l1_e - shrink1, diff_color, 4.0, true)
			canvas.draw_line(l2_s + shrink2, l2_e - shrink2, diff_color, 4.0, true)

# Draws horizontal and vertical "bridge" lines connecting highlighted cells that are
# separated by a run of wall cells. Used to visually link related cells during hints.
# Only draws a bridge when both endpoints are highlighted, non-wall, and separated
# exclusively by wall cells (no gaps or other playable cells in between).
static func draw_highlight_bridges(
	canvas: CanvasItem,
	board_cells: Dictionary,
	highlight_coords: Array,
	cell_size: float
) -> void:
	if highlight_coords.is_empty() or board_cells.is_empty():
		return
	var highlighted: Dictionary = {}
	for raw in highlight_coords:
		highlighted[raw as Vector2i] = true
	var color := Color.RED
	var width := 10.0

	# Horizontal bridges: scan rightward from each highlighted cell.
	for raw in highlight_coords:
		var c: Vector2i = raw as Vector2i
		if not board_cells.has(c):
			continue
		if board_cells[c].state == GameConstants.TileState.WALL:
			continue
		var right: Vector2i = c + Vector2i(1, 0)
		# Bridge only starts when the immediate right neighbour is a wall.
		if not board_cells.has(right) or board_cells[right].state != GameConstants.TileState.WALL:
			continue
		# Walk the wall run until we exit it.
		var cursor: Vector2i = right
		while board_cells.has(cursor) and board_cells[cursor].state == GameConstants.TileState.WALL:
			cursor += Vector2i(1, 0)
		# Only draw if the landing cell is also highlighted.
		if not highlighted.has(cursor) or not board_cells.has(cursor):
			continue
		if board_cells[cursor].state == GameConstants.TileState.WALL:
			continue
		var y_mid: float = float(c.y) * cell_size + cell_size * 0.5
		var x0: float = float(c.x + 1) * cell_size
		var x1: float = float(cursor.x) * cell_size
		canvas.draw_line(Vector2(x0, y_mid), Vector2(x1, y_mid), color, width, true)

	# Vertical bridges: same logic as horizontal but scanning downward.
	for raw in highlight_coords:
		var c: Vector2i = raw as Vector2i
		if not board_cells.has(c):
			continue
		if board_cells[c].state == GameConstants.TileState.WALL:
			continue
		var down: Vector2i = c + Vector2i(0, 1)
		if not board_cells.has(down) or board_cells[down].state != GameConstants.TileState.WALL:
			continue
		var cursor: Vector2i = down
		while board_cells.has(cursor) and board_cells[cursor].state == GameConstants.TileState.WALL:
			cursor += Vector2i(0, 1)
		if not highlighted.has(cursor) or not board_cells.has(cursor):
			continue
		if board_cells[cursor].state == GameConstants.TileState.WALL:
			continue
		var x_mid: float = float(c.x) * cell_size + cell_size * 0.5
		var y0: float = float(c.y + 1) * cell_size
		var y1: float = float(cursor.y) * cell_size
		canvas.draw_line(Vector2(x_mid, y0), Vector2(x_mid, y1), color, width, true)

# Alias for draw_highlight_bridges used when the caller wants to emphasize
# that the bridges represent a focused/selected group rather than a hint highlight.
static func draw_focus_bridges(
	canvas: CanvasItem,
	board_cells: Dictionary,
	focus_coords: Array,
	cell_size: float
) -> void:
	draw_highlight_bridges(canvas, board_cells, focus_coords, cell_size)
