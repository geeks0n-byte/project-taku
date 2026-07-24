class_name HowToPlayContent
extends RefCounted

const PAGE_COUNT := 5

static func get_rules_text(force_english: bool = false) -> String:
	return get_page_text(0, force_english)

static func get_page_text(page_index: int, force_english: bool = false) -> String:
	var page := clampi(page_index, 0, PAGE_COUNT - 1)
	match page:
		0:
			return _page_goal(force_english)
		1:
			return _page_core_rules(force_english)
		2:
			return _page_green(force_english)
		3:
			return _page_specials(force_english)
		_:
			return _page_stars(force_english)

static func _title_size() -> int:
	return HudLayout.body_font_size(GameConstants.UI_BODY_TITLE_FONT_SIZE)

static func _body_size() -> int:
	return HudLayout.body_font_size(GameConstants.UI_BODY_FONT_SIZE)

static func _page_goal(force_english: bool) -> String:
	var img_y := _tile_img(GameConstants.TILE_YELLOW)
	var img_b := _tile_img(GameConstants.TILE_BLUE)
	var img_g := _tile_img(GameConstants.TILE_GREEN)
	var title_sz := _title_size()
	var body_sz := _body_size()
	var lines: PackedStringArray = [
		"[center][font_size=%d][b][color=#88ccff]%s[/color][/b][/font_size][/center]" % [
			title_sz, _t("HTP_TITLE", force_english)
		],
		"",
		"[font_size=%d]" % body_sz,
		"• %s" % _t("HTP_GOAL_TAP", force_english) % [img_y, img_b, img_g],
		"",
		"• %s" % _t("HTP_GOAL_WIN", force_english),
		"",
		"• %s" % _t("HTP_GOAL_TIMER", force_english),
		"[/font_size]",
	]
	return "\n".join(lines)

static func _page_core_rules(force_english: bool) -> String:
	var img_y := _tile_img(GameConstants.TILE_YELLOW)
	var img_b := _tile_img(GameConstants.TILE_BLUE)
	var title_sz := _title_size()
	var body_sz := _body_size()
	var lines: PackedStringArray = [
		"[center][font_size=%d][b][color=#88ccff]%s[/color][/b][/font_size][/center]" % [
			title_sz, _t("HTP_CORE_TITLE", force_english)
		],
		"",
		"[font_size=%d]" % body_sz,
		_rule_bullet("HTP_EQUAL_BALANCE", force_english),
		"",
		_rule_bullet("HTP_RULE_OF_TWO", force_english),
		"",
		"              ❌ %s %s %s  %s" % [img_y, img_y, img_y, _t("HTP_EXAMPLE_THREE_YELLOWS", force_english)],
		"              ❌ %s %s %s  %s" % [img_b, img_b, img_b, _t("HTP_EXAMPLE_THREE_BLUES", force_english)],
		"              ✅ %s %s %s  %s" % [img_y, img_y, img_b, _t("HTP_EXAMPLE_VALID_MIX", force_english)],
		"[/font_size]",
	]
	return "\n".join(lines)

static func _page_green(force_english: bool) -> String:
	var img_g := _tile_img(GameConstants.TILE_GREEN)
	var ex_y := _tile_img(GameConstants.TILE_YELLOW, 40)
	var ex_b := _tile_img(GameConstants.TILE_BLUE, 40)
	var ex_g := _tile_img(GameConstants.TILE_GREEN, 40)
	var title_sz := _title_size()
	var body_sz := _body_size()
	var lines: PackedStringArray = [
		"[center][font_size=%d][b][color=#88ccff]%s[/color][/b][/font_size][/center]" % [
			title_sz, _t("HTP_GREEN_TITLE", force_english)
		],
		"",
		"[font_size=%d]" % body_sz,
		"• %s %s" % [img_g, _t("HTP_GREEN_TILES_DESC", force_english)],
		"",
		"• %s" % _t("HTP_GREEN_MAX_ONE", force_english),
		"",
		"• %s" % _t("HTP_GREEN_BALANCE_NOTE", force_english),
		"",
		"              ❌ %s %s %s  %s" % [ex_b, ex_b, ex_g, _t("HTP_GREEN_EXAMPLE_INVALID_1", force_english)],
		"              ❌ %s %s %s  %s" % [ex_y, ex_g, ex_y, _t("HTP_GREEN_EXAMPLE_INVALID_2", force_english)],
		"              ✅ %s %s %s  %s" % [ex_b, ex_g, ex_y, _t("HTP_GREEN_EXAMPLE_VALID", force_english)],
		"[/font_size]",
	]
	return "\n".join(lines)

static func _page_specials(force_english: bool) -> String:
	var img_s := _tile_img(GameConstants.TILE_SHIFTER)
	var img_lock := "[img height=72 region=16,0,96,128]%s[/img]" % GameConstants.TILE_LOCK
	var shifter_arrows := "".join([
		_tile_img(GameConstants.TILE_SHIFTER_UP, 56),
		_tile_img(GameConstants.TILE_SHIFTER_DOWN, 56),
		_tile_img(GameConstants.TILE_SHIFTER_LEFT, 56),
		_tile_img(GameConstants.TILE_SHIFTER_RIGHT, 56),
	])
	var title_sz := _title_size()
	var body_sz := _body_size()
	var lines: PackedStringArray = [
		"[center][font_size=%d][b][color=#88ccff]%s[/color][/b][/font_size][/center]" % [
			title_sz, _t("HTP_SPECIALS_TITLE", force_english)
		],
		"",
		"[font_size=%d]" % body_sz,
		"• %s %s" % [img_s, _t("HTP_SHIFTER_TILES_DESC", force_english) % shifter_arrows],
		"",
		"• %s [b]%s[/b] %s" % [img_lock, _t("HTP_LOCKS_LABEL", force_english), _t("HTP_LOCKS_DESC", force_english)],
		"",
		"• %s" % _t("HTP_EQUALS_RULE", force_english),
		"",
		"• %s" % _t("HTP_NOT_EQUALS_RULE", force_english),
		"[/font_size]",
	]
	return "\n".join(lines)

static func _page_stars(force_english: bool) -> String:
	var title_sz := _title_size()
	var body_sz := _body_size()
	var lines: PackedStringArray = [
		"[center][font_size=%d][b][color=#88ccff]%s[/color][/b][/font_size][/center]" % [
			title_sz, _t("HTP_STARS_TITLE", force_english)
		],
		"",
		"[font_size=%d]" % body_sz,
		"• %s" % _t("HTP_STARS_INTRO", force_english),
		"",
		"• [b]%s[/b] %s" % [_t("HTP_STARS_TIME_LABEL", force_english), _t("HTP_STARS_TIME_DESC", force_english)],
		"",
		"• [b]%s[/b] %s" % [_t("HTP_STARS_GREEN_LABEL", force_english), _t("HTP_STARS_GREEN_DESC", force_english)],
		"",
		"• [b]%s[/b] %s" % [_t("HTP_STARS_MOVES_LABEL", force_english), _t("HTP_STARS_MOVES_DESC", force_english)],
		"[/font_size]",
	]
	return "\n".join(lines)

static func _tile_img(path: String, size: int = 48) -> String:
	return "[img=%dx%d]%s[/img]" % [size, size, path]

static func _t(key: String, force_english: bool) -> String:
	return HudLayout.english(key) if force_english else String(TranslationServer.translate(key))

static func _rule_bullet(translation_key: String, force_english: bool = false) -> String:
	var text := _t(translation_key, force_english)
	var separator := text.find(": ")
	if separator == -1:
		return "• %s" % text
	var label := text.substr(0, separator)
	var rest := text.substr(separator + 2)
	return "• [b]%s:[/b] %s" % [label, rest]
