extends RefCounted

const LogicTestRunner := preload("res://tests/logic_test_runner.gd")

static func run(r: LogicTestRunner) -> void:
	_test_achievement_catalog(r)

static func _test_achievement_catalog(r: LogicTestRunner) -> void:
	var empty := AchievementCatalog.collect_unlocks({})
	r.ok(empty.is_empty(), "ach: empty state unlocks nothing")
	var first := AchievementCatalog.collect_unlocks({"campaign_clears": 1})
	r.ok(first.has(AchievementCatalog.ID_FIRST_CLEAR), "ach: first_clear")
	r.ok(not first.has(AchievementCatalog.ID_FIRST_HARD), "ach: first_hard not from easy")
	r.ok(not first.has(AchievementCatalog.ID_CLEARS_SILVER), "ach: silver needs 30 clears")
	var hard := AchievementCatalog.collect_unlocks({"campaign_clears": 1, "hard_clears": 1})
	r.ok(hard.has(AchievementCatalog.ID_FIRST_HARD), "ach: first_hard")
	var hinted := AchievementCatalog.collect_unlocks({"campaign_clears": 10, "no_hint_clears": 0})
	r.ok(not hinted.has(AchievementCatalog.ID_NO_HINT_CLEAR), "ach: hinted clear is not no_hint")
	var no_hint := AchievementCatalog.collect_unlocks({"campaign_clears": 10, "no_hint_clears": 10})
	r.ok(no_hint.has(AchievementCatalog.ID_NO_HINT_CLEAR), "ach: no_hint_clear")
	r.ok(not no_hint.has(AchievementCatalog.ID_HINT_SAVER), "ach: hint_saver needs 30")
	var saver := AchievementCatalog.collect_unlocks({"campaign_clears": 30, "no_hint_clears": 30})
	r.ok(saver.has(AchievementCatalog.ID_HINT_SAVER), "ach: hint_saver at 30")
	r.ok(not saver.has(AchievementCatalog.ID_NO_HINT_GOLD), "ach: no_hint_gold needs 60")
	var sets := AchievementCatalog.collect_unlocks({
		"campaign_clears": 60,
		"easy_complete": true,
		"medium_complete": true,
		"hard_complete": true,
		"hard_clears": 10,
		"no_hint_clears": 10,
	})
	r.ok(sets.has(AchievementCatalog.ID_EASY_SET), "ach: easy_set")
	r.ok(sets.has(AchievementCatalog.ID_MEDIUM_SET), "ach: medium_set")
	r.ok(sets.has(AchievementCatalog.ID_HARD_SET), "ach: hard_set")
	var already := {AchievementCatalog.ID_FIRST_CLEAR: 1}
	var skip := AchievementCatalog.collect_unlocks({"campaign_clears": 2}, already)
	r.ok(not skip.has(AchievementCatalog.ID_FIRST_CLEAR), "ach: already unlocked is skipped")
	var easy_last := AchievementCatalog.last_level_number_in_dir(GameConstants.CAMPAIGN_EASY_DIR)
	var hard_first := AchievementCatalog.first_level_number_in_dir(GameConstants.CAMPAIGN_HARD_DIR)
	r.ok(easy_last > 0, "ach: easy folder is detectable")
	r.ok(hard_first > easy_last, "ach: hard starts after easy")
	var duo: Array = AchievementCatalog.collect_unlocks({
		"campaign_clears": 10,
		"no_hint_clears": 10,
	})
	r.ok(duo.has(AchievementCatalog.ID_FIRST_CLEAR), "ach: duo has first_clear")
	r.ok(duo.has(AchievementCatalog.ID_NO_HINT_CLEAR), "ach: duo has no_hint_clear")
	r.ok(duo.has(AchievementCatalog.ID_CLEARS_BRONZE), "ach: duo has clears_bronze")
	r.ok(duo.size() == 3, "ach: collect_unlocks unique size 3")
	var seen := {}
	for raw_id in duo:
		var sid := str(raw_id)
		r.ok(not seen.has(sid), "ach: no duplicate %s" % sid)
		seen[sid] = true
	r.ok(
		AchievementCatalog.icon_path(AchievementCatalog.ID_FIRST_CLEAR).ends_with("ach_first_clear.svg"),
		"ach: first_clear uses solved-board icon"
	)
	r.ok(
		AchievementCatalog.icon_path(AchievementCatalog.ID_FIRST_HARD)
		!= AchievementCatalog.icon_path(AchievementCatalog.ID_FIRST_CLEAR),
		"ach: first_hard has its own icon"
	)
	r.ok(
		AchievementCatalog.icon_path(AchievementCatalog.ID_CLEARS_BRONZE).ends_with(
			"ach_one_more_level.svg"
		),
		"ach: clears family uses one-more-level icon"
	)
	r.ok(
		AchievementCatalog.icon_path(AchievementCatalog.ID_CLEARS_BRONZE)
		!= AchievementCatalog.icon_path(AchievementCatalog.ID_FIRST_CLEAR),
		"ach: first_clear icon differs from clears family"
	)
	r.ok(
		AchievementCatalog.icon_path(AchievementCatalog.ID_HINT_SAVER)
		== AchievementCatalog.icon_path(AchievementCatalog.ID_NO_HINT_CLEAR),
		"ach: no_hint family shares base icon"
	)
	r.ok(
		AchievementCatalog.icon_path(AchievementCatalog.ID_ON_TIME_GOLD).ends_with("ach_on_time.svg"),
		"ach: on_time family uses clock/star icon"
	)
	r.ok(AchievementCatalog.tier(AchievementCatalog.ID_FIRST_CLEAR) == AchievementCatalog.TIER_NONE, "ach: first_clear is standalone")
	r.ok(AchievementCatalog.tier(AchievementCatalog.ID_CLEARS_BRONZE) == AchievementCatalog.TIER_BRONZE, "ach: clears_bronze is bronze")
	r.ok(AchievementCatalog.tier(AchievementCatalog.ID_CLEARS_SILVER) == AchievementCatalog.TIER_SILVER, "ach: clears_silver is silver")
	r.ok(AchievementCatalog.tier(AchievementCatalog.ID_CLEARS_GOLD) == AchievementCatalog.TIER_GOLD, "ach: clears_gold is gold")
	r.ok(AchievementCatalog.family(AchievementCatalog.ID_FIRST_CLEAR) == "", "ach: first_clear is standalone")
	r.ok(AchievementCatalog.family(AchievementCatalog.ID_CLEARS_BRONZE) == AchievementCatalog.FAM_CLEARS, "ach: clears_bronze family clears")
	r.ok(AchievementCatalog.family(AchievementCatalog.ID_HINT_SAVER) == AchievementCatalog.FAM_NO_HINT, "ach: hint_saver family no_hint")
	r.ok(AchievementCatalog.family(AchievementCatalog.ID_FIRST_HARD) == "", "ach: first_hard is standalone")
	r.ok(AchievementCatalog.visibility(AchievementCatalog.ID_FIRST_CLEAR) == AchievementCatalog.VIS_VISIBLE, "ach: starter vis visible")
	r.ok(AchievementCatalog.visibility(AchievementCatalog.ID_IM_BLUE) == AchievementCatalog.VIS_HIDDEN_DESC, "ach: im_blue hidden_desc")
	r.ok(AchievementCatalog.visibility(AchievementCatalog.ID_SHALL_NOT_PASS) == AchievementCatalog.VIS_HIDDEN_DESC, "ach: shall_not_pass hidden_desc")
	r.ok(AchievementCatalog.visibility(AchievementCatalog.ID_DEV_MODE) == AchievementCatalog.VIS_SECRET, "ach: dev_mode secret")
	r.ok(
		AchievementCatalog.medal_overlay_path(AchievementCatalog.ID_CLEARS_BRONZE, true).ends_with(
			"icon_achievement_cup_bronze.svg"
		),
		"ach: bronze cup on clears_bronze"
	)
	r.ok(AchievementCatalog.medal_overlay_path(AchievementCatalog.ID_FIRST_HARD, true) == "", "ach: no medal on unranked")
	r.ok(AchievementCatalog.listed_when(AchievementCatalog.VIS_VISIBLE, false), "ach: visible locked is listed")
	r.ok(AchievementCatalog.listed_when(AchievementCatalog.VIS_HIDDEN_DESC, false), "ach: hidden_desc locked is listed")
	r.ok(not AchievementCatalog.listed_when(AchievementCatalog.VIS_SECRET, false), "ach: secret locked is omitted")
	r.ok(AchievementCatalog.listed_when(AchievementCatalog.VIS_SECRET, true), "ach: secret unlocked is listed")
	r.ok(AchievementCatalog.desc_shown_when(AchievementCatalog.VIS_VISIBLE, false), "ach: visible locked shows desc")
	r.ok(not AchievementCatalog.desc_shown_when(AchievementCatalog.VIS_HIDDEN_DESC, false), "ach: hidden_desc locked hides desc")
	r.ok(AchievementCatalog.desc_shown_when(AchievementCatalog.VIS_HIDDEN_DESC, true), "ach: hidden_desc unlocked shows desc")
	r.ok(not AchievementCatalog.desc_visible(AchievementCatalog.ID_IM_BLUE, false), "ach: im_blue locked hides desc")
	r.ok(AchievementCatalog.desc_visible(AchievementCatalog.ID_IM_BLUE, true), "ach: im_blue unlocked shows desc")
	r.ok(not AchievementCatalog.identity_visible(AchievementCatalog.ID_IM_BLUE, false), "ach: im_blue locked hides identity")
	r.ok(AchievementCatalog.identity_visible(AchievementCatalog.ID_IM_BLUE, true), "ach: im_blue unlocked shows identity")
	r.ok(
		AchievementCatalog.display_title_key(
			AchievementCatalog.ID_CLEARS_SILVER,
			true
		) == AchievementCatalog.title_key(AchievementCatalog.ID_CLEARS_BRONZE),
		"ach: ranked family shares bronze title"
	)
	r.ok(
		AchievementCatalog.display_desc_key(AchievementCatalog.ID_CLEARS_GOLD)
		== AchievementCatalog.desc_key(AchievementCatalog.ID_CLEARS_BRONZE),
		"ach: ranked family shares bronze desc"
	)
	r.ok(
		AchievementCatalog.display_title_key(AchievementCatalog.ID_IM_BLUE, false) == "ACH_HIDDEN_NAME",
		"ach: hidden locked uses mystery title key"
	)
	r.ok(
		AchievementCatalog.hidden_locked_icon_path().ends_with("ach_medal_bronze_outline.svg"),
		"ach: hidden locked uses mystery icon"
	)
	r.ok(AchievementCatalog.display_icon_path(AchievementCatalog.ID_IM_BLUE, false) == "", "ach: hidden locked display icon empty")
	r.ok(
		AchievementCatalog.tier_modulate(AchievementCatalog.ID_FIRST_CLEAR) == Color.WHITE,
		"ach: standalone first_clear is white"
	)
	r.ok(
		AchievementCatalog.tier_modulate(AchievementCatalog.ID_CLEARS_BRONZE) != Color.WHITE,
		"ach: bronze tier tints icon"
	)
	r.ok(
		AchievementCatalog.tier_modulate(AchievementCatalog.ID_FIRST_HARD) == Color.WHITE,
		"ach: unranked tier is white"
	)
	r.ok(
		AchievementCatalog.display_title_key(AchievementCatalog.ID_FIRST_CLEAR, false) == AchievementCatalog.title_key(AchievementCatalog.ID_FIRST_CLEAR),
		"ach: visible locked keeps real title key"
	)
	var locked_grid: Array = AchievementCatalog.grid_ids({})
	r.ok(locked_grid.size() == 17, "ach: grid lists 17 cells (families collapsed, secret omitted)")
	r.ok(locked_grid.has(AchievementCatalog.ID_CLEARS_BRONZE), "ach: locked grid shows clears bronze")
	var full_unlock := {}
	for id in AchievementCatalog.ORDERED_IDS:
		full_unlock[str(id)] = 1
	var clears_seen: Array = AchievementCatalog.seen_ids_for_grid_cell(
		AchievementCatalog.ID_CLEARS_GOLD,
		full_unlock
	)
	r.ok(clears_seen.size() == 3, "ach: grid cell marks all earned family tiers seen")
	r.ok(clears_seen.has(AchievementCatalog.ID_CLEARS_BRONZE), "ach: family seen includes bronze")
	r.ok(not locked_grid.has(AchievementCatalog.ID_CLEARS_SILVER), "ach: locked grid hides silver sibling")
	r.ok(not locked_grid.has(AchievementCatalog.ID_DEV_MODE), "ach: secret omitted until unlock")
	r.ok(locked_grid.has(AchievementCatalog.ID_IM_BLUE), "ach: hidden_desc listed while locked")
	r.ok(locked_grid.has(AchievementCatalog.ID_SHALL_NOT_PASS), "ach: shall_not_pass listed while locked")
	r.ok(locked_grid.has(AchievementCatalog.ID_THREE_STAR_DEBUT), "ach: three_star_debut listed while locked")
	var silver_grid: Array = AchievementCatalog.grid_ids({
		AchievementCatalog.ID_CLEARS_BRONZE: 1,
		AchievementCatalog.ID_CLEARS_SILVER: 1,
	})
	r.ok(silver_grid.has(AchievementCatalog.ID_CLEARS_SILVER), "ach: family cell promotes to silver")
	r.ok(not silver_grid.has(AchievementCatalog.ID_CLEARS_BRONZE), "ach: bronze sibling collapsed after silver")
	r.ok(silver_grid.size() == 17, "ach: unlock does not duplicate family cells")
	var secret_grid: Array = AchievementCatalog.grid_ids({AchievementCatalog.ID_DEV_MODE: 1})
	r.ok(secret_grid.has(AchievementCatalog.ID_DEV_MODE), "ach: secret listed after unlock")
	r.ok(secret_grid.size() == 18, "ach: secret adds one cell")
	var clears29 := AchievementCatalog.collect_unlocks({"campaign_clears": 29})
	r.ok(clears29.has(AchievementCatalog.ID_FIRST_CLEAR), "ach: 29 clears is first_clear")
	r.ok(clears29.has(AchievementCatalog.ID_CLEARS_BRONZE), "ach: 29 clears is bronze")
	r.ok(not clears29.has(AchievementCatalog.ID_CLEARS_SILVER), "ach: 29 clears is not silver")
	var clears30 := AchievementCatalog.collect_unlocks({"campaign_clears": 30})
	r.ok(clears30.has(AchievementCatalog.ID_CLEARS_SILVER), "ach: 30 clears is silver")
	r.ok(not clears30.has(AchievementCatalog.ID_CLEARS_GOLD), "ach: 30 clears is not gold")
	var clears60 := AchievementCatalog.collect_unlocks({"campaign_clears": 60})
	r.ok(clears60.has(AchievementCatalog.ID_CLEARS_GOLD), "ach: 60 clears is gold")
	var keep_bronze := AchievementCatalog.collect_unlocks({"campaign_clears": 30}, {AchievementCatalog.ID_CLEARS_BRONZE: 1})
	r.ok(not keep_bronze.has(AchievementCatalog.ID_CLEARS_BRONZE), "ach: migrate keeps clears_bronze")
	r.ok(keep_bronze.has(AchievementCatalog.ID_CLEARS_SILVER), "ach: migrate still requires silver counter")
	var on_time := AchievementCatalog.collect_unlocks({"on_time_clears": 10})
	r.ok(on_time.has(AchievementCatalog.ID_ON_TIME_BRONZE), "ach: on_time bronze at 10")
	r.ok(not on_time.has(AchievementCatalog.ID_ON_TIME_SILVER), "ach: on_time silver needs 30")
	var on_time30 := AchievementCatalog.collect_unlocks({"on_time_clears": 30})
	r.ok(on_time30.has(AchievementCatalog.ID_ON_TIME_SILVER), "ach: on_time silver at 30")
	r.ok(not on_time30.has(AchievementCatalog.ID_ON_TIME_GOLD), "ach: on_time gold needs 60")
	var on_time60 := AchievementCatalog.collect_unlocks({"on_time_clears": 60})
	r.ok(on_time60.has(AchievementCatalog.ID_ON_TIME_GOLD), "ach: on_time gold at 60")
	var gold_hints := AchievementCatalog.collect_unlocks({"no_hint_clears": 60})
	r.ok(gold_hints.has(AchievementCatalog.ID_NO_HINT_GOLD), "ach: no_hint gold at 60")
	var purple := AchievementCatalog.collect_unlocks({"shifter_slides": 30})
	r.ok(purple.has(AchievementCatalog.ID_PURPLE_RAIN), "ach: purple_rain at 30 slides")
	var rules := AchievementCatalog.collect_unlocks({"rules_open_levels": 10})
	r.ok(rules.has(AchievementCatalog.ID_RULES_READER), "ach: rules_reader at 10 levels")
	r.ok(
		not AchievementCatalog.collect_unlocks({"rules_open_levels": 9}).has(
			AchievementCatalog.ID_RULES_READER
		),
		"ach: rules_reader needs 10 unique levels"
	)
	var no_events := AchievementCatalog.collect_unlocks({"campaign_clears": 60})
	r.ok(not no_events.has(AchievementCatalog.ID_IM_BLUE), "ach: im_blue not from collect")
	r.ok(not no_events.has(AchievementCatalog.ID_SHALL_NOT_PASS), "ach: shall_not_pass not from collect")
	r.ok(not no_events.has(AchievementCatalog.ID_DEV_MODE), "ach: dev_mode not from collect")
	var flagged := AchievementCatalog.collect_unlocks({
		"im_blue": true,
		"shall_not_pass": true,
		"dev_mode": true,
	})
	r.ok(flagged.has(AchievementCatalog.ID_IM_BLUE), "ach: im_blue from flag")
	r.ok(flagged.has(AchievementCatalog.ID_SHALL_NOT_PASS), "ach: shall_not_pass from flag")
	r.ok(flagged.has(AchievementCatalog.ID_DEV_MODE), "ach: dev_mode from flag")
	var bag := {}
	r.ok(AchievementCatalog.apply_grant(bag, AchievementCatalog.ID_IM_BLUE, 9), "ach: first grant writes")
	r.ok(bag.has(AchievementCatalog.ID_IM_BLUE), "ach: grant stores id")
	r.ok(not AchievementCatalog.apply_grant(bag, AchievementCatalog.ID_IM_BLUE, 10), "ach: grant is idempotent")
	r.ok(int(bag[AchievementCatalog.ID_IM_BLUE]) == 9, "ach: second grant keeps first timestamp")
	r.ok(not AchievementCatalog.apply_grant(bag, "not_a_real_id", 1), "ach: unknown id is rejected")
	var none_unlocked: Dictionary = {}
	r.ok(
		AchievementCatalog.display_tier_modulate(
			AchievementCatalog.ID_CLEARS_BRONZE,
			none_unlocked
		) != Color.WHITE,
		"ach: locked family uses bronze tint"
	)
	var bronze_only := {AchievementCatalog.ID_CLEARS_BRONZE: 1}
	r.ok(
		AchievementCatalog.display_tier_modulate(
			AchievementCatalog.ID_CLEARS_SILVER,
			bronze_only
		) == AchievementCatalog.tier_modulate(AchievementCatalog.ID_CLEARS_BRONZE),
		"ach: display tint follows highest earned tier"
	)
	r.ok(
		AchievementCatalog.cell_is_unlocked(AchievementCatalog.ID_CLEARS_BRONZE, bronze_only),
		"ach: family cell unlocked when bronze earned"
	)
	r.ok(
		not AchievementCatalog.cell_is_unlocked(AchievementCatalog.ID_CLEARS_BRONZE, none_unlocked),
		"ach: family cell locked when none earned"
	)
	var prog := AchievementCatalog.progress_for_cell(
		AchievementCatalog.ID_CLEARS_BRONZE,
		none_unlocked,
		{"campaign_clears": 23}
	)
	r.ok(prog.get("show", false), "ach: locked clears shows progress")
	var clears_targets: Array = prog.get("thresholds", [])
	r.ok(clears_targets.size() == 3, "ach: clears family has three tier targets")
	r.ok(int(clears_targets[0]) == 10, "ach: clears bronze target is 10")
	r.ok(int(clears_targets[1]) == 30, "ach: clears silver target is 30")
	r.ok(int(clears_targets[2]) == 60, "ach: clears gold target is 60")
	r.ok(int(prog.get("highlight_index", 0)) == -1, "ach: no tier earned highlights none")
	var prog_silver := AchievementCatalog.progress_for_cell(
		AchievementCatalog.ID_CLEARS_SILVER,
		bronze_only,
		{"campaign_clears": 23}
	)
	r.ok(prog_silver.get("show", false), "ach: partial clears family still shows tier row")
	r.ok(int(prog_silver.get("highlight_index", -1)) == 0, "ach: bronze earned highlights first threshold")
	var silver_only := {
		AchievementCatalog.ID_CLEARS_BRONZE: 1,
		AchievementCatalog.ID_CLEARS_SILVER: 2,
	}
	var prog_silver_earned := AchievementCatalog.progress_for_cell(
		AchievementCatalog.ID_CLEARS_SILVER,
		silver_only,
		{"campaign_clears": 60}
	)
	r.ok(prog_silver_earned.get("show", false), "ach: silver earned still shows tier row")
	r.ok(
		int(prog_silver_earned.get("highlight_index", -1)) == 1,
		"ach: silver earned highlights middle threshold"
	)
	var all_clears := {
		AchievementCatalog.ID_CLEARS_BRONZE: 1,
		AchievementCatalog.ID_CLEARS_SILVER: 2,
		AchievementCatalog.ID_CLEARS_GOLD: 3,
	}
	var prog_done := AchievementCatalog.progress_for_cell(
		AchievementCatalog.ID_CLEARS_GOLD,
		all_clears,
		{"campaign_clears": 60}
	)
	r.ok(prog_done.get("show", false), "ach: all tiers earned still shows tier row")
	r.ok(int(prog_done.get("highlight_index", -1)) == 2, "ach: gold earned highlights final threshold")
	r.ok(
		AchievementCatalog.next_tier_preview_path(AchievementCatalog.ID_CLEARS_SILVER).ends_with(
			"icon_achievement_cup_silver.svg"
		),
		"ach: next tier preview uses silver cup"
	)
	r.ok(
		AchievementCatalog.earned_tier_badge_path(
			AchievementCatalog.ID_CLEARS_SILVER,
			bronze_only
		).ends_with("icon_achievement_cup_bronze.svg"),
		"ach: earned badge follows highest tier"
	)
	r.ok(
		AchievementCatalog.display_tier_badge_path(
			AchievementCatalog.ID_CLEARS_BRONZE,
			none_unlocked
		) == "",
		"ach: no tier badge until a family rank is earned"
	)
	r.ok(
		AchievementCatalog.display_tier_badge_path(
			AchievementCatalog.ID_CLEARS_BRONZE,
			bronze_only
		).ends_with("icon_achievement_cup_bronze.svg"),
		"ach: tier badge shows once a family rank is earned"
	)
	var y := GameConstants.TileState.YELLOW
	var b := GameConstants.TileState.BLUE
	var e := GameConstants.TileState.EMPTY
	var wall := GameConstants.TileState.WALL
	var all_blue := {
		Vector2i(0, 0): {"state": b, "is_playable": true, "is_locked": false},
		Vector2i(1, 0): {"state": b, "is_playable": true, "is_locked": false},
		Vector2i(0, 1): {"state": y, "is_playable": true, "is_locked": true},
		Vector2i(1, 1): {"state": wall, "is_playable": false, "is_locked": true},
	}
	r.ok(AchievementCatalog.board_is_all_blue(all_blue), "ach: all fillable cells blue")
	var leftover := all_blue.duplicate(true)
	leftover[Vector2i(1, 0)] = {"state": e, "is_playable": true, "is_locked": false}
	r.ok(not AchievementCatalog.board_is_all_blue(leftover), "ach: leftover empty is not all blue")
	var yellow_fill := all_blue.duplicate(true)
	yellow_fill[Vector2i(0, 0)] = {"state": y, "is_playable": true, "is_locked": false}
	r.ok(not AchievementCatalog.board_is_all_blue(yellow_fill), "ach: yellow fillable is not all blue")
	r.ok(not AchievementCatalog.board_is_all_blue({}), "ach: empty board is not all blue")
	var sh := GameConstants.TileState.SHIFTER
	var with_shifter := {
		Vector2i(0, 0): {"state": b, "is_playable": true, "is_locked": false},
		Vector2i(1, 0): {"state": b, "is_playable": true, "is_locked": false},
		Vector2i(2, 0): {"state": sh, "is_playable": true, "is_locked": false},
	}
	r.ok(AchievementCatalog.board_is_all_blue(with_shifter), "ach: shifter tile ignored for im_blue")
	var shifter_empty := with_shifter.duplicate(true)
	shifter_empty[Vector2i(2, 0)] = {"state": e, "is_playable": true, "is_locked": false}
	r.ok(not AchievementCatalog.board_is_all_blue(shifter_empty), "ach: vacated shifter cell must be blue")
	var all_yellow := {
		Vector2i(0, 0): {"state": y, "is_playable": true, "is_locked": false},
		Vector2i(1, 0): {"state": y, "is_playable": true, "is_locked": false},
	}
	r.ok(AchievementCatalog.board_is_all_yellow(all_yellow), "ach: all fillable cells yellow")
	r.ok(not AchievementCatalog.board_is_all_yellow(all_blue), "ach: blue board is not all yellow")
	var mixed := {
		Vector2i(0, 0): {"state": y, "is_playable": true, "is_locked": false},
		Vector2i(1, 0): {"state": b, "is_playable": true, "is_locked": false},
	}
	r.ok(
		AchievementCatalog.uniform_fillable_color(mixed) == GameConstants.TileState.EMPTY,
		"ach: mixed fillable colors are not uniform"
	)
	r.ok(
		AchievementCatalog.uniform_fillable_color(all_yellow) == GameConstants.TileState.YELLOW,
		"ach: uniform yellow detected"
	)
	r.ok(
		AchievementCatalog.toast_cup_icon_path(AchievementCatalog.ID_CLEARS_SILVER).ends_with(
			"icon_achievement_cup_silver.svg"
		),
		"ach: toast cup silver for silver tier"
	)
	r.ok(
		AchievementCatalog.toast_cup_icon_path(AchievementCatalog.ID_FIRST_CLEAR).ends_with("icon_achievement_cup.svg"),
		"ach: toast cup gold for standalone"
	)
	var packed := load("res://scenes/achievement_toast.tscn")
	r.ok(packed is PackedScene, "toast: scene loads")
	if packed is PackedScene and r.root != null:
		var toast: Node = packed.instantiate()
		r.ok(toast.get_script() != null, "toast: script attached")
		r.ok(toast.has_method("enqueue"), "toast: enqueue available")
		r.root.add_child(toast)
		for raw_id in duo:
			toast.enqueue(str(raw_id))
			toast.enqueue(str(raw_id))
		var snap: Array = toast.snapshot_ids() if toast.has_method("snapshot_ids") else []
		r.ok(snap.size() == 3, "toast: three unique queued ids")
		if snap.size() >= 2:
			r.ok(str(snap[0]) != str(snap[1]), "toast: different ids not duplicates")
			r.ok(snap.has(AchievementCatalog.ID_FIRST_CLEAR), "toast: first_clear present")
			r.ok(snap.has(AchievementCatalog.ID_NO_HINT_CLEAR), "toast: no_hint_clear present")
			r.ok(snap.has(AchievementCatalog.ID_CLEARS_BRONZE), "toast: clears_bronze present")
		r.root.remove_child(toast)
		toast.free()
