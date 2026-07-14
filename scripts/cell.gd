extends TextureButton

signal cell_clicked(coord: Vector2i)
signal red_toggled(coord: Vector2i) # Notifies BoardManager to swap the shifter

var coord: Vector2i = Vector2i.ZERO
# States: -2=Wall, -1=Empty, 0=Yellow, 1=Blue, 2=Green, 3=Red Shifter
var state: int = -1 
var is_locked: bool = false 
var is_playable: bool = true
var is_error: bool = false 

var allowed_cycle_tiles: Array[int] = [0, 1]

# --- NEW RED TILE PAIR VARIABLES ---
var is_part_of_pair: bool = false
var pair_partner: Vector2i = Vector2i.ZERO

@export var texture_empty: Texture2D
@export var texture_zero: Texture2D
@export var texture_one: Texture2D
@export var texture_wildcard: Texture2D
@export var texture_wall: Texture2D 
@export var texture_red: Texture2D # Remember to assign tile_red.svg in the inspector!

@onready var error_highlight = $ErrorHighlight 
@onready var lock_icon = $LockIcon 
@onready var pair_highlight = $PairHighlight # The node you added in the GUI step

func _ready():
	pressed.connect(_on_pressed)
	
	if error_highlight:
		error_highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if pair_highlight:
		pair_highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
	update_visuals()

func _on_pressed():
	if not is_playable or is_locked: 
		return 
		
	# NEW: Click behavior for the Red Shifter
	if state == 3:
		red_toggled.emit(coord)
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
		3: texture_normal = texture_red
		
	_update_overlays()

func _update_overlays():
	self_modulate = Color(1.0, 1.0, 1.0)
	
	if lock_icon:
		# Hide locks on Red Shifters since they are moved, not cycled
		if is_locked and (state >= 0 and state <= 2):
			lock_icon.visible = true
		else:
			lock_icon.visible = false
			
	# Show the yellow border if this cell is linked to a partner
	if pair_highlight:
		pair_highlight.visible = is_part_of_pair

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
