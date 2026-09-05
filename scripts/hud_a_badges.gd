class_name HudBadges
extends RefCounted
## Notification badge builders extracted from HudLayout.

const NOTIFICATION_BADGE_TEXT := "!"
const NOTIFICATION_BADGE_FONT := 24
const NOTIFICATION_BADGE_RED := Color(0.92, 0.22, 0.18, 1.0)
const LEVEL_CARD_BADGE_HOST_H := 240.0

## Red "!" without a panel background (main menu buttons).
static func build_plain_notification_badge(host_h: float = -1.0) -> Label:
	var label := Label.new()
	label.set_meta("_notification_badge", true)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.visible = false
	var font_px := plain_notification_badge_font_size(host_h)
	HudLocale.apply_raster_pixel_label(
		label, NOTIFICATION_BADGE_TEXT, font_px, NOTIFICATION_BADGE_RED, 0, true
	)
	return label


static func refresh_plain_notification_badge(label: Label, host_h: float = -1.0) -> void:
	if label == null:
		return
	var font_px := plain_notification_badge_font_size(host_h)
	HudLocale.apply_raster_pixel_label(
		label, NOTIFICATION_BADGE_TEXT, font_px, NOTIFICATION_BADGE_RED, 0, true
	)


static func plain_notification_badge_font_size(host_h: float = -1.0) -> int:
	if host_h > 1.0:
		return int(clampf(host_h * 0.38, 28.0, 40.0))
	return NOTIFICATION_BADGE_FONT


static func plain_notification_badge_size(host_h: float) -> Vector2:
	var px := plain_notification_badge_font_size(host_h)
	return Vector2(px * 0.55, px)


## Pins a plain red "!" badge to the top-right corner (achievements, level cards).
static func attach_plain_notification_badge_corner(
	parent: Control,
	host_h: float,
	inset_right: float = 2.0,
	inset_top: float = 2.0
) -> Label:
	var badge := build_plain_notification_badge(host_h)
	badge.name = "NewBadge"
	var dims := plain_notification_badge_size(host_h)
	parent.add_child(badge)
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -dims.x - inset_right
	badge.offset_top = inset_top
	badge.offset_right = -inset_right
	badge.offset_bottom = inset_top + dims.y
	badge.z_index = 2
	badge.visible = true
	return badge


## Red "!" pinned to the top-right inside a level card (campaign unseen badge).
static func attach_level_new_badge(
	content: Control, inset_right: float, inset_top: float
) -> Label:
	return attach_plain_notification_badge_corner(
		content, LEVEL_CARD_BADGE_HOST_H, inset_right, inset_top
	)


## Builds a red circular "!" badge panel + label for level cards.
static func build_notification_badge() -> Dictionary:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = NOTIFICATION_BADGE_RED
	style.set_corner_radius_all(999)
	style.set_content_margin(SIDE_LEFT, 4)
	style.set_content_margin(SIDE_RIGHT, 4)
	style.set_content_margin(SIDE_TOP, 2)
	style.set_content_margin(SIDE_BOTTOM, 2)
	style.set_border_width_all(2)
	style.border_color = Color(0, 0, 0, 0.85)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.set_meta("_notification_badge", true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(label)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	HudLocale.apply_raster_pixel_label(label, NOTIFICATION_BADGE_TEXT, NOTIFICATION_BADGE_FONT, Color.WHITE, 0, true)
	return {"panel": panel, "label": label}


## Keeps a menu/card notification badge showing "!" (never a numeric count).
static func refresh_notification_badge(panel: Panel) -> void:
	if panel == null:
		return
	for child in panel.get_children():
		if child is Label:
			HudLocale.apply_raster_pixel_label(
				child as Label, NOTIFICATION_BADGE_TEXT, NOTIFICATION_BADGE_FONT, Color.WHITE, 0, true
			)
			return


## Badge width/height for a host control height (menu row or level card).
static func notification_badge_size(host_h: float) -> Vector2:
	var badge_h := clampf(host_h * 0.34, 32.0, 44.0)
	var badge_w := maxf(badge_h, badge_h * 0.72 * float(NOTIFICATION_BADGE_TEXT.length()))
	return Vector2(badge_w, badge_h)


## Pins a badge to the top-right corner of a card-style control.
static func attach_notification_badge_corner(parent: Control, host_h: float = -1.0) -> Panel:
	var built := build_notification_badge()
	var panel: Panel = built["panel"]
	var h := host_h if host_h > 1.0 else parent.custom_minimum_size.y
	var dims := notification_badge_size(h)
	parent.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_right = -8.0
	panel.offset_top = 8.0
	panel.offset_left = -8.0 - dims.x
	panel.offset_bottom = 8.0 + dims.y
	panel.z_index = 2
	return panel


# Creates the near-opaque dark panel StyleBox used by all confirmation dialogs
# (reset progress, session resume, etc.). Gold border gives it a premium feel.
