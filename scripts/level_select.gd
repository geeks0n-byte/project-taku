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

# ==========================================
# INITIALIZATION
# ==========================================
func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	back_button.text = "Back"
	
	level_grid.add_theme_constant_override("h_separation", 20)
	level_grid.add_theme_constant_override("v_separation", 20)
	level_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	populate_level_menu()

# ==========================================
# CONTAINER BUILDERS
# ==========================================
func populate_level_menu() -> void:
	for child in level_grid.get_children():
		child.queue_free()
		
	var level_files = get_sorted_level_files()
	
	if level_files.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "No levels found!"
		empty_label.add_theme_font_size_override("font_size", 24)
		level_grid.add_child(empty_label)
		return

	var processed_levels = {}

	for file_path in level_files:
		var resource = load(file_path)
		if resource and resource is LevelData:
			if processed_levels.has(resource.level_number):
				continue # Priority is given to your newer dev folders to overwrite old templates
				
			processed_levels[resource.level_number] = true
			
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(150, 100)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.add_theme_font_size_override("font_size", 32)
			
			var is_unlocked = SaveManager.is_level_unlocked(resource.level_number)
			
			if is_unlocked:
				btn.text = "Level " + str(resource.level_number)
				btn.disabled = false
			else:
				btn.text = "Level " + str(resource.level_number) + "\n(Locked)"
				btn.disabled = true
			
			btn.pressed.connect(func(): _on_level_selected(resource))
			level_grid.add_child(btn)

# ==========================================
# SCANNING UTILITIES
# ==========================================
func get_sorted_level_files() -> Array:
	var files = []
	
	# Scans user folder drafts first so they merge cleanly on top of PC project builds
	files.append_array(_scan_directory(DEV_DIR))
	files.append_array(_scan_directory(CAMPAIGN_DIR))
	
	files.sort_custom(func(a, b):
		var num_a = int(a.get_file().get_basename().replace("level_", ""))
		var num_b = int(b.get_file().get_basename().replace("level_", ""))
		return num_a < num_b
	)
	return files

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
					var clean_name = file_name.replace(".remap", "")
					found_files.append(path_to_scan + clean_name)
					
			file_name = dir.get_next()
		dir.list_dir_end()
		
	return found_files

# ==========================================
# VIEW NAVIGATION
# ==========================================
func _on_level_selected(level_resource: LevelData) -> void:
	print("Passing to Global Courier: Level ", level_resource.level_number)
	GlobalGameManager.selected_level_resource = level_resource
	var gameplay_scene_path = "res://scenes/main.tscn" 
	get_tree().change_scene_to_file(gameplay_scene_path)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
