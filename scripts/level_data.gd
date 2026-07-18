class_name LevelData
extends Resource

@export var level_number: int = 1
@export var width: int = 6
@export var height: int = 6
@export var time_limit: int = 0
@export var required_jokers: int = 0 # NEW: Saves exact joker math per level!
@export var available_tiles: Array = [0, 1, 2]
@export var layout: Dictionary = {}
@export var shifter_pairs: Array = []
@export var constraint_pairs: Array = []
