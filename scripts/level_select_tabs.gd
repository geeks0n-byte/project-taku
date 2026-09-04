class_name LevelSelectTabs
extends RefCounted
## Difficulty tabs, level grid paging, and campaign/custom level lists for level select.


enum ViewMode { EASY, MEDIUM, HARD, CUSTOM }

const LEVELS_PER_PAGE := 12
const LOCK_ICON := preload("res://resources/tiles/tile_lock.svg")
const TAB_LOCK_ICON_SIZE := 64.0
const TAB_LOCK_ALPHA := 0.9

var current_view: ViewMode = ViewMode.EASY

var _level_grid: GridContainer
var _page_nav: HBoxContainer
var _page_prev_button: Button
var _page_next_button: Button
var _easy_tab_button: Button
var _medium_tab_button: Button
var _hard_tab_button: Button
var _custom_tab_button: Button
var _button_template: Button
var _locked_button_template: Button
var _custom_button_template: Button
var _empty_state_label: Label
var _level_entries: Array = []
var _page_index: int = 0
var _on_level_selected: Callable
var _apply_button_content: Callable
var _pin_level_list: Callable
var _defer_pin_level_list: Callable
var _apply_close_button: Callable


func bind(
	level_grid: GridContainer,
	page_nav: HBoxContainer,
	page_prev_button: Button,
	page_next_button: Button,
	easy_tab_button: Button,
	medium_tab_button: Button,
	hard_tab_button: Button,
	custom_tab_button: Button,
	button_template: Button,
	locked_button_template: Button,
	custom_button_template: Button,
	empty_state_label: Label,
	on_level_selected: Callable,
	apply_button_content: Callable,
	pin_level_list: Callable,
	defer_pin_level_list: Callable,
	apply_close_button: Callable
) -> void:
	_level_grid = level_grid
	_page_nav = page_nav
	_page_prev_button = page_prev_button
	_page_next_button = page_next_button
	_easy_tab_button = easy_tab_button
	_medium_tab_button = medium_tab_button
	_hard_tab_button = hard_tab_button
	_custom_tab_button = custom_tab_button
	_button_template = button_template
	_locked_button_template = locked_button_template
	_custom_button_template = custom_button_template
	_empty_state_label = empty_state_label
	_on_level_selected = on_level_selected
	_apply_button_content = apply_button_content
	_pin_level_list = pin_level_list
	_defer_pin_level_list = defer_pin_level_list
	_apply_close_button = apply_close_button


func switch_view(new_mode: ViewMode) -> void:
	if new_mode == ViewMode.CUSTOM and not GlobalGameManager.debug_tools_enabled:
		return
	if new_mode != ViewMode.CUSTOM and not is_category_unlocked(new_mode):
		return
	if current_view == new_mode:
		return
	current_view = new_mode
	_page_index = 0
	update_tab_button_visuals()
	populate_level_menu()


func first_unlocked_view() -> ViewMode:
	for view in [ViewMode.EASY, ViewMode.MEDIUM, ViewMode.HARD]:
		if is_category_unlocked(view):
			return view
	return ViewMode.EASY


func is_category_unlocked(view: ViewMode) -> bool:
	if view == ViewMode.CUSTOM:
		return GlobalGameManager.debug_tools_enabled
	return true


func populate_level_menu() -> void:
	if not _level_grid or not _button_template:
		return

	_level_entries.clear()
	var paths: Array = []
	if current_view == ViewMode.CUSTOM:
		paths = LevelUtils.scan_directory(GameConstants.DEV_LEVELS_DIR)
	else:
		paths = LevelUtils.scan_directory(_folder_for_view(current_view))
	LevelUtils.sort_level_paths(paths)

	for path in paths:
		var resource = load(path)
		if resource == null or not (resource is LevelData):
			continue
		var title: String
		var locked := false
		if current_view == ViewMode.CUSTOM:
			title = str(int(resource.level_number))
		else:
			var display_num := LevelUtils.get_display_level_number(resource)
			title = str(int(display_num))
			locked = not SaveManager.is_level_unlocked(resource.level_number)
		_level_entries.append({
			"resource": resource,
			"title": title,
			"locked": locked,
		})

	_page_index = clampi(_page_index, 0, _max_page_index())
	refresh_page()


func on_page_prev() -> void:
	_page_index = maxi(_page_index - 1, 0)
	refresh_page()


func on_page_next() -> void:
	_page_index = mini(_page_index + 1, _max_page_index())
	refresh_page()


func refresh_page() -> void:
	for child in _level_grid.get_children():
		if child not in [_button_template, _locked_button_template, _custom_button_template]:
			_level_grid.remove_child(child)
			child.queue_free()

	var valid_level_count := _level_entries.size()
	if _empty_state_label:
		_empty_state_label.visible = valid_level_count == 0
		if _empty_state_label.visible:
			var empty_key := (
				"UI_NO_CUSTOM_LEVELS"
				if current_view == ViewMode.CUSTOM
				else "UI_NO_PLAYABLE_LEVELS"
			)
			_empty_state_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			_empty_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var empty_text := str(TranslationServer.translate(empty_key))
			# Pixel/display font used by menus; larger than body copy.
			const EMPTY_FONT := 40
			HudLayout.apply_raster_pixel_label(
				_empty_state_label, empty_text, EMPTY_FONT, Color(1, 1, 1, 1)
			)
		_empty_state_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if _level_grid:
		_level_grid.visible = valid_level_count > 0
		_level_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var start := _page_index * LEVELS_PER_PAGE
	var end := mini(start + LEVELS_PER_PAGE, valid_level_count)
	for i in range(start, end):
		var entry: Dictionary = _level_entries[i]
		var resource: LevelData = entry["resource"]
		var title: String = entry["title"]
		var locked: bool = entry["locked"]
		var btn: Button
		if current_view == ViewMode.CUSTOM:
			btn = _custom_button_template.duplicate() as Button
			btn.disabled = false
		elif locked:
			btn = _locked_button_template.duplicate() as Button
			btn.disabled = true
		else:
			btn = _button_template.duplicate() as Button
			btn.disabled = false
		btn.visible = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		if _apply_button_content.is_valid():
			_apply_button_content.call(btn, resource, title, locked)
		if _on_level_selected.is_valid():
			btn.pressed.connect(_on_level_selected.bind(resource))
		_level_grid.add_child(btn)

	# Pad the last row so a short custom page keeps the same 3-column widths as campaign.
	var page_count := end - start
	var pad := HudLayout.grid_row_pad_count(page_count, maxi(1, _level_grid.columns))
	for _i in pad:
		var filler := Control.new()
		filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
		filler.custom_minimum_size = Vector2(260, 240)
		filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		filler.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_level_grid.add_child(filler)

	_update_page_nav_visibility()
	if _pin_level_list.is_valid():
		_pin_level_list.call()
	if _defer_pin_level_list.is_valid():
		_defer_pin_level_list.call()


func update_tab_button_visuals() -> void:
	var tabs := [
		[_easy_tab_button, ViewMode.EASY, Color(0.45, 1.0, 0.45)],
		[_medium_tab_button, ViewMode.MEDIUM, Color(1.0, 0.85, 0.35)],
		[_hard_tab_button, ViewMode.HARD, Color(1.0, 0.45, 0.4)],
		[_custom_tab_button, ViewMode.CUSTOM, Color(0.72, 0.48, 1.0)],
	]
	for entry in tabs:
		var btn: Button = entry[0]
		if not btn:
			continue
		var view: ViewMode = entry[1]
		var accent: Color = entry[2]
		var unlocked: bool = is_category_unlocked(view)
		var active: bool = current_view == view
		btn.disabled = not unlocked
		if unlocked:
			btn.modulate = accent if active else Color(0.6, 0.6, 0.6)
		else:
			btn.modulate = Color(0.35, 0.35, 0.35, 1.0)
		_set_tab_lock_icon(btn, not unlocked)


func _max_page_index() -> int:
	if _level_entries.is_empty():
		return 0
	return int(ceili(float(_level_entries.size()) / float(LEVELS_PER_PAGE))) - 1


func _folder_for_view(view: ViewMode) -> String:
	match view:
		ViewMode.MEDIUM:
			return GameConstants.CAMPAIGN_MEDIUM_DIR
		ViewMode.HARD:
			return GameConstants.CAMPAIGN_HARD_DIR
		_:
			return GameConstants.CAMPAIGN_EASY_DIR


func _update_page_nav_visibility() -> void:
	var multi_page := _level_entries.size() > LEVELS_PER_PAGE
	if _page_nav:
		_page_nav.visible = true
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
	HudLayout.sync_page_nav_slots(_page_prev_button, _page_next_button)
	if _apply_close_button.is_valid():
		_apply_close_button.call()


func _set_tab_lock_icon(button: Button, show_lock: bool) -> void:
	if not button:
		return
	var existing := button.get_node_or_null("CategoryLockIcon") as TextureRect
	if not show_lock:
		if existing:
			existing.queue_free()
		return
	if existing == null:
		existing = TextureRect.new()
		existing.name = "CategoryLockIcon"
		existing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		existing.texture = LOCK_ICON
		existing.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		existing.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		existing.custom_minimum_size = Vector2(TAB_LOCK_ICON_SIZE, TAB_LOCK_ICON_SIZE)
		existing.set_anchors_preset(Control.PRESET_CENTER)
		var half := TAB_LOCK_ICON_SIZE * 0.5
		existing.offset_left = -half
		existing.offset_top = -half
		existing.offset_right = half
		existing.offset_bottom = half
		existing.modulate = Color(1, 1, 1, TAB_LOCK_ALPHA)
		button.add_child(existing)
	else:
		existing.custom_minimum_size = Vector2(TAB_LOCK_ICON_SIZE, TAB_LOCK_ICON_SIZE)
		existing.set_anchors_preset(Control.PRESET_CENTER)
		var half := TAB_LOCK_ICON_SIZE * 0.5
		existing.offset_left = -half
		existing.offset_top = -half
		existing.offset_right = half
		existing.offset_bottom = half
		existing.modulate = Color(1, 1, 1, TAB_LOCK_ALPHA)
	existing.visible = true
