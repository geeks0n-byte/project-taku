extends Resource
class_name LevelData

@export var level_number: int = 1
@export var width: int = 3 
@export var height: int = 3 
@export var layout: Dictionary = {} 
@export var available_tiles: Array = []

@export var time_limit: int = 120 
@export var shifter_pairs: Array = [] 
@export var constraint_pairs: Array = [] 

func _init():
	layout = {}
	available_tiles = [0, 1]
	shifter_pairs = []
	constraint_pairs = []

func validate_layout() -> bool:
	for coord in layout.keys():
		if not coord is Vector2i:
			return false
	return true
