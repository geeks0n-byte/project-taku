extends Node
## Autoload for UI clicks, haptics, and synthesized title-screen FX.

# Prefer the authored click; synthesize only if the asset is missing.
const CLICK_STREAM_PATH := "res://resources/audio/ui_click.wav"

var _player: AudioStreamPlayer
var _click_stream: AudioStream
var _fx_voices: Array[AudioStreamPlayer] = []
var _fx_voice_i: int = 0
var _letter_stream: AudioStreamWAV
var _tile_pop_stream: AudioStreamWAV
var _slide_stream: AudioStreamWAV

## Always-process click player plus pooled FX voices so SFX still play while paused.
func _ready() -> void:
	# PROCESS_MODE_ALWAYS so clicks play even while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "ClickPlayer"
	_player.bus = "Master"
	_player.volume_db = -6.0
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	_click_stream = _load_or_make_click()
	_player.stream = _click_stream
	for i in 4:
		var voice := AudioStreamPlayer.new()
		voice.name = "FxVoice%d" % i
		voice.bus = "Master"
		voice.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(voice)
		_fx_voices.append(voice)
	_letter_stream = _make_title_letter()
	_tile_pop_stream = _make_title_tile_pop()
	_slide_stream = _make_title_slide()
	# Hook every button that already exists in the tree, then watch for new ones.
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	call_deferred("_hook_existing", get_tree().root)

## True unless the player turned SFX off in options.
func _sfx_on() -> bool:
	return SaveManager == null or SaveManager.sfx_enabled

## Plays a short stream on the next pooled voice (round-robin).
func _play_fx(stream: AudioStream, volume_db: float, pitch: float = 1.0) -> void:
	if not _sfx_on() or stream == null or _fx_voices.is_empty():
		return
	var voice := _fx_voices[_fx_voice_i]
	_fx_voice_i = (_fx_voice_i + 1) % _fx_voices.size()
	voice.stop()
	voice.stream = stream
	voice.volume_db = volume_db
	voice.pitch_scale = pitch
	voice.play()

## Title intro glyph tick; pitch and haptic climb with the letter index.
func play_title_letter(index: int) -> void:
	# Climb a little with each glyph so SPACEBLOX feels like a scale, not a metronome.
	var pitch := 0.92 + float(index) * 0.045
	_vibrate(8 + mini(index, 6), 0.12 + float(index) * 0.015)
	_play_fx(_letter_stream, -10.0, pitch)

## Title tile pop; pitch and haptic climb with the tile index.
func play_title_tile_pop(index: int) -> void:
	var pitch := 0.94 + float(index) * 0.08
	_vibrate(28 + index * 4, 0.32 + float(index) * 0.06)
	_play_fx(_tile_pop_stream, -7.0, pitch)

## Title slide whoosh plus a longer haptic.
func play_title_slide() -> void:
	_vibrate(120, 0.38)
	_play_fx(_slide_stream, -12.0, 1.0)

# Plays the click sound and a light haptic. Called automatically for every button press.
func play_click() -> void:
	play_click_haptic()
	if not _sfx_on():
		return
	if _player == null or _click_stream == null:
		return
	_player.stream = _click_stream
	_player.play()

# Very short, light haptic for normal button presses.
func play_click_haptic() -> void:
	_vibrate(10, 0.15)

# Medium buzz when a tile is removed via long-press hold-to-clear.
func play_clear_haptic() -> void:
	_vibrate(50, 0.5)

# Hold-to-clear feedback: clear haptic plus the usual click sound.
func play_clear() -> void:
	play_clear_haptic()
	if not _sfx_on():
		return
	if _player == null or _click_stream == null:
		return
	_player.stream = _click_stream
	_player.play()

# Stronger bump for a blocked move (e.g. shifter hitting a wall).
# Android only — requires VIBRATE permission in the export preset.
func play_blocked_haptic() -> void:
	_vibrate(80, 0.8)

# Fires the vibration if haptic feedback is enabled in settings.
func _vibrate(duration_ms: int, amplitude: float) -> void:
	if SaveManager and not SaveManager.haptic_enabled:
		return
	Input.vibrate_handheld(duration_ms, amplitude)

# Hooks new buttons as they enter the scene tree.
func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_hook_button(node as BaseButton)

# Recursively hooks all existing buttons under a given node.
func _hook_existing(node: Node) -> void:
	if node is BaseButton:
		_hook_button(node as BaseButton)
	for child in node.get_children():
		_hook_existing(child)

# Connects play_click to a button's pressed signal, guarded by a meta flag
# so the same button is never connected more than once.
func _hook_button(button: BaseButton) -> void:
	if button == null or button.has_meta("_ui_sfx_hooked"):
		return
	# Game/editor cells drive their own tile haptics (press/hold paths differ).
	var script: Script = button.get_script() as Script
	if script != null and String(script.resource_path).ends_with("cell.gd"):
		return
	button.set_meta("_ui_sfx_hooked", true)
	button.pressed.connect(_on_hooked_pressed.bind(button))

# Hold buttons play click on button_down; skip the automatic pressed click once
# so a single press does not double-fire SFX/haptic.
func suppress_next_pressed_click(button: BaseButton) -> void:
	if button:
		button.set_meta("_ui_sfx_suppress_once", true)

# Clears a pending suppress (e.g. pressed was cancelled because the button disabled).
func clear_pressed_click_suppress(button: BaseButton) -> void:
	if button and button.has_meta("_ui_sfx_suppress_once"):
		button.set_meta("_ui_sfx_suppress_once", false)

## Auto-click for hooked buttons, unless a one-shot suppress meta is set.
func _on_hooked_pressed(button: BaseButton) -> void:
	if button != null and bool(button.get_meta("_ui_sfx_suppress_once", false)):
		button.set_meta("_ui_sfx_suppress_once", false)
		return
	play_click()

# Loads the authored click WAV. Falls back to a procedural tone if missing.
func _load_or_make_click() -> AudioStream:
	# ResourceLoader only sees imported assets; FileAccess works before first import.
	if FileAccess.file_exists(CLICK_STREAM_PATH):
		if ResourceLoader.exists(CLICK_STREAM_PATH):
			var imported := load(CLICK_STREAM_PATH) as AudioStream
			if imported:
				return imported
		var from_file := _load_wav_pcm16_mono(CLICK_STREAM_PATH)
		if from_file:
			return from_file
	push_warning("UiSfx: missing %s — using procedural click" % CLICK_STREAM_PATH)
	return _make_procedural_click()

## Loads a known PCM16 mono WAV (44-byte header) without waiting on .import.
func _load_wav_pcm16_mono(path: String) -> AudioStreamWAV:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() <= 44:
		return null
	# Standard RIFF WAV header is 44 bytes for PCM.
	var pcm := bytes.slice(44)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	stream.data = pcm
	return stream

## Wraps mono PCM16 bytes as an AudioStreamWAV.
func _pcm16_stream(data: PackedByteArray, sample_rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream

## Procedural short blip used when letter glyphs appear.
func _make_title_letter() -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(sample_rate * 0.055)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / float(sample_rate)
		var env := exp(-t * 62.0)
		var sample := (sin(t * TAU * 1040.0) * 0.72 + sin(t * TAU * 2080.0) * 0.22) * env * 0.32
		data.encode_s16(i * 2, clampi(int(sample * 32767.0), -32768, 32767))
	return _pcm16_stream(data, sample_rate)

## Procedural thump+tick used when title tiles pop in.
func _make_title_tile_pop() -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(sample_rate * 0.14)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / float(sample_rate)
		var thump := sin(t * TAU * 210.0) * exp(-t * 22.0) * 0.55
		var tick := sin(t * TAU * 1320.0) * exp(-t * 70.0) * 0.28
		var sample := (thump + tick) * 0.42
		data.encode_s16(i * 2, clampi(int(sample * 32767.0), -32768, 32767))
	return _pcm16_stream(data, sample_rate)

## Procedural noise sweep used for the title slide.
func _make_title_slide() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration := 0.52
	var sample_count := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase := 0.0
	var noise := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 24
	for i in sample_count:
		var t := float(i) / float(sample_rate)
		var u := t / duration
		var env := sin(PI * clampf(u, 0.0, 1.0))
		noise = noise * 0.82 + rng.randf_range(-1.0, 1.0) * 0.18
		var hz := lerpf(180.0, 520.0, u)
		phase += TAU * hz / float(sample_rate)
		var sample := (sin(phase) * 0.22 + noise * 0.55) * env * 0.28
		data.encode_s16(i * 2, clampi(int(sample * 32767.0), -32768, 32767))
	return _pcm16_stream(data, sample_rate)

# Generates a short 980 Hz sine-wave click with exponential decay.
# Used as a fallback when no audio file is present.
func _make_procedural_click() -> AudioStreamWAV:
	var sample_rate := 22050
	var duration_sec := 0.045
	var sample_count := int(sample_rate * duration_sec)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / float(sample_rate)
		var env := exp(-t * 55.0)
		var sample := sin(t * TAU * 980.0) * env * 0.35
		var s16 := clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, s16)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream
