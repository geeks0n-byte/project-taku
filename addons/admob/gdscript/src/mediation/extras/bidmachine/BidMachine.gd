
class_name BidMachine
extends MobileSingletonPlugin

static var _plugin := _get_plugin("PoingGodotAdMobBidMachine", false)


static func set_subject_to_gdpr(subject_to_gdpr: bool) -> void:
	if _plugin:
		_plugin.set_subject_to_gdpr(subject_to_gdpr)


static func set_consent_status(consent_status: bool) -> void:
	if _plugin:
		_plugin.set_consent_status(consent_status)


static func set_us_privacy_string(us_privacy_string: String) -> void:
	if _plugin:
		_plugin.set_us_privacy_string(us_privacy_string)
