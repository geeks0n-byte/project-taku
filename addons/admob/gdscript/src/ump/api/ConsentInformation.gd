




class_name ConsentInformation
extends MobileSingletonPlugin

static var _plugin := _get_plugin("PoingGodotAdMobConsentInformation")

enum ConsentStatus { UNKNOWN, NOT_REQUIRED, REQUIRED, OBTAINED }

enum PrivacyOptionsRequirementStatus {
	UNKNOWN,
	NOT_REQUIRED,
	REQUIRED,
}


func get_consent_status() -> ConsentStatus:
	if _plugin:
		return _plugin.get_consent_status()
	return ConsentStatus.UNKNOWN


func get_is_consent_form_available() -> bool:
	if _plugin:
		return _plugin.get_is_consent_form_available()
	return false


func get_privacy_options_requirement_status() -> PrivacyOptionsRequirementStatus:
	if _plugin:
		return _plugin.get_privacy_options_requirement_status()
	return PrivacyOptionsRequirementStatus.UNKNOWN


var _on_consent_info_updated_success_callback
var _on_consent_info_updated_failure_callback


func update(
	consent_request: ConsentRequestParameters,
	on_consent_info_updated_success := func(): pass,
	on_consent_info_updated_failure := func(form_error: FormError): pass,
) -> void:
	if _plugin:
		self._on_consent_info_updated_success_callback = on_consent_info_updated_success
		self._on_consent_info_updated_failure_callback = on_consent_info_updated_failure
		_plugin.update(consent_request.convert_to_dictionary())

		safe_connect(_plugin, "on_consent_info_updated_success", _on_consent_info_updated_success)
		safe_connect(_plugin, "on_consent_info_updated_failure", _on_consent_info_updated_failure)


func reset():
	if _plugin:
		_plugin.reset()


func _on_consent_info_updated_success() -> void:
	_on_consent_info_updated_success_callback.call_deferred()


func _on_consent_info_updated_failure(form_error_dictionary: Dictionary) -> void:
	_on_consent_info_updated_failure_callback.call_deferred(FormError.create(form_error_dictionary))
