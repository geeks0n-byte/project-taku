
class_name NativeTemplateStyle

const SMALL = "small"
const MEDIUM = "medium"

var template_id: String = MEDIUM  # small or medium
var main_background_color: Variant  # Color or null
var primary_text: NativeTemplateTextStyle
var secondary_text: NativeTemplateTextStyle
var tertiary_text: NativeTemplateTextStyle
var call_to_action_text: NativeTemplateTextStyle


func convert_to_dictionary() -> Dictionary:
	return {
		"template_id": template_id,
		"main_background_color":
		main_background_color.to_html(true) if typeof(main_background_color) == TYPE_COLOR else "",
		"primary_text": primary_text.convert_to_dictionary() if primary_text != null else null,
		"secondary_text":
		secondary_text.convert_to_dictionary() if secondary_text != null else null,
		"tertiary_text": tertiary_text.convert_to_dictionary() if tertiary_text != null else null,
		"call_to_action_text":
		call_to_action_text.convert_to_dictionary() if call_to_action_text != null else null
	}
