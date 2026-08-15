class_name LevelPreview
extends RefCounted

const COLOR_BG := Color(0.08, 0.1, 0.16, 1.0)
const COLOR_EMPTY := Color(0.28, 0.34, 0.46, 1.0)
const COLOR_WALL := Color(0.05, 0.06, 0.09, 1.0)
const COLOR_YELLOW := Color(0.95, 0.82, 0.2, 1.0)
const COLOR_BLUE := Color(0.25, 0.55, 0.95, 1.0)
const COLOR_JOKER := Color(0.3, 0.85, 0.45, 1.0)
const COLOR_SHIFTER := Color(0.7, 0.35, 0.9, 1.0)

const PATH_EMPTY := "res://resources/tiles/tile_empty.svg"
const PATH_WALL := "res://resources/tiles/tile_wall.svg"

static var _tile_image_cache: Dictionary = {}
static var _preview_texture_cache: Dictionary = {}
const _PREVIEW_CACHE_MAX := 64

static func make_frame_style() -> StyleBoxFlat:
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = COLOR_BG
	frame_style.border_color = Color(0.35, 0.42, 0.55, 1.0)
	frame_style.set_border_width_all(3)
	frame_style.set_corner_radius_all(8)
	frame_style.content_margin_left = 4.0
	frame_style.content_margin_top = 4.0
	frame_style.content_margin_right = 4.0
	frame_style.content_margin_bottom = 4.0
	return frame_style

static func frame_outer_size(inner_size: float) -> float:
	# border 3 + content pad 4 on each side
	return inner_size + 14.0

## Ensures `preview` sits inside a bordered PanelContainer (level-select style).
static func ensure_preview_frame(preview: TextureRect) -> PanelContainer:
	if preview == null:
		return null
	var parent := preview.get_parent()
	if parent is PanelContainer and (parent as PanelContainer).has_meta("_level_preview_frame"):
		var existing := parent as PanelContainer
		existing.add_theme_stylebox_override("panel", make_frame_style())
		return existing
	if parent == null:
		return null
	var index := preview.get_index()
	var frame := PanelContainer.new()
	frame.name = "%sFrame" % preview.name
	frame.set_meta("_level_preview_frame", true)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.visible = preview.visible
	frame.set_anchors_preset(Control.PRESET_CENTER_TOP)
	frame.add_theme_stylebox_override("panel", make_frame_style())
	parent.add_child(frame)
	parent.move_child(frame, index)
	preview.reparent(frame)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.offset_left = 0.0
	preview.offset_top = 0.0
	preview.offset_right = 0.0
	preview.offset_bottom = 0.0
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return frame

static func make_texture(level: LevelData, pixel_size: int = GameConstants.LEVEL_PREVIEW_SIZE) -> ImageTexture:
	if level == null:
		return ImageTexture.create_from_image(Image.create(pixel_size, pixel_size, false, Image.FORMAT_RGBA8))

	var layout: Dictionary = level.layout if level.layout != null else {}
	if layout.is_empty():
		var dims := LevelUtils.get_dimensions_from_level(level)
		layout = LevelUtils.make_empty_layout(maxi(1, dims.x), maxi(1, dims.y))
	if LevelUtils.is_shape_only_layout(layout):
		return _make_silhouette_texture(layout, pixel_size)
	var preview_layout := layout.duplicate()
	var active_shifters := _active_shifter_set(level)
	var shifter_cells := _shifter_cell_set(level)
	for coord in preview_layout.keys():
		var state := int(preview_layout[coord])
		if active_shifters.has(coord):
			preview_layout[coord] = GameConstants.TileState.SHIFTER
		elif shifter_cells.has(coord) and state == GameConstants.TileState.SHIFTER:
			preview_layout[coord] = GameConstants.TileState.EMPTY
	return make_texture_from_layout(preview_layout, pixel_size)

static func make_texture_from_layout(
	layout: Dictionary,
	pixel_size: int = GameConstants.LEVEL_PREVIEW_SIZE,
	shifter_dirs: Dictionary = {}
) -> ImageTexture:
	if layout == null or layout.is_empty():
		return ImageTexture.create_from_image(Image.create(pixel_size, pixel_size, false, Image.FORMAT_RGBA8))

	var cache_key := _layout_cache_key(layout, pixel_size, shifter_dirs)
	if _preview_texture_cache.has(cache_key):
		return _preview_texture_cache[cache_key]

	var max_x := 0
	var max_y := 0
	for coord in layout.keys():
		max_x = maxi(max_x, int(coord.x))
		max_y = maxi(max_y, int(coord.y))
	var width: int = maxi(1, max_x + 1)
	var height: int = maxi(1, max_y + 1)

	var image := Image.create(pixel_size, pixel_size, false, Image.FORMAT_RGBA8)
	image.fill(COLOR_BG)

	var pad := maxi(4, int(round(float(pixel_size) * 0.1)))
	var inner := maxi(8, pixel_size - pad * 2)
	var cell := maxi(3, int(float(inner) / float(maxi(width, height))))
	var board_w := width * cell
	var board_h := height * cell
	var origin := Vector2i(
		int((pixel_size - board_w) / 2.0),
		int((pixel_size - board_h) / 2.0)
	)

	for y in height:
		for x in width:
			var coord := Vector2i(x, y)
			var state: int = GameConstants.TileState.WALL
			if layout.has(coord):
				state = int(layout[coord])
			if state == GameConstants.TileState.WALL:
				continue
			var dst := origin + Vector2i(x * cell, y * cell)
			var tile_img := _resized_tile(_path_for_state(state), cell)
			if tile_img:
				image.blend_rect(tile_img, Rect2i(Vector2i.ZERO, tile_img.get_size()), dst)
			else:
				image.fill_rect(Rect2i(dst.x, dst.y, cell, cell), _color_for_state(state))
			if state == GameConstants.TileState.SHIFTER and shifter_dirs.has(coord):
				_blit_shifter_arrow(image, dst, cell, shifter_dirs[coord])

	var tex := ImageTexture.create_from_image(image)
	_store_preview_texture(cache_key, tex)
	return tex

static func _layout_cache_key(layout: Dictionary, pixel_size: int, shifter_dirs: Dictionary) -> String:
	var parts: PackedStringArray = []
	parts.append("v5tiles")
	parts.append(str(pixel_size))
	var coords: Array = layout.keys()
	coords.sort_custom(func(a, b): return str(a) < str(b))
	for coord in coords:
		parts.append("%s:%d" % [str(coord), int(layout[coord])])
	if not shifter_dirs.is_empty():
		var dir_coords: Array = shifter_dirs.keys()
		dir_coords.sort_custom(func(a, b): return str(a) < str(b))
		for coord in dir_coords:
			var d: Vector2i = shifter_dirs[coord] as Vector2i
			parts.append("d%s:%d,%d" % [str(coord), d.x, d.y])
	return "|".join(parts)

static func _store_preview_texture(key: String, tex: ImageTexture) -> void:
	if _preview_texture_cache.size() >= _PREVIEW_CACHE_MAX:
		var first_key = _preview_texture_cache.keys()[0]
		_preview_texture_cache.erase(first_key)
	_preview_texture_cache[key] = tex

static func make_texture_from_board_cells(
	board_cells: Dictionary,
	pixel_size: int = GameConstants.LEVEL_PREVIEW_SIZE
) -> ImageTexture:
	return make_texture_from_layout(
		layout_from_board_cells(board_cells),
		pixel_size,
		shifter_dirs_from_board_cells(board_cells)
	)

static func layout_from_board_cells(board_cells: Dictionary) -> Dictionary:
	var layout := {}
	for coord in board_cells:
		var cell = board_cells[coord]
		if cell == null:
			continue
		layout[coord] = int(cell.state)
	return layout

static func shifter_dirs_from_board_cells(board_cells: Dictionary) -> Dictionary:
	var dirs := {}
	for coord in board_cells:
		var cell = board_cells[coord]
		if cell == null:
			continue
		if int(cell.state) != GameConstants.TileState.SHIFTER:
			continue
		var dir: Vector2i = cell.shifter_direction
		if dir != Vector2i.ZERO:
			dirs[coord] = dir
	return dirs

static func _make_silhouette_texture(layout: Dictionary, pixel_size: int) -> ImageTexture:
	if layout == null or layout.is_empty():
		return ImageTexture.create_from_image(Image.create(pixel_size, pixel_size, false, Image.FORMAT_RGBA8))

	var max_x := 0
	var max_y := 0
	for coord in layout.keys():
		max_x = maxi(max_x, int(coord.x))
		max_y = maxi(max_y, int(coord.y))
	var width: int = maxi(1, max_x + 1)
	var height: int = maxi(1, max_y + 1)

	var image := Image.create(pixel_size, pixel_size, false, Image.FORMAT_RGBA8)
	image.fill(COLOR_BG)

	var pad := maxi(4, int(round(float(pixel_size) * 0.1)))
	var inner := maxi(8, pixel_size - pad * 2)
	var cell := maxi(3, int(float(inner) / float(maxi(width, height))))
	var board_w := width * cell
	var board_h := height * cell
	var origin := Vector2i(
		int((pixel_size - board_w) / 2.0),
		int((pixel_size - board_h) / 2.0)
	)

	for y in height:
		for x in width:
			var coord := Vector2i(x, y)
			var state: int = GameConstants.TileState.WALL
			if layout.has(coord):
				state = int(layout[coord])
			if state == GameConstants.TileState.WALL:
				continue
			var dst := origin + Vector2i(x * cell, y * cell)
			image.fill_rect(Rect2i(dst.x, dst.y, cell, cell), COLOR_EMPTY)

	return ImageTexture.create_from_image(image)

static func _shifter_cell_set(level: LevelData) -> Dictionary:
	var shifter_cells := {}
	for pair in LevelUtils.get_shifter_pairs(level):
		if typeof(pair) != TYPE_DICTIONARY:
			continue
		if pair.has("a"):
			shifter_cells[pair["a"]] = true
		if pair.has("b"):
			shifter_cells[pair["b"]] = true
		if pair.has("active"):
			shifter_cells[pair["active"]] = true
		if pair.has("home"):
			shifter_cells[pair["home"]] = true
	return shifter_cells

static func _active_shifter_set(level: LevelData) -> Dictionary:
	var active := {}
	for pair in LevelUtils.get_shifter_pairs(level):
		if typeof(pair) != TYPE_DICTIONARY:
			continue
		if pair.has("active"):
			active[pair["active"]] = true
		elif pair.has("home"):
			active[pair["home"]] = true
	return active

static func _path_for_state(state: int) -> String:
	match state:
		GameConstants.TileState.WALL:
			return PATH_WALL
		GameConstants.TileState.YELLOW:
			return GameConstants.TILE_YELLOW
		GameConstants.TileState.BLUE:
			return GameConstants.TILE_BLUE
		GameConstants.TileState.JOKER:
			return GameConstants.TILE_GREEN
		GameConstants.TileState.SHIFTER:
			return GameConstants.TILE_SHIFTER
		_:
			return PATH_EMPTY

static func _path_for_shifter_dir(dir: Vector2i) -> String:
	if dir == Vector2i(0, -1):
		return GameConstants.TILE_SHIFTER_UP
	if dir == Vector2i(0, 1):
		return GameConstants.TILE_SHIFTER_DOWN
	if dir == Vector2i(-1, 0):
		return GameConstants.TILE_SHIFTER_LEFT
	if dir == Vector2i(1, 0):
		return GameConstants.TILE_SHIFTER_RIGHT
	return ""

static func _blit_shifter_arrow(image: Image, cell_pos: Vector2i, cell: int, dir: Variant) -> void:
	var path := _path_for_shifter_dir(dir as Vector2i)
	if path.is_empty():
		return
	var arrow_size := maxi(4, int(round(float(cell) * 0.72)))
	var arrow_img := _resized_tile(path, arrow_size)
	if arrow_img == null:
		return
	var inset := int((cell - arrow_size) / 2.0)
	image.blend_rect(
		arrow_img,
		Rect2i(Vector2i.ZERO, arrow_img.get_size()),
		cell_pos + Vector2i(inset, inset)
	)

static func _resized_tile(path: String, size: int) -> Image:
	var key := "%s@%d" % [path, size]
	if _tile_image_cache.has(key):
		return _tile_image_cache[key]

	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var src := tex.get_image()
	if src == null:
		var img_tex := tex as ImageTexture
		if img_tex:
			src = img_tex.get_image()
	if src == null:
		return null
	if src.is_compressed():
		src = src.duplicate()
		src.decompress()
	else:
		src = src.duplicate()
	src.resize(size, size, Image.INTERPOLATE_NEAREST)
	_tile_image_cache[key] = src
	return src

static func _color_for_state(state: int) -> Color:
	match state:
		GameConstants.TileState.WALL:
			return COLOR_WALL
		GameConstants.TileState.YELLOW:
			return COLOR_YELLOW
		GameConstants.TileState.BLUE:
			return COLOR_BLUE
		GameConstants.TileState.JOKER:
			return COLOR_JOKER
		GameConstants.TileState.SHIFTER:
			return COLOR_SHIFTER
		_:
			return COLOR_EMPTY
