class_name LevelSelectGoalsPopup
extends RefCounted
## Star-goals overlay for the level-select screen.


const PANEL_WIDTH := 720.0
const TITLE_FONT := 36
const TITLE_COLOR := Color(1.0, 0.92, 0.55, 1.0)

var _blocker: ColorRect
var _title: RichTextLabel
var _host: Control
var _play: Button
var _close: Button
var _overlay_z: int = 30
var _current_level: LevelData = null
var _get_title_num: Callable
var _style_dialog_button: Callable


func bind(
	blocker: ColorRect,
	title: RichTextLabel,
	host: Control,
	play: Button,
	close_btn: Button,
	overlay_z: int,
	get_title_num: Callable,
	style_dialog_button: Callable
) -> void:
	_blocker = blocker
	_title = title
	_host = host
	_play = play
	_close = close_btn
	_overlay_z = overlay_z
	_get_title_num = get_title_num
	_style_dialog_button = style_dialog_button


func setup(play_pressed: Callable, close_pressed: Callable) -> void:
	if _blocker == null:
		return
	_blocker.visible = false
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.color = Color(0, 0, 0, 0.45)
	_blocker.z_index = _overlay_z
	if not _blocker.gui_input.is_connected(_on_blocker_gui_input):
		_blocker.gui_input.connect(_on_blocker_gui_input)
	var center := _blocker.get_node_or_null("CenterContainer") as Control
	if center:
		HudLayout.raise_centered_dialog_host(center)
	var panel := _blocker.get_node_or_null("CenterContainer/Panel") as Panel
	if panel:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.add_theme_stylebox_override("panel", HudLayout.make_dialog_panel_style())
	if _play and not _play.pressed.is_connected(play_pressed):
		_play.pressed.connect(play_pressed)
	if _close and not _close.pressed.is_connected(close_pressed):
		_close.pressed.connect(close_pressed)
	if _style_dialog_button.is_valid():
		_style_dialog_button.call(_play)
		_style_dialog_button.call(_close)


func current_level() -> LevelData:
	return _current_level


func hide() -> void:
	_current_level = null
	if _blocker:
		_blocker.visible = false


func show_for_level(level: LevelData, earned_bits: int) -> void:
	if _blocker == null or _host == null or level == null:
		return
	_current_level = level
	var title_num := String(_get_title_num.call(level)) if _get_title_num.is_valid() else str(level.level_number)
	_title.text = "%s %s" % [TranslationServer.translate("UI_LEVEL"), title_num]
	HudLayout.apply_popup_title_with_number(
		_title, TranslationServer.translate("UI_LEVEL"), title_num, TITLE_FONT, TITLE_COLOR
	)
	if _play:
		_play.text = TranslationServer.translate("UI_PLAY")
		if _style_dialog_button.is_valid():
			_style_dialog_button.call(_play)
		HudLayout.apply_dialog_button(_play)
	if _close:
		_close.text = TranslationServer.translate("UI_CLOSE")
		if _style_dialog_button.is_valid():
			_style_dialog_button.call(_close)
		HudLayout.apply_dialog_button(_close)
	var panel := _blocker.get_node_or_null("CenterContainer/Panel") as Panel
	while _host.get_child_count() > 0:
		_host.get_child(0).free()
	LevelStars.populate_requirements(
		_host, level, earned_bits, LevelStars.RESULTS_CONTENT_WIDTH, true
	)
	if panel:
		var content_w := HudLayout.fit_dialog_panel(panel, PANEL_WIDTH, 420.0)
		if _host.get_child_count() > 0:
			var stars_root := _host.get_child(0) as Control
			if stars_root:
				_host.custom_minimum_size.y = HudDialogs.measure_control_height(
					stars_root, minf(content_w, LevelStars.RESULTS_CONTENT_WIDTH)
				)
		HudLayout.fit_dialog_panel(panel, PANEL_WIDTH, 420.0)
	_blocker.visible = true
	_blocker.move_to_front()
	_apply_a11y_labels()


func _apply_a11y_labels() -> void:
	if _title:
		_title.accessibility_name = A11yLabels.strip_bbcode(String(_title.text))
	A11yLabels.bind_button(_play, "UI_PLAY")
	A11yLabels.bind_button(_close, "UI_CLOSE")


func _on_blocker_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide()
