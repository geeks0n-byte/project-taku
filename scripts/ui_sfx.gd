extends Node

# Candidate paths for the click sound file.
# The first one that exists on disk is used.
const CLICK_CANDIDATES := [
	"res://resources/audio/ui_click.mp3",
	"res://resources/audio/ui_click.wav",
	"res://resources/audio/ui_click.ogg",
	"res://resources/audio/click.mp3",
	"res://resources/audio/click.wav",
]

var _player: AudioStreamPlayer
var _click_stream: AudioStream

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
	# Hook every button that already exists in the tree, then watch for new ones.
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	call_deferred("_hook_existing", get_tree().root)

# Plays the click sound and a light haptic. Called automatically for every button press.
func play_click() -> void:
	play_click_haptic()
	if SaveManager and not SaveManager.sfx_enabled:
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
	button.pressed.connect(play_click)

# Tries each candidate audio file path in order. Falls back to a
# procedurally generated click tone if none are found on disk.
func _load_or_make_click() -> AudioStream:
	for path in CLICK_CANDIDATES:
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream:
				return stream
	return _make_procedural_click()

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
