




extends "res://addons/admob/internal/editor/popup_menu.gd"


func _init() -> void:
	super._init()
	name = "Documents"

	add_menu_item(
		"Official", func(): OS.shell_open("https://poingstudios.github.io/godot-admob-plugin")
	)
	add_menu_item("Google", func(): OS.shell_open("https://developers.google.com/admob"))
