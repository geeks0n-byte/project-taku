




static func manage_visibility(editor_plugin: EditorPlugin = null) -> void:
	var is_mono_version := ClassDB.class_exists("CSharpScript")
	var is_csharp_project := false

	var files := DirAccess.get_files_at("res://")
	for file in files:
		if file.get_extension() == "csproj" or file.get_extension() == "sln":
			is_csharp_project = true
			break

	var csharp_gdignore_path := "res://addons/admob/csharp/.gdignore"
	var should_hide := not is_mono_version or not is_csharp_project
	var file_system_modified := false

	if not should_hide:
		if FileAccess.file_exists(csharp_gdignore_path):
			DirAccess.remove_absolute(csharp_gdignore_path)
			file_system_modified = true
	else:
		if not FileAccess.file_exists(csharp_gdignore_path):
			var ignore_file := FileAccess.open(csharp_gdignore_path, FileAccess.WRITE)
			if ignore_file:
				ignore_file.store_string("")
				ignore_file.close()
				file_system_modified = true

	if file_system_modified and editor_plugin:
		_refresh_filesystem(editor_plugin, csharp_gdignore_path)


static func _refresh_filesystem(editor_plugin: EditorPlugin = null, file_path: String = "") -> void:
	if not editor_plugin:
		return

	var filesystem := editor_plugin.get_editor_interface().get_resource_filesystem()
	if not filesystem:
		return

	filesystem.update_file(file_path)

	var timer := editor_plugin.get_tree().create_timer(1.0)
	timer.timeout.connect(
		func():
			if filesystem and not filesystem.is_scanning():
				filesystem.scan()
	)
