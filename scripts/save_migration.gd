class_name SaveMigration
extends RefCounted
## progression.cfg format helpers (kept free of autoload deps for headless tests).

const FORMAT_VERSION := 5
const LEGACY_LEVEL_OFFSET := 14
const LEGACY_LEVEL_MIN := 15
const LEGACY_LEVEL_MAX := 74

## Migrates older progression.cfg shapes in-place before fields are read.
static func migrate_config(config: ConfigFile, from_version: int) -> void:
	if from_version >= FORMAT_VERSION:
		return
	# v1 → v2: introduce Meta.version; normalize star-bit dictionary keys to strings.
	if from_version < 2:
		var bits = config.get_value("Progression", "level_star_bits", {})
		if typeof(bits) == TYPE_DICTIONARY:
			var normalized := {}
			for key in bits:
				normalized[str(key)] = int(bits[key])
			config.set_value("Progression", "level_star_bits", normalized)
	# v2 → v3: achievements "seen" tracking. Only pre-existing unlocks (saved before
	# 1.1 backfill) are marked seen so retroactive grants keep the menu badge.
	if from_version < 3:
		var unlocked = config.get_value("Achievements", "unlocked", {})
		if typeof(unlocked) == TYPE_DICTIONARY and not unlocked.is_empty():
			var seen: Dictionary = config.get_value("Achievements", "seen", {})
			if typeof(seen) != TYPE_DICTIONARY:
				seen = {}
			for id in unlocked:
				seen[str(id)] = true
			config.set_value("Achievements", "seen", seen)
	# v3 → v4: campaign level ids 15–74 → 1–60; tutorial script id level_1 → level_00.
	if from_version < 4:
		_migrate_v4_progression(config)
		_migrate_v4_achievements(config)
		_migrate_v4_session(config)
	# v4 → v5: undo_nothing was granted on any no-undo clear; keep only after a hard clear.
	if from_version < 5:
		_migrate_v5_undo_nothing(config)


## Remaps legacy internal campaign level numbers (15–74) to 1–60.
static func remap_legacy_level_number(level_num: int) -> int:
	var n := int(level_num)
	if n >= LEGACY_LEVEL_MIN and n <= LEGACY_LEVEL_MAX:
		return n - LEGACY_LEVEL_OFFSET
	if n == LEGACY_LEVEL_MAX + 1:
		return 61
	return n


static func remap_legacy_level_path(path: String) -> String:
	var p := String(path)
	if p.is_empty():
		return p
	if p.ends_with("/tutorials/level_1.tres"):
		return p.replace("/tutorials/level_1.tres", "/tutorials/level_00.tres")
	var file := p.get_file()
	if not file.begins_with("level_") or not file.ends_with(".tres"):
		return p
	var old_num := int(file.get_basename().replace("level_", ""))
	if old_num >= LEGACY_LEVEL_MIN and old_num <= LEGACY_LEVEL_MAX:
		var new_num := remap_legacy_level_number(old_num)
		return p.replace(file, "level_%02d.tres" % new_num)
	return p


static func remap_level_dict(dict: Dictionary) -> Dictionary:
	var out := {}
	for key in dict:
		var new_key := str(remap_legacy_level_number(int(key)))
		var existing := int(out.get(new_key, 0))
		out[new_key] = maxi(existing, int(dict[key]))
	return out


static func _migrate_v4_progression(config: ConfigFile) -> void:
	var max_unlocked := int(config.get_value("Progression", "max_unlocked_level", 1))
	config.set_value("Progression", "max_unlocked_level", remap_legacy_level_number(max_unlocked))
	var bits = config.get_value("Progression", "level_star_bits", {})
	if typeof(bits) == TYPE_DICTIONARY:
		config.set_value("Progression", "level_star_bits", remap_level_dict(bits))
	var unseen = config.get_value("Progression", "levels_unseen", {})
	if typeof(unseen) == TYPE_DICTIONARY:
		var remapped := {}
		for key in unseen:
			remapped[str(remap_legacy_level_number(int(key)))] = unseen[key]
		config.set_value("Progression", "levels_unseen", remapped)
	var scripts = config.get_value("Progression", "completed_tutorial_scripts", [])
	if typeof(scripts) == TYPE_ARRAY:
		var migrated: Array = []
		for entry in scripts:
			var id := str(entry)
			if id == "level_1":
				id = "level_00"
			if not migrated.has(id):
				migrated.append(id)
		config.set_value("Progression", "completed_tutorial_scripts", migrated)


static func _migrate_v4_achievements(config: ConfigFile) -> void:
	var rules = config.get_value("Achievements", "rules_open_levels", {})
	if typeof(rules) == TYPE_DICTIONARY:
		var remapped := {}
		for key in rules:
			remapped[str(remap_legacy_level_number(int(key)))] = rules[key]
		config.set_value("Achievements", "rules_open_levels", remapped)


static func _migrate_v4_session(config: ConfigFile) -> void:
	var session = config.get_value("Session", "data", {})
	if typeof(session) != TYPE_DICTIONARY or session.is_empty():
		return
	var path := str(session.get("level_path", ""))
	if not path.is_empty():
		session["level_path"] = remap_legacy_level_path(path)
	if session.has("level_number"):
		session["level_number"] = remap_legacy_level_number(int(session.get("level_number", 0)))
	config.set_value("Session", "data", session)


## Drops undo_nothing unless campaign progress has cleared at least one hard level.
static func _migrate_v5_undo_nothing(config: ConfigFile) -> void:
	var unlocked = config.get_value("Achievements", "unlocked", {})
	if typeof(unlocked) != TYPE_DICTIONARY:
		return
	if not unlocked.has(AchievementCatalog.ID_UNDO_NOTHING):
		return
	var max_unlocked := int(config.get_value("Progression", "max_unlocked_level", 1))
	var hard_first := AchievementCatalog.first_level_number_in_dir(GameConstants.CAMPAIGN_HARD_DIR)
	if hard_first > 0 and max_unlocked > hard_first:
		return
	unlocked.erase(AchievementCatalog.ID_UNDO_NOTHING)
	config.set_value("Achievements", "unlocked", unlocked)
	var seen = config.get_value("Achievements", "seen", {})
	if typeof(seen) == TYPE_DICTIONARY:
		seen.erase(AchievementCatalog.ID_UNDO_NOTHING)
		config.set_value("Achievements", "seen", seen)
