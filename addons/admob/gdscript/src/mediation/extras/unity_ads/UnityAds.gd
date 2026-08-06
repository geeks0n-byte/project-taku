
class_name UnityAds
extends MobileSingletonPlugin

static var _plugin := _get_plugin("PoingGodotAdMobUnityAds", false)


static func set_consent(consent: bool) -> void:
	if _plugin:
		_plugin.set_consent(consent)


static func set_privacy_consent(privacy_type: String, consent: bool) -> void:
	if _plugin:
		_plugin.set_privacy_consent(privacy_type, consent)
