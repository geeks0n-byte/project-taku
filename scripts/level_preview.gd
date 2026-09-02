class_name LevelPreview
extends RefCounted
## Stateless utility for generating puzzle preview thumbnails (ImageTexture).
## SVG tile images are cached by "path@size" and composed layouts are cached by fingerprint.
## All methods are static; no instance is needed.

# Fallback solid colors used when a tile SVG cannot be loaded or resized.
const COLOR_BG := Color(0.08, 0.1, 0.16, 1.0)
const COLOR_EMPTY := Color(0.28, 0.34, 0.46, 1.0)
const COLOR_WALL := Color(0.05, 0.06, 0.09, 1.0)
const COLOR_YELLOW := Color(0.95, 0.82, 0.2, 1.0)
const COLOR_BLUE := Color(0.25, 0.55, 0.95, 1.0)
const COLOR_JOKER := Color(0.3, 0.85, 0.45, 1.0)
const COLOR_SHIFTER := Color(0.7, 0.35, 0.9, 1.0)

const PATH_EMPTY := "res://resources/tiles/tile_empty.svg"
const PATH_WALL := "res://resources/tiles/tile_wall.svg"

# Per-size tile image cache: key = "path@size". Avoids re-rasterizing SVGs each frame.
static var _tile_image_cache: Dictionary = {}
# Fully-composed preview textures keyed by layout fingerprint + pixel_size.
# Bounded to _PREVIEW_CACHE_MAX entries; oldest entry is evicted when full.
static var _preview_texture_cache: Dictionary = {}
const _PREVIEW_CACHE_MAX := 64
const _CB_STRIPE_PERIOD := 5


## Drops composed preview textures (e.g. after color-blind toggle).
static func clear_texture_cache() -> void:
	_preview_texture_cache.clear()

## Creates the dark bordered StyleBoxFlat used to frame preview thumbnails.
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

## Returns the outer pixel size for a frame with a given inner content area.
## Accounts for border (3 px) + content margin (4 px) on each side = +14 total.
static func frame_outer_size(inner_size: float) -> float:
	return inner_size + 14.0

## Ensures `preview` sits inside a bordered PanelContainer (level-select style).
## Idempotent: if the frame already exists it just refreshes the style; otherwise it
## inserts a new PanelContainer at the same scene-tree index as `preview` was.
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

## Generates a preview thumbnail for a LevelData resource.
## Handles the shifter display correctly: the active shifter position shows the
## SHIFTER tile, while the inactive home/alt position is rendered as EMPTY so
## only the current state of each pair is visible in the preview.
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

## Rasterizes a coord→TileState layout dict into a square preview image.
## Tiles are rendered using SVG assets when available, falling back to solid colors.
## `shifter_dirs` maps shifter coords to their direction vector so an arrow overlay is drawn.
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

	# Pad = 10 % of pixel_size, floored at 4. inner is the drawable square after padding.
	# cell is the pixel size of one grid tile, determined by the larger board dimension
	# so both axes always fit; minimum 3 px so very large boards still render something.
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
			if state == GameConstants.TileState.BLUE or state == GameConstants.TileState.YELLOW:
				_blit_color_blind_pattern(image, dst, cell, state)
			if state == GameConstants.TileState.SHIFTER and shifter_dirs.has(coord):
				_blit_shifter_arrow(image, dst, cell, shifter_dirs[coord])

	var tex := ImageTexture.create_from_image(image)
	_store_preview_texture(cache_key, tex)
	return tex

## Produces a stable string fingerprint for a layout + pixel_size combination.
## The "v5tiles" prefix allows cache invalidation if the tile rendering logic changes.
static func _layout_cache_key(layout: Dictionary, pixel_size: int, shifter_dirs: Dictionary) -> String:
	var parts: PackedStringArray = []
	parts.append("v5tiles")
	parts.append(str(pixel_size))
	parts.append("cb1" if _color_blind_enabled() else "cb0")
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


static func _color_blind_enabled() -> bool:
	var tree := Engine.get_main_loop()
	if tree == null:
		return false
	var sm := tree.root.get_node_or_null("/root/SaveManager")
	return sm != null and bool(sm.get("color_blind_patterns"))


## Diagonal stripe overlay on blue/yellow preview cells (matches live board patterns).
static func _blit_color_blind_pattern(image: Image, dst: Vector2i, cell: int, state: int) -> void:
	if not _color_blind_enabled():
		return
	if state != GameConstants.TileState.BLUE and state != GameConstants.TileState.YELLOW:
		return
	var margin := maxi(1, int(round(float(cell) * 0.12)))
	var alpha := 0.28 if state == GameConstants.TileState.BLUE else 0.42
	var slope := 1 if state == GameConstants.TileState.BLUE else -1
	for y in cell:
		for x in cell:
			if x < margin or y < margin or x >= cell - margin or y >= cell - margin:
				continue
			var lx := x - margin
			var ly := y - margin
			var diag := lx + slope * ly
			if int(abs(diag)) % _CB_STRIPE_PERIOD >= _CB_STRIPE_PERIOD / 2:
				continue
			var px := dst.x + x
			var py := dst.y + y
			if px < 0 or py < 0 or px >= image.get_width() or py >= image.get_height():
				continue
			var existing := image.get_pixel(px, py)
			image.set_pixel(px, py, existing.lerp(Color(0, 0, 0, alpha), alpha))


## Inserts a generated texture into the preview cache, evicting the oldest entry
## (insertion order) when the cache has reached its capacity.
static func _store_preview_texture(key: String, tex: ImageTexture) -> void:
	if _preview_texture_cache.size() >= _PREVIEW_CACHE_MAX:
		var first_key = _preview_texture_cache.keys()[0]
		_preview_texture_cache.erase(first_key)
	_preview_texture_cache[key] = tex

## Convenience wrapper that converts live board_cells (Cell node dict) into a preview texture.
static func make_texture_from_board_cells(
	board_cells: Dictionary,
	pixel_size: int = GameConstants.LEVEL_PREVIEW_SIZE
) -> ImageTexture:
	return make_texture_from_layout(
		layout_from_board_cells(board_cells),
		pixel_size,
		shifter_dirs_from_board_cells(board_cells)
	)

## Extracts a plain coord→int state map from live Cell nodes for use with make_texture_from_layout.
static func layout_from_board_cells(board_cells: Dictionary) -> Dictionary:
	var layout := {}
	for coord in board_cells:
		var cell = board_cells[coord]
		if cell == null:
			continue
		layout[coord] = int(cell.state)
	return layout

## Extracts a coord→Vector2i direction map for all SHIFTER cells in the live board.
## Only cells with a non-zero shifter_direction are included.
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

## Renders a shape-only layout (no color data) as a flat silhouette: all non-wall
## cells are filled with COLOR_EMPTY. Used for levels whose layout has no tile states yet.
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

## Returns a set (coord → true) of every coord that belongs to any shifter pair,
## including both the home and active positions. Used to identify shifter-occupied cells.
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

## Returns a set of only the currently-active shifter coord for each pair.
## Prefers "active" over "home" — whichever key the pair dict provides.
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

## Maps a TileState int to the SVG resource path for that tile type.
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

## Maps a unit direction vector to the corresponding directional arrow SVG path.
## Returns an empty string for zero or diagonal directions (no arrow to draw).
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

## Blends a directional arrow sprite centered within a shifter cell.
## The arrow is sized to 72 % of the cell and inset equally on all sides.
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

## Loads and nearest-neighbor-resizes a tile SVG to `size` × `size` pixels.
## Results are cached by "path@size" key to avoid redundant disk reads and resizes.
## Returns null if the resource cannot be loaded or has no pixel data.
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
	# Image must be decompressed before resize; always duplicate to avoid mutating the cached source.
	if src.is_compressed():
		src = src.duplicate()
		src.decompress()
	else:
		src = src.duplicate()
	src.resize(size, size, Image.INTERPOLATE_NEAREST)
	_tile_image_cache[key] = src
	return src

## Returns the solid fallback color for a tile state, used when the SVG tile cannot be loaded.
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
