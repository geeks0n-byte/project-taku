class_name BoardRenderer
extends RefCounted

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

static func clear_highlights(board_cells: Dictionary) -> void:
	for coord in board_cells:
		board_cells[coord].clear_highlight()

static func is_board_full(board_cells: Dictionary) -> bool:
	for coord in board_cells:
		var cell = board_cells[coord]
		if cell.is_playable and cell.state == GameConstants.TileState.EMPTY:
			return false
	return true

static func draw_grid(
	canvas: CanvasItem,
	board_cells: Dictionary,
	cell_size: float,
	full_grid: bool = false
) -> void:
	var line_color := Color.BLACK
	var line_width := 4.0

	for coord in board_cells:
		var cell = board_cells[coord]
		var is_playable: bool = cell.state != GameConstants.TileState.WALL

		var pos_tl := Vector2(coord.x * cell_size, coord.y * cell_size)
		var pos_tr := Vector2((coord.x + 1) * cell_size, coord.y * cell_size)
		var pos_bl := Vector2(coord.x * cell_size, (coord.y + 1) * cell_size)
		var pos_br := Vector2((coord.x + 1) * cell_size, (coord.y + 1) * cell_size)

		var draw_right: bool
		var draw_bottom: bool
		var draw_top: bool
		var draw_left: bool

		if full_grid:
			# Editor: outline every cell, including walls.
			draw_right = true
			draw_bottom = true
			draw_top = not board_cells.has(coord + Vector2i(0, -1))
			draw_left = not board_cells.has(coord + Vector2i(-1, 0))
		else:
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
			canvas.draw_line(pos_tr, pos_br, line_color, line_width)
		if draw_bottom:
			canvas.draw_line(pos_bl, pos_br, line_color, line_width)
		if draw_top:
			canvas.draw_line(pos_tl, pos_tr, line_color, line_width)
		if draw_left:
			canvas.draw_line(pos_tl, pos_bl, line_color, line_width)

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

		var pos_a := Vector2(
			coord_a.x * cell_size + cell_size / 2.0,
			coord_a.y * cell_size + cell_size / 2.0
		)
		var pos_b := Vector2(
			coord_b.x * cell_size + cell_size / 2.0,
			coord_b.y * cell_size + cell_size / 2.0
		)

		var midpoint := (pos_a + pos_b) / 2.0
		var dir := (pos_b - pos_a).normalized()
		var perp := dir.orthogonal()

		if pair["type"] == "equals":
			var l1_s := midpoint + perp * 8.0 - dir * 16.0
			var l1_e := midpoint + perp * 8.0 + dir * 16.0
			var l2_s := midpoint - perp * 8.0 - dir * 16.0
			var l2_e := midpoint - perp * 8.0 + dir * 16.0

			canvas.draw_line(l1_s, l1_e, outline_color, 8.0, true)
			canvas.draw_line(l2_s, l2_e, outline_color, 8.0, true)

			var shrink := dir * 2.0
			canvas.draw_line(l1_s + shrink, l1_e - shrink, equals_color, 4.0, true)
			canvas.draw_line(l2_s + shrink, l2_e - shrink, equals_color, 4.0, true)

		elif pair["type"] == "not_equals":
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

## Red bridge lines across wall cutouts between highlighted playable cells.
## Does not box walls — only spans the gap from playable border to playable border.
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
	# Horizontal bridges: playable → walls… → playable in the same row.
	for raw in highlight_coords:
		var c: Vector2i = raw as Vector2i
		if not board_cells.has(c):
			continue
		if board_cells[c].state == GameConstants.TileState.WALL:
			continue
		var right: Vector2i = c + Vector2i(1, 0)
		if not board_cells.has(right) or board_cells[right].state != GameConstants.TileState.WALL:
			continue
		# Walk through contiguous walls to the next highlighted playable.
		var cursor: Vector2i = right
		while board_cells.has(cursor) and board_cells[cursor].state == GameConstants.TileState.WALL:
			cursor += Vector2i(1, 0)
		if not highlighted.has(cursor) or not board_cells.has(cursor):
			continue
		if board_cells[cursor].state == GameConstants.TileState.WALL:
			continue
		var y_mid: float = float(c.y) * cell_size + cell_size * 0.5
		var x0: float = float(c.x + 1) * cell_size
		var x1: float = float(cursor.x) * cell_size
		canvas.draw_line(Vector2(x0, y_mid), Vector2(x1, y_mid), color, width, true)
	# Vertical bridges.
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

## Alias kept for tutorial focus call sites.
static func draw_focus_bridges(
	canvas: CanvasItem,
	board_cells: Dictionary,
	focus_coords: Array,
	cell_size: float
) -> void:
	draw_highlight_bridges(canvas, board_cells, focus_coords, cell_size)
