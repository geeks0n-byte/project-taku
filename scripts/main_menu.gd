extends Control

# ==========================================
# EXPORT SLOTS & CONFIGURATIONS
# ==========================================
@export var gameplay_scene : PackedScene

const DEV_LEVELS_DIR = "user://levels/"

# ==========================================
# NODE REFERENCES
# ==========================================
@onready var options_panel: Panel = $OptionsPanel

@onready var clear_save_button: Button = $OptionsPanel/DeleteSaveButton 
@onready var clear_custom_button: Button = get_node_or_null("OptionsPanel/DeleteCustomButton")
@onready var close_options_button: Button = $OptionsPanel/CloseOptionsButton
@onready var status_label: Label = $OptionsPanel/StatusLabel

@onready var start_button: Button = get_node_or_null("MarginContainer/MainLayout/ButtonList/StartButton")

var input_blocker: ColorRect

# ==========================================
# MAIN INITIALIZATION
# ==========================================
func _ready() -> void:
	input_blocker = ColorRect.new()
	input_blocker.color = Color(0, 0, 0, 0.6) 
	input_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP 
	input_blocker.hide()
	add_child(input_blocker)
	
	if options_panel:
		move_child(input_blocker, options_panel.get_index())
		
		var panel_size = Vector2(500, 480) 
		options_panel.custom_minimum_size = panel_size
		options_panel.size = panel_size
		
		var screen_size = get_viewport_rect().size
		options_panel.position = (screen_size - panel_size) / 2
		
		# --- REVERTED & FIXED: Solid Background For Options ---
		var solid_style = StyleBoxFlat.new()
		solid_style.bg_color = Color(0.12, 0.12, 0.12, 1.0) # Solid dark gray
		options_panel.add_theme_stylebox_override("panel", solid_style)
		options_panel.self_modulate = Color(1, 1, 1, 1) # Ensure 100% opacity
		# ------------------------------------------------------
		
		if clear_save_button: 
			clear_save_button.size = Vector2(350, 60)
			clear_save_button.position = Vector2((panel_size.x - 350) / 2, 60)
			if not clear_save_button.pressed.is_connected(_on_delete_save_button_pressed):
				clear_save_button.pressed.connect(_on_delete_save_button_pressed)
				
		if clear_custom_button:
			clear_custom_button.text = "Delete All Custom Levels"
			clear_custom_button.size = Vector2(350, 60)
			clear_custom_button.position = Vector2((panel_size.x - 350) / 2, 140)
			if not clear_custom_button.pressed.is_connected(_on_delete_custom_button_pressed):
				clear_custom_button.pressed.connect(_on_delete_custom_button_pressed)
			
		if close_options_button:
			close_options_button.size = Vector2(350, 60)
			close_options_button.position = Vector2((panel_size.x - 350) / 2, 220)
			if not close_options_button.pressed.is_connected(_on_close_options_button_pressed):
				close_options_button.pressed.connect(_on_close_options_button_pressed)
			
		if status_label:
			status_label.text = ""
			status_label.size = Vector2(460, 100)
			status_label.position = Vector2((panel_size.x - 460) / 2, 320)
			status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		
		options_panel.hide()
		
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
	if input_blocker:
		input_blocker.show()
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
	SaveManager.delete_save_file()
	
	if status_label:
		status_label.text = "Save file physically deleted!\nProgress reset to Level 1."
		status_label.modulate = Color(0.4, 1.0, 0.4)
		
	if start_button:
		start_button.text = "Play"

func _on_delete_custom_button_pressed() -> void:
	if DirAccess.dir_exists_absolute(DEV_LEVELS_DIR):
		var dir = DirAccess.open(DEV_LEVELS_DIR)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".remap")):
					DirAccess.remove_absolute(DEV_LEVELS_DIR + file_name)
				file_name = dir.get_next()
			dir.list_dir_end()
			
	if status_label:
		status_label.text = "All custom levels have been deleted from your device!"
		status_label.modulate = Color(1.0, 0.6, 0.2)

func _on_close_options_button_pressed() -> void:
	if input_blocker:
		input_blocker.hide()
	if options_panel:
		options_panel.hide()
