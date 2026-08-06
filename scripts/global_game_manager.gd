extends Node

var selected_level_resource: LevelData = null
var debug_tools_enabled: bool = false
var main_menu_should_fade_in: bool = false

var _back_guard_until_msec: int = 0
var _scene_guard_until_msec: int = 0
var _screenshot_busy: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_F12:
			capture_store_screenshot()
			get_viewport().set_input_as_handled()

func capture_store_screenshot() -> void:
	if _screenshot_busy:
		return
	_screenshot_busy = true
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		push_error("Screenshot failed: no viewport image")
		_screenshot_busy = false
		return
	if img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)
	var dir_path := _screenshot_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-")
	var file_path := dir_path.path_join("screenshot_%s.png" % stamp)
	var err := img.save_png(file_path)
	_screenshot_busy = false
	if err != OK:
		push_error("Screenshot save failed (%s): %s" % [err, file_path])
		return
	print("Screenshot saved: ", file_path)

func _screenshot_dir() -> String:
	if OS.has_feature("editor") or OS.get_name() in ["Windows", "Linux", "macOS"]:
		var project_dir := ProjectSettings.globalize_path("res://docs/store-assets/screenshots")
		if not project_dir.is_empty():
			return project_dir
	return ProjectSettings.globalize_path("user://screenshots")

func consume_system_back() -> bool:
	var now := Time.get_ticks_msec()
	if now < _back_guard_until_msec:
		return false
	_back_guard_until_msec = now + 450
	return true

func quit_app() -> void:
	if AdsManager and AdsManager.has_method("prepare_for_app_exit"):
		AdsManager.prepare_for_app_exit()
	var tree := get_tree()
	if tree:
		tree.call_deferred("quit")

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
