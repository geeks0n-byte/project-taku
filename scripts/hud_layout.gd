class_name HudLayout
extends RefCounted

const _TOP_BAR_TILE_TEX := preload("res://resources/buttons/button_tile_gray_dark.svg")
const _CLOSE_ICON_TEX := preload("res://resources/icons/icon_close.svg")
const _PREV_ICON_TEX := preload("res://resources/icons/icon_prev.svg")
const _NEXT_ICON_TEX := preload("res://resources/icons/icon_next.svg")
const _TOP_BAR_ICON_PX := 83.0

static func position_top_wide(control: Control, top: float, height: float, margin: float = GameConstants.HUD_SIDE_MARGIN) -> void:
	if not control:
		return
	control.set_anchors_preset(Control.PRESET_TOP_WIDE)
	control.offset_left = margin
	control.offset_right = -margin
	control.offset_top = top
	control.offset_bottom = top + height

static func position_status_below_board(status: Control, board_y: float, board_height: float) -> void:
	position_top_wide(status, board_y + board_height + GameConstants.HUD_STATUS_GAP, GameConstants.HUD_STATUS_MIN_HEIGHT)

static func position_editor_status_below_panel(control_panel: Control, status: Control) -> void:
	if not control_panel or not status:
		return
	var bottom_margin := GameConstants.HUD_TOP_BAR_EDGE_MARGIN
	var status_top := -(bottom_margin + GameConstants.HUD_EDITOR_STATUS_HEIGHT)
	status.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	status.offset_left = bottom_margin
	status.offset_right = -bottom_margin
	status.offset_bottom = -bottom_margin
	status.offset_top = status_top
	control_panel.offset_bottom = 0.0

static func position_counter_row(counter_row: Control) -> void:
	# Geometry is owned by the HUD scene tree.
	align_counter_row(counter_row)

static func align_counter_row(counter_row: Control) -> void:
	if counter_row == null:
		return
	if counter_row is HBoxContainer:
		(counter_row as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	for child in counter_row.get_children():
		if child is Control and (child as Control).visible:
			var slot := child as Control
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot.size_flags_stretch_ratio = 1.0

static var _screen_header_font_default: Font

static func screen_header_font(force_pixel: bool = false) -> Font:
	if force_pixel or uses_pixel_font():
		return pixel_font()
	if _screen_header_font_default == null:
		_screen_header_font_default = ThemeDB.fallback_font
	return _screen_header_font_default

static func apply_screen_header_style(label: Label) -> void:
	if not label:
		return
	label.set_meta("_screen_header", true)
	var force_pixel := bool(label.get_meta("_brand_title", false))
	label.add_theme_font_override("font", screen_header_font(force_pixel))
	var header_size: int = int(label.get_meta(
		"_screen_header_font_size",
		GameConstants.SCREEN_HEADER_FONT_SIZE
	))
	var outline_size: int = int(label.get_meta(
		"_screen_header_outline",
		GameConstants.SCREEN_HEADER_OUTLINE
	))
	if force_pixel or uses_pixel_font():
		label.add_theme_font_size_override("font_size", header_size)
	else:
		label.add_theme_font_size_override("font_size", body_font_size(header_size))
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_color_override("font_color", GameConstants.SCREEN_HEADER_COLOR)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = false
	label.clip_contents = false

static func apply_end_screen_header_style(label: Label, base_size: int = 48) -> void:
	if not label:
		return
	var size := base_size
	var outline := 8
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		size = 40
		outline = 6
	label.set_meta("_brand_title", true)
	label.set_meta("_screen_header", true)
	label.set_meta("_screen_header_font_size", size)
	label.set_meta("_screen_header_outline", outline)
	apply_screen_header_style(label)
	label.clip_text = false
	label.clip_contents = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF

static func ensure_how_to_play_page_header(host: Control) -> Label:
	if host == null:
		return null
	return host.get_node_or_null("HowToPlayPageHeader") as Label

## Size the rules panel to its text and park PREV/NEXT directly under it.
static func layout_how_to_play_stack(
	host: Control,
	panel: Control,
	rules: RichTextLabel,
	nav: Control
) -> void:
	if host == null or panel == null or nav == null:
		return
	var host_h := host.size.y
	if host_h <= 1.0:
		host_h = float(
			ProjectSettings.get_setting("display/window/size/viewport_height", 1920)
		)
	var nav_h := GameConstants.UI_BTN_NAV_SIZE.y
	var bottom_limit := host_h - GameConstants.AD_BANNER_RESERVE - 16.0
	var max_panel_h := maxf(
		GameConstants.HTP_PANEL_MIN_HEIGHT,
		bottom_limit - GameConstants.HTP_PANEL_TOP - nav_h - GameConstants.SCREEN_NAV_GAP
	)

	# Lock horizontal size first so RichTextLabel can measure wrap height.
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -GameConstants.HTP_PANEL_HALF_WIDTH
	panel.offset_right = GameConstants.HTP_PANEL_HALF_WIDTH
	panel.offset_top = GameConstants.HTP_PANEL_TOP
	panel.offset_bottom = GameConstants.HTP_PANEL_TOP + max_panel_h
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var content_h := max_panel_h
	if rules:
		rules.fit_content = true
		rules.scroll_active = false
		rules.custom_minimum_size = Vector2(0, 0)
		content_h = maxf(rules.get_content_height() + 24.0, GameConstants.HTP_PANEL_MIN_HEIGHT)
	var panel_h := clampf(content_h, GameConstants.HTP_PANEL_MIN_HEIGHT, max_panel_h)
	panel.offset_bottom = GameConstants.HTP_PANEL_TOP + panel_h
	if rules:
		var needs_scroll := content_h > panel_h + 1.0
		rules.scroll_active = needs_scroll
		rules.fit_content = not needs_scroll

	var nav_top := panel.offset_bottom + GameConstants.SCREEN_NAV_GAP
	nav.anchor_left = 0.0
	nav.anchor_right = 1.0
	nav.anchor_top = 0.0
	nav.anchor_bottom = 0.0
	nav.offset_left = 40.0
	nav.offset_right = -40.0
	nav.offset_top = nav_top
	nav.offset_bottom = nav_top + nav_h
	nav.grow_horizontal = Control.GROW_DIRECTION_BOTH
	nav.grow_vertical = Control.GROW_DIRECTION_BEGIN

static func apply_top_bar_tile_styles(button: Button) -> void:
	if not button:
		return
	for style_name in ["normal", "pressed", "hover", "disabled", "focus"]:
		var box := StyleBoxTexture.new()
		box.texture = _TOP_BAR_TILE_TEX
		box.texture_margin_left = 16.0
		box.texture_margin_top = 16.0
		box.texture_margin_right = 16.0
		box.texture_margin_bottom = 16.0
		box.content_margin_left = 8.0
		box.content_margin_top = 8.0
		box.content_margin_right = 8.0
		box.content_margin_bottom = 8.0
		if style_name == "hover":
			box.modulate_color = Color(1.2, 1.2, 1.2, 1.0)
		elif style_name == "pressed":
			box.modulate_color = Color(0.8, 0.8, 0.8, 1.0)
		elif style_name == "disabled":
			box.modulate_color = Color(0.55, 0.55, 0.55, 1.0)
		button.add_theme_stylebox_override(style_name, box)

static func ensure_top_bar_icon(button: Button, texture: Texture2D) -> void:
	if not button or texture == null:
		return
	button.text = ""
	button.flat = false
	button.clip_text = true
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	var icon_container := button.get_node_or_null("IconContainer") as MarginContainer
	if icon_container == null:
		icon_container = MarginContainer.new()
		icon_container.name = "IconContainer"
		icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
		icon_container.grow_vertical = Control.GROW_DIRECTION_BOTH
		button.add_child(icon_container)
	var icon := icon_container.get_node_or_null("Icon") as TextureRect
	if icon == null:
		icon = TextureRect.new()
		icon.name = "Icon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_container.add_child(icon)
	icon.texture = texture
	icon.custom_minimum_size = Vector2(_TOP_BAR_ICON_PX, _TOP_BAR_ICON_PX)

static func style_top_bar_close_button(button: Button) -> void:
	if button == null:
		return
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.z_index = 20
	button.focus_mode = Control.FOCUS_ALL
	apply_top_bar_tile_styles(button)
	ensure_top_bar_icon(button, _CLOSE_ICON_TEX)
	apply_square_top_bar_button(button)

static func english(key: String) -> String:
	if key.is_empty():
		return ""
	var translation := TranslationServer.get_translation_object("en")
	if translation:
		var msg := String(translation.get_message(StringName(key)))
		if not msg.is_empty():
			return msg
	return key

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

static func _translate_status_token(token: String, force_english: bool = false) -> String:
	var parts := token.split("|")
	var key := parts[0]
	var translated := _tr(key, force_english)
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

static func break_after_sentences(text: String) -> String:
	if text.is_empty():
		return text
	var out := ""
	var i := 0
	var n := text.length()
	while i < n:
		var c := text[i]
		out += c
		if c == "." or c == "!" or c == "?":
			var j := i + 1
			while j < n and (text[j] == " " or text[j] == "\t"):
				j += 1
			if j > i + 1 and j < n and text[j] != "\n":
				var next_c := text[j]
				if next_c < "0" or next_c > "9":
					out += "\n"
					i = j
					continue
		i += 1
	return out

static func format_centered_status(msg: String, force_english: bool = false) -> String:
	return "[center]" + translate_status_text(msg, force_english) + "[/center]"

static func font_scale() -> float:
	var scale := 1.0
	if not uses_pixel_font():
		scale = GameConstants.DEFAULT_FONT_SCALE
	var locale := TranslationServer.get_locale().substr(0, 2)
	if locale == "ka":
		scale *= 1.15
	return scale

static func scaled_font_size(base: int) -> int:
	return int(round(float(base) * font_scale()))

static func body_font_size(base: int) -> int:
	var scale := GameConstants.DEFAULT_FONT_SCALE
	var locale := TranslationServer.get_locale().substr(0, 2)
	if locale == "ka":
		scale *= 1.15
	return int(round(float(base) * scale))

const PIXEL_FONT: Font = preload("res://resources/fonts/PressStart2P-vaV7.ttf")
static var _pixel_font_with_fallback: Font

static func uses_pixel_font() -> bool:
	return TranslationServer.get_locale().substr(0, 2) == "en"

static func pixel_font() -> Font:
	if _pixel_font_with_fallback == null and PIXEL_FONT != null:
		_pixel_font_with_fallback = PIXEL_FONT.duplicate()
		var fallback := ThemeDB.fallback_font
		if fallback:
			_pixel_font_with_fallback.fallbacks = [fallback]
	return _pixel_font_with_fallback if _pixel_font_with_fallback else PIXEL_FONT

static func ui_font() -> Font:
	return pixel_font() if uses_pixel_font() else ThemeDB.fallback_font

static func is_status_label(node: Node) -> bool:
	if node == null:
		return false
	var n := String(node.name)
	return n == "StatusLabel" or n == "PlaytestStatusLabel" or n.ends_with("StatusLabel")

static func apply_status_font(label: RichTextLabel, base_size: int = GameConstants.HUD_STATUS_FONT_SIZE) -> void:
	if not label:
		return
	var font := ThemeDB.fallback_font
	label.add_theme_font_override("normal_font", font)
	label.add_theme_font_override("bold_font", font)
	label.add_theme_font_override("italics_font", font)
	label.add_theme_font_override("bold_italics_font", font)
	label.add_theme_font_override("mono_font", font)
	var size := int(round(float(base_size) * 1.2))
	var locale := TranslationServer.get_locale().substr(0, 2)
	if locale == "ka":
		size = int(round(float(size) * 1.15))
	for size_name in [
		"normal_font_size",
		"bold_font_size",
		"italics_font_size",
		"bold_italics_font_size",
		"mono_font_size",
	]:
		label.add_theme_font_size_override(size_name, size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.fit_content = true
	label.scroll_active = false

static func apply_locale_font_to_control(node: Node) -> void:
	if node == null:
		return
	if node.get_meta("_force_pixel_font", false):
		_apply_forced_pixel_font(node)
		return
	if node.get_meta("_screen_header", false) and node is Label:
		apply_screen_header_style(node as Label)
		return
	if is_status_label(node) and node is RichTextLabel:
		apply_status_font(node as RichTextLabel)
		return
	# Icon-only top-bar buttons: locale font metrics shift the TextureRect.
	if _is_icon_only_button(node):
		return
	var use_default := bool(node.get_meta("_use_default_font", false))
	if not use_default and node is Label:
		var label_text := (node as Label).text
		if label_text == "=" or label_text == "×":
			use_default = true
			node.set_meta("_use_default_font", true)
	var font := ThemeDB.fallback_font if use_default else ui_font()
	if node is Button or node is Label or node is LineEdit or node is OptionButton:
		node.add_theme_font_override("font", font)
	elif node is RichTextLabel:
		node.add_theme_font_override("normal_font", font)
		node.add_theme_font_override("bold_font", font)
		node.add_theme_font_override("italics_font", font)
		node.add_theme_font_override("bold_italics_font", font)
		node.add_theme_font_override("mono_font", font)

static func _is_icon_only_button(node: Node) -> bool:
	if not node is Button:
		return false
	var button := node as Button
	return button.get_node_or_null("IconContainer") != null and button.text.is_empty()

static func _apply_forced_pixel_font(node: Node) -> void:
	var font := pixel_font()
	if font == null:
		return
	if node is Button or node is Label or node is LineEdit or node is OptionButton:
		node.add_theme_font_override("font", font)
	elif node is RichTextLabel:
		node.add_theme_font_override("normal_font", font)
		node.add_theme_font_override("bold_font", font)
		node.add_theme_font_override("italics_font", font)
		node.add_theme_font_override("bold_italics_font", font)
		node.add_theme_font_override("mono_font", font)

static func apply_locale_fonts_to_tree(root: Node) -> void:
	if root == null:
		return
	apply_locale_font_to_control(root)
	for child in root.get_children():
		apply_locale_fonts_to_tree(child)

static func fit_text_button(button: Button, base_font_size: int = 36, min_font_size: int = 18) -> void:
	if not button:
		return
	button.clip_text = false
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	apply_locale_font_to_control(button)
	var font: Font = (
		ThemeDB.fallback_font if button.get_meta("_use_default_font", false) else ui_font()
	)
	if font == null:
		font = ThemeDB.fallback_font
	var target_w := maxf(40.0, button.custom_minimum_size.x - 28.0)
	var target_h := maxf(40.0, button.custom_minimum_size.y - 24.0)
	var display := button.text
	if button.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED:
		display = String(TranslationServer.translate(button.text))
	var size := scaled_font_size(base_font_size)
	var min_size := scaled_font_size(min_font_size)
	while size > min_size:
		var measured := font.get_multiline_string_size(display, HORIZONTAL_ALIGNMENT_CENTER, target_w, size)
		if measured.x <= target_w + 2.0 and measured.y <= target_h + 2.0:
			break
		size -= 2
	button.add_theme_font_size_override("font_size", size)
	# Keep outline proportional so large outlines don't mush glyphs on mobile.
	var base_outline := int(button.get_theme_constant("outline_size"))
	if base_outline <= 0:
		base_outline = GameConstants.MENU_TEXT_OUTLINE
	var outline := int(round(float(base_outline) * float(size) / float(maxi(base_font_size, 1))))
	outline = clampi(outline, 2, base_outline)
	button.add_theme_constant_override("outline_size", outline)

static func fit_text_button_single_line(button: Button, base_font_size: int = 36, min_font_size: int = 18) -> void:
	if not button:
		return
	button.clip_text = false
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	apply_locale_font_to_control(button)
	var font: Font = (
		ThemeDB.fallback_font if button.get_meta("_use_default_font", false) else ui_font()
	)
	if font == null:
		font = ThemeDB.fallback_font
	var target_w := maxf(40.0, button.custom_minimum_size.x - 36.0)
	var display := button.text
	if button.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED:
		display = String(TranslationServer.translate(button.text))
	var size := scaled_font_size(base_font_size)
	var min_size := scaled_font_size(min_font_size)
	while size > min_size:
		var measured := font.get_string_size(display, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		if measured.x <= target_w + 2.0:
			break
		size -= 2
	button.add_theme_font_size_override("font_size", size)
	var base_outline := int(button.get_theme_constant("outline_size"))
	if base_outline <= 0:
		base_outline = GameConstants.MENU_TEXT_OUTLINE
	var outline := int(round(float(base_outline) * float(size) / float(maxi(base_font_size, 1))))
	outline = clampi(outline, 2, base_outline)
	button.add_theme_constant_override("outline_size", outline)

static func apply_primary_button(button: Button) -> void:
	if not button:
		return
	button.custom_minimum_size = GameConstants.UI_BTN_PRIMARY_SIZE
	fit_text_button(
		button, GameConstants.UI_BTN_PRIMARY_FONT, GameConstants.UI_BTN_PRIMARY_FONT_MIN
	)

static func apply_secondary_button(button: Button) -> void:
	if not button:
		return
	button.custom_minimum_size = GameConstants.UI_BTN_SECONDARY_SIZE
	fit_text_button(
		button, GameConstants.UI_BTN_SECONDARY_FONT, GameConstants.UI_BTN_SECONDARY_FONT_MIN
	)

static func apply_dialog_button(button: Button) -> void:
	if not button:
		return
	button.custom_minimum_size = GameConstants.UI_BTN_DIALOG_SIZE
	fit_text_button(
		button, GameConstants.UI_BTN_DIALOG_FONT, GameConstants.UI_BTN_DIALOG_FONT_MIN
	)

static func apply_nav_button(button: Button) -> void:
	if not button:
		return
	button.text = ""
	button.flat = false
	button.clip_text = true
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.custom_minimum_size = GameConstants.UI_BTN_NAV_SIZE
	apply_top_bar_tile_styles(button)
	var name_l := String(button.name).to_lower()
	var is_next := name_l.contains("next")
	ensure_top_bar_icon(button, _NEXT_ICON_TEX if is_next else _PREV_ICON_TEX)
	var icon := button.get_node_or_null("IconContainer/Icon") as TextureRect
	if icon:
		var px := GameConstants.UI_BTN_NAV_ICON_PX
		icon.custom_minimum_size = Vector2(px, px - 1.0)
	nudge_button_icon_up(button, GameConstants.HUD_TOP_BAR_ICON_NUDGE)
	# Nudge helper uses 2x margins; add exactly +1px more lift for nav icons.
	var icon_root := button.get_node_or_null("IconContainer") as MarginContainer
	if icon_root:
		icon_root.add_theme_constant_override(
			"margin_bottom",
			GameConstants.HUD_TOP_BAR_ICON_NUDGE * 2 + 1
		)
	refresh_button_icon_modulate(button)
	if not button.has_meta("_icon_disabled_hook"):
		button.set_meta("_icon_disabled_hook", true)
		button.draw.connect(func(): refresh_button_icon_modulate(button))

static func apply_panel_button(button: Button) -> void:
	if not button:
		return
	button.custom_minimum_size = GameConstants.UI_BTN_PANEL_SIZE
	fit_text_button(button, GameConstants.UI_BTN_PANEL_FONT, GameConstants.UI_BTN_PANEL_FONT_MIN)

static func apply_tab_button(button: Button) -> void:
	if not button:
		return
	button.custom_minimum_size = GameConstants.UI_BTN_TAB_SIZE
	fit_text_button(button, GameConstants.UI_BTN_TAB_FONT, GameConstants.UI_BTN_TAB_FONT_MIN)

static func apply_popup_label(label: Label, base_size: int = GameConstants.UI_BODY_FONT_SIZE) -> void:
	if not label:
		return
	label.set_meta("_use_default_font", not uses_pixel_font())
	apply_locale_font_to_control(label)
	var size := base_size if uses_pixel_font() else body_font_size(base_size)
	label.add_theme_font_size_override("font_size", size)

static func make_dialog_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.98)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(28)
	style.border_color = Color(1.0, 0.84, 0.0, 0.4)
	style.set_border_width_all(3)
	return style

static func apply_body_label(label: Label, base_size: int = GameConstants.UI_BODY_FONT_SIZE) -> void:
	if not label:
		return
	label.set_meta("_use_default_font", true)
	apply_locale_font_to_control(label)
	label.add_theme_font_size_override("font_size", body_font_size(base_size))

static func apply_body_richtext(
	label: RichTextLabel, base_size: int = GameConstants.UI_BODY_FONT_SIZE
) -> void:
	if not label:
		return
	label.set_meta("_use_default_font", true)
	apply_locale_font_to_control(label)
	label.add_theme_font_size_override("normal_font_size", body_font_size(base_size))

static func apply_toggle_active_mask(button: Button, is_on: bool, tint: Color = GameConstants.TOGGLE_MASK_AMBER) -> void:
	if not button:
		return
	var legacy := button.get_node_or_null("ActiveMask")
	if legacy is ColorRect:
		legacy.queue_free()
		legacy = null
	var mask := button.get_node_or_null("ActiveMask") as Panel
	if mask == null:
		mask = Panel.new()
		mask.name = "ActiveMask"
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mask.set_anchors_preset(Control.PRESET_FULL_RECT)
		mask.offset_left = 12.0
		mask.offset_top = 12.0
		mask.offset_right = -12.0
		mask.offset_bottom = -12.0
		button.add_child(mask)
	var style := StyleBoxFlat.new()
	style.bg_color = tint
	style.set_corner_radius_all(10)
	style.set_content_margin_all(0)
	mask.add_theme_stylebox_override("panel", style)
	mask.visible = is_on
	mask.modulate = Color.WHITE
	button.modulate = Color.WHITE
	if not is_on:
		stop_toggle_mask_breathe(button)

static func start_toggle_mask_breathe(button: Button) -> void:
	if not button:
		return
	var mask := button.get_node_or_null("ActiveMask") as CanvasItem
	if mask == null or not mask.visible:
		return
	stop_toggle_mask_breathe(button)
	mask.modulate = Color(1, 1, 1, 1)
	var tween := button.create_tween().set_loops()
	tween.tween_property(mask, "modulate:a", 0.35, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(mask, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	button.set_meta("_toggle_mask_breathe", tween)

static func stop_toggle_mask_breathe(button: Button) -> void:
	if not button:
		return
	if button.has_meta("_toggle_mask_breathe"):
		var tween: Tween = button.get_meta("_toggle_mask_breathe")
		if tween:
			tween.kill()
		button.remove_meta("_toggle_mask_breathe")
	var mask := button.get_node_or_null("ActiveMask") as CanvasItem
	if mask:
		mask.modulate = Color.WHITE

static func start_button_attention_pulse(button: Button) -> void:
	if not button:
		return
	stop_button_attention_pulse(button)
	_sync_button_attention_pivot(button)
	button.scale = Vector2.ONE
	button.modulate = Color.WHITE
	var tween := button.create_tween().set_loops()
	tween.tween_property(button, "scale", Vector2(1.12, 1.12), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(
		button, "modulate", Color(1.22, 1.22, 1.1, 1.0), 0.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(button, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	button.set_meta("_attention_pulse", tween)

static func stop_button_attention_pulse(button: Button) -> void:
	if not button:
		return
	if button.has_meta("_attention_pulse"):
		var tween: Tween = button.get_meta("_attention_pulse")
		if tween:
			tween.kill()
		button.remove_meta("_attention_pulse")
	button.scale = Vector2.ONE
	button.modulate = Color.WHITE

static func _sync_button_attention_pivot(button: Button) -> void:
	if button:
		button.pivot_offset = button.size * 0.5

static func refresh_button_icon_modulate(button: Button) -> void:
	if not button:
		return
	var icon_root := button.get_node_or_null("IconContainer") as CanvasItem
	if icon_root:
		icon_root.modulate = GameConstants.DISABLED_ICON_MODULATE if button.disabled else Color.WHITE

static func format_mode_label(translation_key: String, force_english: bool = false) -> String:
	var text := _tr(translation_key, force_english)
	return format_outlined_center_text(text.replace(" ", "\n"))

static func format_outlined_center_text(body: String) -> String:
	return "[center]%s[/center]" % body

static func _tr(key: String, force_english: bool = false) -> String:
	if force_english:
		return english(key)
	return String(TranslationServer.translate(key))

## Keep `[img]…[/img]` + color name on one line (no wrap between icon and label).
static func glue_tile_icon_color_labels(bbcode: String) -> String:
	if bbcode.is_empty():
		return bbcode
	var out := bbcode
	out = out.replace("[/img] [color=", "[/img][wj][color=")
	out = out.replace("[/img]\t[color=", "[/img][wj][color=")
	out = out.replace("[/img][color=", "[/img][wj][color=")
	out = out.replace("[/img][wj][wj][color=", "[/img][wj][color=")
	return out

static func apply_square_top_bar_button(button: Button) -> void:
	if not button:
		return
	var size := float(GameConstants.HUD_BUTTON_WIDTH)
	button.custom_minimum_size = Vector2(size, size)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon := button.get_node_or_null("IconContainer/Icon") as TextureRect
	if icon:
		var px := float(GameConstants.HUD_ICON_SIZE)
		icon.custom_minimum_size = Vector2(px, px)
	nudge_button_icon_up(button, GameConstants.HUD_TOP_BAR_ICON_NUDGE)
	refresh_button_icon_modulate(button)
	if not button.has_meta("_icon_disabled_hook"):
		button.set_meta("_icon_disabled_hook", true)
		button.draw.connect(func(): refresh_button_icon_modulate(button))

static func apply_top_bar_button_cluster(cluster: HBoxContainer) -> void:
	if not cluster:
		return
	cluster.custom_minimum_size = Vector2(
		GameConstants.HUD_BUTTON_CLUSTER_WIDTH,
		GameConstants.HUD_BUTTON_HEIGHT
	)
	cluster.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cluster.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cluster.add_theme_constant_override("separation", GameConstants.HUD_BUTTON_SEPARATION)

static func nudge_button_icon_up(button: Button, pixels: int = 1) -> void:
	if not button:
		return
	var icon_container := button.get_node_or_null("IconContainer")
	if icon_container is MarginContainer:
		icon_container.add_theme_constant_override("margin_bottom", pixels * 2)
		icon_container.add_theme_constant_override("margin_top", 0)
	elif icon_container is CenterContainer:
		for child in icon_container.get_children():
			if child is MarginContainer and child.has_meta("_icon_nudge"):
				child.add_theme_constant_override("margin_bottom", pixels * 2)
				continue
			if child is Control:
				var wrapper := MarginContainer.new()
				wrapper.set_meta("_icon_nudge", true)
				wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
				wrapper.add_theme_constant_override("margin_bottom", pixels * 2)
				var idx := child.get_index()
				icon_container.remove_child(child)
				wrapper.add_child(child)
				icon_container.add_child(wrapper)
				icon_container.move_child(wrapper, idx)
	if button.text != "" and icon_container == null:
		_nudge_button_text_up(button, pixels)

static func _nudge_button_text_up(button: Button, pixels: int) -> void:
	for style_name in ["normal", "pressed", "hover", "disabled"]:
		var style: StyleBox = button.get_theme_stylebox(style_name)
		if style is StyleBoxTexture:
			var copied: StyleBoxTexture = style.duplicate()
			copied.content_margin_top = maxf(0.0, copied.content_margin_top - float(pixels))
			copied.content_margin_bottom = copied.content_margin_bottom + float(pixels)
			button.add_theme_stylebox_override(style_name, copied)

static func apply_top_bar_mode_label(label: RichTextLabel) -> void:
	if not label:
		return
	label.set_meta("_use_default_font", not uses_pixel_font())
	apply_locale_font_to_control(label)
	label.bbcode_enabled = true
	label.fit_content = false
	label.scroll_active = false
	label.clip_contents = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("line_separation", GameConstants.HUD_CENTER_LABEL_LINE_SEPARATION)
	label.add_theme_constant_override("outline_size", GameConstants.HUD_LEVEL_OUTLINE_SIZE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	var w := float(GameConstants.HUD_CENTER_LABEL_WIDTH)
	var h := float(GameConstants.HUD_BUTTON_HEIGHT)
	label.custom_minimum_size = Vector2(w, h)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var inset := label.get_parent() as Control
	if inset:
		inset.custom_minimum_size = Vector2(w, h)
		inset.clip_contents = false
		if inset is MarginContainer:
			inset.add_theme_constant_override("margin_top", 0)
			inset.add_theme_constant_override("margin_bottom", 0)
		var label_wrap := inset.get_parent() as Control
		if label_wrap:
			label_wrap.custom_minimum_size = Vector2(w, h)
			label_wrap.clip_contents = false
			label_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			label_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var plain := _plain_top_bar_label_text(label.text)
	if not plain.is_empty():
		label.add_theme_font_size_override("normal_font_size", fit_top_bar_two_line_font_size(plain))

static func _plain_top_bar_label_text(bbcode: String) -> String:
	var plain := bbcode
	for tag in ["[center]", "[/center]"]:
		plain = plain.replace(tag, "")
	return plain.strip_edges()

static func fit_top_bar_level_font_size(prefix: String, num: int) -> int:
	return fit_top_bar_two_line_font_size("%s\n%d" % [prefix, num])

static func fit_top_bar_two_line_font_size(body: String) -> int:
	var base := GameConstants.HUD_LEVEL_FONT_SIZE
	var size := scaled_font_size(base)
	var font: Font = ui_font()
	if font == null:
		font = ThemeDB.fallback_font
	if font == null:
		return size
	var bar_h := float(GameConstants.HUD_BUTTON_HEIGHT)
	var bar_w := float(GameConstants.HUD_CENTER_LABEL_WIDTH)
	var line_sep := GameConstants.HUD_CENTER_LABEL_LINE_SEPARATION
	while size > 16:
		var measured := font.get_multiline_string_size(
			body, HORIZONTAL_ALIGNMENT_CENTER, bar_w, size
		)
		var total_h := measured.y + float(line_sep)
		if measured.x <= bar_w - 8.0 and total_h <= bar_h - 8.0:
			break
		size -= 1
	return size

static func align_counter_label(label: RichTextLabel, _y_nudge: float = 0.0) -> void:
	if not label:
		return
	label.bbcode_enabled = true
	label.fit_content = false
	label.scroll_active = false
	label.clip_contents = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

static func prepare_counter_label(label: RichTextLabel) -> void:
	if not label:
		return
	apply_locale_font_to_control(label)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.fit_content = false
	label.scroll_active = false
	label.clip_contents = false
	label.add_theme_font_size_override("normal_font_size", scaled_font_size(GameConstants.HUD_COUNTER_FONT_SIZE))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_color_override("default_color", Color(0.96, 0.96, 0.96, 1))

static func prepare_timer_label(label: RichTextLabel) -> void:
	if not label:
		return
	# Timer digits always use Press Start at the English HUD size.
	label.set_meta("_force_pixel_font", true)
	_apply_forced_pixel_font(label)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.fit_content = false
	label.scroll_active = false
	label.clip_contents = false
	label.add_theme_font_size_override("normal_font_size", GameConstants.HUD_COUNTER_FONT_SIZE)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_color_override("default_color", Color(0.96, 0.96, 0.96, 1))

static func format_icon_ratio_counter(
	icon_path: String,
	current: int,
	required: int,
	accent: Color = Color.WHITE,
	caption: String = ""
) -> String:
	var icon_size := GameConstants.HUD_COUNTER_ICON_SIZE
	var num_size := scaled_font_size(GameConstants.HUD_COUNTER_FONT_SIZE)
	var label_size := scaled_font_size(GameConstants.HUD_COUNTER_LABEL_FONT_SIZE)
	var hex := accent.to_html(false)
	if caption.is_empty():
		return "[center][img=%dx%d]%s[/img] [font_size=%d][color=#%s]%d/%d[/color][/font_size][/center]" % [
			icon_size, icon_size, icon_path, num_size, hex, current, required
		]
	return "[center][img=%dx%d]%s[/img] [font_size=%d][color=#%s]%s[/color][/font_size] [font_size=%d][color=#%s]%d/%d[/color][/font_size][/center]" % [
		icon_size, icon_size, icon_path, label_size, hex, caption, num_size, hex, current, required
	]

static func format_time_counter(formatted_time: String, _label_text: String = "") -> String:
	var num_size := GameConstants.HUD_COUNTER_FONT_SIZE
	if formatted_time == "∞":
		var icon_size := GameConstants.HUD_INFINITY_ICON_SIZE
		return "[center][img=%dx%d]%s[/img][/center]" % [
			icon_size, icon_size, GameConstants.ICON_INFINITY
		]
	return "[center][font_size=%d]%s[/font_size][/center]" % [num_size, formatted_time]
