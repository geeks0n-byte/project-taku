class_name ColorBlindTiles
extends RefCounted
## Remaps tile art to a color-blind-safe palette (blue / orange / teal / magenta).


const _LUM_SHADOW := 0.28
const _LUM_HIGHLIGHT := 0.62
const _LUM_RIM := 0.12

static var _texture_cache: Dictionary = {}


static func is_enabled() -> bool:
	var tree := Engine.get_main_loop()
	if tree == null:
		return false
	var sm: Node = tree.root.get_node_or_null("/root/SaveManager")
	return sm != null and bool(sm.get("color_blind_patterns"))


static func clear_texture_cache() -> void:
	_texture_cache.clear()


static func resolve_tile_texture(source: Texture2D, state: int) -> Texture2D:
	if source == null or not is_enabled() or not _is_remap_state(state):
		return source
	var path := source.resource_path if source.resource_path else str(source.get_instance_id())
	var key := "%s|%d|cb3" % [path, state]
	if _texture_cache.has(key):
		return _texture_cache[key]
	var img := _texture_to_image(source)
	if img == null:
		return source
	var remapped := remap_tile_image(img, state)
	var tex := ImageTexture.create_from_image(remapped)
	_texture_cache[key] = tex
	return tex


static func remap_tile_image(img: Image, state: int) -> Image:
	if img == null or not is_enabled() or not _is_remap_state(state):
		return img
	var out := img.duplicate()
	for y in out.get_height():
		for x in out.get_width():
			out.set_pixel(x, y, _remap_pixel(out.get_pixel(x, y), state))
	return out


static func filter_tile_image(img: Image, state: int) -> Image:
	return remap_tile_image(img, state)


static func preview_fallback_color(state: int, default: Color) -> Color:
	if not is_enabled() or not _is_remap_state(state):
		return default
	var palette: Array = _palette_for_state(state)
	return palette[1] if palette.size() > 1 else default


static func finish_tile_icon(tile_icon: CanvasItem) -> void:
	if tile_icon == null:
		return
	_remove_legacy_overlay(tile_icon)
	tile_icon.modulate = Color.WHITE


static func refresh_board_cells(cells: Dictionary) -> void:
	clear_texture_cache()
	for key in cells:
		var cell: Variant = cells[key]
		if cell != null and cell is Object and (cell as Object).has_method("update_visuals"):
			(cell as Object).call("update_visuals")


static func _is_remap_state(state: int) -> bool:
	return state in [
		GameConstants.TileState.BLUE,
		GameConstants.TileState.YELLOW,
		GameConstants.TileState.JOKER,
		GameConstants.TileState.SHIFTER,
	]


static func _palette_for_state(state: int) -> Array:
	match state:
		GameConstants.TileState.BLUE:
			return [
				Color(0.10, 0.18, 0.55),
				Color(0.16, 0.44, 1.0),
				Color(0.62, 0.82, 1.0),
			]
		GameConstants.TileState.YELLOW:
			return [
				Color(0.48, 0.22, 0.0),
				Color(1.0, 0.52, 0.0),
				Color(1.0, 0.80, 0.35),
			]
		GameConstants.TileState.JOKER:
			return [
				Color(0.0, 0.26, 0.24),
				Color(0.0, 0.72, 0.62),
				Color(0.42, 0.98, 0.88),
			]
		GameConstants.TileState.SHIFTER:
			return [
				Color(0.36, 0.05, 0.40),
				Color(0.92, 0.12, 0.72),
				Color(1.0, 0.50, 0.88),
			]
		_:
			return []


static func _remap_pixel(c: Color, state: int) -> Color:
	if c.a <= 0.001:
		return c
	var lum := maxf(c.r, maxf(c.g, c.b))
	if lum < _LUM_RIM:
		return c
	var palette: Array = _palette_for_state(state)
	if palette.is_empty():
		return c
	var mapped: Color
	if lum >= _LUM_HIGHLIGHT:
		mapped = palette[2]
	elif lum >= _LUM_SHADOW:
		mapped = palette[1]
	else:
		mapped = palette[0]
	return Color(mapped.r, mapped.g, mapped.b, c.a)


static func _texture_to_image(source: Texture2D) -> Image:
	if source == null:
		return null
	var img: Image = source.get_image()
	if img != null:
		return _prepare_image(img)
	if source is ImageTexture:
		img = (source as ImageTexture).get_image()
		if img != null:
			return _prepare_image(img)
	return null


static func _prepare_image(img: Image) -> Image:
	var out := img.duplicate()
	if out.is_compressed():
		out.decompress()
	return out


static func _remove_legacy_overlay(host: Node) -> void:
	var existing := host.get_node_or_null("ColorBlindPattern")
	if existing:
		existing.queue_free()
