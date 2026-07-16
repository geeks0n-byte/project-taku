class_name BoardManager
extends Node2D

signal cell_changed(coord: Vector2i)
signal shifter_move_made

@export var cell_scene: PackedScene = preload("res://scenes/cell.tscn")
const CELL_SIZE = 120 

var board_cells = {}
var cell_pool: Array = []
var cached_lines: Array = []

var active_shifter_pairs: Array = []
var active_constraint_pairs: Array = [] 
var overlay_drawer: Node2D

func _ready():
	overlay_drawer = Node2D.new()
	overlay_drawer.z_index = 10 
	overlay_drawer.draw.connect(_draw_overlays)
	add_child(overlay_drawer)

func trigger_redraw():
	queue_redraw()
	if overlay_drawer:
		overlay_drawer.queue_redraw()

# Updated default arg to [0, 1, 2]
func build_grid(layout_data: Dictionary, available_tiles: Array = [0, 1, 2], shifter_pairs: Array = [], constraint_pairs: Array = []):
	board_cells.clear()
	var pool_index = 0
	
	var allowed_tiles = available_tiles if available_tiles.size() > 0 else [0, 1, 2] # Fallback updated
	var max_x = 0
	for coord in layout_data:
		if coord.x > max_x: max_x = coord.x
		
	var board_pixel_width = (max_x + 1) * CELL_SIZE
	var screen_width = get_viewport_rect().size.x
	position = Vector2((screen_width - board_pixel_width) / 2.0, get_viewport_rect().size.y / 3.0)

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
		
		var int_allowed_tiles: Array[int] = []
		for tile in allowed_tiles:
			int_allowed_tiles.append(int(tile))
		cell.allowed_cycle_tiles = int_allowed_tiles
		
		cell.is_linked_pair = false
		cell.shifter_direction = Vector2i.ZERO 
		
		if cell.shifter_toggled.is_connected(_on_shifter_tile_toggled):
			cell.shifter_toggled.disconnect(_on_shifter_tile_toggled)
		
		cell.state = int(starting_state)
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
		
	active_shifter_pairs = shifter_pairs.duplicate()
	active_constraint_pairs = constraint_pairs.duplicate() 
	
	for pair in active_shifter_pairs:
		var a = pair["a"]
		var b = pair["b"]
		var active = pair["active"]
		
		if board_cells.has(a) and board_cells.has(b):
			var cell_a = board_cells[a]
			var cell_b = board_cells[b]
			
			cell_a.is_linked_pair = true
			cell_a.link_partner = b
			cell_a.shifter_toggled.connect(_on_shifter_tile_toggled)
			
			cell_b.is_linked_pair = true
			cell_b.link_partner = a
			cell_b.shifter_toggled.connect(_on_shifter_tile_toggled)
			
			if active == a: 
				cell_a.state = 3
				cell_a.shifter_direction = b - a 
				cell_b.shifter_direction = Vector2i.ZERO
			else: 
				cell_b.state = 3
				cell_b.shifter_direction = a - b 
				cell_a.shifter_direction = Vector2i.ZERO
			
			cell_a.update_visuals()
			cell_b.update_visuals()
		
	_cache_board_lines()
	trigger_redraw()

func _on_shifter_tile_toggled(clicked_coord: Vector2i):
	var clicked_cell = board_cells[clicked_coord]
	var partner_coord = clicked_cell.link_partner
	var partner_cell = board_cells[partner_coord]
	
	clicked_cell.state = -1 
	clicked_cell.shifter_direction = Vector2i.ZERO
	
	partner_cell.state = 3
	partner_cell.shifter_direction = clicked_coord - partner_coord
	
	clicked_cell.update_visuals()
	partner_cell.update_visuals()
	
	shifter_move_made.emit() 
	cell_changed.emit(clicked_coord)
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
		var is_playable = cell.state != -2
		
		var pos_tl = Vector2(coord.x * CELL_SIZE, coord.y * CELL_SIZE)
		var pos_tr = Vector2((coord.x + 1) * CELL_SIZE, coord.y * CELL_SIZE)
		var pos_bl = Vector2(coord.x * CELL_SIZE, (coord.y + 1) * CELL_SIZE)
		var pos_br = Vector2((coord.x + 1) * CELL_SIZE, (coord.y + 1) * CELL_SIZE)
		
		var right_playable = false
		if board_cells.has(coord + Vector2i(1, 0)): 
			right_playable = board_cells[coord + Vector2i(1, 0)].state != -2
		if is_playable or right_playable:
			overlay_drawer.draw_line(pos_tr, pos_br, line_color, line_width)
			
		var bot_playable = false
		if board_cells.has(coord + Vector2i(0, 1)): 
			bot_playable = board_cells[coord + Vector2i(0, 1)].state != -2
		if is_playable or bot_playable:
			overlay_drawer.draw_line(pos_bl, pos_br, line_color, line_width)

		if not board_cells.has(coord + Vector2i(0, -1)):
			if is_playable:
				overlay_drawer.draw_line(pos_tl, pos_tr, line_color, line_width)
				
		if not board_cells.has(coord + Vector2i(-1, 0)):
			if is_playable:
				overlay_drawer.draw_line(pos_tl, pos_bl, line_color, line_width)

	var equals_color = Color(1.0, 1.0, 1.0, 0.9)
	var diff_color = Color(1.0, 1.0, 1.0, 0.9) 
	for pair in active_constraint_pairs:
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
