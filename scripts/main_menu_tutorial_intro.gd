class_name MainMenuTutorialIntro
extends RefCounted

var _blocker: ColorRect
var _label: Label
var _yes_btn: Button
var _no_btn: Button
var _set_chrome_visible: Callable
var _launch_tutorial: Callable
var _start_easy_campaign: Callable


func setup(
	blocker: ColorRect,
	label: Label,
	yes_btn: Button,
	no_btn: Button,
	set_chrome_visible: Callable,
	launch_tutorial: Callable,
	start_easy_campaign: Callable
) -> void:
	_blocker = blocker
	_label = label
	_yes_btn = yes_btn
	_no_btn = no_btn
	_set_chrome_visible = set_chrome_visible
	_launch_tutorial = launch_tutorial
	_start_easy_campaign = start_easy_campaign


func setup_panel() -> void:
	if _blocker:
		_blocker.visible = false
		_blocker.color = Color(0, 0, 0, 0)
		HudLayout.register_modal_blocker(_blocker)
	var center := (
		_blocker.get_node_or_null("CenterContainer") as Control
		if _blocker
		else null
	)
	if center:
		HudLayout.raise_centered_dialog_host(center)
	var panel := _blocker.get_node_or_null("CenterContainer/Panel") as Panel if _blocker else null
	if panel:
		panel.add_theme_stylebox_override("panel", HudLayout.make_dialog_panel_style())
	if _label:
		_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55, 1.0))
		HudLayout.apply_popup_label(_label, GameConstants.UI_BODY_FONT_SIZE_LARGE)
	_apply_button_styles()


func bind_signals() -> void:
	if _yes_btn and not _yes_btn.pressed.is_connected(_on_yes):
		_yes_btn.pressed.connect(_on_yes)
	if _no_btn and not _no_btn.pressed.is_connected(_on_no):
		_no_btn.pressed.connect(_on_no)


func is_blocking() -> bool:
	return _blocker != null and _blocker.visible


func handle_back() -> bool:
	if not is_blocking():
		return false
	hide()
	return true


func show_prompt() -> void:
	MainMenuChrome.set_visible(_set_chrome_visible, false)
	if _label:
		_label.text = tr("TUTORIAL_INTRO_PROMPT")
		HudLayout.apply_popup_label(_label, GameConstants.UI_BODY_FONT_SIZE_LARGE)
	if _yes_btn:
		_yes_btn.text = tr("UI_YES")
	if _no_btn:
		_no_btn.text = tr("UI_NO")
	_apply_button_styles()
	apply_a11y_labels()
	var panel := (
		_blocker.get_node_or_null("CenterContainer/Panel") as Panel
		if _blocker
		else null
	)
	if panel:
		HudLayout.fit_dialog_panel(panel, HudLayout.UI_DEFAULT_DIALOG_WIDTH)
	if _blocker:
		_blocker.color = Color(0, 0, 0, 0)
		_blocker.visible = true
		_blocker.move_to_front()


func hide() -> void:
	if _blocker:
		_blocker.visible = false
	MainMenuChrome.set_visible(_set_chrome_visible, true)


func apply_a11y_labels() -> void:
	if _label:
		_label.accessibility_name = tr("TUTORIAL_INTRO_PROMPT")
	A11yLabels.bind_button(_yes_btn, "UI_YES")
	A11yLabels.bind_button(_no_btn, "UI_NO")


func _apply_button_styles() -> void:
	# Keep scene StyleBoxTexture tiles; only size/font (start_btn is flat — do not copy from it).
	if _yes_btn:
		HudLayout.apply_dialog_button(_yes_btn)
	if _no_btn:
		HudLayout.apply_dialog_button(_no_btn)


func _on_yes() -> void:
	hide()
	if SaveManager:
		SaveManager.set_tutorial_intro_answered(true)
	if _launch_tutorial.is_valid():
		_launch_tutorial.call()


func _on_no() -> void:
	hide()
	if SaveManager:
		SaveManager.set_tutorial_intro_answered(true)
	if _start_easy_campaign.is_valid():
		_start_easy_campaign.call()
