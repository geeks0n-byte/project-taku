




extends EditorExportPlugin

const ProjectSettingsService := preload(
	"res://addons/admob/internal/services/project_settings_service.gd"
)

const MEDIATION_LIBS: Array[String] = [
	"applovin",
	"bidmachine",
	"chartboost",
	"dtexchange",
	"imobile",
	"inmobi",
	"ironsource",
	"line",
	"maio",
	"meta",
	"mintegral",
	"moloco",
	"mytarget",
	"pangle",
	"pubmatic",
	"unity_ads",
	"vungle",
	"vpon",
	"zucks"
]
static var KNOWN_LIBS: Array[String] = ["ads"] + MEDIATION_LIBS


func _get_setting(setting_name: String, default_value):
	if ProjectSettings.has_setting(setting_name):
		return ProjectSettings.get_setting(setting_name)
	return default_value


func _discover_enabled_libs(root_bin_path: String) -> Array[String]:
	var enabled_libs: Array[String] = ["ads"]

	for lib_name in MEDIATION_LIBS:
		var setting_name := ProjectSettingsService.MEDIATION_PREFIX + lib_name
		var is_enabled := _get_setting(setting_name, false) as bool
		if is_enabled:
			enabled_libs.append(lib_name)

	var dir_access := DirAccess.open(root_bin_path)
	if dir_access:
		dir_access.list_dir_begin()
		var dir_name := dir_access.get_next()
		while dir_name != "":
			if dir_access.current_is_dir() and not dir_name.begins_with("."):
				if not dir_name in KNOWN_LIBS:
					var gd_path := root_bin_path.path_join(dir_name).path_join(
						"poing_godot_admob_" + dir_name + ".gd"
					)
					if FileAccess.file_exists(gd_path):
						var setting_name := (
							ProjectSettingsService.MEDIATION_PREFIX + dir_name
						)
						var is_enabled := _get_setting(setting_name, false) as bool
						if is_enabled:
							enabled_libs.append(dir_name)
			dir_name = dir_access.get_next()

	return enabled_libs
