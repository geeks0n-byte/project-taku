extends TextureButton

signal cell_clicked(coord: Vector2i)

var coord: Vector2i = Vector2i.ZERO
# States: -2 = Wall, -1 = Empty, 0 = Zero, 1 = One, 2 = Wildcard
var state: int = -1 
var is_locked: bool = false 
var is_playable: bool = true

@export var texture_empty: Texture2D
@export var texture_zero: Texture2D
@export var texture_one: Texture2D
@export var texture_wildcard: Texture2D
@export var texture_wall: Texture2D # New texture slot for the wall

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

func highlight_error():
	if is_playable:
		modulate = Color(1.0, 0.4, 0.4)

func clear_highlight():
	_apply_modulation()
