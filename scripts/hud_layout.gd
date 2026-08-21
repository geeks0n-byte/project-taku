# Static utility library — no scene node needed. All layout and font helpers
# live here so every HUD scene can share the same logic without duplicating code.
class_name HudLayout
extends RefCounted

# Shared tile texture for all top-bar buttons (close, nav, square action buttons).
const _TOP_BAR_TILE_TEX := preload("res://resources/buttons/button_tile_gray_dark.svg")
# Icon textures used by the close button and the HTP prev/next nav buttons.
const _CLOSE_ICON_TEX := preload("res://resources/icons/icon_close.svg")
const _PREV_ICON_TEX := preload("res://resources/icons/icon_prev.svg")
const _NEXT_ICON_TEX := preload("res://resources/icons/icon_next.svg")
# Default icon render size in pixels for square top-bar buttons.
const _TOP_BAR_ICON_PX := 83.0

# Stretches a control to the full horizontal width with symmetric side margins,
# anchored to the top of its parent at the given pixel offset.
static func position_top_wide(control: Control, top: float, height: float, margin: float = GameConstants.HUD_SIDE_MARGIN) -> void:
	if not control:
		return
	control.set_anchors_preset(Control.PRESET_TOP_WIDE)
	control.offset_left = margin
	control.offset_right = -margin
	control.offset_top = top
	control.offset_bottom = top + height

# Places the in-game status label (error / success messages) directly below the board
# with the standard gap defined in GameConstants.
static func position_status_below_board(status: Control, board_y: float, board_height: float) -> void:
	position_top_wide(status, board_y + board_height + GameConstants.HUD_STATUS_GAP, GameConstants.HUD_STATUS_MIN_HEIGHT)

# Pins the editor's status bar at the bottom of its parent and shrinks the control
# panel's bottom edge flush so there's no gap between them.
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

# Public entry point for counter row layout. Actual position offsets are
# managed by the HUD scene tree; this call handles only the internal alignment.
static func position_counter_row(counter_row: Control) -> void:
	# Geometry is owned by the HUD scene tree.
	align_counter_row(counter_row)

# Centres the HBoxContainer and makes all visible child slots share equal width,
# so the counter row re-balances when slots are hidden/shown.
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

# Cached fallback font reference so we don't call ThemeDB.fallback_font on every frame.
static var _screen_header_font_default: Font

# Returns the font to use for screen headers. Press Start is used in English;
# all other locales fall back to the theme's default scalable font.
static func screen_header_font(force_pixel: bool = false) -> Font:
	if force_pixel or uses_pixel_font():
		return pixel_font()
	if _screen_header_font_default == null:
		_screen_header_font_default = ThemeDB.fallback_font
	return _screen_header_font_default

# Returns true when text looks like a raw i18n key (all-caps ASCII + digits + underscores).
# Used to distinguish un-translated keys from already-translated display strings.
static func _is_message_key(text: String) -> bool:
	if text.is_empty():
		return false
	# Message ids are ASCII tokens like UI_OPTIONS / PAUSED / HTP_TITLE.
	var first := text.unicode_at(0)
	if first < 65 or first > 90:
		return false
	for i in text.length():
		var c := text.unicode_at(i)
		var is_az := c >= 65 and c <= 90
		var is_digit := c >= 48 and c <= 57
		if not (is_az or is_digit or c == 95):
			return false
	return true

# Reverse-looks up the original i18n key from an already-translated string.
# Necessary when a scene was saved with tr() output baked into .text,
# making it impossible to retranslate on locale change without this recovery.
static func _recover_header_key_from_translated(text: String) -> String:
	if text.is_empty() or _is_message_key(text):
		return text
	# Recover after a bad bake of tr() into .text (e.g. Ukrainian stuck forever).
	for key in [
		"UI_OPTIONS", "UI_CREDITS", "UI_SELECT_LEVEL", "PAUSED",
		"HTP_TITLE", "HTP_EXAMPLES_TITLE", "HTP_PURPLE_TITLE", "HTP_LINKS_TITLE", "HTP_STARS_TITLE",
		"TUTORIAL", "COMPLETED", "ED_VICTORY_SOLVABLE",
	]:
		if text == key:
			return key
		for locale in TranslationServer.get_loaded_locales():
			var translation := TranslationServer.get_translation_object(locale)
			if translation == null:
				continue
			if String(translation.get_message(key)) == text:
				return key
	return ""

# Determines the stable i18n key for a header label, checking the stored meta
# first, then the raw .text, then attempting recovery from a translated string.
# Result is cached in the "_tr_key" meta so the next call is cheap.
static func _header_translation_key(label: Label) -> String:
	if label == null:
		return ""
	var stored := String(label.get_meta("_tr_key", ""))
	if not stored.is_empty() and _is_message_key(stored):
		return stored
	var raw := label.text.strip_edges()
	if _is_message_key(raw):
		label.set_meta("_tr_key", raw)
		return raw
	var recovered := _recover_header_key_from_translated(raw)
	if not recovered.is_empty():
		label.set_meta("_tr_key", recovered)
		return recovered
	if not stored.is_empty():
		return stored
	return raw

# Resets a label's translation binding to a known key, clearing any previously
# baked translated text so auto-translate can re-evaluate it from scratch.
static func _bind_header_translation_key(label: Label, key: String) -> void:
	if label == null or key.is_empty():
		return
	_clear_pixel_raster(label)
	label.set_meta("_tr_key", key)
	# Force auto-translate to rebind off any previously baked locale string.
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = key
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_ALWAYS
	label.notification(Node.NOTIFICATION_TRANSLATION_CHANGED)

# Applies the canonical screen-header look: centred, correct font, outline, colour.
# Handles both the pixel-font (English) and scalable-font (other locales) paths,
# and ensures the translation key stays in .text rather than a baked string.
static func apply_screen_header_style(label: Label) -> void:
	if not label:
		return
	label.set_meta("_screen_header", true)
	var force_pixel := bool(label.get_meta("_brand_title", false))
	var header_size: int = int(label.get_meta(
		"_screen_header_font_size",
		GameConstants.SCREEN_HEADER_FONT_SIZE
	))
	var outline_size: int = int(label.get_meta(
		"_screen_header_outline",
		GameConstants.SCREEN_HEADER_OUTLINE
	))
	# Keep the translation key in .text — never bake tr() output (that froze
	# Ukrainian "НАЛАШТУВАННЯ" across every language and broke Press Start glyphs).
	var key := _header_translation_key(label)
	if not key.is_empty() and _is_message_key(key):
		_bind_header_translation_key(label, key)
	elif not key.is_empty():
		_clear_pixel_raster(label)
		label.text = key
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = false
	label.clip_contents = false
	label.add_theme_color_override("font_color", GameConstants.SCREEN_HEADER_COLOR)
	if force_pixel or needs_pixel_text_raster():
		label.set_meta("_use_default_font", false)
		label.add_theme_font_override("font", pixel_font_clean())
		label.add_theme_font_size_override("font_size", header_size)
		_strip_live_pixel_outline(label)
		return
	label.set_meta("_use_default_font", true)
	label.add_theme_font_override("font", screen_header_font(false))
	label.add_theme_font_size_override("font_size", body_font_size(header_size))
	apply_safe_outline(label, outline_size)

# Styles the victory/completion header label. Reduces font size on mobile to prevent
# overflow, and uses the pixel font path when the locale is English.
static func apply_end_screen_header_style(label: Label, base_size: int = 48) -> void:
	if not label:
		return
	var size := base_size
	if _is_mobile_ui():
		size = 40
	label.set_meta("_screen_header", true)
	label.set_meta("_screen_header_font_size", size)
	label.set_meta("_screen_header_outline", 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = false
	label.clip_contents = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if uses_pixel_font():
		label.set_meta("_brand_title", false)
		apply_live_pixel_label_settings(
			label, label.text, size, GameConstants.SCREEN_HEADER_COLOR
		)
		return
	label.set_meta("_brand_title", false)
	label.set_meta("_use_default_font", true)
	clear_label_settings(label)
	_clear_pixel_raster(label)
	label.add_theme_font_override("font", ThemeDB.fallback_font)
	label.add_theme_font_size_override("font_size", body_font_size(size))
	label.add_theme_color_override("font_color", GameConstants.SCREEN_HEADER_COLOR)
	apply_safe_outline(label, 8)

# Finds the named header label inside a how-to-play host container without crashing
# if the node doesn't exist (returns null instead).
static func ensure_how_to_play_page_header(host: Control) -> Label:
	if host == null:
		return null
	return host.get_node_or_null("HowToPlayPageHeader") as Label

## Size the rules panel to its text. PREV/NEXT stay at a fixed Y locked from the
## first layout after the lock is cleared (callers clear on open at page 0).
static func clear_how_to_play_nav_lock(host: Control) -> void:
	if host and host.has_meta("_htp_nav_top"):
		host.remove_meta("_htp_nav_top")

static func layout_how_to_play_stack(
	host: Control,
	panel: Control,
	rules: RichTextLabel,
	nav: Control,
	update_nav_lock: bool = false
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
	var natural_panel_h := clampf(content_h, GameConstants.HTP_PANEL_MIN_HEIGHT, max_panel_h)

	# Capture nav Y from this page (typically page 0) once; later pages keep it.
	if update_nav_lock or not host.has_meta("_htp_nav_top"):
		host.set_meta(
			"_htp_nav_top",
			GameConstants.HTP_PANEL_TOP + natural_panel_h + GameConstants.SCREEN_NAV_GAP
		)
	var nav_top: float = float(host.get_meta("_htp_nav_top"))
	var max_under_nav := maxf(
		GameConstants.HTP_PANEL_MIN_HEIGHT,
		nav_top - GameConstants.HTP_PANEL_TOP - GameConstants.SCREEN_NAV_GAP
	)
	var panel_h := clampf(content_h, GameConstants.HTP_PANEL_MIN_HEIGHT, minf(max_panel_h, max_under_nav))
	panel.offset_bottom = GameConstants.HTP_PANEL_TOP + panel_h
	if rules:
		var needs_scroll := content_h > panel_h + 1.0
		rules.scroll_active = needs_scroll
		rules.fit_content = not needs_scroll

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

# Applies the 9-slice gray-dark tile texture to all visual states of a button,
# with brightness modulation for hover, pressed, and disabled states.
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

# Creates or reuses an IconContainer/Icon child hierarchy inside a button so
# the texture is rendered at a fixed pixel size independent of the button's font metrics.
# Using a child node instead of button.icon avoids theme-driven scaling surprises.
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

# Full setup for a close/back button in the top bar: stops mouse events, puts it
# on top of other controls (z_index 20), and gives it tile style + close icon.
static func style_top_bar_close_button(button: Button) -> void:
	if button == null:
		return
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.z_index = 20
	button.focus_mode = Control.FOCUS_NONE
	apply_top_bar_tile_styles(button)
	ensure_top_bar_icon(button, _CLOSE_ICON_TEX)
	apply_square_top_bar_button(button)

# Returns the English translation of an i18n key regardless of the active locale.
# Used by the editor preview and forced-English paths to get consistent layout metrics.
static func english(key: String) -> String:
	if key.is_empty():
		return ""
	var translation := TranslationServer.get_translation_object("en")
	if translation:
		var msg := String(translation.get_message(StringName(key)))
		if not msg.is_empty():
			return msg
	return key

# Translates a status message string, supporting multi-line input and pipe-delimited
# format strings (e.g. "KEY|arg1|arg2"). Applies sentence-break formatting after translation.
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

# Handles a single pipe-delimited token: splits off the key, translates it,
# then substitutes any typed arguments (int or string) into %d/%s placeholders.
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

# Inserts a newline after sentence-ending punctuation followed by a space and a
# non-numeric character. Prevents two-sentence status messages from running together
# on a single line without breaking mid-number (e.g. "1.5 seconds").
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

# Wraps a status message in BBCode center tags after translation.
static func format_centered_status(msg: String, force_english: bool = false) -> String:
	return "[center]" + translate_status_text(msg, force_english) + "[/center]"

# Returns the composite font scale for the current locale and font type.
# Georgian is slightly reduced (glyphs read large). Press Start is not scaled.
static func font_scale() -> float:
	var scale := 1.0
	if not uses_pixel_font():
		scale = GameConstants.DEFAULT_FONT_SCALE
	var locale := TranslationServer.get_locale().substr(0, 2)
	if locale == "ka":
		scale *= GameConstants.GEORGIAN_FONT_SCALE
	return scale

# Scales a font size by font_scale() and snaps to the nearest valid Press Start grid size.
static func scaled_font_size(base: int) -> int:
	return snap_pixel_font_size(int(round(float(base) * font_scale())))

# Scales a font size for the non-pixel (scalable) font path.
static func body_font_size(base: int) -> int:
	var scale := GameConstants.DEFAULT_FONT_SCALE
	var locale := TranslationServer.get_locale().substr(0, 2)
	if locale == "ka":
		scale *= GameConstants.GEORGIAN_FONT_SCALE
	return int(round(float(base) * scale))

## Press Start is an 8px grid font — odd sizes create uneven gaps between letters.
static func snap_pixel_font_size(size: int) -> int:
	if size <= 0:
		return size
	if not uses_pixel_font():
		return size
	return maxi(8, int(round(float(size) / 8.0)) * 8)

const PIXEL_FONT_PATH := "res://resources/fonts/PressStart2P-vaV7.ttf"
## Canonical English pixel font (imported FontFile). Do not rebuild from bytes.
const PIXEL_FONT: Font = preload("res://resources/fonts/PressStart2P-vaV7.ttf")
const _PIXEL_MONO_TEXT_SCRIPT: Script = preload("res://scripts/pixel_mono_text.gd")
static var _pixel_font_with_fallback: Font

# Press Start 2P is only used in English; all other locales use the fallback font.
static func uses_pixel_font() -> bool:
	return TranslationServer.get_locale().substr(0, 2) == "en"

# Loads the Press Start font, preferring the preloaded constant to avoid disk reads.
static func _load_press_start_font() -> Font:
	if PIXEL_FONT != null:
		return PIXEL_FONT
	if ResourceLoader.exists(PIXEL_FONT_PATH):
		var loaded := load(PIXEL_FONT_PATH) as Font
		if loaded != null:
			return loaded
	return ThemeDB.fallback_font

# Returns the Press Start font, falling back to the theme font if somehow missing.
# Result is cached after first call to avoid repeated ResourceLoader hits.
static func pixel_font() -> Font:
	if _pixel_font_with_fallback == null:
		_pixel_font_with_fallback = _load_press_start_font()
	return _pixel_font_with_fallback if _pixel_font_with_fallback else ThemeDB.fallback_font

static func pixel_font_clean() -> Font:
	# Same imported face as pixel_font(). Isolation is outline_size == 0 only —
	# runtime FontFile copies and the extra safe.ttf import produced fd-null crashes.
	return pixel_font()

# True when the current locale uses Press Start; callers use this to decide
# whether to create a pixel caption overlay instead of using the theme font.
static func needs_pixel_text_raster() -> bool:
	return uses_pixel_font()

# No-op kept for call-site compatibility. The imported FontFile must remain alive
# in memory; clearing the cached reference caused fd-null crashes in older builds.
static func clear_pixel_text_cache() -> void:
	# Keep the imported FontFile reference alive; clearing it caused fd-null.
	pass

# Applies Press Start directly to a Label via theme overrides (not LabelSettings).
# LabelSettings advances glyphs differently from the menu theme path and produces
# inconsistent spacing, so it is intentionally avoided here.
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
	label.add_theme_font_override("font", pixel_font_clean())
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
	var font := pixel_font_clean()
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
	return uses_pixel_font()

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
		host.call("set_mono_text", text, pixel_font_clean(), font_size, color)
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
	# Digits / forced badges stay Press Start in every language.
	if force_pixel or uses_pixel_font():
		if force_pixel:
			label.set_meta("_force_pixel_font", true)
		apply_live_pixel_label_settings(label, text, font_size, color)
		return
	clear_label_settings(label)
	_clear_pixel_raster(label)
	label.set_meta("_use_default_font", true)
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.clip_text = false
	label.clip_contents = false
	label.add_theme_font_override("font", ThemeDB.fallback_font)
	label.add_theme_font_size_override("font_size", body_font_size(font_size))
	label.add_theme_color_override("font_color", color)
	apply_safe_outline(label, 8)

# Styles a Button for pixel or scalable text rendering.
# In English, creates a PixelSafeCaption child Label with Press Start so the
# button's own font/outline path (which scrambles under GL Compatibility) is bypassed.
static func apply_raster_pixel_button(
	button: Button, text: String, font_size: int, _max_width: int = 0
) -> void:
	if not button:
		return
	_clear_pixel_raster(button)
	button.clip_text = false
	if uses_pixel_font():
		# Draw Press Start on a caption label — never via Button theme font/outline.
		button.set_meta("_use_default_font", false)
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
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		host.add_child(caption)
		button.add_child(host)
		apply_live_pixel_label_settings(caption, text, font_size, Color.WHITE)
		return
	button.set_meta("_use_default_font", true)
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.text = text
	button.add_theme_font_override("font", ThemeDB.fallback_font)
	button.add_theme_font_size_override("font_size", body_font_size(font_size))
	apply_safe_outline(button, 8)

# Returns the appropriate UI font for the active locale.
static func ui_font() -> Font:
	return pixel_font() if uses_pixel_font() else ThemeDB.fallback_font

# Returns true for any node whose name marks it as a status/feedback label.
# Used by apply_locale_font_to_control to route these to apply_status_font instead.
static func is_status_label(node: Node) -> bool:
	if node == null:
		return false
	var n := String(node.name)
	return n == "StatusLabel" or n == "PlaytestStatusLabel" or n.ends_with("StatusLabel")

# Sets up a RichTextLabel to render status/feedback text at a slightly enlarged size
# (×1.2 of base) with word-wrap and auto-height. Georgian uses GEORGIAN_FONT_SCALE.
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
		size = int(round(float(size) * GameConstants.GEORGIAN_FONT_SCALE))
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

# Applies the correct locale font to a single UI control, respecting all the
# special-case guards: pixel outline parts, pre-styled pixel labels, icon-only buttons,
# LabelSettings, screen headers, and the "=" / "×" math symbols that must stay default.
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
	if node is Control and (node as Control).get_node_or_null("PixelMonoCaption") != null:
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
	if is_status_label(node) and node is RichTextLabel:
		apply_status_font(node as RichTextLabel)
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
	if not use_default and node is Label:
		var label_text := (node as Label).text
		if label_text == "=" or label_text == "×":
			use_default = true
			node.set_meta("_use_default_font", true)
	var font := ThemeDB.fallback_font if use_default else ui_font()
	if font == null:
		font = ThemeDB.fallback_font
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
		if bool(node.get_meta("_fixed_counter_font_size", false)):
			node.add_theme_font_size_override(
				"normal_font_size", GameConstants.HUD_COUNTER_FONT_SIZE
			)

# Recursively walks a subtree and applies the correct locale font to every
# eligible control. Skips pixel-outline overlay parts to avoid infinite recursion.
static func apply_locale_fonts_to_tree(root: Node) -> void:
	if root == null:
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
		apply_locale_fonts_to_tree(child)

# Shrinks a button's font until the wrapped text fits within the button's minimum
# size minus padding. Useful for long translated strings that otherwise overflow.
static func fit_text_button(button: Button, base_font_size: int = 36, min_font_size: int = 18) -> void:
	if not button:
		return
	if _is_icon_only_button(button):
		return
	button.clip_text = false
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	if display.is_empty():
		return
	var size := scaled_font_size(base_font_size)
	var min_size := scaled_font_size(min_font_size)
	var step := 8 if uses_pixel_font() else 2
	while size > min_size:
		var measured := font.get_multiline_string_size(display, HORIZONTAL_ALIGNMENT_CENTER, target_w, size)
		if measured.x <= target_w + 2.0 and measured.y <= target_h + 2.0:
			break
		size = maxi(min_size, size - step)
	size = snap_pixel_font_size(size) if uses_pixel_font() else size
	_clear_pixel_raster(button)
	apply_locale_font_to_control(button)
	button.add_theme_font_size_override("font_size", size)
	var base_outline := int(button.get_theme_constant("outline_size"))
	if base_outline <= 0:
		base_outline = GameConstants.MENU_TEXT_OUTLINE
	apply_safe_outline(button, base_outline)

# Same as fit_text_button but for single-line buttons only (AUTOWRAP_OFF).
# Shrinks font until the text width fits, ignoring height.
static func fit_text_button_single_line(button: Button, base_font_size: int = 36, min_font_size: int = 18) -> void:
	if not button:
		return
	if _is_icon_only_button(button):
		return
	button.clip_text = false
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	var font: Font = (
		ThemeDB.fallback_font if button.get_meta("_use_default_font", false) else ui_font()
	)
	if font == null:
		font = ThemeDB.fallback_font
	var target_w := maxf(40.0, button.custom_minimum_size.x - 36.0)
	var display := button.text
	if button.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED:
		display = String(TranslationServer.translate(button.text))
	if display.is_empty():
		return
	var size := scaled_font_size(base_font_size)
	var min_size := scaled_font_size(min_font_size)
	var step := 8 if uses_pixel_font() else 2
	while size > min_size:
		var measured := font.get_string_size(display, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		if measured.x <= target_w + 2.0:
			break
		size = maxi(min_size, size - step)
	size = snap_pixel_font_size(size) if uses_pixel_font() else size
	_clear_pixel_raster(button)
	apply_locale_font_to_control(button)
	button.add_theme_font_size_override("font_size", size)
	var base_outline := int(button.get_theme_constant("outline_size"))
	if base_outline <= 0:
		base_outline = GameConstants.MENU_TEXT_OUTLINE
	apply_safe_outline(button, base_outline)

# Returns true when running on a physical mobile device or the Android/iOS simulator.
# Used to select a slightly smaller default font size on small screens.
static func _is_mobile_ui() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		return true
	var os_name := OS.get_name()
	return os_name == "Android" or os_name == "iOS"

# Returns true when the current locale should use the scalable theme font instead of Press Start.
static func prefer_default_font() -> bool:
	return not uses_pixel_font()

# Applies a text outline safely: strips it for Press Start controls (outline_size
# scrambles glyphs under GL Compatibility), applies a black outline for all others.
static func apply_safe_outline(control: Control, base_outline: int = GameConstants.MENU_TEXT_OUTLINE) -> void:
	if not control:
		return
	# Only strip live outlines from Press Start itself. Default-font English UI
	# (counters, HTP body, etc.) can keep theme outlines safely.
	if _is_live_pixel_control(control):
		# Press Start + theme outlines scramble glyphs under GL Compatibility.
		_strip_live_pixel_outline(control)
		return
	control.add_theme_constant_override("shadow_offset_x", 0)
	control.add_theme_constant_override("shadow_offset_y", 0)
	var outline := clampi(base_outline, 0, maxi(1, base_outline))
	control.add_theme_color_override("font_outline_color", Color.BLACK)
	control.add_theme_constant_override("outline_size", outline)

# Sets the standard primary-button minimum size and fits its text font.
static func apply_primary_button(button: Button) -> void:
	if not button:
		return
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = GameConstants.UI_BTN_PRIMARY_SIZE
	fit_text_button(
		button, GameConstants.UI_BTN_PRIMARY_FONT, GameConstants.UI_BTN_PRIMARY_FONT_MIN
	)

# Sets the standard secondary-button minimum size and fits its text font.
static func apply_secondary_button(button: Button) -> void:
	if not button:
		return
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = GameConstants.UI_BTN_SECONDARY_SIZE
	fit_text_button(
		button, GameConstants.UI_BTN_SECONDARY_FONT, GameConstants.UI_BTN_SECONDARY_FONT_MIN
	)

# Sizes and styles a dialog confirm/cancel button (Yes/No), translating its text
# and routing through apply_raster_pixel_button for font consistency.
static func apply_dialog_button(button: Button) -> void:
	if not button:
		return
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = GameConstants.UI_BTN_DIALOG_SIZE
	var display := button.text
	if not display.is_empty() and _is_message_key(display):
		display = String(TranslationServer.translate(display))
	elif (
		button.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED
		and not display.is_empty()
	):
		display = String(TranslationServer.translate(display))
	apply_raster_pixel_button(button, display, GameConstants.UI_BTN_DIALOG_FONT)

# Styles a PREV/NEXT navigation button: tile background, directional icon chosen
# by whether the button name contains "next", and an extra +1 px icon lift.
static func apply_nav_button(button: Button) -> void:
	if not button:
		return
	button.focus_mode = Control.FOCUS_NONE
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
			GameConstants.HUD_TOP_BAR_ICON_NUDGE * 2 + 2
		)
	refresh_button_icon_modulate(button)
	if not button.has_meta("_icon_disabled_hook"):
		button.set_meta("_icon_disabled_hook", true)
		button.draw.connect(func(): refresh_button_icon_modulate(button))

# Styles a "panel" button (victory screen: Next Level, Play Again, Main Menu).
# Sizes to UI_BTN_PANEL_SIZE and fits any caption Labels inside the button.
static func apply_panel_button(button: Button) -> void:
	if not button:
		return
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = GameConstants.UI_BTN_PANEL_SIZE
	button.set_meta("_use_default_font", not uses_pixel_font())
	if uses_pixel_font():
		_strip_live_pixel_outline(button)
	else:
		apply_safe_outline(button, 8)
	fit_text_button(button, GameConstants.UI_BTN_PANEL_FONT, GameConstants.UI_BTN_PANEL_FONT_MIN)
	_fit_panel_button_captions(button)

## Applies the gray-dark tile texture style to a button.
## Height is fixed to [param height]; width auto-fits the text label.
## Font is set to [param font_size] (scaled). Used for consent and similar overlay buttons.
static func apply_tile_button(
	button: Button,
	texture: Texture2D,
	font_size: int = 52,
	height: float = 118.0
) -> void:
	if not button:
		return
	button.focus_mode = Control.FOCUS_NONE
	button.flat = false
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.clip_text = false
	button.custom_minimum_size = Vector2(0.0, height)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	for style_name in ["normal", "pressed", "hover", "disabled", "focus"]:
		var box := StyleBoxTexture.new()
		box.texture = texture
		box.texture_margin_left = 16.0
		box.texture_margin_top = 16.0
		box.texture_margin_right = 16.0
		box.texture_margin_bottom = 16.0
		box.content_margin_left = 48.0
		box.content_margin_top = 8.0
		box.content_margin_right = 48.0
		box.content_margin_bottom = 8.0
		match style_name:
			"hover":    box.modulate_color = Color(1.2, 1.2, 1.2, 1.0)
			"pressed":  box.modulate_color = Color(0.8, 0.8, 0.8, 1.0)
			"disabled": box.modulate_color = Color(0.55, 0.55, 0.55, 1.0)
		button.add_theme_stylebox_override(style_name, box)
	apply_locale_font_to_control(button)
	button.add_theme_font_size_override("font_size", scaled_font_size(font_size))
	apply_safe_outline(button, GameConstants.MENU_TEXT_OUTLINE)

# Iterates all Label descendants of a panel button and shrinks each one's font
# until the text fits within the button's minimum width. Skips caption overlays
# and labels that already have their own LabelSettings or pixel styling.
static func _fit_panel_button_captions(button: Button) -> void:
	if not button:
		return
	for node in button.find_children("*", "Label", true, false):
		var label := node as Label
		if label == null:
			continue
		if label.name == "Caption" or label.name == "PixelSafeCaption":
			continue
		if label.get_parent() != null and String(label.get_parent().name) == "PixelSafeCaption":
			continue
		if has_pixel_text_overlay(label):
			continue
		if label.label_settings != null or bool(label.get_meta("_safe_pixel_label", false)):
			continue
		_fit_caption_label(
			label,
			button.custom_minimum_size,
			GameConstants.UI_BTN_PANEL_FONT,
			GameConstants.UI_BTN_PANEL_FONT_MIN
		)

# Shrinks a single caption Label's font until its single-line width fits inside
# the button's minimum width minus padding, using the correct font for the locale.
static func _fit_caption_label(
	label: Label,
	button_size: Vector2,
	base_font_size: int,
	min_font_size: int
) -> void:
	if not label:
		return
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = false
	var display := label.text
	if _is_message_key(display):
		display = String(TranslationServer.translate(display))
	var use_pixel := uses_pixel_font()
	var font: Font = pixel_font_clean() if use_pixel else ThemeDB.fallback_font
	if font == null:
		font = ThemeDB.fallback_font
	if font == null:
		return
	var target_w := maxf(40.0, button_size.x - 36.0)
	var size := scaled_font_size(base_font_size) if use_pixel else body_font_size(base_font_size)
	var min_size := scaled_font_size(min_font_size) if use_pixel else body_font_size(min_font_size)
	var step := 8 if use_pixel else 2
	while size > min_size:
		var measured := font.get_string_size(display, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		if measured.x <= target_w + 2.0:
			break
		size = maxi(min_size, size - step)
	if use_pixel:
		size = snap_pixel_font_size(size)
	var color := Color.WHITE
	if label.has_theme_color_override("font_color"):
		color = label.get_theme_color("font_color")
	if use_pixel:
		apply_live_pixel_label_settings(label, display, size, color)
		return
	clear_label_settings(label)
	label.set_meta("_use_default_font", true)
	label.text = display
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	apply_safe_outline(label, GameConstants.MENU_TEXT_OUTLINE)

# Sizes and fits text for a tab-style button (e.g. editor mode tabs).
static func apply_tab_button(button: Button) -> void:
	if not button:
		return
	button.custom_minimum_size = GameConstants.UI_BTN_TAB_SIZE
	fit_text_button(button, GameConstants.UI_BTN_TAB_FONT, GameConstants.UI_BTN_TAB_FONT_MIN)

# Styles a popup/dialog body label. In English uses the pixel label path;
# in other locales applies body font scaling and a safe outline.
static func apply_popup_label(label: Label, base_size: int = GameConstants.UI_BODY_FONT_SIZE) -> void:
	if not label:
		return
	if needs_pixel_text_raster():
		var key := _header_translation_key(label)
		var display := key if not key.is_empty() else label.text
		if _is_message_key(display):
			label.set_meta("_tr_key", display)
			display = String(TranslationServer.translate(display))
		display = _popup_prompt_with_title_gap(display)
		var color := Color.WHITE
		if label.has_theme_color_override("font_color"):
			color = label.get_theme_color("font_color")
		apply_live_pixel_label_settings(label, display, base_size, color)
		label.add_theme_constant_override("line_spacing", 8)
		return
	clear_label_settings(label)
	var use_default := prefer_default_font()
	label.set_meta("_use_default_font", use_default)
	label.text = _popup_prompt_with_title_gap(label.text)
	apply_locale_font_to_control(label)
	var size := body_font_size(base_size) if use_default else base_size
	label.add_theme_font_size_override("font_size", size)
	# Default fonts already read taller than Press Start — keep gaps tight.
	label.add_theme_constant_override("line_spacing", 4 if use_default else 8)
	apply_safe_outline(label, 8)

## Ensures a blank line after the first line of a multi-line confirm prompt.
## Pixel English keeps a full blank line; other locales use a single break so
## default-font line height does not look like a double gap.
static func _popup_prompt_with_title_gap(text: String) -> String:
	if text.is_empty():
		return text
	var normalized := text.replace("\\n", "\n")
	while normalized.contains("\n\n\n"):
		normalized = normalized.replace("\n\n\n", "\n\n")
	if not normalized.contains("\n"):
		return normalized
	var parts := normalized.split("\n", true, 1)
	if parts.size() < 2:
		return normalized
	var gap := "\n\n" if uses_pixel_font() else "\n"
	return parts[0] + gap + parts[1].lstrip("\n")

# Creates the near-opaque dark panel StyleBox used by all confirmation dialogs
# (reset progress, session resume, etc.). Gold border gives it a premium feel.
static func make_dialog_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.98)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(28)
	style.border_color = Color(1.0, 0.84, 0.0, 0.4)
	style.set_border_width_all(3)
	return style

# Biases a full-rect CenterContainer upward by shrinking it from the bottom.
# Visual raise ≈ raise_px because children are re-centered in the shorter host.
static func raise_centered_dialog_host(
	center: Control, raise_px: float = GameConstants.UI_DIALOG_RAISE_PX
) -> void:
	if center == null or not is_instance_valid(center):
		return
	center.offset_bottom = -absf(raise_px) * 2.0

# Applies the locale-correct body font to a plain Label. Always uses the scalable
# font (not Press Start), suitable for longer readable text blocks.
static func apply_body_label(label: Label, base_size: int = GameConstants.UI_BODY_FONT_SIZE) -> void:
	if not label:
		return
	label.set_meta("_use_default_font", true)
	apply_locale_font_to_control(label)
	label.add_theme_font_size_override("font_size", body_font_size(base_size))

# Same as apply_body_label but for RichTextLabel, setting the normal_font_size slot.
static func apply_body_richtext(
	label: RichTextLabel, base_size: int = GameConstants.UI_BODY_FONT_SIZE
) -> void:
	if not label:
		return
	label.set_meta("_use_default_font", true)
	apply_locale_font_to_control(label)
	label.add_theme_font_size_override("normal_font_size", body_font_size(base_size))

# Adds or updates the amber/white rounded overlay that indicates a toggled-on
# or tutorial-highlighted button. Hides and cleans up any legacy ColorRect version.
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

# Starts a looping tween that fades the ActiveMask alpha between 1.0 and 0.35,
# drawing the player's attention to the highlighted tutorial button.
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

# Kills the breathe tween and resets the ActiveMask to fully opaque white.
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

# Starts a looping scale+brightness pulse to attract attention to a button
# (e.g. the hint button when hints are available). Pivot is centred first.
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

# Stops the attention pulse tween and restores scale and modulate to neutral.
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

# Sets the pivot to the button centre so scale animations expand symmetrically.
static func _sync_button_attention_pivot(button: Button) -> void:
	if button:
		button.pivot_offset = button.size * 0.5

# Dims IconContainer (and hint count badge) when the button is disabled.
# Connected to button.draw so it re-evaluates whenever the disabled state changes.
static func refresh_button_icon_modulate(button: Button) -> void:
	if not button:
		return
	var dim := GameConstants.DISABLED_ICON_MODULATE if button.disabled else Color.WHITE
	var icon_root := button.get_node_or_null("IconContainer") as CanvasItem
	if icon_root:
		icon_root.modulate = dim
	# Infinity / ad badge sits outside IconContainer — dim it with the button too.
	var count_icon := button.get_node_or_null("HintCountIcon") as CanvasItem
	if count_icon:
		count_icon.modulate = dim
	var count_label := button.get_node_or_null("HintCountLabel") as CanvasItem
	if count_label:
		count_label.modulate = dim

# Translates a mode name (e.g. "EASY MODE") and replaces spaces with newlines
# so it fits on two lines in the top-bar centre label.
static func format_mode_label(translation_key: String, force_english: bool = false) -> String:
	var text := _tr(translation_key, force_english)
	return format_outlined_center_text(text.replace(" ", "\n"))

# Wraps text in BBCode [center] tags for use in a RichTextLabel.
static func format_outlined_center_text(body: String) -> String:
	return "[center]%s[/center]" % body

# Internal translation helper that supports forced-English mode for the editor preview.
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

# Sizes a top-bar button to a square (HUD_BUTTON_WIDTH × HUD_BUTTON_WIDTH),
# nudges its icon upward, and connects a draw callback to keep the icon modulation
# in sync with the button's disabled state.
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

# Sets the overall size and spacing for a left-buttons or right-buttons cluster
# so all buttons sit at a consistent height in the top bar.
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

# Shifts the icon upward by pixels by adjusting the IconContainer's bottom margin.
# This compensates for the visual weight of the tile background pushing icons down.
# Handles both MarginContainer and CenterContainer icon layouts.
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

# Fallback nudge for text-only buttons (no IconContainer): shifts content upward
# by reducing top content margin and increasing bottom margin in each StyleBox.
static func _nudge_button_text_up(button: Button, pixels: int) -> void:
	for style_name in ["normal", "pressed", "hover", "disabled"]:
		var style: StyleBox = button.get_theme_stylebox(style_name)
		if style is StyleBoxTexture:
			var copied: StyleBoxTexture = style.duplicate()
			copied.content_margin_top = maxf(0.0, copied.content_margin_top - float(pixels))
			copied.content_margin_bottom = copied.content_margin_bottom + float(pixels)
			button.add_theme_stylebox_override(style_name, copied)

# Applies layout and font to the top-bar centre RichTextLabel that shows the
# current mode name. Strips BBCode centre/font tags to get the plain text for
# font-size fitting, then re-applies pixel or scalable styling.
static func apply_top_bar_mode_label(label: RichTextLabel) -> void:
	if not label:
		return
	_layout_top_bar_center_label(label)
	var plain := _plain_top_bar_label_text(label.text)
	_clear_pixel_raster(label)
	if plain.is_empty():
		label.text = ""
		return
	if uses_pixel_font():
		label.set_meta("_use_default_font", false)
		label.set_meta("_force_pixel_font", true)
		label.text = format_outlined_center_text(plain)
		label.add_theme_font_override("normal_font", pixel_font())
		label.add_theme_font_size_override("normal_font_size", fit_top_bar_two_line_font_size(plain))
		_strip_live_pixel_outline(label)
		return
	label.set_meta("_force_pixel_font", false)
	label.set_meta("_use_default_font", true)
	apply_locale_font_to_control(label)
	apply_safe_outline(label, GameConstants.HUD_LEVEL_OUTLINE_SIZE)
	label.add_theme_font_size_override("normal_font_size", fit_top_bar_two_line_font_size(plain))

## Level word uses locale font; digits always use Press Start (like the timer).
static func apply_level_label(label: RichTextLabel, prefix: String, num: int) -> void:
	if not label:
		return
	_layout_top_bar_center_label(label)
	_clear_pixel_raster(label)
	var num_str := str(num)
	var plain := "%s\n%s" % [prefix, num_str]
	var font_size := fit_top_bar_two_line_font_size(plain)
	if uses_pixel_font():
		label.set_meta("_use_default_font", false)
		label.set_meta("_force_pixel_font", true)
		label.set_meta("_fixed_counter_font_size", false)
		label.text = format_outlined_center_text(plain)
		label.add_theme_font_override("normal_font", pixel_font())
		label.add_theme_font_size_override("normal_font_size", font_size)
		_strip_live_pixel_outline(label)
		return
	label.set_meta("_force_pixel_font", false)
	label.set_meta("_use_default_font", true)
	apply_locale_font_to_control(label)
	apply_safe_outline(label, GameConstants.HUD_LEVEL_OUTLINE_SIZE)
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.text = "[center]%s\n[font=%s][font_size=%d]%s[/font_size][/font][/center]" % [
		prefix, PIXEL_FONT_PATH, font_size, num_str
	]

# Configures the RichTextLabel geometry for the top-bar centre slot:
# fixed size, no scroll, centred alignment, and propagates the size up to the
# wrapping ancestors so the HBoxContainer knows the reserved width.
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

# Strips all BBCode formatting from the top-bar label text so the raw string
# can be measured for font-size fitting without tags inflating its width.
static func _plain_top_bar_label_text(bbcode: String) -> String:
	var plain := bbcode
	for tag in ["[center]", "[/center]"]:
		plain = plain.replace(tag, "")
	# Strip optional [font=...] wrappers used for digit Press Start.
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

# Convenience wrapper that builds the "LVL\n5" two-line string before fitting.
static func fit_top_bar_level_font_size(prefix: String, num: int) -> int:
	return fit_top_bar_two_line_font_size("%s\n%d" % [prefix, num])

# Finds the largest font size at which a two-line body string fits inside the
# top-bar centre area (HUD_BUTTON_HEIGHT × HUD_CENTER_LABEL_WIDTH), stepping by 1px.
static func fit_top_bar_two_line_font_size(body: String) -> int:
	var base := GameConstants.HUD_LEVEL_FONT_SIZE
	var size := scaled_font_size(base) if not uses_pixel_font() else base
	var font: Font = pixel_font() if uses_pixel_font() else ui_font()
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

# Configures a HUD counter RichTextLabel to be centred and non-scrolling.
# _y_nudge is reserved for future vertical fine-tuning and currently unused.
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

# Prepares a timer RichTextLabel for Press Start rendering by disabling scroll,
# fit-content, and any live outline (which scrambles under GL Compatibility).
static func prepare_timer_label(label: RichTextLabel) -> void:
	if not label:
		return
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.fit_content = false
	label.scroll_active = false
	label.clip_contents = false
	_strip_live_pixel_outline(label)

# Sets the timer label to display a formatted time string using Press Start
# at the fixed counter font size. The ∞ symbol shows a special icon instead.
static func set_timer_raster_text(label: RichTextLabel, plain_time: String) -> void:
	if not label:
		return
	prepare_timer_label(label)
	_clear_pixel_raster(label)
	# Timer stays Press Start + fixed size in every language (digits only).
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
	label.add_theme_font_override("normal_font", pixel_font())
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", Color(0.96, 0.96, 0.96, 1))
	_strip_live_pixel_outline(label)
	label.text = format_time_counter(plain_time)

# Prepares a joker/move counter label for BBCode icon+number rendering.
# Uses the default (scalable) font because Press Start and inline icon images
# don't mix well under GL Compatibility.
static func prepare_counter_label(label: RichTextLabel) -> void:
	if not label:
		return
	# Counter BBCode mixes icons + numbers; keep default font to avoid Press Start scramble.
	label.set_meta("_use_default_font", true)
	apply_locale_font_to_control(label)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.fit_content = false
	label.scroll_active = false
	label.clip_contents = false
	label.add_theme_font_size_override("normal_font_size", scaled_font_size(GameConstants.HUD_COUNTER_FONT_SIZE))
	apply_safe_outline(label, 6)
	label.add_theme_color_override("default_color", Color(0.96, 0.96, 0.96, 1))

# Builds a BBCode string that shows [icon] current/required with an optional
# caption label before the numbers. Used for joker and move-count HUD slots.
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

# Builds the BBCode string for the timer slot. Shows an infinity icon for ∞
# and wraps the time digits in a fixed Press Start font-size tag otherwise.
static func format_time_counter(formatted_time: String, _label_text: String = "") -> String:
	var num_size := GameConstants.HUD_COUNTER_FONT_SIZE
	if formatted_time == "∞":
		var icon_size := GameConstants.HUD_INFINITY_ICON_SIZE
		return "[center][img=%dx%d]%s[/img][/center]" % [
			icon_size, icon_size, GameConstants.ICON_INFINITY
		]
	return "[center][font_size=%d]%s[/font_size][/center]" % [num_size, formatted_time]
