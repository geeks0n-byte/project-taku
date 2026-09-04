class_name UiVictoryPanel
extends RefCounted
## Victory overlay: header, stars, preview, and action buttons.


var _panel: Control
var _win_label: Label
var _restart_button: Button
var _restart_label: Label
var _play_again_button: Button
var _play_again_label: Label
var _main_menu_button: Button
var _time_result_label: Label
var _results_host: Control
var _preview: TextureRect
var _set_dimmer_visible: Callable
var _set_dialog_raised: Callable

var _is_last_level_completed: bool = false
var _display_num: int = 0
var _is_custom: bool = false
var _is_tutorial: bool = false
var _star_result: Dictionary = {}


func bind(
	panel: Control,
	win_label: Label,
	restart_button: Button,
	restart_label: Label,
	play_again_button: Button,
	play_again_label: Label,
	main_menu_button: Button,
	time_result_label: Label,
	results_host: Control,
	preview: TextureRect,
	set_dimmer_visible: Callable,
	set_dialog_raised: Callable
) -> void:
	_panel = panel
	_win_label = win_label
	_restart_button = restart_button
	_restart_label = restart_label
	_play_again_button = play_again_button
	_play_again_label = play_again_label
	_main_menu_button = main_menu_button
	_time_result_label = time_result_label
	_results_host = results_host
	_preview = preview
	_set_dimmer_visible = set_dimmer_visible
	_set_dialog_raised = set_dialog_raised


func is_visible() -> bool:
	return _panel != null and _panel.visible


func hide_panel() -> void:
	if _panel:
		_panel.visible = false


func setup_chrome() -> void:
	_style_chrome()


func show(
	display_num: int,
	is_last_level: bool,
	star_result: Dictionary,
	is_custom: bool,
	is_tutorial: bool,
	solved_preview: Texture2D
) -> void:
	if _set_dialog_raised.is_valid():
		_set_dialog_raised.call(true, GameConstants.UI_VICTORY_RAISE_PX)
	_is_last_level_completed = is_last_level
	_display_num = display_num
	_is_custom = is_custom
	_is_tutorial = is_tutorial
	_star_result = star_result.duplicate(true)
	_style_chrome()
	if _set_dimmer_visible.is_valid():
		_set_dimmer_visible.call(true)
	refresh_locale()
	_populate_results(_star_result)
	_set_preview(solved_preview)
	_layout_panel(_star_result)
	if _panel:
		_panel.visible = true


func refresh_locale() -> void:
	if _win_label:
		if _is_last_level_completed:
			_win_label.text = _all_levels_completed_text() + "\n" + TranslationServer.translate("UI_YOU_WIN")
		elif _is_custom:
			_win_label.text = (
				(TranslationServer.translate("UI_CUSTOM_COMPLETED") % _display_num)
				+ "\n"
				+ TranslationServer.translate("UI_COMPLETED")
			)
		elif _is_tutorial:
			_win_label.text = TranslationServer.translate("TUTORIAL") + "\n" + TranslationServer.translate("UI_COMPLETED")
		else:
			_win_label.text = (
				(TranslationServer.translate("UI_LEVEL_COMPLETED") % _display_num)
				+ "\n"
				+ TranslationServer.translate("UI_COMPLETED")
			)
		HudLayout.apply_end_screen_header_style(_win_label, 48)
		_win_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_win_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _restart_label:
		_restart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		HudLayout.apply_raster_pixel_label(
			_restart_label,
			TranslationServer.translate("UI_NEXT_LEVEL"),
			GameConstants.UI_BTN_PANEL_FONT,
			Color.WHITE
		)
	elif _restart_button:
		_restart_button.text = TranslationServer.translate("UI_NEXT_LEVEL")
	if _restart_button:
		_restart_button.visible = not _is_last_level_completed
		if _restart_label == null:
			HudLayout.apply_raster_pixel_button(
				_restart_button,
				TranslationServer.translate("UI_NEXT_LEVEL"),
				GameConstants.UI_BTN_PANEL_FONT
			)
			HudLayout.grow_panel_button_to_text(_restart_button)
		else:
			HudLayout.apply_panel_button(_restart_button)
	if _play_again_label:
		_play_again_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		HudLayout.apply_raster_pixel_label(
			_play_again_label,
			TranslationServer.translate("UI_PLAY_AGAIN"),
			GameConstants.UI_BTN_PANEL_FONT,
			Color.WHITE
		)
	if _play_again_button:
		_play_again_button.visible = true
		HudLayout.apply_panel_button(_play_again_button)
	if _main_menu_button:
		var menu_label := _main_menu_button.get_node_or_null("HBoxContainer/Label") as Label
		if menu_label:
			menu_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			HudLayout.apply_raster_pixel_label(
				menu_label,
				TranslationServer.translate("UI_MAIN_MENU"),
				GameConstants.UI_BTN_PANEL_FONT,
				Color.WHITE
			)
		HudLayout.apply_panel_button(_main_menu_button)
	if _results_host and not _star_result.is_empty():
		_populate_results(_star_result)
	if is_visible():
		_layout_panel(_star_result)
	_apply_a11y_labels()


func _apply_a11y_labels() -> void:
	if _win_label:
		_win_label.accessibility_name = String(_win_label.text).strip_edges()
	A11yLabels.bind_button(_restart_button, "UI_NEXT_LEVEL")
	A11yLabels.bind_button(_play_again_button, "UI_PLAY_AGAIN")
	A11yLabels.bind_button(_main_menu_button, "UI_MAIN_MENU")


func _all_levels_completed_text() -> String:
	var text := String(TranslationServer.translate("UI_ALL_COMPLETED")).strip_edges()
	while text.ends_with("!") or text.ends_with("！"):
		text = text.substr(0, text.length() - 1).strip_edges()
	if text.begins_with("¡"):
		text = text.substr(1).strip_edges()
	return text


func _style_chrome() -> void:
	if _panel and _panel is Panel:
		(_panel as Panel).add_theme_stylebox_override("panel", HudLayout.make_dialog_panel_style())
	if _win_label:
		_win_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_win_label.offset_left = 28.0
		_win_label.offset_right = -28.0
		_win_label.offset_top = 24.0
		_win_label.offset_bottom = 220.0
		_win_label.clip_contents = false
		_win_label.clip_text = false
		_win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_win_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _raise_buttons() -> void:
	if _panel == null:
		return
	if _restart_button:
		_panel.move_child(_restart_button, -1)
	if _play_again_button:
		_panel.move_child(_play_again_button, -1)
	if _main_menu_button:
		_panel.move_child(_main_menu_button, -1)


func _set_preview(texture: Texture2D) -> void:
	if not _preview:
		return
	var frame := LevelPreview.ensure_preview_frame(_preview)
	_preview.texture = texture
	var should_show := texture != null
	_preview.visible = should_show
	if frame:
		frame.visible = should_show


## Replaces the solved-board thumbnail (e.g. after store-capture palette switch).
func set_preview_texture(texture: Texture2D) -> void:
	_set_preview(texture)
	if _panel and _panel.visible:
		_layout_panel(_star_result)


func _populate_results(star_result: Dictionary) -> void:
	if not _results_host:
		return
	if _time_result_label:
		_time_result_label.visible = false
	LevelStars.populate_results(_results_host, star_result)


func _layout_panel(star_result: Dictionary) -> void:
	if not _panel or not _results_host or not _preview:
		return
	_raise_buttons()
	if _play_again_button:
		_play_again_button.visible = true
	layout_stack(
		_panel,
		_win_label,
		_results_host,
		_preview,
		star_result,
		[_restart_button, _play_again_button, _main_menu_button],
		bool(star_result.get("untimed", false))
	)


## Shared victory geometry for campaign HUD and editor playtest.
static func layout_stack(
	panel: Control,
	title: Control,
	results_host: Control,
	preview: TextureRect,
	star_result: Dictionary,
	action_buttons: Array = [],
	untimed: bool = false,
	buttons_vbox: Control = null
) -> void:
	if panel == null:
		return
	var goal_count := int(star_result.get("total_count", 0))
	var panel_w := HudLayout.UI_MAX_DIALOG_WIDTH
	var title_top := 28.0
	var title_side := 24.0
	var title_h := 82.0
	if title is Label:
		var label := title as Label
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_h = maxf(
			82.0,
			HudDialogs.measure_label_height(label, panel_w - title_side * 2.0)
		)
		label.offset_left = title_side
		label.offset_right = -title_side
		label.offset_top = title_top
		label.offset_bottom = title_top + title_h
	var title_bottom := title_top + title_h
	var results_h := 0.0
	if not untimed:
		results_h = float(maxi(1, goal_count)) * (LevelStars.ROW_HEIGHT + 14.0) + 24.0
	if results_host:
		results_host.offset_top = title_bottom + 8.0
		results_host.offset_bottom = title_bottom + 8.0 + results_h

	var cursor := title_bottom + 8.0 + results_h
	var preview_h := 0.0
	var frame: PanelContainer = null
	if preview:
		frame = LevelPreview.ensure_preview_frame(preview)
	var show_preview := (
		preview != null
		and preview.visible
		and preview.texture != null
	)
	if show_preview:
		preview_h = LevelPreview.frame_outer_size(320.0)
		cursor += 24.0 if results_h > 0.0 else 16.0
		var half := preview_h * 0.5
		var target: Control = frame
		if target == null:
			target = preview
		target.offset_left = -half
		target.offset_right = half
		target.offset_top = cursor
		target.offset_bottom = cursor + preview_h
		cursor += preview_h
	elif frame:
		frame.visible = false

	var buttons_top := cursor + 28.0
	var buttons_bottom := buttons_top
	if buttons_vbox:
		var buttons_w := GameConstants.UI_BTN_PANEL_SIZE.x
		for child in buttons_vbox.get_children():
			if child is Control and (child as Control).visible:
				buttons_w = maxf(buttons_w, (child as Control).custom_minimum_size.x)
		var buttons_h := maxf(
			260.0,
			HudDialogs.measure_control_height(buttons_vbox, buttons_w)
		)
		var half_w := buttons_w * 0.5
		buttons_vbox.offset_left = -half_w
		buttons_vbox.offset_right = half_w
		buttons_vbox.offset_top = buttons_top
		buttons_vbox.offset_bottom = buttons_top + buttons_h
		buttons_bottom = buttons_top + buttons_h
	else:
		var row := 0
		for item in action_buttons:
			var button := item as Button
			if button == null or not button.visible:
				continue
			_place_action_button(button, buttons_top, row)
			row += 1
		buttons_bottom = buttons_top + float(row) * 130.0
	var height := buttons_bottom + 40.0 + HudDialogs.DIALOG_EXTRA_PAD_V
	var soft_min := 560.0 if preview_h > 0.0 else (400.0 if untimed else 520.0)
	panel.custom_minimum_size = Vector2(panel_w, maxf(soft_min, height))


static func _place_action_button(button: Button, buttons_top: float, row: int) -> void:
	if not button:
		return
	var top := buttons_top + float(row) * 130.0
	var min_size := GameConstants.UI_BTN_PANEL_SIZE
	var w := maxf(button.custom_minimum_size.x, min_size.x)
	var h := maxf(button.custom_minimum_size.y, min_size.y)
	button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	button.offset_left = -w * 0.5
	button.offset_right = w * 0.5
	button.offset_top = top
	button.offset_bottom = top + h
