class_name ExportSmoke
extends RefCounted
## Headless checks that Android export presets and release excludes stay sane.


const EXAMPLE_PRESET_PATH := "res://export_presets.example.cfg"
const ANDROID_BUILD_GRADLE := "res://android/build/build.gradle"
const PLAY_REVIEW_AAR := "res://addons/play_review/bin/PlayReview-release.aar"
const REQUIRED_EXCLUDES := [
	"tests/",
	"dev/",
	"addons/godot_ai/",
	"tools/",
]


static func audit() -> Array[String]:
	var issues: Array[String] = []
	if not FileAccess.file_exists(EXAMPLE_PRESET_PATH):
		issues.append("missing export_presets.example.cfg")
		return issues
	var text := FileAccess.get_file_as_string(EXAMPLE_PRESET_PATH)
	if text.is_empty():
		issues.append("export_presets.example.cfg is empty")
		return issues
	if not text.contains("platform=\"Android\""):
		issues.append("export_presets.example.cfg has no Android preset")
	if not FileAccess.file_exists(ANDROID_BUILD_GRADLE):
		issues.append("missing android/build/build.gradle")
	if not FileAccess.file_exists(PLAY_REVIEW_AAR):
		issues.append("missing addons/play_review/bin/PlayReview-release.aar")
	var exclude_line := ""
	for line in text.split("\n"):
		if line.begins_with("exclude_filter="):
			exclude_line = line
			break
	if exclude_line.is_empty():
		issues.append("export_presets.example.cfg missing exclude_filter")
	else:
		for token in REQUIRED_EXCLUDES:
			if not exclude_line.contains(token):
				issues.append("exclude_filter missing %s" % token)
	return issues
