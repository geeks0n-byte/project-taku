extends ParallaxBackground

@export var base_scroll_speed: Vector2 = Vector2(-15, -5)
@export var event_spawn_interval: Vector2 = Vector2(0.2, 12.0)

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

var event_timers: Dictionary = {}

func _ready() -> void:
	layer = -2
	
	if ResourceLoader.exists(ASSET_DIR + ASSET_FILES["void"]):
		add_child(_create_pixel_rect(load(ASSET_DIR + ASSET_FILES["void"])))
	else:
		var fallback_bg = ColorRect.new()
		fallback_bg.color = Color(0.04, 0.04, 0.08, 1)
		fallback_bg.size = Vector2(1080, 1920)
		add_child(fallback_bg)
	
	if ResourceLoader.exists(ASSET_DIR + ASSET_FILES["dust"]):
		_build_parallax_layer(load(ASSET_DIR + ASSET_FILES["dust"]), Vector2(0.2, 0.2))
		
	var layer_stars_mid = null
	if ResourceLoader.exists(ASSET_DIR + ASSET_FILES["stars_mid"]):
		layer_stars_mid = _build_parallax_layer(load(ASSET_DIR + ASSET_FILES["stars_mid"]), Vector2(0.4, 0.4))
	
	dyn_layer_stars = Node2D.new()
	add_child(dyn_layer_stars)
	
	var layer_accents = null
	if ResourceLoader.exists(ASSET_DIR + ASSET_FILES["accents"]):
		layer_accents = _build_parallax_layer(load(ASSET_DIR + ASSET_FILES["accents"]), Vector2(0.6, 0.6))
	
	dyn_layer_comets = Node2D.new()
	add_child(dyn_layer_comets)
	
	if ResourceLoader.exists(ASSET_DIR + ASSET_FILES["sparklers"]):
		_build_parallax_layer(load(ASSET_DIR + ASSET_FILES["sparklers"]), Vector2(0.9, 0.9))
	
	dyn_layer_asteroids = Node2D.new()
	add_child(dyn_layer_asteroids)
	
	if layer_stars_mid and layer_accents:
		var twinkle_tween = create_tween().set_loops()
		twinkle_tween.tween_property(layer_stars_mid, "modulate:a", 0.5, 3.0)
		twinkle_tween.parallel().tween_property(layer_accents, "modulate:a", 0.6, 3.0)
		twinkle_tween.tween_property(layer_stars_mid, "modulate:a", 1.0, 3.0)
		twinkle_tween.parallel().tween_property(layer_accents, "modulate:a", 1.0, 3.0)
	
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
			
	if ResourceLoader.exists(ASSET_DIR + "fx_asteroid_1.svg"):
		tex_asteroids.append(load(ASSET_DIR + "fx_asteroid_1.svg"))
	if ResourceLoader.exists(ASSET_DIR + "fx_asteroid_2.svg"):
		tex_asteroids.append(load(ASSET_DIR + "fx_asteroid_2.svg"))
	if ResourceLoader.exists(ASSET_DIR + "fx_asteroid_3.svg"):
		tex_asteroids.append(load(ASSET_DIR + "fx_asteroid_3.svg"))
	
	_setup_timer("event", event_spawn_interval, _on_event_timeout)

func _process(delta: float) -> void:
	scroll_offset += base_scroll_speed * delta

func _build_parallax_layer(tex: Texture2D, speed_scale: Vector2) -> ParallaxLayer:
	var p_layer = ParallaxLayer.new()
	p_layer.motion_scale = speed_scale
	p_layer.motion_offset = Vector2(randf_range(0.0, 1080.0), randf_range(0.0, 1920.0))
	p_layer.motion_mirroring = Vector2(1080, 1920)
	p_layer.add_child(_create_pixel_rect(tex))
	add_child(p_layer)
	return p_layer

func _create_pixel_rect(tex: Texture2D) -> TextureRect:
	var rect = TextureRect.new()
	rect.texture = tex
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.stretch_mode = TextureRect.STRETCH_TILE
	rect.size = Vector2(1080, 1920)
	return rect

func _setup_timer(key: String, interval: Vector2, callback: Callable) -> void:
	var t = Timer.new()
	t.one_shot = true
	t.timeout.connect(callback)
	add_child(t)
	event_timers[key] = {"timer": t, "interval": interval}
	_restart_timer(key)

func _restart_timer(key: String) -> void:
	var t_data = event_timers[key]
	t_data["timer"].start(randf_range(t_data["interval"].x, t_data["interval"].y))

func _on_event_timeout() -> void:
	var roll = randi() % 1000 + 1 
	
	if roll <= 1:
		_trigger_meteor_shower()
	elif roll <= 11:
		_spawn_entity(sf_comet_anim, dyn_layer_comets, Vector2(128, 64), 10.0, 20.0, "comet")
	elif roll <= 351:
		var spawn_count = 1
		if randi() % 100 < 25:
			spawn_count = randi_range(3, 6)
			
		for i in range(spawn_count):
			if tex_asteroids.size() > 0:
				_spawn_entity(tex_asteroids.pick_random(), dyn_layer_asteroids, Vector2(64, 64), 15.0, 25.0, "asteroid")
	else:
		_spawn_entity(tex_shooting_star, dyn_layer_stars, Vector2(64, 64), 0.8, 1.5, "star")
		
	_restart_timer("event")

func _trigger_meteor_shower() -> void:
	var count = randi_range(20, 40)
	for i in range(count):
		var delay = randf_range(0.0, 2.5)
		var t = create_tween()
		t.tween_interval(delay)
		t.tween_callback(func(): _spawn_entity(sf_comet_anim, dyn_layer_comets, Vector2(128, 64), 3.0, 6.0, "comet"))

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
