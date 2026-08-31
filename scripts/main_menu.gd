extends Control
## Main menu: boot intro, campaign/tutorial entry, how-to-play, achievements, options, and credits.

@export var show_debug_tools: bool = false

@onready var menu_center = $UILayer/CenterContainer
@onready var start_btn = $UILayer/CenterContainer/VBoxContainer/StartButton
@onready var tutorial_btn = $UILayer/CenterContainer/VBoxContainer/TutorialButton
@onready var levels_btn = $UILayer/CenterContainer/VBoxContainer/LevelSelectButton
@onready var how_to_play_btn = $UILayer/CenterContainer/VBoxContainer/HowToPlayButton
@onready var achievements_btn = $UILayer/CenterContainer/VBoxContainer/AchievementsButton
@onready var options_btn = $UILayer/CenterContainer/VBoxContainer/OptionsButton
@onready var credits_btn = $UILayer/CenterContainer/VBoxContainer/CreditsButton
@onready var editor_btn = $UILayer/CenterContainer/VBoxContainer/EditorButton
@onready var debug_bar = $UILayer/DebugBar
@onready var debug_star_btn = $UILayer/DebugBar/DebugStarButton
@onready var debug_asteroid_btn = $UILayer/DebugBar/DebugAsteroidButton
@onready var debug_asteroid_cloud_btn = $UILayer/DebugBar/DebugAsteroidCloudButton
@onready var debug_comet_btn = $UILayer/DebugBar/DebugCometButton
@onready var debug_comet_shower_btn = $UILayer/DebugBar/DebugCometShowerButton

const _FX_STAR := preload("res://resources/background/fx_shooting_star.svg")
const _FX_AST_1 := preload("res://resources/background/fx_asteroid_1.svg")
const _FX_AST_2 := preload("res://resources/background/fx_asteroid_2.svg")
const _FX_AST_3 := preload("res://resources/background/fx_asteroid_3.svg")
const _FX_COMET_1 := preload("res://resources/background/fx_comet_1.svg")
const _FX_COMET_2 := preload("res://resources/background/fx_comet_2.svg")
const _FX_COMET_3 := preload("res://resources/background/fx_comet_3.svg")
const _DEBUG_BTN_SIZE := Vector2(96, 96)

@onready var options_menu = $UILayer/OptionsMenu
@onready var overlay_blocker = $OverlayLayer/OverlayBlocker
@onready var credits_panel = $OverlayLayer/OverlayBlocker/CreditsPanel
@onready var credits_version_label: Label = $OverlayLayer/OverlayBlocker/CreditsPanel/VersionLabel
@onready var close_credits_btn = $OverlayLayer/OverlayBlocker/CloseCreditsButton
@onready var _htp_host: Control = $OverlayLayer/HowToPlayHost
@onready var _htp_header: Label = $OverlayLayer/HowToPlayHost/HowToPlayPageHeader
@onready var _htp_panel: Control = $OverlayLayer/HowToPlayHost/HowToPlayPanel
@onready var _htp_nav: HBoxContainer = $OverlayLayer/HowToPlayHost/NavRow
@onready var _htp_rules: RichTextLabel = $OverlayLayer/HowToPlayHost/HowToPlayPanel/RulesLabel
@onready var _htp_prev: Button = $OverlayLayer/HowToPlayHost/NavRow/PrevSlot/PrevButton
@onready var _htp_close: Button = $OverlayLayer/HowToPlayHost/CloseButton
@onready var _htp_next: Button = $OverlayLayer/HowToPlayHost/NavRow/NextSlot/NextButton
@onready var _tutorial_intro_blocker: ColorRect = $OverlayLayer/TutorialIntroBlocker
@onready var _tutorial_intro_label: Label = (
	$OverlayLayer/TutorialIntroBlocker/CenterContainer/Panel/VBoxContainer/PromptLabel
)
@onready var _tutorial_intro_yes: Button = (
	$OverlayLayer/TutorialIntroBlocker/CenterContainer/Panel/VBoxContainer/HBoxContainer/YesButton
)
@onready var _tutorial_intro_no: Button = (
	$OverlayLayer/TutorialIntroBlocker/CenterContainer/Panel/VBoxContainer/HBoxContainer/NoButton
)

const TITLE_FONT_SIZE := 96
const TITLE_OUTLINE := 14
const MENU_BTN_FONT := 64
const MENU_BTN_OUTLINE := GameConstants.MENU_TEXT_OUTLINE
const MENU_BADGE_MARGIN := 10.0
const MENU_BADGE_TEXT_GAP := -6.0
const _PIXEL_MONO_TEXT_SCRIPT: Script = preload("res://scripts/pixel_mono_text.gd")
const CREDITS_BODY_SIZE := 48
const CREDITS_HEADER_SIZE := 42
const CREDITS_NAME_SIZE := 34
const CREDITS_HEADER_LOCALE_SIZE := 52
const CREDITS_NAME_LOCALE_SIZE := 42
const MENU_FADE_IN := 1.35
const BOOT_VOID_COLOR := GameConstants.BOOT_VOID_COLOR
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

var _htp_page: int = 0
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

# Instance of consent_popup.tscn. Kept as a reference so we can check
# its visibility for the back-button handler.
var _consent_blocker: ColorRect

# Dev mode is unlocked by holding the version label in credits for _VERSION_HOLD_SEC seconds.
# This gives the developer access to debug tools in production builds without exposing them
# to players, and without storing the flag in the save file.
var _version_hold_active: bool = false
var _version_hold_elapsed: float = 0.0
const _VERSION_HOLD_SEC := 3.0
var _menu_badge_host: Control = null
var _ach_badge_panel: Panel = null
var _levels_badge_panel: Panel = null

# Wires menu buttons, overlays, ads, and optionally starts the boot intro.
func _ready() -> void:
	_apply_debug_tools_visibility()
	_apply_editor_button_label()
	_refresh_start_button_label()
	_fit_menu_buttons()
	HudLayout.apply_locale_fonts_to_tree(self)
	_setup_title_under_fx()
	_build_boot_splash_layer()
	_setup_tutorial_intro_panel()
	_setup_how_to_play_overlay()
	if AdsManager:
		AdsManager.ensure_started()
		AdsManager.show_menu_banner()
		AdsManager.warm_rewarded_hint()
	if SpaceBackground and SpaceBackground.has_method("set_foreground_events_enabled"):
		if not _boot_intro_active:
			SpaceBackground.set_foreground_events_enabled(true)
	if SaveManager and not SaveManager.language_changed.is_connected(_on_language_changed):
		SaveManager.language_changed.connect(_on_language_changed)
	if start_btn: start_btn.pressed.connect(_on_start_pressed)
	if tutorial_btn: tutorial_btn.pressed.connect(_on_tutorial_pressed)
	if levels_btn: levels_btn.pressed.connect(_on_levels_pressed)
	if how_to_play_btn: how_to_play_btn.pressed.connect(_on_how_to_play_pressed)
	if achievements_btn: achievements_btn.pressed.connect(_on_achievements_pressed)
	_setup_menu_notification_badges()
	if AchievementManager:
		# Only unseen_count_changed — unlocked emits a String id, not a count.
		if not AchievementManager.unseen_count_changed.is_connected(_refresh_achievements_badge):
			AchievementManager.unseen_count_changed.connect(_refresh_achievements_badge)
	_refresh_achievements_badge()
	if SaveManager and not SaveManager.unseen_levels_changed.is_connected(_refresh_levels_badge):
		SaveManager.unseen_levels_changed.connect(_refresh_levels_badge)
	_refresh_levels_badge()
	if options_btn: options_btn.pressed.connect(_on_options_pressed)
	if credits_btn: credits_btn.pressed.connect(_on_credits_pressed)
	if editor_btn: editor_btn.pressed.connect(_on_editor_pressed)
	if debug_star_btn: debug_star_btn.pressed.connect(_on_debug_star_pressed)
	if debug_comet_btn: debug_comet_btn.pressed.connect(_on_debug_comet_pressed)
	if debug_asteroid_btn: debug_asteroid_btn.pressed.connect(_on_debug_asteroid_pressed)
	if debug_asteroid_cloud_btn: debug_asteroid_cloud_btn.pressed.connect(_on_debug_asteroid_cloud_pressed)
	if debug_comet_shower_btn: debug_comet_shower_btn.pressed.connect(_on_debug_comet_shower_pressed)

	if close_credits_btn: close_credits_btn.pressed.connect(_on_close_credits)
	if _htp_prev: _htp_prev.pressed.connect(_on_htp_prev)
	if _htp_close: _htp_close.pressed.connect(_on_htp_close)
	if _htp_next: _htp_next.pressed.connect(_on_htp_next)
	if _tutorial_intro_yes: _tutorial_intro_yes.pressed.connect(_on_tutorial_intro_yes)
	if _tutorial_intro_no: _tutorial_intro_no.pressed.connect(_on_tutorial_intro_no)
	_mount_credits_close_button()

	_boot_intro_active = GlobalGameManager.main_menu_should_fade_in
	_build_consent_popup()
	_apply_safe_area_layout()
	if not get_viewport().size_changed.is_connected(_on_safe_area_viewport_resized):
		get_viewport().size_changed.connect(_on_safe_area_viewport_resized)

	if options_menu:
		options_menu.back_requested.connect(_on_options_back)
		if not options_menu.save_deleted.is_connected(_on_save_deleted):
			options_menu.save_deleted.connect(_on_save_deleted)

	if _boot_intro_active:
		GlobalGameManager.main_menu_should_fade_in = false
		# Survive an immediate Android pause during the boot intro.
		process_mode = Node.PROCESS_MODE_ALWAYS
		if _needs_privacy_consent():
			_boot_intro_waiting_on_consent = true
		_prepare_boot_intro()
		call_deferred("_play_boot_intro")

# Skips leftover intro animation and restores inherited process mode.
func _ensure_menu_ui_visible() -> void:
	_complete_boot_intro()
	process_mode = Node.PROCESS_MODE_INHERIT

# True for left-click or touch down (intro skip).
func _is_primary_pointer_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		return mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false

# True for left-click or touch up (intro skip).
func _is_primary_pointer_release(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		return not mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return not (event as InputEventScreenTouch).pressed
	return false

# Ignores menu buttons during the boot intro so they cannot be pressed early.
func _set_boot_menu_input_enabled(enabled: bool) -> void:
	var filter := Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for btn in [start_btn, tutorial_btn, levels_btn, how_to_play_btn, achievements_btn, options_btn, credits_btn, editor_btn]:
		if btn:
			btn.mouse_filter = filter
	for btn in [debug_star_btn, debug_asteroid_btn, debug_asteroid_cloud_btn, debug_comet_btn, debug_comet_shower_btn]:
		if btn:
			btn.mouse_filter = filter

# Skip-intro tap: eat the press/release so it does not hit a menu button.
func _input(event: InputEvent) -> void:
	if _eat_intro_pointer:
		get_viewport().set_input_as_handled()
		if _is_primary_pointer_release(event):
			_eat_intro_pointer = false
			call_deferred("_set_boot_menu_input_enabled", true)
		return
	if not _boot_intro_active:
		return
	if _consent_blocker and _consent_blocker.visible:
		return
	if _tutorial_intro_blocker and _tutorial_intro_blocker.visible:
		return
	if not _can_skip_boot_intro():
		return
	if not _is_primary_pointer_press(event):
		return
	_eat_intro_pointer = true
	get_viewport().set_input_as_handled()
	_ensure_menu_ui_visible()


# Tap skip is blocked until privacy is accepted on first launch.
func _can_skip_boot_intro() -> bool:
	if not _boot_intro_active:
		return false
	if _needs_privacy_consent():
		return false
	# First launch: after accept, wait until the title sequence actually starts.
	if _boot_intro_privacy_gate_passed and not _title_intro_started:
		return false
	return true

# Android back: close overlays first, then quit.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if GlobalGameManager == null or not GlobalGameManager.consume_system_back():
		return
	if AchievementManager and AchievementManager.is_list_open():
		AchievementManager.hide_list()
		return
	if _htp_host and _htp_host.visible:
		_on_htp_close()
		return
	if credits_panel and credits_panel.visible:
		_on_close_credits()
		return
	if options_menu and options_menu.visible:
		if options_menu.has_method("handle_system_back"):
			options_menu.handle_system_back()
		elif options_menu.has_method("hide_menu"):
			options_menu.hide_menu()
		return
	if _consent_blocker and _consent_blocker.visible:
		GlobalGameManager.quit_app()
		return
	if _tutorial_intro_blocker and _tutorial_intro_blocker.visible:
		_hide_tutorial_intro_prompt()
		return
	GlobalGameManager.quit_app()

# Disables space-background foreground FX when leaving the menu.
func _exit_tree() -> void:
	if SpaceBackground and SpaceBackground.has_method("set_foreground_events_enabled"):
		SpaceBackground.set_foreground_events_enabled(false)

# Menu chrome faded in after the title intro (center column + debug bar).
func _button_fade_targets() -> Array[CanvasItem]:
	var nodes: Array[CanvasItem] = []
	var center := menu_center as CanvasItem
	if center:
		nodes.append(center)
	var bar := debug_bar as CanvasItem
	if bar and debug_bar.visible:
		nodes.append(bar)
	return nodes

# Sets modulate.a on every boot-intro fade target.
func _set_button_ui_alpha(alpha: float) -> void:
	for node in _button_fade_targets():
		if node:
			node.modulate.a = alpha

# Authored TAKU title label inside TitleCluster.
func _title_label() -> Label:
	return get_node_or_null("TitleLayer/TitleHost/TitleCluster/TitleLabel") as Label

# Letter-tile controls that pop in after the typewriter.
func _title_tiles() -> Array[CanvasItem]:
	var tiles: Array[CanvasItem] = []
	var host := get_node_or_null("TitleLayer/TitleHost/TitleCluster/TitleTileHost") as Control
	if host == null:
		return tiles
	for child in host.get_children():
		if child is CanvasItem:
			tiles.append(child)
	return tiles

# TitleLabel + tiles host, slid from centre to rest.
func _title_cluster() -> Control:
	return get_node_or_null("TitleLayer/TitleHost/TitleCluster") as Control

# Cluster offset_top that vertically centres the title glyphs.
func _title_intro_center_top() -> float:
	return get_viewport_rect().size.y * 0.5 - TITLE_GLYPH_MID

# Sets TitleCluster top/bottom offsets for intro vs rest.
func _place_title_cluster(top: float) -> void:
	var cluster := _title_cluster()
	if cluster == null:
		return
	cluster.offset_top = top
	cluster.offset_bottom = top + TITLE_CLUSTER_HEIGHT

# Stores rest scale/offsets, then scales tiles to zero for the pop-in.
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
		# Scene offsets assume top-left pivot + scale 1.15. Shift so a center
		# pivot keeps that same visual center while the tile pops.
		var dx := pivot.x * (rest_scale.x - 1.0)
		var dy := pivot.y * (rest_scale.y - 1.0)
		ctrl.offset_left = rest.x + dx
		ctrl.offset_top = rest.y + dy
		ctrl.offset_right = rest.z + dx
		ctrl.offset_bottom = rest.w + dy
		ctrl.scale = Vector2.ZERO
		ctrl.modulate.a = 1.0

# Restores authored tile scale and offsets after intro or skip.
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

# Hides buttons, zeros title letters, and parks the cluster at centre.
func _prepare_boot_intro() -> void:
	var title := _title_label()
	if title:
		_layout_title_for_typewriter(title)
		title.visible_characters = 0
	_prepare_title_tile_pops()
	_place_title_cluster(_title_intro_center_top())
	var title_host := get_node_or_null("TitleLayer/TitleHost") as CanvasItem
	if title_host:
		title_host.modulate.a = 0.0
	_set_button_ui_alpha(0.0)
	_set_boot_menu_input_enabled(false)
	if SpaceBackground and SpaceBackground.has_method("prepare_boot_intro"):
		SpaceBackground.prepare_boot_intro()
	_show_boot_splash()

# Left-aligns the title at the settled glyph origin so typing matches rest.
func _layout_title_for_typewriter(title: Label) -> void:
	# Measure in the settled (centered, 24px-inset) rect, then left-align at that
	# same glyph origin so typing matches the title after the intro.
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

# Restores centred, fully-visible title layout from main_menu.tscn.
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

# Navy overlay that matches the system boot splash before live parallax fades in.
func _build_boot_splash_layer() -> void:
	if _boot_splash_layer != null:
		return
	_boot_splash_layer = CanvasLayer.new()
	_boot_splash_layer.name = "BootSplashLayer"
	_boot_splash_layer.layer = -1
	add_child(_boot_splash_layer)
	_boot_splash_void = ColorRect.new()
	_boot_splash_void.name = "VoidFill"
	_boot_splash_void.color = BOOT_VOID_COLOR
	_boot_splash_void.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boot_splash_layer.add_child(_boot_splash_void)
	_layout_boot_splash()
	_boot_splash_layer.visible = false


func _layout_boot_splash() -> void:
	if _boot_splash_void:
		_boot_splash_void.set_anchors_preset(Control.PRESET_FULL_RECT)
		_boot_splash_void.set_offsets_preset(Control.PRESET_FULL_RECT)


func _show_boot_splash() -> void:
	_build_boot_splash_layer()
	_layout_boot_splash()
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
	_layout_boot_splash()


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
		_on_boot_intro_impacted(get_viewport_rect().size * 0.5)
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
	_on_boot_intro_impacted(get_viewport_rect().size * 0.5)


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


# After splash tiles scatter or explode: privacy on first launch, else title letters.
func _continue_after_splash_tiles_cleared() -> void:
	if not _boot_intro_active:
		return
	if _boot_intro_waiting_on_consent and _needs_privacy_consent():
		_cancel_boot_intro_failsafe()
		_cancel_splash_deferred_timer()
		_show_privacy_consent_if_needed(false)
		return
	_begin_title_intro_sequence()


func _resume_title_intro_after_consent() -> void:
	if not _boot_intro_active or _title_intro_started:
		return
	var title_layer := get_node_or_null("TitleLayer") as CanvasLayer
	if title_layer:
		title_layer.visible = true
	if menu_center:
		menu_center.visible = true
	_set_button_ui_alpha(0.0)
	var title := _title_label()
	if title:
		_layout_title_for_typewriter(title)
		title.visible_characters = 0
	_prepare_title_tile_pops()
	_place_title_cluster(_title_intro_center_top())
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
	var title_host := get_node_or_null("TitleLayer/TitleHost") as CanvasItem
	if title_host:
		title_host.modulate.a = 1.0


func _cancel_boot_intro_failsafe() -> void:
	if _boot_intro_failsafe == null:
		return
	if _boot_intro_failsafe.timeout.is_connected(_ensure_menu_ui_visible):
		_boot_intro_failsafe.timeout.disconnect(_ensure_menu_ui_visible)
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
		_on_boot_intro_impacted(get_viewport_rect().size * 0.5)
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
	failsafe.timeout.connect(_ensure_menu_ui_visible)

# Splash blend (system splash → stars → physics hit → title intro).
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

# Shows the next typewriter letter and plays its SFX.
func _reveal_title_letter(count: int) -> void:
	if not _boot_intro_active:
		return
	var title := _title_label()
	if is_instance_valid(title):
		title.visible_characters = count
	if UiSfx:
		UiSfx.play_title_letter(count - 1)

# Tile-pop click used by the intro tween.
func _play_title_tile_pop_sfx(index: int) -> void:
	if not _boot_intro_active:
		return
	if UiSfx:
		UiSfx.play_title_tile_pop(index)

# Restores centred title layout as the cluster slides to rest.
func _on_title_slide_start() -> void:
	if not _boot_intro_active:
		return
	var title := _title_label()
	if is_instance_valid(title):
		_restore_title_layout(title)
	if UiSfx:
		UiSfx.play_title_slide()

# Fades in the menu column after the title has settled.
func _fade_buttons_after_title() -> void:
	if not _boot_intro_active:
		return
	_set_main_menu_chrome_visible(true)
	var buttons := _button_fade_targets()
	if buttons.is_empty():
		_complete_boot_intro()
		return
	_set_button_ui_alpha(0.0)
	if _button_fade_tween and _button_fade_tween.is_valid():
		_button_fade_tween.kill()
	_button_fade_tween = create_tween()
	_button_fade_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_button_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_button_fade_tween.set_parallel(true)
	for node in buttons:
		_button_fade_tween.tween_property(node, "modulate:a", 1.0, MENU_FADE_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_button_fade_tween.chain().tween_callback(_complete_boot_intro)

# Kills intro tweens and snaps title/buttons to their rest state.
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
	var title_host := get_node_or_null("TitleLayer/TitleHost") as CanvasItem
	if title_host:
		title_host.modulate.a = 1.0
	_set_button_ui_alpha(1.0)
	_title_intro_started = false
	_splash_physics_impact_handled = false
	_set_main_menu_chrome_visible(true)
	_apply_debug_tools_visibility()
	process_mode = Node.PROCESS_MODE_INHERIT
	if not _eat_intro_pointer:
		_set_boot_menu_input_enabled(true)

# Keeps title + UI on layer 0 so space FX can draw above the wordmark.
func _setup_title_under_fx() -> void:
	var ui_layer := $UILayer as CanvasLayer
	if ui_layer:
		ui_layer.layer = 0
	var title_layer := get_node_or_null("TitleLayer") as CanvasLayer
	if title_layer:
		title_layer.layer = 0
	_ensure_overlays_above_fx()
	var title := get_node_or_null("TitleLayer/TitleHost/TitleCluster/TitleLabel") as Label
	if title:
		_style_title_label(title)

# OverlayLayer is authored in main_menu.tscn at layer 5 so HTP/credits sit above FX.
func _ensure_overlays_above_fx() -> void:
	var overlay_layer := get_node_or_null("OverlayLayer") as CanvasLayer
	if overlay_layer:
		overlay_layer.layer = 5

# Brands the TAKU title as a screen header (Press Start / locale).
func _style_title_label(title: Label) -> void:
	title.set_meta("_brand_title", true)
	title.set_meta("_screen_header", true)
	title.set_meta("_screen_header_font_size", TITLE_FONT_SIZE)
	title.set_meta("_screen_header_outline", TITLE_OUTLINE)
	HudLayout.apply_screen_header_style(title)

# Styles the credits close control as a top-bar X.
func _mount_credits_close_button() -> void:
	if close_credits_btn:
		HudLayout.style_top_bar_close_button(close_credits_btn)

# Rebuilds menu fonts, HTP copy, and safe-area after a locale switch.
func _on_language_changed() -> void:
	_refresh_start_button_label()
	_fit_menu_buttons()
	HudLayout.apply_locale_fonts_to_tree(self)
	HudLayout.clear_how_to_play_nav_lock(_htp_host)
	_refresh_how_to_play_text()
	_apply_safe_area_layout()
	if _consent_blocker and _consent_blocker.visible and _consent_blocker.has_method("refresh_locale"):
		_consent_blocker.refresh_locale()
	if _tutorial_intro_blocker and _tutorial_intro_blocker.visible:
		_show_tutorial_intro_prompt()

# Viewport resized: recompute menu + debug-bar safe-area padding.
func _on_safe_area_viewport_resized() -> void:
	_apply_safe_area_layout()
	_layout_boot_splash()

# Pads the menu column and debug bar away from notches / nav bars.
func _apply_safe_area_layout() -> void:
	HudLayout.apply_content_edge_safe_area(menu_center)
	if debug_bar:
		var top := SafeInsets.padded_top(24.0)
		debug_bar.offset_left = 24.0 + SafeInsets.left()
		debug_bar.offset_top = top
		debug_bar.offset_right = -24.0 - SafeInsets.right()
		debug_bar.offset_bottom = top + 96.0

# PLAY vs RESUME depending on whether a session autosave exists.
func _refresh_start_button_label() -> void:
	if not start_btn:
		return
	if SaveManager and SaveManager.has_session():
		start_btn.text = "UI_RESUME"
	else:
		start_btn.text = "UI_PLAY"
	start_btn.set_meta("_tr_key", start_btn.text)

# Profile reset: refresh PLAY/RESUME and re-show consent if needed.
func _on_save_deleted() -> void:
	_refresh_start_button_label()
	_fit_menu_buttons()
	_refresh_achievements_badge()
	_refresh_levels_badge()
	# Privacy agreement is cleared with the profile — show consent immediately
	# (not only after a later main-menu reload via Level Select).
	_show_privacy_consent_if_needed(true)

# Sizes/fonts menu buttons, title, debug bar, and credits text.
func _fit_menu_buttons() -> void:
	for btn in [start_btn, tutorial_btn, levels_btn, how_to_play_btn, achievements_btn, options_btn, credits_btn, editor_btn]:
		_apply_main_menu_button(btn)
	_fit_debug_bar_buttons()
	if close_credits_btn:
		HudLayout.style_top_bar_close_button(close_credits_btn)
	var title = get_node_or_null("TitleLayer/TitleHost/TitleCluster/TitleLabel") as Label
	if title:
		_style_title_label(title)
	var credits_text_node = credits_panel.get_node_or_null("CreditsText") if credits_panel else null
	if credits_text_node:
		_apply_credits_fonts(credits_text_node)
	call_deferred("_bind_menu_badge_layout_hooks")
	call_deferred("_layout_menu_badges")

# Flat menu row: Press Start for Latin, locale font otherwise.
func _apply_main_menu_button(button: Button) -> void:
	if not button:
		return
	var empty := StyleBoxEmpty.new()
	for style_name in ["normal", "pressed", "hover", "disabled", "focus"]:
		button.add_theme_stylebox_override(style_name, empty)
	button.flat = true
	# Font path decided below from translated display (Latin → Press Start even in ka/uk).
	button.set_meta("_force_pixel_font", false)
	var is_play: bool = button == start_btn
	var row_h := 148.0 if is_play else 118.0
	var row_w := 780.0 if is_play else 720.0
	# Fixed sizes — PLAY/RESUME one step above the rest (64 → 72).
	var font_size := 72 if is_play else MENU_BTN_FONT
	button.custom_minimum_size = Vector2(row_w, row_h)
	button.clip_text = false
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	var raw := button.text.strip_edges()
	var key := raw if not raw.is_empty() else String(button.get_meta("_tr_key", "")).strip_edges()
	if not key.is_empty():
		button.set_meta("_tr_key", key)
	var display := String(TranslationServer.translate(key)) if not key.is_empty() else ""
	if display.is_empty():
		display = key
	if HudFonts.should_use_press_start_font(display):
		# Natural advances + geometric centering (Label captions can shift long titles).
		# Also covers Latin-only chrome while the game language is ka/uk.
		HudLayout.apply_pixel_mono_button(button, display, font_size, Color.WHITE)
	else:
		HudLayout._clear_pixel_raster(button)
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
		button.text = key if not key.is_empty() else button.text
		button.remove_meta("_safe_pixel_label")
		button.set_meta("_use_default_font", true)
		button.set_meta("_force_pixel_font", false)
		HudLayout.apply_locale_font_to_control(button)
		button.add_theme_font_size_override("font_size", HudLayout.body_font_size(font_size))
		HudLayout.apply_safe_outline(button, MENU_BTN_OUTLINE)

# Icon-only debug FX buttons along the top bar.
func _fit_debug_bar_buttons() -> void:
	_setup_debug_fx_button(debug_star_btn, [_FX_STAR])
	_setup_debug_fx_button(debug_asteroid_btn, [_FX_AST_1])
	_setup_debug_fx_button(debug_asteroid_cloud_btn, [_FX_AST_1, _FX_AST_2, _FX_AST_3])
	_setup_debug_fx_button(debug_comet_btn, [_FX_COMET_1])
	_setup_debug_fx_button(debug_comet_shower_btn, [_FX_COMET_1, _FX_COMET_2, _FX_COMET_3])

# Builds nearest-neighbour icon(s) inside a debug FX button.
func _setup_debug_fx_button(button: Button, textures: Array) -> void:
	if button == null:
		return
	button.text = ""
	button.custom_minimum_size = _DEBUG_BTN_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	var host := button.get_node_or_null("IconHost") as Control
	if host == null:
		host = Control.new()
		host.name = "IconHost"
		host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.add_child(host)
	for child in host.get_children():
		child.queue_free()
	var count := textures.size()
	if count <= 0:
		return
	var btn_px := _DEBUG_BTN_SIZE.x
	if count == 1:
		var pad := maxf(10.0, btn_px * 0.14)
		var scale_i := maxi(2, int(floor((btn_px - pad * 2.0) / 16.0)))
		var solo_px := float(16 * scale_i)
		var inset := (btn_px - solo_px) * 0.5
		var icon := TextureRect.new()
		icon.texture = textures[0]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2(inset, inset)
		icon.size = Vector2(solo_px, solo_px)
		host.add_child(icon)
		return
	var s := btn_px / 72.0
	var icon_px := 28.0 * s
	var offsets := [
		Vector2(8, 10) * s,
		Vector2(28, 22) * s,
		Vector2(14, 34) * s,
	]
	for i in count:
		var icon := TextureRect.new()
		icon.texture = textures[i]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = offsets[mini(i, offsets.size() - 1)]
		icon.size = Vector2(icon_px, icon_px)
		host.add_child(icon)

# Shows/hides the title layer and centre button column.
func _set_main_menu_chrome_visible(should_show: bool) -> void:
	if menu_center:
		menu_center.visible = should_show
	var title_layer := get_node_or_null("TitleLayer") as CanvasLayer
	if title_layer:
		title_layer.visible = should_show


# Hides menu chrome for overlays. During boot intro, keep the title layer
# visible so the post-consent letter sequence can play.
func _hide_main_menu_chrome_for_overlay() -> void:
	if menu_center:
		menu_center.visible = false
	_set_debug_bar_visible(false)
	if _boot_intro_active:
		var title_layer := get_node_or_null("TitleLayer") as CanvasLayer
		if title_layer:
			title_layer.visible = true
	else:
		var title_layer := get_node_or_null("TitleLayer") as CanvasLayer
		if title_layer:
			title_layer.visible = false

# Locale-aware credits BBCode sizes; Press Start for Latin names.
func _apply_credits_fonts(credits_text_node: RichTextLabel) -> void:
	if not credits_text_node:
		return
	# Don't expand-fill the panel — that + a huge theme font size stretches blank lines.
	credits_text_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	credits_text_node.fit_content = true
	credits_text_node.scroll_active = false
	credits_text_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var bbcode := String(TranslationServer.translate("CREDITS_TEXT"))
	var locale_mul := HudFonts.non_pixel_locale_scale()
	if HudFonts.uses_pixel_font():
		var header_sz := int(round(float(CREDITS_HEADER_SIZE) * locale_mul))
		var body_sz := int(round(float(CREDITS_NAME_SIZE) * locale_mul))
		# Normalize authored BBCode sizes so the name stays on one line.
		bbcode = bbcode.replace("[font_size=48]", "[font_size=%d]" % header_sz)
		bbcode = bbcode.replace("[font_size=42]", "[font_size=%d]" % header_sz)
		bbcode = bbcode.replace("[font_size=40]", "[font_size=%d]" % body_sz)
		bbcode = bbcode.replace("[font_size=36]", "[font_size=%d]" % header_sz)
		bbcode = bbcode.replace("[font_size=34]", "[font_size=%d]" % body_sz)
		bbcode = bbcode.replace("[font_size=28]", "[font_size=%d]" % body_sz)
		credits_text_node.set_meta("_use_default_font", false)
		HudLayout.apply_live_pixel_richtext(credits_text_node, CREDITS_BODY_SIZE)
		credits_text_node.text = bbcode
	else:
		# Default fonts read smaller than Press Start at the same nominal size.
		var header_sz := int(round(float(CREDITS_HEADER_LOCALE_SIZE) * locale_mul))
		var body_sz := int(round(float(CREDITS_NAME_LOCALE_SIZE) * locale_mul))
		bbcode = bbcode.replace("[font_size=48]", "[font_size=%d]" % header_sz)
		bbcode = bbcode.replace("[font_size=42]", "[font_size=%d]" % header_sz)
		bbcode = bbcode.replace("[font_size=40]", "[font_size=%d]" % body_sz)
		bbcode = bbcode.replace("[font_size=36]", "[font_size=%d]" % header_sz)
		bbcode = bbcode.replace("[font_size=34]", "[font_size=%d]" % body_sz)
		bbcode = bbcode.replace("[font_size=28]", "[font_size=%d]" % body_sz)
		var pixel_sz := int(round(float(CREDITS_NAME_SIZE) * locale_mul))
		bbcode = _wrap_credits_author_pixel_font(bbcode, body_sz, pixel_sz)
		credits_text_node.set_meta("_use_default_font", true)
		HudLayout.apply_locale_font_to_control(credits_text_node)
		for size_name in [
			"normal_font_size",
			"bold_font_size",
			"italics_font_size",
			"bold_italics_font_size",
			"mono_font_size",
		]:
			credits_text_node.add_theme_font_size_override(size_name, body_sz)
		credits_text_node.text = bbcode
		HudLayout.apply_safe_outline(credits_text_node, GameConstants.MENU_TEXT_OUTLINE)
	_refresh_credits_version()

# ka credits: Georgian name/surname in locale font; Press Start only for "gix0n".
# uk credits: full Latin author name in Press Start (no Georgian script to localize).
const CREDITS_NICKNAME := "\"gix0n\""

# NBSP so author first/last names stay on one line.
func _credits_author_single_line(text: String) -> String:
	return text.replace(" ", "\u00a0")

# ka credits: wrap only the gix0n nickname in Press Start.
func _wrap_credits_nickname_pixel_font(text: String, pixel_sz: int) -> String:
	if not text.contains(CREDITS_NICKNAME):
		return text
	var pixel := "[font=%s][font_size=%d]%s[/font_size][/font]" % [
		HudLayout.PIXEL_FONT_PATH, pixel_sz, CREDITS_NICKNAME
	]
	return text.replace(CREDITS_NICKNAME, pixel)

# uk credits: wrap the full Latin author name in Press Start.
func _wrap_credits_full_name_pixel_font(text: String, pixel_sz: int) -> String:
	return "[font=%s][font_size=%d]%s[/font_size][/font]" % [
		HudLayout.PIXEL_FONT_PATH, pixel_sz, text
	]

# Picks nickname vs full-name Press Start wrap from locale.
func _wrap_credits_author_name_display(author: String, pixel_sz: int) -> String:
	var single_line := _credits_author_single_line(author)
	if HudFonts.locale_code() == "ka":
		return _wrap_credits_nickname_pixel_font(single_line, pixel_sz)
	return _wrap_credits_full_name_pixel_font(single_line, pixel_sz)

# Replaces the translated author run with mixed-font BBCode.
func _wrap_credits_author_pixel_font(bbcode: String, body_sz: int, pixel_sz: int) -> String:
	var author := String(TranslationServer.translate("UI_SPLASH_AUTHOR"))
	var author_display := _wrap_credits_author_name_display(author, pixel_sz)
	var author_single := _credits_author_single_line(author)
	if author_display == author_single and HudFonts.locale_code() == "ka":
		return bbcode
	var name_mixed: String
	if HudFonts.locale_code() == "ka":
		name_mixed = "[font_size=%d]%s[/font_size]" % [body_sz, author_display]
	else:
		name_mixed = author_display
	for name_plain in [
		"[font_size=%d]%s[/font_size]" % [body_sz, author_single],
		"[font_size=%d]%s[/font_size]" % [body_sz, author],
	]:
		if bbcode.contains(name_plain):
			return bbcode.replace(name_plain, name_mixed)
	var normalized := bbcode.replace("\u00a0", " ")
	for name_plain in [
		"[font_size=%d]%s[/font_size]" % [body_sz, author],
	]:
		if normalized.contains(name_plain):
			return normalized.replace(name_plain, name_mixed)
	return bbcode

# ASCII-safe project version for the credits label.
func _app_version_string() -> String:
	var version := String(ProjectSettings.get_setting("application/config/version", "1.0.0"))
	# Guard against mangled/non-ASCII version strings from export tooling.
	var cleaned := ""
	for i in version.length():
		var ch := version.substr(i, 1)
		var code := version.unicode_at(i)
		var ok := (
			(code >= 48 and code <= 57) # 0-9
			or ch == "."
			or ch == "-"
			or ch == "+"
			or (code >= 65 and code <= 90) # A-Z
			or (code >= 97 and code <= 122) # a-z
		)
		if ok:
			cleaned += ch
	if cleaned.is_empty():
		cleaned = "1.0.0"
	return cleaned

# Draws vX.Y.Z [DEV] and wires the hold-to-unlock input.
func _refresh_credits_version() -> void:
	if not credits_version_label:
		return
	credits_version_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var dev_on := SaveManager != null and SaveManager.dev_mode_enabled
	var version_text := "v%s%s" % [_app_version_string(), " [DEV]" if dev_on else ""]
	credits_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_version_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	HudLayout.apply_raster_pixel_label(
		credits_version_label,
		version_text,
		28,
		Color(0.67, 0.67, 0.67, 1),
		0,
		true
	)
	credits_version_label.mouse_filter = Control.MOUSE_FILTER_STOP
	if not credits_version_label.gui_input.is_connected(_on_version_label_input):
		credits_version_label.gui_input.connect(_on_version_label_input)

# Detects press/release on the version label to start/stop the hold timer.
func _on_version_label_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_version_hold_active = true
			_version_hold_elapsed = 0.0
			set_process(true)
		else:
			_version_hold_active = false

# Counts hold time; fires _toggle_dev_mode once the threshold is reached.
func _process(delta: float) -> void:
	if not _version_hold_active:
		set_process(false)
		return
	_version_hold_elapsed += delta
	if _version_hold_elapsed >= _VERSION_HOLD_SEC:
		_version_hold_active = false
		set_process(false)
		_toggle_dev_mode()

# Toggles dev mode via SaveManager and flashes the version label green (on) or red (off).
# Does NOT change debug_bar visibility here — the bar must only appear in the main menu,
# not inside the credits overlay where this label lives.
func _toggle_dev_mode() -> void:
	if SaveManager == null:
		return
	var now_on := SaveManager.toggle_dev_mode()
	# Secret achievement: only when the hold successfully turns dev mode ON.
	if now_on and AchievementManager:
		AchievementManager.grant(AchievementCatalog.ID_DEV_MODE)
	GlobalGameManager.debug_tools_enabled = _is_debug_enabled()
	_refresh_credits_version()
	if credits_version_label:
		var tw := create_tween()
		var target_color := Color(0.2, 1.0, 0.4, 1.0) if now_on else Color(1.0, 0.3, 0.3, 1.0)
		tw.tween_property(credits_version_label, "modulate", target_color, 0.15)
		tw.tween_property(credits_version_label, "modulate", Color.WHITE, 0.4)

# Sets the Editor row translation key.
func _apply_editor_button_label() -> void:
	if not editor_btn:
		return
	editor_btn.text = "UI_EDITOR"
	editor_btn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS

# Debug tools are enabled either via the export flag (editor/testing builds)
# or via the in-game dev mode unlock (runtime, session-only).
func _is_debug_enabled() -> bool:
	return show_debug_tools or (SaveManager != null and SaveManager.dev_mode_enabled)

# Shows Editor + debug bar when export flag or session dev mode is on.
func _apply_debug_tools_visibility() -> void:
	var enabled := _is_debug_enabled()
	GlobalGameManager.debug_tools_enabled = enabled
	if editor_btn:
		editor_btn.visible = enabled
	if debug_bar:
		debug_bar.visible = enabled

# Debug bar only when both requested and debug tools are enabled.
func _set_debug_bar_visible(should_show: bool) -> void:
	if debug_bar:
		debug_bar.visible = _is_debug_enabled() and should_show

# Tutorial row: skip the intro prompt and launch the first incomplete lesson.
func _on_tutorial_pressed() -> void:
	_apply_debug_tools_visibility()
	if SaveManager:
		SaveManager.set_tutorial_intro_answered(true)
	_ensure_easy_unlocked()
	_launch_tutorial()

# PLAY/RESUME: tutorial prompt if unanswered, else start the campaign.
func _on_start_pressed() -> void:
	_apply_debug_tools_visibility()
	_ensure_easy_unlocked()
	if SaveManager and not SaveManager.tutorial_intro_answered:
		_show_tutorial_intro_prompt()
		return
	_start_game()

# Loads the main puzzle scene.
func _start_game() -> void:
	GlobalGameManager.go_to_scene("res://scenes/main.tscn")

# Selects the first incomplete tutorial level, then starts the game.
func _launch_tutorial() -> void:
	var tutorial := TutorialScripts.first_incomplete_level()
	if tutorial:
		GlobalGameManager.selected_level_resource = tutorial
	_start_game()

# First LevelData in a campaign directory, or null.
func _first_level_in_dir(dir_path: String) -> LevelData:
	var paths := LevelUtils.scan_directory(dir_path)
	LevelUtils.sort_level_paths(paths)
	for path in paths:
		var resource = load(path)
		if resource is LevelData:
			return resource
	return null

# Styles HTP chrome. Page header is authored in main_menu.tscn.
func _setup_how_to_play_overlay() -> void:
	if _htp_host:
		_htp_host.visible = false
		_htp_host.mouse_filter = Control.MOUSE_FILTER_STOP
	if _htp_rules:
		_htp_rules.set_meta("_use_default_font", true)
		_htp_rules.add_theme_color_override("default_color", Color.WHITE)
		HudLayout.apply_safe_outline(_htp_rules, GameConstants.MENU_TEXT_OUTLINE)
	for btn in [_htp_prev, _htp_next]:
		HudLayout.apply_nav_button(btn)
	if _htp_close:
		HudLayout.style_top_bar_close_button(_htp_close)
	_refresh_how_to_play_text()

# Header, body, and prev/next visibility for the current HTP page.
func _refresh_how_to_play_text() -> void:
	if _htp_header:
		HudLayout._bind_header_translation_key(
			_htp_header, HowToPlayContent.get_page_title_key(_htp_page)
		)
		HudLayout.apply_screen_header_style(_htp_header)
	if _htp_rules:
		_htp_rules.text = HowToPlayContent.get_page_text(_htp_page)
		HudLayout.apply_locale_font_to_control(_htp_rules)
	if _htp_prev:
		_htp_prev.visible = _htp_page > 0
		HudLayout.apply_nav_button(_htp_prev)
	if _htp_next:
		_htp_next.visible = _htp_page < HowToPlayContent.PAGE_COUNT - 1
		HudLayout.apply_nav_button(_htp_next)
	if _htp_close:
		HudLayout.style_top_bar_close_button(_htp_close)
	call_deferred("_layout_how_to_play_stack")

# Places HTP panel + nav after the rules label has measured.
func _layout_how_to_play_stack() -> void:
	HudLayout.layout_how_to_play_stack(
		_htp_host, _htp_panel, _htp_rules, _htp_nav, _htp_page == 0, true
	)

# Previous HTP page, clamped at 0.
func _on_htp_prev() -> void:
	_htp_page = maxi(_htp_page - 1, 0)
	_refresh_how_to_play_text()

# Next HTP page, clamped at PAGE_COUNT-1.
func _on_htp_next() -> void:
	_htp_page = mini(_htp_page + 1, HowToPlayContent.PAGE_COUNT - 1)
	_refresh_how_to_play_text()

# Closes HTP and restores menu chrome.
func _on_htp_close() -> void:
	if _htp_host:
		_htp_host.visible = false
	_set_main_menu_chrome_visible(true)
	_set_debug_bar_visible(true)

const _CONSENT_POPUP_SCENE := preload("res://scenes/consent_popup.tscn")

# True until the player has accepted the privacy popup.
func _needs_privacy_consent() -> bool:
	return SaveManager != null and not SaveManager.privacy_accepted

# Instantiates the consent popup scene. Shown after splash tiles clear on first
# launch, or immediately when a reset profile still needs acceptance.
func _build_consent_popup() -> void:
	_ensure_overlays_above_fx()
	var host := get_node_or_null("OverlayLayer") as CanvasLayer
	if host == null:
		host = get_node_or_null("UILayer") as CanvasLayer
	if host == null:
		return
	var popup := _CONSENT_POPUP_SCENE.instantiate()
	host.add_child(popup)
	_consent_blocker = popup as ColorRect
	if _consent_blocker:
		_consent_blocker.visible = false
	popup.accepted.connect(_on_consent_accepted)
	_bias_consent_popup_up()
	if not _boot_intro_active:
		_show_privacy_consent_if_needed(false)

# Raises the consent card above true center for easier reach on tall phones.
func _bias_consent_popup_up() -> void:
	if _consent_blocker == null:
		return
	var top := _consent_blocker.get_node_or_null("Outer/SpacerTop") as Control
	var bot := _consent_blocker.get_node_or_null("Outer/SpacerBot") as Control
	if top:
		top.size_flags_stretch_ratio = 1.0
	if bot:
		bot.size_flags_stretch_ratio = 1.0 + GameConstants.UI_DIALOG_RAISE_PX / 480.0

# Shows the privacy consent overlay when the profile has not accepted it yet.
# If close_options is true, closes Options first so the consent is unobstructed.
func _show_privacy_consent_if_needed(close_options: bool = false) -> void:
	if not _needs_privacy_consent():
		return
	if _consent_blocker == null:
		return
	if close_options and options_menu and options_menu.visible:
		options_menu.visible = false
	_hide_main_menu_chrome_for_overlay()
	# Refresh copy/fonts for the current locale (reset can reopen after a language change).
	if _consent_blocker.has_method("refresh_locale"):
		_consent_blocker.refresh_locale()
	_consent_blocker.visible = true
	_consent_blocker.move_to_front()

# Called when the player taps ACCEPT on the consent popup.
# Saves acceptance, then resumes the title intro or restores the menu.
func _on_consent_accepted() -> void:
	var resume_intro := _boot_intro_active and not _title_intro_started
	if resume_intro:
		_boot_intro_privacy_gate_passed = true
		_eat_intro_pointer = true
	if SaveManager:
		SaveManager.accept_privacy()
	_boot_intro_waiting_on_consent = false
	if _consent_blocker:
		_consent_blocker.visible = false
	if resume_intro:
		_cancel_boot_intro_failsafe()
		_cancel_splash_deferred_timer()
		_resume_title_intro_after_consent()
		return
	_set_main_menu_chrome_visible(true)
	_set_button_ui_alpha(1.0)
	var title_host := get_node_or_null("TitleLayer/TitleHost") as CanvasItem
	if title_host:
		title_host.modulate.a = 1.0
	var title := _title_label()
	if title:
		_restore_title_layout(title)
	_apply_debug_tools_visibility()
	_set_boot_menu_input_enabled(true)

# Styles the first-play tutorial prompt (no dimmer; chrome hides instead).
func _setup_tutorial_intro_panel() -> void:
	if _tutorial_intro_blocker:
		_tutorial_intro_blocker.visible = false
		_tutorial_intro_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
		# Match other popups: no dim overlay — menu chrome is hidden instead.
		_tutorial_intro_blocker.color = Color(0, 0, 0, 0)
	var center := (
		_tutorial_intro_blocker.get_node_or_null("CenterContainer") as Control
		if _tutorial_intro_blocker
		else null
	)
	if center:
		HudLayout.raise_centered_dialog_host(center)
	var panel := _tutorial_intro_blocker.get_node_or_null("CenterContainer/Panel") as Panel if _tutorial_intro_blocker else null
	if panel:
		panel.add_theme_stylebox_override("panel", HudLayout.make_dialog_panel_style())
	if _tutorial_intro_label:
		_tutorial_intro_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55, 1.0))
		HudLayout.apply_popup_label(_tutorial_intro_label, GameConstants.UI_BODY_FONT_SIZE_LARGE)
	_copy_menu_button_styles(_tutorial_intro_yes)
	_copy_menu_button_styles(_tutorial_intro_no)

# Copies PLAY/Options StyleBoxes onto a dialog button.
func _copy_menu_button_styles(target: Button) -> void:
	var source: Button = start_btn if start_btn else options_btn
	if not source or not target:
		return
	for style_name in ["normal", "pressed", "hover", "disabled"]:
		var style := source.get_theme_stylebox(style_name)
		if style and not (style is StyleBoxEmpty):
			target.add_theme_stylebox_override(style_name, style)
	target.add_theme_color_override("font_outline_color", Color.BLACK)
	HudLayout.apply_safe_outline(target, GameConstants.MENU_TEXT_OUTLINE)

# First-play Yes/No: hide chrome and show the tutorial intro dialog.
func _show_tutorial_intro_prompt() -> void:
	_set_main_menu_chrome_visible(false)
	_set_debug_bar_visible(false)
	if _tutorial_intro_label:
		_tutorial_intro_label.text = tr("TUTORIAL_INTRO_PROMPT")
		HudLayout.apply_popup_label(_tutorial_intro_label, GameConstants.UI_BODY_FONT_SIZE_LARGE)
	if _tutorial_intro_yes:
		_tutorial_intro_yes.text = tr("UI_YES")
	if _tutorial_intro_no:
		_tutorial_intro_no.text = tr("UI_NO")
	var panel := (
		_tutorial_intro_blocker.get_node_or_null("CenterContainer/Panel") as Panel
		if _tutorial_intro_blocker
		else null
	)
	if panel:
		HudLayout.fit_dialog_panel(panel, HudLayout.UI_DEFAULT_DIALOG_WIDTH)
	if _tutorial_intro_blocker:
		_tutorial_intro_blocker.color = Color(0, 0, 0, 0)
		_tutorial_intro_blocker.visible = true
		_tutorial_intro_blocker.move_to_front()

# Hides the tutorial intro dialog and restores menu chrome.
func _hide_tutorial_intro_prompt() -> void:
	if _tutorial_intro_blocker:
		_tutorial_intro_blocker.visible = false
	_set_main_menu_chrome_visible(true)
	_set_debug_bar_visible(true)

# Starts the tutorial from the intro prompt.
func _on_tutorial_intro_yes() -> void:
	_hide_tutorial_intro_prompt()
	SaveManager.set_tutorial_intro_answered(true)
	_ensure_easy_unlocked()
	_launch_tutorial()

# Declines tutorial and starts Easy campaign instead.
func _on_tutorial_intro_no() -> void:
	_hide_tutorial_intro_prompt()
	SaveManager.set_tutorial_intro_answered(true)
	_ensure_easy_unlocked()
	var easy := _first_level_in_dir(GameConstants.CAMPAIGN_EASY_DIR)
	if easy:
		GlobalGameManager.selected_level_resource = easy
	_start_game()

# Unlocks campaign level 1 so PLAY cannot land on a locked slot.
func _ensure_easy_unlocked() -> void:
	if SaveManager == null:
		return
	SaveManager.unlock_level(LevelUtils.first_campaign_level_number())

# Opens level select.
func _on_levels_pressed() -> void:
	_apply_debug_tools_visibility()
	_ensure_easy_unlocked()
	GlobalGameManager.go_to_scene("res://scenes/level_select.tscn")

# Hides menu chrome and opens HTP at page 0.
func _on_how_to_play_pressed() -> void:
	_set_main_menu_chrome_visible(false)
	_set_debug_bar_visible(false)
	_htp_page = 0
	HudLayout.clear_how_to_play_nav_lock(_htp_host)
	_refresh_how_to_play_text()
	if _htp_host:
		_htp_host.visible = true
		_htp_host.move_to_front()


# Hides menu chrome and shows the achievements overlay.
func _on_achievements_pressed() -> void:
	_set_main_menu_chrome_visible(false)
	_set_debug_bar_visible(false)
	if AchievementManager:
		AchievementManager.show_list(_on_achievements_closed)
	else:
		_set_main_menu_chrome_visible(true)
		_set_debug_bar_visible(true)


## Restores menu after the achievements list closes.
func _on_achievements_closed() -> void:
	_set_main_menu_chrome_visible(true)
	_set_debug_bar_visible(true)
	_refresh_achievements_badge()
	_refresh_levels_badge()
	_fit_menu_buttons()


func _setup_menu_notification_badges() -> void:
	if _menu_badge_host == null:
		var host := _ensure_menu_badge_host()
		if host == null:
			return
	if achievements_btn != null and _ach_badge_panel == null:
		var ach_built := HudLayout.build_notification_badge()
		_ach_badge_panel = ach_built["panel"] as Panel
		_ach_badge_panel.name = "AchievementsUnseenBadge"
		_menu_badge_host.add_child(_ach_badge_panel)
	if levels_btn != null and _levels_badge_panel == null:
		var levels_built := HudLayout.build_notification_badge()
		_levels_badge_panel = levels_built["panel"] as Panel
		_levels_badge_panel.name = "LevelsUnseenBadge"
		_menu_badge_host.add_child(_levels_badge_panel)
	if achievements_btn and not achievements_btn.resized.is_connected(_layout_menu_badges):
		achievements_btn.resized.connect(_layout_menu_badges)
	if levels_btn and not levels_btn.resized.is_connected(_layout_menu_badges):
		levels_btn.resized.connect(_layout_menu_badges)
	if menu_center and not menu_center.resized.is_connected(_layout_menu_badges):
		menu_center.resized.connect(_layout_menu_badges)


func _ensure_menu_badge_host() -> Control:
	if _menu_badge_host != null and is_instance_valid(_menu_badge_host):
		return _menu_badge_host
	if menu_center == null:
		return null
	_menu_badge_host = Control.new()
	_menu_badge_host.name = "MenuNotificationBadgeHost"
	_menu_badge_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_badge_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_badge_host.offset_left = 0.0
	_menu_badge_host.offset_top = 0.0
	_menu_badge_host.offset_right = 0.0
	_menu_badge_host.offset_bottom = 0.0
	_menu_badge_host.z_index = 10
	menu_center.add_child(_menu_badge_host)
	return _menu_badge_host


func _menu_button_display_text(button: Button, fallback_key: String) -> String:
	if button == null:
		return ""
	var key := String(button.get_meta("_tr_key", fallback_key)).strip_edges()
	if key.is_empty():
		key = fallback_key
	var display := String(TranslationServer.translate(key))
	return display if not display.is_empty() else key


func _bind_menu_badge_layout_hooks() -> void:
	for button in [achievements_btn, levels_btn]:
		if button == null:
			continue
		var mono: Control = button.get_node_or_null("PixelMonoCaption") as Control
		if mono != null and not mono.resized.is_connected(_layout_menu_badges):
			mono.resized.connect(_layout_menu_badges)


func _centered_label_trailing_x(display: String, host_w: float, font_size: int, use_pixel: bool) -> float:
	if display.is_empty() or host_w <= 0.0 or font_size <= 0:
		return host_w * 0.5
	var font := HudLayout.pixel_font_clean() if use_pixel else HudFonts.default_font()
	var px := font_size if use_pixel else HudLayout.body_font_size(font_size)
	if use_pixel:
		return _PIXEL_MONO_TEXT_SCRIPT.ink_trailing_x_for_centered_text(
			display, font, px, host_w
		)
	var text_w := font.get_string_size(display, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	return (host_w + text_w) * 0.5


func _menu_button_label_trailing_x(button: Button, btn_w: float, fallback_key: String) -> float:
	if button == null or btn_w <= 0.0:
		return btn_w * 0.5
	var mono: Control = button.get_node_or_null("PixelMonoCaption") as Control
	if mono != null and mono.has_method("text_trailing_local_x"):
		return float(mono.call("text_trailing_local_x", btn_w))
	var display := _menu_button_display_text(button, fallback_key)
	return _centered_label_trailing_x(
		display,
		btn_w,
		MENU_BTN_FONT,
		HudFonts.should_use_press_start_font(display)
	)


func _layout_menu_button_badge(panel: Panel, button: Button, fallback_key: String) -> void:
	if panel == null or button == null:
		return
	var host := _ensure_menu_badge_host()
	if host == null:
		return
	if panel.get_parent() != host:
		host.add_child(panel)
	var btn_rect: Rect2 = button.get_global_rect()
	var btn_w: float = btn_rect.size.x
	if btn_w <= 1.0:
		btn_w = button.custom_minimum_size.x
	var btn_h: float = btn_rect.size.y
	if btn_h <= 1.0:
		btn_h = button.custom_minimum_size.y
	var badge_dims: Vector2 = HudLayout.notification_badge_size(btn_h)
	var trailing_x: float = _menu_button_label_trailing_x(button, btn_w, fallback_key)
	var host_origin: Vector2 = host.get_global_rect().position
	var x: float = btn_rect.position.x - host_origin.x + trailing_x + MENU_BADGE_TEXT_GAP
	var y: float = btn_rect.position.y - host_origin.y + maxf(MENU_BADGE_MARGIN, btn_h * 0.12)
	x = clampf(x, 0.0, maxf(0.0, host.size.x - badge_dims.x))
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = x
	panel.offset_top = y
	panel.offset_right = x + badge_dims.x
	panel.offset_bottom = y + badge_dims.y
	panel.z_index = 1
	panel.move_to_front()


func _layout_menu_badges() -> void:
	_layout_menu_button_badge(_ach_badge_panel, achievements_btn, "UI_ACHIEVEMENTS")
	_layout_menu_button_badge(_levels_badge_panel, levels_btn, "UI_LEVEL_SELECT")


func _refresh_achievements_badge(_count: int = -1) -> void:
	if _ach_badge_panel == null:
		return
	var unseen := _count if _count >= 0 else (AchievementManager.unseen_count() if AchievementManager else 0)
	# Keep panel.visible true while unseen — parent menu_center hides with overlays.
	# Gating on is_visible_in_tree() cleared the badge during credits unlocks.
	_ach_badge_panel.visible = unseen > 0
	if unseen > 0:
		call_deferred("_layout_menu_badges")


func _refresh_levels_badge(_count: int = -1) -> void:
	if _levels_badge_panel == null:
		return
	var unseen := _count if _count >= 0 else (SaveManager.unseen_level_count() if SaveManager else 0)
	_levels_badge_panel.visible = unseen > 0
	if unseen > 0:
		call_deferred("_layout_menu_badges")


# Hides menu chrome and shows the options overlay.
func _on_options_pressed() -> void:
	_set_main_menu_chrome_visible(false)
	_set_debug_bar_visible(false)
	if options_menu:
		options_menu.show_menu(true)

# Restores menu after Options; may re-show consent after a profile reset.
func _on_options_back() -> void:
	_set_main_menu_chrome_visible(true)
	_set_debug_bar_visible(true)
	_refresh_start_button_label()
	_fit_menu_buttons()
	_refresh_achievements_badge()
	_refresh_levels_badge()
	_show_privacy_consent_if_needed(false)

# Hides menu chrome and shows credits.
func _on_credits_pressed() -> void:
	_set_main_menu_chrome_visible(false)
	_set_debug_bar_visible(false)
	if overlay_blocker: overlay_blocker.visible = true
	if credits_panel: credits_panel.visible = true
	var credits_text = credits_panel.get_node_or_null("CreditsText") if credits_panel else null
	if credits_text:
		_apply_credits_fonts(credits_text)
	else:
		_refresh_credits_version()
	if close_credits_btn:
		HudLayout.style_top_bar_close_button(close_credits_btn)

# Closes credits and refreshes debug visibility (dev mode may have toggled).
func _on_close_credits() -> void:
	if overlay_blocker: overlay_blocker.visible = false
	if credits_panel: credits_panel.visible = false
	_set_main_menu_chrome_visible(true)
	# Refresh editor + debug bar now that credits overlay is gone — dev mode may
	# have been toggled while credits was open and _toggle_dev_mode intentionally
	# skips visibility changes until we return to the main menu.
	_apply_debug_tools_visibility()
	_fit_menu_buttons()
	_refresh_achievements_badge()
	_refresh_levels_badge()

# Opens the level editor.
func _on_editor_pressed() -> void:
	GlobalGameManager.go_to_scene("res://scenes/level_editor.tscn")

# Debug: spawn a shooting star.
func _on_debug_star_pressed() -> void:
	if SpaceBackground:
		SpaceBackground.debug_spawn_shooting_star()

# Debug: spawn a comet.
func _on_debug_comet_pressed() -> void:
	if SpaceBackground:
		SpaceBackground.debug_spawn_comet()

# Debug: spawn an asteroid.
func _on_debug_asteroid_pressed() -> void:
	if SpaceBackground:
		SpaceBackground.debug_spawn_asteroid()

# Debug: spawn an asteroid cloud.
func _on_debug_asteroid_cloud_pressed() -> void:
	if SpaceBackground:
		SpaceBackground.debug_spawn_asteroid_cloud()

# Debug: spawn a meteor shower.
func _on_debug_comet_shower_pressed() -> void:
	if SpaceBackground:
		SpaceBackground.debug_spawn_meteor_shower()
