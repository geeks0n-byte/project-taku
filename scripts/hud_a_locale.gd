class_name HudLocale
extends RefCounted
## Pixel raster overlays and locale font application extracted from HudLayout.
## Public call sites continue to use HudLayout.* wrappers.

const _PIXEL_MONO_TEXT_SCRIPT: Script = preload("res://scripts/pixel_mono_text.gd")

static var _locale_font_tree_depth: int = 0

static func apply_live_pixel_label_settings(
	label: Label,
	text: String,
	font_size: int,
	color: Color = Color.WHITE
) -> void:
	# Press Start via theme font + outline 0. Avoid LabelSettings here — it can
	# advance glyphs differently than the menu theme path (looks more spaced).
	if label == null:
		return
	_clear_pixel_raster(label)
	label.set_meta("_use_default_font", false)
	label.set_meta("_safe_pixel_label", true)
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.clip_text = false
	label.clip_contents = false
	label.text = text
	label.label_settings = null
	label.add_theme_font_override("font", HudFonts.pixel_font_clean())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("letter_spacing", 0)
	_strip_live_pixel_outline(label)

# Detaches LabelSettings from a label so theme overrides take effect cleanly.
static func clear_label_settings(label: Label) -> void:
	if label:
		label.label_settings = null

# Sets Press Start on all font slots of a RichTextLabel so bold/italic/mono
# variants also render as pixel text instead of the theme fallback.
static func apply_live_pixel_richtext(label: RichTextLabel, font_size: int) -> void:
	if label == null:
		return
	label.set_meta("_use_default_font", false)
	var font := HudFonts.pixel_font_clean()
	for font_name in ["normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"]:
		label.add_theme_font_override(font_name, font)
	for size_name in [
		"normal_font_size",
		"bold_font_size",
		"italics_font_size",
		"bold_italics_font_size",
		"mono_font_size",
	]:
		label.add_theme_font_size_override(size_name, font_size)
	_strip_live_pixel_outline(label)

static func _strip_live_pixel_outline(control: Control) -> void:
	if control == null:
		return
	# Force theme outline off — Press Start + outline_size scrambles under GL Compatibility.
	if control.has_theme_constant_override("outline_size"):
		control.remove_theme_constant_override("outline_size")
	control.add_theme_constant_override("outline_size", 0)
	control.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	control.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	control.add_theme_constant_override("shadow_offset_x", 0)
	control.add_theme_constant_override("shadow_offset_y", 0)
	if control is Label or control is Button or control is RichTextLabel:
		control.add_theme_constant_override("letter_spacing", 0)

# Returns true when a control should currently render with Press Start.
# Forced/brand controls stay pixel in every locale; _use_default_font opts out.
static func _is_live_pixel_control(control: Control) -> bool:
	if control == null:
		return false
	# Brand / forced Press Start stays pixel even outside English.
	if bool(control.get_meta("_force_pixel_font", false)) or bool(control.get_meta("_brand_title", false)):
		return true
	if bool(control.get_meta("_use_default_font", false)):
		return false
	if HudFonts._in_force_pixel_subtree(control):
		return true
	return HudFonts.uses_pixel_font()

# Returns true if a control already has a pixel-text overlay child node.
# Used to skip re-styling controls that were already processed this frame.
static func has_pixel_text_overlay(host: Control) -> bool:
	if host == null:
		return false
	return (
		host.get_node_or_null("PixelOutlineStack") != null
		or host.get_node_or_null("PixelTextRaster") != null
		or host.get_node_or_null("PixelSafeCaption") != null
		or host.get_node_or_null("PixelMonoCaption") != null
	)

# Removes all pixel-text overlay children from a control so they can be rebuilt
# fresh (e.g. after a locale change or font-size recalculation).
static func _clear_pixel_raster(host: Control) -> void:
	if host == null:
		return
	for child_name in ["PixelOutlineStack", "PixelTextRaster", "PixelSafeCaption", "PixelMonoCaption"]:
		var holder := host.get_node_or_null(child_name)
		if holder:
			host.remove_child(holder)
			holder.free()

## English Press Start centered with natural glyph advances (fills the button;
## does not inflate button minimum size the way a Caption Label can).
static func apply_pixel_mono_button(
	button: Button, text: String, font_size: int, color: Color = Color.WHITE
) -> void:
	if button == null:
		return
	_clear_pixel_raster(button)
	button.set_meta("_use_default_font", false)
	button.set_meta("_safe_pixel_label", true)
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.text = ""
	button.clip_text = false
	if button.has_theme_font_override("font"):
		button.remove_theme_font_override("font")
	if button.has_theme_font_size_override("font_size"):
		button.remove_theme_font_size_override("font_size")
	_strip_live_pixel_outline(button)
	var host := Control.new()
	host.name = "PixelMonoCaption"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.set_script(_PIXEL_MONO_TEXT_SCRIPT)
	button.add_child(host)
	if host.has_method("set_mono_text"):
		host.call("set_mono_text", text, HudFonts.pixel_font_clean(), font_size, color)
	host.queue_redraw()

# Styles a Label for pixel or scalable display.
# force_pixel keeps Press Start regardless of locale (used for digit-only badges).
# For other locales, falls back to the theme font with safe outline and body scaling.
static func apply_raster_pixel_label(
	label: Label,
	text: String,
	font_size: int,
	color: Color = Color.WHITE,
	_max_width: int = 0,
	force_pixel: bool = false
) -> void:
	if not label:
		return
	# Digits / symbols / Latin-only copy stay Press Start in ka/uk.
	var use_pixel := force_pixel or HudFonts.control_uses_pixel_font(label)
	if not use_pixel and HudFonts.is_scalable_script_locale() and HudFonts.text_uses_press_start_font(text):
		use_pixel = true
	if use_pixel:
		if force_pixel or HudFonts._in_force_pixel_subtree(label):
			label.set_meta("_force_pixel_font", true)
		apply_live_pixel_label_settings(label, text, font_size, color)
		if _max_width > 0:
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.custom_minimum_size.x = float(_max_width)
		return
	clear_label_settings(label)
	_clear_pixel_raster(label)
	label.set_meta("_use_default_font", true)
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.clip_text = false
	label.clip_contents = false
	label.add_theme_font_override("font", HudFonts.default_font())
	label.add_theme_font_size_override("font_size", HudFonts.body_font_size(font_size))
	label.add_theme_color_override("font_color", color)
	HudButtons.apply_safe_outline(label, 8)
	if _max_width > 0:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = float(_max_width)

# Styles a Button for pixel or scalable text rendering.
# In English, creates a PixelSafeCaption child Label with Press Start so the
# button's own font/outline path (which scrambles under GL Compatibility) is bypassed.
# force_pixel keeps Press Start even in ka/uk (digits/symbols-only labels).
static func apply_raster_pixel_button(
	button: Button, text: String, font_size: int, _max_width: int = 0, force_pixel: bool = false
) -> void:
	if not button:
		return
	_clear_pixel_raster(button)
	button.clip_text = false
	var use_pixel := force_pixel or HudFonts.control_uses_pixel_font(button) or bool(button.get_meta("_force_pixel_font", false))
	if not use_pixel and HudFonts.is_scalable_script_locale() and HudFonts.text_uses_press_start_font(text):
		use_pixel = true
	if use_pixel:
		# Draw Press Start on a caption label — never via Button theme font/outline.
		button.set_meta("_use_default_font", false)
		if force_pixel or HudFonts._in_force_pixel_subtree(button):
			button.set_meta("_force_pixel_font", true)
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.text = ""
		if button.has_theme_font_override("font"):
			button.remove_theme_font_override("font")
		if button.has_theme_font_size_override("font_size"):
			button.remove_theme_font_size_override("font_size")
		_strip_live_pixel_outline(button)
		var host := CenterContainer.new()
		host.name = "PixelSafeCaption"
		host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		host.offset_left = 8.0
		host.offset_top = 4.0
		host.offset_right = -8.0
		host.offset_bottom = -4.0
		var caption := Label.new()
		caption.name = "Caption"
		caption.set_meta("_safe_pixel_label", true)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		host.add_child(caption)
		button.add_child(host)
		apply_live_pixel_label_settings(caption, text, font_size, Color.WHITE)
		return
	button.set_meta("_use_default_font", true)
	button.set_meta("_force_pixel_font", false)
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.text = text
	button.add_theme_font_override("font", HudFonts.default_font())
	button.add_theme_font_size_override("font_size", HudFonts.body_font_size(font_size))
	HudButtons.apply_safe_outline(button, 8)

# Returns the appropriate UI font for the active locale.
static func _resolved_control_text(node: Node) -> String:
	var raw := ""
	if node is Label:
		raw = String((node as Label).text)
	elif node is Button:
		raw = String((node as Button).text)
		if raw.is_empty():
			raw = String(node.get_meta("_tr_key", ""))
	elif node is RichTextLabel:
		raw = String((node as RichTextLabel).text)
	raw = raw.strip_edges()
	if raw.is_empty():
		return ""
	# Include keys without "_" (TUTORIAL still used as victory copy). Underscore-only
	# matching is for dialog-key recovery where TAK/JA must not look like keys.
	if HudHeaders.is_message_key(raw):
		return String(TranslationServer.translate(raw))
	return raw

# Returns true for any node whose name marks it as a status/feedback label.
# Used by apply_locale_font_to_control to route these to apply_status_font instead.
static func is_status_label(node: Node) -> bool:
	if node == null:
		return false
	var n := String(node.name)
	return n == "StatusLabel" or n == "PlaytestStatusLabel" or n.ends_with("StatusLabel")

# Sets up a RichTextLabel to render status/feedback text at a slightly enlarged size
# (×1.2 of base) with word-wrap and auto-height. ka/uk use NON_PIXEL_LOCALE_FONT_SCALE.
# Status/error copy always uses the default font — never Press Start.
static func apply_status_font(label: RichTextLabel, base_size: int = GameConstants.HUD_STATUS_FONT_SIZE) -> void:
	if not label:
		return
	var font := HudFonts.default_font()
	label.set_meta("_force_pixel_font", false)
	label.set_meta("_use_default_font", true)
	label.add_theme_font_override("normal_font", font)
	label.add_theme_font_override("bold_font", font)
	label.add_theme_font_override("italics_font", font)
	label.add_theme_font_override("bold_italics_font", font)
	label.add_theme_font_override("mono_font", font)
	var size := int(round(float(base_size) * 1.2))
	size = int(round(float(size) * HudFonts.non_pixel_locale_scale()))
	for size_name in [
		"normal_font_size",
		"bold_font_size",
		"italics_font_size",
		"bold_italics_font_size",
		"mono_font_size",
	]:
		label.add_theme_font_size_override(size_name, size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false

# Applies the correct locale font to a single UI control, respecting all the
# special-case guards: pixel outline parts, pre-styled pixel labels, icon-only buttons,
# LabelSettings, and screen headers.
static func apply_locale_font_to_control(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not (node is Button or node is Label or node is LineEdit or node is OptionButton or node is RichTextLabel):
		return
	if bool(node.get_meta("_pixel_outline_part", false)):
		return
	if bool(node.get_meta("_safe_pixel_label", false)):
		# Already styled by apply_live_pixel_label_settings / mono caption — don't re-theme.
		return
	# Captions inside PixelSafeCaption enter the tree before _safe_pixel_label is set;
	# never re-theme them or language switches recurse / freeze.
	if node is Label:
		var parent := (node as Label).get_parent()
		if parent != null and String(parent.name) == "PixelSafeCaption":
			return
	if node is Control and (node as Control).get_node_or_null("PixelMonoCaption") != null:
		return
	# PixelSafeCaption already draws Press Start — keep it for Latin-only labels.
	# If the resolved string now needs Noto (ka/uk native letters), drop the caption
	# and fall through so language switches cannot leave a stale Press Start overlay.
	if node is Control and (node as Control).get_node_or_null("PixelSafeCaption") != null:
		if HudFonts.is_scalable_script_locale():
			var caption_display := _resolved_control_text(node)
			if caption_display.is_empty() and node is Button:
				caption_display = String(TranslationServer.translate(String(node.get_meta("_tr_key", ""))))
			if HudFonts.text_needs_scalable_font(caption_display):
				_clear_pixel_raster(node as Control)
				node.set_meta("_safe_pixel_label", false)
			else:
				return
		else:
			return
	# Status before forced-pixel meta — playtest errors follow locale font rules.
	if is_status_label(node) and node is RichTextLabel:
		apply_status_font(node as RichTextLabel)
		return
	if node.get_meta("_notification_badge", false):
		return
	# ka/uk: Noto only for native letters; digits/symbols/Latin → Press Start.
	# Resolve i18n keys before sniffing — scene .text is often "UI_PLAY" while
	# the drawn string is Georgian/Ukrainian. Never sticky-force Press Start from
	# a Latin key or that lock survives and draws missing glyphs (□).
	# Runs before _force_pixel_font so a bad sticky lock can be cleared.
	if HudFonts.is_scalable_script_locale() and not bool(node.get_meta("_brand_title", false)):
		var display_text := _resolved_control_text(node)
		if node is RichTextLabel:
			display_text = HudFonts.strip_font_bbcode(display_text)
		if HudFonts.text_needs_scalable_font(display_text):
			node.set_meta("_force_pixel_font", false)
			node.set_meta("_use_default_font", true)
			if node is RichTextLabel and not display_text.is_empty():
				var rtl := node as RichTextLabel
				# How-To-Play / icon pages: authored [img] + page [font_size]. Injecting
				# Press Start runs used to nest font_size tags and freeze on ka↔uk.
				if display_text.find("[img") >= 0:
					if rtl.text != display_text:
						rtl.text = display_text
				else:
					var sz := rtl.get_theme_font_size("normal_font_size")
					if sz <= 0:
						sz = GameConstants.UI_BODY_FONT_SIZE
					# Wrap from already-stripped copy — never re-wrap raw rtl.text.
					var wrapped := HudFonts.wrap_press_start_runs_bbcode(display_text, sz)
					if wrapped != rtl.text:
						rtl.text = wrapped
		elif not display_text.is_empty() and HudFonts.text_uses_press_start_font(display_text):
			node.set_meta("_use_default_font", false)
			# Buttons: Press Start via caption (theme font scrambles under GL Compatibility).
			if node is Button:
				var btn := node as Button
				var sz := btn.get_theme_font_size("font_size")
				if sz <= 0:
					sz = GameConstants.UI_BTN_PANEL_FONT
				apply_raster_pixel_button(btn, display_text, sz)
				return
			if node is Label:
				var label := node as Label
				var sz := label.get_theme_font_size("font_size")
				if sz <= 0:
					sz = GameConstants.UI_BODY_FONT_SIZE
				apply_live_pixel_label_settings(label, display_text, sz, Color.WHITE)
				return
			_apply_forced_pixel_font(node)
			_strip_live_pixel_outline(node as Control)
			return
	if node.get_meta("_force_pixel_font", false):
		_apply_forced_pixel_font(node)
		_strip_live_pixel_outline(node as Control)
		return
	# Screen headers are styled only via apply_screen_header_style. Calling it
	# from here re-enters through apply_raster_pixel_label and overflows.
	if node.get_meta("_screen_header", false):
		if node is Control and _is_live_pixel_control(node as Control):
			_strip_live_pixel_outline(node as Control)
		return
	# Icon-only top-bar buttons: locale font metrics shift the TextureRect.
	if _is_icon_only_button(node):
		return
	# LabelSettings already has a font — don't replace it (reshape can fd-null).
	if node is Label and (node as Label).label_settings != null:
		if _is_live_pixel_control(node as Control):
			_strip_live_pixel_outline(node as Control)
		return
	var use_default := bool(node.get_meta("_use_default_font", false))
	# English-only editor chrome: Press Start even when the game language is not EN.
	if not use_default and HudFonts._in_force_pixel_subtree(node):
		node.set_meta("_force_pixel_font", true)
		node.set_meta("_use_default_font", false)
		_apply_forced_pixel_font(node)
		_strip_live_pixel_outline(node as Control)
		return
	var font := HudFonts.default_font() if use_default else HudFonts.ui_font()
	if font == null:
		font = HudFonts.default_font()
	if font == null:
		return
	if node is Button or node is Label or node is LineEdit or node is OptionButton:
		node.add_theme_font_override("font", font)
		if node is Control and _is_live_pixel_control(node as Control):
			_strip_live_pixel_outline(node as Control)
	elif node is RichTextLabel:
		node.add_theme_font_override("normal_font", font)
		node.add_theme_font_override("bold_font", font)
		node.add_theme_font_override("italics_font", font)
		node.add_theme_font_override("bold_italics_font", font)
		node.add_theme_font_override("mono_font", font)
		if node is Control and _is_live_pixel_control(node as Control):
			_strip_live_pixel_outline(node as Control)

# True for top-bar buttons that render only an icon (no text label).
# These must be skipped during locale font walks because applying a font shifts the
# IconContainer's layout and misaligns the texture.
static func _is_icon_only_button(node: Node) -> bool:
	if not node is Button:
		return false
	var button := node as Button
	return button.get_node_or_null("IconContainer") != null and button.text.is_empty()

# Applies Press Start to a node that has _force_pixel_font=true, regardless of locale.
# Also sets a fixed counter font size when the node is marked as a HUD counter.
static func _apply_forced_pixel_font(node: Node) -> void:
	var font := HudFonts.pixel_font()
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
		if bool(node.get_meta("_fixed_counter_font_size", false)):
			node.add_theme_font_size_override(
				"normal_font_size", GameConstants.HUD_COUNTER_FONT_SIZE
			)

# Recursively walks a subtree and applies the correct locale font to every
# eligible control. Skips pixel-outline overlay parts to avoid infinite recursion.

## True while apply_locale_fonts_to_tree is walking the tree (re-entrancy guard).
static func is_applying_locale_fonts() -> bool:
	return _locale_font_tree_depth > 0

## Walks a subtree and applies locale-correct fonts; depth-capped to avoid hangs.
static func apply_locale_fonts_to_tree(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	# Re-entrancy / depth guard — node_added during raster rebuilds must not
	# stack another full tree walk (ka↔uk used to hang here).
	if _locale_font_tree_depth > 48:
		return
	_locale_font_tree_depth += 1
	_apply_locale_fonts_to_tree_inner(root)
	_locale_font_tree_depth -= 1

static func _apply_locale_fonts_to_tree_inner(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	if bool(root.get_meta("_pixel_outline_part", false)):
		return
	apply_locale_font_to_control(root)
	# Scenes ship Press Start + outline_size; that combo scrambles under GL Compatibility.
	if root is Control and _is_live_pixel_control(root as Control):
		if (
			root is Label
			or root is Button
			or root is RichTextLabel
			or root is LineEdit
			or root is OptionButton
		):
			_strip_live_pixel_outline(root as Control)
	for child in root.get_children():
		if is_instance_valid(child):
			_apply_locale_fonts_to_tree_inner(child)

# Applies the locale-correct body font to a plain Label.
static func apply_body_label(label: Label, base_size: int = GameConstants.UI_BODY_FONT_SIZE) -> void:
	if not label:
		return
	label.set_meta("_use_default_font", true)
	apply_locale_font_to_control(label)
	label.add_theme_font_size_override("font_size", HudFonts.body_font_size(base_size))

# Same as apply_body_label but for RichTextLabel, setting the normal_font_size slot.
static func apply_body_richtext(
	label: RichTextLabel, base_size: int = GameConstants.UI_BODY_FONT_SIZE
) -> void:
	if not label:
		return
	label.set_meta("_use_default_font", true)
	apply_locale_font_to_control(label)
	label.add_theme_font_size_override("normal_font_size", HudFonts.body_font_size(base_size))

# Adds or updates the amber/white rounded overlay that indicates a toggled-on
# or tutorial-highlighted button.
