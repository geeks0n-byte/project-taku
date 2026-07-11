extends Resource
class_name LevelData

@export var level_number: int = 1
@export var layout: Dictionary = {} # Holds the { Vector2i(x,y): state_id } mappings
