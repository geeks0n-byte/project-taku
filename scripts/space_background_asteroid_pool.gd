class_name SpaceBackgroundAsteroidPool
extends RefCounted

const ASTEROID_POOL_SIZE := 16
const ASTEROID_OFFSCREEN_MARGIN := 64.0
const BG_COLLISION_LAYER := 2
const FG_COLLISION_LAYER := 4

var _host: Node
var _boot_intro: SpaceBackgroundBootIntro
var _parallax: SpaceBackgroundParallax
var _fx: SpaceBackgroundFx
var max_active_asteroids: int = 16

var _asteroid_pool: Array[RigidBody2D] = []
var _asteroid_pool_root: Node2D
var _active_asteroid_count: int = 0
var _asteroid_phys_mat: PhysicsMaterial
var _pool_initialized: bool = false


func setup(
	host: Node,
	parallax: SpaceBackgroundParallax,
	fx: SpaceBackgroundFx,
	max_active: int
) -> void:
	_host = host
	_parallax = parallax
	_fx = fx
	max_active_asteroids = max_active


func bind_boot_intro(boot_intro: SpaceBackgroundBootIntro) -> void:
	_boot_intro = boot_intro


func configure_collision_layer(rb: RigidBody2D, foreground: bool) -> void:
	var layer := FG_COLLISION_LAYER if foreground else BG_COLLISION_LAYER
	rb.collision_layer = layer
	rb.collision_mask = layer


func init_pool_if_needed() -> void:
	if not _pool_initialized:
		init_pool()


func init_pool() -> void:
	_asteroid_pool_root = Node2D.new()
	_asteroid_pool_root.name = "AsteroidPool"
	_asteroid_pool_root.visible = false
	_host.add_child(_asteroid_pool_root)
	_asteroid_phys_mat = PhysicsMaterial.new()
	_asteroid_phys_mat.bounce = 0.8
	_asteroid_phys_mat.friction = 0.5
	for _i in ASTEROID_POOL_SIZE:
		_asteroid_pool.append(_make_pooled_asteroid())
	_pool_initialized = true


func acquire() -> RigidBody2D:
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


func release(rb: RigidBody2D) -> void:
	if not is_instance_valid(rb):
		return
	if _boot_intro and rb == _boot_intro.boot_intro_asteroid():
		_boot_intro.clear_boot_intro_asteroid_ref()
	if rb.has_meta("boot_intro_asteroid"):
		rb.remove_meta("boot_intro_asteroid")
	configure_collision_layer(rb, false)
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


func release_offscreen_asteroids() -> void:
	if _active_asteroid_count <= 0:
		return
	var view := _host.get_viewport().get_visible_rect()
	for layer_node in [_parallax.dyn_layer_asteroids, _fx.fg_asteroids()]:
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
				release(rb)


func release_all_from_layers() -> void:
	for layer_node in [_parallax.dyn_layer_asteroids, _fx.fg_asteroids()]:
		if layer_node == null:
			continue
		for child in layer_node.get_children():
			if child is RigidBody2D and child.has_meta("pooled_asteroid"):
				release(child as RigidBody2D)


func _make_pooled_asteroid() -> RigidBody2D:
	var rb := RigidBody2D.new()
	rb.set_meta("pooled_asteroid", true)
	rb.gravity_scale = 0.0
	rb.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	rb.linear_damp = 0.0
	rb.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	rb.angular_damp = 0.0
	rb.physics_material_override = _asteroid_phys_mat
	configure_collision_layer(rb, false)
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


func _release_oldest_offscreen_asteroid() -> void:
	var view := _host.get_viewport().get_visible_rect()
	for layer_node in [_parallax.dyn_layer_asteroids, _fx.fg_asteroids()]:
		if layer_node == null:
			continue
		for child in layer_node.get_children():
			if child is RigidBody2D and child.has_meta("pooled_asteroid"):
				var rb := child as RigidBody2D
				if _asteroid_is_fully_offscreen(rb, view):
					release(rb)
					return


func _release_oldest_active_asteroid() -> void:
	var oldest: RigidBody2D = null
	var oldest_stamp: int = Time.get_ticks_msec()
	for layer_node in [_parallax.dyn_layer_asteroids, _fx.fg_asteroids()]:
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
		release(oldest)


func _sync_active_asteroid_count() -> void:
	var live_count := 0
	for layer_node in [_parallax.dyn_layer_asteroids, _fx.fg_asteroids()]:
		if layer_node == null:
			continue
		for child in layer_node.get_children():
			if child is RigidBody2D and child.has_meta("pooled_asteroid"):
				live_count += 1
	_active_asteroid_count = live_count


func _asteroid_visual_radius(rb: RigidBody2D) -> float:
	var col := rb.get_node_or_null("Collision") as CollisionShape2D
	if col and col.shape is CircleShape2D:
		return (col.shape as CircleShape2D).radius * maxf(absf(rb.scale.x), absf(rb.scale.y))
	return 48.0


func _asteroid_is_fully_offscreen(rb: RigidBody2D, view: Rect2) -> bool:
	var radius := _asteroid_visual_radius(rb) + ASTEROID_OFFSCREEN_MARGIN
	var pos := rb.global_position
	return (
		pos.x + radius < view.position.x
		or pos.x - radius > view.position.x + view.size.x
		or pos.y + radius < view.position.y
		or pos.y - radius > view.position.y + view.size.y
	)


func _asteroid_intersects_view(rb: RigidBody2D, view: Rect2) -> bool:
	var radius := _asteroid_visual_radius(rb)
	var pos := rb.global_position
	return not (
		pos.x + radius < view.position.x
		or pos.x - radius > view.position.x + view.size.x
		or pos.y + radius < view.position.y
		or pos.y - radius > view.position.y + view.size.y
	)
