
class_name NativeTemplateTextStyle

var background_color: Variant  # Color or null
var text_color: Variant  # Color or null
var font_size: float = 0.0
var style: NativeTemplateFontStyle.Values = NativeTemplateFontStyle.Values.NORMAL


func convert_to_dictionary() -> Dictionary:
	return {
		"background_color":
		background_color.to_html(true) if typeof(background_color) == TYPE_COLOR else "",
		"text_color": text_color.to_html(true) if typeof(text_color) == TYPE_COLOR else "",
		"font_size": font_size,
		"style": style
	}
