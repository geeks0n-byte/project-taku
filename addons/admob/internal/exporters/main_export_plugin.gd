




extends EditorExportPlugin

const CFG_FILE_PATH := "res://addons/admob/plugin.cfg"


func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	var file = FileAccess.open(CFG_FILE_PATH, FileAccess.READ)
	if file:
		print("Exporting Poing AdMob '.cfg' file")
		add_file(CFG_FILE_PATH, file.get_buffer(file.get_length()), false)
	file.close()


func _get_name() -> String:
	return "PoingAdMob"
