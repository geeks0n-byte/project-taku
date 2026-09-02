class_name ColorBlindTiles
extends RefCounted
## Optional diagonal stripe overlays on blue/yellow tiles for color-blind accessibility.


const PATTERN_ALPHA := 0.42

static func is_enabled() -> bool:
	var tree := Engine.get_main_loop()
	if tree == null:
		return false
	var sm := tree.root.get_node_or_null("/root/SaveManager")
	return sm != null and bool(sm.get("color_blind_patterns"))


static func sync_pattern(host: Control, state: int) -> void:
	if host == null:
		return
	var overlay := host.get_node_or_null("ColorBlindPattern") as ColorRect
	if not is_enabled() or (
		state != GameConstants.TileState.BLUE and state != GameConstants.TileState.YELLOW
	):
		if overlay:
			overlay.visible = false
		return
	if overlay == null:
		overlay = ColorRect.new()
		overlay.name = "ColorBlindPattern"
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		host.add_child(overlay)
	overlay.visible = true
	overlay.color = Color(0, 0, 0, PATTERN_ALPHA if state == GameConstants.TileState.YELLOW else 0.28)
	overlay.rotation = 0.785398 if state == GameConstants.TileState.BLUE else -0.785398
	var margin := maxf(4.0, host.size.x * 0.12)
	overlay.offset_left = margin
	overlay.offset_top = margin
	overlay.offset_right = -margin
	overlay.offset_bottom = -margin


## Refreshes pattern overlays on live board cells after the setting changes.
static func refresh_board_cells(cells: Dictionary) -> void:
	for key in cells:
		var cell: Variant = cells[key]
		if cell != null and cell is Object and (cell as Object).has_method("update_visuals"):
			(cell as Object).call("update_visuals")
