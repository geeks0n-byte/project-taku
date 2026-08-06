




const EXPORT_PRESETS_PATH := "res://export_presets.cfg"


static func get_activated_plugins(platform_name: String) -> Array[String]:
	var activated_plugins: Array[String] = []

	if not FileAccess.file_exists(EXPORT_PRESETS_PATH):
		return activated_plugins

	var config := ConfigFile.new()
	var err := config.load(EXPORT_PRESETS_PATH)
	if err != OK:
		return activated_plugins

	for section in config.get_sections():
		if not section.begins_with("preset."):
			continue

		var platform = config.get_value(section, "platform", "")
		if platform != platform_name:
			continue

		var options_section = section + ".options"
		if config.has_section(options_section):
			for key in config.get_section_keys(options_section):
				if key.begins_with("plugins/"):
					var is_enabled = config.get_value(options_section, key, false)
					if is_enabled:
						var plugin_name = key.trim_prefix("plugins/")
						if not activated_plugins.has(plugin_name):
							activated_plugins.append(plugin_name)

	return activated_plugins
