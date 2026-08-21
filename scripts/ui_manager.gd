# Owns all HUD controls, overlay panels, and the how-to-play pages.
# Emits signals so main.gd can respond to player actions without UIManager
# knowing about game logic.
class_name UIManager
extends Control

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
@onready var reset_confirm_panel: Panel = $"../EndLayer/CenterContainer/ResetConfirmPanel"
@onready var reset_confirm_label: Label = $"../EndLayer/CenterContainer/ResetConfirmPanel/VBoxContainer/PromptLabel"
@onready var reset_confirm_yes: Button = $"../EndLayer/CenterContainer/ResetConfirmPanel/VBoxContainer/HBoxContainer/YesButton"
@onready var reset_confirm_no: Button = $"../EndLayer/CenterContainer/ResetConfirmPanel/VBoxContainer/HBoxContainer/NoButton"

# State cached so the victory panel and status label can be rebuilt on locale change.
var _is_last_level_completed: bool = false
var _victory_display_num: int = 0
var _victory_is_custom: bool = false
var _victory_is_tutorial: bool = false
var _victory_star_result: Dictionary = {}
# Current how-to-play page index (0-based, clamped to HowToPlayContent.PAGE_COUNT-1).
var _htp_page: int = 0
var _htp_header: Label
# When true, all HUD buttons except the highlighted one are disabled (tutorial mode).
var _tutorial_tools_locked: bool = false
# Name of the single HUD button that remains active during a tutorial step.
var _highlighted_hud_button: String = ""
var _tutorial_status_body: String = ""
var _tutorial_mode: bool = false
# When true the reset button shows the restart icon; false shows the random icon.
var _reset_is_restart: bool = false
const _ICON_RESET: Texture2D = preload("res://resources/icons/icon_reset.svg")
const _ICON_RANDOM: Texture2D = preload("res://resources/icons/icon_random.svg")
# Error keys to display in the status label; empty means "board is valid".
var _status_error_keys: Array = []
var _hint_remaining: int = GameConstants.HINT_LIMIT_UNLIMITED
# Set by an external caller (e.g. when ads are loading) to disable the hint button.
var _hint_forced_disabled: bool = false
# Cached for locale-rebuild: last values passed to display_level().
var _level_display_num: int = 0
var _level_display_custom: bool = false
var _level_display_tutorial: bool = false
var _level_display_set: bool = false
# Cached counter values so they can be re-rendered on locale change.
var _joker_current: int = 0
var _joker_required: int = 0
var _move_count: int = 0
var _move_required: int = -1
var _last_timer_text: String = ""

# Hold-to-repeat undo/redo: starts after _HOLD_INITIAL_DELAY then accelerates
# each repeat until it reaches _HOLD_REPEAT_MIN interval.
var _hold_undo_active: bool = false
var _hold_redo_active: bool = false
var _hold_repeat_elapsed: float = 0.0
var _hold_repeat_interval: float = 0.0
const _HOLD_INITIAL_DELAY := 0.4
const _HOLD_REPEAT_START := 0.3
const _HOLD_REPEAT_MIN := 0.05
# Multiplied to _hold_repeat_interval each repeat so actions speed up when held.
const _HOLD_REPEAT_ACCEL := 0.82

func _ready() -> void:
	set_process(false)
	_layout_how_to_play()
	_setup_how_to_play_font()
	_refresh_how_to_play_text()
	_connect_signals()
	_setup_end_layer()
	_style_victory_chrome()
	if SaveManager and not SaveManager.language_changed.is_connected(_on_language_changed):
		SaveManager.language_changed.connect(_on_language_changed)

# Styles the how-to-play nav buttons and locates the page header label in the container.
func _layout_how_to_play() -> void:
	for btn in [htp_prev_button, htp_next_button]:
		HudLayout.apply_nav_button(btn)
	if tutorial_back_button:
		HudLayout.style_top_bar_close_button(tutorial_back_button)
	_htp_header = HudLayout.ensure_how_to_play_page_header(how_to_play_container)

# Rebuilds all locale-sensitive UI after SaveManager.language_changed fires.
# Re-asserts Press Start on digit-only widgets because the font walk resets them.
func _on_language_changed() -> void:
	HudLayout.apply_locale_fonts_to_tree(self)
	_apply_top_bar_buttons()
	if _level_display_set:
		display_level(_level_display_num, _level_display_custom, _level_display_tutorial)
	locale_refresh_requested.emit()
	_refresh_status_label()
	HudLayout.clear_how_to_play_nav_lock(how_to_play_container)
	_refresh_how_to_play_text()
	# Re-assert Press Start + fixed size after locale font walk (digits only).
	if timer_label and not _last_timer_text.is_empty():
		update_timer(_last_timer_text)
	if joker_counter_label and joker_counter_label.visible:
		update_joker_counter(_joker_current, _joker_required)
	if move_counter_label and move_counter_label.visible:
		update_move_counter(_move_count, _move_required)
	if reset_confirm_panel and reset_confirm_panel.visible:
		show_reset_confirm()
	if resume_panel and resume_panel.visible:
		show_session_resume_prompt()
	if victory_panel and victory_panel.visible:
		_refresh_victory_locale()

func _setup_how_to_play_font() -> void:
	if not rules_label:
		return
	rules_label.set_meta("_use_default_font", true)
	HudLayout.apply_locale_font_to_control(rules_label)

# Called once by main.gd after the scene is ready. Hides all overlays, sets up
# fonts, and defers top-bar button layout to the next frame so sizes are stable.
func setup_ui(_show_debug_tools: bool, _cell_size: float) -> void:
	_connect_signals()
	set_overlays_hidden()
	set_joker_counter_visibility(false)
	set_move_counter_visibility(false)
	set_status_visible(false)
	if status_label:
		HudLayout.apply_status_font(status_label, GameConstants.HUD_STATUS_FONT_SIZE)
	call_deferred("_apply_top_bar_buttons")

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
	_refresh_counter_row_alignment()
	if top_margin:
		top_margin.offset_bottom = GameConstants.HUD_TOP_BAR_HEIGHT
	if top_bar_row:
		top_bar_row.custom_minimum_size.y = float(GameConstants.HUD_BUTTON_HEIGHT)
	if counter_container:
		counter_container.offset_top = GameConstants.HUD_COUNTER_ROW_TOP
		counter_container.offset_bottom = GameConstants.HUD_COUNTER_ROW_TOP + GameConstants.HUD_COUNTER_ROW_HEIGHT

# Connects all button pressed/down/up signals once, guarded against double-connection.
func _connect_signals() -> void:
	if pause_button and not pause_button.pressed.is_connected(_on_pause_requested):
		pause_button.pressed.connect(_on_pause_requested)
	if reset_button and not reset_button.pressed.is_connected(_on_reset_requested):
		reset_button.pressed.connect(_on_reset_requested)
	if how_to_play_button and not how_to_play_button.pressed.is_connected(_on_how_to_play_requested):
		how_to_play_button.pressed.connect(_on_how_to_play_requested)
	if hint_button and not hint_button.pressed.is_connected(_on_hint_requested):
		hint_button.pressed.connect(_on_hint_requested)
	if undo_button and not undo_button.pressed.is_connected(_on_undo_requested):
		undo_button.pressed.connect(_on_undo_requested)
	if undo_button and not undo_button.button_down.is_connected(_on_undo_button_down):
		undo_button.button_down.connect(_on_undo_button_down)
		undo_button.button_up.connect(_on_undo_button_up)
	if redo_button and not redo_button.pressed.is_connected(_on_redo_requested):
		redo_button.pressed.connect(_on_redo_requested)
	if redo_button and not redo_button.button_down.is_connected(_on_redo_button_down):
		redo_button.button_down.connect(_on_redo_button_down)
		redo_button.button_up.connect(_on_redo_button_up)
	if restart_button and not restart_button.pressed.is_connected(_on_victory_next_pressed):
		restart_button.pressed.connect(_on_victory_next_pressed)
	if main_menu_button and not main_menu_button.pressed.is_connected(_on_main_menu_pressed):
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	if tutorial_back_button and not tutorial_back_button.pressed.is_connected(_on_tutorial_back_pressed):
		tutorial_back_button.pressed.connect(_on_tutorial_back_pressed)
	if htp_prev_button and not htp_prev_button.pressed.is_connected(_on_htp_prev_pressed):
		htp_prev_button.pressed.connect(_on_htp_prev_pressed)
	if htp_next_button and not htp_next_button.pressed.is_connected(_on_htp_next_pressed):
		htp_next_button.pressed.connect(_on_htp_next_pressed)
	if play_again_button and not play_again_button.pressed.is_connected(_on_play_again_pressed):
		play_again_button.pressed.connect(_on_play_again_pressed)
	if reset_confirm_yes and not reset_confirm_yes.pressed.is_connected(_on_reset_confirm_yes):
		reset_confirm_yes.pressed.connect(_on_reset_confirm_yes)
	if reset_confirm_no and not reset_confirm_no.pressed.is_connected(_on_reset_confirm_no):
		reset_confirm_no.pressed.connect(_on_reset_confirm_no)
	var resume_continue_btn := resume_panel.get_node_or_null("Buttons/ContinueButton") as Button if resume_panel else null
	var resume_restart_btn := resume_panel.get_node_or_null("Buttons/RestartButton") as Button if resume_panel else null
	var resume_back_btn := resume_panel.get_node_or_null("Buttons/BackButton") as Button if resume_panel else null
	if resume_continue_btn and not resume_continue_btn.pressed.is_connected(_on_session_continue_pressed):
		resume_continue_btn.pressed.connect(_on_session_continue_pressed)
	if resume_restart_btn and not resume_restart_btn.pressed.is_connected(_on_session_restart_pressed):
		resume_restart_btn.pressed.connect(_on_session_restart_pressed)
	if resume_back_btn and not resume_back_btn.pressed.is_connected(_on_session_back_pressed):
		resume_back_btn.pressed.connect(_on_session_back_pressed)

# Simple signal forwarders from button callbacks to main.gd.
func _on_pause_requested() -> void:
	pause_requested.emit()

func _on_reset_requested() -> void:
	reset_requested.emit()

func _on_how_to_play_requested() -> void:
	how_to_play_requested.emit()

func _on_hint_requested() -> void:
	hint_requested.emit()

func _on_undo_requested() -> void:
	undo_requested.emit()

func _on_redo_requested() -> void:
	redo_requested.emit()

# Starts the hold-to-repeat timer when the undo button is pressed and held.
func _on_undo_button_down() -> void:
	_hold_undo_active = true
	_hold_redo_active = false
	_hold_repeat_elapsed = 0.0
	_hold_repeat_interval = _HOLD_REPEAT_START
	set_process(true)
	if UiSfx and undo_button:
		UiSfx.suppress_next_pressed_click(undo_button)
		UiSfx.play_click()

# Stops hold-to-repeat for undo when the user releases the button.
func _on_undo_button_up() -> void:
	_hold_undo_active = false
	if UiSfx and undo_button:
		UiSfx.clear_pressed_click_suppress(undo_button)
	if not _hold_redo_active:
		set_process(false)

# Starts the hold-to-repeat timer when the redo button is pressed and held.
func _on_redo_button_down() -> void:
	_hold_redo_active = true
	_hold_undo_active = false
	_hold_repeat_elapsed = 0.0
	_hold_repeat_interval = _HOLD_REPEAT_START
	set_process(true)
	if UiSfx and redo_button:
		UiSfx.suppress_next_pressed_click(redo_button)
		UiSfx.play_click()

# Stops hold-to-repeat for redo when the user releases the button.
func _on_redo_button_up() -> void:
	_hold_redo_active = false
	if UiSfx and redo_button:
		UiSfx.clear_pressed_click_suppress(redo_button)
	if not _hold_undo_active:
		set_process(false)

# Drives hold-to-repeat undo/redo. Waits for the initial delay, then emits
# the action each time the accelerating interval elapses.
func _process(delta: float) -> void:
	if not _hold_undo_active and not _hold_redo_active:
		set_process(false)
		return
	_hold_repeat_elapsed += delta
	if _hold_repeat_elapsed < _HOLD_INITIAL_DELAY:
		return
	var time_since_start := _hold_repeat_elapsed - _HOLD_INITIAL_DELAY
	# Check if next repeat is due.
	if time_since_start < _hold_repeat_interval:
		return
	_hold_repeat_elapsed = _HOLD_INITIAL_DELAY + 0.0
	_hold_repeat_interval = maxf(_hold_repeat_interval * _HOLD_REPEAT_ACCEL, _HOLD_REPEAT_MIN)
	if _hold_undo_active:
		if UiSfx:
			UiSfx.play_click()
		undo_requested.emit()
	elif _hold_redo_active:
		if UiSfx:
			UiSfx.play_click()
		redo_requested.emit()

# Closes the HTP overlay and tells main.gd to return to paused gameplay.
func _on_tutorial_back_pressed() -> void:
	if how_to_play_container:
		how_to_play_container.visible = false
	resume_from_tutorial_requested.emit()

# Victory panel button handlers.
func _on_victory_next_pressed() -> void:
	next_level_requested.emit()

func _on_play_again_pressed() -> void:
	play_again_requested.emit()

func _on_main_menu_pressed() -> void:
	GlobalGameManager.go_to_scene("res://scenes/main_menu.tscn")

# Updates the enabled/disabled state of undo and redo buttons.
# In tutorial mode, both are forced disabled unless one of them is the highlighted button.
func update_undo_redo_buttons(can_undo: bool, can_redo: bool) -> void:
	if _tutorial_tools_locked and _highlighted_hud_button != "undo" and _highlighted_hud_button != "redo":
		if undo_button:
			undo_button.disabled = true
			HudLayout.refresh_button_icon_modulate(undo_button)
		if redo_button:
			redo_button.disabled = true
			HudLayout.refresh_button_icon_modulate(redo_button)
		return
	if undo_button:
		var undo_on := can_undo
		if _tutorial_tools_locked and _highlighted_hud_button == "undo":
			undo_on = true
		undo_button.disabled = not undo_on
		HudLayout.refresh_button_icon_modulate(undo_button)
	if redo_button:
		var redo_on := can_redo
		if _tutorial_tools_locked and _highlighted_hud_button == "redo":
			redo_on = true
		redo_button.disabled = not redo_on
		HudLayout.refresh_button_icon_modulate(redo_button)

# Updates the joker (green tile) counter label with the current/required ratio.
func update_joker_counter(current: int, required: int) -> void:
	if not joker_counter_label:
		return
	_joker_current = current
	_joker_required = required
	HudLayout.prepare_counter_label(joker_counter_label)
	joker_counter_label.text = HudLayout.format_icon_ratio_counter(
		GameConstants.TILE_GREEN, current, required, GameConstants.HUD_COUNTER_GREEN, tr("COUNTER_GREEN")
	)

# Shows or hides the joker counter slot (parent node) and re-aligns the counter row.
func set_joker_counter_visibility(visible_state: bool) -> void:
	var slot := joker_counter_label.get_parent() as Control if joker_counter_label else null
	if slot:
		slot.visible = visible_state
	elif joker_counter_label:
		joker_counter_label.visible = visible_state
	_refresh_counter_row_alignment()

# Updates the shifter-move counter. When required < 0, both numerator and denominator
# show the current count (used to display moves without a fixed goal).
func update_move_counter(moves: int, required: int = -1) -> void:
	if not move_counter_label:
		return
	_move_count = moves
	_move_required = required
	HudLayout.prepare_counter_label(move_counter_label)
	var target := required if required >= 0 else moves
	move_counter_label.text = HudLayout.format_icon_ratio_counter(
		GameConstants.TILE_SHIFTER, moves, target, GameConstants.HUD_COUNTER_SHIFTER, tr("MOVES")
	)

func set_move_counter_visibility(visible_state: bool) -> void:
	var slot := move_counter_label.get_parent() as Control if move_counter_label else null
	if slot:
		slot.visible = visible_state
	elif move_counter_label:
		move_counter_label.visible = visible_state
	_refresh_counter_row_alignment()

# Re-centres visible counter slots after any visibility change.
func _refresh_counter_row_alignment() -> void:
	HudLayout.align_counter_row(counter_container)

# Stores the remaining hint count and updates the hint button visual state.
func set_hint_remaining(remaining: int) -> void:
	_hint_remaining = remaining
	_refresh_hint_button_visual()

# Externally disables the hint button (e.g. while an ad is loading) without
# affecting the hint count itself.
func set_hint_button_disabled(is_disabled: bool) -> void:
	_hint_forced_disabled = is_disabled
	_refresh_hint_button_visual()

# Applies the current hint availability to the hint button, respecting tutorial lock.
func _refresh_hint_button_visual() -> void:
	if _tutorial_tools_locked and _highlighted_hud_button != "hint":
		HintController.update_button(hint_button, false, _hint_remaining)
		return
	if _tutorial_tools_locked and _highlighted_hud_button == "hint":
		HintController.update_button(hint_button, true, _hint_remaining)
		return
	HintController.update_button(hint_button, not _hint_forced_disabled, _hint_remaining)

# Shows a tutorial instruction in the status label (BBCode supported).
func show_tutorial_status(bbcode_body: String) -> void:
	_tutorial_status_body = bbcode_body
	_refresh_status_label()

# Clears the tutorial instruction and reverts the status label to normal mode.
func clear_tutorial_status() -> void:
	_tutorial_status_body = ""
	_refresh_status_label()

# Locks/unlocks the HUD toolbar for tutorial steps. When locked, only the
# highlighted button is interactive.
func set_tutorial_tools_locked(locked: bool) -> void:
	_tutorial_tools_locked = locked
	if not locked:
		_highlighted_hud_button = ""
	_apply_tutorial_tool_state()

# Highlights a single HUD button (by id string) with the breathing mask animation.
# When the "reset" button is highlighted, swaps to the random icon to match the tutorial step.
func highlight_hud_button(button_id: String) -> void:
	_highlighted_hud_button = button_id
	if button_id == "reset":
		_set_reset_button_texture(_ICON_RANDOM)
	else:
		_apply_reset_button_icon()
	_apply_tutorial_tool_state()

# Removes the highlight from all HUD buttons and restores normal tool state.
func clear_hud_button_highlight() -> void:
	_highlighted_hud_button = ""
	_apply_reset_button_icon()
	_apply_tutorial_tool_state()

# Controls which icon the reset button shows: restart icon for tutorial levels
# (where the board layout is fixed), random icon for generated puzzles.
func set_reset_mode_restart(is_restart: bool) -> void:
	_reset_is_restart = is_restart
	_apply_reset_button_icon()

func _apply_reset_button_icon() -> void:
	_set_reset_button_texture(_ICON_RESET if _reset_is_restart else _ICON_RANDOM)

# Swaps the IconContainer/Icon texture on the reset button without rebuilding the node.
func _set_reset_button_texture(tex: Texture2D) -> void:
	if not reset_button:
		return
	var icon := reset_button.get_node_or_null("IconContainer/Icon") as TextureRect
	if icon:
		icon.texture = tex

# Returns the Button node for a given id string ("reset", "hint", "undo", etc.).
# Used by tutorial director to position tooltip arrows or pulse specific buttons.
func get_hud_button(button_id: String) -> Button:
	match button_id:
		"reset":
			return reset_button
		"how_to_play":
			return how_to_play_button
		"hint":
			return hint_button
		"undo":
			return undo_button
		"redo":
			return redo_button
		"pause":
			return pause_button
		_:
			return null

# Re-applies the active mask and enabled state to all toolbar buttons based on
# the current tutorial lock and highlighted button. Reset/HTP are never disabled.
func _apply_tutorial_tool_state() -> void:
	var ids := ["reset", "how_to_play", "hint", "undo", "redo"]
	for id in ids:
		var button := get_hud_button(id)
		if button == null:
			continue
		var is_focus: bool = _highlighted_hud_button == id
		HudLayout.apply_toggle_active_mask(button, is_focus, GameConstants.TOGGLE_MASK_WHITE)
		if is_focus:
			HudLayout.start_toggle_mask_breathe(button)
		else:
			HudLayout.stop_toggle_mask_breathe(button)
		if id == "reset" or id == "how_to_play":
			button.disabled = false
			HudLayout.refresh_button_icon_modulate(button)
			continue
		if not _tutorial_tools_locked:
			if id == "hint":
				pass
			elif id == "undo" or id == "redo":
				pass
			else:
				button.disabled = false
				HudLayout.refresh_button_icon_modulate(button)
			continue
		if id == "hint":
			HintController.update_button(button, is_focus, _hint_remaining)
		else:
			button.disabled = not is_focus
			HudLayout.refresh_button_icon_modulate(button)

# Called after the board is positioned to place the counter row and status label
# relative to the board's actual screen position (board_y, board_height).
func update_dynamic_layout(board_y: float, board_height: float) -> void:
	HudLayout.position_counter_row(counter_container)
	if status_label:
		HudLayout.position_status_below_board(status_label, board_y, board_height)

# Enables or disables all top-bar action buttons. When disabling, hint/undo/redo
# are also forced off; on re-enable, tutorial tool state is restored if active.
func set_hud_buttons_disabled(is_disabled: bool) -> void:
	for button in [pause_button, reset_button, how_to_play_button]:
		if button:
			button.disabled = is_disabled
			HudLayout.refresh_button_icon_modulate(button)
	if is_disabled:
		if undo_button:
			undo_button.disabled = true
			HudLayout.refresh_button_icon_modulate(undo_button)
		if redo_button:
			redo_button.disabled = true
			HudLayout.refresh_button_icon_modulate(redo_button)
		if hint_button:
			HintController.update_button(hint_button, false, _hint_remaining)
	elif _tutorial_tools_locked:
		_apply_tutorial_tool_state()
	else:
		_refresh_hint_button_visual()

func update_timer(formatted_time: String) -> void:
	if not timer_label:
		return
	_last_timer_text = formatted_time
	HudLayout.set_timer_raster_text(timer_label, formatted_time)

func set_timer_visibility(visible_state: bool) -> void:
	var slot := timer_label.get_parent() as Control if timer_label else null
	if slot:
		slot.visible = visible_state
	elif timer_label:
		timer_label.visible = visible_state
	if timer_label and not visible_state:
		timer_label.text = ""
	_refresh_counter_row_alignment()

# Updates the top-bar level label. Tutorial levels hide the label (alpha=0) since
# they don't have a meaningful level number to show.
func display_level(num: int, is_custom: bool = false, is_tutorial: bool = false) -> void:
	if not level_label:
		return
	_level_display_num = num
	_level_display_custom = is_custom
	_level_display_tutorial = is_tutorial
	_level_display_set = true
	var label_wrap: Control = level_label.get_parent() as Control
	if label_wrap:
		label_wrap = label_wrap.get_parent() as Control
	if label_wrap:
		label_wrap.visible = true
	level_label.visible = true
	if is_tutorial:
		level_label.modulate.a = 0.0
		level_label.text = ""
		HudLayout.apply_top_bar_mode_label(level_label)
		return
	level_label.modulate = Color.WHITE
	var prefix: String
	if is_custom:
		prefix = String(tr("DEV"))
	else:
		prefix = String(tr("LVL"))
	HudLayout.apply_level_label(level_label, prefix, num)

# Clears any error state and shows the default "fill empty cells" prompt.
func show_status_valid() -> void:
	_status_error_keys.clear()
	_refresh_status_label()

# Stores an array of error key strings and refreshes the status label to show them.
func show_status_errors(errors: Array) -> void:
	_status_error_keys = errors.duplicate()
	_refresh_status_label()

func set_status_visible(should_show: bool) -> void:
	if status_label:
		status_label.visible = should_show

func set_top_bar_visible(should_show: bool) -> void:
	if top_margin:
		top_margin.visible = should_show
	if counter_container:
		counter_container.visible = should_show

# Switches the status label between tutorial-instruction mode and normal error/valid mode.
func set_tutorial_mode(active: bool) -> void:
	_tutorial_mode = active
	if not active:
		_tutorial_status_body = ""
	_refresh_status_label()

# Rebuilds the status label text from the current state:
# tutorial body if in tutorial mode, error keys if any, or the default hint message.
func _refresh_status_label() -> void:
	if not status_label:
		return
	status_label.modulate = Color.WHITE
	HudLayout.apply_status_font(status_label, GameConstants.HUD_STATUS_FONT_SIZE)
	var lines: PackedStringArray = []
	if _tutorial_mode:
		if not _tutorial_status_body.is_empty():
			lines.append(HudLayout.break_after_sentences(_tutorial_status_body))
	elif not _status_error_keys.is_empty():
		for e in _status_error_keys:
			var translated := HudLayout.translate_status_text(str(e))
			if not translated.is_empty():
				lines.append(translated)
	else:
		lines.append(HudLayout.break_after_sentences(tr("MSG_FILL_EMPTY")))
	status_label.text = "[center]" + "\n".join(lines) + "[/center]"
	status_label.visible = true

# Hides all overlays (victory, HTP, resume prompt, reset confirm) and re-enables
# the HUD buttons. Called at the start of every new level.
func set_overlays_hidden() -> void:
	if victory_panel:
		victory_panel.visible = false
	if how_to_play_container:
		how_to_play_container.visible = false
	hide_session_resume_prompt()
	hide_reset_confirm()
	_set_end_dimmer_visible(false)
	set_hud_buttons_disabled(false)

# Shows the reset/restart confirmation panel over a transparent dimmer.
# The prompt text varies based on whether reset restarts a fixed layout or generates a new one.
func show_reset_confirm() -> void:
	_set_end_dialog_raised(true)
	if end_dimmer:
		end_dimmer.color = Color(0, 0, 0, 0)
	_set_end_dimmer_visible(true)
	if reset_confirm_label:
		reset_confirm_label.text = tr("CONFIRM_RESTART_LEVEL" if _reset_is_restart else "CONFIRM_NEW_PUZZLE")
		HudLayout.apply_popup_label(reset_confirm_label, GameConstants.UI_BODY_FONT_SIZE_LARGE)
	if reset_confirm_yes:
		reset_confirm_yes.text = tr("UI_YES")
		HudLayout.apply_dialog_button(reset_confirm_yes)
	if reset_confirm_no:
		reset_confirm_no.text = tr("UI_NO")
		HudLayout.apply_dialog_button(reset_confirm_no)
	if victory_panel:
		victory_panel.visible = false
	if resume_panel:
		resume_panel.visible = false
	if reset_confirm_panel:
		reset_confirm_panel.add_theme_stylebox_override("panel", HudLayout.make_dialog_panel_style())
		HudLayout.fit_dialog_panel(reset_confirm_panel, 640.0)
		reset_confirm_panel.visible = true
		reset_confirm_panel.move_to_front()
	set_hud_buttons_disabled(true)

# Hides the reset confirm panel and removes the dimmer only if no other overlay is visible.
func hide_reset_confirm() -> void:
	if reset_confirm_panel:
		reset_confirm_panel.visible = false
	if (
		(victory_panel == null or not victory_panel.visible)
		and (resume_panel == null or not resume_panel.visible)
	):
		_set_end_dimmer_visible(false)
		_set_end_dialog_raised(false)

# Biases EndLayer centered dialogs upward for confirm/resume/victory.
func _set_end_dialog_raised(
	raised: bool, raise_px: float = GameConstants.UI_DIALOG_RAISE_PX
) -> void:
	if end_center == null:
		return
	if raised:
		HudLayout.raise_centered_dialog_host(end_center, raise_px)
	else:
		end_center.offset_bottom = 0.0

# Reset confirm panel button handlers.
func _on_reset_confirm_yes() -> void:
	hide_reset_confirm()
	reset_confirmed.emit()

func _on_reset_confirm_no() -> void:
	hide_reset_confirm()
	reset_cancelled.emit()

# Shows the "Resume or New Layout?" panel when the player returns to a level
# that has an autosaved session. Styles and sizes all three action buttons.
func show_session_resume_prompt() -> void:
	_set_end_dialog_raised(true)
	if end_dimmer:
		end_dimmer.color = Color(0, 0, 0, 0)
	_set_end_dimmer_visible(true)
	if resume_prompt_label:
		resume_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		resume_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		resume_prompt_label.clip_contents = true
		# Panel is 820 wide with 48px side insets → ~724 usable.
		var prompt_w := 700
		if resume_panel:
			prompt_w = maxi(200, int(resume_panel.custom_minimum_size.x) - 96)
		HudLayout.apply_raster_pixel_label(
			resume_prompt_label,
			HudLayout._popup_prompt_with_title_gap(tr("SESSION_RESUME_PROMPT")),
			GameConstants.UI_BODY_FONT_SIZE_LARGE,
			Color(1, 0.84, 0, 1),
			prompt_w
		)
		resume_prompt_label.add_theme_constant_override(
			"line_spacing", 4 if HudLayout.prefer_default_font() else 8
		)
	if resume_panel:
		var continue_btn := resume_panel.get_node_or_null("Buttons/ContinueButton") as Button
		var restart_btn := resume_panel.get_node_or_null("Buttons/RestartButton") as Button
		var back_btn := resume_panel.get_node_or_null("Buttons/BackButton") as Button
		if continue_btn:
			_style_resume_button(continue_btn, tr("UI_CONTINUE"))
		if restart_btn:
			_style_resume_button(restart_btn, tr("UI_NEW_LAYOUT"))
		if back_btn:
			_style_resume_button(back_btn, tr("UI_BACK"))
	if victory_panel:
		victory_panel.visible = false
	if resume_panel:
		resume_panel.add_theme_stylebox_override("panel", _make_end_screen_panel_style())
		var buttons := resume_panel.get_node_or_null("Buttons") as Control
		HudLayout.fit_session_resume_panel(resume_panel, resume_prompt_label, buttons, 820.0)
		resume_panel.visible = true
	set_hud_buttons_disabled(true)

func hide_session_resume_prompt() -> void:
	if resume_panel:
		resume_panel.visible = false
	if victory_panel == null or not victory_panel.visible:
		_set_end_dimmer_visible(false)
		_set_end_dialog_raised(false)

# Session resume panel button handlers.
func _on_session_continue_pressed() -> void:
	hide_session_resume_prompt()
	session_continue_requested.emit()

func _on_session_restart_pressed() -> void:
	hide_session_resume_prompt()
	session_restart_requested.emit()

func _on_session_back_pressed() -> void:
	hide_session_resume_prompt()
	session_back_requested.emit()

func _make_end_screen_panel_style() -> StyleBoxFlat:
	return HudLayout.make_dialog_panel_style()

# Applies pixel/scalable text and sizes a session-resume panel button.
# text overrides button.text when provided (used for translated strings).
func _style_resume_button(button: Button, text: String = "") -> void:
	if not button:
		return
	button.custom_minimum_size = Vector2(460, 110)
	var display := text if not text.is_empty() else button.text
	if button.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED and text.is_empty():
		display = String(TranslationServer.translate(button.text))
	HudLayout.apply_raster_pixel_button(button, display, 28)
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.clip_text = false

# HTP page navigation handlers (bounded to valid page range).
func _on_htp_prev_pressed() -> void:
	_htp_page = maxi(_htp_page - 1, 0)
	_refresh_how_to_play_text()

func _on_htp_next_pressed() -> void:
	_htp_page = mini(_htp_page + 1, HowToPlayContent.PAGE_COUNT - 1)
	_refresh_how_to_play_text()

# Refreshes all how-to-play content for the current page: header title, body text,
# and prev/next button visibility. Defers layout to the next frame so the
# RichTextLabel has a chance to measure its content height.
func _refresh_how_to_play_text() -> void:
	if _htp_header == null and how_to_play_container:
		_htp_header = HudLayout.ensure_how_to_play_page_header(how_to_play_container)
	if _htp_header:
		HudLayout._bind_header_translation_key(
			_htp_header, HowToPlayContent.get_page_title_key(_htp_page)
		)
		HudLayout.apply_screen_header_style(_htp_header)
	if rules_label:
		_setup_how_to_play_font()
		rules_label.text = HowToPlayContent.get_page_text(_htp_page)
	if htp_prev_button:
		htp_prev_button.visible = _htp_page > 0
		htp_prev_button.disabled = false
		HudLayout.apply_nav_button(htp_prev_button)
		HudLayout.refresh_button_icon_modulate(htp_prev_button)
	if tutorial_back_button:
		HudLayout.style_top_bar_close_button(tutorial_back_button)
	if htp_next_button:
		htp_next_button.visible = _htp_page < HowToPlayContent.PAGE_COUNT - 1
		htp_next_button.disabled = false
		HudLayout.apply_nav_button(htp_next_button)
		HudLayout.refresh_button_icon_modulate(htp_next_button)
	call_deferred("_layout_how_to_play_stack")

# Applies final panel/nav placement after rules_label measured its content height.
func _layout_how_to_play_stack() -> void:
	HudLayout.layout_how_to_play_stack(
		how_to_play_container,
		how_to_play_panel,
		rules_label,
		how_to_play_nav,
		_htp_page == 0
	)

# Opens the HTP overlay from page 0 and disables in-game HUD controls.
func show_how_to_play() -> void:
	_htp_page = 0
	HudLayout.clear_how_to_play_nav_lock(how_to_play_container)
	_refresh_how_to_play_text()
	if how_to_play_container:
		how_to_play_container.visible = true
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
	_set_end_dialog_raised(true, GameConstants.UI_VICTORY_RAISE_PX)
	_is_last_level_completed = is_last_level
	_victory_display_num = display_num
	_victory_is_custom = is_custom
	_victory_is_tutorial = is_tutorial
	_victory_star_result = star_result.duplicate(true)
	set_hud_buttons_disabled(true)
	_style_victory_chrome()
	if end_dimmer:
		end_dimmer.color = Color(0, 0, 0, 0)
	_set_end_dimmer_visible(true)
	_refresh_victory_locale()
	_populate_victory_results(_victory_star_result)
	_set_victory_preview(solved_preview)
	_layout_victory_panel(_victory_star_result)
	if victory_panel:
		victory_panel.visible = true

# Re-translates and re-styles all text in the victory panel.
# Called on initial show and after a locale change while the panel is visible.
func _refresh_victory_locale() -> void:
	if win_label:
		if _is_last_level_completed:
			win_label.text = _all_levels_completed_text() + "\n" + tr("YOU_WIN")
		elif _victory_is_custom:
			win_label.text = (tr("CUSTOM_COMPLETED") % _victory_display_num) + "\n" + tr("COMPLETED")
		elif _victory_is_tutorial:
			win_label.text = tr("TUTORIAL") + "\n" + tr("COMPLETED")
		else:
			win_label.text = (tr("LEVEL_COMPLETED") % _victory_display_num) + "\n" + tr("COMPLETED")
		HudLayout.apply_end_screen_header_style(win_label, 48)
		win_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		win_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if victory_restart_label:
		victory_restart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		HudLayout.apply_raster_pixel_label(
			victory_restart_label, tr("NEXT_LEVEL"), GameConstants.UI_BTN_PANEL_FONT, Color.WHITE
		)
	elif restart_button:
		restart_button.text = tr("NEXT_LEVEL")
	if restart_button:
		restart_button.visible = not _is_last_level_completed
		if victory_restart_label == null:
			HudLayout.apply_raster_pixel_button(
				restart_button, tr("NEXT_LEVEL"), GameConstants.UI_BTN_PANEL_FONT
			)
		else:
			HudLayout.apply_panel_button(restart_button)
	if play_again_label:
		play_again_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		HudLayout.apply_raster_pixel_label(
			play_again_label, tr("PLAY_AGAIN"), GameConstants.UI_BTN_PANEL_FONT, Color.WHITE
		)
	if play_again_button:
		play_again_button.visible = true
		HudLayout.apply_panel_button(play_again_button)
	if main_menu_button:
		var menu_label := main_menu_button.get_node_or_null("HBoxContainer/Label") as Label
		if menu_label:
			menu_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			HudLayout.apply_raster_pixel_label(
				menu_label, tr("UI_MAIN_MENU"), GameConstants.UI_BTN_PANEL_FONT, Color.WHITE
			)
		HudLayout.apply_panel_button(main_menu_button)
	if victory_results_host and not _victory_star_result.is_empty():
		_populate_victory_results(_victory_star_result)
	if victory_panel and victory_panel.visible:
		_layout_victory_panel(_victory_star_result)

# Returns the "All levels completed" string with exclamation marks and the
# Spanish inverted exclamation mark stripped, so it can be combined with YOU_WIN
# without double punctuation in any locale.
func _all_levels_completed_text() -> String:
	var text := String(tr("ALL_COMPLETED")).strip_edges()
	while text.ends_with("!") or text.ends_with("！"):
		text = text.substr(0, text.length() - 1).strip_edges()
	if text.begins_with("¡"):
		text = text.substr(1).strip_edges()
	return text

# Keeps overlay centre container transparent to input; dimmer panels handle blocking.
func _setup_end_layer() -> void:
	if end_center:
		end_center.mouse_filter = Control.MOUSE_FILTER_IGNORE

# Shows or hides the full-screen dimmer behind overlay panels.
# Blocks mouse input when visible so clicks don't pass through to the board.
func _set_end_dimmer_visible(should_show: bool) -> void:
	if end_dimmer:
		end_dimmer.visible = should_show
		end_dimmer.mouse_filter = (
			Control.MOUSE_FILTER_STOP if should_show else Control.MOUSE_FILTER_IGNORE
		)

# Applies panel frame and title geometry for the victory overlay.
func _style_victory_chrome() -> void:
	if victory_panel and victory_panel is Panel:
		(victory_panel as Panel).add_theme_stylebox_override("panel", _make_end_screen_panel_style())
	if win_label:
		win_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		win_label.offset_left = 28.0
		win_label.offset_right = -28.0
		win_label.offset_top = 24.0
		win_label.offset_bottom = 220.0
		win_label.clip_contents = false
		win_label.clip_text = false
		win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		win_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

# Moves victory-screen action buttons to the top of the panel's draw order so they
# render above the results host and preview frame.
func _raise_victory_buttons() -> void:
	if victory_panel == null:
		return
	if restart_button:
		victory_panel.move_child(restart_button, -1)
	if play_again_button:
		victory_panel.move_child(play_again_button, -1)
	if main_menu_button:
		victory_panel.move_child(main_menu_button, -1)

# Shows/hides the solved-board preview texture and its decorative frame together.
func _set_victory_preview(texture: Texture2D) -> void:
	if not victory_preview:
		return
	var frame := LevelPreview.ensure_preview_frame(victory_preview)
	victory_preview.texture = texture
	var should_show := texture != null
	victory_preview.visible = should_show
	if frame:
		frame.visible = should_show

# Delegates star goal row rendering to LevelStars.
func _populate_victory_results(star_result: Dictionary) -> void:
	if not victory_results_host:
		return
	if time_result_label:
		time_result_label.visible = false
	LevelStars.populate_results(victory_results_host, star_result)

# Computes and applies absolute pixel positions for all victory panel elements:
# results host, optional board preview, and the action buttons stacked below.
# Panel minimum height adapts to whether a preview is shown and the goal count.
func _layout_victory_panel(star_result: Dictionary) -> void:
	if not victory_panel:
		return
	var goal_count := int(star_result.get("total_count", 0))
	var untimed := bool(star_result.get("untimed", false))
	var title_bottom := 220.0
	var results_h := 0.0
	if not untimed:
		results_h = float(maxi(1, goal_count)) * (LevelStars.ROW_HEIGHT + 14.0) + 24.0
	if not victory_results_host or not victory_preview:
		return
	_raise_victory_buttons()
	victory_results_host.offset_top = title_bottom + 8.0
	victory_results_host.offset_bottom = title_bottom + 8.0 + results_h

	var cursor := title_bottom + 8.0 + results_h
	var preview_h := 0.0
	var frame := LevelPreview.ensure_preview_frame(victory_preview)
	var show_preview := victory_preview.visible and victory_preview.texture != null
	if show_preview:
		var inner := 320.0
		preview_h = LevelPreview.frame_outer_size(inner)
		cursor += 24.0 if results_h > 0.0 else 16.0
		var half := preview_h * 0.5
		var target: Control = frame
		if target == null:
			target = victory_preview
		target.offset_left = -half
		target.offset_right = half
		target.offset_top = cursor
		target.offset_bottom = cursor + preview_h
		cursor += preview_h
	elif frame:
		frame.visible = false

	var buttons_top := cursor + 28.0
	var row := 0
	if restart_button and restart_button.visible:
		_place_victory_button(restart_button, buttons_top, row)
		row += 1
	if play_again_button:
		play_again_button.visible = true
		_place_victory_button(play_again_button, buttons_top, row)
		row += 1
	if main_menu_button:
		_place_victory_button(main_menu_button, buttons_top, row)
		row += 1
	var buttons_bottom := buttons_top + float(row) * 130.0 + 20.0
	var min_h := 980.0 if preview_h > 0.0 else (620.0 if untimed else 900.0)
	victory_panel.custom_minimum_size = Vector2(840, maxf(min_h, buttons_bottom + 40.0))

# Positions a victory button at the given row below buttons_top, centred horizontally.
func _place_victory_button(button: Button, buttons_top: float, row: int) -> void:
	if not button:
		return
	var top := buttons_top + float(row) * 130.0
	button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	button.offset_left = -260.0
	button.offset_right = 260.0
	button.offset_top = top
	button.offset_bottom = top + 110.0
