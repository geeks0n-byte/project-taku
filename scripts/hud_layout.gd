class_name HudLayout
extends RefCounted

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
	# Extend panel to the screen bottom so the status strip sits on the same dark fill
	# (avoids a brighter EditorBackground band under the panel).
	control_panel.offset_bottom = 0.0

static func position_counter_row(counter_row: Control) -> void:
	position_top_wide(
		counter_row,
		GameConstants.HUD_COUNTER_ROW_TOP,
		GameConstants.HUD_COUNTER_ROW_HEIGHT,
		GameConstants.HUD_TOP_BAR_EDGE_MARGIN
	)
	align_counter_row(counter_row)

## Keep counter HBox centered; hidden slots collapse so a solo timer spans the row.
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

static func position_top_bar(top_bar: Control) -> void:
	position_top_wide(
		top_bar,
		GameConstants.HUD_TOP_BAR_EDGE_MARGIN,
		GameConstants.HUD_BUTTON_HEIGHT,
		GameConstants.HUD_TOP_BAR_EDGE_MARGIN
	)

static var _screen_header_font: Font
static var _screen_header_font_default: Font

## Brand / English headers use the pixel font; other locales use the default UI font.
static func screen_header_font(force_pixel: bool = false) -> Font:
	if force_pixel or uses_pixel_font():
		if _screen_header_font == null:
			_screen_header_font = PIXEL_FONT.duplicate()
			var fallback := ThemeDB.fallback_font
			if fallback:
				_screen_header_font.fallbacks = [fallback]
		return _screen_header_font
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
	# Brand title stays pixel-sized; localized headers scale for the default font.
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

## Victory / defeat titles — safer outlines on mobile (stretch can clip glyph edges into a hard line).
static func apply_end_screen_header_style(label: Label, base_size: int = 48) -> void:
	if not label:
		return
	var size := base_size
	var outline := 8
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		# Keep sizes on the pixel grid; lighter outline avoids atlas/edge clipping on GL.
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

## Moves a header label onto `host` and pins it to the shared top-of-screen slot.
static func mount_screen_header(host: Node, label: Label) -> void:
	if not host or not label:
		return
	var parent := label.get_parent()
	if parent != host:
		if parent:
			parent.remove_child(label)
		host.add_child(label)
	if label is Control:
		label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		label.offset_left = GameConstants.HUD_SIDE_MARGIN
		label.offset_right = -GameConstants.HUD_SIDE_MARGIN
		label.offset_top = GameConstants.SCREEN_HEADER_TOP
		label.offset_bottom = GameConstants.SCREEN_HEADER_TOP + GameConstants.SCREEN_HEADER_HEIGHT
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	apply_screen_header_style(label)

## How-to-play: page titles sit on the shared header band; nav stays screen-bottom.
static func layout_how_to_play(host: Control, panel: Control, nav: Control) -> void:
	if host == null or panel == null or nav == null:
		return
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.grow_horizontal = Control.GROW_DIRECTION_BOTH
	host.grow_vertical = Control.GROW_DIRECTION_BOTH

	if nav.get_parent() != host:
		var old_parent := nav.get_parent()
		if old_parent:
			old_parent.remove_child(nav)
		host.add_child(nav)

	nav.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	nav.anchor_left = 0.0
	nav.anchor_top = 1.0
	nav.anchor_right = 1.0
	nav.anchor_bottom = 1.0
	nav.offset_left = 40.0
	nav.offset_right = -40.0
	nav.offset_top = GameConstants.SCREEN_BOTTOM_NAV_TOP
	nav.offset_bottom = GameConstants.SCREEN_BOTTOM_NAV_BOTTOM
	nav.grow_horizontal = Control.GROW_DIRECTION_BOTH
	nav.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if nav is HBoxContainer:
		(nav as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER

	var panel_w := 950.0
	if panel.custom_minimum_size.x > 0.0:
		panel_w = panel.custom_minimum_size.x
	# Stretch body between the shared header band and bottom nav (stops truncation).
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -panel_w * 0.5
	panel.offset_right = panel_w * 0.5
	panel.offset_top = (
		GameConstants.SCREEN_HEADER_TOP
		+ GameConstants.SCREEN_HEADER_HEIGHT
		+ GameConstants.SCREEN_CONTENT_GAP
	)
	panel.offset_bottom = GameConstants.SCREEN_BOTTOM_NAV_TOP - 12.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var rules := panel.get_node_or_null("RulesLabel") as Control
	if rules:
		rules.offset_top = 0.0
		rules.offset_bottom = -12.0
		if rules is RichTextLabel:
			var rtl := rules as RichTextLabel
			rtl.fit_content = false
			# Avoid a useless 1px scrollbar; pages are laid out to fit the panel.
			rtl.scroll_active = false
			rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

## Shared Label header for How to Play pages (same band/style as other screens).
static func ensure_how_to_play_page_header(host: Control) -> Label:
	if host == null:
		return null
	var header := host.get_node_or_null("HowToPlayPageHeader") as Label
	if header == null:
		header = Label.new()
		header.name = "HowToPlayPageHeader"
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(header)
	mount_screen_header(host, header)
	return header

## Keep Close centered when Prev/Next are hidden by reserving fixed side slots.
static func ensure_how_to_play_nav_slots(nav: HBoxContainer, prev: Button, next: Button) -> void:
	if nav == null:
		return
	_ensure_htp_side_slot(nav, prev, "PrevSlot", 0)
	_ensure_htp_side_slot(nav, next, "NextSlot", -1)

static func _ensure_htp_side_slot(
	nav: HBoxContainer,
	button: Button,
	slot_name: String,
	desired_index: int
) -> void:
	if button == null:
		return
	var slot := nav.get_node_or_null(slot_name) as Control
	if slot == null:
		slot = Control.new()
		slot.name = slot_name
		nav.add_child(slot)
	slot.custom_minimum_size = GameConstants.UI_BTN_NAV_SIZE
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if button.get_parent() != slot:
		var old_parent := button.get_parent()
		if old_parent:
			old_parent.remove_child(button)
		slot.add_child(button)
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.offset_left = 0.0
	button.offset_top = 0.0
	button.offset_right = 0.0
	button.offset_bottom = 0.0
	var target_index := desired_index if desired_index >= 0 else nav.get_child_count() - 1
	target_index = clampi(target_index, 0, nav.get_child_count() - 1)
	if slot.get_index() != target_index:
		nav.move_child(slot, target_index)

## Pull menu body up under the shared header (CenterContainer otherwise leaves a large gap).
static func pin_menu_body_below_header(
	body: Control,
	approx_body_height: float = 980.0,
	extra_gap: float = 0.0
) -> void:
	if body == null:
		return
	body.offset_top = (
		GameConstants.SCREEN_HEADER_TOP
		+ GameConstants.SCREEN_HEADER_HEIGHT
		+ GameConstants.SCREEN_CONTENT_GAP
		+ extra_gap
	)
	var vh := 1920.0
	if body.get_viewport():
		vh = body.get_viewport().get_visible_rect().size.y
	var usable := maxf(240.0, vh - body.offset_top - 24.0)
	var band := minf(approx_body_height, usable)
	body.offset_bottom = -(vh - body.offset_top - band)

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
	# Keep intentional multi-message breaks; do not force mid-sentence wraps.
	# RichTextLabel autowrap handles line breaks by available width.
	var translated := ""
	if msg.contains("\n"):
		var translated_lines: PackedStringArray = []
		for line in msg.split("\n"):
			if line.is_empty():
				continue
			translated_lines.append(_tr(line, force_english))
		translated = "\n".join(translated_lines)
	else:
		translated = _tr(msg, force_english)
	return break_after_sentences(translated)

## After a sentence ends (. ! ?), put the following text on its own line.
## Skips digit-after-abbrev cases like "Max. 1".
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
			# Only break when there was whitespace and more content on the same line.
			if j > i + 1 and j < n and text[j] != "\n":
				var next_c := text[j]
				# Keep "Max. 1 ..." on one line; break for real next sentences.
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

## Body/status copy always uses the default font — scale even for English.
static func body_font_size(base: int) -> int:
	var scale := GameConstants.DEFAULT_FONT_SCALE
	var locale := TranslationServer.get_locale().substr(0, 2)
	if locale == "ka":
		scale *= 1.15
	return int(round(float(base) * scale))

## Temporary: pixel font for English only; all other locales use the default font.
const PIXEL_FONT: Font = preload("res://resources/fonts/PressStart2P-vaV7.ttf")

static func uses_pixel_font() -> bool:
	return TranslationServer.get_locale().substr(0, 2) == "en"

static func ui_font() -> Font:
	return PIXEL_FONT if uses_pixel_font() else ThemeDB.fallback_font

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
	# Status always uses the default font; keep size readable but not oversized.
	var size := int(round(float(base_size) * 1.2))
	var locale := TranslationServer.get_locale().substr(0, 2)
	if locale == "ka":
		size = int(round(float(size) * 1.15))
	# Keep bold/italics the same size so [b]/[i]/[color] words are not smaller.
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
	if node.get_meta("_screen_header", false) and node is Label:
		apply_screen_header_style(node as Label)
		return
	if is_status_label(node) and node is RichTextLabel:
		apply_status_font(node as RichTextLabel)
		return
	var use_default := bool(node.get_meta("_use_default_font", false))
	# Constraint brush glyphs (= / ×) always need the default font.
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
	button.custom_minimum_size = GameConstants.UI_BTN_NAV_SIZE
	fit_text_button(button, GameConstants.UI_BTN_NAV_FONT, GameConstants.UI_BTN_NAV_FONT_MIN)

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

## Popup body copy: pixel font in English, default font elsewhere.
static func apply_popup_label(label: Label, base_size: int = GameConstants.UI_BODY_FONT_SIZE) -> void:
	if not label:
		return
	label.set_meta("_use_default_font", not uses_pixel_font())
	apply_locale_font_to_control(label)
	var size := base_size if uses_pixel_font() else body_font_size(base_size)
	label.add_theme_font_size_override("font_size", size)

## Shared dialog / confirm panel chrome (dark fill + soft yellow border).
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
	# Replace legacy full-bleed ColorRect if present.
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
		# Inset so the tint sits inside the 9-slice button art.
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

## Soft scale + brightness pulse for tutorial NEXT (clearer than a white mask).
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

## Pads top/bottom so RichTextLabel font outlines are not clipped by fit_content bounds.
static func format_outlined_center_text(body: String) -> String:
	var pad := GameConstants.HUD_LEVEL_OUTLINE_PAD
	return "[center][font_size=%d][color=#00000000].[/color][/font_size]\n%s\n[font_size=%d][color=#00000000].[/color][/font_size][/center]" % [
		pad, body, pad
	]

static func _tr(key: String, force_english: bool = false) -> String:
	if force_english:
		return english(key)
	return String(TranslationServer.translate(key))

static func apply_square_top_bar_button(button: Button) -> void:
	if not button:
		return
	var size := float(GameConstants.HUD_BUTTON_WIDTH)
	button.custom_minimum_size = Vector2(size, size)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nudge_button_icon_up(button, GameConstants.HUD_TOP_BAR_ICON_NUDGE)
	refresh_button_icon_modulate(button)
	if not button.has_meta("_icon_disabled_hook"):
		button.set_meta("_icon_disabled_hook", true)
		button.draw.connect(func(): refresh_button_icon_modulate(button))

static func nudge_button_icon_up(button: Button, pixels: int = 1) -> void:
	if not button:
		return
	var icon_container := button.get_node_or_null("IconContainer")
	if icon_container is MarginContainer:
		icon_container.add_theme_constant_override("margin_bottom", pixels * 2)
		icon_container.add_theme_constant_override("margin_top", 0)
	elif icon_container is CenterContainer:
		# CenterContainer resets child positions; wrap content with bottom margin.
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
	# Text-only buttons (- / +): bias via stylebox content margins.
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

static func apply_top_bar_row(top_bar_row: HBoxContainer) -> void:
	if not top_bar_row:
		return

	# Desired layout:
	# [expand][left buttons][small gap][label][small gap][right buttons][expand]
	var left_buttons := top_bar_row.get_node_or_null("LeftButtons") as Control
	var right_buttons := top_bar_row.get_node_or_null("RightButtons") as Control
	var label_wrap: Control = null
	for child in top_bar_row.get_children():
		if child is CenterContainer:
			label_wrap = child
			break

	if left_buttons:
		left_buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if right_buttons:
		right_buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if label_wrap:
		label_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var gap := GameConstants.HUD_CENTER_LABEL_GAP
	for spacer_name in ["LeftSpacer", "RightSpacer"]:
		var spacer := top_bar_row.get_node_or_null(spacer_name) as Control
		if spacer:
			spacer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			spacer.size_flags_stretch_ratio = 0.0
			spacer.custom_minimum_size = Vector2(gap, 0)

	var left_edge := _ensure_named_spacer(top_bar_row, "LeftEdgeSpacer")
	var right_edge := _ensure_named_spacer(top_bar_row, "RightEdgeSpacer")
	left_edge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_edge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_edge.size_flags_stretch_ratio = 1.0
	right_edge.size_flags_stretch_ratio = 1.0

	# Force final child order every time.
	var ordered: Array[Node] = []
	ordered.append(left_edge)
	if left_buttons:
		ordered.append(left_buttons)
	var left_spacer := top_bar_row.get_node_or_null("LeftSpacer")
	if left_spacer:
		ordered.append(left_spacer)
	if label_wrap:
		ordered.append(label_wrap)
	var right_spacer := top_bar_row.get_node_or_null("RightSpacer")
	if right_spacer:
		ordered.append(right_spacer)
	if right_buttons:
		ordered.append(right_buttons)
	ordered.append(right_edge)

	for i in range(ordered.size()):
		top_bar_row.move_child(ordered[i], i)

	top_bar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar_row.add_theme_constant_override("separation", 0)

static func _ensure_named_spacer(top_bar_row: HBoxContainer, spacer_name: String) -> Control:
	var edge := top_bar_row.get_node_or_null(spacer_name) as Control
	if edge == null:
		edge = Control.new()
		edge.name = spacer_name
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_bar_row.add_child(edge)
	return edge

static func apply_top_bar_mode_label(label: RichTextLabel) -> void:
	if not label:
		return
	# Non-English locales: default font (pixel font is English-only for now).
	label.set_meta("_use_default_font", not uses_pixel_font())
	apply_locale_font_to_control(label)
	label.custom_minimum_size = Vector2(220, 0)
	label.fit_content = true
	label.clip_contents = false
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_constant_override("line_separation", GameConstants.HUD_CENTER_LABEL_LINE_SEPARATION)
	var inset: Node = label.get_parent()
	if inset is MarginContainer:
		var nudge := int(GameConstants.HUD_LEVEL_LABEL_Y_NUDGE)
		inset.add_theme_constant_override("margin_top", nudge)
		inset.add_theme_constant_override("margin_bottom", nudge)
		inset.clip_contents = false
	var label_wrap: Node = null
	if inset:
		label_wrap = inset.get_parent()
	if label_wrap is CenterContainer:
		label_wrap.custom_minimum_size = Vector2(220, GameConstants.HUD_BUTTON_HEIGHT)
		label_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		label_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label_wrap.clip_contents = false
	var row := label_wrap.get_parent() if label_wrap else null
	if row is HBoxContainer:
		apply_top_bar_row(row)

static func align_counter_label(label: RichTextLabel, y_nudge: float = 0.0) -> void:
	if not label:
		return
	label.set_anchors_preset(Control.PRESET_CENTER)
	var half_w := GameConstants.HUD_COUNTER_LABEL_HALF_W
	var half_h := GameConstants.HUD_COUNTER_LABEL_HALF_H
	label.offset_left = -half_w
	label.offset_right = half_w
	label.offset_top = -half_h + y_nudge
	label.offset_bottom = half_h + y_nudge
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
	# Icon + caption clarifies what is counted (green tiles vs shifter moves).
	return "[center][img=%dx%d]%s[/img] [font_size=%d][color=#%s]%s[/color][/font_size] [font_size=%d][color=#%s]%d/%d[/color][/font_size][/center]" % [
		icon_size, icon_size, icon_path, label_size, hex, caption, num_size, hex, current, required
	]

static func format_time_counter(formatted_time: String, _label_text: String = "") -> String:
	var num_size := scaled_font_size(GameConstants.HUD_COUNTER_FONT_SIZE)
	if formatted_time == "∞":
		var icon_size := GameConstants.HUD_INFINITY_ICON_SIZE
		return "[center][img=%dx%d]%s[/img][/center]" % [
			icon_size, icon_size, GameConstants.ICON_INFINITY
		]
	return "[center][font_size=%d]%s[/font_size][/center]" % [num_size, formatted_time]
