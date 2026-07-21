class_name UIManager
extends Node

signal pause_requested
signal reset_requested
signal how_to_play_requested 
signal resume_from_tutorial_requested 
signal next_level_requested  
signal play_again_requested  
signal hint_requested 
signal undo_requested
signal redo_requested

@export var ui_scale: float = 1.0

@onready var level_label = $"../LevelLabel"
@onready var status_label = $"../StatusLabel"
@onready var pause_button = $"../PauseButton"
@onready var reset_button = $"../ResetButton"
@onready var how_to_play_button = $"../HowToPlayButton" 
@onready var timer_label = $"../TimerLabel"
var move_counter_label: RichTextLabel
var joker_counter_label: RichTextLabel

@onready var victory_panel = $"../EndLayer/VictoryPanel"
@onready var restart_button = $"../EndLayer/VictoryPanel/RestartButton"
@onready var main_menu_button = $"../EndLayer/VictoryPanel/MainMenuButton"
@onready var time_result_label = $"../EndLayer/VictoryPanel/TimeResultLabel"
@onready var win_label = $"../EndLayer/VictoryPanel/WinLabel"

@onready var defeat_panel = get_node_or_null("../EndLayer/DefeatPanel")
var defeat_restart_button: Button
var defeat_main_menu_button: Button
var defeat_label: Label 

@onready var how_to_play_container = $"../HowToPlayLayer/CenterContainer"
@onready var how_to_play_panel = $"../HowToPlayLayer/CenterContainer/HowToPlayPanel" 
@onready var rules_label = $"../HowToPlayLayer/CenterContainer/HowToPlayPanel/RulesLabel"
@onready var tutorial_back_button = $"../HowToPlayLayer/CenterContainer/HowToPlayPanel/BackButton"

var hint_button: Button 
var undo_button: Button
var redo_button: Button

var _is_last_level_completed: bool = false
var custom_font: Font

# --- SCALING HELPERS ---
func _s(val: float) -> float: return val * ui_scale
func _sv(x: float, y: float) -> Vector2: return Vector2(x * ui_scale, y * ui_scale)
func _si(val: int) -> int: return int(val * ui_scale)

# --- TEXT & OUTLINE HELPERS ---
func _apply_text_outline(node: Control, outline_size: int = 6):
	if not node: return
	node.add_theme_color_override("font_outline_color", Color.BLACK)
	node.add_theme_constant_override("outline_size", _si(outline_size))

func _set_text_color(node: Control, color: Color):
	if not node: return
	node.modulate = Color.WHITE 
	if node is RichTextLabel:
		node.add_theme_color_override("default_color", color)
	elif node is Label or node is Button:
		node.add_theme_color_override("font_color", color)

func _create_scalable_button_style(texture_path: String, color_modulate: Color = Color.WHITE) -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	var tex = load(texture_path)
	if tex:
		style.texture = tex
		var margin = 16.0 
		style.texture_margin_left = margin
		style.texture_margin_right = margin
		style.texture_margin_top = margin
		style.texture_margin_bottom = margin
		
		# Offset the content up to counteract the 3D bottom bevel
		style.content_margin_left = _si(8)
		style.content_margin_right = _si(8)
		style.content_margin_top = _si(2)
		style.content_margin_bottom = _si(16)
		
		style.modulate_color = color_modulate
	return style

func _apply_scalable_theme(btn: Button, base_font_size: int):
	if not btn: return
	var svg_path = "res://icons/buttons/button_tile_gray_dark.svg"
	
	btn.add_theme_stylebox_override("normal", _create_scalable_button_style(svg_path, Color(1.0, 1.0, 1.0)))
	btn.add_theme_stylebox_override("hover", _create_scalable_button_style(svg_path, Color(1.2, 1.2, 1.2)))
	btn.add_theme_stylebox_override("pressed", _create_scalable_button_style(svg_path, Color(0.8, 0.8, 0.8)))
	btn.add_theme_stylebox_override("disabled", _create_scalable_button_style(svg_path, Color(0.5, 0.5, 0.5)))
	
	if custom_font:
		btn.add_theme_font_override("font", custom_font)
	
	btn.add_theme_font_size_override("font_size", _si(base_font_size))
	_apply_text_outline(btn, 7)

# --- ICON-ONLY BUTTON INJECTION HELPER ---
func _set_icon_only_button(btn: Button, icon_file: String, icon_size: int):
	if not btn: return
	
	btn.text = ""
	
	for child in btn.get_children():
		if child.name == "CustomIconText":
			child.queue_free()
			
	var tex = load("res://icons/buttons/" + icon_file)
	if tex:
		var hbox = HBoxContainer.new()
		hbox.name = "CustomIconText"
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		
		# Shift layout box slightly up to respect visual centering 
		hbox.offset_top = -_si(4)
		hbox.offset_bottom = -_si(4)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var tex_rect = TextureRect.new()
		tex_rect.texture = tex
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(_si(icon_size), _si(icon_size))
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(tex_rect)
		
		btn.add_child(hbox)
		
	_apply_scalable_theme(btn, 14)

func setup_ui(_show_debug_tools: bool, _cell_size: float):
	custom_font = load("res://fonts/PressStart2P-vaV7.ttf")
	
	var screen_width = get_viewport().get_visible_rect().size.x
	var root_parent = get_parent()
	
	# --- UNIFIED TOP BAR DIMENSIONS ---
	var btn_size = 135
	var icon_size = 90
	var start_y = 20
	
	var left_1 = 25
	var left_2 = 175
	var left_3 = 325
	
	var right_3 = screen_width - 460
	var right_2 = screen_width - 310
	var right_1 = screen_width - 160
	
	# --- TOP BUTTON ROW (Square Icons) ---
	if pause_button:
		_set_icon_only_button(pause_button, "icon_pause.svg", icon_size)
		pause_button.global_position = _sv(left_1, start_y) 
		pause_button.size = _sv(btn_size, btn_size)

	if reset_button:
		_set_icon_only_button(reset_button, "icon_reset.svg", icon_size)
		reset_button.global_position = _sv(left_2, start_y)
		reset_button.size = _sv(btn_size, btn_size)
		
	if how_to_play_button:
		_set_icon_only_button(how_to_play_button, "icon_rules.svg", icon_size)
		how_to_play_button.global_position = _sv(left_3, start_y)
		how_to_play_button.size = _sv(btn_size, btn_size) 

	if level_label:
		if level_label.get_parent() != root_parent:
			level_label.get_parent().remove_child(level_label)
			root_parent.add_child(level_label)
		_set_text_color(level_label, Color(1.0, 0.9, 0.4)) 
		level_label.global_position = Vector2((screen_width - _s(300)) / 2.0, _s(start_y)) 
		level_label.size = _sv(300, btn_size)
		level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if level_label is RichTextLabel: 
			level_label.bbcode_enabled = true
			if custom_font: level_label.add_theme_font_override("normal_font", custom_font)
			level_label.add_theme_font_size_override("normal_font_size", _si(36))
		else:
			level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			if custom_font: level_label.add_theme_font_override("font", custom_font)
			level_label.add_theme_font_size_override("font_size", _si(36))
		_apply_text_outline(level_label, 8)

	hint_button = root_parent.get_node_or_null("HintButton")
	if not hint_button:
		hint_button = Button.new()
		hint_button.name = "HintButton"
		root_parent.add_child(hint_button)
		
	_set_icon_only_button(hint_button, "icon_hint.svg", icon_size)
	hint_button.global_position = Vector2(right_3, _s(start_y)) 
	hint_button.size = _sv(btn_size, btn_size) 
	hint_button.disabled = true
	
	undo_button = root_parent.get_node_or_null("UndoButton")
	if not undo_button:
		undo_button = Button.new()
		undo_button.name = "UndoButton"
		root_parent.add_child(undo_button)
	
	_set_icon_only_button(undo_button, "icon_undo.svg", icon_size)
	undo_button.global_position = Vector2(right_2, _s(start_y)) 
	undo_button.size = _sv(btn_size, btn_size)
	undo_button.disabled = true
	
	redo_button = root_parent.get_node_or_null("RedoButton")
	if not redo_button:
		redo_button = Button.new()
		redo_button.name = "RedoButton"
		root_parent.add_child(redo_button)
		
	_set_icon_only_button(redo_button, "icon_redo.svg", icon_size)
	redo_button.global_position = Vector2(right_1, _s(start_y)) 
	redo_button.size = _sv(btn_size, btn_size)
	redo_button.disabled = true
	
	var old_top_hud = root_parent.get_node_or_null("TopHUDContainer")
	if old_top_hud:
		old_top_hud.queue_free()

	# --- SCALED COUNTERS (Pushed down to clear huge top bar) ---
	var counters_y = 180
	
	if timer_label:
		if timer_label.get_parent() != root_parent:
			timer_label.get_parent().remove_child(timer_label)
			root_parent.add_child(timer_label)
		timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_text_color(timer_label, Color(0.9, 0.9, 0.9))
		timer_label.global_position = _sv(30, counters_y)
		timer_label.size = _sv(300, 80)
		if timer_label is RichTextLabel:
			timer_label.bbcode_enabled = true
			timer_label.fit_content = false
			timer_label.scroll_active = false
			timer_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			if custom_font: timer_label.add_theme_font_override("normal_font", custom_font)
			timer_label.add_theme_font_size_override("normal_font_size", _si(24))
		_apply_text_outline(timer_label, 6)

	var old_joker = root_parent.get_node_or_null("JokerCounterLabel")
	if old_joker:
		if old_joker is RichTextLabel:
			joker_counter_label = old_joker
		else:
			old_joker.name = "ObsoleteJoker" 
			old_joker.queue_free()

	if not joker_counter_label:
		joker_counter_label = RichTextLabel.new()
		joker_counter_label.name = "JokerCounterLabel"
		root_parent.add_child(joker_counter_label)
		
	joker_counter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joker_counter_label.global_position = Vector2((screen_width - _s(300)) / 2.0, _s(counters_y))
	joker_counter_label.size = _sv(300, 80)
	joker_counter_label.bbcode_enabled = true
	joker_counter_label.fit_content = false
	joker_counter_label.scroll_active = false
	joker_counter_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if custom_font: joker_counter_label.add_theme_font_override("normal_font", custom_font)
	joker_counter_label.add_theme_font_size_override("normal_font_size", _si(24))
	_set_text_color(joker_counter_label, Color(0.4, 1.0, 0.4, 1.0))
	_apply_text_outline(joker_counter_label, 6)

	var old_move = root_parent.get_node_or_null("MoveCounterLabel")
	if old_move:
		if old_move is RichTextLabel:
			move_counter_label = old_move
		else:
			old_move.name = "ObsoleteMove"
			old_move.queue_free()

	if not move_counter_label:
		move_counter_label = RichTextLabel.new()
		move_counter_label.name = "MoveCounterLabel"
		root_parent.add_child(move_counter_label)
		
	move_counter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	move_counter_label.global_position = Vector2(screen_width - _s(330), _s(counters_y))
	move_counter_label.size = _sv(300, 80)
	move_counter_label.bbcode_enabled = true
	move_counter_label.fit_content = false
	move_counter_label.scroll_active = false
	move_counter_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if custom_font: move_counter_label.add_theme_font_override("normal_font", custom_font)
	move_counter_label.add_theme_font_size_override("normal_font_size", _si(24))
	_set_text_color(move_counter_label, Color(0.75, 0.55, 1.0, 1.0))
	_apply_text_outline(move_counter_label, 6)

	if status_label:
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		status_label.global_position.x = _s(20)
		status_label.size = Vector2(screen_width - _s(40), _s(250))
		_set_text_color(status_label, Color.WHITE)
		if status_label is RichTextLabel:
			status_label.bbcode_enabled = true
			status_label.fit_content = true 
			status_label.add_theme_font_size_override("normal_font_size", _si(48)) 
			status_label.text = "[center]Fill the empty spaces on the board.[/center]"
		else:
			status_label.add_theme_font_size_override("font_size", _si(48)) 
			status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			status_label.text = "Fill the empty spaces on the board."
		_apply_text_outline(status_label, 6)

	var square_panel_size = _sv(460, 500)
	var panel_pos = _sv(310, 300)
	var menu_button_size = _sv(340, 75)
	var button_center_x = (square_panel_size.x - menu_button_size.x) / 2 
	var spacing_y = _s(90) 

	if victory_panel:
		victory_panel.custom_minimum_size = square_panel_size
		victory_panel.global_position = panel_pos 
		victory_panel.size = square_panel_size
		
	if defeat_panel:
		defeat_panel.custom_minimum_size = square_panel_size
		defeat_panel.global_position = panel_pos
		defeat_panel.size = square_panel_size
		
		defeat_restart_button = defeat_panel.find_child("RestartButton", true, false)
		if not defeat_restart_button:
			defeat_restart_button = defeat_panel.find_child("TryAgainButton", true, false)
		defeat_main_menu_button = defeat_panel.find_child("MainMenuButton", true, false)
		
		defeat_label = defeat_panel.find_child("DefeatLabel", true, false)
		if not defeat_label:
			defeat_label = defeat_panel.find_child("Label", true, false)
		
		if defeat_restart_button: defeat_restart_button.text = "TRY AGAIN"

	if win_label:
		if custom_font: win_label.add_theme_font_override("font", custom_font)
		win_label.add_theme_font_size_override("font_size", _si(18)) 
		_set_text_color(win_label, Color(1.0, 0.84, 0.0))
		win_label.size = Vector2(square_panel_size.x, _s(70)) 
		win_label.position = _sv(0, 20)
		win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER 
		win_label.autowrap_mode = TextServer.AUTOWRAP_WORD 
		_apply_text_outline(win_label, 7)
		
	if defeat_label:
		if custom_font: defeat_label.add_theme_font_override("font", custom_font)
		defeat_label.add_theme_font_size_override("font_size", _si(18))
		_set_text_color(defeat_label, Color(1.0, 0.3, 0.3)) 
		defeat_label.size = Vector2(square_panel_size.x, _s(70))
		defeat_label.position = _sv(0, 20)
		defeat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		defeat_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_apply_text_outline(defeat_label, 7)
		
	if time_result_label:
		if custom_font: time_result_label.add_theme_font_override("font", custom_font)
		time_result_label.add_theme_font_size_override("font_size", _si(14))
		_set_text_color(time_result_label, Color(0.9, 0.9, 0.9))
		time_result_label.size = Vector2(square_panel_size.x, _s(40))
		time_result_label.position = _sv(0, 115)
		time_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER 
		_apply_text_outline(time_result_label, 5)

	var v_start_y = _s(190) 
	
	if restart_button:
		_apply_scalable_theme(restart_button, 20)
		restart_button.position = Vector2(button_center_x, v_start_y)
		restart_button.size = menu_button_size
	if defeat_restart_button:
		_apply_scalable_theme(defeat_restart_button, 20)
		defeat_restart_button.position = Vector2(button_center_x, v_start_y)
		defeat_restart_button.size = menu_button_size
		
	v_start_y += spacing_y

	if main_menu_button:
		main_menu_button.text = "MAIN MENU"
		_apply_scalable_theme(main_menu_button, 20)
		main_menu_button.position = Vector2(button_center_x, v_start_y)
		main_menu_button.size = menu_button_size
	if defeat_main_menu_button:
		defeat_main_menu_button.text = "MAIN MENU"
		_apply_scalable_theme(defeat_main_menu_button, 20)
		defeat_main_menu_button.position = Vector2(button_center_x, v_start_y)
		defeat_main_menu_button.size = menu_button_size

	var tutorial_size = _sv(850, 1200) 
	if how_to_play_panel:
		how_to_play_panel.custom_minimum_size = tutorial_size
		how_to_play_panel.size = tutorial_size
		var solid_style = StyleBoxFlat.new()
		solid_style.bg_color = Color(0.12, 0.12, 0.12, 1.0) 
		how_to_play_panel.add_theme_stylebox_override("panel", solid_style)
		if how_to_play_container:
			how_to_play_container.visible = false
		
	if rules_label:
		if rules_label is RichTextLabel:
			rules_label.add_theme_font_size_override("normal_font_size", _si(24))
		else:
			rules_label.add_theme_font_size_override("font_size", _si(24))
		rules_label.position = _sv(30, 30)
		rules_label.size = _sv(790, 1090) 
		_apply_text_outline(rules_label, 4)
		
	if tutorial_back_button:
		_apply_scalable_theme(tutorial_back_button, 18)
		var t_btn_size = _sv(160, 60)
		tutorial_back_button.size = t_btn_size
		var btn_x = (tutorial_size.x - t_btn_size.x) / 2
		var btn_y = tutorial_size.y - t_btn_size.y - _s(30)
		tutorial_back_button.position = Vector2(btn_x, btn_y)
		if not tutorial_back_button.pressed.is_connected(_on_tutorial_back_pressed):
			tutorial_back_button.pressed.connect(_on_tutorial_back_pressed)

	_connect_signals()

func update_undo_redo_buttons(can_undo: bool, can_redo: bool):
	if undo_button: undo_button.disabled = not can_undo
	if redo_button: redo_button.disabled = not can_redo

func update_joker_counter(current: int, required: int):
	if joker_counter_label:
		joker_counter_label.text = "[center][img width=%d height=%d region=0,-12,128,128]res://icons/tiles/tile_green.svg[/img] USED: %d/%d[/center]" % [_si(32), _si(32), current, required]

func set_joker_counter_visibility(is_visible: bool):
	if joker_counter_label:
		joker_counter_label.visible = is_visible
		var c = joker_counter_label.modulate
		c.a = 1.0 if is_visible else 0.0
		joker_counter_label.modulate = c

func update_move_counter(moves: int):
	if move_counter_label: 
		move_counter_label.text = "[center][img width=%d height=%d region=0,-12,128,128]res://icons/tiles/tile_purple.svg[/img] MOVES: %d[/center]" % [_si(32), _si(32), moves]

func set_move_counter_visibility(is_visible: bool):
	if move_counter_label:
		move_counter_label.visible = is_visible
		var c = move_counter_label.modulate
		c.a = 1.0 if is_visible else 0.0
		move_counter_label.modulate = c

func set_hint_button_disabled(is_disabled: bool):
	if hint_button: hint_button.disabled = is_disabled

func update_dynamic_layout(_board_y: float, _board_height: float):
	if status_label:
		status_label.global_position.y = _board_y + _board_height + _s(40)

func set_hud_buttons_disabled(is_disabled: bool):
	if pause_button: pause_button.disabled = is_disabled
	if reset_button: reset_button.disabled = is_disabled
	if how_to_play_button: how_to_play_button.disabled = is_disabled
	
	if is_disabled:
		if undo_button: undo_button.disabled = true
		if redo_button: redo_button.disabled = true
		if hint_button: hint_button.disabled = true

func _connect_signals():
	if pause_button and not pause_button.pressed.is_connected(func(): pause_requested.emit()):
		pause_button.pressed.connect(func(): pause_requested.emit())
	if reset_button and not reset_button.pressed.is_connected(func(): reset_requested.emit()):
		reset_button.pressed.connect(func(): reset_requested.emit())
	if how_to_play_button and not how_to_play_button.pressed.is_connected(func(): how_to_play_requested.emit()):
		how_to_play_button.pressed.connect(func(): how_to_play_requested.emit())
	if hint_button and not hint_button.pressed.is_connected(_on_hint_pressed):
		hint_button.pressed.connect(_on_hint_pressed)
		
	if undo_button and not undo_button.pressed.is_connected(func(): undo_requested.emit()):
		undo_button.pressed.connect(func(): undo_requested.emit())
		
	if redo_button and not redo_button.pressed.is_connected(func(): redo_requested.emit()):
		redo_button.pressed.connect(func(): redo_requested.emit())
		
	if restart_button and not restart_button.pressed.is_connected(_on_victory_button_pressed):
		restart_button.pressed.connect(_on_victory_button_pressed)
	if main_menu_button and not main_menu_button.pressed.is_connected(_on_main_menu_pressed):
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	if tutorial_back_button and not tutorial_back_button.pressed.is_connected(_on_tutorial_back_pressed):
		tutorial_back_button.pressed.connect(_on_tutorial_back_pressed)
	
	if defeat_restart_button and not defeat_restart_button.pressed.is_connected(func(): reset_requested.emit()):
		defeat_restart_button.pressed.connect(func(): reset_requested.emit())
	if defeat_main_menu_button and not defeat_main_menu_button.pressed.is_connected(_on_main_menu_pressed):
		defeat_main_menu_button.pressed.connect(_on_main_menu_pressed)

func _on_hint_pressed():
	hint_requested.emit()

func _on_tutorial_back_pressed():
	if how_to_play_container: how_to_play_container.visible = false
	resume_from_tutorial_requested.emit()

func _on_victory_button_pressed():
	if _is_last_level_completed: play_again_requested.emit()
	else: next_level_requested.emit()

func _on_main_menu_pressed():
	get_tree().paused = false 
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func update_timer(formatted_time: String):
	if timer_label: 
		if formatted_time == "∞":
			if timer_label is RichTextLabel:
				var inf_size = _si(46) 
				timer_label.text = "[center]TIME: [img width=%d height=%d]res://icons/buttons/icon_infinity.svg[/img][/center]" % [inf_size, inf_size]
			else:
				timer_label.text = "TIME: ∞"
		else:
			if timer_label is RichTextLabel:
				timer_label.text = "[center]TIME: " + formatted_time + "[/center]"
			else:
				timer_label.text = "TIME: " + formatted_time

func display_level(num: int, is_custom: bool = false):
	if level_label: 
		var txt = "CUSTOM\n%d" if is_custom else "LVL\n%d"
		if level_label is RichTextLabel:
			level_label.text = "[center]" + (txt % num) + "[/center]"
		else:
			level_label.text = txt % num

func show_status_valid():
	if status_label:
		_set_text_color(status_label, Color.WHITE)
		if status_label is RichTextLabel:
			status_label.text = "[center]Fill the empty spaces on the board.[/center]"
		else:
			status_label.text = "Fill the empty spaces on the board."

func show_status_errors(errors: Array):
	if status_label:
		_set_text_color(status_label, Color.WHITE)
		if status_label is RichTextLabel:
			status_label.text = "[center]" + "\n".join(errors) + "[/center]"
		else:
			status_label.text = "\n".join(errors).replace("[color=#FFD700]", "").replace("[color=#4DA6FF]", "").replace("[color=#4DFF4D]", "").replace("[color=#BF8BFF]", "").replace("[/color]", "")

func set_overlays_hidden():
	if victory_panel: victory_panel.visible = false
	if defeat_panel: defeat_panel.visible = false
	if how_to_play_container: how_to_play_container.visible = false 
	set_hud_buttons_disabled(false)

func show_how_to_play():
	if how_to_play_container:
		how_to_play_container.visible = true
	set_hud_buttons_disabled(true)

func show_victory(display_num: int, is_last_level: bool, formatted_time: String, is_custom: bool = false):
	_is_last_level_completed = is_last_level
	set_hud_buttons_disabled(true)
	
	if status_label:
		_set_text_color(status_label, Color(1.0, 0.84, 0.0))
		if status_label is RichTextLabel:
			status_label.text = "[center]Puzzle solved![/center]"
		else:
			status_label.text = "Puzzle solved!"
	
	if win_label:
		if is_last_level: win_label.text = "ALL LEVELS COMPLETED!\nYOU WIN!" 
		else: win_label.text = ("CUSTOM %d COMPLETED!" if is_custom else "LEVEL %d COMPLETED!") % display_num
		
	if restart_button: restart_button.text = "PLAY AGAIN" if is_last_level else "NEXT LEVEL"
	if time_result_label: time_result_label.text = "COMPLETION TIME: %s" % formatted_time
	if victory_panel: victory_panel.visible = true

func show_defeat():
	set_hud_buttons_disabled(true)
	if status_label:
		_set_text_color(status_label, Color(1.0, 0.3, 0.3))
		if status_label is RichTextLabel:
			status_label.text = "[center]Time's up! The puzzle remains unsolved.[/center]"
		else:
			status_label.text = "Time's up! The puzzle remains unsolved."
	if defeat_panel: defeat_panel.visible = true
