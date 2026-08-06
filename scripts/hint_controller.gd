class_name HintController
extends RefCounted


const ICON_HINT_ON: Texture2D = preload("res://resources/icons/icon_hint_on.svg")
const ICON_HINT_OFF: Texture2D = preload("res://resources/icons/icon_hint_off.svg")
const COUNT_LABEL_NAME := "HintCountLabel"

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

static func update_toggle_button(button: Button, is_on: bool) -> void:
	if not button:
		return
	button.button_pressed = is_on
	var icon := button.get_node_or_null("IconContainer/Icon") as TextureRect
	if icon:
		icon.texture = ICON_HINT_ON if is_on else ICON_HINT_OFF
	_update_count_badge(button, -1)

static func _update_count_badge(button: Button, remaining: int) -> void:
	var label := _ensure_count_label(button)
	if label == null:
		return
	if remaining < 0:
		label.visible = false
		return
	label.visible = true
	if remaining == 0:
		label.text = String(TranslationServer.translate("UI_AD"))
		label.add_theme_color_override("font_color", Color.WHITE)
	else:
		label.text = str(remaining)
		label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35, 1.0))

static func _ensure_count_label(button: Button) -> Label:
	if not button:
		return null
	var existing := button.get_node_or_null(COUNT_LABEL_NAME) as Label
	if existing:
		_apply_count_label_layout(existing)
		return existing
	var label := Label.new()
	label.name = COUNT_LABEL_NAME
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_count_label_layout(label)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	if HudLayout.PIXEL_FONT:
		label.add_theme_font_override("font", HudLayout.PIXEL_FONT)
	label.add_theme_font_size_override(
		"font_size", HudLayout.scaled_font_size(GameConstants.HUD_COUNTER_LABEL_FONT_SIZE)
	)
	label.visible = false
	button.add_child(label)
	return label

static func _apply_count_label_layout(label: Label) -> void:
	label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	label.offset_left = -64.0
	label.offset_top = 16.0
	label.offset_right = -16.0
	label.offset_bottom = 56.0

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
