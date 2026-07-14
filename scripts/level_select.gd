extends Control

# ==========================================
# CONSTANTS & PATHS
# ==========================================
const CAMPAIGN_DIR = "res://levels/"
const DEV_DIR = "user://levels/"

# ==========================================
# NODE REFERENCES
# ==========================================
@onready var level_grid = $MarginContainer/VBoxContainer/ScrollContainer/LevelGrid
@onready var back_button = $MarginContainer/VBoxContainer/BackButton

# Navigation tab controls managed programmatically
var core_tab_button: Button
var custom_tab_button: Button

enum ViewMode { CORE, CUSTOM }
var current_view: ViewMode = ViewMode.CORE

# ==========================================
# INITIALIZATION
# ==========================================
func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	back_button.text = "Back"
	
	_setup_tab_headers()
	
	level_grid.add_theme_constant_override("h_separation", 20)
	level_grid.add_theme_constant_override("v_separation", 20)
	level_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	populate_level_menu()

func _setup_tab_headers() -> void:
	# Inserts a row layout container for the mode category headers above the main grid container
	var tab_layout = HBoxContainer.new()
	tab_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_layout.add_theme_constant_override("separation", 40)
	$MarginContainer/VBoxContainer.add_child(tab_layout)
	$MarginContainer/VBoxContainer.move_child(tab_layout, 0) # Force position to top of view stack
	
	core_tab_button = Button.new()
	core_tab_button.text = "CORE"
	core_tab_button.custom_minimum_size = Vector2(250, 60)
	core_tab_button.pressed.connect(func(): _switch_view(ViewMode.CORE))
	tab_layout.add_child(core_tab_button)
	
	custom_tab_button = Button.new()
	custom_tab_button.text = "CUSTOM"
	custom_tab_button.custom_minimum_size = Vector2(250, 60)
	custom_tab_button.pressed.connect(func(): _switch_view(ViewMode.CUSTOM))
	tab_layout.add_child(custom_tab_button)
	
	_update_tab_button_visuals()

func _switch_view(new_mode: ViewMode) -> void:
	if current_view == new_mode: return
	current_view = new_mode
	_update_tab_button_visuals()
	populate_level_menu()

func _update_tab_button_visuals() -> void:
	if current_view == ViewMode.CORE:
		core_tab_button.modulate = Color(0.4, 1.0, 0.4) # Highlighted color style
		custom_tab_button.modulate = Color(0.6, 0.6, 0.6) # Dimmed style
	else:
		core_tab_button.modulate = Color(0.6, 0.6, 0.6)
		custom_tab_button.modulate = Color(1.0, 0.84, 0.0)

# ==========================================
# CONTAINER BUILDERS
# ==========================================
func populate_level_menu() -> void:
	# Safely purge old remnants from the scene layout grid
	for child in level_grid.get_children():
		child.queue_free()
		
	var target_dir = CAMPAIGN_DIR if current_view == ViewMode.CORE else DEV_DIR
	var level_files = _scan_directory(target_dir)
	
	# Sort layout pathways numerically
	level_files.sort_custom(func(a, b):
		var num_a = int(a.get_file().get_basename().replace("level_", ""))
		var num_b = int(b.get_file().get_basename().replace("level_", ""))
		return num_a < num_b
	)
	
	var valid_level_count = 0

	for file_path in level_files:
		var resource = load(file_path)
		if resource and resource is LevelData:
			# STRICT SANITATION PASS: Throw away configurations that have entirely blank cells
			if _is_layout_empty(resource.layout):
				continue
				
			valid_level_count += 1
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(150, 100)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.add_theme_font_size_override("font_size", 32)
			
			if current_view == ViewMode.CUSTOM:
				btn.text = "Custom Level " + str(resource.level_number)
				btn.disabled = false
			else:
				var is_unlocked = SaveManager.is_level_unlocked(resource.level_number)
				if is_unlocked:
					btn.text = "Level " + str(resource.level_number)
					btn.disabled = false
				else:
					btn.text = "Level " + str(resource.level_number) + "\n(Locked)"
					btn.disabled = true
			
			btn.pressed.connect(func(): _on_level_selected(resource))
			level_grid.add_child(btn)
			
	if valid_level_count == 0:
		var empty_label = Label.new()
		empty_label.text = "No playable levels found in this category!"
		empty_label.add_theme_font_size_override("font_size", 24)
		level_grid.add_child(empty_label)

func _is_layout_empty(layout: Dictionary) -> bool:
	for coord in layout:
		if layout[coord] != -1:
			return false
	return true

func _scan_directory(path_to_scan: String) -> Array:
	var found_files = []
	if not DirAccess.dir_exists_absolute(path_to_scan):
		return found_files
		
	var dir = DirAccess.open(path_to_scan)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.ends_with(".tres"):
					found_files.append(path_to_scan + file_name)
				elif file_name.ends_with(".tres.remap"):
					found_files.append(path_to_scan + file_name.replace(".remap", ""))
			file_name = dir.get_next()
		dir.list_dir_end()
	return found_files

# ==========================================
# VIEW NAVIGATION
# ==========================================
func _on_level_selected(level_resource: LevelData) -> void:
	GlobalGameManager.selected_level_resource = level_resource
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
