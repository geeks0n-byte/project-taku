





class_name AdVideoController
extends RefCounted

var _uid: int
var _plugin: Object
var video_lifecycle_callbacks: VideoLifecycleCallbacks

func _init(uid: int, plugin: Object) -> void:
	_uid = uid
	_plugin = plugin


func is_muted() -> bool:
	if _plugin:
		return _plugin.is_video_muted(_uid)
	return true


func is_custom_controls_enabled() -> bool:
	if _plugin:
		return _plugin.is_video_custom_controls_enabled(_uid)
	return false
