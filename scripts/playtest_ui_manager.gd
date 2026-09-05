class_name PlaytestUIManager
extends Node2D
## Playtest HUD, how-to-play overlay, and victory dialog for the level editor.
## Mirrors UIManager chrome so Giga can edit layout in level_editor.tscn.

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
@onready var how_to_play_container: Control = $"../HowToPlayLayer/CenterContainer"
@onready var how_to_play_panel: Control = $"../HowToPlayLayer/CenterContainer/HowToPlayPanel"
@onready var _htp_header: Label = $"../HowToPlayLayer/CenterContainer/HowToPlayPageHeader"
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
var _hint_remaining: int = GameConstants.HINT_LIMIT_UNLIMITED  # -1 = unlimited; 0 = ad required.
var _hint_forced_disabled: bool = false    # True while the board is solved or overlay is open.
var _button_style_source: Button           # Reference button whose StyleBoxes are copied to end-screen buttons.
const _ICON_RESET: Texture2D = preload("res://resources/icons/icon_reset.svg")

var _htp := UiHowToPlayPanel.new()

# Hold-to-repeat undo/redo (same timing as main-game HUD).
var _hold_repeat := HoldRepeat.new()

# Wires playtest HUD, HTP overlay, and end-layer; listens for locale / resize.
func _ready() -> void:
	_button_style_source = exit_button if exit_button else reset_button
	_setup_end_layer()
	_connect_signals()
	if test_mode_label:
		test_mode_label.text = HudLayout.format_mode_label("UI_TEST_MODE", true)
	_htp.bind(
		how_to_play_container,
		how_to_play_panel,
		_htp_header,
		how_to_play_nav,
		htp_prev_button,
		htp_next_button,
		rules_label,
		tutorial_back_button,
		false
	)
	_htp.setup()
	_htp.bind_nav_signals()
	call_deferred("_apply_top_bar_buttons")
	if SaveManager and not SaveManager.language_changed.is_connected(_on_language_changed):
		SaveManager.language_changed.connect(_on_language_changed)
	if not get_viewport().size_changed.is_connected(_on_safe_area_viewport_resized):
		get_viewport().size_changed.connect(_on_safe_area_viewport_resized)

# Viewport resized: recompute HUD offsets (notch / nav-bar / landscape).
func _on_safe_area_viewport_resized() -> void:
	_apply_top_bar_buttons()

# Rebuilds playtest + HTP fonts after SaveManager.language_changed.
func _on_language_changed() -> void:
	_apply_top_bar_buttons()
	_htp.on_locale_changed()
	# Editor playtest HUD stays Press Start; How-To-Play keeps locale fonts.
	var editor_root := get_node_or_null("../EditorUI")
	if editor_root:
		HudLayout.apply_locale_fonts_to_tree(editor_root)
	var end_root := get_node_or_null("../PlaytestEndLayer")
	if end_root:
		HudLayout.apply_locale_fonts_to_tree(end_root)
	# Re-apply victory button fonts after the tree walk (Latin → Press Start caption).
	if _victory_panel and _victory_panel.visible:
		_style_end_buttons()

# Sizes playtest top-bar clusters, counters, and safe-area padding.
func _apply_top_bar_buttons() -> void:
	HudLayout.apply_top_bar_button_cluster(top_bar_row.get_node_or_null("LeftButtons") as HBoxContainer)
	HudLayout.apply_top_bar_button_cluster(top_bar_row.get_node_or_null("RightButtons") as HBoxContainer)
	for button in [exit_button, reset_button, rules_button, hint_button, undo_button, redo_button]:
		HudLayout.apply_square_top_bar_button(button)
	_apply_reset_button_icon()
	HudLayout.apply_top_bar_mode_label(test_mode_label)
	HudLayout.align_counter_label(timer_label, GameConstants.HUD_TIMER_Y_NUDGE)
	HudLayout.align_counter_label(jokers_label)
	HudLayout.align_counter_label(moves_label)
	if timer_label:
		HudLayout.prepare_timer_label(timer_label)
	set_playtest_joker_counter_visibility(false)
	set_playtest_move_counter_visibility(false)
	HudLayout.align_counter_row(counter_container)
	HudLayout.apply_top_hud_safe_area(playtest_hud_container, counter_container)
	if top_bar_row:
		top_bar_row.custom_minimum_size.y = float(GameConstants.HUD_BUTTON_HEIGHT)
	_start_test_mode_label_breathe()

# Playtest reset always uses the restart icon (never the random-board icon).
func _apply_reset_button_icon() -> void:
	if not reset_button:
		return
	var icon := reset_button.get_node_or_null("IconContainer/Icon") as TextureRect
	if icon:
		icon.texture = _ICON_RESET

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

# Connects playtest HUD buttons and HTP nav once at ready.
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
			_htp.hide_panel()
			_set_playtest_buttons_disabled(false)
			resume_from_tutorial_requested.emit()
		)
	if _try_again_button and not _try_again_button.pressed.is_connected(_on_try_again_pressed):
		_try_again_button.pressed.connect(_on_try_again_pressed)
	if _return_button and not _return_button.pressed.is_connected(_on_return_pressed):
		_return_button.pressed.connect(_on_return_pressed)

# Starts hold-to-repeat undo (same timing as the main-game HUD).
func _on_undo_button_down() -> void:
	_hold_repeat.start_undo()
	set_process(true)
	if UiSfx and undo_button:
		UiSfx.suppress_next_pressed_click(undo_button)
		UiSfx.play_click()


# Stops hold-to-repeat undo when the button is released.
func _on_undo_button_up() -> void:
	_hold_repeat.stop_undo()
	if UiSfx and undo_button:
		UiSfx.clear_pressed_click_suppress(undo_button)
	if not _hold_repeat.is_active():
		set_process(false)


# Starts hold-to-repeat redo (same timing as the main-game HUD).
func _on_redo_button_down() -> void:
	_hold_repeat.start_redo()
	set_process(true)
	if UiSfx and redo_button:
		UiSfx.suppress_next_pressed_click(redo_button)
		UiSfx.play_click()


# Stops hold-to-repeat redo when the button is released.
func _on_redo_button_up() -> void:
	_hold_repeat.stop_redo()
	if UiSfx and redo_button:
		UiSfx.clear_pressed_click_suppress(redo_button)
	if not _hold_repeat.is_active():
		set_process(false)


# Drives hold-to-repeat undo/redo. Stops if the button becomes disabled.
func _process(delta: float) -> void:
	if not _hold_repeat.is_active():
		set_process(false)
		return
	if not _hold_repeat.tick(delta):
		return
	if _hold_repeat.is_undo():
		if undo_button and undo_button.disabled:
			_on_undo_button_up()
			return
		if UiSfx:
			UiSfx.play_click()
		playtest_undo_requested.emit()
	elif _hold_repeat.is_redo():
		if redo_button and redo_button.disabled:
			_on_redo_button_up()
			return
		if UiSfx:
			UiSfx.play_click()
		playtest_redo_requested.emit()


# Victory "Try Again": hide overlay and ask the editor to reset the board.
func _on_try_again_pressed() -> void:
	playtest_reset_requested.emit()

# Victory "Return": leave playtest and restore the editor HUD.
func _on_return_pressed() -> void:
	test_mode_exited.emit()

# End-layer starts hidden; victory opts in when the board is solved.
func _setup_end_layer() -> void:
	HudLayout.register_modal_blocker(_end_dimmer)
	if _center:
		_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _victory_panel:
		_victory_panel.add_theme_stylebox_override("panel", HudLayout.make_dialog_panel_style())
	_style_end_buttons()
	hide_end_overlays()

# Pixel-fonts the victory action buttons (Latin captions stay Press Start).
func _style_end_buttons() -> void:
	_style_end_button(_try_again_button, HudLayout.english("UI_TRY_AGAIN"))
	_style_end_button(_return_button, HudLayout.english("UI_RETURN"))

## Panel chrome + Press Start caption for Latin/digits/symbols (incl. ka/uk English chrome).
# One victory button: raster caption, then grow to the translated text width.
func _style_end_button(btn: Button, display: String) -> void:
	if btn == null:
		return
	if _button_style_source:
		for style_name in ["normal", "pressed", "hover", "disabled"]:
			var style := _button_style_source.get_theme_stylebox(style_name)
			if style:
				btn.add_theme_stylebox_override(style_name, style)
	btn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	btn.focus_mode = Control.FOCUS_NONE
	btn.autowrap_mode = TextServer.AUTOWRAP_OFF
	btn.clip_text = false
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.custom_minimum_size = GameConstants.UI_BTN_PANEL_SIZE
	HudLayout.apply_raster_pixel_button(
		btn, display, GameConstants.UI_BTN_PANEL_FONT
	)
	HudLayout.grow_panel_button_to_text(btn)

# Sizes and stacks playtest victory header, stars, preview, and buttons.
func _layout_victory_panel(star_result: Dictionary) -> void:
	UiVictoryPanel.layout_stack(
		_victory_panel,
		_victory_title,
		_victory_results_host,
		_victory_preview,
		star_result,
		[],
		false,
		_victory_buttons
	)

## Disables (or re-enables) all playtest action buttons, including restart.
func _set_playtest_buttons_disabled(disabled: bool) -> void:
	if reset_button:
		reset_button.disabled = disabled
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
			reset_button.disabled = false
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

# Enables undo/redo only when the playtest stack has something to apply.
func update_playtest_undo_redo_buttons(can_undo: bool, can_redo: bool) -> void:
	if undo_button:
		undo_button.disabled = not can_undo
		HudLayout.refresh_button_icon_modulate(undo_button)
	if redo_button:
		redo_button.disabled = not can_redo
		HudLayout.refresh_button_icon_modulate(redo_button)

# Shows the playtest victory dialog with stars and an optional board preview.
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
	_style_end_buttons()

# Preview TextureRect is authored in level_editor.tscn; no runtime spawn.
func _ensure_victory_preview() -> void:
	if _victory_preview and is_instance_valid(_victory_preview):
		return

# Hides victory/end chrome and re-enables playtest HUD buttons.
func hide_end_overlays() -> void:
	if _end_layer:
		_end_layer.visible = false
	if _end_dimmer:
		_end_dimmer.visible = false
		_end_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _victory_panel:
		_victory_panel.visible = false
	_set_playtest_buttons_disabled(false)

# Alias used by the editor controller; same as hide_end_overlays.
func hide_victory_overlay() -> void:
	hide_end_overlays()

func show_how_to_play() -> void:
	_htp.show_panel()
	_set_playtest_buttons_disabled(true)

# Shows or hides HUD + counters + status without tearing down playtest mode.
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
			GameConstants.TILE_SHIFTER, moves, target, GameConstants.HUD_COUNTER_SHIFTER, tr("UI_MOVES")
		)

# Updates the playtest joker ratio counter (current / required).
func update_playtest_joker_counter(current: int, required: int) -> void:
	if not jokers_label:
		return
	HudLayout.prepare_counter_label(jokers_label)
	jokers_label.text = HudLayout.format_icon_ratio_counter(
		GameConstants.TILE_GREEN, current, required, GameConstants.HUD_COUNTER_GREEN, tr("UI_COUNTER_GREEN")
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
