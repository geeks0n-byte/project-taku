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
## Horizontal inset from screen edges for auto-sized popups and wrapped controls.
const UI_SAFE_SIDE_MARGIN := 32.0
## Minimum width for centered dialog/popup panels (capped by viewport when narrow).
const UI_MIN_DIALOG_WIDTH := 640.0
## Default width for standard confirmation / dialog panels.
const UI_DEFAULT_DIALOG_WIDTH := 720.0
## Maximum width for centered dialog/popup panels on wide screens.
const UI_MAX_DIALOG_WIDTH := 760.0
## Side margin when clamping dialog panels to the viewport (slightly tighter than generic UI).
const UI_DIALOG_SCREEN_MARGIN := 20.0
## Authored phone portrait width (project.godot display/window/size/viewport_width).
## Wide-screen caps keep phone chrome unchanged once the viewport grows past this.
const UI_PHONE_VIEWPORT_WIDTH := 1080.0
## Level-select content width on phones (1080 minus 24px HUD_SIDE_MARGIN each side).
const UI_PHONE_CONTENT_WIDTH := 1032.0
## Editor ControlPanel inner row width on phones (1080 minus 20px scroll pad each side).
const UI_PHONE_EDITOR_ROW_WIDTH := 1040.0

## Usable content width inside centered overlays (viewport minus side margins).
static func max_ui_content_width(extra_margin: float = UI_SAFE_SIDE_MARGIN) -> float:
	var window_w := 0.0
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		var root := (tree as SceneTree).root
		if root:
			window_w = root.get_viewport().get_visible_rect().size.x
	if window_w <= 0.0:
		window_w = float(DisplayServer.window_get_size().x)
	if window_w <= 0.0:
		window_w = float(ProjectSettings.get_setting("display/window/size/viewport_width", 1080))
	return maxf(240.0, window_w - extra_margin * 2.0)

static func clamp_ui_width(width: float, extra_margin: float = UI_SAFE_SIDE_MARGIN) -> float:
	var max_w := max_ui_content_width(extra_margin)
	var min_w := minf(UI_MIN_DIALOG_WIDTH, max_w)
	return clampf(width, min_w, max_w)

## Clamps a dialog panel's outer width to the viewport (uses tighter side margins).
static func clamp_dialog_panel_width(width: float) -> float:
	var viewport_max := max_ui_content_width(UI_DIALOG_SCREEN_MARGIN)
	var max_w := minf(viewport_max, UI_MAX_DIALOG_WIDTH)
	var min_w := minf(UI_MIN_DIALOG_WIDTH, max_w)
	return clampf(width, min_w, max_w)

## Inner content width for a dialog panel with symmetric vbox insets.
static func dialog_content_width(
	panel_width: float, horizontal_inset: float = HudDialogs.DIALOG_EDGE_INSET * 2.0
) -> float:
	return maxf(120.0, clamp_dialog_panel_width(panel_width) - horizontal_inset)

## Single-line width of a label's current text (locale-aware, respects label_settings).
static func measure_label_min_width(label: Label) -> float:
	return HudDialogs.measure_label_min_width(label)

## Caps width to the viewport without applying the dialog minimum (for buttons/controls).
static func cap_ui_width(width: float, extra_margin: float = UI_SAFE_SIDE_MARGIN) -> float:
	return minf(width, max_ui_content_width(extra_margin))

## Extra inset on each side so a stretched control is at most max_width. 0 on phones.
static func extra_side_inset_for_cap(current_width: float, max_width: float) -> float:
	if current_width <= max_width + 0.5:
		return 0.0
	return (current_width - max_width) * 0.5


## Centers a left-right stretched Control so it never exceeds max_width.
## Call after setting left/right offsets (safe-area included). No-op on narrow screens.
static func cap_stretched_width(control: Control, max_width: float = UI_PHONE_CONTENT_WIDTH) -> void:
	if control == null or max_width <= 0.0:
		return
	var span := control.anchor_right - control.anchor_left
	if span <= 0.0001:
		return
	var parent_w := _layout_parent_width(control)
	if parent_w <= 1.0:
		return
	var current_w := parent_w * span + control.offset_right - control.offset_left
	var extra := extra_side_inset_for_cap(current_w, max_width)
	if extra <= 0.0:
		return
	control.offset_left += extra
	control.offset_right -= extra


## On viewports wider than max_width, shrink-center a fill row; restore phone flags otherwise.
static func cap_box_row_width(row: Control, max_width: float = UI_PHONE_EDITOR_ROW_WIDTH) -> void:
	if row == null or max_width <= 0.0:
		return
	if not row.has_meta("_wide_cap_hflags"):
		row.set_meta("_wide_cap_hflags", row.size_flags_horizontal)
		row.set_meta("_wide_cap_min_x", row.custom_minimum_size.x)
	# Use the box parent only — viewport fallback would treat a 1080 phone as wide.
	var parent := row.get_parent()
	if not (parent is Control):
		return
	var parent_w := (parent as Control).size.x
	if parent_w <= 1.0:
		return
	if parent_w <= max_width + 0.5:
		row.size_flags_horizontal = int(row.get_meta("_wide_cap_hflags"))
		var min_sz := row.custom_minimum_size
		min_sz.x = float(row.get_meta("_wide_cap_min_x"))
		row.custom_minimum_size = min_sz
		return
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var capped := row.custom_minimum_size
	capped.x = max_width
	row.custom_minimum_size = capped


static func _layout_parent_width(control: Control) -> float:
	if control == null:
		return 0.0
	var parent := control.get_parent()
	if parent is Control:
		var pw := (parent as Control).size.x
		if pw > 1.0:
			return pw
	var vp := control.get_viewport()
	if vp:
		var w := vp.get_visible_rect().size.x
		if w > 0.0:
			return w
	return float(ProjectSettings.get_setting("display/window/size/viewport_width", 1080))

## Shifts a top-anchored HUD bar (and optional counter row) below the status bar / cutout.
static func apply_top_hud_safe_area(top_bar: Control, counter: Control = null) -> void:
	var edge := float(GameConstants.HUD_TOP_BAR_EDGE_MARGIN)
	var top := SafeInsets.padded_top(edge)
	var left := SafeInsets.left()
	var right := SafeInsets.right()
	if top_bar:
		top_bar.offset_left = edge + left
		top_bar.offset_top = top
		top_bar.offset_right = -edge - right
		top_bar.offset_bottom = top + GameConstants.HUD_TOP_BAR_HEIGHT - edge
	if counter:
		var shift := top - edge
		counter.offset_left = edge + left
		counter.offset_top = GameConstants.HUD_COUNTER_ROW_TOP + shift
		counter.offset_right = -edge - right
		counter.offset_bottom = (
			GameConstants.HUD_COUNTER_ROW_TOP + GameConstants.HUD_COUNTER_ROW_HEIGHT + shift
		)


## Lifts a bottom-anchored panel above the nav bar / home indicator.
static func apply_bottom_bar_safe_area(control: Control) -> void:
	if control == null:
		return
	if not control.has_meta("_safe_authored"):
		control.set_meta("_safe_authored", true)
		control.set_meta("_safe_t", control.offset_top)
		control.set_meta("_safe_b", control.offset_bottom)
		control.set_meta("_safe_l", control.offset_left)
		control.set_meta("_safe_r", control.offset_right)
	var m := SafeInsets.viewport_margins()
	control.offset_top = float(control.get_meta("_safe_t")) - m.w
	control.offset_bottom = float(control.get_meta("_safe_b")) - m.w
	control.offset_left = float(control.get_meta("_safe_l")) + m.x
	control.offset_right = float(control.get_meta("_safe_r")) - m.z


## Pads a full-rect content host so authored top/bottom/side offsets clear system bars.
static func apply_content_edge_safe_area(control: Control) -> void:
	if control == null:
		return
	if not control.has_meta("_safe_authored"):
		control.set_meta("_safe_authored", true)
		control.set_meta("_safe_t", control.offset_top)
		control.set_meta("_safe_b", control.offset_bottom)
		control.set_meta("_safe_l", control.offset_left)
		control.set_meta("_safe_r", control.offset_right)
	var m := SafeInsets.viewport_margins()
	control.offset_top = SafeInsets.padded_top(float(control.get_meta("_safe_t")))
	control.offset_bottom = SafeInsets.padded_bottom_offset(float(control.get_meta("_safe_b")))
	control.offset_left = float(control.get_meta("_safe_l")) + m.x
	control.offset_right = float(control.get_meta("_safe_r")) - m.z


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
	var bottom_margin := GameConstants.HUD_TOP_BAR_EDGE_MARGIN + SafeInsets.bottom()
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

# Cached fallback font reference so we don't call HudFonts.default_font() on every frame.
static var _screen_header_font_default: Font

# Returns the font to use for screen headers. Press Start except ka/uk;
# all other locales fall back to the theme's default scalable font.
static func screen_header_font(force_pixel: bool = false) -> Font:
	if force_pixel or uses_pixel_font():
		return pixel_font()
	if _screen_header_font_default == null:
		_screen_header_font_default = HudFonts.default_font()
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

# True for message ids (UI_YES), not short translated words that also look all-caps (TAK, JA).
static func _is_i18n_key(text: String) -> bool:
	return _is_message_key(text) and text.contains("_")

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

static func _screen_header_display_text(label: Label) -> String:
	if label == null:
		return ""
	var key := _header_translation_key(label)
	if not key.is_empty() and _is_message_key(key):
		return String(TranslationServer.translate(key))
	return String(label.text)

static func _screen_header_side_margin(label: Label) -> float:
	if label == null:
		return UI_SAFE_SIDE_MARGIN
	var margin := maxf(absf(label.offset_left), absf(label.offset_right))
	if margin <= 0.0:
		return UI_SAFE_SIDE_MARGIN
	return margin

static func _screen_header_available_width(label: Label, outline_size: int) -> float:
	var inner_pad := float(outline_size) * 2.0 + 8.0
	if label != null and label.size.x > 1.0:
		return maxf(120.0, label.size.x - inner_pad)
	return maxf(120.0, max_ui_content_width(_screen_header_side_margin(label)) - inner_pad)

static func _fit_screen_header_font_size(
	display: String,
	font: Font,
	base_size: int,
	max_width: float,
	snap_pixel: bool = false
) -> int:
	if display.is_empty() or font == null or max_width <= 0.0:
		return base_size
	var size := base_size
	var min_size := 16 if snap_pixel else 14
	var step := 8 if snap_pixel else 1
	while size > min_size:
		var text_w := HudDialogs.measure_text_max_line_width(font, display, size)
		if text_w <= max_width + 1.0:
			break
		size -= step
	if snap_pixel:
		size = snap_pixel_font_size(maxi(min_size, size))
	return maxi(min_size, size)

# Applies the canonical screen-header look: centred, correct font, outline, colour.
# Handles both the pixel-font and scalable-font (ka/uk) paths,
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
	var display := _screen_header_display_text(label)
	var max_w := _screen_header_available_width(label, outline_size)
	var font: Font
	var fitted_size: int
	if force_pixel or needs_pixel_text_raster():
		label.set_meta("_use_default_font", false)
		font = pixel_font_clean()
		fitted_size = _fit_screen_header_font_size(display, font, header_size, max_w, true)
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", fitted_size)
		_strip_live_pixel_outline(label)
		return
	label.set_meta("_use_default_font", true)
	font = screen_header_font(false)
	fitted_size = _fit_screen_header_font_size(
		display, font, body_font_size(header_size), max_w, false
	)
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", fitted_size)
	apply_safe_outline(label, outline_size)

# Styles the victory/completion header label. Reduces font size on mobile to prevent
# overflow, and uses the pixel font path except for ka/uk.
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
	if uses_pixel_font() or control_uses_pixel_font(label):
		label.set_meta("_brand_title", false)
		if _in_force_pixel_subtree(label):
			label.set_meta("_force_pixel_font", true)
		apply_live_pixel_label_settings(
			label, label.text, size, GameConstants.SCREEN_HEADER_COLOR
		)
		return
	label.set_meta("_brand_title", false)
	label.set_meta("_use_default_font", true)
	clear_label_settings(label)
	_clear_pixel_raster(label)
	label.add_theme_font_override("font", HudFonts.default_font())
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
	var panel_top := SafeInsets.padded_top(GameConstants.HTP_PANEL_TOP)
	var bottom_limit := host_h - GameConstants.AD_BANNER_RESERVE - 16.0 - SafeInsets.bottom()
	var max_panel_h := maxf(
		GameConstants.HTP_PANEL_MIN_HEIGHT,
		bottom_limit - panel_top - nav_h - GameConstants.SCREEN_NAV_GAP
	)

	# Lock horizontal size first so RichTextLabel can measure wrap height.
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -GameConstants.HTP_PANEL_HALF_WIDTH
	panel.offset_right = GameConstants.HTP_PANEL_HALF_WIDTH
	panel.offset_top = panel_top
	panel.offset_bottom = panel_top + max_panel_h
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
			panel_top + natural_panel_h + GameConstants.SCREEN_NAV_GAP
		)
	var nav_top: float = float(host.get_meta("_htp_nav_top"))
	var max_under_nav := maxf(
		GameConstants.HTP_PANEL_MIN_HEIGHT,
		nav_top - panel_top - GameConstants.SCREEN_NAV_GAP
	)
	var panel_h := clampf(content_h, GameConstants.HTP_PANEL_MIN_HEIGHT, minf(max_panel_h, max_under_nav))
	panel.offset_bottom = panel_top + panel_h
	if rules:
		var needs_scroll := content_h > panel_h + 1.0
		rules.scroll_active = needs_scroll
		rules.fit_content = not needs_scroll

	nav.anchor_left = 0.0
	nav.anchor_right = 1.0
	nav.anchor_top = 0.0
	nav.anchor_bottom = 0.0
	nav.offset_left = 40.0 + SafeInsets.left()
	nav.offset_right = -40.0 - SafeInsets.right()
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
	_place_overlay_close_like_pause(button)
	_register_overlay_close_layout(button)

# One size_changed hook per viewport; Godot treats binds of the same method as one connection.
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

# Match the in-game pause button: HUD top-bar left cluster, not the raw screen corner.
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
# non-numeric character. Skips BBCode tags so [color=...] markup stays intact.
static func break_after_sentences(text: String) -> String:
	if text.is_empty():
		return text
	var out := ""
	var i := 0
	var n := text.length()
	var in_tag := false
	while i < n:
		var c := text[i]
		if c == "[":
			in_tag = true
			out += c
		elif c == "]":
			in_tag = false
			out += c
		elif not in_tag and (c == "." or c == "!" or c == "?"):
			out += c
			var j := i + 1
			while j < n and (text[j] == " " or text[j] == "\t"):
				j += 1
			if j > i + 1 and j < n and text[j] != "\n":
				var next_c := text[j]
				if next_c < "0" or next_c > "9":
					out += "\n"
					i = j
					continue
		else:
			out += c
		i += 1
	return out

# Wraps a status message in BBCode center tags after translation.
static func format_centered_status(msg: String, force_english: bool = false) -> String:
	return "[center]" + translate_status_text(msg, force_english) + "[/center]"

# Returns the composite font scale for the current locale and font type.
# Georgian/Ukrainian are slightly reduced (glyphs read large). Press Start is not scaled.
static func font_scale() -> float:
	var scale := 1.0
	if not uses_pixel_font():
		scale = GameConstants.DEFAULT_FONT_SCALE
	scale *= HudFonts.non_pixel_locale_scale()
	return scale

# Scales a font size by font_scale() and snaps to the nearest valid Press Start grid size.
static func scaled_font_size(base: int) -> int:
	var size := int(round(float(base) * font_scale()))
	if uses_pixel_font():
		return snap_pixel_font_size(size)
	return size

# Scales a font size for the non-pixel (scalable) font path.
static func body_font_size(base: int) -> int:
	var scale := GameConstants.DEFAULT_FONT_SCALE * HudFonts.non_pixel_locale_scale()
	return int(round(float(base) * scale))

## Press Start is an 8px grid font — odd sizes create uneven gaps between letters.
## Callers should only invoke this on the pixel-font path.
static func snap_pixel_font_size(size: int) -> int:
	if size <= 0:
		return size
	return maxi(8, int(round(float(size) / 8.0)) * 8)

const PIXEL_FONT_PATH := "res://resources/fonts/PressStart2P-vaV7.ttf"
## Canonical English pixel font (imported FontFile). Do not rebuild from bytes.
const PIXEL_FONT: Font = preload("res://resources/fonts/PressStart2P-vaV7.ttf")
const _PIXEL_MONO_TEXT_SCRIPT: Script = preload("res://scripts/pixel_mono_text.gd")

# Press Start for every locale except Georgian / Ukrainian (see HudFonts).
# Editor tooling can opt a subtree into Press Start via mark_force_pixel_subtree().

static func uses_pixel_font() -> bool:
	return HudFonts.uses_pixel_font()

## True when this control (or an ancestor) should render Press Start regardless of locale.
static func control_uses_pixel_font(control: Node = null) -> bool:
	return HudFonts.control_uses_pixel_font(control)

static func _in_force_pixel_subtree(node: Node) -> bool:
	return HudFonts._in_force_pixel_subtree(node)

## Marks a UI root so all text under it uses Press Start (editor is English-only).
static func mark_force_pixel_subtree(root: Node) -> void:
	HudFonts.mark_force_pixel_subtree(root)

static func begin_force_pixel_font() -> void:
	HudFonts.begin_force_pixel_font()

static func end_force_pixel_font() -> void:
	HudFonts.end_force_pixel_font()

static func pixel_font() -> Font:
	return HudFonts.pixel_font()

static func pixel_font_clean() -> Font:
	return HudFonts.pixel_font_clean()

# True when the current locale uses Press Start; callers use this to decide
# whether to create a pixel caption overlay instead of using the theme font.
static func needs_pixel_text_raster() -> bool:
	return uses_pixel_font()

# No-op kept for call-site compatibility. The imported FontFile must remain alive
# in memory; clearing the cached reference caused fd-null crashes in older builds.
static func clear_pixel_text_cache() -> void:
	HudFonts.clear_pixel_text_cache()

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
	if _in_force_pixel_subtree(control):
		return true
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
	# Digits / symbols / Latin-only copy stay Press Start in ka/uk.
	var use_pixel := force_pixel or control_uses_pixel_font(label)
	if not use_pixel and HudFonts.is_scalable_script_locale() and HudFonts.text_uses_press_start_font(text):
		use_pixel = true
	if use_pixel:
		if force_pixel or _in_force_pixel_subtree(label):
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
	label.add_theme_font_size_override("font_size", body_font_size(font_size))
	label.add_theme_color_override("font_color", color)
	apply_safe_outline(label, 8)
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
	var use_pixel := force_pixel or control_uses_pixel_font(button) or bool(button.get_meta("_force_pixel_font", false))
	if not use_pixel and HudFonts.is_scalable_script_locale() and HudFonts.text_uses_press_start_font(text):
		use_pixel = true
	if use_pixel:
		# Draw Press Start on a caption label — never via Button theme font/outline.
		button.set_meta("_use_default_font", false)
		if force_pixel or _in_force_pixel_subtree(button):
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
	button.add_theme_font_size_override("font_size", body_font_size(font_size))
	apply_safe_outline(button, 8)

# Returns the appropriate UI font for the active locale.
static func ui_font() -> Font:
	return pixel_font() if uses_pixel_font() else HudFonts.default_font()

## Visible/copy string for font routing (translates i18n keys when needed).
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
	# Include keys without "_" (TUTORIAL, PAUSED, COMPLETED). Underscore-only
	# matching is for dialog-key recovery where TAK/JA must not look like keys.
	if _is_message_key(raw):
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
	if not use_default and _in_force_pixel_subtree(node):
		node.set_meta("_force_pixel_font", true)
		node.set_meta("_use_default_font", false)
		_apply_forced_pixel_font(node)
		_strip_live_pixel_outline(node as Control)
		return
	var font := HudFonts.default_font() if use_default else ui_font()
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
static var _locale_font_tree_depth: int = 0

static func is_applying_locale_fonts() -> bool:
	return _locale_font_tree_depth > 0

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

# Shrinks a button's font until the wrapped text fits within the button's minimum
# size minus padding. Useful for long translated strings that otherwise overflow.
static func fit_text_button(button: Button, base_font_size: int = 36, min_font_size: int = 18) -> void:
	if not button:
		return
	if _is_icon_only_button(button):
		return
	button.clip_text = false
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var use_pixel := control_uses_pixel_font(button)
	var font: Font = (
		HudFonts.default_font() if button.get_meta("_use_default_font", false) else (
			pixel_font() if use_pixel else ui_font()
		)
	)
	if font == null:
		font = HudFonts.default_font()
	var target_w := maxf(40.0, button.custom_minimum_size.x - 28.0)
	var target_h := maxf(40.0, button.custom_minimum_size.y - 24.0)
	var display := button.text
	if button.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED:
		display = String(TranslationServer.translate(button.text))
	if display.is_empty():
		return
	var size: int
	var min_size: int
	if use_pixel:
		size = snap_pixel_font_size(base_font_size)
		min_size = snap_pixel_font_size(min_font_size)
	else:
		size = body_font_size(base_font_size)
		min_size = body_font_size(min_font_size)
	var step := 8 if use_pixel else 2
	while size > min_size:
		var measured := font.get_multiline_string_size(display, HORIZONTAL_ALIGNMENT_CENTER, target_w, size)
		if measured.x <= target_w + 2.0 and measured.y <= target_h + 2.0:
			break
		size = maxi(min_size, size - step)
	if use_pixel:
		size = snap_pixel_font_size(size)
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
	var use_pixel := control_uses_pixel_font(button)
	var font: Font = (
		HudFonts.default_font() if button.get_meta("_use_default_font", false) else (
			pixel_font() if use_pixel else ui_font()
		)
	)
	if font == null:
		font = HudFonts.default_font()
	var target_w := maxf(40.0, button.custom_minimum_size.x - 36.0)
	var display := button.text
	if button.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED:
		display = String(TranslationServer.translate(button.text))
	if display.is_empty():
		return
	var size: int
	var min_size: int
	if use_pixel:
		size = snap_pixel_font_size(base_font_size)
		min_size = snap_pixel_font_size(min_font_size)
	else:
		size = body_font_size(base_font_size)
		min_size = body_font_size(min_font_size)
	var step := 8 if use_pixel else 2
	while size > min_size:
		var measured := font.get_string_size(display, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		if measured.x <= target_w + 2.0:
			break
		size = maxi(min_size, size - step)
	if use_pixel:
		size = snap_pixel_font_size(size)
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
static func apply_dialog_button(button: Button, display_override: String = "") -> void:
	if not button:
		return
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = GameConstants.UI_BTN_DIALOG_SIZE
	# Prefer explicit / button.text when set (e.g. after tr() on locale change); stale
	# PixelSafeCaption would otherwise win for words like Polish "TAK" that look like keys.
	var display := display_override.strip_edges()
	if display.is_empty():
		display = String(button.text)
	if display.is_empty() or _is_i18n_key(display):
		var info := _button_label_display(button)
		display = String(info.get("text", ""))
	if not display.is_empty() and _is_i18n_key(display):
		display = String(TranslationServer.translate(display))
	apply_raster_pixel_button(button, display, GameConstants.UI_BTN_DIALOG_FONT)
	grow_dialog_button_to_text(button)

## Applies dialog styling and grows width to fit the label (single-button popups).
static func apply_dialog_button_fitted(
	button: Button,
	min_width: float = -1.0
) -> void:
	apply_dialog_button(button)
	var base := GameConstants.UI_BTN_DIALOG_SIZE
	grow_button_to_text(
		button,
		base.y,
		48.0,
		base.x if min_width < 0.0 else min_width
	)

## Styles dialog buttons and optionally gives them a shared width (max of the group).
## When `max_total_width` is set, the group is capped to that width (e.g. panel content area).
static func fit_dialog_button_group(
	buttons: Array,
	equal_width: bool = true,
	min_width: float = GameConstants.UI_BTN_DIALOG_SIZE.x,
	height: float = GameConstants.UI_BTN_DIALOG_SIZE.y,
	max_total_width: float = -1.0
) -> void:
	if buttons.is_empty():
		return
	for btn in buttons:
		if btn == null or not (btn is Button):
			continue
		apply_dialog_button(btn)
	if not equal_width:
		return
	equalize_button_group_widths(buttons, min_width, height, max_total_width)

## Sets every button in the group to the widest minimum width (locale-aware sizing).
static func equalize_button_group_widths(
	buttons: Array,
	min_width: float = 160.0,
	height: float = -1.0,
	max_total_width: float = -1.0
) -> void:
	var visible_btns: Array[Button] = []
	for btn in buttons:
		if btn == null or not (btn is Button):
			continue
		if not (btn as CanvasItem).visible:
			continue
		visible_btns.append(btn)
	if visible_btns.is_empty():
		return
	for btn in visible_btns:
		grow_dialog_button_to_text(btn)
	var shared_w := min_width
	for btn in visible_btns:
		shared_w = maxf(shared_w, HudLayout.measure_dialog_button_min_width(btn))
	if max_total_width > 0.0:
		var in_hbox := false
		if not visible_btns.is_empty():
			var parent := visible_btns[0].get_parent()
			in_hbox = parent is HBoxContainer
		if in_hbox:
			var n := visible_btns.size()
			var sep_total := 40.0 * float(maxi(n - 1, 0))
			var row_natural := shared_w * float(n) + sep_total
			if row_natural > max_total_width:
				shared_w = maxf(
					80.0, (max_total_width - sep_total) / float(maxi(n, 1))
				)
	else:
		shared_w = cap_ui_width(shared_w)
	for btn in visible_btns:
		var button := btn as Button
		var btn_h := height if height > 0.0 else button.custom_minimum_size.y
		var info := _button_label_display(button)
		var caption: Label = info.get("caption")
		_reset_button_single_line(button, caption)
		button.custom_minimum_size = Vector2(shared_w, btn_h)

static func _button_label_display(button: Button) -> Dictionary:
	var display := button.text
	var font: Font = button.get_theme_font("font")
	var font_size := button.get_theme_font_size("font_size")
	var caption := button.get_node_or_null("PixelSafeCaption/Caption") as Label
	if caption == null:
		# Victory / panel buttons often draw via a nested Label (e.g. HBox/Label).
		for node in button.find_children("*", "Label", true, false):
			var label := node as Label
			if label == null or label.text.strip_edges().is_empty():
				continue
			if bool(label.get_meta("_pixel_outline_part", false)):
				continue
			caption = label
			break
	if caption:
		display = caption.text
		if caption.label_settings != null:
			font = caption.label_settings.font
			font_size = caption.label_settings.font_size
		else:
			font = caption.get_theme_font("font")
			font_size = caption.get_theme_font_size("font_size")
	elif display.is_empty() or _is_i18n_key(display):
		var key := display if not display.is_empty() else String(button.get_meta("_tr_key", ""))
		if not key.is_empty():
			display = String(TranslationServer.translate(key))
	return {"text": display, "font": font, "font_size": font_size, "caption": caption}

## Single-line width for a dialog button label (used to size panels before wrapping).
static func measure_dialog_button_min_width(
	button: Button, horizontal_padding: float = 48.0
) -> float:
	if button == null:
		return GameConstants.UI_BTN_DIALOG_SIZE.x
	var info := _button_label_display(button)
	var display: String = info.get("text", "")
	var font: Font = info.get("font")
	var font_size: int = info.get("font_size", GameConstants.UI_BTN_DIALOG_FONT)
	if font == null:
		font = HudFonts.default_font()
	if display.is_empty():
		return GameConstants.UI_BTN_DIALOG_SIZE.x
	var text_w := HudDialogs.measure_text_max_line_width(font, display, font_size)
	return maxf(GameConstants.UI_BTN_DIALOG_SIZE.x, text_w + horizontal_padding)

static func _reset_button_single_line(button: Button, caption: Label) -> void:
	if caption:
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.autowrap_mode = TextServer.AUTOWRAP_OFF

static func _apply_button_wrapped_size(
	button: Button,
	caption: Label,
	display: String,
	font: Font,
	font_size: int,
	width: float,
	min_height: float,
	horizontal_padding: float,
	vertical_padding: float = 20.0
) -> void:
	var inner_w := maxf(40.0, width - horizontal_padding)
	if caption:
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var measured := font.get_multiline_string_size(
		display, HORIZONTAL_ALIGNMENT_CENTER, inner_w, font_size
	)
	var line_h := maxf(1.0, font.get_height(font_size))
	var max_text_h := line_h * float(UI_TILE_BUTTON_MAX_LINES)
	var text_h := minf(measured.y, max_text_h)
	var btn_h := maxf(min_height, text_h + vertical_padding)
	button.custom_minimum_size = Vector2(width, btn_h)

static func _button_uses_tile_style(button: Button) -> bool:
	if button == null:
		return false
	var normal := button.get_theme_stylebox("normal")
	return normal is StyleBoxTexture

## Tile-style overlay buttons (consent, etc.).
const UI_TILE_BUTTON_H_PAD := 96.0
const UI_TILE_BUTTON_V_PAD := 40.0
const UI_TILE_BUTTON_MIN_HEIGHT := 118.0
## Single-line tile buttons wider than this wrap (up to [member UI_TILE_BUTTON_MAX_LINES] lines).
const UI_TILE_BUTTON_PREFER_WRAP_WIDTH := 560.0
const UI_TILE_BUTTON_MAX_LINES := 2

## Width/height for a tile button label — single line when narrow, else ≤2 wrapped lines.
static func compute_tile_button_size(
	display: String,
	font: Font,
	font_size: int,
	column_w: float,
	min_width: float = 280.0,
	min_height: float = UI_TILE_BUTTON_MIN_HEIGHT,
	h_pad: float = UI_TILE_BUTTON_H_PAD,
	v_pad: float = UI_TILE_BUTTON_V_PAD
) -> Vector2:
	if display.is_empty() or font == null:
		return Vector2(min_width, min_height)
	var line_h := maxf(1.0, font.get_height(font_size))
	var text_w := HudDialogs.measure_text_max_line_width(font, display, font_size)
	var single_w := maxf(min_width, text_w + h_pad)
	var single_h := maxf(min_height, line_h + v_pad)
	# Keep short labels on one line; wider copy wraps near the preferred width.
	if single_w <= UI_TILE_BUTTON_PREFER_WRAP_WIDTH + 2.0:
		return Vector2(minf(column_w, single_w), single_h)
	var btn_w := maxf(min_width, minf(UI_TILE_BUTTON_PREFER_WRAP_WIDTH, column_w))
	var inner_w := maxf(40.0, btn_w - h_pad)
	while (
		HudDialogs.count_wrapped_text_lines(font, display, inner_w, font_size) > UI_TILE_BUTTON_MAX_LINES
		and btn_w < column_w - 1.0
	):
		btn_w = minf(column_w, btn_w + 24.0)
		inner_w = maxf(40.0, btn_w - h_pad)
	var measured := font.get_multiline_string_size(
		display, HORIZONTAL_ALIGNMENT_CENTER, inner_w, font_size
	)
	var max_text_h := line_h * float(UI_TILE_BUTTON_MAX_LINES)
	var text_h := minf(measured.y, max_text_h)
	var btn_h := maxf(min_height, text_h + v_pad)
	return Vector2(btn_w, btn_h)

## Single-line width/height for a tile-style button label.
static func compute_tile_button_single_line_size(
	display: String,
	font: Font,
	font_size: int,
	min_width: float = 280.0,
	min_height: float = UI_TILE_BUTTON_MIN_HEIGHT,
	h_pad: float = UI_TILE_BUTTON_H_PAD,
	v_pad: float = UI_TILE_BUTTON_V_PAD
) -> Vector2:
	if display.is_empty() or font == null:
		return Vector2(min_width, min_height)
	var line_h := maxf(1.0, font.get_height(font_size))
	var text_w := HudDialogs.measure_text_max_line_width(font, display, font_size)
	return Vector2(maxf(min_width, text_w + h_pad), maxf(min_height, line_h + v_pad))

static func apply_tile_button_single_line_size(
	button: Button,
	display: String,
	font: Font,
	font_size: int,
	min_height: float = UI_TILE_BUTTON_MIN_HEIGHT,
	min_width: float = 280.0,
	h_pad: float = UI_TILE_BUTTON_H_PAD,
	v_pad: float = UI_TILE_BUTTON_V_PAD
) -> void:
	if button == null:
		return
	var info := _button_label_display(button)
	var caption: Label = info.get("caption")
	_reset_button_single_line(button, caption)
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.custom_minimum_size = compute_tile_button_single_line_size(
		display, font, font_size, min_width, min_height, h_pad, v_pad
	)

static func apply_tile_button_size(
	button: Button,
	display: String,
	font: Font,
	font_size: int,
	column_w: float,
	min_height: float = UI_TILE_BUTTON_MIN_HEIGHT,
	min_width: float = 280.0,
	h_pad: float = UI_TILE_BUTTON_H_PAD,
	v_pad: float = UI_TILE_BUTTON_V_PAD
) -> void:
	if button == null:
		return
	var info := _button_label_display(button)
	var caption: Label = info.get("caption")
	var size := compute_tile_button_size(
		display, font, font_size, column_w, min_width, min_height, h_pad, v_pad
	)
	var text_w := HudDialogs.measure_text_max_line_width(font, display, font_size)
	var use_single_line := text_w + h_pad <= UI_TILE_BUTTON_PREFER_WRAP_WIDTH + 2.0
	if use_single_line:
		_reset_button_single_line(button, caption)
		button.custom_minimum_size = size
	else:
		_apply_button_wrapped_size(
			button, caption, display, font, font_size,
			size.x, min_height, h_pad, v_pad
		)
		button.custom_minimum_size.y = size.y

## Sets a button's width from its current label (locale-aware). Height is fixed.
static func grow_button_to_text(
	button: Button,
	height: float,
	horizontal_padding: float = 48.0,
	min_width: float = 160.0
) -> void:
	if not button:
		return
	var info := _button_label_display(button)
	var display: String = info.get("text", "")
	var font: Font = info.get("font")
	var font_size: int = info.get("font_size", 16)
	var caption: Label = info.get("caption")
	if font == null or display.is_empty():
		button.custom_minimum_size = Vector2(min_width, height)
		return
	var text_w := HudDialogs.measure_text_max_line_width(font, display, font_size)
	var desired_w := maxf(min_width, text_w + horizontal_padding)
	_reset_button_single_line(button, caption)
	button.custom_minimum_size = Vector2(desired_w, height)

## Grows a dialog button's width to fit its current label (locale-aware).
## Height stays at UI_BTN_DIALOG_SIZE.y. Used by the tutorial NEXT control.
static func grow_dialog_button_to_text(button: Button, horizontal_padding: float = 48.0) -> void:
	var base := GameConstants.UI_BTN_DIALOG_SIZE
	grow_button_to_text(button, base.y, horizontal_padding, base.x)

## Grows a panel button's width to fit its label; never thinner than UI_BTN_PANEL_SIZE.x.
static func grow_panel_button_to_text(button: Button, horizontal_padding: float = 48.0) -> void:
	var base := GameConstants.UI_BTN_PANEL_SIZE
	grow_button_to_text(button, base.y, horizontal_padding, base.x)

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
# Height is UI_BTN_PANEL_SIZE.y; width grows to the label with that size as a minimum.
# Latin/digits/symbols use Press Start even in ka/uk; native-script copy uses Noto.
static func apply_panel_button(button: Button) -> void:
	if not button:
		return
	button.focus_mode = Control.FOCUS_NONE
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.clip_text = false
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size = GameConstants.UI_BTN_PANEL_SIZE
	var display := _resolved_control_text(button)
	if display.is_empty():
		display = button.text.strip_edges()
	if display.is_empty():
		var info := _button_label_display(button)
		display = String(info.get("text", ""))
	if HudFonts.should_use_press_start_font(display) and not display.is_empty():
		button.set_meta("_use_default_font", false)
		if _in_force_pixel_subtree(button):
			button.set_meta("_force_pixel_font", true)
		# Prefer caption on the button itself when there is no nested Label chrome.
		var nested := button.get_node_or_null("HBoxContainer/Label") as Label
		if nested == null:
			nested = button.get_node_or_null("Label") as Label
		if nested:
			apply_raster_pixel_label(
				nested, display, GameConstants.UI_BTN_PANEL_FONT, Color.WHITE
			)
		else:
			apply_raster_pixel_button(
				button, display, GameConstants.UI_BTN_PANEL_FONT
			)
		grow_panel_button_to_text(button)
		return
	var use_pixel := control_uses_pixel_font(button)
	button.set_meta("_use_default_font", not use_pixel)
	if use_pixel:
		if _in_force_pixel_subtree(button):
			button.set_meta("_force_pixel_font", true)
		_strip_live_pixel_outline(button)
	else:
		apply_safe_outline(button, 8)
	if not display.is_empty() and button.text.strip_edges().is_empty():
		# Keep i18n key on the button when a nested Label owns the visible copy.
		pass
	elif not display.is_empty():
		button.text = display
	button.add_theme_font_size_override(
		"font_size", body_font_size(GameConstants.UI_BTN_PANEL_FONT)
	)
	apply_locale_font_to_control(button)
	grow_panel_button_to_text(button)

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
	var use_default := prefer_default_font()
	button.set_meta("_use_default_font", use_default)
	button.set_meta("_force_pixel_font", false)
	if button.has_theme_font_override("font"):
		button.remove_theme_font_override("font")
	button.add_theme_font_override("font", HudFonts.default_font() if use_default else pixel_font())
	apply_locale_font_to_control(button)
	button.add_theme_font_size_override("font_size", scaled_font_size(font_size))
	fit_text_button_single_line(button, font_size, maxi(18, font_size - 24))
	var font := button.get_theme_font("font")
	var size := button.get_theme_font_size("font_size")
	var display := button.text
	if font and not display.is_empty():
		apply_tile_button_single_line_size(
			button, display, font, size, height
		)
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
	var use_pixel := control_uses_pixel_font(label)
	var font: Font = pixel_font_clean() if use_pixel else HudFonts.default_font()
	if font == null:
		font = HudFonts.default_font()
	if font == null:
		return
	var target_w := maxf(40.0, button_size.x - 36.0)
	var size: int
	var min_size: int
	if use_pixel:
		size = snap_pixel_font_size(base_font_size)
		min_size = snap_pixel_font_size(min_font_size)
	else:
		size = body_font_size(base_font_size)
		min_size = body_font_size(min_font_size)
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

# Styles a popup/dialog body label. Uses the pixel label path except ka/uk;
# in other locales applies body font scaling and a safe outline.
static func apply_popup_label(label: Label, base_size: int = GameConstants.UI_BODY_FONT_SIZE) -> void:
	if not label:
		return
	if control_uses_pixel_font(label):
		var key := _header_translation_key(label)
		var display := key if not key.is_empty() else label.text
		if _is_message_key(display):
			label.set_meta("_tr_key", display)
			# Editor chrome stays English; elsewhere use the active locale.
			display = (
				english(display)
				if _in_force_pixel_subtree(label)
				else String(TranslationServer.translate(display))
			)
		display = _popup_prompt_with_title_gap(display, true)
		var color := Color.WHITE
		if label.has_theme_color_override("font_color"):
			color = label.get_theme_color("font_color")
		if _in_force_pixel_subtree(label):
			label.set_meta("_force_pixel_font", true)
		apply_live_pixel_label_settings(label, display, base_size, color)
		label.add_theme_constant_override("line_spacing", 8)
	else:
		clear_label_settings(label)
		var use_default := prefer_default_font()
		label.set_meta("_use_default_font", use_default)
		label.set_meta("_force_pixel_font", false)
		# Drop scene-baked Press Start so ka/uk can show real glyphs.
		if label.has_theme_font_override("font"):
			label.remove_theme_font_override("font")
		label.text = _popup_prompt_with_title_gap(label.text, false)
		apply_locale_font_to_control(label)
		label.add_theme_font_override("font", HudFonts.default_font() if use_default else pixel_font())
		var size := body_font_size(base_size) if use_default else base_size
		label.add_theme_font_size_override("font_size", size)
		# Default fonts already read taller than Press Start — keep gaps tight.
		label.add_theme_constant_override("line_spacing", 4 if use_default else 8)
		apply_safe_outline(label, 8)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.custom_minimum_size.x = 0.0
	label.clip_contents = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

# True when copy is numeric/symbol display (level numbers, MM:SS clocks, etc.) — Press Start in ka/uk.
static func text_is_digit_display(text: String) -> bool:
	if text.is_empty() or text == "∞":
		return false
	for i in text.length():
		var c := text[i]
		if c >= "0" and c <= "9":
			continue
		if c in [":", "/", " "]:
			continue
		return false
	return true

## Popup heading with a locale word + level number; digits use Press Start in ka/uk.
static func apply_popup_title_with_number(
	label: RichTextLabel, prefix: String, num_str: String, base_size: int, color: Color
) -> void:
	if label == null:
		return
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hex := color.to_html(false)
	if uses_pixel_font():
		var display := "%s %s" % [prefix, num_str]
		label.text = "[center][color=#%s]%s[/color][/center]" % [hex, display]
		apply_live_pixel_richtext(label, base_size)
		label.add_theme_color_override("default_color", color)
	else:
		label.set_meta("_use_default_font", true)
		label.set_meta("_force_pixel_font", false)
		apply_locale_font_to_control(label)
		var size := body_font_size(base_size)
		label.add_theme_font_size_override("normal_font_size", size)
		label.text = "[center][color=#%s]%s [font=%s][font_size=%d]%s[/font_size][/font][/color][/center]" % [
			hex, prefix, PIXEL_FONT_PATH, size, num_str
		]
		apply_safe_outline(label, 8)
		label.add_theme_color_override("default_color", color)

## Ensures a blank line after the first line of a multi-line confirm prompt.
## Pixel English keeps a full blank line; other locales use a single break so
## default-font line height does not look like a double gap.
static func _popup_prompt_with_title_gap(text: String, use_pixel_gap: bool = false) -> String:
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
	# CSV copy often already includes a blank line after the title.
	if parts[1].begins_with("\n"):
		return normalized
	var gap := "\n\n" if (use_pixel_gap or uses_pixel_font()) else "\n"
	return parts[0] + gap + parts[1].lstrip("\n")

# Creates the near-opaque dark panel StyleBox used by all confirmation dialogs
# (reset progress, session resume, etc.). Gold border gives it a premium feel.
static func make_dialog_panel_style() -> StyleBoxFlat:
	return HudDialogs.make_dialog_panel_style()

# Biases a full-rect CenterContainer upward by shrinking it from the bottom.
# Visual raise ≈ raise_px because children are re-centered in the shorter host.
static func raise_centered_dialog_host(
	center: Control, raise_px: float = GameConstants.UI_DIALOG_RAISE_PX
) -> void:
	HudDialogs.raise_centered_dialog_host(center, raise_px)

## Fit a Yes/No dialog panel height to current locale text (+ top/bottom margin).
## Returns the inner content width so callers can size nested widgets to match.
static func fit_dialog_panel(
	panel: Panel, width: float = UI_DEFAULT_DIALOG_WIDTH, min_height: float = 280.0
) -> float:
	return HudDialogs.fit_vbox_dialog_panel(panel, width, HudDialogs.DIALOG_EDGE_INSET, HudDialogs.DIALOG_EXTRA_PAD_V, min_height)

static func fit_session_resume_panel(
	panel: Panel, prompt: Label, buttons: Control, width: float = 820.0
) -> void:
	HudDialogs.fit_session_resume_panel(panel, prompt, buttons, width)

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
	if control_uses_pixel_font(label):
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
