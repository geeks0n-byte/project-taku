extends Node

## Global looping BGM. Persists across scene changes via autoload.

const BGM_PATH := "res://resources/audio/bgm.mp3"

var _player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "Player"
	_player.bus = "Master"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	_load_stream()
	# SaveManager loads first in autoload order; apply after both are ready.
	call_deferred("apply_enabled")

func _load_stream() -> void:
	if not ResourceLoader.exists(BGM_PATH):
		push_warning("BGM missing: %s" % BGM_PATH)
		return
	var stream: AudioStream = load(BGM_PATH) as AudioStream
	if stream == null:
		push_warning("Failed to load BGM: %s" % BGM_PATH)
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif "loop" in stream:
		stream.set("loop", true)
	_player.stream = stream

func apply_enabled() -> void:
	if _player == null or _player.stream == null:
		return
	if SaveManager.bgm_enabled:
		if not _player.playing:
			_player.play()
	else:
		if _player.playing:
			_player.stop()
