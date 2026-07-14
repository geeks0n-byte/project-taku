@tool
extends EditorScript

# Master database containing your completed layouts
var master_level_database: Array = [
	{
		"number": 1,
		# NEW: Define your allowed tiles here! [0 = Red, 1 = Blue, 2 = Green Wildcard]
		"available_tiles": [0, 1, 2], 
		"layout": {
			Vector2i(0,0): -1, Vector2i(1,0): -1, Vector2i(2,0): 2,  Vector2i(3,0): -1, Vector2i(4,0): -1, Vector2i(5,0): -1, Vector2i(6,0): -1,
			Vector2i(0,1): -1, Vector2i(1,1): -1, Vector2i(2,1): -1, Vector2i(3,1): -1, Vector2i(4,1): 2,  Vector2i(5,1): -1, Vector2i(6,1): -1,
			Vector2i(0,2): 2,  Vector2i(1,2): -1, Vector2i(2,2): 0,  Vector2i(3,2): -1, Vector2i(4,2): -1, Vector2i(5,2): -1,  Vector2i(6,2): -1,
			Vector2i(0,3): -1, Vector2i(1,3): -1, Vector2i(2,3): -1, Vector2i(3,3): -1, Vector2i(4,3): -1, Vector2i(5,3): -2,  Vector2i(6,3): -1,
			Vector2i(0,4): -1, Vector2i(1,4): -1, Vector2i(2,4): -1, Vector2i(3,4): -2,  Vector2i(4,4): -1, Vector2i(5,4): -1, Vector2i(6,4): -1,
			Vector2i(0,5): 1,  Vector2i(1,5): -1, Vector2i(2,5): -1, Vector2i(3,5): -1, Vector2i(4,5): -1, Vector2i(5,5): 1,  Vector2i(6,5): 2,
			Vector2i(0,6): -1, Vector2i(1,6): 2,  Vector2i(2,6): -1, Vector2i(3,6): 0,  Vector2i(4,6): -1, Vector2i(5,6): -1, Vector2i(6,6): -1,
		}
	},
	{
		"number": 2,
		# If you completely omit "available_tiles" here, the script will automatically
		# default to [0, 1] when building the file, saving you typing time!
		"layout": {
			Vector2i(0,0): -1, Vector2i(1,0): -1, Vector2i(2,0): -1, Vector2i(3,0): -1, Vector2i(4,0): 1,  Vector2i(5,0): -1, Vector2i(6,0): -1,
			Vector2i(0,1): -1, Vector2i(1,1): -2, Vector2i(2,1): -1, Vector2i(3,1): 2,  Vector2i(4,1): -1, Vector2i(5,1): -1, Vector2i(6,1): -1,
			Vector2i(0,2): 0,  Vector2i(1,2): -1, Vector2i(2,2): -1, Vector2i(3,2): -1, Vector2i(4,2): -1, Vector2i(5,2): 2,  Vector2i(6,2): -1,
			Vector2i(0,3): -1, Vector2i(1,3): -1, Vector2i(2,3): 1,  Vector2i(3,3): -1, Vector2i(4,3): 0,  Vector2i(5,3): -1, Vector2i(6,3): -1,
			Vector2i(0,4): -1, Vector2i(1,4): 2,  Vector2i(2,4): -1, Vector2i(3,4): -1, Vector2i(4,4): -1, Vector2i(5,4): -1, Vector2i(6,4): 0,
			Vector2i(0,5): -1, Vector2i(1,5): -1, Vector2i(2,5): -1, Vector2i(3,5): 0,  Vector2i(4,5): -1, Vector2i(5,5): -2, Vector2i(6,5): -1,
			Vector2i(0,6): -1, Vector2i(1,6): -1, Vector2i(2,6): -1, Vector2i(3,6): -1, Vector2i(4,6): -1, Vector2i(5,6): -1, Vector2i(6,6): 1,
		}
	}
]

func _run():
	print("--- Running Level Generation Sequence ---")
	
	if not DirAccess.dir_exists_absolute("res://levels"):
		DirAccess.make_dir_absolute("res://levels")

	for data in master_level_database:
		var new_level = LevelData.new()
		new_level.level_number = data["number"]
		new_level.layout = data["layout"]
		
		# --- NEW: Safely read and assign available tiles ---
		var allowed: Array[int] = [0, 1] # Fallback
		if data.has("available_tiles"):
			# .assign() safely forces the dictionary array into Godot's strictly typed Array[int]
			allowed.assign(data["available_tiles"])
		new_level.available_tiles = allowed
		# ---------------------------------------------------
		
		var max_x = 0
		var max_y = 0
		
		for coord in data["layout"].keys():
			if coord.x > max_x: max_x = coord.x
			if coord.y > max_y: max_y = coord.y
			
		new_level.width = max_x + 1
		new_level.height = max_y + 1
		
		var save_path = "res://levels/level_%d.tres" % data["number"]
		var result = ResourceSaver.save(new_level, save_path)
		
		if result == OK:
			print("Successfully created resource: ", save_path, " (Size: %dx%d, Tiles: %s)" % [new_level.width, new_level.height, str(allowed)])
		else:
			print("Generation Error on path: ", save_path, " Code: ", result)
			
	print("--- Sequence Complete! Check your files ---")
