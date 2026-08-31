extends SceneTree

## Writes achievement audit manifest + rasterized icon PNGs for the Python compositor.
## Run: Godot --headless --path . -s res://dev/asset-gen/export_achievement_icon_assets.gd

const OUT_DIR := "res://docs/_achievement_audit/"
const MANIFEST := "res://docs/_achievement_audit/manifest.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TranslationServer.set_locale("en")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var unlocked: Dictionary = {}
	for raw in AchievementCatalog.ORDERED_IDS:
		unlocked[str(raw)] = 1

	var entries: Array = []
	for raw_id in AchievementCatalog.grid_ids(unlocked):
		entries.append(_entry_dict(str(raw_id)))

	for label_text in [
		["Bronze medal", "res://resources/icons/ach_medal_bronze.svg", "(overlay)"],
		["Silver medal", "res://resources/icons/ach_medal_silver.svg", "(overlay)"],
		["Gold medal", "res://resources/icons/ach_medal_gold.svg", "(overlay)"],
		["Bronze outline", "res://resources/icons/ach_medal_bronze_outline.svg", "(overlay)"],
		["Silver outline", "res://resources/icons/ach_medal_silver_outline.svg", "(overlay)"],
		["Gold outline", "res://resources/icons/ach_medal_gold_outline.svg", "(overlay)"],
	]:
		entries.append(_extra_entry(label_text[0], label_text[1], label_text[2]))

	var used: Dictionary = {}
	for e in entries:
		used[str(e["icon"])] = true
	var dir := DirAccess.open("res://resources/icons/")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.begins_with("ach_") and file_name.ends_with(".svg"):
				var path := "res://resources/icons/%s" % file_name
				if not used.has(path):
					entries.append(_extra_entry("UNUSED", path, "(orphan)"))
			file_name = dir.get_next()
		dir.list_dir_end()

	for i in entries.size():
		var icon_path := str(entries[i]["icon"])
		var slug := str(entries[i]["slug"])
		var png_path := OUT_DIR.path_join("%s.png" % slug)
		if not _save_icon_png(icon_path, png_path):
			push_error("Failed to rasterize: %s" % icon_path)
			quit(1)
			return
		entries[i]["png"] = png_path

	var file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	file.store_string(JSON.stringify({"entries": entries}, "\t"))
	file.close()
	print("AchievementIconAssets: wrote ", MANIFEST)
	quit(0)


func _entry_dict(id: String) -> Dictionary:
	var icon_path := AchievementCatalog.icon_path(id)
	var title_key := AchievementCatalog.display_title_key(id, true)
	var title := TranslationServer.translate(title_key)
	if title == title_key:
		title = title_key
	return {
		"title": title,
		"id": id,
		"icon": icon_path,
		"file": icon_path.get_file(),
		"slug": id.replace("/", "_"),
	}


func _extra_entry(title: String, icon_path: String, id: String) -> Dictionary:
	var slug := icon_path.get_file().get_basename()
	return {
		"title": title,
		"id": id,
		"icon": icon_path,
		"file": icon_path.get_file(),
		"slug": slug,
	}


func _save_icon_png(icon_path: String, out_path: String) -> bool:
	var tex: Texture2D = load(icon_path)
	if tex == null:
		return false
	var img := tex.get_image()
	if img == null or img.is_empty():
		return false
	img = img.duplicate()
	img.resize(96, 96, Image.INTERPOLATE_NEAREST)
	return img.save_png(out_path) == OK
