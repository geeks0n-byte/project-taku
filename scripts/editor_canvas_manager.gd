class_name EditorCanvasManager
extends Node2D

signal canvas_cell_clicked(coord: Vector2i)

@export var cell_scene: PackedScene = preload("res://scenes/cell.tscn")

const CELL_SIZE = 120

var grid_width: int = 3
var grid_height: int = 3

var board_cells = {}
var cell_pool: Array = []
var cached_lines: Array = []

func _ready():
	position = Vector2(120, 180)

func generate_blank_canvas(new_width: int = 3, new_height: int = 3):
	grid_width = new_width
	grid_height = new_height
	board_cells.clear()
	
	var board_pixel_width = grid_width * CELL_SIZE
	var screen_width = get_viewport_rect().size.x
	position = Vector2((screen_width - board_pixel_width) / 2.0, 180)
	
	var pool_index = 0
	
	for y in range(grid_height):
		for x in range(grid_width):
			var coord = Vector2i(x, y)
			
			var cell
			var interceptor
			
			if pool_index < cell_pool.size():
				var cell_data = cell_pool[pool_index]
				cell = cell_data["cell"]
				interceptor = cell_data["interceptor"]
				
				cell.visible = true
				interceptor.visible = true
			else:
				cell = cell_scene.instantiate()
				add_child(cell)
				
				interceptor = Control.new()
				interceptor.mouse_filter = Control.MOUSE_FILTER_STOP 
				add_child(interceptor)
				
				cell_pool.append({"cell": cell, "interceptor": interceptor})
			
			cell.coord = coord
			cell.position = Vector2(float(x * CELL_SIZE), float(y * CELL_SIZE))
			cell.state = -1
			cell.is_playable = true
			cell.is_locked = false
			cell.update_visuals()
			
			interceptor.size = Vector2(CELL_SIZE, CELL_SIZE)
			interceptor.position = cell.position
			
			for conn in interceptor.gui_input.get_connections():
				interceptor.gui_input.disconnect(conn.callable)
				
			interceptor.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					canvas_cell_clicked.emit(coord)
			)
			
			board_cells[coord] = cell
			pool_index += 1
			
	for i in range(pool_index, cell_pool.size()):
		cell_pool[i]["cell"].visible = false
		cell_pool[i]["interceptor"].visible = false
		
	_cache_board_lines()
	queue_redraw()

# NEW: Maps saved data onto the generated canvas
func load_layout(new_width: int, new_height: int, layout_data: Dictionary):
	generate_blank_canvas(new_width, new_height)
	
	for coord in layout_data:
		if board_cells.has(coord):
			var cell = board_cells[coord]
			var saved_state = layout_data[coord]
			
			cell.state = saved_state
			if saved_state == -2:
				cell.is_playable = false
				cell.is_locked = true
			elif saved_state != -1:
				cell.is_playable = true
				cell.is_locked = true
			else:
				cell.is_playable = true
				cell.is_locked = false
				
			cell.update_visuals()

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
	for coord in board_cells:
		var cell_pos = Vector2(coord.x * CELL_SIZE, coord.y * CELL_SIZE)
		draw_rect(Rect2(cell_pos, Vector2(CELL_SIZE, CELL_SIZE)), Color.BLACK, false, 2.0)
