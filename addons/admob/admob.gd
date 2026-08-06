




@tool
extends EditorPlugin

const MENU_NAME := "AdMob Manager"
const AdMobEditorMenu := preload("res://addons/admob/internal/editor/editor_menu.gd")
const CSharpService := preload("res://addons/admob/internal/services/csharp_service.gd")
const BinaryInstaller := preload("res://addons/admob/internal/services/network/binary_installer.gd")
const ProjectSettingsService := preload(
	"res://addons/admob/internal/services/project_settings_service.gd"
)

var _main_exporter := preload("res://addons/admob/internal/exporters/main_export_plugin.gd").new()
var _android_exporter := preload("res://addons/admob/internal/exporters/android/export_plugin.gd").new()
var _ios_exporter := preload("res://addons/admob/internal/exporters/ios/export_plugin.gd").new()


func _enter_tree() -> void:
	CSharpService.manage_visibility(self)

	BinaryInstaller.install_missing_binaries_sync()

	ProjectSettingsService.register_settings()

	add_export_plugin(_main_exporter)
	add_export_plugin(_android_exporter)
	add_export_plugin(_ios_exporter)
	add_tool_submenu_item(MENU_NAME, AdMobEditorMenu.new(self))


func _exit_tree() -> void:
	remove_export_plugin(_main_exporter)
	remove_export_plugin(_android_exporter)
	remove_export_plugin(_ios_exporter)
	remove_tool_menu_item(MENU_NAME)
