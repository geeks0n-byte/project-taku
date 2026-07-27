extends Node

# The global courier variable that will hold our selected level resource
var selected_level_resource: LevelData = null
var debug_tools_enabled: bool = false
## Set by splash so main menu can fade UI in over the shared space background.
var main_menu_should_fade_in: bool = false

## Debounce Android back (can fire twice per press on some Godot versions).
var _back_guard_until_msec: int = 0
var _scene_guard_until_msec: int = 0

func _ready() -> void:
	# Portrait lock only applies on mobile display servers (desktop warns otherwise).
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)

## Returns true once per back gesture; ignores duplicate presses for a short window.
func consume_system_back() -> bool:
	var now := Time.get_ticks_msec()
	if now < _back_guard_until_msec:
		return false
	_back_guard_until_msec = now + 450
	return true

## Tear down ads, then quit on the next idle frame (avoids AdMob native crashes).
func quit_app() -> void:
	if AdsManager and AdsManager.has_method("prepare_for_app_exit"):
		AdsManager.prepare_for_app_exit()
	var tree := get_tree()
	if tree:
		tree.call_deferred("quit")

## Deferred scene change; ignores stacked back/quit navigation.
func go_to_scene(path: String) -> void:
	if path.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now < _scene_guard_until_msec:
		return
	var tree := get_tree()
	if tree == null:
		return
	_scene_guard_until_msec = now + 600
	tree.paused = false
	tree.call_deferred("change_scene_to_file", path)