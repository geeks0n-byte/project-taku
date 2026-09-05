class_name UiEndDialogs
extends RefCounted
## Reset confirm and session-resume overlays on the gameplay end layer.


var _end_center: CenterContainer
var _end_dimmer: ColorRect
var _victory_panel: Control
var _resume_panel: Panel
var _resume_prompt: Label
var _resume_buttons: VBoxContainer
var _resume_continue: Button
var _resume_restart: Button
var _resume_back: Button
var _reset_panel: Panel
var _reset_label: Label
var _reset_yes: Button
var _reset_no: Button
var _reset_is_restart: bool = false
var _on_reset_confirmed: Callable
var _on_reset_cancelled: Callable
var _on_session_continue: Callable
var _on_session_restart: Callable
var _on_session_back: Callable
var _set_hud_disabled: Callable


func bind(
	end_center: CenterContainer,
	end_dimmer: ColorRect,
	victory_panel: Control,
	resume_panel: Panel,
	resume_prompt: Label,
	resume_buttons: VBoxContainer,
	resume_continue: Button,
	resume_restart: Button,
	resume_back: Button,
	reset_panel: Panel,
	reset_label: Label,
	reset_yes: Button,
	reset_no: Button
) -> void:
	_end_center = end_center
	_end_dimmer = end_dimmer
	_victory_panel = victory_panel
	_resume_panel = resume_panel
	_resume_prompt = resume_prompt
	_resume_buttons = resume_buttons
	_resume_continue = resume_continue
	_resume_restart = resume_restart
	_resume_back = resume_back
	_reset_panel = reset_panel
	_reset_label = reset_label
	_reset_yes = reset_yes
	_reset_no = reset_no


func setup(
	on_reset_confirmed: Callable,
	on_reset_cancelled: Callable,
	on_session_continue: Callable,
	on_session_restart: Callable,
	on_session_back: Callable,
	set_hud_disabled: Callable
) -> void:
	_on_reset_confirmed = on_reset_confirmed
	_on_reset_cancelled = on_reset_cancelled
	_on_session_continue = on_session_continue
	_on_session_restart = on_session_restart
	_on_session_back = on_session_back
	_set_hud_disabled = set_hud_disabled
	HudLayout.register_modal_blocker(_end_dimmer)
	if _end_center:
		_end_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _reset_yes and not _reset_yes.pressed.is_connected(_on_reset_yes_pressed):
		_reset_yes.pressed.connect(_on_reset_yes_pressed)
	if _reset_no and not _reset_no.pressed.is_connected(_on_reset_no_pressed):
		_reset_no.pressed.connect(_on_reset_no_pressed)
	if _resume_continue and not _resume_continue.pressed.is_connected(_on_resume_continue_pressed):
		_resume_continue.pressed.connect(_on_resume_continue_pressed)
	if _resume_restart and not _resume_restart.pressed.is_connected(_on_resume_restart_pressed):
		_resume_restart.pressed.connect(_on_resume_restart_pressed)
	if _resume_back and not _resume_back.pressed.is_connected(_on_resume_back_pressed):
		_resume_back.pressed.connect(_on_resume_back_pressed)


func set_reset_is_restart(is_restart: bool) -> void:
	_reset_is_restart = is_restart


func set_dimmer_visible(should_show: bool) -> void:
	if _end_dimmer:
		_end_dimmer.visible = should_show
		_end_dimmer.mouse_filter = (
			Control.MOUSE_FILTER_STOP if should_show else Control.MOUSE_FILTER_IGNORE
		)


func set_dialog_raised(raised: bool, raise_px: float = GameConstants.UI_DIALOG_RAISE_PX) -> void:
	if _end_center == null:
		return
	if raised:
		HudLayout.raise_centered_dialog_host(_end_center, raise_px)
	else:
		_end_center.offset_bottom = 0.0


func any_overlay_visible() -> bool:
	if _victory_panel and _victory_panel.visible:
		return true
	if _resume_panel and _resume_panel.visible:
		return true
	if _reset_panel and _reset_panel.visible:
		return true
	return false


func show_reset_confirm() -> void:
	set_dialog_raised(true)
	if _end_dimmer:
		_end_dimmer.color = Color(0, 0, 0, 0)
	set_dimmer_visible(true)
	if _reset_label:
		_reset_label.text = TranslationServer.translate(
			"UI_CONFIRM_RESTART_LEVEL" if _reset_is_restart else "UI_CONFIRM_NEW_PUZZLE"
		)
		HudLayout.apply_popup_label(_reset_label, GameConstants.UI_BODY_FONT_SIZE_LARGE)
	if _reset_yes:
		_reset_yes.text = TranslationServer.translate("UI_YES")
	if _reset_no:
		_reset_no.text = TranslationServer.translate("UI_NO")
	if _victory_panel:
		_victory_panel.visible = false
	if _resume_panel:
		_resume_panel.visible = false
	if _reset_panel:
		_reset_panel.add_theme_stylebox_override("panel", HudLayout.make_dialog_panel_style())
		HudLayout.fit_dialog_panel(_reset_panel, HudLayout.UI_DEFAULT_DIALOG_WIDTH)
		_reset_panel.visible = true
		_reset_panel.move_to_front()
	if _set_hud_disabled.is_valid():
		_set_hud_disabled.call(true)
	apply_a11y_labels()


func hide_reset_confirm() -> void:
	if _reset_panel:
		_reset_panel.visible = false
	if not any_overlay_visible():
		set_dimmer_visible(false)
		set_dialog_raised(false)


func show_session_resume_prompt() -> void:
	set_dialog_raised(true)
	if _end_dimmer:
		_end_dimmer.color = Color(0, 0, 0, 0)
	set_dimmer_visible(true)
	if _resume_prompt:
		_resume_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_resume_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_resume_prompt.clip_contents = true
		var prompt_w := 700
		if _resume_panel:
			prompt_w = maxi(200, int(_resume_panel.custom_minimum_size.x) - 96)
		HudLayout.apply_raster_pixel_label(
			_resume_prompt,
			HudLayout._popup_prompt_with_title_gap(
				TranslationServer.translate("UI_SESSION_RESUME_PROMPT")
			),
			GameConstants.UI_BODY_FONT_SIZE_LARGE,
			Color(1, 0.84, 0, 1),
			prompt_w
		)
		_resume_prompt.add_theme_constant_override(
			"line_spacing", 4 if HudLayout.prefer_default_font() else 8
		)
	if _resume_panel:
		var resume_btns: Array = []
		if _resume_continue:
			_style_resume_button(_resume_continue, TranslationServer.translate("UI_CONTINUE"))
			resume_btns.append(_resume_continue)
		if _resume_restart:
			_style_resume_button(
				_resume_restart,
				TranslationServer.translate(
					"UI_RESTART" if _reset_is_restart else "UI_NEW_LAYOUT"
				)
			)
			resume_btns.append(_resume_restart)
		if _resume_back:
			_style_resume_button(_resume_back, TranslationServer.translate("UI_BACK"))
			resume_btns.append(_resume_back)
		HudLayout.equalize_button_group_widths(resume_btns, 260.0, 110.0)
	if _victory_panel:
		_victory_panel.visible = false
	if _resume_panel:
		_resume_panel.add_theme_stylebox_override("panel", HudLayout.make_dialog_panel_style())
		HudLayout.fit_session_resume_panel(
			_resume_panel, _resume_prompt, _resume_buttons, 820.0
		)
		_resume_panel.visible = true
	if _set_hud_disabled.is_valid():
		_set_hud_disabled.call(true)
	apply_a11y_labels()


func hide_session_resume_prompt() -> void:
	if _resume_panel:
		_resume_panel.visible = false
	if _victory_panel == null or not _victory_panel.visible:
		set_dimmer_visible(false)
		set_dialog_raised(false)


func apply_a11y_labels() -> void:
	if _reset_panel and _reset_panel.visible:
		if _reset_label:
			_reset_label.accessibility_name = String(_reset_label.text).strip_edges()
		A11yLabels.bind_button(_reset_yes, "UI_YES")
		A11yLabels.bind_button(_reset_no, "UI_NO")
	if _resume_panel and _resume_panel.visible:
		if _resume_prompt:
			_resume_prompt.accessibility_name = A11yLabels.strip_bbcode(String(_resume_prompt.text))
		A11yLabels.bind_button(_resume_continue, "UI_CONTINUE")
		A11yLabels.bind_button(
			_resume_restart,
			"UI_RESTART" if _reset_is_restart else "UI_NEW_LAYOUT"
		)
		A11yLabels.bind_button(_resume_back, "UI_BACK")


func _style_resume_button(button: Button, text: String = "") -> void:
	if not button:
		return
	const RESUME_BTN_MIN_W := 260.0
	const RESUME_BTN_H := 110.0
	var display := text if not text.is_empty() else button.text
	if button.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED and text.is_empty():
		display = String(TranslationServer.translate(button.text))
	HudLayout.apply_raster_pixel_button(button, display, 28)
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.clip_text = false
	HudLayout.grow_button_to_text(button, RESUME_BTN_H, 48.0, RESUME_BTN_MIN_W)


func _on_reset_yes_pressed() -> void:
	hide_reset_confirm()
	if _on_reset_confirmed.is_valid():
		_on_reset_confirmed.call()


func _on_reset_no_pressed() -> void:
	hide_reset_confirm()
	if _on_reset_cancelled.is_valid():
		_on_reset_cancelled.call()


func _on_resume_continue_pressed() -> void:
	hide_session_resume_prompt()
	if _on_session_continue.is_valid():
		_on_session_continue.call()


func _on_resume_restart_pressed() -> void:
	hide_session_resume_prompt()
	if _on_session_restart.is_valid():
		_on_session_restart.call()


func _on_resume_back_pressed() -> void:
	hide_session_resume_prompt()
	if _on_session_back.is_valid():
		_on_session_back.call()
