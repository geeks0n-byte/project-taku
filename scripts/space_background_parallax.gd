class_name SpaceBackgroundParallax
extends RefCounted

const ASSET_DIR := "res://resources/background/"
const PHONE_VIEWPORT_SIZE := Vector2(1080.0, 1920.0)
const LAYER_COVER_PAD := 1.35

const ASSET_FILES := {
	"void": "bg_0_void.svg",
	"dust": "bg_1_far_dust.svg",
	"stars_mid": "bg_2_medium_stars.svg",
	"accents": "bg_3_foreground_accents.svg",
	"sparklers": "bg_4_sparkler_crosses.svg",
}

var dyn_layer_stars: Node2D
var dyn_layer_comets: Node2D
var dyn_layer_asteroids: Node2D

var _host: ParallaxBackground
var _parallax_layer_nodes: Array[ParallaxLayer] = []
var _twinkle_tween: Tween
var _bg_seed: int = 0
var _bg_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(host: ParallaxBackground, rng_seed: int) -> void:
	_host = host
	_bg_seed = rng_seed
	_bg_rng.seed = _bg_seed


func bg_seed() -> int:
	return _bg_seed


func parallax_layer_nodes() -> Array[ParallaxLayer]:
	return _parallax_layer_nodes


func twinkle_tween() -> Tween:
	return _twinkle_tween


func kill_twinkle() -> void:
	if _twinkle_tween:
		_twinkle_tween.kill()
		_twinkle_tween = null


static func phone_layer_scale(tex_size: Vector2, phone_viewport: Vector2 = Vector2(1080.0, 1920.0)) -> float:
	var tile := phone_viewport * LAYER_COVER_PAD
	var tw := maxf(1.0, tex_size.x)
	var th := maxf(1.0, tex_size.y)
	return maxf(tile.x / tw, tile.y / th)


static func phone_cover_size() -> Vector2:
	return PHONE_VIEWPORT_SIZE * LAYER_COVER_PAD


static func fx_spawn_start_x(viewport_width: float, max_dim: float, margin: float = 50.0) -> float:
	return viewport_width + max_dim + margin


func live_viewport_size() -> Vector2:
	return live_visible_rect().size


func live_visible_rect() -> Rect2:
	var view := _host.get_viewport().get_visible_rect()
	if view.size.x <= 1.0 or view.size.y <= 1.0:
		return Rect2(Vector2.ZERO, PHONE_VIEWPORT_SIZE)
	return view


func cover_size() -> Vector2:
	return phone_cover_size()


func build_layers() -> void:
	_parallax_layer_nodes.clear()
	var view_size := cover_size()
	var viewport_size := live_viewport_size()
	if ResourceLoader.exists(ASSET_DIR + ASSET_FILES["void"]):
		_host.add_child(_create_void_rect(load(ASSET_DIR + ASSET_FILES["void"])))
	else:
		var fallback_bg := ColorRect.new()
		fallback_bg.name = "Void"
		fallback_bg.color = Color(0.04, 0.04, 0.08, 1)
		_apply_cover_rect(fallback_bg, viewport_size)
		_host.add_child(fallback_bg)

	if ResourceLoader.exists(ASSET_DIR + ASSET_FILES["dust"]):
		_parallax_layer_nodes.append(_build_parallax_layer(load(ASSET_DIR + ASSET_FILES["dust"]), Vector2(0.2, 0.2), view_size))

	var layer_stars_mid: ParallaxLayer = null
	if ResourceLoader.exists(ASSET_DIR + ASSET_FILES["stars_mid"]):
		layer_stars_mid = _build_parallax_layer(load(ASSET_DIR + ASSET_FILES["stars_mid"]), Vector2(0.4, 0.4), view_size)
		_parallax_layer_nodes.append(layer_stars_mid)

	dyn_layer_stars = Node2D.new()
	_host.add_child(dyn_layer_stars)

	var layer_accents: ParallaxLayer = null
	if ResourceLoader.exists(ASSET_DIR + ASSET_FILES["accents"]):
		layer_accents = _build_parallax_layer(load(ASSET_DIR + ASSET_FILES["accents"]), Vector2(0.6, 0.6), view_size)
		_parallax_layer_nodes.append(layer_accents)

	dyn_layer_comets = Node2D.new()
	_host.add_child(dyn_layer_comets)

	if ResourceLoader.exists(ASSET_DIR + ASSET_FILES["sparklers"]):
		_parallax_layer_nodes.append(_build_parallax_layer(load(ASSET_DIR + ASSET_FILES["sparklers"]), Vector2(0.9, 0.9), view_size))

	dyn_layer_asteroids = Node2D.new()
	_host.add_child(dyn_layer_asteroids)

	if layer_stars_mid and layer_accents:
		start_twinkle_on_mid_layers()


func start_twinkle_on_mid_layers() -> void:
	if _parallax_layer_nodes.size() < 2:
		return
	var layer_stars_mid := _parallax_layer_nodes[1] if _parallax_layer_nodes.size() > 1 else null
	var layer_accents := _parallax_layer_nodes[2] if _parallax_layer_nodes.size() > 2 else null
	if layer_stars_mid == null or layer_accents == null:
		return
	_twinkle_tween = _host.create_tween().set_loops()
	_twinkle_tween.tween_property(layer_stars_mid, "modulate:a", 0.5, 3.0)
	_twinkle_tween.parallel().tween_property(layer_accents, "modulate:a", 0.6, 3.0)
	_twinkle_tween.tween_property(layer_stars_mid, "modulate:a", 1.0, 3.0)
	_twinkle_tween.parallel().tween_property(layer_accents, "modulate:a", 1.0, 3.0)


func on_viewport_size_changed(static_mode: bool, static_rect: TextureRect, on_relayout_boot_intro: Callable) -> void:
	var cover := cover_size()
	var viewport_size := live_viewport_size()
	for child in _host.get_children():
		if child is ParallaxLayer:
			child.motion_mirroring = cover
			for rect_child in child.get_children():
				if rect_child is TextureRect:
					_apply_phone_scale_cover(rect_child as TextureRect, cover)
				elif rect_child is Control:
					_apply_cover_rect(rect_child as Control, cover)
		elif child.name == "Void":
			if child is TextureRect:
				_apply_void_cover(child as TextureRect)
			elif child is Control:
				_apply_cover_rect(child as Control, viewport_size)
		elif child is TextureRect:
			_apply_phone_scale_cover(child as TextureRect, cover)
		elif child is ColorRect:
			_apply_cover_rect(child as Control, viewport_size)
	if static_mode and static_rect and static_rect.visible:
		_apply_phone_scale_cover(static_rect, cover)
	if on_relayout_boot_intro.is_valid():
		on_relayout_boot_intro.call()


func _build_parallax_layer(tex: Texture2D, speed_scale: Vector2, view_size: Vector2 = Vector2.ZERO) -> ParallaxLayer:
	if view_size == Vector2.ZERO:
		view_size = cover_size()
	var p_layer := ParallaxLayer.new()
	p_layer.motion_scale = speed_scale
	p_layer.motion_offset = Vector2(
		_bg_rng.randf_range(0.0, view_size.x),
		_bg_rng.randf_range(0.0, view_size.y)
	)
	p_layer.motion_mirroring = view_size
	p_layer.add_child(_create_pixel_rect(tex, view_size))
	_host.add_child(p_layer)
	return p_layer


func _create_pixel_rect(tex: Texture2D, view_size: Vector2 = Vector2.ZERO) -> TextureRect:
	if view_size == Vector2.ZERO:
		view_size = cover_size()
	var rect := TextureRect.new()
	rect.texture = tex
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_phone_scale_cover(rect, view_size)
	return rect


func _create_void_rect(tex: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = "Void"
	rect.texture = tex
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_void_cover(rect)
	return rect


func _apply_cover_rect(rect: Control, view_size: Vector2) -> void:
	var viewport_size := live_viewport_size()
	rect.scale = Vector2.ONE
	rect.size = view_size
	rect.position = (viewport_size - view_size) * 0.5


func _apply_void_cover(rect: TextureRect) -> void:
	var viewport_size := live_viewport_size()
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.scale = Vector2.ONE
	rect.size = viewport_size
	rect.position = Vector2.ZERO


func apply_phone_scale_cover(rect: TextureRect, view_size: Vector2) -> void:
	_apply_phone_scale_cover(rect, view_size)


func _apply_phone_scale_cover(rect: TextureRect, view_size: Vector2) -> void:
	var viewport_size := live_viewport_size()
	var cover := view_size
	if cover.x <= 1.0 or cover.y <= 1.0:
		cover = phone_cover_size()
	var tex_size := PHONE_VIEWPORT_SIZE
	if rect.texture:
		tex_size = Vector2(float(rect.texture.get_width()), float(rect.texture.get_height()))
	var phone_scale := phone_layer_scale(tex_size)
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.scale = Vector2(phone_scale, phone_scale)
	rect.size = cover / phone_scale
	rect.position = (viewport_size - cover) * 0.5
