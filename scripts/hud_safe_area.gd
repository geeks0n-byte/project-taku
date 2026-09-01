class_name HudSafeArea
extends RefCounted
## Safe-area insets and phone-width capping extracted from HudLayout.
## Public call sites continue to use HudLayout.* wrappers.


static func max_ui_content_width(extra_margin: float = HudLayout.UI_SAFE_SIDE_MARGIN) -> float:
	var window_w := 0.0
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		var root := (tree as SceneTree).root
		if root:
			window_w = root.get_viewport().get_visible_rect().size.x
	if window_w <= 0.0:
		window_w = float(DisplayServer.window_get_size().x)
	if window_w <= 0.0:
		window_w = float(ProjectSettings.get_setting("display/window/size/viewport_width", 1080))
	return maxf(240.0, window_w - extra_margin * 2.0)


static func clamp_ui_width(width: float, extra_margin: float = HudLayout.UI_SAFE_SIDE_MARGIN) -> float:
	var max_w := max_ui_content_width(extra_margin)
	var min_w := minf(HudLayout.UI_MIN_DIALOG_WIDTH, max_w)
	return clampf(width, min_w, max_w)


static func clamp_dialog_panel_width(width: float) -> float:
	var viewport_max := max_ui_content_width(HudLayout.UI_DIALOG_SCREEN_MARGIN)
	var max_w := minf(viewport_max, HudLayout.UI_MAX_DIALOG_WIDTH)
	var min_w := minf(HudLayout.UI_MIN_DIALOG_WIDTH, max_w)
	return clampf(width, min_w, max_w)


static func dialog_content_width(
	panel_width: float, horizontal_inset: float = HudDialogs.DIALOG_EDGE_INSET * 2.0
) -> float:
	return maxf(120.0, clamp_dialog_panel_width(panel_width) - horizontal_inset)


static func cap_ui_width(width: float, extra_margin: float = HudLayout.UI_SAFE_SIDE_MARGIN) -> float:
	return minf(width, max_ui_content_width(extra_margin))


static func extra_side_inset_for_cap(current_width: float, max_width: float) -> float:
	if current_width <= max_width + 0.5:
		return 0.0
	return (current_width - max_width) * 0.5


static func cap_stretched_width(control: Control, max_width: float = HudLayout.UI_PHONE_CONTENT_WIDTH) -> void:
	if control == null or max_width <= 0.0:
		return
	var span := control.anchor_right - control.anchor_left
	if span <= 0.0001:
		return
	var parent_w := layout_parent_width(control)
	if parent_w <= 1.0:
		return
	var current_w := parent_w * span + control.offset_right - control.offset_left
	var extra := extra_side_inset_for_cap(current_w, max_width)
	if extra <= 0.0:
		return
	control.offset_left += extra
	control.offset_right -= extra


static func cap_box_row_width(row: Control, max_width: float = HudLayout.UI_PHONE_EDITOR_ROW_WIDTH) -> void:
	if row == null or max_width <= 0.0:
		return
	if not row.has_meta("_wide_cap_hflags"):
		row.set_meta("_wide_cap_hflags", row.size_flags_horizontal)
		row.set_meta("_wide_cap_min_x", row.custom_minimum_size.x)
	var parent := row.get_parent()
	if not (parent is Control):
		return
	var parent_w := (parent as Control).size.x
	if parent_w <= 1.0:
		return
	if parent_w <= max_width + 0.5:
		row.size_flags_horizontal = int(row.get_meta("_wide_cap_hflags"))
		var min_sz := row.custom_minimum_size
		min_sz.x = float(row.get_meta("_wide_cap_min_x"))
		row.custom_minimum_size = min_sz
		return
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var capped := row.custom_minimum_size
	capped.x = max_width
	row.custom_minimum_size = capped


static func grid_row_pad_count(item_count: int, columns: int) -> int:
	if item_count <= 0 or columns <= 1:
		return 0
	var rem := item_count % columns
	if rem == 0:
		return 0
	return columns - rem


static func layout_parent_width(control: Control) -> float:
	if control == null:
		return 0.0
	var parent := control.get_parent()
	if parent is Control:
		var pw := (parent as Control).size.x
		if pw > 1.0:
			return pw
	var vp := control.get_viewport()
	if vp:
		var w := vp.get_visible_rect().size.x
		if w > 0.0:
			return w
	return float(ProjectSettings.get_setting("display/window/size/viewport_width", 1080))


static func apply_top_hud_safe_area(top_bar: Control, counter: Control = null) -> void:
	var edge := float(GameConstants.HUD_TOP_BAR_EDGE_MARGIN)
	var top := SafeInsets.padded_top(edge)
	var left := SafeInsets.left()
	var right := SafeInsets.right()
	if top_bar:
		top_bar.offset_left = edge + left
		top_bar.offset_top = top
		top_bar.offset_right = -edge - right
		top_bar.offset_bottom = top + GameConstants.HUD_TOP_BAR_HEIGHT - edge
	if counter:
		var shift := top - edge
		counter.offset_left = edge + left
		counter.offset_top = GameConstants.HUD_COUNTER_ROW_TOP + shift
		counter.offset_right = -edge - right
		counter.offset_bottom = (
			GameConstants.HUD_COUNTER_ROW_TOP + GameConstants.HUD_COUNTER_ROW_HEIGHT + shift
		)


static func apply_bottom_bar_safe_area(control: Control) -> void:
	if control == null:
		return
	if not control.has_meta("_safe_authored"):
		control.set_meta("_safe_authored", true)
		control.set_meta("_safe_t", control.offset_top)
		control.set_meta("_safe_b", control.offset_bottom)
		control.set_meta("_safe_l", control.offset_left)
		control.set_meta("_safe_r", control.offset_right)
	var m := SafeInsets.viewport_margins()
	control.offset_top = float(control.get_meta("_safe_t")) - m.w
	control.offset_bottom = float(control.get_meta("_safe_b")) - m.w
	control.offset_left = float(control.get_meta("_safe_l")) + m.x
	control.offset_right = float(control.get_meta("_safe_r")) - m.z


static func apply_content_edge_safe_area(control: Control) -> void:
	if control == null:
		return
	if not control.has_meta("_safe_authored"):
		control.set_meta("_safe_authored", true)
		control.set_meta("_safe_t", control.offset_top)
		control.set_meta("_safe_b", control.offset_bottom)
		control.set_meta("_safe_l", control.offset_left)
		control.set_meta("_safe_r", control.offset_right)
	var m := SafeInsets.viewport_margins()
	control.offset_top = SafeInsets.padded_top(float(control.get_meta("_safe_t")))
	control.offset_bottom = SafeInsets.padded_bottom_offset(float(control.get_meta("_safe_b")))
	control.offset_left = float(control.get_meta("_safe_l")) + m.x
	control.offset_right = float(control.get_meta("_safe_r")) - m.z


static func position_top_wide(
	control: Control, top: float, height: float, margin: float = GameConstants.HUD_SIDE_MARGIN
) -> void:
	if not control:
		return
	control.set_anchors_preset(Control.PRESET_TOP_WIDE)
	control.offset_left = margin
	control.offset_right = -margin
	control.offset_top = top
	control.offset_bottom = top + height


static func position_status_below_board(status: Control, board_y: float, board_height: float) -> void:
	position_top_wide(
		status, board_y + board_height + GameConstants.HUD_STATUS_GAP, GameConstants.HUD_STATUS_MIN_HEIGHT
	)
	cap_stretched_width(status, HudLayout.UI_PHONE_CONTENT_WIDTH)


static func position_editor_status_below_panel(control_panel: Control, status: Control) -> void:
	if not control_panel or not status:
		return
	var bottom_margin := GameConstants.HUD_TOP_BAR_EDGE_MARGIN + SafeInsets.bottom()
	var status_top := -(bottom_margin + GameConstants.HUD_EDITOR_STATUS_HEIGHT)
	status.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	status.offset_left = bottom_margin
	status.offset_right = -bottom_margin
	status.offset_bottom = -bottom_margin
	status.offset_top = status_top
	control_panel.offset_bottom = 0.0
	var phone_w := HudLayout.UI_PHONE_VIEWPORT_WIDTH - 2.0 * float(GameConstants.HUD_TOP_BAR_EDGE_MARGIN)
	cap_stretched_width(status, phone_w)


static func position_counter_row(counter_row: Control) -> void:
	align_counter_row(counter_row)


static func align_counter_row(counter_row: Control) -> void:
	if counter_row == null:
		return
	if counter_row is HBoxContainer:
		(counter_row as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	for child in counter_row.get_children():
		if child is Control and (child as Control).visible:
			var slot := child as Control
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot.size_flags_stretch_ratio = 1.0
