
class_name AppOpenAd
extends MobileSingletonPlugin

static var _plugin = _get_plugin("PoingGodotAdMobAppOpenAd")
var full_screen_content_callback := FullScreenContentCallback.new()

var _uid: int
var on_ad_paid: Callable = func(_ad_value: AdValue): pass

var placement_id: int:
	get:
		if _plugin:
			return _plugin.get_placement_id(_uid)
		return 0
	set(value):
		if _plugin:
			_plugin.set_placement_id(_uid, value)


func _init(uid: int):
	self._uid = uid
	register_callbacks()


func show() -> void:
	if _plugin:
		_plugin.show(_uid)


func destroy() -> void:
	if _plugin:
		_plugin.destroy(_uid)


func get_ad_unit_id() -> String:
	if _plugin:
		return _plugin.get_ad_unit_id(_uid)
	return ""


func get_response_info() -> ResponseInfo:
	if _plugin:
		var response_info_dictionary: Dictionary = _plugin.get_response_info(_uid)
		return ResponseInfo.create(response_info_dictionary)
	return null


func register_callbacks() -> void:
	if _plugin:
		safe_connect(_plugin, "on_app_open_ad_clicked", _on_app_open_ad_clicked)
		safe_connect(
			_plugin,
			"on_app_open_ad_dismissed_full_screen_content",
			_on_app_open_ad_dismissed_full_screen_content
		)
		safe_connect(
			_plugin,
			"on_app_open_ad_failed_to_show_full_screen_content",
			_on_app_open_ad_failed_to_show_full_screen_content
		)
		safe_connect(_plugin, "on_app_open_ad_impression", _on_app_open_ad_impression)
		safe_connect(
			_plugin,
			"on_app_open_ad_showed_full_screen_content",
			_on_app_open_ad_showed_full_screen_content
		)
		safe_connect(_plugin, "on_app_open_ad_paid", _on_app_open_ad_paid)


func _on_app_open_ad_clicked(uid: int) -> void:
	if uid == _uid:
		full_screen_content_callback.on_ad_clicked.call_deferred()


func _on_app_open_ad_dismissed_full_screen_content(uid: int) -> void:
	if uid == _uid:
		full_screen_content_callback.on_ad_dismissed_full_screen_content.call_deferred()


func _on_app_open_ad_failed_to_show_full_screen_content(
	uid: int, ad_error_dictionary: Dictionary
) -> void:
	if uid == _uid:
		full_screen_content_callback.on_ad_failed_to_show_full_screen_content.call_deferred(
			AdError.create(ad_error_dictionary)
		)


func _on_app_open_ad_impression(uid: int) -> void:
	if uid == _uid:
		full_screen_content_callback.on_ad_impression.call_deferred()


func _on_app_open_ad_showed_full_screen_content(uid: int) -> void:
	if uid == _uid:
		full_screen_content_callback.on_ad_showed_full_screen_content.call_deferred()


func _on_app_open_ad_paid(uid: int, ad_value_dictionary: Dictionary) -> void:
	if uid == _uid:
		on_ad_paid.call_deferred(AdValue.create(ad_value_dictionary))
