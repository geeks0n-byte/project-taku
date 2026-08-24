extends TextureButton

# Emitted when the player taps the tile (cycles its state).
signal cell_clicked(coord: Vector2i)
# Emitted when the player holds the tile long enough to clear it.
signal cell_hold_cleared(coord: Vector2i)
# Emitted when a shifter tile is tapped (toggles its direction).
signal shifter_toggled(coord: Vector2i)

# Grid position of this cell, set by BoardManager when the board is built.
var coord: Vector2i
var state: int = -1
var is_playable: bool = true
var is_locked: bool = false
var is_linked_pair: bool = false
var shifter_direction: Vector2i = Vector2i.ZERO
# Which tile states the player can cycle through on this cell.
var allowed_cycle_tiles: Array[int] = [0, 1, 2]
var tutorial_blocked: bool = false
var guide_active: bool = false
var focus_active: bool = false
var validation_error_active: bool = false

# How long the player must hold before the tile is cleared.
const HOLD_TO_CLEAR_SEC := 0.8
# How long into the hold before the shake animation starts (gives early feedback).
const HOLD_SHAKE_START_SEC := 0.15

# Hold-to-clear state — all reset when the finger is lifted.
var _hold_pressed: bool = false
var _hold_elapsed: float = 0.0
var _hold_cleared: bool = false   # True once the clear has triggered this press.
var _hold_shaking: bool = false
var _hold_shake_tween: Tween
var _hold_clear_tween: Tween      # Stored so it can be killed if the node exits.

# Guide highlight (white overlay on cells the hint system points to).
const GUIDE_COLOR := Color(1.0, 1.0, 1.0, 0.45)
const GUIDE_ALPHA_MIN := 0.22
const GUIDE_ALPHA_MAX := 0.72

# Focus/error border drawn around the cell.
const FOCUS_BORDER_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const FOCUS_BORDER_ALPHA_MIN := 0.35
const FOCUS_BORDER_ALPHA_MAX := 1.0
const ERROR_BORDER_COLOR := Color.RED
const HIGHLIGHT_INSET := 4.0
const HIGHLIGHT_BORDER_WIDTH := 4.0
const HIGHLIGHT_FILL_ALPHA_SCALE := 0.55
# Tile SVGs are 16×16 with a 1px empty rim, so the painted tile is 14×14.
const TILE_ART_GRID := 16.0
const TILE_ART_PAD := 1.0

var _guide_breathe_tween: Tween
var _focus_breathe_tween: Tween
var _shake_tween: Tween           # Used for the blocked-move lateral shake.
var _focus_border_alpha: float = 1.0
var _shake_rest_position: Vector2 = Vector2.ZERO
var _tutorial_fill: ColorRect

# Tile textures — assigned in the scene editor, overridable per cell type.
@export var tex_empty: Texture2D = preload("res://resources/tiles/tile_empty.svg")
@export var tex_empty_editor: Texture2D = preload("res://resources/tiles/tile_empty_editor.svg")
@export var tex_wall: Texture2D = preload("res://resources/tiles/tile_wall.svg")
@export var tex_yellow: Texture2D = preload("res://resources/tiles/tile_yellow.svg")
@export var tex_blue: Texture2D = preload("res://resources/tiles/tile_blue.svg")
@export var tex_joker: Texture2D = preload("res://resources/tiles/tile_green.svg")
@export var tex_shifter: Texture2D = preload("res://resources/tiles/tile_shifter.svg")

# Chevron textures for shifter direction indicators.
@export var tex_chevron_up: Texture2D
@export var tex_chevron_down: Texture2D
@export var tex_chevron_left: Texture2D
@export var tex_chevron_right: Texture2D

@onready var error_highlight = $ErrorHighlight
@onready var link_highlight = $LinkHighlight
@onready var lock_icon = $LockIcon
@onready var tile_icon = $TileIcon
@onready var chevron_icon = get_node_or_null("ChevronIcon")

# Pixels of margin from the tile edge that are ignored for tap detection.
const CLICK_MARGIN = 5.0
var is_editor_mode: bool = false

# Kill all active tweens when the node leaves the tree to prevent
# callbacks firing on a freed object (e.g. during board reset).
func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		for tw in [_hold_shake_tween, _hold_clear_tween, _guide_breathe_tween, _focus_breathe_tween, _shake_tween]:
			if tw and tw.is_valid():
				tw.kill()

func _ready():
	set_process(false)
	custom_minimum_size = Vector2(120, 120)
	clip_contents = false

	_stretch_node_to_parent(error_highlight, 0.0)
	_stretch_node_to_parent(link_highlight, 0.0)
	_stretch_node_to_parent(tile_icon, 0.0)
	if tile_icon:
		tile_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tile_icon.stretch_mode = TextureRect.STRETCH_SCALE
		tile_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tile_icon.z_index = 3

	if lock_icon:
		_stretch_node_to_parent(lock_icon, 0.0)
		lock_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	if chevron_icon:
		_stretch_node_to_parent(chevron_icon, 0.0)
		chevron_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		chevron_icon.z_index = 4

	if error_highlight:
		error_highlight.z_index = 100
		var clear_style := StyleBoxFlat.new()
		clear_style.bg_color = Color(0, 0, 0, 0)
		clear_style.set_border_width_all(0)
		error_highlight.add_theme_stylebox_override("panel", clear_style)
		if not error_highlight.draw.is_connected(_draw_error_border):
			error_highlight.draw.connect(_draw_error_border)
		error_highlight.clip_contents = false
		_tutorial_fill = ColorRect.new()
		_tutorial_fill.name = "TutorialFill"
		_tutorial_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tutorial_fill.color = Color(
			FOCUS_BORDER_COLOR.r, FOCUS_BORDER_COLOR.g, FOCUS_BORDER_COLOR.b,
			FOCUS_BORDER_ALPHA_MAX * HIGHLIGHT_FILL_ALPHA_SCALE
		)
		_tutorial_fill.visible = false
		_tutorial_fill.z_index = 50
		add_child(_tutorial_fill)
		_layout_highlight_overlays()
		if not resized.is_connected(_layout_highlight_overlays):
			resized.connect(_layout_highlight_overlays)
		if tile_icon and not tile_icon.resized.is_connected(_layout_highlight_overlays):
			tile_icon.resized.connect(_layout_highlight_overlays)

func _draw_error_border():
	if error_highlight == null:
		return
	if validation_error_active:
		error_highlight.draw_rect(
			Rect2(Vector2.ZERO, error_highlight.size), ERROR_BORDER_COLOR, false, 10.0
		)
		return
	if not focus_active:
		return
	if guide_active and focus_active:
		# Fill is a ColorRect sized in layout, not draw_rect (avoids pixel snap).
		return
	var inner := _highlight_inner_rect()
	var border_color := Color(
		FOCUS_BORDER_COLOR.r,
		FOCUS_BORDER_COLOR.g,
		FOCUS_BORDER_COLOR.b,
		_focus_border_alpha
	)
	error_highlight.draw_rect(inner, border_color, false, HIGHLIGHT_BORDER_WIDTH)

func _highlight_inner_rect() -> Rect2:
	var panel_size: Vector2 = error_highlight.size
	# Unfilled draw_rect includes both far edges, which reads 1px too wide/tall.
	return Rect2(
		Vector2(HIGHLIGHT_INSET, HIGHLIGHT_INSET),
		panel_size - Vector2(HIGHLIGHT_INSET * 2.0 + 1.0, HIGHLIGHT_INSET * 2.0 + 1.0)
	)

func _layout_tutorial_fill() -> void:
	_layout_highlight_overlays()

func _layout_highlight_overlays() -> void:
	_apply_tile_art_frame(_tutorial_fill)
	if link_highlight and link_highlight.visible:
		_apply_tile_art_frame(link_highlight)

func _highlight_cell_size() -> Vector2:
	return Vector2(GameConstants.CELL_SIZE, GameConstants.CELL_SIZE)

func _apply_tile_art_frame(node: Control) -> void:
	if node == null:
		return
	var pad := _highlight_cell_size() / TILE_ART_GRID * TILE_ART_PAD
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	var left := floorf(pad.x)
	var top := floorf(pad.y)
	var right := -ceilf(pad.x)
	var bottom := -ceilf(pad.y)
	if node == link_highlight or node == _tutorial_fill:
		left += 1.0
		top += 1.0
		right += 1.0
		bottom += 1.0
	node.offset_left = left
	node.offset_top = top
	node.offset_right = right
	node.offset_bottom = bottom

func _apply_full_cell_frame(node: Control) -> void:
	if node == null:
		return
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0

func _set_tutorial_fill_visible(enabled: bool) -> void:
	if _tutorial_fill == null:
		return
	_layout_tutorial_fill()
	_tutorial_fill.visible = enabled
	if enabled:
		_tutorial_fill.color = Color(
			FOCUS_BORDER_COLOR.r, FOCUS_BORDER_COLOR.g, FOCUS_BORDER_COLOR.b,
			_focus_border_alpha * HIGHLIGHT_FILL_ALPHA_SCALE
		)

func _uses_unified_highlight() -> bool:
	return guide_active and focus_active and not validation_error_active

func _update_highlight_breathe() -> void:
	_stop_guide_breathe()
	_stop_focus_breathe()
	if validation_error_active:
		return
	if _uses_unified_highlight():
		if state != GameConstants.TileState.WALL:
			_start_unified_breathe()
	elif guide_active:
		if (
			state == GameConstants.TileState.EMPTY
			or is_locked
			or state == GameConstants.TileState.SHIFTER
		):
			_start_guide_breathe()
	elif focus_active:
		_start_focus_breathe()

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
	# Editor placement uses canvas interceptors / brush input — never cycle here.
	if is_editor_mode:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.position.x > CLICK_MARGIN and event.position.x < (size.x - CLICK_MARGIN) and \
			   event.position.y > CLICK_MARGIN and event.position.y < (size.y - CLICK_MARGIN):
				_hold_pressed = true
				_hold_elapsed = 0.0
				_hold_cleared = false
				set_process(true)
		else:
			_on_release()

# Cycles the tile to its next allowed state, or toggles the shifter direction.
# Called on finger release if no hold-clear happened.
func _perform_action():
	if is_editor_mode:
		return
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
		if UiSfx:
			UiSfx.play_click()
		cell_clicked.emit(coord)

# Returns true if the current tile state and flags allow a hold-clear.
# Wall, empty, and shifter tiles cannot be cleared this way.
func _can_hold_clear() -> bool:
	if is_editor_mode or is_locked or tutorial_blocked or not is_playable:
		return false
	if state == GameConstants.TileState.EMPTY or state == GameConstants.TileState.WALL or state == GameConstants.TileState.SHIFTER:
		return false
	return true

# Runs every frame while the player is holding the tile.
# Triggers the shake animation after HOLD_SHAKE_START_SEC,
# then clears the tile after HOLD_TO_CLEAR_SEC.
func _process(delta: float) -> void:
	if not _hold_pressed:
		set_process(false)
		return
	_hold_elapsed += delta
	if _hold_elapsed >= HOLD_SHAKE_START_SEC and not _hold_shaking and _can_hold_clear():
		_start_hold_shake()
	if _hold_elapsed >= HOLD_TO_CLEAR_SEC and _can_hold_clear():
		_finish_hold_clear()

# Called when the finger is lifted. If no clear happened, performs the normal tap action.
func _on_release() -> void:
	var was_cleared := _hold_cleared
	_hold_pressed = false
	_hold_elapsed = 0.0
	_hold_cleared = false
	if _hold_shaking:
		_stop_hold_shake()
	set_process(false)
	if not was_cleared:
		_perform_action()

# Cancels the hold without firing any action (e.g. called externally to interrupt).
func _cancel_hold() -> void:
	_hold_pressed = false
	_hold_elapsed = 0.0
	_hold_cleared = false
	if _hold_shaking:
		_stop_hold_shake()
	set_process(false)

# Starts a looping left-right rotation tween to signal an imminent clear.
# Animates tile visuals only so error/focus borders stay fixed in place.
func _start_hold_shake() -> void:
	_hold_shaking = true
	_prepare_hold_visual_pivots()
	_reset_hold_visual_transforms()
	if _hold_shake_tween and _hold_shake_tween.is_valid():
		_hold_shake_tween.kill()
	_hold_shake_tween = create_tween().set_loops()
	var intensity := deg_to_rad(3.0)
	_hold_shake_tween.tween_method(_set_hold_visual_rotation, 0.0, intensity, 0.04).set_trans(Tween.TRANS_SINE)
	_hold_shake_tween.tween_method(_set_hold_visual_rotation, intensity, -intensity, 0.08).set_trans(Tween.TRANS_SINE)
	_hold_shake_tween.tween_method(_set_hold_visual_rotation, -intensity, 0.0, 0.04).set_trans(Tween.TRANS_SINE)

# Stops the shake tween and snaps tile visuals back to rest.
func _stop_hold_shake() -> void:
	_hold_shaking = false
	if _hold_shake_tween and _hold_shake_tween.is_valid():
		_hold_shake_tween.kill()
		_hold_shake_tween = null
	_reset_hold_visual_transforms()

# Locks in the clear, plays haptic, then runs the pop-out shrink animation.
# _apply_hold_clear is called at the end of the tween to actually reset the tile.
func _finish_hold_clear() -> void:
	_hold_pressed = false
	_hold_cleared = true
	set_process(false)
	if _hold_shake_tween and _hold_shake_tween.is_valid():
		_hold_shake_tween.kill()
		_hold_shake_tween = null
	if UiSfx:
		UiSfx.play_clear()
	_prepare_hold_visual_pivots()
	if _hold_clear_tween and _hold_clear_tween.is_valid():
		_hold_clear_tween.kill()
	_hold_clear_tween = create_tween()
	_hold_clear_tween.set_parallel(true)
	_hold_clear_tween.tween_method(
		_set_hold_visual_scale, Vector2.ONE, Vector2.ZERO, 0.18
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_hold_clear_tween.tween_method(
		_set_hold_visual_rotation, 0.0, deg_to_rad(15.0), 0.18
	).set_trans(Tween.TRANS_SINE)
	_hold_clear_tween.chain().tween_callback(_apply_hold_clear)

# Tween callback: resets visual transforms, sets state to EMPTY, and emits the signal.
func _apply_hold_clear() -> void:
	_reset_hold_visual_transforms()
	_hold_shaking = false
	state = GameConstants.TileState.EMPTY
	update_visuals()
	cell_hold_cleared.emit(coord)

func _hold_visual_nodes() -> Array[Control]:
	var nodes: Array[Control] = []
	for n in [tile_icon, lock_icon, chevron_icon, link_highlight]:
		if n:
			nodes.append(n)
	return nodes

func _prepare_hold_visual_pivots() -> void:
	for n in _hold_visual_nodes():
		n.pivot_offset = n.size * 0.5

func _set_hold_visual_rotation(radians: float) -> void:
	for n in _hold_visual_nodes():
		n.rotation = radians

func _set_hold_visual_scale(s: Vector2) -> void:
	for n in _hold_visual_nodes():
		n.scale = s

func _reset_hold_visual_transforms() -> void:
	for n in _hold_visual_nodes():
		n.scale = Vector2.ONE
		n.rotation = 0.0

func update_visuals():
	if lock_icon:
		lock_icon.visible = is_locked and state != GameConstants.TileState.WALL

	if link_highlight:
		var show_guide := guide_active and state != GameConstants.TileState.WALL
		if show_guide and _uses_unified_highlight():
			if _guide_breathe_tween:
				_stop_guide_breathe()
			link_highlight.visible = false
			_set_tutorial_fill_visible(true)
		elif show_guide:
			_set_tutorial_fill_visible(false)
			var alpha: float = GUIDE_ALPHA_MAX
			if link_highlight.visible:
				alpha = float(link_highlight.color.a)
			link_highlight.color = Color(GUIDE_COLOR.r, GUIDE_COLOR.g, GUIDE_COLOR.b, alpha)
			_apply_tile_art_frame(link_highlight)
			link_highlight.visible = true
			call_deferred("_layout_highlight_overlays")
		elif is_linked_pair:
			_set_tutorial_fill_visible(false)
			if _guide_breathe_tween:
				_stop_guide_breathe()
			link_highlight.color = Color(0.6, 0.36, 0.9, 0.4)
			_apply_tile_art_frame(link_highlight)
			link_highlight.visible = true
			call_deferred("_layout_highlight_overlays")
		else:
			if guide_active and _guide_breathe_tween:
				_stop_guide_breathe()
			link_highlight.visible = false
			if not _uses_unified_highlight():
				_set_tutorial_fill_visible(false)

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
	_stop_guide_breathe()
	_stop_focus_breathe()
	if link_highlight and guide_active and not _uses_unified_highlight():
		link_highlight.visible = true
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
	update_visuals()
	_update_highlight_breathe()

func set_focus_highlight(enabled: bool) -> void:
	focus_active = enabled
	if error_highlight:
		error_highlight.visible = enabled or validation_error_active or _uses_unified_highlight()
		if error_highlight.visible:
			error_highlight.queue_redraw()
	update_visuals()
	_update_highlight_breathe()

func set_mask_color(mask_color: Color):
	if link_highlight:
		link_highlight.color = mask_color
		if is_editor_mode:
			_apply_full_cell_frame(link_highlight)
		else:
			_apply_tile_art_frame(link_highlight)
		link_highlight.visible = true

func clear_highlight():
	validation_error_active = false
	if error_highlight:
		error_highlight.visible = focus_active or _uses_unified_highlight()
		if error_highlight.visible:
			error_highlight.queue_redraw()
	_update_highlight_breathe()

func _start_unified_breathe() -> void:
	if error_highlight == null or not _uses_unified_highlight():
		return
	if state == GameConstants.TileState.WALL:
		return
	_focus_border_alpha = FOCUS_BORDER_ALPHA_MAX
	_set_tutorial_fill_visible(true)
	if error_highlight:
		error_highlight.visible = true
		error_highlight.queue_redraw()
	_focus_breathe_tween = create_tween().set_loops()
	_focus_breathe_tween.tween_method(
		_set_focus_border_alpha, FOCUS_BORDER_ALPHA_MAX, FOCUS_BORDER_ALPHA_MIN, 1.1
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_focus_breathe_tween.tween_method(
		_set_focus_border_alpha, FOCUS_BORDER_ALPHA_MIN, FOCUS_BORDER_ALPHA_MAX, 1.1
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _start_guide_breathe() -> void:
	if link_highlight == null or not guide_active or _uses_unified_highlight():
		return
	if state == GameConstants.TileState.WALL:
		return
	_stop_guide_breathe()
	_apply_tile_art_frame(link_highlight)
	link_highlight.visible = true
	call_deferred("_layout_highlight_overlays")
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
	if _uses_unified_highlight():
		_start_unified_breathe()
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
	if not _uses_unified_highlight():
		_set_tutorial_fill_visible(false)

func _set_focus_border_alpha(alpha: float) -> void:
	_focus_border_alpha = alpha
	if _tutorial_fill and _tutorial_fill.visible:
		_tutorial_fill.color = Color(
			FOCUS_BORDER_COLOR.r, FOCUS_BORDER_COLOR.g, FOCUS_BORDER_COLOR.b,
			_focus_border_alpha * HIGHLIGHT_FILL_ALPHA_SCALE
		)
	if error_highlight and error_highlight.visible:
		error_highlight.queue_redraw()
