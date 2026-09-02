class_name CampaignLevelAudit
extends RefCounted
## Validates every campaign .tres: clean starting layout and solver analysis.

static func validate_all() -> Array[String]:
	var errors: Array[String] = []
	for path in LevelUtils.scan_campaign_levels():
		errors.append_array(_validate_path(path))
	return errors


static func _difficulty_for_path(path: String) -> int:
	if path.begins_with(GameConstants.CAMPAIGN_EASY_DIR):
		return PuzzleGenerator.Difficulty.EASY
	if path.begins_with(GameConstants.CAMPAIGN_HARD_DIR):
		return PuzzleGenerator.Difficulty.HARD
	if path.begins_with(GameConstants.CAMPAIGN_MEDIUM_DIR):
		return PuzzleGenerator.Difficulty.MEDIUM
	return PuzzleGenerator.Difficulty.MEDIUM


static func _validate_path(path: String) -> Array[String]:
	var errors: Array[String] = []
	var level := load(path) as LevelData
	if level == null:
		errors.append("%s: failed to load LevelData" % path)
		return errors
	var layout := LevelUtils.ensure_layout_covers_grid(level.layout.duplicate(true), level.width, level.height)
	var shifters := LevelUtils.get_shifter_pairs(level)
	if not PuzzleValidator.starting_layout_is_clean(
		layout,
		level.width,
		level.height,
		level.constraint_pairs,
		shifters
	):
		errors.append("%s: starting layout is not clean" % path)
		return errors
	if LevelUtils.is_shape_only_layout(layout):
		return _validate_shape_template(level, path)
	return _validate_preset_layout(level, path, layout, shifters)


## Wall/empty templates are filled procedurally at runtime — mirror generate_board().
static func _validate_shape_template(level: LevelData, path: String) -> Array[String]:
	var errors: Array[String] = []
	var tiles := LevelUtils.normalize_available_tiles(level.available_tiles)
	var require_unique := bool(level.is_unique_solution)
	var difficulty := _difficulty_for_path(path)
	var attempts := 25 if require_unique else 10
	var generated: Dictionary = {}
	for _attempt in attempts:
		generated = PuzzleGenerator.generate_random_layout(
			level.width,
			level.height,
			tiles,
			level.layout,
			require_unique,
			level.keep_walls,
			difficulty,
			true
		)
		if not generated.is_empty():
			break
	if generated.is_empty():
		errors.append("%s: generator could not fill shape template" % path)
		return errors
	var fill: Dictionary = generated.get("layout", {})
	var constraints: Array = generated.get("constraints", [])
	var gen_shifters: Array = generated.get("shifters", [])
	if not PuzzleValidator.starting_layout_is_clean(
		fill, level.width, level.height, constraints, gen_shifters
	):
		errors.append("%s: generated layout is not clean" % path)
		return errors
	var analysis := PuzzleSolver.analyze(
		fill, level.width, level.height, tiles, constraints, gen_shifters, require_unique
	)
	if not bool(analysis.get("solvable", false)):
		errors.append("%s: generated layout not solvable" % path)
	elif require_unique and not bool(analysis.get("unique", false)):
		errors.append("%s: generated layout not unique" % path)
	return errors


## Authored tile placements (tutorials and fixed boards) are played as stored.
static func _validate_preset_layout(
	level: LevelData,
	path: String,
	layout: Dictionary,
	shifters: Array
) -> Array[String]:
	var errors: Array[String] = []
	var tiles := LevelUtils.normalize_available_tiles(level.available_tiles)
	var require_unique := bool(level.is_unique_solution)
	if path.begins_with(GameConstants.CAMPAIGN_TUTORIALS_DIR):
		require_unique = false
	var analysis := PuzzleSolver.analyze(
		layout,
		level.width,
		level.height,
		tiles,
		level.constraint_pairs,
		shifters,
		require_unique
	)
	if not bool(analysis.get("solvable", false)):
		errors.append("%s: not solvable" % path)
	elif require_unique and not bool(analysis.get("unique", false)):
		errors.append("%s: not unique" % path)
	return errors
