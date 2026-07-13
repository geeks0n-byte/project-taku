extends Control

# ==========================================
# EXPORT SLOTS & CONFIGURATIONS
# ==========================================
# Drag and drop your main gameplay scene (.tscn) into this inspector slot.
@export var gameplay_scene : PackedScene

# ==========================================
# NODE REFERENCES
# ==========================================
@onready var options_panel: Panel = $OptionsPanel
@onready var status_label: Label = $OptionsPanel/StatusLabel

# ==========================================
# MAIN INITIALIZATION
# ==========================================
func _ready() -> void:
	if options_panel:
		# Define how big you want the Options menu to be
		var panel_size = Vector2(500, 400) 
		options_panel.custom_minimum_size = panel_size
		options_panel.size = panel_size
		
		# Calculate the exact center of the screen
		var screen_size = get_viewport_rect().size
		options_panel.position = (screen_size - panel_size) / 2
		
		# Ensure it is hidden on launch
		options_panel.hide()
		
	# Clear out any old debug messages on the options screen.
	if status_label:
		status_label.text = ""
		
	# Safely grab focus for controller/keyboard support if the button node exists.
	if has_node("MarginContainer/MainLayout/ButtonList/StartButton"):
		$MarginContainer/MainLayout/ButtonList/StartButton.grab_focus()

# ==========================================
# MAIN INTERFACE SIGNALS
# ==========================================
func _on_start_button_pressed() -> void:
	if gameplay_scene:
		get_tree().change_scene_to_packed(gameplay_scene)
	else:
		print("Warning: No gameplay scene assigned to the MainMenu inspector slot!")

func _on_options_pressed() -> void:
	# Opens the centered options popup window and clears old status messages.
	if options_panel:
		options_panel.show()
	if status_label:
		status_label.text = ""

func _on_level_select_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")

func _on_level_editor_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level_editor.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()

# ==========================================
# OPTIONS PANEL INTERACTION METHODS
# ==========================================
func _on_delete_save_button_pressed() -> void:
	# Physically wipe the progression save file from disk.
	SaveManager.delete_save_file()
	
	# Provide feedback so the player knows their action worked.
	if status_label:
		status_label.text = "Save file physically deleted!\nProgress reset to Level 1."
		status_label.modulate = Color(0.4, 1.0, 0.4) # Success green color styling

func _on_close_options_button_pressed() -> void:
	# Closes options screen overlay.
	if options_panel:
		options_panel.hide()
