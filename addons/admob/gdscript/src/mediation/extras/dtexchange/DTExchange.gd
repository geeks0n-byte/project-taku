
class_name DTExchange
extends MobileSingletonPlugin

static var _plugin := _get_plugin("PoingGodotAdMobDTExchange", false)


static func set_gdpr_consent(consent: bool) -> void:
	if _plugin:
		_plugin.set_gdpr_consent(consent)


static func set_gdpr_consent_string(consent_string: String) -> void:
	if _plugin:
		_plugin.set_gdpr_consent_string(consent_string)


static func set_ccpa_string(ccpa_string: String) -> void:
	if _plugin:
		_plugin.set_ccpa_string(ccpa_string)
