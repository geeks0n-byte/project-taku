extends Node2D

@export var cell_scene: PackedScene = preload("res://cell.tscn")

# UI Node References matching your Scene Tree hierarchy
@onready var grid_container = $GridContainer2D
@onready var level_spin_box = $EditorUI/ControlPanel/ConfigContainer/LevelSpinBox
@onready var status_label = $EditorUI/ControlPanel/StatusLabel

# Brush Tool Selection Button References
@onready var empty_button = $EditorUI/ControlPanel/BrushContainer/EmptyButton
@onready var wall_button = $EditorUI/ControlPanel/BrushContainer/WallButton
@onready var zero_button = $EditorUI/ControlPanel/BrushContainer/ZeroButton
@onready var one_button = $EditorUI/ControlPanel/BrushContainer/OneButton
@onready var joker_button = $EditorUI/ControlPanel/BrushContainer/JokerButton

# Layout Action Configuration References
@onready var save_button = $EditorUI/ControlPanel/ConfigContainer/SaveButton
@onready var main_menu_button = $EditorUI/ControlPanel/ConfigContainer/MainMenuButton

const CELL_SIZE = 120
const GRID_WIDTH = 7
const GRID_HEIGHT = 7

# Active brush parameter track state: Default is Empty (-1)
var current_brush_state: int = -1 
var board_cells = {}

func _ready():
	# Connect brush click signals to inline state modifiers
	empty_button.pressed.connect(func(): _set_brush(-1, "Empty (Clear)"))
	wall_button.pressed.connect(func(): _set_brush(-2, "Wall"))
	zero_button.pressed.connect(func(): _set_brush(0, "Prefilled 0"))
	one_button.pressed.connect(func(): _set_brush(1, "Prefilled 1"))
	joker_button.pressed.connect(func(): _set_brush(2, "Joker"))
	
	# Connect execution routines
	save_button.pressed.connect(_on_save_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	
	setup_editor_ui()
	generate_blank_canvas()

func _set_brush(state_id: int, brush_name: String):
	current_brush_state = state_id
	_update_status("Selected Tool: " + brush_name, Color.WHITE)

func setup_editor_ui():
	_set_brush(-1, "Empty (Clear)")
	
	status_label.custom_minimum_size = Vector2(360, 100)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Dynamically calculate position beneath the 7x7 grid footprint
	var board_bottom_y = 180 + (GRID_HEIGHT * CELL_SIZE) 
	var ui_margin_y = 30
	
	# Positions the panel directly under the grid, aligned to the left grid edge (X = 120)
	$EditorUI/ControlPanel.position = Vector2(120, board_bottom_y + ui_margin_y)
	$EditorUI/ControlPanel.set_deferred("size", Vector2(400, 500))
	
	empty_button.text = "Empty"
	wall_button.text = "Wall (-2)"
	zero_button.text = "Fixed 0"
	one_button.text = "Fixed 1"
	joker_button.text = "Joker (2)"
	save_button.text = "SAVE LEVEL"
	main_menu_button.text = "Main Menu"

func generate_blank_canvas():
	for child in grid_container.get_children():
		child.queue_free()
	board_cells.clear()
	
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var coord = Vector2i(x, y)
			var cell = cell_scene.instantiate()
			
			cell.coord = coord
			cell.position = Vector2(float(x * CELL_SIZE), float(y * CELL_SIZE))
			
			# Force default blank slate initialization settings
			cell.state = -1
			cell.is_playable = true
			cell.is_locked = false
			
			grid_container.add_child(cell)
			board_cells[coord] = cell
			cell.update_visuals()
			
			# FIX: Create a transparent overlay to intercept input events cleanly 
			# before they reach the cell script and trip the gameplay lock toggles.
			var input_interceptor = Control.new()
			input_interceptor.size = Vector2(CELL_SIZE, CELL_SIZE)
			input_interceptor.position = cell.position
			input_interceptor.mouse_filter = Control.MOUSE_FILTER_STOP # Swallows the click event
			
			# Custom input detection logic mapped right onto the editor layer
			input_interceptor.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_on_canvas_cell_clicked(coord)
			)
			
			grid_container.add_child(input_interceptor)
			
	queue_redraw()

func _on_canvas_cell_clicked(coord: Vector2i):
	var cell = board_cells[coord]
	cell.state = current_brush_state
	
	# Apply logical flag rules matching game environment expectations
	if current_brush_state == -2:
		cell.is_playable = false
		cell.is_locked = true
	elif current_brush_state != -1:
		cell.is_playable = true
		cell.is_locked = true
	else:
		cell.is_playable = true
		cell.is_locked = false
		
	cell.update_visuals()

func _on_save_pressed():
	var level_num = int(level_spin_box.value)
	var output_layout = {}
	
	for coord in board_cells:
		output_layout[coord] = board_cells[coord].state
		
	# Instantiate and populate the LevelData Resource object
	var new_level_resource = LevelData.new()
	new_level_resource.set_script(load("res://level_data.gd"))
	new_level_resource.level_number = level_num
	new_level_resource.layout = output_layout
	
	# Safeguard storage target paths
	if not DirAccess.dir_exists_absolute("res://levels"):
		DirAccess.make_dir_absolute("res://levels")
		
	var target_save_path = "res://levels/level_%d.tres" % level_num
	var save_result = ResourceSaver.save(new_level_resource, target_save_path)
	
	if save_result == OK:
		_update_status("SUCCESS: Saved level file cleanly to: " + target_save_path, Color(0.4, 1.0, 0.4))
	else:
		_update_status("ERROR: Resource preservation routine failed with code: " + str(save_result), Color(1.0, 0.3, 0.3))

func _on_main_menu_pressed():
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _update_status(msg: String, text_color: Color):
	status_label.text = msg
	status_label.modulate = text_color

func _draw():
	var offset = grid_container.position
	for coord in board_cells:
		var cell_pos = offset + Vector2(coord.x * CELL_SIZE, coord.y * CELL_SIZE)
		draw_rect(Rect2(cell_pos, Vector2(CELL_SIZE, CELL_SIZE)), Color.BLACK, false, 2.0)
