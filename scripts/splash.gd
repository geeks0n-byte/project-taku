extends Control

const MENU_SCENE := "res://scenes/main_menu.tscn"
const FADE_IN := 0.55
const HOLD := 1.75
const FADE_OUT := 0.45

@onready var content: Control = $UILayer/Content
@onready var created_label: Label = $UILayer/Content/CreatedLabel
@onready var author_label: Label = $UILayer/Content/AuthorLabel

var _leaving := false
var _intro_tween: Tween

func _ready() -> void:
	if SpaceBackground and SpaceBackground.has_method("set_foreground_events_enabled"):
		SpaceBackground.set_foreground_events_enabled(false)
	_apply_copy()
	_apply_fonts()
	content.modulate.a = 0.0
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

func _apply_copy() -> void:
	created_label.text = _t("SPLASH_CREATED_BY", "Created by")
	author_label.text = _t("SPLASH_AUTHOR", "Giga \"gix0n\" Sichinava")

func _apply_fonts() -> void:
	created_label.add_theme_font_override("font", HudLayout.screen_header_font())
	author_label.add_theme_font_override("font", HudLayout.screen_header_font())
	# Smaller tagline; author reads as the hero line.
	created_label.add_theme_font_size_override("font_size", 28)
	author_label.add_theme_font_size_override("font_size", 36)
	HudLayout.apply_locale_fonts_to_tree(self)

func _play_intro() -> void:
	_intro_tween = create_tween()
	_intro_tween.tween_property(content, "modulate:a", 1.0, FADE_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_interval(HOLD)
	_intro_tween.tween_callback(_go_to_menu)

func _go_to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	if _intro_tween:
		_intro_tween.kill()
		_intro_tween = null
	var tween := create_tween()
	tween.tween_property(content, "modulate:a", 0.0, FADE_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		get_tree().change_scene_to_file(MENU_SCENE)
	)

func _t(key: String, fallback: String) -> String:
	var msg := tr(key)
	if msg.is_empty() or msg == key:
		return fallback
	return msg
