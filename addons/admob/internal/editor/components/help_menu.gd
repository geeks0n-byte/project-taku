




extends "res://addons/admob/internal/editor/popup_menu.gd"


func _init() -> void:
	super._init()
	name = "Help"

	add_menu_item("Discord", func(): OS.shell_open("https://discord.com/invite/YEPvYjSSMk"))
	add_menu_item(
		"SDK Developers", func(): OS.shell_open("https://groups.google.com/g/google-admob-ads-sdk/")
	)
