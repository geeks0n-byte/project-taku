extends Control
## Draws Press Start (and similar) centered in this control using the font's
## natural glyph advances — no fixed per-character cell width.

var text: String = ""
var font_size: int = 64
var font_color: Color = Color.WHITE
var font: Font

## Ignores mouse hits and listens for ancestor transforms so the glyph stays centered.
func _ready() -> void:
	# This node is purely decorative; it should never block pointer events.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Needed so _notification fires on parent transforms, keeping layout responsive.
	set_notify_transform(true)

## Sets all text properties at once and triggers a redraw.
## Call this instead of setting individual vars to avoid partial-state redraws.
func set_mono_text(p_text: String, p_font: Font, p_size: int, p_color: Color = Color.WHITE) -> void:
	text = p_text
	font = p_font
	font_size = p_size
	font_color = p_color
	queue_redraw()

## Redraws when this control is resized (transform changes also notify).
func _notification(what: int) -> void:
	# Also fires for NOTIFICATION_TRANSFORM_CHANGED (enabled via set_notify_transform)
	# so the label redraws when an ancestor moves or scales it.
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

## Local X of the last glyph's trailing edge (centered mono text).
## Uses the same get_string_size() path as _draw() — do not query TextServer
## glyph indexes (Font.get_rid() can be null for this pixel font).
## Pass [param host_width] when the control's own width is not laid out yet.
func text_trailing_local_x(host_width: float = -1.0) -> float:
	var host_w := host_width if host_width > 1.0 else size.x
	if font == null or text.is_empty() or font_size <= 0 or host_w <= 0.0:
		return host_w * 0.5
	return ink_trailing_x_for_centered_text(text, font, font_size, host_w)


## Shared helper for centered Press Start / mono labels.
static func ink_trailing_x_for_centered_text(
	p_text: String, p_font: Font, p_font_size: int, host_w: float
) -> float:
	if p_text.is_empty() or p_font == null or p_font_size <= 0 or host_w <= 0.0:
		return host_w * 0.5
	var block_w := p_font.get_string_size(
		p_text, HORIZONTAL_ALIGNMENT_LEFT, -1, p_font_size
	).x
	return (host_w + block_w) * 0.5


## Centers the string with natural glyph advances rather than a fixed cell width.
func _draw() -> void:
	if font == null or text.is_empty() or font_size <= 0:
		return
	var total_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	# Center the full string block horizontally within the control's bounds.
	var x := (size.x - total_w) * 0.5
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	# Vertically center using the font metrics so the visual midpoint aligns with the control center.
	var baseline := (size.y + ascent - descent) * 0.5
	font.draw_string(
		get_canvas_item(),
		Vector2(x, baseline),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		font_color
	)
