class_name HudButtons
extends RefCounted
## Button sizing/styling and toggle-mask helpers extracted from HudLayout.
## Public call sites continue to use HudLayout.* wrappers.

# Shrinks a button's font until the wrapped text fits within the button's minimum
# size minus padding. Useful for long translated strings that otherwise overflow.
static func fit_text_button(button: Button, base_font_size: int = 36, min_font_size: int = 18) -> void:
	if not button:
		return
	if HudLayout._is_icon_only_button(button):
		return
	button.clip_text = false
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var use_pixel := HudLayout.control_uses_pixel_font(button)
	var font: Font = (
		HudFonts.default_font() if button.get_meta("_use_default_font", false) else (
			HudLayout.pixel_font() if use_pixel else HudLayout.ui_font()
		)
	)
	if font == null:
		font = HudFonts.default_font()
	var target_w := maxf(40.0, button.custom_minimum_size.x - 28.0)
	var target_h := maxf(40.0, button.custom_minimum_size.y - 24.0)
	var display := button.text
	if button.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED:
		display = String(TranslationServer.translate(button.text))
	if display.is_empty():
		return
	var size: int
	var min_size: int
	if use_pixel:
		size = HudLayout.snap_pixel_font_size(base_font_size)
		min_size = HudLayout.snap_pixel_font_size(min_font_size)
	else:
		size = HudLayout.body_font_size(base_font_size)
		min_size = HudLayout.body_font_size(min_font_size)
	var step := 8 if use_pixel else 2
	while size > min_size:
		var measured := font.get_multiline_string_size(display, HORIZONTAL_ALIGNMENT_CENTER, target_w, size)
		if measured.x <= target_w + 2.0 and measured.y <= target_h + 2.0:
			break
		size = maxi(min_size, size - step)
	if use_pixel:
		size = HudLayout.snap_pixel_font_size(size)
	HudLayout._clear_pixel_raster(button)
	HudLayout.apply_locale_font_to_control(button)
	button.add_theme_font_size_override("font_size", size)
	var base_outline := int(button.get_theme_constant("outline_size"))
	if base_outline <= 0:
		base_outline = GameConstants.MENU_TEXT_OUTLINE
	apply_safe_outline(button, base_outline)

# Same as fit_text_button but for single-line buttons only (AUTOWRAP_OFF).
# Shrinks font until the text width fits, ignoring height.
static func fit_text_button_single_line(button: Button, base_font_size: int = 36, min_font_size: int = 18) -> void:
	if not button:
		return
	if HudLayout._is_icon_only_button(button):
		return
	button.clip_text = false
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	var use_pixel := HudLayout.control_uses_pixel_font(button)
	var font: Font = (
		HudFonts.default_font() if button.get_meta("_use_default_font", false) else (
			HudLayout.pixel_font() if use_pixel else HudLayout.ui_font()
		)
	)
	if font == null:
		font = HudFonts.default_font()
	var target_w := maxf(40.0, button.custom_minimum_size.x - 36.0)
	var display := button.text
	if button.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED:
		display = String(TranslationServer.translate(button.text))
	if display.is_empty():
		return
	var size: int
	var min_size: int
	if use_pixel:
		size = HudLayout.snap_pixel_font_size(base_font_size)
		min_size = HudLayout.snap_pixel_font_size(min_font_size)
	else:
		size = HudLayout.body_font_size(base_font_size)
		min_size = HudLayout.body_font_size(min_font_size)
	var step := 8 if use_pixel else 2
	while size > min_size:
		var measured := font.get_string_size(display, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		if measured.x <= target_w + 2.0:
			break
		size = maxi(min_size, size - step)
	if use_pixel:
		size = HudLayout.snap_pixel_font_size(size)
	HudLayout._clear_pixel_raster(button)
	HudLayout.apply_locale_font_to_control(button)
	button.add_theme_font_size_override("font_size", size)
	var base_outline := int(button.get_theme_constant("outline_size"))
	if base_outline <= 0:
		base_outline = GameConstants.MENU_TEXT_OUTLINE
	apply_safe_outline(button, base_outline)

# Returns true when running on a physical mobile device or the Android/iOS simulator.
# Used to select a slightly smaller default font size on small screens.
static func _is_mobile_ui() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		return true
	var os_name := OS.get_name()
	return os_name == "Android" or os_name == "iOS"

# Returns true when the current locale should use the scalable theme font instead of Press Start.
static func prefer_default_font() -> bool:
	return not HudLayout.uses_pixel_font()

# Applies a text outline safely: strips it for Press Start controls (outline_size
# scrambles glyphs under GL Compatibility), applies a black outline for all others.
static func apply_safe_outline(control: Control, base_outline: int = GameConstants.MENU_TEXT_OUTLINE) -> void:
	if not control:
		return
	# Only strip live outlines from Press Start itself. Default-font English UI
	# (counters, HTP body, etc.) can keep theme outlines safely.
	if HudLayout._is_live_pixel_control(control):
		# Press Start + theme outlines scramble glyphs under GL Compatibility.
		HudLayout._strip_live_pixel_outline(control)
		return
	control.add_theme_constant_override("shadow_offset_x", 0)
	control.add_theme_constant_override("shadow_offset_y", 0)
	var outline := clampi(base_outline, 0, maxi(1, base_outline))
	control.add_theme_color_override("font_outline_color", Color.BLACK)
	control.add_theme_constant_override("outline_size", outline)

# Sets the standard primary-button minimum size and fits its text font.
static func apply_primary_button(button: Button) -> void:
	if not button:
		return
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = GameConstants.UI_BTN_PRIMARY_SIZE
	fit_text_button(
		button, GameConstants.UI_BTN_PRIMARY_FONT, GameConstants.UI_BTN_PRIMARY_FONT_MIN
	)

# Sets the standard secondary-button minimum size and fits its text font.
static func apply_secondary_button(button: Button) -> void:
	if not button:
		return
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = GameConstants.UI_BTN_SECONDARY_SIZE
	fit_text_button(
		button, GameConstants.UI_BTN_SECONDARY_FONT, GameConstants.UI_BTN_SECONDARY_FONT_MIN
	)

# Sizes and styles a dialog confirm/cancel button (Yes/No), translating its text
# and routing through apply_raster_pixel_button for font consistency.
static func apply_dialog_button(button: Button, display_override: String = "") -> void:
	if not button:
		return
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = GameConstants.UI_BTN_DIALOG_SIZE
	# Prefer explicit / button.text when set (e.g. after tr() on locale change); stale
	# PixelSafeCaption would otherwise win for words like Polish "TAK" that look like keys.
	var display := display_override.strip_edges()
	if display.is_empty():
		display = String(button.text)
	if display.is_empty() or HudHeaders.is_i18n_key(display):
		var info := _button_label_display(button)
		display = String(info.get("text", ""))
	if not display.is_empty() and HudHeaders.is_i18n_key(display):
		display = String(TranslationServer.translate(display))
	HudLayout.apply_raster_pixel_button(button, display, GameConstants.UI_BTN_DIALOG_FONT)
	grow_dialog_button_to_text(button)

## Applies dialog styling and grows width to fit the label (single-button popups).
static func apply_dialog_button_fitted(
	button: Button,
	min_width: float = -1.0
) -> void:
	apply_dialog_button(button)
	var base := GameConstants.UI_BTN_DIALOG_SIZE
	grow_button_to_text(
		button,
		base.y,
		48.0,
		base.x if min_width < 0.0 else min_width
	)

## Styles dialog buttons and optionally gives them a shared width (max of the group).
## When `max_total_width` is set, the group is capped to that width (e.g. panel content area).
static func fit_dialog_button_group(
	buttons: Array,
	equal_width: bool = true,
	min_width: float = GameConstants.UI_BTN_DIALOG_SIZE.x,
	height: float = GameConstants.UI_BTN_DIALOG_SIZE.y,
	max_total_width: float = -1.0
) -> void:
	if buttons.is_empty():
		return
	for btn in buttons:
		if btn == null or not (btn is Button):
			continue
		apply_dialog_button(btn)
	if not equal_width:
		return
	equalize_button_group_widths(buttons, min_width, height, max_total_width)

## Sets every button in the group to the widest minimum width (locale-aware sizing).
static func equalize_button_group_widths(
	buttons: Array,
	min_width: float = 160.0,
	height: float = -1.0,
	max_total_width: float = -1.0
) -> void:
	var visible_btns: Array[Button] = []
	for btn in buttons:
		if btn == null or not (btn is Button):
			continue
		if not (btn as CanvasItem).visible:
			continue
		visible_btns.append(btn)
	if visible_btns.is_empty():
		return
	for btn in visible_btns:
		grow_dialog_button_to_text(btn)
	var shared_w := min_width
	for btn in visible_btns:
		shared_w = maxf(shared_w, measure_dialog_button_min_width(btn))
	if max_total_width > 0.0:
		var in_hbox := false
		if not visible_btns.is_empty():
			var parent := visible_btns[0].get_parent()
			in_hbox = parent is HBoxContainer
		if in_hbox:
			var n := visible_btns.size()
			var sep_total := 40.0 * float(maxi(n - 1, 0))
			var row_natural := shared_w * float(n) + sep_total
			if row_natural > max_total_width:
				shared_w = maxf(
					80.0, (max_total_width - sep_total) / float(maxi(n, 1))
				)
	else:
		shared_w = HudLayout.cap_ui_width(shared_w)
	for btn in visible_btns:
		var button := btn as Button
		var btn_h := height if height > 0.0 else button.custom_minimum_size.y
		var info := _button_label_display(button)
		var caption: Label = info.get("caption")
		_reset_button_single_line(button, caption)
		button.custom_minimum_size = Vector2(shared_w, btn_h)

static func _button_label_display(button: Button) -> Dictionary:
	var display := button.text
	var font: Font = button.get_theme_font("font")
	var font_size := button.get_theme_font_size("font_size")
	var caption := button.get_node_or_null("PixelSafeCaption/Caption") as Label
	if caption == null:
		# Victory / panel buttons often draw via a nested Label (e.g. HBox/Label).
		for node in button.find_children("*", "Label", true, false):
			var label := node as Label
			if label == null or label.text.strip_edges().is_empty():
				continue
			if bool(label.get_meta("_pixel_outline_part", false)):
				continue
			caption = label
			break
	if caption:
		display = caption.text
		if caption.label_settings != null:
			font = caption.label_settings.font
			font_size = caption.label_settings.font_size
		else:
			font = caption.get_theme_font("font")
			font_size = caption.get_theme_font_size("font_size")
	elif display.is_empty() or HudHeaders.is_i18n_key(display):
		var key := display if not display.is_empty() else String(button.get_meta("_tr_key", ""))
		if not key.is_empty():
			display = String(TranslationServer.translate(key))
	return {"text": display, "font": font, "font_size": font_size, "caption": caption}

## Single-line width for a dialog button label (used to size panels before wrapping).
static func measure_dialog_button_min_width(
	button: Button, horizontal_padding: float = 48.0
) -> float:
	if button == null:
		return GameConstants.UI_BTN_DIALOG_SIZE.x
	var info := _button_label_display(button)
	var display: String = info.get("text", "")
	var font: Font = info.get("font")
	var font_size: int = info.get("font_size", GameConstants.UI_BTN_DIALOG_FONT)
	if font == null:
		font = HudFonts.default_font()
	if display.is_empty():
		return GameConstants.UI_BTN_DIALOG_SIZE.x
	var text_w := HudDialogs.measure_text_max_line_width(font, display, font_size)
	return maxf(GameConstants.UI_BTN_DIALOG_SIZE.x, text_w + horizontal_padding)

static func _reset_button_single_line(button: Button, caption: Label) -> void:
	if caption:
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.autowrap_mode = TextServer.AUTOWRAP_OFF

static func _apply_button_wrapped_size(
	button: Button,
	caption: Label,
	display: String,
	font: Font,
	font_size: int,
	width: float,
	min_height: float,
	horizontal_padding: float,
	vertical_padding: float = 20.0
) -> void:
	var inner_w := maxf(40.0, width - horizontal_padding)
	if caption:
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var measured := font.get_multiline_string_size(
		display, HORIZONTAL_ALIGNMENT_CENTER, inner_w, font_size
	)
	var line_h := maxf(1.0, font.get_height(font_size))
	var max_text_h := line_h * float(UI_TILE_BUTTON_MAX_LINES)
	var text_h := minf(measured.y, max_text_h)
	var btn_h := maxf(min_height, text_h + vertical_padding)
	button.custom_minimum_size = Vector2(width, btn_h)

static func _button_uses_tile_style(button: Button) -> bool:
	if button == null:
		return false
	var normal := button.get_theme_stylebox("normal")
	return normal is StyleBoxTexture

## Tile-style overlay buttons (consent, etc.).
const UI_TILE_BUTTON_H_PAD := 96.0
const UI_TILE_BUTTON_V_PAD := 40.0
const UI_TILE_BUTTON_MIN_HEIGHT := 118.0
## Single-line tile buttons wider than this wrap (up to [member UI_TILE_BUTTON_MAX_LINES] lines).
const UI_TILE_BUTTON_PREFER_WRAP_WIDTH := 560.0
const UI_TILE_BUTTON_MAX_LINES := 2

## Width/height for a tile button label — single line when narrow, else ≤2 wrapped lines.
static func compute_tile_button_size(
	display: String,
	font: Font,
	font_size: int,
	column_w: float,
	min_width: float = 280.0,
	min_height: float = UI_TILE_BUTTON_MIN_HEIGHT,
	h_pad: float = UI_TILE_BUTTON_H_PAD,
	v_pad: float = UI_TILE_BUTTON_V_PAD
) -> Vector2:
	if display.is_empty() or font == null:
		return Vector2(min_width, min_height)
	var line_h := maxf(1.0, font.get_height(font_size))
	var text_w := HudDialogs.measure_text_max_line_width(font, display, font_size)
	var single_w := maxf(min_width, text_w + h_pad)
	var single_h := maxf(min_height, line_h + v_pad)
	# Keep short labels on one line; wider copy wraps near the preferred width.
	if single_w <= UI_TILE_BUTTON_PREFER_WRAP_WIDTH + 2.0:
		return Vector2(minf(column_w, single_w), single_h)
	var btn_w := maxf(min_width, minf(UI_TILE_BUTTON_PREFER_WRAP_WIDTH, column_w))
	var inner_w := maxf(40.0, btn_w - h_pad)
	while (
		HudDialogs.count_wrapped_text_lines(font, display, inner_w, font_size) > UI_TILE_BUTTON_MAX_LINES
		and btn_w < column_w - 1.0
	):
		btn_w = minf(column_w, btn_w + 24.0)
		inner_w = maxf(40.0, btn_w - h_pad)
	var measured := font.get_multiline_string_size(
		display, HORIZONTAL_ALIGNMENT_CENTER, inner_w, font_size
	)
	var max_text_h := line_h * float(UI_TILE_BUTTON_MAX_LINES)
	var text_h := minf(measured.y, max_text_h)
	var btn_h := maxf(min_height, text_h + v_pad)
	return Vector2(btn_w, btn_h)

## Single-line width/height for a tile-style button label.
static func compute_tile_button_single_line_size(
	display: String,
	font: Font,
	font_size: int,
	min_width: float = 280.0,
	min_height: float = UI_TILE_BUTTON_MIN_HEIGHT,
	h_pad: float = UI_TILE_BUTTON_H_PAD,
	v_pad: float = UI_TILE_BUTTON_V_PAD
) -> Vector2:
	if display.is_empty() or font == null:
		return Vector2(min_width, min_height)
	var line_h := maxf(1.0, font.get_height(font_size))
	var text_w := HudDialogs.measure_text_max_line_width(font, display, font_size)
	return Vector2(maxf(min_width, text_w + h_pad), maxf(min_height, line_h + v_pad))

## Sizes a tile button for a single unwrapped caption line.
static func apply_tile_button_single_line_size(
	button: Button,
	display: String,
	font: Font,
	font_size: int,
	min_height: float = UI_TILE_BUTTON_MIN_HEIGHT,
	min_width: float = 280.0,
	h_pad: float = UI_TILE_BUTTON_H_PAD,
	v_pad: float = UI_TILE_BUTTON_V_PAD
) -> void:
	if button == null:
		return
	var info := _button_label_display(button)
	var caption: Label = info.get("caption")
	_reset_button_single_line(button, caption)
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.custom_minimum_size = compute_tile_button_single_line_size(
		display, font, font_size, min_width, min_height, h_pad, v_pad
	)

## Sizes a tile button, wrapping only when the caption exceeds the prefer-wrap width.
static func apply_tile_button_size(
	button: Button,
	display: String,
	font: Font,
	font_size: int,
	column_w: float,
	min_height: float = UI_TILE_BUTTON_MIN_HEIGHT,
	min_width: float = 280.0,
	h_pad: float = UI_TILE_BUTTON_H_PAD,
	v_pad: float = UI_TILE_BUTTON_V_PAD
) -> void:
	if button == null:
		return
	var info := _button_label_display(button)
	var caption: Label = info.get("caption")
	var size := compute_tile_button_size(
		display, font, font_size, column_w, min_width, min_height, h_pad, v_pad
	)
	var text_w := HudDialogs.measure_text_max_line_width(font, display, font_size)
	var use_single_line := text_w + h_pad <= UI_TILE_BUTTON_PREFER_WRAP_WIDTH + 2.0
	if use_single_line:
		_reset_button_single_line(button, caption)
		button.custom_minimum_size = size
	else:
		_apply_button_wrapped_size(
			button, caption, display, font, font_size,
			size.x, min_height, h_pad, v_pad
		)
		button.custom_minimum_size.y = size.y

## Sets a button's width from its current label (locale-aware). Height is fixed.
static func grow_button_to_text(
	button: Button,
	height: float,
	horizontal_padding: float = 48.0,
	min_width: float = 160.0
) -> void:
	if not button:
		return
	var info := _button_label_display(button)
	var display: String = info.get("text", "")
	var font: Font = info.get("font")
	var font_size: int = info.get("font_size", 16)
	var caption: Label = info.get("caption")
	if font == null or display.is_empty():
		button.custom_minimum_size = Vector2(min_width, height)
		return
	var text_w := HudDialogs.measure_text_max_line_width(font, display, font_size)
	var desired_w := maxf(min_width, text_w + horizontal_padding)
	_reset_button_single_line(button, caption)
	button.custom_minimum_size = Vector2(desired_w, height)

## Grows a dialog button's width to fit its current label (locale-aware).
## Height stays at UI_BTN_DIALOG_SIZE.y. Used by the tutorial NEXT control.
static func grow_dialog_button_to_text(button: Button, horizontal_padding: float = 48.0) -> void:
	var base := GameConstants.UI_BTN_DIALOG_SIZE
	grow_button_to_text(button, base.y, horizontal_padding, base.x)

## Grows a panel button's width to fit its label; never thinner than UI_BTN_PANEL_SIZE.x.
static func grow_panel_button_to_text(button: Button, horizontal_padding: float = 48.0) -> void:
	var base := GameConstants.UI_BTN_PANEL_SIZE
	grow_button_to_text(button, base.y, horizontal_padding, base.x)

# Styles a "panel" button (victory screen: Next Level, Play Again, Main Menu).
# Height is UI_BTN_PANEL_SIZE.y; width grows to the label with that size as a minimum.
# Latin/digits/symbols use Press Start even in ka/uk; native-script copy uses Noto.
static func apply_panel_button(button: Button) -> void:
	if not button:
		return
	button.focus_mode = Control.FOCUS_NONE
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.clip_text = false
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size = GameConstants.UI_BTN_PANEL_SIZE
	var display := HudLayout._resolved_control_text(button)
	if display.is_empty():
		display = button.text.strip_edges()
	if display.is_empty():
		var info := _button_label_display(button)
		display = String(info.get("text", ""))
	if HudFonts.should_use_press_start_font(display) and not display.is_empty():
		button.set_meta("_use_default_font", false)
		if HudLayout._in_force_pixel_subtree(button):
			button.set_meta("_force_pixel_font", true)
		# Prefer caption on the button itself when there is no nested Label chrome.
		var nested := button.get_node_or_null("HBoxContainer/Label") as Label
		if nested == null:
			nested = button.get_node_or_null("Label") as Label
		if nested:
			HudLayout.apply_raster_pixel_label(
				nested, display, GameConstants.UI_BTN_PANEL_FONT, Color.WHITE
			)
		else:
			HudLayout.apply_raster_pixel_button(
				button, display, GameConstants.UI_BTN_PANEL_FONT
			)
		grow_panel_button_to_text(button)
		return
	var use_pixel := HudLayout.control_uses_pixel_font(button)
	button.set_meta("_use_default_font", not use_pixel)
	if use_pixel:
		if HudLayout._in_force_pixel_subtree(button):
			button.set_meta("_force_pixel_font", true)
		HudLayout._strip_live_pixel_outline(button)
	else:
		apply_safe_outline(button, 8)
	if not display.is_empty() and button.text.strip_edges().is_empty():
		# Keep i18n key on the button when a nested Label owns the visible copy.
		pass
	elif not display.is_empty():
		button.text = display
	button.add_theme_font_size_override(
		"font_size", HudLayout.body_font_size(GameConstants.UI_BTN_PANEL_FONT)
	)
	HudLayout.apply_locale_font_to_control(button)
	grow_panel_button_to_text(button)

## Applies the gray-dark tile texture style to a button.
## Height is fixed to [param height]; width auto-fits the text label.
## Font is set to [param font_size] (scaled). Used for consent and similar overlay buttons.
static func apply_tile_button(
	button: Button,
	texture: Texture2D,
	font_size: int = 52,
	height: float = 118.0
) -> void:
	if not button:
		return
	button.focus_mode = Control.FOCUS_NONE
	button.flat = false
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.clip_text = false
	button.custom_minimum_size = Vector2(0.0, height)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	for style_name in ["normal", "pressed", "hover", "disabled", "focus"]:
		var box := StyleBoxTexture.new()
		box.texture = texture
		box.texture_margin_left = 16.0
		box.texture_margin_top = 16.0
		box.texture_margin_right = 16.0
		box.texture_margin_bottom = 16.0
		box.content_margin_left = 48.0
		box.content_margin_top = 8.0
		box.content_margin_right = 48.0
		box.content_margin_bottom = 8.0
		match style_name:
			"hover":    box.modulate_color = Color(1.2, 1.2, 1.2, 1.0)
			"pressed":  box.modulate_color = Color(0.8, 0.8, 0.8, 1.0)
			"disabled": box.modulate_color = Color(0.55, 0.55, 0.55, 1.0)
		button.add_theme_stylebox_override(style_name, box)
	var use_default := prefer_default_font()
	button.set_meta("_use_default_font", use_default)
	button.set_meta("_force_pixel_font", false)
	if button.has_theme_font_override("font"):
		button.remove_theme_font_override("font")
	button.add_theme_font_override("font", HudFonts.default_font() if use_default else HudLayout.pixel_font())
	HudLayout.apply_locale_font_to_control(button)
	button.add_theme_font_size_override("font_size", HudLayout.scaled_font_size(font_size))
	fit_text_button_single_line(button, font_size, maxi(18, font_size - 24))
	var font := button.get_theme_font("font")
	var size := button.get_theme_font_size("font_size")
	var display := button.text
	if font and not display.is_empty():
		apply_tile_button_single_line_size(
			button, display, font, size, height
		)
	apply_safe_outline(button, GameConstants.MENU_TEXT_OUTLINE)

# Iterates all Label descendants of a panel button and shrinks each one's font
# until the text fits within the button's minimum width. Skips caption overlays
# and labels that already have their own LabelSettings or pixel styling.
static func _fit_panel_button_captions(button: Button) -> void:
	if not button:
		return
	for node in button.find_children("*", "Label", true, false):
		var label := node as Label
		if label == null:
			continue
		if label.name == "Caption" or label.name == "PixelSafeCaption":
			continue
		if label.get_parent() != null and String(label.get_parent().name) == "PixelSafeCaption":
			continue
		if HudLayout.has_pixel_text_overlay(label):
			continue
		if label.label_settings != null or bool(label.get_meta("_safe_pixel_label", false)):
			continue
		_fit_caption_label(
			label,
			button.custom_minimum_size,
			GameConstants.UI_BTN_PANEL_FONT,
			GameConstants.UI_BTN_PANEL_FONT_MIN
		)

# Shrinks a single caption Label's font until its single-line width fits inside
# the button's minimum width minus padding, using the correct font for the locale.
static func _fit_caption_label(
	label: Label,
	button_size: Vector2,
	base_font_size: int,
	min_font_size: int
) -> void:
	if not label:
		return
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = false
	var display := label.text
	if HudHeaders.is_message_key(display):
		display = String(TranslationServer.translate(display))
	var use_pixel := HudLayout.control_uses_pixel_font(label)
	var font: Font = HudLayout.pixel_font_clean() if use_pixel else HudFonts.default_font()
	if font == null:
		font = HudFonts.default_font()
	if font == null:
		return
	var target_w := maxf(40.0, button_size.x - 36.0)
	var size: int
	var min_size: int
	if use_pixel:
		size = HudLayout.snap_pixel_font_size(base_font_size)
		min_size = HudLayout.snap_pixel_font_size(min_font_size)
	else:
		size = HudLayout.body_font_size(base_font_size)
		min_size = HudLayout.body_font_size(min_font_size)
	var step := 8 if use_pixel else 2
	while size > min_size:
		var measured := font.get_string_size(display, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		if measured.x <= target_w + 2.0:
			break
		size = maxi(min_size, size - step)
	if use_pixel:
		size = HudLayout.snap_pixel_font_size(size)
	var color := Color.WHITE
	if label.has_theme_color_override("font_color"):
		color = label.get_theme_color("font_color")
	if use_pixel:
		HudLayout.apply_live_pixel_label_settings(label, display, size, color)
		return
	HudLayout.clear_label_settings(label)
	label.set_meta("_use_default_font", true)
	label.text = display
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	apply_safe_outline(label, GameConstants.MENU_TEXT_OUTLINE)

# Sizes and fits text for a tab-style button (e.g. editor mode tabs).
static func apply_tab_button(button: Button) -> void:
	if not button:
		return
	button.custom_minimum_size = GameConstants.UI_BTN_TAB_SIZE
	fit_text_button(button, GameConstants.UI_BTN_TAB_FONT, GameConstants.UI_BTN_TAB_FONT_MIN)
# Adds or updates the amber/white rounded overlay that indicates a toggled-on
# or tutorial-highlighted button.
static func apply_toggle_active_mask(button: Button, is_on: bool, tint: Color = GameConstants.TOGGLE_MASK_AMBER) -> void:
	if not button:
		return
	var mask := button.get_node_or_null("ActiveMask") as Panel
	if mask == null:
		mask = Panel.new()
		mask.name = "ActiveMask"
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mask.set_anchors_preset(Control.PRESET_FULL_RECT)
		mask.offset_left = 12.0
		mask.offset_top = 12.0
		mask.offset_right = -12.0
		mask.offset_bottom = -12.0
		button.add_child(mask)
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.set_corner_radius_all(10)
	style.set_content_margin_all(0)
	mask.add_theme_stylebox_override("panel", style)
	mask.visible = is_on
	mask.modulate = Color.WHITE
	button.modulate = Color.WHITE
	if not is_on:
		stop_toggle_mask_breathe(button)

# Starts a looping tween that fades the ActiveMask alpha between 1.0 and 0.35,
# drawing the player's attention to the highlighted tutorial button.
static func start_toggle_mask_breathe(button: Button) -> void:
	if not button:
		return
	var mask := button.get_node_or_null("ActiveMask") as CanvasItem
	if mask == null or not mask.visible:
		return
	stop_toggle_mask_breathe(button)
	mask.modulate = Color(1, 1, 1, 1)
	var tween := button.create_tween().set_loops()
	tween.tween_property(mask, "modulate:a", 0.35, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(mask, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	button.set_meta("_toggle_mask_breathe", tween)

# Kills the breathe tween and resets the ActiveMask to fully opaque white.
static func stop_toggle_mask_breathe(button: Button) -> void:
	if not button:
		return
	if button.has_meta("_toggle_mask_breathe"):
		var tween: Tween = button.get_meta("_toggle_mask_breathe")
		if tween:
			tween.kill()
		button.remove_meta("_toggle_mask_breathe")
	var mask := button.get_node_or_null("ActiveMask") as CanvasItem
	if mask:
		mask.modulate = Color.WHITE

# Starts a looping scale+brightness pulse to attract attention to a button
# (e.g. the hint button when hints are available). Pivot is centred first.
static func start_button_attention_pulse(button: Button) -> void:
	if not button:
		return
	stop_button_attention_pulse(button)
	_sync_button_attention_pivot(button)
	button.scale = Vector2.ONE
	button.modulate = Color.WHITE
	var tween := button.create_tween().set_loops()
	tween.tween_property(button, "scale", Vector2(1.12, 1.12), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(
		button, "modulate", Color(1.22, 1.22, 1.1, 1.0), 0.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(button, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	button.set_meta("_attention_pulse", tween)

# Stops the attention pulse tween and restores scale and modulate to neutral.
static func stop_button_attention_pulse(button: Button) -> void:
	if not button:
		return
	if button.has_meta("_attention_pulse"):
		var tween: Tween = button.get_meta("_attention_pulse")
		if tween:
			tween.kill()
		button.remove_meta("_attention_pulse")
	button.scale = Vector2.ONE
	button.modulate = Color.WHITE

# Sets the pivot to the button centre so scale animations expand symmetrically.
static func _sync_button_attention_pivot(button: Button) -> void:
	if button:
		button.pivot_offset = button.size * 0.5
