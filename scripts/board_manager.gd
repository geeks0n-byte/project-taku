class_name BoardManager
extends Node2D

signal cell_changed(coord: Vector2i)
signal shifter_move_made
signal invalid_move_attempted(message: String)

@export var cell_scene: PackedScene = preload("res://scenes/cell.tscn")

var board_cells = {}
var cell_pool: Array = []
var cached_lines: Array = []

var active_shifter_pairs: Array = []
var active_constraint_pairs: Array = []

var grid_drawer: Node2D
var constraint_drawer: Node2D

func _ready():
	grid_drawer = Node2D.new()
	grid_drawer.z_index = 10
	grid_drawer.draw.connect(_draw_grid)
	add_child(grid_drawer)

	constraint_drawer = Node2D.new()
	constraint_drawer.z_index = 4096
	constraint_drawer.draw.connect(_draw_constraints)
	add_child(constraint_drawer)

func trigger_redraw():
	queue_redraw()
	if grid_drawer:
		grid_drawer.queue_redraw()
	if constraint_drawer:
		constraint_drawer.queue_redraw()

func build_grid(layout_data: Dictionary, available_tiles: Array = [0, 1, 2], shifter_pairs: Array = [], constraint_pairs: Array = []):
	board_cells.clear()
	var pool_index = 0

	var allowed_tiles = available_tiles if available_tiles.size() > 0 else [0, 1, 2]
	var max_x = 0
	for coord in layout_data:
		if coord.x > max_x:
			max_x = coord.x

	var board_pixel_width = (max_x + 1) * GameConstants.CELL_SIZE
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
			cell.cell_clicked.connect(func(c):
				clear_highlights()
				cell_changed.emit(c)
			)
			add_child(cell)
			cell_pool.append(cell)

		cell.coord = coord
		cell.position = Vector2(float(coord.x * GameConstants.CELL_SIZE), float(coord.y * GameConstants.CELL_SIZE))

		var int_allowed_tiles: Array[int] = []
		for tile in allowed_tiles:
			int_allowed_tiles.append(int(tile))
		cell.allowed_cycle_tiles = int_allowed_tiles

		cell.is_linked_pair = false
		cell.shifter_direction = Vector2i.ZERO

		if cell.shifter_toggled.is_connected(_on_shifter_tile_toggled):
			cell.shifter_toggled.disconnect(_on_shifter_tile_toggled)

		cell.state = int(starting_state)
		if starting_state == GameConstants.TileState.WALL:
			cell.is_playable = false
			cell.is_locked = true
		elif starting_state != GameConstants.TileState.EMPTY:
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
			if not cell_a.shifter_toggled.is_connected(_on_shifter_tile_toggled):
				cell_a.shifter_toggled.connect(_on_shifter_tile_toggled)

			cell_b.is_linked_pair = true
			if not cell_b.shifter_toggled.is_connected(_on_shifter_tile_toggled):
				cell_b.shifter_toggled.connect(_on_shifter_tile_toggled)

			if active == a:
				cell_a.state = GameConstants.TileState.SHIFTER
				cell_a.shifter_direction = b - a
				if cell_b.state != GameConstants.TileState.SHIFTER:
					cell_b.shifter_direction = Vector2i.ZERO
			else:
				cell_b.state = GameConstants.TileState.SHIFTER
				cell_b.shifter_direction = a - b
				if cell_a.state != GameConstants.TileState.SHIFTER:
					cell_a.shifter_direction = Vector2i.ZERO

			cell_a.update_visuals()
			cell_b.update_visuals()

	move_child(grid_drawer, -1)
	move_child(constraint_drawer, -1)

	cached_lines = BoardRenderer.cache_board_lines(board_cells)
	trigger_redraw()

func _on_shifter_tile_toggled(clicked_coord: Vector2i):
	clear_highlights()

	var clicked_cell = board_cells[clicked_coord]
	if clicked_cell.state != GameConstants.TileState.SHIFTER:
		return

	var partner_coord = clicked_coord + clicked_cell.shifter_direction
	if not board_cells.has(partner_coord):
		return

	var partner_cell = board_cells[partner_coord]
	if partner_cell.state == GameConstants.TileState.SHIFTER:
		partner_cell.set_error_highlight()
		invalid_move_attempted.emit("No space to move! The cell is occupied by another [color=#9c27b0]Purple[/color] tile.")
		return

	clicked_cell.state = GameConstants.TileState.EMPTY
	clicked_cell.shifter_direction = Vector2i.ZERO

	partner_cell.state = GameConstants.TileState.SHIFTER
	partner_cell.shifter_direction = clicked_coord - partner_coord

	clicked_cell.update_visuals()
	partner_cell.update_visuals()

	shifter_move_made.emit()
	cell_changed.emit(clicked_coord)
	trigger_redraw()

func clear_highlights():
	BoardRenderer.clear_highlights(board_cells)

func is_board_full() -> bool:
	return BoardRenderer.is_board_full(board_cells)

func _draw_grid():
	BoardRenderer.draw_grid(grid_drawer, board_cells, GameConstants.CELL_SIZE, true)

func _draw_constraints():
	BoardRenderer.draw_constraints(constraint_drawer, board_cells, active_constraint_pairs, GameConstants.CELL_SIZE)
