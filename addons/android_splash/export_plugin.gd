@tool
extends EditorPlugin

const VOID_COLOR := Color(0, 0.0705882, 0.227451, 1)
const VOID_HEX := "#00123a"
const ADDON_COLORS := "res://addons/android_splash/res/values/spaceblox_colors.xml"
const ADDON_SPLASH_BG := "res://addons/android_splash/res/drawable/spaceblox_splash_bg.xml"
const ADDON_SPLASH_GRADLE := "res://addons/android_splash/spaceblox-splash.gradle"
const BUILD_RES_VALUES := "res://android/build/res/values"
const BUILD_RES_DRAWABLE := "res://android/build/res/drawable"
const COLORS_XML := "res://android/build/res/values/spaceblox_colors.xml"
const SPLASH_BG_XML := "res://android/build/res/drawable/spaceblox_splash_bg.xml"
const THEMES_XML := "res://android/build/res/values/themes.xml"

var _export_plugin: _AndroidSplashExportPlugin


func _enter_tree() -> void:
	_export_plugin = _AndroidSplashExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


class _AndroidSplashExportPlugin extends EditorExportPlugin:
	func _get_name() -> String:
		return &"android_splash"


	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid


	func _get_export_options_overrides(platform: EditorExportPlatform) -> Dictionary:
		# Force void splash colors even if export_presets.cfg Color fields fail to parse.
		return {
			"screen/background_color": VOID_COLOR,
			"splash_screen/background_color": VOID_COLOR,
			"gradle_build/custom_theme_attributes": {
				"[splash]android:windowSplashScreenBackground": VOID_HEX,
				"[splash]android:windowSplashScreenIconBackgroundColor": VOID_HEX,
			},
		}


	func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
		_install_splash_resources()
		_install_splash_gradle_hook()


	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		# Called after Godot writes themes.xml but before Gradle assembles the APK.
		_patch_splash_theme()
		return PackedStringArray()


	func _install_splash_resources() -> void:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BUILD_RES_VALUES))
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BUILD_RES_DRAWABLE))
		var err := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(ADDON_COLORS),
			ProjectSettings.globalize_path(COLORS_XML)
		)
		if err != OK:
			push_warning("AndroidSplashFix: copy colors.xml failed (%s)" % err)
			return
		err = DirAccess.copy_absolute(
			ProjectSettings.globalize_path(ADDON_SPLASH_BG),
			ProjectSettings.globalize_path(SPLASH_BG_XML)
		)
		if err != OK:
			push_warning("AndroidSplashFix: copy splash_bg.xml failed (%s)" % err)
			return


	func _install_splash_gradle_hook() -> void:
		var gradle_path := "res://android/build/build.gradle"
		if not FileAccess.file_exists(gradle_path):
			return
		var gradle_dir := gradle_path.get_base_dir()
		var dest := gradle_dir.path_join("spaceblox-splash.gradle")
		var err := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(ADDON_SPLASH_GRADLE),
			ProjectSettings.globalize_path(dest)
		)
		if err != OK:
			push_warning("AndroidSplashFix: copy spaceblox-splash.gradle failed (%s)" % err)
			return
		var content := FileAccess.get_file_as_string(gradle_path)
		if content.is_empty():
			return
		content = content.replace("\r\n", "\n").replace("\r", "\n")
		if not content.contains("spaceblox-splash.gradle"):
			content += "\napply from: 'spaceblox-splash.gradle'\n"
			var file := FileAccess.open(gradle_path, FileAccess.WRITE)
			if file == null:
				push_warning("AndroidSplashFix: could not patch build.gradle")
				return
			file.store_string(content)
			file.close()


	func _patch_splash_theme() -> void:
		var path := ProjectSettings.globalize_path(THEMES_XML)
		if not FileAccess.file_exists(path):
			push_warning("AndroidSplashFix: themes.xml missing before patch")
			return
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			return
		text = text.replace(
			'<item name="android:windowSplashScreenBackground">@mipmap/icon_background</item>',
			'<item name="android:windowSplashScreenBackground">%s</item>' % VOID_HEX
		)
		text = text.replace(
			'<item name="android:windowSplashScreenBackground">#000000</item>',
			'<item name="android:windowSplashScreenBackground">%s</item>' % VOID_HEX
		)
		text = _upsert_theme_item(text, "GodotAppSplashTheme", "android:windowSplashScreenBackground", VOID_HEX)
		text = _upsert_theme_item(text, "GodotAppSplashTheme", "android:windowSplashScreenIconBackgroundColor", VOID_HEX)
		text = _upsert_theme_item(text, "GodotAppSplashTheme", "android:windowIsTranslucent", "false")
		text = _upsert_theme_item(text, "GodotAppMainTheme", "android:windowBackground", VOID_HEX)
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_warning("AndroidSplashFix: could not write themes.xml")
			return
		file.store_string(text)
		file.close()
		if text.contains("@mipmap/icon_background"):
			push_error("AndroidSplashFix: themes.xml still references @mipmap/icon_background")


	func _upsert_theme_item(text: String, style_name: String, key: String, value: String) -> String:
		var item_line := '\t\t<item name="%s">%s</item>' % [key, value]
		var block_start := text.find('<style name="%s"' % style_name)
		if block_start < 0:
			return text
		var block_end := text.find("</style>", block_start)
		if block_end < 0:
			return text
		var block := text.substr(block_start, block_end - block_start)
		var regex := RegEx.new()
		regex.compile('\\t\\t<item name="%s">[^<]*</item>' % key)
		if regex.search(block):
			block = regex.sub(block, item_line, true)
		else:
			block += "\n" + item_line
		return text.substr(0, block_start) + block + text.substr(block_end)
