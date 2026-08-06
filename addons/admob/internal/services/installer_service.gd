




const PluginVersion := preload("res://addons/admob/internal/version/plugin_version.gd")


static func create_package_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		var content := """# This file is dynamically generated.

const VERSION := "%s"
""" % PluginVersion.current
		file.store_string(content)
		file.close()

	var gitignore_path := path.get_base_dir().get_base_dir().path_join(".gitignore")
	if not FileAccess.file_exists(gitignore_path):
		var gitignore_file := FileAccess.open(gitignore_path, FileAccess.WRITE)
		if gitignore_file:
			var gitignore_content := """# Remove the line below if you want to commit the binaries to your repository
/bin
"""
			gitignore_file.store_string(gitignore_content)
			gitignore_file.close()
