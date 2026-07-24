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
@onready var how_to_play_container: Control = $"../HowToPlayLayer/CenterContainer"
@onready var how_to_play_panel: Control = $"../HowToPlayLayer/CenterContainer/HowToPlayPanel"
@onready var how_to_play_nav: HBoxContainer = $"../HowToPlayLayer/CenterContainer/NavRow"
@onready var rules_label: RichTextLabel = $"../HowToPlayLayer/CenterContainer/HowToPlayPanel/RulesLabel"
@onready var tutorial_back_button: Button = $"../HowToPlayLayer/CenterContainer/NavRow/BackButton"
@onready var htp_prev_button: Button = $"../HowToPlayLayer/CenterContainer/NavRow/PrevSlot/PrevButton"
@onready var htp_next_button: Button = $"../HowToPlayLayer/CenterContainer/NavRow/NextSlot/NextButton"

var _test_label_breathe_tween: Tween
var _htp_page: int = 0
var _htp_header: Label
var _hint_remaining: int = GameConstants.HINT_LIMIT_UNLIMITED
var _hint_forced_disabled: bool = false

var _end_layer: CanvasLayer
var _end_dimmer: ColorRect
var _victory_panel: Panel
var _victory_title: Label
var _victory_results_host: Control
var _victory_preview: TextureRect
var _victory_buttons: Control
var _button_style_source: Button
var _center: CenterContainer

func _ready() -> void:
	_button_style_source = exit_button if exit_button else reset_button
	# Parent is still finishing _ready children; defer panel construction.
	call_deferred("_build_end_panels")
	if legacy_victory_panel:
		legacy_victory_panel.visible = false
	_connect_signals()
	if test_mode_label:
		test_mode_label.text = HudLayout.format_mode_label("TEST_MODE", true)
	_layout_how_to_play()
	_setup_how_to_play_font()
	_refresh_how_to_play_text()
	HudLayout.position_top_bar(playtest_hud_container)
	call_deferred("_apply_top_bar_buttons")

func _layout_how_to_play() -> void:
	HudLayout.layout_how_to_play(how_to_play_container, how_to_play_panel, how_to_play_nav)
	HudLayout.ensure_how_to_play_nav_slots(how_to_play_nav, htp_prev_button, htp_next_button)
	_htp_header = HudLayout.ensure_how_to_play_page_header(how_to_play_container)

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
	set_playtest_joker_counter_visibility(false)
	set_playtest_move_counter_visibility(false)
	HudLayout.align_counter_row(counter_container)
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
	if _end_layer and is_instance_valid(_end_layer):
		return
	_end_layer = CanvasLayer.new()
	_end_layer.name = "PlaytestEndLayer"
	_end_layer.layer = 5
	get_parent().add_child(_end_layer)

	_end_dimmer = ColorRect.new()
	_end_dimmer.name = "Dimmer"
	_end_dimmer.color = Color(0, 0, 0, 0)
	_end_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_end_dimmer.visible = false
	_end_layer.add_child(_end_dimmer)

	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_layer.add_child(_center)

	_victory_panel = _make_end_panel(_center)
	_victory_title = _make_end_title(_victory_panel, Color(1.0, 0.84, 0.0, 1.0))
	_victory_results_host = _make_end_results_host(_victory_panel)
	_victory_buttons = _make_end_buttons(_victory_panel)

	hide_end_overlays()

func _make_end_panel(parent: Control) -> Panel:
	var panel := Panel.new()
	panel.visible = false
	panel.custom_minimum_size = Vector2(840, 800)
	panel.add_theme_stylebox_override("panel", HudLayout.make_dialog_panel_style())
	parent.add_child(panel)
	return panel

func _make_end_title(panel: Panel, _color: Color) -> Label:
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 24.0
	label.offset_bottom = 200.0
	label.offset_left = 28.0
	label.offset_right = -28.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_contents = false
	label.clip_text = false
	HudLayout.apply_end_screen_header_style(label, 48)
	panel.add_child(label)
	return label

func _make_end_results_host(panel: Panel) -> Control:
	var host := Control.new()
	host.name = "VictoryResultsHost"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_anchors_preset(Control.PRESET_TOP_WIDE)
	host.offset_left = 40.0
	host.offset_right = -40.0
	host.offset_top = 188.0
	host.offset_bottom = 430.0
	panel.add_child(host)
	return host

func _make_end_buttons(panel: Panel) -> Control:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER_TOP)
	col.offset_left = -260.0
	col.offset_right = 260.0
	col.offset_top = 450.0
	col.offset_bottom = 720.0
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 20)
	panel.add_child(col)

	var try_btn := _make_styled_button(tr("UI_TRY_AGAIN"))
	try_btn.pressed.connect(func():
		playtest_reset_requested.emit()
	)
	col.add_child(try_btn)

	var return_btn := _make_styled_button(tr("RETURN"))
	return_btn.pressed.connect(func():
		test_mode_exited.emit()
	)
	col.add_child(return_btn)
	return col

func _make_styled_button(caption: String) -> Button:
	var btn := Button.new()
	btn.text = caption
	if _button_style_source:
		for style_name in ["normal", "pressed", "hover", "disabled"]:
			var style := _button_style_source.get_theme_stylebox(style_name)
			if style:
				btn.add_theme_stylebox_override(style_name, style)
	btn.add_theme_color_override("font_outline_color", Color.BLACK)
	btn.add_theme_constant_override("outline_size", 8)
	HudLayout.apply_panel_button(btn)
	return btn

func _layout_victory_panel(star_result: Dictionary) -> void:
	if not _victory_panel or not _victory_results_host:
		return
	var goal_count := int(star_result.get("total_count", 0))
	var title_bottom := 200.0
	var results_h := 90.0 + float(maxi(1, goal_count)) * (LevelStars.ROW_HEIGHT + 14.0)
	_victory_results_host.offset_top = title_bottom + 8.0
	_victory_results_host.offset_bottom = title_bottom + 8.0 + results_h
	var cursor := title_bottom + 8.0 + results_h
	var preview_h := 0.0
	if _victory_preview and _victory_preview.visible and _victory_preview.texture != null:
		preview_h = 320.0
		cursor += 24.0
		_victory_preview.offset_left = -160.0
		_victory_preview.offset_right = 160.0
		_victory_preview.offset_top = cursor
		_victory_preview.offset_bottom = cursor + preview_h
		cursor += preview_h
	var buttons_top := cursor + 28.0
	if _victory_buttons:
		_victory_buttons.offset_top = buttons_top
		_victory_buttons.offset_bottom = buttons_top + 260.0
	var min_h := 980.0 if preview_h > 0.0 else 900.0
	_victory_panel.custom_minimum_size = Vector2(840, maxf(min_h, buttons_top + 300.0))

func _set_playtest_buttons_disabled(disabled: bool) -> void:
	# Top-bar reset is unavailable in TEST MODE; Try Again on victory still works.
	if reset_button:
		reset_button.disabled = true
		HudLayout.refresh_button_icon_modulate(reset_button)
	if rules_button:
		rules_button.disabled = disabled
		HudLayout.refresh_button_icon_modulate(rules_button)
	if hint_button:
		if disabled:
			HintController.update_button(hint_button, false, _hint_remaining)
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
		if reset_button:
			reset_button.disabled = true
			HudLayout.refresh_button_icon_modulate(reset_button)
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
	set_playtest_chrome_visible(false)
	if _end_dimmer:
		_end_dimmer.color = Color(0, 0, 0, 0)
		_end_dimmer.visible = true
		_end_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	if _victory_title:
		_victory_title.text = tr("ED_VICTORY_SOLVABLE")
		HudLayout.apply_end_screen_header_style(_victory_title, 48)
	var star_result: Dictionary = stats.get("star_result", {})
	if _victory_results_host:
		LevelStars.populate_results(_victory_results_host, star_result)
	_ensure_victory_preview()
	var preview_tex = stats.get("solved_preview", null)
	if _victory_preview:
		_victory_preview.texture = preview_tex if preview_tex is Texture2D else null
		_victory_preview.visible = _victory_preview.texture != null
	_layout_victory_panel(star_result)
	if _victory_panel:
		_victory_panel.visible = true

func _ensure_victory_preview() -> void:
	if _victory_preview and is_instance_valid(_victory_preview):
		return
	if _victory_panel == null:
		return
	_victory_preview = TextureRect.new()
	_victory_preview.name = "VictoryBoardPreview"
	_victory_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_victory_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_victory_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_victory_preview.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_victory_preview.visible = false
	_victory_panel.add_child(_victory_preview)
	if _victory_buttons:
		_victory_panel.move_child(_victory_buttons, -1)

func hide_end_overlays() -> void:
	if _end_dimmer:
		_end_dimmer.visible = false
		_end_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _victory_panel:
		_victory_panel.visible = false
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

func update_playtest_hud(elapsed_seconds: int, moves: int, _editor_time_limit: int, required_moves: int = -1) -> void:
	if timer_label:
		HudLayout.prepare_counter_label(timer_label)
		timer_label.text = HudLayout.format_time_counter(
			LevelStars.format_clock(elapsed_seconds)
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
	var slot := jokers_label.get_parent() as Control if jokers_label else null
	if slot:
		slot.visible = visible_state
	elif jokers_label:
		jokers_label.visible = visible_state
	HudLayout.align_counter_row(counter_container)

func set_playtest_move_counter_visibility(visible_state: bool) -> void:
	var slot := moves_label.get_parent() as Control if moves_label else null
	if slot:
		slot.visible = visible_state
	elif moves_label:
		moves_label.visible = visible_state
	HudLayout.align_counter_row(counter_container)

func set_playtest_hint_remaining(remaining: int) -> void:
	_hint_remaining = remaining
	_refresh_playtest_hint_visual()

func set_playtest_hint_button_disabled(is_disabled: bool) -> void:
	_hint_forced_disabled = is_disabled
	_refresh_playtest_hint_visual()

func _refresh_playtest_hint_visual() -> void:
	HintController.update_button(hint_button, not _hint_forced_disabled, _hint_remaining)
