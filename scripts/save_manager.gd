extends Node

# ==========================================
# CONSTANTS & PATHS
# ==========================================
# 'user://' points to the local AppData directory on PC,
# and secure internal sandboxed storage on Android. Fully writeable!
const SAVE_PATH = "user://progression.cfg"

# ==========================================
# SYSTEM VARIABLES
# ==========================================
var max_unlocked_level: int = 1

# ==========================================
# INITIALIZATION
# ==========================================
func _ready() -> void:
	load_progress()

# ==========================================
# PROGRESSION STORAGE METHODS
# ==========================================
func load_progress() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	
	if err == OK:
		# Grabs saved progress under the [Progression] section.
		# Falls back to Level 1 if the variable is missing or corrupted.
		max_unlocked_level = config.get_value("Progression", "max_unlocked_level", 1)
	else:
		# If no save file exists, build a new default template instantly.
		save_progress()

func save_progress() -> void:
	var config = ConfigFile.new()
	config.set_value("Progression", "max_unlocked_level", max_unlocked_level)
	config.save(SAVE_PATH)

# ==========================================
# PROGRESSION TRACKERS
# ==========================================
func unlock_level(level_num: int) -> void:
	# Updates progress only if the unlocked level is higher than current progress.
	if level_num > max_unlocked_level:
		max_unlocked_level = level_num
		save_progress()

func is_level_unlocked(level_num: int) -> bool:
	# Helper tool used by the level select screen to evaluate visual locks.
	return level_num <= max_unlocked_level

# ==========================================
# HARD SYSTEM WIPES
# ==========================================
func delete_save_file() -> void:
	# Reset state tracking variable inside memory back to Level 1.
	max_unlocked_level = 1
	
	# Physically evaluate path availability and wipe the file from storage.
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
