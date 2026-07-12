class_name EditorCanvasManager
extends Node2D

signal canvas_cell_clicked(coord: Vector2i)

@export var cell_scene: PackedScene = preload("res://scenes/cell.tscn")

const CELL_SIZE = 120
const GRID_WIDTH = 7
const GRID_HEIGHT = 7

var board_cells = {}

func _ready():
	position = Vector2(120, 180)

func generate_blank_canvas():
	for child in get_children():
		child.queue_free()
	board_cells.clear()
	
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var coord = Vector2i(x, y)
			var cell = cell_scene.instantiate()
			
			cell.coord = coord
			cell.position = Vector2(float(x * CELL_SIZE), float(y * CELL_SIZE))
			cell.state = -1
			cell.is_playable = true
			cell.is_locked = false
			
			add_child(cell)
			board_cells[coord] = cell
			cell.update_visuals()
			
			var input_interceptor = Control.new()
			input_interceptor.size = Vector2(CELL_SIZE, CELL_SIZE)
			input_interceptor.position = cell.position
			input_interceptor.mouse_filter = Control.MOUSE_FILTER_STOP 
			
			input_interceptor.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					canvas_cell_clicked.emit(coord)
			)
			add_child(input_interceptor)
			
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
	for coord in board_cells:
		var cell_pos = Vector2(coord.x * CELL_SIZE, coord.y * CELL_SIZE)
		draw_rect(Rect2(cell_pos, Vector2(CELL_SIZE, CELL_SIZE)), Color.BLACK, false, 2.0)
