class_name UIManager
extends Control

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
signal session_continue_requested
signal session_restart_requested
signal session_back_requested
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
@onready var tutorial_back_button: Button = $"../HowToPlayLayer/CenterContainer/NavRow/BackButton"
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

var _is_last_level_completed: bool = false
var _victory_display_num: int = 0
var _victory_is_custom: bool = false
var _victory_is_tutorial: bool = false
var _victory_star_result: Dictionary = {}
var _htp_page: int = 0
var _htp_header: Label
var _tutorial_tools_locked: bool = false
var _highlighted_hud_button: String = ""
var _tutorial_status_body: String = ""
## Tutorial levels: reset restarts the board; other levels: new puzzle.
var _reset_is_restart: bool = false
const _ICON_RESET: Texture2D = preload("res://resources/icons/icon_reset.svg")
const _ICON_RANDOM: Texture2D = preload("res://resources/icons/icon_random.svg")
var _status_error_keys: Array = []
var _hint_remaining: int = GameConstants.HINT_LIMIT_UNLIMITED
var _hint_forced_disabled: bool = false
var _level_display_num: int = 0
var _level_display_custom: bool = false
var _level_display_tutorial: bool = false
var _level_display_set: bool = false
var _joker_current: int = 0
var _joker_required: int = 0
var _move_count: int = 0
var _move_required: int = -1

func _ready() -> void:
	_layout_how_to_play()
	_setup_how_to_play_font()
	_refresh_how_to_play_text()
	_connect_signals()
	_setup_end_layer()
	_style_victory_chrome()
	if SaveManager and not SaveManager.language_changed.is_connected(_on_language_changed):
		SaveManager.language_changed.connect(_on_language_changed)

func _layout_how_to_play() -> void:
	HudLayout.layout_how_to_play(how_to_play_container, how_to_play_panel, how_to_play_nav)
	HudLayout.ensure_how_to_play_nav_slots(how_to_play_nav, htp_prev_button, htp_next_button)
	_htp_header = HudLayout.ensure_how_to_play_page_header(how_to_play_container)

func _on_language_changed() -> void:
	HudLayout.apply_locale_fonts_to_tree(self)
	if _level_display_set:
		display_level(_level_display_num, _level_display_custom, _level_display_tutorial)
	# Tutorial tips first so status refresh uses the new language body.
	locale_refresh_requested.emit()
	_refresh_status_label()
	_refresh_how_to_play_text()
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
	# How-to-play body text always uses the default font (not the pixel UI font).
	rules_label.set_meta("_use_default_font", true)
	HudLayout.apply_locale_font_to_control(rules_label)

func setup_ui(_show_debug_tools: bool, _cell_size: float) -> void:
	_connect_signals()
	set_overlays_hidden()
	set_joker_counter_visibility(false)
	set_move_counter_visibility(false)
	set_status_visible(false)
	HudLayout.position_top_bar(top_margin)
	if status_label:
		HudLayout.apply_status_font(status_label, GameConstants.HUD_STATUS_FONT_SIZE)
	call_deferred("_apply_top_bar_buttons")

func _apply_top_bar_buttons() -> void:
	for button in [pause_button, reset_button, how_to_play_button, hint_button, undo_button, redo_button]:
		HudLayout.apply_square_top_bar_button(button)
	HudLayout.apply_top_bar_mode_label(level_label)
	HudLayout.apply_top_bar_row(top_bar_row)
	HudLayout.align_counter_label(timer_label, GameConstants.HUD_TIMER_Y_NUDGE)
	HudLayout.align_counter_label(joker_counter_label)
	HudLayout.align_counter_label(move_counter_label)
	_refresh_counter_row_alignment()

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
	if redo_button and not redo_button.pressed.is_connected(_on_redo_requested):
		redo_button.pressed.connect(_on_redo_requested)
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

func _on_tutorial_back_pressed() -> void:
	if how_to_play_container:
		how_to_play_container.visible = false
	resume_from_tutorial_requested.emit()

func _on_victory_next_pressed() -> void:
	next_level_requested.emit()

func _on_play_again_pressed() -> void:
	play_again_requested.emit()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

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

func update_joker_counter(current: int, required: int) -> void:
	if not joker_counter_label:
		return
	_joker_current = current
	_joker_required = required
	HudLayout.prepare_counter_label(joker_counter_label)
	joker_counter_label.text = HudLayout.format_icon_ratio_counter(
		GameConstants.TILE_GREEN, current, required, GameConstants.HUD_COUNTER_GREEN, tr("COUNTER_GREEN")
	)

func set_joker_counter_visibility(visible_state: bool) -> void:
	var slot := joker_counter_label.get_parent() as Control if joker_counter_label else null
	if slot:
		slot.visible = visible_state
	elif joker_counter_label:
		joker_counter_label.visible = visible_state
	_refresh_counter_row_alignment()

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

func _refresh_counter_row_alignment() -> void:
	HudLayout.align_counter_row(counter_container)

func set_hint_remaining(remaining: int) -> void:
	_hint_remaining = remaining
	_refresh_hint_button_visual()

func set_hint_button_disabled(is_disabled: bool) -> void:
	_hint_forced_disabled = is_disabled
	_refresh_hint_button_visual()

func _refresh_hint_button_visual() -> void:
	if _tutorial_tools_locked and _highlighted_hud_button != "hint":
		HintController.update_button(hint_button, false, _hint_remaining)
		return
	if _tutorial_tools_locked and _highlighted_hud_button == "hint":
		HintController.update_button(hint_button, true, _hint_remaining)
		return
	HintController.update_button(hint_button, not _hint_forced_disabled, _hint_remaining)

func show_tutorial_status(bbcode_body: String) -> void:
	_tutorial_status_body = bbcode_body
	_refresh_status_label()

func clear_tutorial_status() -> void:
	_tutorial_status_body = ""
	_refresh_status_label()

func set_tutorial_tools_locked(locked: bool) -> void:
	_tutorial_tools_locked = locked
	if not locked:
		_highlighted_hud_button = ""
	_apply_tutorial_tool_state()

func highlight_hud_button(button_id: String) -> void:
	_highlighted_hud_button = button_id
	_apply_tutorial_tool_state()

func clear_hud_button_highlight() -> void:
	_highlighted_hud_button = ""
	_apply_tutorial_tool_state()

## Tutorial: reset icon + restart confirm. Campaign/other: random icon + new puzzle.
func set_reset_mode_restart(is_restart: bool) -> void:
	_reset_is_restart = is_restart
	_apply_reset_button_icon()

func _apply_reset_button_icon() -> void:
	if not reset_button:
		return
	var icon := reset_button.get_node_or_null("IconContainer/Icon") as TextureRect
	if icon:
		icon.texture = _ICON_RESET if _reset_is_restart else _ICON_RANDOM

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

func _apply_tutorial_tool_state() -> void:
	var ids := ["reset", "how_to_play", "hint", "undo", "redo"]
	for id in ids:
		var button := get_hud_button(id)
		if button == null:
			continue
		var is_focus: bool = _highlighted_hud_button == id
		HudLayout.apply_toggle_active_mask(button, is_focus, GameConstants.TOGGLE_MASK_LOCK)
		# Reset and How to Play stay usable during tutorials.
		if id == "reset" or id == "how_to_play":
			button.disabled = false
			HudLayout.refresh_button_icon_modulate(button)
			continue
		if not _tutorial_tools_locked:
			if id == "hint":
				# Caller restores enabled state via set_hint_button_disabled.
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

func update_dynamic_layout(board_y: float, board_height: float) -> void:
	HudLayout.position_counter_row(counter_container)
	if status_label:
		HudLayout.position_status_below_board(status_label, board_y, board_height)

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
	HudLayout.prepare_counter_label(timer_label)
	timer_label.text = HudLayout.format_time_counter(formatted_time)

func set_timer_visibility(visible_state: bool) -> void:
	var slot := timer_label.get_parent() as Control if timer_label else null
	if slot:
		slot.visible = visible_state
	elif timer_label:
		timer_label.visible = visible_state
	if timer_label and not visible_state:
		timer_label.text = ""
	_refresh_counter_row_alignment()

func display_level(num: int, is_custom: bool = false, is_tutorial: bool = false) -> void:
	if not level_label:
		return
	_level_display_num = num
	_level_display_custom = is_custom
	_level_display_tutorial = is_tutorial
	_level_display_set = true
	# Keep LevelLabelWrap in the top-bar layout so button positions stay fixed.
	var label_wrap: Control = level_label.get_parent() as Control
	if label_wrap:
		label_wrap = label_wrap.get_parent() as Control
	if label_wrap:
		label_wrap.visible = true
	level_label.visible = true
	if is_tutorial:
		level_label.modulate.a = 0.0
		level_label.text = ""
		return
	level_label.modulate = Color.WHITE
	var prefix: String
	if is_custom:
		prefix = String(tr("DEV"))
	else:
		prefix = String(tr("LVL"))
	# Pixel font is English-only for now; other locales use the default font.
	level_label.set_meta("_use_default_font", not HudLayout.uses_pixel_font())
	HudLayout.apply_locale_font_to_control(level_label)
	level_label.add_theme_font_size_override("normal_font_size", HudLayout.scaled_font_size(GameConstants.HUD_LEVEL_FONT_SIZE))
	level_label.text = HudLayout.format_outlined_center_text("%s\n%d" % [prefix, num])

func show_status_valid() -> void:
	_status_error_keys.clear()
	_refresh_status_label()

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

func _refresh_status_label() -> void:
	if not status_label:
		return
	status_label.modulate = Color.WHITE
	HudLayout.apply_status_font(status_label, GameConstants.HUD_STATUS_FONT_SIZE)
	var lines: PackedStringArray = []
	if not _tutorial_status_body.is_empty():
		lines.append(HudLayout.break_after_sentences(_tutorial_status_body))
	for e in _status_error_keys:
		var translated := HudLayout.translate_status_text(str(e))
		if not translated.is_empty():
			lines.append(translated)
	# Default fill prompt only when there is no tutorial tip and no errors.
	if lines.is_empty():
		lines.append(HudLayout.break_after_sentences(tr("MSG_FILL_EMPTY")))
	status_label.text = "[center]" + "\n".join(lines) + "[/center]"
	# Keep status visible once content is driven by gameplay / tutorial.
	status_label.visible = true

func set_overlays_hidden() -> void:
	if victory_panel:
		victory_panel.visible = false
	if how_to_play_container:
		how_to_play_container.visible = false
	hide_session_resume_prompt()
	hide_reset_confirm()
	_set_end_dimmer_visible(false)
	set_hud_buttons_disabled(false)

func show_reset_confirm() -> void:
	# Match pause / how-to-play: clear view of the space background (board already hidden).
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
		reset_confirm_panel.visible = true
		reset_confirm_panel.move_to_front()
	set_hud_buttons_disabled(true)

func hide_reset_confirm() -> void:
	if reset_confirm_panel:
		reset_confirm_panel.visible = false
	if (
		(victory_panel == null or not victory_panel.visible)
		and (resume_panel == null or not resume_panel.visible)
	):
		_set_end_dimmer_visible(false)

func _on_reset_confirm_yes() -> void:
	hide_reset_confirm()
	reset_confirmed.emit()

func _on_reset_confirm_no() -> void:
	hide_reset_confirm()
	reset_cancelled.emit()

func show_session_resume_prompt() -> void:
	# Keep space background undimmed (same as reset confirm / pause).
	if end_dimmer:
		end_dimmer.color = Color(0, 0, 0, 0)
	_set_end_dimmer_visible(true)
	if resume_prompt_label:
		resume_prompt_label.text = tr("SESSION_RESUME_PROMPT")
		HudLayout.apply_popup_label(resume_prompt_label, GameConstants.UI_BODY_FONT_SIZE_LARGE)
	if resume_panel:
		var continue_btn := resume_panel.get_node_or_null("Buttons/ContinueButton") as Button
		var restart_btn := resume_panel.get_node_or_null("Buttons/RestartButton") as Button
		var back_btn := resume_panel.get_node_or_null("Buttons/BackButton") as Button
		if continue_btn:
			continue_btn.text = tr("UI_CONTINUE")
			_style_resume_button(continue_btn)
		if restart_btn:
			restart_btn.text = tr("UI_NEW_LAYOUT")
			_style_resume_button(restart_btn)
		if back_btn:
			back_btn.text = tr("UI_BACK")
			_style_resume_button(back_btn)
	if victory_panel:
		victory_panel.visible = false
	if resume_panel:
		resume_panel.add_theme_stylebox_override("panel", _make_end_screen_panel_style())
		resume_panel.visible = true
	set_hud_buttons_disabled(true)

func hide_session_resume_prompt() -> void:
	if resume_panel:
		resume_panel.visible = false
	if victory_panel == null or not victory_panel.visible:
		_set_end_dimmer_visible(false)

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

## Wider than generic dialog buttons so "NEW PUZZLE" doesn't wrap / clip on mobile.
func _style_resume_button(button: Button) -> void:
	if not button:
		return
	button.custom_minimum_size = Vector2(460, 110)
	var outline := 8
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		# Lighter outline avoids Press Start glyph-edge clipping (same as end-screen headers).
		outline = 5
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", outline)
	HudLayout.fit_text_button(button, 28, 18)
	# fit_text_button enables wrap — keep one line so glyphs don't clip into each other.
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.clip_text = false

func _on_htp_prev_pressed() -> void:
	_htp_page = maxi(_htp_page - 1, 0)
	_refresh_how_to_play_text()

func _on_htp_next_pressed() -> void:
	_htp_page = mini(_htp_page + 1, HowToPlayContent.PAGE_COUNT - 1)
	_refresh_how_to_play_text()

func _refresh_how_to_play_text() -> void:
	if _htp_header == null and how_to_play_container:
		_htp_header = HudLayout.ensure_how_to_play_page_header(how_to_play_container)
	if _htp_header:
		_htp_header.text = tr(HowToPlayContent.get_page_title_key(_htp_page))
		HudLayout.apply_screen_header_style(_htp_header)
	if rules_label:
		_setup_how_to_play_font()
		rules_label.text = HowToPlayContent.get_page_text(_htp_page)
	if htp_prev_button:
		htp_prev_button.text = tr("UI_PREVIOUS")
		htp_prev_button.visible = _htp_page > 0
		htp_prev_button.disabled = false
		HudLayout.apply_nav_button(htp_prev_button)
		HudLayout.refresh_button_icon_modulate(htp_prev_button)
	if tutorial_back_button:
		tutorial_back_button.text = tr("UI_CLOSE")
		HudLayout.apply_secondary_button(tutorial_back_button)
	if htp_next_button:
		htp_next_button.text = tr("UI_NEXT")
		htp_next_button.visible = _htp_page < HowToPlayContent.PAGE_COUNT - 1
		htp_next_button.disabled = false
		HudLayout.apply_nav_button(htp_next_button)
		HudLayout.refresh_button_icon_modulate(htp_next_button)

func show_how_to_play() -> void:
	_htp_page = 0
	_refresh_how_to_play_text()
	if how_to_play_container:
		how_to_play_container.visible = true
	set_hud_buttons_disabled(true)

func show_victory(
	display_num: int,
	is_last_level: bool,
	star_result: Dictionary = {},
	is_custom: bool = false,
	is_tutorial: bool = false,
	solved_preview: Texture2D = null
) -> void:
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

func _refresh_victory_locale() -> void:
	if win_label:
		if _is_last_level_completed:
			win_label.text = tr("ALL_COMPLETED") + "\n" + tr("YOU_WIN")
		elif _victory_is_custom:
			win_label.text = (tr("CUSTOM_COMPLETED") % _victory_display_num) + "\n" + tr("COMPLETED")
		elif _victory_is_tutorial:
			win_label.text = (tr("TUTORIAL_COMPLETED") % _victory_display_num) + "\n" + tr("COMPLETED")
		else:
			win_label.text = (tr("LEVEL_COMPLETED") % _victory_display_num) + "\n" + tr("COMPLETED")
		HudLayout.apply_end_screen_header_style(win_label, 48)
		# Explicit two-line title: "LEVEL 1" / "COMPLETED!"
		win_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		win_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if victory_restart_label:
		victory_restart_label.text = tr("NEXT_LEVEL")
		HudLayout.apply_locale_font_to_control(victory_restart_label)
	elif restart_button:
		restart_button.text = tr("NEXT_LEVEL")
	if restart_button:
		restart_button.visible = not _is_last_level_completed
		HudLayout.apply_panel_button(restart_button)
	if play_again_label:
		play_again_label.text = tr("PLAY_AGAIN")
		HudLayout.apply_locale_font_to_control(play_again_label)
	if play_again_button:
		play_again_button.visible = true
		HudLayout.apply_panel_button(play_again_button)
	if main_menu_button:
		var menu_label := main_menu_button.get_node_or_null("HBoxContainer/Label") as Label
		if menu_label:
			menu_label.text = tr("UI_MAIN_MENU")
			HudLayout.apply_locale_font_to_control(menu_label)
		HudLayout.apply_panel_button(main_menu_button)
	if victory_results_host and not _victory_star_result.is_empty():
		_populate_victory_results(_victory_star_result)
	if victory_panel and victory_panel.visible:
		_layout_victory_panel(_victory_star_result)

func _setup_end_layer() -> void:
	# Keep full-screen center as IGNORE so HUD stays clickable when overlays are off.
	if end_center:
		end_center.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _set_end_dimmer_visible(should_show: bool) -> void:
	if end_dimmer:
		end_dimmer.visible = should_show
		end_dimmer.mouse_filter = (
			Control.MOUSE_FILTER_STOP if should_show else Control.MOUSE_FILTER_IGNORE
		)

func _style_victory_chrome() -> void:
	if victory_panel and victory_panel is Panel:
		(victory_panel as Panel).add_theme_stylebox_override("panel", _make_end_screen_panel_style())
	if win_label:
		win_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
		win_label.offset_left = 28.0
		win_label.offset_right = -28.0
		# Extra vertical room for two-line title + outlined glyphs on mobile.
		win_label.offset_top = 24.0
		win_label.offset_bottom = 220.0
		win_label.clip_contents = false
		win_label.clip_text = false
		win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		win_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _raise_victory_buttons() -> void:
	if victory_panel == null:
		return
	if restart_button:
		victory_panel.move_child(restart_button, -1)
	if play_again_button:
		victory_panel.move_child(play_again_button, -1)
	if main_menu_button:
		victory_panel.move_child(main_menu_button, -1)

func _set_victory_preview(texture: Texture2D) -> void:
	if not victory_preview:
		return
	victory_preview.texture = texture
	victory_preview.visible = texture != null

func _populate_victory_results(star_result: Dictionary) -> void:
	if not victory_results_host:
		return
	if time_result_label:
		time_result_label.visible = false
	LevelStars.populate_results(victory_results_host, star_result)

func _layout_victory_panel(star_result: Dictionary) -> void:
	if not victory_panel:
		return
	var goal_count := int(star_result.get("total_count", 0))
	var untimed := bool(star_result.get("untimed", false))
	var title_bottom := 220.0
	var results_h := 0.0
	if not untimed:
		results_h = 90.0 + float(maxi(1, goal_count)) * (LevelStars.ROW_HEIGHT + 14.0)
	if not victory_results_host or not victory_preview:
		return
	_raise_victory_buttons()
	victory_results_host.offset_top = title_bottom + 8.0
	victory_results_host.offset_bottom = title_bottom + 8.0 + results_h

	var cursor := title_bottom + 8.0 + results_h
	var preview := victory_preview
	var preview_h := 0.0
	if preview.visible and preview.texture != null:
		preview_h = 320.0
		cursor += 24.0 if results_h > 0.0 else 16.0
		preview.offset_left = -160.0
		preview.offset_right = 160.0
		preview.offset_top = cursor
		preview.offset_bottom = cursor + preview_h
		cursor += preview_h

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

func _place_victory_button(button: Button, buttons_top: float, row: int) -> void:
	if not button:
		return
	var top := buttons_top + float(row) * 130.0
	button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	button.offset_left = -260.0
	button.offset_right = 260.0
	button.offset_top = top
	button.offset_bottom = top + 110.0
