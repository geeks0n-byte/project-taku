




extends "res://addons/admob/internal/editor/popup_menu.gd"


const DownloadService := preload("res://addons/admob/internal/services/network/download_service.gd")

const AndroidHandler := preload("res://addons/admob/internal/handlers/android_handler.gd")
const IOSHandler := preload("res://addons/admob/internal/handlers/ios_handler.gd")

const AndroidMenu := preload("res://addons/admob/internal/editor/components/android_menu.gd")
const IOSMenu := preload("res://addons/admob/internal/editor/components/ios_menu.gd")
const DocumentsMenu := preload("res://addons/admob/internal/editor/components/documents_menu.gd")
const HelpMenu := preload("res://addons/admob/internal/editor/components/help_menu.gd")
const SupportMenu := preload("res://addons/admob/internal/editor/components/support_menu.gd")
const DialogService := preload("res://addons/admob/internal/services/ui/dialog_service.gd")

const PluginVersion := preload("res://addons/admob/internal/version/plugin_version.gd")

const DEFAULT_DOWNLOAD_PATH := "res://addons/admob/downloads/"

var _dialog_service: DialogService
var _android_handler: AndroidHandler
var _ios_handler: IOSHandler


func _init(host: Node) -> void:
	super._init()

	_dialog_service = DialogService.new()

	_android_handler = AndroidHandler.new(DownloadService.new(host), _dialog_service)
	_ios_handler = IOSHandler.new(DownloadService.new(host), _dialog_service)

	if DisplayServer.get_name() != "headless":
		_android_handler.check_dependencies()
		_ios_handler.check_dependencies()

	_setup_menu()


func _setup_menu() -> void:
	_add_submenu(AndroidMenu.new(_android_handler))
	_add_submenu(IOSMenu.new(_ios_handler))
	_add_submenu(DocumentsMenu.new())
	_add_submenu(HelpMenu.new())
	_add_submenu(SupportMenu.new())

	add_menu_item(
		"Downloads Folder",
		func(): OS.shell_open(str("file://", ProjectSettings.globalize_path(DEFAULT_DOWNLOAD_PATH)))
	)
	add_menu_item(
		"GitHub",
		func():
			OS.shell_open(
				"https://github.com/poingstudios/godot-admob-plugin/tree/" + PluginVersion.current
			)
	)


func _add_submenu(menu: PopupMenu) -> void:
	add_child(menu)
	add_submenu_item(menu.name, menu.name)
