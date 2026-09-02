extends Control
## Level-select grid, difficulty tabs, star-goals popup, and first-run tutorial prompt.

const PREVIEW_SIZE := 96
const LOCK_ICON := preload("res://resources/tiles/tile_lock.svg")
const LEVEL_LOCK_ICON_SIZE := 200.0
const LEVEL_GOALS_OVERLAY_Z := 30
const LEVEL_GOALS_PANEL_WIDTH := 720.0
const LEVEL_GOALS_TITLE_FONT := 36
const LEVEL_GOALS_TITLE_COLOR := Color(1.0, 0.92, 0.55, 1.0)

@onready var level_grid: GridContainer = $"UILayer/CenterContainer/VBoxContainer/LevelListHost/LevelGrid"
@onready var back_button: Button = $"UILayer/CloseButtonHost/BackButton"
@onready var _page_nav: HBoxContainer = $"UILayer/CenterContainer/VBoxContainer/PageNav"
@onready var _page_prev_button: Button = $"UILayer/CenterContainer/VBoxContainer/PageNav/PrevSlot/PrevButton"
@onready var _page_next_button: Button = $"UILayer/CenterContainer/VBoxContainer/PageNav/NextSlot/NextButton"
@onready var easy_tab_button: Button = $"UILayer/CenterContainer/VBoxContainer/TabContainer/EasyTabButton"
@onready var medium_tab_button: Button = $"UILayer/CenterContainer/VBoxContainer/TabContainer/MediumTabButton"
@onready var hard_tab_button: Button = $"UILayer/CenterContainer/VBoxContainer/TabContainer/HardTabButton"
@onready var custom_debug_bar_host: HBoxContainer = $"UILayer/CustomDebugBarHost"
@onready var custom_tab_button: Button = $"UILayer/CustomDebugBarHost/CustomTabButton"
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
var _goals_popup := LevelSelectGoalsPopup.new()
var _tutorial_intro := LevelSelectTutorialIntro.new()
var _layout := LevelSelectLayout.new()
var _tabs := LevelSelectTabs.new()


## Wires chrome, layouts the grid, and styles authored overlay panels.
func _ready() -> void:
	if AdsManager:
		AdsManager.show_menu_banner()
		# Pre-load the rewarded-ad unit so there's no latency when the player first asks for a hint.
		AdsManager.warm_rewarded_hint()
	_layout.bind(
		_title_label,
		content_vbox,
		_page_nav,
		_screen_header_host,
		_close_button_host,
		back_button,
		_page_prev_button,
		_page_next_button,
		level_grid,
		empty_state_label,
		easy_tab_button,
		medium_tab_button,
		hard_tab_button,
		custom_tab_button,
		custom_debug_bar_host,
		LevelSelectTabs.LEVELS_PER_PAGE
	)
	_tabs.bind(
		level_grid,
		_page_nav,
		_page_prev_button,
		_page_next_button,
		easy_tab_button,
		medium_tab_button,
		hard_tab_button,
		custom_tab_button,
		button_template,
		locked_button_template,
		custom_button_template,
		empty_state_label,
		_on_level_selected,
		_apply_level_button_content,
		_layout.pin_level_list_to_top,
		_deferred_pin_level_list,
		_layout.apply_close_button
	)
	# Template buttons live in the scene tree as design references; remove them before populating.
	for template in [button_template, locked_button_template, custom_button_template]:
		if template and template.get_parent() == level_grid:
			level_grid.remove_child(template)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if _page_prev_button:
		_page_prev_button.pressed.connect(_tabs.on_page_prev)
	if _page_next_button:
		_page_next_button.pressed.connect(_tabs.on_page_next)
	if easy_tab_button:
		easy_tab_button.pressed.connect(func(): _tabs.switch_view(LevelSelectTabs.ViewMode.EASY))
	if medium_tab_button:
		medium_tab_button.pressed.connect(func(): _tabs.switch_view(LevelSelectTabs.ViewMode.MEDIUM))
	if hard_tab_button:
		hard_tab_button.pressed.connect(func(): _tabs.switch_view(LevelSelectTabs.ViewMode.HARD))
	if custom_tab_button:
		custom_tab_button.pressed.connect(func(): _tabs.switch_view(LevelSelectTabs.ViewMode.CUSTOM))
	_configure_custom_tab()
	_layout.reparent_page_nav()
	_layout.layout_level_select()
	# If the default tab is locked (e.g. only Easy is unlocked initially), fall back gracefully.
	if not _tabs.is_category_unlocked(_tabs.current_view):
		_tabs.current_view = _tabs.first_unlocked_view()
	_layout.fit_chrome_buttons(_configure_custom_tab)
	_tabs.update_tab_button_visuals()
	_tabs.populate_level_menu()
	_setup_tutorial_intro_panel()
	_setup_level_goals_popup()
	_apply_a11y_labels()
	if SaveManager and not SaveManager.language_changed.is_connected(_on_language_changed):
		SaveManager.language_changed.connect(_on_language_changed)
	if SaveManager and not SaveManager.unseen_levels_changed.is_connected(_on_unseen_levels_changed):
		SaveManager.unseen_levels_changed.connect(_on_unseen_levels_changed)
	if SaveManager and not SaveManager.color_blind_patterns_changed.is_connected(_on_color_blind_patterns_changed):
		SaveManager.color_blind_patterns_changed.connect(_on_color_blind_patterns_changed)
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)


func _deferred_pin_level_list() -> void:
	call_deferred("_layout_pin_level_list")


func _layout_pin_level_list() -> void:
	_layout.pin_level_list_to_top()


func _apply_a11y_labels() -> void:
	if _title_label:
		_title_label.accessibility_name = tr("UI_SELECT_LEVEL")
	A11yLabels.bind_buttons([
		[back_button, "UI_CLOSE"],
		[_page_prev_button, "UI_PREVIOUS"],
		[_page_next_button, "UI_NEXT"],
		[easy_tab_button, "DIFF_EASY"],
		[medium_tab_button, "DIFF_MEDIUM"],
		[hard_tab_button, "DIFF_HARD"],
	])


## Relays viewport changes into the phone-capped level-select layout.
func _on_viewport_resized() -> void:
	_layout.layout_level_select()


## Rebuilds level cards when a new-level badge is cleared.
func _on_unseen_levels_changed(_count: int) -> void:
	_tabs.refresh_page()


## Re-rasterizes previews when color-blind tile colors are toggled.
func _on_color_blind_patterns_changed() -> void:
	LevelPreview.clear_texture_cache()
	_tabs.refresh_page()


## Hardware back closes tutorial/goals popups first, then leaves the screen.
func _notification(what: int) -> void:
	# Handle the Android/iOS hardware back button — treat it the same as the UI back button.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if GlobalGameManager and GlobalGameManager.consume_system_back():
			if _tutorial_intro.handle_back():
				return
			if _level_goals_blocker and _level_goals_blocker.visible:
				_hide_level_goals_popup()
				return
			_on_back_pressed()


## Shows or hides the Custom tab depending on whether dev/debug tools are enabled.
## If the tab is hidden while it's the active view, resets to Easy.
func _configure_custom_tab() -> void:
	_layout.configure_custom_tab_visibility()
	if not GlobalGameManager.debug_tools_enabled and _tabs.current_view == LevelSelectTabs.ViewMode.CUSTOM:
		_tabs.current_view = LevelSelectTabs.ViewMode.EASY


## Re-applies fonts and rebuilds the menu when the player changes language at runtime.
func _on_language_changed() -> void:
	HudLayout.apply_locale_fonts_to_tree(self)
	_layout.fit_chrome_buttons(_configure_custom_tab)
	_tabs.update_tab_button_visuals()
	_tabs.populate_level_menu()
	if _title_label:
		HudLayout._bind_header_translation_key(_title_label, "UI_SELECT_LEVEL")
		HudLayout.apply_screen_header_style(_title_label)
	if _tutorial_intro.is_blocking():
		_tutorial_intro.show_prompt()
	if _level_goals_blocker and _level_goals_blocker.visible:
		var goals_level := _goals_popup.current_level()
		if goals_level:
			var earned_bits := SaveManager.get_level_star_bits(goals_level.level_number) if SaveManager else 0
			_show_level_goals_popup(goals_level, earned_bits)


## Populates a level button with a corner number, preview thumbnail, and star row.
## Locked levels get a greyed-out preview and a centered lock icon overlay instead of stars.
## Preview Y is top-aligned so locked and unlocked cards share the same thumbnail height.
func _apply_level_button_content(btn: Button, level: LevelData, title: String, locked: bool) -> void:
	var show_badge := (
		not locked
		and _tabs.current_view != LevelSelectTabs.ViewMode.CUSTOM
		and SaveManager != null
		and SaveManager.is_level_unseen(level.level_number)
	)
	LevelSelectCards.apply_button_content(
		btn,
		level,
		title,
		locked,
		_tabs.current_view == LevelSelectTabs.ViewMode.CUSTOM,
		LOCK_ICON,
		PREVIEW_SIZE,
		LEVEL_LOCK_ICON_SIZE,
		show_badge
	)


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
	if _tutorial_intro.handle_back():
		return
	if _level_goals_blocker and _level_goals_blocker.visible:
		_hide_level_goals_popup()
		return
	GlobalGameManager.go_to_scene("res://scenes/main_menu.tscn")


## Styles the authored first-run tutorial prompt (no dimmer; chrome hides instead).
func _setup_tutorial_intro_panel() -> void:
	_tutorial_intro.bind(
		_tutorial_intro_blocker,
		_tutorial_intro_label,
		_tutorial_intro_yes,
		_tutorial_intro_no,
		_set_level_select_chrome_visible,
		_copy_dialog_button_styles,
		_configure_custom_tab,
		_on_tutorial_intro_yes,
		_on_tutorial_intro_no
	)
	_tutorial_intro.setup_panel()


func _show_tutorial_intro_prompt() -> void:
	_tutorial_intro.show_prompt()


func _hide_tutorial_intro_prompt() -> void:
	_pending_level = null
	_tutorial_intro.hide()


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
	if custom_debug_bar_host:
		custom_debug_bar_host.visible = should_show and (
			GlobalGameManager != null and GlobalGameManager.debug_tools_enabled
		)


func _level_card_title_num(level: LevelData) -> String:
	if _tabs.current_view == LevelSelectTabs.ViewMode.CUSTOM:
		return str(int(level.level_number))
	return str(int(LevelUtils.get_display_level_number(level)))


## Styles the authored star-goals popup. Star rows are still filled at show time.
func _setup_level_goals_popup() -> void:
	_goals_popup.bind(
		_level_goals_blocker,
		_level_goals_title,
		_level_goals_host,
		_level_goals_play,
		_level_goals_close,
		LEVEL_GOALS_OVERLAY_Z,
		_level_card_title_num,
		_copy_dialog_button_styles
	)
	_goals_popup.setup(_on_level_goals_play, _hide_level_goals_popup)


## Fills the authored goals popup with this level's star requirements and shows it.
func _show_level_goals_popup(level: LevelData, earned_bits: int) -> void:
	_goals_popup.show_for_level(level, earned_bits)


## Hides the star-goals popup without starting the level.
func _hide_level_goals_popup() -> void:
	_goals_popup.hide()


## Starts the chosen level, or the tutorial intro if it has not been answered.
func _on_level_goals_play() -> void:
	var resource := _goals_popup.current_level()
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
