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

# Ensure these names exactly match what you named them in your Scene Tree!
@onready var clear_save_button: Button = $OptionsPanel/DeleteSaveButton 
@onready var close_options_button: Button = $OptionsPanel/CloseOptionsButton
@onready var status_label: Label = $OptionsPanel/StatusLabel

# Using get_node_or_null so the game won't crash if you move this button later
@onready var start_button: Button = get_node_or_null("MarginContainer/MainLayout/ButtonList/StartButton")

# ==========================================
# MAIN INITIALIZATION
# ==========================================
func _ready() -> void:
	if options_panel:
		# 1. Define and apply the Panel's overall size
		var panel_size = Vector2(500, 400) 
		options_panel.custom_minimum_size = panel_size
		options_panel.size = panel_size
		
		# 2. Calculate the exact center of the screen and snap the panel there
		var screen_size = get_viewport_rect().size
		options_panel.position = (screen_size - panel_size) / 2
		
		# 3. Format and Connect the Delete Save Button inside the panel
		if clear_save_button: 
			clear_save_button.size = Vector2(300, 60)
			clear_save_button.position = Vector2((panel_size.x - 300) / 2, 80)
			if not clear_save_button.pressed.is_connected(_on_delete_save_button_pressed):
				clear_save_button.pressed.connect(_on_delete_save_button_pressed)
			
		# 4. Format and Connect the Close Options Button inside the panel
		if close_options_button:
			close_options_button.size = Vector2(300, 60)
			close_options_button.position = Vector2((panel_size.x - 300) / 2, 160)
			if not close_options_button.pressed.is_connected(_on_close_options_button_pressed):
				close_options_button.pressed.connect(_on_close_options_button_pressed)
			
		# 5. Format the Status Label inside the panel
		if status_label:
			status_label.text = ""
			status_label.size = Vector2(460, 100)
			status_label.position = Vector2((panel_size.x - 460) / 2, 260)
			status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		
		# 6. Hide it until the player clicks "Options"
		options_panel.hide()
		
	# 7. Setup "Continue" logic and grab focus
	if start_button:
		if SaveManager.max_unlocked_level > 1:
			start_button.text = "Continue"
		else:
			start_button.text = "Play"
		start_button.grab_focus()

# ==========================================
# MAIN INTERFACE SIGNALS
# ==========================================
func _on_start_button_pressed() -> void:
	if gameplay_scene:
		get_tree().change_scene_to_packed(gameplay_scene)
	else:
		print("Warning: No gameplay scene assigned to the MainMenu inspector slot!")

func _on_options_pressed() -> void:
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
		status_label.modulate = Color(0.4, 1.0, 0.4)
		
	# Dynamically revert the "Continue" button back to "Play"
	if start_button:
		start_button.text = "Play"

func _on_close_options_button_pressed() -> void:
	if options_panel:
		options_panel.hide()
