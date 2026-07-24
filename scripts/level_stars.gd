class_name LevelStars
extends RefCounted

## Star challenges (time / greens / shifter moves).
## End screen and level select always show all three slots.

const BIT_TIME := 1
const BIT_GREEN := 2
const BIT_MOVES := 4
const ALL_GOAL_MASKS: Array = [BIT_TIME, BIT_GREEN, BIT_MOVES]

const ICON_STAR_ON: Texture2D = preload("res://resources/icons/icon_star_on.svg")
const ICON_STAR_OFF: Texture2D = preload("res://resources/icons/icon_star_off.svg")
const STAR_ICON_SIZE := 56.0
const SELECT_STAR_ICON_SIZE := 40.0
const ROW_HEIGHT := 72.0
const RESULTS_CONTENT_WIDTH := 620.0
const RESULTS_TITLE_FONT := 34
const RESULTS_ROW_FONT := 28

static func count_earned_bits(bits: int) -> int:
	var n := 0
	if bits & BIT_TIME:
		n += 1
	if bits & BIT_GREEN:
		n += 1
	if bits & BIT_MOVES:
		n += 1
	return n

## Compact on/off star row for level-select buttons (always 3 slots).
static func make_select_star_row(_level: LevelData, earned_bits: int) -> Control:
	var row := HBoxContainer.new()
	row.name = "StarRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
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

static func format_clock(total_seconds: int) -> String:
	var secs := maxi(0, total_seconds)
	return "%02d:%02d" % [int(secs / 60.0), secs % 60]

## Always returns three goals (time / green / moves), earned or not.
static func evaluate(
	elapsed_sec: int,
	time_limit: int,
	greens_used: int,
	green_target: int,
	moves_used: int,
	move_target: int,
	has_shifters: bool
) -> Dictionary:
	var goals: Array = []
	var bits := 0

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

	var green_earned := green_target > 0 and greens_used <= green_target
	if green_earned:
		bits |= BIT_GREEN
	goals.append({
		"id": "green",
		"earned": green_earned,
		"title": TranslationServer.translate("STAR_GREEN"),
		"detail": (
			"%d / %d" % [greens_used, green_target]
			if green_target > 0
			else "%d / —" % greens_used
		),
	})

	var moves_earned := has_shifters and move_target > 0 and moves_used <= move_target
	if moves_earned:
		bits |= BIT_MOVES
	goals.append({
		"id": "moves",
		"earned": moves_earned,
		"title": TranslationServer.translate("STAR_MOVES"),
		"detail": (
			"%d / %d" % [moves_used, move_target]
			if has_shifters and move_target > 0
			else "%d / —" % moves_used
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

## Builds completion-time + star rows into `host` (clears previous children).
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
	var elapsed := int(star_result.get("elapsed_sec", 0))
	# Tutorials / untimed runs: never show an infinity glyph; skip optional star goals.
	if not untimed:
		root.add_child(_make_text_row(
			TranslationServer.translate("COMPLETION_TIME") % format_clock(elapsed),
			Color(0.95, 0.95, 0.95, 1.0),
			RESULTS_TITLE_FONT
		))

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

static func _make_text_row(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	HudLayout.apply_popup_label(label, font_size)
	return label

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

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(STAR_ICON_SIZE, STAR_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = ICON_STAR_ON if earned else ICON_STAR_OFF
	icon.modulate = Color(1, 1, 1, 1) if earned else Color(1, 1, 1, 0.5)
	icon_slot.add_child(icon)

	var title := Label.new()
	title.text = str(goal.get("title", ""))
	title.custom_minimum_size = Vector2(200, 0)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45, 1.0) if earned else Color(0.72, 0.72, 0.76, 1.0))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 8)
	HudLayout.apply_popup_label(title, RESULTS_ROW_FONT)
	row.add_child(title)

	var detail := Label.new()
	detail.text = str(goal.get("detail", ""))
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail.add_theme_color_override("font_color", Color(0.92, 0.92, 0.94, 1.0) if earned else Color(0.78, 0.78, 0.82, 1.0))
	detail.add_theme_color_override("font_outline_color", Color.BLACK)
	detail.add_theme_constant_override("outline_size", 8)
	HudLayout.apply_popup_label(detail, RESULTS_ROW_FONT)
	row.add_child(detail)

	return row
