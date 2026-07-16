@tool
extends EditorScript

# Master database containing your completed layouts
var master_level_database: Array = [
	{
		"number": 1,
		"time_limit": 0, # 0 = Unlimited Time!
		"available_tiles": [0, 1, 2], 
		"layout": {
			Vector2i(0,0): -1, Vector2i(1,0): -1, Vector2i(2,0): 2,  Vector2i(3,0): -1, Vector2i(4,0): -1, Vector2i(5,0): -1, Vector2i(6,0): -1,
			Vector2i(0,1): -1, Vector2i(1,1): -1, Vector2i(2,1): -1, Vector2i(3,1): -1, Vector2i(4,1): 2,  Vector2i(5,1): -1, Vector2i(6,1): -1,
			Vector2i(0,2): 2,  Vector2i(1,2): -1, Vector2i(2,2): 0,  Vector2i(3,2): -1, Vector2i(4,2): -1, Vector2i(5,2): -1,  Vector2i(6,2): -1,
			Vector2i(0,3): -1, Vector2i(1,3): -1, Vector2i(2,3): -1, Vector2i(3,3): -1, Vector2i(4,3): -1, Vector2i(5,3): -2,  Vector2i(6,3): -1,
			Vector2i(0,4): -1, Vector2i(1,4): -1, Vector2i(2,4): -1, Vector2i(3,4): -2,  Vector2i(4,4): -1, Vector2i(5,4): -1, Vector2i(6,4): -1,
			Vector2i(0,5): 1,  Vector2i(1,5): -1, Vector2i(2,5): -1, Vector2i(3,5): -1, Vector2i(4,5): -1, Vector2i(5,5): 1,  Vector2i(6,5): 2,
			Vector2i(0,6): -1, Vector2i(1,6): 2,  Vector2i(2,6): -1, Vector2i(3,6): 0,  Vector2i(4,6): -1, Vector2i(5,6): -1, Vector2i(6,6): -1,
		},
		# NEW: Define Shifter pairs. "a" and "b" are the two linked coordinates. "active" is where the purple tile currently sits.
		"shifter_pairs": [
			{"a": Vector2i(0,0), "b": Vector2i(1,0), "active": Vector2i(0,0)}
		],
		# NEW: Define Constraints. type can be "equals" (=) or "not_equals" (x)
		"constraint_pairs": [
			{"a": Vector2i(2,2), "b": Vector2i(3,2), "type": "equals"}
		]
	},
	{
		"number": 2,
		"time_limit": 60,
		# If omitted, available_tiles defaults to [0, 1]
		# If omitted, shifter_pairs and constraint_pairs default to empty arrays []
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
		
		# --- TIME LIMIT ---
		if data.has("time_limit"):
			new_level.time_limit = data["time_limit"]
		else:
			new_level.time_limit = 60 # Default fallback
		
		# --- AVAILABLE TILES ---
		var allowed: Array[int] = [0, 1] 
		if data.has("available_tiles"):
			allowed.assign(data["available_tiles"])
		new_level.available_tiles = allowed
		
		# --- SHIFTER PAIRS ---
		var shifters: Array = []
		if data.has("shifter_pairs"):
			shifters.assign(data["shifter_pairs"].duplicate(true))
		new_level.shifter_pairs = shifters
		
		# --- CONSTRAINT PAIRS ---
		var constraints: Array = []
		if data.has("constraint_pairs"):
			constraints.assign(data["constraint_pairs"].duplicate(true))
		new_level.constraint_pairs = constraints
		
		# --- DYNAMIC GRID SIZING ---
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
			print("Successfully created resource: ", save_path, " (Size: %dx%d, Time: %ds, Tiles: %s, Shifters: %d, Constraints: %d)" % [new_level.width, new_level.height, new_level.time_limit, str(allowed), shifters.size(), constraints.size()])
		else:
			print("Generation Error on path: ", save_path, " Code: ", result)
			
	print("--- Sequence Complete! Check your files ---")
