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

var _boot_intro: BootIntroController
var _debug_bar_helper: MainMenuDebugBar = MainMenuDebugBar.new()
var _htp: MainMenuHowToPlay = MainMenuHowToPlay.new()
var _credits: MainMenuCreditsOverlay = MainMenuCreditsOverlay.new()
var _tutorial: MainMenuTutorialIntro = MainMenuTutorialIntro.new()
var _consent: MainMenuConsentController = MainMenuConsentController.new()
var _menu_badges: MainMenuBadges = MainMenuBadges.new()


# Wires menu buttons, overlays, ads, and optionally starts the boot intro.
func _ready() -> void:
	_boot_intro = BootIntroController.new()
	add_child(_boot_intro)
	_boot_intro.setup(self)
	_boot_intro.privacy_consent_requested.connect(_consent.show_if_needed.bind(false))

	_debug_bar_helper.setup(
		show_debug_tools,
		editor_btn,
		debug_bar,
		debug_star_btn,
		debug_asteroid_btn,
		debug_asteroid_cloud_btn,
		debug_comet_btn,
		debug_comet_shower_btn
	)
	_debug_bar_helper.bind_signals()

	_htp.setup(
		_htp_host,
		_htp_header,
		_htp_panel,
		_htp_nav,
		_htp_rules,
		_htp_prev,
		_htp_close,
		_htp_next,
		set_menu_chrome_visible
	)
	_htp.setup_overlay()
	_htp.bind_signals()

	_credits.setup(
		self,
		show_debug_tools,
		overlay_blocker,
		credits_panel,
		credits_version_label,
		close_credits_btn,
		set_menu_chrome_visible
	)
	_credits.on_closed = _on_credits_closed
	_credits.mount_close_button()
	_credits.bind_signals()

	_tutorial.setup(
		_tutorial_intro_blocker,
		_tutorial_intro_label,
		_tutorial_intro_yes,
		_tutorial_intro_no,
		set_menu_chrome_visible,
		_launch_tutorial_from_intro,
		_start_easy_campaign_from_intro
	)
	_tutorial.setup_panel()
	_tutorial.bind_signals()

	_consent.setup(
		self,
		get_node_or_null("OverlayLayer") as CanvasLayer,
		options_menu,
		_boot_intro,
		set_menu_chrome_visible,
		_set_button_ui_alpha,
		_apply_debug_tools_visibility,
		_set_boot_menu_input_enabled
	)

	_apply_debug_tools_visibility()
	_apply_editor_button_label()
	_refresh_start_button_label()
	_fit_menu_buttons()
	HudLayout.apply_locale_fonts_to_tree(self)
	_setup_title_under_fx()
	if AdsManager:
		AdsManager.ensure_started()
		AdsManager.show_menu_banner()
		AdsManager.warm_rewarded_hint()
	if SpaceBackground and SpaceBackground.has_method("set_foreground_events_enabled"):
		if not _boot_intro.is_active():
			SpaceBackground.set_foreground_events_enabled(true)
	if SaveManager and not SaveManager.language_changed.is_connected(_on_language_changed):
		SaveManager.language_changed.connect(_on_language_changed)
	if start_btn:
		start_btn.pressed.connect(_on_start_pressed)
	if tutorial_btn:
		tutorial_btn.pressed.connect(_on_tutorial_pressed)
	if levels_btn:
		levels_btn.pressed.connect(_on_levels_pressed)
	if how_to_play_btn:
		how_to_play_btn.pressed.connect(_on_how_to_play_pressed)
	if achievements_btn:
		achievements_btn.pressed.connect(_on_achievements_pressed)
	_menu_badges.setup(menu_center, achievements_btn, levels_btn)
	_menu_badges.setup_panels()
	_menu_badges.bind_resize_hooks()
	if AchievementManager:
		if not AchievementManager.unseen_count_changed.is_connected(_refresh_achievements_badge):
			AchievementManager.unseen_count_changed.connect(_refresh_achievements_badge)
	_refresh_achievements_badge()
	if SaveManager and not SaveManager.unseen_levels_changed.is_connected(_refresh_levels_badge):
		SaveManager.unseen_levels_changed.connect(_refresh_levels_badge)
	_refresh_levels_badge()
	if options_btn:
		options_btn.pressed.connect(_on_options_pressed)
	if credits_btn:
		credits_btn.pressed.connect(_on_credits_pressed)
	if editor_btn:
		editor_btn.pressed.connect(_on_editor_pressed)

	_consent.build_popup()
	_apply_safe_area_layout()
	if not get_viewport().size_changed.is_connected(_on_safe_area_viewport_resized):
		get_viewport().size_changed.connect(_on_safe_area_viewport_resized)

	if options_menu:
		options_menu.back_requested.connect(_on_options_back)
		if not options_menu.save_deleted.is_connected(_on_save_deleted):
			options_menu.save_deleted.connect(_on_save_deleted)

	if GlobalGameManager.main_menu_should_fade_in:
		GlobalGameManager.main_menu_should_fade_in = false
		process_mode = Node.PROCESS_MODE_ALWAYS
		_boot_intro.begin(needs_privacy_consent())
	elif not _boot_intro.is_active():
		_consent.show_if_needed(false)


func needs_privacy_consent() -> bool:
	return SaveManager != null and not SaveManager.privacy_accepted


func set_menu_chrome_visible(should_show: bool, preserve_title_on_hide: bool = false) -> void:
	if menu_center:
		menu_center.visible = should_show
	_debug_bar_helper.set_bar_visible(should_show)
	var title_layer := get_node_or_null("TitleLayer") as CanvasLayer
	if title_layer:
		if should_show:
			title_layer.visible = true
		elif preserve_title_on_hide and _boot_intro.is_active():
			title_layer.visible = true
		else:
			title_layer.visible = false


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
	_debug_bar_helper.set_boot_menu_input_enabled(enabled)


# Skip-intro tap: eat the press/release so it does not hit a menu button.
func _input(event: InputEvent) -> void:
	if _boot_intro.get_eat_intro_pointer():
		get_viewport().set_input_as_handled()
		if _is_primary_pointer_release(event):
			_boot_intro.set_eat_intro_pointer(false)
			call_deferred("_set_boot_menu_input_enabled", true)
		return
	if not _boot_intro.is_active():
		return
	if _consent.is_blocking():
		return
	if _tutorial.is_blocking():
		return
	if not _boot_intro.can_skip(needs_privacy_consent()):
		return
	if not _is_primary_pointer_press(event):
		return
	_boot_intro.set_eat_intro_pointer(true)
	get_viewport().set_input_as_handled()
	_boot_intro.skip_to_end()


# Android back: close overlays first, then quit.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if GlobalGameManager == null or not GlobalGameManager.consume_system_back():
		return
	if AchievementManager and AchievementManager.is_list_open():
		AchievementManager.hide_list()
		return
	if _htp.handle_back():
		return
	if _credits.handle_back():
		return
	if options_menu and options_menu.visible:
		if options_menu.has_method("handle_system_back"):
			options_menu.handle_system_back()
		elif options_menu.has_method("hide_menu"):
			options_menu.hide_menu()
		return
	if _consent.handle_back():
		return
	if _tutorial.handle_back():
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
	var bar := _debug_bar_helper.fade_target()
	if bar:
		nodes.append(bar)
	return nodes


# Sets modulate.a on every boot-intro fade target.
func _set_button_ui_alpha(alpha: float) -> void:
	for node in _button_fade_targets():
		if node:
			node.modulate.a = alpha


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


# Rebuilds menu fonts, HTP copy, and safe-area after a locale switch.
func _on_language_changed() -> void:
	_refresh_start_button_label()
	_fit_menu_buttons()
	HudLayout.apply_locale_fonts_to_tree(self)
	if _htp.is_blocking():
		HudLayout.clear_how_to_play_nav_lock(_htp_host)
	_htp.refresh_text()
	_apply_safe_area_layout()
	_consent.refresh_locale_if_visible()
	if _tutorial.is_blocking():
		_tutorial.show_prompt()


# Viewport resized: recompute menu + debug-bar safe-area padding.
func _on_safe_area_viewport_resized() -> void:
	_apply_safe_area_layout()
	_boot_intro.layout_splash()


# Pads the menu column and debug bar away from notches / nav bars.
func _apply_safe_area_layout() -> void:
	HudLayout.apply_content_edge_safe_area(menu_center)
	_debug_bar_helper.apply_safe_area_layout()


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
	_consent.show_if_needed(true)


# Sizes/fonts menu buttons, title, debug bar, and credits text.
func _fit_menu_buttons() -> void:
	for btn in [start_btn, tutorial_btn, levels_btn, how_to_play_btn, achievements_btn, options_btn, credits_btn, editor_btn]:
		_apply_main_menu_button(btn)
	_debug_bar_helper.fit_buttons()
	_credits.mount_close_button()
	var title = get_node_or_null("TitleLayer/TitleHost/TitleCluster/TitleLabel") as Label
	if title:
		_style_title_label(title)
	var credits_text_node = credits_panel.get_node_or_null("CreditsText") if credits_panel else null
	if credits_text_node:
		_credits.apply_credits_fonts(credits_text_node)
	_menu_badges.layout.call_deferred()


# Flat menu row: Press Start for Latin, locale font otherwise.
func _apply_main_menu_button(button: Button) -> void:
	if not button:
		return
	var empty := StyleBoxEmpty.new()
	for style_name in ["normal", "pressed", "hover", "disabled", "focus"]:
		button.add_theme_stylebox_override(style_name, empty)
	button.flat = true
	button.set_meta("_force_pixel_font", false)
	var is_play: bool = button == start_btn
	var row_h := 148.0 if is_play else 118.0
	var row_w := 780.0 if is_play else 720.0
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


# Shows Editor + debug bar when export flag or session dev mode is on.
func _apply_debug_tools_visibility() -> void:
	_debug_bar_helper.apply_visibility()


# Sets the Editor row translation key.
func _apply_editor_button_label() -> void:
	if not editor_btn:
		return
	editor_btn.text = "UI_EDITOR"
	editor_btn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS


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
		_tutorial.show_prompt()
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


func _launch_tutorial_from_intro() -> void:
	_ensure_easy_unlocked()
	_launch_tutorial()


func _start_easy_campaign_from_intro() -> void:
	_ensure_easy_unlocked()
	var easy := _first_level_in_dir(GameConstants.CAMPAIGN_EASY_DIR)
	if easy:
		GlobalGameManager.selected_level_resource = easy
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
	_htp.open()


# Hides menu chrome and shows the achievements overlay.
func _on_achievements_pressed() -> void:
	set_menu_chrome_visible(false)
	if AchievementManager:
		AchievementManager.show_list(_on_achievements_closed)
	else:
		set_menu_chrome_visible(true)


## Restores menu after the achievements list closes.
func _on_achievements_closed() -> void:
	set_menu_chrome_visible(true)
	_refresh_achievements_badge()
	_refresh_levels_badge()
	_fit_menu_buttons()


func _refresh_achievements_badge(_count: int = -1) -> void:
	_menu_badges.refresh_achievements(_count)


func _refresh_levels_badge(_count: int = -1) -> void:
	_menu_badges.refresh_levels(_count)


# Hides menu chrome and shows the options overlay.
func _on_options_pressed() -> void:
	set_menu_chrome_visible(false)
	if options_menu:
		options_menu.show_menu(true)


# Restores menu after Options; may re-show consent after a profile reset.
func _on_options_back() -> void:
	set_menu_chrome_visible(true)
	_refresh_start_button_label()
	_fit_menu_buttons()
	_refresh_achievements_badge()
	_refresh_levels_badge()
	_consent.show_if_needed(false)


# Hides menu chrome and shows credits.
func _on_credits_pressed() -> void:
	_credits.open()


# Closes credits and refreshes debug visibility (dev mode may have toggled).
func _on_credits_closed() -> void:
	_apply_debug_tools_visibility()
	_fit_menu_buttons()
	_refresh_achievements_badge()
	_refresh_levels_badge()


# Opens the level editor.
func _on_editor_pressed() -> void:
	GlobalGameManager.go_to_scene("res://scenes/level_editor.tscn")
