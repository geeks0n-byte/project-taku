class_name EditorUIManager
extends Node

signal brush_changed(state_id: int, brush_name: String)
signal save_requested
signal load_requested
signal clear_requested
signal random_requested 
signal main_menu_requested
signal test_mode_entered
signal test_mode_exited
signal grid_size_changed(new_width: int, new_height: int) 
signal overwrite_confirmed

const MIN_GRID_WIDTH: int = 3
const MAX_GRID_WIDTH: int = 9
const MIN_GRID_HEIGHT: int = 3
const MAX_GRID_HEIGHT: int = 11

@export var icon_wall: Texture2D
@export var icon_empty: Texture2D
@export var icon_zero: Texture2D
@export var icon_one: Texture2D
@export var icon_joker: Texture2D

@onready var editor_ui_root = $"../EditorUI"

@onready var grid_size_container = editor_ui_root.find_child("GridSizeContainer", true, false)
@onready var width_minus = editor_ui_root.find_child("WidthMinus", true, false)
@onready var width_label = editor_ui_root.find_child("WidthLabel", true, false)
@onready var width_plus = editor_ui_root.find_child("WidthPlus", true, false)
@onready var height_minus = editor_ui_root.find_child("HeightMinus", true, false)
@onready var height_label = editor_ui_root.find_child("HeightLabel", true, false)
@onready var height_plus = editor_ui_root.find_child("HeightPlus", true, false)
@onready var set_size_button = editor_ui_root.find_child("SetSizeButton", true, false)

@onready var level_settings_container = editor_ui_root.find_child("LevelSettingsContainer", true, false)
@onready var allow_zero = editor_ui_root.find_child("AllowZero", true, false)
@onready var allow_one = editor_ui_root.find_child("AllowOne", true, false)
@onready var allow_joker = editor_ui_root.find_child("AllowJoker", true, false)
@onready var time_minus = editor_ui_root.find_child("TimeMinus", true, false)
@onready var time_label = editor_ui_root.find_child("TimeLabel", true, false)
@onready var time_plus = editor_ui_root.find_child("TimePlus", true, false)

@onready var level_minus = editor_ui_root.find_child("LevelMinus", true, false)
@onready var level_label = editor_ui_root.find_child("LevelLabel", true, false)
@onready var level_plus = editor_ui_root.find_child("LevelPlus", true, false)
@onready var status_label = editor_ui_root.find_child("StatusLabel", true, false)

@onready var brush_container = editor_ui_root.find_child("BrushContainer", true, false)
@onready var clear_button = editor_ui_root.find_child("ClearButton", true, false)
@onready var wall_button = editor_ui_root.find_child("WallButton", true, false)
@onready var empty_button = editor_ui_root.find_child("EmptyButton", true, false)
@onready var zero_button = editor_ui_root.find_child("ZeroButton", true, false)
@onready var one_button = editor_ui_root.find_child("OneButton", true, false)
@onready var joker_button = editor_ui_root.find_child("JokerButton", true, false)
@onready var shifter_button = editor_ui_root.find_child("ShifterButton", true, false)
@onready var equals_button = editor_ui_root.find_child("EqualsButton", true, false)
@onready var not_equals_button = editor_ui_root.find_child("NotEqualsButton", true, false)

@onready var save_button = editor_ui_root.find_child("SaveButton", true, false)
@onready var load_button = editor_ui_root.find_child("LoadButton", true, false)
@onready var main_menu_button = editor_ui_root.find_child("MainMenuButton", true, false)
@onready var test_button = editor_ui_root.find_child("TestButton", true, false)
@onready var exit_test_button = editor_ui_root.find_child("ExitTestButton", true, false)

@onready var playtest_victory_panel = editor_ui_root.find_child("PlaytestVictoryPanel", true, false)
@onready var victory_message_label = editor_ui_root.find_child("VictoryMessageLabel", true, false)
@onready var return_button = editor_ui_root.find_child("ReturnButton", true, false)

@onready var overwrite_panel = editor_ui_root.find_child("OverwritePanel", true, false)
@onready var warning_label = editor_ui_root.find_child("WarningLabel", true, false)
@onready var confirm_button = editor_ui_root.find_child("ConfirmButton", true, false)
@onready var cancel_button = editor_ui_root.find_child("CancelButton", true, false)

var editor_width: int = 3
var editor_height: int = 3
var editor_level: int = 1
var editor_time_limit: int = 0 

var brush_button_group: ButtonGroup = ButtonGroup.new()

var playtest_hud_container: HBoxContainer
var pt_timer_label: Label
var pt_moves_label: Label
var random_button: Button 

func setup_ui(grid_width: int, grid_height: int, _cell_size: float):
	editor_width = grid_width
	editor_height = grid_height
	
	if grid_size_container and not random_button:
		random_button = Button.new()
		random_button.text = "🎲 RANDOM"
		random_button.add_theme_font_size_override("font_size", 28)
		random_button.pressed.connect(func(): random_requested.emit())
		grid_size_container.add_child(random_button)
		grid_size_container.move_child(random_button, 0)
	
	_setup_brush_toggles()
	_setup_tree_checkbox_icons()
	_build_playtest_hud() 
	emit_signal("brush_changed", -1, "Empty (Clear)")
	
	_update_number_labels()
	_update_panel_layout(grid_width, grid_height)
	
	if main_menu_button:
		main_menu_button.text = "Main Menu"
		main_menu_button.global_position = Vector2(120, 40)
		main_menu_button.size = Vector2(200, 70)
		main_menu_button.add_theme_font_size_override("font_size", 32)
		
	if clear_button:
		clear_button.global_position = Vector2(340, 40)
		clear_button.size = Vector2(200, 70)
		clear_button.add_theme_font_size_override("font_size", 32)
	
	var screen_width = get_viewport().get_visible_rect().size.x
	
	if playtest_victory_panel:
		playtest_victory_panel.visible = false
		var victory_x = (screen_width - 500) / 2.0
		playtest_victory_panel.global_position = Vector2(victory_x, 250)
		playtest_victory_panel.set_deferred("size", Vector2(500, 450))
		
	if victory_message_label:
		victory_message_label.set_deferred("custom_minimum_size", Vector2(460, 300))
		victory_message_label.position = Vector2(20, 20)
		victory_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		victory_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		victory_message_label.add_theme_font_size_override("font_size", 36)
		
	if return_button:
		return_button.position = Vector2(100, 360)
		return_button.set_deferred("size", Vector2(300, 60))
		return_button.add_theme_font_size_override("font_size", 24)
		
	if overwrite_panel:
		overwrite_panel.visible = false
		var over_x = (screen_width - 600) / 2.0
		overwrite_panel.global_position = Vector2(over_x, 300)
		overwrite_panel.set_deferred("size", Vector2(600, 350))
		
	if warning_label:
		warning_label.set_deferred("custom_minimum_size", Vector2(560, 200))
		warning_label.position = Vector2(20, 20)
		warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		warning_label.add_theme_font_size_override("font_size", 38)
		warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		warning_label.modulate = Color(1.0, 0.4, 0.4)
		
	if confirm_button:
		confirm_button.add_theme_font_size_override("font_size", 32)
		confirm_button.custom_minimum_size = Vector2(200, 80)
		confirm_button.pressed.connect(func():
			overwrite_panel.visible = false
			overwrite_confirmed.emit()
		)
		
	if cancel_button:
		cancel_button.add_theme_font_size_override("font_size", 32)
		cancel_button.custom_minimum_size = Vector2(200, 80)
		cancel_button.pressed.connect(func(): overwrite_panel.visible = false)
		
	var button_row = editor_ui_root.find_child("ButtonRow", true, false)
	if button_row:
		button_row.position = Vector2(50, 240)
		button_row.set_deferred("size", Vector2(500, 80))
		button_row.alignment = BoxContainer.ALIGNMENT_CENTER
		button_row.add_theme_constant_override("separation", 60)
	
	if exit_test_button:
		exit_test_button.visible = false
	
	_set_button_labels()
	_connect_ui_signals()

func show_overwrite_warning():
	if overwrite_panel:
		overwrite_panel.visible = true

func _build_playtest_hud():
	if not editor_ui_root: return
	
	playtest_hud_container = HBoxContainer.new()
	playtest_hud_container.name = "PlaytestHUD"
	editor_ui_root.add_child(playtest_hud_container)
	
	var screen_width = get_viewport().get_visible_rect().size.x
	playtest_hud_container.position = Vector2(0, 40)
	playtest_hud_container.size = Vector2(screen_width, 60)
	playtest_hud_container.alignment = BoxContainer.ALIGNMENT_CENTER
	playtest_hud_container.add_theme_constant_override("separation", 100)
	playtest_hud_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	playtest_hud_container.visible = false
	
	pt_timer_label = Label.new()
	pt_timer_label.add_theme_font_size_override("font_size", 32)
	pt_timer_label.modulate = Color(0.9, 0.9, 0.9)
	playtest_hud_container.add_child(pt_timer_label)
	
	pt_moves_label = Label.new()
	pt_moves_label.add_theme_font_size_override("font_size", 32)
	pt_moves_label.modulate = Color(1.0, 0.6, 0.2)
	playtest_hud_container.add_child(pt_moves_label)

func update_playtest_hud(time_remaining: int, moves: int):
	if pt_timer_label:
		if editor_time_limit == 0:
			pt_timer_label.text = "Time: ∞"
		else:
			var minutes = max(0, int(time_remaining / 60.0))
			var seconds = max(0, time_remaining % 60)
			pt_timer_label.text = "Time: %02d:%02d" % [minutes, seconds]
	if pt_moves_label:
		pt_moves_label.text = "Shifter Moves: %d" % moves

func _setup_tree_checkbox_icons():
	var tex_zero_file = load("res://icons/tiles/tile_yellow.svg")
	var tex_one_file = load("res://icons/tiles/tile_blue.svg")
	var tex_joker_file = load("res://icons/tiles/tile_green.svg")
	
	if allow_zero:
		allow_zero.toggle_mode = true
		allow_zero.button_pressed = true # Check by default
		if tex_zero_file: allow_zero.icon = tex_zero_file
		elif icon_zero: allow_zero.icon = icon_zero
		allow_zero.expand_icon = true
		allow_zero.add_theme_constant_override("icon_max_width", 48)
		
	if allow_one:
		allow_one.toggle_mode = true
		allow_one.button_pressed = true # Check by default
		if tex_one_file: allow_one.icon = tex_one_file
		elif icon_one: allow_one.icon = icon_one
		allow_one.expand_icon = true
		allow_one.add_theme_constant_override("icon_max_width", 48)
		
	if allow_joker:
		allow_joker.toggle_mode = true
		allow_joker.button_pressed = true # Check by default
		if tex_joker_file: allow_joker.icon = tex_joker_file
		elif icon_joker: allow_joker.icon = icon_joker
		allow_joker.expand_icon = true
		allow_joker.add_theme_constant_override("icon_max_width", 48)

func get_allowed_tiles() -> Array:
	var tiles: Array = []
	if allow_zero and allow_zero.button_pressed: tiles.append(0)
	if allow_one and allow_one.button_pressed: tiles.append(1)
	if allow_joker and allow_joker.button_pressed: tiles.append(2)
	
	# Updated fallback to include Joker (2)
	if tiles.size() == 0: tiles = [0, 1, 2] 
	return tiles

func set_allowed_tiles(tiles: Array):
	if allow_zero: allow_zero.button_pressed = (0 in tiles)
	if allow_one: allow_one.button_pressed = (1 in tiles)
	if allow_joker: allow_joker.button_pressed = (2 in tiles)

func get_time_limit() -> int:
	return editor_time_limit
	
func set_time_limit(val: int):
	editor_time_limit = max(0, val)
	_update_number_labels()

func update_dynamic_editor_layout(_board_y: float = 0.0, _board_height: float = 0.0) -> void:
	_update_panel_layout(editor_width, editor_height)

func _setup_brush_toggles():
	var brushes = [wall_button, empty_button, zero_button, one_button, joker_button, shifter_button, equals_button, not_equals_button]
	for btn in brushes:
		if btn:
			btn.toggle_mode = true
			btn.button_group = brush_button_group
	if empty_button:
		empty_button.button_pressed = true

func sync_size_displays(new_w: int, new_h: int):
	editor_width = new_w
	editor_height = new_h
	_update_number_labels()
	_update_panel_layout(editor_width, editor_height)

func _update_number_labels():
	if width_label: width_label.text = "X: " + str(editor_width)
	if height_label: height_label.text = "Y: " + str(editor_height)
	if level_label: level_label.text = "Lvl: " + str(editor_level)
	if time_label:
		if editor_time_limit == 0:
			time_label.text = "Time: ∞"
		else:
			time_label.text = "Time: " + str(editor_time_limit) + "s"

func _update_panel_layout(_grid_width: int, _grid_height: int):
	var screen_width = get_viewport().get_visible_rect().size.x
	var screen_height = get_viewport().get_visible_rect().size.y
	
	var panel_width = screen_width
	var panel_height = 680.0
	var panel_x = 0.0
	var control_panel_y = screen_height - panel_height
	
	var square_btns = [width_minus, width_plus, height_minus, height_plus, level_minus, level_plus, time_minus, time_plus]
	
	var control_panel = editor_ui_root.find_child("ControlPanel", true, false)
	if control_panel:
		control_panel.global_position = Vector2(panel_x, control_panel_y)
		control_panel.set_deferred("size", Vector2(panel_width, panel_height)) 
		
	if level_settings_container:
		level_settings_container.position = Vector2(40, 260)
		level_settings_container.set_deferred("size", Vector2(panel_width - 80, 80))
		for child in level_settings_container.get_children():
			if child is Control:
				if child in square_btns:
					child.size_flags_horizontal = 0
					child.custom_minimum_size = Vector2(80, 80)
				else:
					child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					child.custom_minimum_size = Vector2(0, 80)
				if child is Button or child is Label or child is CheckBox:
					if not child.has_theme_font_size_override("font_size"):
						child.add_theme_font_size_override("font_size", 28)
				if child is Label:
					child.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					child.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var core_container = get_tree().current_scene.find_child("CoreLevelsContainer", true, false)
	if core_container:
		core_container.global_position = Vector2(panel_x + 40, control_panel_y + 550)
		core_container.size = Vector2(panel_width - 80, 80)
		if core_container is BoxContainer:
			core_container.alignment = BoxContainer.ALIGNMENT_BEGIN
			core_container.add_theme_constant_override("separation", 20)
					
	if grid_size_container:
		grid_size_container.position = Vector2(40, 20)
		grid_size_container.set_deferred("size", Vector2(panel_width - 80, 80))
		for child in grid_size_container.get_children():
			if child is Control:
				if child in square_btns:
					child.size_flags_horizontal = 0
					child.custom_minimum_size = Vector2(80, 80)
				else:
					child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					child.custom_minimum_size = Vector2(0, 80)
				if child is Button or child is Label:
					if not child.has_theme_font_size_override("font_size"):
						child.add_theme_font_size_override("font_size", 28)
				if child is Label:
					child.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					child.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	if brush_container:
		brush_container.position = Vector2(40, 130)
		brush_container.set_deferred("size", Vector2(panel_width - 80, 80))
		for btn in brush_container.get_children():
			if btn is Button:
				btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				btn.custom_minimum_size = Vector2(0, 80) 
				btn.expand_icon = true
				btn.add_theme_constant_override("icon_max_width", 56)
				btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				if not btn.has_theme_font_size_override("font_size"):
					btn.add_theme_font_size_override("font_size", 28)

	var config_container = editor_ui_root.find_child("ConfigContainer", true, false)
	if config_container:
		config_container.position = Vector2(40, 370)
		config_container.set_deferred("size", Vector2(panel_width - 80, 80))
		for child in config_container.get_children():
			if child is Control:
				if child in square_btns:
					child.size_flags_horizontal = 0
					child.custom_minimum_size = Vector2(80, 80)
				else:
					child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					child.custom_minimum_size = Vector2(0, 80)
				if child is Button or child is Label:
					if not child.has_theme_font_size_override("font_size"):
						child.add_theme_font_size_override("font_size", 28)
				if child is Label:
					child.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					child.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					
	if status_label:
		status_label.position = Vector2(40, 470)
		status_label.set_deferred("size", Vector2(panel_width - 80, 100))
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		if not status_label.has_theme_font_size_override("font_size"):
			status_label.add_theme_font_size_override("font_size", 28)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _set_button_labels():
	if clear_button: clear_button.text = "🗑️ CLEAR"
	if wall_button: 
		wall_button.text = ""
		if icon_wall: wall_button.icon = icon_wall
	if empty_button: 
		empty_button.text = ""
		if icon_empty: empty_button.icon = icon_empty
	if zero_button: 
		zero_button.text = ""
		if icon_zero: zero_button.icon = icon_zero
	if one_button: 
		one_button.text = ""
		if icon_one: one_button.icon = icon_one
	if joker_button: 
		joker_button.text = ""
		if icon_joker: joker_button.icon = icon_joker
	if shifter_button:
		shifter_button.text = ""
		var tex_shifter_icon = load("res://icons/tiles/tile_purple.svg")
		if tex_shifter_icon: shifter_button.icon = tex_shifter_icon
		
	if equals_button:
		equals_button.text = "="
		equals_button.add_theme_font_size_override("font_size", 44)
	if not_equals_button:
		not_equals_button.text = "×"
		not_equals_button.add_theme_font_size_override("font_size", 44)
	
	if save_button: save_button.text = "💾 SAVE" 
	if load_button: load_button.text = "📂 LOAD"
	if test_button: test_button.text = "▶️ TEST"
	if exit_test_button: exit_test_button.text = "⏹️ EXIT TEST"
	if set_size_button: set_size_button.text = "✅ SET" 
	
	if width_minus: width_minus.text = "-"
	if width_plus: width_plus.text = "+"
	if height_minus: height_minus.text = "-"
	if height_plus: height_plus.text = "+"
	if level_minus: level_minus.text = "-"
	if level_plus: level_plus.text = "+"
	if time_minus: time_minus.text = "-"
	if time_plus: time_plus.text = "+"

func _connect_ui_signals():
	if clear_button: clear_button.pressed.connect(func(): clear_requested.emit()) 
	
	wall_button.pressed.connect(func(): brush_changed.emit(-2, "Wall"))
	empty_button.pressed.connect(func(): brush_changed.emit(-1, "Empty (Clear)"))
	zero_button.pressed.connect(func(): brush_changed.emit(0, "Prefilled Zero"))
	one_button.pressed.connect(func(): brush_changed.emit(1, "Prefilled One"))
	joker_button.pressed.connect(func(): brush_changed.emit(2, "Joker"))
	if shifter_button: shifter_button.pressed.connect(func(): brush_changed.emit(3, "Shifter Pair Link Tool"))
	
	if equals_button: equals_button.pressed.connect(func(): brush_changed.emit(4, "Equals (=) Link Tool"))
	if not_equals_button: not_equals_button.pressed.connect(func(): brush_changed.emit(5, "Not Equals (×) Link Tool"))
	
	save_button.pressed.connect(func(): save_requested.emit())
	if load_button: load_button.pressed.connect(func(): load_requested.emit()) 
	if main_menu_button: main_menu_button.pressed.connect(func(): main_menu_requested.emit())
	test_button.pressed.connect(func(): test_mode_entered.emit())
	exit_test_button.pressed.connect(func(): test_mode_exited.emit())
	return_button.pressed.connect(func(): test_mode_exited.emit())
	
	if set_size_button: set_size_button.pressed.connect(_on_set_size_pressed)
	if width_minus: width_minus.pressed.connect(func(): _adjust_value("width", -1))
	if width_plus: width_plus.pressed.connect(func(): _adjust_value("width", 1))
	if height_minus: height_minus.pressed.connect(func(): _adjust_value("height", -1))
	if height_plus: height_plus.pressed.connect(func(): _adjust_value("height", 1))
	if level_minus: level_minus.pressed.connect(func(): _adjust_value("level", -1))
	if level_plus: level_plus.pressed.connect(func(): _adjust_value("level", 1))
	
	if time_minus: time_minus.pressed.connect(func(): _adjust_value("time", -30))
	if time_plus: time_plus.pressed.connect(func(): _adjust_value("time", 30))

func _adjust_value(target: String, amount: int):
	match target:
		"width": editor_width = clamp(editor_width + amount, MIN_GRID_WIDTH, MAX_GRID_WIDTH) 
		"height": editor_height = clamp(editor_height + amount, MIN_GRID_HEIGHT, MAX_GRID_HEIGHT)
		"level": editor_level = max(1, editor_level + amount) 
		"time": editor_time_limit = max(0, editor_time_limit + amount)
	_update_number_labels()

func _on_set_size_pressed():
	_update_panel_layout(editor_width, editor_height)
	grid_size_changed.emit(editor_width, editor_height)

func update_status(msg: String, text_color: Color):
	if status_label:
		status_label.text = msg
		status_label.modulate = text_color
		status_label.add_theme_font_size_override("font_size", 28)

func toggle_playtest_visibility(is_playtesting: bool):
	brush_container.visible = not is_playtesting
	save_button.visible = not is_playtesting
	if load_button: load_button.visible = not is_playtesting
	if main_menu_button: main_menu_button.visible = not is_playtesting
	if clear_button: clear_button.visible = not is_playtesting
	test_button.visible = not is_playtesting
	
	if level_minus: level_minus.visible = not is_playtesting
	if level_label: level_label.visible = not is_playtesting
	if level_plus: level_plus.visible = not is_playtesting
	if grid_size_container: grid_size_container.visible = not is_playtesting 
	
	if level_settings_container: level_settings_container.visible = not is_playtesting
	if playtest_hud_container: playtest_hud_container.visible = is_playtesting
	
	exit_test_button.visible = is_playtesting

func display_victory_overlay(compiled_text: String):
	if victory_message_label:
		victory_message_label.text = compiled_text
		if "DEFEAT" in compiled_text:
			victory_message_label.modulate = Color(1.0, 0.3, 0.3) 
		else:
			victory_message_label.modulate = Color(0.4, 1.0, 0.4) 
	if playtest_victory_panel:
		playtest_victory_panel.visible = true

func hide_victory_overlay():
	if playtest_victory_panel: playtest_victory_panel.visible = false

func get_level_number() -> int:
	return editor_level
