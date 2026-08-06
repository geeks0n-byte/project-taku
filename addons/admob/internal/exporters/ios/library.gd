




const ROOT_BIN_PATH := "res://addons/admob/ios/bin"

var path: String
var is_enabled: bool


func _init(p_path: String, p_is_enabled: bool = true) -> void:
	path = p_path
	is_enabled = p_is_enabled


func get_config_script_path() -> String:
	return ROOT_BIN_PATH + "/" + path + "/poing_godot_admob_" + path + ".gd"


func get_config() -> EditorExportPlugin:
	var script_path := get_config_script_path()
	if not FileAccess.file_exists(script_path):
		push_error("AdMob: iOS library configuration not found at " + script_path)
		return null
	return load(script_path).new()
