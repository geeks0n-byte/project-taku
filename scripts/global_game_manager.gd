extends Node
## Autoload for scene changes, system-back debounce, and focus/keyboard.

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

## Always-process so back-button and focus handling still run while the tree is paused.
func _ready() -> void:
	# Always process so back-button and focus events work even when the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

## On focus in/out: hide the IME keyboard, unpin banners, and keep the tree unpaused.
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


## Clears SceneTree.paused so boot tweens and incoming scenes are not stuck.
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
