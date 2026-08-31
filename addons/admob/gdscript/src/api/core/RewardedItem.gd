




class_name RewardedItem

var amount: int
var type: String


func _init(p_amount: int, p_type: String):
	self.amount = p_amount
	self.type = p_type


static func create(rewarded_item_dictionary: Dictionary) -> RewardedItem:
	if not rewarded_item_dictionary.is_empty():
		var p_amount: int = rewarded_item_dictionary["amount"]
		var p_type: String = rewarded_item_dictionary["type"]

		return RewardedItem.new(p_amount, p_type)
	return null
