




class_name UserMessagingPlatform
extends MobileSingletonPlugin

static var _plugin := _get_plugin("PoingGodotAdMobUserMessagingPlatform")

static var consent_information := ConsentInformation.new()

static var active_consent_form: ConsentForm

static var _on_consent_form_load_success_listener_callback
static var _on_consent_form_load_failure_listener_callback
static var _on_privacy_options_form_dismissed_callback


static func load_consent_form(
	on_consent_form_load_success_listener := func(consent_form: ConsentForm): pass,
	on_consent_form_load_failure_listener := func(form_error: FormError): pass
) -> void:
	if _plugin:
		_on_consent_form_load_success_listener_callback = on_consent_form_load_success_listener
		_on_consent_form_load_failure_listener_callback = on_consent_form_load_failure_listener
		_plugin.load_consent_form()
		safe_connect(
			_plugin,
			"on_consent_form_load_success_listener",
			_on_consent_form_load_success_listener,
			CONNECT_ONE_SHOT
		)
		safe_connect(
			_plugin,
			"on_consent_form_load_failure_listener",
			_on_consent_form_load_failure_listener,
			CONNECT_ONE_SHOT
		)


static func show_privacy_options_form(
	on_privacy_options_form_dismissed := func(form_error: FormError): pass
) -> void:
	if _plugin:
		_on_privacy_options_form_dismissed_callback = on_privacy_options_form_dismissed
		_plugin.show_privacy_options_form()
		safe_connect(
			_plugin,
			"on_privacy_options_form_dismissed_listener",
			_on_privacy_options_form_dismissed_listener,
			CONNECT_ONE_SHOT
		)


static func _on_consent_form_load_success_listener(UID: int) -> void:
	_on_consent_form_load_success_listener_callback.call_deferred(ConsentForm.new(UID))


static func _on_consent_form_load_failure_listener(form_error_dictionary: Dictionary) -> void:
	_on_consent_form_load_failure_listener_callback.call_deferred(
		FormError.create(form_error_dictionary)
	)


static func _on_privacy_options_form_dismissed_listener(form_error_dictionary: Dictionary) -> void:
	var form_error := (
		FormError.create(form_error_dictionary) if not form_error_dictionary.is_empty() else null
	)
	_on_privacy_options_form_dismissed_callback.call_deferred(form_error)
