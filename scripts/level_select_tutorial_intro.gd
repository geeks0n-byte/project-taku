class_name LevelSelectTutorialIntro
extends RefCounted
## First-run tutorial Yes/No prompt on the level-select screen.


var _blocker: ColorRect
var _label: Label
var _yes_btn: Button
var _no_btn: Button
var _set_chrome_visible: Callable
var _style_dialog_button: Callable
var _on_after_hide: Callable
var _on_yes: Callable
var _on_no: Callable


func bind(
	blocker: ColorRect,
	label: Label,
	yes_btn: Button,
	no_btn: Button,
	set_chrome_visible: Callable,
	style_dialog_button: Callable,
	on_after_hide: Callable,
	on_yes: Callable,
	on_no: Callable
) -> void:
	_blocker = blocker
	_label = label
	_yes_btn = yes_btn
	_no_btn = no_btn
	_set_chrome_visible = set_chrome_visible
	_style_dialog_button = style_dialog_button
	_on_after_hide = on_after_hide
	_on_yes = on_yes
	_on_no = on_no


func setup_panel() -> void:
	if _blocker == null:
		return
	_blocker.visible = false
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.color = Color(0, 0, 0, 0)
	var center := _blocker.get_node_or_null("CenterContainer") as Control
	if center:
		HudLayout.raise_centered_dialog_host(center)
	var panel := _blocker.get_node_or_null("CenterContainer/Panel") as Panel
	if panel:
		panel.add_theme_stylebox_override("panel", HudLayout.make_dialog_panel_style())
	if _label:
		_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55, 1.0))
	_apply_button_styles()
	if _yes_btn and not _yes_btn.pressed.is_connected(_on_yes_pressed):
		_yes_btn.pressed.connect(_on_yes_pressed)
	if _no_btn and not _no_btn.pressed.is_connected(_on_no_pressed):
		_no_btn.pressed.connect(_on_no_pressed)


func is_blocking() -> bool:
	return _blocker != null and _blocker.visible


func handle_back() -> bool:
	if not is_blocking():
		return false
	hide()
	return true


func show_prompt() -> void:
	if _set_chrome_visible.is_valid():
		_set_chrome_visible.call(false)
	if _label:
		_label.text = TranslationServer.translate("TUTORIAL_INTRO_PROMPT")
		HudLayout.apply_popup_label(_label, GameConstants.UI_BODY_FONT_SIZE_LARGE)
	if _yes_btn:
		_yes_btn.text = TranslationServer.translate("UI_YES")
		_apply_button_styles()
	if _no_btn:
		_no_btn.text = TranslationServer.translate("UI_NO")
		_apply_button_styles()
	var panel := _blocker.get_node_or_null("CenterContainer/Panel") as Panel if _blocker else null
	if panel:
		HudLayout.fit_dialog_panel(panel, HudLayout.UI_DEFAULT_DIALOG_WIDTH)
	if _blocker:
		_blocker.color = Color(0, 0, 0, 0)
		_blocker.visible = true
		_blocker.move_to_front()


func hide() -> void:
	if _blocker:
		_blocker.visible = false
	if _set_chrome_visible.is_valid():
		_set_chrome_visible.call(true)
	if _on_after_hide.is_valid():
		_on_after_hide.call()


func _apply_button_styles() -> void:
	if _style_dialog_button.is_valid():
		_style_dialog_button.call(_yes_btn)
		_style_dialog_button.call(_no_btn)


func _on_yes_pressed() -> void:
	if _on_yes.is_valid():
		_on_yes.call()


func _on_no_pressed() -> void:
	if _on_no.is_valid():
		_on_no.call()
