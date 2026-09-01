class_name InAppReviewLogic
extends RefCounted
## Eligibility rules for the Google Play in-app review prompt.


static func should_prompt(input: Dictionary) -> bool:
	if not bool(input.get("runtime_available", false)):
		return false
	if bool(input.get("headless", true)):
		return false
	if bool(input.get("is_tutorial", false)):
		return false
	if bool(input.get("is_custom", false)):
		return false
	if int(input.get("earned_stars", 0)) < int(input.get("min_earned_stars", 2)):
		return false
	if int(input.get("unique_clears", 0)) < int(input.get("min_unique_clears", 5)):
		return false
	if int(input.get("prompt_count", 0)) >= int(input.get("max_prompts", 3)):
		return false
	var min_gap := int(input.get("min_days_between_prompts", 90))
	var last_unix := int(input.get("last_prompt_unix", 0))
	var now_unix := int(input.get("now_unix", 0))
	if last_unix > 0 and now_unix > 0:
		var days := float(now_unix - last_unix) / 86400.0
		if days < float(min_gap):
			return false
	var min_session := float(input.get("min_session_sec", 300.0))
	if float(input.get("session_sec", 0.0)) < min_session:
		return false
	return true
