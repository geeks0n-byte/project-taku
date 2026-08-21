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
static func fit_vbox_dialog_panel(
	panel: Panel,
	width: float = 640.0,
	edge_inset: float = DIALOG_EDGE_INSET,
	extra_pad_v: float = DIALOG_EXTRA_PAD_V,
	min_height: float = 280.0,
	max_height: float = 1600.0
) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	var vbox := panel.get_node_or_null("VBoxContainer") as VBoxContainer
	if vbox == null:
		for child in panel.get_children():
			if child is VBoxContainer:
				vbox = child
				break
	if vbox == null:
		panel.custom_minimum_size = Vector2(width, min_height)
		_sync_center_anchor_offsets(panel)
		return

	var content_w := maxf(120.0, width - edge_inset * 2.0)
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
	panel.custom_minimum_size = Vector2(width, height)
	_sync_center_anchor_offsets(panel)

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
	var content_w := maxf(120.0, width - 96.0)
	var prompt_h := _measure_wrapped_label_height(prompt, content_w) if prompt else 80.0
	var buttons_h := _measure_control_height(buttons, content_w) if buttons else 400.0
	var height := margin_v * 2.0 + extra_pad_v * 2.0 + prompt_h + gap + buttons_h
	height = clampf(height, min_height, max_height)
	panel.custom_minimum_size = Vector2(width, height)

	if prompt:
		prompt.offset_left = 48.0
		prompt.offset_right = -48.0
		prompt.offset_top = margin_v + extra_pad_v
		prompt.offset_bottom = prompt.offset_top + prompt_h
	if buttons:
		var buttons_top := (margin_v + extra_pad_v) + prompt_h + gap
		buttons.offset_top = buttons_top
		buttons.offset_bottom = buttons_top + buttons_h

## Consent / freeform content column: height from children, keep outer spacers.
static func fit_content_column(
	content: Control,
	width: float = 760.0,
	extra_pad_v: float = DIALOG_EXTRA_PAD_V,
	min_height: float = 200.0,
	max_height: float = 1600.0
) -> void:
	if content == null or not is_instance_valid(content):
		return
	content.custom_minimum_size.x = width
	var h := _measure_control_height(content, width) + extra_pad_v * 2.0
	content.custom_minimum_size = Vector2(width, clampf(h, min_height, max_height))

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
	var size := panel.custom_minimum_size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	panel.offset_left = -size.x * 0.5
	panel.offset_right = size.x * 0.5
	panel.offset_top = -size.y * 0.5
	panel.offset_bottom = size.y * 0.5

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
		font = ThemeDB.fallback_font
	var text := String(label.text)
	if text.is_empty():
		return float(font_size)
	var measured := font.get_multiline_string_size(
		text,
		label.horizontal_alignment,
		width,
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
				total += maxf(min_sz.y, child_ctrl.custom_minimum_size.y)
		total += sep * maxi(visible_n - 1, 0)
		return total
	var ms := control.get_combined_minimum_size()
	return maxf(ms.y, control.custom_minimum_size.y)
