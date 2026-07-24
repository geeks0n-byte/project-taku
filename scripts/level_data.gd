class_name LevelData
extends Resource

@export var level_number: int = 1
@export var width: int = 6
@export var height: int = 6
## Soft time-star target in seconds (0 = no time star). Not a hard fail timer.
@export var time_limit: int = 0
@export var required_jokers: int = 0
@export var required_shifter_moves: int = 0
@export var is_unique_solution: bool = true
## When true, generator keeps this layout's walls. When false, it may rebuild walls each load.
@export var keep_walls: bool = true
@export var available_tiles: Array = [0, 1, 2]
@export var layout: Dictionary = {}
@export var shifter_pairs: Array = []
@export var constraint_pairs: Array = []
