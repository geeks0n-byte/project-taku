




class_name FormError

var error_code: int
var message: String


func _init(p_error_code: int, p_message: String):
	self.error_code = p_error_code
	self.message = p_message


static func create(form_error_dictionary: Dictionary) -> FormError:
	var p_error_code = form_error_dictionary["error_code"]
	var p_message = form_error_dictionary["message"]
	return FormError.new(p_error_code, p_message)
