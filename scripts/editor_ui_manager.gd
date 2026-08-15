class_name EditorUIManager
extends Node2D

signal brush_changed(state_id: int, brush_name: String)
signal save_requested
signal load_requested
signal clear_requested
signal random_requested
signal main_menu_requested
signal test_mode_entered
signal grid_size_changed(new_width: int, new_height: int)
signal overwrite_confirmed
signal editor_undo_requested
signal editor_redo_requested
signal allowed_tiles_changed
signal editor_hint_toggled(is_on: bool)

const MIN_GRID_WIDTH: int = 3
const MAX_GRID_WIDTH: int = 8
const MIN_GRID_HEIGHT: int = 3
const MAX_GRID_HEIGHT: int = 8

@onready var top_hud: MarginContainer = $"../EditorUI/TopHUD"
@onready var top_bar_row: HBoxContainer = $"../EditorUI/TopHUD/TopBarRow"
@onready var main_menu_button: Button = $"../EditorUI/TopHUD/TopBarRow/LeftButtons/MainMenuButton"
@onready var test_button: Button = $"../EditorUI/TopHUD/TopBarRow/LeftButtons/TestButton"
@onready var clear_button: Button = $"../EditorUI/TopHUD/TopBarRow/LeftButtons/ClearButton"
@onready var editor_undo_button: Button = $"../EditorUI/TopHUD/TopBarRow/RightButtons/EditorUndoButton"
@onready var editor_redo_button: Button = $"../EditorUI/TopHUD/TopBarRow/RightButtons/EditorRedoButton"
@onready var editor_hint_button: Button = $"../EditorUI/TopHUD/TopBarRow/RightButtons/EditorHintButton"
@onready var editor_mode_label: RichTextLabel = $"../EditorUI/TopHUD/TopBarRow/EditorModeLabelWrap/EditorModeLabelInset/EditorModeLabel"
@onready var control_panel: Panel = $"../EditorUI/ControlPanel"
@onready var status_label: RichTextLabel = $"../EditorUI/StatusLabel"
@onready var width_minus: Button = $"../EditorUI/ControlPanel/ScrollContainer/VBox/GridSizeContainer/WidthMinus"
@onready var width_label: Label = $"../EditorUI/ControlPanel/ScrollContainer/VBox/GridSizeContainer/WidthLabel"
@onready var width_plus: Button = $"../EditorUI/ControlPanel/ScrollContainer/VBox/GridSizeContainer/WidthPlus"
@onready var height_minus: Button = $"../EditorUI/ControlPanel/ScrollContainer/VBox/GridSizeContainer/HeightMinus"
@onready var height_label: Label = $"../EditorUI/ControlPanel/ScrollContainer/VBox/GridSizeContainer/HeightLabel"
@onready var height_plus: Button = $"../EditorUI/ControlPanel/ScrollContainer/VBox/GridSizeContainer/HeightPlus"
@onready var keep_walls_toggle: Button = $"../EditorUI/ControlPanel/ScrollContainer/VBox/GeneratorOptionsContainer/KeepWallsToggle"
@onready var unique_solution_toggle: Button = $"../EditorUI/ControlPanel/ScrollContainer/VBox/GeneratorOptionsContainer/UniqueSolutionToggle"
@onready var difficulty_button: Button = $"../EditorUI/ControlPanel/ScrollContainer/VBox/GeneratorOptionsContainer/DifficultyButton"
@onready var random_button: Button = $"../EditorUI/ControlPanel/ScrollContainer/VBox/GeneratorOptionsContainer/RandomButton"
@onready var wall_button: Button = $"../EditorUI/ControlPanel/ScrollContainer/VBox/BrushContainer/WallButton"
@onready var empty_button: Button = $"../EditorUI/ControlPanel/ScrollContainer/VBox/BrushContainer/EmptyButton"
@onready var yellow_button: Button = $"../EditorUI/ControlPanel/ScrollContainer/VBox/BrushContainer/YellowButton"
@onready var blue_button: Button = $"../EditorUI/ControlPanel/ScrollContainer/VBox/BrushContainer/BlueButton"
@onready var joker_button: Button = $"../EditorUI/ControlPanel/ScrollContainer/VBox/BrushContainer/JokerButton"
@onready var shifter_button: Button = $"../EditorUI/ControlPanel/ScrollContainer/VBox/BrushContainer/ShifterButton"
@onready var equals_button: Button = $"../EditorUI/ControlPanel/ScrollContainer/VBox/BrushContainer/EqualsButton"
@onready var not_equals_button: Button = $"../EditorUI/ControlPanel/ScrollContainer/VBox/BrushContainer/NotEqualsButton"
@onready var time_minus: Button = $"../EditorUI/ControlPanel/ScrollContainer/VBox/LevelSettingsContainer/TimeSelector/TimeMinus"
@onready var time_label: RichTextLabel = $"../EditorUI/ControlPanel/ScrollContainer/VBox/LevelSettingsContainer/TimeSelector/TimeLabel"
@onready var time_plus: Button = $"../EditorUI/ControlPanel/ScrollContainer/VBox/LevelSettingsContainer/TimeSelector/TimePlus"
@onready var allow_yellow: Button = $"../EditorUI/ControlPanel/ScrollContainer/VBox/LevelSettingsContainer/AllowYellow"
@onready var allow_blue: Button = $"../EditorUI/ControlPanel/ScrollContainer/VBox/LevelSettingsContainer/AllowBlue"
@onready var allow_joker: Button = $"../EditorUI/ControlPanel/ScrollContainer/VBox/LevelSettingsContainer/AllowJoker"
@onready var save_button: Button = $"../EditorUI/ControlPanel/ScrollContainer/VBox/ConfigContainer/SaveButton"
@onready var load_button: Button = $"../EditorUI/ControlPanel/ScrollContainer/VBox/ConfigContainer/LoadButton"
@onready var level_minus: Button = $"../EditorUI/ControlPanel/ScrollContainer/VBox/ConfigContainer/LevelSelector/LevelMinus"
@onready var level_label: RichTextLabel = $"../EditorUI/ControlPanel/ScrollContainer/VBox/ConfigContainer/LevelSelector/LevelLabel"
@onready var level_plus: Button = $"../EditorUI/ControlPanel/ScrollContainer/VBox/ConfigContainer/LevelSelector/LevelPlus"
@onready var overwrite_panel: Panel = $"../EditorUI/OverwritePanel"
@onready var confirm_button: Button = $"../EditorUI/OverwritePanel/ButtonRow/ConfirmButton"
@onready var cancel_button: Button = $"../EditorUI/OverwritePanel/ButtonRow/CancelButton"

var editor_width: int = 3
var editor_height: int = 3
var editor_level: int = 1
var editor_time_limit: int = 0
var is_playtesting_mode: bool = false
var editor_difficulty: int = PuzzleGenerator.Difficulty.EASY

const HOLD_INITIAL_DELAY := 0.35
const HOLD_REPEAT_INTERVAL := 0.08

var _hold_button: Button = null
var _hold_target: String = ""
var _hold_amount: int = 0
var _hold_timer: Timer = null

func setup_ui(grid_width: int, grid_height: int) -> void:
	editor_width = grid_width
	editor_height = grid_height
	if editor_mode_label:
		editor_mode_label.text = HudLayout.format_mode_label("EDIT_MODE", true)
	_apply_top_bar_buttons()
	_ensure_hold_timer()
	_update_number_labels()
	_connect_ui_signals()
	_refresh_toggle_masks()
	_refresh_difficulty_button()
	_apply_default_font_to_link_buttons()
	_apply_star_time_label()
	_disable_editor_hint_button()
	if status_label and control_panel:
		HudLayout.position_editor_status_below_panel(control_panel, status_label)
	call_deferred("_emit_startup_signals")
	call_deferred("_apply_default_font_to_link_buttons")
	call_deferred("_apply_star_time_label")
	call_deferred("_disable_editor_hint_button")
	if SaveManager and not SaveManager.language_changed.is_connected(_on_language_changed):
		SaveManager.language_changed.connect(_on_language_changed)

func _on_language_changed() -> void:
	_apply_default_font_to_link_buttons()
	_apply_star_time_label()

func _disable_editor_hint_button() -> void:
	if not editor_hint_button:
		return
	editor_hint_button.disabled = true
	editor_hint_button.toggle_mode = true
	editor_hint_button.button_pressed = false
	HintController.update_button(editor_hint_button, false)

func _apply_default_font_to_link_buttons() -> void:
	const BRUSH_BTN := Vector2(120, 120)
	for button in [equals_button, not_equals_button]:
		if not button:
			continue
		button.custom_minimum_size = BRUSH_BTN
		button.size = BRUSH_BTN
		button.clip_contents = true
		var label := button.get_node_or_null("IconContainer/Label") as Label
		if not label:
			continue
		label.set_meta("_use_default_font", true)
		label.add_theme_font_override("font", ThemeDB.fallback_font)
		label.add_theme_font_size_override("font_size", 52)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2.ZERO
		label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _apply_star_time_label() -> void:
	var title := get_node_or_null(
		"../EditorUI/ControlPanel/ScrollContainer/VBox/LevelSettingsContainer/TimeTitleLabel"
	) as Label
	if not title:
		return
	title.text = "TIME:"
	title.tooltip_text = "Star time: beat this to earn the time star. Infinity = no time star."

func _ensure_hold_timer() -> void:
	if _hold_timer:
		return
	_hold_timer = Timer.new()
	_hold_timer.one_shot = true
	add_child(_hold_timer)
	_hold_timer.timeout.connect(_on_hold_timer_timeout)

func _bind_hold_button(button: Button, target: String, amount: int) -> void:
	if not button:
		return
	button.button_down.connect(func(): _start_hold(button, target, amount))
	button.button_up.connect(func(): _stop_hold(button))
	button.mouse_exited.connect(func():
		if _hold_button == button:
			_stop_hold(button)
	)

func _apply_top_bar_buttons() -> void:
	HudLayout.apply_top_bar_button_cluster(top_bar_row.get_node_or_null("LeftButtons") as HBoxContainer)
	HudLayout.apply_top_bar_button_cluster(top_bar_row.get_node_or_null("RightButtons") as HBoxContainer)
	for button in [main_menu_button, test_button, clear_button, editor_hint_button, editor_undo_button, editor_redo_button]:
		HudLayout.apply_square_top_bar_button(button)
	HudLayout.apply_top_bar_mode_label(editor_mode_label)
	if top_hud:
		top_hud.offset_bottom = GameConstants.HUD_TOP_BAR_HEIGHT
	if top_bar_row:
		top_bar_row.custom_minimum_size.y = float(GameConstants.HUD_BUTTON_HEIGHT)
	_nudge_editor_control_icons()

func _nudge_editor_control_icons() -> void:
	for button in [width_minus, width_plus, height_minus, height_plus, time_minus, time_plus, level_minus, level_plus]:
		HudLayout.nudge_button_icon_up(button, 2)
	for button in [wall_button, empty_button, equals_button, not_equals_button]:
		HudLayout.nudge_button_icon_up(button, 2)

func _emit_startup_signals() -> void:
	brush_changed.emit(-2, "Wall")
	grid_size_changed.emit(editor_width, editor_height)

func _connect_ui_signals() -> void:
	if main_menu_button:
		main_menu_button.pressed.connect(func(): main_menu_requested.emit())
	if test_button:
		test_button.pressed.connect(func(): test_mode_entered.emit())
	if clear_button:
		clear_button.pressed.connect(func(): clear_requested.emit())
	if editor_undo_button:
		editor_undo_button.pressed.connect(func(): editor_undo_requested.emit())
	if editor_redo_button:
		editor_redo_button.pressed.connect(func(): editor_redo_requested.emit())
	if editor_hint_button:
		editor_hint_button.toggled.connect(func(is_on: bool): editor_hint_toggled.emit(is_on))

	if width_minus:
		_bind_hold_button(width_minus, "width", -1)
	if width_plus:
		_bind_hold_button(width_plus, "width", 1)
	if height_minus:
		_bind_hold_button(height_minus, "height", -1)
	if height_plus:
		_bind_hold_button(height_plus, "height", 1)

	if unique_solution_toggle:
		unique_solution_toggle.pressed.connect(_on_settings_toggle_pressed)
	if keep_walls_toggle:
		keep_walls_toggle.pressed.connect(_on_settings_toggle_pressed)
	if difficulty_button:
		difficulty_button.pressed.connect(_on_difficulty_pressed)
	if random_button:
		random_button.pressed.connect(func(): random_requested.emit())

	if wall_button:
		wall_button.pressed.connect(func(): brush_changed.emit(-2, "Wall"))
	if empty_button:
		empty_button.pressed.connect(func(): brush_changed.emit(-1, "Empty (Clear)"))
	if yellow_button:
		yellow_button.pressed.connect(func(): brush_changed.emit(0, "Yellow Tile"))
	if blue_button:
		blue_button.pressed.connect(func(): brush_changed.emit(1, "Blue Tile"))
	if joker_button:
		joker_button.pressed.connect(func(): brush_changed.emit(2, "Joker Tile"))
	if shifter_button:
		shifter_button.pressed.connect(func(): brush_changed.emit(3, "Shifter Tile Link Tool"))
	if equals_button:
		equals_button.pressed.connect(
			func(): brush_changed.emit(GameConstants.BrushTool.EQUALS, "Equals (=) Link Tool")
		)
	if not_equals_button:
		not_equals_button.pressed.connect(
			func(): brush_changed.emit(GameConstants.BrushTool.NOT_EQUALS, "Not Equals (×) Link Tool")
		)

	if time_minus:
		_bind_hold_button(time_minus, "time", -30)
	if time_plus:
		_bind_hold_button(time_plus, "time", 30)
	if allow_yellow:
		allow_yellow.pressed.connect(func(): allowed_tiles_changed.emit())
	if allow_blue:
		allow_blue.pressed.connect(func(): allowed_tiles_changed.emit())
	if allow_joker:
		allow_joker.pressed.connect(func(): allowed_tiles_changed.emit())
	if save_button:
		save_button.pressed.connect(func(): save_requested.emit())
	if load_button:
		load_button.pressed.connect(func(): load_requested.emit())
	if level_minus:
		_bind_hold_button(level_minus, "level", -1)
	if level_plus:
		_bind_hold_button(level_plus, "level", 1)
	if confirm_button:
		confirm_button.pressed.connect(func():
			if overwrite_panel:
				overwrite_panel.visible = false
			overwrite_confirmed.emit()
		)
	if cancel_button:
		cancel_button.pressed.connect(func():
			if overwrite_panel:
				overwrite_panel.visible = false
		)

func get_allowed_tiles() -> Array:
	var tiles: Array = []
	if allow_yellow and allow_yellow.button_pressed:
		tiles.append(0)
	if allow_blue and allow_blue.button_pressed:
		tiles.append(1)
	if allow_joker and allow_joker.button_pressed:
		tiles.append(2)
	if tiles.is_empty():
		tiles = [0, 1, 2]
	return tiles

func set_allowed_tiles(tiles: Array) -> void:
	if allow_yellow:
		allow_yellow.button_pressed = (0 in tiles)
	if allow_blue:
		allow_blue.button_pressed = (1 in tiles)
	if allow_joker:
		allow_joker.button_pressed = (2 in tiles)

func get_time_limit() -> int:
	return editor_time_limit

func set_time_limit(val: int) -> void:
	editor_time_limit = max(0, val)
	_update_number_labels()

func sync_size_displays(new_w: int, new_h: int) -> void:
	editor_width = new_w
	editor_height = new_h
	_update_number_labels()

func _update_number_labels() -> void:
	if width_label:
		width_label.text = "X:" + str(editor_width)
	if height_label:
		height_label.text = "Y:" + str(editor_height)
	if time_label:
		time_label.custom_minimum_size = Vector2(140, 90)
		if editor_time_limit == 0:
			var infinity_size := GameConstants.EDITOR_INFINITY_ICON_SIZE
			time_label.text = "[center][img=%dx%d]%s[/img]\n[font_size=3][color=#00000000].[/color][/font_size][/center]" % [
				infinity_size, infinity_size, GameConstants.ICON_INFINITY
			]
		else:
			var minutes := int(editor_time_limit / 60.0)
			var seconds := editor_time_limit % 60
			time_label.text = "[center]%d:%02d[/center]" % [minutes, seconds]
	if level_label:
		level_label.text = "[center]" + HudLayout.english("LEVEL") + " " + str(editor_level) + "[/center]"
		level_label.custom_minimum_size = Vector2(200, 90)
	_update_selector_button_states()

func _update_selector_button_states() -> void:
	if width_minus:
		width_minus.disabled = editor_width <= MIN_GRID_WIDTH
	if width_plus:
		width_plus.disabled = editor_width >= MAX_GRID_WIDTH
	if height_minus:
		height_minus.disabled = editor_height <= MIN_GRID_HEIGHT
	if height_plus:
		height_plus.disabled = editor_height >= MAX_GRID_HEIGHT
	if time_minus:
		time_minus.disabled = editor_time_limit <= 0
	if level_minus:
		level_minus.disabled = editor_level <= 1
	for button in [width_minus, width_plus, height_minus, height_plus, time_minus, time_plus, level_minus, level_plus]:
		HudLayout.refresh_button_icon_modulate(button)

func _on_settings_toggle_pressed() -> void:
	_refresh_toggle_masks()
	if not is_playtesting_mode:
		update_status("", Color.WHITE)

func _refresh_toggle_masks() -> void:
	if keep_walls_toggle:
		HudLayout.apply_toggle_active_mask(
			keep_walls_toggle,
			keep_walls_toggle.button_pressed,
			GameConstants.TOGGLE_MASK_WHITE
		)
	if unique_solution_toggle:
		HudLayout.apply_toggle_active_mask(
			unique_solution_toggle,
			unique_solution_toggle.button_pressed,
			GameConstants.TOGGLE_MASK_WHITE
		)
	_refresh_difficulty_button()

func _on_difficulty_pressed() -> void:
	editor_difficulty = (editor_difficulty + 1) % 3
	_refresh_difficulty_button()
	if not is_playtesting_mode:
		update_status("", Color.WHITE)

func _refresh_difficulty_button() -> void:
	if not difficulty_button:
		return
	match editor_difficulty:
		PuzzleGenerator.Difficulty.EASY:
			difficulty_button.text = "DIFF\nEASY"
			HudLayout.apply_toggle_active_mask(
				difficulty_button, true, Color(0.45, 1.0, 0.45, 0.4)
			)
		PuzzleGenerator.Difficulty.HARD:
			difficulty_button.text = "DIFF\nHARD"
			HudLayout.apply_toggle_active_mask(
				difficulty_button, true, Color(1.0, 0.45, 0.4, 0.4)
			)
		_:
			difficulty_button.text = "DIFF\nMED"
			HudLayout.apply_toggle_active_mask(
				difficulty_button, true, GameConstants.TOGGLE_MASK_AMBER
			)

func get_generation_difficulty() -> int:
	return editor_difficulty

func set_generation_difficulty(difficulty: int) -> void:
	editor_difficulty = clampi(
		difficulty, PuzzleGenerator.Difficulty.EASY, PuzzleGenerator.Difficulty.HARD
	)
	_refresh_difficulty_button()

func _start_hold(button: Button, target: String, amount: int) -> void:
	_stop_hold(_hold_button)
	if not button or button.disabled:
		return
	_hold_button = button
	_hold_target = target
	_hold_amount = amount
	_adjust_value(target, amount)
	if _hold_timer:
		_hold_timer.start(HOLD_INITIAL_DELAY)

func _stop_hold(button: Button = null) -> void:
	if button != null and _hold_button != null and button != _hold_button:
		return
	_hold_button = null
	_hold_target = ""
	_hold_amount = 0
	if _hold_timer:
		_hold_timer.stop()

func _on_hold_timer_timeout() -> void:
	if _hold_button == null or not is_instance_valid(_hold_button):
		_stop_hold()
		return
	if not _hold_button.button_pressed or _hold_button.disabled:
		_stop_hold(_hold_button)
		return
	_adjust_value(_hold_target, _hold_amount)
	if _hold_timer:
		_hold_timer.start(HOLD_REPEAT_INTERVAL)

func _adjust_value(target: String, amount: int) -> void:
	var grid_changed = false
	match target:
		"width":
			var old = editor_width
			editor_width = clamp(editor_width + amount, MIN_GRID_WIDTH, MAX_GRID_WIDTH)
			if old != editor_width:
				grid_changed = true
		"height":
			var old = editor_height
			editor_height = clamp(editor_height + amount, MIN_GRID_HEIGHT, MAX_GRID_HEIGHT)
			if old != editor_height:
				grid_changed = true
		"level":
			editor_level = max(1, editor_level + amount)
		"time":
			editor_time_limit = max(0, editor_time_limit + amount)
	_update_number_labels()
	if not is_playtesting_mode:
		update_status("", Color.WHITE)
	if grid_changed:
		grid_size_changed.emit(editor_width, editor_height)

func update_status(msg: String, text_color: Color = Color.WHITE, should_translate: bool = true) -> void:
	if not status_label:
		return
	status_label.modulate = text_color
	HudLayout.apply_status_font(status_label, GameConstants.HUD_EDITOR_STATUS_FONT_SIZE)
	if msg.is_empty():
		status_label.text = "[center][/center]"
	elif should_translate:
		status_label.text = "[center]" + HudLayout.translate_status_text(msg, true) + "[/center]"
	else:
		status_label.text = "[center]" + HudLayout.break_after_sentences(msg) + "[/center]"

func update_dynamic_editor_layout(_board_y: float, _board_height: float) -> void:
	if status_label and control_panel:
		HudLayout.position_editor_status_below_panel(control_panel, status_label)

func toggle_editor_visibility(is_playtesting: bool) -> void:
	is_playtesting_mode = is_playtesting
	if top_hud:
		top_hud.visible = not is_playtesting
	if control_panel:
		control_panel.visible = not is_playtesting
	if status_label:
		status_label.visible = not is_playtesting

func get_level_number() -> int:
	return editor_level

func is_unique_solution_required() -> bool:
	if unique_solution_toggle:
		return unique_solution_toggle.button_pressed
	return false

func set_unique_solution_required(is_required: bool) -> void:
	if unique_solution_toggle:
		unique_solution_toggle.button_pressed = is_required
		_refresh_toggle_masks()

func set_keep_walls_requested(keep: bool) -> void:
	if keep_walls_toggle:
		keep_walls_toggle.button_pressed = keep
		_refresh_toggle_masks()

func is_keep_walls_requested() -> bool:
	if keep_walls_toggle:
		return keep_walls_toggle.button_pressed
	return true

func update_editor_undo_redo_buttons(can_undo: bool, can_redo: bool) -> void:
	if editor_undo_button:
		editor_undo_button.disabled = not can_undo
		HudLayout.refresh_button_icon_modulate(editor_undo_button)
	if editor_redo_button:
		editor_redo_button.disabled = not can_redo
		HudLayout.refresh_button_icon_modulate(editor_redo_button)

func set_editor_hint_toggle(_is_on: bool) -> void:
	_disable_editor_hint_button()

func show_overwrite_warning() -> void:
	if not overwrite_panel:
		return
	var warning_label := overwrite_panel.get_node_or_null("WarningLabel") as Label
	if warning_label:
		warning_label.text = "Level already exists.\nOverwrite?"
		HudLayout.apply_popup_label(warning_label, GameConstants.UI_BODY_FONT_SIZE_LARGE)
	HudLayout.apply_dialog_button(confirm_button)
	HudLayout.apply_dialog_button(cancel_button)
	overwrite_panel.z_index = 4096
	overwrite_panel.move_to_front()
	overwrite_panel.visible = true
