extends CanvasLayer
## Full-screen achievements grid with paged prev/next navigation (like level select).

signal back_requested

@onready var title_label: Label = $ScreenHeaderHost/TitleLabel
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
const _ROW_H := 252.0
const _CELL_SEP_H := 24
const _CELL_SEP_V := 24
const _ICON_PX := 120.0
const _ICON_ART_PX := 96.0
const _BADGE_PX := 48.0
const _BADGE_INSET := 0.0
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
const _NAME_FONT_MIN := 18
const _DESC_FONT_BASE := 22
const _DESC_FONT_MIN := 16
const LOCK_ICON := preload("res://resources/tiles/tile_lock.svg")
const LOCK_OVERLAY_PX := 88.0
const _LOCK_SCRIM_RADIUS := 22.0

var _progress_state: Dictionary = {}
var _all_ids: Array = []
var _unlocked_map: Dictionary = {}
var _page_index: int = 0


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


func _on_resized() -> void:
	if visible:
		_layout()


func _on_language_changed() -> void:
	if visible:
		refresh()


func _style_header() -> void:
	if title_label == null:
		return
	HudLayout._bind_header_translation_key(title_label, "UI_ACHIEVEMENTS")
	HudLayout.apply_screen_header_style(title_label)


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
	_style_header()
	_style_close()
	_style_page_nav()
	_load_catalog_state()
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
			"rules_opens": SaveManager.rules_opens,
		}
	_all_ids = AchievementCatalog.grid_ids(_unlocked_map)


func _max_page_index() -> int:
	if _all_ids.is_empty():
		return 0
	return int(ceili(float(_all_ids.size()) / float(_ITEMS_PER_PAGE))) - 1


func _on_page_prev() -> void:
	_page_index = maxi(_page_index - 1, 0)
	_refresh_page()
	call_deferred("_fit_all_cell_labels")


func _on_page_next() -> void:
	_page_index = mini(_page_index + 1, _max_page_index())
	_refresh_page()
	call_deferred("_fit_all_cell_labels")


## Clears the grid and fills only the current page slice (4 rows × 2 columns).
func _refresh_page() -> void:
	if _grid == null:
		return
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
		cell.custom_minimum_size.y = _ROW_H
		cell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_grid.add_child(cell)

	var page_count := end - start
	for _i in HudLayout.grid_row_pad_count(page_count, _GRID_COLUMNS):
		var pad := Control.new()
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pad.custom_minimum_size.y = _ROW_H
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
	var reserved_h := _ROWS_PER_PAGE * _ROW_H + maxi(0, _ROWS_PER_PAGE - 1) * sep
	var grid_w := minf(host_w, HudLayout.UI_PHONE_CONTENT_WIDTH)
	if grid_w < 1.0:
		grid_w = host_w
	_grid.size = Vector2(grid_w, reserved_h)
	_grid.position = Vector2((host_w - grid_w) * 0.5, 0.0)
	_grid_host.custom_minimum_size = Vector2(0, reserved_h)
	_grid_host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


## One grid cell: icon + tier medal, title, optional progress + description.
func _make_cell(id: String, unlocked_map: Dictionary) -> Control:
	var unlocked: bool = AchievementCatalog.cell_is_unlocked(id, unlocked_map)
	var show_identity := AchievementCatalog.identity_visible(id, unlocked)
	var cell := VBoxContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cell.add_theme_constant_override("separation", 8)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(_make_icon_row(id, unlocked, show_identity, unlocked_map))

	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text = tr(AchievementCatalog.display_title_key(id, unlocked))
	var name_color := (
		GameConstants.SCREEN_HEADER_COLOR if unlocked else _LOCKED_TITLE_COLOR
	)
	name_label.add_theme_color_override("font_color", name_color)
	HudLayout.apply_popup_label(name_label, _NAME_FONT_BASE)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_contents = false
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_child(name_label)
	name_label.set_meta("_ach_fit_base", _NAME_FONT_BASE)
	name_label.set_meta("_ach_fit_min", _NAME_FONT_MIN)

	var progress := AchievementCatalog.progress_for_cell(id, unlocked_map, _progress_state)
	if progress.get("show", false):
		cell.add_child(_make_tier_progress_label(progress))

	if AchievementCatalog.desc_visible(id, unlocked):
		var desc := Label.new()
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.text = tr(AchievementCatalog.display_desc_key(id))
		desc.add_theme_color_override(
			"font_color",
			Color(0.85, 0.85, 0.85, 1.0) if unlocked else _LOCKED_DESC_COLOR
		)
		HudLayout.apply_popup_label(desc, _DESC_FONT_BASE)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.clip_contents = false
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_child(desc)
		desc.set_meta("_ach_fit_base", _DESC_FONT_BASE)
		desc.set_meta("_ach_fit_min", _DESC_FONT_MIN)

	return cell


func _make_tier_progress_label(progress: Dictionary) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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


## Keeps the main icon centered; tier medal uses a fixed slot on the 120px frame.
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
	var cell_w := _cell_label_width()
	for child in _grid.get_children():
		if child is VBoxContainer:
			_fit_cell_labels(child as VBoxContainer, cell_w)


func _cell_label_width() -> float:
	var grid_w := _grid.size.x if _grid else HudLayout.UI_PHONE_CONTENT_WIDTH
	if grid_w <= 1.0:
		grid_w = HudLayout.UI_PHONE_CONTENT_WIDTH
	var col_w := (grid_w - float(_CELL_SEP_H)) / 2.0
	return maxf(96.0, col_w - 20.0)


func _fit_cell_labels(cell: VBoxContainer, target_w: float) -> void:
	for label in cell.get_children():
		if label is Label and label.has_meta("_ach_fit_base"):
			_fit_wrapped_label(
				label as Label,
				int(label.get_meta("_ach_fit_base")),
				int(label.get_meta("_ach_fit_min")),
				target_w
			)


func _fit_wrapped_label(label: Label, base_size: int, min_size: int, target_w: float) -> void:
	var text := label.text
	if text.is_empty():
		return
	var font: Font = label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	if font == null:
		return
	var use_pixel := HudLayout.control_uses_pixel_font(label)
	var size := HudLayout.snap_pixel_font_size(base_size) if use_pixel else HudLayout.body_font_size(base_size)
	var floor_size := HudLayout.snap_pixel_font_size(min_size) if use_pixel else HudLayout.body_font_size(min_size)
	var step := 8 if use_pixel else 2
	while size > floor_size:
		var measured := font.get_multiline_string_size(
			text,
			HORIZONTAL_ALIGNMENT_CENTER,
			target_w,
			size
		)
		if measured.y <= size * 3.2:
			break
		size = maxi(floor_size, size - step)
	if use_pixel:
		var color := label.get_theme_color("font_color") if label.has_theme_color_override("font_color") else Color.WHITE
		HudLayout.apply_live_pixel_label_settings(label, text, size, color)
	else:
		label.add_theme_font_size_override("font_size", size)


## Safe-area header, close button, and phone-width-capped paged grid region.
func _layout() -> void:
	_style_header()
	_style_close()
	_style_page_nav()
	if title_label:
		title_label.offset_top = SafeInsets.padded_top(GameConstants.SCREEN_HEADER_TOP)
		title_label.offset_bottom = title_label.offset_top + GameConstants.SCREEN_HEADER_HEIGHT
	if _list_host and title_label:
		_list_host.offset_top = title_label.offset_bottom + _BELOW_TITLE_GAP
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
	back_requested.emit()


## Android back closes this overlay.
func handle_system_back() -> bool:
	if not visible:
		return false
	back_requested.emit()
	return true
