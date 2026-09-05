extends RefCounted

const LogicTestRunner := preload("res://tests/logic_test_runner.gd")
const ExportSmoke := preload("res://tests/support/export_smoke.gd")

static func run(r: LogicTestRunner) -> void:
	_test_main_menu_scene(r)
	_test_export_smoke(r)


static func _test_main_menu_scene(r: LogicTestRunner) -> void:
	var packed: PackedScene = load("res://scenes/main_menu.tscn")
	r.ok(packed != null, "scene: main_menu loads")
	if packed == null:
		return
	var inst: Node = packed.instantiate()
	r.ok(inst != null, "scene: main_menu instantiates")
	if inst:
		inst.free()


static func _test_export_smoke(r: LogicTestRunner) -> void:
	var issues := ExportSmoke.audit()
	for issue in issues:
		printerr("  export: ", issue)
	r.ok(issues.is_empty(), "export: android preset smoke")
