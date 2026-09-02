extends SceneTree
## Headless Android export preset smoke checks.
## Run: godot --headless --path . -s res://tests/run_export_smoke.gd

const ExportSmoke := preload("res://tests/support/export_smoke.gd")

func _init() -> void:
	var issues := ExportSmoke.audit()
	for issue in issues:
		printerr("export_smoke: ", issue)
	var failed := issues.size()
	print("export_smoke: %d passed, %d failed" % [1 if failed == 0 else 0, failed])
	call_deferred("quit", 1 if failed > 0 else 0)
