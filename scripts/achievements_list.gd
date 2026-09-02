extends CanvasLayer
## Full-screen achievements grid with paged prev/next navigation (like level select).

signal back_requested

@onready var title_label: Label = $ScreenHeaderHost/TitleLabel
@onready var progress_label: Label = $ScreenHeaderHost/ProgressLabel
@onready var close_btn: Button = $CloseButtonHost/CloseButton
@onready var _nav_host: Control = $ScreenHeaderHost
@onready var _header_host: Control = $ScreenHeaderHost
@onready var _close_host: Control = $CloseButtonHost
@onready var _list_host: VBoxContainer = $ListHost
@onready var _grid_host: Control = $ListHost/GridHost
@onready var _grid: GridContainer = $ListHost/GridHost/Grid
@onready var _page_nav: HBoxContainer = $ListHost/PageNav
@onready var _page_nav_gap: Control = $ListHost/PageNavGap
@onready var _page_prev_button: Button = $ListHost/PageNav/PrevSlot/PrevButton
@onready var _page_next_button: Button = $ListHost/PageNav/NextSlot/NextButton

const _GRID_COLUMNS := 2
const _ROWS_PER_PAGE := 4
const _ITEMS_PER_PAGE := _GRID_COLUMNS * _ROWS_PER_PAGE
## Max cell height. Fitted to ListHost so 4 rows stay above the pinned pager (HARD KNOCKS).
## 276 * 4 + 24 * 3 = 1176, under the 1182px phone ListHost (bottom inset 278).
const _ROW_H := 276.0
const _CELL_SEP_H := 24
const _CELL_SEP_V := 24
const _ICON_PX := 88.0
const _ICON_ART_PX := 72.0
const _BADGE_PX := 36.0
const _BADGE_INSET := 0.0
const _NAME_SLOT_H := 56.0
const _TIER_SLOT_H := 22.0
## Full 2-line pixel desc (22px) + pad. Do not shrink this to dodge the pager.
const _DESC_SLOT_H := 82.0
const _TEXT_SLOT_PAD_TOP := 2.0
const _TEXT_SLOT_PAD_BOTTOM := 2.0
const _BELOW_TITLE_GAP := 48.0
const _RESERVE_MENU_BANNER_NAV := true
const _LOCKED_ICON_MODULATE := Color(0.34, 0.34, 0.38, 1.0)
const _LOCKED_TITLE_COLOR := Color(0.58, 0.58, 0.62, 1.0)
const _LOCKED_DESC_COLOR := Color(0.48, 0.48, 0.52, 1.0)
const _TIER_COUNTER_HIGHLIGHT := Color(1.0, 1.0, 1.0, 1.0)
const _TIER_COUNTER_DIM := Color(0.55, 0.58, 0.64, 1.0)
const _TIER_PROGRESS_FONT := 20
const _NEXT_BADGE_MODULATE := Color(1.0, 1.0, 1.0, 0.45)
const _NAME_FONT_BASE := 28
const _NAME_MAX_LINES := 2
const _DESC_FONT_BASE := 22
const _DESC_MAX_LINES := 3
const LOCK_ICON := preload("res://resources/tiles/tile_lock.svg")
const LOCK_OVERLAY_PX := 64.0
const _LOCK_SCRIM_RADIUS := 22.0

const _NEW_BADGE_INSET := 2.0

var _progress_state: Dictionary = {}
var _all_ids: Array = []
var _unlocked_map: Dictionary = {}
var _page_index: int = 0
var _viewed_page_indices: Dictionary = {}


## Wires close, header style, paging, and safe-area resize.
func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if close_btn and not close_btn.pressed.is_connected(_on_close):
		close_btn.pressed.connect(_on_close)
	if _page_prev_button and not _page_prev_button.pressed.is_connected(_on_page_prev):
		_page_prev_button.pressed.connect(_on_page_prev)
	if _page_next_button and not _page_next_button.pressed.is_connected(_on_page_next):
		_page_next_button.pressed.connect(_on_page_next)
	_style_header()
	_style_close()
	_style_page_nav()
	if _grid_host and not _grid_host.resized.is_connected(_pin_grid_to_top):
		_grid_host.resized.connect(_pin_grid_to_top)
	_reparent_page_nav()
	if not get_viewport().size_changed.is_connected(_on_resized):
		get_viewport().size_changed.connect(_on_resized)
	if SaveManager and not SaveManager.language_changed.is_connected(_on_language_changed):
		SaveManager.language_changed.connect(_on_language_changed)
	call_deferred("_apply_a11y_labels")


func _on_resized() -> void:
	if visible:
		_layout()


func _on_language_changed() -> void:
	if visible:
		refresh()
	_apply_a11y_labels()


func _apply_a11y_labels() -> void:
	if title_label:
		title_label.accessibility_name = tr("UI_ACHIEVEMENTS")
	if close_btn:
		A11yLabels.bind_button(close_btn, "UI_CLOSE")
	if _page_prev_button:
		A11yLabels.bind_button(_page_prev_button, "UI_PREVIOUS")
	if _page_next_button:
		A11yLabels.bind_button(_page_next_button, "UI_NEXT")


func _style_header() -> void:
	if title_label == null:
		return
	HudLayout._bind_header_translation_key(title_label, "UI_ACHIEVEMENTS")
	HudLayout.apply_screen_header_style(title_label)
	if progress_label:
		HudLayout.apply_popup_label(progress_label, 22)
		progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		progress_label.add_theme_color_override("font_color", GameConstants.SCREEN_HEADER_COLOR)


func _update_progress_label() -> void:
	if progress_label == null:
		return
	var total := _all_ids.size()
	var unlocked := 0
	for id in _all_ids:
		if AchievementCatalog.cell_is_unlocked(str(id), _unlocked_map):
			unlocked += 1
	progress_label.text = tr("UI_ACHIEVEMENTS_PROGRESS") % [unlocked, total]


func _style_close() -> void:
	if close_btn:
		HudLayout.style_top_bar_close_button(close_btn)


func _style_page_nav() -> void:
	if _page_prev_button:
		HudLayout.apply_nav_button(_page_prev_button)
	if _page_next_button:
		HudLayout.apply_nav_button(_page_next_button)


## Moves PREV/NEXT out of the list vbox so they share the global pinned nav row.
func _reparent_page_nav() -> void:
	if _page_nav == null or _nav_host == null:
		return
	if _page_nav.get_parent() != _nav_host:
		_page_nav.reparent(_nav_host)
	if _page_nav_gap and is_instance_valid(_page_nav_gap):
		_page_nav_gap.queue_free()
		_page_nav_gap = null
	var stale := _list_host.get_node_or_null("NavSpacer") if _list_host else null
	if stale:
		stale.queue_free()


## Rebuilds catalog data and the current page, then relayouts.
func refresh() -> void:
	if not visible:
		_page_index = 0
	_viewed_page_indices.clear()
	_style_header()
	_style_close()
	_style_page_nav()
	_load_catalog_state()
	_update_progress_label()
	_page_index = clampi(_page_index, 0, _max_page_index())
	_refresh_page()
	_layout()
	call_deferred("_layout")
	call_deferred("_fit_all_cell_labels")


func _load_catalog_state() -> void:
	_progress_state = {}
	_unlocked_map = {}
	_all_ids = []
	if SaveManager:
		_unlocked_map = SaveManager.achievements_unlocked
		var first := AchievementCatalog.first_level_number_in_dir(GameConstants.CAMPAIGN_EASY_DIR)
		if first <= 0:
			first = SaveManager.get_campaign_start_unlock()
		_progress_state = {
			"campaign_clears": maxi(0, SaveManager.max_unlocked_level - first),
			"no_hint_clears": SaveManager.no_hint_clears,
			"on_time_clears": SaveManager.on_time_clears,
			"shifter_slides": SaveManager.shifter_slides,
			"rules_open_levels": SaveManager.rules_open_level_count(),
		}
	_all_ids = AchievementCatalog.grid_ids(_unlocked_map)


func _max_page_index() -> int:
	if _all_ids.is_empty():
		return 0
	return int(ceili(float(_all_ids.size()) / float(_ITEMS_PER_PAGE))) - 1


func _on_page_prev() -> void:
	_commit_page_seen(_page_index)
	_page_index = maxi(_page_index - 1, 0)
	_refresh_page()
	call_deferred("_fit_all_cell_labels")


func _on_page_next() -> void:
	_commit_page_seen(_page_index)
	_page_index = mini(_page_index + 1, _max_page_index())
	_refresh_page()
	call_deferred("_fit_all_cell_labels")


## Clears the grid and fills only the current page slice (4 rows × 2 columns).
func _refresh_page() -> void:
	if _grid == null:
		return
	_viewed_page_indices[_page_index] = true
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_grid.columns = _GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", _CELL_SEP_H)
	_grid.add_theme_constant_override("v_separation", _CELL_SEP_V)

	var start := _page_index * _ITEMS_PER_PAGE
	var end := mini(start + _ITEMS_PER_PAGE, _all_ids.size())
	for i in range(start, end):
		var cell := _make_cell(str(_all_ids[i]), _unlocked_map)
		cell.custom_minimum_size.y = _page_row_height()
		cell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_grid.add_child(cell)

	var page_count := end - start
	for _i in HudLayout.grid_row_pad_count(page_count, _GRID_COLUMNS):
		var pad := Control.new()
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.custom_minimum_size.y = _page_row_height()
		pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(pad)

	_update_page_nav_visibility()
	_pin_grid_to_top()


func _update_page_nav_visibility() -> void:
	var multi_page := _all_ids.size() > _ITEMS_PER_PAGE
	if _page_nav:
		_page_nav.visible = multi_page
	if _page_prev_button:
		_page_prev_button.visible = multi_page and _page_index > 0
		_page_prev_button.disabled = false
		HudLayout.apply_nav_button(_page_prev_button)
		HudLayout.refresh_button_icon_modulate(_page_prev_button)
	if _page_next_button:
		_page_next_button.visible = multi_page and _page_index < _max_page_index()
		_page_next_button.disabled = false
		HudLayout.apply_nav_button(_page_next_button)
		HudLayout.refresh_button_icon_modulate(_page_next_button)


## Row height that fits four cells in ListHost so the pinned pager cannot overlap HARD KNOCKS.
func _page_row_height() -> float:
	var sep := _CELL_SEP_V
	if _grid:
		sep = _grid.get_theme_constant("v_separation")
	var seps := float(maxi(0, _ROWS_PER_PAGE - 1) * sep)
	var avail := _ROW_H * float(_ROWS_PER_PAGE) + seps
	if _list_host and _list_host.size.y > 1.0:
		avail = _list_host.size.y
	var fitted := floorf((avail - seps) / float(_ROWS_PER_PAGE))
	return maxf(1.0, minf(_ROW_H, fitted))


## Pins the grid to the top of its host and reserves a full 4-row page height.
func _pin_grid_to_top() -> void:
	if _grid == null or _grid_host == null or _grid.get_parent() != _grid_host:
		return
	var host_w := _grid_host.size.x
	if host_w <= 0.0:
		return
	_grid.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_grid.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_grid.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_grid.size_flags_horizontal = 0
	_grid.size_flags_vertical = 0
	_grid.clip_contents = false
	var sep := _grid.get_theme_constant("v_separation")
	var row_h := _page_row_height()
	for child in _grid.get_children():
		if child is Control:
			(child as Control).custom_minimum_size.y = row_h
	var reserved_h := float(_ROWS_PER_PAGE) * row_h + float(maxi(0, _ROWS_PER_PAGE - 1) * sep)
	var grid_w := minf(host_w, HudLayout.UI_PHONE_CONTENT_WIDTH)
	if grid_w < 1.0:
		grid_w = host_w
	_grid.size = Vector2(grid_w, reserved_h)
	_grid.position = Vector2((host_w - grid_w) * 0.5, 0.0)
	# Never force the host taller than ListHost; overflow would paint over PREV/NEXT.
	_grid_host.custom_minimum_size = Vector2(0, reserved_h)
	_grid_host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


## One grid cell: icon + tier medal, title, tier progress slot, description slot.
func _make_cell(id: String, unlocked_map: Dictionary) -> Control:
	var unlocked: bool = AchievementCatalog.cell_is_unlocked(id, unlocked_map)
	var show_identity := AchievementCatalog.identity_visible(id, unlocked)
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cell.add_theme_constant_override("separation", 6)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(_make_icon_row(id, unlocked, show_identity, unlocked_map))

	var name_slot := _make_text_slot(_NAME_SLOT_H)
	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text = tr(AchievementCatalog.display_title_key(id, unlocked))
	var name_color := (
		GameConstants.SCREEN_HEADER_COLOR if unlocked else _LOCKED_TITLE_COLOR
	)
	name_label.add_theme_color_override("font_color", name_color)
	HudLayout.apply_popup_label(name_label, _NAME_FONT_BASE)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_contents = false
	name_label.clip_text = false
	name_label.max_lines_visible = _NAME_MAX_LINES
	name_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	name_label.custom_minimum_size.y = _NAME_SLOT_H - _TEXT_SLOT_PAD_TOP - _TEXT_SLOT_PAD_BOTTOM
	name_slot.add_child(name_label)
	_anchor_slot_child(name_label)
	cell.add_child(name_slot)
	name_label.set_meta("_ach_fit_base", _NAME_FONT_BASE)
	name_label.set_meta("_ach_fit_max_lines", _NAME_MAX_LINES)

	var tier_slot := _make_text_slot(_TIER_SLOT_H)
	var progress := AchievementCatalog.progress_for_cell(id, unlocked_map, _progress_state)
	if progress.get("show", false):
		var tier_label := _make_tier_progress_label(progress)
		tier_slot.add_child(tier_label)
		_anchor_slot_child(tier_label)
	cell.add_child(tier_slot)

	# Description takes leftover cell height so pixel glyphs are never sliced at the baseline.
	var desc_slot := _make_text_slot(_DESC_SLOT_H)
	desc_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if AchievementCatalog.desc_visible(id, unlocked):
		var desc := Label.new()
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		desc.text = tr(AchievementCatalog.display_desc_key(id))
		desc.add_theme_color_override(
			"font_color",
			Color(0.85, 0.85, 0.85, 1.0) if unlocked else _LOCKED_DESC_COLOR
		)
		HudLayout.apply_popup_label(desc, _DESC_FONT_BASE)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.clip_contents = false
		desc.clip_text = false
		desc.max_lines_visible = _DESC_MAX_LINES
		desc.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		desc.custom_minimum_size.y = _DESC_SLOT_H - _TEXT_SLOT_PAD_TOP - _TEXT_SLOT_PAD_BOTTOM
		desc_slot.add_child(desc)
		_anchor_slot_child(desc)
		desc.set_meta("_ach_fit_base", _DESC_FONT_BASE)
		desc.set_meta("_ach_fit_max_lines", _DESC_MAX_LINES)
	cell.add_child(desc_slot)

	return cell


func _make_text_slot(height: float) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(0.0, height)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# clip_contents sliced pixel descenders; labels use clip_text=false instead.
	slot.clip_contents = false
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return slot


func _anchor_slot_child(child: Control) -> void:
	child.set_anchors_preset(Control.PRESET_FULL_RECT)
	child.offset_left = 0.0
	child.offset_top = _TEXT_SLOT_PAD_TOP
	child.offset_right = 0.0
	child.offset_bottom = -_TEXT_SLOT_PAD_BOTTOM
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _make_tier_progress_label(progress: Dictionary) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = false
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(0.0, _TIER_SLOT_H)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = _tier_progress_bbcode(progress)
	if HudLayout.uses_pixel_font():
		label.set_meta("_force_pixel_font", true)
		HudLayout.apply_live_pixel_richtext(label, _TIER_PROGRESS_FONT)
	else:
		HudLayout.apply_body_richtext(label, _TIER_PROGRESS_FONT)
		HudLayout.apply_safe_outline(label, 8)
	return label


func _tier_progress_bbcode(progress: Dictionary) -> String:
	var thresholds: Array = progress.get("thresholds", [])
	var highlight_index := int(progress.get("highlight_index", -1))
	var hi_hex := _TIER_COUNTER_HIGHLIGHT.to_html(false)
	var dim_hex := _TIER_COUNTER_DIM.to_html(false)
	var parts: PackedStringArray = []
	for i in thresholds.size():
		var hex := hi_hex if i == highlight_index else dim_hex
		parts.append("[color=#%s]%d[/color]" % [hex, int(thresholds[i])])
	return "[center]%s[/center]" % "/".join(parts)


## Keeps the main icon centered; tier cup uses a fixed slot on the 120px frame.
func _make_icon_row(
	id: String,
	unlocked: bool,
	show_identity: bool,
	unlocked_map: Dictionary
) -> Control:
	var icon_wrap := CenterContainer.new()
	icon_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_wrap.custom_minimum_size.y = _ICON_PX
	icon_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frame := Control.new()
	frame.custom_minimum_size = Vector2(_ICON_PX, _ICON_PX)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_make_icon_stack(id, unlocked, show_identity))

	var badge_path := ""
	if show_identity:
		badge_path = AchievementCatalog.display_tier_badge_path(id, unlocked_map)
	if not badge_path.is_empty() and ResourceLoader.exists(badge_path):
		frame.add_child(_make_corner_tier_badge(badge_path, unlocked))
	if _is_achievement_unseen(id, unlocked):
		frame.add_child(_make_new_badge())

	icon_wrap.add_child(frame)
	return icon_wrap


func _make_corner_tier_badge(path: String, unlocked: bool) -> TextureRect:
	var badge := TextureRect.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(_BADGE_PX, _BADGE_PX)
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	badge.texture = load(path)
	badge.modulate = Color.WHITE if unlocked else _NEXT_BADGE_MODULATE
	badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.offset_left = -_BADGE_PX - _BADGE_INSET
	badge.offset_top = -_BADGE_PX - _BADGE_INSET
	badge.offset_right = -_BADGE_INSET
	badge.offset_bottom = -_BADGE_INSET
	return badge


func _is_achievement_unseen(id: String, unlocked: bool) -> bool:
	if not unlocked or SaveManager == null:
		return false
	return SaveManager.is_achievement_unseen(id)


func _make_new_badge() -> Label:
	var badge := HudLayout.build_plain_notification_badge(_ICON_PX)
	badge.name = "NewBadge"
	var dims := HudLayout.plain_notification_badge_size(_ICON_PX)
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -dims.x - _NEW_BADGE_INSET
	badge.offset_top = _NEW_BADGE_INSET
	badge.offset_right = -_NEW_BADGE_INSET
	badge.offset_bottom = _NEW_BADGE_INSET + dims.y
	badge.visible = true
	return badge


## Base achievement icon; art is centered in the frame so tier badges align across rows.
func _make_icon_stack(id: String, unlocked: bool, show_identity: bool) -> Control:
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(_ICON_PX, _ICON_PX)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var art := Control.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_preset(Control.PRESET_CENTER)
	var art_half := _ICON_ART_PX * 0.5
	art.offset_left = -art_half
	art.offset_top = -art_half
	art.offset_right = art_half
	art.offset_bottom = art_half

	var icon_path := AchievementCatalog.icon_path(id)
	if not show_identity:
		icon_path = AchievementCatalog.hidden_locked_icon_path()

	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var icon := _make_full_rect_icon(icon_path)
		icon.modulate = Color.WHITE if (show_identity and unlocked) else _LOCKED_ICON_MODULATE
		art.add_child(icon)

	if not unlocked:
		art.add_child(_make_lock_scrim())
		art.add_child(_make_lock_overlay())

	stack.add_child(art)
	return stack


func _make_full_rect_icon(path: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 0
	icon.offset_top = 0
	icon.offset_right = 0
	icon.offset_bottom = 0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(path):
		icon.texture = load(path)
	return icon


## Dark rounded veil over a locked achievement icon.
func _make_lock_scrim() -> Panel:
	var scrim := Panel.new()
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.offset_left = 0
	scrim.offset_top = 0
	scrim.offset_right = 0
	scrim.offset_bottom = 0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.07, 0.82)
	style.set_corner_radius_all(int(_LOCK_SCRIM_RADIUS))
	style.set_border_width_all(2)
	style.border_color = Color(0.0, 0.0, 0.0, 0.55)
	scrim.add_theme_stylebox_override("panel", style)
	return scrim


## Large centered lock badge (same art as level select).
func _make_lock_overlay() -> TextureRect:
	var lock := TextureRect.new()
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock.texture = LOCK_ICON
	lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lock.modulate = Color(1.0, 1.0, 1.0, 0.96)
	lock.set_anchors_preset(Control.PRESET_CENTER)
	var half := LOCK_OVERLAY_PX * 0.5
	lock.offset_left = -half
	lock.offset_top = -half
	lock.offset_right = half
	lock.offset_bottom = half
	return lock


func _fit_all_cell_labels() -> void:
	if _grid == null:
		return
	var name_labels: Array[Label] = []
	var desc_labels: Array[Label] = []
	for child in _grid.get_children():
		if child is VBoxContainer:
			_collect_fit_labels(child as VBoxContainer, name_labels, desc_labels)
	for label in name_labels:
		var max_lines := int(label.get_meta("_ach_fit_max_lines", _NAME_MAX_LINES))
		_apply_fitted_label_size(label, _name_font_size(label), max_lines)
	for label in desc_labels:
		var max_lines := int(label.get_meta("_ach_fit_max_lines", _DESC_MAX_LINES))
		_apply_fitted_label_size(label, _desc_font_size(label), max_lines)


func _name_font_size(label: Label) -> int:
	if HudLayout.control_uses_pixel_font(label):
		return _NAME_FONT_BASE
	return HudLayout.body_font_size(_NAME_FONT_BASE)


func _desc_font_size(label: Label) -> int:
	if HudLayout.control_uses_pixel_font(label):
		return _DESC_FONT_BASE
	return HudLayout.body_font_size(_DESC_FONT_BASE)


func _collect_fit_labels(cell: VBoxContainer, name_labels: Array[Label], desc_labels: Array[Label]) -> void:
	for child in cell.get_children():
		if child is Control:
			for label in (child as Control).get_children():
				if label is Label and label.has_meta("_ach_fit_base"):
					var base := int(label.get_meta("_ach_fit_base"))
					if base == _NAME_FONT_BASE:
						name_labels.append(label as Label)
					elif base == _DESC_FONT_BASE:
						desc_labels.append(label as Label)


func _apply_fitted_label_size(label: Label, size: int, max_lines: int) -> void:
	if HudLayout.control_uses_pixel_font(label):
		var color := (
			label.get_theme_color("font_color")
			if label.has_theme_color_override("font_color")
			else Color.WHITE
		)
		HudLayout.apply_live_pixel_label_settings(label, label.text, size, color)
	else:
		label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = max_lines
	label.clip_contents = false
	label.clip_text = false


## Safe-area header, close button, and phone-width-capped paged grid region.
func _layout() -> void:
	_style_header()
	_style_close()
	_style_page_nav()
	if title_label:
		title_label.offset_top = SafeInsets.padded_top(GameConstants.SCREEN_HEADER_TOP)
		title_label.offset_bottom = title_label.offset_top + GameConstants.SCREEN_HEADER_HEIGHT
	if progress_label and title_label:
		progress_label.offset_top = title_label.offset_bottom + 4.0
		progress_label.offset_bottom = progress_label.offset_top + 32.0
	if _list_host and title_label:
		var list_top := title_label.offset_bottom + _BELOW_TITLE_GAP
		if progress_label:
			list_top = progress_label.offset_bottom + 12.0
		_list_host.offset_top = list_top
		_list_host.offset_bottom = SafeInsets.padded_bottom_offset(
			HudLayout.page_nav_content_bottom_offset(_RESERVE_MENU_BANNER_NAV)
		)
		_list_host.offset_left = GameConstants.HUD_SIDE_MARGIN + SafeInsets.left()
		_list_host.offset_right = -GameConstants.HUD_SIDE_MARGIN - SafeInsets.right()
		HudLayout.cap_stretched_width(_list_host, HudLayout.UI_PHONE_CONTENT_WIDTH)
		_list_host.alignment = BoxContainer.ALIGNMENT_BEGIN
	if _page_nav and _nav_host:
		HudLayout.pin_page_nav_row(_page_nav, _nav_host, _RESERVE_MENU_BANNER_NAV)
	_pin_grid_to_top()
	if _header_host:
		_header_host.move_to_front()
	if _close_host:
		_close_host.move_to_front()
	call_deferred("_fit_all_cell_labels")


func _on_close() -> void:
	_commit_viewed_pages_seen()
	back_requested.emit()


func _commit_viewed_pages_seen() -> void:
	if SaveManager == null or _viewed_page_indices.is_empty():
		return
	if _all_pages_viewed():
		SaveManager.mark_achievements_seen()
		_notify_unseen_changed()
		return
	_commit_pages_seen(_viewed_page_indices.keys())


func _commit_page_seen(page_idx: int) -> void:
	_commit_pages_seen([page_idx])


func _commit_pages_seen(page_indices: Array) -> void:
	if SaveManager == null or page_indices.is_empty():
		return
	var ids: Array = []
	var seen_ids: Dictionary = {}
	for raw_page in page_indices:
		var page_idx := int(raw_page)
		var start := page_idx * _ITEMS_PER_PAGE
		var end := mini(start + _ITEMS_PER_PAGE, _all_ids.size())
		for i in range(start, end):
			for sid in AchievementCatalog.seen_ids_for_grid_cell(str(_all_ids[i]), _unlocked_map):
				if seen_ids.has(sid):
					continue
				seen_ids[sid] = true
				ids.append(sid)
	if ids.is_empty():
		return
	SaveManager.mark_achievements_seen_for_ids(ids)
	_notify_unseen_changed()


func _notify_unseen_changed() -> void:
	if AchievementManager:
		AchievementManager.notify_unseen_changed()


func _all_pages_viewed() -> bool:
	if _all_ids.is_empty():
		return true
	var last := _max_page_index()
	for page_idx in range(last + 1):
		if not _viewed_page_indices.has(page_idx):
			return false
	return true


## Android back closes this overlay.
func handle_system_back() -> bool:
	if not visible:
		return false
	_on_close()
	return true
