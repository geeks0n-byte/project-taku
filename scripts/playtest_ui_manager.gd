class_name PlaytestUIManager
extends Node2D

signal test_mode_exited
signal playtest_reset_requested
signal playtest_rules_requested
signal playtest_hint_requested
signal playtest_undo_requested
signal playtest_redo_requested
signal resume_from_tutorial_requested

@onready var playtest_hud_container: MarginContainer = $"../EditorUI/PlaytestHUD"
@onready var top_bar_row: HBoxContainer = $"../EditorUI/PlaytestHUD/TopBarRow"
@onready var exit_button: Button = $"../EditorUI/PlaytestHUD/TopBarRow/LeftButtons/ExitButton"
@onready var reset_button: Button = $"../EditorUI/PlaytestHUD/TopBarRow/LeftButtons/ResetButton"
@onready var rules_button: Button = $"../EditorUI/PlaytestHUD/TopBarRow/LeftButtons/RulesButton"
@onready var hint_button: Button = $"../EditorUI/PlaytestHUD/TopBarRow/RightButtons/HintButton"
@onready var undo_button: Button = $"../EditorUI/PlaytestHUD/TopBarRow/RightButtons/UndoButton"
@onready var redo_button: Button = $"../EditorUI/PlaytestHUD/TopBarRow/RightButtons/RedoButton"
@onready var test_mode_label: RichTextLabel = $"../EditorUI/PlaytestHUD/TopBarRow/TestModeLabelWrap/TestModeLabelInset/TestModeLabel"
@onready var timer_label: RichTextLabel = $"../EditorUI/CounterContainer/TimerSlot/TimerLabel"
@onready var moves_label: RichTextLabel = $"../EditorUI/CounterContainer/MoveSlot/MoveCounterLabel"
@onready var jokers_label: RichTextLabel = $"../EditorUI/CounterContainer/JokerSlot/JokerCounterLabel"
@onready var status_label: RichTextLabel = $"../EditorUI/PlaytestStatusLabel"
@onready var counter_container: HBoxContainer = $"../EditorUI/CounterContainer"
@onready var legacy_victory_panel: Panel = $"../EditorUI/PlaytestVictoryPanel"
@onready var how_to_play_container: CenterContainer = $"../HowToPlayLayer/CenterContainer"
@onready var rules_label: RichTextLabel = $"../HowToPlayLayer/CenterContainer/HowToPlayPanel/RulesLabel"
@onready var tutorial_back_button: Button = $"../HowToPlayLayer/CenterContainer/HowToPlayPanel/NavRow/BackButton"
@onready var htp_prev_button: Button = $"../HowToPlayLayer/CenterContainer/HowToPlayPanel/NavRow/PrevButton"
@onready var htp_next_button: Button = $"../HowToPlayLayer/CenterContainer/HowToPlayPanel/NavRow/NextButton"

var _test_label_breathe_tween: Tween
var _htp_page: int = 0

var _end_layer: CanvasLayer
var _victory_panel: Panel
var _defeat_panel: Panel
var _victory_title: Label
var _defeat_title: Label
var _victory_stats: Label
var _defeat_stats: Label
var _button_style_source: Button

func _ready() -> void:
	_button_style_source = exit_button if exit_button else reset_button
	_build_end_panels()
	if legacy_victory_panel:
		legacy_victory_panel.visible = false
	_connect_signals()
	if test_mode_label:
		test_mode_label.text = HudLayout.format_mode_label("TEST_MODE", true)
	_setup_how_to_play_font()
	_refresh_how_to_play_text()
	HudLayout.position_top_bar(playtest_hud_container)
	call_deferred("_apply_top_bar_buttons")

func _setup_how_to_play_font() -> void:
	if not rules_label:
		return
	# How-to-play body text always uses the default font (not the pixel UI font).
	rules_label.set_meta("_use_default_font", true)
	HudLayout.apply_locale_font_to_control(rules_label)

func _apply_top_bar_buttons() -> void:
	for button in [exit_button, reset_button, rules_button, hint_button, undo_button, redo_button]:
		HudLayout.apply_square_top_bar_button(button)
	HudLayout.apply_top_bar_mode_label(test_mode_label)
	HudLayout.apply_top_bar_row(top_bar_row)
	HudLayout.align_counter_label(timer_label, GameConstants.HUD_TIMER_Y_NUDGE)
	HudLayout.align_counter_label(jokers_label)
	HudLayout.align_counter_label(moves_label)
	_start_test_mode_label_breathe()

func _start_test_mode_label_breathe() -> void:
	if not test_mode_label:
		return
	test_mode_label.add_theme_color_override("default_color", Color(1.0, 0.3, 0.3, 1.0))
	if _test_label_breathe_tween:
		_test_label_breathe_tween.kill()
	test_mode_label.modulate = Color(1, 1, 1, 1)
	_test_label_breathe_tween = create_tween().set_loops()
	_test_label_breathe_tween.tween_property(test_mode_label, "modulate:a", 0.4, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_test_label_breathe_tween.tween_property(test_mode_label, "modulate:a", 1.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _connect_signals() -> void:
	if exit_button:
		exit_button.pressed.connect(func(): test_mode_exited.emit())
	if reset_button:
		reset_button.pressed.connect(func(): playtest_reset_requested.emit())
	if rules_button:
		rules_button.pressed.connect(func(): playtest_rules_requested.emit())
	if hint_button:
		hint_button.pressed.connect(func(): playtest_hint_requested.emit())
	if undo_button:
		undo_button.pressed.connect(func(): playtest_undo_requested.emit())
	if redo_button:
		redo_button.pressed.connect(func(): playtest_redo_requested.emit())
	if tutorial_back_button:
		tutorial_back_button.pressed.connect(func():
			if how_to_play_container:
				how_to_play_container.visible = false
			_set_playtest_buttons_disabled(false)
			resume_from_tutorial_requested.emit()
		)
	if htp_prev_button:
		htp_prev_button.pressed.connect(_on_htp_prev_pressed)
	if htp_next_button:
		htp_next_button.pressed.connect(_on_htp_next_pressed)

func _build_end_panels() -> void:
	_end_layer = CanvasLayer.new()
	_end_layer.name = "PlaytestEndLayer"
	_end_layer.layer = 5
	get_parent().add_child(_end_layer)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_layer.add_child(center)

	_victory_panel = _make_end_panel(center)
	_victory_title = _make_end_title(_victory_panel, Color(1.0, 0.84, 0.0, 1.0))
	_victory_stats = _make_end_stats(_victory_panel)
	_make_end_buttons(_victory_panel)
	_defeat_panel = _make_end_panel(center)
	_defeat_title = _make_end_title(_defeat_panel, Color(1.0, 0.35, 0.35, 1.0))
	_defeat_stats = _make_end_stats(_defeat_panel)
	_make_end_buttons(_defeat_panel)

	hide_end_overlays()

func _make_end_panel(parent: Control) -> Panel:
	var panel := Panel.new()
	panel.visible = false
	panel.custom_minimum_size = Vector2(680, 720)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.94)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _make_end_title(panel: Panel, color: Color) -> Label:
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 28.0
	label.offset_bottom = 140.0
	label.offset_left = 24.0
	label.offset_right = -24.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	label.add_theme_font_size_override("font_size", HudLayout.scaled_font_size(28))
	HudLayout.apply_locale_font_to_control(label)
	panel.add_child(label)
	return label

func _make_end_stats(panel: Panel) -> Label:
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 150.0
	label.offset_bottom = 380.0
	label.offset_left = 36.0
	label.offset_right = -36.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92, 1.0))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_font_size_override("font_size", HudLayout.scaled_font_size(22))
	label.set_meta("_use_default_font", true)
	HudLayout.apply_locale_font_to_control(label)
	panel.add_child(label)
	return label

func _make_end_buttons(panel: Panel) -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = -280.0
	row.offset_bottom = -36.0
	row.offset_left = 36.0
	row.offset_right = -36.0
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	row.add_child(col)

	var try_btn := _make_styled_button(tr("UI_TRY_AGAIN"))
	try_btn.pressed.connect(func():
		hide_end_overlays()
		playtest_reset_requested.emit()
	)
	col.add_child(try_btn)

	var return_btn := _make_styled_button(tr("RETURN"))
	return_btn.pressed.connect(func():
		hide_end_overlays()
		test_mode_exited.emit()
	)
	col.add_child(return_btn)

func _make_styled_button(caption: String) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(460, 100)
	btn.text = caption
	if _button_style_source:
		for style_name in ["normal", "pressed", "hover", "disabled"]:
			var style := _button_style_source.get_theme_stylebox(style_name)
			if style:
				btn.add_theme_stylebox_override(style_name, style)
	btn.add_theme_color_override("font_outline_color", Color.BLACK)
	btn.add_theme_constant_override("outline_size", 8)
	HudLayout.fit_text_button(btn, 24, 14)
	return btn

func _format_end_stats(stats: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append(tr("STAT_TIME_LEFT") % str(stats.get("time_text", "--")))
	if bool(stats.get("show_green", false)):
		lines.append(tr("STAT_GREEN_TILES") % [
			int(stats.get("green_current", 0)),
			int(stats.get("green_required", 0)),
		])
	if bool(stats.get("show_moves", false)):
		lines.append(tr("STAT_SHIFTER_MOVES") % [
			int(stats.get("moves", 0)),
			int(stats.get("moves_required", 0)),
		])
	return "\n\n".join(lines)

func _set_playtest_buttons_disabled(disabled: bool) -> void:
	if reset_button:
		reset_button.disabled = disabled
		HudLayout.refresh_button_icon_modulate(reset_button)
	if rules_button:
		rules_button.disabled = disabled
		HudLayout.refresh_button_icon_modulate(rules_button)
	if hint_button:
		if disabled:
			HintController.update_button(hint_button, false)
	if undo_button:
		undo_button.disabled = disabled
		HudLayout.refresh_button_icon_modulate(undo_button)
	if redo_button:
		redo_button.disabled = disabled
		HudLayout.refresh_button_icon_modulate(redo_button)
	if exit_button:
		exit_button.disabled = disabled
		HudLayout.refresh_button_icon_modulate(exit_button)

func update_playtest_status(msg: String, text_color: Color) -> void:
	if not status_label:
		return
	status_label.modulate = text_color
	HudLayout.apply_status_font(status_label, GameConstants.HUD_STATUS_FONT_SIZE)
	status_label.text = HudLayout.format_centered_status(msg, false)

func toggle_playtest_visibility(is_playtesting: bool) -> void:
	if playtest_hud_container:
		playtest_hud_container.visible = is_playtesting
	if counter_container:
		counter_container.visible = is_playtesting
	if status_label:
		status_label.visible = is_playtesting
	if not is_playtesting:
		hide_end_overlays()
	if is_playtesting:
		_start_test_mode_label_breathe()
	elif _test_label_breathe_tween:
		_test_label_breathe_tween.kill()
		_test_label_breathe_tween = null
		if test_mode_label:
			test_mode_label.modulate = Color(1, 1, 1, 1)

func update_dynamic_playtest_layout(board_y: float, board_height: float) -> void:
	HudLayout.position_counter_row(counter_container)
	if status_label:
		HudLayout.position_status_below_board(status_label, board_y, board_height)

func update_playtest_undo_redo_buttons(can_undo: bool, can_redo: bool) -> void:
	if undo_button:
		undo_button.disabled = not can_undo
		HudLayout.refresh_button_icon_modulate(undo_button)
	if redo_button:
		redo_button.disabled = not can_redo
		HudLayout.refresh_button_icon_modulate(redo_button)

func show_victory_overlay(stats: Dictionary) -> void:
	_set_playtest_buttons_disabled(true)
	if _victory_title:
		_victory_title.text = tr("ED_VICTORY_SOLVABLE")
		HudLayout.apply_locale_font_to_control(_victory_title)
	if _victory_stats:
		_victory_stats.text = _format_end_stats(stats)
		HudLayout.apply_locale_font_to_control(_victory_stats)
	if _defeat_panel:
		_defeat_panel.visible = false
	if _victory_panel:
		_victory_panel.visible = true

func show_defeat_overlay(stats: Dictionary) -> void:
	_set_playtest_buttons_disabled(true)
	if _defeat_title:
		_defeat_title.text = tr("ED_DEFEAT_TIME")
		HudLayout.apply_locale_font_to_control(_defeat_title)
	if _defeat_stats:
		_defeat_stats.text = _format_end_stats(stats)
		HudLayout.apply_locale_font_to_control(_defeat_stats)
	if _victory_panel:
		_victory_panel.visible = false
	if _defeat_panel:
		_defeat_panel.visible = true

func hide_end_overlays() -> void:
	if _victory_panel:
		_victory_panel.visible = false
	if _defeat_panel:
		_defeat_panel.visible = false
	if legacy_victory_panel:
		legacy_victory_panel.visible = false
	_set_playtest_buttons_disabled(false)

## Kept for older call sites.
func hide_victory_overlay() -> void:
	hide_end_overlays()

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
	_set_playtest_buttons_disabled(true)

func set_playtest_chrome_visible(should_show: bool) -> void:
	if playtest_hud_container:
		playtest_hud_container.visible = should_show
	if counter_container:
		counter_container.visible = should_show
	if status_label:
		status_label.visible = should_show
	if not should_show:
		_set_playtest_buttons_disabled(true)
	else:
		_set_playtest_buttons_disabled(false)

func update_playtest_hud(time_remaining: int, moves: int, editor_time_limit: int, required_moves: int = -1) -> void:
	if timer_label:
		HudLayout.prepare_counter_label(timer_label)
		if editor_time_limit == 0:
			timer_label.text = HudLayout.format_time_counter("∞", tr("TIME"))
		else:
			var minutes = max(0, int(time_remaining / 60.0))
			var seconds = max(0, time_remaining % 60)
			timer_label.text = HudLayout.format_time_counter(
				"%02d:%02d" % [minutes, seconds], tr("TIME")
			)
	if moves_label:
		HudLayout.prepare_counter_label(moves_label)
		var target := required_moves if required_moves >= 0 else moves
		moves_label.text = HudLayout.format_icon_ratio_counter(
			GameConstants.TILE_SHIFTER, moves, target, GameConstants.HUD_COUNTER_SHIFTER, tr("MOVES")
		)

func update_playtest_joker_counter(current: int, required: int) -> void:
	if not jokers_label:
		return
	HudLayout.prepare_counter_label(jokers_label)
	jokers_label.text = HudLayout.format_icon_ratio_counter(
		GameConstants.TILE_GREEN, current, required, GameConstants.HUD_COUNTER_GREEN, tr("COUNTER_GREEN")
	)

func set_playtest_joker_counter_visibility(visible_state: bool) -> void:
	if jokers_label:
		jokers_label.visible = visible_state

func set_playtest_move_counter_visibility(visible_state: bool) -> void:
	if moves_label:
		moves_label.visible = visible_state

func set_playtest_hint_button_disabled(is_disabled: bool) -> void:
	HintController.update_button(hint_button, not is_disabled)
