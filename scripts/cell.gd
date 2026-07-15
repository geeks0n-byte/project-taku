extends TextureButton

signal cell_clicked(coord: Vector2i)
signal shifter_toggled(coord: Vector2i)

var coord: Vector2i = Vector2i.ZERO
# States: -2=Wall, -1=Empty, 0=Zero, 1=One, 2=Joker, 3=Shifter
var state: int = -1 
var is_locked: bool = false 
var is_playable: bool = true
var is_error: bool = false 

var allowed_cycle_tiles: Array[int] = [0, 1]

# --- SHIFTER LINK SYSTEM DATA ---
var is_linked_pair: bool = false
var link_partner: Vector2i = Vector2i.ZERO

# --- REORDERED EXPORTS ---
@export var texture_wall: Texture2D 
@export var texture_empty: Texture2D
@export var texture_zero: Texture2D
@export var texture_one: Texture2D
@export var texture_wildcard: Texture2D
@export var texture_shifter: Texture2D 

@onready var error_highlight = $ErrorHighlight 
@onready var lock_icon = $LockIcon 
@onready var link_highlight = $LinkHighlight 

func _ready():
	pressed.connect(_on_pressed)
	
	if error_highlight:
		error_highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if link_highlight:
		link_highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
	update_visuals()

func _on_pressed():
	if not is_playable or is_locked: 
		return 
		
	if state == 3:
		shifter_toggled.emit(coord)
		return
		
	if allowed_cycle_tiles.size() == 0:
		allowed_cycle_tiles = [0, 1]
		
	if state == -1:
		state = allowed_cycle_tiles[0]
	else:
		var current_index = allowed_cycle_tiles.find(state)
		if current_index == -1 or current_index == allowed_cycle_tiles.size() - 1:
			state = -1
		else:
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
		3: texture_normal = texture_shifter
		
	_update_overlays()

func _update_overlays():
	self_modulate = Color(1.0, 1.0, 1.0)
	
	if lock_icon:
		if is_locked and (state >= 0 and state <= 2):
			lock_icon.visible = true
		else:
			lock_icon.visible = false
			
	if link_highlight:
		link_highlight.visible = is_linked_pair

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
