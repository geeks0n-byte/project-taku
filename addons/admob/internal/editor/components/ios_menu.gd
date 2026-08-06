




extends "res://addons/admob/internal/editor/popup_menu.gd"

const PluginVersion := preload("res://addons/admob/internal/version/plugin_version.gd")
const IOSHandler := preload("res://addons/admob/internal/handlers/ios_handler.gd")

var _handler: IOSHandler


func _init(handler: IOSHandler) -> void:
	super._init()
	name = "iOS"
	_handler = handler

	add_menu_item("Download & Install", func(): _handler.install())
	add_menu_item(
		"GitHub",
		func():
			OS.shell_open(
				(
					"https://github.com/poingstudios/godot-admob-plugin/tree/"
					+ PluginVersion.current
					+ "/platforms/ios"
				)
			)
	)
