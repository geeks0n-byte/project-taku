




class_name AdapterResponseInfo

var adapter_class_name: String
var ad_source_id: String
var ad_source_name: String
var ad_source_instance_id: String
var ad_source_instance_name: String
var ad_unit_mapping: Dictionary
var ad_error: AdError
var latency_millis: int


func _init(
	p_adapter_class_name: String,
	p_ad_source_id: String,
	p_ad_source_name: String,
	p_ad_source_instance_id: String,
	p_ad_source_instance_name: String,
	p_ad_unit_mapping: Dictionary,
	p_ad_error: AdError,
	p_latency_millis: int
):
	self.adapter_class_name = p_adapter_class_name
	self.ad_source_id = p_ad_source_id
	self.ad_source_name = p_ad_source_name
	self.ad_source_instance_id = p_ad_source_instance_id
	self.ad_source_instance_name = p_ad_source_instance_name
	self.ad_unit_mapping = p_ad_unit_mapping
	self.ad_error = p_ad_error
	self.latency_millis = p_latency_millis


static func create(adapter_response_info_dictionary: Dictionary) -> AdapterResponseInfo:
	if not adapter_response_info_dictionary.is_empty():
		var p_adapter_class_name: String = adapter_response_info_dictionary["adapter_class_name"]
		var p_ad_source_id: String = adapter_response_info_dictionary["ad_source_id"]
		var p_ad_source_name: String = adapter_response_info_dictionary["ad_source_name"]
		var p_ad_source_instance_id: String = adapter_response_info_dictionary["ad_source_instance_id"]
		var p_ad_source_instance_name: String = adapter_response_info_dictionary["ad_source_instance_name"]
		var p_ad_unit_mapping: Dictionary = adapter_response_info_dictionary["ad_unit_mapping"]
		var p_ad_error := AdError.create(adapter_response_info_dictionary["ad_error"])
		var p_latency_millis: int = adapter_response_info_dictionary["latency_millis"]

		return AdapterResponseInfo.new(
			p_adapter_class_name,
			p_ad_source_id,
			p_ad_source_name,
			p_ad_source_instance_id,
			p_ad_source_instance_name,
			p_ad_unit_mapping,
			p_ad_error,
			p_latency_millis
		)
	return null


static func create_adapter_responses(
	adapter_responses_dictionary: Dictionary
) -> Array[AdapterResponseInfo]:
	var array: Array[AdapterResponseInfo]

	for key in adapter_responses_dictionary:
		var adapter_response_info_dictionary = adapter_responses_dictionary[key] as Dictionary
		array.append(AdapterResponseInfo.create(adapter_response_info_dictionary))

	return array
