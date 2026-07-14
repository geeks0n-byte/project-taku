class_name EditorCanvasManager
extends Node2D

signal canvas_cell_clicked(coord: Vector2i)
signal pair_created(coord_a: Vector2i, coord_b: Vector2i)

@export var cell_scene: PackedScene = preload("res://scenes/cell.tscn")

const CELL_SIZE = 120

var grid_width: int = 3
var grid_height: int = 3

var board_cells = {}
var cell_pool: Array = []
var cached_lines: Array = []

# --- NEW: Drag-to-Link Drag State Data ---
var active_drag_start_coord = null
var current_drag_mouse_position: Vector2 = Vector2.ZERO
var loaded_red_pairs: Array = []

func _ready():
	position = Vector2(120, 180)
	set_process_unhandled_input(true)

func generate_blank_canvas(new_width: int = 3, new_height: int = 3):
	grid_width = new_width
	grid_height = new_height
	board_cells.clear()
	loaded_red_pairs.clear()
	active_drag_start_coord = null
	
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
			cell.is_part_of_pair = false
			cell.update_visuals()
			
			interceptor.size = Vector2(CELL_SIZE, CELL_SIZE)
			interceptor.position = cell.position
			
			for conn in interceptor.gui_input.get_connections():
				interceptor.gui_input.disconnect(conn.callable)
				
			interceptor.gui_input.connect(func(event): _on_cell_gui_input(event, coord))
			
			board_cells[coord] = cell
			pool_index += 1
			
	for i in range(pool_index, cell_pool.size()):
		cell_pool[i]["cell"].visible = false
		cell_pool[i]["interceptor"].visible = false
		
	_cache_board_lines()
	queue_redraw()

# --- NEW: Drag-and-Drop Input Processor ---
func _on_cell_gui_input(event: InputEvent, coord: Vector2i):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			active_drag_start_coord = coord
			current_drag_mouse_position = get_local_mouse_position()
			queue_redraw()
		elif not event.pressed and active_drag_start_coord != null:
			_evaluate_drag_drop_release(get_local_mouse_position())

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseMotion and active_drag_start_coord != null:
		current_drag_mouse_position = get_local_mouse_position()
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if active_drag_start_coord != null:
			_evaluate_drag_drop_release(get_local_mouse_position())

func _evaluate_drag_drop_release(local_mouse_pos: Vector2):
	var target_grid_x = int(local_mouse_pos.x / CELL_SIZE)
	var target_grid_y = int(local_mouse_pos.y / CELL_SIZE)
	
	if local_mouse_pos.x < 0: target_grid_x = -1
	if local_mouse_pos.y < 0: target_grid_y = -1
	
	var target_coord = Vector2i(target_grid_x, target_grid_y)
	var source_coord = active_drag_start_coord
	active_drag_start_coord = null
	queue_redraw()
	
	if target_coord == source_coord:
		canvas_cell_clicked.emit(source_coord)
		return
		
	if board_cells.has(target_coord):
		var diff = (target_coord - source_coord).abs()
		if (diff.x == 1 and diff.y == 0) or (diff.x == 0 and diff.y == 1):
			pair_created.emit(source_coord, target_coord)

func _draw():
	for coord in board_cells:
		var cell_pos = Vector2(coord.x * CELL_SIZE, coord.y * CELL_SIZE)
		draw_rect(Rect2(cell_pos, Vector2(CELL_SIZE, CELL_SIZE)), Color.BLACK, false, 2.0)
		
	# Draw active connection lines during level compilation editing passes
	for pair in loaded_red_pairs:
		var pos_a = Vector2(pair["a"].x * CELL_SIZE + CELL_SIZE/2, pair["a"].y * CELL_SIZE + CELL_SIZE/2)
		var pos_b = Vector2(pair["b"].x * CELL_SIZE + CELL_SIZE/2, pair["b"].y * CELL_SIZE + CELL_SIZE/2)
		draw_line(pos_a, pos_b, Color.YELLOW, 6.0)
		
	if active_drag_start_coord != null:
		var start_pos = Vector2(active_drag_start_coord.x * CELL_SIZE + CELL_SIZE/2, active_drag_start_coord.y * CELL_SIZE + CELL_SIZE/2)
		draw_line(start_pos, current_drag_mouse_position, Color.GOLD, 4.0)
# -------------------------------------------

func load_layout(new_width: int, new_height: int, layout_data: Dictionary, red_pairs: Array = []):
	generate_blank_canvas(new_width, new_height)
	loaded_red_pairs = red_pairs.duplicate()
	
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
			
	for pair in loaded_red_pairs:
		if board_cells.has(pair["a"]): board_cells[pair["a"]].is_part_of_pair = true
		if board_cells.has(pair["b"]): board_cells[pair["b"]].is_part_of_pair = true
		if board_cells.has(pair["active"]):
			board_cells[pair["active"]].state = 3
			
	for coord in board_cells:
		board_cells[coord].update_visuals()
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
