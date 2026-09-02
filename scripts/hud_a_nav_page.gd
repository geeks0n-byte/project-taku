class_name HudPageNav
extends RefCounted
## How-to-play / overlay PREV-NEXT row layout extracted from HudLayout.


static func clear_how_to_play_nav_lock(host: Control) -> void:
	if host and host.has_meta("_htp_nav_top"):
		host.remove_meta("_htp_nav_top")


static func page_nav_bottom_inset(reserve_menu_banner: bool = false) -> float:
	var inset := GameConstants.SCREEN_PAGE_NAV_BOTTOM_INSET
	if reserve_menu_banner:
		inset += GameConstants.AD_BANNER_RESERVE
	return inset


static func page_nav_content_bottom_offset(reserve_menu_banner: bool = false) -> float:
	return -(
		page_nav_bottom_inset(reserve_menu_banner)
		+ GameConstants.UI_BTN_NAV_SIZE.y
		+ GameConstants.SCREEN_NAV_GAP
	)


static func pin_page_nav_row(
	nav: Control,
	host: Control,
	reserve_menu_banner: bool = false,
	horizontal_inset: float = 40.0
) -> void:
	if nav == null or host == null:
		return
	var host_h := host.size.y
	if host_h <= 1.0:
		host_h = float(
			ProjectSettings.get_setting("display/window/size/viewport_height", 1920)
		)
	var nav_h := GameConstants.UI_BTN_NAV_SIZE.y
	if nav.custom_minimum_size.y > 0.0:
		nav_h = nav.custom_minimum_size.y
	var bottom_inset := page_nav_bottom_inset(reserve_menu_banner)
	var nav_bottom := host_h - SafeInsets.bottom() - bottom_inset
	var nav_top := nav_bottom - nav_h
	nav.set_anchors_preset(Control.PRESET_TOP_WIDE)
	nav.anchor_left = 0.0
	nav.anchor_right = 1.0
	nav.anchor_top = 0.0
	nav.anchor_bottom = 0.0
	nav.offset_left = horizontal_inset + SafeInsets.left()
	nav.offset_right = -horizontal_inset - SafeInsets.right()
	nav.offset_top = nav_top
	nav.offset_bottom = nav_bottom
	nav.grow_horizontal = Control.GROW_DIRECTION_BOTH
	nav.grow_vertical = Control.GROW_DIRECTION_BEGIN
	nav.z_index = maxi(nav.z_index, 4)


static func layout_how_to_play_stack(
	host: Control,
	panel: Control,
	rules: RichTextLabel,
	nav: Control,
	_update_nav_lock: bool = false,
	reserve_menu_banner: bool = false
) -> void:
	if host == null or panel == null or nav == null:
		return
	var host_h := host.size.y
	if host_h <= 1.0:
		host_h = float(
			ProjectSettings.get_setting("display/window/size/viewport_height", 1920)
		)
	var nav_h := GameConstants.UI_BTN_NAV_SIZE.y
	var panel_top := SafeInsets.padded_top(GameConstants.HTP_PANEL_TOP)
	var bottom_inset := page_nav_bottom_inset(reserve_menu_banner)
	var nav_bottom := host_h - SafeInsets.bottom() - bottom_inset
	var nav_top := nav_bottom - nav_h
	var max_panel_h := maxf(
		GameConstants.HTP_PANEL_MIN_HEIGHT,
		nav_top - panel_top - GameConstants.SCREEN_NAV_GAP
	)

	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -GameConstants.HTP_PANEL_HALF_WIDTH
	panel.offset_right = GameConstants.HTP_PANEL_HALF_WIDTH
	panel.offset_top = panel_top
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var content_h := max_panel_h
	if rules:
		rules.fit_content = true
		rules.scroll_active = false
		rules.custom_minimum_size = Vector2(0, 0)
		content_h = maxf(rules.get_content_height() + 24.0, GameConstants.HTP_PANEL_MIN_HEIGHT)
	var panel_h := clampf(content_h, GameConstants.HTP_PANEL_MIN_HEIGHT, max_panel_h)
	panel.offset_bottom = panel_top + panel_h
	if rules:
		var needs_scroll := content_h > panel_h + 1.0
		rules.scroll_active = needs_scroll
		rules.fit_content = not needs_scroll

	pin_page_nav_row(nav, host, reserve_menu_banner)
