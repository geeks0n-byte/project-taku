class_name MainMenuConsentController
extends RefCounted

const _CONSENT_POPUP_SCENE := preload("res://scenes/consent_popup.tscn")

var _owner: Control
var _overlay_layer: CanvasLayer
var _options_menu: CanvasLayer
var _boot_intro: BootIntroController
var _consent_blocker: ColorRect
var _set_chrome_visible: Callable
var _set_button_ui_alpha: Callable
var _apply_debug_tools: Callable
var _set_boot_menu_input: Callable


func setup(
	owner: Control,
	overlay_layer: CanvasLayer,
	options_menu: CanvasLayer,
	boot_intro: BootIntroController,
	set_chrome_visible: Callable,
	set_button_ui_alpha: Callable,
	apply_debug_tools: Callable,
	set_boot_menu_input: Callable
) -> void:
	_owner = owner
	_overlay_layer = overlay_layer
	_options_menu = options_menu
	_boot_intro = boot_intro
	_set_chrome_visible = set_chrome_visible
	_set_button_ui_alpha = set_button_ui_alpha
	_apply_debug_tools = apply_debug_tools
	_set_boot_menu_input = set_boot_menu_input


func build_popup() -> void:
	if _overlay_layer == null:
		_overlay_layer = _owner.get_node_or_null("OverlayLayer") as CanvasLayer
	if _overlay_layer == null:
		_overlay_layer = _owner.get_node_or_null("UILayer") as CanvasLayer
	if _overlay_layer == null:
		return
	var popup := _CONSENT_POPUP_SCENE.instantiate()
	_overlay_layer.add_child(popup)
	_consent_blocker = popup as ColorRect
	if _consent_blocker:
		_consent_blocker.visible = false
	if popup.has_signal("accepted") and not popup.accepted.is_connected(_on_accepted):
		popup.accepted.connect(_on_accepted)
	_bias_popup_up()


func needs_consent() -> bool:
	return SaveManager != null and not SaveManager.privacy_accepted


func is_blocking() -> bool:
	return _consent_blocker != null and _consent_blocker.visible


func handle_back() -> bool:
	if not is_blocking():
		return false
	GlobalGameManager.quit_app()
	return true


func refresh_locale_if_visible() -> void:
	if _consent_blocker and _consent_blocker.visible and _consent_blocker.has_method("refresh_locale"):
		_consent_blocker.refresh_locale()


func show_if_needed(close_options: bool = false) -> void:
	if not needs_consent():
		return
	if _consent_blocker == null:
		return
	if close_options and _options_menu and _options_menu.visible:
		_options_menu.visible = false
	MainMenuChrome.set_visible(_set_chrome_visible, false, true)
	if _consent_blocker.has_method("refresh_locale"):
		_consent_blocker.refresh_locale()
	_consent_blocker.visible = true
	_consent_blocker.move_to_front()


func _bias_popup_up() -> void:
	if _consent_blocker == null:
		return
	var top := _consent_blocker.get_node_or_null("Outer/SpacerTop") as Control
	var bot := _consent_blocker.get_node_or_null("Outer/SpacerBot") as Control
	if top:
		top.size_flags_stretch_ratio = 1.0
	if bot:
		bot.size_flags_stretch_ratio = 1.0 + GameConstants.UI_DIALOG_RAISE_PX / 480.0


func _on_accepted() -> void:
	var resume_intro := _boot_intro.is_active() and not _boot_intro.is_title_intro_started()
	if resume_intro:
		_boot_intro.on_consent_accepted_begin()
	if SaveManager:
		SaveManager.accept_privacy()
	if _consent_blocker:
		_consent_blocker.visible = false
	if resume_intro:
		_boot_intro.on_consent_resume()
		return
	MainMenuChrome.set_visible(_set_chrome_visible, true)
	if _set_button_ui_alpha.is_valid():
		_set_button_ui_alpha.call(1.0)
	var title_host := _owner.get_node_or_null("TitleLayer/TitleHost") as CanvasItem
	if title_host:
		title_host.modulate.a = 1.0
	var title := _owner.get_node_or_null("TitleLayer/TitleHost/TitleCluster/TitleLabel") as Label
	if title:
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.set_anchors_preset(Control.PRESET_TOP_WIDE)
		title.anchor_left = 0.0
		title.anchor_right = 1.0
		title.offset_left = 24.0
		title.offset_right = -24.0
		title.offset_top = 240.0
		title.offset_bottom = 400.0
		title.visible_characters = -1
	if _apply_debug_tools.is_valid():
		_apply_debug_tools.call()
	if _set_boot_menu_input.is_valid():
		_set_boot_menu_input.call(true)
