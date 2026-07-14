class_name BoardManager
extends Node2D

signal cell_changed(coord: Vector2i)
signal red_move_made # Tells Main to increment the Move Counter

@export var cell_scene: PackedScene = preload("res://scenes/cell.tscn")
const CELL_SIZE = 120 

var board_cells = {}
var cell_pool: Array = []
var cached_lines: Array = []

func _ready():
	pass

# UPDATED: Now accepts red_pairs to set up the shifters
func build_grid(layout_data: Dictionary, available_tiles: Array[int] = [0, 1], red_pairs: Array = []):
	board_cells.clear()
	var pool_index = 0
	
	var allowed_tiles = available_tiles if available_tiles.size() > 0 else [0, 1]
	
	var max_x = 0
	for coord in layout_data:
		if coord.x > max_x: max_x = coord.x
		
	var board_pixel_width = (max_x + 1) * CELL_SIZE
	var screen_width = get_viewport_rect().size.x
	# Centered in 1/3 of the screen as requested previously
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
		cell.allowed_cycle_tiles = allowed_tiles
		
		# Reset logic for shifter linkage (important for pooling)
		cell.is_part_of_pair = false
		if cell.red_toggled.is_connected(_on_red_tile_toggled):
			cell.red_toggled.disconnect(_on_red_tile_toggled)
		
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
		
	# --- NEW: Process Red Shifter Pairs ---
	for pair in red_pairs:
		var a = pair["a"]
		var b = pair["b"]
		var active = pair["active"]
		
		if board_cells.has(a) and board_cells.has(b):
			var cell_a = board_cells[a]
			var cell_b = board_cells[b]
			
			cell_a.is_part_of_pair = true
			cell_a.pair_partner = b
			cell_a.red_toggled.connect(_on_red_tile_toggled)
			
			cell_b.is_part_of_pair = true
			cell_b.pair_partner = a
			cell_b.red_toggled.connect(_on_red_tile_toggled)
			
			# Place the red tile in the active position
			if active == a: cell_a.state = 3
			else: cell_b.state = 3
			
			cell_a.update_visuals()
			cell_b.update_visuals()
	# --------------------------------------
		
	_cache_board_lines()
	queue_redraw()

# Logic to swap the shifter between the paired cells
func _on_red_tile_toggled(clicked_coord: Vector2i):
	var clicked_cell = board_cells[clicked_coord]
	var partner_coord = clicked_cell.pair_partner
	var partner_cell = board_cells[partner_coord]
	
	# The red tile leaves the clicked cell (making it empty)
	clicked_cell.state = -1 
	# The red tile enters the partner cell (overwriting whatever was there)
	partner_cell.state = 3
	
	clicked_cell.update_visuals()
	partner_cell.update_visuals()
	
	red_move_made.emit() # Signal Main to increment move counter
	cell_changed.emit(clicked_coord) # Trigger a new validation pass

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
