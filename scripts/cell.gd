extends TextureButton

signal cell_clicked(coord: Vector2i)

var coord: Vector2i = Vector2i.ZERO
# States: -2 = Wall, -1 = Empty, 0 = Zero, 1 = One, 2 = Wildcard
var state: int = -1 
var is_locked: bool = false 
var is_playable: bool = true
var is_error: bool = false 

@export var texture_empty: Texture2D
@export var texture_zero: Texture2D
@export var texture_one: Texture2D
@export var texture_wildcard: Texture2D
@export var texture_wall: Texture2D 

@onready var error_highlight = $ErrorHighlight 
@onready var lock_icon = $LockIcon # NEW: Reference to the lock image

func _ready():
	pressed.connect(_on_pressed)
	
	if error_highlight:
		error_highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
	update_visuals()

func _on_pressed():
	if not is_playable or is_locked: 
		return 
		
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
		
	_update_overlays()

# CHANGED: Handles the lock icon visibility and ensures the tile stays bright
func _update_overlays():
	self_modulate = Color(1.0, 1.0, 1.0)
	
	if lock_icon:
		if is_locked and (state == 0 or state == 1):
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
