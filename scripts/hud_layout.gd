# Static utility library — no scene node needed. All layout and font helpers
# live here so every HUD scene can share the same logic without duplicating code.
class_name HudLayout
extends RefCounted

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
const UI_TILE_BUTTON_H_PAD := 96.0
const UI_TILE_BUTTON_V_PAD := 40.0
const UI_TILE_BUTTON_MIN_HEIGHT := 118.0
const UI_TILE_BUTTON_PREFER_WRAP_WIDTH := 560.0
const UI_TILE_BUTTON_MAX_LINES := 2
const PIXEL_FONT_PATH := HudFonts.PIXEL_FONT_PATH
const PIXEL_FONT: Font = HudFonts.PIXEL_FONT

## Usable content width inside centered overlays (viewport minus side margins).
static func max_ui_content_width(extra_margin: float = UI_SAFE_SIDE_MARGIN) -> float:
	return HudSafeArea.max_ui_content_width(extra_margin)

## Clamps a generic UI width between the dialog minimum and the viewport content max.
static func clamp_ui_width(width: float, extra_margin: float = UI_SAFE_SIDE_MARGIN) -> float:
	return HudSafeArea.clamp_ui_width(width, extra_margin)

## Clamps a dialog panel's outer width to the viewport (uses tighter side margins).
static func clamp_dialog_panel_width(width: float) -> float:
	return HudSafeArea.clamp_dialog_panel_width(width)

## Inner content width for a dialog panel with symmetric vbox insets.
static func dialog_content_width(
	panel_width: float, horizontal_inset: float = HudDialogs.DIALOG_EDGE_INSET * 2.0
) -> float:
	return HudSafeArea.dialog_content_width(panel_width, horizontal_inset)

## Single-line width of a label's current text (locale-aware, respects label_settings).
static func measure_label_min_width(label: Label) -> float:
	return HudDialogs.measure_label_min_width(label)

## Caps width to the viewport without applying the dialog minimum (for buttons/controls).
static func cap_ui_width(width: float, extra_margin: float = UI_SAFE_SIDE_MARGIN) -> float:
	return HudSafeArea.cap_ui_width(width, extra_margin)

## Extra inset on each side so a stretched control is at most max_width. 0 on phones.
static func extra_side_inset_for_cap(current_width: float, max_width: float) -> float:
	return HudSafeArea.extra_side_inset_for_cap(current_width, max_width)

## Centers a left-right stretched Control so it never exceeds max_width.
static func cap_stretched_width(control: Control, max_width: float = UI_PHONE_CONTENT_WIDTH) -> void:
	HudSafeArea.cap_stretched_width(control, max_width)

## On viewports wider than max_width, shrink-center a fill row; restore phone flags otherwise.
static func cap_box_row_width(row: Control, max_width: float = UI_PHONE_EDITOR_ROW_WIDTH) -> void:
	HudSafeArea.cap_box_row_width(row, max_width)

## Invisible cells needed so the last GridContainer row keeps the same column count.
static func grid_row_pad_count(item_count: int, columns: int) -> int:
	return HudSafeArea.grid_row_pad_count(item_count, columns)

static func _layout_parent_width(control: Control) -> float:
	return HudSafeArea.layout_parent_width(control)

## Shifts a top-anchored HUD bar (and optional counter row) below the status bar / cutout.
static func apply_top_hud_safe_area(top_bar: Control, counter: Control = null) -> void:
	HudSafeArea.apply_top_hud_safe_area(top_bar, counter)

## Lifts a bottom-anchored panel above the nav bar / home indicator.
static func apply_bottom_bar_safe_area(control: Control) -> void:
	HudSafeArea.apply_bottom_bar_safe_area(control)

## Pads a full-rect content host so authored top/bottom/side offsets clear system bars.
static func apply_content_edge_safe_area(control: Control) -> void:
	HudSafeArea.apply_content_edge_safe_area(control)

static func position_top_wide(control: Control, top: float, height: float, margin: float = GameConstants.HUD_SIDE_MARGIN) -> void:
	HudSafeArea.position_top_wide(control, top, height, margin)

static func position_status_below_board(status: Control, board_y: float, board_height: float) -> void:
	HudSafeArea.position_status_below_board(status, board_y, board_height)

static func position_editor_status_below_panel(control_panel: Control, status: Control) -> void:
	HudSafeArea.position_editor_status_below_panel(control_panel, status)

static func position_counter_row(counter_row: Control) -> void:
	HudSafeArea.position_counter_row(counter_row)

static func align_counter_row(counter_row: Control) -> void:
	HudSafeArea.align_counter_row(counter_row)

# Cached fallback font reference so we don't call HudFonts.default_font() on every frame.
# Returns the font to use for screen headers. Press Start except ka/uk;
# all other locales fall back to the theme's default scalable font.
static func screen_header_font(force_pixel: bool = false) -> Font:
	return HudHeaders.screen_header_font(force_pixel)

static func _is_message_key(text: String) -> bool:
	return HudHeaders.is_message_key(text)

static func _is_i18n_key(text: String) -> bool:
	return HudHeaders.is_i18n_key(text)

static func apply_screen_header_style(label: Label) -> void:
	HudHeaders.apply_screen_header_style(label)

static func apply_end_screen_header_style(label: Label, base_size: int = 48) -> void:
	HudHeaders.apply_end_screen_header_style(label, base_size)

static func _bind_header_translation_key(label: Label, key: String) -> void:
	HudHeaders._bind_header_translation_key(label, key)

static func clear_how_to_play_nav_lock(host: Control) -> void:
	HudPageNav.clear_how_to_play_nav_lock(host)

static func page_nav_bottom_inset(reserve_menu_banner: bool = false) -> float:
	return HudPageNav.page_nav_bottom_inset(reserve_menu_banner)

static func page_nav_content_bottom_offset(reserve_menu_banner: bool = false) -> float:
	return HudPageNav.page_nav_content_bottom_offset(reserve_menu_banner)

static func pin_page_nav_row(
	nav: Control,
	host: Control,
	reserve_menu_banner: bool = false,
	horizontal_inset: float = 40.0
) -> void:
	HudPageNav.pin_page_nav_row(nav, host, reserve_menu_banner, horizontal_inset)

static func sync_page_nav_slots(prev_button: Button, next_button: Button) -> void:
	HudPageNav.sync_page_nav_slots(prev_button, next_button)

static func layout_how_to_play_stack(
	host: Control,
	panel: Control,
	rules: RichTextLabel,
	nav: Control,
	_update_nav_lock: bool = false,
	reserve_menu_banner: bool = false
) -> void:
	HudPageNav.layout_how_to_play_stack(host, panel, rules, nav, _update_nav_lock, reserve_menu_banner)

static func apply_top_bar_tile_styles(button: Button) -> void:
	HudTopBar.apply_top_bar_tile_styles(button)

static func ensure_top_bar_icon(button: Button, texture: Texture2D) -> void:
	HudTopBar.ensure_top_bar_icon(button, texture)

static func style_screen_header_close_button(button: Button) -> void:
	HudTopBar.style_screen_header_close_button(button)

static func style_top_bar_close_button(button: Button) -> void:
	HudTopBar.style_top_bar_close_button(button)

# Returns the English translation of an i18n key regardless of the active locale.
# Used by the editor preview and forced-English paths to get consistent layout metrics.
static func english(key: String) -> String:
	return HudHeaders.english(key)

static func translate_status_text(msg: String, force_english: bool = false) -> String:
	return HudHeaders.translate_status_text(msg, force_english)

static func break_after_sentences(text: String) -> String:
	return HudHeaders.break_after_sentences(text)

static func format_centered_status(msg: String, force_english: bool = false) -> String:
	return HudHeaders.format_centered_status(msg, force_english)

static func font_scale() -> float:
	return HudFonts.font_scale()

static func scaled_font_size(base: int) -> int:
	return HudFonts.scaled_font_size(base)

static func body_font_size(base: int) -> int:
	return HudFonts.body_font_size(base)

static func snap_pixel_font_size(size: int) -> int:
	return HudFonts.snap_pixel_font_size(size)

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

## Nested counter: treat UI as Press Start until a matching end_force_pixel_font.
static func begin_force_pixel_font() -> void:
	HudFonts.begin_force_pixel_font()

## Pops one begin_force_pixel_font nesting level.
static func end_force_pixel_font() -> void:
	HudFonts.end_force_pixel_font()

## Press Start 2P (or engine fallback) via HudFonts.
static func pixel_font() -> Font:
	return HudFonts.pixel_font()

## Same face as pixel_font — alias kept for older call sites.
static func pixel_font_clean() -> Font:
	return HudFonts.pixel_font_clean()

# True when the current locale uses Press Start; callers use this to decide
# whether to create a pixel caption overlay instead of using the theme font.
static func needs_pixel_text_raster() -> bool:
	return HudFonts.needs_pixel_text_raster()

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
	HudLocale.apply_live_pixel_label_settings(label, text, font_size, color)

static func clear_label_settings(label: Label) -> void:
	HudLocale.clear_label_settings(label)

static func apply_live_pixel_richtext(label: RichTextLabel, font_size: int) -> void:
	HudLocale.apply_live_pixel_richtext(label, font_size)

static func _strip_live_pixel_outline(control: Control) -> void:
	HudLocale._strip_live_pixel_outline(control)

static func _is_live_pixel_control(control: Control) -> bool:
	return HudLocale._is_live_pixel_control(control)

static func has_pixel_text_overlay(host: Control) -> bool:
	return HudLocale.has_pixel_text_overlay(host)

static func _clear_pixel_raster(host: Control) -> void:
	HudLocale._clear_pixel_raster(host)

static func apply_pixel_mono_button(
	button: Button, text: String, font_size: int, color: Color = Color.WHITE
) -> void:
	HudLocale.apply_pixel_mono_button(button, text, font_size, color)

static func apply_raster_pixel_label(
	label: Label,
	text: String,
	font_size: int,
	color: Color = Color.WHITE,
	_max_width: int = 0,
	force_pixel: bool = false
) -> void:
	HudLocale.apply_raster_pixel_label(label, text, font_size, color, _max_width, force_pixel)

static func apply_raster_pixel_button(
	button: Button, text: String, font_size: int, _max_width: int = 0, force_pixel: bool = false
) -> void:
	HudLocale.apply_raster_pixel_button(button, text, font_size, _max_width, force_pixel)

static func ui_font() -> Font:
	return HudFonts.ui_font()

## Visible/copy string for font routing (translates i18n keys when needed).
static func _resolved_control_text(node: Node) -> String:
	return HudLocale._resolved_control_text(node)

static func is_status_label(node: Node) -> bool:
	return HudLocale.is_status_label(node)

static func apply_status_font(label: RichTextLabel, base_size: int = GameConstants.HUD_STATUS_FONT_SIZE) -> void:
	HudLocale.apply_status_font(label, base_size)

static func apply_locale_font_to_control(node: Node) -> void:
	HudLocale.apply_locale_font_to_control(node)

static func _is_icon_only_button(node: Node) -> bool:
	return HudLocale._is_icon_only_button(node)

static func _apply_forced_pixel_font(node: Node) -> void:
	HudLocale._apply_forced_pixel_font(node)

static func is_applying_locale_fonts() -> bool:
	return HudLocale.is_applying_locale_fonts()

static func apply_locale_fonts_to_tree(root: Node) -> void:
	HudLocale.apply_locale_fonts_to_tree(root)

static func _apply_locale_fonts_to_tree_inner(root: Node) -> void:
	HudLocale._apply_locale_fonts_to_tree_inner(root)

static func _button_label_display(button: Button) -> Dictionary:
	return HudButtons._button_label_display(button)

static func fit_text_button(button: Button, base_font_size: int = 36, min_font_size: int = 18) -> void:
	HudButtons.fit_text_button(button, base_font_size, min_font_size)

static func fit_text_button_single_line(button: Button, base_font_size: int = 36, min_font_size: int = 18) -> void:
	HudButtons.fit_text_button_single_line(button, base_font_size, min_font_size)

static func _is_mobile_ui() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		return true
	var os_name := OS.get_name()
	return os_name == "Android" or os_name == "iOS"

# Returns true when the current locale should use the scalable theme font instead of Press Start.
static func prefer_default_font() -> bool:
	return HudButtons.prefer_default_font()

static func apply_safe_outline(control: Control, base_outline: int = GameConstants.MENU_TEXT_OUTLINE) -> void:
	HudButtons.apply_safe_outline(control, base_outline)

static func apply_primary_button(button: Button) -> void:
	HudButtons.apply_primary_button(button)

static func apply_secondary_button(button: Button) -> void:
	HudButtons.apply_secondary_button(button)

static func apply_dialog_button(button: Button, display_override: String = "") -> void:
	HudButtons.apply_dialog_button(button, display_override)

static func apply_dialog_button_fitted(
	button: Button,
	min_width: float = -1.0
) -> void:
	HudButtons.apply_dialog_button_fitted(button, min_width)

static func fit_dialog_button_group(
	buttons: Array,
	equal_width: bool = true,
	min_width: float = GameConstants.UI_BTN_DIALOG_SIZE.x,
	height: float = GameConstants.UI_BTN_DIALOG_SIZE.y,
	max_total_width: float = -1.0
) -> void:
	HudButtons.fit_dialog_button_group(buttons, equal_width, min_width, height, max_total_width)

static func equalize_button_group_widths(
	buttons: Array,
	min_width: float = 160.0,
	height: float = -1.0,
	max_total_width: float = -1.0
) -> void:
	HudButtons.equalize_button_group_widths(buttons, min_width, height, max_total_width)

static func measure_dialog_button_min_width(
	button: Button, horizontal_padding: float = 48.0
) -> float:
	return HudButtons.measure_dialog_button_min_width(button, horizontal_padding)

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
	return HudButtons.compute_tile_button_size(display, font, font_size, column_w, min_width, min_height, h_pad, v_pad)

static func compute_tile_button_single_line_size(
	display: String,
	font: Font,
	font_size: int,
	min_width: float = 280.0,
	min_height: float = UI_TILE_BUTTON_MIN_HEIGHT,
	h_pad: float = UI_TILE_BUTTON_H_PAD,
	v_pad: float = UI_TILE_BUTTON_V_PAD
) -> Vector2:
	return HudButtons.compute_tile_button_single_line_size(display, font, font_size, min_width, min_height, h_pad, v_pad)

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
	HudButtons.apply_tile_button_single_line_size(button, display, font, font_size, min_height, min_width, h_pad, v_pad)

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
	HudButtons.apply_tile_button_size(button, display, font, font_size, column_w, min_height, min_width, h_pad, v_pad)

static func grow_button_to_text(
	button: Button,
	height: float,
	horizontal_padding: float = 48.0,
	min_width: float = 160.0
) -> void:
	HudButtons.grow_button_to_text(button, height, horizontal_padding, min_width)

static func grow_dialog_button_to_text(button: Button, horizontal_padding: float = 48.0) -> void:
	HudButtons.grow_dialog_button_to_text(button, horizontal_padding)

static func grow_panel_button_to_text(button: Button, horizontal_padding: float = 48.0) -> void:
	HudButtons.grow_panel_button_to_text(button, horizontal_padding)

static func apply_nav_button(button: Button) -> void:
	HudTopBar.apply_nav_button(button)

# Styles a "panel" button (victory screen: Next Level, Play Again, Main Menu).
# Height is UI_BTN_PANEL_SIZE.y; width grows to the label with that size as a minimum.
# Latin/digits/symbols use Press Start even in ka/uk; native-script copy uses Noto.
static func apply_panel_button(button: Button) -> void:
	HudButtons.apply_panel_button(button)

static func apply_tile_button(
	button: Button,
	texture: Texture2D,
	font_size: int = 52,
	height: float = 118.0
) -> void:
	HudButtons.apply_tile_button(button, texture, font_size, height)

static func apply_tab_button(button: Button) -> void:
	HudButtons.apply_tab_button(button)

static func apply_popup_label(label: Label, base_size: int = GameConstants.UI_BODY_FONT_SIZE) -> void:
	HudPopups.apply_popup_label(label, base_size)

static func text_is_digit_display(text: String) -> bool:
	return HudPopups.text_is_digit_display(text)

static func apply_popup_title_with_number(
	label: RichTextLabel, prefix: String, num_str: String, base_size: int, color: Color
) -> void:
	HudPopups.apply_popup_title_with_number(label, prefix, num_str, base_size, color)

static func _popup_prompt_with_title_gap(text: String, use_pixel_gap: bool = false) -> String:
	return HudPopups._popup_prompt_with_title_gap(text, use_pixel_gap)

static func build_plain_notification_badge(host_h: float = -1.0) -> Label:
	return HudBadges.build_plain_notification_badge(host_h)

static func refresh_plain_notification_badge(label: Label, host_h: float = -1.0) -> void:
	HudBadges.refresh_plain_notification_badge(label, host_h)

static func plain_notification_badge_font_size(host_h: float = -1.0) -> int:
	return HudBadges.plain_notification_badge_font_size(host_h)

static func plain_notification_badge_size(host_h: float) -> Vector2:
	return HudBadges.plain_notification_badge_size(host_h)

static func attach_plain_notification_badge_corner(
	parent: Control, host_h: float, inset_right: float = 2.0, inset_top: float = 2.0
) -> Label:
	return HudBadges.attach_plain_notification_badge_corner(
		parent, host_h, inset_right, inset_top
	)

static func build_notification_badge() -> Dictionary:
	return HudBadges.build_notification_badge()

static func refresh_notification_badge(panel: Panel) -> void:
	HudBadges.refresh_notification_badge(panel)

static func notification_badge_size(host_h: float) -> Vector2:
	return HudBadges.notification_badge_size(host_h)

static func attach_notification_badge_corner(parent: Control, host_h: float = -1.0) -> Panel:
	return HudBadges.attach_notification_badge_corner(parent, host_h)

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

## Sizes the continue-run dialog; forwards to HudDialogs.
static func fit_session_resume_panel(
	panel: Panel, prompt: Label, buttons: Control, width: float = 820.0
) -> void:
	HudDialogs.fit_session_resume_panel(panel, prompt, buttons, width)

# Applies the locale-correct body font to a plain Label. Always uses the scalable
# font (not Press Start), suitable for longer readable text blocks.
static func apply_body_label(label: Label, base_size: int = GameConstants.UI_BODY_FONT_SIZE) -> void:
	HudLocale.apply_body_label(label, base_size)

static func apply_body_richtext(
	label: RichTextLabel, base_size: int = GameConstants.UI_BODY_FONT_SIZE
) -> void:
	HudLocale.apply_body_richtext(label, base_size)

static func apply_toggle_active_mask(button: Button, is_on: bool, tint: Color = GameConstants.TOGGLE_MASK_AMBER) -> void:
	HudButtons.apply_toggle_active_mask(button, is_on, tint)

static func start_toggle_mask_breathe(button: Button) -> void:
	HudButtons.start_toggle_mask_breathe(button)

static func stop_toggle_mask_breathe(button: Button) -> void:
	HudButtons.stop_toggle_mask_breathe(button)

static func start_button_attention_pulse(button: Button) -> void:
	HudButtons.start_button_attention_pulse(button)

static func stop_button_attention_pulse(button: Button) -> void:
	HudButtons.stop_button_attention_pulse(button)

static func refresh_button_icon_modulate(button: Button) -> void:
	HudTopBar.refresh_button_icon_modulate(button)

static func format_mode_label(translation_key: String, force_english: bool = false) -> String:
	return HudTopBar.format_mode_label(translation_key, force_english)

static func format_outlined_center_text(body: String) -> String:
	return HudTopBar.format_outlined_center_text(body)

# Internal translation helper that supports forced-English mode for the editor preview.
static func _tr(key: String, force_english: bool = false) -> String:
	return HudHeaders.translate_key(key, force_english)

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
	HudTopBar.apply_square_top_bar_button(button)

static func apply_top_bar_button_cluster(cluster: HBoxContainer) -> void:
	HudTopBar.apply_top_bar_button_cluster(cluster)

static func nudge_button_icon_up(button: Button, pixels: int = 1) -> void:
	HudTopBar.nudge_button_icon_up(button, pixels)

static func apply_top_bar_mode_label(label: RichTextLabel) -> void:
	HudTopBar.apply_top_bar_mode_label(label)

static func apply_level_label(label: RichTextLabel, prefix: String, num: int) -> void:
	HudTopBar.apply_level_label(label, prefix, num)

static func fit_top_bar_level_font_size(prefix: String, num: int) -> int:
	return HudTopBar.fit_top_bar_level_font_size(prefix, num)

static func fit_top_bar_two_line_font_size(body: String) -> int:
	return HudTopBar.fit_top_bar_two_line_font_size(body)

static func align_counter_label(label: RichTextLabel, _y_nudge: float = 0.0) -> void:
	HudTopBar.align_counter_label(label, _y_nudge)

static func prepare_timer_label(label: RichTextLabel) -> void:
	HudTopBar.prepare_timer_label(label)

static func set_timer_raster_text(label: RichTextLabel, plain_time: String) -> void:
	HudTopBar.set_timer_raster_text(label, plain_time)

static func prepare_counter_label(label: RichTextLabel) -> void:
	HudTopBar.prepare_counter_label(label)

static func format_icon_ratio_counter(
	icon_path: String,
	current: int,
	required: int,
	accent: Color = Color.WHITE,
	caption: String = ""
) -> String:
	return HudTopBar.format_icon_ratio_counter(icon_path, current, required, accent, caption)

static func format_time_counter(formatted_time: String, _label_text: String = "") -> String:
	return HudTopBar.format_time_counter(formatted_time, _label_text)
