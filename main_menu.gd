extends Control

# This creates a slot in the Inspector where you will drop your playable level
@export var gameplay_scene : PackedScene

func _ready() -> void:
	# Ensure the buttons grab focus for controller/keyboard support out of the box
	$MarginContainer/MainLayout/ButtonList/StartButton.grab_focus()

func _on_start_button_pressed() -> void:
	if gameplay_scene:
		get_tree().change_scene_to_packed(gameplay_scene)
	else:
		print("Warning: No gameplay scene assigned to the MainMenu inspector slot!")

func _on_options_button_pressed() -> void:
	print("Open options menu panel here later!")

func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_options_pressed() -> void:
	pass # Replace with function body.


func _on_exit_pressed() -> void:
	pass # Replace with function body.
