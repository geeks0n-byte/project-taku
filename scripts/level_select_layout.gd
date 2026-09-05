class_name LevelSelectLayout
extends RefCounted
## Phone-capped layout, chrome sizing, and custom-debug tab placement for level select.


const RESERVE_MENU_BANNER_NAV := true
## Matches main-menu / options debug bar vertical placement; width fits text label.
const CUSTOM_DEBUG_BTN_TOP := 24.0
const CUSTOM_DEBUG_BTN_HEIGHT := GameConstants.UI_BTN_TAB_SIZE.y
const CUSTOM_DEBUG_BTN_WIDTH := 280.0

var _title_label: Label
var _content_vbox: VBoxContainer
var _page_nav: HBoxContainer
var _screen_header_host: Control
var _close_button_host: Control
var _back_button: Button
var _page_prev_button: Button
var _page_next_button: Button
var _level_grid: GridContainer
var _empty_state_label: Label
var _easy_tab_button: Button
var _medium_tab_button: Button
var _hard_tab_button: Button
var _custom_tab_button: Button
var _custom_debug_bar_host: HBoxContainer
var _levels_per_page: int = 12


func bind(
	title_label: Label,
	content_vbox: VBoxContainer,
	page_nav: HBoxContainer,
	screen_header_host: Control,
	close_button_host: Control,
	back_button: Button,
	page_prev_button: Button,
	page_next_button: Button,
	level_grid: GridContainer,
	empty_state_label: Label,
	easy_tab_button: Button,
	medium_tab_button: Button,
	hard_tab_button: Button,
	custom_tab_button: Button,
	custom_debug_bar_host: HBoxContainer,
	levels_per_page: int
) -> void:
	_title_label = title_label
	_content_vbox = content_vbox
	_page_nav = page_nav
	_screen_header_host = screen_header_host
	_close_button_host = close_button_host
	_back_button = back_button
	_page_prev_button = page_prev_button
	_page_next_button = page_next_button
	_level_grid = level_grid
	_empty_state_label = empty_state_label
	_easy_tab_button = easy_tab_button
	_medium_tab_button = medium_tab_button
	_hard_tab_button = hard_tab_button
	_custom_tab_button = custom_tab_button
	_custom_debug_bar_host = custom_debug_bar_host
	_levels_per_page = levels_per_page


func layout_level_select() -> void:
	if _title_label:
		HudLayout._bind_header_translation_key(_title_label, "UI_SELECT_LEVEL")
		HudLayout.apply_screen_header_style(_title_label)
		var title_top := SafeInsets.padded_top(GameConstants.SCREEN_HEADER_TOP)
		_title_label.offset_top = title_top
		_title_label.offset_bottom = title_top + GameConstants.SCREEN_HEADER_HEIGHT
		if _content_vbox:
			const VBOX_AUTHORED_TOP := (
				GameConstants.SCREEN_HEADER_TOP
				+ GameConstants.SCREEN_HEADER_HEIGHT
				+ GameConstants.SCREEN_CONTENT_GAP
			)
			_content_vbox.offset_top = VBOX_AUTHORED_TOP + (title_top - GameConstants.SCREEN_HEADER_TOP)
			_content_vbox.offset_bottom = SafeInsets.padded_bottom_offset(
				HudLayout.page_nav_content_bottom_offset(RESERVE_MENU_BANNER_NAV)
			)
			_content_vbox.offset_left = 24.0 + SafeInsets.left()
			_content_vbox.offset_right = -24.0 - SafeInsets.right()
			HudLayout.cap_stretched_width(_content_vbox, HudLayout.UI_PHONE_CONTENT_WIDTH)
		if _page_nav and _screen_header_host:
			HudLayout.pin_page_nav_row(_page_nav, _screen_header_host, RESERVE_MENU_BANNER_NAV)
	apply_close_button()
	connect_level_list_host()
	pin_level_list_to_top()
	layout_custom_tab_button()
	if _screen_header_host:
		_screen_header_host.move_to_front()
	if _close_button_host:
		_close_button_host.move_to_front()


func reparent_page_nav() -> void:
	if _page_nav == null or _screen_header_host == null:
		return
	if _page_nav.get_parent() != _screen_header_host:
		_page_nav.reparent(_screen_header_host)
	var gap := _content_vbox.get_node_or_null("PageNavGap") if _content_vbox else null
	if gap:
		gap.queue_free()


func connect_level_list_host() -> void:
	var host := _content_vbox.get_node_or_null("LevelListHost") as Control if _content_vbox else null
	if host == null:
		return
	if not host.resized.is_connected(pin_level_list_to_top):
		host.resized.connect(pin_level_list_to_top)
	if _level_grid:
		_level_grid.columns = 3
		_level_grid.add_theme_constant_override("h_separation", 30)
		_level_grid.add_theme_constant_override("v_separation", 30)


func pin_level_list_to_top() -> void:
	var host := _content_vbox.get_node_or_null("LevelListHost") as Control if _content_vbox else null
	if host == null:
		return
	var host_w := host.size.x
	if host_w <= 0.0:
		return

	if _level_grid and _level_grid.get_parent() == host:
		_level_grid.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_level_grid.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_level_grid.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_level_grid.size_flags_horizontal = 0
		_level_grid.size_flags_vertical = 0
		_level_grid.clip_contents = false
		const ROW_H := 240.0
		for child in _level_grid.get_children():
			if child is Control:
				var cell := child as Control
				cell.custom_minimum_size = Vector2(cell.custom_minimum_size.x, ROW_H)
				cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				cell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var cols := maxi(1, _level_grid.columns)
		var page_rows := int(ceili(float(_levels_per_page) / float(cols)))
		var sep := _level_grid.get_theme_constant("v_separation")
		# Always reserve a full page so paging never shifts the list upward.
		var reserved_h := page_rows * ROW_H + maxi(0, page_rows - 1) * sep
		# Cap to phone content width and center. No-op when host is already 1032 (phones).
		var grid_w := minf(host_w, HudLayout.UI_PHONE_CONTENT_WIDTH)
		if grid_w < 1.0:
			grid_w = host_w
		_level_grid.size = Vector2(grid_w, reserved_h)
		_level_grid.position = Vector2((host_w - grid_w) * 0.5, 0.0)
		host.custom_minimum_size = Vector2(0, reserved_h)
		host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	if _empty_state_label and _empty_state_label.get_parent() == host and _empty_state_label.visible:
		_empty_state_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_empty_state_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_empty_state_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_empty_state_label.size_flags_horizontal = 0
		_empty_state_label.size_flags_vertical = 0
		var label_h := _empty_state_label.get_combined_minimum_size().y
		const EMPTY_STATE_TOP := 160.0
		_empty_state_label.position = Vector2(0, EMPTY_STATE_TOP)
		_empty_state_label.size = Vector2(host_w, maxf(label_h, 1.0))
		host.custom_minimum_size = Vector2(0, EMPTY_STATE_TOP + maxf(label_h, 1.0))
		host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func fit_chrome_buttons(configure_tab: Callable = Callable()) -> void:
	apply_close_button()
	if configure_tab.is_valid():
		configure_tab.call()
	else:
		configure_custom_tab_visibility()
	for btn in [
		_easy_tab_button,
		_medium_tab_button,
		_hard_tab_button,
	]:
		if btn == null:
			continue
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, GameConstants.UI_BTN_TAB_SIZE.y)
		btn.add_theme_color_override("font_outline_color", Color.BLACK)
		HudLayout.apply_safe_outline(btn, GameConstants.MENU_TEXT_OUTLINE)
		btn.autowrap_mode = TextServer.AUTOWRAP_OFF
		btn.clip_text = false
		HudLayout.fit_text_button(
			btn, GameConstants.UI_BTN_TAB_FONT, GameConstants.UI_BTN_TAB_FONT_MIN
		)
		btn.autowrap_mode = TextServer.AUTOWRAP_OFF
	if _custom_debug_bar_host and _custom_debug_bar_host.visible and _custom_tab_button:
		_custom_tab_button.focus_mode = Control.FOCUS_NONE
		_custom_tab_button.custom_minimum_size = Vector2(
			CUSTOM_DEBUG_BTN_WIDTH,
			CUSTOM_DEBUG_BTN_HEIGHT
		)
		_custom_tab_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		HudLayout.fit_text_button(
			_custom_tab_button,
			GameConstants.UI_BTN_TAB_FONT,
			GameConstants.UI_BTN_TAB_FONT_MIN
		)
		HudLayout.apply_safe_outline(_custom_tab_button, GameConstants.MENU_TEXT_OUTLINE)
		_custom_tab_button.text = "UI_CUSTOM"
		_sync_custom_tab_font()
		layout_custom_tab_button()
	if _page_prev_button:
		HudLayout.apply_nav_button(_page_prev_button)
	if _page_next_button:
		HudLayout.apply_nav_button(_page_next_button)


func apply_close_button() -> void:
	if _back_button:
		HudLayout.style_top_bar_close_button(_back_button)


func configure_custom_tab_visibility() -> void:
	var show_custom := GlobalGameManager.debug_tools_enabled
	if _custom_debug_bar_host:
		_custom_debug_bar_host.visible = show_custom
	if _custom_tab_button and show_custom:
		_custom_tab_button.text = "UI_CUSTOM"
	layout_custom_tab_button()


func layout_custom_tab_button() -> void:
	if _custom_debug_bar_host == null or not _custom_debug_bar_host.visible:
		return
	var top := SafeInsets.padded_top(CUSTOM_DEBUG_BTN_TOP)
	_custom_debug_bar_host.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_custom_debug_bar_host.offset_left = 24.0 + SafeInsets.left()
	_custom_debug_bar_host.offset_top = top
	_custom_debug_bar_host.offset_right = -24.0 - SafeInsets.right()
	_custom_debug_bar_host.offset_bottom = top + CUSTOM_DEBUG_BTN_HEIGHT
	if _custom_tab_button:
		_custom_tab_button.custom_minimum_size = Vector2(
			CUSTOM_DEBUG_BTN_WIDTH,
			CUSTOM_DEBUG_BTN_HEIGHT
		)


func _sync_custom_tab_font() -> void:
	if _custom_tab_button == null or _easy_tab_button == null:
		return
	var tab_font_size := _easy_tab_button.get_theme_font_size("font_size")
	if tab_font_size <= 0:
		return
	_custom_tab_button.add_theme_font_size_override("font_size", tab_font_size)
	if _easy_tab_button.has_theme_font_override("font"):
		_custom_tab_button.add_theme_font_override(
			"font", _easy_tab_button.get_theme_font("font")
		)
