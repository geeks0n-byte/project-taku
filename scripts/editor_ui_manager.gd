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

@onready var root = get_parent()
@onready var top_hud = root.find_child("TopHUD", true, false)
@onready var main_menu_button = root.find_child("MainMenuButton", true, false)
@onready var test_button = root.find_child("TestButton", true, false)
@onready var clear_button = root.find_child("ClearButton", true, false)
@onready var editor_title_label = root.find_child("EditorTitleLabel", true, false)
@onready var editor_undo_button = root.find_child("EditorUndoButton", true, false)
@onready var editor_redo_button = root.find_child("EditorRedoButton", true, false)
@onready var editor_hint_button = root.find_child("EditorHintButton", true, false)
@onready var control_panel = root.find_child("ControlPanel", true, false)
@onready var status_label = root.find_child("StatusLabel", true, false)
@onready var grid_size_container = root.find_child("GridSizeContainer", true, false)
@onready var width_minus = root.find_child("WidthMinus", true, false)
@onready var width_label = root.find_child("WidthLabel", true, false)
@onready var width_plus = root.find_child("WidthPlus", true, false)
@onready var height_minus = root.find_child("HeightMinus", true, false)
@onready var height_label = root.find_child("HeightLabel", true, false)
@onready var height_plus = root.find_child("HeightPlus", true, false)
@onready var keep_walls_toggle = root.find_child("KeepWallsToggle", true, false)
@onready var unique_solution_toggle = root.find_child("UniqueSolutionToggle", true, false)
@onready var random_button = root.find_child("RandomButton", true, false)
@onready var wall_button = root.find_child("WallButton", true, false)
@onready var empty_button = root.find_child("EmptyButton", true, false)
@onready var zero_button = root.find_child("ZeroButton", true, false)
@onready var one_button = root.find_child("OneButton", true, false)
@onready var joker_button = root.find_child("JokerButton", true, false)
@onready var shifter_button = root.find_child("ShifterButton", true, false)
@onready var equals_button = root.find_child("EqualsButton", true, false)
@onready var not_equals_button = root.find_child("NotEqualsButton", true, false)
@onready var time_minus = root.find_child("TimeMinus", true, false)
@onready var time_label = root.find_child("TimeLabel", true, false)
@onready var time_plus = root.find_child("TimePlus", true, false)
@onready var allow_zero = root.find_child("AllowZero", true, false)
@onready var allow_one = root.find_child("AllowOne", true, false)
@onready var allow_joker = root.find_child("AllowJoker", true, false)
@onready var save_button = root.find_child("SaveButton", true, false)
@onready var load_button = root.find_child("LoadButton", true, false)
@onready var level_minus = root.find_child("LevelMinus", true, false)
@onready var level_label = root.find_child("LevelLabel", true, false)
@onready var level_plus = root.find_child("LevelPlus", true, false)
@onready var overwrite_panel = root.find_child("OverwritePanel", true, false)
@onready var confirm_button = root.find_child("ConfirmButton", true, false)
@onready var cancel_button = root.find_child("CancelButton", true, false)

var editor_width: int = 3
var editor_height: int = 3
var editor_level: int = 1
var editor_time_limit: int = 0 
var is_playtesting_mode: bool = false
var brush_button_group: ButtonGroup = ButtonGroup.new()

func setup_ui(grid_width: int, grid_height: int):
	editor_width = grid_width
	editor_height = grid_height
	if editor_undo_button: editor_undo_button.disabled = true
	if editor_redo_button: editor_redo_button.disabled = true
	_setup_brush_toggles()
	_update_number_labels()
	if overwrite_panel: overwrite_panel.visible = false
	_connect_ui_signals()
	call_deferred("_emit_startup_signals")

func _emit_startup_signals():
	brush_changed.emit(-2, "Wall")
	grid_size_changed.emit(editor_width, editor_height)

func _setup_brush_toggles():
	var brushes = [wall_button, empty_button, zero_button, one_button, joker_button, shifter_button, equals_button, not_equals_button]
	for btn in brushes:
		if btn:
			btn.toggle_mode = true
			btn.button_group = brush_button_group
	if wall_button: wall_button.button_pressed = true

func _connect_ui_signals():
	if main_menu_button: main_menu_button.pressed.connect(func(): main_menu_requested.emit())
	if test_button: test_button.pressed.connect(func(): test_mode_entered.emit())
	if clear_button: clear_button.pressed.connect(func(): clear_requested.emit())
	if editor_undo_button: editor_undo_button.pressed.connect(func(): editor_undo_requested.emit())
	if editor_redo_button: editor_redo_button.pressed.connect(func(): editor_redo_requested.emit())
	if editor_hint_button: editor_hint_button.pressed.connect(func(): 
		var is_on = not editor_hint_button.button_pressed
		editor_hint_button.button_pressed = is_on
		editor_hint_toggled.emit(is_on)
	)
	
	if width_minus: width_minus.pressed.connect(func(): _adjust_value("width", -1))
	if width_plus: width_plus.pressed.connect(func(): _adjust_value("width", 1))
	if height_minus: height_minus.pressed.connect(func(): _adjust_value("height", -1))
	if height_plus: height_plus.pressed.connect(func(): _adjust_value("height", 1))
	
	if unique_solution_toggle: unique_solution_toggle.pressed.connect(_on_settings_toggle_pressed)
	if keep_walls_toggle: keep_walls_toggle.pressed.connect(_on_settings_toggle_pressed)
	if random_button: random_button.pressed.connect(func(): random_requested.emit())
	
	if wall_button: wall_button.pressed.connect(func(): brush_changed.emit(-2, "Wall"))
	if empty_button: empty_button.pressed.connect(func(): brush_changed.emit(-1, "Empty (Clear)"))
	if zero_button: zero_button.pressed.connect(func(): brush_changed.emit(0, "Yellow Tile"))
	if one_button: one_button.pressed.connect(func(): brush_changed.emit(1, "Blue Tile"))
	if joker_button: joker_button.pressed.connect(func(): brush_changed.emit(2, "Combined Tile"))
	if shifter_button: shifter_button.pressed.connect(func(): brush_changed.emit(3, "Shifter Tile Link Tool"))
	if equals_button: equals_button.pressed.connect(func(): brush_changed.emit(4, "Equals (=) Link Tool"))
	if not_equals_button: not_equals_button.pressed.connect(func(): brush_changed.emit(5, "Not Equals (×) Link Tool"))
	
	if time_minus: time_minus.pressed.connect(func(): _adjust_value("time", -30))
	if time_plus: time_plus.pressed.connect(func(): _adjust_value("time", 30))
	if allow_zero: allow_zero.pressed.connect(func(): allowed_tiles_changed.emit())
	if allow_one: allow_one.pressed.connect(func(): allowed_tiles_changed.emit())
	if allow_joker: allow_joker.pressed.connect(func(): allowed_tiles_changed.emit())
	if save_button: save_button.pressed.connect(func(): save_requested.emit())
	if load_button: load_button.pressed.connect(func(): load_requested.emit()) 
	if level_minus: level_minus.pressed.connect(func(): _adjust_value("level", -1))
	if level_plus: level_plus.pressed.connect(func(): _adjust_value("level", 1))
	if confirm_button: confirm_button.pressed.connect(func(): 
		if overwrite_panel: overwrite_panel.visible = false
		overwrite_confirmed.emit()
	)
	if cancel_button: cancel_button.pressed.connect(func():
		if overwrite_panel: overwrite_panel.visible = false
	)

func get_allowed_tiles() -> Array:
	var tiles: Array = []
	if allow_zero and allow_zero.button_pressed: tiles.append(0)
	if allow_one and allow_one.button_pressed: tiles.append(1)
	if allow_joker and allow_joker.button_pressed: tiles.append(2)
	if tiles.size() == 0: tiles = [0, 1, 2] 
	return tiles

func set_allowed_tiles(tiles: Array):
	if allow_zero: allow_zero.button_pressed = (0 in tiles)
	if allow_one: allow_one.button_pressed = (1 in tiles)
	if allow_joker: allow_joker.button_pressed = (2 in tiles)

func get_time_limit() -> int: return editor_time_limit
func set_time_limit(val: int):
	editor_time_limit = max(0, val)
	_update_number_labels()

func sync_size_displays(new_w: int, new_h: int):
	editor_width = new_w
	editor_height = new_h
	_update_number_labels()

func _update_number_labels():
	if width_label: width_label.text = "X: " + str(editor_width)
	if height_label: height_label.text = "Y: " + str(editor_height)
	if time_label:
		if editor_time_limit == 0: time_label.text = "[center][img=26x26]res:///resources/icons/icon_infinity.svg[/img][/center]"
		else: time_label.text = "[center]" + str(editor_time_limit) + "s[/center]"
	if level_label: level_label.text = "[center]" + tr("LEVEL") + " " + str(editor_level) + "[/center]"

func _on_settings_toggle_pressed():
	if not is_playtesting_mode: update_status("", Color.WHITE)

func _adjust_value(target: String, amount: int):
	var grid_changed = false
	match target:
		"width": 
			var old = editor_width
			editor_width = clamp(editor_width + amount, MIN_GRID_WIDTH, MAX_GRID_WIDTH)
			if old != editor_width: grid_changed = true
		"height": 
			var old = editor_height
			editor_height = clamp(editor_height + amount, MIN_GRID_HEIGHT, MAX_GRID_HEIGHT)
			if old != editor_height: grid_changed = true
		"level": editor_level = max(1, editor_level + amount) 
		"time": editor_time_limit = max(0, editor_time_limit + amount)
	_update_number_labels()
	if not is_playtesting_mode: update_status("", Color.WHITE)
	if grid_changed: grid_size_changed.emit(editor_width, editor_height)

func update_status(msg: String, text_color: Color = Color.WHITE):
	if status_label:
		status_label.modulate = text_color
		status_label.text = "[center]" + tr(msg) + "[/center]"
		status_label.fit_content = true

func toggle_editor_visibility(is_playtesting: bool):
	is_playtesting_mode = is_playtesting
	if top_hud: top_hud.visible = not is_playtesting
	if control_panel: control_panel.visible = not is_playtesting

func update_dynamic_editor_layout(_board_y: float, _board_height: float):
	pass

func get_level_number() -> int: return editor_level

func is_unique_solution_required() -> bool:
	if unique_solution_toggle: return unique_solution_toggle.button_pressed
	return false 
	
func is_keep_walls_requested() -> bool:
	if keep_walls_toggle: return keep_walls_toggle.button_pressed
	return true 

func update_editor_undo_redo_buttons(can_undo: bool, can_redo: bool):
	if editor_undo_button: editor_undo_button.disabled = not can_undo
	if editor_redo_button: editor_redo_button.disabled = not can_redo

func set_editor_hint_toggle(is_on: bool):
	if editor_hint_button: editor_hint_button.button_pressed = is_on

func show_overwrite_warning():
	if overwrite_panel: overwrite_panel.visible = true
