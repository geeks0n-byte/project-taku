extends RefCounted
class_name StoreAssetRenderer

# Offline tool for generating Play Store listing assets programmatically.
# Call render_all() from an editor script or autoload; it is not used at runtime.

const OUTPUT_DIR := "res://docs/store-assets/"
const MAIN_MENU_SCENE := preload("res://scenes/main_menu.tscn")
const ICON_TEXTURE: Texture2D = preload("res://resources/icons/app_icon_cosmos.svg")

# Dark space-blue background colour matching the game's main menu backdrop.
const SPACE_BG := Color(0.0, 0.0705882, 0.227451, 1.0) # #00123a
# Natural pixel size of the TitleCluster node as authored in the main menu scene.
const CLUSTER_SIZE := Vector2(1080.0, 420.0)
# The crop region within CLUSTER_SIZE that contains just the title text (strips
# excess vertical whitespace above and below the visible title area).
const TITLE_CROP := Rect2(0.0, 220.0, 1080.0, 180.0)


# Entry point: renders store assets and returns true when all succeed.
# Waits a few frames first so the scene tree is fully settled before capturing.
# The 512 app icon is owned by dev/asset-gen/gen_launcher_icons.py — skip it by default.
static func render_all(tree: SceneTree, include_icon: bool = false) -> bool:
	print("StoreAssetRenderer: starting")
	var host := Node.new()
	host.name = "StoreAssetHost"
	tree.root.add_child(host)
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame

	var ok := true
	if include_icon:
		ok = await _save_png(host, tree, Vector2i(512, 512), _build_app_icon()) and ok
	ok = await _save_png(host, tree, Vector2i(1024, 500), _build_feature_landscape()) and ok
	ok = await _save_png(host, tree, Vector2i(500, 1024), _build_feature_portrait()) and ok

	host.queue_free()
	return ok


# Captures content into a SubViewport at the given size, then writes the result
# to a deterministic filename under OUTPUT_DIR based on the pixel dimensions.
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


# Creates a temporary SubViewport, adds a background and the content Control,
# then waits 8 frames for Godot to fully render the scene before extracting the
# image. The viewport is freed after capture to avoid memory leaks.
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


# Builds the 512×512 app icon asset: space background + the SVG app icon
# stretched to fill the full square.
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


# Builds the 1024×500 feature graphic (landscape). Scales the TITLE_CROP
# region of the TitleCluster to fit within a 960×360 safe area and centres it.
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


# Builds the 500×1024 feature graphic (portrait). Pins the title to the upper
# third of the canvas so there is space below for promotional text overlays.
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


# Extracts the TitleCluster node from the main menu scene without running the
# full menu. The cluster is reparented to avoid it being freed with the menu,
# and its anchors are reset to top-left so scale/position work predictably.
# Font overrides are applied here to ensure consistent rendering outside the
# game's normal theme context.
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


# Space backdrop matching dev/asset-gen/gen_launcher_icons.py / in-game layers:
# void #00123a, dust, white stars, cyan/pink accents, sparklers, corner asteroids.
# Deterministic RNG so feature graphics stay reproducible.
static func _add_star_field(parent: Control, size: Vector2) -> void:
	var bg := ColorRect.new()
	bg.color = SPACE_BG
	bg.size = size
	parent.add_child(bg)

	const DUST := Color(0.251, 0.251, 0.251, 1.0) # #404040
	const STAR := Color.WHITE
	const CYAN := Color(0.671, 1.0, 0.902, 1.0) # #abffe6
	const PINK := Color(1.0, 0.467, 0.659, 1.0) # #ff77a8
	const STAR_PX := 2.0
	const SPARK_ARM := 2.0

	var area_scale := (size.x * size.y) / (128.0 * 128.0)
	var dust_n := maxi(28, int(round(10.0 * area_scale * 0.55)))
	var bright_n := maxi(20, int(round(8.0 * area_scale * 0.55)))
	var cyan_n := maxi(7, int(round(3.0 * area_scale * 0.55)))
	var pink_n := maxi(5, int(round(2.0 * area_scale * 0.55)))
	var spark_n := maxi(2, int(round(2.0 * area_scale * 0.35)))

	var rng := RandomNumberGenerator.new()
	rng.seed = 7369215
	var placed: Array[Vector2] = []
	var min_dist := 14.0

	var add_star := func(color: Color, px: float = STAR_PX) -> void:
		for _attempt in range(400):
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			var ok := true
			for q in placed:
				if p.distance_to(q) < min_dist:
					ok = false
					break
			if not ok:
				continue
			placed.append(p)
			var star := ColorRect.new()
			star.color = color
			star.size = Vector2(px, px)
			star.position = p - star.size * 0.5
			parent.add_child(star)
			return

	for _i in range(dust_n):
		add_star.call(DUST)
	for _i in range(bright_n):
		add_star.call(STAR)
	for _i in range(cyan_n):
		add_star.call(CYAN)
	for _i in range(pink_n):
		add_star.call(PINK)

	for _i in range(spark_n):
		for _attempt in range(400):
			var c := Vector2(
				rng.randf_range(SPARK_ARM + 2.0, size.x - SPARK_ARM - 2.0),
				rng.randf_range(SPARK_ARM + 2.0, size.y - SPARK_ARM - 2.0)
			)
			var ok := true
			for q in placed:
				if c.distance_to(q) < min_dist * 1.2:
					ok = false
					break
			if not ok:
				continue
			placed.append(c)
			for offset in [
				Vector2(0, -SPARK_ARM),
				Vector2(-SPARK_ARM, 0),
				Vector2(0, 0),
				Vector2(SPARK_ARM, 0),
				Vector2(0, SPARK_ARM),
			]:
				var arm := ColorRect.new()
				arm.color = STAR
				arm.size = Vector2(STAR_PX, STAR_PX)
				arm.position = c + offset - arm.size * 0.5
				parent.add_child(arm)
			break

	_add_feature_asteroids(parent, size)


static func _add_feature_asteroids(parent: Control, size: Vector2) -> void:
	# Match dev/asset-gen/gen_launcher_icons.py — three corners, no bottom-right rock.
	var specs := [
		["res://resources/background/fx_asteroid_1.svg", Vector2(0.04, 0.08), false, false, 1.0],
		["res://resources/background/fx_asteroid_2.svg", Vector2(0.88, 0.10), false, false, 1.12],
		["res://resources/background/fx_asteroid_3.svg", Vector2(0.05, 0.78), false, false, 1.0],
	]
	var base := minf(size.x, size.y) * 0.11
	for entry in specs:
		var path: String = entry[0]
		var frac: Vector2 = entry[1]
		var flip_h: bool = entry[2]
		var flip_v: bool = entry[3]
		var scale_mul: float = entry[4]
		var tex: Texture2D = load(path)
		if tex == null:
			continue
		var stamp := base * scale_mul
		var node := TextureRect.new()
		node.texture = tex
		node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		node.stretch_mode = TextureRect.STRETCH_SCALE
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		node.size = Vector2(stamp, stamp)
		node.position = Vector2(frac.x * size.x, frac.y * size.y)
		if flip_h:
			node.scale.x = -1.0
			node.position.x += stamp
		if flip_v:
			node.scale.y = -1.0
			node.position.y += stamp
		parent.add_child(node)
