class_name EditorUIManager
extends Node

signal brush_changed(state_id: int, brush_name: String)
signal save_requested
signal load_requested
signal clear_requested
signal main_menu_requested
signal test_mode_entered
signal test_mode_exited
signal grid_size_changed(new_width: int, new_height: int) 

@export var icon_empty: Texture2D
@export var icon_wall: Texture2D
@export var icon_zero: Texture2D
@export var icon_one: Texture2D
@export var icon_joker: Texture2D

@onready var grid_size_container = $"../EditorUI/ControlPanel/GridSizeContainer"

@onready var width_minus = $"../EditorUI/ControlPanel/GridSizeContainer/WidthMinus"
@onready var width_label = $"../EditorUI/ControlPanel/GridSizeContainer/WidthLabel"
@onready var width_plus = $"../EditorUI/ControlPanel/GridSizeContainer/WidthPlus"

@onready var height_minus = $"../EditorUI/ControlPanel/GridSizeContainer/HeightMinus"
@onready var height_label = $"../EditorUI/ControlPanel/GridSizeContainer/HeightLabel"
@onready var height_plus = $"../EditorUI/ControlPanel/GridSizeContainer/HeightPlus"

@onready var set_size_button = $"../EditorUI/ControlPanel/GridSizeContainer/SetSizeButton" 

@onready var level_minus = $"../EditorUI/ControlPanel/ConfigContainer/LevelMinus"
@onready var level_label = $"../EditorUI/ControlPanel/ConfigContainer/LevelLabel"
@onready var level_plus = $"../EditorUI/ControlPanel/ConfigContainer/LevelPlus"

@onready var status_label = $"../EditorUI/ControlPanel/StatusLabel"

@onready var brush_container = $"../EditorUI/ControlPanel/BrushContainer"

@onready var clear_button = $"../EditorUI/ControlPanel/BrushContainer/ClearButton" 
@onready var empty_button = $"../EditorUI/ControlPanel/BrushContainer/EmptyButton"
@onready var wall_button = $"../EditorUI/ControlPanel/BrushContainer/WallButton"
@onready var zero_button = $"../EditorUI/ControlPanel/BrushContainer/ZeroButton"
@onready var one_button = $"../EditorUI/ControlPanel/BrushContainer/OneButton"
@onready var joker_button = $"../EditorUI/ControlPanel/BrushContainer/JokerButton"

@onready var save_button = $"../EditorUI/ControlPanel/ConfigContainer/SaveButton"
@onready var load_button = $"../EditorUI/ControlPanel/ConfigContainer/LoadButton"
@onready var main_menu_button = $"../EditorUI/ControlPanel/ConfigContainer/MainMenuButton" 
@onready var test_button = $"../EditorUI/ControlPanel/ConfigContainer/TestButton"
@onready var exit_test_button = $"../EditorUI/ControlPanel/ConfigContainer/ExitTestButton"

@onready var playtest_victory_panel = $"../EditorUI/PlaytestVictoryPanel"
@onready var layout_text_edit = $"../EditorUI/PlaytestVictoryPanel/LayoutTextEdit"
@onready var return_button = $"../EditorUI/PlaytestVictoryPanel/ReturnButton"

var _cell_size: float = 120.0
var editor_width: int = 3
var editor_height: int = 3
var editor_level: int = 1

var brush_button_group: ButtonGroup = ButtonGroup.new()

var _last_board_y: float = 180.0
var _last_board_height: float = 0.0

var allowed_tiles_container: HBoxContainer
var allow_zero_chk: CheckBox
var allow_one_chk: CheckBox
var allow_joker_chk: CheckBox

func setup_ui(grid_width: int, grid_height: int, cell_size: float):
	_cell_size = cell_size
	editor_width = grid_width
	editor_height = grid_height
	
	_setup_brush_toggles()
	_build_allowed_tiles_ui()
	emit_signal("brush_changed", -1, "Empty (Clear)")
	
	_update_number_labels()
	_update_panel_layout(grid_width, grid_height)
	
	if playtest_victory_panel:
		playtest_victory_panel.visible = false
		var screen_width = get_viewport().get_visible_rect().size.x
		var victory_x = (screen_width - 500) / 2.0
		playtest_victory_panel.global_position = Vector2(victory_x, 250)
		playtest_victory_panel.set_deferred("size", Vector2(500, 450))
		
	if layout_text_edit:
		layout_text_edit.set_deferred("custom_minimum_size", Vector2(460, 300))
		layout_text_edit.position = Vector2(20, 20)
		layout_text_edit.editable = false
		
	if return_button:
		return_button.position = Vector2(100, 360)
		return_button.set_deferred("size", Vector2(300, 60))
		return_button.add_theme_font_size_override("font_size", 24)
	
	if exit_test_button:
		exit_test_button.visible = false
	
	_set_button_labels()
	_connect_ui_signals()

# ==========================================
# DYNAMIC CHECKBOX BUILDER WITH EXPLICIT SVGS & TEXT
# ==========================================
func _build_allowed_tiles_ui():
	var control_panel = $"../EditorUI/ControlPanel"
	if not control_panel: return
	
	var tex_red = load("res://icons/tiles/tile_red.svg")
	var tex_blue = load("res://icons/tiles/tile_blue.svg")
	var tex_green = load("res://icons/tiles/tile_green.svg") 
	
	allowed_tiles_container = HBoxContainer.new()
	allowed_tiles_container.name = "AllowedTilesContainer"
	control_panel.add_child(allowed_tiles_container)
	
	var lbl = Label.new()
	lbl.text = "Allowed Tiles:"
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	allowed_tiles_container.add_child(lbl)
	
	allow_zero_chk = CheckBox.new()
	allow_zero_chk.text = " RED"
	if tex_red: allow_zero_chk.icon = tex_red
	elif icon_zero: allow_zero_chk.icon = icon_zero
	allow_zero_chk.expand_icon = true
	allow_zero_chk.add_theme_constant_override("icon_max_width", 32)
	allow_zero_chk.button_pressed = true
	allow_zero_chk.add_theme_font_size_override("font_size", 22)
	allow_zero_chk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	allowed_tiles_container.add_child(allow_zero_chk)
	
	allow_one_chk = CheckBox.new()
	allow_one_chk.text = " BLUE"
	if tex_blue: allow_one_chk.icon = tex_blue
	elif icon_one: allow_one_chk.icon = icon_one
	allow_one_chk.expand_icon = true
	allow_one_chk.add_theme_constant_override("icon_max_width", 32)
	allow_one_chk.button_pressed = true
	allow_one_chk.add_theme_font_size_override("font_size", 22)
	allow_one_chk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	allowed_tiles_container.add_child(allow_one_chk)
	
	allow_joker_chk = CheckBox.new()
	allow_joker_chk.text = " GREEN"
	if tex_green: allow_joker_chk.icon = tex_green
	elif icon_joker: allow_joker_chk.icon = icon_joker
	allow_joker_chk.expand_icon = true
	allow_joker_chk.add_theme_constant_override("icon_max_width", 32)
	allow_joker_chk.button_pressed = false
	allow_joker_chk.add_theme_font_size_override("font_size", 22)
	allow_joker_chk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	allowed_tiles_container.add_child(allow_joker_chk)

func get_allowed_tiles() -> Array[int]:
	var tiles: Array[int] = []
	if allow_zero_chk and allow_zero_chk.button_pressed: tiles.append(0)
	if allow_one_chk and allow_one_chk.button_pressed: tiles.append(1)
	if allow_joker_chk and allow_joker_chk.button_pressed: tiles.append(2)
	
	if tiles.size() == 0: tiles = [0, 1] 
	return tiles

func set_allowed_tiles(tiles: Array[int]):
	if allow_zero_chk: allow_zero_chk.button_pressed = (0 in tiles)
	if allow_one_chk: allow_one_chk.button_pressed = (1 in tiles)
	if allow_joker_chk: allow_joker_chk.button_pressed = (2 in tiles)

func update_dynamic_editor_layout(board_y: float, board_height: float) -> void:
	_last_board_y = board_y
	_last_board_height = board_height
	_update_panel_layout(editor_width, editor_height)

func _setup_brush_toggles():
	var brushes = [empty_button, wall_button, zero_button, one_button, joker_button]
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
	if width_label: width_label.text = "W: " + str(editor_width)
	if height_label: height_label.text = "H: " + str(editor_height)
	if level_label: level_label.text = "Lvl: " + str(editor_level)

func _update_panel_layout(_grid_width: int, _grid_height: int):
	var board_bottom_y = _last_board_y + _last_board_height 
	var ui_margin_y = 30
	var screen_width = get_viewport().get_visible_rect().size.x
	
	var panel_width = screen_width
	var panel_x = 0.0
	
	var control_panel = $"../EditorUI/ControlPanel"
	if control_panel:
		control_panel.global_position = Vector2(panel_x, board_bottom_y + ui_margin_y)
		control_panel.set_deferred("size", Vector2(panel_width, 540)) 
		
	if allowed_tiles_container:
		allowed_tiles_container.position = Vector2(40, 260)
		allowed_tiles_container.set_deferred("size", Vector2(panel_width - 80, 60))

	var core_container = get_tree().current_scene.find_child("CoreLevelsContainer", true, false)
	if core_container:
		core_container.global_position = Vector2(panel_x + 40, board_bottom_y + ui_margin_y + 340)
		core_container.size = Vector2(panel_width - 80, 70)
		
		if core_container is BoxContainer:
			core_container.alignment = BoxContainer.ALIGNMENT_BEGIN
			core_container.add_theme_constant_override("separation", 15)
	
	if grid_size_container:
		grid_size_container.position = Vector2(40, 20)
		grid_size_container.set_deferred("size", Vector2(panel_width - 80, 60))
		for child in grid_size_container.get_children():
			if child is Control:
				child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				if child is Button or child is Label:
					child.custom_minimum_size = Vector2(0, 60)
					if not child.has_theme_font_size_override("font_size"):
						child.add_theme_font_size_override("font_size", 24)
						
				if child is Label:
					child.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					child.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	if brush_container:
		brush_container.position = Vector2(40, 100)
		brush_container.set_deferred("size", Vector2(panel_width - 80, 60))
		for btn in brush_container.get_children():
			if btn is Button:
				btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				btn.custom_minimum_size = Vector2(0, 60) 
				btn.expand_icon = true
				btn.add_theme_constant_override("icon_max_width", 48)
				btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				
				if not btn.has_theme_font_size_override("font_size"):
					btn.add_theme_font_size_override("font_size", 22)
				
	var config_container = $"../EditorUI/ControlPanel/ConfigContainer"
	if config_container:
		config_container.position = Vector2(40, 180)
		config_container.set_deferred("size", Vector2(panel_width - 80, 60))
		for child in config_container.get_children():
			if child is Control:
				child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				if child is Button or child is Label:
					child.custom_minimum_size = Vector2(0, 60) 
					if not child.has_theme_font_size_override("font_size"):
						child.add_theme_font_size_override("font_size", 22)
						
				if child is Label:
					child.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					child.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					
	if status_label:
		status_label.position = Vector2(40, 430)
		status_label.set_deferred("size", Vector2(panel_width - 80, 90))
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		if not status_label.has_theme_font_size_override("font_size"):
			status_label.add_theme_font_size_override("font_size", 22)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _set_button_labels():
	if empty_button: 
		empty_button.text = ""
		if icon_empty: empty_button.icon = icon_empty
			
	if wall_button: 
		wall_button.text = ""
		if icon_wall: wall_button.icon = icon_wall
			
	if zero_button: 
		zero_button.text = ""
		if icon_zero: zero_button.icon = icon_zero
			
	if one_button: 
		one_button.text = ""
		if icon_one: one_button.icon = icon_one
			
	if joker_button: 
		joker_button.text = ""
		if icon_joker: joker_button.icon = icon_joker
	
	if clear_button: clear_button.text = "🗑️ CLEAR"
	
	if save_button: save_button.text = "💾 SAVE" 
	if load_button: load_button.text = "📂 LOAD"
	if main_menu_button: main_menu_button.text = "🏠 Menu"
	if test_button: test_button.text = "▶️ TEST"
	if exit_test_button: exit_test_button.text = "⏹️ EXIT TEST"
	if set_size_button: set_size_button.text = "✅ SET" 
	
	if width_minus: width_minus.text = "-"
	if width_plus: width_plus.text = "+"
	if height_minus: height_minus.text = "-"
	if height_plus: height_plus.text = "+"
	if level_minus: level_minus.text = "-"
	if level_plus: level_plus.text = "+"

func _connect_ui_signals():
	empty_button.pressed.connect(func(): brush_changed.emit(-1, "Empty (Clear)"))
	wall_button.pressed.connect(func(): brush_changed.emit(-2, "Wall"))
	zero_button.pressed.connect(func(): brush_changed.emit(0, "Prefilled 0"))
	one_button.pressed.connect(func(): brush_changed.emit(1, "Prefilled 1"))
	joker_button.pressed.connect(func(): brush_changed.emit(2, "Joker"))
	
	if clear_button: clear_button.pressed.connect(func(): clear_requested.emit()) 
	
	save_button.pressed.connect(func(): save_requested.emit())
	if load_button: load_button.pressed.connect(func(): load_requested.emit()) 
	if main_menu_button: main_menu_button.pressed.connect(func(): main_menu_requested.emit())
	test_button.pressed.connect(func(): test_mode_entered.emit())
	exit_test_button.pressed.connect(func(): test_mode_exited.emit())
	return_button.pressed.connect(func(): test_mode_exited.emit())
	
	if set_size_button:
		set_size_button.pressed.connect(_on_set_size_pressed)
		
	if width_minus: width_minus.pressed.connect(func(): _adjust_value("width", -1))
	if width_plus: width_plus.pressed.connect(func(): _adjust_value("width", 1))
	if height_minus: height_minus.pressed.connect(func(): _adjust_value("height", -1))
	if height_plus: height_plus.pressed.connect(func(): _adjust_value("height", 1))
	if level_minus: level_minus.pressed.connect(func(): _adjust_value("level", -1))
	if level_plus: level_plus.pressed.connect(func(): _adjust_value("level", 1))

func _adjust_value(target: String, amount: int):
	match target:
		"width":
			editor_width = clamp(editor_width + amount, 3, 9) 
		"height":
			editor_height = clamp(editor_height + amount, 3, 11)
		"level":
			editor_level = max(1, editor_level + amount) 
			
	_update_number_labels()

func _on_set_size_pressed():
	_update_panel_layout(editor_width, editor_height)
	grid_size_changed.emit(editor_width, editor_height)

func update_status(msg: String, text_color: Color):
	if status_label:
		status_label.text = msg
		status_label.modulate = text_color
		status_label.add_theme_font_size_override("font_size", 22)

func toggle_playtest_visibility(is_playtesting: bool):
	brush_container.visible = not is_playtesting
	save_button.visible = not is_playtesting
	if load_button: load_button.visible = not is_playtesting
	if main_menu_button: main_menu_button.visible = not is_playtesting
	test_button.visible = not is_playtesting
	
	if level_minus: level_minus.visible = not is_playtesting
	if level_label: level_label.visible = not is_playtesting
	if level_plus: level_plus.visible = not is_playtesting
	if grid_size_container: grid_size_container.visible = not is_playtesting 
	
	if allowed_tiles_container: allowed_tiles_container.visible = not is_playtesting
	
	exit_test_button.visible = is_playtesting

func display_victory_overlay(compiled_text: String):
	if layout_text_edit: layout_text_edit.text = compiled_text
	if playtest_victory_panel: playtest_victory_panel.visible = true

func hide_victory_overlay():
	if playtest_victory_panel: playtest_victory_panel.visible = false

func get_level_number() -> int:
	return editor_level
