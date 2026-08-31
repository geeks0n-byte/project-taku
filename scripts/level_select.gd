extends Control
## Level-select grid, difficulty tabs, star-goals popup, and first-run tutorial prompt.

const DEV_DIR = GameConstants.DEV_LEVELS_DIR
const LEVELS_PER_PAGE := 12
const PREVIEW_SIZE := 96
const LOCK_ICON := preload("res://resources/tiles/tile_lock.svg")
const LEVEL_LOCK_ICON_SIZE := 200.0
const TAB_LOCK_ICON_SIZE := 64.0
const TAB_LOCK_ALPHA := 0.9
## Above CloseButtonHost/BackButton (z_index 20) and PageNav so the dimmer covers all chrome.
const LEVEL_GOALS_OVERLAY_Z := 30
const LEVEL_GOALS_PANEL_WIDTH := 720.0
const LEVEL_GOALS_TITLE_FONT := 36
const LEVEL_GOALS_TITLE_COLOR := Color(1.0, 0.92, 0.55, 1.0)
const _RESERVE_MENU_BANNER_NAV := true

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
@onready var _close_button_host: Control = $"UILayer/CloseButtonHost"
@onready var _screen_header_host: Control = $"UILayer/ScreenHeaderHost"

## Corresponds to the four difficulty tabs; CUSTOM is only visible in debug builds.
enum ViewMode { EASY, MEDIUM, HARD, CUSTOM }
var current_view: ViewMode = ViewMode.EASY
# Flat list of {resource, title, locked} dicts for the active tab, rebuilt on tab switch.
var _level_entries: Array = []
# Zero-based page currently displayed; clamped to valid range before each refresh.
var _page_index: int = 0
# Level chosen before the first-run tutorial intro prompt; played if the player declines.
var _pending_level: LevelData = null
@onready var _tutorial_intro_blocker: ColorRect = $"UILayer/TutorialIntroBlocker"
@onready var _tutorial_intro_label: Label = (
	$"UILayer/TutorialIntroBlocker/CenterContainer/Panel/VBoxContainer/PromptLabel"
)
@onready var _tutorial_intro_yes: Button = (
	$"UILayer/TutorialIntroBlocker/CenterContainer/Panel/VBoxContainer/HBoxContainer/YesButton"
)
@onready var _tutorial_intro_no: Button = (
	$"UILayer/TutorialIntroBlocker/CenterContainer/Panel/VBoxContainer/HBoxContainer/NoButton"
)
@onready var _level_goals_blocker: ColorRect = $"UILayer/LevelGoalsBlocker"
@onready var _level_goals_title: RichTextLabel = (
	$"UILayer/LevelGoalsBlocker/CenterContainer/Panel/VBoxContainer/Title"
)
@onready var _level_goals_host: Control = (
	$"UILayer/LevelGoalsBlocker/CenterContainer/Panel/VBoxContainer/GoalsHost"
)
@onready var _level_goals_play: Button = (
	$"UILayer/LevelGoalsBlocker/CenterContainer/Panel/VBoxContainer/DialogButtons/PlayButton"
)
@onready var _level_goals_close: Button = (
	$"UILayer/LevelGoalsBlocker/CenterContainer/Panel/VBoxContainer/DialogButtons/CloseButton"
)
var _level_goals_level: LevelData = null

## Wires chrome, layouts the grid, and styles authored overlay panels.
func _ready() -> void:
	if AdsManager:
		AdsManager.show_menu_banner()
		# Pre-load the rewarded-ad unit so there's no latency when the player first asks for a hint.
		AdsManager.warm_rewarded_hint()
	# Template buttons live in the scene tree as design references; remove them before populating.
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
	_reparent_page_nav()
	_layout_level_select()
	# If the default tab is locked (e.g. only Easy is unlocked initially), fall back gracefully.
	if not _is_category_unlocked(current_view):
		current_view = _first_unlocked_view()
	_fit_chrome_buttons()
	_update_tab_button_visuals()
	populate_level_menu()
	_setup_tutorial_intro_panel()
	_setup_level_goals_popup()
	if SaveManager and not SaveManager.language_changed.is_connected(_on_language_changed):
		SaveManager.language_changed.connect(_on_language_changed)
	if SaveManager and not SaveManager.unseen_levels_changed.is_connected(_on_unseen_levels_changed):
		SaveManager.unseen_levels_changed.connect(_on_unseen_levels_changed)
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)

## Relays viewport changes into the phone-capped level-select layout.
func _on_viewport_resized() -> void:
	_layout_level_select()


## Rebuilds level cards when a new-level badge is cleared.
func _on_unseen_levels_changed(_count: int) -> void:
	_refresh_page()

## Hardware back closes tutorial/goals popups first, then leaves the screen.
func _notification(what: int) -> void:
	# Handle the Android/iOS hardware back button — treat it the same as the UI back button.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if GlobalGameManager and GlobalGameManager.consume_system_back():
			if _tutorial_intro_blocker and _tutorial_intro_blocker.visible:
				_hide_tutorial_intro_prompt()
				return
			if _level_goals_blocker and _level_goals_blocker.visible:
				_hide_level_goals_popup()
				return
			_on_back_pressed()

## Applies consistent styling to all chrome buttons (tabs, page nav, close).
## Called on ready and again whenever the language changes to handle font switches.
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

## Styles the top-left close control as a square top-bar X.
func _apply_close_button() -> void:
	if back_button:
		HudLayout.style_top_bar_close_button(back_button)

## Re-applies fonts and rebuilds the menu when the player changes language at runtime.
func _on_language_changed() -> void:
	HudLayout.apply_locale_fonts_to_tree(self)
	_fit_chrome_buttons()
	_update_tab_button_visuals()
	populate_level_menu()
	if _title_label:
		HudLayout._bind_header_translation_key(_title_label, "UI_SELECT_LEVEL")
		HudLayout.apply_screen_header_style(_title_label)
	if _tutorial_intro_blocker and _tutorial_intro_blocker.visible:
		_show_tutorial_intro_prompt()
	if _level_goals_blocker and _level_goals_blocker.visible and _level_goals_level:
		var earned_bits := SaveManager.get_level_star_bits(_level_goals_level.level_number) if SaveManager else 0
		_show_level_goals_popup(_level_goals_level, earned_bits)

## Pads title/content for safe-area and caps the column to phone content width.
func _layout_level_select() -> void:
	if _title_label:
		HudLayout._bind_header_translation_key(_title_label, "UI_SELECT_LEVEL")
		HudLayout.apply_screen_header_style(_title_label)
		var title_top := SafeInsets.padded_top(GameConstants.SCREEN_HEADER_TOP)
		_title_label.offset_top = title_top
		_title_label.offset_bottom = title_top + GameConstants.SCREEN_HEADER_HEIGHT
		if content_vbox:
			const VBOX_AUTHORED_TOP := (
				GameConstants.SCREEN_HEADER_TOP
				+ GameConstants.SCREEN_HEADER_HEIGHT
				+ GameConstants.SCREEN_CONTENT_GAP
			)
			content_vbox.offset_top = VBOX_AUTHORED_TOP + (title_top - GameConstants.SCREEN_HEADER_TOP)
			content_vbox.offset_bottom = SafeInsets.padded_bottom_offset(
				HudLayout.page_nav_content_bottom_offset(_RESERVE_MENU_BANNER_NAV)
			)
			content_vbox.offset_left = 24.0 + SafeInsets.left()
			content_vbox.offset_right = -24.0 - SafeInsets.right()
			HudLayout.cap_stretched_width(content_vbox, HudLayout.UI_PHONE_CONTENT_WIDTH)
		if _page_nav and content_root:
			HudLayout.pin_page_nav_row(_page_nav, content_root, _RESERVE_MENU_BANNER_NAV)
	_connect_level_list_host()
	_pin_level_list_to_top()


## Moves PREV/NEXT out of the scroll column so they share the global pinned nav row.
func _reparent_page_nav() -> void:
	if _page_nav == null or content_root == null:
		return
	if _page_nav.get_parent() != content_root:
		_page_nav.reparent(content_root)
	var gap := content_vbox.get_node_or_null("PageNavGap") if content_vbox else null
	if gap:
		gap.queue_free()

## Wires the LevelListHost resize signal to keep layout pinned to the top, and
## sets the grid to 3 columns with consistent spacing.
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

## Pins the level grid to the top-left of its host and reserves exactly one full page
## of height so the layout doesn't jump when navigating between pages with fewer items.
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
			if child is Control:
				var cell := child as Control
				cell.custom_minimum_size = Vector2(cell.custom_minimum_size.x, ROW_H)
				cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				cell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var cols := maxi(1, level_grid.columns)
		var page_rows := int(ceili(float(LEVELS_PER_PAGE) / float(cols)))
		var sep := level_grid.get_theme_constant("v_separation")
		# Always reserve a full page so paging never shifts the list upward.
		var reserved_h := page_rows * ROW_H + maxi(0, page_rows - 1) * sep
		# Cap to phone content width and center. No-op when host is already 1032 (phones).
		var grid_w := minf(host_w, HudLayout.UI_PHONE_CONTENT_WIDTH)
		if grid_w < 1.0:
			grid_w = host_w
		level_grid.size = Vector2(grid_w, reserved_h)
		level_grid.position = Vector2((host_w - grid_w) * 0.5, 0.0)
		host.custom_minimum_size = Vector2(0, reserved_h)
		host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	if empty_state_label and empty_state_label.get_parent() == host and empty_state_label.visible:
		empty_state_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		empty_state_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		empty_state_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		empty_state_label.size_flags_horizontal = 0
		empty_state_label.size_flags_vertical = 0
		var label_h := empty_state_label.get_combined_minimum_size().y
		const EMPTY_STATE_TOP := 160.0
		empty_state_label.position = Vector2(0, EMPTY_STATE_TOP)
		empty_state_label.size = Vector2(host_w, maxf(label_h, 1.0))
		host.custom_minimum_size = Vector2(0, EMPTY_STATE_TOP + maxf(label_h, 1.0))
		host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

## Shows or hides the Custom tab depending on whether dev/debug tools are enabled.
## If the tab is hidden while it's the active view, resets to Easy.
func _configure_custom_tab() -> void:
	var show_custom := GlobalGameManager.debug_tools_enabled
	if custom_tab_button:
		custom_tab_button.visible = show_custom
		if show_custom:
			custom_tab_button.text = "UI_CUSTOM"
	if not show_custom and current_view == ViewMode.CUSTOM:
		current_view = ViewMode.EASY

## Switches the active difficulty tab, resets to page 0, and repopulates the grid.
## Guards against switching to locked or unavailable categories.
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

## Finds the first playable non-Custom view in Easy→Medium→Hard order.
## Falls back to Easy if nothing is explicitly unlocked (should not happen in normal play).
func _first_unlocked_view() -> ViewMode:
	for view in [ViewMode.EASY, ViewMode.MEDIUM, ViewMode.HARD]:
		if _is_category_unlocked(view):
			return view
	return ViewMode.EASY

## All non-Custom categories are always accessible; Custom requires debug tools enabled.
func _is_category_unlocked(view: ViewMode) -> bool:
	if view == ViewMode.CUSTOM:
		return GlobalGameManager.debug_tools_enabled
	return true

## Refreshes tab button modulate and disabled state to reflect the active view.
## Active tab uses its accent color; inactive tabs are grey; locked tabs are dark with a lock icon.
func _update_tab_button_visuals() -> void:
	var tabs := [
		[easy_tab_button, ViewMode.EASY, Color(0.45, 1.0, 0.45)],
		[medium_tab_button, ViewMode.MEDIUM, Color(1.0, 0.85, 0.35)],
		[hard_tab_button, ViewMode.HARD, Color(1.0, 0.45, 0.4)],
		[custom_tab_button, ViewMode.CUSTOM, Color(0.72, 0.48, 1.0)],
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

## Lazily adds or removes a centered lock-icon overlay on a tab button.
## The icon is created on first use and reused on subsequent calls.
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

## Scans the correct directory for the active tab, loads all valid LevelData resources,
## builds the _level_entries list, then renders the current page.
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
	_refresh_page()

## Returns the index of the last valid page (0-based). Returns 0 when the list is empty.
func _max_page_index() -> int:
	if _level_entries.is_empty():
		return 0
	return int(ceili(float(_level_entries.size()) / float(LEVELS_PER_PAGE))) - 1

## Steps one page backward and rebuilds the grid.
func _on_page_prev() -> void:
	_page_index = maxi(_page_index - 1, 0)
	_refresh_page()

## Steps one page forward and rebuilds the grid.
func _on_page_next() -> void:
	_page_index = mini(_page_index + 1, _max_page_index())
	_refresh_page()

## Clears all dynamically-added buttons from the grid and re-populates the current page.
## Template nodes are retained so they can be duplicated again on the next refresh.
func _refresh_page() -> void:
	for child in level_grid.get_children():
		if child not in [button_template, locked_button_template, custom_button_template]:
			level_grid.remove_child(child)
			child.queue_free()

	var valid_level_count := _level_entries.size()
	if empty_state_label:
		empty_state_label.visible = valid_level_count == 0
		if empty_state_label.visible:
			var empty_key := (
				"UI_NO_CUSTOM_LEVELS"
				if current_view == ViewMode.CUSTOM
				else "UI_NO_PLAYABLE_LEVELS"
			)
			empty_state_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			empty_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var empty_text := str(TranslationServer.translate(empty_key))
			# Pixel/display font used by menus; larger than body copy.
			const EMPTY_FONT := 40
			HudLayout.apply_raster_pixel_label(
				empty_state_label, empty_text, EMPTY_FONT, Color(1, 1, 1, 1)
			)
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

	# Pad the last row so a short custom page keeps the same 3-column widths as campaign.
	var page_count := end - start
	var pad := HudLayout.grid_row_pad_count(page_count, maxi(1, level_grid.columns))
	for _i in pad:
		var filler := Control.new()
		filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
		filler.custom_minimum_size = Vector2(260, 240)
		filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		filler.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		level_grid.add_child(filler)

	_update_page_nav_visibility()
	_pin_level_list_to_top()
	call_deferred("_pin_level_list_to_top")

## Shows prev/next arrows only when there is more than one page of levels, and only
## for the direction the player can actually navigate to from the current page.
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

## Maps a ViewMode to the resource directory where its LevelData files are stored.
func _folder_for_view(view: ViewMode) -> String:
	match view:
		ViewMode.MEDIUM:
			return GameConstants.CAMPAIGN_MEDIUM_DIR
		ViewMode.HARD:
			return GameConstants.CAMPAIGN_HARD_DIR
		_:
			return GameConstants.CAMPAIGN_EASY_DIR

## Populates a level button with a corner number, preview thumbnail, and star row.
## Locked levels get a greyed-out preview and a centered lock icon overlay instead of stars.
## Preview Y is top-aligned so locked and unlocked cards share the same thumbnail height.
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
	# Extra inset so the number isn't flush against the card edge/bevel.
	label.offset_left = 10.0
	label.offset_top = 8.0
	label.grow_horizontal = Control.GROW_DIRECTION_END
	label.grow_vertical = Control.GROW_DIRECTION_END
	const TITLE_FONT := 32
	var title_color := Color(0.55, 0.55, 0.55, 1.0) if locked else Color.WHITE
	HudLayout.apply_raster_pixel_label(label, title, TITLE_FONT, title_color, 0, true)
	content.add_child(label)

	# Small top inset for the preview stack (independent of the corner number overlay).
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
	preview.custom_minimum_size = Vector2(PREVIEW_SIZE, PREVIEW_SIZE)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture = LevelPreview.make_texture(level, GameConstants.LEVEL_PREVIEW_SIZE)
	# Desaturate the preview and frame slightly so locked levels look unavailable.
	if locked:
		preview.modulate = Color(0.45, 0.45, 0.45, 1.0)
		preview_frame.modulate = Color(0.7, 0.7, 0.7, 1.0)
	preview_frame.add_child(preview)
	vbox.add_child(preview_frame)

	if not locked:
		var earned_bits := SaveManager.get_level_star_bits(level.level_number)
		var star_row := LevelStars.make_select_star_row(level, earned_bits)
		vbox.add_child(star_row)

	content.add_child(vbox)
	# Keep the number above the preview if they overlap.
	content.move_child(label, content.get_child_count() - 1)

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
		# Overlay on the preview (top-aligned); keep out of layout so card size stays stable.
		lock_overlay.anchor_left = 0.5
		lock_overlay.anchor_right = 0.5
		lock_overlay.anchor_top = 0.0
		lock_overlay.anchor_bottom = 0.0
		var preview_mid_y := PREVIEW_TOP + PREVIEW_SIZE * 0.5
		lock_overlay.offset_left = -half
		lock_overlay.offset_right = half
		lock_overlay.offset_top = preview_mid_y - half
		lock_overlay.offset_bottom = preview_mid_y + half
		content.add_child(lock_overlay)

	btn.add_child(content)

	if not locked and current_view != ViewMode.CUSTOM and SaveManager:
		if SaveManager.is_level_unseen(level.level_number):
			var badge := HudLayout.attach_notification_badge_corner(btn, btn.custom_minimum_size.y)
			badge.visible = true

## Opens the level detail popup (star goals + play). Locked levels stay disabled.
func _on_level_selected(resource: LevelData) -> void:
	if SaveManager:
		SaveManager.mark_level_seen(resource.level_number)
	var earned_bits := SaveManager.get_level_star_bits(resource.level_number) if SaveManager else 0
	_show_level_goals_popup(resource, earned_bits)

## Stores the chosen level and switches to the main gameplay scene.
func _enter_gameplay(resource: LevelData) -> void:
	if SaveManager:
		SaveManager.mark_level_seen(resource.level_number)
	GlobalGameManager.selected_level_resource = resource
	GlobalGameManager.go_to_scene("res://scenes/main.tscn")

## Closes an open overlay first; otherwise returns to the main menu.
func _on_back_pressed() -> void:
	if _tutorial_intro_blocker and _tutorial_intro_blocker.visible:
		_hide_tutorial_intro_prompt()
		return
	if _level_goals_blocker and _level_goals_blocker.visible:
		_hide_level_goals_popup()
		return
	GlobalGameManager.go_to_scene("res://scenes/main_menu.tscn")

## Styles the authored first-run tutorial prompt (no dimmer; chrome hides instead).
func _setup_tutorial_intro_panel() -> void:
	if _tutorial_intro_blocker == null:
		return
	_tutorial_intro_blocker.visible = false
	_tutorial_intro_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_tutorial_intro_blocker.color = Color(0, 0, 0, 0)
	var center := _tutorial_intro_blocker.get_node_or_null("CenterContainer") as Control
	if center:
		HudLayout.raise_centered_dialog_host(center)
	var panel := _tutorial_intro_blocker.get_node_or_null("CenterContainer/Panel") as Panel
	if panel:
		panel.add_theme_stylebox_override("panel", HudLayout.make_dialog_panel_style())
	if _tutorial_intro_label:
		_tutorial_intro_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55, 1.0))
	_copy_dialog_button_styles(_tutorial_intro_yes)
	_copy_dialog_button_styles(_tutorial_intro_no)
	if _tutorial_intro_yes and not _tutorial_intro_yes.pressed.is_connected(_on_tutorial_intro_yes):
		_tutorial_intro_yes.pressed.connect(_on_tutorial_intro_yes)
	if _tutorial_intro_no and not _tutorial_intro_no.pressed.is_connected(_on_tutorial_intro_no):
		_tutorial_intro_no.pressed.connect(_on_tutorial_intro_no)

## Copies tab StyleBoxes onto a dialog button so popups match the rest of the screen.
func _copy_dialog_button_styles(target: Button) -> void:
	var source: Button = easy_tab_button if easy_tab_button else button_template
	if not source or not target:
		return
	for style_name in ["normal", "pressed", "hover", "disabled"]:
		var style := source.get_theme_stylebox(style_name)
		if style and not (style is StyleBoxEmpty):
			target.add_theme_stylebox_override(style_name, style)
	target.add_theme_color_override("font_outline_color", Color.BLACK)
	HudLayout.apply_safe_outline(target, GameConstants.MENU_TEXT_OUTLINE)

## Hides/shows the grid chrome while a full-screen prompt is up.
func _set_level_select_chrome_visible(should_show: bool) -> void:
	if content_root:
		content_root.visible = should_show
	if _screen_header_host:
		_screen_header_host.visible = should_show
	if _close_button_host:
		_close_button_host.visible = should_show
	if custom_tab_button:
		custom_tab_button.visible = should_show and (
			GlobalGameManager != null and GlobalGameManager.debug_tools_enabled
		)

## Hides chrome and shows the first-run Yes/No tutorial prompt.
func _show_tutorial_intro_prompt() -> void:
	_set_level_select_chrome_visible(false)
	if _tutorial_intro_label:
		_tutorial_intro_label.text = tr("TUTORIAL_INTRO_PROMPT")
		HudLayout.apply_popup_label(
			_tutorial_intro_label, GameConstants.UI_BODY_FONT_SIZE_LARGE
		)
	if _tutorial_intro_yes:
		_tutorial_intro_yes.text = tr("UI_YES")
		_copy_dialog_button_styles(_tutorial_intro_yes)
	if _tutorial_intro_no:
		_tutorial_intro_no.text = tr("UI_NO")
		_copy_dialog_button_styles(_tutorial_intro_no)
	var panel := _tutorial_intro_blocker.get_node_or_null("CenterContainer/Panel") as Panel if _tutorial_intro_blocker else null
	if panel:
		HudLayout.fit_dialog_panel(panel, HudLayout.UI_DEFAULT_DIALOG_WIDTH)
	if _tutorial_intro_blocker:
		_tutorial_intro_blocker.color = Color(0, 0, 0, 0)
		_tutorial_intro_blocker.visible = true
		_tutorial_intro_blocker.move_to_front()

## Dismisses the tutorial prompt and restores the level-select chrome.
func _hide_tutorial_intro_prompt() -> void:
	_pending_level = null
	if _tutorial_intro_blocker:
		_tutorial_intro_blocker.visible = false
	_set_level_select_chrome_visible(true)
	_configure_custom_tab()

## Records the intro answer and launches the first incomplete tutorial level.
func _on_tutorial_intro_yes() -> void:
	var fallback := _pending_level
	_hide_tutorial_intro_prompt()
	if SaveManager:
		SaveManager.set_tutorial_intro_answered(true)
	var tutorial := _first_tutorial_level()
	if tutorial:
		_enter_gameplay(tutorial)
	elif fallback:
		_enter_gameplay(fallback)

## Records the intro answer and plays the pending campaign level instead.
func _on_tutorial_intro_no() -> void:
	var chosen := _pending_level
	_hide_tutorial_intro_prompt()
	if SaveManager:
		SaveManager.set_tutorial_intro_answered(true)
	if chosen:
		_enter_gameplay(chosen)

## Styles the authored star-goals popup. Star rows are still filled at show time.
func _setup_level_goals_popup() -> void:
	if _level_goals_blocker == null:
		return
	_level_goals_blocker.visible = false
	_level_goals_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_level_goals_blocker.color = Color(0, 0, 0, 0.45)
	_level_goals_blocker.z_index = LEVEL_GOALS_OVERLAY_Z
	if not _level_goals_blocker.gui_input.is_connected(_on_level_goals_blocker_gui_input):
		_level_goals_blocker.gui_input.connect(_on_level_goals_blocker_gui_input)
	var center := _level_goals_blocker.get_node_or_null("CenterContainer") as Control
	if center:
		HudLayout.raise_centered_dialog_host(center)
	var panel := _level_goals_blocker.get_node_or_null("CenterContainer/Panel") as Panel
	if panel:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.add_theme_stylebox_override("panel", HudLayout.make_dialog_panel_style())
	if _level_goals_play and not _level_goals_play.pressed.is_connected(_on_level_goals_play):
		_level_goals_play.pressed.connect(_on_level_goals_play)
	if _level_goals_close and not _level_goals_close.pressed.is_connected(_hide_level_goals_popup):
		_level_goals_close.pressed.connect(_hide_level_goals_popup)
	_copy_dialog_button_styles(_level_goals_play)
	_copy_dialog_button_styles(_level_goals_close)

## Click-outside on the dimmer closes the goals popup.
func _on_level_goals_blocker_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hide_level_goals_popup()

## Fills the authored goals popup with this level's star requirements and shows it.
func _show_level_goals_popup(level: LevelData, earned_bits: int) -> void:
	if _level_goals_blocker == null or _level_goals_host == null:
		return
	_level_goals_level = level
	var title_num := (
		str(int(level.level_number))
		if current_view == ViewMode.CUSTOM
		else str(int(LevelUtils.get_display_level_number(level)))
	)
	_level_goals_title.text = "%s %s" % [tr("UI_LEVEL"), title_num]
	HudLayout.apply_popup_title_with_number(
		_level_goals_title, tr("UI_LEVEL"), title_num, LEVEL_GOALS_TITLE_FONT, LEVEL_GOALS_TITLE_COLOR
	)
	if _level_goals_play:
		_level_goals_play.text = tr("UI_PLAY")
		_copy_dialog_button_styles(_level_goals_play)
		HudLayout.apply_dialog_button(_level_goals_play)
	if _level_goals_close:
		_level_goals_close.text = tr("UI_CLOSE")
		_copy_dialog_button_styles(_level_goals_close)
		HudLayout.apply_dialog_button(_level_goals_close)
	var panel := _level_goals_blocker.get_node_or_null("CenterContainer/Panel") as Panel
	while _level_goals_host.get_child_count() > 0:
		_level_goals_host.get_child(0).free()
	LevelStars.populate_requirements(
		_level_goals_host,
		level,
		earned_bits,
		LevelStars.RESULTS_CONTENT_WIDTH,
		true
	)
	if panel:
		var content_w := HudLayout.fit_dialog_panel(panel, LEVEL_GOALS_PANEL_WIDTH, 420.0)
		if _level_goals_host.get_child_count() > 0:
			var stars_root := _level_goals_host.get_child(0) as Control
			if stars_root:
				_level_goals_host.custom_minimum_size.y = HudDialogs.measure_control_height(
					stars_root, minf(content_w, LevelStars.RESULTS_CONTENT_WIDTH)
				)
		HudLayout.fit_dialog_panel(panel, LEVEL_GOALS_PANEL_WIDTH, 420.0)
	_level_goals_blocker.visible = true
	_level_goals_blocker.move_to_front()

## Hides the star-goals popup without starting the level.
func _hide_level_goals_popup() -> void:
	_level_goals_level = null
	if _level_goals_blocker:
		_level_goals_blocker.visible = false

## Starts the chosen level, or the tutorial intro if it has not been answered.
func _on_level_goals_play() -> void:
	var resource := _level_goals_level
	_hide_level_goals_popup()
	if resource == null:
		return
	if SaveManager and not SaveManager.tutorial_intro_answered:
		_pending_level = resource
		_show_tutorial_intro_prompt()
		return
	_enter_gameplay(resource)

## First incomplete tutorial LevelData, or null if every lesson is done.
func _first_tutorial_level() -> LevelData:
	return TutorialScripts.first_incomplete_level()
