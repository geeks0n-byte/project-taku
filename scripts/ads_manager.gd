extends Node
## Autoload wrapping AdMob banners, interstitials, rewarded ads, and UMP privacy forms.

# Interstitial cadence knobs live on GameConstants so short-session policy is
# tunable in one place. Rewarded/hint ads are unchanged and ignore this cadence.

# AdMob test unit IDs — safe to ship; they never charge real money.
const TEST_BANNER_UNIT_ID := "ca-app-pub-3940256099942544/6300978111"
const TEST_INTERSTITIAL_UNIT_ID := "ca-app-pub-3940256099942544/1033173712"
# Google sample Rewarded Interstitial (matches PROD format).
const TEST_REWARDED_UNIT_ID := "ca-app-pub-3940256099942544/5354046379"

# Production AdMob unit IDs — only used in release builds.
const PROD_BANNER_UNIT_ID := "ca-app-pub-1624206851803206/6555942665"
const PROD_INTERSTITIAL_UNIT_ID := "ca-app-pub-1624206851803206/8878973813"
const PROD_REWARDED_UNIT_ID := "ca-app-pub-1624206851803206/1850531037"

const PRIVACY_POLICY_URL := "https://geeks0n-byte.github.io/project-taku/privacy-policy.html"

# Emitted when a fullscreen ad (interstitial or rewarded) becomes visible.
# main.gd uses this to pause the game timer.
signal fullscreen_ad_started
# Emitted when the fullscreen ad is dismissed, allowing the timer to resume.
signal fullscreen_ad_finished

var _initialized: bool = false
var _initializing: bool = false
# False on non-Android or when the AdMob plugin singleton is absent.
var _ads_supported: bool = false
# Guards against emitting fullscreen_ad_started more than once per ad session.
var _fullscreen_ad_open: bool = false

var _banner: AdView = null
# Tracks whether the banner should be visible; used to restore it after fullscreen ads.
var _banner_wanted_visible: bool = false
var _banner_loaded: bool = false
var _banner_loading: bool = false
var _banner_retry_timer: Timer = null
const BANNER_RETRY_SEC := 12.0

var _interstitial: InterstitialAd = null
var _loading_interstitial: bool = false
# Called after the interstitial is dismissed (e.g. go-to-next-level callback).
var _pending_after_ad: Callable = Callable()
## Session-only interstitial cadence: first after min wins + min session age,
## then every_n (starts at INTERSTITIAL_START_EVERY_N, +1 after each shown ad).
## Short sessions keep an extra gap until INTERSTITIAL_SHORT_SESSION_SEC.
var _interstitial_progress: int = 0
var _interstitial_every_n: int = GameConstants.INTERSTITIAL_START_EVERY_N
var _interstitial_wins: int = 0
var _session_started_msec: int = 0

var _rewarded: RewardedInterstitialAd = null
# Kept as a member to prevent GC between load request and callback.
var _rewarded_loader: RewardedInterstitialAdLoader = null
var _loading_rewarded: bool = false
# Called only if the user earns the reward before dismissing the ad.
var _pending_reward_callback: Callable = Callable()
var _reward_earned: bool = false
# Queued when the ad is not yet loaded; flushed once the ad becomes available.
var _queued_reward_callback: Callable = Callable()
# Retries a failed rewarded ad load after a delay.
var _rewarded_retry_timer: Timer = null
# Kills a stuck load request that never called back.
var _rewarded_load_watchdog: Timer = null
# Runs several times after app-focus to re-pin the banner once the IME fully closes.
var _focus_banner_settle_timer: Timer = null
var _focus_banner_settle_ticks: int = 0
const REWARDED_RETRY_SEC := 8.0
const REWARDED_LOAD_TIMEOUT_SEC := 25.0
# How many settle ticks to run after focus returns before giving up on banner re-pin.
const FOCUS_BANNER_SETTLE_TRIES := 5
const FOCUS_BANNER_SETTLE_SEC := 0.2

## Detects AdMob support, builds retry timers, and defers consent/start until the tree is ready.
func _ready() -> void:
	_ads_supported = _detect_ads_support()
	_session_started_msec = Time.get_ticks_msec()
	_focus_banner_settle_timer = _make_timer(_on_banner_focus_settle)
	_banner_retry_timer = _make_timer(_on_banner_retry_timeout)
	_rewarded_retry_timer = _make_timer(_on_rewarded_retry_timeout)
	_rewarded_load_watchdog = _make_timer(_on_rewarded_load_timeout)
	# Defer so the scene tree is fully ready before consent flow starts.
	call_deferred("ensure_started")
	call_deferred("_connect_safe_area_resize")

## Re-pins the banner when the root viewport size changes (IME / rotation).
func _connect_safe_area_resize() -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	if not tree.root.size_changed.is_connected(_on_root_resized):
		tree.root.size_changed.connect(_on_root_resized)

## Re-anchors a visible banner after a viewport resize.
func _on_root_resized() -> void:
	if _banner_wanted_visible:
		_pin_banner_bottom()

# Creates a one-shot Timer and connects it to the given callback.
func _make_timer(on_timeout: Callable) -> Timer:
	var t := Timer.new()
	t.one_shot = true
	t.timeout.connect(on_timeout)
	add_child(t)
	return t

# Guards against double-emission; the game timer should pause exactly once per ad.
func _notify_fullscreen_started() -> void:
	if _fullscreen_ad_open:
		return
	_fullscreen_ad_open = true
	fullscreen_ad_started.emit()

# Symmetric guard for fullscreen_ad_finished.
func _notify_fullscreen_finished() -> void:
	if not _fullscreen_ad_open:
		return
	_fullscreen_ad_open = false
	fullscreen_ad_finished.emit()

# Ads are only supported on Android with the PoingGodotAdMob plugin installed.
func _detect_ads_support() -> bool:
	if not (OS.has_feature("android") or OS.get_name() == "Android"):
		return false
	return ClassDB.class_exists("PoingGodotAdMob") or Engine.has_singleton("PoingGodotAdMob")

## True when this build can talk to AdMob (Android + plugin present).
func is_ads_available() -> bool:
	return _ads_supported

# Entry point for the entire ads initialization pipeline. Safe to call multiple times.
func ensure_started() -> void:
	if _initialized or _initializing or not _ads_supported:
		return
	_initializing = true
	_request_consent_then_init()

# Starts the UMP consent flow before initializing AdMob, as required by Google policy.
func _request_consent_then_init() -> void:
	var params := ConsentRequestParameters.new()
	UserMessagingPlatform.consent_information.update(
		params,
		_on_consent_update_success,
		_on_consent_update_failure
	)

# If a consent form is available, load it before initializing ads.
# If no form is available (e.g. outside EEA), initialize immediately.
func _on_consent_update_success() -> void:
	if UserMessagingPlatform.consent_information.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(_on_consent_form_loaded, _on_consent_form_load_failed)
	else:
		_initialize_mobile_ads()

# Consent update failed (network error etc.) — proceed with ads anyway.
func _on_consent_update_failure(_error: FormError) -> void:
	_initialize_mobile_ads()

# Only show the consent form if consent is actually required for this user's region.
func _on_consent_form_loaded(form: ConsentForm) -> void:
	var status := UserMessagingPlatform.consent_information.get_consent_status()
	if status == ConsentInformation.ConsentStatus.REQUIRED:
		form.show(_on_consent_form_dismissed)
	else:
		_initialize_mobile_ads()

# Consent form failed to load — proceed with ads anyway.
func _on_consent_form_load_failed(_error: FormError) -> void:
	_initialize_mobile_ads()

# Called after the user interacts with the consent form (accept or dismiss).
func _on_consent_form_dismissed(_error: FormError) -> void:
	_initialize_mobile_ads()

# Initializes the AdMob SDK. On success, immediately pre-loads all ad formats
# and shows the banner if it was already requested before initialization completed.
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

# Debug builds always use Google's public test ad units to avoid invalid traffic.
func _use_test_units() -> bool:
	return OS.is_debug_build()

# Unit-id helpers centralize test-vs-production selection.
func _banner_unit_id() -> String:
	return TEST_BANNER_UNIT_ID if _use_test_units() else PROD_BANNER_UNIT_ID

## Test interstitial unit in debug/editor; production unit in release.
func _interstitial_unit_id() -> String:
	return TEST_INTERSTITIAL_UNIT_ID if _use_test_units() else PROD_INTERSTITIAL_UNIT_ID

## Test rewarded-interstitial unit in debug/editor; production unit in release.
func _rewarded_unit_id() -> String:
	return TEST_REWARDED_UNIT_ID if _use_test_units() else PROD_REWARDED_UNIT_ID


## On app focus-in, dismisses the IME and re-settles the banner once the node is ready.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		# Focus can arrive while this autoload is still entering the tree.
		if is_node_ready() and is_inside_tree():
			_on_app_focus_in()
		else:
			call_deferred("_on_app_focus_in")

# After app-resume, re-pins the banner and warms the rewarded ad.
# Pinning is deferred once more because the layout may still be settling.
func _on_app_focus_in() -> void:
	if not is_inside_tree():
		return
	_dismiss_soft_keyboard()
	if _banner_wanted_visible:
		_pin_banner_bottom()
		call_deferred("_pin_banner_bottom")
		_schedule_banner_focus_settle()
		if not _banner_loaded:
			if _banner != null and not _banner_loading:
				_destroy_banner()
			_ensure_banner_loaded()
	warm_rewarded_hint()

## Releases GUI focus and hides the virtual keyboard so banners stay at the true bottom.
func _dismiss_soft_keyboard() -> void:
	var tree := get_tree()
	if tree and tree.root:
		var vp := tree.root.get_viewport()
		if vp:
			vp.gui_release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()

## Starts the post-focus banner settle ticks from zero.
func _schedule_banner_focus_settle() -> void:
	_focus_banner_settle_ticks = 0
	_start_banner_focus_settle_timer()

## Defers until this autoload is in the tree, then starts the settle timer.
func _start_banner_focus_settle_timer() -> void:
	if not is_inside_tree():
		return
	if _focus_banner_settle_timer == null or not _focus_banner_settle_timer.is_inside_tree():
		call_deferred("_start_banner_focus_settle_timer")
		return
	_focus_banner_settle_timer.start(FOCUS_BANNER_SETTLE_SEC)

# Fires repeatedly after focus returns to ensure the banner sits at the true bottom
# once the IME (on-screen keyboard) has finished closing.
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
		_start_banner_focus_settle_timer()

# Shows a bottom banner ad. Records intent so the banner is shown once ads finish initializing.
func show_menu_banner() -> void:
	_banner_wanted_visible = true
	if not _ads_supported:
		return
	ensure_started()
	if not _initialized:
		return
	if _banner != null and not _banner_loaded and not _banner_loading:
		_destroy_banner()
	_ensure_banner_loaded()
	if _banner and _banner_loaded:
		_show_banner_pinned()

# Destroys and recreates the banner with a fresh adaptive size after rotation or fullscreen.
func refresh_banner_anchor() -> void:
	_banner_wanted_visible = true
	if not _ads_supported:
		return
	ensure_started()
	if not _initialized:
		return
	_destroy_banner()
	_ensure_banner_loaded()

# Hides the banner without destroying it so it can be quickly restored later.
func hide_menu_banner() -> void:
	_banner_wanted_visible = false
	if _banner:
		_banner.hide()

# Hard-pins the banner above the system nav bar / home indicator.
func _pin_banner_bottom() -> void:
	if _banner == null:
		return
	_banner.set_position(_banner_safe_bottom_position())

## Bottom AdPosition, raised by the nav-bar / home-indicator inset when needed.
func _banner_safe_bottom_position() -> AdPosition:
	var bottom := int(round(SafeInsets.screen_margins().w))
	if bottom <= 0:
		return AdPosition.BOTTOM
	var banner_h := _banner.get_height_in_pixels() if _banner else 0
	if banner_h <= 0:
		return AdPosition.BOTTOM
	var window_h := DisplayServer.window_get_size().y
	var y := window_h - banner_h - bottom
	return AdPosition.custom(0, maxi(0, y))

# Shows banner and re-pins on the next frame to survive transient layout shifts.
func _show_banner_pinned() -> void:
	if _banner == null:
		return
	_pin_banner_bottom()
	_banner.show()
	call_deferred("_pin_banner_bottom")

## Creates/loads the banner if missing; shows it when already loaded and wanted.
func _ensure_banner_loaded() -> void:
	if not _initialized:
		return
	if _banner != null:
		if _banner_loaded and _banner_wanted_visible:
			_show_banner_pinned()
		return
	if _banner_loading:
		return
	_banner_loading = true
	var ad_size := AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
	_banner = AdView.new(_banner_unit_id(), ad_size, _banner_safe_bottom_position())
	var listener := AdListener.new()
	listener.on_ad_loaded = func() -> void:
		_banner_loading = false
		_banner_loaded = true
		if _banner_retry_timer:
			_banner_retry_timer.stop()
		if _banner_wanted_visible and _banner:
			_show_banner_pinned()
		else:
			if _banner:
				_banner.hide()
	listener.on_ad_failed_to_load = func(_error: LoadAdError) -> void:
		_banner_loading = false
		_banner_loaded = false
		_destroy_banner()
		_schedule_banner_retry()
	_banner.ad_listener = listener
	_banner.load_ad(AdRequest.new())
	_banner.hide()

## One-shot retry when a wanted banner failed to load.
func _schedule_banner_retry() -> void:
	if not _banner_wanted_visible or _banner_retry_timer == null:
		return
	if _banner_retry_timer.time_left > 0.0:
		return
	_banner_retry_timer.start(BANNER_RETRY_SEC)

## Retries banner load if it is still wanted and not loaded.
func _on_banner_retry_timeout() -> void:
	if not _banner_wanted_visible or _banner_loaded:
		return
	_ensure_banner_loaded()

## Destroys the native banner object and clears load flags.
func _destroy_banner() -> void:
	if _banner:
		_banner.destroy()
		_banner = null
	_banner_loaded = false
	_banner_loading = false
	if _banner_retry_timer:
		_banner_retry_timer.stop()

## Re-pins the banner after a fullscreen ad or privacy form closes.
func _reanchor_banner_after_fullscreen() -> void:
	if not _banner_wanted_visible:
		return
	refresh_banner_anchor()


# Requests an interstitial ad and stores it for later show_interstitial_if_ready().
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

# Hooks fullscreen lifecycle so game timer pause/resume and continuation callbacks
# happen reliably across both success and failure paths.
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

# Releases native interstitial resources.
func _destroy_interstitial() -> void:
	if _interstitial:
		_interstitial.destroy()
		_interstitial = null

# Runs deferred continuation after interstitial closes and reanchors the banner.
func _finish_pending_after_ad() -> void:
	var cb := _pending_after_ad
	_pending_after_ad = Callable()
	_reanchor_banner_after_fullscreen()
	if cb.is_valid():
		cb.call()

# Called when the player completes a level; advances the interstitial cadence counter.
func record_level_win(is_tutorial: bool) -> void:
	_record_interstitial_progress(is_tutorial)

# Called when the player restarts a level; also advances the cadence counter.
func record_level_restart(is_tutorial: bool) -> void:
	_record_interstitial_progress(is_tutorial)

# Tutorials don't count toward the interstitial threshold (avoids interrupting teaching moments).
func _record_interstitial_progress(is_tutorial: bool) -> void:
	if is_tutorial:
		return
	_interstitial_progress += 1
	_interstitial_wins += 1

# Shows an interstitial if the softened cadence threshold is met and one is loaded.
# Calls on_done immediately if no ad is shown, so the game can continue normally.
# Soft-session policy (does not affect rewarded/hint ads):
#   - First interstitial needs INTERSTITIAL_MIN_WINS_BEFORE_FIRST non-tutorial
#     wins/restarts AND INTERSTITIAL_MIN_SESSION_SEC of session age.
#   - After each shown ad, every_n grows by 1; while session age is still under
#     INTERSTITIAL_SHORT_SESSION_SEC, an extra gap is applied so quick sessions
#     stay sparse without removing ads entirely.
func show_interstitial_if_ready(on_done: Callable = Callable()) -> void:
	if not _ads_supported or not _initialized:
		if on_done.is_valid():
			on_done.call()
		return
	var session_sec := _session_age_sec()
	var first_gate_ok := (
		_interstitial_wins >= GameConstants.INTERSTITIAL_MIN_WINS_BEFORE_FIRST
		and session_sec >= GameConstants.INTERSTITIAL_MIN_SESSION_SEC
	)
	var needed := _interstitial_every_n
	if session_sec < GameConstants.INTERSTITIAL_SHORT_SESSION_SEC:
		needed += GameConstants.INTERSTITIAL_SHORT_SESSION_EXTRA_GAP
	var due := first_gate_ok and needed > 0 and _interstitial_progress >= needed
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


func _session_age_sec() -> float:
	if _session_started_msec <= 0:
		_session_started_msec = Time.get_ticks_msec()
		return 0.0
	return float(Time.get_ticks_msec() - _session_started_msec) / 1000.0


# Returns true if a rewarded ad could ever be shown (used to show/hide the hint ad button).
# In debug builds without ads, always returns true so the flow can be tested.
func can_offer_rewarded_hint() -> bool:
	if not _ads_supported:
		return OS.is_debug_build()
	return true

# Returns true only when a rewarded ad is fully loaded and ready to display immediately.
func is_rewarded_hint_ready() -> bool:
	if not _ads_supported:
		return OS.is_debug_build()
	return _initialized and _rewarded != null

# Returns true while the rewarded ad is being loaded, so the UI can show a "loading" message.
func is_rewarded_hint_loading() -> bool:
	if not _ads_supported:
		return false
	return _initializing or _loading_rewarded

# Pre-loads a rewarded ad so it's ready when the player taps "watch ad for hint".
# Call this proactively whenever hints are running low.
func warm_rewarded_hint() -> void:
	if not _ads_supported:
		return
	ensure_started()
	if _initialized:
		_load_rewarded()

# Verifies rewarded-interstitial singleton exists in current build/plugin setup.
func _rewarded_native_available() -> bool:
	return Engine.has_singleton("PoingGodotAdMobRewardedInterstitialAd")

## Starts a rewarded-interstitial load when none is in flight.
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

# Starts timeout guard for stuck rewarded loads.
func _start_rewarded_load_watchdog() -> void:
	if _rewarded_load_watchdog == null or not _rewarded_load_watchdog.is_inside_tree():
		return
	_rewarded_load_watchdog.start(REWARDED_LOAD_TIMEOUT_SEC)

# Stops rewarded timeout guard after success/failure.
func _stop_rewarded_load_watchdog() -> void:
	if _rewarded_load_watchdog and not _rewarded_load_watchdog.is_stopped():
		_rewarded_load_watchdog.stop()

## Resets a hung rewarded load and schedules another attempt.
func _on_rewarded_load_timeout() -> void:
	if not _loading_rewarded:
		return
	push_warning("AdsManager: rewarded load timed out; resetting")
	_loading_rewarded = false
	_rewarded_loader = null
	_schedule_rewarded_retry()

## Wires fullscreen show/dismiss callbacks on the loaded rewarded ad.
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

# Releases native rewarded-interstitial resources.
func _destroy_rewarded() -> void:
	if _rewarded:
		_rewarded.destroy()
		_rewarded = null

# Schedules delayed retry after rewarded load failure/timeout.
func _schedule_rewarded_retry() -> void:
	if not _ads_supported or not _initialized:
		return
	if _rewarded_retry_timer == null or not _rewarded_retry_timer.is_inside_tree():
		return
	if _rewarded_retry_timer.is_stopped():
		_rewarded_retry_timer.start(REWARDED_RETRY_SEC)

# Cancels pending rewarded retry timer.
func _cancel_rewarded_retry() -> void:
	if _rewarded_retry_timer and not _rewarded_retry_timer.is_stopped():
		_rewarded_retry_timer.stop()

# Retry timer callback.
func _on_rewarded_retry_timeout() -> void:
	_load_rewarded()

# If UI requested rewarded ad while loading, show it immediately once loaded.
func _flush_queued_rewarded_show() -> void:
	if not _queued_reward_callback.is_valid():
		return
	if _rewarded == null:
		return
	var cb := _queued_reward_callback
	_queued_reward_callback = Callable()
	show_rewarded_for_hint(cb)

# Shows a rewarded interstitial ad and calls on_rewarded only if the player earns the reward.
# Returns true in all cases where the ad flow was started (including queued/loading states).
# If the ad is not yet loaded, queues the callback so it fires once the ad loads.
# In debug builds without AdMob support, immediately invokes a mock that mimics the flow.
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
	# Flag is set inside the ad's own callback; checked on dismissal to decide
	# whether to call the reward callback (skipping if the user closed without watching).
	reward_listener.on_user_earned_reward = func(_item: RewardedItem) -> void:
		_reward_earned = true
	_notify_fullscreen_started()
	_rewarded.show(reward_listener)
	return true

## Debug path: grants the reward immediately while still bracketing fullscreen signals.
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

# Returns one of the PRIVACY_OPTIONS_STATE_* constants so the UI can decide
# whether to show a "Privacy Options" button (only shown when READY).
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

## Opens the UMP privacy options form when the platform says it is ready.
func show_privacy_options_form(on_done: Callable = Callable()) -> bool:
	if get_privacy_options_state() != PRIVACY_OPTIONS_STATE_READY:
		return false
	UserMessagingPlatform.show_privacy_options_form(func(form_error: FormError) -> void:
		_reanchor_banner_after_fullscreen()
		if on_done.is_valid():
			on_done.call(form_error)
	)
	return true

## Opens the canonical privacy-policy URL in the device browser.
func open_privacy_policy() -> void:
	OS.shell_open(PRIVACY_POLICY_URL)

# Clears all pending state and destroys active ad objects before the process exits.
# Must be called before quit_app() to avoid callbacks firing on freed nodes.
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

# Safety net cleanup in case app exits without calling quit flow.
func _exit_tree() -> void:
	prepare_for_app_exit()
