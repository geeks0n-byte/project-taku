
class_name IronSource
extends MobileSingletonPlugin

static var _plugin := _get_plugin("PoingGodotAdMobIronSource", false)


static func set_consent(consent: bool) -> void:
	if _plugin:
		_plugin.set_consent(consent)


static func set_metadata(key: String, value: String) -> void:
	if _plugin:
		_plugin.set_metadata(key, value)


static func set_user_id(user_id: String) -> void:
	if _plugin:
		_plugin.set_user_id(user_id)
