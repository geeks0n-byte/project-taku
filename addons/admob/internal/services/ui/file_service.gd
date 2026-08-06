




static func write_file(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return

	file.store_string(content)
	file.close()
	update_file(path)


static func update_file(path: String) -> void:
	if not Engine.is_editor_hint() or path.is_empty() or not FileAccess.file_exists(path):
		return
	if DisplayServer.get_name() == "headless":
		return

	EditorInterface.get_resource_filesystem().update_file(path)
	refresh_filesystem()


static func refresh_filesystem() -> void:
	if not Engine.is_editor_hint():
		return
	if DisplayServer.get_name() == "headless":
		return

	var fs := EditorInterface.get_resource_filesystem()
	fs.scan()
	fs.scan_sources()
