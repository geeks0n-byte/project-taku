extends ParallaxBackground

@export var base_scroll_speed: Vector2 = Vector2(-15, -5)
@export var event_spawn_interval: Vector2 = Vector2(0.2, 12.0)
## Chance that a random event draws above the main-menu title (0–1).
@export var foreground_event_chance: float = 0.38

const ASSET_DIR = "res://resources/background/"

const ASSET_FILES = {
	"void": "bg_0_void.svg",
	"dust": "bg_1_far_dust.svg",
	"stars_mid": "bg_2_medium_stars.svg",
	"accents": "bg_3_foreground_accents.svg",
	"sparklers": "bg_4_sparkler_crosses.svg",
	"fx_star": "fx_shooting_star.svg",
	"fx_comet_1": "fx_comet_1.svg",
	"fx_comet_2": "fx_comet_2.svg",
	"fx_comet_3": "fx_comet_3.svg"
}

var tex_shooting_star: Texture2D
var sf_comet_anim: SpriteFrames
var tex_asteroids: Array[Texture2D] = []

var dyn_layer_stars: Node2D
var dyn_layer_comets: Node2D
var dyn_layer_asteroids: Node2D

## Overlay above default UI (layer 0) so events can pass over the menu title.
var _fx_foreground: CanvasLayer
var _fg_stars: Node2D
var _fg_comets: Node2D
var _fg_asteroids: Node2D
var _foreground_events_enabled: bool = false

var event_timers: Dictionary = {}
var _static_mode: bool = false
var _static_rect: TextureRect
var _twinkle_tween: Tween
var _parallax_layer_nodes: Array[ParallaxLayer] = []

func _ready() -> void:
	layer = -2
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_build_background_layers()
	_build_foreground_fx_layer()
	_load_fx_assets()
	_setup_timer("event", event_spawn_interval, _on_event_timeout)
	call_deferred("_on_viewport_size_changed")
	if SaveManager:
		call_deferred("set_static_mode", SaveManager.background_static)

func set_foreground_events_enabled(enabled: bool) -> void:
	_foreground_events_enabled = enabled
	if not enabled:
		_clear_foreground_fx()

func _build_foreground_fx_layer() -> void:
	_fx_foreground = CanvasLayer.new()
	_fx_foreground.name = "FxForeground"
	# Above main-menu UI (0), below options/overlays (20+).
	_fx_foreground.layer = 1
	add_child(_fx_foreground)
	_fg_stars = Node2D.new()
	_fg_comets = Node2D.new()
	_fg_asteroids = Node2D.new()
	_fx_foreground.add_child(_fg_stars)
	_fx_foreground.add_child(_fg_comets)
	_fx_foreground.add_child(_fg_asteroids)

func _clear_foreground_fx() -> void:
	for layer_node in [_fg_stars, _fg_comets, _fg_asteroids]:
		if layer_node:
			for child in layer_node.get_children():
				child.queue_free()

func _use_foreground_layer() -> bool:
	return _foreground_events_enabled and not _static_mode and randf() < foreground_event_chance

func set_static_mode(is_static: bool) -> void:
	_static_mode = is_static
	set_process(not is_static)
	if is_static:
		_stop_events_and_fx()
		_show_static_composite()
	else:
		_hide_static_composite()
		_restart_timer("event")

func _stop_events_and_fx() -> void:
	for key in event_timers:
		var t: Timer = event_timers[key]["timer"]
		if t:
			t.stop()
	for layer_node in [dyn_layer_stars, dyn_layer_comets, dyn_layer_asteroids]:
		if layer_node:
			for child in layer_node.get_children():
				child.queue_free()
	_clear_foreground_fx()

func _show_static_composite() -> void:
	for p_layer in _parallax_layer_nodes:
		if is_instance_valid(p_layer):
			p_layer.visible = false
	# Hide non-parallax tiled void rects that aren't the static rect.
	for child in get_children():
		if child is TextureRect and child != _static_rect:
			child.visible = false
		elif child is ColorRect:
			child.visible = false
	if _twinkle_tween:
		_twinkle_tween.kill()
		_twinkle_tween = null
	if _static_rect == null:
		_static_rect = TextureRect.new()
		_static_rect.name = "StaticComposite"
		_static_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_static_rect.stretch_mode = TextureRect.STRETCH_TILE
		_static_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_static_rect)
		move_child(_static_rect, 0)
	_static_rect.texture = _bake_static_texture()
	_static_rect.visible = true
	_apply_cover_rect(_static_rect, _cover_size())

func _hide_static_composite() -> void:
	if _static_rect:
		_static_rect.visible = false
	for p_layer in _parallax_layer_nodes:
		if is_instance_valid(p_layer):
			p_layer.visible = true
	for child in get_children():
		if child is TextureRect and child != _static_rect:
			child.visible = true
		elif child is ColorRect:
			child.visible = true
	# Rebuild twinkle if missing.
	if _twinkle_tween == null and _parallax_layer_nodes.size() >= 2:
		_start_twinkle_on_mid_layers()

func _bake_static_texture() -> Texture2D:
	var size := Vector2i(1080, 1920)
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.04, 0.04, 0.08, 1.0))
	for key in ["void", "dust", "stars_mid", "accents", "sparklers"]:
		var path: String = ASSET_DIR + ASSET_FILES[key]
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
		_blit_tiled(img, src)
	return ImageTexture.create_from_image(img)

func _blit_tiled(dest: Image, src: Image) -> void:
	var sw := src.get_width()
	var sh := src.get_height()
	if sw <= 0 or sh <= 0:
		return
	var y := 0
	while y < dest.get_height():
		var x := 0
		while x < dest.get_width():
			dest.blend_rect(src, Rect2i(0, 0, sw, sh), Vector2i(x, y))
			x += sw
		y += sh

func _start_twinkle_on_mid_layers() -> void:
	if _parallax_layer_nodes.size() < 2:
		return
	var layer_stars_mid = _parallax_layer_nodes[1] if _parallax_layer_nodes.size() > 1 else null
	var layer_accents = _parallax_layer_nodes[2] if _parallax_layer_nodes.size() > 2 else null
	if layer_stars_mid == null or layer_accents == null:
		return
	_twinkle_tween = create_tween().set_loops()
	_twinkle_tween.tween_property(layer_stars_mid, "modulate:a", 0.5, 3.0)
	_twinkle_tween.parallel().tween_property(layer_accents, "modulate:a", 0.6, 3.0)
	_twinkle_tween.tween_property(layer_stars_mid, "modulate:a", 1.0, 3.0)
	_twinkle_tween.parallel().tween_property(layer_accents, "modulate:a", 1.0, 3.0)

func _build_background_layers() -> void:
	_parallax_layer_nodes.clear()
	var view_size := _cover_size()
	if ResourceLoader.exists(ASSET_DIR + ASSET_FILES["void"]):
		add_child(_create_pixel_rect(load(ASSET_DIR + ASSET_FILES["void"]), view_size))
	else:
		var fallback_bg = ColorRect.new()
		fallback_bg.color = Color(0.04, 0.04, 0.08, 1)
		_apply_cover_rect(fallback_bg, view_size)
		add_child(fallback_bg)

	if ResourceLoader.exists(ASSET_DIR + ASSET_FILES["dust"]):
		_parallax_layer_nodes.append(_build_parallax_layer(load(ASSET_DIR + ASSET_FILES["dust"]), Vector2(0.2, 0.2), view_size))

	var layer_stars_mid = null
	if ResourceLoader.exists(ASSET_DIR + ASSET_FILES["stars_mid"]):
		layer_stars_mid = _build_parallax_layer(load(ASSET_DIR + ASSET_FILES["stars_mid"]), Vector2(0.4, 0.4), view_size)
		_parallax_layer_nodes.append(layer_stars_mid)

	dyn_layer_stars = Node2D.new()
	add_child(dyn_layer_stars)

	var layer_accents = null
	if ResourceLoader.exists(ASSET_DIR + ASSET_FILES["accents"]):
		layer_accents = _build_parallax_layer(load(ASSET_DIR + ASSET_FILES["accents"]), Vector2(0.6, 0.6), view_size)
		_parallax_layer_nodes.append(layer_accents)

	dyn_layer_comets = Node2D.new()
	add_child(dyn_layer_comets)

	if ResourceLoader.exists(ASSET_DIR + ASSET_FILES["sparklers"]):
		_parallax_layer_nodes.append(_build_parallax_layer(load(ASSET_DIR + ASSET_FILES["sparklers"]), Vector2(0.9, 0.9), view_size))

	dyn_layer_asteroids = Node2D.new()
	add_child(dyn_layer_asteroids)

	if layer_stars_mid and layer_accents:
		_twinkle_tween = create_tween().set_loops()
		_twinkle_tween.tween_property(layer_stars_mid, "modulate:a", 0.5, 3.0)
		_twinkle_tween.parallel().tween_property(layer_accents, "modulate:a", 0.6, 3.0)
		_twinkle_tween.tween_property(layer_stars_mid, "modulate:a", 1.0, 3.0)
		_twinkle_tween.parallel().tween_property(layer_accents, "modulate:a", 1.0, 3.0)

func _load_fx_assets() -> void:
	if ResourceLoader.exists(ASSET_DIR + ASSET_FILES["fx_star"]):
		tex_shooting_star = load(ASSET_DIR + ASSET_FILES["fx_star"])

	if ResourceLoader.exists(ASSET_DIR + ASSET_FILES["fx_comet_1"]):
		sf_comet_anim = SpriteFrames.new()
		sf_comet_anim.set_animation_speed("default", 12.0)
		sf_comet_anim.add_frame("default", load(ASSET_DIR + ASSET_FILES["fx_comet_1"]))
		if ResourceLoader.exists(ASSET_DIR + ASSET_FILES["fx_comet_2"]):
			sf_comet_anim.add_frame("default", load(ASSET_DIR + ASSET_FILES["fx_comet_2"]))
		if ResourceLoader.exists(ASSET_DIR + ASSET_FILES["fx_comet_3"]):
			sf_comet_anim.add_frame("default", load(ASSET_DIR + ASSET_FILES["fx_comet_3"]))

	tex_asteroids.clear()
	if ResourceLoader.exists(ASSET_DIR + "fx_asteroid_1.svg"):
		tex_asteroids.append(load(ASSET_DIR + "fx_asteroid_1.svg"))
	if ResourceLoader.exists(ASSET_DIR + "fx_asteroid_2.svg"):
		tex_asteroids.append(load(ASSET_DIR + "fx_asteroid_2.svg"))
	if ResourceLoader.exists(ASSET_DIR + "fx_asteroid_3.svg"):
		tex_asteroids.append(load(ASSET_DIR + "fx_asteroid_3.svg"))

func _cover_size() -> Vector2:
	# With stretch aspect=expand, phones taller than 9:16 grow the viewport.
	# Always cover the live viewport (plus margin for parallax scroll).
	var view := get_viewport().get_visible_rect().size
	if view.x <= 1.0 or view.y <= 1.0:
		view = Vector2(1080.0, 1920.0)
	return view * 1.35

func _apply_cover_rect(rect: Control, view_size: Vector2) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = Vector2(1080.0, 1920.0)
	rect.size = view_size
	# Center overflow so expand-aspect letterboxing never shows empty edges.
	rect.position = (viewport_size - view_size) * 0.5

func _on_viewport_size_changed() -> void:
	var view_size := _cover_size()
	for child in get_children():
		if child is ParallaxLayer:
			child.motion_mirroring = view_size
			for rect_child in child.get_children():
				if rect_child is Control:
					_apply_cover_rect(rect_child, view_size)
		elif child is Control:
			_apply_cover_rect(child, view_size)
	if _static_mode and _static_rect and _static_rect.visible:
		_apply_cover_rect(_static_rect, view_size)

func _process(delta: float) -> void:
	if _static_mode:
		return
	scroll_offset += base_scroll_speed * delta

func _build_parallax_layer(tex: Texture2D, speed_scale: Vector2, view_size: Vector2 = Vector2.ZERO) -> ParallaxLayer:
	if view_size == Vector2.ZERO:
		view_size = _cover_size()
	var p_layer = ParallaxLayer.new()
	p_layer.motion_scale = speed_scale
	p_layer.motion_offset = Vector2(randf_range(0.0, view_size.x), randf_range(0.0, view_size.y))
	p_layer.motion_mirroring = view_size
	p_layer.add_child(_create_pixel_rect(tex, view_size))
	add_child(p_layer)
	return p_layer

func _create_pixel_rect(tex: Texture2D, view_size: Vector2 = Vector2.ZERO) -> TextureRect:
	if view_size == Vector2.ZERO:
		view_size = _cover_size()
	var rect = TextureRect.new()
	rect.texture = tex
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.stretch_mode = TextureRect.STRETCH_TILE
	_apply_cover_rect(rect, view_size)
	return rect

func _setup_timer(key: String, interval: Vector2, callback: Callable) -> void:
	var t = Timer.new()
	t.one_shot = true
	t.timeout.connect(callback)
	add_child(t)
	event_timers[key] = {"timer": t, "interval": interval}
	_restart_timer(key)

func _restart_timer(key: String) -> void:
	if not event_timers.has(key):
		return
	var t_data = event_timers[key]
	if _static_mode:
		t_data["timer"].stop()
		return
	t_data["timer"].start(randf_range(t_data["interval"].x, t_data["interval"].y))

func _on_event_timeout() -> void:
	if _static_mode:
		return
	var roll = randi() % 1000 + 1 
	
	if roll <= 1:
		_trigger_meteor_shower()
	elif roll <= 11:
		debug_spawn_comet()
	elif roll <= 351:
		var spawn_count = 1
		if randi() % 100 < 25:
			spawn_count = randi_range(3, 6)
			
		for i in range(spawn_count):
			debug_spawn_asteroid()
	else:
		debug_spawn_shooting_star()
		
	_restart_timer("event")

func debug_spawn_shooting_star() -> void:
	var target := _fg_stars if _use_foreground_layer() else dyn_layer_stars
	_spawn_entity(tex_shooting_star, target, Vector2(64, 64), 0.8, 1.5, "star")

func debug_spawn_comet() -> void:
	var target := _fg_comets if _use_foreground_layer() else dyn_layer_comets
	_spawn_entity(sf_comet_anim, target, Vector2(128, 64), 10.0, 20.0, "comet")

func debug_spawn_asteroid() -> void:
	if tex_asteroids.is_empty():
		return
	var target := _fg_asteroids if _use_foreground_layer() else dyn_layer_asteroids
	_spawn_entity(tex_asteroids.pick_random(), target, Vector2(64, 64), 15.0, 25.0, "asteroid")

func debug_spawn_asteroid_cloud() -> void:
	var spawn_count := randi_range(3, 6)
	for i in range(spawn_count):
		debug_spawn_asteroid()

func debug_spawn_meteor_shower() -> void:
	_trigger_meteor_shower()

func _trigger_meteor_shower() -> void:
	var count = randi_range(20, 40)
	var use_fg := _use_foreground_layer()
	for i in range(count):
		var delay = randf_range(0.0, 2.5)
		var t = create_tween()
		t.tween_interval(delay)
		t.tween_callback(func():
			var target := _fg_comets if use_fg else dyn_layer_comets
			_spawn_entity(sf_comet_anim, target, Vector2(128, 64), 3.0, 6.0, "comet")
		)

func _on_asteroid_collided(body: Node, self_entity: RigidBody2D) -> void:
	if not body is RigidBody2D: return
	
	if self_entity.get_instance_id() > body.get_instance_id(): return
	
	var vfx = CPUParticles2D.new()
	vfx.emitting = true
	vfx.one_shot = true
	vfx.explosiveness = 0.95
	vfx.amount = 8
	vfx.lifetime = 0.6
	vfx.spread = 180.0
	vfx.gravity = Vector2.ZERO
	vfx.initial_velocity_min = 20.0
	vfx.initial_velocity_max = 80.0
	vfx.scale_amount_min = 2.0
	vfx.scale_amount_max = 6.0
	vfx.color = Color(0.6, 0.6, 0.65) 
	
	vfx.global_position = (self_entity.global_position + body.global_position) / 2.0
	
	dyn_layer_asteroids.add_child(vfx)
	get_tree().create_timer(1.0).timeout.connect(vfx.queue_free)

func _spawn_entity(tex: Variant, target_layer: Node2D, size: Vector2, min_time: float, max_time: float, type: String) -> void:
	if not tex or not target_layer: return
	
	var entity
	var final_duration: float
	
	if type == "comet":
		var anim_sprite = AnimatedSprite2D.new()
		anim_sprite.sprite_frames = tex
		anim_sprite.play("default")
		anim_sprite.centered = true
		entity = anim_sprite
		
	elif type == "asteroid":
		var rb = RigidBody2D.new()
		rb.gravity_scale = 0.0 
		
		rb.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
		rb.linear_damp = 0.0   
		rb.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
		rb.angular_damp = 0.0
		
		var phys_mat = PhysicsMaterial.new()
		phys_mat.bounce = 0.8
		phys_mat.friction = 0.5
		rb.physics_material_override = phys_mat
		
		rb.collision_layer = 2
		rb.collision_mask = 2
		
		rb.contact_monitor = true
		rb.max_contacts_reported = 2
		rb.body_entered.connect(_on_asteroid_collided.bind(rb))
		
		var sprite = Sprite2D.new()
		sprite.texture = tex
		rb.add_child(sprite)
		
		var col = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		col.shape = circle
		rb.add_child(col)
		
		entity = rb
		
	else:
		var tex_rect = TextureRect.new()
		tex_rect.texture = tex
		tex_rect.size = size
		tex_rect.pivot_offset = size / 2.0 
		entity = tex_rect

	entity.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	var viewport_size = get_viewport().get_visible_rect().size
	var max_dim = max(size.x, size.y)
	
	var start_x = viewport_size.x + max_dim + 50
	var end_x = -max_dim - 100 
	var travel_x = start_x - end_x
	var start_y: float
	var end_y: float
	
	if type == "star":
		start_y = randf_range(-100.0, viewport_size.y * 0.4)
		end_y = start_y + (travel_x * randf_range(0.5, 1.5))
	elif type == "comet":
		start_y = randf_range(-100.0, viewport_size.y * 0.6)
		end_y = start_y + (travel_x * randf_range(0.2, 0.8))
	elif type == "asteroid":
		start_y = randf_range(-100.0, viewport_size.y * 0.8)
		end_y = start_y + (travel_x * randf_range(0.1, 1.2))
	
	entity.position = Vector2(start_x, start_y)
	
	if type == "star" or type == "comet":
		var flight_vector = Vector2(end_x - start_x, end_y - start_y)
		var base_angle = (3.0 * PI / 4.0) if type == "star" else PI
		entity.rotation = flight_vector.angle() - base_angle
		
		if type == "comet":
			var random_scale = randf_range(0.9, 1.1)
			entity.scale = Vector2.ONE * random_scale
			final_duration = remap(random_scale, 0.9, 1.1, max_time, min_time) * randf_range(0.85, 1.15)
		else:
			final_duration = randf_range(min_time, max_time)
			
	elif type == "asteroid":
		entity.rotation = randf_range(0.0, PI * 2.0) 
		var random_scale = randf_range(0.8, 1.2)
		
		var sprite = entity.get_child(0) as Sprite2D
		sprite.scale = Vector2.ONE * random_scale
		
		var col = entity.get_child(1) as CollisionShape2D
		col.shape.radius = 32.0 * random_scale * 0.8 
		
		entity.mass = random_scale * 1.5 
		
		var base_duration = remap(random_scale, 0.8, 1.2, max_time, min_time)
		final_duration = base_duration * randf_range(0.85, 1.15)

	target_layer.add_child(entity)
	
	if type == "asteroid":
		var travel_vector = Vector2(end_x - start_x, end_y - start_y)
		var velocity_pixels_per_sec = travel_vector / final_duration
		entity.linear_velocity = velocity_pixels_per_sec
		
		var total_rotations = randf_range(1.0, 5.0) 
		var total_spin_amount = total_rotations * (PI * 2.0) * (1.0 if randi() % 2 == 0 else -1.0)
		entity.angular_velocity = total_spin_amount / final_duration
		
		get_tree().create_timer(120.0).timeout.connect(entity.queue_free)
		
	else:
		var tween = entity.create_tween()
		tween.tween_property(entity, "position", Vector2(end_x, end_y), final_duration)
		tween.set_parallel(false)
		tween.tween_callback(entity.queue_free)
