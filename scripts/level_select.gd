extends Control

const DEV_DIR = GameConstants.DEV_LEVELS_DIR
const PREVIEW_SIZE := 120
const LOCK_ICON := preload("res://resources/tiles/tile_lock.svg")
const LEVEL_LOCK_ICON_SIZE := 240.0
const TAB_LOCK_ICON_SIZE := 36.0

@onready var level_grid: GridContainer = $"UILayer/CenterContainer/VBoxContainer/ScrollContainer/LevelGrid"
@onready var back_button: Button = $"UILayer/CenterContainer/VBoxContainer/BackButton"
@onready var tutorials_tab_button: Button = $"UILayer/CenterContainer/VBoxContainer/TabContainer/TutorialsTabButton"
@onready var easy_tab_button: Button = $"UILayer/CenterContainer/VBoxContainer/TabContainer/EasyTabButton"
@onready var medium_tab_button: Button = $"UILayer/CenterContainer/VBoxContainer/TabContainer/MediumTabButton"
@onready var hard_tab_button: Button = $"UILayer/CenterContainer/VBoxContainer/TabContainer/HardTabButton"
@onready var custom_tab_button: Button = $"UILayer/CenterContainer/VBoxContainer/TabContainer/CustomTabButton"
@onready var button_template: Button = $"UILayer/CenterContainer/VBoxContainer/ScrollContainer/LevelGrid/LevelButtonTemplate"
@onready var locked_button_template: Button = $"UILayer/CenterContainer/VBoxContainer/ScrollContainer/LevelGrid/LevelButtonTemplateLocked"
@onready var custom_button_template: Button = $"UILayer/CenterContainer/VBoxContainer/ScrollContainer/LevelGrid/LevelButtonTemplateCustom"
@onready var empty_state_label: Label = $"UILayer/CenterContainer/VBoxContainer/EmptyStateLabel"
@onready var scroll_container: ScrollContainer = $"UILayer/CenterContainer/VBoxContainer/ScrollContainer"

enum ViewMode { TUTORIALS, EASY, MEDIUM, HARD, CUSTOM }
var current_view: ViewMode = ViewMode.TUTORIALS

func _ready() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if tutorials_tab_button:
		tutorials_tab_button.pressed.connect(func(): _switch_view(ViewMode.TUTORIALS))
	if easy_tab_button:
		easy_tab_button.pressed.connect(func(): _switch_view(ViewMode.EASY))
	if medium_tab_button:
		medium_tab_button.pressed.connect(func(): _switch_view(ViewMode.MEDIUM))
	if hard_tab_button:
		hard_tab_button.pressed.connect(func(): _switch_view(ViewMode.HARD))
	if custom_tab_button:
		custom_tab_button.pressed.connect(func(): _switch_view(ViewMode.CUSTOM))
	_configure_custom_tab()
	_mount_header()
	if not _is_category_unlocked(current_view):
		current_view = _first_unlocked_view()
	_fit_chrome_buttons()
	_update_tab_button_visuals()
	populate_level_menu()
	if SaveManager and not SaveManager.language_changed.is_connected(_on_language_changed):
		SaveManager.language_changed.connect(_on_language_changed)

func _fit_chrome_buttons() -> void:
	HudLayout.apply_primary_button(back_button)
	for btn in [
		tutorials_tab_button,
		easy_tab_button,
		medium_tab_button,
		hard_tab_button,
		custom_tab_button,
	]:
		if btn == null:
			continue
		# Custom tab is slightly wider for the translated label.
		if btn == custom_tab_button:
			btn.custom_minimum_size = Vector2(220, GameConstants.UI_BTN_TAB_SIZE.y)
			HudLayout.fit_text_button(
				btn, GameConstants.UI_BTN_TAB_FONT, GameConstants.UI_BTN_TAB_FONT_MIN
			)
		else:
			HudLayout.apply_tab_button(btn)

func _on_language_changed() -> void:
	_fit_chrome_buttons()
	_update_tab_button_visuals()
	populate_level_menu()

func _mount_header() -> void:
	var ui_layer := $UILayer as CanvasLayer
	var title := $UILayer/CenterContainer/VBoxContainer/TitleLabel as Label
	if ui_layer and title:
		# Host must be a Control for anchors; use a full-rect root under the layer.
		var host := ui_layer.get_node_or_null("ScreenHeaderHost") as Control
		if host == null:
			host = Control.new()
			host.name = "ScreenHeaderHost"
			host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			host.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ui_layer.add_child(host)
			ui_layer.move_child(host, 0)
		HudLayout.mount_screen_header(host, title)
	# Keep content below the shared header band.
	var center := $UILayer/CenterContainer as Control
	if center:
		HudLayout.pin_menu_body_below_header(center, 1180.0)

func _configure_custom_tab() -> void:
	var show_custom := GlobalGameManager.debug_tools_enabled
	if custom_tab_button:
		custom_tab_button.visible = show_custom
	if not show_custom and current_view == ViewMode.CUSTOM:
		current_view = ViewMode.TUTORIALS

func _switch_view(new_mode: ViewMode) -> void:
	if new_mode == ViewMode.CUSTOM and not GlobalGameManager.debug_tools_enabled:
		return
	if new_mode != ViewMode.CUSTOM and not _is_category_unlocked(new_mode):
		return
	if current_view == new_mode:
		return
	current_view = new_mode
	_update_tab_button_visuals()
	populate_level_menu()

func _first_unlocked_view() -> ViewMode:
	for view in [ViewMode.TUTORIALS, ViewMode.EASY, ViewMode.MEDIUM, ViewMode.HARD]:
		if _is_category_unlocked(view):
			return view
	return ViewMode.TUTORIALS

func _is_category_unlocked(view: ViewMode) -> bool:
	if view == ViewMode.CUSTOM:
		return GlobalGameManager.debug_tools_enabled
	# Tutorials and Easy are available from the start.
	if view == ViewMode.TUTORIALS or view == ViewMode.EASY:
		return true
	var paths := LevelUtils.scan_directory(_folder_for_view(view))
	LevelUtils.sort_level_paths(paths)
	var found_any := false
	for path in paths:
		var resource = load(path)
		if resource and resource is LevelData:
			found_any = true
			if SaveManager.is_level_unlocked(resource.level_number):
				return true
	# Empty category stays selectable; only lock when every level is locked.
	return not found_any

func _update_tab_button_visuals() -> void:
	var tabs := [
		[tutorials_tab_button, ViewMode.TUTORIALS, Color(0.55, 0.85, 1.0)],
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
		existing.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		existing.offset_left = -TAB_LOCK_ICON_SIZE - 10.0
		existing.offset_right = -10.0
		existing.offset_top = -TAB_LOCK_ICON_SIZE * 0.5
		existing.offset_bottom = TAB_LOCK_ICON_SIZE * 0.5
		existing.modulate = Color(1, 1, 1, 0.9)
		button.add_child(existing)
	existing.visible = true

func populate_level_menu() -> void:
	if not level_grid or not button_template:
		return

	for child in level_grid.get_children():
		if child not in [button_template, locked_button_template, custom_button_template]:
			child.queue_free()

	var paths: Array = []
	if current_view == ViewMode.CUSTOM:
		paths = LevelUtils.scan_directory(DEV_DIR)
	else:
		paths = LevelUtils.scan_directory(_folder_for_view(current_view))
	LevelUtils.sort_level_paths(paths)

	var valid_level_count := 0
	var tutorial_index := 0
	for path in paths:
		var resource = load(path)
		if resource and resource is LevelData:
			valid_level_count += 1
			var btn: Button
			var title: String
			var locked := false
			if current_view == ViewMode.CUSTOM:
				btn = custom_button_template.duplicate() as Button
				title = tr("CUSTOM_LVL") + " " + str(resource.level_number)
				btn.disabled = false
			elif current_view == ViewMode.TUTORIALS:
				tutorial_index += 1
				btn = button_template.duplicate() as Button
				title = tr("TUTORIAL") + " " + str(tutorial_index)
				btn.disabled = false
			else:
				var is_unlocked = SaveManager.is_level_unlocked(resource.level_number)
				var display_num := LevelUtils.get_display_level_number(resource)
				if is_unlocked:
					btn = button_template.duplicate() as Button
					title = tr("LEVEL") + " " + str(display_num)
					btn.disabled = false
				else:
					btn = locked_button_template.duplicate() as Button
					title = tr("LEVEL") + " " + str(display_num)
					btn.disabled = true
					locked = true
			btn.visible = true
			_apply_level_button_content(btn, resource, title, locked)
			btn.pressed.connect(_on_level_selected.bind(resource))
			level_grid.add_child(btn)

	if empty_state_label:
		empty_state_label.visible = (valid_level_count == 0)
		if empty_state_label.visible:
			HudLayout.apply_body_label(empty_state_label, GameConstants.UI_BODY_FONT_SIZE)
	if scroll_container:
		scroll_container.visible = (valid_level_count > 0)

func _folder_for_view(view: ViewMode) -> String:
	match view:
		ViewMode.TUTORIALS:
			return GameConstants.CAMPAIGN_TUTORIALS_DIR
		ViewMode.MEDIUM:
			return GameConstants.CAMPAIGN_MEDIUM_DIR
		ViewMode.HARD:
			return GameConstants.CAMPAIGN_HARD_DIR
		_:
			return GameConstants.CAMPAIGN_EASY_DIR

func _apply_level_button_content(btn: Button, level: LevelData, title: String, locked: bool) -> void:
	btn.text = ""
	var show_preview := current_view != ViewMode.TUTORIALS
	btn.custom_minimum_size = Vector2(260, 280 if show_preview else 200)
	btn.clip_text = true

	var content := Control.new()
	content.name = "LevelContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 16.0
	content.offset_top = 16.0
	content.offset_right = -16.0
	content.offset_bottom = -16.0

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	if show_preview:
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
		vbox.add_child(preview)

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
		"font_size", HudLayout.scaled_font_size(GameConstants.UI_BTN_TAB_FONT)
	)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	if locked:
		label.add_theme_color_override("font_color", btn.get_theme_color("font_disabled_color"))
	else:
		label.add_theme_color_override("font_color", btn.get_theme_color("font_color"))
	vbox.add_child(label)

	if not locked and current_view != ViewMode.TUTORIALS:
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
		lock_overlay.offset_top = -half - (18.0 if show_preview else 0.0)
		lock_overlay.offset_right = half
		lock_overlay.offset_bottom = half - (18.0 if show_preview else 0.0)
		content.add_child(lock_overlay)

	btn.add_child(content)

func _on_level_selected(resource: LevelData) -> void:
	GlobalGameManager.selected_level_resource = resource
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
