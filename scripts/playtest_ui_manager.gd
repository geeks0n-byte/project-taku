class_name PlaytestUIManager
extends Node2D

signal test_mode_exited            ## Player pressed Exit; editor should end playtest mode.
signal playtest_reset_requested    ## Player pressed Reset; board should be restored to start.
signal playtest_rules_requested    ## Player pressed Rules; How-To-Play overlay should open.
signal playtest_hint_requested     ## Player pressed Hint; hint logic should run.
signal playtest_undo_requested     ## Player pressed Undo.
signal playtest_redo_requested     ## Player pressed Redo.
signal resume_from_tutorial_requested  ## Player closed the How-To-Play overlay; gameplay resumes.

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
@onready var tutorial_back_button: Button = $"../HowToPlayLayer/CenterContainer/BackButton"
@onready var htp_prev_button: Button = $"../HowToPlayLayer/CenterContainer/NavRow/PrevSlot/PrevButton"
@onready var htp_next_button: Button = $"../HowToPlayLayer/CenterContainer/NavRow/NextSlot/NextButton"
@onready var _end_layer: CanvasLayer = $"../PlaytestEndLayer"
@onready var _end_dimmer: ColorRect = $"../PlaytestEndLayer/Dimmer"
@onready var _center: CenterContainer = $"../PlaytestEndLayer/CenterContainer"
@onready var _victory_panel: Panel = $"../PlaytestEndLayer/CenterContainer/VictoryPanel"
@onready var _victory_title: Label = $"../PlaytestEndLayer/CenterContainer/VictoryPanel/VictoryTitle"
@onready var _victory_results_host: Control = $"../PlaytestEndLayer/CenterContainer/VictoryPanel/VictoryResultsHost"
@onready var _victory_preview: TextureRect = $"../PlaytestEndLayer/CenterContainer/VictoryPanel/VictoryBoardPreview"
@onready var _victory_buttons: VBoxContainer = $"../PlaytestEndLayer/CenterContainer/VictoryPanel/VictoryButtons"
@onready var _try_again_button: Button = $"../PlaytestEndLayer/CenterContainer/VictoryPanel/VictoryButtons/TryAgainButton"
@onready var _return_button: Button = $"../PlaytestEndLayer/CenterContainer/VictoryPanel/VictoryButtons/ReturnButton"

var _test_label_breathe_tween: Tween       # Looping alpha tween on the "TEST MODE" label.
var _htp_page: int = 0                     # Current zero-based How-To-Play page index.
var _htp_header: Label                     # Page header label injected by HudLayout.
var _hint_remaining: int = GameConstants.HINT_LIMIT_UNLIMITED  # -1 = unlimited; 0 = ad required.
var _hint_forced_disabled: bool = false    # True while the board is solved or overlay is open.
var _button_style_source: Button           # Reference button whose StyleBoxes are copied to end-screen buttons.

# Hold-to-repeat undo/redo (same timing as main-game HUD).
const _HOLD_INITIAL_DELAY := 0.4
const _HOLD_REPEAT_START := 0.3
const _HOLD_REPEAT_MIN := 0.05
const _HOLD_REPEAT_ACCEL := 0.82
var _hold_undo_active: bool = false
var _hold_redo_active: bool = false
var _hold_repeat_elapsed: float = 0.0
var _hold_repeat_interval: float = 0.0

func _ready() -> void:
	_button_style_source = exit_button if exit_button else reset_button
	_setup_end_layer()
	if legacy_victory_panel:
		legacy_victory_panel.visible = false
	_connect_signals()
	if test_mode_label:
		test_mode_label.text = HudLayout.format_mode_label("TEST_MODE", true)
	_layout_how_to_play()
	_setup_how_to_play_font()
	_refresh_how_to_play_text()
	call_deferred("_apply_top_bar_buttons")
	if SaveManager and not SaveManager.language_changed.is_connected(_on_language_changed):
		SaveManager.language_changed.connect(_on_language_changed)

func _on_language_changed() -> void:
	_apply_top_bar_buttons()
	HudLayout.clear_how_to_play_nav_lock(how_to_play_container)
	_refresh_how_to_play_text()
	_setup_how_to_play_font()
	# Editor playtest HUD stays Press Start; How-To-Play keeps locale fonts.
	var editor_root := get_node_or_null("../EditorUI")
	if editor_root:
		HudLayout.apply_locale_fonts_to_tree(editor_root)
	var end_root := get_node_or_null("../PlaytestEndLayer")
	if end_root:
		HudLayout.apply_locale_fonts_to_tree(end_root)

func _layout_how_to_play() -> void:
	for btn in [htp_prev_button, htp_next_button]:
		HudLayout.apply_nav_button(btn)
	if tutorial_back_button:
		HudLayout.style_top_bar_close_button(tutorial_back_button)
	_htp_header = HudLayout.ensure_how_to_play_page_header(how_to_play_container)

func _setup_how_to_play_font() -> void:
	if not rules_label:
		return
	rules_label.set_meta("_use_default_font", true)
	HudLayout.apply_locale_font_to_control(rules_label)

func _apply_top_bar_buttons() -> void:
	HudLayout.apply_top_bar_button_cluster(top_bar_row.get_node_or_null("LeftButtons") as HBoxContainer)
	HudLayout.apply_top_bar_button_cluster(top_bar_row.get_node_or_null("RightButtons") as HBoxContainer)
	for button in [exit_button, reset_button, rules_button, hint_button, undo_button, redo_button]:
		HudLayout.apply_square_top_bar_button(button)
	HudLayout.apply_top_bar_mode_label(test_mode_label)
	HudLayout.align_counter_label(timer_label, GameConstants.HUD_TIMER_Y_NUDGE)
	HudLayout.align_counter_label(jokers_label)
	HudLayout.align_counter_label(moves_label)
	if timer_label:
		HudLayout.prepare_timer_label(timer_label)
	set_playtest_joker_counter_visibility(false)
	set_playtest_move_counter_visibility(false)
	HudLayout.align_counter_row(counter_container)
	if playtest_hud_container:
		playtest_hud_container.offset_bottom = GameConstants.HUD_TOP_BAR_HEIGHT
	if top_bar_row:
		top_bar_row.custom_minimum_size.y = float(GameConstants.HUD_BUTTON_HEIGHT)
	if counter_container:
		counter_container.offset_top = GameConstants.HUD_COUNTER_ROW_TOP
		counter_container.offset_bottom = GameConstants.HUD_COUNTER_ROW_TOP + GameConstants.HUD_COUNTER_ROW_HEIGHT
	_start_test_mode_label_breathe()

## Starts an infinite alpha pulse on the "TEST MODE" label to remind developers
## they are in playtest mode. Kills any existing tween before starting a new one
## so calling this multiple times is safe.
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
		undo_button.button_down.connect(_on_undo_button_down)
		undo_button.button_up.connect(_on_undo_button_up)
	if redo_button:
		redo_button.pressed.connect(func(): playtest_redo_requested.emit())
		redo_button.button_down.connect(_on_redo_button_down)
		redo_button.button_up.connect(_on_redo_button_up)
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
	if _try_again_button and not _try_again_button.pressed.is_connected(_on_try_again_pressed):
		_try_again_button.pressed.connect(_on_try_again_pressed)
	if _return_button and not _return_button.pressed.is_connected(_on_return_pressed):
		_return_button.pressed.connect(_on_return_pressed)

func _on_undo_button_down() -> void:
	_hold_undo_active = true
	_hold_redo_active = false
	_hold_repeat_elapsed = 0.0
	_hold_repeat_interval = _HOLD_REPEAT_START
	set_process(true)
	if UiSfx and undo_button:
		UiSfx.suppress_next_pressed_click(undo_button)
		UiSfx.play_click()


func _on_undo_button_up() -> void:
	_hold_undo_active = false
	if UiSfx and undo_button:
		UiSfx.clear_pressed_click_suppress(undo_button)
	if not _hold_redo_active:
		set_process(false)


func _on_redo_button_down() -> void:
	_hold_redo_active = true
	_hold_undo_active = false
	_hold_repeat_elapsed = 0.0
	_hold_repeat_interval = _HOLD_REPEAT_START
	set_process(true)
	if UiSfx and redo_button:
		UiSfx.suppress_next_pressed_click(redo_button)
		UiSfx.play_click()


func _on_redo_button_up() -> void:
	_hold_redo_active = false
	if UiSfx and redo_button:
		UiSfx.clear_pressed_click_suppress(redo_button)
	if not _hold_undo_active:
		set_process(false)


func _process(delta: float) -> void:
	if not _hold_undo_active and not _hold_redo_active:
		set_process(false)
		return
	_hold_repeat_elapsed += delta
	if _hold_repeat_elapsed < _HOLD_INITIAL_DELAY:
		return
	var time_since_start := _hold_repeat_elapsed - _HOLD_INITIAL_DELAY
	if time_since_start < _hold_repeat_interval:
		return
	_hold_repeat_elapsed = _HOLD_INITIAL_DELAY
	_hold_repeat_interval = maxf(_hold_repeat_interval * _HOLD_REPEAT_ACCEL, _HOLD_REPEAT_MIN)
	if _hold_undo_active:
		if undo_button and undo_button.disabled:
			_on_undo_button_up()
			return
		if UiSfx:
			UiSfx.play_click()
		playtest_undo_requested.emit()
	elif _hold_redo_active:
		if redo_button and redo_button.disabled:
			_on_redo_button_up()
			return
		if UiSfx:
			UiSfx.play_click()
		playtest_redo_requested.emit()


func _on_try_again_pressed() -> void:
	playtest_reset_requested.emit()

func _on_return_pressed() -> void:
	test_mode_exited.emit()

func _setup_end_layer() -> void:
	if _center:
		_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _victory_panel:
		_victory_panel.add_theme_stylebox_override("panel", HudLayout.make_dialog_panel_style())
	_style_end_buttons()
	hide_end_overlays()

func _style_end_buttons() -> void:
	for btn in [_try_again_button, _return_button]:
		if btn == null:
			continue
		if _button_style_source:
			for style_name in ["normal", "pressed", "hover", "disabled"]:
				var style := _button_style_source.get_theme_stylebox(style_name)
				if style:
					btn.add_theme_stylebox_override(style_name, style)
		HudLayout.apply_safe_outline(btn, 8)
		HudLayout.apply_panel_button(btn)

## Calculates and applies offsets for all children of the victory panel based on how
## many star-goal rows the result contains and whether a board preview is shown.
## Heights follow title/results/preview/buttons so long copy keeps top/bottom margin.
func _layout_victory_panel(star_result: Dictionary) -> void:
	if not _victory_panel or not _victory_results_host:
		return
	var goal_count := int(star_result.get("total_count", 0))
	var panel_w := 840.0
	var title_top := 28.0
	var title_side := 24.0
	var title_h := 82.0
	if _victory_title:
		_victory_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_h = maxf(
			82.0,
			HudDialogs.measure_label_height(_victory_title, panel_w - title_side * 2.0)
		)
		_victory_title.offset_left = title_side
		_victory_title.offset_right = -title_side
		_victory_title.offset_top = title_top
		_victory_title.offset_bottom = title_top + title_h
	var title_bottom := title_top + title_h
	var results_h := float(maxi(1, goal_count)) * (LevelStars.ROW_HEIGHT + 14.0) + 24.0
	_victory_results_host.offset_top = title_bottom + 8.0
	_victory_results_host.offset_bottom = title_bottom + 8.0 + results_h
	var cursor := title_bottom + 8.0 + results_h
	var preview_h := 0.0
	var frame: PanelContainer = null
	if _victory_preview:
		frame = LevelPreview.ensure_preview_frame(_victory_preview)
	var show_preview := (
		_victory_preview
		and _victory_preview.visible
		and _victory_preview.texture != null
	)
	if show_preview:
		var inner := 320.0
		preview_h = LevelPreview.frame_outer_size(inner)
		cursor += 24.0
		var half := preview_h * 0.5
		var target: Control = frame
		if target == null:
			target = _victory_preview
		target.offset_left = -half
		target.offset_right = half
		target.offset_top = cursor
		target.offset_bottom = cursor + preview_h
		cursor += preview_h
	elif frame:
		frame.visible = false
	var buttons_top := cursor + 28.0
	var buttons_h := 260.0
	if _victory_buttons:
		buttons_h = maxf(
			260.0,
			HudDialogs.measure_control_height(_victory_buttons, 480.0)
		)
		_victory_buttons.offset_top = buttons_top
		_victory_buttons.offset_bottom = buttons_top + buttons_h
	var height := buttons_top + buttons_h + 40.0 + HudDialogs.DIALOG_EXTRA_PAD_V
	var soft_min := 560.0 if preview_h > 0.0 else 520.0
	_victory_panel.custom_minimum_size = Vector2(panel_w, maxf(soft_min, height))

## Disables (or re-enables) all playtest action buttons.
## Reset is always kept disabled regardless of `disabled` — it is only enabled by
## external code once the board has been interacted with.
func _set_playtest_buttons_disabled(disabled: bool) -> void:
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

## Updates the in-playtest status message (e.g. "Board solved!" or validation errors).
func update_playtest_status(msg: String, text_color: Color) -> void:
	if not status_label:
		return
	status_label.modulate = text_color
	HudLayout.apply_status_font(status_label, GameConstants.HUD_STATUS_FONT_SIZE)
	status_label.text = HudLayout.format_centered_status(msg, false)

## Shows or hides the entire playtest chrome (HUD, counters, status label).
## Also manages the breathe tween so it only runs while playtesting is active.
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

## Re-positions the counter row and status label to account for the current board position.
## Called whenever the board is rebuilt or repositioned in the editor viewport.
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
	if _end_layer:
		_end_layer.visible = true
	if _end_dimmer:
		_end_dimmer.color = Color(0, 0, 0, 0)
		_end_dimmer.visible = true
		_end_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	if _victory_panel:
		_victory_panel.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if _victory_title:
		_victory_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_victory_title.text = HudLayout.english("ED_VICTORY_SOLVABLE")
		HudLayout.apply_end_screen_header_style(_victory_title, 48)
	var star_result: Dictionary = stats.get("star_result", {})
	if _victory_results_host:
		_victory_results_host.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		HudFonts.begin_force_pixel_font()
		LevelStars.populate_results(_victory_results_host, star_result)
		HudFonts.end_force_pixel_font()
	_ensure_victory_preview()
	var preview_tex = stats.get("solved_preview", null)
	if _victory_preview:
		var frame := LevelPreview.ensure_preview_frame(_victory_preview)
		_victory_preview.texture = preview_tex if preview_tex is Texture2D else null
		var should_show := _victory_preview.texture != null
		_victory_preview.visible = should_show
		if frame:
			frame.visible = should_show
	_layout_victory_panel(star_result)
	if _victory_panel:
		_victory_panel.visible = true
	if _try_again_button:
		_try_again_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_try_again_button.text = HudLayout.english("UI_TRY_AGAIN")
		HudLayout.apply_panel_button(_try_again_button)
	if _return_button:
		_return_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_return_button.text = HudLayout.english("RETURN")
		HudLayout.apply_panel_button(_return_button)

func _ensure_victory_preview() -> void:
	if _victory_preview and is_instance_valid(_victory_preview):
		return

func hide_end_overlays() -> void:
	if _end_layer:
		_end_layer.visible = false
	if _end_dimmer:
		_end_dimmer.visible = false
		_end_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _victory_panel:
		_victory_panel.visible = false
	if legacy_victory_panel:
		legacy_victory_panel.visible = false
	_set_playtest_buttons_disabled(false)

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

func _layout_how_to_play_stack() -> void:
	HudLayout.layout_how_to_play_stack(
		how_to_play_container,
		how_to_play_panel,
		rules_label,
		how_to_play_nav,
		_htp_page == 0
	)

func show_how_to_play() -> void:
	_htp_page = 0
	HudLayout.clear_how_to_play_nav_lock(how_to_play_container)
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

## Updates the timer and move-counter labels each game tick.
## `required_moves` overrides the displayed target; pass -1 to show the actual move count as target.
func update_playtest_hud(elapsed_seconds: int, moves: int, _editor_time_limit: int, required_moves: int = -1) -> void:
	if timer_label:
		HudLayout.set_timer_raster_text(timer_label, LevelStars.format_clock(elapsed_seconds))
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

## Shows/hides the joker counter slot (parent preferred so spacing collapses cleanly).
func set_playtest_joker_counter_visibility(visible_state: bool) -> void:
	var slot := jokers_label.get_parent() as Control if jokers_label else null
	if slot:
		slot.visible = visible_state
	elif jokers_label:
		jokers_label.visible = visible_state
	HudLayout.align_counter_row(counter_container)

## Shows/hides the move counter slot (parent preferred so spacing collapses cleanly).
func set_playtest_move_counter_visibility(visible_state: bool) -> void:
	var slot := moves_label.get_parent() as Control if moves_label else null
	if slot:
		slot.visible = visible_state
	elif moves_label:
		moves_label.visible = visible_state
	HudLayout.align_counter_row(counter_container)

## Updates the cached hint count and refreshes the button badge.
func set_playtest_hint_remaining(remaining: int) -> void:
	_hint_remaining = remaining
	_refresh_playtest_hint_visual()

## Forces the hint button disabled regardless of remaining count (e.g. during victory overlay).
func set_playtest_hint_button_disabled(is_disabled: bool) -> void:
	_hint_forced_disabled = is_disabled
	_refresh_playtest_hint_visual()

## Applies the current enabled/remaining state to the hint button via HintController.
func _refresh_playtest_hint_visual() -> void:
	HintController.update_button(hint_button, not _hint_forced_disabled, _hint_remaining)
