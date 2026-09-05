extends RefCounted

const LogicTestRunner := preload("res://tests/logic_test_runner.gd")


static func run(r: LogicTestRunner) -> void:
	_test_grid_progress_counts(r)
	_test_orchestration(r)


static func _test_grid_progress_counts(r: LogicTestRunner) -> void:
	var locked: Array = AchievementCatalog.grid_ids({})
	var total := locked.size()
	var unlocked_map := {}
	for id in AchievementCatalog.ORDERED_IDS:
		unlocked_map[id] = 1
	var all: Array = AchievementCatalog.grid_ids(unlocked_map)
	var unlocked := 0
	for id in all:
		if AchievementCatalog.cell_is_unlocked(str(id), unlocked_map):
			unlocked += 1
	r.ok(total > 0, "ach mgr: grid has cells")
	r.ok(unlocked == all.size(), "ach mgr: full unlock fills grid count")
	r.ok(unlocked >= total, "ach mgr: unlocked count grows with progress")


static func _test_orchestration(r: LogicTestRunner) -> void:
	var save := _autoload("SaveManager")
	var mgr := _autoload("AchievementManager")
	if save == null or mgr == null:
		r.ok(true, "ach mgr orch: skip without autoloads")
		return

	var backup_unlocked: Dictionary = (save.get("achievements_unlocked") as Dictionary).duplicate()
	var backup_seen: Dictionary = (save.get("achievements_seen") as Dictionary).duplicate()
	var backup_no_hint: int = int(save.get("no_hint_clears"))
	var backup_slides: int = int(save.get("shifter_slides"))
	var backup_undo: int = int(save.get("undo_uses"))
	var backup_redo: int = int(save.get("redo_uses"))

	_restore_save(save, {}, {}, 0, 0, 0, 0)

	r.ok(
		not bool(mgr.call("is_play_games_push_suppressed")),
		"ach mgr orch: play games push starts allowed"
	)
	mgr.call("push_play_games_push_suppressed", true)
	r.ok(
		bool(mgr.call("is_play_games_push_suppressed")),
		"ach mgr orch: debug suppress blocks play games push"
	)
	mgr.call("push_play_games_push_suppressed", false)
	r.ok(
		not bool(mgr.call("is_play_games_push_suppressed")),
		"ach mgr orch: debug suppress releases play games push"
	)

	r.ok(
		not bool(mgr.call("is_unlocked", AchievementCatalog.ID_DEV_MODE)),
		"ach mgr orch: dev_mode starts locked"
	)
	r.ok(bool(mgr.call("grant", AchievementCatalog.ID_DEV_MODE)), "ach mgr orch: grant succeeds once")
	r.ok(
		bool(mgr.call("is_unlocked", AchievementCatalog.ID_DEV_MODE)),
		"ach mgr orch: grant marks unlocked"
	)
	r.ok(not bool(mgr.call("grant", AchievementCatalog.ID_DEV_MODE)), "ach mgr orch: grant is idempotent")

	r.ok(
		bool(mgr.call("import_remote_unlock", AchievementCatalog.ID_FIRST_CLEAR)),
		"ach mgr orch: remote import grants silently"
	)
	r.ok(
		bool(mgr.call("is_unlocked", AchievementCatalog.ID_FIRST_CLEAR)),
		"ach mgr orch: remote import persisted"
	)
	r.ok(
		not bool(mgr.call("import_remote_unlock", AchievementCatalog.ID_FIRST_CLEAR)),
		"ach mgr orch: remote import is idempotent"
	)

	r.ok(
		not bool(mgr.call("notify_invalid_move", "ERR_OTHER")),
		"ach mgr orch: invalid move ignores other errors"
	)
	r.ok(
		bool(mgr.call("notify_invalid_move", "ERR_SHIFTER_BLOCKED")),
		"ach mgr orch: shifter block grants shall_not_pass"
	)
	r.ok(
		bool(mgr.call("is_unlocked", AchievementCatalog.ID_SHALL_NOT_PASS)),
		"ach mgr orch: shall_not_pass persisted"
	)

	var blue_cells := {}
	for i in 4:
		blue_cells[Vector2i(i, 0)] = {
			"state": GameConstants.TileState.BLUE,
			"is_playable": true,
			"is_locked": false,
		}
	r.ok(bool(mgr.call("check_all_blue", blue_cells)), "ach mgr orch: all-blue board grants")
	r.ok(
		bool(mgr.call("is_unlocked", AchievementCatalog.ID_IM_BLUE)),
		"ach mgr orch: im_blue unlocked"
	)

	var yellow_cells := {}
	for i in 4:
		yellow_cells[Vector2i(i, 0)] = {
			"state": GameConstants.TileState.YELLOW,
			"is_playable": true,
			"is_locked": false,
		}
	r.ok(bool(mgr.call("check_all_yellow", yellow_cells)), "ach mgr orch: all-yellow board grants")

	var green_cells := {}
	for i in 4:
		green_cells[Vector2i(i, 0)] = {
			"state": GameConstants.TileState.JOKER,
			"is_playable": true,
			"is_locked": false,
		}
	r.ok(bool(mgr.call("check_all_green", green_cells)), "ach mgr orch: all-green board grants")

	save.set("undo_uses", 0)
	save.set("redo_uses", 0)
	save.set("achievements_unlocked", {})
	mgr.call("notify_undo")
	r.ok(int(save.get("undo_uses")) == 1, "ach mgr orch: notify_undo increments")
	mgr.call("notify_redo")
	r.ok(int(save.get("redo_uses")) == 1, "ach mgr orch: notify_redo increments")
	save.set("undo_uses", 49)
	save.set("achievements_unlocked", {})
	mgr.call("notify_undo")
	r.ok(
		bool(mgr.call("is_unlocked", AchievementCatalog.ID_CTRL_Z)),
		"ach mgr orch: ctrl_z at 50th undo"
	)

	var dummy_level := LevelData.new()
	save.set("achievements_unlocked", {})
	var easy_clear: Array = mgr.call(
		"record_level_clear",
		dummy_level,
		0,
		PuzzleGenerator.Difficulty.EASY,
		false,
		false,
		0,
		true,
		false,
		0.0
	)
	r.ok(
		not easy_clear.has(AchievementCatalog.ID_UNDO_NOTHING),
		"ach mgr orch: undo_nothing not from easy no-undo clear"
	)
	save.set("achievements_unlocked", {})
	var hard_undo: Array = mgr.call(
		"record_level_clear",
		dummy_level,
		0,
		PuzzleGenerator.Difficulty.HARD,
		false,
		false,
		0,
		true,
		true,
		0.0
	)
	r.ok(
		not hard_undo.has(AchievementCatalog.ID_UNDO_NOTHING),
		"ach mgr orch: undo_nothing not from hard clear that used undo"
	)
	save.set("achievements_unlocked", {})
	var hard_clear: Array = mgr.call(
		"record_level_clear",
		dummy_level,
		0,
		PuzzleGenerator.Difficulty.HARD,
		false,
		false,
		0,
		true,
		false,
		0.0
	)
	r.ok(
		hard_clear.has(AchievementCatalog.ID_UNDO_NOTHING),
		"ach mgr orch: undo_nothing from hard no-undo clear"
	)

	_restore_save(save, backup_unlocked, backup_seen, backup_no_hint, backup_slides, backup_undo, backup_redo)
	save.call("save_progress")


static func _autoload(name: String) -> Node:
	var tree := Engine.get_main_loop()
	if tree == null:
		return null
	return tree.root.get_node_or_null(name)


static func _restore_save(
	save: Node,
	unlocked: Dictionary,
	seen: Dictionary,
	no_hint_clears: int,
	shifter_slides: int,
	undo_uses: int = 0,
	redo_uses: int = 0
) -> void:
	save.set("achievements_unlocked", unlocked.duplicate())
	save.set("achievements_seen", seen.duplicate())
	save.set("no_hint_clears", no_hint_clears)
	save.set("shifter_slides", shifter_slides)
	save.set("undo_uses", undo_uses)
	save.set("redo_uses", redo_uses)
