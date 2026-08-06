




extends "res://addons/admob/internal/editor/popup_menu.gd"


func _init() -> void:
	super._init()
	name = "Support"

	add_menu_item("Patreon", func(): OS.shell_open("https://www.patreon.com/poingstudios"))
	add_menu_item("KoFi", func(): OS.shell_open("https://ko-fi.com/poingstudios"))
	add_menu_item(
		"PayPal",
		func(): OS.shell_open("https://www.paypal.com/donate/?hosted_button_id=EBUVPEGF4BUR8")
	)
