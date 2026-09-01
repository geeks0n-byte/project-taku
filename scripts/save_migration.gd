class_name SaveMigration
extends RefCounted
## progression.cfg format helpers (kept free of autoload deps for headless tests).

const FORMAT_VERSION := 3

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
