extends TextureButton

signal cell_clicked(coord: Vector2i)
signal shifter_toggled(coord: Vector2i)

var coord: Vector2i
var state: int = -1
var is_playable: bool = true
var is_locked: bool = false
var is_linked_pair: bool = false
var shifter_direction: Vector2i = Vector2i.ZERO
var allowed_cycle_tiles: Array[int] = [0, 1, 2]
## When true, clicks are ignored (used by scripted tutorials).
var tutorial_blocked: bool = false
## Soft yellow guide highlight for tutorial focus cells.
var guide_active: bool = false

const GUIDE_COLOR := Color(1.0, 0.85, 0.2, 0.5)

@export var tex_empty: Texture2D = preload("res://resources/tiles/tile_empty.svg")
@export var tex_empty_editor: Texture2D = preload("res://resources/tiles/tile_empty_editor.svg")

@export var tex_wall: Texture2D = preload("res://resources/tiles/tile_wall.svg")
@export var tex_yellow: Texture2D = preload("res://resources/tiles/tile_yellow.svg")
@export var tex_blue: Texture2D = preload("res://resources/tiles/tile_blue.svg")
@export var tex_joker: Texture2D = preload("res://resources/tiles/tile_green.svg")
@export var tex_shifter: Texture2D = preload("res://resources/tiles/tile_shifter.svg")

@export var tex_chevron_up: Texture2D
@export var tex_chevron_down: Texture2D
@export var tex_chevron_left: Texture2D
@export var tex_chevron_right: Texture2D

@onready var error_highlight = $ErrorHighlight
@onready var link_highlight = $LinkHighlight
@onready var lock_icon = $LockIcon
@onready var tile_icon = $TileIcon
@onready var chevron_icon = get_node_or_null("ChevronIcon")

const CLICK_MARGIN = 5.0
var is_editor_mode: bool = false

func _ready():
	custom_minimum_size = Vector2(120, 120)

	_stretch_node_to_parent(error_highlight, 0.0)
	_stretch_node_to_parent(link_highlight, 0.0)
	_stretch_node_to_parent(tile_icon, 0.0)

	if lock_icon:
		_stretch_node_to_parent(lock_icon, 0.0)

	if chevron_icon:
		_stretch_node_to_parent(chevron_icon, 0.0)
		chevron_icon.z_index = 4

	if error_highlight:
		error_highlight.z_index = 100
		if "color" in error_highlight:
			error_highlight.color = Color(0, 0, 0, 0)
		error_highlight.draw.connect(_draw_error_border)

	if tile_icon:
		tile_icon.z_index = 3

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

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.position.x > CLICK_MARGIN and event.position.x < (size.x - CLICK_MARGIN) and \
		   event.position.y > CLICK_MARGIN and event.position.y < (size.y - CLICK_MARGIN):
			_perform_action()

func _perform_action():
	if not is_playable or is_locked or tutorial_blocked:
		return

	if state == GameConstants.TileState.SHIFTER:
		shifter_toggled.emit(coord)
	else:
		if state == GameConstants.TileState.EMPTY:
			state = allowed_cycle_tiles[0]
		else:
			var current_idx = allowed_cycle_tiles.find(state)
			if current_idx == -1 or current_idx == allowed_cycle_tiles.size() - 1:
				state = GameConstants.TileState.EMPTY
			else:
				state = allowed_cycle_tiles[current_idx + 1]

		update_visuals()
		cell_clicked.emit(coord)

func update_visuals():
	if lock_icon:
		lock_icon.visible = is_locked and state != GameConstants.TileState.WALL

	if link_highlight:
		if guide_active:
			link_highlight.color = GUIDE_COLOR
			link_highlight.visible = true
		elif is_linked_pair:
			link_highlight.color = Color(0.6, 0.36, 0.9, 0.4)
			link_highlight.visible = true
		else:
			link_highlight.visible = false

	if chevron_icon:
		chevron_icon.offset_left = 0
		chevron_icon.offset_right = 0
		chevron_icon.offset_top = 0
		chevron_icon.offset_bottom = 0

		if state == GameConstants.TileState.SHIFTER and shifter_direction != Vector2i.ZERO:
			chevron_icon.visible = true
			if shifter_direction == Vector2i(0, -1):
				chevron_icon.texture = tex_chevron_up
			elif shifter_direction == Vector2i(0, 1):
				chevron_icon.texture = tex_chevron_down
			elif shifter_direction == Vector2i(-1, 0):
				chevron_icon.texture = tex_chevron_left
				var shift_amount = -3
				chevron_icon.offset_left = shift_amount
				chevron_icon.offset_right = shift_amount
			elif shifter_direction == Vector2i(1, 0):
				chevron_icon.texture = tex_chevron_right
		else:
			chevron_icon.visible = false

	if state == GameConstants.TileState.WALL:
		if is_editor_mode:
			modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			modulate = Color(1.0, 1.0, 1.0, 0.0)
	elif state == GameConstants.TileState.EMPTY:
		modulate = Color(1.0, 1.0, 1.0, 0.85)
	else:
		modulate = Color(1.0, 1.0, 1.0, 1.0)

	if not tile_icon:
		return

	match state:
		GameConstants.TileState.WALL:
			tile_icon.texture = tex_wall
		GameConstants.TileState.EMPTY:
			if is_editor_mode:
				tile_icon.texture = tex_empty_editor
			else:
				tile_icon.texture = tex_empty
		GameConstants.TileState.YELLOW:
			tile_icon.texture = tex_yellow
		GameConstants.TileState.BLUE:
			tile_icon.texture = tex_blue
		GameConstants.TileState.JOKER:
			tile_icon.texture = tex_joker
		GameConstants.TileState.SHIFTER:
			tile_icon.texture = tex_shifter
		_:
			tile_icon.texture = null

func set_error_highlight():
	if error_highlight:
		error_highlight.visible = true
		error_highlight.queue_redraw()

func set_guide_highlight(enabled: bool) -> void:
	guide_active = enabled
	update_visuals()

func set_mask_color(mask_color: Color):
	if link_highlight:
		link_highlight.color = mask_color
		link_highlight.visible = true

func clear_highlight():
	if error_highlight:
		error_highlight.visible = false
