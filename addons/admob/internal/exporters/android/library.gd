




const ROOT_BIN_PATH := "res://addons/admob/android/bin"

var path: String
var is_enabled: bool


func _init(p_path: String, p_is_enabled: bool = true) -> void:
	path = p_path
	is_enabled = p_is_enabled


func get_full_path() -> String:
	return ROOT_BIN_PATH + "/" + path + "/poing_godot_admob_" + path + ".gd"


func get_plugin() -> EditorExportPlugin:
	return load(get_full_path()).new()
