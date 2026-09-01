extends SceneTree
## Renders Play Console achievement icons (512x512 PNG) from in-game SVGs.

const AchievementCatalog := preload("res://scripts/achievement_catalog.gd")

const OUT_SIZE := 512
const OUT_DIR := "res://resources/play_games/achievement_icons_512/"
## Matches achievements_list.gd (_BADGE_PX / _ICON_PX) for bottom-right cup placement.
const BADGE_RATIO := 48.0 / 120.0


func _initialize() -> void:
	var out_abs := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out_abs)
	var exported := 0
	var skipped := 0
	for catalog_id in AchievementCatalog.ORDERED_IDS:
		if catalog_id == AchievementCatalog.ID_DEV_MODE:
			skipped += 1
			continue
		var svg_path := AchievementCatalog.icon_path(catalog_id)
		if svg_path.is_empty() or not ResourceLoader.exists(svg_path):
			push_error("Missing SVG for %s: %s" % [catalog_id, svg_path])
			quit(1)
			return
		var texture: Texture2D = load(svg_path)
		if texture == null:
			push_error("Failed to load %s" % svg_path)
			quit(1)
			return
		var img := texture.get_image()
		if img == null or img.is_empty():
			push_error("No image data for %s" % svg_path)
			quit(1)
			return
		img.resize(OUT_SIZE, OUT_SIZE, Image.INTERPOLATE_NEAREST)
		img = _composite_tier_badge(img, catalog_id)
		var png_path := OUT_DIR.path_join("%s.png" % catalog_id)
		var err := img.save_png(ProjectSettings.globalize_path(png_path))
		if err != OK:
			push_error("save_png failed for %s (%s)" % [png_path, err])
			quit(1)
			return
		exported += 1
	print(
		"play_achievement_icons: %d exported, %d skipped (dev_mode) -> %s"
		% [exported, skipped, OUT_DIR]
	)
	quit(0)


func _composite_tier_badge(base: Image, catalog_id: String) -> Image:
	var badge_path := AchievementCatalog.medal_overlay_path(catalog_id, true)
	if badge_path.is_empty() or not ResourceLoader.exists(badge_path):
		return base
	var badge_tex: Texture2D = load(badge_path)
	if badge_tex == null:
		return base
	var badge_img := badge_tex.get_image()
	if badge_img == null or badge_img.is_empty():
		return base
	var badge_size := int(round(OUT_SIZE * BADGE_RATIO))
	badge_img.resize(badge_size, badge_size, Image.INTERPOLATE_NEAREST)
	var dst := Vector2i(OUT_SIZE - badge_size, OUT_SIZE - badge_size)
	base.blend_rect(badge_img, Rect2i(0, 0, badge_size, badge_size), dst)
	return base
