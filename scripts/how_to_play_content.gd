class_name HowToPlayContent
extends RefCounted

const PAGE_COUNT := 5
const BODY_TILE_SIZE := 40
const EXAMPLE_TILE_SIZE := 72
const ARROW_TILE_SIZE := 64
const LOCK_ICON_SIZE := 96

static func get_rules_text(force_english: bool = false) -> String:
	return get_page_text(0, force_english)

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

static func _body_size() -> int:
	return HudLayout.body_font_size(GameConstants.UI_BODY_FONT_SIZE_LARGE)

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

## VALID / INVALID: bold default font (Press Start + live outline scrambles glyphs).
static func _example_column_label(text: String, _force_english: bool) -> String:
	return "[b]%s[/b]" % text

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

static func _tile_img(path: String, size: int = BODY_TILE_SIZE) -> String:
	return "[img width=%d height=%d center,baseline]%s[/img]" % [size, size, path]

## Arrow icons sit on the text baseline.
static func _tile_img_text_aligned(path: String, size: int = ARROW_TILE_SIZE) -> String:
	return "[img width=%d height=%d center,baseline]%s[/img]" % [size, size, path]


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
