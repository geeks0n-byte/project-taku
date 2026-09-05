class_name LevelSelectCards
extends RefCounted
## Level-select card button content: number, preview, stars, lock overlay.


static func apply_button_content(
	btn: Button,
	level: LevelData,
	title: String,
	locked: bool,
	is_custom_view: bool,
	lock_icon: Texture2D,
	preview_size: int,
	lock_icon_size: float,
	show_unseen_badge: bool
) -> void:
	btn.text = ""
	btn.custom_minimum_size = Vector2(260, 240)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	btn.clip_text = true
	btn.clip_contents = false

	const TITLE_FONT := 32
	const TITLE_INSET_X := 10.0
	const TITLE_INSET_Y := 8.0

	var content := Control.new()
	content.name = "LevelContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 18.0
	content.offset_top = 18.0
	content.offset_right = -18.0
	content.offset_bottom = -14.0

	var label := Label.new()
	label.name = "Title"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	label.offset_left = TITLE_INSET_X
	label.offset_top = TITLE_INSET_Y
	label.grow_horizontal = Control.GROW_DIRECTION_END
	label.grow_vertical = Control.GROW_DIRECTION_END
	var title_color := Color(0.55, 0.55, 0.55, 1.0) if locked else Color.WHITE
	HudLayout.apply_raster_pixel_label(label, title, TITLE_FONT, title_color, 0, true)
	content.add_child(label)

	const PREVIEW_TOP := 24.0
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_top = PREVIEW_TOP
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN

	var preview_frame := PanelContainer.new()
	preview_frame.name = "PreviewFrame"
	preview_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview_frame.add_theme_stylebox_override("panel", LevelPreview.make_frame_style())

	var preview := TextureRect.new()
	preview.name = "Preview"
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.custom_minimum_size = Vector2(preview_size, preview_size)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture = LevelPreview.make_texture(level, GameConstants.LEVEL_PREVIEW_SIZE)
	if locked:
		preview.modulate = Color(0.45, 0.45, 0.45, 1.0)
		preview_frame.modulate = Color(0.7, 0.7, 0.7, 1.0)
	preview_frame.add_child(preview)
	vbox.add_child(preview_frame)

	if not locked:
		var earned_bits := SaveManager.get_level_star_bits(level.level_number) if SaveManager else 0
		var star_row := LevelStars.make_select_star_row(level, earned_bits)
		vbox.add_child(star_row)

	content.add_child(vbox)
	content.move_child(label, content.get_child_count() - 1)

	if locked and lock_icon:
		var half := lock_icon_size * 0.5
		var lock_overlay := TextureRect.new()
		lock_overlay.name = "LockOverlay"
		lock_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_overlay.texture = lock_icon
		lock_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock_overlay.modulate = Color(1, 1, 1, 0.9)
		lock_overlay.custom_minimum_size = Vector2(lock_icon_size, lock_icon_size)
		lock_overlay.anchor_left = 0.5
		lock_overlay.anchor_right = 0.5
		lock_overlay.anchor_top = 0.0
		lock_overlay.anchor_bottom = 0.0
		var preview_mid_y := PREVIEW_TOP + preview_size * 0.5
		lock_overlay.offset_left = -half
		lock_overlay.offset_right = half
		lock_overlay.offset_top = preview_mid_y - half
		lock_overlay.offset_bottom = preview_mid_y + half
		content.add_child(lock_overlay)

	btn.add_child(content)

	if show_unseen_badge and not locked and not is_custom_view:
		HudBadges.attach_level_new_badge(content, TITLE_INSET_X, TITLE_INSET_Y)
