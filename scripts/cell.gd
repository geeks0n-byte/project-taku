extends TextureButton

signal cell_clicked(coord: Vector2i)

var coord: Vector2i = Vector2i.ZERO
# States: -2 = Wall, -1 = Empty, 0 = Zero, 1 = One, 2 = Wildcard
var state: int = -1 
var is_locked: bool = false 
var is_playable: bool = true
var is_error: bool = false 

# NEW: Tells this specific cell which values it is allowed to cycle through when clicked.
# Automatically falls back to [0, 1] if not configured.
var allowed_cycle_tiles: Array[int] = [0, 1]

@export var texture_empty: Texture2D
@export var texture_zero: Texture2D
@export var texture_one: Texture2D
@export var texture_wildcard: Texture2D
@export var texture_wall: Texture2D 

@onready var error_highlight = $ErrorHighlight 
@onready var lock_icon = $LockIcon # Reference to the lock image

func _ready():
	pressed.connect(_on_pressed)
	
	if error_highlight:
		error_highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
	update_visuals()

# UPDATED: Dynamic step-through rotation based on the current level's rules
func _on_pressed():
	if not is_playable or is_locked: 
		return 
		
	if allowed_cycle_tiles.size() == 0:
		# If somehow empty, default to standard Red/Blue cycle safety behavior
		allowed_cycle_tiles = [0, 1]
		
	if state == -1:
		# Move from empty to the first allowed tile in the array
		state = allowed_cycle_tiles[0]
	else:
		var current_index = allowed_cycle_tiles.find(state)
		if current_index == -1 or current_index == allowed_cycle_tiles.size() - 1:
			# If the state isn't in the list or we reached the last tile, return to empty
			state = -1
		else:
			# Otherwise, cycle to the next allowed tile
			state = allowed_cycle_tiles[current_index + 1]
		
	update_visuals()
	cell_clicked.emit(coord)

func update_visuals():
	match state:
		-2: texture_normal = texture_wall
		-1: texture_normal = texture_empty
		0: texture_normal = texture_zero
		1: texture_normal = texture_one
		2: texture_normal = texture_wildcard
		
	_update_overlays()

func _update_overlays():
	self_modulate = Color(1.0, 1.0, 1.0)
	
	if lock_icon:
		if is_locked and (state == 0 or state == 1 or state == 2):
			lock_icon.visible = true
		else:
			lock_icon.visible = false

func highlight_error():
	if is_playable and not is_error:
		is_error = true
		if error_highlight:
			error_highlight.visible = true

func clear_highlight():
	if is_error:
		is_error = false
		if error_highlight:
			error_highlight.visible = false
	_update_overlays()
