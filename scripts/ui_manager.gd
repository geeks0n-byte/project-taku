class_name UIManager
extends Control
## Owns all HUD controls, overlay panels, and the how-to-play pages.
## Emits signals so main.gd can respond to player actions without UIManager
## knowing about game logic.

# Fired by top-bar button presses — main.gd connects and responds to each.
signal pause_requested
signal reset_requested
signal reset_confirmed
signal reset_cancelled
signal how_to_play_requested 
signal resume_from_tutorial_requested 
signal next_level_requested  
signal play_again_requested  
signal hint_requested 
signal undo_requested
signal redo_requested
# Session-resume panel actions.
signal session_continue_requested
signal session_restart_requested
signal session_back_requested
# Emitted after a locale change so main.gd can re-format time and tutorial text.
signal locale_refresh_requested

@onready var top_margin: MarginContainer = $"../HUDLayer/HUDControl/TopMargin"
@onready var top_bar_row: HBoxContainer = $"../HUDLayer/HUDControl/TopMargin/VBox/TopBarRow"
@onready var level_label: RichTextLabel = $"../HUDLayer/HUDControl/TopMargin/VBox/TopBarRow/LevelLabelWrap/LevelLabelInset/LevelLabel"
@onready var status_label: RichTextLabel = $"../HUDLayer/HUDControl/StatusLabel"
@onready var counter_container: Control = $"../HUDLayer/HUDControl/CounterContainer"
@onready var timer_label: RichTextLabel = $"../HUDLayer/HUDControl/CounterContainer/TimerSlot/TimerLabel"
@onready var joker_counter_label: RichTextLabel = $"../HUDLayer/HUDControl/CounterContainer/JokerSlot/JokerCounterLabel"
@onready var move_counter_label: RichTextLabel = $"../HUDLayer/HUDControl/CounterContainer/MoveSlot/MoveCounterLabel"
@onready var pause_button: Button = $"../HUDLayer/HUDControl/TopMargin/VBox/TopBarRow/LeftButtons/PauseButton"
@onready var reset_button: Button = $"../HUDLayer/HUDControl/TopMargin/VBox/TopBarRow/LeftButtons/ResetButton"
@onready var how_to_play_button: Button = $"../HUDLayer/HUDControl/TopMargin/VBox/TopBarRow/LeftButtons/HowToPlayButton"
@onready var hint_button: Button = $"../HUDLayer/HUDControl/TopMargin/VBox/TopBarRow/RightButtons/HintButton"
@onready var undo_button: Button = $"../HUDLayer/HUDControl/TopMargin/VBox/TopBarRow/RightButtons/UndoButton"
@onready var redo_button: Button = $"../HUDLayer/HUDControl/TopMargin/VBox/TopBarRow/RightButtons/RedoButton"
@onready var victory_panel: Control = $"../EndLayer/CenterContainer/VictoryPanel"
@onready var restart_button: Button = $"../EndLayer/CenterContainer/VictoryPanel/RestartButton"
@onready var main_menu_button: Button = $"../EndLayer/CenterContainer/VictoryPanel/MainMenuButton"
@onready var time_result_label: Label = $"../EndLayer/CenterContainer/VictoryPanel/TimeResultLabel"
@onready var win_label: Label = $"../EndLayer/CenterContainer/VictoryPanel/WinLabel"
@onready var how_to_play_container: Control = $"../HowToPlayLayer/CenterContainer"
@onready var how_to_play_panel: Control = $"../HowToPlayLayer/CenterContainer/HowToPlayPanel"
@onready var _htp_header: Label = $"../HowToPlayLayer/CenterContainer/HowToPlayPageHeader"
@onready var how_to_play_nav: HBoxContainer = $"../HowToPlayLayer/CenterContainer/NavRow"
@onready var tutorial_back_button: Button = $"../HowToPlayLayer/CenterContainer/BackButton"
@onready var htp_prev_button: Button = $"../HowToPlayLayer/CenterContainer/NavRow/PrevSlot/PrevButton"
@onready var htp_next_button: Button = $"../HowToPlayLayer/CenterContainer/NavRow/NextSlot/NextButton"
@onready var rules_label: RichTextLabel = $"../HowToPlayLayer/CenterContainer/HowToPlayPanel/RulesLabel"
@onready var victory_restart_label: Label = $"../EndLayer/CenterContainer/VictoryPanel/RestartButton/HBoxContainer/Label"
@onready var end_layer: CanvasLayer = $"../EndLayer"
@onready var end_center: CenterContainer = $"../EndLayer/CenterContainer"
@onready var end_dimmer: ColorRect = $"../EndLayer/Dimmer"
@onready var play_again_button: Button = $"../EndLayer/CenterContainer/VictoryPanel/PlayAgainButton"
@onready var play_again_label: Label = $"../EndLayer/CenterContainer/VictoryPanel/PlayAgainButton/HBoxContainer/Label"
@onready var victory_results_host: Control = $"../EndLayer/CenterContainer/VictoryPanel/VictoryResultsHost"
@onready var victory_preview: TextureRect = $"../EndLayer/CenterContainer/VictoryPanel/VictoryBoardPreview"
@onready var resume_panel: Panel = $"../EndLayer/CenterContainer/SessionResumePanel"
@onready var resume_prompt_label: Label = $"../EndLayer/CenterContainer/SessionResumePanel/PromptLabel"
@onready var resume_buttons: VBoxContainer = $"../EndLayer/CenterContainer/SessionResumePanel/Buttons"
@onready var resume_continue_btn: Button = $"../EndLayer/CenterContainer/SessionResumePanel/Buttons/ContinueButton"
@onready var resume_restart_btn: Button = $"../EndLayer/CenterContainer/SessionResumePanel/Buttons/RestartButton"
@onready var resume_back_btn: Button = $"../EndLayer/CenterContainer/SessionResumePanel/Buttons/BackButton"
@onready var reset_confirm_panel: Panel = $"../EndLayer/CenterContainer/ResetConfirmPanel"
@onready var reset_confirm_label: Label = $"../EndLayer/CenterContainer/ResetConfirmPanel/VBoxContainer/PromptLabel"
@onready var reset_confirm_yes: Button = $"../EndLayer/CenterContainer/ResetConfirmPanel/VBoxContainer/HBoxContainer/YesButton"
@onready var reset_confirm_no: Button = $"../EndLayer/CenterContainer/ResetConfirmPanel/VBoxContainer/HBoxContainer/NoButton"

var _hud_counters := UiHudCounters.new()
var _toolbar := UiHudToolbar.new()
var _tutorial_hud := UiTutorialHud.new()
var _htp_panel := UiHowToPlayPanel.new()
var _end_dialogs := UiEndDialogs.new()
var _victory_panel := UiVictoryPanel.new()

# Styles HTP chrome, wires HUD buttons, and listens for locale changes.
func _ready() -> void:
	set_process(false)
	_tutorial_hud.bind(
		reset_button,
		how_to_play_button,
		hint_button,
		undo_button,
		redo_button,
		pause_button,
		func(): return _hud_counters.hint_remaining(),
		func(): pass
	)
	_hud_counters.bind(
		counter_container,
		timer_label,
		joker_counter_label,
		move_counter_label,
		level_label,
		status_label,
		hint_button,
		_tutorial_hud.is_tools_locked,
		_tutorial_hud.highlighted_button
	)
	_toolbar.bind(
		self,
		pause_button,
		reset_button,
		how_to_play_button,
		hint_button,
		undo_button,
		redo_button,
		restart_button,
		main_menu_button,
		tutorial_back_button,
		htp_prev_button,
		htp_next_button,
		play_again_button,
		func(): pause_requested.emit(),
		func(): reset_requested.emit(),
		func(): how_to_play_requested.emit(),
		func(): hint_requested.emit(),
		func(): undo_requested.emit(),
		func(): redo_requested.emit(),
		func(): next_level_requested.emit(),
		func(): play_again_requested.emit(),
		func(): GlobalGameManager.go_to_scene("res://scenes/main_menu.tscn"),
		_on_tutorial_back_pressed,
		func(): _htp_panel.on_prev_pressed(),
		func(): _htp_panel.on_next_pressed(),
		_tutorial_hud.is_tools_locked,
		_tutorial_hud.highlighted_button
	)
	_htp_panel.bind(
		how_to_play_container,
		how_to_play_panel,
		_htp_header,
		how_to_play_nav,
		htp_prev_button,
		htp_next_button,
		rules_label
	)
	_htp_panel.setup(func(): _layout_how_to_play_stack())
	_end_dialogs.bind(
		end_center,
		end_dimmer,
		victory_panel,
		resume_panel,
		resume_prompt_label,
		resume_buttons,
		resume_continue_btn,
		resume_restart_btn,
		resume_back_btn,
		reset_confirm_panel,
		reset_confirm_label,
		reset_confirm_yes,
		reset_confirm_no
	)
	_end_dialogs.setup(
		func(): reset_confirmed.emit(),
		func(): reset_cancelled.emit(),
		func(): session_continue_requested.emit(),
		func(): session_restart_requested.emit(),
		func(): session_back_requested.emit(),
		set_hud_buttons_disabled
	)
	_victory_panel.bind(
		victory_panel,
		win_label,
		restart_button,
		victory_restart_label,
		play_again_button,
		play_again_label,
		main_menu_button,
		time_result_label,
		victory_results_host,
		victory_preview,
		_end_dialogs.set_dimmer_visible,
		_end_dialogs.set_dialog_raised
	)
	_victory_panel.setup_chrome()
	_toolbar.connect_signals()
	_apply_a11y_labels()
	if SaveManager and not SaveManager.language_changed.is_connected(_on_language_changed):
		SaveManager.language_changed.connect(_on_language_changed)

# Rebuilds all locale-sensitive UI after SaveManager.language_changed fires.
# Re-asserts Press Start on digit-only widgets because the font walk resets them.
func _on_language_changed() -> void:
	HudLayout.apply_locale_fonts_to_tree(self)
	_apply_top_bar_buttons()
	_apply_a11y_labels()
	_hud_counters.on_locale_changed()
	locale_refresh_requested.emit()
	_htp_panel.on_locale_changed()
	if tutorial_back_button:
		HudLayout.style_top_bar_close_button(tutorial_back_button)
	if reset_confirm_panel and reset_confirm_panel.visible:
		show_reset_confirm()
	if resume_panel and resume_panel.visible:
		show_session_resume_prompt()
	if _victory_panel.is_visible():
		_victory_panel.refresh_locale()
	if reset_confirm_panel and reset_confirm_panel.visible:
		_end_dialogs.apply_a11y_labels()
	if resume_panel and resume_panel.visible:
		_end_dialogs.apply_a11y_labels()

# Called once by main.gd after the scene is ready. Hides all overlays, sets up
# fonts, and defers top-bar button layout to the next frame so sizes are stable.
func setup_ui(_show_debug_tools: bool, _cell_size: float) -> void:
	_ensure_safe_area_resize_hook()
	set_overlays_hidden()
	_hud_counters.hide_counters_on_setup()
	_hud_counters.setup_status_font()
	call_deferred("_apply_top_bar_buttons")

# Re-applies top-bar safe-area padding when the viewport size changes.
func _ensure_safe_area_resize_hook() -> void:
	if not is_inside_tree():
		return
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_on_safe_area_viewport_resized):
		viewport.size_changed.connect(_on_safe_area_viewport_resized)

# Viewport resized: recompute HUD offsets (notch / nav-bar / landscape).
func _on_safe_area_viewport_resized() -> void:
	_apply_top_bar_buttons()

# Applies sizing and icon styles to all top-bar button clusters and counter labels.
# Deferred on setup so the scene tree has computed its initial sizes.
func _apply_top_bar_buttons() -> void:
	HudLayout.apply_top_bar_button_cluster(top_bar_row.get_node_or_null("LeftButtons") as HBoxContainer)
	HudLayout.apply_top_bar_button_cluster(top_bar_row.get_node_or_null("RightButtons") as HBoxContainer)
	for button in [pause_button, reset_button, how_to_play_button, hint_button, undo_button, redo_button]:
		HudLayout.apply_square_top_bar_button(button)
	HudLayout.apply_top_bar_mode_label(level_label)
	HudLayout.align_counter_label(timer_label, GameConstants.HUD_TIMER_Y_NUDGE)
	HudLayout.align_counter_label(joker_counter_label)
	HudLayout.align_counter_label(move_counter_label)
	if timer_label:
		HudLayout.prepare_timer_label(timer_label)
	HudLayout.align_counter_row(counter_container)
	HudLayout.apply_top_hud_safe_area(top_margin, counter_container)
	if top_bar_row:
		top_bar_row.custom_minimum_size.y = float(GameConstants.HUD_BUTTON_HEIGHT)
	_ensure_safe_area_resize_hook()

# Drives hold-to-repeat undo/redo via UiHudToolbar.
func _process(delta: float) -> void:
	if not _toolbar.process(delta):
		set_process(false)

# Closes the HTP overlay and tells main.gd to return to paused gameplay.
func _on_tutorial_back_pressed() -> void:
	if how_to_play_container:
		how_to_play_container.visible = false
	resume_from_tutorial_requested.emit()

func update_undo_redo_buttons(can_undo: bool, can_redo: bool) -> void:
	_toolbar.update_undo_redo_buttons(can_undo, can_redo)

func set_tutorial_tools_locked(locked: bool) -> void:
	_tutorial_hud.set_tutorial_tools_locked(locked)

func highlight_hud_button(button_id: String) -> void:
	_tutorial_hud.highlight_hud_button(button_id)

func clear_hud_button_highlight() -> void:
	_tutorial_hud.clear_hud_button_highlight()

func set_reset_mode_restart(is_restart: bool) -> void:
	_tutorial_hud.set_reset_mode_restart(is_restart)
	_end_dialogs.set_reset_is_restart(is_restart)
	if reset_button:
		A11yLabels.bind_button(reset_button, "UI_RESTART" if is_restart else "UI_NEW_LAYOUT")

func get_hud_button(button_id: String) -> Button:
	return _tutorial_hud.get_hud_button(button_id)

func set_hud_buttons_disabled(is_disabled: bool) -> void:
	_toolbar.set_hud_buttons_disabled(
		is_disabled,
		_hud_counters.hint_remaining(),
		_hud_counters.refresh_hint_button_visual
	)
	if not is_disabled and _tutorial_hud.is_tools_locked():
		_tutorial_hud.apply_tool_state()

func _apply_a11y_labels() -> void:
	A11yLabels.bind_buttons([
		[pause_button, "UI_PAUSE"],
		[reset_button, "UI_NEW_LAYOUT"],
		[how_to_play_button, "UI_HOW_TO_PLAY"],
		[hint_button, "UI_HINT"],
		[undo_button, "UI_UNDO"],
		[redo_button, "UI_REDO"],
		[tutorial_back_button, "UI_BACK"],
	])
	_htp_panel.apply_a11y_labels()

func update_joker_counter(current: int, required: int) -> void:
	_hud_counters.update_joker_counter(current, required)

func set_joker_counter_visibility(visible_state: bool) -> void:
	_hud_counters.set_joker_counter_visibility(visible_state)

func update_move_counter(moves: int, required: int = -1) -> void:
	_hud_counters.update_move_counter(moves, required)

func set_move_counter_visibility(visible_state: bool) -> void:
	_hud_counters.set_move_counter_visibility(visible_state)

func set_hint_remaining(remaining: int) -> void:
	_hud_counters.set_hint_remaining(remaining)

func set_hint_button_disabled(is_disabled: bool) -> void:
	_hud_counters.set_hint_button_disabled(is_disabled)

func show_tutorial_status(bbcode_body: String) -> void:
	_hud_counters.show_tutorial_status(bbcode_body)

func clear_tutorial_status() -> void:
	_hud_counters.clear_tutorial_status()

func update_dynamic_layout(board_y: float, board_height: float) -> void:
	_hud_counters.update_dynamic_layout(board_y, board_height)

func update_timer(formatted_time: String) -> void:
	_hud_counters.update_timer(formatted_time)

func set_timer_visibility(visible_state: bool) -> void:
	_hud_counters.set_timer_visibility(visible_state)

func display_level(num: int, is_custom: bool = false, is_tutorial: bool = false) -> void:
	_hud_counters.display_level(num, is_custom, is_tutorial)

func show_status_valid() -> void:
	_hud_counters.show_status_valid()

func show_status_errors(errors: Array) -> void:
	_hud_counters.show_status_errors(errors)

func set_status_visible(should_show: bool) -> void:
	_hud_counters.set_status_visible(should_show)

# Shows or hides the top HUD bar and the counter row together.
func set_top_bar_visible(should_show: bool) -> void:
	if top_margin:
		top_margin.visible = should_show
	if counter_container:
		counter_container.visible = should_show

func set_tutorial_mode(active: bool) -> void:
	_hud_counters.set_tutorial_mode(active)

# Hides all overlays (victory, HTP, resume prompt, reset confirm) and re-enables
# the HUD buttons. Called at the start of every new level.
func set_overlays_hidden() -> void:
	_victory_panel.hide_panel()
	_htp_panel.hide_panel()
	_end_dialogs.hide_session_resume_prompt()
	_end_dialogs.hide_reset_confirm()
	_end_dialogs.set_dimmer_visible(false)
	set_hud_buttons_disabled(false)

# Shows the reset/restart confirmation panel over a transparent dimmer.
# The prompt text varies based on whether reset restarts a fixed layout or generates a new one.
func show_reset_confirm() -> void:
	_end_dialogs.show_reset_confirm()


func hide_reset_confirm() -> void:
	_end_dialogs.hide_reset_confirm()


func show_session_resume_prompt() -> void:
	_end_dialogs.show_session_resume_prompt()


func hide_session_resume_prompt() -> void:
	_end_dialogs.hide_session_resume_prompt()


func _layout_how_to_play_stack() -> void:
	_htp_panel.layout_stack()


func show_how_to_play() -> void:
	_htp_panel.show_panel()
	set_hud_buttons_disabled(true)

# Shows the victory panel with level number, star results, optional board preview,
# and appropriate "Next Level" / "Play Again" / "Main Menu" buttons.
func show_victory(
	display_num: int,
	is_last_level: bool,
	star_result: Dictionary = {},
	is_custom: bool = false,
	is_tutorial: bool = false,
	solved_preview: Texture2D = null
) -> void:
	set_hud_buttons_disabled(true)
	if end_dimmer:
		end_dimmer.color = Color(0, 0, 0, 0)
	_victory_panel.show(
		display_num, is_last_level, star_result, is_custom, is_tutorial, solved_preview
	)


## Rebuilds the victory board thumbnail (used when store capture forces default tile colors).
func refresh_victory_preview(solved_preview: Texture2D) -> void:
	if not _victory_panel.is_visible():
		return
	_victory_panel.set_preview_texture(solved_preview)
