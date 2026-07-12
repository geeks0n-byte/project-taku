extends Control

# This creates a slot in the Inspector where you will drop your playable level scene
@export var gameplay_scene : PackedScene

func _ready() -> void:
	# Safely grab focus for controller/keyboard support if the node exists
	if has_node("MarginContainer/MainLayout/ButtonList/StartButton"):
		$MarginContainer/MainLayout/ButtonList/StartButton.grab_focus()

func _on_start_button_pressed() -> void:
	if gameplay_scene:
		get_tree().change_scene_to_packed(gameplay_scene)
	else:
		print("Warning: No gameplay scene assigned to the MainMenu inspector slot!")

# FIXES ERROR: Missing connected method '_on_options_pressed'
func _on_options_pressed() -> void:
	print("Open options menu panel here later!")

# FIXES ERROR: Missing connected method '_on_exit_pressed'
func _on_exit_pressed() -> void:
	get_tree().quit()

# FIXES ERROR: Missing connected method '_on_level_editor_pressed'
func _on_level_editor_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level_editor.tscn")

# NEW: Connect to level select screen
func _on_level_select_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")
