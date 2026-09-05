class_name MainMenuBadges
extends RefCounted
## Notification badges for achievements and level-select menu buttons.


const MENU_BADGE_MARGIN := 10.0
const MENU_BADGE_TEXT_GAP := -6.0
const MENU_BTN_FONT := 64
const _PIXEL_MONO_TEXT_SCRIPT: Script = preload("res://scripts/pixel_mono_text.gd")

var _menu_center: Control
var _achievements_btn: Button
var _levels_btn: Button
var _menu_badge_host: Control = null
var _ach_badge_label: Label = null
var _levels_badge_label: Label = null


func setup(menu_center: Control, achievements_btn: Button, levels_btn: Button) -> void:
	_menu_center = menu_center
	_achievements_btn = achievements_btn
	_levels_btn = levels_btn


func ensure_host() -> void:
	if _menu_badge_host != null and is_instance_valid(_menu_badge_host):
		return
	if _menu_center == null:
		return
	_menu_badge_host = Control.new()
	_menu_badge_host.name = "MenuNotificationBadgeHost"
	_menu_badge_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_badge_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_badge_host.z_index = 10
	_menu_center.add_child(_menu_badge_host)


func setup_panels() -> void:
	ensure_host()
	if _menu_badge_host == null:
		return
	if _achievements_btn != null and _ach_badge_label == null:
		_ach_badge_label = HudLayout.build_plain_notification_badge(_achievements_btn.custom_minimum_size.y)
		_ach_badge_label.name = "AchievementsUnseenBadge"
		_menu_badge_host.add_child(_ach_badge_label)
	if _levels_btn != null and _levels_badge_label == null:
		_levels_badge_label = HudLayout.build_plain_notification_badge(_levels_btn.custom_minimum_size.y)
		_levels_badge_label.name = "LevelsUnseenBadge"
		_menu_badge_host.add_child(_levels_badge_label)


func bind_resize_hooks() -> void:
	setup_panels()
	if _achievements_btn and not _achievements_btn.resized.is_connected(layout):
		_achievements_btn.resized.connect(layout)
	if _levels_btn and not _levels_btn.resized.is_connected(layout):
		_levels_btn.resized.connect(layout)
	if _menu_center and not _menu_center.resized.is_connected(layout):
		_menu_center.resized.connect(layout)
	for button in [_achievements_btn, _levels_btn]:
		if button == null:
			continue
		var mono: Control = button.get_node_or_null("PixelMonoCaption") as Control
		if mono != null and not mono.resized.is_connected(layout):
			mono.resized.connect(layout)


func refresh_achievements(count: int = -1) -> void:
	if _ach_badge_label == null:
		return
	var unseen := count if count >= 0 else (AchievementManager.unseen_count() if AchievementManager else 0)
	_ach_badge_label.visible = unseen > 0
	if unseen > 0:
		var host_h := _button_host_h(_achievements_btn)
		HudLayout.refresh_plain_notification_badge(_ach_badge_label, host_h)
	layout.call_deferred()


func refresh_levels(count: int = -1) -> void:
	if _levels_badge_label == null:
		return
	var unseen := count if count >= 0 else (SaveManager.unseen_level_count() if SaveManager else 0)
	_levels_badge_label.visible = unseen > 0
	if unseen > 0:
		var host_h := _button_host_h(_levels_btn)
		HudLayout.refresh_plain_notification_badge(_levels_badge_label, host_h)
	layout.call_deferred()


func layout() -> void:
	_layout_button_badge(_ach_badge_label, _achievements_btn, "UI_ACHIEVEMENTS")
	_layout_button_badge(_levels_badge_label, _levels_btn, "UI_LEVEL_SELECT")


func _layout_button_badge(badge: Label, button: Button, fallback_key: String) -> void:
	if badge == null or button == null:
		return
	ensure_host()
	if _menu_badge_host == null:
		return
	if badge.get_parent() != _menu_badge_host:
		_menu_badge_host.add_child(badge)
	var btn_rect: Rect2 = button.get_global_rect()
	var btn_w: float = btn_rect.size.x if btn_rect.size.x > 1.0 else button.custom_minimum_size.x
	var btn_h: float = _button_host_h(button)
	var badge_dims: Vector2 = HudLayout.plain_notification_badge_size(btn_h)
	var trailing_x: float = _button_label_trailing_x(button, btn_w, fallback_key)
	var host_origin: Vector2 = _menu_badge_host.get_global_rect().position
	var x: float = btn_rect.position.x - host_origin.x + trailing_x + MENU_BADGE_TEXT_GAP
	var y: float = btn_rect.position.y - host_origin.y + maxf(MENU_BADGE_MARGIN, btn_h * 0.12)
	x = clampf(x, 0.0, maxf(0.0, _menu_badge_host.size.x - badge_dims.x))
	badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	badge.offset_left = x
	badge.offset_top = y
	badge.offset_right = x + badge_dims.x
	badge.offset_bottom = y + badge_dims.y
	badge.z_index = 1
	badge.move_to_front()


func _button_host_h(button: Button) -> float:
	if button == null:
		return 0.0
	var btn_rect: Rect2 = button.get_global_rect()
	return btn_rect.size.y if btn_rect.size.y > 1.0 else button.custom_minimum_size.y


func _button_label_trailing_x(button: Button, btn_w: float, fallback_key: String) -> float:
	if button == null or btn_w <= 0.0:
		return btn_w * 0.5
	var mono: Control = button.get_node_or_null("PixelMonoCaption") as Control
	if mono != null and mono.has_method("text_trailing_local_x"):
		return float(mono.call("text_trailing_local_x", btn_w))
	var key := String(button.get_meta("_tr_key", fallback_key)).strip_edges()
	if key.is_empty():
		key = fallback_key
	var display := String(TranslationServer.translate(key))
	if display.is_empty():
		display = key
	return _centered_label_trailing_x(
		display,
		btn_w,
		MENU_BTN_FONT,
		HudFonts.should_use_press_start_font(display)
	)


func _centered_label_trailing_x(display: String, host_w: float, font_size: int, use_pixel: bool) -> float:
	if display.is_empty() or host_w <= 0.0 or font_size <= 0:
		return host_w * 0.5
	var font := HudLayout.pixel_font_clean() if use_pixel else HudFonts.default_font()
	var px := font_size if use_pixel else HudLayout.body_font_size(font_size)
	if use_pixel:
		return _PIXEL_MONO_TEXT_SCRIPT.ink_trailing_x_for_centered_text(display, font, px, host_w)
	var text_w := font.get_string_size(display, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	return (host_w + text_w) * 0.5
