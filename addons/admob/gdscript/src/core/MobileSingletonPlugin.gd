




class_name MobileSingletonPlugin


static func _get_plugin(plugin_name: String, is_required := true) -> Object:
	if Engine.has_singleton(plugin_name):
		return Engine.get_singleton(plugin_name)

	var os_name := OS.get_name()
	if os_name != "Android" and os_name != "iOS":
		if OS.has_feature("editor"):
			var MockFactory = load("res://addons/admob/internal/mock/mock_admob_factory.gd")
			if MockFactory:
				return MockFactory.get_mock_plugin(plugin_name)
		return null

	var location := (
		"the Project Settings and 'Use Gradle Build' is enabled"
		if os_name == "Android"
		else "the 'Plugins' section of the Export tab"
	)
	var message := plugin_name + " not found, make sure it is enabled in " + location

	if is_required:
		printerr(message)
	else:
		push_warning(message)

	return null


static func safe_connect(
	plugin: Object, signal_name: String, callable: Callable, flags := 0
) -> void:
	if plugin and not plugin.is_connected(signal_name, callable):
		plugin.connect(signal_name, callable, flags)


static func safe_disconnect(plugin: Object, signal_name: String, callable: Callable) -> void:
	if plugin and plugin.is_connected(signal_name, callable):
		plugin.disconnect(signal_name, callable)
