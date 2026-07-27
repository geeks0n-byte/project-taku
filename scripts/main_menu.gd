extends Control

@export var show_debug_tools: bool = false

@onready var menu_center = $UILayer/CenterContainer
@onready var start_btn = $UILayer/CenterContainer/VBoxContainer/StartButton
@onready var levels_btn = $UILayer/CenterContainer/VBoxContainer/LevelSelectButton
@onready var how_to_play_btn = $UILayer/CenterContainer/VBoxContainer/HowToPlayButton
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
@onready var overlay_blocker = $UILayer/OverlayBlocker
@onready var credits_panel = $UILayer/OverlayBlocker/CreditsPanel
@onready var close_credits_btn = $UILayer/OverlayBlocker/CreditsPanel/VBoxContainer/CloseCreditsButton
@onready var _htp_host: Control = $UILayer/HowToPlayHost
@onready var _htp_panel: Panel = $UILayer/HowToPlayHost/HowToPlayPanel
@onready var _htp_rules: RichTextLabel = $UILayer/HowToPlayHost/HowToPlayPanel/RulesLabel
@onready var _htp_nav: HBoxContainer = $UILayer/HowToPlayHost/NavRow
@onready var _htp_prev: Button = $UILayer/HowToPlayHost/NavRow/PrevSlot/PrevButton
@onready var _htp_close: Button = $UILayer/HowToPlayHost/NavRow/CloseButton
@onready var _htp_next: Button = $UILayer/HowToPlayHost/NavRow/NextSlot/NextButton
@onready var _tutorial_intro_blocker: ColorRect = $UILayer/TutorialIntroBlocker
@onready var _tutorial_intro_label: Label = (
	$UILayer/TutorialIntroBlocker/CenterContainer/Panel/VBoxContainer/PromptLabel
)
@onready var _tutorial_intro_yes: Button = (
	$UILayer/TutorialIntroBlocker/CenterContainer/Panel/VBoxContainer/HBoxContainer/YesButton
)
@onready var _tutorial_intro_no: Button = (
	$UILayer/TutorialIntroBlocker/CenterContainer/Panel/VBoxContainer/HBoxContainer/NoButton
)

const TITLE_FONT_SIZE := 96
const TITLE_OUTLINE := 14
const MENU_BTN_FONT := 64
const MENU_BTN_OUTLINE := GameConstants.MENU_TEXT_OUTLINE
const CREDITS_HEADER_SIZE := 80
const CREDITS_HEADER_OUTLINE := 14
const CREDITS_BODY_SIZE := 54
const MENU_FADE_IN := 0.65

var _htp_header: Label
var _htp_page: int = 0

func _ready() -> void:
	_apply_debug_tools_visibility()
	_apply_editor_button_label()
	_refresh_start_button_label()
	_fit_menu_buttons()
	HudLayout.apply_locale_fonts_to_tree(self)
	_setup_title_under_fx()
	_setup_tutorial_intro_panel()
	_setup_how_to_play_overlay()
	if AdsManager:
		AdsManager.ensure_started()
		AdsManager.show_menu_banner()
	if SpaceBackground and SpaceBackground.has_method("set_foreground_events_enabled"):
		SpaceBackground.set_foreground_events_enabled(true)
	if SaveManager and not SaveManager.language_changed.is_connected(_on_language_changed):
		SaveManager.language_changed.connect(_on_language_changed)
	if start_btn: start_btn.pressed.connect(_on_start_pressed)
	if levels_btn: levels_btn.pressed.connect(_on_levels_pressed)
	if how_to_play_btn: how_to_play_btn.pressed.connect(_on_how_to_play_pressed)
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
	_mount_credits_header()

	if options_menu:
		options_menu.back_requested.connect(_on_options_back)
		if not options_menu.save_deleted.is_connected(_on_save_deleted):
			options_menu.save_deleted.connect(_on_save_deleted)

	if GlobalGameManager.main_menu_should_fade_in:
		GlobalGameManager.main_menu_should_fade_in = false
		_set_menu_ui_alpha(0.0)
		call_deferred("_fade_in_menu_ui")
		# Hard fallback: never leave the menu invisible on device if the tween fails.
		get_tree().create_timer(MENU_FADE_IN + 0.75).timeout.connect(_ensure_menu_ui_visible)

func _ensure_menu_ui_visible() -> void:
	_set_menu_ui_alpha(1.0)

func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if GlobalGameManager == null or not GlobalGameManager.consume_system_back():
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
	if _tutorial_intro_blocker and _tutorial_intro_blocker.visible:
		_hide_tutorial_intro_prompt()
		return
	GlobalGameManager.quit_app()

func _exit_tree() -> void:
	if SpaceBackground and SpaceBackground.has_method("set_foreground_events_enabled"):
		SpaceBackground.set_foreground_events_enabled(false)

## Fade title + menu chrome in over the persistent space background (post-splash).
func _menu_fade_targets() -> Array[CanvasItem]:
	var nodes: Array[CanvasItem] = []
	var title_host := get_node_or_null("TitleLayer/TitleHost") as CanvasItem
	if title_host:
		nodes.append(title_host)
	var center := menu_center as CanvasItem
	if center:
		nodes.append(center)
	var bar := debug_bar as CanvasItem
	if bar and debug_bar.visible:
		nodes.append(bar)
	return nodes

func _set_menu_ui_alpha(alpha: float) -> void:
	for node in _menu_fade_targets():
		if node:
			node.modulate.a = alpha

func _fade_in_menu_ui() -> void:
	var nodes := _menu_fade_targets()
	if nodes.is_empty():
		_set_menu_ui_alpha(1.0)
		return
	_set_menu_ui_alpha(0.0)
	var tween := create_tween()
	tween.set_parallel(true)
	for node in nodes:
		tween.tween_property(node, "modulate:a", 1.0, MENU_FADE_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Safety: never leave the menu stuck invisible if the tween is interrupted.
	if not tween.finished.is_connected(_ensure_menu_ui_visible):
		tween.finished.connect(_ensure_menu_ui_visible)

## Title + main menu buttons sit under FX; modal overlays stay above.
## P/O tiles are children of TitleLabel — edit their offsets relative to the title.
## Move TitleCluster to move the whole title (text + tiles) together.
func _setup_title_under_fx() -> void:
	var ui_layer := $UILayer as CanvasLayer
	if ui_layer:
		# Same band as the title so asteroids/comets can pass over menu buttons too.
		ui_layer.layer = 0
	var title_layer := get_node_or_null("TitleLayer") as CanvasLayer
	if title_layer:
		title_layer.layer = 0
	_ensure_overlays_above_fx()
	var title := get_node_or_null("TitleLayer/TitleHost/TitleCluster/TitleLabel") as Label
	if title:
		_style_title_label(title)
	var spacer := $UILayer/CenterContainer/VBoxContainer/Spacer as Control
	if spacer:
		spacer.custom_minimum_size.y = 20.0
	var vbox := $UILayer/CenterContainer/VBoxContainer as VBoxContainer
	if vbox:
		vbox.add_theme_constant_override("separation", 22)
	if menu_center:
		# Tall enough for PLAY + 4 rows (and EDITOR when debug is on) on phone viewports.
		HudLayout.pin_menu_body_below_header(menu_center, 1280.0)

## Credits / How To Play / tutorial prompt stay above flying FX.
func _ensure_overlays_above_fx() -> void:
	var ui_layer := $UILayer as CanvasLayer
	if ui_layer == null:
		return
	var overlay_layer := get_node_or_null("OverlayLayer") as CanvasLayer
	if overlay_layer == null:
		overlay_layer = CanvasLayer.new()
		overlay_layer.name = "OverlayLayer"
		# Above FxForeground (1); OptionsMenu uses 20 on its own.
		overlay_layer.layer = 5
		add_child(overlay_layer)
	for node_name in ["OverlayBlocker", "HowToPlayHost", "TutorialIntroBlocker"]:
		var node := ui_layer.get_node_or_null(node_name) as Node
		if node == null:
			continue
		if node.get_parent() == overlay_layer:
			continue
		ui_layer.remove_child(node)
		overlay_layer.add_child(node)

func _style_title_label(title: Label) -> void:
	# Brand title always uses the pixel font (even in Georgian); tiles stay title-relative.
	title.set_meta("_brand_title", true)
	title.set_meta("_screen_header", true)
	title.set_meta("_screen_header_font_size", TITLE_FONT_SIZE)
	title.set_meta("_screen_header_outline", TITLE_OUTLINE)
	HudLayout.apply_screen_header_style(title)

func _mount_credits_header() -> void:
	var credits_title = credits_panel.get_node_or_null("VBoxContainer/CreditsTitle") if credits_panel else null
	if credits_title and overlay_blocker:
		HudLayout.mount_screen_header(overlay_blocker, credits_title)
		credits_title.set_meta("_screen_header_font_size", CREDITS_HEADER_SIZE)
		credits_title.set_meta("_screen_header_outline", CREDITS_HEADER_OUTLINE)
		HudLayout.apply_screen_header_style(credits_title)
	_configure_credits_layout()

func _configure_credits_layout() -> void:
	if not credits_panel:
		return
	# Sit lower under the larger credits header.
	var top := (
		GameConstants.SCREEN_HEADER_TOP
		+ GameConstants.SCREEN_HEADER_HEIGHT
		+ GameConstants.SCREEN_CONTENT_GAP
		+ 40.0
	)
	credits_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	credits_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	credits_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	credits_panel.custom_minimum_size = Vector2(860, 900)
	credits_panel.offset_left = -430.0
	credits_panel.offset_right = 430.0
	credits_panel.offset_top = top
	credits_panel.offset_bottom = top + 900.0
	var vbox := credits_panel.get_node_or_null("VBoxContainer") as VBoxContainer
	if vbox:
		vbox.add_theme_constant_override("separation", 24)
		vbox.offset_top = 24.0
		vbox.offset_bottom = -24.0
	var credits_text = credits_panel.get_node_or_null("VBoxContainer/CreditsText") as RichTextLabel
	if credits_text:
		credits_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		credits_text.scroll_active = false
		credits_text.fit_content = false
		credits_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_position_credits_close()

func _position_credits_close() -> void:
	if close_credits_btn == null or overlay_blocker == null:
		return
	if close_credits_btn.get_parent() != overlay_blocker:
		var old := close_credits_btn.get_parent()
		if old:
			old.remove_child(close_credits_btn)
		overlay_blocker.add_child(close_credits_btn)
	close_credits_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	var half_w := GameConstants.UI_BTN_SECONDARY_SIZE.x * 0.5
	close_credits_btn.offset_left = -half_w
	close_credits_btn.offset_right = half_w
	close_credits_btn.offset_top = GameConstants.SCREEN_BOTTOM_NAV_TOP
	close_credits_btn.offset_bottom = GameConstants.SCREEN_BOTTOM_NAV_BOTTOM
	close_credits_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	close_credits_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	HudLayout.apply_secondary_button(close_credits_btn)

func _on_language_changed() -> void:
	_refresh_start_button_label()
	_fit_menu_buttons()
	HudLayout.apply_locale_fonts_to_tree(self)
	_refresh_how_to_play_text()

func _refresh_start_button_label() -> void:
	if not start_btn:
		return
	if SaveManager and SaveManager.has_session():
		start_btn.text = "UI_RESUME"
	else:
		start_btn.text = "UI_PLAY"

func _on_save_deleted() -> void:
	_refresh_start_button_label()
	_fit_menu_buttons()

func _fit_menu_buttons() -> void:
	for btn in [start_btn, levels_btn, how_to_play_btn, options_btn, credits_btn, editor_btn]:
		_apply_main_menu_button(btn)
	_fit_debug_bar_buttons()
	HudLayout.apply_secondary_button(close_credits_btn)
	var title = get_node_or_null("TitleLayer/TitleHost/TitleCluster/TitleLabel") as Label
	if title:
		_style_title_label(title)
	var credits_title = null
	if credits_panel:
		credits_title = credits_panel.get_node_or_null("VBoxContainer/CreditsTitle") as Label
	if credits_title == null and overlay_blocker:
		credits_title = overlay_blocker.get_node_or_null("CreditsTitle") as Label
	if credits_title:
		credits_title.set_meta("_screen_header_font_size", CREDITS_HEADER_SIZE)
		credits_title.set_meta("_screen_header_outline", CREDITS_HEADER_OUTLINE)
		HudLayout.apply_screen_header_style(credits_title)
	var credits_text_node = credits_panel.get_node_or_null("VBoxContainer/CreditsText") if credits_panel else null
	if credits_text_node:
		_apply_credits_fonts(credits_text_node)

## Text-only main-menu rows (no tile backgrounds), larger type.
func _apply_main_menu_button(button: Button) -> void:
	if not button:
		return
	var empty := StyleBoxEmpty.new()
	for style_name in ["normal", "pressed", "hover", "disabled", "focus"]:
		button.add_theme_stylebox_override(style_name, empty)
	button.flat = true
	# Georgian (and other non-English locales): default font; English keeps pixel UI font.
	button.set_meta("_use_default_font", not HudLayout.uses_pixel_font())
	var is_play: bool = button == start_btn
	# Keep rows short enough that all menu items fit on tall phone viewports.
	var row_h := 148.0 if is_play else 118.0
	var row_w := 780.0 if is_play else 720.0
	var font_size := 72 if is_play else MENU_BTN_FONT
	var min_font := 34 if is_play else 30
	button.custom_minimum_size = Vector2(row_w, row_h)
	button.add_theme_constant_override("outline_size", MENU_BTN_OUTLINE + (2 if is_play else 0))
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	# Keep Level Select on one line (no mid-phrase wrap).
	if button == levels_btn:
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.clip_text = false
		HudLayout.apply_locale_font_to_control(button)
		var font: Font = (
			ThemeDB.fallback_font if button.get_meta("_use_default_font", false) else HudLayout.ui_font()
		)
		var display := String(TranslationServer.translate(button.text))
		var fitted := HudLayout.scaled_font_size(MENU_BTN_FONT)
		var min_font_size := HudLayout.scaled_font_size(32)
		var target_w := maxf(40.0, button.custom_minimum_size.x - 28.0)
		while fitted > min_font_size:
			var measured := font.get_string_size(display, HORIZONTAL_ALIGNMENT_CENTER, -1, fitted)
			if measured.x <= target_w + 2.0:
				break
			fitted -= 2
		button.add_theme_font_size_override("font_size", fitted)
	else:
		HudLayout.fit_text_button(button, font_size, min_font)

func _fit_debug_bar_buttons() -> void:
	_position_debug_bar()
	_setup_debug_fx_button(debug_star_btn, [_FX_STAR])
	_setup_debug_fx_button(debug_asteroid_btn, [_FX_AST_1])
	_setup_debug_fx_button(debug_asteroid_cloud_btn, [_FX_AST_1, _FX_AST_2, _FX_AST_3])
	_setup_debug_fx_button(debug_comet_btn, [_FX_COMET_1])
	_setup_debug_fx_button(debug_comet_shower_btn, [_FX_COMET_1, _FX_COMET_2, _FX_COMET_3])

## Sit in the shared bottom nav band (same clearance as credits Close above the ad).
func _position_debug_bar() -> void:
	if debug_bar == null:
		return
	var bar := debug_bar as Control
	var btn_h := _DEBUG_BTN_SIZE.y
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = 12.0
	bar.offset_right = -12.0
	# Align with SCREEN_BOTTOM_NAV so native AdMob cannot cover the row.
	bar.offset_bottom = GameConstants.SCREEN_BOTTOM_NAV_BOTTOM
	bar.offset_top = bar.offset_bottom - btn_h
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.z_index = 8
	bar.mouse_filter = Control.MOUSE_FILTER_STOP

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
	# Original art is 16×16 crispEdges — integer scale stays sharp with NEAREST.
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
	# Cluster of 3 small icons for cloud / shower (scaled from 72px layout).
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

func _set_main_menu_chrome_visible(should_show: bool) -> void:
	if menu_center:
		menu_center.visible = should_show
	var title_layer := get_node_or_null("TitleLayer") as CanvasLayer
	if title_layer:
		title_layer.visible = should_show

func _apply_credits_fonts(credits_text_node: RichTextLabel) -> void:
	# English credits use the pixel UI font; other locales need default-font coverage.
	if HudLayout.uses_pixel_font():
		credits_text_node.set_meta("_use_default_font", false)
		HudLayout.apply_locale_font_to_control(credits_text_node)
		credits_text_node.add_theme_font_size_override(
			"normal_font_size", HudLayout.scaled_font_size(CREDITS_BODY_SIZE)
		)
		credits_text_node.add_theme_constant_override("outline_size", GameConstants.MENU_TEXT_OUTLINE)
	else:
		HudLayout.apply_body_richtext(credits_text_node, CREDITS_BODY_SIZE)
		credits_text_node.add_theme_constant_override("outline_size", GameConstants.MENU_TEXT_OUTLINE)
	credits_text_node.scroll_active = false
	credits_text_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _apply_editor_button_label() -> void:
	if not editor_btn:
		return
	editor_btn.text = "EDITOR"
	editor_btn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED

func _apply_debug_tools_visibility() -> void:
	GlobalGameManager.debug_tools_enabled = show_debug_tools
	if editor_btn:
		editor_btn.visible = show_debug_tools
	if debug_bar:
		debug_bar.visible = show_debug_tools

func _set_debug_bar_visible(should_show: bool) -> void:
	if debug_bar:
		debug_bar.visible = show_debug_tools and should_show

func _on_start_pressed() -> void:
	_apply_debug_tools_visibility()
	if SaveManager and not SaveManager.tutorial_intro_answered:
		_show_tutorial_intro_prompt()
		return
	_start_game()

func _start_game() -> void:
	GlobalGameManager.go_to_scene("res://scenes/main.tscn")

func _first_level_in_dir(dir_path: String) -> LevelData:
	var paths := LevelUtils.scan_directory(dir_path)
	LevelUtils.sort_level_paths(paths)
	for path in paths:
		var resource = load(path)
		if resource is LevelData:
			return resource
	return null

func _setup_how_to_play_overlay() -> void:
	if _htp_host:
		_htp_host.visible = false
		_htp_host.mouse_filter = Control.MOUSE_FILTER_STOP
	if _htp_rules:
		_htp_rules.set_meta("_use_default_font", true)
		_htp_rules.add_theme_color_override("default_color", Color.WHITE)
		_htp_rules.add_theme_color_override("font_outline_color", Color.BLACK)
		_htp_rules.add_theme_constant_override("outline_size", GameConstants.MENU_TEXT_OUTLINE)
	for btn in [_htp_prev, _htp_close, _htp_next]:
		_copy_menu_button_styles(btn)
	HudLayout.layout_how_to_play(_htp_host, _htp_panel, _htp_nav)
	HudLayout.ensure_how_to_play_nav_slots(_htp_nav, _htp_prev, _htp_next)
	_htp_header = HudLayout.ensure_how_to_play_page_header(_htp_host)
	_refresh_how_to_play_text()

func _refresh_how_to_play_text() -> void:
	if _htp_header == null and _htp_host:
		_htp_header = HudLayout.ensure_how_to_play_page_header(_htp_host)
	if _htp_header:
		_htp_header.text = tr(HowToPlayContent.get_page_title_key(_htp_page))
		HudLayout.apply_screen_header_style(_htp_header)
	if _htp_rules:
		HudLayout.apply_locale_font_to_control(_htp_rules)
		_htp_rules.text = HowToPlayContent.get_page_text(_htp_page)
	if _htp_prev:
		_htp_prev.text = tr("UI_PREVIOUS")
		_htp_prev.visible = _htp_page > 0
		HudLayout.apply_nav_button(_htp_prev)
	if _htp_next:
		_htp_next.text = tr("UI_NEXT")
		_htp_next.visible = _htp_page < HowToPlayContent.PAGE_COUNT - 1
		HudLayout.apply_nav_button(_htp_next)
	if _htp_close:
		_htp_close.text = tr("UI_CLOSE")
		HudLayout.apply_secondary_button(_htp_close)

func _on_htp_prev() -> void:
	_htp_page = maxi(_htp_page - 1, 0)
	_refresh_how_to_play_text()

func _on_htp_next() -> void:
	_htp_page = mini(_htp_page + 1, HowToPlayContent.PAGE_COUNT - 1)
	_refresh_how_to_play_text()

func _on_htp_close() -> void:
	if _htp_host:
		_htp_host.visible = false
	_set_main_menu_chrome_visible(true)
	_set_debug_bar_visible(true)

func _setup_tutorial_intro_panel() -> void:
	if _tutorial_intro_blocker:
		_tutorial_intro_blocker.visible = false
		_tutorial_intro_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := _tutorial_intro_blocker.get_node_or_null("CenterContainer/Panel") as Panel if _tutorial_intro_blocker else null
	if panel:
		panel.add_theme_stylebox_override("panel", HudLayout.make_dialog_panel_style())
	if _tutorial_intro_label:
		_tutorial_intro_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55, 1.0))
		_tutorial_intro_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_tutorial_intro_label.add_theme_constant_override("outline_size", GameConstants.MENU_TEXT_OUTLINE)
		HudLayout.apply_popup_label(_tutorial_intro_label, GameConstants.UI_BODY_FONT_SIZE_LARGE)
	_copy_menu_button_styles(_tutorial_intro_yes)
	_copy_menu_button_styles(_tutorial_intro_no)

func _copy_menu_button_styles(target: Button) -> void:
	var source: Button = start_btn if start_btn else options_btn
	if not source or not target:
		return
	# Prefer tiled chrome from options close / credits close when available.
	var style_source: Button = close_credits_btn if close_credits_btn else source
	for style_name in ["normal", "pressed", "hover", "disabled"]:
		var style := style_source.get_theme_stylebox(style_name)
		if style and not (style is StyleBoxEmpty):
			target.add_theme_stylebox_override(style_name, style)
	target.add_theme_color_override("font_outline_color", Color.BLACK)
	target.add_theme_constant_override("outline_size", GameConstants.MENU_TEXT_OUTLINE)

func _show_tutorial_intro_prompt() -> void:
	if _tutorial_intro_label:
		_tutorial_intro_label.text = tr("TUTORIAL_INTRO_PROMPT")
		HudLayout.apply_popup_label(_tutorial_intro_label, GameConstants.UI_BODY_FONT_SIZE_LARGE)
	if _tutorial_intro_yes:
		_tutorial_intro_yes.text = tr("UI_YES")
		HudLayout.apply_dialog_button(_tutorial_intro_yes)
	if _tutorial_intro_no:
		_tutorial_intro_no.text = tr("UI_NO")
		HudLayout.apply_dialog_button(_tutorial_intro_no)
	if _tutorial_intro_blocker:
		_tutorial_intro_blocker.visible = true
		_tutorial_intro_blocker.move_to_front()

func _hide_tutorial_intro_prompt() -> void:
	if _tutorial_intro_blocker:
		_tutorial_intro_blocker.visible = false

func _on_tutorial_intro_yes() -> void:
	_hide_tutorial_intro_prompt()
	SaveManager.set_tutorial_intro_answered(true)
	var tutorial := _first_level_in_dir(GameConstants.CAMPAIGN_TUTORIALS_DIR)
	if tutorial:
		GlobalGameManager.selected_level_resource = tutorial
	_start_game()

func _on_tutorial_intro_no() -> void:
	_hide_tutorial_intro_prompt()
	SaveManager.set_tutorial_intro_answered(true)
	var easy := _first_level_in_dir(GameConstants.CAMPAIGN_EASY_DIR)
	if easy:
		GlobalGameManager.selected_level_resource = easy
	_start_game()

func _on_levels_pressed() -> void:
	_apply_debug_tools_visibility()
	GlobalGameManager.go_to_scene("res://scenes/level_select.tscn")

func _on_how_to_play_pressed() -> void:
	_set_main_menu_chrome_visible(false)
	_set_debug_bar_visible(false)
	_htp_page = 0
	_refresh_how_to_play_text()
	if _htp_host:
		_htp_host.visible = true
		_htp_host.move_to_front()

func _on_options_pressed() -> void:
	_set_main_menu_chrome_visible(false)
	_set_debug_bar_visible(false)
	if options_menu:
		options_menu.show_menu(true)

func _on_options_back() -> void:
	_set_main_menu_chrome_visible(true)
	_set_debug_bar_visible(true)
	_refresh_start_button_label()
	_fit_menu_buttons()

func _on_credits_pressed() -> void:
	_set_main_menu_chrome_visible(false)
	_set_debug_bar_visible(false)
	if overlay_blocker: overlay_blocker.visible = true
	if credits_panel: credits_panel.visible = true
	var credits_text = credits_panel.get_node_or_null("VBoxContainer/CreditsText") if credits_panel else null
	if credits_text:
		credits_text.text = tr("CREDITS_TEXT")
		_apply_credits_fonts(credits_text)
	_position_credits_close()

func _on_close_credits() -> void:
	if overlay_blocker: overlay_blocker.visible = false
	if credits_panel: credits_panel.visible = false
	_set_main_menu_chrome_visible(true)
	_set_debug_bar_visible(true)

func _on_editor_pressed() -> void:
	GlobalGameManager.go_to_scene("res://scenes/level_editor.tscn")

func _on_debug_star_pressed() -> void:
	if SpaceBackground:
		SpaceBackground.debug_spawn_shooting_star()

func _on_debug_comet_pressed() -> void:
	if SpaceBackground:
		SpaceBackground.debug_spawn_comet()

func _on_debug_asteroid_pressed() -> void:
	if SpaceBackground:
		SpaceBackground.debug_spawn_asteroid()

func _on_debug_asteroid_cloud_pressed() -> void:
	if SpaceBackground:
		SpaceBackground.debug_spawn_asteroid_cloud()

func _on_debug_comet_shower_pressed() -> void:
	if SpaceBackground:
		SpaceBackground.debug_spawn_meteor_shower()
