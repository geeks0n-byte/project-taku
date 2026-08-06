
extends VBoxContainer

const UIScaler = preload("res://addons/admob/gdscript/sample/UIScaler.gd")


func _ready() -> void:
	_optimize_for_scrolling(self)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()


func _on_viewport_size_changed() -> void:
	var vp := get_viewport_rect().size
	var win_size := get_window().size
	if vp.x <= 0 or vp.y <= 0 or win_size.x <= 0 or win_size.y <= 0:
		return

	var scale_factor := vp.y / float(win_size.y)
	var window_factor: float = (float(win_size.x) + float(win_size.y)) / 1140.0
	var total_factor: float = window_factor * scale_factor

	UIScaler.scale_ui(self, total_factor, scale_factor)


func _optimize_for_scrolling(node: Node) -> void:
	if node is Control:
		var is_interactive := (
			node is Button
			or node is LineEdit
			or node is TextEdit
			or node is Slider
			or node is OptionButton
			or node is CheckButton
			or node is CheckBox
			or node is ColorPickerButton
			or node is MenuButton
		)
		if not is_interactive:
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for child in node.get_children():
		_optimize_for_scrolling(child)
