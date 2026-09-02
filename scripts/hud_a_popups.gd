class_name HudPopups
extends RefCounted
## Popup label/title helpers extracted from HudLayout.

static func apply_popup_label(label: Label, base_size: int = GameConstants.UI_BODY_FONT_SIZE) -> void:
	if not label:
		return
	if HudFonts.control_uses_pixel_font(label):
		var key := HudHeaders._header_translation_key(label)
		var display := key if not key.is_empty() else label.text
		if HudHeaders.is_message_key(display):
			label.set_meta("_tr_key", display)
			# Editor chrome stays English; elsewhere use the active locale.
			display = (
				HudHeaders.english(display)
				if HudFonts._in_force_pixel_subtree(label)
				else String(TranslationServer.translate(display))
			)
		display = HudPopups._popup_prompt_with_title_gap(display, true)
		var color := Color.WHITE
		if label.has_theme_color_override("font_color"):
			color = label.get_theme_color("font_color")
		if HudFonts._in_force_pixel_subtree(label):
			label.set_meta("_force_pixel_font", true)
		HudLocale.apply_live_pixel_label_settings(label, display, base_size, color)
		label.add_theme_constant_override("line_spacing", 8)
	else:
		HudLocale.clear_label_settings(label)
		var use_default := HudButtons.prefer_default_font()
		label.set_meta("_use_default_font", use_default)
		label.set_meta("_force_pixel_font", false)
		# Drop scene-baked Press Start so ka/uk can show real glyphs.
		if label.has_theme_font_override("font"):
			label.remove_theme_font_override("font")
		label.text = HudPopups._popup_prompt_with_title_gap(label.text, false)
		HudLocale.apply_locale_font_to_control(label)
		label.add_theme_font_override("font", HudFonts.default_font() if use_default else HudFonts.pixel_font())
		var size := HudFonts.body_font_size(base_size) if use_default else base_size
		label.add_theme_font_size_override("font_size", size)
		# Default fonts already read taller than Press Start — keep gaps tight.
		label.add_theme_constant_override("line_spacing", 4 if use_default else 8)
		HudButtons.apply_safe_outline(label, 8)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size.x = 0.0
	label.clip_contents = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

# True when copy is numeric/symbol display (level numbers, MM:SS clocks, etc.) — Press Start in ka/uk.
static func text_is_digit_display(text: String) -> bool:
	if text.is_empty() or text == "∞":
		return false
	for i in text.length():
		var c := text[i]
		if c >= "0" and c <= "9":
			continue
		if c in [":", "/", " "]:
			continue
		return false
	return true

## Popup heading with a locale word + level number; digits use Press Start in ka/uk.
static func apply_popup_title_with_number(
	label: RichTextLabel, prefix: String, num_str: String, base_size: int, color: Color
) -> void:
	if label == null:
		return
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hex := color.to_html(false)
	if HudFonts.uses_pixel_font():
		var display := "%s %s" % [prefix, num_str]
		label.text = "[center][color=#%s]%s[/color][/center]" % [hex, display]
		HudLocale.apply_live_pixel_richtext(label, base_size)
		label.add_theme_color_override("default_color", color)
	else:
		label.set_meta("_use_default_font", true)
		label.set_meta("_force_pixel_font", false)
		HudLocale.apply_locale_font_to_control(label)
		var size := HudFonts.body_font_size(base_size)
		label.add_theme_font_size_override("normal_font_size", size)
		label.text = "[center][color=#%s]%s [font=%s][font_size=%d]%s[/font_size][/font][/color][/center]" % [
			hex, prefix, HudFonts.PIXEL_FONT_PATH, size, num_str
		]
		HudButtons.apply_safe_outline(label, 8)
		label.add_theme_color_override("default_color", color)

## Ensures a blank line after the first line of a multi-line confirm prompt.
## Pixel English keeps a full blank line; other locales use a single break so
## default-font line height does not look like a double gap.
static func _popup_prompt_with_title_gap(text: String, use_pixel_gap: bool = false) -> String:
	if text.is_empty():
		return text
	var normalized := text.replace("\\n", "\n")
	while normalized.contains("\n\n\n"):
		normalized = normalized.replace("\n\n\n", "\n\n")
	if not normalized.contains("\n"):
		return normalized
	var parts := normalized.split("\n", true, 1)
	if parts.size() < 2:
		return normalized
	# CSV copy often already includes a blank line after the title.
	if parts[1].begins_with("\n"):
		return normalized
	var gap := "\n\n" if (use_pixel_gap or HudFonts.uses_pixel_font()) else "\n"
	return parts[0] + gap + parts[1].lstrip("\n")

