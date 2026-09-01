extends Node
## Autoload for progression.cfg: unlocks, settings, locale fonts, and in-progress sessions.

const SAVE_PATH = "user://progression.cfg"
const SAVE_TEMP_PATH = "user://progression.cfg.tmp"
const SAVE_FORMAT_VERSION := 3
const SUPPORTED_LANGUAGES := ["en", "es", "de", "fr", "pl", "ka", "uk", Pseudolocale.LOCALE]
const PSEUDO_LOCALE := Pseudolocale.LOCALE
const _TranslationHygiene := preload("res://scripts/translation_hygiene.gd")
const _PseudolocaleTranslation := preload("res://scripts/pseudolocale_translation.gd")
const _SessionSerialization := preload("res://scripts/session_serialization.gd")

signal language_changed
signal unseen_levels_changed(count: int)

var max_unlocked_level: int = 1
var current_language: String = "en"
var background_static: bool = false
var bgm_enabled: bool = true
var sfx_enabled: bool = true
var haptic_enabled: bool = true
var tutorial_intro_answered: bool = false
var completed_tutorial_scripts: Array = []
# True once the player has tapped ACCEPT on the first-launch consent popup.
# Defaults to true for existing saves (no save file key = already accepted).
var privacy_accepted: bool = false
# Unlocked each session by holding the version label in credits for 3 seconds.
# NOT saved to disk — must be re-activated every launch to prevent save file cheating.
var dev_mode_enabled: bool = false
var level_star_bits: Dictionary = {}
var session_data: Dictionary = {}
var ads_wins_since_interstitial: int = 0
# Local achievements: id -> unix timestamp. New section; existing keys stay intact.
var achievements_unlocked: Dictionary = {}
# ids the player has viewed in the achievements list since unlocking (menu badge).
var achievements_seen: Dictionary = {}
# Campaign level numbers unlocked since last viewed/played (menu + level-select badges).
var levels_unseen: Dictionary = {}
# Campaign clears with zero hints (hint_saver / no_hint family progress).
var no_hint_clears: int = 0
# Campaign victories that earned the time star (on_time family).
var on_time_clears: int = 0
# Lifetime shifter slides (purple_rain).
var shifter_slides: int = 0
# Campaign level numbers where the player opened rules (rules_reader).
var rules_open_levels: Dictionary = {}
# Last local save time (unix seconds) for cloud conflict resolution.
var updated_unix: int = 0
# In-app review prompt bookkeeping.
var review_prompt_count: int = 0
var review_last_prompt_unix: int = 0
var first_play_unix: int = 0

## Loads save data, applies background mode, and walks new text controls for locale fonts.
func _ready() -> void:
	_sync_translations_from_csv()
	_verify_translation_hygiene()
	load_progress()
	_apply_background_mode()
	if not get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.connect(_on_tree_node_added)
	call_deferred("apply_locale_fonts")

## Editor-only: rebuilds Translation objects from translations.csv so CSV edits apply without reimport.
func _sync_translations_from_csv() -> void:
	# Exported builds use imported .translation from Project Settings.
	# Reading translations.csv only works reliably in the editor; on device the
	# CSV is often missing/remapped, which left keys untranslated and broke % formatting.
	if not OS.has_feature("editor"):
		return
	const CSV_PATH := "res://resources/localization/translations.csv"
	if not FileAccess.file_exists(CSV_PATH):
		return
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		return
	var headers: PackedStringArray = file.get_csv_line()
	if headers.size() < 2 or headers[0] != "keys":
		return
	# Rebuild plain Translation objects from CSV so editor picks up CSV edits
	# without waiting for reimport. OptimizedTranslation ignores add_message().
	var locale_translations: Dictionary = {}
	for i in range(1, headers.size()):
		var locale := String(headers[i]).strip_edges()
		if locale.is_empty():
			continue
		while true:
			var existing := TranslationServer.get_translation_object(locale)
			if existing == null:
				break
			TranslationServer.remove_translation(existing)
		var translation := Translation.new()
		translation.locale = locale
		TranslationServer.add_translation(translation)
		locale_translations[i] = translation
	var expected_cols := headers.size()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.is_empty():
			continue
		var key := String(row[0]).strip_edges()
		if key.is_empty() or key == "keys":
			continue
		if row.size() != expected_cols:
			push_warning("translations.csv: skipped %s (got %d cols, expected %d)" % [key, row.size(), expected_cols])
			continue
		for i in locale_translations.keys():
			var idx := int(i)
			if idx >= row.size():
				continue
			var message := String(row[idx])
			if message.is_empty():
				continue
			(locale_translations[idx] as Translation).add_message(key, message.c_unescape())
	file.close()

## Editor-only: warn when CSV locales are missing or rows have empty cells.
func _verify_translation_hygiene() -> void:
	if not OS.has_feature("editor"):
		return
	for issue in _TranslationHygiene.audit():
		push_warning(issue)

## Level number of the first easy campaign puzzle (unlock floor for new saves).
func get_campaign_start_unlock() -> int:
	var easy_paths := LevelUtils.scan_directory(GameConstants.CAMPAIGN_EASY_DIR)
	LevelUtils.sort_level_paths(easy_paths)
	for path in easy_paths:
		var resource = load(path)
		if resource is LevelData:
			return int(resource.level_number)
	return 1

## Raises max_unlocked_level if it sits below the campaign start.
func _ensure_campaign_start_unlock() -> void:
	var start := get_campaign_start_unlock()
	if max_unlocked_level < start:
		max_unlocked_level = start
		save_progress()

## Reads progression.cfg, migrates older formats, or seeds a new save from the system language.
func load_progress() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)

	if err == OK:
		var save_version := int(config.get_value("Meta", "version", 1))
		_migrate_save(config, save_version)
		max_unlocked_level = config.get_value("Progression", "max_unlocked_level", 1)
		current_language = config.get_value("Progression", "current_language", "en")
		background_static = bool(config.get_value("Progression", "background_static", false))
		bgm_enabled = bool(config.get_value("Progression", "bgm_enabled", true))
		sfx_enabled = bool(config.get_value("Progression", "sfx_enabled", true))
		haptic_enabled = bool(config.get_value("Progression", "haptic_enabled", true))
		if config.has_section_key("Progression", "tutorial_intro_answered"):
			tutorial_intro_answered = bool(config.get_value("Progression", "tutorial_intro_answered", false))
		else:
			tutorial_intro_answered = true
		completed_tutorial_scripts = config.get_value("Progression", "completed_tutorial_scripts", [])
		if typeof(completed_tutorial_scripts) != TYPE_ARRAY:
			completed_tutorial_scripts = []
		if config.has_section_key("Progression", "privacy_accepted"):
			privacy_accepted = bool(config.get_value("Progression", "privacy_accepted", false))
		else:
			privacy_accepted = true  # Existing install; treat as already accepted.
		# dev_mode_enabled is intentionally not loaded — must be re-activated each session.
		level_star_bits = config.get_value("Progression", "level_star_bits", {})
		if typeof(level_star_bits) != TYPE_DICTIONARY:
			level_star_bits = {}
		session_data = config.get_value("Session", "data", {})
		if typeof(session_data) != TYPE_DICTIONARY:
			session_data = {}
		ads_wins_since_interstitial = int(config.get_value("Ads", "wins_since_interstitial", 0))
		achievements_unlocked = config.get_value("Achievements", "unlocked", {})
		if typeof(achievements_unlocked) != TYPE_DICTIONARY:
			achievements_unlocked = {}
		achievements_seen = config.get_value("Achievements", "seen", {})
		if typeof(achievements_seen) != TYPE_DICTIONARY:
			achievements_seen = {}
		levels_unseen = config.get_value("Progression", "levels_unseen", {})
		if typeof(levels_unseen) != TYPE_DICTIONARY:
			levels_unseen = {}
		no_hint_clears = int(config.get_value("Achievements", "no_hint_clears", 0))
		on_time_clears = int(config.get_value("Achievements", "on_time_clears", 0))
		shifter_slides = int(config.get_value("Achievements", "shifter_slides", 0))
		rules_open_levels = config.get_value("Achievements", "rules_open_levels", {})
		if typeof(rules_open_levels) != TYPE_DICTIONARY:
			rules_open_levels = {}
		updated_unix = int(config.get_value("Meta", "updated_unix", 0))
		review_prompt_count = int(config.get_value("Meta", "review_prompt_count", 0))
		review_last_prompt_unix = int(config.get_value("Meta", "review_last_prompt_unix", 0))
		first_play_unix = int(config.get_value("Meta", "first_play_unix", 0))
		if not SUPPORTED_LANGUAGES.has(current_language):
			current_language = "en"
		_apply_translation_locale(current_language)
		if save_version < SAVE_FORMAT_VERSION:
			save_progress()
	elif err == ERR_FILE_NOT_FOUND:
		_seed_new_save()
	else:
		push_error("SaveManager: failed to load %s (error %d) — starting fresh" % [SAVE_PATH, err])
		_seed_new_save()
	_ensure_campaign_start_unlock()

## Initializes default progression for a missing or unreadable save file.
func _seed_new_save() -> void:
	current_language = _detect_system_language()
	_apply_translation_locale(current_language)
	session_data = {}
	tutorial_intro_answered = false
	ads_wins_since_interstitial = 0
	achievements_unlocked = {}
	achievements_seen = {}
	levels_unseen = {}
	no_hint_clears = 0
	on_time_clears = 0
	shifter_slides = 0
	rules_open_levels = {}
	updated_unix = 0
	max_unlocked_level = get_campaign_start_unlock()
	save_progress()

## Migrates older progression.cfg shapes in-place before fields are read.
func _migrate_save(config: ConfigFile, from_version: int) -> void:
	const Migration := preload("res://scripts/save_migration.gd")
	Migration.migrate_config(config, from_version)

## Maps OS locale to a supported language code; falls back to en.
func _detect_system_language() -> String:
	var lang := OS.get_locale_language().to_lower()
	if SUPPORTED_LANGUAGES.has(lang):
		return lang
	var full := OS.get_locale().to_lower()
	if full.length() >= 2:
		var code := full.substr(0, 2)
		if SUPPORTED_LANGUAGES.has(code):
			return code
	return "en"

## Writes progression.cfg. Session section is erased when session_data is empty. Dev mode is never saved.
func save_progress() -> void:
	var config = ConfigFile.new()
	updated_unix = int(Time.get_unix_time_from_system())
	config.set_value("Meta", "version", SAVE_FORMAT_VERSION)
	config.set_value("Meta", "updated_unix", updated_unix)
	config.set_value("Meta", "review_prompt_count", review_prompt_count)
	config.set_value("Meta", "review_last_prompt_unix", review_last_prompt_unix)
	if first_play_unix <= 0:
		first_play_unix = updated_unix
	config.set_value("Meta", "first_play_unix", first_play_unix)
	config.set_value("Progression", "max_unlocked_level", max_unlocked_level)
	config.set_value("Progression", "current_language", current_language)
	config.set_value("Progression", "background_static", background_static)
	config.set_value("Progression", "bgm_enabled", bgm_enabled)
	config.set_value("Progression", "sfx_enabled", sfx_enabled)
	config.set_value("Progression", "haptic_enabled", haptic_enabled)
	config.set_value("Progression", "tutorial_intro_answered", tutorial_intro_answered)
	config.set_value("Progression", "completed_tutorial_scripts", completed_tutorial_scripts)
	config.set_value("Progression", "privacy_accepted", privacy_accepted)
	# dev_mode_enabled is not saved — it resets each session by design.
	config.set_value("Progression", "level_star_bits", level_star_bits)
	config.set_value("Progression", "levels_unseen", levels_unseen)
	config.set_value("Ads", "wins_since_interstitial", ads_wins_since_interstitial)
	config.set_value("Achievements", "unlocked", achievements_unlocked)
	config.set_value("Achievements", "seen", achievements_seen)
	config.set_value("Achievements", "no_hint_clears", no_hint_clears)
	config.set_value("Achievements", "on_time_clears", on_time_clears)
	config.set_value("Achievements", "shifter_slides", shifter_slides)
	config.set_value("Achievements", "rules_open_levels", rules_open_levels)
	if session_data.is_empty():
		if config.has_section("Session"):
			config.erase_section("Session")
	else:
		config.set_value("Session", "data", session_data)
	var save_err := config.save(SAVE_TEMP_PATH)
	if save_err != OK:
		push_error("SaveManager: failed to write %s (error %d)" % [SAVE_TEMP_PATH, save_err])
		return
	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("SaveManager: failed to open user:// for atomic save")
		return
	if dir.file_exists("progression.cfg"):
		var remove_err := dir.remove("progression.cfg")
		if remove_err != OK:
			push_error("SaveManager: failed to replace %s (error %d)" % [SAVE_PATH, remove_err])
			return
	var rename_err := dir.rename("progression.cfg.tmp", "progression.cfg")
	if rename_err != OK:
		push_error("SaveManager: failed to finalize %s (error %d)" % [SAVE_PATH, rename_err])

## Counts a win/restart toward the next interstitial.
func record_ad_win() -> void:
	ads_wins_since_interstitial += 1
	save_progress()

## True when wins-since-last-ad has reached the current every-N threshold.
func should_show_interstitial(every_n: int) -> bool:
	return every_n > 0 and ads_wins_since_interstitial >= every_n

## Resets the interstitial win counter after an ad is shown.
func consume_interstitial_wins() -> void:
	ads_wins_since_interstitial = 0
	save_progress()

var _locale_fonts_deferred: bool = false
var _pseudolocale_translation: Translation = null

## Persists locale, emits language_changed, then defers a single font walk.
func set_language(lang_code: String) -> void:
	current_language = lang_code
	_apply_translation_locale(lang_code)
	HudFonts.clear_pixel_text_cache()
	save_progress()
	# Listeners refresh translated copy first; fonts run once after (deferred).
	language_changed.emit()
	request_locale_fonts()


func _apply_translation_locale(lang_code: String) -> void:
	if lang_code == PSEUDO_LOCALE:
		if _pseudolocale_translation == null:
			_pseudolocale_translation = _PseudolocaleTranslation.new()
			_pseudolocale_translation.locale = PSEUDO_LOCALE
			TranslationServer.add_translation(_pseudolocale_translation)
		TranslationServer.set_locale(PSEUDO_LOCALE)
		return
	TranslationServer.set_locale(lang_code)

## Coalesces locale font walks onto the next idle frame.
func request_locale_fonts() -> void:
	if _locale_fonts_deferred:
		return
	_locale_fonts_deferred = true
	call_deferred("_apply_locale_fonts_deferred")

## Clears the coalesce flag and walks the tree for locale fonts.
func _apply_locale_fonts_deferred() -> void:
	_locale_fonts_deferred = false
	apply_locale_fonts()

## Applies locale fonts from the scene-tree root.
func apply_locale_fonts() -> void:
	var tree := get_tree()
	if tree and tree.root:
		HudLayout.apply_locale_fonts_to_tree(tree.root)

## Fonts a newly added text control unless a tree walk is already in progress.
func _on_tree_node_added(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	# PixelSafeCaption rebuilds during a tree walk must not re-enter font apply.
	if HudLayout.is_applying_locale_fonts():
		return
	if not (
		node is Button
		or node is Label
		or node is LineEdit
		or node is OptionButton
		or node is RichTextLabel
	):
		return
	# Direct apply — call_deferred(String, Node) hits Godot's Object→Object bug.
	HudLayout.apply_locale_font_to_control(node)

## Persists the static-backdrop option and applies it to SpaceBackground.
func set_background_static(is_static: bool) -> void:
	background_static = is_static
	save_progress()
	_apply_background_mode()

## Persists BGM and tells BgmManager to start or stop.
func set_bgm_enabled(enabled: bool) -> void:
	bgm_enabled = enabled
	save_progress()
	if BgmManager and BgmManager.has_method("apply_enabled"):
		BgmManager.apply_enabled()

## Persists the SFX toggle.
func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	save_progress()

## Persists the haptic toggle.
func set_haptic_enabled(enabled: bool) -> void:
	haptic_enabled = enabled
	save_progress()

# Marks privacy as accepted and persists it. Called by consent_popup.gd via main_menu.gd.
func accept_privacy() -> void:
	privacy_accepted = true
	save_progress()

# Toggles dev mode on/off at runtime (not saved). Returns the new state.
# To activate: hold the version label in the credits screen for 3 seconds.
func toggle_dev_mode() -> bool:
	dev_mode_enabled = not dev_mode_enabled
	return dev_mode_enabled

## Pushes background_static to SpaceBackground when that autoload exists.
func _apply_background_mode() -> void:
	if SpaceBackground and SpaceBackground.has_method("set_static_mode"):
		SpaceBackground.set_static_mode(background_static)

## Raises max_unlocked_level when this number is new, then saves.
func unlock_level(level_num: int, mark_unseen: bool = true) -> void:
	if level_num > max_unlocked_level:
		max_unlocked_level = level_num
		if mark_unseen:
			levels_unseen[str(level_num)] = true
		save_progress()
		unseen_levels_changed.emit(unseen_level_count())


## True when this campaign level was unlocked but not yet viewed/played.
func is_level_unseen(level_num: int) -> bool:
	return levels_unseen.has(str(level_num))


## Clears the new-level badge for one campaign number.
func mark_level_seen(level_num: int) -> void:
	var key := str(level_num)
	if not levels_unseen.has(key):
		return
	levels_unseen.erase(key)
	save_progress()
	unseen_levels_changed.emit(unseen_level_count())


## Count of unique campaign levels where rules were opened.
func rules_open_level_count() -> int:
	return rules_open_levels.size()


## Records a rules overlay open for `level` (campaign only). Returns true when newly counted.
func record_rules_opened(level: LevelData) -> bool:
	var key := rules_level_key(level)
	if key.is_empty() or rules_open_levels.has(key):
		return false
	rules_open_levels[key] = true
	return true


## Stable save key for rules_reader progress (campaign level numbers only).
static func rules_level_key(level: LevelData) -> String:
	if level == null:
		return ""
	var path := String(level.resource_path)
	if path.begins_with("user://"):
		return ""
	if path.begins_with(GameConstants.CAMPAIGN_TUTORIALS_DIR):
		return ""
	if not (
		path.begins_with(GameConstants.CAMPAIGN_EASY_DIR)
		or path.begins_with(GameConstants.CAMPAIGN_MEDIUM_DIR)
		or path.begins_with(GameConstants.CAMPAIGN_HARD_DIR)
	):
		return ""
	return str(level.level_number)


## Count of unlocked levels the player has not opened or played yet.
func unseen_level_count() -> int:
	return levels_unseen.size()

## Debug: unlocks through the highest campaign level number.
func unlock_all_levels() -> void:
	var highest := get_campaign_start_unlock()
	for path in LevelUtils.scan_campaign_levels():
		var resource = load(path)
		if resource and resource is LevelData:
			highest = maxi(highest, int(resource.level_number))
	if highest > max_unlocked_level:
		max_unlocked_level = highest
		save_progress()

## True when this campaign number is at or below max_unlocked_level.
func is_level_unlocked(level_num: int) -> bool:
	return level_num <= max_unlocked_level

## Saved star bits for a level; completion bit is implied once a later level is unlocked.
func get_level_star_bits(level_num: int) -> int:
	var bits := int(level_star_bits.get(str(level_num), 0))
	# Cleared levels always count the completion star (bit 4 / legacy moves bit).
	if level_num < max_unlocked_level:
		bits |= LevelStars.BIT_COMPLETE
	return bits

## OR-merges new star bits into the save and returns the combined mask.
func record_level_stars(level_num: int, bits: int) -> int:
	var key := str(level_num)
	var merged := get_level_star_bits(level_num) | bits
	level_star_bits[key] = merged
	save_progress()
	return merged

## True when an in-progress run is stored (non-empty level_path).
func has_session() -> bool:
	return not session_data.is_empty() and str(session_data.get("level_path", "")) != ""

## True when the stored session belongs to this LevelData resource.
func has_session_for(level: LevelData) -> bool:
	if level == null or not has_session():
		return false
	return str(session_data.get("level_path", "")) == level.resource_path

## Deserializes the stored session, or {} when none exists.
func load_session() -> Dictionary:
	if not has_session():
		return {}
	return _SessionSerialization.deserialize_session(session_data)

## Serializes an in-progress run into progression.cfg.
func save_session(data: Dictionary) -> void:
	session_data = _SessionSerialization.serialize_session(data)
	save_progress()

## Marks achievement ids as seen after the player viewed their list page(s).
func mark_achievements_seen_for_ids(ids: Array) -> void:
	var changed := false
	for raw_id in ids:
		var sid := str(raw_id)
		if not achievements_unlocked.has(sid) or achievements_seen.has(sid):
			continue
		achievements_seen[sid] = true
		changed = true
	if changed:
		save_progress()


## True when an unlocked achievement has not yet been viewed on its list page.
func is_achievement_unseen(id: String) -> bool:
	var sid := str(id)
	return achievements_unlocked.has(sid) and not achievements_seen.has(sid)


## Marks every current unlock as seen in the achievements list (clears the menu badge).
func mark_achievements_seen() -> void:
	var changed := false
	for id in achievements_unlocked:
		if achievements_seen.has(id):
			continue
		achievements_seen[id] = true
		changed = true
	if changed:
		save_progress()


## Count of unlocked achievements not yet viewed in the achievements list.
func unseen_achievement_count() -> int:
	var count := 0
	for id in achievements_unlocked:
		if not achievements_seen.has(id):
			count += 1
	return count


## Drops the stored run if one exists.
func clear_session() -> void:
	if session_data.is_empty():
		return
	session_data = {}
	save_progress()

## Resets progression, stars, session, tutorial, and privacy; language/audio prefs stay.
func delete_save_file() -> void:
	max_unlocked_level = get_campaign_start_unlock()
	level_star_bits.clear()
	session_data = {}
	tutorial_intro_answered = false
	completed_tutorial_scripts = []
	privacy_accepted = false
	ads_wins_since_interstitial = 0
	achievements_unlocked.clear()
	achievements_seen.clear()
	levels_unseen.clear()
	no_hint_clears = 0
	on_time_clears = 0
	shifter_slides = 0
	rules_open_levels.clear()
	updated_unix = 0
	review_prompt_count = 0
	review_last_prompt_unix = 0
	first_play_unix = int(Time.get_unix_time_from_system())
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	save_progress()
	unseen_levels_changed.emit(0)
	if AchievementManager:
		AchievementManager.notify_unseen_changed()


## Records that the in-app review flow was requested (quota + spacing).
func record_review_prompt() -> void:
	review_prompt_count += 1
	review_last_prompt_unix = int(Time.get_unix_time_from_system())
	save_progress()

## Remembers whether the first-run tutorial prompt was answered.
func set_tutorial_intro_answered(answered: bool = true) -> void:
	tutorial_intro_answered = answered
	save_progress()

## True when this tutorial script id is in the completed list.
func is_tutorial_script_complete(script_id: String) -> bool:
	var id := String(script_id).strip_edges()
	return not id.is_empty() and completed_tutorial_scripts.has(id)

## Appends a tutorial script id once and saves.
func mark_tutorial_script_complete(script_id: String) -> void:
	var id := String(script_id).strip_edges()
	if id.is_empty() or completed_tutorial_scripts.has(id):
		return
	completed_tutorial_scripts.append(id)
	save_progress()


## Portable JSON-friendly snapshot for CloudSaveManager (no in-progress session).
func export_cloud_payload() -> Dictionary:
	var ts := updated_unix if updated_unix > 0 else int(Time.get_unix_time_from_system())
	return CloudSaveLogic.build_blob(
		{
			"max_unlocked_level": max_unlocked_level,
			"level_star_bits": level_star_bits.duplicate(true),
			"tutorial_intro_answered": tutorial_intro_answered,
			"completed_tutorial_scripts": completed_tutorial_scripts.duplicate(),
			"privacy_accepted": privacy_accepted,
		},
		{
			"current_language": "en" if current_language == PSEUDO_LOCALE else current_language,
			"background_static": background_static,
			"bgm_enabled": bgm_enabled,
			"sfx_enabled": sfx_enabled,
			"haptic_enabled": haptic_enabled,
		},
		{
			"unlocked": achievements_unlocked.duplicate(true),
			"no_hint_clears": no_hint_clears,
			"on_time_clears": on_time_clears,
			"shifter_slides": shifter_slides,
			"rules_open_levels": rules_open_levels.duplicate(true),
		},
		ts
	)


## Applies a cloud blob then saves. Unknown keys are ignored so older blobs stay safe.
func apply_cloud_payload(blob: Dictionary) -> void:
	if not CloudSaveLogic.is_valid_blob(blob):
		return
	var progress: Dictionary = blob.get("progress", {})
	var settings: Dictionary = blob.get("settings", {})
	var ach: Dictionary = blob.get("achievements", {})
	max_unlocked_level = int(progress.get("max_unlocked_level", max_unlocked_level))
	var bits = progress.get("level_star_bits", level_star_bits)
	if typeof(bits) == TYPE_DICTIONARY:
		level_star_bits = bits
	tutorial_intro_answered = bool(progress.get("tutorial_intro_answered", tutorial_intro_answered))
	var scripts = progress.get("completed_tutorial_scripts", completed_tutorial_scripts)
	if typeof(scripts) == TYPE_ARRAY:
		completed_tutorial_scripts = scripts
	privacy_accepted = bool(progress.get("privacy_accepted", privacy_accepted))
	var lang := str(settings.get("current_language", current_language))
	if lang == PSEUDO_LOCALE:
		lang = "en"
	if SUPPORTED_LANGUAGES.has(lang):
		current_language = lang
		_apply_translation_locale(current_language)
	background_static = bool(settings.get("background_static", background_static))
	bgm_enabled = bool(settings.get("bgm_enabled", bgm_enabled))
	sfx_enabled = bool(settings.get("sfx_enabled", sfx_enabled))
	haptic_enabled = bool(settings.get("haptic_enabled", haptic_enabled))
	var unlocked = ach.get("unlocked", achievements_unlocked)
	if typeof(unlocked) == TYPE_DICTIONARY:
		achievements_unlocked = unlocked
	no_hint_clears = int(ach.get("no_hint_clears", no_hint_clears))
	on_time_clears = int(ach.get("on_time_clears", on_time_clears))
	shifter_slides = int(ach.get("shifter_slides", shifter_slides))
	var rules_levels = ach.get("rules_open_levels", rules_open_levels)
	if typeof(rules_levels) == TYPE_DICTIONARY:
		rules_open_levels = rules_levels
	updated_unix = int(blob.get("timestamp", updated_unix))
	_apply_background_mode()
	if BgmManager and BgmManager.has_method("apply_enabled"):
		BgmManager.apply_enabled()
	save_progress()
	language_changed.emit()
	request_locale_fonts()
