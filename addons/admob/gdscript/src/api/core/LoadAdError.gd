




class_name LoadAdError
extends AdError

var response_info: ResponseInfo


func _init(p_response_info: ResponseInfo, p_code: int, p_domain: String, p_message: String, p_cause: AdError):
	super._init(p_code, p_domain, p_message, p_cause)
	self.response_info = p_response_info


static func create(load_ad_error_dictionary: Dictionary) -> AdError:
	if not load_ad_error_dictionary.is_empty():
		var adError := AdError.create(load_ad_error_dictionary)
		var responseInfo := ResponseInfo.create(load_ad_error_dictionary["response_info"])

		return LoadAdError.new(
			responseInfo, adError.code, adError.domain, adError.message, adError.cause
		)
	return null
