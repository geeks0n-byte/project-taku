class_name UIManager
extends Control

signal pause_requested
signal reset_requested
signal how_to_play_requested
signal resume_from_tutorial_requested
signal next_level_requested
signal play_again_requested
signal hint_requested
signal undo_requested
signal redo_requested

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
@onready var defeat_panel: Control = $"../EndLayer/CenterContainer/DefeatPanel"
@onready var defeat_restart_button: Button = $"../EndLayer/CenterContainer/DefeatPanel/RestartButton"
@onready var defeat_main_menu_button: Button = $"../EndLayer/CenterContainer/DefeatPanel/MainMenuButton"
@onready var defeat_label: Label = $"../EndLayer/CenterContainer/DefeatPanel/DefeatLabel"
@onready var how_to_play_container: Control = $"../HowToPlayLayer/CenterContainer"
@onready var tutorial_back_button: Button = $"../HowToPlayLayer/CenterContainer/HowToPlayPanel/NavRow/BackButton"
@onready var htp_prev_button: Button = $"../HowToPlayLayer/CenterContainer/HowToPlayPanel/NavRow/PrevButton"
@onready var htp_next_button: Button = $"../HowToPlayLayer/CenterContainer/HowToPlayPanel/NavRow/NextButton"
@onready var rules_label: RichTextLabel = $"../HowToPlayLayer/CenterContainer/HowToPlayPanel/RulesLabel"
@onready var victory_restart_label: Label = $"../EndLayer/CenterContainer/VictoryPanel/RestartButton/HBoxContainer/Label"

var _is_last_level_completed: bool = false
var _htp_page: int = 0

func _ready() -> void:
	_setup_how_to_play_font()
	_refresh_how_to_play_text()
	_connect_signals()

func _setup_how_to_play_font() -> void:
	if not rules_label:
		return
	# How-to-play body text always uses the default font (not the pixel UI font).
	rules_label.set_meta("_use_default_font", true)
	HudLayout.apply_locale_font_to_control(rules_label)

func setup_ui(_show_debug_tools: bool, _cell_size: float) -> void:
	_connect_signals()
	set_overlays_hidden()
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
	if restart_button and not restart_button.pressed.is_connected(_on_victory_button_pressed):
		restart_button.pressed.connect(_on_victory_button_pressed)
	if main_menu_button and not main_menu_button.pressed.is_connected(_on_main_menu_pressed):
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	if defeat_restart_button and not defeat_restart_button.pressed.is_connected(_on_reset_requested):
		defeat_restart_button.pressed.connect(_on_reset_requested)
	if defeat_main_menu_button and not defeat_main_menu_button.pressed.is_connected(_on_main_menu_pressed):
		defeat_main_menu_button.pressed.connect(_on_main_menu_pressed)
	if tutorial_back_button and not tutorial_back_button.pressed.is_connected(_on_tutorial_back_pressed):
		tutorial_back_button.pressed.connect(_on_tutorial_back_pressed)
	if htp_prev_button and not htp_prev_button.pressed.is_connected(_on_htp_prev_pressed):
		htp_prev_button.pressed.connect(_on_htp_prev_pressed)
	if htp_next_button and not htp_next_button.pressed.is_connected(_on_htp_next_pressed):
		htp_next_button.pressed.connect(_on_htp_next_pressed)

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

func _on_victory_button_pressed() -> void:
	if _is_last_level_completed:
		play_again_requested.emit()
	else:
		next_level_requested.emit()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func update_undo_redo_buttons(can_undo: bool, can_redo: bool) -> void:
	if undo_button:
		undo_button.disabled = not can_undo
		HudLayout.refresh_button_icon_modulate(undo_button)
	if redo_button:
		redo_button.disabled = not can_redo
		HudLayout.refresh_button_icon_modulate(redo_button)

func update_joker_counter(current: int, required: int) -> void:
	if not joker_counter_label:
		return
	HudLayout.prepare_counter_label(joker_counter_label)
	joker_counter_label.text = HudLayout.format_icon_ratio_counter(
		GameConstants.TILE_GREEN, current, required, GameConstants.HUD_COUNTER_GREEN, tr("COUNTER_GREEN")
	)

func set_joker_counter_visibility(visible_state: bool) -> void:
	if joker_counter_label:
		joker_counter_label.visible = visible_state

func update_move_counter(moves: int, required: int = -1) -> void:
	if not move_counter_label:
		return
	HudLayout.prepare_counter_label(move_counter_label)
	var target := required if required >= 0 else moves
	move_counter_label.text = HudLayout.format_icon_ratio_counter(
		GameConstants.TILE_SHIFTER, moves, target, GameConstants.HUD_COUNTER_SHIFTER, tr("MOVES")
	)

func set_move_counter_visibility(visible_state: bool) -> void:
	if move_counter_label:
		move_counter_label.visible = visible_state

func set_hint_button_disabled(is_disabled: bool) -> void:
	HintController.update_button(hint_button, not is_disabled)

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
			HintController.update_button(hint_button, false)

func update_timer(formatted_time: String) -> void:
	if not timer_label:
		return
	HudLayout.prepare_counter_label(timer_label)
	timer_label.text = HudLayout.format_time_counter(formatted_time, tr("TIME"))

func display_level(num: int, is_custom: bool = false) -> void:
	if level_label:
		var prefix := String(tr("DEV") if is_custom else tr("LVL"))
		level_label.add_theme_font_size_override("normal_font_size", HudLayout.scaled_font_size(GameConstants.HUD_LEVEL_FONT_SIZE))
		level_label.text = HudLayout.format_outlined_center_text("%s\n%d" % [prefix, num])

func show_status_valid() -> void:
	if not status_label:
		return
	status_label.modulate = Color.WHITE
	HudLayout.apply_status_font(status_label, GameConstants.HUD_STATUS_FONT_SIZE)
	status_label.text = "[center]" + tr("MSG_FILL_EMPTY") + "[/center]"

func show_status_errors(errors: Array) -> void:
	if not status_label:
		return
	status_label.modulate = Color.WHITE
	HudLayout.apply_status_font(status_label, GameConstants.HUD_STATUS_FONT_SIZE)
	var tr_errors: PackedStringArray = []
	for e in errors:
		tr_errors.append(HudLayout.translate_status_text(str(e)))
	status_label.text = "[center]" + "\n".join(tr_errors) + "[/center]"

func set_overlays_hidden() -> void:
	if victory_panel:
		victory_panel.visible = false
	if defeat_panel:
		defeat_panel.visible = false
	if how_to_play_container:
		how_to_play_container.visible = false
	set_hud_buttons_disabled(false)

func _on_htp_prev_pressed() -> void:
	_htp_page = maxi(_htp_page - 1, 0)
	_refresh_how_to_play_text()

func _on_htp_next_pressed() -> void:
	_htp_page = mini(_htp_page + 1, HowToPlayContent.PAGE_COUNT - 1)
	_refresh_how_to_play_text()

func _refresh_how_to_play_text() -> void:
	if rules_label:
		_setup_how_to_play_font()
		rules_label.text = HowToPlayContent.get_page_text(_htp_page)
	if htp_prev_button:
		htp_prev_button.text = tr("UI_PREVIOUS")
		htp_prev_button.disabled = _htp_page <= 0
		HudLayout.fit_text_button(htp_prev_button, 22, 12)
		HudLayout.refresh_button_icon_modulate(htp_prev_button)
	if tutorial_back_button:
		tutorial_back_button.text = tr("UI_CLOSE")
		HudLayout.fit_text_button(tutorial_back_button, 24, 14)
	if htp_next_button:
		htp_next_button.text = tr("UI_NEXT")
		htp_next_button.disabled = _htp_page >= HowToPlayContent.PAGE_COUNT - 1
		HudLayout.fit_text_button(htp_next_button, 22, 12)
		HudLayout.refresh_button_icon_modulate(htp_next_button)

func show_how_to_play() -> void:
	_htp_page = 0
	_refresh_how_to_play_text()
	if how_to_play_container:
		how_to_play_container.visible = true
	set_hud_buttons_disabled(true)

func show_victory(display_num: int, is_last_level: bool, formatted_time: String, is_custom: bool = false) -> void:
	_is_last_level_completed = is_last_level
	set_hud_buttons_disabled(true)
	if win_label:
		if is_last_level:
			win_label.text = tr("ALL_COMPLETED") + "\n" + tr("YOU_WIN")
		else:
			win_label.text = (tr("CUSTOM_COMPLETED") if is_custom else tr("LEVEL_COMPLETED")) % display_num
	if victory_restart_label:
		victory_restart_label.text = tr("PLAY_AGAIN") if is_last_level else tr("NEXT_LEVEL")
	elif restart_button:
		restart_button.text = tr("PLAY_AGAIN") if is_last_level else tr("NEXT_LEVEL")
	if time_result_label:
		time_result_label.text = tr("COMPLETION_TIME") % formatted_time
	if main_menu_button:
		var menu_label := main_menu_button.get_node_or_null("HBoxContainer/Label") as Label
		if menu_label:
			menu_label.text = tr("UI_MAIN_MENU")
	if victory_panel:
		victory_panel.visible = true

func show_defeat() -> void:
	set_hud_buttons_disabled(true)
	if defeat_label:
		defeat_label.text = tr("TIMES_UP")
	if defeat_restart_button:
		var restart_label := defeat_restart_button.get_node_or_null("HBoxContainer/Label") as Label
		if restart_label:
			restart_label.text = tr("UI_TRY_AGAIN")
		else:
			defeat_restart_button.text = tr("UI_TRY_AGAIN")
	if defeat_main_menu_button:
		var menu_label := defeat_main_menu_button.get_node_or_null("HBoxContainer/Label") as Label
		if menu_label:
			menu_label.text = tr("UI_MAIN_MENU")
	if defeat_panel:
		defeat_panel.visible = true
