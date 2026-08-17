extends Node


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
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "ClickPlayer"
	_player.bus = "Master"
	_player.volume_db = -6.0
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	_click_stream = _load_or_make_click()
	_player.stream = _click_stream
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	call_deferred("_hook_existing", get_tree().root)

func play_click() -> void:
	if SaveManager and not SaveManager.sfx_enabled:
		return
	if _player == null or _click_stream == null:
		return
	_player.stream = _click_stream
	_player.play()

## Short bump for a blocked purple move. Android only; needs VIBRATE in the export.
func play_blocked_haptic() -> void:
	Input.vibrate_handheld(80, 0.8)

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_hook_button(node as BaseButton)

func _hook_existing(node: Node) -> void:
	if node is BaseButton:
		_hook_button(node as BaseButton)
	for child in node.get_children():
		_hook_existing(child)

func _hook_button(button: BaseButton) -> void:
	if button == null or button.has_meta("_ui_sfx_hooked"):
		return
	button.set_meta("_ui_sfx_hooked", true)
	button.pressed.connect(play_click)

func _load_or_make_click() -> AudioStream:
	for path in CLICK_CANDIDATES:
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream:
				return stream
	return _make_procedural_click()

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
