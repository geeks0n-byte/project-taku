extends Control

const DEV_DIR = GameConstants.DEV_LEVELS_DIR
const LEVELS_PER_PAGE := 12
const PREVIEW_SIZE := 96
const LOCK_ICON := preload("res://resources/tiles/tile_lock.svg")
const LEVEL_LOCK_ICON_SIZE := 200.0
const TAB_LOCK_ICON_SIZE := 64.0
const TAB_LOCK_ALPHA := 0.9

@onready var level_grid: GridContainer = $"UILayer/CenterContainer/VBoxContainer/LevelListHost/LevelGrid"
@onready var back_button: Button = $"UILayer/CloseButtonHost/BackButton"
@onready var _page_nav: HBoxContainer = $"UILayer/CenterContainer/VBoxContainer/PageNav"
@onready var _page_prev_button: Button = $"UILayer/CenterContainer/VBoxContainer/PageNav/PrevSlot/PrevButton"
@onready var _page_next_button: Button = $"UILayer/CenterContainer/VBoxContainer/PageNav/NextSlot/NextButton"
@onready var easy_tab_button: Button = $"UILayer/CenterContainer/VBoxContainer/TabContainer/EasyTabButton"
@onready var medium_tab_button: Button = $"UILayer/CenterContainer/VBoxContainer/TabContainer/MediumTabButton"
@onready var hard_tab_button: Button = $"UILayer/CenterContainer/VBoxContainer/TabContainer/HardTabButton"
@onready var custom_tab_button: Button = $"UILayer/CustomTabButton"
@onready var button_template: Button = $"UILayer/CenterContainer/VBoxContainer/LevelListHost/LevelGrid/LevelButtonTemplate"
@onready var locked_button_template: Button = $"UILayer/CenterContainer/VBoxContainer/LevelListHost/LevelGrid/LevelButtonTemplateLocked"
@onready var custom_button_template: Button = $"UILayer/CenterContainer/VBoxContainer/LevelListHost/LevelGrid/LevelButtonTemplateCustom"
@onready var empty_state_label: Label = $"UILayer/CenterContainer/VBoxContainer/LevelListHost/EmptyStateLabel"
@onready var content_root: Control = $"UILayer/CenterContainer"
@onready var content_vbox: VBoxContainer = $"UILayer/CenterContainer/VBoxContainer"
@onready var tab_container: HBoxContainer = $"UILayer/CenterContainer/VBoxContainer/TabContainer"
@onready var tab_list_gap: Control = $"UILayer/CenterContainer/VBoxContainer/TabListGap"
@onready var _title_label: Label = $"UILayer/ScreenHeaderHost/TitleLabel"

enum ViewMode { EASY, MEDIUM, HARD, CUSTOM }
var current_view: ViewMode = ViewMode.EASY
var _level_entries: Array = []
var _page_index: int = 0

func _ready() -> void:
	if AdsManager:
		AdsManager.show_menu_banner()
		AdsManager.warm_rewarded_hint()
	for template in [button_template, locked_button_template, custom_button_template]:
		if template and template.get_parent() == level_grid:
			level_grid.remove_child(template)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if _page_prev_button:
		_page_prev_button.pressed.connect(_on_page_prev)
	if _page_next_button:
		_page_next_button.pressed.connect(_on_page_next)
	if easy_tab_button:
		easy_tab_button.pressed.connect(func(): _switch_view(ViewMode.EASY))
	if medium_tab_button:
		medium_tab_button.pressed.connect(func(): _switch_view(ViewMode.MEDIUM))
	if hard_tab_button:
		hard_tab_button.pressed.connect(func(): _switch_view(ViewMode.HARD))
	if custom_tab_button:
		custom_tab_button.pressed.connect(func(): _switch_view(ViewMode.CUSTOM))
	_configure_custom_tab()
	_layout_level_select()
	if not _is_category_unlocked(current_view):
		current_view = _first_unlocked_view()
	_fit_chrome_buttons()
	_update_tab_button_visuals()
	populate_level_menu()
	if SaveManager and not SaveManager.language_changed.is_connected(_on_language_changed):
		SaveManager.language_changed.connect(_on_language_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if GlobalGameManager and GlobalGameManager.consume_system_back():
			_on_back_pressed()

func _fit_chrome_buttons() -> void:
	_apply_close_button()
	_configure_custom_tab()
	for btn in [
		easy_tab_button,
		medium_tab_button,
		hard_tab_button,
	]:
		if btn == null:
			continue
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, GameConstants.UI_BTN_TAB_SIZE.y)
		btn.add_theme_color_override("font_outline_color", Color.BLACK)
		HudLayout.apply_safe_outline(btn, GameConstants.MENU_TEXT_OUTLINE)
		btn.autowrap_mode = TextServer.AUTOWRAP_OFF
		btn.clip_text = false
		HudLayout.fit_text_button(
			btn, GameConstants.UI_BTN_TAB_FONT, GameConstants.UI_BTN_TAB_FONT_MIN
		)
		btn.autowrap_mode = TextServer.AUTOWRAP_OFF
	if custom_tab_button and custom_tab_button.visible:
		HudLayout.apply_secondary_button(custom_tab_button)
		HudLayout.apply_safe_outline(custom_tab_button, GameConstants.MENU_TEXT_OUTLINE)
		custom_tab_button.text = "UI_CUSTOM"
	if _page_prev_button:
		HudLayout.apply_nav_button(_page_prev_button)
	if _page_next_button:
		HudLayout.apply_nav_button(_page_next_button)

func _apply_close_button() -> void:
	if back_button:
		HudLayout.style_top_bar_close_button(back_button)

func _on_language_changed() -> void:
	HudLayout.apply_locale_fonts_to_tree(self)
	_fit_chrome_buttons()
	_update_tab_button_visuals()
	populate_level_menu()
	if _title_label:
		HudLayout._bind_header_translation_key(_title_label, "UI_SELECT_LEVEL")
		HudLayout.apply_screen_header_style(_title_label)

func _layout_level_select() -> void:
	if _title_label:
		HudLayout._bind_header_translation_key(_title_label, "UI_SELECT_LEVEL")
		HudLayout.apply_screen_header_style(_title_label)
	_connect_level_list_host()
	_pin_level_list_to_top()

func _connect_level_list_host() -> void:
	var host := content_vbox.get_node_or_null("LevelListHost") as Control if content_vbox else null
	if host == null:
		return
	if not host.resized.is_connected(_pin_level_list_to_top):
		host.resized.connect(_pin_level_list_to_top)
	if level_grid:
		level_grid.columns = 3
		level_grid.add_theme_constant_override("h_separation", 30)
		level_grid.add_theme_constant_override("v_separation", 30)

func _pin_level_list_to_top() -> void:
	var host := content_vbox.get_node_or_null("LevelListHost") as Control if content_vbox else null
	if host == null:
		return
	var host_w := host.size.x
	if host_w <= 0.0:
		return

	if level_grid and level_grid.get_parent() == host:
		level_grid.set_anchors_preset(Control.PRESET_TOP_LEFT)
		level_grid.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		level_grid.grow_vertical = Control.GROW_DIRECTION_BEGIN
		level_grid.size_flags_horizontal = 0
		level_grid.size_flags_vertical = 0
		level_grid.clip_contents = false
		const ROW_H := 240.0
		for child in level_grid.get_children():
			if child is Button:
				var btn := child as Button
				btn.custom_minimum_size = Vector2(btn.custom_minimum_size.x, ROW_H)
				btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var cols := maxi(1, level_grid.columns)
		var page_rows := int(ceili(float(LEVELS_PER_PAGE) / float(cols)))
		var sep := level_grid.get_theme_constant("v_separation")
		# Always reserve a full page so paging never shifts the list upward.
		var reserved_h := page_rows * ROW_H + maxi(0, page_rows - 1) * sep
		level_grid.position = Vector2.ZERO
		level_grid.size = Vector2(host_w, reserved_h)
		host.custom_minimum_size = Vector2(0, reserved_h)
		host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	if empty_state_label and empty_state_label.get_parent() == host and empty_state_label.visible:
		empty_state_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		empty_state_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		empty_state_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		empty_state_label.size_flags_horizontal = 0
		empty_state_label.size_flags_vertical = 0
		var label_h := empty_state_label.get_combined_minimum_size().y
		empty_state_label.position = Vector2.ZERO
		empty_state_label.size = Vector2(host_w, maxf(label_h, 1.0))
		host.custom_minimum_size = Vector2(0, maxf(label_h, 1.0))
		host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

func _configure_custom_tab() -> void:
	var show_custom := GlobalGameManager.debug_tools_enabled
	if custom_tab_button:
		custom_tab_button.visible = show_custom
		if show_custom:
			custom_tab_button.text = "UI_CUSTOM"
	if not show_custom and current_view == ViewMode.CUSTOM:
		current_view = ViewMode.EASY

func _switch_view(new_mode: ViewMode) -> void:
	if new_mode == ViewMode.CUSTOM and not GlobalGameManager.debug_tools_enabled:
		return
	if new_mode != ViewMode.CUSTOM and not _is_category_unlocked(new_mode):
		return
	if current_view == new_mode:
		return
	current_view = new_mode
	_page_index = 0
	_update_tab_button_visuals()
	populate_level_menu()

func _first_unlocked_view() -> ViewMode:
	for view in [ViewMode.EASY, ViewMode.MEDIUM, ViewMode.HARD]:
		if _is_category_unlocked(view):
			return view
	return ViewMode.EASY

func _is_category_unlocked(view: ViewMode) -> bool:
	if view == ViewMode.CUSTOM:
		return GlobalGameManager.debug_tools_enabled
	return true

func _update_tab_button_visuals() -> void:
	var tabs := [
		[easy_tab_button, ViewMode.EASY, Color(0.45, 1.0, 0.45)],
		[medium_tab_button, ViewMode.MEDIUM, Color(1.0, 0.85, 0.35)],
		[hard_tab_button, ViewMode.HARD, Color(1.0, 0.45, 0.4)],
		[custom_tab_button, ViewMode.CUSTOM, Color(1.0, 0.84, 0.0)],
	]
	for entry in tabs:
		var btn: Button = entry[0]
		if not btn:
			continue
		var view: ViewMode = entry[1]
		var accent: Color = entry[2]
		var unlocked: bool = _is_category_unlocked(view)
		var active: bool = current_view == view
		btn.disabled = not unlocked
		if unlocked:
			btn.modulate = accent if active else Color(0.6, 0.6, 0.6)
		else:
			btn.modulate = Color(0.35, 0.35, 0.35, 1.0)
		_set_tab_lock_icon(btn, not unlocked)

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

func populate_level_menu() -> void:
	if not level_grid or not button_template:
		return

	_level_entries.clear()
	var paths: Array = []
	if current_view == ViewMode.CUSTOM:
		paths = LevelUtils.scan_directory(DEV_DIR)
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
			title = tr("CUSTOM_LVL") + " " + str(resource.level_number)
		else:
			var display_num := LevelUtils.get_display_level_number(resource)
			title = tr("LEVEL") + " " + str(display_num)
			locked = not SaveManager.is_level_unlocked(resource.level_number)
		_level_entries.append({
			"resource": resource,
			"title": title,
			"locked": locked,
		})

	_page_index = clampi(_page_index, 0, _max_page_index())
	_refresh_page()

func _max_page_index() -> int:
	if _level_entries.is_empty():
		return 0
	return int(ceili(float(_level_entries.size()) / float(LEVELS_PER_PAGE))) - 1

func _on_page_prev() -> void:
	_page_index = maxi(_page_index - 1, 0)
	_refresh_page()

func _on_page_next() -> void:
	_page_index = mini(_page_index + 1, _max_page_index())
	_refresh_page()

func _refresh_page() -> void:
	for child in level_grid.get_children():
		if child not in [button_template, locked_button_template, custom_button_template]:
			level_grid.remove_child(child)
			child.queue_free()

	var valid_level_count := _level_entries.size()
	if empty_state_label:
		empty_state_label.visible = valid_level_count == 0
		if empty_state_label.visible:
			HudLayout.apply_body_label(empty_state_label, GameConstants.UI_BODY_FONT_SIZE)
		empty_state_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if level_grid:
		level_grid.visible = valid_level_count > 0
		level_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var start := _page_index * LEVELS_PER_PAGE
	var end := mini(start + LEVELS_PER_PAGE, valid_level_count)
	for i in range(start, end):
		var entry: Dictionary = _level_entries[i]
		var resource: LevelData = entry["resource"]
		var title: String = entry["title"]
		var locked: bool = entry["locked"]
		var btn: Button
		if current_view == ViewMode.CUSTOM:
			btn = custom_button_template.duplicate() as Button
			btn.disabled = false
		elif locked:
			btn = locked_button_template.duplicate() as Button
			btn.disabled = true
		else:
			btn = button_template.duplicate() as Button
			btn.disabled = false
		btn.visible = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_apply_level_button_content(btn, resource, title, locked)
		btn.pressed.connect(_on_level_selected.bind(resource))
		level_grid.add_child(btn)

	_update_page_nav_visibility()
	_pin_level_list_to_top()
	call_deferred("_pin_level_list_to_top")

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
	_apply_close_button()

func _folder_for_view(view: ViewMode) -> String:
	match view:
		ViewMode.MEDIUM:
			return GameConstants.CAMPAIGN_MEDIUM_DIR
		ViewMode.HARD:
			return GameConstants.CAMPAIGN_HARD_DIR
		_:
			return GameConstants.CAMPAIGN_EASY_DIR

func _apply_level_button_content(btn: Button, level: LevelData, title: String, locked: bool) -> void:
	btn.text = ""
	btn.custom_minimum_size = Vector2(260, 240)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	btn.clip_text = true
	btn.clip_contents = false

	var content := Control.new()
	content.name = "LevelContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 14.0
	content.offset_top = 22.0
	content.offset_right = -14.0
	content.offset_bottom = -34.0

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var preview_frame := PanelContainer.new()
	preview_frame.name = "PreviewFrame"
	preview_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview_frame.add_theme_stylebox_override("panel", LevelPreview.make_frame_style())

	var preview := TextureRect.new()
	preview.name = "Preview"
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.custom_minimum_size = Vector2(PREVIEW_SIZE, PREVIEW_SIZE)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture = LevelPreview.make_texture(level, GameConstants.LEVEL_PREVIEW_SIZE)
	if locked:
		preview.modulate = Color(0.45, 0.45, 0.45, 1.0)
		preview_frame.modulate = Color(0.7, 0.7, 0.7, 1.0)
	preview_frame.add_child(preview)
	vbox.add_child(preview_frame)

	var preview_label_gap := Control.new()
	preview_label_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_label_gap.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(preview_label_gap)

	var label := Label.new()
	label.name = "Title"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_override("font", HudLayout.ui_font())
	label.add_theme_font_size_override(
		"font_size", HudLayout.scaled_font_size(GameConstants.UI_BTN_SECONDARY_FONT)
	)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	HudLayout.apply_safe_outline(label, GameConstants.MENU_TEXT_OUTLINE)
	if locked:
		label.add_theme_color_override("font_color", btn.get_theme_color("font_disabled_color"))
	else:
		label.add_theme_color_override("font_color", btn.get_theme_color("font_color"))
	vbox.add_child(label)

	if not locked:
		var earned_bits := SaveManager.get_level_star_bits(level.level_number)
		var star_row := LevelStars.make_select_star_row(level, earned_bits)
		vbox.add_child(star_row)

	content.add_child(vbox)

	if locked:
		var half := LEVEL_LOCK_ICON_SIZE * 0.5
		var lock_overlay := TextureRect.new()
		lock_overlay.name = "LockOverlay"
		lock_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_overlay.texture = LOCK_ICON
		lock_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock_overlay.modulate = Color(1, 1, 1, 0.9)
		lock_overlay.custom_minimum_size = Vector2(LEVEL_LOCK_ICON_SIZE, LEVEL_LOCK_ICON_SIZE)
		lock_overlay.set_anchors_preset(Control.PRESET_CENTER)
		lock_overlay.offset_left = -half
		lock_overlay.offset_top = -half - 28.0
		lock_overlay.offset_right = half
		lock_overlay.offset_bottom = half - 28.0
		content.add_child(lock_overlay)

	btn.add_child(content)

func _on_level_selected(resource: LevelData) -> void:
	GlobalGameManager.selected_level_resource = resource
	GlobalGameManager.go_to_scene("res://scenes/main.tscn")

func _on_back_pressed() -> void:
	GlobalGameManager.go_to_scene("res://scenes/main_menu.tscn")
