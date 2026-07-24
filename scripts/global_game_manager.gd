extends Node

# The global courier variable that will hold our selected level resource
var selected_level_resource: LevelData = null
var debug_tools_enabled: bool = false
## Set by splash so main menu can fade UI in over the shared space background.
var main_menu_should_fade_in: bool = false

func _ready() -> void:
	# Portrait lock only applies on mobile display servers (desktop warns otherwise).
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
