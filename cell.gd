extends TextureButton

signal cell_clicked(coord: Vector2i)

var coord: Vector2i = Vector2i.ZERO
# States: -1 = Empty, 0 = Zero, 1 = One, 2 = Wildcard
var state: int = -1 
var is_locked: bool = false 

@export var texture_empty: Texture2D
@export var texture_zero: Texture2D
@export var texture_one: Texture2D
@export var texture_wildcard: Texture2D

func _ready():
	pressed.connect(_on_pressed)
	update_visuals()

func _on_pressed():
	if is_locked: 
		return # Blocks clicks entirely on pre-placed clues (including wildcards)
		
	# Strict Player Cycle: Empty (-1) -> 0 -> 1 -> resets to Empty (-1)
	state += 1
	if state > 1:
		state = -1
		
	update_visuals()
	cell_clicked.emit(coord)

func update_visuals():
	match state:
		-1: texture_normal = texture_empty
		0: texture_normal = texture_zero
		1: texture_normal = texture_one
		2: texture_normal = texture_wildcard
		
	# Dim locked cells slightly so the player knows they are unchangeable clues
	if is_locked:
		modulate = Color(0.6, 0.6, 0.6) 
	else:
		modulate = Color(1.0, 1.0, 1.0) 

func highlight_error():
	# Tints the cell red to indicate a rule violation
	modulate = Color(1.0, 0.4, 0.4)

func clear_highlight():
	# Restores the original color setup based on lock status
	if is_locked:
		modulate = Color(0.6, 0.6, 0.6)
	else:
		modulate = Color(1.0, 1.0, 1.0)
