class_name LogicTestRunner
extends RefCounted

var passed := 0
var failed := 0
var root: Window = null

func ok(cond: bool, name: String) -> void:
	if cond:
		passed += 1
		print("  PASS  ", name)
	else:
		failed += 1
		printerr("  FAIL  ", name)

func grid(w: int, h: int, fill: Callable) -> Dictionary:
	var layout := {}
	for y in h:
		for x in w:
			layout[Vector2i(x, y)] = fill.call(x, y)
	return layout
