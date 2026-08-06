extends RefCounted
class_name StoreAssetRenderer


const OUTPUT_DIR := "res://docs/store-assets/"
const MAIN_MENU_SCENE := preload("res://scenes/main_menu.tscn")
const ICON_TEXTURE: Texture2D = preload("res://resources/icons/app_icon_cosmos.svg")

const SPACE_BG := Color(0.0, 0.0705882, 0.227451, 1.0) # #00123a
const CLUSTER_SIZE := Vector2(1080.0, 420.0)
const TITLE_CROP := Rect2(0.0, 220.0, 1080.0, 180.0)


static func render_all(tree: SceneTree) -> bool:
	print("StoreAssetRenderer: starting")
	var host := Node.new()
	host.name = "StoreAssetHost"
	tree.root.add_child(host)
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame

	var ok := true
	ok = await _save_png(host, tree, Vector2i(512, 512), _build_app_icon()) and ok
	ok = await _save_png(host, tree, Vector2i(1024, 500), _build_feature_landscape()) and ok
	ok = await _save_png(host, tree, Vector2i(500, 1024), _build_feature_portrait()) and ok

	host.queue_free()
	return ok


static func _save_png(host: Node, tree: SceneTree, size: Vector2i, content: Control) -> bool:
	var image := await _capture(host, tree, size, content)
	if image == null:
		push_error("StoreAssetRenderer: failed to capture %s" % str(size))
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var path := ""
	match size:
		Vector2i(512, 512):
			path = OUTPUT_DIR.path_join("play_store_icon_512.png")
		Vector2i(1024, 500):
			path = OUTPUT_DIR.path_join("play_store_feature_graphic_1024x500.png")
		Vector2i(500, 1024):
			path = OUTPUT_DIR.path_join("play_store_graphic_500x1024.png")
		_:
			path = OUTPUT_DIR.path_join("store_%dx%d.png" % [size.x, size.y])
	var err := image.save_png(path)
	if err != OK:
		push_error("StoreAssetRenderer: save failed (%s) -> %s" % [err, path])
		return false
	print("StoreAssetRenderer: wrote ", path)
	return true


static func _capture(host: Node, tree: SceneTree, size: Vector2i, content: Control) -> Image:
	var vp := SubViewport.new()
	vp.name = "CaptureViewport"
	vp.size = size
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(vp)

	var bg := ColorRect.new()
	bg.color = SPACE_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)

	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vp.add_child(content)

	for _i in range(8):
		await tree.process_frame

	var tex := vp.get_texture()
	host.remove_child(vp)
	vp.queue_free()
	if tex == null:
		return null
	return tex.get_image()


static func _build_app_icon() -> Control:
	var root := Control.new()
	var bg := ColorRect.new()
	bg.color = SPACE_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var icon := TextureRect.new()
	icon.texture = ICON_TEXTURE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = Vector2.ZERO
	icon.size = Vector2(512, 512)
	root.add_child(icon)
	return root


static func _build_feature_landscape() -> Control:
	var root := Control.new()
	_add_star_field(root, Vector2(1024, 500))
	var cluster := _instantiate_title_cluster()
	var scale := minf(960.0 / TITLE_CROP.size.x, 360.0 / TITLE_CROP.size.y)
	cluster.scale = Vector2(scale, scale)
	var drawn := TITLE_CROP.size * scale
	cluster.position = Vector2(
		(1024.0 - drawn.x) * 0.5 - TITLE_CROP.position.x * scale,
		(500.0 - drawn.y) * 0.5 - TITLE_CROP.position.y * scale
	)
	root.add_child(cluster)
	return root


static func _build_feature_portrait() -> Control:
	var root := Control.new()
	_add_star_field(root, Vector2(500, 1024))
	var cluster := _instantiate_title_cluster()
	var scale := minf(460.0 / TITLE_CROP.size.x, 320.0 / TITLE_CROP.size.y)
	cluster.scale = Vector2(scale, scale)
	var drawn := TITLE_CROP.size * scale
	cluster.position = Vector2(
		(500.0 - drawn.x) * 0.5 - TITLE_CROP.position.x * scale,
		220.0 - TITLE_CROP.position.y * scale
	)
	root.add_child(cluster)
	return root


static func _instantiate_title_cluster() -> Control:
	var menu: Node = MAIN_MENU_SCENE.instantiate()
	var cluster: Control = menu.get_node("TitleLayer/TitleHost/TitleCluster")
	cluster.owner = null
	for child in cluster.find_children("*", "", true, false):
		child.owner = null
	cluster.get_parent().remove_child(cluster)
	menu.free()

	cluster.set_anchors_preset(Control.PRESET_TOP_LEFT)
	cluster.anchor_left = 0.0
	cluster.anchor_top = 0.0
	cluster.anchor_right = 0.0
	cluster.anchor_bottom = 0.0
	cluster.position = Vector2.ZERO
	cluster.size = CLUSTER_SIZE
	cluster.custom_minimum_size = CLUSTER_SIZE
	cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := cluster.get_node_or_null("TitleLabel") as Label
	if label:
		label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 14)
		label.add_theme_font_size_override("font_size", 96)

	var tile_host := cluster.get_node_or_null("TitleTileHost") as Control
	if tile_host:
		for child in tile_host.get_children():
			var tile := child as TextureRect
			if tile == null:
				continue
			tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tile.stretch_mode = TextureRect.STRETCH_SCALE
			tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return cluster


static func _add_star_field(parent: Control, size: Vector2) -> void:
	var bg := ColorRect.new()
	bg.color = SPACE_BG
	bg.size = size
	parent.add_child(bg)

	var dim := Color(0.25, 0.25, 0.25, 1.0)
	var bright := Color.WHITE
	var points := [
		[Vector2(0.05, 0.12), dim],
		[Vector2(0.18, 0.28), bright],
		[Vector2(0.32, 0.08), dim],
		[Vector2(0.46, 0.22), bright],
		[Vector2(0.58, 0.14), dim],
		[Vector2(0.72, 0.34), bright],
		[Vector2(0.86, 0.10), dim],
		[Vector2(0.92, 0.42), bright],
		[Vector2(0.12, 0.62), bright],
		[Vector2(0.28, 0.78), dim],
		[Vector2(0.44, 0.66), bright],
		[Vector2(0.64, 0.82), dim],
		[Vector2(0.80, 0.58), bright],
		[Vector2(0.90, 0.74), dim],
	]
	for entry in points:
		var star := ColorRect.new()
		var pos: Vector2 = entry[0]
		star.color = entry[1]
		star.size = Vector2(3, 3)
		star.position = Vector2(pos.x * size.x, pos.y * size.y)
		parent.add_child(star)
