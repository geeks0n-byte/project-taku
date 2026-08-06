




extends PopupMenu

var _callbacks := {}


func _init() -> void:
	id_pressed.connect(_on_id_pressed)


func add_menu_item(label: String, callback: Callable) -> void:
	var id := item_count
	add_item(label, id)
	_callbacks[id] = callback


func _on_id_pressed(id: int) -> void:
	if _callbacks.has(id):
		_callbacks[id].call()
