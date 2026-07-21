extends ParallaxBackground

# --- CONFIGURATION ---
@export var base_scroll_speed: Vector2 = Vector2(-15, -5)

# A single master timer controls how often ANY event happens. 
# Every time it fires, it rolls a 100-sided die to decide WHAT spawns.
@export var event_spawn_interval: Vector2 = Vector2(0.2, 12.0) 

const ASSET_DIR = "res://background/" 

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

# Textures and Animations
var tex_shooting_star: Texture2D
var sf_comet_anim: SpriteFrames 
var tex_asteroids: Array[Texture2D] = []

# Dynamic Layers
var dyn_layer_stars: Node2D
var dyn_layer_comets: Node2D
var dyn_layer_asteroids: Node2D

var event_timers: Dictionary = {}

func _ready() -> void:
	layer = -2
	
	for key in ASSET_FILES:
		var file_path = ASSET_DIR + ASSET_FILES[key]
		if not ResourceLoader.exists(file_path):
			printerr("BACKGROUND ERROR: Cannot find file at: ", file_path)
			return
			
	tex_shooting_star = load(ASSET_DIR + ASSET_FILES["fx_star"])
	
	sf_comet_anim = SpriteFrames.new()
	sf_comet_anim.set_animation_speed("default", 12.0) 
	sf_comet_anim.add_frame("default", load(ASSET_DIR + ASSET_FILES["fx_comet_1"]))
	sf_comet_anim.add_frame("default", load(ASSET_DIR + ASSET_FILES["fx_comet_2"]))
	sf_comet_anim.add_frame("default", load(ASSET_DIR + ASSET_FILES["fx_comet_3"]))
	
	tex_asteroids.append(load(ASSET_DIR + "fx_asteroid_1.svg"))
	tex_asteroids.append(load(ASSET_DIR + "fx_asteroid_2.svg"))
	tex_asteroids.append(load(ASSET_DIR + "fx_asteroid_3.svg"))
	
	# --- 1. BUILD SCENE TREE ---
	
	add_child(_create_pixel_rect(load(ASSET_DIR + ASSET_FILES["void"])))
	
	_build_parallax_layer(load(ASSET_DIR + ASSET_FILES["dust"]), Vector2(0.2, 0.2))
	var layer_stars_mid = _build_parallax_layer(load(ASSET_DIR + ASSET_FILES["stars_mid"]), Vector2(0.4, 0.4))
	
	dyn_layer_stars = Node2D.new()
	add_child(dyn_layer_stars) 
	
	var layer_accents = _build_parallax_layer(load(ASSET_DIR + ASSET_FILES["accents"]), Vector2(0.6, 0.6))
	
	dyn_layer_comets = Node2D.new()
	add_child(dyn_layer_comets)
	
	_build_parallax_layer(load(ASSET_DIR + ASSET_FILES["sparklers"]), Vector2(0.9, 0.9))
	
	dyn_layer_asteroids = Node2D.new()
	add_child(dyn_layer_asteroids) 
	
	# --- 2. TWINKLING EFFECT ---
	var twinkle_tween = create_tween().set_loops()
	twinkle_tween.tween_property(layer_stars_mid, "modulate:a", 0.5, 3.0)
	twinkle_tween.parallel().tween_property(layer_accents, "modulate:a", 0.6, 3.0)
	twinkle_tween.tween_property(layer_stars_mid, "modulate:a", 1.0, 3.0)
	twinkle_tween.parallel().tween_property(layer_accents, "modulate:a", 1.0, 3.0)
	
	# --- 3. MASTER TIMER ---
	_setup_timer("event", event_spawn_interval, _on_event_timeout)

func _process(delta: float) -> void:
	scroll_offset += base_scroll_speed * delta

# --- SETUP HELPERS ---

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

# --- EVENT SPAWNER (PROBABILITY LOOT TABLE) ---

func _on_event_timeout() -> void:
	# Roll a random number between 1 and 100
	var roll = randi() % 100 + 1 
	
	if roll <= 1:
		# 1% Chance: Comet
		_spawn_entity(sf_comet_anim, dyn_layer_comets, Vector2(128, 64), 10.0, 20.0, "comet")
	elif roll <= 35:
		# 34% Chance: Asteroid (Rolls 2 through 35)
		_spawn_entity(tex_asteroids.pick_random(), dyn_layer_asteroids, Vector2(64, 64), 15.0, 25.0, "asteroid")
	else:
		# 65% Chance: Shooting Star (Rolls 36 through 100)
		_spawn_entity(tex_shooting_star, dyn_layer_stars, Vector2(64, 64), 0.8, 1.5, "star")
		
	# Restart the master timer for the next random event
	_restart_timer("event")

# --- COLLISION LOGIC ---

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


# --- UNIVERSAL SPAWN LOGIC ---

func _spawn_entity(tex: Variant, target_layer: Node2D, size: Vector2, min_time: float, max_time: float, type: String) -> void:
	if not tex or not target_layer: return
	
	var entity
	var final_duration: float
	
	# 1. NODE CONSTRUCTION BASED ON TYPE
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
		
	else: # Star
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
	
	# --- MOVEMENT DISPATCH ---
	
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
