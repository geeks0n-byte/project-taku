extends ParallaxBackground

signal boot_intro_impacted(impact_position: Vector2)

# Autoload-style global that renders the animated space backdrop.
# Manages a multi-layer parallax background, a foreground FX CanvasLayer for
# shooting stars / comets / asteroids, and a static composite mode for performance.

# Pixels per second the entire scroll offset moves when not in static mode.
@export var base_scroll_speed: Vector2 = Vector2(-15, -5)
# Min/max seconds between random FX event triggers (shooting star, comet, asteroid).
@export var event_spawn_interval: Vector2 = Vector2(0.2, 12.0)
# Probability (0–1) that a triggered FX event spawns on the foreground CanvasLayer
# instead of the mid-layer, making it appear in front of game UI.
@export var foreground_event_chance: float = 0.38
# Hard cap on simultaneously active asteroid RigidBody2D instances across both layers.
@export var max_active_asteroids: int = 16

const ASSET_DIR = "res://resources/background/"
# Extra pixels beyond the asteroid's visual radius before it is considered fully offscreen.
const ASTEROID_POOL_SIZE := 16
const ASTEROID_OFFSCREEN_MARGIN := 64.0
# Authored portrait size (project.godot). Patterned layers draw ONE tile at
# this size * LAYER_COVER_PAD (1458x2592), centered. Tablets keep phone-scale
# stars; extra width is void gutters, not a second copy of the unique sky.
const PHONE_VIEWPORT_SIZE := Vector2(1080.0, 1920.0)
const LAYER_COVER_PAD := 1.35
const BOOT_INTRO_COLLISION_LAYER := 8
const BOOT_ICON_SIZE := 64
const BOOT_TILE_DST := 16
const BOOT_TILE_GAP := 3
const BOOT_TILE_HALO := 1
const BOOT_TILE_STRIDE := BOOT_TILE_DST - 2 * BOOT_TILE_HALO + BOOT_TILE_GAP
const BOOT_TILE_MARGIN := (BOOT_ICON_SIZE - (BOOT_TILE_STRIDE + BOOT_TILE_DST)) >> 1
const BOOT_INTRO_TILE_PATHS: Array[String] = [
	GameConstants.TILE_SHIFTER,
	GameConstants.TILE_YELLOW,
	GameConstants.TILE_BLUE,
	GameConstants.TILE_GREEN,
]
const BOOT_INTRO_ASTEROID_MASS := 18.0
const BOOT_INTRO_TILE_MASS := 0.85
const BOOT_INTRO_TILE_SCATTER_MIN := 110.0
const BOOT_INTRO_TILE_SCATTER_MAX := 190.0
const BOOT_INTRO_ASTEROID_SPIN_MIN := 1.0
const BOOT_INTRO_ASTEROID_SPIN_MAX := 2.2

# Maps logical layer names to their SVG asset filenames, keeping paths in one place.
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

# Runtime textures/frames loaded once and reused by every spawn call.
var tex_shooting_star: Texture2D
var sf_comet_anim: SpriteFrames
var tex_asteroids: Array[Texture2D] = []

# Mid-layer Node2D containers that sit inside the parallax stack.
var dyn_layer_stars: Node2D
var dyn_layer_comets: Node2D
var dyn_layer_asteroids: Node2D

# Foreground CanvasLayer (layer=1) whose children render on top of the game UI.
var _fx_foreground: CanvasLayer
var _fg_stars: Node2D
var _fg_comets: Node2D
var _fg_asteroids: Node2D
# Set to false during scenes where foreground FX would be distracting.
var _foreground_events_enabled: bool = false
# True while the main-menu boot intro is hiding parallax until stars fade in.
var _boot_intro_prepared: bool = false

# Keyed by timer name ("event"); each entry holds {"timer": Timer, "interval": Vector2}.
var event_timers: Dictionary = {}
# When true, scroll and FX are frozen and the background is replaced with a baked texture.
var _static_mode: bool = false
# Lazily created TextureRect that shows the baked composite in static mode.
var _static_rect: TextureRect
# Looping tween that alternates alpha on the stars_mid and accents layers to simulate twinkling.
var _twinkle_tween: Tween
# Ordered list of all ParallaxLayer nodes added by _build_background_layers.
var _parallax_layer_nodes: Array[ParallaxLayer] = []
# Free pool of pre-built RigidBody2D asteroid nodes waiting to be activated.
var _asteroid_pool: Array[RigidBody2D] = []
# Invisible root that holds inactive pooled asteroids to keep the scene tree tidy.
var _asteroid_pool_root: Node2D
# Tracked separately from pool size to avoid iterating children on every frame.
var _active_asteroid_count: int = 0
# Scripted splash asteroid (main menu boot intro); kept out of offscreen recycling.
var _boot_intro_asteroid: RigidBody2D = null
var _boot_intro_root: Node2D = null
var _boot_intro_tiles: Array[RigidBody2D] = []
var _boot_intro_active: bool = false
var _boot_intro_phys_mat: PhysicsMaterial = null
# Shared physics material instance reused by all pooled asteroids (bouncy, no friction-damp).
var _asteroid_phys_mat: PhysicsMaterial
# Cached bake for static background mode.
var _cached_bake_texture: Texture2D = null

var _bg_seed: int = 0
var _bg_rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Seeds the backdrop RNG, builds parallax layers, and follows viewport resizes.
func _ready() -> void:
	# layer = -2 so the entire parallax background renders behind all game UI layers.
	layer = -2
	_bg_seed = randi()
	_bg_rng.seed = _bg_seed
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_build_background_layers()
	_build_foreground_fx_layer()
	_load_fx_assets()
	_init_asteroid_pool()
	_setup_timer("event", event_spawn_interval, _on_event_timeout)
	# Deferred so the viewport size is valid when the first layout pass runs.
	call_deferred("_on_viewport_size_changed")
	# SaveManager may have run first (autoload order); apply preference now that we exist.
	var want_static := SaveManager.background_static if SaveManager else false
	set_static_mode(want_static)

# Controls whether FX events can spawn on the foreground CanvasLayer.
# Disabling also immediately removes any foreground FX that is already visible.
func set_foreground_events_enabled(enabled: bool) -> void:
	_foreground_events_enabled = enabled
	if not enabled:
		_clear_foreground_fx()


## Hides live parallax (or the static bake) so frame zero matches the solid boot splash.
func prepare_boot_intro() -> void:
	_boot_intro_prepared = true
	set_foreground_events_enabled(false)
	_stop_events_and_fx()
	if _twinkle_tween:
		_twinkle_tween.kill()
		_twinkle_tween = null
	if _static_mode and _static_rect:
		_static_rect.modulate.a = 0.0
	else:
		for p_layer in _parallax_layer_nodes:
			if is_instance_valid(p_layer):
				p_layer.modulate.a = 0.0


## Fades parallax layers (or static bake) in during the splash handoff to live stars.
func fade_boot_parallax_in(duration: float) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if _static_mode and _static_rect:
		tween.tween_property(_static_rect, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		tween.set_parallel(true)
		for p_layer in _parallax_layer_nodes:
			if is_instance_valid(p_layer):
				tween.tween_property(p_layer, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_boot_parallax_fade_finished)


func _on_boot_parallax_fade_finished() -> void:
	if _boot_intro_prepared and not _static_mode:
		_start_twinkle_on_mid_layers()
	_boot_intro_prepared = false


## Restores normal FX after the splash intro finishes or is skipped.
func finish_boot_intro() -> void:
	dismiss_boot_intro()
	_boot_intro_prepared = false
	set_foreground_events_enabled(true)
	if _static_mode:
		if _static_rect:
			_static_rect.modulate.a = 1.0
		return
	for p_layer in _parallax_layer_nodes:
		if is_instance_valid(p_layer):
			p_layer.modulate.a = 1.0
	if _twinkle_tween == null:
		_start_twinkle_on_mid_layers()
	_restart_timer("event")


func _boot_intro_icon_layout(view_rect: Rect2) -> Dictionary:
	return GameConstants.boot_splash_icon_layout(view_rect)


func _boot_intro_ref_tile_px() -> float:
	return GameConstants.boot_splash_ref_tile_px(_live_viewport_size().x)


func _ensure_boot_intro_root() -> Node2D:
	if _boot_intro_root != null and is_instance_valid(_boot_intro_root):
		return _boot_intro_root
	_ensure_foreground_fx_layer()
	_boot_intro_root = Node2D.new()
	_boot_intro_root.name = "BootIntroPhysics"
	_fg_asteroids.add_child(_boot_intro_root)
	return _boot_intro_root


func _ensure_foreground_fx_layer() -> void:
	if _fg_asteroids == null:
		_build_foreground_fx_layer()


func _boot_intro_material() -> PhysicsMaterial:
	if _boot_intro_phys_mat == null:
		_boot_intro_phys_mat = PhysicsMaterial.new()
		_boot_intro_phys_mat.bounce = 0.06
		_boot_intro_phys_mat.friction = 0.35
	return _boot_intro_phys_mat


func _make_boot_intro_tile(tex_path: String, center: Vector2, tile_px: float) -> RigidBody2D:
	var rb := RigidBody2D.new()
	rb.set_meta("boot_intro_tile", true)
	rb.gravity_scale = 0.0
	rb.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	rb.linear_damp = 0.35
	rb.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	rb.angular_damp = 0.9
	rb.physics_material_override = _boot_intro_material()
	rb.collision_layer = BOOT_INTRO_COLLISION_LAYER
	rb.collision_mask = BOOT_INTRO_COLLISION_LAYER
	rb.contact_monitor = true
	rb.max_contacts_reported = 2
	rb.freeze = true
	rb.mass = BOOT_INTRO_TILE_MASS
	rb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex := load(tex_path) as Texture2D
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex_w := 16.0
	if tex != null:
		tex_w = float(tex.get_width())
	sprite.scale = Vector2.ONE * GameConstants.boot_splash_tile_sprite_scale(tile_px, tex_w)
	rb.add_child(sprite)
	var col := CollisionShape2D.new()
	col.name = "Collision"
	var box := RectangleShape2D.new()
	box.size = Vector2.ONE * tile_px * 0.88
	col.shape = box
	rb.add_child(col)
	rb.position = center
	return rb


## Four app-icon tiles as separate frozen bodies until the intro asteroid hits.
func setup_boot_intro_tiles() -> void:
	dismiss_boot_intro()
	_boot_intro_active = true
	if _asteroid_phys_mat == null:
		_init_asteroid_pool()
	var root := _ensure_boot_intro_root()
	var layout := _boot_intro_icon_layout(_live_visible_rect())
	var tile_px: float = layout["tile_px"]
	var centers: Array = layout["centers"]
	for i in BOOT_INTRO_TILE_PATHS.size():
		var center: Vector2 = centers[i]
		var tile := _make_boot_intro_tile(BOOT_INTRO_TILE_PATHS[i], center, tile_px)
		root.add_child(tile)
		_boot_intro_tiles.append(tile)


func _relayout_boot_intro_tiles_if_idle() -> void:
	if not _boot_intro_active or _boot_intro_tiles.is_empty():
		return
	for tile in _boot_intro_tiles:
		if is_instance_valid(tile) and not tile.freeze:
			return
	var layout := _boot_intro_icon_layout(_live_visible_rect())
	var centers: Array = layout["centers"]
	for i in _boot_intro_tiles.size():
		if i >= centers.size():
			break
		var tile := _boot_intro_tiles[i]
		if is_instance_valid(tile):
			tile.position = centers[i]


func _unfreeze_boot_intro_tiles() -> void:
	for tile in _boot_intro_tiles:
		if is_instance_valid(tile):
			tile.freeze = false
			tile.linear_velocity = Vector2.ZERO
			tile.angular_velocity = 0.0


func _apply_boot_intro_scatter(asteroid: RigidBody2D) -> void:
	var approach_vel := asteroid.linear_velocity
	var layout := _boot_intro_icon_layout(_live_visible_rect())
	var cluster_center: Vector2 = layout["cluster_center"]
	var tile_px: float = layout["tile_px"]
	var scatter_scale := tile_px / maxf(_boot_intro_ref_tile_px(), 1.0)
	var speed_min := BOOT_INTRO_TILE_SCATTER_MIN * scatter_scale
	var speed_max := BOOT_INTRO_TILE_SCATTER_MAX * scatter_scale
	var dir := approach_vel.normalized() if approach_vel.length_squared() > 1.0 else Vector2(-0.75, 0.55).normalized()
	for tile in _boot_intro_tiles:
		if not is_instance_valid(tile):
			continue
		var away := tile.global_position - cluster_center
		if away.length_squared() < 4.0:
			away = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		var push_dir := (away.normalized() * 0.55 + dir * 0.45).normalized()
		var speed := randf_range(speed_min, speed_max)
		tile.linear_velocity = push_dir * speed
		tile.angular_velocity = randf_range(-1.8, 1.8) * scatter_scale
	# Heavy rock keeps plowing through instead of ricocheting off the cluster.
	if approach_vel.length_squared() > 1.0:
		asteroid.linear_velocity = approach_vel * 0.96
	var spin_cap := BOOT_INTRO_ASTEROID_SPIN_MAX * 1.15
	asteroid.angular_velocity = clampf(asteroid.angular_velocity, -spin_cap, spin_cap)


## Spawns a tile-sized rock aimed at the icon cluster using pooled physics motion.
func spawn_boot_intro_asteroid(travel_duration: float) -> RigidBody2D:
	dismiss_boot_intro_asteroid()
	if tex_asteroids.is_empty():
		_load_fx_assets()
	if tex_asteroids.is_empty():
		return null
	if _boot_intro_tiles.is_empty():
		setup_boot_intro_tiles()
	var layout := _boot_intro_icon_layout(_live_visible_rect())
	var tile_px: float = layout["tile_px"]
	var target: Vector2 = layout["cluster_center"]
	var tex: Texture2D = tex_asteroids.pick_random()
	if tex == null:
		return null
	var size := Vector2.ONE * tile_px
	var rb := _acquire_asteroid()
	if rb == null:
		return null
	rb.set_meta("boot_intro_asteroid", true)
	rb.set_meta("boot_intro_impact_done", false)
	rb.set_meta("spawn_msec", Time.get_ticks_msec())
	rb.set_meta("entered_view", false)
	rb.collision_layer = BOOT_INTRO_COLLISION_LAYER
	rb.collision_mask = BOOT_INTRO_COLLISION_LAYER
	rb.freeze = false
	rb.process_mode = Node.PROCESS_MODE_INHERIT
	rb.visible = true
	rb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rb.physics_material_override = _boot_intro_material()
	rb.mass = BOOT_INTRO_ASTEROID_MASS
	rb.linear_damp = 0.0
	rb.angular_damp = 0.0
	for conn in rb.body_entered.get_connections():
		rb.body_entered.disconnect(conn["callable"])
	rb.body_entered.connect(_on_boot_intro_asteroid_collided.bind(rb))

	var sprite := rb.get_node("Sprite") as Sprite2D
	sprite.texture = tex
	var base_scale := size.x / maxf(1.0, float(tex.get_width()))
	sprite.scale = Vector2.ONE * base_scale
	var overlay := rb.get_node("Overlay") as Sprite2D
	overlay.visible = false
	overlay.texture = null

	var col := rb.get_node("Collision") as CollisionShape2D
	if col and col.shape is CircleShape2D:
		(col.shape as CircleShape2D).radius = size.x * 0.44

	var viewport_size := _live_viewport_size()
	var max_dim: float = maxf(size.x, size.y)
	var start_x: float = viewport_size.x + max_dim * 0.85
	var start_y: float = randf_range(-max_dim * 0.35, viewport_size.y * 0.24)
	var start := Vector2(start_x, start_y)
	var travel := target - start
	var duration := maxf(travel_duration, 0.05)
	rb.position = start
	rb.rotation = randf_range(0.0, TAU)
	rb.linear_velocity = travel / duration
	var spin_dir := 1.0 if randi() % 2 == 0 else -1.0
	rb.angular_velocity = randf_range(BOOT_INTRO_ASTEROID_SPIN_MIN, BOOT_INTRO_ASTEROID_SPIN_MAX) * spin_dir

	if rb.get_parent() != null:
		rb.get_parent().remove_child(rb)
	_ensure_boot_intro_root().add_child(rb)
	# Resting dynamic bodies stay put until the hit; avoids frozen-wall ricochet.
	_unfreeze_boot_intro_tiles()
	_boot_intro_asteroid = rb
	return rb


func _on_boot_intro_asteroid_collided(body: Node, asteroid: RigidBody2D) -> void:
	if not (body is RigidBody2D and body.get_meta("boot_intro_tile", false)):
		return
	var impact_pos := (asteroid.global_position + (body as Node2D).global_position) * 0.5
	var burst_parent := _boot_intro_root if _boot_intro_root else _fg_asteroids
	_spawn_asteroid_impact_burst(impact_pos, burst_parent)
	if asteroid.get_meta("boot_intro_impact_done", false):
		return
	asteroid.set_meta("boot_intro_impact_done", true)
	_apply_boot_intro_scatter(asteroid)
	boot_intro_impacted.emit(impact_pos)


func get_boot_intro_asteroid() -> RigidBody2D:
	return _boot_intro_asteroid if is_instance_valid(_boot_intro_asteroid) else null


func get_boot_intro_asteroid_velocity() -> Vector2:
	var rb := get_boot_intro_asteroid()
	if rb == null:
		return Vector2.ZERO
	return rb.linear_velocity


func boot_intro_tiles_offscreen() -> bool:
	if _boot_intro_tiles.size() < 4:
		return false
	var view := _live_visible_rect()
	for tile in _boot_intro_tiles:
		if not is_instance_valid(tile):
			continue
		if not _boot_intro_body_offscreen(tile, view):
			return false
	return true


## Poof any splash tiles still on screen when the clear-timeout fires (e.g. large tablets).
func explode_boot_intro_tiles_remaining() -> void:
	var view := _live_visible_rect()
	var parent := _boot_intro_root if _boot_intro_root else _fg_asteroids
	for tile in _boot_intro_tiles:
		if not is_instance_valid(tile):
			continue
		if _boot_intro_body_offscreen(tile, view):
			tile.queue_free()
			continue
		_spawn_boot_intro_tile_explosion(tile.global_position, parent)
		tile.queue_free()
	_boot_intro_tiles.clear()
	if is_instance_valid(_boot_intro_asteroid):
		if not _boot_intro_body_offscreen(_boot_intro_asteroid, view):
			_spawn_boot_intro_tile_explosion(_boot_intro_asteroid.global_position, parent)
		dismiss_boot_intro_asteroid()


func _spawn_boot_intro_tile_explosion(global_pos: Vector2, parent: Node) -> void:
	if parent == null:
		return
	_spawn_boot_intro_impact_burst(global_pos, parent)
	var vfx := CPUParticles2D.new()
	vfx.emitting = true
	vfx.one_shot = true
	vfx.explosiveness = 1.0
	vfx.amount = 38
	vfx.lifetime = 1.0
	vfx.spread = 180.0
	vfx.gravity = Vector2.ZERO
	vfx.initial_velocity_min = 110.0
	vfx.initial_velocity_max = 280.0
	vfx.scale_amount_min = 7.0
	vfx.scale_amount_max = 18.0
	vfx.color = Color(0.72, 0.74, 0.82, 1.0)
	parent.add_child(vfx)
	vfx.global_position = global_pos
	get_tree().create_timer(1.45).timeout.connect(vfx.queue_free)


func _spawn_boot_intro_impact_burst(global_pos: Vector2, parent: Node) -> void:
	if parent == null:
		return
	var vfx := CPUParticles2D.new()
	vfx.emitting = true
	vfx.one_shot = true
	vfx.explosiveness = 0.95
	vfx.amount = 16
	vfx.lifetime = 0.85
	vfx.spread = 180.0
	vfx.gravity = Vector2.ZERO
	vfx.initial_velocity_min = 45.0
	vfx.initial_velocity_max = 150.0
	vfx.scale_amount_min = 5.0
	vfx.scale_amount_max = 12.0
	vfx.color = Color(0.65, 0.67, 0.74, 1.0)
	parent.add_child(vfx)
	vfx.global_position = global_pos
	get_tree().create_timer(1.2).timeout.connect(vfx.queue_free)


func _boot_intro_body_offscreen(body: RigidBody2D, view: Rect2, margin: float = 32.0) -> bool:
	var col := body.get_node_or_null("Collision") as CollisionShape2D
	var radius := 64.0
	if col and col.shape is RectangleShape2D:
		var half := (col.shape as RectangleShape2D).size * 0.5
		radius = half.length()
	elif col and col.shape is CircleShape2D:
		radius = (col.shape as CircleShape2D).radius
	radius *= maxf(absf(body.scale.x), absf(body.scale.y))
	radius += margin
	var pos := body.global_position
	return (
		pos.x + radius < view.position.x
		or pos.x - radius > view.position.x + view.size.x
		or pos.y + radius < view.position.y
		or pos.y - radius > view.position.y + view.size.y
	)


func play_asteroid_impact_burst(global_pos: Vector2) -> void:
	var parent := _boot_intro_root if _boot_intro_root else _fg_asteroids
	if parent == null:
		parent = dyn_layer_asteroids
	if parent:
		_spawn_asteroid_impact_burst(global_pos, parent)


func dismiss_boot_intro_asteroid() -> void:
	if not is_instance_valid(_boot_intro_asteroid):
		_boot_intro_asteroid = null
		return
	_release_asteroid(_boot_intro_asteroid)
	_boot_intro_asteroid = null


func dismiss_boot_intro() -> void:
	dismiss_boot_intro_asteroid()
	for tile in _boot_intro_tiles:
		if is_instance_valid(tile):
			tile.queue_free()
	_boot_intro_tiles.clear()
	if _boot_intro_root != null and is_instance_valid(_boot_intro_root):
		_boot_intro_root.queue_free()
		_boot_intro_root = null
	_boot_intro_active = false

## Cached static composite used when animated FX are turned off.
func _get_baked_texture() -> Texture2D:
	if _cached_bake_texture == null:
		_cached_bake_texture = _bake_static_texture()
	return _cached_bake_texture

# Creates the CanvasLayer that renders FX in front of game UI.
# follow_viewport_enabled=false keeps the layer anchored to screen space, not world space.
func _build_foreground_fx_layer() -> void:
	_fx_foreground = CanvasLayer.new()
	_fx_foreground.name = "FxForeground"
	_fx_foreground.layer = 1
	_fx_foreground.follow_viewport_enabled = false
	add_child(_fx_foreground)
	_fg_stars = Node2D.new()
	_fg_comets = Node2D.new()
	_fg_asteroids = Node2D.new()
	_fx_foreground.add_child(_fg_stars)
	_fx_foreground.add_child(_fg_comets)
	_fx_foreground.add_child(_fg_asteroids)

# Removes all active foreground FX children.
# Asteroids are returned to the pool rather than freed so they can be reused.
func _clear_foreground_fx() -> void:
	for layer_node in [_fg_stars, _fg_comets, _fg_asteroids]:
		if layer_node:
			for child in layer_node.get_children():
				if child is RigidBody2D and child.has_meta("pooled_asteroid"):
					_release_asteroid(child as RigidBody2D)
				else:
					child.queue_free()

# Pre-builds ASTEROID_POOL_SIZE inactive asteroids so spawning has no instantiation cost at runtime.
func _init_asteroid_pool() -> void:
	_asteroid_pool_root = Node2D.new()
	_asteroid_pool_root.name = "AsteroidPool"
	_asteroid_pool_root.visible = false
	add_child(_asteroid_pool_root)
	_asteroid_phys_mat = PhysicsMaterial.new()
	_asteroid_phys_mat.bounce = 0.8
	_asteroid_phys_mat.friction = 0.5
	for _i in ASTEROID_POOL_SIZE:
		_asteroid_pool.append(_make_pooled_asteroid())

# Builds a single inactive asteroid RigidBody2D with:
# - No gravity and zero damping (moves at constant velocity set on spawn).
# - Collision on layer/mask 2 so asteroids only collide with each other, not game objects.
# - A main Sprite2D for the rock texture and an Overlay Sprite2D for optional direction icons
#   (e.g. shifter arrows rendered on top of game-tile asteroids).
# - process_mode=DISABLED while pooled to avoid physics overhead when inactive.
func _make_pooled_asteroid() -> RigidBody2D:
	var rb := RigidBody2D.new()
	rb.set_meta("pooled_asteroid", true)
	rb.gravity_scale = 0.0
	rb.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	rb.linear_damp = 0.0
	rb.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	rb.angular_damp = 0.0
	rb.physics_material_override = _asteroid_phys_mat
	rb.collision_layer = 2
	rb.collision_mask = 2
	rb.contact_monitor = true
	rb.max_contacts_reported = 2
	rb.freeze = true
	rb.process_mode = Node.PROCESS_MODE_DISABLED
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	rb.add_child(sprite)
	var overlay := Sprite2D.new()
	overlay.name = "Overlay"
	overlay.centered = true
	overlay.z_index = 1
	overlay.visible = false
	rb.add_child(overlay)
	var col := CollisionShape2D.new()
	col.name = "Collision"
	var circle := CircleShape2D.new()
	circle.radius = 1.0
	col.shape = circle
	rb.add_child(col)
	_asteroid_pool_root.add_child(rb)
	return rb

# Checks out an asteroid from the pool, enforcing the active-count cap with two fallback
# eviction passes: first try to reclaim offscreen asteroids, then the oldest active one.
# Returns null only if the cap still cannot be met after both eviction attempts.
func _acquire_asteroid() -> RigidBody2D:
	_sync_active_asteroid_count()
	if _active_asteroid_count >= max_active_asteroids:
		_release_oldest_offscreen_asteroid()
		_sync_active_asteroid_count()
	if _active_asteroid_count >= max_active_asteroids:
		_release_oldest_active_asteroid()
		_sync_active_asteroid_count()
	if _active_asteroid_count >= max_active_asteroids:
		return null
	var rb: RigidBody2D = null
	if not _asteroid_pool.is_empty():
		rb = _asteroid_pool.pop_back()
	else:
		rb = _make_pooled_asteroid()
	_active_asteroid_count += 1
	return rb

# Releases the first asteroid found to be fully outside the viewport,
# freeing a pool slot without discarding a visible one.
func _release_oldest_offscreen_asteroid() -> void:
	var view := get_viewport().get_visible_rect()
	for layer_node in [dyn_layer_asteroids, _fg_asteroids]:
		if layer_node == null:
			continue
		for child in layer_node.get_children():
			if child is RigidBody2D and child.has_meta("pooled_asteroid"):
				var rb := child as RigidBody2D
				if _asteroid_is_fully_offscreen(rb, view):
					_release_asteroid(rb)
					return

# Last-resort eviction: releases the asteroid that has been alive the longest,
# identified by the "spawn_msec" meta tag written at spawn time.
func _release_oldest_active_asteroid() -> void:
	var oldest: RigidBody2D = null
	var oldest_stamp: int = Time.get_ticks_msec()
	for layer_node in [dyn_layer_asteroids, _fg_asteroids]:
		if layer_node == null:
			continue
		for child in layer_node.get_children():
			if not (child is RigidBody2D and child.has_meta("pooled_asteroid")):
				continue
			var rb := child as RigidBody2D
			var stamp := int(rb.get_meta("spawn_msec", Time.get_ticks_msec()))
			if oldest == null or stamp < oldest_stamp:
				oldest = rb
				oldest_stamp = stamp
	if oldest:
		_release_asteroid(oldest)

# Recounts live asteroids across both layers to keep _active_asteroid_count accurate.
func _sync_active_asteroid_count() -> void:
	var live_count := 0
	for layer_node in [dyn_layer_asteroids, _fg_asteroids]:
		if layer_node == null:
			continue
		for child in layer_node.get_children():
			if child is RigidBody2D and child.has_meta("pooled_asteroid"):
				live_count += 1
	_active_asteroid_count = live_count

# Returns the effective screen-space radius of an asteroid, accounting for its node scale.
# Falls back to 48px when the collision shape is missing (e.g. before full initialization).
func _asteroid_visual_radius(rb: RigidBody2D) -> float:
	var col := rb.get_node_or_null("Collision") as CollisionShape2D
	if col and col.shape is CircleShape2D:
		return (col.shape as CircleShape2D).radius * maxf(absf(rb.scale.x), absf(rb.scale.y))
	return 48.0

# True when the asteroid's bounding circle (plus the offscreen margin) is entirely outside
# the viewport — used to decide when a moving asteroid can safely be recycled.
func _asteroid_is_fully_offscreen(rb: RigidBody2D, view: Rect2) -> bool:
	var radius := _asteroid_visual_radius(rb) + ASTEROID_OFFSCREEN_MARGIN
	var pos := rb.global_position
	return (
		pos.x + radius < view.position.x
		or pos.x - radius > view.position.x + view.size.x
		or pos.y + radius < view.position.y
		or pos.y - radius > view.position.y + view.size.y
	)

# True when any part of the asteroid's bounding circle overlaps the viewport.
# Used to track when a freshly-spawned asteroid first becomes visible so we know
# it has "entered view" and can be released once it exits again.
func _asteroid_intersects_view(rb: RigidBody2D, view: Rect2) -> bool:
	var radius := _asteroid_visual_radius(rb)
	var pos := rb.global_position
	return not (
		pos.x + radius < view.position.x
		or pos.x - radius > view.position.x + view.size.x
		or pos.y + radius < view.position.y
		or pos.y - radius > view.position.y + view.size.y
	)

# Returns an asteroid to the pool: disconnects collision signals, freezes physics,
# hides it, and re-parents it under _asteroid_pool_root.
# If the pool is already at capacity the node is freed instead of retained.
func _release_asteroid(rb: RigidBody2D) -> void:
	if not is_instance_valid(rb):
		return
	if rb == _boot_intro_asteroid:
		_boot_intro_asteroid = null
	if rb.has_meta("boot_intro_asteroid"):
		rb.remove_meta("boot_intro_asteroid")
	# Guard against double-release (already pooled or already in the pool root).
	if rb.get_parent() == _asteroid_pool_root or _asteroid_pool.has(rb):
		return
	for conn in rb.body_entered.get_connections():
		rb.body_entered.disconnect(conn["callable"])
	rb.freeze = true
	rb.linear_velocity = Vector2.ZERO
	rb.angular_velocity = 0.0
	rb.process_mode = Node.PROCESS_MODE_DISABLED
	rb.visible = false
	var overlay := rb.get_node_or_null("Overlay") as Sprite2D
	if overlay:
		overlay.visible = false
		overlay.texture = null
	var parent := rb.get_parent()
	if parent:
		parent.remove_child(rb)
	_asteroid_pool_root.add_child(rb)
	_active_asteroid_count = maxi(0, _active_asteroid_count - 1)
	if _asteroid_pool.size() < ASTEROID_POOL_SIZE:
		_asteroid_pool.append(rb)
	else:
		rb.queue_free()

# Returns true when the next FX event should use the foreground CanvasLayer.
# Requires foreground events to be enabled and passes a random chance roll.
func _use_foreground_layer() -> bool:
	return _foreground_events_enabled and not _static_mode and randf() < foreground_event_chance

# Switches between animated and static background modes.
# In static mode: FX timers and scroll stop, and all parallax layers are replaced by
# a single baked texture for better performance on low-end devices.
func set_static_mode(is_static: bool) -> void:
	_static_mode = is_static
	set_process(not is_static)
	if is_static:
		_stop_events_and_fx()
		_show_static_composite()
	else:
		_hide_static_composite()
		_restart_timer("event")

## Stops spawn timers and frees or pools live shooting-star / comet / asteroid nodes.
func _stop_events_and_fx() -> void:
	for key in event_timers:
		var t: Timer = event_timers[key]["timer"]
		if t:
			t.stop()
	for layer_node in [dyn_layer_stars, dyn_layer_comets, dyn_layer_asteroids]:
		if layer_node:
			for child in layer_node.get_children():
				if child is RigidBody2D and child.has_meta("pooled_asteroid"):
					_release_asteroid(child as RigidBody2D)
				else:
					child.queue_free()
	_clear_foreground_fx()

# Hides patterned parallax layers and shows a single baked composite TextureRect.
# Void stays visible so tablet gutters keep the solid sky color. The bake is one
# phone cover tile, centered — never STRETCH_TILE of the 1080 composite.
# _static_rect is created lazily and reused on subsequent calls.
func _present_baked_composite() -> void:
	for p_layer in _parallax_layer_nodes:
		if is_instance_valid(p_layer):
			p_layer.visible = false
	for child in get_children():
		if child.name == "Void":
			continue
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
		_static_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_static_rect)
	_place_static_composite_above_void()
	_static_rect.texture = _get_baked_texture()
	_static_rect.visible = true
	_apply_phone_scale_cover(_static_rect, _cover_size())


## Stacks the bake just above Void so gutters stay the void color and the 1080
## composite is a single centered tile (not behind the full-viewport void).
func _place_static_composite_above_void() -> void:
	if _static_rect == null:
		return
	var void_idx := -1
	for i in get_child_count():
		if get_child(i).name == "Void":
			void_idx = i
			break
	if void_idx < 0:
		move_child(_static_rect, 0)
	else:
		move_child(_static_rect, void_idx + 1)

## Swaps animated layers for the baked composite (performance / options toggle).
func _show_static_composite() -> void:
	_present_baked_composite()

## Hides the baked composite and shows the live parallax layers again.
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
	if _twinkle_tween == null and _parallax_layer_nodes.size() >= 2:
		_start_twinkle_on_mid_layers()

# CPU-composites all background SVG layers onto a fixed 1080x1920 image.
# Using a fixed resolution keeps the baked texture small while still covering
# portrait phone screens at maximum quality.
# Layer tile phases come from _bg_seed so each launch gets a different static sky.
func _bake_static_texture() -> Texture2D:
	var size := Vector2i(1080, 1920)
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.04, 0.04, 0.08, 1.0))
	var bake_rng := RandomNumberGenerator.new()
	bake_rng.seed = _bg_seed
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
		var phase := Vector2i(bake_rng.randi(), bake_rng.randi())
		_blit_tiled(img, src, phase)
	return ImageTexture.create_from_image(img)

# Tiles src over dest using alpha-blending so each layer composites on top of the previous.
# Handles SVGs whose native size is smaller than the target canvas.
# `phase` shifts the tile origin (mod tile size) so seeded bakes look different per run.
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

# Starts the looping alpha tween that makes the star and accent layers appear to twinkle.
# The two layers fade together but not identically (0.5 vs 0.6 target alpha) for a natural look.
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

## Stacks void, dust, stars, accents, sparklers, and dynamic FX hosts.
func _build_background_layers() -> void:
	_parallax_layer_nodes.clear()
	var view_size := _cover_size()
	var viewport_size := _live_viewport_size()
	if ResourceLoader.exists(ASSET_DIR + ASSET_FILES["void"]):
		add_child(_create_void_rect(load(ASSET_DIR + ASSET_FILES["void"])))
	else:
		var fallback_bg = ColorRect.new()
		fallback_bg.name = "Void"
		fallback_bg.color = Color(0.04, 0.04, 0.08, 1)
		_apply_cover_rect(fallback_bg, viewport_size)
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

# Loads all FX textures/frames at startup (or lazily when first needed for asteroids).
# Comet frames are packed into a SpriteFrames so AnimatedSprite2D can play them at 12 fps.
# Asteroid textures are loaded into a pool so spawning can pick_random() for variety.
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
	
# KEEP_ASPECT_COVERED scale of a layer texture onto one authored phone cover tile.
# Independent of the live viewport so tablets cannot zoom stars.
static func phone_layer_scale(tex_size: Vector2, phone_viewport: Vector2 = Vector2(1080.0, 1920.0)) -> float:
	var tile := phone_viewport * LAYER_COVER_PAD
	var tw := maxf(1.0, tex_size.x)
	var th := maxf(1.0, tex_size.y)
	return maxf(tile.x / tw, tile.y / th)


## One patterned-layer tile: authored phone size * LAYER_COVER_PAD (1458x2592).
## Does not use the live viewport, so a 1440-wide tablet still gets 1080*1.35.
static func phone_cover_size() -> Vector2:
	return PHONE_VIEWPORT_SIZE * LAYER_COVER_PAD


## Off-window FX start X from the live window's right edge.
## `viewport_width` is the live visible rect (tablet 1440, phone 1080), never
## the authored cover width. Both spawn paths share this so stars never appear
## at x=1080 on a wider window.
static func fx_spawn_start_x(viewport_width: float, max_dim: float, margin: float = 50.0) -> float:
	return viewport_width + max_dim + margin


## Live visible-rect size, or the authored phone size when the viewport is not ready.
func _live_viewport_size() -> Vector2:
	return _live_visible_rect().size


func _live_visible_rect() -> Rect2:
	var view := get_viewport().get_visible_rect()
	if view.size.x <= 1.0 or view.size.y <= 1.0:
		return Rect2(Vector2.ZERO, PHONE_VIEWPORT_SIZE)
	return view


## Patterned-layer and motion_mirroring size: always the phone cover tile.
## Extra tablet width is void gutters; we do not grow this with the viewport.
func _cover_size() -> Vector2:
	return phone_cover_size()

# Sizes and centers a Control rect (void ColorRect fallback) on the live viewport.
# Passing the live viewport size fills the window; an oversized size is centered.
func _apply_cover_rect(rect: Control, view_size: Vector2) -> void:
	var viewport_size := _live_viewport_size()
	rect.scale = Vector2.ONE
	rect.size = view_size
	rect.position = (viewport_size - view_size) * 0.5


## Fills the live viewport with the solid void. A flat color can tile without a
## visible seam; we size to the window so gutters exist when the patterned phone
## cover is narrower than a tablet. Never uses the 1080*1.35 unique-sky tile.
func _apply_void_cover(rect: TextureRect) -> void:
	var viewport_size := _live_viewport_size()
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.scale = Vector2.ONE
	rect.size = viewport_size
	rect.position = Vector2.ZERO


## Solid void TextureRect sized to the live viewport (not the phone cover tile).
func _create_void_rect(tex: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = "Void"
	rect.texture = tex
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_void_cover(rect)
	return rect


## One KEEP_ASPECT_COVERED phone tile, centered on the live viewport.
## Does not STRETCH_TILE: tiling a 1080 unique drawing is the tablet double-sky bug.
## view_size is the phone cover (1458x2592), not the live viewport.
func _apply_phone_scale_cover(rect: TextureRect, view_size: Vector2) -> void:
	var viewport_size := _live_viewport_size()
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

## Re-centers the phone cover on resize. Void still fills the live viewport.
## Does not start tiling when width > 1458 — void gutters are OK.
func _on_viewport_size_changed() -> void:
	var cover := _cover_size()
	var viewport_size := _live_viewport_size()
	for child in get_children():
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
	if _static_mode and _static_rect and _static_rect.visible:
		_apply_phone_scale_cover(_static_rect, cover)
	_relayout_boot_intro_tiles_if_idle()

# Advances the parallax scroll and checks for asteroids that have left the screen.
func _process(delta: float) -> void:
	if _static_mode:
		return
	scroll_offset += base_scroll_speed * delta
	_release_offscreen_asteroids()

# Per-frame cleanup: recycles any asteroid that has entered the viewport and then
# fully exited it. The "entered_view" meta flag prevents releasing an asteroid that
# was spawned offscreen but has not yet crossed into view.
func _release_offscreen_asteroids() -> void:
	if _active_asteroid_count <= 0:
		return
	var view := get_viewport().get_visible_rect()
	for layer_node in [dyn_layer_asteroids, _fg_asteroids]:
		if layer_node == null:
			continue
		for child in layer_node.get_children():
			if not (child is RigidBody2D and child.has_meta("pooled_asteroid")):
				continue
			var rb := child as RigidBody2D
			if rb.get_meta("boot_intro_asteroid", false):
				continue
			if rb.get_meta("boot_intro_tile", false):
				continue
			var seen := bool(rb.get_meta("entered_view", false))
			if not seen and _asteroid_intersects_view(rb, view):
				rb.set_meta("entered_view", true)
				seen = true
			if seen and _asteroid_is_fully_offscreen(rb, view):
				_release_asteroid(rb)

# Creates a parallax layer for a given texture.
# motion_offset is seeded so layers don't all start aligned and each launch differs.
# motion_mirroring wraps one phone cover tile (1458x2592) during scroll — not the
# live viewport. The TextureRect is a single untiled KEEP_ASPECT_COVERED drawing.
func _build_parallax_layer(tex: Texture2D, speed_scale: Vector2, view_size: Vector2 = Vector2.ZERO) -> ParallaxLayer:
	if view_size == Vector2.ZERO:
		view_size = _cover_size()
	var p_layer = ParallaxLayer.new()
	p_layer.motion_scale = speed_scale
	p_layer.motion_offset = Vector2(
		_bg_rng.randf_range(0.0, view_size.x),
		_bg_rng.randf_range(0.0, view_size.y)
	)
	p_layer.motion_mirroring = view_size
	p_layer.add_child(_create_pixel_rect(tex, view_size))
	add_child(p_layer)
	return p_layer

## Nearest-filter TextureRect for one patterned phone-cover tile (no STRETCH_TILE).
func _create_pixel_rect(tex: Texture2D, view_size: Vector2 = Vector2.ZERO) -> TextureRect:
	if view_size == Vector2.ZERO:
		view_size = _cover_size()
	var rect = TextureRect.new()
	rect.texture = tex
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_phone_scale_cover(rect, view_size)
	return rect

# Creates a one-shot Timer registered under `key` and immediately starts it with a random
# wait drawn from the [interval.x, interval.y] range. One-shot timers are manually restarted
# by _restart_timer after each callback so the interval randomises each time.
func _setup_timer(key: String, interval: Vector2, callback: Callable) -> void:
	var t = Timer.new()
	t.one_shot = true
	t.timeout.connect(callback)
	add_child(t)
	event_timers[key] = {"timer": t, "interval": interval}
	_restart_timer(key)

# Re-arms the timer with a new random wait from its stored interval.
# In static mode the timer is stopped instead of restarted.
func _restart_timer(key: String) -> void:
	if not event_timers.has(key):
		return
	var t_data = event_timers[key]
	if _static_mode:
		t_data["timer"].stop()
		return
	t_data["timer"].start(randf_range(t_data["interval"].x, t_data["interval"].y))

# Randomly selects and triggers one background FX event, then re-arms the timer.
# Roll thresholds (out of 1000) determine rarity:
#   1/1000  → meteor shower (mass comet burst)
#   10/1000 → single comet
#   340/1000 → asteroid(s), with a 30% chance of spawning a cluster of 3–5
#   648/1000 → shooting star (most common)
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
		if randi() % 100 < 30:
			spawn_count = randi_range(3, 5)
		for i in range(spawn_count):
			debug_spawn_asteroid()
	else:
		debug_spawn_shooting_star()
	_restart_timer("event")

# Public spawn helpers — named "debug_" historically; they are the main runtime spawn paths.
func debug_spawn_shooting_star() -> void:
	var target := _fg_stars if _use_foreground_layer() else dyn_layer_stars
	_spawn_entity(tex_shooting_star, target, Vector2(64, 64), 0.8, 1.5, "star")

## Runtime comet spawn (name is historical); uses foreground layer when enabled.
func debug_spawn_comet() -> void:
	var target := _fg_comets if _use_foreground_layer() else dyn_layer_comets
	_spawn_entity(sf_comet_anim, target, Vector2(128, 64), 10.0, 20.0, "comet")

# Spawns a regular rock asteroid with a 2% chance of using a game-tile texture instead,
# giving the background an occasional Easter-egg feel.
func debug_spawn_asteroid() -> void:
	if tex_asteroids.is_empty():
		_load_fx_assets()
	if tex_asteroids.is_empty():
		return
	var target := _fg_asteroids if _use_foreground_layer() else dyn_layer_asteroids
	if randi() % 100 < 2:
		_spawn_debug_tile_asteroid_standard_motion(target)
		return
	var tex: Texture2D = tex_asteroids.pick_random()
	if tex == null and not tex_asteroids.is_empty():
		tex = tex_asteroids[0]
	if tex == null:
		return
	_spawn_debug_asteroid_standard_motion(target, tex, Vector2(64, 64))

# Spawns an asteroid textured as an in-game tile (yellow/blue/green or a shifter tile).
# Shifter asteroids (roll==3) get a randomly-directed arrow overlay to mimic the in-game look.
func _spawn_tile_asteroid(target: Node2D) -> void:
	var size := Vector2(36, 36)
	var roll := randi() % 4
	if roll == 3:
		var base := load(GameConstants.TILE_SHIFTER) as Texture2D
		if base == null:
			return
		var arrows: Array[String] = [
			GameConstants.TILE_SHIFTER_UP,
			GameConstants.TILE_SHIFTER_DOWN,
			GameConstants.TILE_SHIFTER_LEFT,
			GameConstants.TILE_SHIFTER_RIGHT,
		]
		var arrow := load(arrows[randi() % arrows.size()]) as Texture2D
		_spawn_entity(base, target, size, 15.0, 25.0, "asteroid", arrow)
		return
	var paths: Array[String] = [
		GameConstants.TILE_YELLOW,
		GameConstants.TILE_BLUE,
		GameConstants.TILE_GREEN,
	]
	var tex := load(paths[roll]) as Texture2D
	if tex:
		_spawn_entity(tex, target, size, 15.0, 25.0, "asteroid")

# Variant of _spawn_tile_asteroid that uses _spawn_debug_asteroid_standard_motion
# (physics-driven velocity) instead of a tween, for consistent motion across all asteroid types.
func _spawn_debug_tile_asteroid_standard_motion(target: Node2D) -> void:
	var size := Vector2(36, 36)
	var roll := randi() % 4
	if roll == 3:
		var base := load(GameConstants.TILE_SHIFTER) as Texture2D
		if base == null:
			return
		var arrows: Array[String] = [
			GameConstants.TILE_SHIFTER_UP,
			GameConstants.TILE_SHIFTER_DOWN,
			GameConstants.TILE_SHIFTER_LEFT,
			GameConstants.TILE_SHIFTER_RIGHT,
		]
		var arrow := load(arrows[randi() % arrows.size()]) as Texture2D
		_spawn_debug_asteroid_standard_motion(target, base, size, arrow)
		return
	var paths: Array[String] = [
		GameConstants.TILE_YELLOW,
		GameConstants.TILE_BLUE,
		GameConstants.TILE_GREEN,
	]
	var tex := load(paths[roll]) as Texture2D
	if tex:
		_spawn_debug_asteroid_standard_motion(target, tex, size)

# Acquires a pooled asteroid, configures its texture/scale/collision, then launches it
# with physics-based linear and angular velocity so it drifts across the screen.
# Larger asteroids (higher random_scale) move slower, preserving a sense of mass.
# The "entered_view" meta starts false and flips on when the node crosses into the viewport,
# allowing _release_offscreen_asteroids to skip premature recycling.
func _spawn_debug_asteroid_standard_motion(
	target_layer: Node2D,
	tex: Texture2D,
	size: Vector2,
	overlay_tex: Texture2D = null
) -> void:
	if tex == null or target_layer == null:
		return
	var rb := _acquire_asteroid()
	if rb == null:
		return
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
		# Scale the overlay to 72% of the tile size so the arrow fits inside the rock.
		overlay.scale = Vector2.ONE * (size.x * 0.72 / overlay_w)
	else:
		overlay.visible = false
		overlay.texture = null

	var col := rb.get_node("Collision") as CollisionShape2D
	if col and col.shape is CircleShape2D:
		(col.shape as CircleShape2D).radius = size.x * 0.4

	rb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var viewport_size := _live_viewport_size()
	var max_dim: float = maxf(size.x, size.y)
	# Enter from the live window's right edge (tablet 1440, phone 1080), never 1080-as-cover.
	var start_x: float = fx_spawn_start_x(viewport_size.x, max_dim)
	var end_x: float = -max_dim - 100.0
	var travel_x: float = start_x - end_x
	var start_y: float = randf_range(-100.0, viewport_size.y * 0.8)
	# Add a vertical drift proportional to the horizontal travel so paths vary in angle.
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

	# Bigger asteroids move slower (remapped inverse relationship).
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

## Spawns a small burst of asteroids.
func debug_spawn_asteroid_cloud() -> void:
	var spawn_count := randi_range(3, 6)
	for i in range(spawn_count):
		debug_spawn_asteroid()

## Starts the staggered multi-comet shower.
func debug_spawn_meteor_shower() -> void:
	_trigger_meteor_shower()

# Spawns 20–40 comets staggered over 2.5 seconds to simulate a meteor shower.
# The foreground/background decision is made once so the whole shower appears on the same layer.
func _trigger_meteor_shower() -> void:
	var count = randi_range(20, 40)
	var use_fg := _use_foreground_layer()
	for i in range(count):
		var delay = randf_range(0.0, 2.5)
		var t = create_tween()
		t.tween_interval(delay)
		t.tween_callback(_spawn_shower_comet.bind(use_fg))

## One comet in a shower; no-op if this node left the tree mid-stagger.
func _spawn_shower_comet(use_fg: bool) -> void:
	if not is_inside_tree():
		return
	var target := _fg_comets if use_fg else dyn_layer_comets
	_spawn_entity(sf_comet_anim, target, Vector2(128, 64), 3.0, 6.0, "comet")

# Plays a small particle burst at the midpoint between two colliding asteroids.
# The instance ID guard ensures only the lower-ID body handles the event,
# preventing the callback from firing twice for a single collision pair.
func _on_asteroid_collided(body: Node, self_entity: RigidBody2D) -> void:
	if not body is RigidBody2D: return
	if self_entity.get_instance_id() > body.get_instance_id(): return
	_spawn_asteroid_impact_burst(
		(self_entity.global_position + body.global_position) * 0.5,
		dyn_layer_asteroids
	)


func _spawn_asteroid_impact_burst(global_pos: Vector2, parent: Node) -> void:
	if parent == null:
		return
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
	# Grey-blue tint matches the overall cool colour palette of the background.
	vfx.color = Color(0.6, 0.6, 0.65)
	parent.add_child(vfx)
	vfx.global_position = global_pos
	get_tree().create_timer(1.0).timeout.connect(vfx.queue_free)

# General-purpose entity spawner used by shooting stars, comets, and the tween-based
# asteroid path (the physics path uses _spawn_debug_asteroid_standard_motion instead).
# tex is a Texture2D for stars/asteroids or a SpriteFrames for animated comets.
# min_time/max_time bound the random travel duration.
# overlay_tex is an optional second sprite rendered on top (used for shifter arrow icons).
func _spawn_entity(
	tex: Variant,
	target_layer: Node2D,
	size: Vector2,
	min_time: float,
	max_time: float,
	type: String,
	overlay_tex: Texture2D = null
) -> void:
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
		var rb := _acquire_asteroid()
		if rb == null:
			return
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
		var tex_rect = TextureRect.new()
		tex_rect.texture = tex
		tex_rect.size = size
		tex_rect.pivot_offset = size / 2.0 
		entity = tex_rect

	entity.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	var viewport_size = _live_viewport_size()
	var max_dim = max(size.x, size.y)
	
	var start_x = fx_spawn_start_x(viewport_size.x, max_dim)
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
		
		for child in entity.get_children():
			if child is Sprite2D:
				(child as Sprite2D).scale *= random_scale
		
		var col = entity.get_node_or_null("Collision") as CollisionShape2D
		if col and col.shape is CircleShape2D:
			(col.shape as CircleShape2D).radius = size.x * 0.4 * random_scale
		
		entity.mass = random_scale * 1.5 
		
		var base_duration = remap(random_scale, 0.8, 1.2, max_time, min_time)
		final_duration = base_duration * randf_range(0.85, 1.15)

	if entity.get_parent() != null:
		entity.get_parent().remove_child(entity)
	target_layer.add_child(entity)
	
	if type == "asteroid":
		var travel_vector = Vector2(end_x - start_x, end_y - start_y)
		var velocity_pixels_per_sec = travel_vector / final_duration
		entity.linear_velocity = velocity_pixels_per_sec
		
		var total_rotations = randf_range(1.0, 5.0) 
		var total_spin_amount = total_rotations * (PI * 2.0) * (1.0 if randi() % 2 == 0 else -1.0)
		entity.angular_velocity = total_spin_amount / final_duration
		
	else:
		var tween = entity.create_tween()
		tween.tween_property(entity, "position", Vector2(end_x, end_y), final_duration)
		tween.set_parallel(false)
		tween.tween_callback(entity.queue_free)
