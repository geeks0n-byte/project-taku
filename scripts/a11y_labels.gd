class_name A11yLabels
extends RefCounted
## Binds translated accessibility names onto primary UI controls.


static func translate(key: String) -> String:
	var label := String(TranslationServer.translate(key))
	return label if not label.is_empty() else key


static func bind_button(btn: Button, translation_key: String) -> void:
	if btn == null:
		return
	btn.accessibility_name = translate(translation_key)


static func bind_buttons(pairs: Array) -> void:
	for entry in pairs:
		if typeof(entry) != TYPE_ARRAY or entry.size() < 2:
			continue
		bind_button(entry[0] as Button, str(entry[1]))


static func bind_label(ctrl: Control, translation_key: String) -> void:
	if ctrl == null:
		return
	ctrl.accessibility_name = translate(translation_key)


static func bind_control(ctrl: Control, text: String) -> void:
	if ctrl == null:
		return
	ctrl.accessibility_name = text


static func bind_button_meta(btn: Button) -> void:
	if btn == null:
		return
	var key := String(btn.get_meta("_tr_key", "")).strip_edges()
	if key.is_empty():
		key = String(btn.text).strip_edges()
	if not key.is_empty():
		bind_button(btn, key)


static func bind_toggle_button(btn: Button, caption_text: String) -> void:
	if btn == null:
		return
	btn.accessibility_name = strip_bbcode(caption_text)


static func strip_bbcode(text: String) -> String:
	if text.is_empty():
		return text
	var re := RegEx.new()
	if re.compile("\\[/?[^\\]]+\\]") != OK:
		return text
	return re.sub(text, "", true)


static func bind_rich_text(rtl: RichTextLabel, plain_text: String = "") -> void:
	if rtl == null:
		return
	var source := plain_text if not plain_text.is_empty() else rtl.text
	rtl.accessibility_name = strip_bbcode(source)


static func bind_level_button(
	btn: Button,
	level: LevelData,
	title: String,
	locked: bool,
	is_custom: bool,
	show_new_badge: bool = false
) -> void:
	if btn == null:
		return
	var parts: PackedStringArray = []
	if is_custom:
		parts.append("%s %s" % [translate("UI_CUSTOM_LVL"), title])
	else:
		parts.append(translate("UI_LEVEL") + " " + title)
	if locked:
		parts.append(translate("UI_LOCKED"))
	elif SaveManager and not is_custom:
		var stars := _count_star_bits(SaveManager.get_level_star_bits(level.level_number))
		if stars > 0:
			parts.append(translate("A11Y_STARS_EARNED") % stars)
	if show_new_badge:
		parts.append(translate("A11Y_NEW_LEVEL"))
	btn.accessibility_name = ", ".join(parts)


static func bind_achievement_cell(cell: Control, title_key: String, unlocked: bool) -> void:
	if cell == null:
		return
	var parts: PackedStringArray = []
	parts.append(translate(title_key))
	if not unlocked:
		parts.append(translate("UI_LOCKED"))
	cell.focus_mode = Control.FOCUS_ALL
	cell.accessibility_name = ", ".join(parts)


static func _count_star_bits(bits: int) -> int:
	var count := 0
	var value := bits
	while value > 0:
		if value & 1:
			count += 1
		value >>= 1
	return count
