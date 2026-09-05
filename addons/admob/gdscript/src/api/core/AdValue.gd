




class_name AdValue

enum PrecisionType { UNKNOWN = 0, ESTIMATED = 1, PUBLISHER_PROVIDED = 2, PRECISE = 3 }

var currency_code: String
var precision: int
var value_micros: int


func _init(p_currency_code: String, p_precision: int, p_value_micros: int):
	self.currency_code = p_currency_code
	self.precision = p_precision
	self.value_micros = p_value_micros


static func create(ad_value_dictionary: Dictionary) -> AdValue:
	var p_currency_code: String = ad_value_dictionary["currency_code"]
	var p_precision: int = ad_value_dictionary["precision_type"]
	var p_value_micros: int = ad_value_dictionary["value_micros"]

	return AdValue.new(p_currency_code, p_precision, p_value_micros)
