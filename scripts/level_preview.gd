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
	# Generated campaign levels often store only width/height with an empty layout.
	if layout.is_empty():
		var dims := LevelUtils.get_dimensions_from_level(level)
		layout = LevelUtils.make_empty_layout(maxi(1, dims.x), maxi(1, dims.y))
	if LevelUtils.is_shape_only_layout(layout):
		return _make_silhouette_texture(layout, pixel_size)
	# Apply authored shifter homes so previews match the starting board.
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

## Renders an arbitrary coord -> TileState layout (e.g. a solved board).
## Walls are omitted (transparent like gameplay) — no wall tiles or wall grid lines.
## Optional `shifter_dirs`: coord -> Vector2i direction for purple-tile arrow overlays.
static func make_texture_from_layout(
	layout: Dictionary,
	pixel_size: int = GameConstants.LEVEL_PREVIEW_SIZE,
	shifter_dirs: Dictionary = {}
) -> ImageTexture:
	if layout == null or layout.is_empty():
		return ImageTexture.create_from_image(Image.create(pixel_size, pixel_size, false, Image.FORMAT_RGBA8))

	var max_x := 0
	var max_y := 0
	for coord in layout.keys():
		max_x = maxi(max_x, int(coord.x))
		max_y = maxi(max_y, int(coord.y))
	var width: int = maxi(1, max_x + 1)
	var height: int = maxi(1, max_y + 1)
	var cell := maxi(4, int(float(pixel_size) / float(maxi(width, height))))
	var img_w := width * cell
	var img_h := height * cell
	var image := Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)
	# Transparent like gameplay — wall cells stay invisible (no fill, no grid).
	image.fill(Color(0, 0, 0, 0))

	for y in height:
		for x in width:
			var coord := Vector2i(x, y)
			var state: int = GameConstants.TileState.EMPTY
			if layout.has(coord):
				state = int(layout[coord])
			if state == GameConstants.TileState.WALL:
				continue
			var dst := Vector2i(x * cell, y * cell)
			var tile_img := _resized_tile(_path_for_state(state), cell)
			if tile_img:
				image.blend_rect(tile_img, Rect2i(Vector2i.ZERO, tile_img.get_size()), dst)
			if state == GameConstants.TileState.SHIFTER and shifter_dirs.has(coord):
				_blit_shifter_arrow(image, dst, cell, shifter_dirs[coord])

	return ImageTexture.create_from_image(image)

## Snapshot board cells including purple-tile arrow directions for solved previews.
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
	var max_x := 0
	var max_y := 0
	for coord in layout.keys():
		max_x = maxi(max_x, int(coord.x))
		max_y = maxi(max_y, int(coord.y))
	var width: int = maxi(1, max_x + 1)
	var height: int = maxi(1, max_y + 1)
	var cell := maxi(2, int(float(pixel_size) / float(maxi(width, height))))
	var img_w := width * cell
	var img_h := height * cell
	var image := Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)
	# Transparent like gameplay — wall cells stay invisible (no fill, no grid).
	image.fill(Color(0, 0, 0, 0))

	for y in height:
		for x in width:
			var coord := Vector2i(x, y)
			var state: int = GameConstants.TileState.EMPTY
			if layout.has(coord):
				state = int(layout[coord])
			# Match gameplay: walls are invisible (no fill, no grid).
			if state == GameConstants.TileState.WALL:
				continue
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
	# Match in-game chevron: slightly smaller than the purple tile, centered.
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
