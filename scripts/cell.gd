extends TextureButton

signal cell_clicked(coord: Vector2i)
signal shifter_toggled(coord: Vector2i)

var coord: Vector2i
var state: int = -1
var is_playable: bool = true
var is_locked: bool = false
var is_linked_pair: bool = false
var link_partner: Vector2i
var allowed_cycle_tiles: Array[int] = [0, 1]

@export var tex_empty: Texture2D
@export var tex_wall: Texture2D
@export var tex_zero: Texture2D = preload("res://icons/tiles/tile_yellow.svg")
@export var tex_one: Texture2D = preload("res://icons/tiles/tile_blue.svg")
@export var tex_joker: Texture2D = preload("res://icons/tiles/tile_green.svg")
@export var tex_shifter: Texture2D = preload("res://icons/tiles/tile_purple.svg")

@onready var error_highlight = $ErrorHighlight
@onready var link_highlight = $LinkHighlight
@onready var lock_icon = $LockIcon
@onready var tile_icon = $TileIcon

func _ready():
	custom_minimum_size = Vector2(120, 120)
	
	_stretch_node_to_parent(error_highlight, 0.0) 
	_stretch_node_to_parent(link_highlight, 0.0)
	_stretch_node_to_parent(tile_icon, 0.0)
	if lock_icon:
		_stretch_node_to_parent(lock_icon, 0.0)
		
	if error_highlight: 
		error_highlight.z_index = 100
		if "color" in error_highlight:
			error_highlight.color = Color(0, 0, 0, 0)
		error_highlight.draw.connect(_draw_error_border)
		
	if tile_icon: tile_icon.z_index = 3
		
	pressed.connect(_on_pressed)

func _draw_error_border():
	if error_highlight:
		error_highlight.draw_rect(Rect2(Vector2.ZERO, error_highlight.size), Color.RED, false, 10.0)

func _stretch_node_to_parent(node: Control, margin: float = 0.0):
	if node:
		node.set_anchors_preset(Control.PRESET_FULL_RECT)
		node.anchor_left = 0.0
		node.anchor_top = 0.0
		node.anchor_right = 1.0
		node.anchor_bottom = 1.0
		node.offset_left = -margin
		node.offset_top = -margin
		node.offset_right = margin
		node.offset_bottom = margin

func _on_pressed():
	if not is_playable or is_locked:
		return
		
	if state == 3:
		shifter_toggled.emit(coord)
	else:
		if state == -1:
			state = allowed_cycle_tiles[0]
		else:
			var current_idx = allowed_cycle_tiles.find(state)
			if current_idx == -1 or current_idx == allowed_cycle_tiles.size() - 1:
				state = -1
			else:
				state = allowed_cycle_tiles[current_idx + 1]
				
		update_visuals()
		cell_clicked.emit(coord)

func update_visuals():
	if lock_icon:
		lock_icon.visible = is_locked and state != -2
		
	if link_highlight:
		if is_linked_pair:
			link_highlight.color = Color(0.6, 0.36, 0.9, 0.4)
			link_highlight.visible = true
		else:
			link_highlight.visible = false
		
	if not tile_icon:
		return
		
	match state:
		-2: tile_icon.texture = tex_wall
		-1: tile_icon.texture = tex_empty
		0: tile_icon.texture = tex_zero
		1: tile_icon.texture = tex_one
		2: tile_icon.texture = tex_joker
		3: tile_icon.texture = tex_shifter
		_: tile_icon.texture = null

func set_error_highlight():
	if error_highlight:
		error_highlight.visible = true
		error_highlight.queue_redraw()

func set_mask_color(mask_color: Color):
	if link_highlight:
		link_highlight.color = mask_color
		link_highlight.visible = true

func clear_highlight():
	if error_highlight:
		error_highlight.visible = false
