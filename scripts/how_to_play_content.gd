class_name HowToPlayContent
extends RefCounted

const PAGE_COUNT := 6

static func get_rules_text(force_english: bool = false) -> String:
	return get_page_text(0, force_english)

static func get_page_title_key(page_index: int) -> String:
	var page := clampi(page_index, 0, PAGE_COUNT - 1)
	match page:
		0:
			return "HTP_TITLE"
		1:
			return "HTP_CORE_TITLE"
		2:
			return "HTP_GREEN_TITLE"
		3:
			return "HTP_PURPLE_TITLE"
		4:
			return "HTP_LINKS_TITLE"
		_:
			return "HTP_STARS_TITLE"

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
			return _page_purple(force_english)
		4:
			return _page_links(force_english)
		_:
			return _page_stars(force_english)

static func _body_size() -> int:
	return HudLayout.body_font_size(GameConstants.UI_BODY_FONT_SIZE_LARGE)

static func _page_goal(force_english: bool) -> String:
	var img_y := _tile_img(GameConstants.TILE_YELLOW)
	var img_b := _tile_img(GameConstants.TILE_BLUE)
	var img_g := _tile_img(GameConstants.TILE_GREEN)
	var body_sz := _body_size()
	var lines: PackedStringArray = [
		"[font_size=%d]" % body_sz,
		"• %s" % _t("HTP_GOAL_TAP", force_english) % [img_y, img_b, img_g],
		"",
		"• %s" % _t("HTP_GOAL_WIN", force_english),
		"[/font_size]",
	]
	return "\n".join(lines)

static func _page_core_rules(force_english: bool) -> String:
	var img_y := _tile_img(GameConstants.TILE_YELLOW)
	var img_b := _tile_img(GameConstants.TILE_BLUE)
	var body_sz := _body_size()
	var lines: PackedStringArray = [
		"[font_size=%d]" % body_sz,
		_rule_bullet("HTP_EQUAL_BALANCE", force_english),
		"",
		_rule_bullet("HTP_RULE_OF_TWO", force_english),
		"",
		"[center]❌ %s %s %s[/center]" % [img_y, img_y, img_y],
		"[center]%s[/center]" % _t("HTP_EXAMPLE_THREE_YELLOWS", force_english),
		"",
		"[center]❌ %s %s %s[/center]" % [img_b, img_b, img_b],
		"[center]%s[/center]" % _t("HTP_EXAMPLE_THREE_BLUES", force_english),
		"",
		"[center]✅ %s %s %s[/center]" % [img_y, img_y, img_b],
		"[center]%s[/center]" % _t("HTP_EXAMPLE_VALID_MIX", force_english),
		"[/font_size]",
	]
	return "\n".join(lines)

static func _page_green(force_english: bool) -> String:
	var img_g := _tile_img(GameConstants.TILE_GREEN)
	var ex_y := _tile_img(GameConstants.TILE_YELLOW, 44)
	var ex_b := _tile_img(GameConstants.TILE_BLUE, 44)
	var ex_g := _tile_img(GameConstants.TILE_GREEN, 44)
	var body_sz := _body_size()
	var lines: PackedStringArray = [
		"[font_size=%d]" % body_sz,
		"• %s %s" % [img_g, _t("HTP_GREEN_TILES_DESC", force_english)],
		"",
		"• %s" % _t("HTP_GREEN_MAX_ONE", force_english),
		"",
		"• %s" % _t("HTP_GREEN_BALANCE_NOTE", force_english),
		"",
		"[center]❌ %s %s %s[/center]" % [ex_b, ex_b, ex_g],
		"[center]%s[/center]" % _t("HTP_GREEN_EXAMPLE_INVALID_1", force_english),
		"",
		"[center]❌ %s %s %s[/center]" % [ex_y, ex_g, ex_y],
		"[center]%s[/center]" % _t("HTP_GREEN_EXAMPLE_INVALID_2", force_english),
		"",
		"[center]✅ %s %s %s[/center]" % [ex_b, ex_g, ex_y],
		"[center]%s[/center]" % _t("HTP_GREEN_EXAMPLE_VALID", force_english),
		"[/font_size]",
	]
	return "\n".join(lines)

static func _page_purple(force_english: bool) -> String:
	var img_s := _tile_img(GameConstants.TILE_SHIFTER)
	var shifter_arrows := "".join([
		_tile_img(GameConstants.TILE_SHIFTER_UP, 64),
		_tile_img(GameConstants.TILE_SHIFTER_DOWN, 64),
		_tile_img(GameConstants.TILE_SHIFTER_LEFT, 64),
		_tile_img(GameConstants.TILE_SHIFTER_RIGHT, 64),
	])
	var body_sz := _body_size()
	var lines: PackedStringArray = [
		"[font_size=%d]" % body_sz,
		"• %s %s" % [img_s, _t("HTP_SHIFTER_TILES_DESC", force_english) % shifter_arrows],
		"",
		"• %s" % _t("HTP_SHIFTER_BLOCK_NOTE", force_english),
		"",
		"• %s" % _t("HTP_SHIFTER_BALANCE_NOTE", force_english),
		"[/font_size]",
	]
	return "\n".join(lines)

static func _page_links(force_english: bool) -> String:
	var img_lock := "[img height=80 region=16,0,96,128]%s[/img]" % GameConstants.TILE_LOCK
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
			_t("HTP_STARS_TIME_LABEL", force_english),
			_t("HTP_STARS_TIME_DESC", force_english),
		],
		"",
		"• [b]%s[/b] %s" % [
			_t("HTP_STARS_GREEN_LABEL", force_english),
			_t("HTP_STARS_GREEN_DESC", force_english),
		],
		"",
		"• [b]%s[/b] %s" % [
			_t("HTP_STARS_MOVES_LABEL", force_english),
			_t("HTP_STARS_MOVES_DESC", force_english),
		],
		"[/font_size]",
	]
	return "\n".join(lines)

static func _tile_img(path: String, size: int = 56) -> String:
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
