class_name BoardManager
extends Node2D

signal cell_changed(coord: Vector2i)

@export var cell_scene: PackedScene = preload("res://scenes/cell.tscn")
const CELL_SIZE = 120 

var board_cells = {}

func _ready():
	position = Vector2(120, 180)

func build_grid(layout_data: Dictionary):
	for child in get_children():
		child.queue_free()
	board_cells.clear()

	for coord in layout_data:
		var starting_state = layout_data[coord]
		var cell = cell_scene.instantiate()
		cell.coord = coord
		cell.position = Vector2(float(coord.x * CELL_SIZE), float(coord.y * CELL_SIZE))
		cell.cell_clicked.connect(func(c): cell_changed.emit(c))
		
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
			
		add_child(cell)
		board_cells[coord] = cell
		cell.update_visuals()
		
	queue_redraw()

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
