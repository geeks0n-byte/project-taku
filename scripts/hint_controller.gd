class_name HintController
extends RefCounted

## Gameplay-facing hint API + hint button visuals.
## Constraint selection / priority lives in HintSystem.

const ICON_HINT_ON: Texture2D = preload("res://resources/icons/icon_hint_on.svg")
const ICON_HINT_OFF: Texture2D = preload("res://resources/icons/icon_hint_off.svg")

static func update_button(button: Button, has_hints: bool) -> void:
	if not button:
		return
	button.disabled = not has_hints
	var icon := button.get_node_or_null("IconContainer/Icon") as TextureRect
	if icon:
		icon.texture = ICON_HINT_ON if has_hints else ICON_HINT_OFF
	HudLayout.refresh_button_icon_modulate(button)

static func update_toggle_button(button: Button, is_on: bool) -> void:
	if not button:
		return
	button.button_pressed = is_on
	var icon := button.get_node_or_null("IconContainer/Icon") as TextureRect
	if icon:
		icon.texture = ICON_HINT_ON if is_on else ICON_HINT_OFF

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

## Returns {"hint": Variant, "solved_reference": Dictionary}.
## When prefer_hidden_pool is true, only reveal from hidden_reference_constraints
## (used for non-unique levels so hints stay solution-pool consistent).
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
