extends Node

# The global courier variable that will hold our selected level resource
var selected_level_resource: LevelData = null
var debug_tools_enabled: bool = false

func _ready() -> void:
	# Portrait lock only applies on mobile display servers (desktop warns otherwise).
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
