# Splash screen shown on app launch; auto-advances or skips on any input.
extends Control

const MENU_SCENE := "res://scenes/main_menu.tscn"
# How long the splash stays visible before auto-transitioning to main menu.
const HOLD := 1.75

# Guard flag to prevent multiple transitions (e.g. tap + timer firing together).
var _leaving := false
var _intro_tween: Tween

func _ready() -> void:
	if AdsManager:
		AdsManager.hide_menu_banner()
	# Disable background shooting-star / comet FX during splash to reduce visual noise.
	if SpaceBackground and SpaceBackground.has_method("set_foreground_events_enabled"):
		SpaceBackground.set_foreground_events_enabled(false)
	# Content starts hidden; the intro tween or skip will trigger the transition.
	var content := get_node_or_null("UILayer/Content") as Control
	if content:
		content.visible = false
	_play_intro()

# Allows the player to skip the splash via tap, click, or any key press.
func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	var tap: bool = event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	var click: bool = (
		event is InputEventMouseButton
		and (event as InputEventMouseButton).pressed
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	)
	var key: bool = event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo
	if tap or click or key:
		_go_to_menu()

# Starts a tween that waits HOLD seconds then auto-transitions to the menu.
func _play_intro() -> void:
	_intro_tween = create_tween()
	_intro_tween.tween_interval(HOLD)
	_intro_tween.tween_callback(_go_to_menu)

# Handles Android/system back button as a skip action.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if GlobalGameManager and GlobalGameManager.consume_system_back():
			_go_to_menu()

# Performs the one-way transition to the main menu scene.
# Kills any running intro tween and signals GlobalGameManager to fade in the menu.
func _go_to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	if _intro_tween:
		_intro_tween.kill()
		_intro_tween = null
	GlobalGameManager.main_menu_should_fade_in = true
	GlobalGameManager.go_to_scene(MENU_SCENE)
