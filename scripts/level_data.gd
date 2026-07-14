extends Resource
class_name LevelData

@export var level_number: int = 1
# Add width and height so the editor knows the bounds of the board
@export var width: int = 3 
@export var height: int = 3 
@export var layout: Dictionary = {} # Holds the { Vector2i(x,y): state_id } mappings

# NEW: Stores which tile types the player is allowed to cycle through.
# Defaulting to [0, 1] automatically fixes older levels that lack this data!
@export var available_tiles: Array[int] = [0, 1]

## Validates that all keys in the layout are Vector2i
func validate_layout() -> bool:
	for coord in layout.keys():
		if not coord is Vector2i:
			return false
	return true
