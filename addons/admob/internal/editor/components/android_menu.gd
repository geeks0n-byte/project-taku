




extends "res://addons/admob/internal/editor/popup_menu.gd"

const PluginVersion := preload("res://addons/admob/internal/version/plugin_version.gd")
const AndroidHandler := preload("res://addons/admob/internal/handlers/android_handler.gd")

var _handler: AndroidHandler


func _init(handler: AndroidHandler) -> void:
	super._init()
	name = "Android"
	_handler = handler

	add_menu_item("Download & Install", func() -> void: _handler.install())
	add_menu_item(
		"GitHub",
		func() -> void:
			OS.shell_open(
				(
					"https://github.com/poingstudios/godot-admob-plugin/tree/"
					+ PluginVersion.current
					+ "/platforms/android"
				)
			)
	)
