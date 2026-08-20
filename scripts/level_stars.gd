class_name LevelStars
extends RefCounted
## Stateless utility that scores completed puzzles, builds star-goal data, and
## renders star rows into result/requirements panels. All methods are static.

## Bit layout (stable for saves):
## 1 = time, 2 = no hints, 4 = level clear (replaces legacy moves bit).
const BIT_TIME := 1
const BIT_NO_HINTS := 2
const BIT_COMPLETE := 4
## Legacy aliases.
const BIT_GREEN := BIT_NO_HINTS
const BIT_MOVES := BIT_COMPLETE
## Display / award order: clear → no hints → time.
const ALL_GOAL_MASKS: Array = [BIT_COMPLETE, BIT_NO_HINTS, BIT_TIME]

const ICON_STAR_ON: Texture2D = preload("res://resources/icons/icon_star_on.svg")
const ICON_STAR_OFF: Texture2D = preload("res://resources/icons/icon_star_off.svg")
const STAR_ICON_SIZE := 56.0
const SELECT_STAR_ICON_SIZE := 44.0
const ROW_HEIGHT := 72.0
const RESULTS_CONTENT_WIDTH := 620.0
const RESULTS_TITLE_FONT := 34
const RESULTS_ROW_FONT := 28
const COLOR_STAR_EARNED := Color(0.45, 1.0, 0.45, 1.0)
const COLOR_STAR_FAILED := Color(1.0, 0.35, 0.35, 1.0)

## Counts how many of the three star goals are set in `bits`.
static func count_earned_bits(bits: int) -> int:
	var n := 0
	for mask in ALL_GOAL_MASKS:
		if bits & int(mask):
			n += 1
	return n

## Builds the compact 3-star icon row shown on each level-select card.
## Earned stars are fully opaque; unearned stars are dimmed.
static func make_select_star_row(_level: LevelData, earned_bits: int) -> Control:
	var row := HBoxContainer.new()
	row.name = "StarRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for mask in ALL_GOAL_MASKS:
		var earned: bool = (earned_bits & int(mask)) != 0
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.custom_minimum_size = Vector2(SELECT_STAR_ICON_SIZE, SELECT_STAR_ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = ICON_STAR_ON if earned else ICON_STAR_OFF
		icon.modulate = Color(1, 1, 1, 1) if earned else Color(1, 1, 1, 0.45)
		row.add_child(icon)
	return row

## Formats a second count as MM:SS, clamped to zero so negative values don't display.
static func format_clock(total_seconds: int) -> String:
	var secs := maxi(0, total_seconds)
	return "%02d:%02d" % [int(secs / 60.0), secs % 60]

## Scores a completed puzzle session and returns the full star result dict.
## `_moves_used`, `_move_target`, `_has_shifters` are reserved for future goal types
## and currently have no effect on the returned bits.
static func evaluate(
	elapsed_sec: int,
	time_limit: int,
	hints_used: int,
	_moves_used: int = 0,
	_move_target: int = 0,
	_has_shifters: bool = false
) -> Dictionary:
	var goals: Array = []
	var bits := 0

	# 1) Completing the level always awards the first star.
	bits |= BIT_COMPLETE
	goals.append({
		"id": "complete",
		"earned": true,
		"title": TranslationServer.translate("STAR_COMPLETE"),
		"detail": "",
	})

	# 2) No hints used.
	var no_hints_earned := hints_used <= 0
	if no_hints_earned:
		bits |= BIT_NO_HINTS
	goals.append({
		"id": "no_hints",
		"earned": no_hints_earned,
		"title": TranslationServer.translate(
			"STAR_HINTS" if no_hints_earned else "STAR_HINTS_USED"
		),
		"detail": "",
	})

	# 3) Time limit (only when the level defines one).
	var time_earned := time_limit > 0 and elapsed_sec <= time_limit
	if time_earned:
		bits |= BIT_TIME
	goals.append({
		"id": "time",
		"earned": time_earned,
		"title": TranslationServer.translate("STAR_TIME"),
		"detail": (
			"%s / %s" % [format_clock(elapsed_sec), format_clock(time_limit)]
			if time_limit > 0
			else "%s / —" % format_clock(elapsed_sec)
		),
	})

	var earned_count := 0
	for g in goals:
		if g.get("earned", false):
			earned_count += 1

	return {
		"bits": bits,
		"goals": goals,
		"earned_count": earned_count,
		"total_count": goals.size(),
		"elapsed_sec": elapsed_sec,
	}

## Builds a star result dict representing the goals for a level without running it.
## Used to preview requirements on the level-select info panel, with previously-earned
## bits optionally pre-filled so the UI can show which goals are already complete.
static func build_requirements(level: LevelData, earned_bits: int = 0) -> Dictionary:
	if level == null:
		return {
			"bits": 0,
			"goals": [],
			"earned_count": 0,
			"total_count": 0,
			"elapsed_sec": 0,
			"untimed": true,
		}
	var time_limit := int(level.time_limit)
	var bits := int(earned_bits) & (BIT_COMPLETE | BIT_NO_HINTS | BIT_TIME)

	var goals: Array = []
	goals.append({
		"id": "complete",
		"earned": (bits & BIT_COMPLETE) != 0,
		"title": TranslationServer.translate("STAR_COMPLETE"),
		"detail": "",
	})
	goals.append({
		"id": "no_hints",
		"earned": (bits & BIT_NO_HINTS) != 0,
		"title": TranslationServer.translate("STAR_HINTS"),
		"detail": "",
	})
	goals.append({
		"id": "time",
		"earned": (bits & BIT_TIME) != 0,
		"title": TranslationServer.translate("STAR_TIME"),
		"detail": format_clock(time_limit) if time_limit > 0 else "—",
	})

	var earned_count := count_earned_bits(bits)
	return {
		"bits": bits,
		"goals": goals,
		"earned_count": earned_count,
		"total_count": goals.size(),
		"elapsed_sec": 0,
		"untimed": false,
	}

## Clears `host` and fills it with the post-game star rows from a completed star_result dict.
## If the result is marked untimed (no goal rows), the host is left empty after clearing.
static func populate_results(host: Control, star_result: Dictionary) -> void:
	if host == null:
		return
	while host.get_child_count() > 0:
		host.get_child(0).free()

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 16)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	host.add_child(root)

	var untimed := bool(star_result.get("untimed", false))
	if untimed:
		return

	var goals: Array = star_result.get("goals", [])
	var stars_box := VBoxContainer.new()
	stars_box.custom_minimum_size = Vector2(RESULTS_CONTENT_WIDTH, 0)
	stars_box.add_theme_constant_override("separation", 12)
	stars_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(stars_box)

	for g in goals:
		stars_box.add_child(_make_star_row(g))

## Clears `host` and fills it with star-goal rows built from the level's requirements.
## Used on the pre-play info panel rather than the post-game results screen.
static func populate_requirements(host: Control, level: LevelData, earned_bits: int = 0) -> void:
	if host == null:
		return
	while host.get_child_count() > 0:
		host.get_child(0).free()
	var preview := build_requirements(level, earned_bits)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 16)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	host.add_child(root)
	var stars_box := VBoxContainer.new()
	stars_box.custom_minimum_size = Vector2(RESULTS_CONTENT_WIDTH, 0)
	stars_box.add_theme_constant_override("separation", 12)
	stars_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(stars_box)
	for g in preview.get("goals", []):
		stars_box.add_child(_make_star_row(g))

## Helper to create a centered pixel-font label used for section headings in result rows.
static func _make_text_row(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	HudLayout.apply_raster_pixel_label(label, text, font_size, color)
	return label

## Builds one full-width HBox row for a single star goal: star icon | title | optional detail.
## Earned goals use green text; missed goals use red (and hints swap to HINTS USED).
static func _make_star_row(goal: Dictionary) -> HBoxContainer:
	var earned := bool(goal.get("earned", false))
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(RESULTS_CONTENT_WIDTH, ROW_HEIGHT)
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var icon_slot := CenterContainer.new()
	icon_slot.custom_minimum_size = Vector2(STAR_ICON_SIZE + 8.0, STAR_ICON_SIZE + 8.0)
	row.add_child(icon_slot)

	# Slight vertical lift so the star icon reads as top-aligned with the text lines beside it.
	var icon_lift := MarginContainer.new()
	icon_lift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_lift.add_theme_constant_override("margin_bottom", 10)
	icon_lift.add_theme_constant_override("margin_top", 0)
	icon_slot.add_child(icon_lift)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(STAR_ICON_SIZE, STAR_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = ICON_STAR_ON if earned else ICON_STAR_OFF
	icon.modulate = Color(1, 1, 1, 1) if earned else Color(1, 1, 1, 0.5)
	icon_lift.add_child(icon)

	var title_slot := HBoxContainer.new()
	title_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_slot.add_theme_constant_override("separation", 10)
	title_slot.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(title_slot)

	# Optional small tile icon placed before the goal title (e.g. a tile sprite for visual context).
	var icon_path := str(goal.get("title_icon", ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var tile_icon := TextureRect.new()
		tile_icon.custom_minimum_size = Vector2(40, 40)
		tile_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tile_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tile_icon.texture = load(icon_path) as Texture2D
		tile_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_slot.add_child(tile_icon)

	var title := Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var title_color := COLOR_STAR_EARNED if earned else COLOR_STAR_FAILED
	HudLayout.apply_raster_pixel_label(
		title, str(goal.get("title", "")), RESULTS_ROW_FONT, title_color
	)
	title_slot.add_child(title)

	var detail_text := str(goal.get("detail", "")).strip_edges()
	if not detail_text.is_empty():
		var detail := Label.new()
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var detail_color := COLOR_STAR_EARNED if earned else COLOR_STAR_FAILED
		HudLayout.apply_raster_pixel_label(
			detail, detail_text, RESULTS_ROW_FONT, detail_color
		)
		row.add_child(detail)

	return row
