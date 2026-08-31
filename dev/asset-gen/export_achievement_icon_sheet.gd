extends SceneTree

## Headless export: one PNG sheet of achievement icons with English names.
## Run: Godot --headless --path . -s res://dev/asset-gen/export_achievement_icon_sheet.gd

const OUTPUT_PATH := "res://docs/achievement_icon_audit.png"
const BG := Color(0.06, 0.08, 0.14, 1.0)
const COLS := 4
const CELL_W := 260
const CELL_H := 240
const ICON_PX := 96
const PAD := 24
const TITLE_SIZE := 20
const META_SIZE := 14
const TITLE_COLOR := Color.WHITE
const META_COLOR := Color(0.65, 0.72, 0.82, 1.0)
const ERROR_COLOR := Color(1.0, 0.35, 0.35, 1.0)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TranslationServer.set_locale("en")
	var sheet := _build_sheet()
	var cols := COLS
	var rows := int(ceil(float(sheet.size()) / float(cols)))
	var size := Vector2i(PAD * 2 + cols * CELL_W, PAD * 2 + rows * CELL_H)
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(BG)

	var font: Font = load("res://resources/fonts/NotoSans-Regular.ttf")
	if font == null:
		font = HudFonts.default_font()
	for i in sheet.size():
		var entry: Dictionary = sheet[i]
		var col := i % cols
		var row := i / cols
		var ox := PAD + col * CELL_W
		var oy := PAD + row * CELL_H
		_draw_cell(image, font, ox, oy, entry)

	var err := image.save_png(OUTPUT_PATH)
	if err != OK:
		push_error("AchievementIconAudit: save failed (%s)" % err)
		quit(1)
		return
	print("AchievementIconAudit: wrote ", OUTPUT_PATH, " (", size.x, "x", size.y, ")")
	quit(0)


func _build_sheet() -> Array:
	var unlocked: Dictionary = {}
	for raw in AchievementCatalog.ORDERED_IDS:
		unlocked[str(raw)] = 1

	var out: Array = []
	for raw_id in AchievementCatalog.grid_ids(unlocked):
		var id := str(raw_id)
		var icon_path := AchievementCatalog.icon_path(id)
		var title_key := AchievementCatalog.display_title_key(id, true)
		var title := TranslationServer.translate(title_key)
		if title == title_key:
			title = title_key
		out.append({
			"title": title,
			"id": id,
			"icon": icon_path,
			"file": icon_path.get_file(),
		})

	for label_text in [
		["Bronze medal", "res://resources/icons/ach_medal_bronze.svg"],
		["Silver medal", "res://resources/icons/ach_medal_silver.svg"],
		["Gold medal", "res://resources/icons/ach_medal_gold.svg"],
		["Bronze outline", "res://resources/icons/ach_medal_bronze_outline.svg"],
		["Silver outline", "res://resources/icons/ach_medal_silver_outline.svg"],
		["Gold outline", "res://resources/icons/ach_medal_gold_outline.svg"],
	]:
		out.append({
			"title": label_text[0],
			"id": "(overlay)",
			"icon": label_text[1],
			"file": String(label_text[1]).get_file(),
		})

	var used: Dictionary = {}
	for entry in out:
		used[str(entry["icon"])] = true
	var dir := DirAccess.open("res://resources/icons/")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.begins_with("ach_") and file_name.ends_with(".svg"):
				var path := "res://resources/icons/%s" % file_name
				if not used.has(path):
					out.append({
						"title": "UNUSED",
						"id": "(orphan)",
						"icon": path,
						"file": file_name,
					})
			file_name = dir.get_next()
		dir.list_dir_end()

	return out


func _draw_cell(image: Image, font: Font, ox: int, oy: int, entry: Dictionary) -> void:
	var icon_path := str(entry.get("icon", ""))
	var tex: Texture2D = load(icon_path)
	var icon_img: Image = null
	if tex:
		icon_img = tex.get_image()
	if icon_img and not icon_img.is_empty():
		icon_img = icon_img.duplicate()
		icon_img.resize(ICON_PX, ICON_PX, Image.INTERPOLATE_NEAREST)
		var ix := ox + (CELL_W - ICON_PX) / 2
		image.blend_rect(icon_img, Rect2i(Vector2i.ZERO, icon_img.get_size()), Vector2i(ix, oy + 12))
	else:
		_draw_centered_text(image, font, ox, oy + 40, "MISSING", META_SIZE, ERROR_COLOR)

	var title_y := oy + ICON_PX + 28
	_draw_wrapped_text(image, font, ox + 8, title_y, CELL_W - 16, str(entry.get("title", "")), TITLE_SIZE, TITLE_COLOR, 3)
	var meta_y := title_y + 52
	_draw_wrapped_text(
		image,
		font,
		ox + 8,
		meta_y,
		CELL_W - 16,
		"%s\n%s" % [str(entry.get("id", "")), str(entry.get("file", ""))],
		META_SIZE,
		META_COLOR,
		3
	)


func _draw_centered_text(
	image: Image, font: Font, ox: int, oy: int, text: String, size: int, color: Color
) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	font.draw_string(image, Vector2(ox + (CELL_W - int(w)) / 2, oy), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_wrapped_text(
	image: Image,
	font: Font,
	ox: int,
	oy: int,
	max_w: int,
	text: String,
	size: int,
	color: Color,
	max_lines: int
) -> void:
	var lines := _wrap_lines(font, text, max_w, size, max_lines)
	var line_h := int(font.get_height(size)) + 2
	for i in lines.size():
		var line: String = lines[i]
		var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var x := ox + maxi(0, (max_w - int(w)) / 2)
		font.draw_string(image, Vector2(x, oy + i * line_h), line, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _wrap_lines(font: Font, text: String, max_w: int, size: int, max_lines: int) -> PackedStringArray:
	var out: PackedStringArray = []
	for raw_line in text.split("\n"):
		var words := str(raw_line).split(" ", false)
		var current := ""
		for word in words:
			var trial := current if current.is_empty() else "%s %s" % [current, word]
			if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= max_w:
				current = trial
			else:
				if not current.is_empty():
					out.append(current)
				current = word
				if out.size() >= max_lines:
					return out
		if not current.is_empty():
			out.append(current)
		if out.size() >= max_lines:
			return out
	return out
