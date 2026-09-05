class_name HudHeaders
extends RefCounted
## Screen headers, status-message translation, and i18n key helpers.
## Public call sites continue to use HudLayout.* wrappers.

# Cached fallback font reference so we don't call HudFonts.default_font() on every frame.
static var _screen_header_font_default: Font

# Returns the font to use for screen headers. Press Start except ka/uk;
# all other locales fall back to the theme's default scalable font.
static func screen_header_font(force_pixel: bool = false) -> Font:
	if force_pixel or HudLayout.uses_pixel_font():
		return HudLayout.pixel_font()
	if _screen_header_font_default == null:
		_screen_header_font_default = HudFonts.default_font()
	return _screen_header_font_default

# Returns true when text looks like a raw i18n key (all-caps ASCII + digits + underscores).
# Used to distinguish un-translated keys from already-translated display strings.
static func is_message_key(text: String) -> bool:
	if text.is_empty():
		return false
	# Message ids are ASCII tokens like UI_OPTIONS / UI_PAUSED / UI_HTP_TITLE.
	var first := text.unicode_at(0)
	if first < 65 or first > 90:
		return false
	for i in text.length():
		var c := text.unicode_at(i)
		var is_az := c >= 65 and c <= 90
		var is_digit := c >= 48 and c <= 57
		if not (is_az or is_digit or c == 95):
			return false
	return true

# True for message ids (UI_YES), not short translated words that also look all-caps (TAK, JA).
static func is_i18n_key(text: String) -> bool:
	return is_message_key(text) and text.contains("_")

# Reverse-looks up the original i18n key from an already-translated string.
# Necessary when a scene was saved with tr() output baked into .text,
# making it impossible to retranslate on locale change without this recovery.
static func _recover_header_key_from_translated(text: String) -> String:
	if text.is_empty() or is_message_key(text):
		return text
	# Recover after a bad bake of tr() into .text (e.g. Ukrainian stuck forever).
	for key in [
		"UI_OPTIONS", "UI_CREDITS", "UI_SELECT_LEVEL", "UI_PAUSED",
		"UI_HTP_TITLE", "UI_HTP_EXAMPLES_TITLE", "UI_HTP_PURPLE_TITLE", "UI_HTP_LINKS_TITLE", "UI_HTP_STARS_TITLE",
		"TUTORIAL", "UI_COMPLETED", "ED_VICTORY_SOLVABLE",
	]:
		if text == key:
			return key
		for locale in TranslationServer.get_loaded_locales():
			var translation := TranslationServer.get_translation_object(locale)
			if translation == null:
				continue
			if String(translation.get_message(key)) == text:
				return key
	return ""

# Determines the stable i18n key for a header label, checking the stored meta
# first, then the raw .text, then attempting recovery from a translated string.
# Result is cached in the "_tr_key" meta so the next call is cheap.
static func _header_translation_key(label: Label) -> String:
	if label == null:
		return ""
	var stored := String(label.get_meta("_tr_key", ""))
	if not stored.is_empty() and is_message_key(stored):
		return stored
	var raw := label.text.strip_edges()
	if is_message_key(raw):
		label.set_meta("_tr_key", raw)
		return raw
	var recovered := _recover_header_key_from_translated(raw)
	if not recovered.is_empty():
		label.set_meta("_tr_key", recovered)
		return recovered
	if not stored.is_empty():
		return stored
	return raw

# Resets a label's translation binding to a known key, clearing any previously
# baked translated text so auto-translate can re-evaluate it from scratch.
static func _bind_header_translation_key(label: Label, key: String) -> void:
	if label == null or key.is_empty():
		return
	HudLayout._clear_pixel_raster(label)
	label.set_meta("_tr_key", key)
	# Force auto-translate to rebind off any previously baked locale string.
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = key
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	label.notification(Node.NOTIFICATION_TRANSLATION_CHANGED)

static func _screen_header_display_text(label: Label) -> String:
	if label == null:
		return ""
	var key := _header_translation_key(label)
	if not key.is_empty() and is_message_key(key):
		return String(TranslationServer.translate(key))
	return String(label.text)

static func _screen_header_side_margin(label: Label) -> float:
	if label == null:
		return HudLayout.UI_SAFE_SIDE_MARGIN
	var margin := maxf(absf(label.offset_left), absf(label.offset_right))
	if margin <= 0.0:
		return HudLayout.UI_SAFE_SIDE_MARGIN
	return margin

static func _screen_header_available_width(label: Label, outline_size: int) -> float:
	var inner_pad := float(outline_size) * 2.0 + 8.0
	if label != null and label.size.x > 1.0:
		return maxf(120.0, label.size.x - inner_pad)
	return maxf(120.0, HudLayout.max_ui_content_width(_screen_header_side_margin(label)) - inner_pad)

static func _fit_screen_header_font_size(
	display: String,
	font: Font,
	base_size: int,
	max_width: float,
	snap_pixel: bool = false
) -> int:
	if display.is_empty() or font == null or max_width <= 0.0:
		return base_size
	var size := base_size
	var min_size := 16 if snap_pixel else 14
	var step := 8 if snap_pixel else 1
	while size > min_size:
		var text_w := HudDialogs.measure_text_max_line_width(font, display, size)
		if text_w <= max_width + 1.0:
			break
		size -= step
	if snap_pixel:
		size = HudLayout.snap_pixel_font_size(maxi(min_size, size))
	return maxi(min_size, size)

# Applies the canonical screen-header look: centred, correct font, outline, colour.
# Handles both the pixel-font and scalable-font (ka/uk) paths,
# and ensures the translation key stays in .text rather than a baked string.
static func apply_screen_header_style(label: Label) -> void:
	if not label:
		return
	label.set_meta("_screen_header", true)
	var force_pixel := bool(label.get_meta("_brand_title", false))
	var header_size: int = int(label.get_meta(
		"_screen_header_font_size",
		GameConstants.SCREEN_HEADER_FONT_SIZE
	))
	var outline_size: int = int(label.get_meta(
		"_screen_header_outline",
		GameConstants.SCREEN_HEADER_OUTLINE
	))
	# Keep the translation key in .text — never bake tr() output (that froze
	# Ukrainian "НАЛАШТУВАННЯ" across every language and broke Press Start glyphs).
	var key := _header_translation_key(label)
	if not key.is_empty() and is_message_key(key):
		_bind_header_translation_key(label, key)
	elif not key.is_empty():
		HudLayout._clear_pixel_raster(label)
		label.text = key
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = false
	label.clip_contents = false
	label.add_theme_color_override("font_color", GameConstants.SCREEN_HEADER_COLOR)
	var display := _screen_header_display_text(label)
	var max_w := _screen_header_available_width(label, outline_size)
	var font: Font
	var fitted_size: int
	if force_pixel or HudLayout.needs_pixel_text_raster():
		label.set_meta("_use_default_font", false)
		font = HudLayout.pixel_font_clean()
		fitted_size = _fit_screen_header_font_size(display, font, header_size, max_w, true)
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", fitted_size)
		HudLayout._strip_live_pixel_outline(label)
		return
	label.set_meta("_use_default_font", true)
	font = screen_header_font(false)
	fitted_size = _fit_screen_header_font_size(
		display, font, HudLayout.body_font_size(header_size), max_w, false
	)
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", fitted_size)
	HudLayout.apply_safe_outline(label, outline_size)

# Styles the victory/completion header label. Reduces font size on mobile to prevent
# overflow, and uses the pixel font path except for ka/uk.
static func apply_end_screen_header_style(label: Label, base_size: int = 48) -> void:
	if not label:
		return
	var size := base_size
	if HudLayout._is_mobile_ui():
		size = 40
	label.set_meta("_screen_header", true)
	label.set_meta("_screen_header_font_size", size)
	label.set_meta("_screen_header_outline", 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = false
	label.clip_contents = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if HudLayout.uses_pixel_font() or HudLayout.control_uses_pixel_font(label):
		label.set_meta("_brand_title", false)
		if HudLayout._in_force_pixel_subtree(label):
			label.set_meta("_force_pixel_font", true)
		HudLayout.apply_live_pixel_label_settings(
			label, label.text, size, GameConstants.SCREEN_HEADER_COLOR
		)
		return
	label.set_meta("_brand_title", false)
	label.set_meta("_use_default_font", true)
	HudLayout.clear_label_settings(label)
	HudLayout._clear_pixel_raster(label)
	label.add_theme_font_override("font", HudFonts.default_font())
	label.add_theme_font_size_override("font_size", HudLayout.body_font_size(size))
	label.add_theme_color_override("font_color", GameConstants.SCREEN_HEADER_COLOR)
	HudLayout.apply_safe_outline(label, 8)
# Returns the English translation of an i18n key regardless of the active locale.
# Used by the editor preview and forced-English paths to get consistent layout metrics.
static func english(key: String) -> String:
	if key.is_empty():
		return ""
	var translation := TranslationServer.get_translation_object("en")
	if translation:
		var msg := String(translation.get_message(StringName(key)))
		if not msg.is_empty():
			return msg
	return key

# Translates a status message string, supporting multi-line input and pipe-delimited
# format strings (e.g. "KEY|arg1|arg2"). Applies sentence-break formatting after translation.
static func translate_status_text(msg: String, force_english: bool = false) -> String:
	if msg.is_empty():
		return ""
	var translated := ""
	if msg.contains("\n"):
		var translated_lines: PackedStringArray = []
		for line in msg.split("\n"):
			if line.is_empty():
				continue
			translated_lines.append(_translate_status_token(line, force_english))
		translated = "\n".join(translated_lines)
	else:
		translated = _translate_status_token(msg, force_english)
	return break_after_sentences(translated)

# Handles a single pipe-delimited token: splits off the key, translates it,
# then substitutes any typed arguments (int or string) into %d/%s placeholders.
static func _translate_status_token(token: String, force_english: bool = false) -> String:
	var parts := token.split("|")
	var key := parts[0]
	var translated := translate_key(key, force_english)
	if parts.size() <= 1 or translated == key:
		return translated
	var args: Array = []
	for i in range(1, parts.size()):
		if parts[i].is_valid_int():
			args.append(int(parts[i]))
		else:
			args.append(parts[i])
	if translated.find("%") >= 0:
		return translated % args
	return translated

# Inserts a newline after sentence-ending punctuation followed by a space and a
# non-numeric character. Skips BBCode tags so [color=...] markup stays intact.
static func break_after_sentences(text: String) -> String:
	if text.is_empty():
		return text
	var out := ""
	var i := 0
	var n := text.length()
	var in_tag := false
	while i < n:
		var c := text[i]
		if c == "[":
			in_tag = true
			out += c
		elif c == "]":
			in_tag = false
			out += c
		elif not in_tag and (c == "." or c == "!" or c == "?"):
			out += c
			var j := i + 1
			while j < n and (text[j] == " " or text[j] == "\t"):
				j += 1
			if j > i + 1 and j < n and text[j] != "\n":
				var next_c := text[j]
				if next_c < "0" or next_c > "9":
					out += "\n"
					i = j
					continue
		else:
			out += c
		i += 1
	return out

# Wraps a status message in BBCode center tags after translation.
static func format_centered_status(msg: String, force_english: bool = false) -> String:
	return "[center]" + translate_status_text(msg, force_english) + "[/center]"

static func translate_key(key: String, force_english: bool = false) -> String:
	if force_english:
		return english(key)
	return String(TranslationServer.translate(key))
