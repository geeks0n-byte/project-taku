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

var loaded_shifter_pairs: Array = []
var loaded_constraint_pairs: Array = [] 
var overlay_drawer: Node2D

var is_playtesting: bool = false 

func _ready():
	overlay_drawer = Node2D.new()
	overlay_drawer.z_index = 10 
	overlay_drawer.draw.connect(_draw_overlays)
	add_child(overlay_drawer)

func trigger_redraw():
	queue_redraw()
	if overlay_drawer:
		overlay_drawer.queue_redraw()

func generate_blank_canvas(new_width: int = 3, new_height: int = 3):
	grid_width = new_width
	grid_height = new_height
	board_cells.clear()
	loaded_shifter_pairs.clear()
	loaded_constraint_pairs.clear()
	
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
			cell.is_linked_pair = false 
			cell.shifter_direction = Vector2i.ZERO # Ensure it resets correctly
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
	trigger_redraw()

func load_layout(new_width: int, new_height: int, layout_data: Dictionary, shifter_pairs: Array = [], constraint_pairs: Array = []):
	generate_blank_canvas(new_width, new_height)
	loaded_shifter_pairs = shifter_pairs.duplicate()
	loaded_constraint_pairs = constraint_pairs.duplicate()
	
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
			
	for pair in loaded_shifter_pairs:
		if board_cells.has(pair["a"]): board_cells[pair["a"]].is_linked_pair = true
		if board_cells.has(pair["b"]): board_cells[pair["b"]].is_linked_pair = true
		if board_cells.has(pair["active"]):
			var active_coord = pair["active"]
			var inactive_coord = pair["b"] if active_coord == pair["a"] else pair["a"]
			board_cells[active_coord].state = 3
			board_cells[active_coord].shifter_direction = inactive_coord - active_coord
			
	for coord in board_cells:
		board_cells[coord].update_visuals()

	trigger_redraw()

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

func _draw_overlays():
	var line_color = Color.BLACK
	var line_width = 4.0 
	
	for coord in board_cells:
		var cell = board_cells[coord]
		
		var pos_tl = Vector2(coord.x * CELL_SIZE, coord.y * CELL_SIZE)
		var pos_tr = Vector2((coord.x + 1) * CELL_SIZE, coord.y * CELL_SIZE)
		var pos_bl = Vector2(coord.x * CELL_SIZE, (coord.y + 1) * CELL_SIZE)
		var pos_br = Vector2((coord.x + 1) * CELL_SIZE, (coord.y + 1) * CELL_SIZE)
		
		var draw_right = false
		var draw_bottom = false
		var draw_top = false
		var draw_left = false
		
		if is_playtesting:
			var is_playable = cell.state != -2
			var right_playable = board_cells.has(coord + Vector2i(1, 0)) and board_cells[coord + Vector2i(1, 0)].state != -2
			var bot_playable = board_cells.has(coord + Vector2i(0, 1)) and board_cells[coord + Vector2i(0, 1)].state != -2
			
			draw_right = is_playable or right_playable
			draw_bottom = is_playable or bot_playable
			draw_top = is_playable and not board_cells.has(coord + Vector2i(0, -1))
			draw_left = is_playable and not board_cells.has(coord + Vector2i(-1, 0))
		else:
			draw_right = true
			draw_bottom = true
			draw_top = not board_cells.has(coord + Vector2i(0, -1))
			draw_left = not board_cells.has(coord + Vector2i(-1, 0))
			
		if draw_right: overlay_drawer.draw_line(pos_tr, pos_br, line_color, line_width)
		if draw_bottom: overlay_drawer.draw_line(pos_bl, pos_br, line_color, line_width)
		if draw_top: overlay_drawer.draw_line(pos_tl, pos_tr, line_color, line_width)
		if draw_left: overlay_drawer.draw_line(pos_tl, pos_bl, line_color, line_width)

	var equals_color = Color(1.0, 1.0, 1.0, 0.9)
	var diff_color = Color(1.0, 1.0, 1.0, 0.9) 
	for pair in loaded_constraint_pairs:
		var coord_a = pair["a"]
		var coord_b = pair["b"]
		if not (board_cells.has(coord_a) and board_cells.has(coord_b)): continue
			
		var pos_a = Vector2(coord_a.x * CELL_SIZE + CELL_SIZE/2.0, coord_a.y * CELL_SIZE + CELL_SIZE/2.0)
		var pos_b = Vector2(coord_b.x * CELL_SIZE + CELL_SIZE/2.0, coord_b.y * CELL_SIZE + CELL_SIZE/2.0)
		
		var midpoint = (pos_a + pos_b) / 2.0
		var dir = (pos_b - pos_a).normalized()
		var perp = dir.orthogonal()
		
		if pair["type"] == "equals":
			var l1_s = midpoint + perp * 8.0 - dir * 10.0
			var l1_e = midpoint + perp * 8.0 + dir * 10.0
			var l2_s = midpoint - perp * 8.0 - dir * 10.0
			var l2_e = midpoint - perp * 8.0 + dir * 10.0
			overlay_drawer.draw_line(l1_s, l1_e, equals_color, 4.0)
			overlay_drawer.draw_line(l2_s, l2_e, equals_color, 4.0)
		elif pair["type"] == "not_equals":
			var l1_s = midpoint - dir * 12.0 - perp * 12.0
			var l1_e = midpoint + dir * 12.0 + perp * 12.0
			var l2_s = midpoint - dir * 12.0 + perp * 12.0
			var l2_e = midpoint + dir * 12.0 - perp * 12.0
			overlay_drawer.draw_line(l1_s, l1_e, diff_color, 4.0)
			overlay_drawer.draw_line(l2_s, l2_e, diff_color, 4.0)
