extends Control

const MENU_SCENE := "res://scenes/main_menu.tscn"
const HOLD := 1.75

var _leaving := false
var _intro_tween: Tween

func _ready() -> void:
	if AdsManager:
		AdsManager.hide_menu_banner()
	if SpaceBackground and SpaceBackground.has_method("set_foreground_events_enabled"):
		SpaceBackground.set_foreground_events_enabled(false)
	# Splash is space background only — hide any credit / title chrome.
	var content := get_node_or_null("UILayer/Content") as Control
	if content:
		content.visible = false
	_play_intro()

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

func _play_intro() -> void:
	_intro_tween = create_tween()
	_intro_tween.tween_interval(HOLD)
	_intro_tween.tween_callback(_go_to_menu)

func _go_to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	if _intro_tween:
		_intro_tween.kill()
		_intro_tween = null
	GlobalGameManager.main_menu_should_fade_in = true
	get_tree().change_scene_to_file(MENU_SCENE)
