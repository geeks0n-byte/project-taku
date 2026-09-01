extends RefCounted

const LogicTestRunner := preload("res://tests/logic_test_runner.gd")
const TranslationHygiene := preload("res://scripts/translation_hygiene.gd")
const CampaignLevelAudit := preload("res://scripts/campaign_level_audit.gd")

static func run(r: LogicTestRunner) -> void:
	_test_cloud_save_logic(r)
	_test_levels_unseen_badges(r)
	_test_cloud_save_stub(r)
	_test_translation_hygiene(r)
	_test_campaign_levels(r)

static func _test_cloud_save_logic(r: LogicTestRunner) -> void:
	var progress := {"max_unlocked_level": 20, "level_star_bits": {"15": 7}}
	var settings := {"current_language": "en", "bgm_enabled": true}
	var ach := {"unlocked": {"first_clear": 1}, "no_hint_clears": 1}
	var older := CloudSaveLogic.build_blob(progress, settings, ach, 100)
	var newer_progress := progress.duplicate(true)
	newer_progress["max_unlocked_level"] = 40
	var newer := CloudSaveLogic.build_blob(newer_progress, settings, ach, 200)
	r.ok(CloudSaveLogic.is_valid_blob(older), "cloud: valid blob")
	r.ok(not CloudSaveLogic.is_valid_blob({}), "cloud: empty is invalid")
	var win_new: Dictionary = CloudSaveLogic.winner(older, newer)
	var win_new_progress: Dictionary = win_new.get("progress", {})
	r.ok(int(win_new_progress.get("max_unlocked_level", 0)) == 40, "cloud: newer remote wins")
	var win_local: Dictionary = CloudSaveLogic.winner(newer, older)
	var win_local_progress: Dictionary = win_local.get("progress", {})
	r.ok(int(win_local_progress.get("max_unlocked_level", 0)) == 40, "cloud: newer local wins")
	var only_local: Dictionary = CloudSaveLogic.winner(older, {})
	r.ok(int(only_local.get("timestamp", 0)) == 100, "cloud: missing remote keeps local")
	var only_remote: Dictionary = CloudSaveLogic.winner({}, newer)
	r.ok(int(only_remote.get("timestamp", 0)) == 200, "cloud: missing local takes remote")
	var tie: Dictionary = CloudSaveLogic.winner(older, CloudSaveLogic.build_blob(newer_progress, settings, ach, 100))
	var tie_progress: Dictionary = tie.get("progress", {})
	r.ok(int(tie_progress.get("max_unlocked_level", 0)) == 40, "cloud: equal timestamp merges progress")
	var merge: Dictionary = CloudSaveLogic.merge_blobs(older, CloudSaveLogic.build_blob(newer_progress, settings, ach, 100))
	r.ok(int(merge.get("progress", {}).get("max_unlocked_level", 0)) == 40, "cloud: merge keeps best level")
	var equal_tie: Dictionary = CloudSaveLogic.resolve_sync(older, CloudSaveLogic.build_blob(progress, settings, ach, 100))
	r.ok(int(equal_tie.get("action", 0)) == CloudSaveLogic.SyncAction.CHOOSE, "cloud: equal score tie needs choice")
	var pick_apply: Dictionary = CloudSaveLogic.resolve_sync(older, newer)
	r.ok(int(pick_apply.get("action", 0)) == CloudSaveLogic.SyncAction.APPLY, "cloud: timestamp mismatch auto-merges")
	var encoded := CloudSaveLogic.encode_json(older)
	var decoded := CloudSaveLogic.decode_json(encoded)
	r.ok(int(decoded.get("timestamp", 0)) == 100, "cloud: json roundtrip timestamp")
	var decoded_progress: Dictionary = decoded.get("progress", {})
	var decoded_settings: Dictionary = decoded.get("settings", {})
	var decoded_ach: Dictionary = decoded.get("achievements", {})
	r.ok(int(decoded_progress.get("max_unlocked_level", 0)) == 20, "cloud: json roundtrip progress")
	r.ok(decoded_progress.has("level_star_bits"), "cloud: star bits preserved")
	r.ok(decoded_settings.has("current_language"), "cloud: settings preserved")
	r.ok(decoded_ach.has("unlocked"), "cloud: achievements preserved")
	var sample := CloudSaveLogic.build_blob({"a": 1}, {"b": 2}, {"c": 3}, 42)
	var bytes := CloudSaveLogic.blob_to_bytes(sample)
	var roundtrip := CloudSaveLogic.blob_from_bytes(bytes)
	r.ok(int(roundtrip.get("timestamp", 0)) == 42, "cloud: blob bytes roundtrip")

static func _test_levels_unseen_badges(r: LogicTestRunner) -> void:
	var save: Node = r.root.get_node_or_null("SaveManager") if r.root != null else null
	if save == null:
		r.ok(true, "levels unseen: skip without SaveManager")
		return
	var backup_unseen: Dictionary = (save.get("levels_unseen") as Dictionary).duplicate()
	save.set("levels_unseen", {"7": true, "8": true})
	r.ok(int(save.call("unseen_level_count")) == 2, "levels unseen: count")
	r.ok(bool(save.call("is_level_unseen", 7)), "levels unseen: query true")
	save.call("mark_level_seen", 7)
	r.ok(not bool(save.call("is_level_unseen", 7)), "levels unseen: mark seen clears")
	r.ok(bool(save.call("is_level_unseen", 8)), "levels unseen: other level untouched")
	save.set("levels_unseen", backup_unseen)

static func _test_cloud_save_stub(r: LogicTestRunner) -> void:
	r.ok(CloudSaveLogic.play_games_plugin_installed(), "cloud: Play Games addon installed")
	r.ok(not CloudSaveLogic.play_games_runtime_available(), "cloud: no Android runtime in headless")
	r.ok(GameConstants.is_headless_run(), "headless: detected in test runner")

static func _test_translation_hygiene(r: LogicTestRunner) -> void:
	var issues := TranslationHygiene.audit()
	for issue in issues:
		printerr("  localization: ", issue)
	r.ok(issues.is_empty(), "localization: translations.csv hygiene")

static func _test_campaign_levels(r: LogicTestRunner) -> void:
	var issues := CampaignLevelAudit.validate_all()
	for issue in issues:
		printerr("  campaign: ", issue)
	r.ok(issues.is_empty(), "campaign: all levels valid (%d checked)" % LevelUtils.scan_campaign_levels().size())
