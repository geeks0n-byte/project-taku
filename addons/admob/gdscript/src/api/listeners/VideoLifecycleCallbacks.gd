





class_name VideoLifecycleCallbacks
extends RefCounted

var on_video_start: Callable = func(): pass
var on_video_play: Callable = func(): pass
var on_video_pause: Callable = func(): pass
var on_video_end: Callable = func(): pass
var on_video_mute: Callable = func(_is_muted: bool): pass
