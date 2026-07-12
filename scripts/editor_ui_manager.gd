class_name EditorUIManager
extends Node

signal brush_changed(state_id: int, brush_name: String)
signal save_requested
signal main_menu_requested
signal test_mode_entered
signal test_mode_exited

@onready var level_spin_box = $"../EditorUI/ControlPanel/ConfigContainer/LevelSpinBox"
@onready var status_label = $"../EditorUI/ControlPanel/StatusLabel"

@onready var empty_button = $"../EditorUI/ControlPanel/BrushContainer/EmptyButton"
@onready var wall_button = $"../EditorUI/ControlPanel/BrushContainer/WallButton"
@onready var zero_button = $"../EditorUI/ControlPanel/BrushContainer/ZeroButton"
@onready var one_button = $"../EditorUI/ControlPanel/BrushContainer/OneButton"
@onready var joker_button = $"../EditorUI/ControlPanel/BrushContainer/JokerButton"

@onready var save_button = $"../EditorUI/ControlPanel/ConfigContainer/SaveButton"
@onready var main_menu_button = $"../EditorUI/ControlPanel/ConfigContainer/MainMenuButton"
@onready var test_button = $"../EditorUI/ControlPanel/ConfigContainer/TestButton"
@onready var exit_test_button = $"../EditorUI/ControlPanel/ConfigContainer/ExitTestButton"

@onready var brush_container = $"../EditorUI/ControlPanel/BrushContainer"
@onready var playtest_victory_panel = $"../EditorUI/PlaytestVictoryPanel"
@onready var layout_text_edit = $"../EditorUI/PlaytestVictoryPanel/LayoutTextEdit"
@onready var return_button = $"../EditorUI/PlaytestVictoryPanel/ReturnButton"

func setup_ui(grid_width: int, grid_height: int, cell_size: float):
	emit_signal("brush_changed", -1, "Empty (Clear)")
	
	var board_bottom_y = 180 + (grid_height * cell_size) 
	var ui_margin_y = 30
	var panel_width = grid_width * cell_size
	
	var control_panel = $"../EditorUI/ControlPanel"
	if control_panel:
		control_panel.global_position = Vector2(120, board_bottom_y + ui_margin_y)
		control_panel.set_deferred("size", Vector2(panel_width, 280))
	
	if brush_container:
		brush_container.position = Vector2(20, 30)
		brush_container.set_deferred("size", Vector2(panel_width - 40, 50))
		for btn in brush_container.get_children():
			if btn is Button:
				btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				btn.add_theme_font_size_override("font_size", 20)
				
	var config_container = $"../EditorUI/ControlPanel/ConfigContainer"
	if config_container:
		config_container.position = Vector2(20, 100)
		config_container.set_deferred("size", Vector2(panel_width - 40, 50))
		for child in config_container.get_children():
			if child is Control:
				child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				if child is Button or child is Label:
					child.add_theme_font_size_override("font_size", 18)
					
	if status_label:
		status_label.position = Vector2(20, 170)
		status_label.set_deferred("size", Vector2(panel_width - 40, 90))
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		status_label.add_theme_font_size_override("font_size", 22)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	if playtest_victory_panel:
		playtest_victory_panel.visible = false
		playtest_victory_panel.global_position = Vector2(120, 250)
		playtest_victory_panel.set_deferred("size", Vector2(500, 450))
		
	if layout_text_edit:
		layout_text_edit.set_deferred("custom_minimum_size", Vector2(460, 300))
		layout_text_edit.position = Vector2(20, 20)
		layout_text_edit.editable = false
		
	if return_button:
		return_button.position = Vector2(100, 360)
		return_button.set_deferred("size", Vector2(300, 50))
	
	if exit_test_button:
		exit_test_button.visible = false
	
	_set_button_labels()
	_connect_ui_signals()

func _set_button_labels():
	if empty_button: empty_button.text = "Empty"
	if wall_button: wall_button.text = "Wall (-2)"
	if zero_button: zero_button.text = "Fixed 0"
	if one_button: one_button.text = "Fixed 1"
	if joker_button: joker_button.text = "Joker (2)"
	if save_button: save_button.text = "SAVE LEVEL"
	if main_menu_button: main_menu_button.text = "Main Menu"
	if test_button: test_button.text = "TEST LEVEL"
	if exit_test_button: exit_test_button.text = "EXIT TEST"

func _connect_ui_signals():
	empty_button.pressed.connect(func(): brush_changed.emit(-1, "Empty (Clear)"))
	wall_button.pressed.connect(func(): brush_changed.emit(-2, "Wall"))
	zero_button.pressed.connect(func(): brush_changed.emit(0, "Prefilled 0"))
	one_button.pressed.connect(func(): brush_changed.emit(1, "Prefilled 1"))
	joker_button.pressed.connect(func(): brush_changed.emit(2, "Joker"))
	
	save_button.pressed.connect(func(): save_requested.emit())
	main_menu_button.pressed.connect(func(): main_menu_requested.emit())
	test_button.pressed.connect(func(): test_mode_entered.emit())
	exit_test_button.pressed.connect(func(): test_mode_exited.emit())
	return_button.pressed.connect(func(): test_mode_exited.emit())

func update_status(msg: String, text_color: Color):
	if status_label:
		status_label.text = msg
		status_label.modulate = text_color
		status_label.add_theme_font_size_override("font_size", 22)

func toggle_playtest_visibility(is_playtesting: bool):
	brush_container.visible = not is_playtesting
	save_button.visible = not is_playtesting
	test_button.visible = not is_playtesting
	main_menu_button.visible = not is_playtesting
	level_spin_box.visible = not is_playtesting
	exit_test_button.visible = is_playtesting

func display_victory_overlay(compiled_text: String):
	if layout_text_edit: layout_text_edit.text = compiled_text
	if playtest_victory_panel: playtest_victory_panel.visible = true

func hide_victory_overlay():
	if playtest_victory_panel: playtest_victory_panel.visible = false

func get_level_number() -> int:
	return int(level_spin_box.value) if level_spin_box else 1
