extends Node

const INTERSTITIAL_START_EVERY_N := 5

const TEST_BANNER_UNIT_ID := "ca-app-pub-3940256099942544/6300978111"
const TEST_INTERSTITIAL_UNIT_ID := "ca-app-pub-3940256099942544/1033173712"
# Google sample Rewarded Interstitial (matches PROD format).
const TEST_REWARDED_UNIT_ID := "ca-app-pub-3940256099942544/5354046379"

const PROD_BANNER_UNIT_ID := "ca-app-pub-1624206851803206/6555942665"
const PROD_INTERSTITIAL_UNIT_ID := "ca-app-pub-1624206851803206/8878973813"
const PROD_REWARDED_UNIT_ID := "ca-app-pub-1624206851803206/1850531037"

const PRIVACY_POLICY_URL := "https://geeks0n-byte.github.io/project-taku/privacy-policy.html"

signal fullscreen_ad_started
signal fullscreen_ad_finished

var _initialized: bool = false
var _initializing: bool = false
var _ads_supported: bool = false
var _fullscreen_ad_open: bool = false

var _banner: AdView = null
var _banner_wanted_visible: bool = false
var _banner_loaded: bool = false

var _interstitial: InterstitialAd = null
var _loading_interstitial: bool = false
var _pending_after_ad: Callable = Callable()
## Session-only interstitial cadence: first at 5 events, then +1 after each shown ad.
var _interstitial_progress: int = 0
var _interstitial_every_n: int = INTERSTITIAL_START_EVERY_N

var _rewarded: RewardedInterstitialAd = null
var _rewarded_loader: RewardedInterstitialAdLoader = null
var _loading_rewarded: bool = false
var _pending_reward_callback: Callable = Callable()
var _reward_earned: bool = false
var _queued_reward_callback: Callable = Callable()
var _rewarded_retry_timer: Timer = null
var _rewarded_load_watchdog: Timer = null
var _focus_banner_settle_timer: Timer = null
var _focus_banner_settle_ticks: int = 0
const REWARDED_RETRY_SEC := 8.0
const REWARDED_LOAD_TIMEOUT_SEC := 25.0
const FOCUS_BANNER_SETTLE_TRIES := 5
const FOCUS_BANNER_SETTLE_SEC := 0.2

func _ready() -> void:
	_ads_supported = _detect_ads_support()
	call_deferred("ensure_started")

func _notify_fullscreen_started() -> void:
	if _fullscreen_ad_open:
		return
	_fullscreen_ad_open = true
	fullscreen_ad_started.emit()

func _notify_fullscreen_finished() -> void:
	if not _fullscreen_ad_open:
		return
	_fullscreen_ad_open = false
	fullscreen_ad_finished.emit()

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


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_on_app_focus_in()

func _on_app_focus_in() -> void:
	_dismiss_soft_keyboard()
	if _banner_wanted_visible:
		_pin_banner_bottom()
		call_deferred("_pin_banner_bottom")
		_schedule_banner_focus_settle()
	warm_rewarded_hint()

func _dismiss_soft_keyboard() -> void:
	var tree := get_tree()
	if tree and tree.root:
		var vp := tree.root.get_viewport()
		if vp:
			vp.gui_release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()

func _schedule_banner_focus_settle() -> void:
	_focus_banner_settle_ticks = 0
	if _focus_banner_settle_timer == null:
		_focus_banner_settle_timer = Timer.new()
		_focus_banner_settle_timer.one_shot = true
		_focus_banner_settle_timer.timeout.connect(_on_banner_focus_settle)
		add_child(_focus_banner_settle_timer)
	_focus_banner_settle_timer.start(FOCUS_BANNER_SETTLE_SEC)

func _on_banner_focus_settle() -> void:
	_dismiss_soft_keyboard()
	if _banner_wanted_visible:
		_pin_banner_bottom()
	_focus_banner_settle_ticks += 1
	if _focus_banner_settle_ticks >= FOCUS_BANNER_SETTLE_TRIES:
		return
	var kb_h := 0
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		kb_h = DisplayServer.virtual_keyboard_get_height()
	# Keep settling while IME is closing, or for a couple frames after resume.
	if kb_h > 0 or _focus_banner_settle_ticks < 3:
		_focus_banner_settle_timer.start(FOCUS_BANNER_SETTLE_SEC)

func show_menu_banner() -> void:
	_banner_wanted_visible = true
	if not _ads_supported:
		return
	ensure_started()
	if not _initialized:
		return
	_ensure_banner_loaded()
	if _banner and _banner_loaded:
		_show_banner_pinned()

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

func _pin_banner_bottom() -> void:
	if _banner == null:
		return
	_banner.set_position(AdPosition.BOTTOM)

func _show_banner_pinned() -> void:
	if _banner == null:
		return
	_pin_banner_bottom()
	_banner.show()
	call_deferred("_pin_banner_bottom")

func _ensure_banner_loaded() -> void:
	if not _initialized or _banner != null:
		if _banner and _banner_loaded and _banner_wanted_visible:
			_show_banner_pinned()
		return
	var ad_size := AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
	_banner = AdView.new(_banner_unit_id(), ad_size, AdPosition.BOTTOM)
	var listener := AdListener.new()
	listener.on_ad_loaded = func() -> void:
		_banner_loaded = true
		if _banner_wanted_visible and _banner:
			_show_banner_pinned()
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

func _reanchor_banner_after_fullscreen() -> void:
	if not _banner_wanted_visible:
		return
	refresh_banner_anchor()


func _load_interstitial() -> void:
	if not _initialized or _loading_interstitial or _interstitial != null:
		return
	_loading_interstitial = true
	var loader := InterstitialAdLoader.new()
	var callback := InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_loading_interstitial = false
		_interstitial = ad
		_bind_interstitial_callbacks()
	callback.on_ad_failed_to_load = func(_error: LoadAdError) -> void:
		_loading_interstitial = false
		_interstitial = null
	loader.load(_interstitial_unit_id(), AdRequest.new(), callback)

func _bind_interstitial_callbacks() -> void:
	if _interstitial == null:
		return
	var callbacks := FullScreenContentCallback.new()
	callbacks.on_ad_showed_full_screen_content = func() -> void:
		_notify_fullscreen_started()
	callbacks.on_ad_dismissed_full_screen_content = func() -> void:
		_destroy_interstitial()
		_notify_fullscreen_finished()
		_finish_pending_after_ad()
		_load_interstitial()
	callbacks.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void:
		_destroy_interstitial()
		_notify_fullscreen_finished()
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
	_reanchor_banner_after_fullscreen()
	if cb.is_valid():
		cb.call()

func record_level_win(is_tutorial: bool) -> void:
	_record_interstitial_progress(is_tutorial)

func record_level_restart(is_tutorial: bool) -> void:
	_record_interstitial_progress(is_tutorial)

func _record_interstitial_progress(is_tutorial: bool) -> void:
	if is_tutorial:
		return
	_interstitial_progress += 1

func show_interstitial_if_ready(on_done: Callable = Callable()) -> void:
	if not _ads_supported or not _initialized:
		if on_done.is_valid():
			on_done.call()
		return
	var due := _interstitial_every_n > 0 and _interstitial_progress >= _interstitial_every_n
	if not due or _interstitial == null:
		if on_done.is_valid():
			on_done.call()
		if _interstitial == null:
			_load_interstitial()
		return
	_pending_after_ad = on_done
	_interstitial_progress = 0
	_interstitial_every_n += 1
	_notify_fullscreen_started()
	_interstitial.show()


func can_offer_rewarded_hint() -> bool:
	if not _ads_supported:
		return OS.is_debug_build()
	return true

func is_rewarded_hint_ready() -> bool:
	if not _ads_supported:
		return OS.is_debug_build()
	return _initialized and _rewarded != null

func is_rewarded_hint_loading() -> bool:
	if not _ads_supported:
		return false
	return _initializing or _loading_rewarded

func warm_rewarded_hint() -> void:
	if not _ads_supported:
		return
	ensure_started()
	if _initialized:
		_load_rewarded()

func _rewarded_native_available() -> bool:
	return Engine.has_singleton("PoingGodotAdMobRewardedInterstitialAd")

func _load_rewarded() -> void:
	if not _initialized or _loading_rewarded or _rewarded != null:
		return
	if not _rewarded_native_available():
		push_warning("AdsManager: PoingGodotAdMobRewardedInterstitialAd singleton missing")
		_loading_rewarded = false
		return
	_loading_rewarded = true
	_start_rewarded_load_watchdog()
	# New loader each request (plugin sample pattern); keep a member ref so it is not GC'd.
	_rewarded_loader = RewardedInterstitialAdLoader.new()
	var callback := RewardedInterstitialAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: RewardedInterstitialAd) -> void:
		_loading_rewarded = false
		_stop_rewarded_load_watchdog()
		_rewarded = ad
		_bind_rewarded_callbacks()
		_cancel_rewarded_retry()
		call_deferred("_flush_queued_rewarded_show")
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_loading_rewarded = false
		_stop_rewarded_load_watchdog()
		_rewarded = null
		var msg := "unknown"
		if error:
			msg = str(error.message)
		push_warning("AdsManager: rewarded interstitial load failed: %s" % msg)
		_schedule_rewarded_retry()
	_rewarded_loader.load(_rewarded_unit_id(), AdRequest.new(), callback)

func _start_rewarded_load_watchdog() -> void:
	if _rewarded_load_watchdog == null:
		_rewarded_load_watchdog = Timer.new()
		_rewarded_load_watchdog.one_shot = true
		_rewarded_load_watchdog.timeout.connect(_on_rewarded_load_timeout)
		add_child(_rewarded_load_watchdog)
	_rewarded_load_watchdog.start(REWARDED_LOAD_TIMEOUT_SEC)

func _stop_rewarded_load_watchdog() -> void:
	if _rewarded_load_watchdog and not _rewarded_load_watchdog.is_stopped():
		_rewarded_load_watchdog.stop()

func _on_rewarded_load_timeout() -> void:
	if not _loading_rewarded:
		return
	push_warning("AdsManager: rewarded load timed out; resetting")
	_loading_rewarded = false
	_rewarded_loader = null
	_schedule_rewarded_retry()

func _bind_rewarded_callbacks() -> void:
	if _rewarded == null:
		return
	var callbacks := FullScreenContentCallback.new()
	callbacks.on_ad_showed_full_screen_content = func() -> void:
		_notify_fullscreen_started()
	callbacks.on_ad_dismissed_full_screen_content = func() -> void:
		var earned := _reward_earned
		var cb := _pending_reward_callback
		_pending_reward_callback = Callable()
		_reward_earned = false
		_destroy_rewarded()
		_notify_fullscreen_finished()
		_reanchor_banner_after_fullscreen()
		_load_rewarded()
		if earned and cb.is_valid():
			cb.call()
	callbacks.on_ad_failed_to_show_full_screen_content = func(error: AdError) -> void:
		var msg := "unknown"
		if error:
			msg = str(error.message)
		push_warning("AdsManager: rewarded interstitial show failed: %s" % msg)
		_pending_reward_callback = Callable()
		_reward_earned = false
		_destroy_rewarded()
		_notify_fullscreen_finished()
		_reanchor_banner_after_fullscreen()
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
	if _rewarded == null:
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
	_notify_fullscreen_started()
	_rewarded.show(reward_listener)
	return true

func _invoke_rewarded_mock(on_rewarded: Callable) -> void:
	# Debug mock is instant — still bracket so timer pause logic stays consistent.
	_notify_fullscreen_started()
	if on_rewarded.is_valid():
		on_rewarded.call()
	_notify_fullscreen_finished()


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
		_reanchor_banner_after_fullscreen()
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
	_loading_rewarded = false
	_cancel_rewarded_retry()
	_stop_rewarded_load_watchdog()
	_destroy_banner()
	_destroy_interstitial()
	_destroy_rewarded()
	_rewarded_loader = null
	_notify_fullscreen_finished()

func _exit_tree() -> void:
	prepare_for_app_exit()
