class_name HudFonts
extends RefCounted
## Font policy for Spaceblox UI.
##
## Press Start (pixel) is used for every locale except Georgian and Ukrainian,
## which need a scalable font with mkhedruli / Cyrillic coverage.
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

static func locale_code() -> String:
	return TranslationServer.get_locale().substr(0, 2)

## True for Georgian / Ukrainian — default font + NON_PIXEL_LOCALE_FONT_SCALE.
static func is_scalable_script_locale(locale: String = "") -> bool:
	var code := locale if not locale.is_empty() else locale_code()
	return SCALABLE_SCRIPT_LOCALES.has(code)

static func uses_pixel_font() -> bool:
	if _force_pixel_depth > 0:
		return true
	return not is_scalable_script_locale()

static func control_uses_pixel_font(control: Node = null) -> bool:
	if control != null and _in_force_pixel_subtree(control):
		return true
	return uses_pixel_font()

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

static func begin_force_pixel_font() -> void:
	_force_pixel_depth += 1

static func end_force_pixel_font() -> void:
	_force_pixel_depth = maxi(0, _force_pixel_depth - 1)

static func _load_press_start_font() -> Font:
	if PIXEL_FONT != null:
		return PIXEL_FONT
	if ResourceLoader.exists(PIXEL_FONT_PATH):
		var loaded := load(PIXEL_FONT_PATH) as Font
		if loaded != null:
			return loaded
	return ThemeDB.fallback_font

static func pixel_font() -> Font:
	if _pixel_font_with_fallback == null:
		_pixel_font_with_fallback = _load_press_start_font()
	return _pixel_font_with_fallback if _pixel_font_with_fallback else ThemeDB.fallback_font

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

static func clear_pixel_text_cache() -> void:
	pass

static func ui_font() -> Font:
	return pixel_font() if uses_pixel_font() else default_font()

static func prefer_default_font() -> bool:
	return not uses_pixel_font()

## Extra scale for ka/uk default-font UI (glyphs read large).
static func non_pixel_locale_scale() -> float:
	return (
		GameConstants.NON_PIXEL_LOCALE_FONT_SCALE
		if is_scalable_script_locale()
		else 1.0
	)
