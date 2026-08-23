extends Control

@export var show_debug_tools: bool = false

@onready var menu_center = $UILayer/CenterContainer
@onready var start_btn = $UILayer/CenterContainer/VBoxContainer/StartButton
@onready var tutorial_btn = $UILayer/CenterContainer/VBoxContainer/TutorialButton
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
@onready var credits_version_label: Label = $UILayer/OverlayBlocker/CreditsPanel/VersionLabel
@onready var close_credits_btn = $UILayer/OverlayBlocker/CloseCreditsButton
@onready var _htp_host: Control = $UILayer/HowToPlayHost
@onready var _htp_panel: Control = $UILayer/HowToPlayHost/HowToPlayPanel
@onready var _htp_nav: HBoxContainer = $UILayer/HowToPlayHost/NavRow
@onready var _htp_rules: RichTextLabel = $UILayer/HowToPlayHost/HowToPlayPanel/RulesLabel
@onready var _htp_prev: Button = $UILayer/HowToPlayHost/NavRow/PrevSlot/PrevButton
@onready var _htp_close: Button = $UILayer/HowToPlayHost/CloseButton
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
const CREDITS_BODY_SIZE := 48
const CREDITS_HEADER_SIZE := 42
const CREDITS_NAME_SIZE := 34
const CREDITS_HEADER_LOCALE_SIZE := 52
const CREDITS_NAME_LOCALE_SIZE := 42
const MENU_FADE_IN := 0.65

var _htp_header: Label
var _htp_page: int = 0

# Instance of consent_popup.tscn. Kept as a reference so we can check
# its visibility for the back-button handler.
var _consent_blocker: ColorRect

# Dev mode is unlocked by holding the version label in credits for _VERSION_HOLD_SEC seconds.
# This gives the developer access to debug tools in production builds without exposing them
# to players, and without storing the flag in the save file.
var _version_hold_active: bool = false
var _version_hold_elapsed: float = 0.0
const _VERSION_HOLD_SEC := 3.0

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
		AdsManager.warm_rewarded_hint()
	if SpaceBackground and SpaceBackground.has_method("set_foreground_events_enabled"):
		SpaceBackground.set_foreground_events_enabled(true)
	if SaveManager and not SaveManager.language_changed.is_connected(_on_language_changed):
		SaveManager.language_changed.connect(_on_language_changed)
	if start_btn: start_btn.pressed.connect(_on_start_pressed)
	if tutorial_btn: tutorial_btn.pressed.connect(_on_tutorial_pressed)
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
	_mount_credits_close_button()
	_build_consent_popup()

	if options_menu:
		options_menu.back_requested.connect(_on_options_back)
		if not options_menu.save_deleted.is_connected(_on_save_deleted):
			options_menu.save_deleted.connect(_on_save_deleted)

	if GlobalGameManager.main_menu_should_fade_in:
		GlobalGameManager.main_menu_should_fade_in = false
		# Survive an immediate Android pause during the boot fade.
		process_mode = Node.PROCESS_MODE_ALWAYS
		_set_menu_ui_alpha(0.0)
		call_deferred("_fade_in_menu_ui")

func _ensure_menu_ui_visible() -> void:
	_set_menu_ui_alpha(1.0)
	process_mode = Node.PROCESS_MODE_INHERIT

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
	if _consent_blocker and _consent_blocker.visible:
		GlobalGameManager.quit_app()
		return
	if _tutorial_intro_blocker and _tutorial_intro_blocker.visible:
		_hide_tutorial_intro_prompt()
		return
	GlobalGameManager.quit_app()

func _exit_tree() -> void:
	if SpaceBackground and SpaceBackground.has_method("set_foreground_events_enabled"):
		SpaceBackground.set_foreground_events_enabled(false)

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
	# PROCESS_MODE_ALWAYS: an early Android pause used to freeze this tween
	# while UI alpha was 0, leaving a black screen on resume.
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	for node in nodes:
		tween.tween_property(node, "modulate:a", 1.0, MENU_FADE_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if not tween.finished.is_connected(_ensure_menu_ui_visible):
		tween.finished.connect(_ensure_menu_ui_visible)
	# Wall-clock fallback if the app is suspended mid-fade.
	var tree := get_tree()
	if tree:
		var failsafe := tree.create_timer(MENU_FADE_IN + 0.35, true, false, true)
		failsafe.timeout.connect(_ensure_menu_ui_visible)

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

func _ensure_overlays_above_fx() -> void:
	var ui_layer := $UILayer as CanvasLayer
	if ui_layer == null:
		return
	var overlay_layer := get_node_or_null("OverlayLayer") as CanvasLayer
	if overlay_layer == null:
		overlay_layer = CanvasLayer.new()
		overlay_layer.name = "OverlayLayer"
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
	title.set_meta("_brand_title", true)
	title.set_meta("_screen_header", true)
	title.set_meta("_screen_header_font_size", TITLE_FONT_SIZE)
	title.set_meta("_screen_header_outline", TITLE_OUTLINE)
	HudLayout.apply_screen_header_style(title)

func _mount_credits_close_button() -> void:
	if close_credits_btn:
		HudLayout.style_top_bar_close_button(close_credits_btn)

func _on_language_changed() -> void:
	_refresh_start_button_label()
	_fit_menu_buttons()
	HudLayout.apply_locale_fonts_to_tree(self)
	HudLayout.clear_how_to_play_nav_lock(_htp_host)
	_refresh_how_to_play_text()
	if _consent_blocker and _consent_blocker.visible and _consent_blocker.has_method("refresh_locale"):
		_consent_blocker.refresh_locale()
	if _tutorial_intro_blocker and _tutorial_intro_blocker.visible:
		_show_tutorial_intro_prompt()

func _refresh_start_button_label() -> void:
	if not start_btn:
		return
	if SaveManager and SaveManager.has_session():
		start_btn.text = "UI_RESUME"
	else:
		start_btn.text = "UI_PLAY"
	start_btn.set_meta("_tr_key", start_btn.text)

func _on_save_deleted() -> void:
	_refresh_start_button_label()
	_fit_menu_buttons()
	# Privacy agreement is cleared with the profile — show consent immediately
	# (not only after a later main-menu reload via Level Select).
	_show_privacy_consent_if_needed(true)

func _fit_menu_buttons() -> void:
	for btn in [start_btn, tutorial_btn, levels_btn, how_to_play_btn, options_btn, credits_btn, editor_btn]:
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

func _fit_debug_bar_buttons() -> void:
	_setup_debug_fx_button(debug_star_btn, [_FX_STAR])
	_setup_debug_fx_button(debug_asteroid_btn, [_FX_AST_1])
	_setup_debug_fx_button(debug_asteroid_cloud_btn, [_FX_AST_1, _FX_AST_2, _FX_AST_3])
	_setup_debug_fx_button(debug_comet_btn, [_FX_COMET_1])
	_setup_debug_fx_button(debug_comet_shower_btn, [_FX_COMET_1, _FX_COMET_2, _FX_COMET_3])

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

func _set_main_menu_chrome_visible(should_show: bool) -> void:
	if menu_center:
		menu_center.visible = should_show
	var title_layer := get_node_or_null("TitleLayer") as CanvasLayer
	if title_layer:
		title_layer.visible = should_show

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

func _credits_author_single_line(text: String) -> String:
	return text.replace(" ", "\u00a0")

func _wrap_credits_nickname_pixel_font(text: String, pixel_sz: int) -> String:
	if not text.contains(CREDITS_NICKNAME):
		return text
	var pixel := "[font=%s][font_size=%d]%s[/font_size][/font]" % [
		HudLayout.PIXEL_FONT_PATH, pixel_sz, CREDITS_NICKNAME
	]
	return text.replace(CREDITS_NICKNAME, pixel)

func _wrap_credits_full_name_pixel_font(text: String, pixel_sz: int) -> String:
	return "[font=%s][font_size=%d]%s[/font_size][/font]" % [
		HudLayout.PIXEL_FONT_PATH, pixel_sz, text
	]

func _wrap_credits_author_name_display(author: String, pixel_sz: int) -> String:
	var single_line := _credits_author_single_line(author)
	if HudFonts.locale_code() == "ka":
		return _wrap_credits_nickname_pixel_font(single_line, pixel_sz)
	return _wrap_credits_full_name_pixel_font(single_line, pixel_sz)

func _wrap_credits_author_pixel_font(bbcode: String, body_sz: int, pixel_sz: int) -> String:
	var author := String(TranslationServer.translate("SPLASH_AUTHOR"))
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
	GlobalGameManager.debug_tools_enabled = _is_debug_enabled()
	_refresh_credits_version()
	if credits_version_label:
		var tw := create_tween()
		var target_color := Color(0.2, 1.0, 0.4, 1.0) if now_on else Color(1.0, 0.3, 0.3, 1.0)
		tw.tween_property(credits_version_label, "modulate", target_color, 0.15)
		tw.tween_property(credits_version_label, "modulate", Color.WHITE, 0.4)

func _apply_editor_button_label() -> void:
	if not editor_btn:
		return
	editor_btn.text = "UI_EDITOR"
	editor_btn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS

# Debug tools are enabled either via the export flag (editor/testing builds)
# or via the in-game dev mode unlock (runtime, session-only).
func _is_debug_enabled() -> bool:
	return show_debug_tools or (SaveManager != null and SaveManager.dev_mode_enabled)

func _apply_debug_tools_visibility() -> void:
	var enabled := _is_debug_enabled()
	GlobalGameManager.debug_tools_enabled = enabled
	if editor_btn:
		editor_btn.visible = enabled
	if debug_bar:
		debug_bar.visible = enabled

func _set_debug_bar_visible(should_show: bool) -> void:
	if debug_bar:
		debug_bar.visible = _is_debug_enabled() and should_show

func _on_tutorial_pressed() -> void:
	_apply_debug_tools_visibility()
	if SaveManager:
		SaveManager.set_tutorial_intro_answered(true)
	_ensure_easy_unlocked()
	_launch_tutorial()

func _on_start_pressed() -> void:
	_apply_debug_tools_visibility()
	_ensure_easy_unlocked()
	if SaveManager and not SaveManager.tutorial_intro_answered:
		_show_tutorial_intro_prompt()
		return
	_start_game()

func _start_game() -> void:
	GlobalGameManager.go_to_scene("res://scenes/main.tscn")

func _launch_tutorial() -> void:
	var tutorial := TutorialScripts.first_incomplete_level()
	if tutorial:
		GlobalGameManager.selected_level_resource = tutorial
	_start_game()

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
		HudLayout.apply_safe_outline(_htp_rules, GameConstants.MENU_TEXT_OUTLINE)
	for btn in [_htp_prev, _htp_next]:
		HudLayout.apply_nav_button(btn)
	if _htp_close:
		HudLayout.style_top_bar_close_button(_htp_close)
	_htp_header = HudLayout.ensure_how_to_play_page_header(_htp_host)
	_refresh_how_to_play_text()

func _refresh_how_to_play_text() -> void:
	if _htp_header == null and _htp_host:
		_htp_header = HudLayout.ensure_how_to_play_page_header(_htp_host)
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

func _layout_how_to_play_stack() -> void:
	HudLayout.layout_how_to_play_stack(
		_htp_host, _htp_panel, _htp_rules, _htp_nav, _htp_page == 0
	)

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

const _CONSENT_POPUP_SCENE := preload("res://scenes/consent_popup.tscn")

# Instantiates the consent popup scene and shows it on first launch.
# The popup blocks interaction with the main menu until the player accepts.
# On subsequent launches, privacy_accepted is true so the popup stays hidden.
func _build_consent_popup() -> void:
	var ui_layer := get_node_or_null("UILayer") as CanvasLayer
	if ui_layer == null:
		return
	var popup := _CONSENT_POPUP_SCENE.instantiate()
	ui_layer.add_child(popup)
	_consent_blocker = popup as ColorRect
	popup.accepted.connect(_on_consent_accepted)
	_bias_consent_popup_up()
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
	if SaveManager == null or SaveManager.privacy_accepted:
		return
	if _consent_blocker == null:
		return
	if close_options and options_menu and options_menu.visible:
		options_menu.visible = false
	_set_main_menu_chrome_visible(false)
	_set_debug_bar_visible(false)
	# Refresh copy/fonts for the current locale (reset can reopen after a language change).
	if _consent_blocker.has_method("refresh_locale"):
		_consent_blocker.refresh_locale()
	_consent_blocker.visible = true
	_consent_blocker.move_to_front()

# Called when the player taps ACCEPT on the consent popup.
# Saves acceptance, restores the main menu UI, and applies debug visibility.
func _on_consent_accepted() -> void:
	if SaveManager:
		SaveManager.accept_privacy()
	_set_main_menu_chrome_visible(true)
	_apply_debug_tools_visibility()

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

func _hide_tutorial_intro_prompt() -> void:
	if _tutorial_intro_blocker:
		_tutorial_intro_blocker.visible = false
	_set_main_menu_chrome_visible(true)
	_set_debug_bar_visible(true)

func _on_tutorial_intro_yes() -> void:
	_hide_tutorial_intro_prompt()
	SaveManager.set_tutorial_intro_answered(true)
	_ensure_easy_unlocked()
	_launch_tutorial()

func _on_tutorial_intro_no() -> void:
	_hide_tutorial_intro_prompt()
	SaveManager.set_tutorial_intro_answered(true)
	_ensure_easy_unlocked()
	var easy := _first_level_in_dir(GameConstants.CAMPAIGN_EASY_DIR)
	if easy:
		GlobalGameManager.selected_level_resource = easy
	_start_game()

func _ensure_easy_unlocked() -> void:
	if SaveManager == null:
		return
	SaveManager.unlock_level(LevelUtils.first_campaign_level_number())

func _on_levels_pressed() -> void:
	_apply_debug_tools_visibility()
	_ensure_easy_unlocked()
	GlobalGameManager.go_to_scene("res://scenes/level_select.tscn")

func _on_how_to_play_pressed() -> void:
	_set_main_menu_chrome_visible(false)
	_set_debug_bar_visible(false)
	_htp_page = 0
	HudLayout.clear_how_to_play_nav_lock(_htp_host)
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
	_show_privacy_consent_if_needed(false)

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

func _on_close_credits() -> void:
	if overlay_blocker: overlay_blocker.visible = false
	if credits_panel: credits_panel.visible = false
	_set_main_menu_chrome_visible(true)
	# Refresh editor + debug bar now that credits overlay is gone — dev mode may
	# have been toggled while credits was open and _toggle_dev_mode intentionally
	# skips visibility changes until we return to the main menu.
	_apply_debug_tools_visibility()
	_fit_menu_buttons()

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
