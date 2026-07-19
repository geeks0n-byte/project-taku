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

signal playtest_reset_requested 
signal playtest_rules_requested 
signal playtest_hint_requested 
signal playtest_undo_requested 
signal playtest_redo_requested 
signal resume_from_tutorial_requested 
signal allowed_tiles_changed 

const MIN_GRID_WIDTH: int = 3
const MAX_GRID_WIDTH: int = 9
const MIN_GRID_HEIGHT: int = 3
const MAX_GRID_HEIGHT: int = 9

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

@onready var level_settings_container = editor_ui_root.find_child("LevelSettingsContainer", true, false)
@onready var allow_zero = editor_ui_root.find_child("AllowZero", true, false)
@onready var allow_one = editor_ui_root.find_child("AllowOne", true, false)
@onready var allow_joker = editor_ui_root.find_child("AllowJoker", true, false)
@onready var time_minus = editor_ui_root.find_child("TimeMinus", true, false)
@onready var time_label = editor_ui_root.find_child("TimeLabel", true, false)
@onready var time_plus = editor_ui_root.find_child("TimePlus", true, false)

var time_title_label: Label 

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
var is_playtesting_mode: bool = false
var editor_cell_size: float = 64.0

var brush_button_group: ButtonGroup = ButtonGroup.new()

var playtest_hud_container: Control
var pt_timer_label: RichTextLabel 
var pt_moves_label: RichTextLabel
var pt_jokers_label: RichTextLabel 
var pt_status_label: RichTextLabel 
var pt_title_label: RichTextLabel 

var random_button: Button 
var unique_solution_toggle: CheckButton
var keep_walls_toggle: CheckButton

var pt_exit_button: Button
var pt_reset_button: Button
var pt_rules_button: Button
var pt_hint_button: Button
var pt_undo_button: Button
var pt_redo_button: Button

var how_to_play_container: Control
var tutorial_back_button: Button 

func setup_ui(grid_width: int, grid_height: int, _cell_size: float):
	editor_width = grid_width
	editor_height = grid_height
	editor_cell_size = _cell_size
	
	var root_parent = get_parent()
	var screen_width = get_viewport().get_visible_rect().size.x
	
	if grid_size_container:
		if not random_button:
			random_button = Button.new()
			random_button.text = "🎲 RANDOM"
			random_button.add_theme_font_size_override("font_size", 28)
			random_button.pressed.connect(func(): random_requested.emit())
			grid_size_container.add_child(random_button)
			
		if not unique_solution_toggle:
			unique_solution_toggle = CheckButton.new()
			unique_solution_toggle.text = "Unique\nSolution"
			unique_solution_toggle.alignment = HORIZONTAL_ALIGNMENT_CENTER
			unique_solution_toggle.button_pressed = false 
			unique_solution_toggle.add_theme_font_size_override("font_size", 24)
			grid_size_container.add_child(unique_solution_toggle)
			
		if not keep_walls_toggle:
			keep_walls_toggle = CheckButton.new()
			keep_walls_toggle.text = "Lock\nWalls"
			keep_walls_toggle.alignment = HORIZONTAL_ALIGNMENT_CENTER
			keep_walls_toggle.button_pressed = true 
			keep_walls_toggle.add_theme_font_size_override("font_size", 24)
			grid_size_container.add_child(keep_walls_toggle)
			
		var spacer1 = Control.new()
		spacer1.custom_minimum_size = Vector2(10, 0)
		grid_size_container.add_child(spacer1)
		
		var spacer2 = Control.new()
		spacer2.custom_minimum_size = Vector2(10, 0)
		grid_size_container.add_child(spacer2)
		
		var spacer3 = Control.new()
		spacer3.custom_minimum_size = Vector2(10, 0)
		grid_size_container.add_child(spacer3)
		
		var grid_children = [
			width_minus, width_label, width_plus, 
			spacer1, 
			height_minus, height_label, height_plus, 
			spacer2, 
			keep_walls_toggle, unique_solution_toggle, 
			spacer3, random_button
		]
		
		for i in range(grid_children.size()):
			if grid_children[i] and grid_children[i].get_parent() == grid_size_container:
				grid_size_container.move_child(grid_children[i], i)
			
	if level_settings_container:
		if time_minus:
			time_title_label = editor_ui_root.find_child("TimeTitleLabel", true, false)
			if not time_title_label:
				time_title_label = Label.new()
				time_title_label.name = "TimeTitleLabel"
				time_title_label.text = "TIME LIMIT:"
				level_settings_container.add_child(time_title_label)
			else:
				time_title_label.text = "TIME LIMIT:"
				
		var allowed_label = editor_ui_root.find_child("AllowedLabel", true, false)
		if not allowed_label:
			for child in level_settings_container.get_children():
				if child is Label and "ALLOWED" in child.text.to_upper():
					allowed_label = child
					break
		if allowed_label:
			allowed_label.text = "ALLOWED:"
			allowed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			
		var spacer_time = Control.new()
		spacer_time.custom_minimum_size = Vector2(40, 0)
		level_settings_container.add_child(spacer_time)
		
		var lvl_children = [time_title_label, time_minus, time_label, time_plus, spacer_time, allowed_label, allow_zero, allow_one, allow_joker]
		for i in range(lvl_children.size()):
			if lvl_children[i] and lvl_children[i].get_parent() == level_settings_container:
				level_settings_container.move_child(lvl_children[i], i)
	
	if not pt_exit_button: 
		pt_exit_button = Button.new()
		pt_exit_button.name = "PTExitButton"
		root_parent.add_child(pt_exit_button)
	pt_exit_button.text = "Exit Test"
	pt_exit_button.add_theme_font_size_override("font_size", 24)
	pt_exit_button.global_position = Vector2(30, 40)
	pt_exit_button.size = Vector2(130, 60)
	pt_exit_button.visible = false
	if not pt_exit_button.pressed.is_connected(func(): test_mode_exited.emit()):
		pt_exit_button.pressed.connect(func(): test_mode_exited.emit())
	
	if not pt_reset_button: pt_reset_button = Button.new(); pt_reset_button.name = "PTResetButton"; root_parent.add_child(pt_reset_button)
	pt_reset_button.text = "Reset"
	pt_reset_button.add_theme_font_size_override("font_size", 24)
	pt_reset_button.global_position = Vector2(170, 40)
	pt_reset_button.size = Vector2(130, 60)
	pt_reset_button.visible = false
	if not pt_reset_button.pressed.is_connected(func(): playtest_reset_requested.emit()):
		pt_reset_button.pressed.connect(func(): playtest_reset_requested.emit())
		
	if not pt_rules_button: pt_rules_button = Button.new(); pt_rules_button.name = "PTRulesButton"; root_parent.add_child(pt_rules_button)
	pt_rules_button.text = "Rules"
	pt_rules_button.add_theme_font_size_override("font_size", 24)
	pt_rules_button.global_position = Vector2(310, 40)
	pt_rules_button.size = Vector2(130, 60) 
	pt_rules_button.visible = false
	if not pt_rules_button.pressed.is_connected(func(): playtest_rules_requested.emit()):
		pt_rules_button.pressed.connect(func(): playtest_rules_requested.emit())
		
	if not pt_hint_button: pt_hint_button = Button.new(); pt_hint_button.name = "PTHintButton"; root_parent.add_child(pt_hint_button)
	pt_hint_button.text = "💡 Hint"
	pt_hint_button.add_theme_font_size_override("font_size", 24)
	pt_hint_button.global_position = Vector2(630, 40) 
	pt_hint_button.size = Vector2(140, 60)
	pt_hint_button.visible = false
	pt_hint_button.disabled = true
	if not pt_hint_button.pressed.is_connected(func(): playtest_hint_requested.emit()):
		pt_hint_button.pressed.connect(func(): playtest_hint_requested.emit())
		
	if not pt_undo_button: pt_undo_button = Button.new(); pt_undo_button.name = "PTUndoButton"; root_parent.add_child(pt_undo_button)
	pt_undo_button.text = "⟲ Undo"
	pt_undo_button.add_theme_font_size_override("font_size", 32)
	pt_undo_button.global_position = Vector2(780, 40) 
	pt_undo_button.size = Vector2(130, 60)
	pt_undo_button.visible = false
	pt_undo_button.disabled = true
	if not pt_undo_button.pressed.is_connected(func(): playtest_undo_requested.emit()):
		pt_undo_button.pressed.connect(func(): playtest_undo_requested.emit())
		
	if not pt_redo_button: pt_redo_button = Button.new(); pt_redo_button.name = "PTRedoButton"; root_parent.add_child(pt_redo_button)
	pt_redo_button.text = "Redo ⟳"
	pt_redo_button.add_theme_font_size_override("font_size", 32)
	pt_redo_button.global_position = Vector2(920, 40) 
	pt_redo_button.size = Vector2(130, 60)
	pt_redo_button.visible = false
	pt_redo_button.disabled = true
	if not pt_redo_button.pressed.is_connected(func(): playtest_redo_requested.emit()):
		pt_redo_button.pressed.connect(func(): playtest_redo_requested.emit())
	
	_setup_brush_toggles()
	_setup_tree_checkbox_icons()
	_build_playtest_hud() 
	emit_signal("brush_changed", -1, "Empty (Clear)")
	
	_update_number_labels()
	_update_panel_layout(grid_width, grid_height)
	
	if main_menu_button:
		main_menu_button.text = "🏠 Menu"
		main_menu_button.custom_minimum_size = Vector2(160, 70)
		main_menu_button.add_theme_font_size_override("font_size", 32)
		
		var core_container = get_tree().current_scene.find_child("CoreLevelsContainer", true, false)
		if core_container and main_menu_button.get_parent() != core_container:
			main_menu_button.get_parent().remove_child(main_menu_button)
			core_container.add_child(main_menu_button)
		
	if clear_button:
		clear_button.global_position = Vector2(340, 40)
		clear_button.size = Vector2(200, 70)
		clear_button.add_theme_font_size_override("font_size", 32)
	
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
		if not return_button.pressed.is_connected(_on_return_pressed):
			return_button.pressed.connect(_on_return_pressed)
		
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
		if not confirm_button.pressed.is_connected(_on_confirm_overwrite):
			confirm_button.pressed.connect(_on_confirm_overwrite)
		
	if cancel_button:
		cancel_button.add_theme_font_size_override("font_size", 32)
		cancel_button.custom_minimum_size = Vector2(200, 80)
		if not cancel_button.pressed.is_connected(_on_cancel_overwrite):
			cancel_button.pressed.connect(_on_cancel_overwrite)
		
	var button_row = editor_ui_root.find_child("ButtonRow", true, false)
	if button_row:
		button_row.position = Vector2(50, 240)
		button_row.set_deferred("size", Vector2(500, 80))
		button_row.alignment = BoxContainer.ALIGNMENT_CENTER
		button_row.add_theme_constant_override("separation", 60)
	
	how_to_play_container = root_parent.get_node_or_null("HowToPlayLayer/CenterContainer")
	var how_to_play_panel = root_parent.get_node_or_null("HowToPlayLayer/CenterContainer/HowToPlayPanel")
	var rules_label = root_parent.get_node_or_null("HowToPlayLayer/CenterContainer/HowToPlayPanel/RulesLabel")
	tutorial_back_button = root_parent.get_node_or_null("HowToPlayLayer/CenterContainer/HowToPlayPanel/BackButton")
	
	var tutorial_size = Vector2(850, 1200) 
	if how_to_play_panel:
		how_to_play_panel.custom_minimum_size = tutorial_size
		how_to_play_panel.size = tutorial_size
		var solid_style = StyleBoxFlat.new()
		solid_style.bg_color = Color(0.12, 0.12, 0.12, 1.0) 
		how_to_play_panel.add_theme_stylebox_override("panel", solid_style)
		if how_to_play_container:
			how_to_play_container.visible = false
		
	if rules_label:
		rules_label.position = Vector2(30, 30)
		rules_label.size = Vector2(790, 1090) 
			
	if tutorial_back_button:
		var btn_size = Vector2(140, 50)
		tutorial_back_button.size = btn_size
		var btn_x = (tutorial_size.x - btn_size.x) / 2
		var btn_y = tutorial_size.y - btn_size.y - 30
		tutorial_back_button.position = Vector2(btn_x, btn_y)
		if not tutorial_back_button.pressed.is_connected(_on_tutorial_back_pressed):
			tutorial_back_button.pressed.connect(_on_tutorial_back_pressed)
			
	if status_label:
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if status_label is RichTextLabel: 
			status_label.bbcode_enabled = true
			status_label.fit_content = true
			status_label.add_theme_font_size_override("normal_font_size", 32)
		else:
			status_label.add_theme_font_size_override("font_size", 32)
	
	_set_button_labels()
	_connect_ui_signals()

func _on_return_pressed():
	hide_victory_overlay()
	test_mode_exited.emit()
	
func _on_confirm_overwrite():
	overwrite_panel.visible = false
	overwrite_confirmed.emit()

func _on_cancel_overwrite():
	overwrite_panel.visible = false

func _on_tutorial_back_pressed():
	if how_to_play_container: how_to_play_container.visible = false
	if pt_reset_button: pt_reset_button.disabled = false
	if pt_rules_button: pt_rules_button.disabled = false
	if pt_hint_button: pt_hint_button.disabled = false
	if pt_undo_button: pt_undo_button.disabled = false
	if pt_redo_button: pt_redo_button.disabled = false
	if pt_exit_button: pt_exit_button.disabled = false
	resume_from_tutorial_requested.emit()

func is_unique_solution_required() -> bool:
	if unique_solution_toggle: return unique_solution_toggle.button_pressed
	return false 
	
func is_keep_walls_requested() -> bool:
	if keep_walls_toggle: return keep_walls_toggle.button_pressed
	return true 

func show_how_to_play():
	if how_to_play_container:
		how_to_play_container.visible = true
	if pt_reset_button: pt_reset_button.disabled = true
	if pt_rules_button: pt_rules_button.disabled = true
	if pt_hint_button: pt_hint_button.disabled = true
	if pt_undo_button: pt_undo_button.disabled = true
	if pt_redo_button: pt_redo_button.disabled = true
	if pt_exit_button: pt_exit_button.disabled = true

func update_undo_redo_buttons(can_undo: bool, can_redo: bool):
	if pt_undo_button: pt_undo_button.disabled = not can_undo
	if pt_redo_button: pt_redo_button.disabled = not can_redo

func update_playtest_joker_counter(current: int, required: int):
	if pt_jokers_label:
		pt_jokers_label.text = "[center][img width=28 height=28 region=0,-12,128,128]res://icons/tiles/tile_green.svg[/img] USED: %d/%d[/center]" % [current, required]

func set_playtest_joker_counter_visibility(is_visible: bool):
	if pt_jokers_label:
		pt_jokers_label.visible = is_visible
		var c = pt_jokers_label.modulate
		c.a = 1.0 if is_visible else 0.0
		pt_jokers_label.modulate = c

func set_playtest_move_counter_visibility(is_visible: bool):
	if pt_moves_label:
		pt_moves_label.visible = is_visible
		var c = pt_moves_label.modulate
		c.a = 1.0 if is_visible else 0.0
		pt_moves_label.modulate = c

func set_hint_button_disabled(is_disabled: bool):
	if pt_hint_button:
		pt_hint_button.disabled = is_disabled

func show_overwrite_warning():
	if overwrite_panel: overwrite_panel.visible = true

func _build_playtest_hud():
	if not editor_ui_root: return
	var screen_width = get_viewport().get_visible_rect().size.x
	
	var old_top_hud = editor_ui_root.get_node_or_null("PlaytestHUD")
	if old_top_hud:
		old_top_hud.queue_free()
		
	playtest_hud_container = Control.new()
	playtest_hud_container.name = "PlaytestHUD"
	playtest_hud_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	editor_ui_root.add_child(playtest_hud_container)
	playtest_hud_container.visible = false
	
	pt_title_label = RichTextLabel.new()
	pt_title_label.name = "PTTitleLabel"
	pt_title_label.bbcode_enabled = true
	pt_title_label.scroll_active = false
	pt_title_label.fit_content = false
	pt_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pt_title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	pt_title_label.add_theme_font_size_override("normal_font_size", 28)
	pt_title_label.modulate = Color(1.0, 0.2, 0.2) 
	pt_title_label.global_position = Vector2((screen_width - 300) / 2.0, 40)
	pt_title_label.size = Vector2(300, 60)
	pt_title_label.text = "[center]TEST MODE[/center]"
	playtest_hud_container.add_child(pt_title_label)
	
	var pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(pt_title_label, "modulate:a", 0.2, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(pt_title_label, "modulate:a", 1.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	pt_timer_label = RichTextLabel.new()
	pt_timer_label.bbcode_enabled = true
	pt_timer_label.scroll_active = false
	pt_timer_label.fit_content = false
	pt_timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pt_timer_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	pt_timer_label.add_theme_font_size_override("normal_font_size", 32)
	pt_timer_label.modulate = Color(0.9, 0.9, 0.9)
	pt_timer_label.global_position = Vector2(30, 115)
	pt_timer_label.size = Vector2(280, 80)
	playtest_hud_container.add_child(pt_timer_label)
	
	pt_jokers_label = RichTextLabel.new()
	pt_jokers_label.bbcode_enabled = true
	pt_jokers_label.scroll_active = false
	pt_jokers_label.fit_content = false
	pt_jokers_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pt_jokers_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	pt_jokers_label.add_theme_font_size_override("normal_font_size", 32)
	pt_jokers_label.modulate = Color(0.4, 1.0, 0.4, 1.0) 
	pt_jokers_label.global_position = Vector2((screen_width - 280) / 2.0, 115)
	pt_jokers_label.size = Vector2(280, 80)
	editor_ui_root.add_child(pt_jokers_label)
	
	pt_moves_label = RichTextLabel.new()
	pt_moves_label.bbcode_enabled = true
	pt_moves_label.scroll_active = false
	pt_moves_label.fit_content = false
	pt_moves_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pt_moves_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	pt_moves_label.add_theme_font_size_override("normal_font_size", 32)
	pt_moves_label.modulate = Color(0.75, 0.55, 1.0, 1.0) 
	pt_moves_label.global_position = Vector2(screen_width - 310, 115)
	pt_moves_label.size = Vector2(280, 80)
	playtest_hud_container.add_child(pt_moves_label)

	pt_status_label = RichTextLabel.new()
	pt_status_label.bbcode_enabled = true
	pt_status_label.scroll_active = false
	pt_status_label.fit_content = true
	pt_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pt_status_label.add_theme_font_size_override("normal_font_size", 48)
	pt_status_label.global_position.x = 20
	pt_status_label.size = Vector2(screen_width - 40, 250)
	editor_ui_root.add_child(pt_status_label)
	pt_status_label.visible = false

func update_playtest_hud(time_remaining: int, moves: int):
	if pt_timer_label:
		if editor_time_limit == 0:
			pt_timer_label.text = "[center]TIME: ∞[/center]"
		else:
			var minutes = max(0, int(time_remaining / 60.0))
			var seconds = max(0, time_remaining % 60)
			pt_timer_label.text = "[center]TIME: %02d:%02d[/center]" % [minutes, seconds]
			
	if pt_moves_label:
		pt_moves_label.text = "[center][img width=28 height=28 region=0,-12,128,128]res://icons/tiles/tile_purple.svg[/img] MOVES: %d[/center]" % moves

func _setup_tree_checkbox_icons():
	var tex_zero_file = load("res://icons/tiles/tile_yellow.svg")
	var tex_one_file = load("res://icons/tiles/tile_blue.svg")
	var tex_joker_file = load("res://icons/tiles/tile_green.svg")
	
	if allow_zero:
		allow_zero.toggle_mode = true
		allow_zero.button_pressed = true 
		if tex_zero_file: allow_zero.icon = tex_zero_file
		elif icon_zero: allow_zero.icon = icon_zero
		allow_zero.expand_icon = true
		allow_zero.add_theme_constant_override("icon_max_width", 48)
		
	if allow_one:
		allow_one.toggle_mode = true
		allow_one.button_pressed = true 
		if tex_one_file: allow_one.icon = tex_one_file
		elif icon_one: allow_one.icon = icon_one
		allow_one.expand_icon = true
		allow_one.add_theme_constant_override("icon_max_width", 48)
		
	if allow_joker:
		allow_joker.toggle_mode = true
		allow_joker.button_pressed = true 
		if tex_joker_file: allow_joker.icon = tex_joker_file
		elif icon_joker: allow_joker.icon = icon_joker
		allow_joker.expand_icon = true
		allow_joker.add_theme_constant_override("icon_max_width", 48)

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

func update_dynamic_editor_layout(_board_y: float, _board_height: float) -> void:
	_update_panel_layout(editor_width, editor_height)
	if pt_status_label and is_playtesting_mode:
		pt_status_label.global_position.y = _board_y + _board_height + 40

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
	
	if time_label:
		if time_label is RichTextLabel:
			time_label.add_theme_font_size_override("normal_font_size", 28)
		else:
			time_label.add_theme_font_size_override("font_size", 28)
			
		if editor_time_limit == 0:
			if time_label is RichTextLabel:
				time_label.text = "[center]∞[/center]"
			else:
				time_label.text = "∞"
		else:
			if time_label is RichTextLabel:
				time_label.text = "[center]" + str(editor_time_limit) + "s[/center]"
			else:
				time_label.text = str(editor_time_limit) + "s"
				
	if level_label: 
		if level_label is RichTextLabel:
			level_label.bbcode_enabled = true
			level_label.add_theme_font_size_override("normal_font_size", 32)
			level_label.text = "[center]LEVEL " + str(editor_level) + "[/center]"
		else:
			level_label.add_theme_font_size_override("font_size", 32)
			level_label.text = "LEVEL " + str(editor_level)

func _update_panel_layout(_grid_width: int, _grid_height: int):
	var screen_width = get_viewport().get_visible_rect().size.x
	var screen_height = get_viewport().get_visible_rect().size.y
	
	var panel_width = screen_width
	var panel_height = 680.0
	var panel_x = 0.0
	
	var control_panel_y = screen_height - panel_height + (editor_cell_size * 0.66)
	
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
				if child is Button or child is CheckBox or child is Label:
					if not child.has_theme_font_size_override("font_size") and child != time_label:
						child.add_theme_font_size_override("font_size", 28)
				if child is Label:
					child.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					child.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var core_container = get_tree().current_scene.find_child("CoreLevelsContainer", true, false)
	if core_container:
		core_container.global_position = Vector2(panel_x + 40, control_panel_y + 470)
		core_container.size = Vector2(panel_width - 80, 80)
		if core_container is BoxContainer:
			core_container.alignment = BoxContainer.ALIGNMENT_BEGIN
			core_container.add_theme_constant_override("separation", 20)
			
	if status_label and not is_playtesting_mode:
		status_label.position = Vector2(40, 560)
		status_label.set_deferred("size", Vector2(panel_width - 80, 60))
					
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
					if not child.has_theme_font_size_override("font_size") and child != level_label:
						child.add_theme_font_size_override("font_size", 28)
				if child is Label:
					child.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					child.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
					
	if level_label and not is_playtesting_mode:
		level_label.modulate = Color(1.0, 0.9, 0.4) 

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
	zero_button.pressed.connect(func(): brush_changed.emit(0, "Yellow Tile"))
	one_button.pressed.connect(func(): brush_changed.emit(1, "Blue Tile"))
	joker_button.pressed.connect(func(): brush_changed.emit(2, "Combined Tile"))
	if shifter_button: shifter_button.pressed.connect(func(): brush_changed.emit(3, "Shifter Tile Link Tool"))
	if equals_button: equals_button.pressed.connect(func(): brush_changed.emit(4, "Equals (=) Link Tool"))
	if not_equals_button: not_equals_button.pressed.connect(func(): brush_changed.emit(5, "Not Equals (×) Link Tool"))
	save_button.pressed.connect(func(): save_requested.emit())
	if load_button: load_button.pressed.connect(func(): load_requested.emit()) 
	if main_menu_button: main_menu_button.pressed.connect(func(): main_menu_requested.emit())
	test_button.pressed.connect(func(): test_mode_entered.emit())
	if width_minus: width_minus.pressed.connect(func(): _adjust_value("width", -1))
	if width_plus: width_plus.pressed.connect(func(): _adjust_value("width", 1))
	if height_minus: height_minus.pressed.connect(func(): _adjust_value("height", -1))
	if height_plus: height_plus.pressed.connect(func(): _adjust_value("height", 1))
	if level_minus: level_minus.pressed.connect(func(): _adjust_value("level", -1))
	if level_plus: level_plus.pressed.connect(func(): _adjust_value("level", 1))
	if time_minus: time_minus.pressed.connect(func(): _adjust_value("time", -30))
	if time_plus: time_plus.pressed.connect(func(): _adjust_value("time", 30))
	
	if allow_zero: allow_zero.pressed.connect(func(): allowed_tiles_changed.emit())
	if allow_one: allow_one.pressed.connect(func(): allowed_tiles_changed.emit())
	if allow_joker: allow_joker.pressed.connect(func(): allowed_tiles_changed.emit())

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
	
	if grid_changed:
		_update_panel_layout(editor_width, editor_height)
		grid_size_changed.emit(editor_width, editor_height)

func update_status(msg: String, text_color: Color):
	if status_label:
		if status_label is RichTextLabel:
			status_label.text = "[center][color=#" + text_color.to_html() + "]" + msg.replace("[center]", "").replace("[/center]", "") + "[/color][/center]"
		else:
			status_label.text = msg.replace("[center]", "").replace("[/center]", "")
			status_label.modulate = text_color

func update_playtest_status(msg: String, text_color: Color):
	if pt_status_label:
		pt_status_label.text = "[center][color=#" + text_color.to_html() + "]" + msg.replace("[center]", "").replace("[/center]", "") + "[/color][/center]"

func toggle_playtest_visibility(is_playtesting: bool):
	is_playtesting_mode = is_playtesting
	_update_number_labels()
	
	if level_label:
		level_label.visible = not is_playtesting
	
	brush_container.visible = not is_playtesting
	save_button.visible = not is_playtesting
	if load_button: load_button.visible = not is_playtesting
	if clear_button: clear_button.visible = not is_playtesting
	test_button.visible = not is_playtesting
	if level_minus: level_minus.visible = not is_playtesting
	if level_plus: level_plus.visible = not is_playtesting
	if grid_size_container: grid_size_container.visible = not is_playtesting 
	if level_settings_container: level_settings_container.visible = not is_playtesting
	
	if playtest_hud_container: playtest_hud_container.visible = is_playtesting
	if pt_status_label: pt_status_label.visible = is_playtesting
	
	var control_panel = editor_ui_root.find_child("ControlPanel", true, false)
	if control_panel:
		control_panel.visible = not is_playtesting
		
	var button_row = editor_ui_root.find_child("ButtonRow", true, false)
	if button_row:
		button_row.visible = not is_playtesting
	
	if pt_reset_button: pt_reset_button.visible = is_playtesting
	if pt_rules_button: pt_rules_button.visible = is_playtesting
	if pt_hint_button: pt_hint_button.visible = is_playtesting
	if pt_undo_button: pt_undo_button.visible = is_playtesting
	if pt_redo_button: pt_redo_button.visible = is_playtesting
	if pt_exit_button: pt_exit_button.visible = is_playtesting
	
	_update_panel_layout(editor_width, editor_height)

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

func get_level_number() -> int: return editor_level
