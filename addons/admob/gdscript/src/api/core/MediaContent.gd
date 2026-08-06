





class_name MediaContent
extends RefCounted

var _uid: int
var _plugin: Object
var _video_controller: AdVideoController

func _init(uid: int, plugin: Object) -> void:
	_uid = uid
	_plugin = plugin
	_video_controller = AdVideoController.new(uid, plugin)


func has_video_content() -> bool:
	if _plugin:
		return _plugin.has_video_content(_uid)
	return false


func get_video_controller() -> AdVideoController:
	return _video_controller


func get_duration() -> float:
	if _plugin:
		return float(_plugin.get_video_duration(_uid))
	return 0.0


func get_aspect_ratio() -> float:
	if _plugin:
		return float(_plugin.get_video_aspect_ratio(_uid))
	return 0.0
