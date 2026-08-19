extends Node

# Autoload-style singleton that owns the single background music AudioStreamPlayer.
# Runs with PROCESS_MODE_ALWAYS so pausing the scene tree does not cut the music.

const BGM_PATH := "res://resources/audio/bgm.mp3"

var _player: AudioStreamPlayer

func _ready() -> void:
	# Keep processing even when the game is paused (e.g. on pause-menu screens).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "Player"
	_player.bus = "Master"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	_load_stream()
	# Defer so SaveManager is fully initialized before we check bgm_enabled.
	call_deferred("apply_enabled")

# Loads the BGM file and enables looping regardless of the stream type.
# The loop flag must be set on the stream resource itself before assigning it to the player.
func _load_stream() -> void:
	if not ResourceLoader.exists(BGM_PATH):
		push_warning("BGM missing: %s" % BGM_PATH)
		return
	var stream: AudioStream = load(BGM_PATH) as AudioStream
	if stream == null:
		push_warning("Failed to load BGM: %s" % BGM_PATH)
		return
	# Each AudioStream subclass stores the loop flag differently, so handle all known types.
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif "loop" in stream:
		# Fallback for future stream types that expose a generic "loop" property.
		stream.set("loop", true)
	_player.stream = stream

# Starts or stops playback based on the player's saved BGM preference.
# Called on startup and whenever the setting changes at runtime.
func apply_enabled() -> void:
	if _player == null or _player.stream == null:
		return
	if SaveManager.bgm_enabled:
		if not _player.playing:
			_player.play()
	else:
		if _player.playing:
			_player.stop()
