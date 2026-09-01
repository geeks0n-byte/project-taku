class_name SpaceBackgroundFxAssets
extends RefCounted
## Loads foreground FX textures used by [SpaceBackground].


const ASSET_DIR := "res://resources/background/"

const FX_FILES := {
	"fx_star": "fx_shooting_star.svg",
	"fx_comet_1": "fx_comet_1.svg",
	"fx_comet_2": "fx_comet_2.svg",
	"fx_comet_3": "fx_comet_3.svg",
}


static func load_assets() -> Dictionary:
	var tex_shooting_star: Texture2D = null
	var sf_comet_anim: SpriteFrames = null
	var tex_asteroids: Array[Texture2D] = []
	if ResourceLoader.exists(ASSET_DIR + FX_FILES["fx_star"]):
		tex_shooting_star = load(ASSET_DIR + FX_FILES["fx_star"])
	if ResourceLoader.exists(ASSET_DIR + FX_FILES["fx_comet_1"]):
		sf_comet_anim = SpriteFrames.new()
		sf_comet_anim.set_animation_speed("default", 12.0)
		sf_comet_anim.add_frame("default", load(ASSET_DIR + FX_FILES["fx_comet_1"]))
		if ResourceLoader.exists(ASSET_DIR + FX_FILES["fx_comet_2"]):
			sf_comet_anim.add_frame("default", load(ASSET_DIR + FX_FILES["fx_comet_2"]))
		if ResourceLoader.exists(ASSET_DIR + FX_FILES["fx_comet_3"]):
			sf_comet_anim.add_frame("default", load(ASSET_DIR + FX_FILES["fx_comet_3"]))
	for asset_name in ["fx_asteroid_1.svg", "fx_asteroid_2.svg", "fx_asteroid_3.svg"]:
		var path: String = ASSET_DIR + asset_name
		if ResourceLoader.exists(path):
			tex_asteroids.append(load(path))
	return {
		"tex_shooting_star": tex_shooting_star,
		"sf_comet_anim": sf_comet_anim,
		"tex_asteroids": tex_asteroids,
	}
