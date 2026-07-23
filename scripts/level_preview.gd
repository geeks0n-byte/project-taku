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

static func make_texture(level: LevelData, pixel_size: int = GameConstants.LEVEL_PREVIEW_SIZE) -> ImageTexture:
	var dims := LevelUtils.get_dimensions_from_level(level)
	var width: int = maxi(1, dims.x)
	var height: int = maxi(1, dims.y)
	var cell := maxi(2, int(float(pixel_size) / float(maxi(width, height))))
	var img_w := width * cell
	var img_h := height * cell
	var image := Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)
	image.fill(COLOR_BG)

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

	for y in height:
		for x in width:
			var coord := Vector2i(x, y)
			var state: int = GameConstants.TileState.EMPTY
			if level.layout.has(coord):
				state = int(level.layout[coord])
			if shifter_cells.has(coord):
				state = GameConstants.TileState.SHIFTER
			var color := _color_for_state(state)
			var rect := Rect2i(x * cell, y * cell, cell, cell)
			image.fill_rect(rect, color)
			if cell >= 4:
				# Inner inset so cells read as a grid.
				var inset := Rect2i(x * cell, y * cell, cell, 1)
				image.fill_rect(inset, COLOR_GRID)
				inset = Rect2i(x * cell, y * cell, 1, cell)
				image.fill_rect(inset, COLOR_GRID)

	return ImageTexture.create_from_image(image)

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
