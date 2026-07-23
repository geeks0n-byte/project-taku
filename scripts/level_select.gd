extends Control

const CAMPAIGN_DIR = "res://levels/"
const DEV_DIR = "user://levels/"

@onready var level_grid = find_child("LevelGrid", true, false)
@onready var back_button = find_child("BackButton", true, false)
@onready var core_tab_button = find_child("CoreTabButton", true, false)
@onready var custom_tab_button = find_child("CustomTabButton", true, false)
@onready var button_template = find_child("LevelButtonTemplate", true, false)
@onready var empty_state_label = find_child("EmptyStateLabel", true, false)
@onready var scroll_container = find_child("ScrollContainer", true, false)

enum ViewMode { CORE, CUSTOM }
var current_view: ViewMode = ViewMode.CORE

func _ready() -> void:
	if back_button: back_button.pressed.connect(_on_back_pressed)
	if core_tab_button: core_tab_button.pressed.connect(func(): _switch_view(ViewMode.CORE))
	if custom_tab_button: custom_tab_button.pressed.connect(func(): _switch_view(ViewMode.CUSTOM))
	if button_template: button_template.visible = false
	_update_tab_button_visuals()
	populate_level_menu()

func _switch_view(new_mode: ViewMode) -> void:
	if current_view == new_mode: return
	current_view = new_mode
	_update_tab_button_visuals()
	populate_level_menu()

func _update_tab_button_visuals() -> void:
	if current_view == ViewMode.CORE:
		if core_tab_button: core_tab_button.modulate = Color(0.4, 1.0, 0.4) 
		if custom_tab_button: custom_tab_button.modulate = Color(0.6, 0.6, 0.6) 
	else:
		if core_tab_button: core_tab_button.modulate = Color(0.6, 0.6, 0.6)
		if custom_tab_button: custom_tab_button.modulate = Color(1.0, 0.84, 0.0)

func populate_level_menu() -> void:
	for child in level_grid.get_children():
		if child != button_template: child.queue_free()
		
	var target_dir = CAMPAIGN_DIR if current_view == ViewMode.CORE else DEV_DIR
	var level_files = _scan_directory(target_dir)
	level_files.sort_custom(func(a, b):
		var num_a = int(a.get_file().get_basename().replace("level_", ""))
		var num_b = int(b.get_file().get_basename().replace("level_", ""))
		return num_a < num_b
	)
	
	var valid_level_count = 0
	for file_path in level_files:
		var resource = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_REPLACE)
		if resource and resource is LevelData:
			valid_level_count += 1
			if button_template:
				var btn = button_template.duplicate()
				btn.visible = true
				if current_view == ViewMode.CUSTOM:
					btn.text = tr("CUSTOM_LVL") + " " + str(resource.level_number)
					btn.disabled = false
					btn.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
				else:
					var is_unlocked = SaveManager.is_level_unlocked(resource.level_number)
					if is_unlocked:
						btn.text = tr("LEVEL") + "\n" + str(resource.level_number)
						btn.disabled = false
						btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
					else:
						btn.text = tr("LEVEL") + "\n" + str(resource.level_number) + "\n(" + tr("LOCKED") + ")"
						btn.disabled = true
						btn.add_theme_color_override("font_disabled_color", Color(0.8, 0.4, 0.4))
				btn.pressed.connect(func(): _on_level_selected(resource))
				level_grid.add_child(btn)
			
	if empty_state_label and scroll_container:
		empty_state_label.visible = (valid_level_count == 0)
		scroll_container.visible = (valid_level_count > 0)

func _scan_directory(path_to_scan: String) -> Array:
	var found_files = []
	if not DirAccess.dir_exists_absolute(path_to_scan): return found_files
	var dir = DirAccess.open(path_to_scan)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.ends_with(".tres"): found_files.append(path_to_scan + file_name)
				elif file_name.ends_with(".tres.remap"): found_files.append(path_to_scan + file_name.replace(".remap", ""))
			file_name = dir.get_next()
		dir.list_dir_end()
	return found_files

func _on_level_selected(level_resource: LevelData) -> void:
	GlobalGameManager.selected_level_resource = level_resource
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
