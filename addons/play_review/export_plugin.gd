@tool
extends EditorPlugin

var _export_plugin: AndroidExportPlugin


func _enter_tree() -> void:
	_export_plugin = AndroidExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


class AndroidExportPlugin extends EditorExportPlugin:
	const _PLUGIN_NAME := &"PlayReview"
	const _AAR := "res://addons/play_review/bin/PlayReview-release.aar"


	func _get_name() -> String:
		return String(_PLUGIN_NAME)


	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid


	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		if not FileAccess.file_exists(_AAR):
			return PackedStringArray()
		return PackedStringArray([_AAR])


	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		if not _supports_platform(_platform):
			return PackedStringArray()
		return PackedStringArray(["com.google.android.play:review:2.0.2"])
