
class_name AppLovin
extends MobileSingletonPlugin

static var _plugin := _get_plugin("PoingGodotAdMobAppLovin", false)


static func set_has_user_consent(has_user_consent: bool) -> void:
	if _plugin:
		_plugin.set_has_user_consent(has_user_consent)


static func set_do_not_sell(do_not_sell: bool) -> void:
	if _plugin:
		_plugin.set_do_not_sell(do_not_sell)


static func set_muted(muted: bool) -> void:
	if _plugin:
		_plugin.set_muted(muted)
