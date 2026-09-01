extends ParallaxBackground

signal boot_intro_impacted(impact_position: Vector2)

const _ParallaxScript := preload("res://scripts/space_background_parallax.gd")
const _StaticBakeScript := preload("res://scripts/space_background_static_bake.gd")
const _PoolScript := preload("res://scripts/space_background_asteroid_pool.gd")
const _FxScript := preload("res://scripts/space_background_fx.gd")
const _BootIntroScript := preload("res://scripts/space_background_boot_intro.gd")

@export var base_scroll_speed: Vector2 = Vector2(-15, -5)
@export var event_spawn_interval: Vector2 = Vector2(0.2, 12.0)
@export var foreground_event_chance: float = 0.38
@export var max_active_asteroids: int = 16

var _static_mode: bool = false
var _boot_intro_prepared: bool = false

var _parallax: SpaceBackgroundParallax
var _static_bake: SpaceBackgroundStaticBake
var _pool: SpaceBackgroundAsteroidPool
var _fx: SpaceBackgroundFx
var _boot_intro: SpaceBackgroundBootIntro


func _ready() -> void:
	layer = -2
	var bg_seed := randi()
	_parallax = _ParallaxScript.new()
	_parallax.setup(self, bg_seed)
	_pool = _PoolScript.new()
	_fx = _FxScript.new()
	_boot_intro = _BootIntroScript.new()
	_static_bake = _StaticBakeScript.new()
	_pool.setup(self, _parallax, _fx, max_active_asteroids)
	_fx.setup(self, _parallax, _pool, event_spawn_interval, foreground_event_chance, _is_static_mode)
	_boot_intro.setup(self, _parallax, _pool, _fx, _emit_boot_intro_impacted)
	_pool.bind_boot_intro(_boot_intro)
	_static_bake.setup(self, _parallax)

	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_parallax.build_layers()
	_fx.build_foreground_layer()
	_fx.load_assets()
	_pool.init_pool()
	_fx.setup_timer("event", event_spawn_interval, _fx.on_event_timeout)
	call_deferred("_on_viewport_size_changed")
	var want_static := SaveManager.background_static if SaveManager else false
	set_static_mode(want_static)


func _is_static_mode() -> bool:
	return _static_mode


func _emit_boot_intro_impacted(impact_position: Vector2) -> void:
	boot_intro_impacted.emit(impact_position)


func set_foreground_events_enabled(enabled: bool) -> void:
	_fx.set_foreground_events_enabled(enabled)


func prepare_boot_intro() -> void:
	_boot_intro_prepared = true
	set_foreground_events_enabled(false)
	_fx.stop_events_and_fx()
	_parallax.kill_twinkle()
	if _static_mode and _static_bake.static_rect():
		_static_bake.static_rect().modulate.a = 0.0
	else:
		for p_layer in _parallax.parallax_layer_nodes():
			if is_instance_valid(p_layer):
				p_layer.modulate.a = 0.0


func fade_boot_parallax_in(duration: float) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if _static_mode and _static_bake.static_rect():
		tween.tween_property(_static_bake.static_rect(), "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		tween.set_parallel(true)
		for p_layer in _parallax.parallax_layer_nodes():
			if is_instance_valid(p_layer):
				tween.tween_property(p_layer, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_boot_parallax_fade_finished)


func _on_boot_parallax_fade_finished() -> void:
	if _boot_intro_prepared and not _static_mode:
		_parallax.start_twinkle_on_mid_layers()
	_boot_intro_prepared = false


func finish_boot_intro() -> void:
	_boot_intro.dismiss_boot_intro()
	_boot_intro_prepared = false
	set_foreground_events_enabled(true)
	if _static_mode:
		if _static_bake.static_rect():
			_static_bake.static_rect().modulate.a = 1.0
		return
	for p_layer in _parallax.parallax_layer_nodes():
		if is_instance_valid(p_layer):
			p_layer.modulate.a = 1.0
	if _parallax.twinkle_tween() == null:
		_parallax.start_twinkle_on_mid_layers()
	_fx.restart_timer("event")


func setup_boot_intro_tiles() -> void:
	_boot_intro.setup_boot_intro_tiles()


func spawn_boot_intro_asteroid(travel_duration: float) -> RigidBody2D:
	return _boot_intro.spawn_boot_intro_asteroid(travel_duration)


func get_boot_intro_asteroid() -> RigidBody2D:
	return _boot_intro.get_boot_intro_asteroid()


func get_boot_intro_asteroid_velocity() -> Vector2:
	return _boot_intro.get_boot_intro_asteroid_velocity()


func boot_intro_tiles_offscreen() -> bool:
	return _boot_intro.boot_intro_tiles_offscreen()


func explode_boot_intro_tiles_remaining() -> void:
	_boot_intro.explode_boot_intro_tiles_remaining()


func play_asteroid_impact_burst(global_pos: Vector2) -> void:
	_boot_intro.play_asteroid_impact_burst(global_pos)


func dismiss_boot_intro() -> void:
	_boot_intro.dismiss_boot_intro()


func set_static_mode(is_static: bool) -> void:
	_static_mode = is_static
	set_process(not is_static)
	if _static_bake == null or _fx == null:
		return
	if is_static:
		_fx.stop_events_and_fx()
		_static_bake.show_composite()
	else:
		_static_bake.hide_composite()
		_fx.restart_timer("event")


func _on_viewport_size_changed() -> void:
	_parallax.on_viewport_size_changed(
		_static_mode,
		_static_bake.static_rect(),
		_boot_intro.relayout_tiles_if_idle
	)


func _process(delta: float) -> void:
	if _static_mode:
		return
	scroll_offset += base_scroll_speed * delta
	_pool.release_offscreen_asteroids()


static func phone_layer_scale(tex_size: Vector2, phone_viewport: Vector2 = Vector2(1080.0, 1920.0)) -> float:
	return SpaceBackgroundParallax.phone_layer_scale(tex_size, phone_viewport)


static func phone_cover_size() -> Vector2:
	return SpaceBackgroundParallax.phone_cover_size()


static func fx_spawn_start_x(viewport_width: float, max_dim: float, margin: float = 50.0) -> float:
	return SpaceBackgroundParallax.fx_spawn_start_x(viewport_width, max_dim, margin)


func debug_spawn_shooting_star() -> void:
	_fx.debug_spawn_shooting_star()


func debug_spawn_comet() -> void:
	_fx.debug_spawn_comet()


func debug_spawn_asteroid() -> void:
	_fx.debug_spawn_asteroid()


func debug_spawn_asteroid_cloud() -> void:
	_fx.debug_spawn_asteroid_cloud()


func debug_spawn_meteor_shower() -> void:
	_fx.debug_spawn_meteor_shower()
