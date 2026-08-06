class_name EditorCanvasManager
extends Node2D

signal canvas_cell_clicked(coord: Vector2i)

@export var cell_scene: PackedScene = preload("res://scenes/cell.tscn")

var grid_width: int = 3
var grid_height: int = 3

var board_cells = {}
var cell_pool: Array = []
var cached_lines: Array = []

var loaded_shifter_pairs: Array = []
var loaded_constraint_pairs: Array = []
var hidden_constraint_pairs: Array = []

var grid_drawer: Node2D
var constraint_drawer: Node2D

var is_playtesting: bool = false
var show_editor_hints: bool = false

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

func generate_blank_canvas(new_width: int = 3, new_height: int = 3):
	grid_width = new_width
	grid_height = new_height
	board_cells.clear()
	loaded_shifter_pairs.clear()
	loaded_constraint_pairs.clear()
	hidden_constraint_pairs.clear()

	var pool_index = 0
	var margin = 5.0

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
			cell.position = Vector2(float(x * GameConstants.CELL_SIZE), float(y * GameConstants.CELL_SIZE))
			cell.state = GameConstants.TileState.EMPTY
			cell.is_playable = true
			cell.is_locked = false
			cell.is_linked_pair = false
			cell.shifter_direction = Vector2i.ZERO
			cell.is_editor_mode = not is_playtesting
			cell.update_visuals()

			interceptor.size = Vector2(GameConstants.CELL_SIZE - (2 * margin), GameConstants.CELL_SIZE - (2 * margin))
			interceptor.position = cell.position + Vector2(margin, margin)

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

	if not is_playtesting:
		for coord in board_cells:
			var cell = board_cells[coord]
			cell.is_editor_mode = true
			if cell.state == GameConstants.TileState.EMPTY:
				cell.update_visuals()

	move_child(grid_drawer, -1)
	move_child(constraint_drawer, -1)

	cached_lines = BoardRenderer.cache_board_lines(board_cells)
	trigger_redraw()

func load_layout(new_width: int, new_height: int, layout_data: Dictionary, shifter_pairs: Array = [], constraint_pairs: Array = []):
	generate_blank_canvas(new_width, new_height)
	loaded_shifter_pairs = shifter_pairs.duplicate()
	loaded_constraint_pairs = constraint_pairs.duplicate()
	hidden_constraint_pairs.clear()

	for coord in layout_data:
		if board_cells.has(coord):
			var cell = board_cells[coord]
			var saved_state = layout_data[coord]
			cell.state = saved_state
			if saved_state == GameConstants.TileState.WALL:
				cell.is_playable = false
				cell.is_locked = true
			elif saved_state != GameConstants.TileState.EMPTY:
				cell.is_playable = true
				cell.is_locked = true
			else:
				cell.is_playable = true
				cell.is_locked = false
			cell.update_visuals()

	for pair in loaded_shifter_pairs:
		if board_cells.has(pair["a"]):
			board_cells[pair["a"]].is_linked_pair = true
		if board_cells.has(pair["b"]):
			board_cells[pair["b"]].is_linked_pair = true
		if board_cells.has(pair["active"]):
			var active_coord = pair["active"]
			var inactive_coord = pair["b"] if active_coord == pair["a"] else pair["a"]
			board_cells[active_coord].state = GameConstants.TileState.SHIFTER
			board_cells[active_coord].shifter_direction = inactive_coord - active_coord

	for coord in board_cells:
		board_cells[coord].update_visuals()

	move_child(grid_drawer, -1)
	move_child(constraint_drawer, -1)

	trigger_redraw()

func clear_highlights():
	BoardRenderer.clear_highlights(board_cells)

func is_board_full() -> bool:
	return BoardRenderer.is_board_full(board_cells)

func _draw_grid():
	BoardRenderer.draw_grid(grid_drawer, board_cells, GameConstants.CELL_SIZE, not is_playtesting)

func _draw_constraints():
	var pairs_to_draw = loaded_constraint_pairs.duplicate()
	if not is_playtesting and show_editor_hints:
		pairs_to_draw.append_array(hidden_constraint_pairs)
	BoardRenderer.draw_constraints(constraint_drawer, board_cells, pairs_to_draw, GameConstants.CELL_SIZE)
