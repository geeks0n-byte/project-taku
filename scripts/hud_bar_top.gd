class_name HudTopBar
extends RefCounted
## In-game and overlay top-bar chrome extracted from HudLayout.
## Public call sites continue to use HudLayout.* wrappers.

const TOP_BAR_TILE_TEX := preload("res://resources/buttons/button_tile_gray_dark.svg")
const CLOSE_ICON_TEX := preload("res://resources/icons/icon_close.svg")
const PREV_ICON_TEX := preload("res://resources/icons/icon_prev.svg")
const NEXT_ICON_TEX := preload("res://resources/icons/icon_next.svg")
const TOP_BAR_ICON_PX := 83.0


static func apply_top_bar_tile_styles(button: Button) -> void:
	if not button:
		return
	for style_name in ["normal", "pressed", "hover", "disabled", "focus"]:
		var box := StyleBoxTexture.new()
		box.texture = TOP_BAR_TILE_TEX
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
	icon.custom_minimum_size = Vector2(TOP_BAR_ICON_PX, TOP_BAR_ICON_PX)


static func style_screen_header_close_button(button: Button) -> void:
	if button == null:
		return
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.z_index = 20
	button.focus_mode = Control.FOCUS_NONE
	apply_top_bar_tile_styles(button)
	ensure_top_bar_icon(button, CLOSE_ICON_TEX)
	apply_square_top_bar_button(button)
	button.set_meta("_overlay_close_layout_mode", "screen_header")
	_place_overlay_close_for_screen_header(button)
	_register_overlay_close_layout(button)


static func _place_overlay_close_for_screen_header(button: Button) -> void:
	if button == null or not is_instance_valid(button):
		return
	if button.get_parent() is HBoxContainer:
		return
	var title_top := SafeInsets.padded_top(GameConstants.SCREEN_HEADER_TOP)
	var title_h := GameConstants.SCREEN_HEADER_HEIGHT
	var size := float(GameConstants.HUD_BUTTON_WIDTH)
	var top := title_top + (title_h - size) * 0.5
	var left := float(GameConstants.HUD_SIDE_MARGIN) + SafeInsets.left()
	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	button.offset_left = left
	button.offset_top = top
	button.offset_right = left + size
	button.offset_bottom = top + size


static func style_top_bar_close_button(button: Button) -> void:
	if button == null:
		return
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.z_index = 20
	button.focus_mode = Control.FOCUS_NONE
	apply_top_bar_tile_styles(button)
	ensure_top_bar_icon(button, CLOSE_ICON_TEX)
	apply_square_top_bar_button(button)
	button.set_meta("_overlay_close_layout_mode", "pause")
	_place_overlay_close_like_pause(button)
	_register_overlay_close_layout(button)


static func _register_overlay_close_layout(button: Button) -> void:
	if button == null or not button.is_inside_tree():
		return
	var viewport := button.get_viewport()
	if viewport == null:
		return
	var buttons: Array = viewport.get_meta("_overlay_close_layout_buttons", [])
	if not buttons.has(button):
		buttons.append(button)
	viewport.set_meta("_overlay_close_layout_buttons", buttons)
	if not viewport.get_meta("_overlay_close_layout_hooked", false):
		viewport.set_meta("_overlay_close_layout_hooked", true)
		viewport.size_changed.connect(_relayout_overlay_close_buttons.bind(viewport))
	if not button.get_meta("_overlay_close_layout_reg", false):
		button.set_meta("_overlay_close_layout_reg", true)
		button.tree_exiting.connect(_unregister_overlay_close_layout.bind(viewport, button), CONNECT_ONE_SHOT)


static func _relayout_overlay_close_buttons(viewport: Viewport) -> void:
	if not is_instance_valid(viewport):
		return
	var buttons: Array = viewport.get_meta("_overlay_close_layout_buttons", [])
	var kept: Array = []
	for item in buttons:
		if not is_instance_valid(item):
			continue
		kept.append(item)
		if item is Button:
			if str(item.get_meta("_overlay_close_layout_mode", "pause")) == "screen_header":
				_place_overlay_close_for_screen_header(item)
			else:
				_place_overlay_close_like_pause(item)
	viewport.set_meta("_overlay_close_layout_buttons", kept)


static func _unregister_overlay_close_layout(viewport: Viewport, button: Button) -> void:
	if not is_instance_valid(viewport):
		return
	var buttons: Array = viewport.get_meta("_overlay_close_layout_buttons", [])
	var kept: Array = []
	for item in buttons:
		if not is_instance_valid(item) or item == button:
			continue
		kept.append(item)
	viewport.set_meta("_overlay_close_layout_buttons", kept)


static func _place_overlay_close_like_pause(button: Button) -> void:
	if button == null or not is_instance_valid(button):
		return
	if button.get_parent() is HBoxContainer:
		return
	var viewport_w := 1080.0
	if button.is_inside_tree():
		viewport_w = button.get_viewport_rect().size.x
	var edge := float(GameConstants.HUD_TOP_BAR_EDGE_MARGIN)
	var safe := SafeInsets.viewport_margins()
	var top := SafeInsets.padded_top(edge)
	var inner := viewport_w - edge * 2.0 - safe.x - safe.z
	var fixed := (
		float(GameConstants.HUD_BUTTON_CLUSTER_WIDTH) * 2.0
		+ float(GameConstants.HUD_CENTER_LABEL_WIDTH)
	)
	var leftover := maxf(inner - fixed, 0.0)
	var left := edge + safe.x + leftover * 0.5
	var size := float(GameConstants.HUD_BUTTON_WIDTH)
	button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	button.offset_left = left
	button.offset_top = top
	button.offset_right = left + size
	button.offset_bottom = top + size


static func apply_nav_button(button: Button) -> void:
	if not button:
		return
	button.focus_mode = Control.FOCUS_NONE
	button.text = ""
	button.flat = false
	button.clip_text = true
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.custom_minimum_size = GameConstants.UI_BTN_NAV_SIZE
	var slot := button.get_parent() as Control
	if slot and String(slot.name).ends_with("Slot"):
		slot.custom_minimum_size = GameConstants.UI_BTN_NAV_SIZE
	var nav_row := slot.get_parent() if slot else null
	if nav_row:
		var spacer := nav_row.get_node_or_null("MidSpacer") as Control
		if spacer:
			spacer.custom_minimum_size = Vector2(GameConstants.UI_BTN_NAV_GAP, 0.0)
	apply_top_bar_tile_styles(button)
	var name_l := String(button.name).to_lower()
	var is_next := name_l.contains("next")
	ensure_top_bar_icon(button, NEXT_ICON_TEX if is_next else PREV_ICON_TEX)
	var icon := button.get_node_or_null("IconContainer/Icon") as TextureRect
	if icon:
		var px := GameConstants.UI_BTN_NAV_ICON_PX
		icon.custom_minimum_size = Vector2(px, px - 1.0)
	nudge_button_icon_up(button, GameConstants.HUD_TOP_BAR_ICON_NUDGE)
	var icon_root := button.get_node_or_null("IconContainer") as MarginContainer
	if icon_root:
		icon_root.add_theme_constant_override(
			"margin_bottom",
			GameConstants.HUD_TOP_BAR_ICON_NUDGE * 2 + 2
		)
	refresh_button_icon_modulate(button)
	if not button.has_meta("_icon_disabled_hook"):
		button.set_meta("_icon_disabled_hook", true)
		button.draw.connect(func(): refresh_button_icon_modulate(button))


static func refresh_button_icon_modulate(button: Button) -> void:
	if not button:
		return
	var dim := GameConstants.DISABLED_ICON_MODULATE if button.disabled else Color.WHITE
	var icon_root := button.get_node_or_null("IconContainer") as CanvasItem
	if icon_root:
		icon_root.modulate = dim
	var count_icon := button.get_node_or_null("HintCountIcon") as CanvasItem
	if count_icon:
		count_icon.modulate = dim
	var count_label := button.get_node_or_null("HintCountLabel") as CanvasItem
	if count_label:
		count_label.modulate = dim


static func format_mode_label(translation_key: String, force_english: bool = false) -> String:
	var text := HudLayout._tr(translation_key, force_english)
	return format_outlined_center_text(text.replace(" ", "\n"))


static func format_outlined_center_text(body: String) -> String:
	return "[center]%s[/center]" % body


static func apply_square_top_bar_button(button: Button) -> void:
	if not button:
		return
	button.focus_mode = Control.FOCUS_NONE
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
	var visible_buttons := 0
	for child in cluster.get_children():
		if child is Button and (child as CanvasItem).visible:
			visible_buttons += 1
	var count := maxi(visible_buttons, 1)
	var width := (
		GameConstants.HUD_BUTTON_WIDTH * count
		+ GameConstants.HUD_BUTTON_SEPARATION * maxi(count - 1, 0)
	)
	cluster.custom_minimum_size = Vector2(width, GameConstants.HUD_BUTTON_HEIGHT)
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
	_layout_top_bar_center_label(label)
	var plain := _plain_top_bar_label_text(label.text)
	HudLayout._clear_pixel_raster(label)
	if plain.is_empty():
		label.text = ""
		return
	if HudLayout.control_uses_pixel_font(label):
		label.set_meta("_use_default_font", false)
		label.set_meta("_force_pixel_font", true)
		label.text = format_outlined_center_text(plain)
		label.add_theme_font_override("normal_font", HudLayout.pixel_font())
		label.add_theme_font_size_override("normal_font_size", fit_top_bar_two_line_font_size(plain))
		HudLayout._strip_live_pixel_outline(label)
		return
	label.set_meta("_force_pixel_font", false)
	label.set_meta("_use_default_font", true)
	HudLayout.apply_locale_font_to_control(label)
	HudLayout.apply_safe_outline(label, GameConstants.HUD_LEVEL_OUTLINE_SIZE)
	label.add_theme_font_size_override("normal_font_size", fit_top_bar_two_line_font_size(plain))


static func apply_level_label(label: RichTextLabel, prefix: String, num: int) -> void:
	if not label:
		return
	_layout_top_bar_center_label(label)
	HudLayout._clear_pixel_raster(label)
	var num_str := str(num)
	var plain := "%s\n%s" % [prefix, num_str]
	var font_size := fit_top_bar_two_line_font_size(plain)
	if HudLayout.uses_pixel_font():
		label.set_meta("_use_default_font", false)
		label.set_meta("_force_pixel_font", true)
		label.set_meta("_fixed_counter_font_size", false)
		label.text = format_outlined_center_text(plain)
		label.add_theme_font_override("normal_font", HudLayout.pixel_font())
		label.add_theme_font_size_override("normal_font_size", font_size)
		HudLayout._strip_live_pixel_outline(label)
		return
	label.set_meta("_force_pixel_font", false)
	label.set_meta("_use_default_font", true)
	HudLayout.apply_locale_font_to_control(label)
	HudLayout.apply_safe_outline(label, GameConstants.HUD_LEVEL_OUTLINE_SIZE)
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.text = "[center]%s\n[font=%s][font_size=%d]%s[/font_size][/font][/center]" % [
		prefix, HudFonts.PIXEL_FONT_PATH, font_size, num_str
	]


static func _layout_top_bar_center_label(label: RichTextLabel) -> void:
	label.bbcode_enabled = true
	label.fit_content = false
	label.scroll_active = false
	label.clip_contents = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_constant_override("line_separation", GameConstants.HUD_CENTER_LABEL_LINE_SEPARATION)
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


static func _plain_top_bar_label_text(bbcode: String) -> String:
	var plain := bbcode
	for tag in ["[center]", "[/center]"]:
		plain = plain.replace(tag, "")
	while true:
		var start := plain.find("[font=")
		if start < 0:
			break
		var end := plain.find("]", start)
		if end < 0:
			break
		plain = plain.substr(0, start) + plain.substr(end + 1)
	for tag in ["[/font]", "[font_size=", "[/font_size]"]:
		if tag == "[font_size=":
			while true:
				var s := plain.find(tag)
				if s < 0:
					break
				var e := plain.find("]", s)
				if e < 0:
					break
				plain = plain.substr(0, s) + plain.substr(e + 1)
		else:
			plain = plain.replace(tag, "")
	return plain.strip_edges()


static func fit_top_bar_level_font_size(prefix: String, num: int) -> int:
	return fit_top_bar_two_line_font_size("%s\n%d" % [prefix, num])


static func fit_top_bar_two_line_font_size(body: String) -> int:
	var base := GameConstants.HUD_LEVEL_FONT_SIZE
	var size := HudLayout.scaled_font_size(base) if not HudLayout.uses_pixel_font() else base
	var font: Font = HudLayout.pixel_font() if HudLayout.uses_pixel_font() else HudLayout.ui_font()
	if font == null:
		font = HudFonts.default_font()
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


static func prepare_timer_label(label: RichTextLabel) -> void:
	if not label:
		return
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.fit_content = false
	label.scroll_active = false
	label.clip_contents = false
	HudLayout._strip_live_pixel_outline(label)


static func set_timer_raster_text(label: RichTextLabel, plain_time: String) -> void:
	if not label:
		return
	prepare_timer_label(label)
	HudLayout._clear_pixel_raster(label)
	label.set_meta("_force_pixel_font", true)
	label.set_meta("_fixed_counter_font_size", true)
	label.set_meta("_use_default_font", false)
	if plain_time.is_empty():
		label.text = ""
		return
	if plain_time == "∞":
		label.text = format_time_counter(plain_time)
		return
	var font_size := GameConstants.HUD_COUNTER_FONT_SIZE
	label.add_theme_font_override("normal_font", HudLayout.pixel_font())
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", Color(0.96, 0.96, 0.96, 1))
	HudLayout._strip_live_pixel_outline(label)
	label.text = format_time_counter(plain_time)


static func prepare_counter_label(label: RichTextLabel) -> void:
	if not label:
		return
	label.set_meta("_use_default_font", true)
	HudLayout.apply_locale_font_to_control(label)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.fit_content = false
	label.scroll_active = false
	label.clip_contents = false
	label.add_theme_font_size_override(
		"normal_font_size", HudLayout.scaled_font_size(GameConstants.HUD_COUNTER_FONT_SIZE)
	)
	HudLayout.apply_safe_outline(label, 6)
	label.add_theme_color_override("default_color", Color(0.96, 0.96, 0.96, 1))


static func format_icon_ratio_counter(
	icon_path: String,
	current: int,
	required: int,
	accent: Color = Color.WHITE,
	caption: String = ""
) -> String:
	var icon_size := GameConstants.HUD_COUNTER_ICON_SIZE
	var num_size := HudLayout.scaled_font_size(GameConstants.HUD_COUNTER_FONT_SIZE)
	var label_size := HudLayout.scaled_font_size(GameConstants.HUD_COUNTER_LABEL_FONT_SIZE)
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
