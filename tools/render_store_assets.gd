extends SceneTree

const Renderer = preload("res://scripts/store_asset_renderer.gd")

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok: bool = await Renderer.render_all(self)
	quit(0 if ok else 1)
