class_name HowToPlayContent
extends RefCounted

const PAGE_COUNT := 3

static func get_rules_text(force_english: bool = false) -> String:
	return get_page_text(0, force_english)

static func get_page_text(page_index: int, force_english: bool = false) -> String:
	var page := clampi(page_index, 0, PAGE_COUNT - 1)
	match page:
		0:
			return _page_basics(force_english)
		1:
			return _page_tile_types(force_english)
		_:
			return _page_specials(force_english)

static func _page_basics(force_english: bool) -> String:
	var img_y := _tile_img(GameConstants.TILE_YELLOW)
	var img_b := _tile_img(GameConstants.TILE_BLUE)
	var lines: PackedStringArray = [
		"[center][font_size=52][b][color=#88ccff]%s[/color][/b][/font_size][/center]" % _t("HTP_TITLE", force_english),
		"",
		"[font_size=30]",
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

static func _page_tile_types(force_english: bool) -> String:
	var img_y := _tile_img(GameConstants.TILE_YELLOW)
	var img_b := _tile_img(GameConstants.TILE_BLUE)
	var img_g := _tile_img(GameConstants.TILE_GREEN)
	var lines: PackedStringArray = [
		"[center][font_size=46][b][color=#88ccff]%s[/color][/b][/font_size][/center]" % _t("HTP_TILE_TYPES_TITLE", force_english),
		"",
		"[font_size=30]",
		"• [b]%s[/b] %s" % [_t("HTP_BASIC_TILES_LABEL", force_english), _t("HTP_BASIC_TILES_DESC", force_english) % [img_y, img_b]],
		"",
		"• %s %s %s" % [img_g, _t("HTP_GREEN_TILES_HEADER", force_english), _t("HTP_GREEN_TILES_DESC", force_english)],
		"",
		"              ❌ %s %s %s  %s" % [img_b, img_b, img_g, _t("HTP_GREEN_EXAMPLE_INVALID_1", force_english)],
		"              ❌ %s %s %s  %s" % [img_y, img_g, img_y, _t("HTP_GREEN_EXAMPLE_INVALID_2", force_english)],
		"              ✅ %s %s %s  %s" % [img_b, img_g, img_y, _t("HTP_GREEN_EXAMPLE_VALID", force_english)],
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
	var lines: PackedStringArray = [
		"[center][font_size=46][b][color=#88ccff]%s[/color][/b][/font_size][/center]" % _t("HTP_SPECIALS_TITLE", force_english),
		"",
		"[font_size=30]",
		"• %s %s %s" % [img_s, _t("HTP_SHIFTER_TILES_HEADER", force_english), _t("HTP_SHIFTER_TILES_DESC", force_english) % shifter_arrows],
		"",
		"• %s [b]%s[/b] %s" % [img_lock, _t("HTP_LOCKS_LABEL", force_english), _t("HTP_LOCKS_DESC", force_english)],
		"",
		"• %s" % _t("HTP_EQUALS_RULE", force_english),
		"",
		"• %s" % _t("HTP_NOT_EQUALS_RULE", force_english),
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
	var description := text.substr(separator + 2)
	return "• [b]%s:[/b] %s" % [label, description]
