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
var tutorial_blocked: bool = false
var guide_active: bool = false
var focus_active: bool = false
var validation_error_active: bool = false

const GUIDE_COLOR := Color(1.0, 1.0, 1.0, 0.45)
const GUIDE_ALPHA_MIN := 0.22
const GUIDE_ALPHA_MAX := 0.72
const FOCUS_BORDER_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const FOCUS_BORDER_ALPHA_MIN := 0.35
const FOCUS_BORDER_ALPHA_MAX := 1.0
const ERROR_BORDER_COLOR := Color.RED

var _guide_breathe_tween: Tween
var _focus_breathe_tween: Tween
var _shake_tween: Tween
var _focus_border_alpha: float = 1.0
var _shake_rest_position: Vector2 = Vector2.ZERO

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
		var clear_style := StyleBoxFlat.new()
		clear_style.bg_color = Color(0, 0, 0, 0)
		clear_style.set_border_width_all(0)
		error_highlight.add_theme_stylebox_override("panel", clear_style)
		if not error_highlight.draw.is_connected(_draw_error_border):
			error_highlight.draw.connect(_draw_error_border)

	if tile_icon:
		tile_icon.z_index = 3

func _draw_error_border():
	if error_highlight == null:
		return
	var border_color: Color
	if validation_error_active:
		border_color = ERROR_BORDER_COLOR
	else:
		border_color = Color(
			FOCUS_BORDER_COLOR.r,
			FOCUS_BORDER_COLOR.g,
			FOCUS_BORDER_COLOR.b,
			_focus_border_alpha
		)
	error_highlight.draw_rect(Rect2(Vector2.ZERO, error_highlight.size), border_color, false, 10.0)

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
		var cycle: Array[int] = allowed_cycle_tiles
		if cycle.is_empty():
			cycle = [
				GameConstants.TileState.YELLOW,
				GameConstants.TileState.BLUE,
				GameConstants.TileState.JOKER,
			]
		if state == GameConstants.TileState.EMPTY:
			state = cycle[0]
		else:
			var current_idx := -1
			for i in range(cycle.size()):
				if int(cycle[i]) == int(state):
					current_idx = i
					break
			if current_idx == -1 or current_idx == cycle.size() - 1:
				state = GameConstants.TileState.EMPTY
			else:
				state = int(cycle[current_idx + 1])

		update_visuals()
		cell_clicked.emit(coord)

func update_visuals():
	if lock_icon:
		lock_icon.visible = is_locked and state != GameConstants.TileState.WALL

	if link_highlight:
		var show_guide := guide_active and state != GameConstants.TileState.WALL
		if show_guide:
			var alpha: float = (
				float(link_highlight.color.a) if link_highlight.visible else GUIDE_ALPHA_MAX
			)
			link_highlight.color = Color(GUIDE_COLOR.r, GUIDE_COLOR.g, GUIDE_COLOR.b, alpha)
			link_highlight.visible = true
			if guide_active and _guide_breathe_tween == null:
				_start_guide_breathe()
		elif is_linked_pair:
			if _guide_breathe_tween:
				_stop_guide_breathe()
			link_highlight.color = Color(0.6, 0.36, 0.9, 0.4)
			link_highlight.visible = true
		else:
			if guide_active and _guide_breathe_tween:
				_stop_guide_breathe()
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
	validation_error_active = true
	_stop_focus_breathe()
	if error_highlight:
		error_highlight.visible = true
		error_highlight.queue_redraw()

func play_blocked_shake() -> void:
	if UiSfx:
		UiSfx.play_blocked_haptic()
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
		position = _shake_rest_position
	_shake_rest_position = position
	var axis := Vector2(1.0, 0.0)
	if abs(shifter_direction.y) > abs(shifter_direction.x):
		axis = Vector2(0.0, 1.0)
	_shake_tween = create_tween()
	var amp := 7.0
	for i in 5:
		var dir := 1.0 if (i % 2) == 0 else -1.0
		_shake_tween.tween_property(
			self, "position", _shake_rest_position + axis * (dir * amp), 0.035
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		amp *= 0.65
	_shake_tween.tween_property(self, "position", _shake_rest_position, 0.04)

func set_guide_highlight(enabled: bool) -> void:
	guide_active = enabled
	_stop_guide_breathe()
	update_visuals()
	if enabled and (
		state == GameConstants.TileState.EMPTY
		or is_locked
		or state == GameConstants.TileState.SHIFTER
	):
		_start_guide_breathe()

func set_focus_highlight(enabled: bool) -> void:
	focus_active = enabled
	_stop_focus_breathe()
	if error_highlight:
		error_highlight.visible = enabled or validation_error_active
		if error_highlight.visible:
			error_highlight.queue_redraw()
	if enabled and not validation_error_active:
		_start_focus_breathe()

func set_mask_color(mask_color: Color):
	if link_highlight:
		link_highlight.color = mask_color
		link_highlight.visible = true

func clear_highlight():
	validation_error_active = false
	if error_highlight:
		error_highlight.visible = focus_active
		if focus_active:
			error_highlight.queue_redraw()
			if not _focus_breathe_tween:
				_start_focus_breathe()

func _start_guide_breathe() -> void:
	if link_highlight == null or not guide_active:
		return
	if state == GameConstants.TileState.WALL:
		return
	_stop_guide_breathe()
	link_highlight.visible = true
	link_highlight.color = Color(GUIDE_COLOR.r, GUIDE_COLOR.g, GUIDE_COLOR.b, GUIDE_ALPHA_MAX)
	_guide_breathe_tween = create_tween().set_loops()
	_guide_breathe_tween.tween_property(
		link_highlight, "color:a", GUIDE_ALPHA_MIN, 1.1
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_guide_breathe_tween.tween_property(
		link_highlight, "color:a", GUIDE_ALPHA_MAX, 1.1
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_guide_breathe() -> void:
	if _guide_breathe_tween:
		_guide_breathe_tween.kill()
		_guide_breathe_tween = null
	if link_highlight and guide_active and state != GameConstants.TileState.WALL:
		link_highlight.color = GUIDE_COLOR

func _start_focus_breathe() -> void:
	if error_highlight == null or not focus_active or validation_error_active:
		return
	_stop_focus_breathe()
	_focus_border_alpha = FOCUS_BORDER_ALPHA_MAX
	error_highlight.queue_redraw()
	_focus_breathe_tween = create_tween().set_loops()
	_focus_breathe_tween.tween_method(_set_focus_border_alpha, FOCUS_BORDER_ALPHA_MAX, FOCUS_BORDER_ALPHA_MIN, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_focus_breathe_tween.tween_method(_set_focus_border_alpha, FOCUS_BORDER_ALPHA_MIN, FOCUS_BORDER_ALPHA_MAX, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_focus_breathe() -> void:
	if _focus_breathe_tween:
		_focus_breathe_tween.kill()
		_focus_breathe_tween = null
	_focus_border_alpha = FOCUS_BORDER_ALPHA_MAX
	if error_highlight and focus_active:
		error_highlight.queue_redraw()

func _set_focus_border_alpha(alpha: float) -> void:
	_focus_border_alpha = alpha
	if error_highlight and error_highlight.visible:
		error_highlight.queue_redraw()
