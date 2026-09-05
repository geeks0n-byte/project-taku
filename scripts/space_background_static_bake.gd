class_name SpaceBackgroundStaticBake
extends RefCounted

var _host: ParallaxBackground
var _parallax: SpaceBackgroundParallax
var _cached_bake_texture: Texture2D
var _static_rect: TextureRect


func setup(host: ParallaxBackground, parallax: SpaceBackgroundParallax) -> void:
	_host = host
	_parallax = parallax


func static_rect() -> TextureRect:
	return _static_rect


func get_baked_texture() -> Texture2D:
	if _cached_bake_texture == null:
		_cached_bake_texture = _bake_static_texture()
	return _cached_bake_texture


func show_composite() -> void:
	_present_baked_composite()


func hide_composite() -> void:
	if _static_rect:
		_static_rect.visible = false
	for p_layer in _parallax.parallax_layer_nodes():
		if is_instance_valid(p_layer):
			p_layer.visible = true
	for child in _host.get_children():
		if child is TextureRect and child != _static_rect:
			child.visible = true
		elif child is ColorRect:
			child.visible = true
	if _parallax.twinkle_tween() == null and _parallax.parallax_layer_nodes().size() >= 2:
		_parallax.start_twinkle_on_mid_layers()


func _present_baked_composite() -> void:
	for p_layer in _parallax.parallax_layer_nodes():
		if is_instance_valid(p_layer):
			p_layer.visible = false
	for child in _host.get_children():
		if child.name == "Void":
			continue
		if child is TextureRect and child != _static_rect:
			child.visible = false
		elif child is ColorRect:
			child.visible = false
	_parallax.kill_twinkle()
	if _static_rect == null:
		_static_rect = TextureRect.new()
		_static_rect.name = "StaticComposite"
		_static_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_static_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_host.add_child(_static_rect)
	_place_static_composite_above_void()
	_static_rect.texture = get_baked_texture()
	_static_rect.visible = true
	_parallax.apply_phone_scale_cover(_static_rect, _parallax.cover_size())


func _place_static_composite_above_void() -> void:
	if _static_rect == null:
		return
	var void_idx := -1
	for i in _host.get_child_count():
		if _host.get_child(i).name == "Void":
			void_idx = i
			break
	if void_idx < 0:
		_host.move_child(_static_rect, 0)
	else:
		_host.move_child(_static_rect, void_idx + 1)


func _bake_static_texture() -> Texture2D:
	var size := Vector2i(1080, 1920)
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.04, 0.04, 0.08, 1.0))
	var bake_rng := RandomNumberGenerator.new()
	bake_rng.seed = _parallax.bg_seed()
	for key in ["void", "dust", "stars_mid", "accents", "sparklers"]:
		var path: String = SpaceBackgroundParallax.ASSET_DIR + SpaceBackgroundParallax.ASSET_FILES[key]
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path)
		if tex == null:
			continue
		var src := tex.get_image()
		if src == null:
			continue
		if src.get_format() != Image.FORMAT_RGBA8:
			src = src.duplicate()
			src.convert(Image.FORMAT_RGBA8)
		var phase := Vector2i(bake_rng.randi(), bake_rng.randi())
		_blit_tiled(img, src, phase)
	return ImageTexture.create_from_image(img)


func _blit_tiled(dest: Image, src: Image, phase: Vector2i = Vector2i.ZERO) -> void:
	var sw := src.get_width()
	var sh := src.get_height()
	if sw <= 0 or sh <= 0:
		return
	var ox := posmod(phase.x, sw)
	var oy := posmod(phase.y, sh)
	var y := -oy
	while y < dest.get_height():
		var x := -ox
		while x < dest.get_width():
			dest.blend_rect(src, Rect2i(0, 0, sw, sh), Vector2i(x, y))
			x += sw
		y += sh
