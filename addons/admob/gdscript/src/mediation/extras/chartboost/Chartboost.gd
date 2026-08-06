




class_name Chartboost
extends MobileSingletonPlugin

static var _plugin := _get_plugin("PoingGodotAdMobChartboost", false)


static func set_consent(consent: bool) -> void:
	if _plugin:
		_plugin.set_consent(consent)


static func set_ccpa_consent(consent: bool) -> void:
	if _plugin:
		_plugin.set_ccpa_consent(consent)
