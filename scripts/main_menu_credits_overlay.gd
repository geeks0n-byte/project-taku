class_name MainMenuCreditsOverlay
extends RefCounted

const CREDITS_BODY_SIZE := 48
const CREDITS_HEADER_SIZE := 42
const CREDITS_NAME_SIZE := 34
const CREDITS_HEADER_LOCALE_SIZE := 52
const CREDITS_NAME_LOCALE_SIZE := 42
const CREDITS_NICKNAME := "\"gix0n\""
const _VERSION_HOLD_SEC := 3.0

var _owner: Control
var _show_debug_tools: bool = false
var _overlay_blocker: Control
var _credits_panel: Control
var _credits_version_label: Label
var _close_btn: Button
var _set_chrome_visible: Callable
var on_closed: Callable
var _version_hold_active: bool = false
var _version_hold_started_msec: int = 0
var _process_connected: bool = false


func setup(
	owner: Control,
	show_debug_tools: bool,
	overlay_blocker: Control,
	credits_panel: Control,
	credits_version_label: Label,
	close_btn: Button,
	set_chrome_visible: Callable
) -> void:
	_owner = owner
	_show_debug_tools = show_debug_tools
	_overlay_blocker = overlay_blocker
	_credits_panel = credits_panel
	_credits_version_label = credits_version_label
	_close_btn = close_btn
	_set_chrome_visible = set_chrome_visible


func mount_close_button() -> void:
	if _close_btn:
		HudLayout.style_top_bar_close_button(_close_btn)


func bind_signals() -> void:
	if _close_btn and not _close_btn.pressed.is_connected(close):
		_close_btn.pressed.connect(close)
	_connect_process_tick()


func is_blocking() -> bool:
	return _credits_panel != null and _credits_panel.visible


func handle_back() -> bool:
	if not is_blocking():
		return false
	close()
	return true


func open() -> void:
	MainMenuChrome.set_visible(_set_chrome_visible, false)
	if _overlay_blocker:
		_overlay_blocker.visible = true
	if _credits_panel:
		_credits_panel.visible = true
	var credits_text = _credits_panel.get_node_or_null("CreditsText") if _credits_panel else null
	if credits_text:
		apply_credits_fonts(credits_text)
	else:
		refresh_version()
	if _close_btn:
		HudLayout.style_top_bar_close_button(_close_btn)


func close() -> void:
	if _overlay_blocker:
		_overlay_blocker.visible = false
	if _credits_panel:
		_credits_panel.visible = false
	_stop_version_hold()
	MainMenuChrome.set_visible(_set_chrome_visible, true)
	if on_closed.is_valid():
		on_closed.call()


func apply_credits_fonts(credits_text_node: RichTextLabel) -> void:
	if not credits_text_node:
		return
	credits_text_node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	credits_text_node.fit_content = true
	credits_text_node.scroll_active = false
	credits_text_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var bbcode := String(TranslationServer.translate("CREDITS_TEXT"))
	var locale_mul := HudFonts.non_pixel_locale_scale()
	if HudFonts.uses_pixel_font():
		var header_sz := int(round(float(CREDITS_HEADER_SIZE) * locale_mul))
		var body_sz := int(round(float(CREDITS_NAME_SIZE) * locale_mul))
		bbcode = bbcode.replace("[font_size=48]", "[font_size=%d]" % header_sz)
		bbcode = bbcode.replace("[font_size=42]", "[font_size=%d]" % header_sz)
		bbcode = bbcode.replace("[font_size=40]", "[font_size=%d]" % body_sz)
		bbcode = bbcode.replace("[font_size=36]", "[font_size=%d]" % header_sz)
		bbcode = bbcode.replace("[font_size=34]", "[font_size=%d]" % body_sz)
		bbcode = bbcode.replace("[font_size=28]", "[font_size=%d]" % body_sz)
		credits_text_node.set_meta("_use_default_font", false)
		HudLayout.apply_live_pixel_richtext(credits_text_node, CREDITS_BODY_SIZE)
		credits_text_node.text = bbcode
	else:
		var header_sz := int(round(float(CREDITS_HEADER_LOCALE_SIZE) * locale_mul))
		var body_sz := int(round(float(CREDITS_NAME_LOCALE_SIZE) * locale_mul))
		bbcode = bbcode.replace("[font_size=48]", "[font_size=%d]" % header_sz)
		bbcode = bbcode.replace("[font_size=42]", "[font_size=%d]" % header_sz)
		bbcode = bbcode.replace("[font_size=40]", "[font_size=%d]" % body_sz)
		bbcode = bbcode.replace("[font_size=36]", "[font_size=%d]" % header_sz)
		bbcode = bbcode.replace("[font_size=34]", "[font_size=%d]" % body_sz)
		bbcode = bbcode.replace("[font_size=28]", "[font_size=%d]" % body_sz)
		var pixel_sz := int(round(float(CREDITS_NAME_SIZE) * locale_mul))
		bbcode = _wrap_credits_author_pixel_font(bbcode, body_sz, pixel_sz)
		credits_text_node.set_meta("_use_default_font", true)
		HudLayout.apply_locale_font_to_control(credits_text_node)
		for size_name in [
			"normal_font_size",
			"bold_font_size",
			"italics_font_size",
			"bold_italics_font_size",
			"mono_font_size",
		]:
			credits_text_node.add_theme_font_size_override(size_name, body_sz)
		credits_text_node.text = bbcode
		HudLayout.apply_safe_outline(credits_text_node, GameConstants.MENU_TEXT_OUTLINE)
	refresh_version()


func refresh_version() -> void:
	if not _credits_version_label:
		return
	_credits_version_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var dev_on := SaveManager != null and SaveManager.dev_mode_enabled
	var version_text := "v%s%s" % [_app_version_string(), " [DEV]" if dev_on else ""]
	_credits_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_credits_version_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	HudLayout.apply_raster_pixel_label(
		_credits_version_label,
		version_text,
		28,
		Color(0.67, 0.67, 0.67, 1),
		0,
		true
	)
	_credits_version_label.mouse_filter = Control.MOUSE_FILTER_STOP
	if not _credits_version_label.gui_input.is_connected(_on_version_label_input):
		_credits_version_label.gui_input.connect(_on_version_label_input)


func _connect_process_tick() -> void:
	if _owner == null or _process_connected:
		return
	var tree := _owner.get_tree()
	if tree == null:
		return
	if not tree.process_frame.is_connected(_on_process_tick):
		tree.process_frame.connect(_on_process_tick)
	_process_connected = true


func _on_process_tick() -> void:
	if not _version_hold_active:
		return
	if Time.get_ticks_msec() - _version_hold_started_msec >= int(_VERSION_HOLD_SEC * 1000.0):
		_stop_version_hold()
		_toggle_dev_mode()


func _on_version_label_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_version_hold_active = true
			_version_hold_started_msec = Time.get_ticks_msec()
		else:
			_version_hold_active = false


func _stop_version_hold() -> void:
	_version_hold_active = false
	_version_hold_started_msec = 0


func _is_debug_enabled() -> bool:
	return _show_debug_tools or (SaveManager != null and SaveManager.dev_mode_enabled)


func _toggle_dev_mode() -> void:
	if SaveManager == null:
		return
	var now_on := SaveManager.toggle_dev_mode()
	if now_on and AchievementManager:
		AchievementManager.grant(AchievementCatalog.ID_DEV_MODE)
	GlobalGameManager.debug_tools_enabled = _is_debug_enabled()
	refresh_version()
	if _credits_version_label and _owner:
		var tw := _owner.create_tween()
		var target_color := Color(0.2, 1.0, 0.4, 1.0) if now_on else Color(1.0, 0.3, 0.3, 1.0)
		tw.tween_property(_credits_version_label, "modulate", target_color, 0.15)
		tw.tween_property(_credits_version_label, "modulate", Color.WHITE, 0.4)


func _app_version_string() -> String:
	var version := String(ProjectSettings.get_setting("application/config/version", "1.0.0"))
	var cleaned := ""
	for i in version.length():
		var ch := version.substr(i, 1)
		var code := version.unicode_at(i)
		var ok := (
			(code >= 48 and code <= 57)
			or ch == "."
			or ch == "-"
			or ch == "+"
			or (code >= 65 and code <= 90)
			or (code >= 97 and code <= 122)
		)
		if ok:
			cleaned += ch
	if cleaned.is_empty():
		cleaned = "1.0.0"
	return cleaned


func _credits_author_single_line(text: String) -> String:
	return text.replace(" ", "\u00a0")


func _wrap_credits_nickname_pixel_font(text: String, pixel_sz: int) -> String:
	if not text.contains(CREDITS_NICKNAME):
		return text
	var pixel := "[font=%s][font_size=%d]%s[/font_size][/font]" % [
		HudLayout.PIXEL_FONT_PATH, pixel_sz, CREDITS_NICKNAME
	]
	return text.replace(CREDITS_NICKNAME, pixel)


func _wrap_credits_full_name_pixel_font(text: String, pixel_sz: int) -> String:
	return "[font=%s][font_size=%d]%s[/font_size][/font]" % [
		HudLayout.PIXEL_FONT_PATH, pixel_sz, text
	]


func _wrap_credits_author_name_display(author: String, pixel_sz: int) -> String:
	var single_line := _credits_author_single_line(author)
	if HudFonts.locale_code() == "ka":
		return _wrap_credits_nickname_pixel_font(single_line, pixel_sz)
	return _wrap_credits_full_name_pixel_font(single_line, pixel_sz)


func _wrap_credits_author_pixel_font(bbcode: String, body_sz: int, pixel_sz: int) -> String:
	var author := String(TranslationServer.translate("UI_SPLASH_AUTHOR"))
	var author_display := _wrap_credits_author_name_display(author, pixel_sz)
	var author_single := _credits_author_single_line(author)
	if author_display == author_single and HudFonts.locale_code() == "ka":
		return bbcode
	var name_mixed: String
	if HudFonts.locale_code() == "ka":
		name_mixed = "[font_size=%d]%s[/font_size]" % [body_sz, author_display]
	else:
		name_mixed = author_display
	for name_plain in [
		"[font_size=%d]%s[/font_size]" % [body_sz, author_single],
		"[font_size=%d]%s[/font_size]" % [body_sz, author],
	]:
		if bbcode.contains(name_plain):
			return bbcode.replace(name_plain, name_mixed)
	var normalized := bbcode.replace("\u00a0", " ")
	for name_plain in [
		"[font_size=%d]%s[/font_size]" % [body_sz, author],
	]:
		if normalized.contains(name_plain):
			return normalized.replace(name_plain, name_mixed)
	return bbcode
