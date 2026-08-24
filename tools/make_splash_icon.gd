extends SceneTree
## Center-crops boot_void_bg.png into a square Android 12 splash icon
## so the system splash shows starfield instead of flat navy.

const SRC := "res://resources/background/boot_void_bg.png"
const DST := "res://resources/background/splash_void_icon.png"


func _init() -> void:
	var img := Image.new()
	var err := img.load(SRC)
	if err != OK:
		push_error("make_splash_icon: failed to load %s (%s)" % [SRC, err])
		quit(1)
		return
	var side := mini(img.get_width(), img.get_height())
	var x := int((img.get_width() - side) / 2.0)
	var y := int((img.get_height() - side) / 2.0)
	var crop := img.get_region(Rect2i(x, y, side, side))
	err = crop.save_png(DST)
	if err != OK:
		push_error("make_splash_icon: save failed (%s) -> %s" % [err, DST])
		quit(1)
		return
	print("wrote ", DST, " ", crop.get_width(), "x", crop.get_height())
	quit(0)
