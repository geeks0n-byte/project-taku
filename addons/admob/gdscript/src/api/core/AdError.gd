




class_name AdError

var code: int
var domain: String
var message: String
var cause: AdError


func _init(p_code: int, p_domain: String, p_message: String, p_cause: AdError):
	self.code = p_code
	self.domain = p_domain
	self.message = p_message
	self.cause = p_cause


static func create(ad_error_dictionary: Dictionary) -> AdError:
	if not ad_error_dictionary.is_empty():
		var p_code: int = ad_error_dictionary["code"]
		var p_domain: String = ad_error_dictionary["domain"]
		var p_message: String = ad_error_dictionary["message"]
		var p_cause := AdError.create(ad_error_dictionary["cause"])

		return AdError.new(p_code, p_domain, p_message, p_cause)
	return null
