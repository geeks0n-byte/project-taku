extends Control
## Draws Press Start (and similar) on a fixed cell grid, cancelling left bearings
## so pairs like P–L / A–Y don't open uneven gaps.

var text: String = ""
var font_size: int = 64
var font_color: Color = Color.WHITE
var font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_notify_transform(true)

func set_mono_text(p_text: String, p_font: Font, p_size: int, p_color: Color = Color.WHITE) -> void:
	text = p_text
	font = p_font
	font_size = p_size
	font_color = p_color
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if font == null or text.is_empty() or font_size <= 0:
		return
	var cell := float(font_size)
	var total_w := cell * float(text.length())
	var x := (size.x - total_w) * 0.5
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var baseline := (size.y + ascent - descent) * 0.5
	var ci := get_canvas_item()
	for i in text.length():
		var code: int = text.unicode_at(i)
		if code == 32:
			x += cell
			continue
		var glyph: int = font.get_glyph_index(font_size, code, 0)
		var offset: Vector2 = Vector2.ZERO
		if font is FontFile:
			offset = (font as FontFile).get_glyph_offset(0, Vector2i(font_size, 0), glyph)
		# Cancel left bearing so every glyph sits on the same pixel grid.
		font.draw_char(ci, Vector2(x - offset.x, baseline), code, font_size, font_color)
		x += cell
