class_name SpaceBackgroundBootIntro
extends RefCounted

const BOOT_INTRO_COLLISION_LAYER := 8
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

var _host: ParallaxBackground
var _parallax: SpaceBackgroundParallax
var _pool: SpaceBackgroundAsteroidPool
var _fx: SpaceBackgroundFx
var _on_impacted: Callable

var _boot_intro_asteroid: RigidBody2D = null
var _boot_intro_root: Node2D = null
var _boot_intro_tiles: Array[RigidBody2D] = []
var _boot_intro_active: bool = false
var _boot_intro_phys_mat: PhysicsMaterial = null


func setup(
	host: ParallaxBackground,
	parallax: SpaceBackgroundParallax,
	pool: SpaceBackgroundAsteroidPool,
	fx: SpaceBackgroundFx,
	on_impacted: Callable
) -> void:
	_host = host
	_parallax = parallax
	_pool = pool
	_fx = fx
	_on_impacted = on_impacted


func boot_intro_asteroid() -> RigidBody2D:
	return _boot_intro_asteroid


func clear_boot_intro_asteroid_ref() -> void:
	_boot_intro_asteroid = null


func setup_boot_intro_tiles() -> void:
	dismiss_boot_intro()
	_boot_intro_active = true
	_pool.init_pool_if_needed()
	var root := _ensure_boot_intro_root()
	var layout := _boot_intro_icon_layout(_parallax.live_visible_rect())
	var tile_px: float = layout["tile_px"]
	var centers: Array = layout["centers"]
	for i in BOOT_INTRO_TILE_PATHS.size():
		var center: Vector2 = centers[i]
		var tile := _make_boot_intro_tile(BOOT_INTRO_TILE_PATHS[i], center, tile_px)
		root.add_child(tile)
		_boot_intro_tiles.append(tile)


func spawn_boot_intro_asteroid(travel_duration: float) -> RigidBody2D:
	dismiss_boot_intro_asteroid()
	if _fx.tex_asteroids.is_empty():
		_fx.load_assets()
	if _fx.tex_asteroids.is_empty():
		return null
	if _boot_intro_tiles.is_empty():
		setup_boot_intro_tiles()
	var layout := _boot_intro_icon_layout(_parallax.live_visible_rect())
	var tile_px: float = layout["tile_px"]
	var target: Vector2 = layout["cluster_center"]
	var tex: Texture2D = _fx.tex_asteroids.pick_random()
	if tex == null:
		return null
	var size := Vector2.ONE * tile_px
	var rb := _pool.acquire()
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

	var viewport_size := _parallax.live_viewport_size()
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
	_unfreeze_boot_intro_tiles()
	_boot_intro_asteroid = rb
	return rb


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
	var view := _parallax.live_visible_rect()
	for tile in _boot_intro_tiles:
		if not is_instance_valid(tile):
			continue
		if not _boot_intro_body_offscreen(tile, view):
			return false
	return true


func explode_boot_intro_tiles_remaining() -> void:
	var view := _parallax.live_visible_rect()
	var parent := _boot_intro_root if _boot_intro_root else _fx.fg_asteroids()
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


func play_asteroid_impact_burst(global_pos: Vector2) -> void:
	var parent := _boot_intro_root if _boot_intro_root else _fx.fg_asteroids()
	if parent == null:
		parent = _parallax.dyn_layer_asteroids
	if parent:
		_fx.spawn_asteroid_impact_burst(global_pos, parent)


func dismiss_boot_intro_asteroid() -> void:
	if not is_instance_valid(_boot_intro_asteroid):
		_boot_intro_asteroid = null
		return
	_pool.release(_boot_intro_asteroid)
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


func relayout_tiles_if_idle() -> void:
	if not _boot_intro_active or _boot_intro_tiles.is_empty():
		return
	for tile in _boot_intro_tiles:
		if is_instance_valid(tile) and not tile.freeze:
			return
	var layout := _boot_intro_icon_layout(_parallax.live_visible_rect())
	var centers: Array = layout["centers"]
	var tile_px: float = layout["tile_px"]
	for i in _boot_intro_tiles.size():
		if i >= centers.size():
			break
		var tile := _boot_intro_tiles[i]
		if not is_instance_valid(tile):
			continue
		tile.position = centers[i]
		var sprite := tile.get_node_or_null("Sprite") as Sprite2D
		if sprite != null and sprite.texture != null:
			var tex_w := float(sprite.texture.get_width())
			sprite.scale = Vector2.ONE * GameConstants.boot_splash_tile_sprite_scale(tile_px, tex_w)
		var col := tile.get_node_or_null("Collision") as CollisionShape2D
		if col != null and col.shape is RectangleShape2D:
			(col.shape as RectangleShape2D).size = Vector2.ONE * tile_px * 0.88


func _boot_intro_icon_layout(view_rect: Rect2) -> Dictionary:
	return GameConstants.boot_splash_icon_layout(view_rect)


func _boot_intro_ref_tile_px() -> float:
	return GameConstants.boot_splash_ref_tile_px(_parallax.live_viewport_size().x)


func _ensure_boot_intro_root() -> Node2D:
	if _boot_intro_root != null and is_instance_valid(_boot_intro_root):
		return _boot_intro_root
	_fx.ensure_foreground_layer()
	_boot_intro_root = Node2D.new()
	_boot_intro_root.name = "BootIntroPhysics"
	_fx.fg_asteroids().add_child(_boot_intro_root)
	return _boot_intro_root


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


func _unfreeze_boot_intro_tiles() -> void:
	for tile in _boot_intro_tiles:
		if is_instance_valid(tile):
			tile.freeze = false
			tile.linear_velocity = Vector2.ZERO
			tile.angular_velocity = 0.0


func _apply_boot_intro_scatter(asteroid: RigidBody2D) -> void:
	var approach_vel := asteroid.linear_velocity
	var layout := _boot_intro_icon_layout(_parallax.live_visible_rect())
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
	if approach_vel.length_squared() > 1.0:
		asteroid.linear_velocity = approach_vel * 0.96
	var spin_cap := BOOT_INTRO_ASTEROID_SPIN_MAX * 1.15
	asteroid.angular_velocity = clampf(asteroid.angular_velocity, -spin_cap, spin_cap)


func _on_boot_intro_asteroid_collided(body: Node, asteroid: RigidBody2D) -> void:
	if not (body is RigidBody2D and body.get_meta("boot_intro_tile", false)):
		return
	var impact_pos := (asteroid.global_position + (body as Node2D).global_position) * 0.5
	var burst_parent := _boot_intro_root if _boot_intro_root else _fx.fg_asteroids()
	_fx.spawn_asteroid_impact_burst(impact_pos, burst_parent)
	if asteroid.get_meta("boot_intro_impact_done", false):
		return
	asteroid.set_meta("boot_intro_impact_done", true)
	_apply_boot_intro_scatter(asteroid)
	if _on_impacted.is_valid():
		_on_impacted.call(impact_pos)


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
	_host.get_tree().create_timer(1.45).timeout.connect(vfx.queue_free)


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
	_host.get_tree().create_timer(1.2).timeout.connect(vfx.queue_free)


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
