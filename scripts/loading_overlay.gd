class_name LoadingOverlay
extends CanvasLayer

## Full-screen indeterminate loading UI for long generation work.

var _root: Control
var _bar: ProgressBar
var _label: Label
var _busy: bool = false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 28)
	center.add_child(box)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", HudLayout.PIXEL_FONT)
	_label.add_theme_font_size_override("font_size", 36)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 8)
	_label.text = "UI_LOADING"
	box.add_child(_label)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(520, 36)
	_bar.show_percentage = false
	_bar.indeterminate = true
	_bar.max_value = 1.0
	_bar.value = 0.0
	box.add_child(_bar)

func show_loading(message_key: String = "UI_LOADING") -> void:
	if _label:
		_label.text = tr(message_key)
		HudLayout.apply_locale_font_to_control(_label)
		_label.add_theme_font_size_override("font_size", HudLayout.scaled_font_size(36))
	if _bar:
		_bar.indeterminate = true
	visible = true
	_busy = true

func hide_loading() -> void:
	visible = false
	_busy = false

func is_busy() -> bool:
	return _busy

## Shows the overlay, runs work on a worker thread, then hides.
## `work` must be thread-safe (no SceneTree / node access).
func run_async(host: Node, work: Callable, message_key: String = "UI_LOADING") -> Variant:
	show_loading(message_key)
	# Let the overlay paint before heavy work starts.
	await host.get_tree().process_frame
	await host.get_tree().process_frame

	var box := {"value": null}
	var task_id := WorkerThreadPool.add_task(func():
		box.value = work.call()
	)
	while not WorkerThreadPool.is_task_completed(task_id):
		await host.get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task_id)

	hide_loading()
	return box.value
