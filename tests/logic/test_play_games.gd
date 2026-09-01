extends RefCounted

const LogicTestRunner := preload("res://tests/logic_test_runner.gd")


static func run(r: LogicTestRunner) -> void:
	_test_achievement_map(r)
	_test_sync_logic(r)
	_test_review_logic(r)


static func _test_achievement_map(r: LogicTestRunner) -> void:
	PlayGamesAchievementMap.reload()
	r.ok(PlayGamesAchievementMap.is_configured(), "pgach: achievement map is configured")
	r.ok(
		not PlayGamesAchievementMap.play_id_for_catalog(AchievementCatalog.ID_FIRST_CLEAR).is_empty(),
		"pgach: first_clear has a Play Games id"
	)


static func _test_sync_logic(r: LogicTestRunner) -> void:
	r.ok(
		not PlayGamesAchievementSyncLogic.should_sync_catalog_id(AchievementCatalog.ID_DEV_MODE),
		"pgach: dev_mode never syncs"
	)
	r.ok(
		PlayGamesAchievementSyncLogic.play_achievement_is_unlocked(0),
		"pgach: unlocked state"
	)
	r.ok(
		not PlayGamesAchievementSyncLogic.play_achievement_is_unlocked(1),
		"pgach: revealed state is not unlocked"
	)
	r.ok(
		PlayGamesAchievementSyncLogic.is_incremental_catalog_id(AchievementCatalog.ID_CLEARS_BRONZE),
		"pgach: clears bronze is incremental"
	)
	r.ok(
		PlayGamesAchievementSyncLogic.steps_for_catalog_id(
			AchievementCatalog.ID_CLEARS_BRONZE,
			{"campaign_clears": 12}
		) == 10,
		"pgach: steps cap at tier target"
	)
	r.ok(
		not PlayGamesAchievementSyncLogic.is_incremental_catalog_id(AchievementCatalog.ID_FIRST_CLEAR),
		"pgach: first_clear is binary"
	)
	r.ok(
		not PlayGamesAchievementSyncLogic.play_achievement_is_unlocked(2),
		"pgach: hidden state is not unlocked"
	)


static func _test_review_logic(r: LogicTestRunner) -> void:
	var base := {
		"runtime_available": true,
		"headless": false,
		"is_tutorial": false,
		"is_custom": false,
		"earned_stars": 3,
		"min_earned_stars": 2,
		"unique_clears": 8,
		"min_unique_clears": 5,
		"prompt_count": 0,
		"max_prompts": 3,
		"last_prompt_unix": 0,
		"now_unix": 1_700_000_000,
		"min_days_between_prompts": 90,
		"session_sec": 400.0,
		"min_session_sec": 300.0,
	}
	r.ok(InAppReviewLogic.should_prompt(base), "review: eligible on good victory")
	var tutorial := base.duplicate(true)
	tutorial["is_tutorial"] = true
	r.ok(not InAppReviewLogic.should_prompt(tutorial), "review: skip tutorial")
	var low_stars := base.duplicate(true)
	low_stars["earned_stars"] = 1
	r.ok(not InAppReviewLogic.should_prompt(low_stars), "review: needs two stars")
	var capped := base.duplicate(true)
	capped["prompt_count"] = 3
	r.ok(not InAppReviewLogic.should_prompt(capped), "review: lifetime cap")
