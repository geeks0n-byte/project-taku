class_name HudFonts
extends RefCounted
## Font policy for Spaceblox UI.
##
## **Default rule (en, de, es, fr, pl, …):** Press Start 2P for all UI text.
##
## **Georgian (ka) and Ukrainian (uk):** mixed fonts on the same control when needed.
##   - [method default_font] (Noto) — **only** native script *letters*:
##     mkhedruli / Georgian supplement (U+10A0–U+10FF, U+2D00–U+2D2F) and Cyrillic
##     letters (U+0400–U+04FF letter ranges, incl. Ukrainian ґ/є/і/ї).
##   - [method pixel_font] (Press Start) — **everything else:** Latin, digits 0–9,
##     math symbols (not sentence punctuation in native copy), arrows, brand tokens ("gix0n"), clocks (MM:SS),
##     level numbers, and any glyph Press Start can render.
##
##   - Sentence punctuation in ka/uk native copy (.,:;!? etc.) stays Noto;
##     clock ":" between digits stays Press Start.
## Routing helpers: [method char_needs_scalable_font], [method text_uses_press_start_font].
## Mixed strings in ka/uk use RichTextLabel [font=] tags or [code]_force_pixel_font[/code]
## / [method HudLayout.apply_raster_pixel_label] with [code]force_pixel=true[/code].
##
## Editor chrome is English-only and may force Press Start via
## [method mark_force_pixel_subtree] even when the game language is ka/uk.

const PIXEL_FONT: Font = preload("res://resources/fonts/PressStart2P-vaV7.ttf")
const PIXEL_FONT_PATH := "res://resources/fonts/PressStart2P-vaV7.ttf"
const NOTO_SANS_PATH := "res://resources/fonts/NotoSans-Regular.ttf"
const NOTO_GEORGIAN_PATH := "res://resources/fonts/NotoSansGeorgian-Regular.ttf"

## Locales that must not use Press Start (missing / poorly covered glyphs).
const SCALABLE_SCRIPT_LOCALES := ["ka", "uk"]

static var _pixel_font_with_fallback: Font
static var _default_ui_font: Font
static var _force_pixel_depth: int = 0

## Two-letter locale from TranslationServer (en, ka, uk, ...).
static func locale_code() -> String:
	return TranslationServer.get_locale().substr(0, 2)

## True for Georgian / Ukrainian — default font + NON_PIXEL_LOCALE_FONT_SCALE.
static func is_scalable_script_locale(locale: String = "") -> bool:
	var code := locale if not locale.is_empty() else locale_code()
	return SCALABLE_SCRIPT_LOCALES.has(code)

## True for Press Start locales, or while begin_force_pixel_font is nested.
static func uses_pixel_font() -> bool:
	if _force_pixel_depth > 0:
		return true
	return not is_scalable_script_locale()

## True when this node sits under a force-pixel subtree or the locale is pixel.
static func control_uses_pixel_font(control: Node = null) -> bool:
	if control != null and _in_force_pixel_subtree(control):
		return true
	return uses_pixel_font()

## Walks parents for the _force_pixel_subtree meta set on editor/playtest roots.
static func _in_force_pixel_subtree(node: Node) -> bool:
	var n := node
	while n != null:
		if bool(n.get_meta("_force_pixel_subtree", false)):
			return true
		n = n.get_parent()
	return false

## Marks a UI root so text under it uses Press Start (editor English-only chrome).
static func mark_force_pixel_subtree(root: Node) -> void:
	if root:
		root.set_meta("_force_pixel_subtree", true)

## Increments the nested Press Start force counter.
static func begin_force_pixel_font() -> void:
	_force_pixel_depth += 1

## Decrements the nested Press Start force counter (not below zero).
static func end_force_pixel_font() -> void:
	_force_pixel_depth = maxi(0, _force_pixel_depth - 1)

## Loads Press Start 2P once; returns the cached Font resource.
static func _load_press_start_font() -> Font:
	if PIXEL_FONT != null:
		return PIXEL_FONT
	if ResourceLoader.exists(PIXEL_FONT_PATH):
		var loaded := load(PIXEL_FONT_PATH) as Font
		if loaded != null:
			return loaded
	return ThemeDB.fallback_font

## Press Start 2P, or ThemeDB.fallback_font if the file is missing.
static func pixel_font() -> Font:
	if _pixel_font_with_fallback == null:
		_pixel_font_with_fallback = _load_press_start_font()
	return _pixel_font_with_fallback if _pixel_font_with_fallback else ThemeDB.fallback_font

## Same face as pixel_font — alias kept for older call sites.
static func pixel_font_clean() -> Font:
	return pixel_font()

## Scalable UI face: Noto Sans (Latin/Cyrillic) with Georgian fallback for mkhedruli.
## Loaded at runtime (FontFile) so headless/CI works before .import exists.
static func default_font() -> Font:
	if _default_ui_font != null:
		return _default_ui_font
	var base := _load_font_file(NOTO_SANS_PATH)
	if base == null:
		_default_ui_font = ThemeDB.fallback_font
		return _default_ui_font
	var georgian := _load_font_file(NOTO_GEORGIAN_PATH)
	if georgian != null:
		base.fallbacks = [georgian]
	_default_ui_font = base
	return _default_ui_font

## Loads a Font from res://, preferring the imported resource then a raw FontFile.
static func _load_font_file(path: String) -> Font:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	if ResourceLoader.exists(path):
		var imported := load(path) as Font
		if imported != null:
			return imported.duplicate()
	var font := FontFile.new()
	var err := font.load_dynamic_font(path)
	if err != OK:
		push_warning("HudFonts: failed to load %s (%s)" % [path, error_string(err)])
		return null
	return font

## No-op kept so call sites that flushed a former raster cache still compile.
static func clear_pixel_text_cache() -> void:
	pass

## Press Start for pixel locales; Noto default otherwise.
static func ui_font() -> Font:
	return pixel_font() if uses_pixel_font() else default_font()

## True for ka/uk (and any other scalable-script locale).
static func prefer_default_font() -> bool:
	return not uses_pixel_font()

## Extra scale for ka/uk default-font UI (glyphs read large).
static func non_pixel_locale_scale() -> float:
	return (
		GameConstants.NON_PIXEL_LOCALE_FONT_SCALE
		if is_scalable_script_locale()
		else 1.0
	)

## Combined locale + default-font scale for pixel-font sizing paths.
static func font_scale() -> float:
	var scale := 1.0
	if not uses_pixel_font():
		scale = GameConstants.DEFAULT_FONT_SCALE
	scale *= non_pixel_locale_scale()
	return scale

## Scales a font size by [method font_scale] and snaps on the Press Start grid.
static func scaled_font_size(base: int) -> int:
	var size := int(round(float(base) * font_scale()))
	if uses_pixel_font():
		return snap_pixel_font_size(size)
	return size

## Scales a font size for the non-pixel (scalable) font path.
static func body_font_size(base: int) -> int:
	var scale := GameConstants.DEFAULT_FONT_SCALE * non_pixel_locale_scale()
	return int(round(float(base) * scale))

## Press Start is an 8px grid font — odd sizes create uneven gaps between letters.
static func snap_pixel_font_size(size: int) -> int:
	if size <= 0:
		return size
	return maxi(8, int(round(float(size) / 8.0)) * 8)

## True when the current locale uses Press Start; callers raster instead of theme font.
static func needs_pixel_text_raster() -> bool:
	return uses_pixel_font()

## True when [param c] is a Georgian or Cyrillic letter that needs Noto in ka/uk.
static func char_needs_scalable_font(c: String) -> bool:
	if c.length() != 1:
		return false
	var code := c.unicode_at(0)
	if code >= 0x10A0 and code <= 0x10FF:
		return true
	if code >= 0x2D00 and code <= 0x2D2F:
		return true
	if code >= 0x0400 and code <= 0x04FF:
		return _is_cyrillic_letter_code(code)
	return false

## True for Unicode Cyrillic letter codepoints used by mixed-font ka/uk splitting.
static func _is_cyrillic_letter_code(code: int) -> bool:
	if code >= 0x0410 and code <= 0x044F:
		return true
	if code >= 0x0400 and code <= 0x040F:
		return true
	if code >= 0x0450 and code <= 0x045F:
		return true
	if code >= 0x0460 and code <= 0x04F9:
		return true
	return false

## Sentence / UI punctuation that should stay Noto inside ka/uk native copy.
## Clock ":" between digits is handled separately (stays Press Start).
static func char_is_native_text_punctuation(c: String) -> bool:
	if c.length() != 1:
		return false
	var code := c.unicode_at(0)
	# ASCII punctuation + common Unicode punctuation / quotes / dashes.
	if code >= 0x21 and code <= 0x2F:
		return true
	if code >= 0x3A and code <= 0x40:
		return true
	if code >= 0x5B and code <= 0x60:
		return true
	if code >= 0x7B and code <= 0x7E:
		return true
	if code >= 0x2010 and code <= 0x2027:
		return true
	if code >= 0x2030 and code <= 0x205E:
		return true
	if code >= 0x00A0 and code <= 0x00BF:
		return true
	return false

## ":" between two digits (MM:SS clocks) — Press Start even inside ka/uk mixed copy.
static func char_is_clock_colon(text: String, index: int) -> bool:
	if index < 1 or index >= text.length() - 1:
		return false
	if text[index] != ":":
		return false
	var prev := text[index - 1]
	var next := text[index + 1]
	return prev.is_valid_int() and next.is_valid_int()

## In mixed ka/uk strings: Latin/digits → Press Start; native letters + punctuation → Noto.
## Exception: digit-bounded ":" (time clocks) stays Press Start.
static func char_uses_press_start_in_mixed(text: String, index: int) -> bool:
	if index < 0 or index >= text.length():
		return false
	var c := text[index]
	if char_needs_scalable_font(c):
		return false
	if char_is_clock_colon(text, index):
		return true
	if c.strip_edges().is_empty():
		return false
	if char_is_native_text_punctuation(c):
		return false
	return true

## True when every character can render in Press Start (digits, symbols, Latin, etc.).
## Latin-only UI (incl. punctuation) stays Press Start; native letters force Noto path.
static func text_uses_press_start_font(text: String) -> bool:
	if text.is_empty():
		return false
	for i in text.length():
		if char_needs_scalable_font(text[i]):
			return false
	return true

## True when copy contains at least one native-script letter (ka/uk Noto path).
static func text_needs_scalable_font(text: String) -> bool:
	for i in text.length():
		if char_needs_scalable_font(text[i]):
			return true
	return false

## Latin locales always; in ka/uk only when the string has no native letters.
static func should_use_press_start_font(text: String) -> bool:
	if uses_pixel_font():
		return true
	return text_uses_press_start_font(text)

## Removes Press Start [font=…] / [font name=…] wrappers (and their paired inner
## [font_size=…] from [method wrap_press_start_runs_bbcode]) so locale re-applies
## can re-wrap cleanly.
##
## Does NOT strip page-level [font_size=…] (How-To-Play wraps whole pages in one).
## A naive strip of every font_size matched the *inner* closer first and shredded
## nested BBCode — ka↔uk then re-wrapped the mess until RichTextLabel froze.
static func strip_font_bbcode(text: String) -> String:
	if text.is_empty() or text.find("[font") < 0:
		return text
	var out := text
	var guard := 0
	while guard < 256:
		guard += 1
		var start := _find_press_start_font_open(out, 0)
		if start < 0:
			break
		var tag_end := out.find("]", start)
		if tag_end < 0:
			break
		var close := _find_matching_close_tag(out, tag_end + 1, "[font", "[/font]")
		if close < 0:
			# Orphan open — drop it only.
			out = out.substr(0, start) + out.substr(tag_end + 1)
			continue
		var inner := out.substr(tag_end + 1, close - tag_end - 1)
		inner = _unwrap_direct_font_size(inner)
		out = out.substr(0, start) + inner + out.substr(close + "[/font]".length())
	return out

## Index of next [font=…] / [font …] / [font], skipping [font_size…].
static func _find_press_start_font_open(text: String, from: int) -> int:
	var i := from
	while true:
		var start := text.find("[font", i)
		if start < 0:
			return -1
		if text.substr(start).begins_with("[font_size"):
			i = start + 5
			continue
		var after := start + 5
		if after >= text.length():
			return -1
		var c := text[after]
		if c == "=" or c == " " or c == "]":
			return start
		i = start + 5
	return -1

## Nesting-aware search for close_tag matching open_prefix opens inside [start, …).
static func _find_matching_close_tag(
	text: String, from: int, open_prefix: String, close_tag: String
) -> int:
	var depth := 1
	var i := from
	var open_len := open_prefix.length()
	var close_len := close_tag.length()
	while i < text.length():
		var next_open := text.find(open_prefix, i)
		var next_close := text.find(close_tag, i)
		if next_close < 0:
			return -1
		# [font_size] also begins with "[font" — only count real [font opens.
		if next_open >= 0 and next_open < next_close:
			var is_font_size := text.substr(next_open).begins_with("[font_size")
			var is_font_open := false
			if not is_font_size:
				var after := next_open + open_len
				if after < text.length():
					var c := text[after]
					is_font_open = c == "=" or c == " " or c == "]"
			if is_font_open:
				depth += 1
			i = next_open + open_len
			continue
		depth -= 1
		if depth == 0:
			return next_close
		i = next_close + close_len
	return -1

## If wrap left [font_size=N]…[/font_size] as the sole/direct wrapper, unwrap it.
static func _unwrap_direct_font_size(inner: String) -> String:
	var trimmed := inner.strip_edges()
	if not trimmed.begins_with("[font_size"):
		return inner
	if not trimmed.ends_with("[/font_size]"):
		return inner
	var tag_end := trimmed.find("]")
	if tag_end < 0:
		return inner
	# wrap_press_start_runs_bbcode never nests font_size inside font_size.
	if trimmed.find("[font_size", 1) >= 0:
		return inner
	var close := trimmed.rfind("[/font_size]")
	if close <= tag_end:
		return inner
	return trimmed.substr(tag_end + 1, close - tag_end - 1)

## In ka/uk, wrap Latin/digit runs (and MM:SS colons) in Press Start BBCode.
## Native letters and sentence punctuation stay on the default Noto face.
## Skips existing BBCode tags so re-apply on language change cannot nest forever.
## No-op outside ka/uk. Pass plain text, or lightly tagged text ([center]/[color]).
static func wrap_press_start_runs_bbcode(text: String, font_size: int = 0) -> String:
	if text.is_empty() or not is_scalable_script_locale():
		return text
	text = strip_font_bbcode(text)
	if not text_needs_scalable_font(text):
		return text
	var out := ""
	var i := 0
	var n := text.length()
	while i < n:
		# Keep BBCode tags intact (never wrap "center", "color", hex, paths, …).
		if text[i] == "[":
			var close := text.find("]", i)
			if close < 0:
				out += text.substr(i)
				break
			out += text.substr(i, close - i + 1)
			i = close + 1
			continue
		if not char_uses_press_start_in_mixed(text, i):
			out += text[i]
			i += 1
			continue
		var start := i
		while (
			i < n
			and text[i] != "["
			and char_uses_press_start_in_mixed(text, i)
		):
			i += 1
		var run := text.substr(start, i - start)
		if run.strip_edges().is_empty():
			out += run
		elif font_size > 0:
			out += "[font=%s][font_size=%d]%s[/font_size][/font]" % [
				PIXEL_FONT_PATH, font_size, run
			]
		else:
			out += "[font=%s]%s[/font]" % [PIXEL_FONT_PATH, run]
	return out
