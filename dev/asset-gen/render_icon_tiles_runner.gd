extends Node

# Export Godot-imported tile bitmaps (128×128) for Python to downscale identically to in-game cells.

const OUT_DIR := "res://resources/icons/_godot_tile_raster/"
const TILE_FILES := [
	"tile_shifter.svg",
	"tile_yellow.svg",
	"tile_blue.svg",
	"tile_green.svg",
]


func _ready() -> void:
	call_deferred("_export")


func _export() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for file_name in TILE_FILES:
		var path := "res://resources/tiles/%s" % file_name
		var tex: Texture2D = load(path)
		if tex == null:
			push_error("IconTileRaster: failed to load %s" % path)
			get_tree().quit(1)
			return
		var img: Image = tex.get_image()
		if img == null or img.is_empty():
			push_error("IconTileRaster: empty image for %s" % path)
			get_tree().quit(1)
			return
		var out_path := OUT_DIR.path_join(file_name.replace(".svg", ".png"))
		var err := img.save_png(out_path)
		if err != OK:
			push_error("IconTileRaster: save failed (%s) -> %s" % [err, out_path])
			get_tree().quit(1)
			return
		print("IconTileRaster: wrote ", out_path, " (", img.get_width(), "x", img.get_height(), ")")
	get_tree().quit(0)
