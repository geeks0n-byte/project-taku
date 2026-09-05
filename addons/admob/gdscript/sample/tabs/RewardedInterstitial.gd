
extends "res://addons/admob/gdscript/sample/tabs/BaseTab.gd"

const Registry = preload("res://addons/admob/internal/sample_registry.gd")

var _rewarded_interstitial_ad: RewardedInterstitialAd
var _reward_listener := OnUserEarnedRewardListener.new()
var _load_callback := RewardedInterstitialAdLoadCallback.new()
var _content_callback := FullScreenContentCallback.new()

@onready var _load_button: Button = $Load
@onready var _show_button: Button = $Show
@onready var _destroy_button: Button = $Destroy


func _ready() -> void:
	super()
	_reward_listener.on_user_earned_reward = _on_user_earned_reward

	_load_callback.on_ad_failed_to_load = _on_ad_failed_to_load
	_load_callback.on_ad_loaded = _on_ad_loaded

	_content_callback.on_ad_clicked = func() -> void: _log("Ad clicked")
	_content_callback.on_ad_dismissed_full_screen_content = func() -> void:
		_log("Ad dismissed")
		_destroy_ad()

	_content_callback.on_ad_failed_to_show_full_screen_content = func(_err: AdError) -> void:
		_log("Failed to show: " + _err.message)
	_content_callback.on_ad_impression = func() -> void: _log("Impression recorded")
	_content_callback.on_ad_showed_full_screen_content = func() -> void: _log("Ad showed")

	_update_ui_state(false)


func _update_ui_state(is_loaded: bool) -> void:
	_load_button.disabled = is_loaded
	_show_button.disabled = !is_loaded
	_destroy_button.disabled = !is_loaded


func _on_load_pressed() -> void:
	_log("Loading rewarded interstitial...")
	var unit_id := (
		"ca-app-pub-3940256099942544/5354046379"
		if OS.get_name() == "Android"
		else "ca-app-pub-3940256099942544/6978759866"
	)
	RewardedInterstitialAdLoader.new().load(unit_id, AdRequest.new(), _load_callback)


func _on_show_pressed() -> void:
	if _rewarded_interstitial_ad:
		_log("Showing rewarded interstitial ad...")
		_rewarded_interstitial_ad.show(_reward_listener)


func _on_destroy_pressed() -> void:
	_destroy_ad()


func _destroy_ad() -> void:
	if _rewarded_interstitial_ad:
		_rewarded_interstitial_ad.destroy()
		_rewarded_interstitial_ad = null
		_log("Ad destroyed")
		_update_ui_state(false)


func _on_user_earned_reward(item: RewardedItem) -> void:
	_log("Reward earned: %d %s" % [item.amount, item.type])


func _on_ad_failed_to_load(error: LoadAdError) -> void:
	_log("Failed to load: " + error.message)
	_update_ui_state(false)


func _on_ad_loaded(ad: RewardedInterstitialAd) -> void:
	_log("Ad loaded successfully (UID: %s)" % str(ad._uid))
	ad.full_screen_content_callback = _content_callback
	ad.on_ad_paid = func(_ad_value: AdValue) -> void:
		var ad_source_name := "N/A"
		var response_info := ad.get_response_info()
		if response_info:
			if response_info.loaded_adapter_response_info:
				ad_source_name = response_info.loaded_adapter_response_info.ad_source_name
			else:
				ad_source_name = "None"
		_log(
			(
				"Ad paid: %f %s (precision: %d, source: %s)"
				% [
					_ad_value.value_micros / 1000000.0,
					_ad_value.currency_code,
					_ad_value.precision,
					ad_source_name
				]
			)
		)

	var ssv_options := ServerSideVerificationOptions.new()
	ssv_options.custom_data = "TEST_DATA"
	ad.set_server_side_verification_options(ssv_options)

	_rewarded_interstitial_ad = ad
	_update_ui_state(true)




func _log(message: String) -> void:
	if Registry.logger:
		Registry.logger.log_message("[RewardedInterstitial] " + message)
	else:
		print("[RewardedInterstitial] " + message)
