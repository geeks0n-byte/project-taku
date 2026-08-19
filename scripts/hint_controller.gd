class_name HintController
extends RefCounted
## Manages the visual state of hint buttons (icon, badge, count) across the HUD.
## Stateless utility — all methods are static and operate on passed-in button nodes.


# Hint button icon textures for toggled on/off states.
const ICON_HINT_ON: Texture2D = preload("res://resources/icons/icon_hint_on.svg")
const ICON_HINT_OFF: Texture2D = preload("res://resources/icons/icon_hint_off.svg")
# Badge icons shown when hints are exhausted (ad) or unlimited (infinity).
const ICON_AD: Texture2D = preload("res://resources/icons/icon_ad.svg")
const ICON_INFINITY: Texture2D = preload("res://resources/icons/icon_infinity.svg")
# Node names used to lazily create / find the count label and icon badge children.
const COUNT_LABEL_NAME := "HintCountLabel"
const COUNT_ICON_NAME := "HintCountIcon"
const COUNT_FONT_SIZE := GameConstants.HUD_COUNTER_LABEL_FONT_SIZE

## Updates a hint button's icon, disabled state, and remaining-count badge.
## `remaining`: -1 = unlimited, 0 = must watch ad, >0 = numeric count.
static func update_button(button: Button, has_action: bool, remaining: int = -1) -> void:
	if not button:
		return
	button.disabled = not has_action
	var icon := button.get_node_or_null("IconContainer/Icon") as TextureRect
	if icon:
		var use_on := remaining != 0
		icon.texture = ICON_HINT_ON if use_on else ICON_HINT_OFF
	HudLayout.refresh_button_icon_modulate(button)
	_update_count_badge(button, remaining)

## Updates a toggle-style hint button (e.g. highlight toggle) — no count badge shown.
static func update_toggle_button(button: Button, is_on: bool) -> void:
	if not button:
		return
	button.button_pressed = is_on
	var icon := button.get_node_or_null("IconContainer/Icon") as TextureRect
	if icon:
		icon.texture = ICON_HINT_ON if is_on else ICON_HINT_OFF
	# Toggle buttons don't show a remaining-count badge.
	var label := button.get_node_or_null(COUNT_LABEL_NAME) as Label
	var badge := button.get_node_or_null(COUNT_ICON_NAME) as TextureRect
	if label:
		label.visible = false
	if badge:
		badge.visible = false

## Displays the appropriate badge on the button: infinity icon, ad icon, or numeric count.
static func _update_count_badge(button: Button, remaining: int) -> void:
	var label := _ensure_count_label(button)
	var badge_icon := _ensure_count_icon(button)
	if label == null or badge_icon == null:
		return
	if remaining < 0:
		# Unlimited (tutorial / remove-ads): show infinity badge.
		label.visible = false
		badge_icon.texture = ICON_INFINITY
		badge_icon.visible = true
		return
	if remaining == 0:
		label.visible = false
		badge_icon.texture = ICON_AD
		badge_icon.visible = true
		return
	badge_icon.visible = false
	label.visible = true
	# Always bake Press Start + thin outline (never live theme outline).
	HudLayout.apply_raster_pixel_label(
		label,
		str(remaining),
		COUNT_FONT_SIZE,
		Color(1.0, 0.92, 0.35, 1.0),
		0,
		true
	)

## Lazily creates and returns the numeric count Label child on the button.
static func _ensure_count_label(button: Button) -> Label:
	if not button:
		return null
	var existing := button.get_node_or_null(COUNT_LABEL_NAME) as Label
	if existing:
		return existing
	var label := Label.new()
	label.name = COUNT_LABEL_NAME
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_count_label_layout(label)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35, 1.0))
	label.visible = false
	button.add_child(label)
	return label

## Lazily creates and returns the badge icon (ad/infinity) TextureRect on the button.
static func _ensure_count_icon(button: Button) -> TextureRect:
	if not button:
		return null
	var existing := button.get_node_or_null(COUNT_ICON_NAME) as TextureRect
	if existing:
		return existing
	var icon := TextureRect.new()
	icon.name = COUNT_ICON_NAME
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = ICON_AD
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_apply_count_icon_layout(icon)
	icon.visible = false
	button.add_child(icon)
	return icon

## Positions the count label in the top-right badge pocket of the button.
static func _apply_count_label_layout(label: Label) -> void:
	label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	label.offset_left = -60.0
	label.offset_top = 20.0
	label.offset_right = -20.0
	label.offset_bottom = 56.0

## Positions the badge icon (ad/infinity) in the same top-right pocket as the count label.
static func _apply_count_icon_layout(icon: TextureRect) -> void:
	# Same badge pocket as the hint count number, slightly inset toward button center.
	icon.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	icon.offset_left = -60.0
	icon.offset_top = 20.0
	icon.offset_right = -20.0
	icon.offset_bottom = 56.0
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

## Returns true if at least one useful hint can be revealed given current board state.
static func has_usable_hints(
	board_cells: Dictionary,
	active_constraints: Array,
	solved_reference: Dictionary,
	hidden_reference_constraints: Array = [],
	grid_size: Vector2i = Vector2i.ZERO,
	prefer_hidden_pool: bool = false
) -> bool:
	return HintSystem.count_usable_hints(
		board_cells,
		active_constraints,
		solved_reference,
		hidden_reference_constraints,
		grid_size,
		prefer_hidden_pool
	) > 0

## Picks and returns a single hint to reveal. Falls back to dynamic solving if no
## pre-computed solution is available. Returns {"hint": ..., "solved_reference": ...}.
static func reveal_hint(
	board_cells: Dictionary,
	active_constraints: Array,
	solved_reference: Dictionary,
	hidden_reference_constraints: Array,
	available_tiles: Array,
	prefer_hidden_pool: bool = false
) -> Dictionary:
	var solved := solved_reference
	var tiles: Array = available_tiles if available_tiles.size() > 0 else [0, 1, 2]
	# Fall back to a fresh solve when the caller has no pre-computed reference solution.
	# This is slower but ensures a hint can always be offered if the board is solvable.
	if solved.is_empty():
		solved = HintSystem.attempt_dynamic_solve(board_cells, active_constraints, tiles)
	var hint = HintSystem.pick_hint(
		board_cells,
		active_constraints,
		solved,
		hidden_reference_constraints,
		LevelUtils.get_dimensions_from_cells(board_cells),
		prefer_hidden_pool
	)
	return {"hint": hint, "solved_reference": solved}
