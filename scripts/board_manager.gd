class_name BoardManager
extends Node2D

signal cell_changed(coord: Vector2i)

@export var cell_scene: PackedScene = preload("res://scenes/cell.tscn")
const CELL_SIZE = 120 

var board_cells = {}
var cell_pool: Array = []
var cached_lines: Array = []

func _ready():
	# We remove the hardcoded position here, as it's now handled in build_grid
	pass

func build_grid(layout_data: Dictionary):
	board_cells.clear()
	var pool_index = 0
	
	# NEW: Calculate the board width to center it dynamically
	var max_x = 0
	for coord in layout_data:
		if coord.x > max_x: max_x = coord.x
		
	var board_pixel_width = (max_x + 1) * CELL_SIZE
	var screen_width = get_viewport_rect().size.x
	position = Vector2((screen_width - board_pixel_width) / 2.0, 180)

	for coord in layout_data:
		var starting_state = layout_data[coord]
		
		var cell
		if pool_index < cell_pool.size():
			cell = cell_pool[pool_index]
			cell.visible = true
		else:
			cell = cell_scene.instantiate()
			cell.cell_clicked.connect(func(c): cell_changed.emit(c))
			add_child(cell)
			cell_pool.append(cell)
			
		cell.coord = coord
		cell.position = Vector2(float(coord.x * CELL_SIZE), float(coord.y * CELL_SIZE))
		
		cell.state = starting_state
		if starting_state == -2:
			cell.is_playable = false
			cell.is_locked = true
		elif starting_state != -1:
			cell.is_playable = true
			cell.is_locked = true
		else:
			cell.is_playable = true
			cell.is_locked = false
			
		board_cells[coord] = cell
		cell.update_visuals()
		pool_index += 1
		
	for i in range(pool_index, cell_pool.size()):
		cell_pool[i].visible = false
		cell_pool[i].is_playable = false
		
	_cache_board_lines()
	queue_redraw()

func _cache_board_lines():
	cached_lines.clear()
	var rows = {}
	var cols = {}
	
	for coord in board_cells:
		if not rows.has(coord.y): rows[coord.y] = []
		if not cols.has(coord.x): cols[coord.x] = []
		rows[coord.y].append(coord)
		cols[coord.x].append(coord)
		
	for r in rows:
		var row = rows[r]
		row.sort_custom(func(a, b): return a.x < b.x)
		cached_lines.append({"coords": row, "is_horizontal": true, "index": r})
		
	for c in cols:
		var col = cols[c]
		col.sort_custom(func(a, b): return a.y < b.y)
		cached_lines.append({"coords": col, "is_horizontal": false, "index": c})

func clear_highlights():
	for coord in board_cells:
		board_cells[coord].clear_highlight()

func is_board_full() -> bool:
	for coord in board_cells:
		if board_cells[coord].is_playable and board_cells[coord].state == -1:
			return false
	return true

func _draw():
	var line_color = Color.BLACK
	var line_width = 4.0 
	for coord in board_cells:
		if board_cells[coord].is_playable:
			var cell_pos = Vector2(coord.x * CELL_SIZE, coord.y * CELL_SIZE)
			draw_rect(Rect2(cell_pos, Vector2(CELL_SIZE, CELL_SIZE)), line_color, false, line_width)
