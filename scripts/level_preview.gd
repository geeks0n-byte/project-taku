class_name LevelPreview
extends RefCounted

const COLOR_BG := Color(0.08, 0.1, 0.16, 1.0)
const COLOR_EMPTY := Color(0.18, 0.22, 0.3, 1.0)
const COLOR_WALL := Color(0.05, 0.06, 0.09, 1.0)
const COLOR_YELLOW := Color(0.95, 0.82, 0.2, 1.0)
const COLOR_BLUE := Color(0.25, 0.55, 0.95, 1.0)
const COLOR_JOKER := Color(0.3, 0.85, 0.45, 1.0)
const COLOR_SHIFTER := Color(0.7, 0.35, 0.9, 1.0)
const COLOR_GRID := Color(0.02, 0.02, 0.04, 0.55)

const PATH_EMPTY := "res://resources/tiles/tile_empty.svg"
const PATH_WALL := "res://resources/tiles/tile_wall.svg"

## path@size -> resized Image
static var _tile_image_cache: Dictionary = {}

static func make_texture(level: LevelData, pixel_size: int = GameConstants.LEVEL_PREVIEW_SIZE) -> ImageTexture:
	if level == null:
		return ImageTexture.create_from_image(Image.create(pixel_size, pixel_size, false, Image.FORMAT_RGBA8))

	var layout: Dictionary = level.layout if level.layout != null else {}
	if LevelUtils.is_shape_only_layout(layout):
		return _make_silhouette_texture(level, pixel_size)
	return _make_tile_texture(level, pixel_size)

static func _make_tile_texture(level: LevelData, pixel_size: int) -> ImageTexture:
	var dims := LevelUtils.get_dimensions_from_level(level)
	var width: int = maxi(1, dims.x)
	var height: int = maxi(1, dims.y)
	var cell := maxi(4, int(float(pixel_size) / float(maxi(width, height))))
	var img_w := width * cell
	var img_h := height * cell
	var image := Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)
	image.fill(COLOR_BG)

	var shifter_cells := _shifter_cell_set(level)
	var active_shifters := _active_shifter_set(level)

	for y in height:
		for x in width:
			var coord := Vector2i(x, y)
			var state: int = GameConstants.TileState.EMPTY
			if level.layout.has(coord):
				state = int(level.layout[coord])
			var is_active_shifter := active_shifters.has(coord)
			var is_shifter_slot := shifter_cells.has(coord)
			if is_active_shifter:
				state = GameConstants.TileState.SHIFTER
			elif is_shifter_slot and state == GameConstants.TileState.SHIFTER:
				# Inactive home cell stored as shifter in some levels — show empty pad.
				state = GameConstants.TileState.EMPTY

			var tile_img := _resized_tile(_path_for_state(state), cell)
			if tile_img:
				image.blit_rect(tile_img, Rect2i(Vector2i.ZERO, tile_img.get_size()), Vector2i(x * cell, y * cell))

	return ImageTexture.create_from_image(image)

static func _make_silhouette_texture(level: LevelData, pixel_size: int) -> ImageTexture:
	var dims := LevelUtils.get_dimensions_from_level(level)
	var width: int = maxi(1, dims.x)
	var height: int = maxi(1, dims.y)
	var cell := maxi(2, int(float(pixel_size) / float(maxi(width, height))))
	var img_w := width * cell
	var img_h := height * cell
	var image := Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)
	image.fill(COLOR_BG)

	for y in height:
		for x in width:
			var coord := Vector2i(x, y)
			var state: int = GameConstants.TileState.EMPTY
			if level.layout.has(coord):
				state = int(level.layout[coord])
			var color := _color_for_state(state)
			var rect := Rect2i(x * cell, y * cell, cell, cell)
			image.fill_rect(rect, color)
			if cell >= 4:
				var inset := Rect2i(x * cell, y * cell, cell, 1)
				image.fill_rect(inset, COLOR_GRID)
				inset = Rect2i(x * cell, y * cell, 1, cell)
				image.fill_rect(inset, COLOR_GRID)

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

static func _resized_tile(path: String, size: int) -> Image:
	var key := "%s@%d" % [path, size]
	if _tile_image_cache.has(key):
		return _tile_image_cache[key]

	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var src := tex.get_image()
	if src == null:
		# SVG / compressed textures may need a GPU readback fallback.
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
	src.resize(size, size, Image.INTERPOLATE_BILINEAR)
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
