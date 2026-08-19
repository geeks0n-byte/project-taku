class_name LevelData
extends Resource

# Serialized resource that fully describes one puzzle level.
# Saved as a .tres file; all fields are exported so the level editor can write them via ResourceSaver.

# Sequential identifier shown to the player. Tutorial levels use their own numbering range.
@export var level_number: int = 1
# Grid dimensions in cells.
@export var width: int = 6
@export var height: int = 6
# Time limit in seconds. 0 means no time limit.
@export var time_limit: int = 0
# How many joker tiles the player must place to satisfy the win condition.
# -1 means "auto" (derive from min(width, height) at runtime).
@export var required_jokers: int = 0
# Minimum number of shifter-swap moves required to reach the solved state.
# Used to validate difficulty and display hints.
@export var required_shifter_moves: int = 0
# Whether this puzzle has exactly one valid solution. Affects hint generation and save validation.
@export var is_unique_solution: bool = true
# If true, wall cells persist when the board is cleared in the editor.
@export var keep_walls: bool = true
# Which tile colours/types are available in the tile picker. Defaults to yellow, blue, joker (0, 1, 2).
@export var available_tiles: Array = [0, 1, 2]
# Sparse dictionary mapping Vector2i grid coordinates to TileState values.
# Cells not present in the dict are treated as EMPTY.
@export var layout: Dictionary = {}
# Each entry is a dict with keys "a", "b", "active", "home", "inactive" (Vector2i coords).
# Describes which cell pairs form a shifter and which cell is currently occupied.
@export var shifter_pairs: Array = []
# Each entry is a dict with keys "a", "b" (Vector2i) and "type" ("equals" or "not_equals").
@export var constraint_pairs: Array = []
