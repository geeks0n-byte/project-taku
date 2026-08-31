extends SceneTree
## Captures the main-menu SPACEBLOX title (Press Start 2P).
## Writes tiled and plain (no tiles in P/O) PNGs.

const OUT_PATH := "res://resources/background/boot_void_title.png"
const OUT_PLAIN_PATH := "res://resources/background/boot_void_title_plain.png"
const CLUSTER_SIZE := Vector2i(1080, 420)
const TITLE_CROP := Rect2i(0, 220, 1080, 180)
const FONT := preload("res://resources/fonts/PressStart2P-vaV7.ttf")
const TILE_GREEN := preload("res://resources/tiles/tile_green.svg")
const TILE_YELLOW := preload("res://resources/tiles/tile_yellow.svg")
const TILE_BLUE := preload("res://resources/tiles/tile_blue.svg")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok := await _capture_title(OUT_PATH, true)
	ok = await _capture_title(OUT_PLAIN_PATH, false) and ok
	quit(0 if ok else 1)


func _capture_title(out_path: String, with_tiles: bool) -> bool:
	var host := Node.new()
	root.add_child(host)

	var vp := SubViewport.new()
	vp.size = CLUSTER_SIZE
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(vp)

	vp.add_child(_build_title_cluster(with_tiles))

	for _i in range(12):
		await process_frame

	var tex := vp.get_texture()
	if tex == null:
		push_error("title capture: no viewport texture")
		return false
	var image := tex.get_image()
	if image == null:
		push_error("title capture: no image (use a real renderer, not --headless dummy)")
		return false
	image.convert(Image.FORMAT_RGBA8)
	var cropped := image.get_region(TITLE_CROP)
	var err := cropped.save_png(out_path)
	host.queue_free()
	if err != OK:
		push_error("title capture: save failed (%s) -> %s" % [err, out_path])
		return false
	print("wrote ", out_path, " ", cropped.get_width(), "x", cropped.get_height())
	return true


func _build_title_cluster(with_tiles: bool) -> Control:
	var cluster := Control.new()
	cluster.size = Vector2(CLUSTER_SIZE)
	cluster.custom_minimum_size = Vector2(CLUSTER_SIZE)
	cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	label.name = "TitleLabel"
	label.position = Vector2(24, 240)
	label.size = Vector2(1032, 160)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = "SPACEBLOX"
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 96)
	label.set_meta("_brand_title", true)
	label.set_meta("_screen_header", true)
	label.set_meta("_screen_header_font_size", 96)
	label.set_meta("_screen_header_outline", 14)
	cluster.add_child(label)
	HudLayout.apply_screen_header_style(label)

	if with_tiles:
		var tiles := Control.new()
		tiles.name = "TitleTileHost"
		tiles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cluster.add_child(tiles)
		# Same offsets/scale as scenes/main_menu.tscn TitleTileHost children.
		_add_title_tile(tiles, TILE_GREEN, Vector2(230, 286))
		_add_title_tile(tiles, TILE_YELLOW, Vector2(806, 286))
		_add_title_tile(tiles, TILE_BLUE, Vector2(806, 313))
	return cluster


func _add_title_tile(host: Control, tex: Texture2D, pos: Vector2) -> void:
	var tile := TextureRect.new()
	tile.position = pos
	tile.size = Vector2(28, 28)
	tile.scale = Vector2(1.15, 1.15)
	tile.texture = tex
	tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(tile)
