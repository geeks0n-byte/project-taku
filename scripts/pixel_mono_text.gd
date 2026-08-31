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
