extends Resource
class_name LevelData

@export var level_number: int = 1
@export var width: int = 3 
@export var height: int = 3 
@export var layout: Dictionary = {} 
@export var available_tiles: Array[int] = [0, 1]

# --- NEW GAMEPLAY MECHANICS ---
@export var time_limit: int = 120 # Default time in seconds
# Stores the linked pairs: {"a": Vector2i, "b": Vector2i, "active": Vector2i}
@export var red_pairs: Array[Dictionary] = [] 

func validate_layout() -> bool:
	for coord in layout.keys():
		if not coord is Vector2i:
			return false
	return true
