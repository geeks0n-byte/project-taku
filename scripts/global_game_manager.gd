extends Node

# Set by the level-select screen so main.gd knows which level to load directly,
# bypassing the normal "highest unlocked" logic.
var selected_level_resource: LevelData = null
# Toggled from a debug menu; enables extra tools (auto-win, unlock-all, etc.).
var debug_tools_enabled: bool = false
# Tells the main menu to play its fade-in on cold launch (cleared after first use).
# Returning from gameplay/levels leaves this false so the menu appears immediately.
var main_menu_should_fade_in: bool = true

# Prevents rapid repeated system-back presses from navigating multiple screens at once.
var _back_guard_until_msec: int = 0
# Prevents change_scene_to_file being called twice in quick succession (e.g. double-tap).
var _scene_guard_until_msec: int = 0
var _screenshot_busy: bool = false

func _ready() -> void:
	# Always process so back-button and focus events work even when the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		# sensorPortrait: portrait-only UX without hard manifest lock (Play large-screen policy).
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_PORTRAIT)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			# Android can restore GUI focus on resume and pop the soft keyboard,
			# which resizes the window and lifts AdMob banners off the true bottom.
			_dismiss_soft_keyboard()
			call_deferred("_dismiss_soft_keyboard")
			# Unpause so boot tweens keep running; do not skip the title intro.
			_unpause_tree()
			call_deferred("_unpause_tree")
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_unpause_tree()

func _unpause_tree() -> void:
	var tree := get_tree()
	if tree:
		tree.paused = false

# Releases GUI focus and hides the virtual keyboard to avoid banner/layout drift on Android.
func _dismiss_soft_keyboard() -> void:
	var vp := get_viewport()
	if vp:
		vp.gui_release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()

# F12 shortcut for capturing store/QA screenshots without external tools.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_F12:
			capture_store_screenshot()
			get_viewport().set_input_as_handled()

# Captures the current viewport after the frame is fully rendered and saves it as PNG.
# The guard prevents overlapping async captures.
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
	# Ensure RGB8 format for PNG compatibility (viewport may return RGBA).
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

# In editor/desktop builds, saves to the tracked docs folder for store asset management.
# On device, falls back to the app's user:// directory.
func _screenshot_dir() -> String:
	if OS.has_feature("editor") or OS.get_name() in ["Windows", "Linux", "macOS"]:
		var project_dir := ProjectSettings.globalize_path("res://docs/store-assets/screenshots")
		if not project_dir.is_empty():
			return project_dir
	return ProjectSettings.globalize_path("user://screenshots")

# Rate-limits system back events to prevent accidental double-navigation.
# Returns false if the guard is still active; true if the back press should be handled.
func consume_system_back() -> bool:
	var now := Time.get_ticks_msec()
	if now < _back_guard_until_msec:
		return false
	_back_guard_until_msec = now + 450
	return true

# Shuts down ads cleanly before exiting so pending callbacks don't fire on dead nodes.
func quit_app() -> void:
	if AdsManager and AdsManager.has_method("prepare_for_app_exit"):
		AdsManager.prepare_for_app_exit()
	var tree := get_tree()
	if tree:
		tree.call_deferred("quit")

# Switches scenes with a debounce guard to prevent rapid double-transitions.
# Unpauses the tree first so the incoming scene starts in a clean state.
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
