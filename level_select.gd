extends Control

# Path where your level resources are stored
const LEVELS_DIR = "res://levels/"

@onready var level_grid = $MarginContainer/VBoxContainer/ScrollContainer/LevelGrid
@onready var back_button = $MarginContainer/VBoxContainer/BackButton

func _ready() -> void:
	# Connect back button behavior
	back_button.pressed.connect(_on_back_pressed)
	back_button.text = "Back"
	
	# Configure GridContainer alignment configurations
	level_grid.columns = 4
	level_grid.add_theme_constant_override("h_separation", 20)
	level_grid.add_theme_constant_override("v_separation", 20)
	
	# Force the Grid layout footprint to expand within the ScrollContainer space boundaries
	level_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Triggers the node tree generator generation immediately on load
	populate_level_menu()

func populate_level_menu() -> void:
	# Purge any old container child remnants or editor placeholders safely
	for child in level_grid.get_children():
		child.queue_free()
		
	var level_files = get_sorted_level_files()
	
	if level_files.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "No levels found!"
		empty_label.add_theme_font_size_override("font_size", 24)
		level_grid.add_child(empty_label)
		return

	# Iterate, instantiate, and align selection buttons
	for file_path in level_files:
		var resource = load(file_path)
		if resource and resource is LevelData:
			var btn = Button.new()
			btn.text = "Level " + str(resource.level_number)
			btn.custom_minimum_size = Vector2(150, 100)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			# Map click behaviors contextually to our level loading pipeline sequence
			btn.pressed.connect(func(): _on_level_selected(resource))
			level_grid.add_child(btn)

func get_sorted_level_files() -> Array:
	var files = []
	if not DirAccess.dir_exists_absolute(LEVELS_DIR):
		return files
		
	var dir = DirAccess.open(LEVELS_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				# Check for standard PC text resource files
				if file_name.ends_with(".tres"):
					files.append(LEVELS_DIR + file_name)
				# Check for compiled mobile files (.remap extensions)
				elif file_name.ends_with(".tres.remap"):
					var clean_name = file_name.replace(".remap", "")
					files.append(LEVELS_DIR + clean_name)
					
			file_name = dir.get_next()
		dir.list_dir_end()
		
	# Sort files numerically so level_10 doesn't sit between level_1 and level_2
	files.sort_custom(func(a, b):
		var num_a = int(a.get_file().get_basename().replace("level_", ""))
		var num_b = int(b.get_file().get_basename().replace("level_", ""))
		return num_a < num_b
	)
	return files

func _on_level_selected(level_resource: LevelData) -> void:
	print("Loading Selected Map: Level ", level_resource.level_number)
	
	# Replace with your actual gameplay main scene path!
	var gameplay_scene_path = "res://main.tscn" 
	get_tree().change_scene_to_file(gameplay_scene_path)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")
