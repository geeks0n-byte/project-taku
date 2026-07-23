class_name PlaytestUIManager
extends Node2D

signal test_mode_exited
signal playtest_reset_requested
signal playtest_rules_requested
signal playtest_hint_requested
signal playtest_undo_requested
signal playtest_redo_requested
signal resume_from_tutorial_requested

@onready var root = get_parent()
@onready var playtest_hud_container = root.find_child("PlaytestHUD", true, false)
@onready var pt_exit_button = root.find_child("PTExitButton", true, false)
@onready var pt_reset_button = root.find_child("PTResetButton", true, false)
@onready var pt_rules_button = root.find_child("PTRulesButton", true, false)
@onready var pt_hint_button = root.find_child("PTHintButton", true, false)
@onready var pt_undo_button = root.find_child("PTUndoButton", true, false)
@onready var pt_redo_button = root.find_child("PTRedoButton", true, false)
@onready var pt_title_label = root.find_child("PTTitleLabel", true, false)
@onready var pt_timer_label = root.find_child("PTTimerLabel", true, false)
@onready var pt_moves_label = root.find_child("PTMoveCounterLabel", true, false)
@onready var pt_jokers_label = root.find_child("PTJokerCounterLabel", true, false)
@onready var pt_status_label = root.find_child("PTStatusLabel", true, false)
@onready var playtest_victory_panel = root.find_child("PlaytestVictoryPanel", true, false)
@onready var victory_message_label = root.find_child("VictoryMessageLabel", true, false)
@onready var return_button = root.find_child("ReturnButton", true, false)

@onready var how_to_play_panel = root.find_child("HowToPlayPanel", true, false)
@onready var how_to_play_container = how_to_play_panel.get_parent() if how_to_play_panel else null
@onready var tutorial_back_button = root.find_child("BackButton", true, false)

func _ready():
	_connect_pt_signals()
	if pt_title_label:
		var pulse_tween = create_tween().set_loops()
		pulse_tween.tween_property(pt_title_label, "modulate:a", 0.2, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse_tween.tween_property(pt_title_label, "modulate:a", 1.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _connect_pt_signals():
	if pt_exit_button: pt_exit_button.pressed.connect(func(): test_mode_exited.emit())
	if pt_reset_button: pt_reset_button.pressed.connect(func(): playtest_reset_requested.emit())
	if pt_rules_button: pt_rules_button.pressed.connect(func(): playtest_rules_requested.emit())
	if pt_hint_button: pt_hint_button.pressed.connect(func(): playtest_hint_requested.emit())
	if pt_undo_button: pt_undo_button.pressed.connect(func(): playtest_undo_requested.emit())
	if pt_redo_button: pt_redo_button.pressed.connect(func(): playtest_redo_requested.emit())
	if return_button: return_button.pressed.connect(func():
		hide_victory_overlay()
		test_mode_exited.emit()
	)
	if tutorial_back_button: tutorial_back_button.pressed.connect(func():
		if how_to_play_container: how_to_play_container.visible = false
		if pt_reset_button: pt_reset_button.disabled = false
		if pt_rules_button: pt_rules_button.disabled = false
		if pt_hint_button: pt_hint_button.disabled = false
		if pt_undo_button: pt_undo_button.disabled = false
		if pt_redo_button: pt_redo_button.disabled = false
		if pt_exit_button: pt_exit_button.disabled = false
		resume_from_tutorial_requested.emit()
	)

func update_playtest_status(msg: String, text_color: Color):
	if pt_status_label:
		pt_status_label.modulate = text_color
		pt_status_label.text = "[center]" + tr(msg).replace("[center]", "").replace("[/center]", "") + "[/center]"
		pt_status_label.fit_content = true

func toggle_playtest_visibility(is_playtesting: bool):
	if playtest_hud_container: playtest_hud_container.visible = is_playtesting

func update_dynamic_playtest_layout(_board_y: float, _board_height: float):
	pass

func update_playtest_undo_redo_buttons(can_undo: bool, can_redo: bool):
	if pt_undo_button: pt_undo_button.disabled = not can_undo
	if pt_redo_button: pt_redo_button.disabled = not can_redo

func display_victory_overlay(compiled_text: String):
	if victory_message_label:
		victory_message_label.text = tr(compiled_text)
		victory_message_label.modulate = Color(1.0, 0.3, 0.3) if "DEFEAT" in compiled_text else Color(0.4, 1.0, 0.4)
	if playtest_victory_panel: playtest_victory_panel.visible = true

func hide_victory_overlay():
	if playtest_victory_panel: playtest_victory_panel.visible = false

func show_how_to_play():
	if how_to_play_container: how_to_play_container.visible = true
	if pt_reset_button: pt_reset_button.disabled = true
	if pt_rules_button: pt_rules_button.disabled = true
	if pt_hint_button: pt_hint_button.disabled = true
	if pt_undo_button: pt_undo_button.disabled = true
	if pt_redo_button: pt_redo_button.disabled = true
	if pt_exit_button: pt_exit_button.disabled = true

func update_playtest_hud(time_remaining: int, moves: int, editor_time_limit: int):
	if pt_timer_label:
		if editor_time_limit == 0:
			pt_timer_label.text = "[center]" + tr("TIME") + ": [img=46x46]" + GameConstants.ICON_INFINITY + "[/img][/center]"
		else:
			var minutes = max(0, int(time_remaining / 60.0))
			var seconds = max(0, time_remaining % 60)
			pt_timer_label.text = "[center]" + tr("TIME") + ": %02d:%02d[/center]" % [minutes, seconds]
	if pt_moves_label:
		pt_moves_label.text = "[center][img=32x32]" + GameConstants.TILE_PURPLE + "[/img] " + tr("MOVES") + ": %d[/center]" % moves

func update_playtest_joker_counter(current: int, required: int):
	if pt_jokers_label:
		pt_jokers_label.text = "[center][img=32x32]" + GameConstants.TILE_GREEN + "[/img] " + tr("USED") + ": %d/%d[/center]" % [current, required]

func set_playtest_joker_counter_visibility(visible_state: bool):
	if pt_jokers_label: pt_jokers_label.visible = visible_state

func set_playtest_move_counter_visibility(visible_state: bool):
	if pt_moves_label: pt_moves_label.visible = visible_state

func set_playtest_hint_button_disabled(is_disabled: bool):
	if pt_hint_button: pt_hint_button.disabled = is_disabled
