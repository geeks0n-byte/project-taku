extends RefCounted

const LogicTestRunner := preload("res://tests/logic_test_runner.gd")
const TranslationHygiene := preload("res://scripts/translation_hygiene.gd")
const CampaignLevelAudit := preload("res://tests/support/campaign_level_audit.gd")

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
	var local_ach := {"undo_uses": 10, "redo_uses": 30, "unlocked": {}}
	var remote_ach := {"undo_uses": 25, "redo_uses": 15, "unlocked": {}}
	var merged := CloudSaveLogic.merge_blobs(
		CloudSaveLogic.build_blob({}, {}, local_ach, 100),
		CloudSaveLogic.build_blob({}, {}, remote_ach, 200)
	)
	var merged_ach: Dictionary = merged.get("achievements", {})
	r.ok(int(merged_ach.get("undo_uses", 0)) == 25, "cloud: merge max undo_uses")
	r.ok(int(merged_ach.get("redo_uses", 0)) == 30, "cloud: merge max redo_uses")
	_test_save_manager_cloud_roundtrip(r)

static func _test_levels_unseen_badges(r: LogicTestRunner) -> void:
	var save: Node = r.root.get_node_or_null("SaveManager") if r.root != null else null
	if save == null:
		r.ok(true, "levels unseen: skip without SaveManager")
		return
	var first := LevelUtils.first_campaign_level_number()
	var second := first + 1
	r.ok(LevelUtils.campaign_level_exists(first), "levels unseen: sample level exists")
	r.ok(LevelUtils.campaign_level_exists(second), "levels unseen: second sample exists")
	var backup_unseen: Dictionary = (save.get("levels_unseen") as Dictionary).duplicate()
	save.set("levels_unseen", {str(first): true, str(second): true})
	r.ok(int(save.call("unseen_level_count")) == 2, "levels unseen: count")
	r.ok(bool(save.call("is_level_unseen", first)), "levels unseen: query true")
	save.call("mark_level_seen", first)
	r.ok(not bool(save.call("is_level_unseen", first)), "levels unseen: mark seen clears")
	r.ok(bool(save.call("is_level_unseen", second)), "levels unseen: other level untouched")
	var highest := LevelUtils.highest_campaign_level_number()
	r.ok(not LevelUtils.campaign_level_exists(highest + 1), "levels unseen: past last level missing")
	save.set("levels_unseen", {str(highest + 1): true})
	r.ok(int(save.call("unseen_level_count")) == 0, "levels unseen: phantom level ignored")
	save.set("levels_unseen", backup_unseen)

static func _test_save_manager_cloud_roundtrip(r: LogicTestRunner) -> void:
	var save: Node = r.root.get_node_or_null("SaveManager") if r.root != null else null
	if save == null:
		r.ok(true, "cloud save mgr: skip without SaveManager")
		return
	var backup_undo := int(save.get("undo_uses"))
	var backup_redo := int(save.get("redo_uses"))
	var backup_color_blind := bool(save.get("color_blind_patterns"))
	save.set("color_blind_patterns", true)
	save.set("undo_uses", 30)
	save.set("redo_uses", 12)
	var blob: Variant = save.call("export_cloud_payload")
	save.set("color_blind_patterns", false)
	save.set("undo_uses", 0)
	save.set("redo_uses", 0)
	save.call("apply_cloud_payload", blob)
	r.ok(bool(save.get("color_blind_patterns")), "cloud save mgr: color_blind roundtrip")
	r.ok(int(save.get("undo_uses")) == 30, "cloud save mgr: undo_uses roundtrip")
	r.ok(int(save.get("redo_uses")) == 12, "cloud save mgr: redo_uses roundtrip")
	save.set("color_blind_patterns", true)
	var host := Control.new()
	r.root.add_child(host)
	host.custom_minimum_size = Vector2(64, 64)
	host.size = Vector2(64, 64)
	ColorBlindTiles.sync_pattern(host, GameConstants.TileState.BLUE)
	var overlay := host.get_node_or_null("ColorBlindPattern") as Control
	r.ok(overlay != null and overlay.visible, "colorblind: overlay on blue when enabled")
	ColorBlindTiles.sync_pattern(host, GameConstants.TileState.JOKER)
	r.ok(overlay == null or not overlay.visible, "colorblind: no overlay on joker")
	save.set("color_blind_patterns", false)
	ColorBlindTiles.sync_pattern(host, GameConstants.TileState.BLUE)
	r.ok(overlay == null or not overlay.visible, "colorblind: overlay hidden when disabled")
	r.root.remove_child(host)
	host.free()
	save.set("undo_uses", backup_undo)
	save.set("redo_uses", backup_redo)
	save.set("color_blind_patterns", backup_color_blind)

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
