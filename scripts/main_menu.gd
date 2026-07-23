extends Control

@onready var start_btn = $UILayer/CenterContainer/VBoxContainer/StartButton
@onready var levels_btn = $UILayer/CenterContainer/VBoxContainer/LevelSelectButton
@onready var options_btn = $UILayer/CenterContainer/VBoxContainer/OptionsButton
@onready var credits_btn = $UILayer/CenterContainer/VBoxContainer/CreditsButton
@onready var editor_btn = $UILayer/CenterContainer/VBoxContainer/EditorButton

@onready var options_menu = $UILayer/OptionsMenu
@onready var overlay_blocker = $UILayer/OverlayBlocker
@onready var credits_panel = $UILayer/OverlayBlocker/CreditsPanel
@onready var close_credits_btn = $UILayer/OverlayBlocker/CreditsPanel/VBoxContainer/CloseCreditsButton

func _ready() -> void:
	if start_btn: start_btn.pressed.connect(_on_start_pressed)
	if levels_btn: levels_btn.pressed.connect(_on_levels_pressed)
	if options_btn: options_btn.pressed.connect(_on_options_pressed)
	if credits_btn: credits_btn.pressed.connect(_on_credits_pressed)
	if editor_btn: editor_btn.pressed.connect(_on_editor_pressed)
	
	if close_credits_btn: close_credits_btn.pressed.connect(_on_close_credits)
	
	if options_menu:
		options_menu.visible = false
		if options_menu.has_signal("back_requested"):
			options_menu.back_requested.connect(_on_options_back)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_levels_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")

func _on_options_pressed() -> void:
	if options_menu:
		options_menu.visible = true
		_set_main_buttons_disabled(true)

func _on_options_back() -> void:
	if options_menu:
		options_menu.visible = false
		_set_main_buttons_disabled(false)

func _on_credits_pressed() -> void:
	if overlay_blocker: overlay_blocker.visible = true
	if credits_panel: credits_panel.visible = true
	_set_main_buttons_disabled(true)

func _on_close_credits() -> void:
	if overlay_blocker: overlay_blocker.visible = false
	if credits_panel: credits_panel.visible = false
	_set_main_buttons_disabled(false)

func _on_editor_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level_editor.tscn")

func _set_main_buttons_disabled(disabled: bool) -> void:
	if start_btn: start_btn.disabled = disabled
	if levels_btn: levels_btn.disabled = disabled
	if options_btn: options_btn.disabled = disabled
	if credits_btn: credits_btn.disabled = disabled
	if editor_btn: editor_btn.disabled = disabled
