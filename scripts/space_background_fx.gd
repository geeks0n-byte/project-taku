class_name SpaceBackgroundFx
extends RefCounted

var tex_shooting_star: Texture2D
var sf_comet_anim: SpriteFrames
var tex_asteroids: Array[Texture2D] = []

var _host: ParallaxBackground
var _parallax: SpaceBackgroundParallax
var _pool: SpaceBackgroundAsteroidPool
var _foreground_event_chance: float = 0.38
var _foreground_events_enabled: bool = false
var _is_static_mode: Callable

var _fx_foreground: CanvasLayer
var _fg_stars: Node2D
var _fg_comets: Node2D
var _fg_asteroids: Node2D
var event_timers: Dictionary = {}


func setup(
	host: ParallaxBackground,
	parallax: SpaceBackgroundParallax,
	pool: SpaceBackgroundAsteroidPool,
	event_interval: Vector2,
	foreground_chance: float,
	is_static_mode: Callable
) -> void:
	_host = host
	_parallax = parallax
	_pool = pool
	_foreground_event_chance = foreground_chance
	_is_static_mode = is_static_mode
	event_timers["event"] = {"interval": event_interval}


func fg_asteroids() -> Node2D:
	return _fg_asteroids


func set_foreground_events_enabled(enabled: bool) -> void:
	_foreground_events_enabled = enabled
	if not enabled:
		clear_foreground_fx()


func build_foreground_layer() -> void:
	_fx_foreground = CanvasLayer.new()
	_fx_foreground.name = "FxForeground"
	_fx_foreground.layer = 1
	_fx_foreground.follow_viewport_enabled = false
	_host.add_child(_fx_foreground)
	_fg_stars = Node2D.new()
	_fg_comets = Node2D.new()
	_fg_asteroids = Node2D.new()
	_fx_foreground.add_child(_fg_stars)
	_fx_foreground.add_child(_fg_comets)
	_fx_foreground.add_child(_fg_asteroids)


func ensure_foreground_layer() -> void:
	if _fg_asteroids == null:
		build_foreground_layer()


func load_assets() -> void:
	var loaded: Dictionary = SpaceBackgroundFxAssets.load_assets()
	tex_shooting_star = loaded.get("tex_shooting_star")
	sf_comet_anim = loaded.get("sf_comet_anim")
	tex_asteroids = loaded.get("tex_asteroids", [])


func setup_timer(key: String, interval: Vector2, callback: Callable) -> void:
	var t := Timer.new()
	t.one_shot = true
	t.timeout.connect(callback)
	_host.add_child(t)
	event_timers[key] = {"timer": t, "interval": interval}
	restart_timer(key)


func restart_timer(key: String) -> void:
	if not event_timers.has(key):
		return
	var t_data = event_timers[key]
	if _is_static_mode.call():
		t_data["timer"].stop()
		return
	t_data["timer"].start(randf_range(t_data["interval"].x, t_data["interval"].y))


func stop_events_and_fx() -> void:
	for key in event_timers:
		var t: Timer = event_timers[key]["timer"]
		if t:
			t.stop()
	for layer_node in [_parallax.dyn_layer_stars, _parallax.dyn_layer_comets, _parallax.dyn_layer_asteroids]:
		if layer_node:
			for child in layer_node.get_children():
				if child is RigidBody2D and child.has_meta("pooled_asteroid"):
					_pool.release(child as RigidBody2D)
				else:
					child.queue_free()
	clear_foreground_fx()


func clear_foreground_fx() -> void:
	for layer_node in [_fg_stars, _fg_comets, _fg_asteroids]:
		if layer_node:
			for child in layer_node.get_children():
				if child is RigidBody2D and child.has_meta("pooled_asteroid"):
					_pool.release(child as RigidBody2D)
				else:
					child.queue_free()


func on_event_timeout() -> void:
	if _is_static_mode.call():
		return
	var roll := randi() % 1000 + 1
	if roll <= 1:
		trigger_meteor_shower()
	elif roll <= 11:
		debug_spawn_comet()
	elif roll <= 351:
		var spawn_count := 1
		if randi() % 100 < 30:
			spawn_count = randi_range(3, 5)
		for i in range(spawn_count):
			debug_spawn_asteroid()
	else:
		debug_spawn_shooting_star()
	restart_timer("event")


func debug_spawn_shooting_star() -> void:
	var target := _fg_stars if _use_foreground_layer() else _parallax.dyn_layer_stars
	_spawn_entity(tex_shooting_star, target, Vector2(64, 64), 0.8, 1.5, "star")


func debug_spawn_comet() -> void:
	var target := _fg_comets if _use_foreground_layer() else _parallax.dyn_layer_comets
	_spawn_entity(sf_comet_anim, target, Vector2(128, 64), 10.0, 20.0, "comet")


func debug_spawn_asteroid() -> void:
	if tex_asteroids.is_empty():
		load_assets()
	if tex_asteroids.is_empty():
		return
	var target := _fg_asteroids if _use_foreground_layer() else _parallax.dyn_layer_asteroids
	if randi() % 100 < 2:
		_spawn_debug_tile_asteroid_standard_motion(target)
		return
	var tex: Texture2D = tex_asteroids.pick_random()
	if tex == null and not tex_asteroids.is_empty():
		tex = tex_asteroids[0]
	if tex == null:
		return
	_spawn_debug_asteroid_standard_motion(target, tex, Vector2(64, 64))


func debug_spawn_asteroid_cloud() -> void:
	var spawn_count := randi_range(3, 6)
	for i in range(spawn_count):
		debug_spawn_asteroid()


func debug_spawn_meteor_shower() -> void:
	trigger_meteor_shower()


func trigger_meteor_shower() -> void:
	var count := randi_range(20, 40)
	var use_fg := _use_foreground_layer()
	for i in range(count):
		var delay := randf_range(0.0, 2.5)
		var t := _host.create_tween()
		t.tween_interval(delay)
		t.tween_callback(_spawn_shower_comet.bind(use_fg))


func spawn_asteroid_impact_burst(global_pos: Vector2, parent: Node) -> void:
	if parent == null:
		return
	var vfx := CPUParticles2D.new()
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
	parent.add_child(vfx)
	vfx.global_position = global_pos
	_host.get_tree().create_timer(1.0).timeout.connect(vfx.queue_free)


func _use_foreground_layer() -> bool:
	return _foreground_events_enabled and not _is_static_mode.call() and randf() < _foreground_event_chance


func _spawn_shower_comet(use_fg: bool) -> void:
	if not _host.is_inside_tree():
		return
	var target := _fg_comets if use_fg else _parallax.dyn_layer_comets
	_spawn_entity(sf_comet_anim, target, Vector2(128, 64), 3.0, 6.0, "comet")


func _spawn_debug_tile_asteroid_standard_motion(target: Node2D) -> void:
	var size := Vector2(36, 36)
	var roll := randi() % 4
	if roll == 3:
		var base_tex := load(GameConstants.TILE_SHIFTER) as Texture2D
		if base_tex == null:
			return
		var arrows: Array[String] = [
			GameConstants.TILE_SHIFTER_UP,
			GameConstants.TILE_SHIFTER_DOWN,
			GameConstants.TILE_SHIFTER_LEFT,
			GameConstants.TILE_SHIFTER_RIGHT,
		]
		var arrow := load(arrows[randi() % arrows.size()]) as Texture2D
		_spawn_debug_asteroid_standard_motion(target, base_tex, size, arrow)
		return
	var paths: Array[String] = [
		GameConstants.TILE_YELLOW,
		GameConstants.TILE_BLUE,
		GameConstants.TILE_GREEN,
	]
	var tex := load(paths[roll]) as Texture2D
	if tex:
		_spawn_debug_asteroid_standard_motion(target, tex, size)


func _spawn_debug_asteroid_standard_motion(
	target_layer: Node2D,
	tex: Texture2D,
	size: Vector2,
	overlay_tex: Texture2D = null
) -> void:
	if tex == null or target_layer == null:
		return
	var rb := _pool.acquire()
	if rb == null:
		return
	_pool.configure_collision_layer(rb, target_layer == _fg_asteroids)
	rb.set_meta("spawn_msec", Time.get_ticks_msec())
	rb.set_meta("entered_view", false)
	rb.freeze = false
	rb.process_mode = Node.PROCESS_MODE_INHERIT
	rb.visible = true
	rb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not rb.body_entered.is_connected(_on_asteroid_collided):
		rb.body_entered.connect(_on_asteroid_collided.bind(rb))

	var sprite := rb.get_node("Sprite") as Sprite2D
	sprite.texture = tex
	var base_scale := size.x / maxf(1.0, float(tex.get_width()))
	sprite.scale = Vector2.ONE * base_scale

	var overlay := rb.get_node("Overlay") as Sprite2D
	if overlay_tex:
		overlay.texture = overlay_tex
		overlay.visible = true
		var overlay_w := maxf(1.0, float(overlay_tex.get_width()))
		overlay.scale = Vector2.ONE * (size.x * 0.72 / overlay_w)
	else:
		overlay.visible = false
		overlay.texture = null

	var col := rb.get_node("Collision") as CollisionShape2D
	if col and col.shape is CircleShape2D:
		(col.shape as CircleShape2D).radius = size.x * 0.4

	rb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var viewport_size := _parallax.live_viewport_size()
	var max_dim: float = maxf(size.x, size.y)
	var start_x: float = SpaceBackgroundParallax.fx_spawn_start_x(viewport_size.x, max_dim)
	var end_x: float = -max_dim - 100.0
	var travel_x: float = start_x - end_x
	var start_y: float = randf_range(-100.0, viewport_size.y * 0.8)
	var end_y: float = start_y + (travel_x * randf_range(0.1, 1.2))

	rb.position = Vector2(start_x, start_y)
	rb.rotation = randf_range(0.0, PI * 2.0)
	var random_scale := randf_range(0.8, 1.2)
	for child in rb.get_children():
		if child is Sprite2D:
			(child as Sprite2D).scale *= random_scale
	if col and col.shape is CircleShape2D:
		(col.shape as CircleShape2D).radius = size.x * 0.4 * random_scale
	rb.mass = random_scale * 1.5

	var base_duration := remap(random_scale, 0.8, 1.2, 25.0, 15.0)
	var final_duration := base_duration * randf_range(0.85, 1.15)
	var travel_vector := Vector2(end_x - start_x, end_y - start_y)
	rb.linear_velocity = travel_vector / final_duration
	var total_rotations := randf_range(1.0, 5.0)
	var spin_dir := 1.0 if randi() % 2 == 0 else -1.0
	var total_spin_amount := total_rotations * (PI * 2.0) * spin_dir
	rb.angular_velocity = total_spin_amount / final_duration

	if rb.get_parent() != null:
		rb.get_parent().remove_child(rb)
	target_layer.add_child(rb)


func _on_asteroid_collided(body: Node, self_entity: RigidBody2D) -> void:
	if not body is RigidBody2D:
		return
	if self_entity.get_instance_id() > body.get_instance_id():
		return
	if self_entity.collision_layer != body.collision_layer:
		return
	var burst_parent := _fg_asteroids if self_entity.get_parent() == _fg_asteroids else _parallax.dyn_layer_asteroids
	spawn_asteroid_impact_burst(
		(self_entity.global_position + body.global_position) * 0.5,
		burst_parent
	)


func _spawn_entity(
	tex: Variant,
	target_layer: Node2D,
	size: Vector2,
	min_time: float,
	max_time: float,
	type: String,
	overlay_tex: Texture2D = null
) -> void:
	if not tex or not target_layer:
		return
	var entity: Node
	var final_duration: float
	if type == "comet":
		var anim_sprite := AnimatedSprite2D.new()
		anim_sprite.sprite_frames = tex
		anim_sprite.play("default")
		anim_sprite.centered = true
		entity = anim_sprite
	elif type == "asteroid":
		var rb := _pool.acquire()
		if rb == null:
			return
		_pool.configure_collision_layer(rb, target_layer == _fg_asteroids)
		rb.set_meta("spawn_msec", Time.get_ticks_msec())
		rb.set_meta("entered_view", false)
		rb.freeze = false
		rb.process_mode = Node.PROCESS_MODE_INHERIT
		rb.visible = true
		rb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if not rb.body_entered.is_connected(_on_asteroid_collided):
			rb.body_entered.connect(_on_asteroid_collided.bind(rb))

		var sprite := rb.get_node("Sprite") as Sprite2D
		sprite.texture = tex
		var base_scale := 1.0
		if tex:
			var tex_w := maxf(1.0, float(tex.get_width()))
			base_scale = size.x / tex_w
			sprite.scale = Vector2.ONE * base_scale

		var overlay := rb.get_node("Overlay") as Sprite2D
		if overlay_tex:
			overlay.texture = overlay_tex
			overlay.visible = true
			var overlay_w := maxf(1.0, float(overlay_tex.get_width()))
			overlay.scale = Vector2.ONE * (size.x * 0.72 / overlay_w)
		else:
			overlay.visible = false
			overlay.texture = null

		var col := rb.get_node("Collision") as CollisionShape2D
		if col and col.shape is CircleShape2D:
			(col.shape as CircleShape2D).radius = size.x * 0.4

		entity = rb
	else:
		var tex_rect := TextureRect.new()
		tex_rect.texture = tex
		tex_rect.size = size
		tex_rect.pivot_offset = size / 2.0
		entity = tex_rect

	if entity is CanvasItem:
		(entity as CanvasItem).texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var viewport_size := _parallax.live_viewport_size()
	var max_dim: float = maxf(size.x, size.y)

	var start_x: float = SpaceBackgroundParallax.fx_spawn_start_x(viewport_size.x, max_dim)
	var end_x: float = -max_dim - 100.0
	var travel_x: float = start_x - end_x
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
		var flight_vector := Vector2(end_x - start_x, end_y - start_y)
		var base_angle := (3.0 * PI / 4.0) if type == "star" else PI
		entity.rotation = flight_vector.angle() - base_angle

		if type == "comet":
			var random_scale := randf_range(0.9, 1.1)
			entity.scale = Vector2.ONE * random_scale
			final_duration = remap(random_scale, 0.9, 1.1, max_time, min_time) * randf_range(0.85, 1.15)
		else:
			final_duration = randf_range(min_time, max_time)
	elif type == "asteroid":
		entity.rotation = randf_range(0.0, PI * 2.0)
		var random_scale := randf_range(0.8, 1.2)

		for child in entity.get_children():
			if child is Sprite2D:
				(child as Sprite2D).scale *= random_scale

		var col := entity.get_node_or_null("Collision") as CollisionShape2D
		if col and col.shape is CircleShape2D:
			(col.shape as CircleShape2D).radius = size.x * 0.4 * random_scale

		entity.mass = random_scale * 1.5

		var base_duration := remap(random_scale, 0.8, 1.2, max_time, min_time)
		final_duration = base_duration * randf_range(0.85, 1.15)

	if entity.get_parent() != null:
		entity.get_parent().remove_child(entity)
	target_layer.add_child(entity)

	if type == "asteroid":
		var travel_vector := Vector2(end_x - start_x, end_y - start_y)
		var velocity_pixels_per_sec := travel_vector / final_duration
		entity.linear_velocity = velocity_pixels_per_sec

		var total_rotations := randf_range(1.0, 5.0)
		var total_spin_amount := total_rotations * (PI * 2.0) * (1.0 if randi() % 2 == 0 else -1.0)
		entity.angular_velocity = total_spin_amount / final_duration
	else:
		var tween: Tween = entity.create_tween()
		tween.tween_property(entity, "position", Vector2(end_x, end_y), final_duration)
		tween.set_parallel(false)
		tween.tween_callback(entity.queue_free)
