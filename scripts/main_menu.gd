extends Control

@export var show_debug_tools: bool = false

@onready var menu_center = $UILayer/CenterContainer
@onready var start_btn = $UILayer/CenterContainer/VBoxContainer/StartButton
@onready var levels_btn = $UILayer/CenterContainer/VBoxContainer/LevelSelectButton
@onready var options_btn = $UILayer/CenterContainer/VBoxContainer/OptionsButton
@onready var credits_btn = $UILayer/CenterContainer/VBoxContainer/CreditsButton
@onready var editor_btn = $UILayer/CenterContainer/VBoxContainer/EditorButton
@onready var debug_bar = $UILayer/DebugBar
@onready var debug_star_btn = $UILayer/DebugBar/DebugStarButton
@onready var debug_comet_btn = $UILayer/DebugBar/DebugCometButton
@onready var debug_asteroid_btn = $UILayer/DebugBar/DebugAsteroidButton
@onready var debug_asteroid_cloud_btn = $UILayer/DebugBar/DebugAsteroidCloudButton
@onready var debug_comet_shower_btn = $UILayer/DebugBar/DebugCometShowerButton

@onready var options_menu = $UILayer/OptionsMenu
@onready var overlay_blocker = $UILayer/OverlayBlocker
@onready var credits_panel = $UILayer/OverlayBlocker/CreditsPanel
@onready var close_credits_btn = $UILayer/OverlayBlocker/CreditsPanel/VBoxContainer/CloseCreditsButton

var _tutorial_intro_blocker: ColorRect
var _tutorial_intro_label: Label
var _tutorial_intro_yes: Button
var _tutorial_intro_no: Button

func _ready() -> void:
	_apply_debug_tools_visibility()
	_apply_editor_button_label()
	_refresh_start_button_label()
	_fit_menu_buttons()
	HudLayout.apply_locale_fonts_to_tree(self)
	_setup_title_under_fx()
	_build_tutorial_intro_panel()
	if SpaceBackground and SpaceBackground.has_method("set_foreground_events_enabled"):
		SpaceBackground.set_foreground_events_enabled(true)
	if SaveManager and not SaveManager.language_changed.is_connected(_on_language_changed):
		SaveManager.language_changed.connect(_on_language_changed)
	if start_btn: start_btn.pressed.connect(_on_start_pressed)
	if levels_btn: levels_btn.pressed.connect(_on_levels_pressed)
	if options_btn: options_btn.pressed.connect(_on_options_pressed)
	if credits_btn: credits_btn.pressed.connect(_on_credits_pressed)
	if editor_btn: editor_btn.pressed.connect(_on_editor_pressed)
	if debug_star_btn: debug_star_btn.pressed.connect(_on_debug_star_pressed)
	if debug_comet_btn: debug_comet_btn.pressed.connect(_on_debug_comet_pressed)
	if debug_asteroid_btn: debug_asteroid_btn.pressed.connect(_on_debug_asteroid_pressed)
	if debug_asteroid_cloud_btn: debug_asteroid_cloud_btn.pressed.connect(_on_debug_asteroid_cloud_pressed)
	if debug_comet_shower_btn: debug_comet_shower_btn.pressed.connect(_on_debug_comet_shower_pressed)

	if close_credits_btn: close_credits_btn.pressed.connect(_on_close_credits)
	_mount_credits_header()

	if options_menu:
		options_menu.back_requested.connect(_on_options_back)
		if not options_menu.save_deleted.is_connected(_on_save_deleted):
			options_menu.save_deleted.connect(_on_save_deleted)

func _exit_tree() -> void:
	if SpaceBackground and SpaceBackground.has_method("set_foreground_events_enabled"):
		SpaceBackground.set_foreground_events_enabled(false)

## Title sits under FX (layer 1); menu buttons stay above FX.
func _setup_title_under_fx() -> void:
	var ui_layer := $UILayer as CanvasLayer
	if ui_layer:
		ui_layer.layer = 2
	var title := $UILayer/CenterContainer/VBoxContainer/TitleLabel as Label
	if not title:
		return
	var title_layer := CanvasLayer.new()
	title_layer.name = "TitleLayer"
	title_layer.layer = 0
	add_child(title_layer)
	var host := Control.new()
	host.name = "TitleHost"
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_layer.add_child(host)
	# Keep vertical placement roughly where the centered title sat.
	var parent := title.get_parent()
	if parent:
		parent.remove_child(title)
	host.add_child(title)
	# Same vertical slot as Options / Level Select / Credits / Pause headers.
	title.set_meta("_screen_header_font_size", 80)
	HudLayout.apply_screen_header_style(title)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = GameConstants.HUD_SIDE_MARGIN
	title.offset_right = -GameConstants.HUD_SIDE_MARGIN
	title.offset_top = GameConstants.SCREEN_HEADER_TOP
	title.offset_bottom = GameConstants.SCREEN_HEADER_TOP + GameConstants.SCREEN_HEADER_HEIGHT
	# Shrink leftover spacer now that the title lives outside the VBox.
	var spacer := $UILayer/CenterContainer/VBoxContainer/Spacer as Control
	if spacer:
		spacer.custom_minimum_size.y = 48.0
	if menu_center:
		HudLayout.pin_menu_body_below_header(menu_center, 980.0)

func _mount_credits_header() -> void:
	var credits_title = credits_panel.get_node_or_null("VBoxContainer/CreditsTitle") if credits_panel else null
	if credits_title and overlay_blocker:
		HudLayout.mount_screen_header(overlay_blocker, credits_title)
	_configure_credits_layout()

func _configure_credits_layout() -> void:
	if not credits_panel:
		return
	# Sit the panel under the shared header band (not vertically centered).
	var top := (
		GameConstants.SCREEN_HEADER_TOP
		+ GameConstants.SCREEN_HEADER_HEIGHT
		+ GameConstants.SCREEN_CONTENT_GAP
	)
	credits_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	credits_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	credits_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	credits_panel.custom_minimum_size = Vector2(820, 780)
	credits_panel.offset_left = -410.0
	credits_panel.offset_right = 410.0
	credits_panel.offset_top = top
	credits_panel.offset_bottom = top + 780.0
	var vbox := credits_panel.get_node_or_null("VBoxContainer") as VBoxContainer
	if vbox:
		vbox.add_theme_constant_override("separation", 18)
		vbox.offset_top = 24.0
		vbox.offset_bottom = -24.0
	var credits_text = credits_panel.get_node_or_null("VBoxContainer/CreditsText") as RichTextLabel
	if credits_text:
		credits_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		credits_text.scroll_active = false
		credits_text.fit_content = false
		credits_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _on_language_changed() -> void:
	_refresh_start_button_label()
	_fit_menu_buttons()
	HudLayout.apply_locale_fonts_to_tree(self)

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
	for btn in [start_btn, levels_btn, options_btn, credits_btn, editor_btn]:
		HudLayout.apply_primary_button(btn)
	HudLayout.apply_secondary_button(close_credits_btn)
	var title = get_node_or_null("TitleLayer/TitleHost/TitleLabel") as Label
	if title == null:
		title = get_node_or_null("UILayer/CenterContainer/VBoxContainer/TitleLabel") as Label
	if title:
		title.set_meta("_screen_header_font_size", 80)
		HudLayout.apply_screen_header_style(title)
	var credits_text_node = credits_panel.get_node_or_null("VBoxContainer/CreditsText") if credits_panel else null
	if credits_text_node:
		_apply_credits_fonts(credits_text_node)

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
			"normal_font_size", HudLayout.scaled_font_size(GameConstants.UI_BODY_FONT_SIZE)
		)
	else:
		HudLayout.apply_body_richtext(credits_text_node, GameConstants.UI_BODY_FONT_SIZE)
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
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _first_level_in_dir(dir_path: String) -> LevelData:
	var paths := LevelUtils.scan_directory(dir_path)
	LevelUtils.sort_level_paths(paths)
	for path in paths:
		var resource = load(path)
		if resource is LevelData:
			return resource
	return null

func _build_tutorial_intro_panel() -> void:
	var ui_layer := $UILayer as CanvasLayer
	if ui_layer == null:
		return
	_tutorial_intro_blocker = ColorRect.new()
	_tutorial_intro_blocker.name = "TutorialIntroBlocker"
	_tutorial_intro_blocker.color = Color(0, 0, 0, 0.72)
	_tutorial_intro_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tutorial_intro_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_tutorial_intro_blocker.visible = false
	ui_layer.add_child(_tutorial_intro_blocker)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tutorial_intro_blocker.add_child(center)

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(680, 380)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.12, 1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 36.0
	vbox.offset_top = 36.0
	vbox.offset_right = -36.0
	vbox.offset_bottom = -36.0
	vbox.add_theme_constant_override("separation", 28)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	_tutorial_intro_label = Label.new()
	_tutorial_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tutorial_intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tutorial_intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tutorial_intro_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tutorial_intro_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55, 1.0))
	_tutorial_intro_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_tutorial_intro_label.add_theme_constant_override("outline_size", 8)
	HudLayout.apply_popup_label(_tutorial_intro_label, GameConstants.UI_BODY_FONT_SIZE_LARGE)
	vbox.add_child(_tutorial_intro_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	vbox.add_child(row)

	_tutorial_intro_yes = Button.new()
	_tutorial_intro_yes.pressed.connect(_on_tutorial_intro_yes)
	row.add_child(_tutorial_intro_yes)

	_tutorial_intro_no = Button.new()
	_tutorial_intro_no.pressed.connect(_on_tutorial_intro_no)
	row.add_child(_tutorial_intro_no)

	_copy_menu_button_styles(_tutorial_intro_yes)
	_copy_menu_button_styles(_tutorial_intro_no)

func _copy_menu_button_styles(target: Button) -> void:
	var source: Button = start_btn if start_btn else options_btn
	if not source or not target:
		return
	for style_name in ["normal", "pressed", "hover", "disabled"]:
		var style := source.get_theme_stylebox(style_name)
		if style:
			target.add_theme_stylebox_override(style_name, style)
	target.add_theme_color_override("font_outline_color", Color.BLACK)
	target.add_theme_constant_override("outline_size", 6)

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
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")

func _on_options_pressed() -> void:
	_set_main_menu_chrome_visible(false)
	_set_debug_bar_visible(false)
	if options_menu:
		options_menu.show_menu()

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

func _on_close_credits() -> void:
	if overlay_blocker: overlay_blocker.visible = false
	if credits_panel: credits_panel.visible = false
	_set_main_menu_chrome_visible(true)
	_set_debug_bar_visible(true)

func _on_editor_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level_editor.tscn")

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
