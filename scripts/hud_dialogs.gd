class_name HudDialogs
extends RefCounted
## Dialog / popup chrome helpers extracted from HudLayout for maintainability.
## Public call sites continue to use HudLayout.* wrappers.

## Horizontal/vertical inset used by VBox-based dialog scenes (matches .tscn offsets).
const DIALOG_EDGE_INSET := 36.0
## Extra breathing room above/below content after fitting to text.
const DIALOG_EXTRA_PAD_V := 20.0

static func make_dialog_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.98)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(28)
	style.border_color = Color(1.0, 0.84, 0.0, 0.4)
	style.set_border_width_all(3)
	return style

## Biases a full-rect CenterContainer upward by shrinking it from the bottom.
static func raise_centered_dialog_host(
	center: Control, raise_px: float = GameConstants.UI_DIALOG_RAISE_PX
) -> void:
	if center == null or not is_instance_valid(center):
		return
	center.offset_bottom = -absf(raise_px) * 2.0

## Sizes a standard Yes/No dialog panel to its prompt + buttons, keeping top/bottom margin.
## Expects Panel → VBoxContainer → [Label, HBoxContainer/buttons].
## Returns inner content width (after edge inset) for nested dynamic content.
static func fit_vbox_dialog_panel(
	panel: Panel,
	width: float = HudLayout.UI_DEFAULT_DIALOG_WIDTH,
	edge_inset: float = DIALOG_EDGE_INSET,
	extra_pad_v: float = DIALOG_EXTRA_PAD_V,
	min_height: float = 280.0,
	max_height: float = 1600.0
) -> float:
	if panel == null or not is_instance_valid(panel):
		return maxf(120.0, width - edge_inset * 2.0)
	var vbox := panel.get_node_or_null("VBoxContainer") as VBoxContainer
	if vbox == null:
		for child in panel.get_children():
			if child is VBoxContainer:
				vbox = child
				break
	if vbox == null:
		width = HudLayout.clamp_dialog_panel_width(width)
		_apply_panel_size(panel, width, min_height)
		return maxf(120.0, width - edge_inset * 2.0)

	var h_inset := _dialog_horizontal_insets(panel, vbox)
	var content_min_w := 0.0
	var sep := float(vbox.get_theme_constant("separation"))
	var body_h := 0.0
	var buttons_h := 0.0
	var other_h := 0.0
	var gaps := 0

	for child in vbox.get_children():
		if not (child is Control) or not (child as Control).visible:
			continue
		gaps += 1
		var ctrl := child as Control
		if child is Label:
			# Use unwrapped line width so localized copy widens the panel instead of
			# wrapping first and then fitting a panel to the broken lines.
			content_min_w = maxf(content_min_w, _measure_label_min_width(child as Label))
		elif child is BoxContainer:
			if _box_is_dialog_button_row(child as BoxContainer):
				content_min_w = maxf(
					content_min_w, _measure_button_row_min_width(child as BoxContainer)
				)
			else:
				content_min_w = maxf(content_min_w, _measure_box_container_min_width(child as BoxContainer))
		else:
			content_min_w = maxf(content_min_w, _measure_control_min_width(ctrl))

	width = maxf(maxf(width, content_min_w + h_inset), HudLayout.UI_MIN_DIALOG_WIDTH)
	width = HudLayout.clamp_dialog_panel_width(width)
	var content_w := maxf(120.0, width - h_inset)
	_constrain_vbox_content_width(vbox, content_w)
	_fit_vbox_dialog_buttons(vbox, content_w)

	for child in vbox.get_children():
		if not (child is Control) or not (child as Control).visible:
			continue
		var ctrl := child as Control
		if child is Label:
			body_h += _measure_wrapped_label_height(child as Label, content_w)
		elif child is BoxContainer:
			buttons_h += _measure_control_height(ctrl, content_w)
		else:
			other_h += _measure_control_height(ctrl, content_w)

	var gap_total := sep * maxi(gaps - 1, 0)
	var height := (
		edge_inset * 2.0
		+ extra_pad_v * 2.0
		+ body_h
		+ buttons_h
		+ other_h
		+ gap_total
	)
	height = clampf(height, min_height, max_height)
	_apply_panel_size(panel, width, height)
	return content_w

## Session-resume panel uses absolute PromptLabel + Buttons layout (not a single VBox).
static func fit_session_resume_panel(
	panel: Panel,
	prompt: Label,
	buttons: Control,
	width: float = 820.0,
	margin_v: float = 40.0,
	gap: float = 40.0,
	extra_pad_v: float = DIALOG_EXTRA_PAD_V,
	min_height: float = 560.0,
	max_height: float = 1600.0
) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var buttons_w := 0.0
	if buttons is BoxContainer:
		buttons_w = _measure_box_container_min_width(buttons as BoxContainer)
	var prompt_w := _measure_label_min_width(prompt) if prompt else 0.0
	width = HudLayout.clamp_dialog_panel_width(
		maxf(maxf(width, buttons_w + 96.0), prompt_w + 96.0)
	)
	var content_w := maxf(120.0, width - 96.0)
	var prompt_h := _measure_wrapped_label_height(prompt, content_w) if prompt else 80.0
	var buttons_h := _measure_control_height(buttons, content_w) if buttons else 400.0
	var height := margin_v * 2.0 + extra_pad_v * 2.0 + prompt_h + gap + buttons_h
	height = clampf(height, min_height, max_height)
	_apply_panel_size(panel, width, height)

	if prompt:
		prompt.offset_left = 48.0
		prompt.offset_right = -48.0
		prompt.offset_top = margin_v + extra_pad_v
		prompt.offset_bottom = prompt.offset_top + prompt_h
	if buttons:
		var buttons_top := (margin_v + extra_pad_v) + prompt_h + gap
		buttons.offset_top = buttons_top
		buttons.offset_bottom = buttons_top + buttons_h

## Consent / freeform content column: width from content; optionally capped like other dialogs.
static func fit_content_column(
	content: Control,
	width: float = 720.0,
	extra_pad_v: float = DIALOG_EXTRA_PAD_V,
	min_height: float = 200.0,
	max_height: float = 1600.0,
	cap_at_dialog_max: bool = true
) -> float:
	if content == null or not is_instance_valid(content):
		return width
	var measured_min := 0.0
	for child in content.get_children():
		if not (child is Control) or not (child as Control).visible:
			continue
		if child is Label:
			measured_min = maxf(measured_min, _measure_label_min_width(child as Label))
		elif child is Button:
			var btn_cap := HudLayout.max_ui_content_width(24.0)
			measured_min = maxf(
				measured_min, _natural_content_column_button_width(child as Button, btn_cap)
			)
		elif child is BoxContainer:
			measured_min = maxf(measured_min, _measure_box_container_min_width(child as BoxContainer))
	var column_w := 0.0
	if cap_at_dialog_max:
		column_w = HudLayout.clamp_dialog_panel_width(maxf(width, measured_min + 32.0))
	else:
		const CONSENT_SIDE_MARGIN := 24.0
		var viewport_w := HudLayout.max_ui_content_width(CONSENT_SIDE_MARGIN)
		column_w = minf(viewport_w, maxf(width, measured_min + 32.0))
		column_w = maxf(column_w, minf(HudLayout.UI_MIN_DIALOG_WIDTH, viewport_w))
	content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for child in content.get_children():
		if not (child is Control) or not (child as Control).visible:
			continue
		if child is Label:
			var label := child as Label
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.custom_minimum_size.x = column_w
			var natural_w := _measure_label_min_width(label)
			if natural_w <= column_w + 2.0:
				label.autowrap_mode = TextServer.AUTOWRAP_OFF
			else:
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		elif child is Button:
			pass  # Buttons are equalized below.
	var column_buttons: Array[Button] = []
	for child in content.get_children():
		if child is Button and (child as Control).visible:
			column_buttons.append(child as Button)
	if not column_buttons.is_empty():
		fit_content_column_buttons(column_buttons, column_w)
	var h := _measure_control_height(content, column_w) + extra_pad_v * 2.0
	content.custom_minimum_size = Vector2(column_w, clampf(h, min_height, max_height))
	return column_w

## Stack buttons at their own single-line widths; wrap only if text exceeds the column.
static func fit_content_column_buttons(
	buttons: Array,
	column_w: float,
	min_width: float = 280.0,
	min_height: float = HudLayout.UI_TILE_BUTTON_MIN_HEIGHT
) -> void:
	for btn in buttons:
		if btn == null or not (btn is Button) or not (btn as Control).visible:
			continue
		_fit_content_column_button(btn as Button, column_w, min_height, min_width)

static func _natural_content_column_button_width(
	button: Button, _column_w: float, min_width: float = 280.0
) -> float:
	if button == null:
		return min_width
	var info := HudLayout._button_label_display(button)
	var display: String = info.get("text", "")
	var font: Font = info.get("font")
	var font_size: int = info.get("font_size", 52)
	if font == null:
		font = HudFonts.default_font()
	return HudLayout.compute_tile_button_single_line_size(
		display, font, font_size, min_width
	).x

static func _fit_content_column_button(
	button: Button,
	_column_w: float,
	min_height: float = HudLayout.UI_TILE_BUTTON_MIN_HEIGHT,
	min_width: float = 280.0
) -> void:
	if button == null:
		return
	var info := HudLayout._button_label_display(button)
	var display: String = info.get("text", "")
	var font: Font = info.get("font")
	var font_size: int = info.get("font_size", 52)
	if font == null:
		font = HudFonts.default_font()
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if display.is_empty():
		button.custom_minimum_size = Vector2(min_width, min_height)
		return
	HudLayout.apply_tile_button_single_line_size(
		button, display, font, font_size, min_height, min_width
	)

static func panel_style_horizontal_insets(panel: Panel) -> float:
	return _panel_style_horizontal_insets(panel)

static func _panel_style_horizontal_insets(panel: Panel) -> float:
	if panel == null:
		return 0.0
	var style := panel.get_theme_stylebox("panel")
	if style == null:
		return 0.0
	return style.get_content_margin(SIDE_LEFT) + style.get_content_margin(SIDE_RIGHT)

static func _dialog_horizontal_insets(panel: Panel, vbox: Control) -> float:
	return _panel_style_horizontal_insets(panel) + _vbox_horizontal_insets(vbox)

static func _vbox_horizontal_insets(vbox: Control) -> float:
	if vbox == null:
		return DIALOG_EDGE_INSET * 2.0
	return maxf(0.0, vbox.offset_left) + maxf(0.0, -vbox.offset_right)

static func _apply_panel_size(panel: Control, width: float, height: float) -> void:
	if panel == null:
		return
	var size := Vector2(width, height)
	panel.custom_minimum_size = size
	panel.size = size
	_sync_center_anchor_offsets(panel)

static func _constrain_vbox_content_width(vbox: VBoxContainer, content_w: float) -> void:
	if vbox == null:
		return
	for child in vbox.get_children():
		if not (child is Control) or not (child as Control).visible:
			continue
		var ctrl := child as Control
		ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if child is Label:
			var label := child as Label
			label.custom_minimum_size.x = content_w
			var natural_w := _measure_label_min_width(label)
			if natural_w <= content_w + 2.0:
				label.autowrap_mode = TextServer.AUTOWRAP_OFF
			else:
				if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
					label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		elif child is BoxContainer:
			if not _box_is_dialog_button_row(child as BoxContainer):
				ctrl.custom_minimum_size.x = content_w
		else:
			ctrl.custom_minimum_size.x = content_w

static func _fit_vbox_dialog_buttons(vbox: VBoxContainer, content_w: float) -> void:
	if vbox == null:
		return
	for child in vbox.get_children():
		if not (child is BoxContainer) or not (child as Control).visible:
			continue
		var box := child as BoxContainer
		if not _box_is_dialog_button_row(box):
			continue
		var buttons: Array = []
		for c in box.get_children():
			if c is Button and (c as Control).visible:
				buttons.append(c)
		if buttons.is_empty():
			continue
		if box is VBoxContainer:
			HudLayout.fit_dialog_button_group(
				buttons,
				true,
				GameConstants.UI_BTN_DIALOG_SIZE.x,
				GameConstants.UI_BTN_DIALOG_SIZE.y
			)
			box.custom_minimum_size.x = content_w
		else:
			HudLayout.fit_dialog_button_group(
				buttons,
				true,
				GameConstants.UI_BTN_DIALOG_SIZE.x,
				GameConstants.UI_BTN_DIALOG_SIZE.y,
				content_w
			)

static func _box_is_dialog_button_row(box: BoxContainer) -> bool:
	if box == null:
		return false
	var has_button := false
	var has_other := false
	for c in box.get_children():
		if not (c is Control) or not (c as Control).visible:
			continue
		if c is Button:
			has_button = true
		else:
			has_other = true
	return has_button and not has_other

static func _measure_control_min_width(control: Control) -> float:
	if control == null:
		return 0.0
	if control is Label:
		return _measure_label_min_width(control as Label)
	if control is BoxContainer:
		return _measure_box_container_min_width(control as BoxContainer)
	var child_w := 0.0
	for child in control.get_children():
		if child is Control and (child as Control).visible:
			child_w = maxf(child_w, _measure_control_min_width(child as Control))
	if child_w > 0.0:
		return child_w
	return maxf(control.custom_minimum_size.x, control.get_combined_minimum_size().x)

static func _measure_button_row_min_width(box: BoxContainer) -> float:
	if box == null:
		return 0.0
	var sep := float(box.get_theme_constant("separation"))
	var sum_w := 0.0
	var max_w := 0.0
	var visible_n := 0
	for child in box.get_children():
		if not (child is Button) or not (child as Control).visible:
			continue
		visible_n += 1
		var btn_w := HudLayout.measure_dialog_button_min_width(child as Button)
		sum_w += btn_w
		max_w = maxf(max_w, btn_w)
	if box is HBoxContainer:
		return sum_w + sep * maxi(visible_n - 1, 0)
	return max_w

static func _sync_center_anchor_offsets(panel: Control) -> void:
	# Panels placed with PRESET_CENTER + fixed offsets need offsets refreshed when size changes.
	if panel == null:
		return
	var uses_center := (
		is_equal_approx(panel.anchor_left, 0.5)
		and is_equal_approx(panel.anchor_right, 0.5)
		and is_equal_approx(panel.anchor_top, 0.5)
		and is_equal_approx(panel.anchor_bottom, 0.5)
	)
	if not uses_center:
		return
	var size := panel.size
	if size.x <= 0.0 or size.y <= 0.0:
		size = panel.custom_minimum_size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	panel.offset_left = -size.x * 0.5
	panel.offset_right = size.x * 0.5
	panel.offset_top = -size.y * 0.5
	panel.offset_bottom = size.y * 0.5

static func measure_control_height(control: Control, width: float) -> float:
	return _measure_control_height(control, width)

static func measure_label_height(label: Label, width: float) -> float:
	return _measure_wrapped_label_height(label, width)

static func measure_label_min_width(label: Label) -> float:
	return _measure_label_min_width(label)

static func measure_text_max_line_width(font: Font, text: String, font_size: int) -> float:
	return _measure_text_max_line_width(font, text, font_size)

static func count_wrapped_text_lines(
	font: Font, text: String, width: float, font_size: int
) -> int:
	if text.is_empty() or font == null or width <= 0.0:
		return 1
	var measured := font.get_multiline_string_size(
		text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size
	)
	var line_h := maxf(1.0, font.get_height(font_size))
	return maxi(1, ceili(measured.y / line_h))

static func _measure_label_min_width(label: Label) -> float:
	if label == null:
		return 0.0
	var font: Font = label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	if label.label_settings:
		if label.label_settings.font:
			font = label.label_settings.font
		if label.label_settings.font_size > 0:
			font_size = label.label_settings.font_size
	if font == null:
		font = HudFonts.default_font()
	var text := String(label.text)
	if text.is_empty():
		return 0.0
	return _measure_text_max_line_width(font, text, font_size) + _label_measure_horizontal_padding(label)

static func _label_measure_horizontal_padding(label: Label) -> float:
	var outline := 0
	if label.label_settings:
		outline = label.label_settings.outline_size
	else:
		outline = label.get_theme_constant("outline_size")
	return float(outline) * 2.0 + 32.0

static func _measure_text_max_line_width(font: Font, text: String, font_size: int) -> float:
	if text.is_empty() or font == null:
		return 0.0
	var max_w := 0.0
	for line in text.split("\n"):
		var stripped := line.strip_edges()
		if stripped.is_empty():
			continue
		max_w = maxf(
			max_w, font.get_string_size(stripped, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		)
	if max_w <= 0.0:
		max_w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return max_w

static func _measure_box_container_min_width(box: BoxContainer) -> float:
	if box == null:
		return 0.0
	var sep := float(box.get_theme_constant("separation"))
	var max_w := 0.0
	var sum_w := 0.0
	var visible_n := 0
	for child in box.get_children():
		if not (child is Control) or not (child as Control).visible:
			continue
		visible_n += 1
		var ctrl := child as Control
		var child_w := 0.0
		if child is Label:
			child_w = _measure_label_min_width(child as Label)
		elif child is BoxContainer:
			child_w = _measure_box_container_min_width(child as BoxContainer)
		else:
			child_w = maxf(ctrl.custom_minimum_size.x, ctrl.get_combined_minimum_size().x)
			child_w = maxf(child_w, _measure_control_min_width(ctrl))
		max_w = maxf(max_w, child_w)
		sum_w += child_w
	if box is HBoxContainer:
		return sum_w + sep * maxi(visible_n - 1, 0)
	if box is VBoxContainer:
		return max_w
	return max_w

static func _measure_wrapped_label_height(label: Label, width: float) -> float:
	if label == null:
		return 0.0
	var font: Font = label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	if label.label_settings:
		if label.label_settings.font:
			font = label.label_settings.font
		if label.label_settings.font_size > 0:
			font_size = label.label_settings.font_size
	if font == null:
		font = HudFonts.default_font()
	var text := String(label.text)
	if text.is_empty():
		return float(font_size)
	var natural_w := _measure_text_max_line_width(font, text, font_size)
	var measure_w := width if natural_w > width + 2.0 else maxf(width, natural_w)
	var measured := font.get_multiline_string_size(
		text,
		label.horizontal_alignment,
		measure_w,
		font_size,
		-1,
		TextServer.BREAK_WORD_BOUND | TextServer.BREAK_MANDATORY
	)
	var line_spacing := float(label.get_theme_constant("line_spacing"))
	# get_multiline_string_size already includes glyph height; add a little for outline/spacing.
	return maxf(float(font_size), measured.y + maxf(0.0, line_spacing) * 0.5)

static func _measure_control_height(control: Control, width: float) -> float:
	if control == null:
		return 0.0
	if control is BoxContainer:
		var box := control as BoxContainer
		var sep := float(box.get_theme_constant("separation"))
		var total := 0.0
		var visible_n := 0
		for child in box.get_children():
			if not (child is Control) or not (child as Control).visible:
				continue
			visible_n += 1
			var child_ctrl := child as Control
			if child is Label:
				total += _measure_wrapped_label_height(child as Label, width)
			else:
				var min_sz := child_ctrl.get_combined_minimum_size()
				var child_h := maxf(min_sz.y, child_ctrl.custom_minimum_size.y)
				if child_h <= 0.0 and child_ctrl.get_child_count() > 0:
					child_h = _measure_control_height(child_ctrl, width)
				total += child_h
		total += sep * maxi(visible_n - 1, 0)
		return total
	if control.get_child_count() > 0:
		var nested_h := 0.0
		for child in control.get_children():
			if child is Control and (child as Control).visible:
				nested_h += _measure_control_height(child as Control, width)
		if nested_h > 0.0:
			return maxf(nested_h, control.custom_minimum_size.y)
	var ms := control.get_combined_minimum_size()
	return maxf(ms.y, control.custom_minimum_size.y)
