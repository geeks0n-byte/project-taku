
class_name AdVideoOptions

var click_to_expand_requested: bool = false
var custom_controls_requested: bool = false
var start_muted: bool = true


func convert_to_dictionary() -> Dictionary:
	return {
		"click_to_expand_requested": click_to_expand_requested,
		"custom_controls_requested": custom_controls_requested,
		"start_muted": start_muted
	}
