class_name PlayGamesAchievementSyncLogic
extends RefCounted
## Pure helpers for Play Games achievement sync eligibility, merge, and tier steps.

const INCREMENTAL_TIER_IDS: Array[String] = [
	AchievementCatalog.ID_CLEARS_BRONZE,
	AchievementCatalog.ID_CLEARS_SILVER,
	AchievementCatalog.ID_CLEARS_GOLD,
	AchievementCatalog.ID_NO_HINT_CLEAR,
	AchievementCatalog.ID_HINT_SAVER,
	AchievementCatalog.ID_NO_HINT_GOLD,
	AchievementCatalog.ID_ON_TIME_BRONZE,
	AchievementCatalog.ID_ON_TIME_SILVER,
	AchievementCatalog.ID_ON_TIME_GOLD,
]


static func should_sync_catalog_id(catalog_id: String) -> bool:
	var sid := str(catalog_id)
	if sid.is_empty():
		return false
	if sid == AchievementCatalog.ID_DEV_MODE:
		return false
	return not PlayGamesAchievementMap.play_id_for_catalog(sid).is_empty()


static func play_achievement_is_unlocked(state: int) -> bool:
	# PlayGamesAchievement.State: UNLOCKED=0, REVEALED=1, HIDDEN=2
	return state == 0 or state == 1


static func is_incremental_catalog_id(catalog_id: String) -> bool:
	return INCREMENTAL_TIER_IDS.has(str(catalog_id))


## Current counter backing a ranked tier family.
static func counter_for_family(fam: String, state: Dictionary) -> int:
	match str(fam):
		AchievementCatalog.FAM_CLEARS:
			return int(state.get("campaign_clears", 0))
		AchievementCatalog.FAM_NO_HINT:
			return int(state.get("no_hint_clears", 0))
		AchievementCatalog.FAM_ON_TIME:
			return int(state.get("on_time_clears", 0))
		_:
			return 0


## Play Games step count for an incremental tier id (capped at its threshold).
static func steps_for_catalog_id(catalog_id: String, state: Dictionary) -> int:
	var sid := str(catalog_id)
	if not is_incremental_catalog_id(sid):
		return 0
	var target := AchievementCatalog.progress_target_for_id(sid)
	if target <= 0:
		return 0
	var fam := AchievementCatalog.family(sid)
	var counter := counter_for_family(fam, state)
	return clampi(counter, 0, target)


## Progress snapshot from SaveManager fields.
static func progress_state_from_save(
	max_unlocked_level: int,
	campaign_start: int,
	no_hint_clears: int,
	on_time_clears: int
) -> Dictionary:
	return {
		"campaign_clears": maxi(0, max_unlocked_level - campaign_start),
		"no_hint_clears": no_hint_clears,
		"on_time_clears": on_time_clears,
	}
