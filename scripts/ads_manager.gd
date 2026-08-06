extends Node

const INTERSTITIAL_EVERY_N := 3

const TEST_BANNER_UNIT_ID := "ca-app-pub-3940256099942544/6300978111"
const TEST_INTERSTITIAL_UNIT_ID := "ca-app-pub-3940256099942544/1033173712"
const TEST_REWARDED_UNIT_ID := "ca-app-pub-3940256099942544/5224354917"

const PROD_BANNER_UNIT_ID := "ca-app-pub-1624206851803206/6555942665"
const PROD_INTERSTITIAL_UNIT_ID := "ca-app-pub-1624206851803206/8878973813"
const PROD_REWARDED_UNIT_ID := "ca-app-pub-1624206851803206/1850531037"

const PRIVACY_POLICY_URL := "https://geeks0n-byte.github.io/project-taku/privacy-policy.html"

var _initialized: bool = false
var _initializing: bool = false
var _ads_supported: bool = false

var _banner: AdView = null
var _banner_wanted_visible: bool = false
var _banner_loaded: bool = false

var _interstitial: InterstitialAd = null
var _interstitial_loader: InterstitialAdLoader = null
var _loading_interstitial: bool = false
var _pending_after_ad: Callable = Callable()

var _rewarded: RewardedAd = null
var _rewarded_loader: RewardedAdLoader = null
var _loading_rewarded: bool = false
var _pending_reward_callback: Callable = Callable()
var _reward_earned: bool = false
var _queued_reward_callback: Callable = Callable()
var _rewarded_retry_timer: Timer = null
const REWARDED_RETRY_SEC := 15.0

func _ready() -> void:
	_ads_supported = _detect_ads_support()
	call_deferred("ensure_started")

func _detect_ads_support() -> bool:
	if not (OS.has_feature("android") or OS.get_name() == "Android"):
		return false
	return ClassDB.class_exists("PoingGodotAdMob") or Engine.has_singleton("PoingGodotAdMob")

func is_ads_available() -> bool:
	return _ads_supported

func ensure_started() -> void:
	if _initialized or _initializing or not _ads_supported:
		return
	_initializing = true
	_request_consent_then_init()

func _request_consent_then_init() -> void:
	var params := ConsentRequestParameters.new()
	UserMessagingPlatform.consent_information.update(
		params,
		_on_consent_update_success,
		_on_consent_update_failure
	)

func _on_consent_update_success() -> void:
	if UserMessagingPlatform.consent_information.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(_on_consent_form_loaded, _on_consent_form_load_failed)
	else:
		_initialize_mobile_ads()

func _on_consent_update_failure(_error: FormError) -> void:
	_initialize_mobile_ads()

func _on_consent_form_loaded(form: ConsentForm) -> void:
	var status := UserMessagingPlatform.consent_information.get_consent_status()
	if status == ConsentInformation.ConsentStatus.REQUIRED:
		form.show(_on_consent_form_dismissed)
	else:
		_initialize_mobile_ads()

func _on_consent_form_load_failed(_error: FormError) -> void:
	_initialize_mobile_ads()

func _on_consent_form_dismissed(_error: FormError) -> void:
	_initialize_mobile_ads()

func _initialize_mobile_ads() -> void:
	var request_config := RequestConfiguration.new()
	MobileAds.set_request_configuration(request_config)
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		_initialized = true
		_initializing = false
		_load_interstitial()
		_load_rewarded()
		if _banner_wanted_visible:
			_ensure_banner_loaded()
	MobileAds.initialize(listener)

func _use_test_units() -> bool:
	return OS.is_debug_build()

func _banner_unit_id() -> String:
	return TEST_BANNER_UNIT_ID if _use_test_units() else PROD_BANNER_UNIT_ID

func _interstitial_unit_id() -> String:
	return TEST_INTERSTITIAL_UNIT_ID if _use_test_units() else PROD_INTERSTITIAL_UNIT_ID

func _rewarded_unit_id() -> String:
	return TEST_REWARDED_UNIT_ID if _use_test_units() else PROD_REWARDED_UNIT_ID


func show_menu_banner() -> void:
	_banner_wanted_visible = true
	if not _ads_supported:
		return
	ensure_started()
	if not _initialized:
		return
	_ensure_banner_loaded()
	if _banner and _banner_loaded:
		_banner.show()

func refresh_banner_anchor() -> void:
	_banner_wanted_visible = true
	if not _ads_supported:
		return
	ensure_started()
	if not _initialized:
		return
	_destroy_banner()
	_ensure_banner_loaded()

func hide_menu_banner() -> void:
	_banner_wanted_visible = false
	if _banner:
		_banner.hide()

func _ensure_banner_loaded() -> void:
	if not _initialized or _banner != null:
		if _banner and _banner_loaded and _banner_wanted_visible:
			_banner.show()
		return
	var ad_size := AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
	_banner = AdView.new(_banner_unit_id(), ad_size, AdPosition.BOTTOM)
	var listener := AdListener.new()
	listener.on_ad_loaded = func() -> void:
		_banner_loaded = true
		if _banner_wanted_visible and _banner:
			_banner.show()
		else:
			if _banner:
				_banner.hide()
	listener.on_ad_failed_to_load = func(_error: LoadAdError) -> void:
		_banner_loaded = false
	_banner.ad_listener = listener
	_banner.load_ad(AdRequest.new())
	_banner.hide()

func _destroy_banner() -> void:
	if _banner:
		_banner.destroy()
		_banner = null
	_banner_loaded = false


func _load_interstitial() -> void:
	if not _initialized or _loading_interstitial or _interstitial != null:
		return
	_loading_interstitial = true
	if _interstitial_loader == null:
		_interstitial_loader = InterstitialAdLoader.new()
	var callback := InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_loading_interstitial = false
		_interstitial = ad
		_bind_interstitial_callbacks()
	callback.on_ad_failed_to_load = func(_error: LoadAdError) -> void:
		_loading_interstitial = false
		_interstitial = null
	_interstitial_loader.load(_interstitial_unit_id(), AdRequest.new(), callback)

func _bind_interstitial_callbacks() -> void:
	if _interstitial == null:
		return
	var callbacks := FullScreenContentCallback.new()
	callbacks.on_ad_dismissed_full_screen_content = func() -> void:
		_destroy_interstitial()
		_finish_pending_after_ad()
		_load_interstitial()
	callbacks.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void:
		_destroy_interstitial()
		_finish_pending_after_ad()
		_load_interstitial()
	_interstitial.full_screen_content_callback = callbacks

func _destroy_interstitial() -> void:
	if _interstitial:
		_interstitial.destroy()
		_interstitial = null

func _finish_pending_after_ad() -> void:
	var cb := _pending_after_ad
	_pending_after_ad = Callable()
	if _banner_wanted_visible:
		refresh_banner_anchor()
	if cb.is_valid():
		cb.call()

func record_level_win(is_tutorial: bool) -> void:
	_record_interstitial_progress(is_tutorial)

func record_level_restart(is_tutorial: bool) -> void:
	_record_interstitial_progress(is_tutorial)

func _record_interstitial_progress(is_tutorial: bool) -> void:
	if is_tutorial:
		return
	if SaveManager:
		SaveManager.record_ad_win()

func show_interstitial_if_ready(on_done: Callable = Callable()) -> void:
	if not _ads_supported or not _initialized:
		if on_done.is_valid():
			on_done.call()
		return
	var due := SaveManager != null and SaveManager.should_show_interstitial(INTERSTITIAL_EVERY_N)
	if not due or _interstitial == null:
		if on_done.is_valid():
			on_done.call()
		if _interstitial == null:
			_load_interstitial()
		return
	_pending_after_ad = on_done
	if SaveManager:
		SaveManager.consume_interstitial_wins()
	_interstitial.show()


func can_offer_rewarded_hint() -> bool:
	return true

func is_rewarded_hint_ready() -> bool:
	if not _ads_supported:
		return OS.is_debug_build()
	return _initialized and _rewarded != null

func is_rewarded_hint_loading() -> bool:
	if not _ads_supported:
		return false
	return _initializing or _loading_rewarded or _queued_reward_callback.is_valid()

func warm_rewarded_hint() -> void:
	if not _ads_supported:
		return
	ensure_started()
	if _initialized:
		_load_rewarded()

func _load_rewarded() -> void:
	if not _initialized or _loading_rewarded or _rewarded != null:
		return
	_loading_rewarded = true
	if _rewarded_loader == null:
		_rewarded_loader = RewardedAdLoader.new()
	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: RewardedAd) -> void:
		_loading_rewarded = false
		_rewarded = ad
		_bind_rewarded_callbacks()
		_cancel_rewarded_retry()
		_flush_queued_rewarded_show()
	callback.on_ad_failed_to_load = func(_error: LoadAdError) -> void:
		_loading_rewarded = false
		_rewarded = null
		_schedule_rewarded_retry()
	_rewarded_loader.load(_rewarded_unit_id(), AdRequest.new(), callback)

func _bind_rewarded_callbacks() -> void:
	if _rewarded == null:
		return
	var callbacks := FullScreenContentCallback.new()
	callbacks.on_ad_dismissed_full_screen_content = func() -> void:
		var earned := _reward_earned
		var cb := _pending_reward_callback
		_pending_reward_callback = Callable()
		_reward_earned = false
		_destroy_rewarded()
		_load_rewarded()
		if earned and cb.is_valid():
			cb.call()
	callbacks.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void:
		_pending_reward_callback = Callable()
		_reward_earned = false
		_destroy_rewarded()
		_load_rewarded()
	_rewarded.full_screen_content_callback = callbacks

func _destroy_rewarded() -> void:
	if _rewarded:
		_rewarded.destroy()
		_rewarded = null

func _schedule_rewarded_retry() -> void:
	if not _ads_supported or not _initialized:
		return
	if _rewarded_retry_timer == null:
		_rewarded_retry_timer = Timer.new()
		_rewarded_retry_timer.one_shot = true
		_rewarded_retry_timer.timeout.connect(_on_rewarded_retry_timeout)
		add_child(_rewarded_retry_timer)
	if _rewarded_retry_timer.is_stopped():
		_rewarded_retry_timer.start(REWARDED_RETRY_SEC)

func _cancel_rewarded_retry() -> void:
	if _rewarded_retry_timer and not _rewarded_retry_timer.is_stopped():
		_rewarded_retry_timer.stop()

func _on_rewarded_retry_timeout() -> void:
	_load_rewarded()

func _flush_queued_rewarded_show() -> void:
	if not _queued_reward_callback.is_valid():
		return
	var cb := _queued_reward_callback
	_queued_reward_callback = Callable()
	show_rewarded_for_hint(cb)

func show_rewarded_for_hint(on_rewarded: Callable = Callable()) -> bool:
	if not _ads_supported:
		if OS.is_debug_build() and on_rewarded.is_valid():
			call_deferred("_invoke_rewarded_mock", on_rewarded)
			return true
		return false
	if not _initialized:
		ensure_started()
		_queued_reward_callback = on_rewarded
		return true
	if _rewarded == null:
		_queued_reward_callback = on_rewarded
		_load_rewarded()
		return true
	_queued_reward_callback = Callable()
	_pending_reward_callback = on_rewarded
	_reward_earned = false
	var reward_listener := OnUserEarnedRewardListener.new()
	reward_listener.on_user_earned_reward = func(_item: RewardedItem) -> void:
		_reward_earned = true
	_rewarded.show(reward_listener)
	return true

func _invoke_rewarded_mock(on_rewarded: Callable) -> void:
	if on_rewarded.is_valid():
		on_rewarded.call()


const PRIVACY_OPTIONS_STATE_UNAVAILABLE := 0
const PRIVACY_OPTIONS_STATE_LOADING := 1
const PRIVACY_OPTIONS_STATE_NOT_REQUIRED := 2
const PRIVACY_OPTIONS_STATE_READY := 3

func get_privacy_options_state() -> int:
	if not _ads_supported:
		return PRIVACY_OPTIONS_STATE_UNAVAILABLE
	ensure_started()
	if not _initialized:
		return PRIVACY_OPTIONS_STATE_LOADING
	var req := UserMessagingPlatform.consent_information.get_privacy_options_requirement_status()
	if req == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED:
		return PRIVACY_OPTIONS_STATE_READY
	if req == ConsentInformation.PrivacyOptionsRequirementStatus.NOT_REQUIRED:
		return PRIVACY_OPTIONS_STATE_NOT_REQUIRED
	return PRIVACY_OPTIONS_STATE_LOADING

func show_privacy_options_form(on_done: Callable = Callable()) -> bool:
	if get_privacy_options_state() != PRIVACY_OPTIONS_STATE_READY:
		return false
	UserMessagingPlatform.show_privacy_options_form(func(form_error: FormError) -> void:
		if on_done.is_valid():
			on_done.call(form_error)
	)
	return true

func open_privacy_policy() -> void:
	OS.shell_open(PRIVACY_POLICY_URL)

func prepare_for_app_exit() -> void:
	_banner_wanted_visible = false
	_pending_after_ad = Callable()
	_pending_reward_callback = Callable()
	_queued_reward_callback = Callable()
	_reward_earned = false
	_cancel_rewarded_retry()
	_destroy_banner()
	_destroy_interstitial()
	_destroy_rewarded()

func _exit_tree() -> void:
	prepare_for_app_exit()
