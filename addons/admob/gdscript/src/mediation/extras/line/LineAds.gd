




class_name LineAds
extends MobileSingletonPlugin

static var _plugin := _get_plugin("PoingGodotAdMobLine", false)


static func set_test_mode(test_mode: bool) -> void:
	if _plugin:
		_plugin.set_test_mode(test_mode)
