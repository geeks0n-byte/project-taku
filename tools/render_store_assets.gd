extends SceneTree
## Renders Play Store PNGs with the real main-menu title (PressStart2P + P/O tiles).
##
## From project root (needs a real GL driver — do NOT use --headless):
## godot --path . --rendering-method gl_compatibility --script tools/render_store_assets.gd

const Renderer = preload("res://scripts/store_asset_renderer.gd")

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ok: bool = await Renderer.render_all(self)
	quit(0 if ok else 1)
