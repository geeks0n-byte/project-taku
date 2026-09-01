extends Node
## Schedules Google Play in-app review after positive campaign victories.

const PLUGIN_SINGLETON := "GodotGooglePlayInAppReview"

var _plugin_ready: bool = false
var _review_info_ready: bool = false


func _ready() -> void:
	if GameConstants.is_headless_run():
		return
	call_deferred("_bind_plugin")


func maybe_prompt_after_victory(
	is_tutorial: bool,
	is_custom: bool,
	earned_stars: int,
	unique_clears: int,
	session_sec: float
) -> void:
	if not _should_prompt(is_tutorial, is_custom, earned_stars, unique_clears, session_sec):
		return
	call_deferred("_begin_review_flow")


func _should_prompt(
	is_tutorial: bool,
	is_custom: bool,
	earned_stars: int,
	unique_clears: int,
	session_sec: float
) -> bool:
	if SaveManager == null:
		return false
	return InAppReviewLogic.should_prompt({
		"runtime_available": _plugin_ready,
		"headless": GameConstants.is_headless_run(),
		"is_tutorial": is_tutorial,
		"is_custom": is_custom,
		"earned_stars": earned_stars,
		"min_earned_stars": GameConstants.REVIEW_MIN_EARNED_STARS,
		"unique_clears": unique_clears,
		"min_unique_clears": GameConstants.REVIEW_MIN_UNIQUE_CLEARS,
		"prompt_count": SaveManager.review_prompt_count,
		"max_prompts": GameConstants.REVIEW_MAX_PROMPTS,
		"last_prompt_unix": SaveManager.review_last_prompt_unix,
		"now_unix": int(Time.get_unix_time_from_system()),
		"min_days_between_prompts": GameConstants.REVIEW_MIN_DAYS_BETWEEN,
		"session_sec": session_sec,
		"min_session_sec": GameConstants.REVIEW_MIN_SESSION_SEC,
	})


func _bind_plugin() -> void:
	if not Engine.has_singleton(PLUGIN_SINGLETON):
		return
	var plugin: Object = Engine.get_singleton(PLUGIN_SINGLETON)
	_plugin_ready = plugin != null
	if not _plugin_ready:
		return
	for signal_name in [
		"on_request_review_success",
		"request_review_success",
		"review_info_ready",
	]:
		if plugin.has_signal(signal_name):
			var cb := Callable(self, "_on_review_info_ready")
			if not plugin.is_connected(signal_name, cb):
				plugin.connect(signal_name, cb)
			break


func _begin_review_flow() -> void:
	if not _plugin_ready or SaveManager == null:
		return
	var plugin: Object = Engine.get_singleton(PLUGIN_SINGLETON)
	if plugin == null:
		return
	_review_info_ready = false
	if plugin.has_method("requestReviewInfo"):
		plugin.call("requestReviewInfo")
	elif plugin.has_method("requestReviewFlow"):
		plugin.call("requestReviewFlow")
	else:
		return
	SaveManager.record_review_prompt()


func _on_review_info_ready(_unused: Variant = null) -> void:
	if _review_info_ready:
		return
	_review_info_ready = true
	var plugin: Object = Engine.get_singleton(PLUGIN_SINGLETON)
	if plugin == null:
		return
	if plugin.has_method("launchReviewFlow"):
		plugin.call("launchReviewFlow")
