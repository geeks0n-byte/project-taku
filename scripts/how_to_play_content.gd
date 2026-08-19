class_name HowToPlayContent
extends RefCounted

# Total number of how-to-play pages shown in the in-game HTP overlay.
const PAGE_COUNT := 5
# Tile icon sizes used in BBCode [img] tags for different contexts.
const BODY_TILE_SIZE := 40
const EXAMPLE_TILE_SIZE := 72
const ARROW_TILE_SIZE := 64
const LOCK_ICON_SIZE := 96

# Convenience alias for the first page (the core rules) used by other systems.
static func get_rules_text(force_english: bool = false) -> String:
	return get_page_text(0, force_english)

# Returns the i18n key for the page's header label, clamped to valid range.
static func get_page_title_key(page_index: int) -> String:
	var page := clampi(page_index, 0, PAGE_COUNT - 1)
	match page:
		0:
			return "HTP_TITLE"
		1:
			return "HTP_EXAMPLES_TITLE"
		2:
			return "HTP_PURPLE_TITLE"
		3:
			return "HTP_LINKS_TITLE"
		_:
			return "HTP_STARS_TITLE"

# Builds the full BBCode string for a given page, then post-processes it with
# glue_tile_icon_color_labels to prevent word-wrap between icons and their color labels.
static func get_page_text(page_index: int, force_english: bool = false) -> String:
	var page := clampi(page_index, 0, PAGE_COUNT - 1)
	var raw := ""
	match page:
		0:
			raw = _page_how_to_play(force_english)
		1:
			raw = _page_examples(force_english)
		2:
			raw = _page_purple(force_english)
		3:
			raw = _page_links(force_english)
		_:
			raw = _page_stars(force_english)
	return HudLayout.glue_tile_icon_color_labels(raw)

# Body text font size, scaled for locale (Georgian needs ~15% larger).
static func _body_size() -> int:
	return HudLayout.body_font_size(GameConstants.UI_BODY_FONT_SIZE_LARGE)

# Builds the core rules page: five bullet points with inline tile icons
# inserted into translated strings via _fill().
static func _page_how_to_play(force_english: bool) -> String:
	var img_e := _tile_img(GameConstants.TILE_EMPTY, BODY_TILE_SIZE)
	var img_y := _tile_img(GameConstants.TILE_YELLOW, BODY_TILE_SIZE)
	var img_b := _tile_img(GameConstants.TILE_BLUE, BODY_TILE_SIZE)
	var img_g := _tile_img(GameConstants.TILE_GREEN, BODY_TILE_SIZE)
	var body_sz := _body_size()
	var goal_tap := _fill(_t("HTP_GOAL_TAP", force_english), [img_e, img_y, img_b, img_g])
	var goal_win := _fill(_t("HTP_GOAL_WIN", force_english), [img_e])
	var equal_balance := _fill(_t("HTP_EQUAL_BALANCE", force_english), [img_y, img_b])
	var rule_of_two := _fill(_t("HTP_RULE_OF_TWO", force_english), [img_y, img_b])
	var green_desc := _fill(_t("HTP_GREEN_TILES_DESC", force_english), [img_g, img_y, img_b])
	var rule_of_one := _fill(_t("HTP_RULE_OF_ONE", force_english), [img_g])
	# Five short bullets with spacing; Rule of One includes the balance note.
	var lines: PackedStringArray = [
		"[font_size=%d]" % body_sz,
		"• %s %s" % [goal_tap, goal_win],
		"",
		"• %s" % equal_balance,
		"",
		"• %s" % rule_of_two,
		"",
		"• %s" % green_desc,
		"",
		"• %s" % rule_of_one,
		"[/font_size]",
	]
	return "\n".join(lines)

# Builds a two-column table showing valid vs invalid tile arrangements.
static func _page_examples(force_english: bool) -> String:
	var img_y := _tile_img(GameConstants.TILE_YELLOW, EXAMPLE_TILE_SIZE)
	var img_b := _tile_img(GameConstants.TILE_BLUE, EXAMPLE_TILE_SIZE)
	var img_g := _tile_img(GameConstants.TILE_GREEN, EXAMPLE_TILE_SIZE)
	var body_sz := _body_size()
	var label_invalid := _example_column_label(_t("HTP_EXAMPLE_INVALID", force_english), force_english)
	var label_valid := _example_column_label(_t("HTP_EXAMPLE_VALID", force_english), force_english)
	var header := "[cell shrink=false expand=1 padding=16,8,16,20][center]%s[/center][/cell]"
	var cell := "[cell shrink=false expand=1 padding=16,24,16,24][center]%s[/center][/cell]"
	var lines: PackedStringArray = [
		"[font_size=%d]" % body_sz,
		"[table=2]",
		header % label_invalid,
		header % label_valid,
		cell % ("❌ %s %s %s" % [img_y, img_y, img_y]),
		cell % ("✅ %s %s %s" % [img_y, img_b, img_y]),
		cell % ("❌ %s %s %s" % [img_b, img_b, img_b]),
		cell % ("✅ %s %s %s" % [img_b, img_y, img_b]),
		cell % ("❌ %s %s %s" % [img_b, img_b, img_g]),
		cell % ("✅ %s %s %s" % [img_y, img_b, img_g]),
		cell % ("❌ %s %s %s" % [img_y, img_g, img_y]),
		cell % ("✅ %s %s %s" % [img_b, img_g, img_y]),
		"[/table]",
		"[/font_size]",
	]
	return "\n".join(lines)

## VALID / INVALID: Press Start on English. Outline is forced off — theme outline
## on Press Start scrambles glyphs under GL Compatibility.
static func _example_column_label(text: String, force_english: bool) -> String:
	if force_english or HudLayout.uses_pixel_font():
		return "[outline_size=0][font=%s]%s[/font][/outline_size]" % [
			HudLayout.PIXEL_FONT_PATH, text
		]
	return "[b]%s[/b]" % text

# Builds the shifter (purple) tile page: explains how shifters move and interact.
static func _page_purple(force_english: bool) -> String:
	var img_s := _tile_img(GameConstants.TILE_SHIFTER, BODY_TILE_SIZE)
	var img_g := _tile_img(GameConstants.TILE_GREEN, BODY_TILE_SIZE)
	var shifter_arrows := "".join([
		_tile_img_text_aligned(GameConstants.TILE_SHIFTER_UP, ARROW_TILE_SIZE),
		_tile_img_text_aligned(GameConstants.TILE_SHIFTER_DOWN, ARROW_TILE_SIZE),
		_tile_img_text_aligned(GameConstants.TILE_SHIFTER_LEFT, ARROW_TILE_SIZE),
		_tile_img_text_aligned(GameConstants.TILE_SHIFTER_RIGHT, ARROW_TILE_SIZE),
	])
	var body_sz := _body_size()
	var shifter_desc := _fill(_t("HTP_SHIFTER_TILES_DESC", force_english), [img_s])
	var shifter_block := _fill(_t("HTP_SHIFTER_BLOCK_NOTE", force_english), [img_s])
	var shifter_balance := _fill(_t("HTP_SHIFTER_BALANCE_NOTE", force_english), [img_g, img_s])
	var lines: PackedStringArray = [
		"[font_size=%d]" % body_sz,
		"• %s %s" % [shifter_desc, shifter_arrows],
		"",
		"• %s" % shifter_block,
		"",
		"• %s" % shifter_balance,
		"[/font_size]",
	]
	return "\n".join(lines)

# Builds the constraint/links page: lock icon usage, equals and not-equals rules.
static func _page_links(force_english: bool) -> String:
	# Region is 96x128 — scale by height only so it stays unstretched.
	var img_lock := (
		"[img height=%d center,baseline region=16,0,96,128]%s[/img]"
		% [LOCK_ICON_SIZE, GameConstants.TILE_LOCK]
	)
	var body_sz := _body_size()
	var lines: PackedStringArray = [
		"[font_size=%d]" % body_sz,
		"• %s [b]%s[/b] %s" % [
			img_lock,
			_t("HTP_LOCKS_LABEL", force_english),
			_t("HTP_LOCKS_DESC", force_english),
		],
		"",
		"• %s" % _t("HTP_EQUALS_RULE", force_english),
		"",
		"• %s" % _t("HTP_NOT_EQUALS_RULE", force_english),
		"[/font_size]",
	]
	return "\n".join(lines)

# Builds the star-scoring page: explains the three star criteria (completion, hints, time).
static func _page_stars(force_english: bool) -> String:
	var body_sz := _body_size()
	var lines: PackedStringArray = [
		"[font_size=%d]" % body_sz,
		"• %s" % _t("HTP_STARS_INTRO", force_english),
		"",
		"• [b]%s[/b] %s" % [
			_t("HTP_STARS_COMPLETE_LABEL", force_english),
			_t("HTP_STARS_COMPLETE_DESC", force_english),
		],
		"",
		"• [b]%s[/b] %s" % [
			_t("HTP_STARS_HINTS_LABEL", force_english),
			_t("HTP_STARS_HINTS_DESC", force_english),
		],
		"",
		"• [b]%s[/b] %s" % [
			_t("HTP_STARS_TIME_LABEL", force_english),
			_t("HTP_STARS_TIME_DESC", force_english),
		],
		"[/font_size]",
	]
	return "\n".join(lines)

# Wraps a tile texture path in a BBCode [img] tag sized for inline body text.
static func _tile_img(path: String, size: int = BODY_TILE_SIZE) -> String:
	return "[img width=%d height=%d center,baseline]%s[/img]" % [size, size, path]

## Arrow icons sit on the text baseline.
static func _tile_img_text_aligned(path: String, size: int = ARROW_TILE_SIZE) -> String:
	return "[img width=%d height=%d center,baseline]%s[/img]" % [size, size, path]


# Translates a key, bypassing the current locale when force_english is true
# (used by the editor's preview which always needs English for layout measurements).
static func _t(key: String, force_english: bool) -> String:
	return HudLayout.english(key) if force_english else String(TranslationServer.translate(key))

## Replace %s placeholders only. Avoids Godot `%` errors when a locale
## string has fewer placeholders than args (missing/stale translation).
static func _fill(template: String, args: Array) -> String:
	var out := template
	for arg in args:
		var pos := out.find("%s")
		if pos < 0:
			push_warning("HowToPlayContent: missing %%s for arg in: %s" % template.substr(0, 64))
			break
		out = out.substr(0, pos) + str(arg) + out.substr(pos + 2)
	return out
