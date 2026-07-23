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

var level_label: RichTextLabel
var status_label: RichTextLabel
var timer_label: RichTextLabel
var joker_counter_label: RichTextLabel
var move_counter_label: RichTextLabel
var pause_button: Button
var reset_button: Button
var how_to_play_button: Button 
var hint_button: Button
var undo_button: Button
var redo_button: Button
var victory_panel: Control
var restart_button: Button
var main_menu_button: Button
var time_result_label: Label
var win_label: Label
var defeat_panel: Control
var defeat_restart_button: Button
var defeat_main_menu_button: Button
var defeat_label: Label
var how_to_play_container: Control
var tutorial_back_button: Button

var _is_last_level_completed: bool = false

func _ready():
	var root = get_tree().current_scene
	if not root: root = get_parent()
	level_label = root.find_child("LevelLabel", true, false) as RichTextLabel
	status_label = root.find_child("StatusLabel", true, false) as RichTextLabel
	timer_label = root.find_child("TimerLabel", true, false) as RichTextLabel
	joker_counter_label = root.find_child("JokerCounterLabel", true, false) as RichTextLabel
	move_counter_label = root.find_child("MoveCounterLabel", true, false) as RichTextLabel
	pause_button = root.find_child("PauseButton", true, false) as Button
	reset_button = root.find_child("ResetButton", true, false) as Button
	how_to_play_button = root.find_child("HowToPlayButton", true, false) as Button
	hint_button = root.find_child("HintButton", true, false) as Button
	undo_button = root.find_child("UndoButton", true, false) as Button
	redo_button = root.find_child("RedoButton", true, false) as Button
	victory_panel = root.find_child("VictoryPanel", true, false) as Control
	if victory_panel:
		restart_button = victory_panel.find_child("RestartButton", true, false) as Button
		main_menu_button = victory_panel.find_child("MainMenuButton", true, false) as Button
		time_result_label = victory_panel.find_child("TimeResultLabel", true, false) as Label
		win_label = victory_panel.find_child("WinLabel", true, false) as Label
	defeat_panel = root.find_child("DefeatPanel", true, false) as Control
	if defeat_panel:
		defeat_restart_button = defeat_panel.find_child("RestartButton", true, false) as Button
		if not defeat_restart_button: defeat_restart_button = defeat_panel.find_child("TryAgainButton", true, false) as Button
		defeat_main_menu_button = defeat_panel.find_child("MainMenuButton", true, false) as Button
		defeat_label = defeat_panel.find_child("DefeatLabel", true, false) as Label
	var htp_panel = root.find_child("HowToPlayPanel", true, false) as Control
	if htp_panel:
		how_to_play_container = htp_panel.get_parent() as Control
		tutorial_back_button = htp_panel.find_child("BackButton", true, false) as Button

func setup_ui(_show_debug_tools: bool, _cell_size: float):
	if hint_button: hint_button.disabled = true
	if undo_button: undo_button.disabled = true
	if redo_button: redo_button.disabled = true
	_connect_signals()
	set_overlays_hidden()
	if status_label:
		status_label.remove_theme_font_override("normal_font")
		status_label.text = "[center]" + tr("MSG_FILL_EMPTY") + "[/center]"

func _connect_signals():
	if pause_button and not pause_button.pressed.is_connected(_on_pause_requested): pause_button.pressed.connect(_on_pause_requested)
	if reset_button and not reset_button.pressed.is_connected(_on_reset_requested): reset_button.pressed.connect(_on_reset_requested)
	if how_to_play_button and not how_to_play_button.pressed.is_connected(_on_how_to_play_requested): how_to_play_button.pressed.connect(_on_how_to_play_requested)
	if hint_button and not hint_button.pressed.is_connected(_on_hint_requested): hint_button.pressed.connect(_on_hint_requested)
	if undo_button and not undo_button.pressed.is_connected(_on_undo_requested): undo_button.pressed.connect(_on_undo_requested)
	if redo_button and not redo_button.pressed.is_connected(_on_redo_requested): redo_button.pressed.connect(_on_redo_requested)
	if restart_button and not restart_button.pressed.is_connected(_on_victory_button_pressed): restart_button.pressed.connect(_on_victory_button_pressed)
	if main_menu_button and not main_menu_button.pressed.is_connected(_on_main_menu_pressed): main_menu_button.pressed.connect(_on_main_menu_pressed)
	if defeat_restart_button and not defeat_restart_button.pressed.is_connected(_on_reset_requested): defeat_restart_button.pressed.connect(_on_reset_requested)
	if defeat_main_menu_button and not defeat_main_menu_button.pressed.is_connected(_on_main_menu_pressed): defeat_main_menu_button.pressed.connect(_on_main_menu_pressed)
	if tutorial_back_button and not tutorial_back_button.pressed.is_connected(_on_tutorial_back_pressed): tutorial_back_button.pressed.connect(_on_tutorial_back_pressed)

func _on_pause_requested(): pause_requested.emit()
func _on_reset_requested(): reset_requested.emit()
func _on_how_to_play_requested(): how_to_play_requested.emit()
func _on_hint_requested(): hint_requested.emit()
func _on_undo_requested(): undo_requested.emit()
func _on_redo_requested(): redo_requested.emit()

func _on_tutorial_back_pressed():
	if how_to_play_container: how_to_play_container.visible = false
	resume_from_tutorial_requested.emit()

func _on_victory_button_pressed():
	if _is_last_level_completed: play_again_requested.emit()
	else: next_level_requested.emit()

func _on_main_menu_pressed():
	get_tree().paused = false 
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func update_undo_redo_buttons(can_undo: bool, can_redo: bool):
	if undo_button: undo_button.disabled = not can_undo
	if redo_button: redo_button.disabled = not can_redo

func update_joker_counter(current: int, required: int):
	if joker_counter_label:
		joker_counter_label.text = "[center][img=28x28]" + GameConstants.TILE_GREEN + "[/img] " + tr("USED") + ": %d/%d[/center]" % [current, required]

func set_joker_counter_visibility(visible_state: bool):
	if joker_counter_label: joker_counter_label.visible = visible_state

func update_move_counter(moves: int):
	if move_counter_label:
		move_counter_label.text = "[center][img=28x28]" + GameConstants.TILE_PURPLE + "[/img] " + tr("MOVES") + ": %d[/center]" % moves

func set_move_counter_visibility(visible_state: bool):
	if move_counter_label: move_counter_label.visible = visible_state

func set_hint_button_disabled(is_disabled: bool):
	if hint_button: hint_button.disabled = is_disabled

func update_dynamic_layout(_board_y: float, _board_height: float):
	pass
	
func set_hud_buttons_disabled(is_disabled: bool):
	if pause_button: pause_button.disabled = is_disabled
	if reset_button: reset_button.disabled = is_disabled
	if how_to_play_button: how_to_play_button.disabled = is_disabled
	if is_disabled:
		if undo_button: undo_button.disabled = true
		if redo_button: redo_button.disabled = true
		if hint_button: hint_button.disabled = true

func update_timer(formatted_time: String):
	if timer_label: 
		if formatted_time == "∞":
			timer_label.text = "[center]" + tr("TIME") + ": [img=36x36]" + GameConstants.ICON_INFINITY + "[/img][/center]"
		else: timer_label.text = "[center]" + tr("TIME") + ": " + formatted_time + "[/center]"

func display_level(num: int, is_custom: bool = false):
	if level_label: level_label.text = "[center]" + (tr("DEV") if is_custom else tr("LVL")) + " %d[/center]" % num

func show_status_valid():
	if status_label:
		status_label.modulate = Color.WHITE
		status_label.text = "[center]" + tr("MSG_FILL_EMPTY") + "[/center]"

func show_status_errors(errors: Array):
	if status_label:
		status_label.modulate = Color.WHITE
		var tr_errors = []
		for e in errors: tr_errors.append(tr(e))
		status_label.text = "[center]" + "\n".join(tr_errors) + "[/center]"

func set_overlays_hidden():
	if victory_panel: victory_panel.visible = false
	if defeat_panel: defeat_panel.visible = false
	if how_to_play_container: how_to_play_container.visible = false 
	set_hud_buttons_disabled(false)

func show_how_to_play():
	if how_to_play_container: how_to_play_container.visible = true
	set_hud_buttons_disabled(true)

func show_victory(display_num: int, is_last_level: bool, formatted_time: String, is_custom: bool = false):
	_is_last_level_completed = is_last_level
	set_hud_buttons_disabled(true)
	if status_label:
		status_label.modulate = Color(1.0, 0.84, 0.0)
		status_label.text = "[center]" + tr("PUZZLE_SOLVED") + "[/center]"
	if win_label:
		if is_last_level: win_label.text = tr("ALL_COMPLETED") + "\n" + tr("YOU_WIN")
		else: win_label.text = (tr("CUSTOM_COMPLETED") if is_custom else tr("LEVEL_COMPLETED")) % display_num
	if restart_button:
		var lbl = restart_button.find_child("Label", true, false)
		if lbl: lbl.text = tr("PLAY_AGAIN") if is_last_level else tr("NEXT_LEVEL")
		else: restart_button.text = tr("PLAY_AGAIN") if is_last_level else tr("NEXT_LEVEL")
	if time_result_label: time_result_label.text = tr("COMPLETION_TIME") + ": %s" % formatted_time
	if victory_panel: victory_panel.visible = true

func show_defeat():
	set_hud_buttons_disabled(true)
	if status_label:
		status_label.modulate = Color(1.0, 0.3, 0.3)
		status_label.text = "[center]" + tr("TIMES_UP_UNSOLVED") + "[/center]"
	if defeat_panel: defeat_panel.visible = true
