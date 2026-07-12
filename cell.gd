extends TextureButton

signal cell_clicked(coord: Vector2i)

var coord: Vector2i = Vector2i.ZERO
# States: -2 = Wall, -1 = Empty, 0 = Zero, 1 = One, 2 = Wildcard
var state: int = -1 
var is_locked: bool = false 
var is_playable: bool = true
var is_error: bool = false # Track whether to draw the error border

@export var texture_empty: Texture2D
@export var texture_zero: Texture2D
@export var texture_one: Texture2D
@export var texture_wildcard: Texture2D
@export var texture_wall: Texture2D 

func _ready():
	pressed.connect(_on_pressed)
	update_visuals()

func _on_pressed():
	# Block clicks if it's a wall or a locked pre-placed clue
	if not is_playable or is_locked: 
		return 
		
	# Strict Player Cycle: Empty (-1) -> 0 -> 1 -> resets to Empty (-1)
	state += 1
	if state > 1:
		state = -1
		
	update_visuals()
	cell_clicked.emit(coord)

func update_visuals():
	match state:
		-2: texture_normal = texture_wall
		-1: texture_normal = texture_empty
		0: texture_normal = texture_zero
		1: texture_normal = texture_one
		2: texture_normal = texture_wildcard
		
	_apply_modulation()

func _apply_modulation():
	if not is_playable:
		modulate = Color(0.4, 0.4, 0.4)
	elif is_locked:
		modulate = Color(0.6, 0.6, 0.6)
	else:
		modulate = Color(1.0, 1.0, 1.0)

# Custom drawing handles the border canvas item overlay
func _draw() -> void:
	if is_error:
		var rect = Rect2(Vector2.ZERO, size)
		var border_color = Color(1.0, 0.2, 0.2) # Clean red color
		var border_width = 4.0 # Adjust this value to make the border thicker or thinner
		
		# Setting 'filled' (3rd param) to false makes it an outline
		draw_rect(rect, border_color, false, border_width)

func highlight_error():
	if is_playable and not is_error:
		is_error = true
		queue_redraw() # Triggers Godot to run the _draw() function

func clear_highlight():
	if is_error:
		is_error = false
		queue_redraw() # Redraws the cell to clear the drawn border
	_apply_modulation()
