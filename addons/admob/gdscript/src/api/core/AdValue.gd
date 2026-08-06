




class_name AdValue

enum PrecisionType { UNKNOWN = 0, ESTIMATED = 1, PUBLISHER_PROVIDED = 2, PRECISE = 3 }

var currency_code: String
var precision: int
var value_micros: int


func _init(currency_code: String, precision: int, value_micros: int):
	self.currency_code = currency_code
	self.precision = precision
	self.value_micros = value_micros


static func create(ad_value_dictionary: Dictionary) -> AdValue:
	var currency_code: String = ad_value_dictionary["currency_code"]
	var precision: int = ad_value_dictionary["precision_type"]
	var value_micros: int = ad_value_dictionary["value_micros"]

	return AdValue.new(currency_code, precision, value_micros)
