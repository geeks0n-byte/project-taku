




class_name ResponseInfo

var loaded_adapter_response_info: AdapterResponseInfo
var adapter_responses: Array[AdapterResponseInfo]
var response_extras: Dictionary
var mediation_adapter_class_name: String
var response_id: String


func _init(
	p_loaded_adapter_response_info: AdapterResponseInfo,
	p_adapter_responses: Array[AdapterResponseInfo],
	p_response_extras: Dictionary,
	p_mediation_adapter_class_name: String,
	p_response_id: String
):
	self.loaded_adapter_response_info = p_loaded_adapter_response_info
	self.adapter_responses = p_adapter_responses
	self.response_extras = p_response_extras
	self.mediation_adapter_class_name = p_mediation_adapter_class_name
	self.response_id = p_response_id


static func create(response_info_dictionary: Dictionary) -> ResponseInfo:
	if not response_info_dictionary.is_empty():
		var p_loaded_adapter_response_info := AdapterResponseInfo.create(
			response_info_dictionary["loaded_adapter_response_info"]
		)
		var p_adapter_responses := AdapterResponseInfo.create_adapter_responses(
			response_info_dictionary["adapter_responses"]
		)
		var p_response_extras: Dictionary = response_info_dictionary["response_extras"]
		var p_mediation_adapter_class_name: String = response_info_dictionary["mediation_adapter_class_name"]
		var p_response_id: String = response_info_dictionary["response_id"]

		return ResponseInfo.new(
			p_loaded_adapter_response_info,
			p_adapter_responses,
			p_response_extras,
			p_mediation_adapter_class_name,
			p_response_id
		)
	return null
