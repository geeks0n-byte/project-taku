class_name BootIntroController
extends Node
## Splash → title intro sequence for the main menu.

signal completed
signal privacy_consent_requested

const BOOT_VOID_COLOR := GameConstants.BOOT_VOID_COLOR
const MENU_FADE_IN := 1.35
const SPLASH_HOLD := 0.55
const SPLASH_STARS_FADE := 1.65
const SPLASH_ASTEROID_APPROACH := 0.9
const SPLASH_ASTEROID_MAX_WAIT := 2.4
const SPLASH_POST_IMPACT_MIN := 0.4
const SPLASH_TILES_CLEAR_MAX_WAIT := 3.8
const SPLASH_TILES_EXPLODE_PAUSE := 0.32
const SPLASH_TO_TITLE_PAUSE := 0.35
const TITLE_LETTER_INTERVAL := 0.12
const TITLE_AFTER_LETTERS := 0.16
const TITLE_TILE_POP := 0.16
const TITLE_TILE_GAP := 0.1
const TITLE_AFTER_TILES := 0.18
const TITLE_SLIDE_DUR := 0.55
## Same horizontal insets as the settled TitleLabel in main_menu.tscn.
const TITLE_H_INSET := 24.0
const TITLE_CLUSTER_HEIGHT := 420.0
const TITLE_CLUSTER_REST_TOP := 0.0
## Midpoint of TitleLabel (offset 240–400) inside TitleCluster.
const TITLE_GLYPH_MID := 320.0
const TITLE_TILE_PIVOT := Vector2(14, 14)

var _menu: Control
var _boot_intro_active: bool = false
var _boot_intro_tween: Tween
var _button_fade_tween: Tween
var _splash_fade_tween: Tween
var _boot_intro_failsafe: SceneTreeTimer
var _splash_deferred_timer: SceneTreeTimer
var _boot_intro_waiting_on_consent: bool = false
var _boot_intro_privacy_gate_passed: bool = false
var _eat_intro_pointer: bool = false
var _splash_physics_impact_handled: bool = false
var _splash_impact_time_msec: int = 0
var _title_intro_started: bool = false
var _boot_splash_layer: CanvasLayer
var _boot_splash_void: ColorRect


func setup(menu: Control) -> void:
	_menu = menu


func ensure_splash_layer() -> void:
	if _boot_splash_layer != null:
		return
	_boot_splash_layer = CanvasLayer.new()
	_boot_splash_layer.name = "BootSplashLayer"
	_boot_splash_layer.layer = -1
	_menu.add_child(_boot_splash_layer)
	_boot_splash_void = ColorRect.new()
	_boot_splash_void.name = "VoidFill"
	_boot_splash_void.color = BOOT_VOID_COLOR
	_boot_splash_void.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boot_splash_layer.add_child(_boot_splash_void)
	layout_splash()
	_boot_splash_layer.visible = false


func begin(wait_for_consent: bool) -> void:
	_boot_intro_active = true
	_boot_intro_waiting_on_consent = wait_for_consent
	_prepare_boot_intro()
	call_deferred("_play_boot_intro")


func is_active() -> bool:
	return _boot_intro_active


func is_title_intro_started() -> bool:
	return _title_intro_started


func can_skip(needs_privacy: bool) -> bool:
	if not _boot_intro_active:
		return false
	if needs_privacy:
		return false
	if _boot_intro_privacy_gate_passed and not _title_intro_started:
		return false
	return true


func skip_to_end() -> void:
	_complete_boot_intro()
	_menu.process_mode = Node.PROCESS_MODE_INHERIT


func on_consent_resume() -> void:
	if not _boot_intro_active or _title_intro_started:
		return
	_cancel_boot_intro_failsafe()
	_cancel_splash_deferred_timer()
	var title_layer := _menu.get_node_or_null("TitleLayer") as CanvasLayer
	if title_layer:
		title_layer.visible = true
	if _menu.menu_center:
		_menu.menu_center.visible = true
	_menu._set_button_ui_alpha(0.0)
	var title := _title_label()
	if title:
		_layout_title_for_typewriter(title)
		title.visible_characters = 0
	_prepare_title_tile_pops()
	_place_title_cluster(_title_intro_center_top())
	_begin_title_intro_sequence()


func on_consent_accepted_begin() -> void:
	_boot_intro_privacy_gate_passed = true
	_eat_intro_pointer = true
	_boot_intro_waiting_on_consent = false


func layout_splash() -> void:
	if _boot_splash_void:
		_boot_splash_void.set_anchors_preset(Control.PRESET_FULL_RECT)
		_boot_splash_void.set_offsets_preset(Control.PRESET_FULL_RECT)


func get_eat_intro_pointer() -> bool:
	return _eat_intro_pointer


func set_eat_intro_pointer(value: bool) -> void:
	_eat_intro_pointer = value


func _title_label() -> Label:
	return _menu.get_node_or_null("TitleLayer/TitleHost/TitleCluster/TitleLabel") as Label


func _title_tiles() -> Array[CanvasItem]:
	var tiles: Array[CanvasItem] = []
	var host := _menu.get_node_or_null("TitleLayer/TitleHost/TitleCluster/TitleTileHost") as Control
	if host == null:
		return tiles
	for child in host.get_children():
		if child is CanvasItem:
			tiles.append(child)
	return tiles


func _title_cluster() -> Control:
	return _menu.get_node_or_null("TitleLayer/TitleHost/TitleCluster") as Control


func _title_intro_center_top() -> float:
	return _menu.get_viewport_rect().size.y * 0.5 - TITLE_GLYPH_MID


func _place_title_cluster(top: float) -> void:
	var cluster := _title_cluster()
	if cluster == null:
		return
	cluster.offset_top = top
	cluster.offset_bottom = top + TITLE_CLUSTER_HEIGHT


func _prepare_title_tile_pops() -> void:
	for tile in _title_tiles():
		var ctrl := tile as Control
		if ctrl == null:
			continue
		if not ctrl.has_meta("_rest_scale"):
			ctrl.set_meta("_rest_scale", ctrl.scale)
		if not ctrl.has_meta("_rest_offsets"):
			ctrl.set_meta("_rest_offsets", Vector4(
				ctrl.offset_left, ctrl.offset_top, ctrl.offset_right, ctrl.offset_bottom
			))
		var rest_scale: Vector2 = ctrl.get_meta("_rest_scale")
		var rest: Vector4 = ctrl.get_meta("_rest_offsets")
		var pivot := ctrl.size * 0.5
		if pivot.x < 1.0 or pivot.y < 1.0:
			pivot = TITLE_TILE_PIVOT
		ctrl.pivot_offset = pivot
		var dx := pivot.x * (rest_scale.x - 1.0)
		var dy := pivot.y * (rest_scale.y - 1.0)
		ctrl.offset_left = rest.x + dx
		ctrl.offset_top = rest.y + dy
		ctrl.offset_right = rest.z + dx
		ctrl.offset_bottom = rest.w + dy
		ctrl.scale = Vector2.ZERO
		ctrl.modulate.a = 1.0


func _restore_title_tile_pops() -> void:
	for tile in _title_tiles():
		var ctrl := tile as Control
		if ctrl == null:
			tile.modulate.a = 1.0
			continue
		ctrl.modulate.a = 1.0
		ctrl.pivot_offset = Vector2.ZERO
		if ctrl.has_meta("_rest_scale"):
			ctrl.scale = ctrl.get_meta("_rest_scale")
		else:
			ctrl.scale = Vector2(1.15, 1.15)
		if ctrl.has_meta("_rest_offsets"):
			var rest: Vector4 = ctrl.get_meta("_rest_offsets")
			ctrl.offset_left = rest.x
			ctrl.offset_top = rest.y
			ctrl.offset_right = rest.z
			ctrl.offset_bottom = rest.w


func _prepare_boot_intro() -> void:
	var title := _title_label()
	if title:
		_layout_title_for_typewriter(title)
		title.visible_characters = 0
	_prepare_title_tile_pops()
	_place_title_cluster(_title_intro_center_top())
	var title_host := _menu.get_node_or_null("TitleLayer/TitleHost") as CanvasItem
	if title_host:
		title_host.modulate.a = 0.0
	_menu._set_button_ui_alpha(0.0)
	_menu._set_boot_menu_input_enabled(false)
	if SpaceBackground and SpaceBackground.has_method("prepare_boot_intro"):
		SpaceBackground.prepare_boot_intro()
	_show_boot_splash()


func _layout_title_for_typewriter(title: Label) -> void:
	_restore_title_layout(title)
	var font := title.get_theme_font("font")
	var font_size := title.get_theme_font_size("font_size")
	var text_w := 0.0
	if font and font_size > 0:
		text_w = font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var cluster := title.get_parent() as Control
	var host_w := cluster.size.x if cluster and cluster.size.x > 1.0 else 1080.0
	var box_w := title.size.x
	if box_w <= 1.0:
		box_w = host_w - TITLE_H_INSET * 2.0
	var x := TITLE_H_INSET + (box_w - text_w) * 0.5
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title.anchor_right = 0.0
	title.offset_left = x
	title.offset_right = x + maxf(text_w, 1.0)
	title.offset_top = 240.0
	title.offset_bottom = 400.0


func _restore_title_layout(title: Label) -> void:
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.offset_left = 24.0
	title.offset_right = -24.0
	title.offset_top = 240.0
	title.offset_bottom = 400.0
	title.visible_characters = -1


func _show_boot_splash() -> void:
	ensure_splash_layer()
	layout_splash()
	if _boot_splash_void:
		_boot_splash_void.color = BOOT_VOID_COLOR
	if SpaceBackground and SpaceBackground.has_method("setup_boot_intro_tiles"):
		SpaceBackground.setup_boot_intro_tiles()
	if _boot_splash_layer:
		_boot_splash_layer.visible = true


func _hide_boot_splash() -> void:
	if _boot_splash_layer:
		_boot_splash_layer.visible = false
	if _boot_splash_void:
		_boot_splash_void.color = BOOT_VOID_COLOR
	layout_splash()


func _begin_splash_stars_fade(duration: float) -> void:
	if not _boot_intro_active:
		return
	if SpaceBackground and SpaceBackground.has_method("fade_boot_parallax_in"):
		SpaceBackground.fade_boot_parallax_in(duration)
	if _boot_splash_void == null:
		return
	if _splash_fade_tween and _splash_fade_tween.is_valid():
		_splash_fade_tween.kill()
	_splash_fade_tween = create_tween()
	_splash_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_splash_fade_tween.tween_property(_boot_splash_void, "color:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _launch_splash_physics_hit() -> void:
	if not _boot_intro_active:
		return
	if SpaceBackground == null:
		_on_boot_intro_impacted(_menu.get_viewport_rect().size * 0.5)
		return
	if SpaceBackground.has_signal("boot_intro_impacted"):
		if not SpaceBackground.boot_intro_impacted.is_connected(_on_boot_intro_impacted):
			SpaceBackground.boot_intro_impacted.connect(_on_boot_intro_impacted, CONNECT_ONE_SHOT)
	if SpaceBackground.has_method("spawn_boot_intro_asteroid"):
		SpaceBackground.spawn_boot_intro_asteroid(SPLASH_ASTEROID_APPROACH)
	var tree := get_tree()
	if tree:
		_cancel_splash_deferred_timer()
		_splash_deferred_timer = tree.create_timer(SPLASH_ASTEROID_MAX_WAIT, true, false, true)
		_splash_deferred_timer.timeout.connect(_on_boot_intro_impacted_failsafe)


func _on_boot_intro_impacted_failsafe() -> void:
	_on_boot_intro_impacted(_menu.get_viewport_rect().size * 0.5)


func _on_boot_intro_impacted(_impact_pos: Vector2) -> void:
	if not _boot_intro_active or _splash_physics_impact_handled:
		return
	_splash_physics_impact_handled = true
	_splash_impact_time_msec = Time.get_ticks_msec()
	if UiSfx:
		UiSfx.play_title_tile_pop(0)
	_wait_for_splash_tiles_cleared()


func _wait_for_splash_tiles_cleared() -> void:
	if not _boot_intro_active:
		return
	var tree := get_tree()
	var elapsed := float(Time.get_ticks_msec() - _splash_impact_time_msec) / 1000.0
	var tiles_clear := true
	if SpaceBackground and SpaceBackground.has_method("boot_intro_tiles_offscreen"):
		tiles_clear = SpaceBackground.boot_intro_tiles_offscreen()
	if elapsed >= SPLASH_POST_IMPACT_MIN and tiles_clear:
		_continue_after_splash_tiles_cleared()
		return
	if elapsed >= SPLASH_TILES_CLEAR_MAX_WAIT:
		if not tiles_clear and SpaceBackground and SpaceBackground.has_method("explode_boot_intro_tiles_remaining"):
			SpaceBackground.explode_boot_intro_tiles_remaining()
			if UiSfx:
				UiSfx.play_title_tile_pop(1)
			if tree:
				_cancel_splash_deferred_timer()
				_splash_deferred_timer = tree.create_timer(
					SPLASH_TILES_EXPLODE_PAUSE, true, false, true
				)
				_splash_deferred_timer.timeout.connect(_continue_after_splash_tiles_cleared)
				return
		_continue_after_splash_tiles_cleared()
		return
	if tree == null:
		return
	_cancel_splash_deferred_timer()
	_splash_deferred_timer = tree.create_timer(0.05, true, false, true)
	_splash_deferred_timer.timeout.connect(_wait_for_splash_tiles_cleared)


func _cancel_splash_deferred_timer() -> void:
	if _splash_deferred_timer == null:
		return
	if _splash_deferred_timer.timeout.is_connected(_wait_for_splash_tiles_cleared):
		_splash_deferred_timer.timeout.disconnect(_wait_for_splash_tiles_cleared)
	if _splash_deferred_timer.timeout.is_connected(_continue_after_splash_tiles_cleared):
		_splash_deferred_timer.timeout.disconnect(_continue_after_splash_tiles_cleared)
	if _splash_deferred_timer.timeout.is_connected(_on_boot_intro_impacted_failsafe):
		_splash_deferred_timer.timeout.disconnect(_on_boot_intro_impacted_failsafe)
	_splash_deferred_timer = null


func _continue_after_splash_tiles_cleared() -> void:
	if not _boot_intro_active:
		return
	if _boot_intro_waiting_on_consent and _menu.needs_privacy_consent():
		_cancel_boot_intro_failsafe()
		_cancel_splash_deferred_timer()
		privacy_consent_requested.emit()
		return
	_begin_title_intro_sequence()


func _begin_title_intro_sequence() -> void:
	if not _boot_intro_active:
		return
	if _title_intro_started:
		return
	_title_intro_started = true
	var title := _title_label()
	if _boot_intro_tween and _boot_intro_tween.is_valid():
		_boot_intro_tween.kill()
	_boot_intro_tween = create_tween()
	_boot_intro_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_boot_intro_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_boot_intro_tween.tween_callback(_splash_handoff_to_title)
	_boot_intro_tween.tween_interval(SPLASH_TO_TITLE_PAUSE)
	var letter_count := title.text.length() if title else 0
	for i in range(1, letter_count + 1):
		var count := i
		_boot_intro_tween.tween_callback(_reveal_title_letter.bind(count))
		_boot_intro_tween.tween_interval(TITLE_LETTER_INTERVAL)
	_boot_intro_tween.tween_interval(TITLE_AFTER_LETTERS)
	var tile_i := 0
	for tile in _title_tiles():
		var ctrl := tile as Control
		if ctrl == null:
			continue
		var pop_i := tile_i
		tile_i += 1
		var rest_scale: Vector2 = ctrl.get_meta("_rest_scale", Vector2(1.15, 1.15))
		_boot_intro_tween.tween_callback(_play_title_tile_pop_sfx.bind(pop_i))
		_boot_intro_tween.tween_property(ctrl, "scale", rest_scale, TITLE_TILE_POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_boot_intro_tween.tween_interval(TITLE_TILE_GAP)
	_boot_intro_tween.tween_interval(TITLE_AFTER_TILES)
	_boot_intro_tween.tween_callback(_on_title_slide_start)
	var cluster := _title_cluster()
	if cluster:
		_boot_intro_tween.parallel().tween_property(cluster, "offset_top", TITLE_CLUSTER_REST_TOP, TITLE_SLIDE_DUR).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_boot_intro_tween.parallel().tween_property(
			cluster, "offset_bottom", TITLE_CLUSTER_REST_TOP + TITLE_CLUSTER_HEIGHT, TITLE_SLIDE_DUR
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_boot_intro_tween.tween_callback(_fade_buttons_after_title)
	_schedule_boot_intro_title_failsafe(letter_count)


func _splash_handoff_to_title() -> void:
	if not _boot_intro_active:
		return
	_hide_boot_splash()
	if SpaceBackground and SpaceBackground.has_method("finish_boot_intro"):
		SpaceBackground.finish_boot_intro()
	var title_host := _menu.get_node_or_null("TitleLayer/TitleHost") as CanvasItem
	if title_host:
		title_host.modulate.a = 1.0


func _cancel_boot_intro_failsafe() -> void:
	if _boot_intro_failsafe == null:
		return
	if _boot_intro_failsafe.timeout.is_connected(_complete_boot_intro):
		_boot_intro_failsafe.timeout.disconnect(_complete_boot_intro)
	if _boot_intro_failsafe.timeout.is_connected(_on_boot_intro_splash_failsafe):
		_boot_intro_failsafe.timeout.disconnect(_on_boot_intro_splash_failsafe)
	_boot_intro_failsafe = null


func _schedule_boot_intro_splash_failsafe() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var intro_len := SPLASH_HOLD + SPLASH_STARS_FADE + SPLASH_ASTEROID_MAX_WAIT
	intro_len += SPLASH_POST_IMPACT_MIN + SPLASH_TILES_CLEAR_MAX_WAIT
	intro_len += SPLASH_TILES_EXPLODE_PAUSE + 0.5
	_cancel_boot_intro_failsafe()
	var failsafe := tree.create_timer(intro_len, true, false, true)
	_boot_intro_failsafe = failsafe
	failsafe.timeout.connect(_on_boot_intro_splash_failsafe)


func _on_boot_intro_splash_failsafe() -> void:
	if not _boot_intro_active:
		return
	if not _splash_physics_impact_handled:
		_on_boot_intro_impacted(_menu.get_viewport_rect().size * 0.5)
		return
	_continue_after_splash_tiles_cleared()


func _schedule_boot_intro_title_failsafe(letter_count: int) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var intro_len := SPLASH_TO_TITLE_PAUSE
	intro_len += float(letter_count) * TITLE_LETTER_INTERVAL + TITLE_AFTER_LETTERS
	intro_len += float(_title_tiles().size()) * (TITLE_TILE_POP + TITLE_TILE_GAP)
	intro_len += TITLE_AFTER_TILES + TITLE_SLIDE_DUR + MENU_FADE_IN + 0.6
	var failsafe := tree.create_timer(intro_len, true, false, true)
	_cancel_boot_intro_failsafe()
	_boot_intro_failsafe = failsafe
	failsafe.timeout.connect(_complete_boot_intro)


func _play_boot_intro() -> void:
	var title := _title_label()
	if title:
		_layout_title_for_typewriter(title)
		title.visible_characters = 0
	_prepare_title_tile_pops()
	_place_title_cluster(_title_intro_center_top())
	_splash_physics_impact_handled = false
	_title_intro_started = false
	_splash_impact_time_msec = 0
	if _boot_intro_tween and _boot_intro_tween.is_valid():
		_boot_intro_tween.kill()
	_boot_intro_tween = create_tween()
	_boot_intro_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_boot_intro_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_boot_intro_tween.tween_interval(SPLASH_HOLD)
	_boot_intro_tween.tween_callback(_begin_splash_stars_fade.bind(SPLASH_STARS_FADE))
	_boot_intro_tween.tween_interval(SPLASH_STARS_FADE)
	_boot_intro_tween.tween_callback(_launch_splash_physics_hit)
	_schedule_boot_intro_splash_failsafe()


func _reveal_title_letter(count: int) -> void:
	if not _boot_intro_active:
		return
	var title := _title_label()
	if is_instance_valid(title):
		title.visible_characters = count
	if UiSfx:
		UiSfx.play_title_letter(count - 1)


func _play_title_tile_pop_sfx(index: int) -> void:
	if not _boot_intro_active:
		return
	if UiSfx:
		UiSfx.play_title_tile_pop(index)


func _on_title_slide_start() -> void:
	if not _boot_intro_active:
		return
	var title := _title_label()
	if is_instance_valid(title):
		_restore_title_layout(title)
	if UiSfx:
		UiSfx.play_title_slide()


func _fade_buttons_after_title() -> void:
	if not _boot_intro_active:
		return
	_menu.set_menu_chrome_visible(true)
	var buttons: Array[CanvasItem] = _menu._button_fade_targets()
	if buttons.is_empty():
		_complete_boot_intro()
		return
	_menu._set_button_ui_alpha(0.0)
	if _button_fade_tween and _button_fade_tween.is_valid():
		_button_fade_tween.kill()
	_button_fade_tween = create_tween()
	_button_fade_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_button_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_button_fade_tween.set_parallel(true)
	for node in buttons:
		_button_fade_tween.tween_property(node, "modulate:a", 1.0, MENU_FADE_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_button_fade_tween.chain().tween_callback(_complete_boot_intro)


func _complete_boot_intro() -> void:
	if not _boot_intro_active and _boot_intro_tween == null and _button_fade_tween == null:
		return
	_boot_intro_active = false
	_cancel_splash_deferred_timer()
	_cancel_boot_intro_failsafe()
	if _boot_intro_tween and _boot_intro_tween.is_valid():
		_boot_intro_tween.kill()
	_boot_intro_tween = null
	if _button_fade_tween and _button_fade_tween.is_valid():
		_button_fade_tween.kill()
	_button_fade_tween = null
	if _splash_fade_tween and _splash_fade_tween.is_valid():
		_splash_fade_tween.kill()
	_splash_fade_tween = null
	if SpaceBackground and SpaceBackground.has_signal("boot_intro_impacted"):
		if SpaceBackground.boot_intro_impacted.is_connected(_on_boot_intro_impacted):
			SpaceBackground.boot_intro_impacted.disconnect(_on_boot_intro_impacted)
	_hide_boot_splash()
	if SpaceBackground and SpaceBackground.has_method("finish_boot_intro"):
		SpaceBackground.finish_boot_intro()
	var title := _title_label()
	if title:
		_restore_title_layout(title)
	_restore_title_tile_pops()
	_place_title_cluster(TITLE_CLUSTER_REST_TOP)
	var title_host := _menu.get_node_or_null("TitleLayer/TitleHost") as CanvasItem
	if title_host:
		title_host.modulate.a = 1.0
	_menu._set_button_ui_alpha(1.0)
	_title_intro_started = false
	_splash_physics_impact_handled = false
	_menu.set_menu_chrome_visible(true)
	_menu._apply_debug_tools_visibility()
	_menu.process_mode = Node.PROCESS_MODE_INHERIT
	if not _eat_intro_pointer:
		_menu._set_boot_menu_input_enabled(true)
	completed.emit()
