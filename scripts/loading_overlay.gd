class_name LoadingOverlay
extends CanvasLayer
## Full-screen dimmer + animated "LOADING..." label used during async work (e.g. level generation).
## Runs at process mode ALWAYS so it ticks even when the tree is paused.
## Hides visible scene children while active to reduce GPU overdraw and visual confusion.

# How long each dot-animation step lasts (cycles through 1, 2, 3 dots).
const DOT_INTERVAL_SEC := 0.45

var _root: Control          # Full-rect control that blocks all pointer events while loading.
var _label: Label           # The "LOADING..." text label, rebuilt each tick.
var _busy: bool = false     # True while a loading operation is in progress.
var _base_text: String = "LOADING"  # Translated message with trailing dots stripped.
var _dot_count: int = 0    # Current dot count (1–3), advanced by _dot_timer.
var _dot_timer: Timer      # Drives the animated dots; restarted on each show_loading call.
var _hidden_nodes: Array = []  # Scene children hidden during loading; restored on hide_loading.

func _ready() -> void:
	# Layer 100 puts this above all regular UI CanvasLayers.
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
	dim.color = Color(0, 0, 0, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	_label = Label.new()
	# Left-align inside a fixed-width box so growing dots don't re-center/jitter.
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.add_theme_font_size_override("font_size", 36)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.text = "LOADING"
	center.add_child(_label)

	_dot_timer = Timer.new()
	_dot_timer.wait_time = DOT_INTERVAL_SEC
	_dot_timer.one_shot = false
	_dot_timer.timeout.connect(_on_dot_tick)
	add_child(_dot_timer)

## Shows the overlay with an animated loading message.
## Hides scene content beneath to reduce visual noise while work is in progress.
func show_loading(message_key: String = "UI_LOADING") -> void:
	_hide_scene_underlay()
	_base_text = _loading_base_text(message_key)
	_dot_count = 0
	_refresh_loading_label()
	if _dot_timer:
		_dot_timer.start()
	visible = true
	_busy = true

## Hides the overlay and restores scene children that were hidden by show_loading.
func hide_loading() -> void:
	if _dot_timer:
		_dot_timer.stop()
	visible = false
	_busy = false
	_restore_scene_underlay()

func is_busy() -> bool:
	return _busy

## Shows the loading overlay, runs `work` on a worker thread, awaits completion, then hides.
## Two process_frame awaits before spawning the task give the main thread time to render
## the overlay before the heavy work starts, preventing a single-frame freeze.
## Returns the Callable's return value, or null if `host` was freed mid-task.
func run_async(host: Node, work: Callable, message_key: String = "UI_LOADING") -> Variant:
	show_loading(message_key)
	if not is_instance_valid(host) or host.get_tree() == null:
		hide_loading()
		return null
	await host.get_tree().process_frame
	if not is_instance_valid(host) or host.get_tree() == null:
		hide_loading()
		return null
	await host.get_tree().process_frame

	# Dictionary acts as a by-reference box so the thread lambda can write its result
	# back and the main thread can read it after wait_for_task_completion.
	var box := {"value": null}
	var task_id := WorkerThreadPool.add_task(func():
		box.value = work.call()
	)
	while not WorkerThreadPool.is_task_completed(task_id):
		if not is_instance_valid(host) or host.get_tree() == null:
			WorkerThreadPool.wait_for_task_completion(task_id)
			hide_loading()
			return null
		await host.get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task_id)

	hide_loading()
	return box.value

## Translates the key and strips any trailing dots so the animated dots animate cleanly.
func _loading_base_text(message_key: String) -> String:
	var raw := String(tr(message_key)).strip_edges()
	while raw.ends_with("."):
		raw = raw.substr(0, raw.length() - 1).strip_edges()
	if raw.is_empty():
		return "LOADING"
	return raw

func _on_dot_tick() -> void:
	_dot_count = (_dot_count % 3) + 1
	_refresh_loading_label()

func _refresh_loading_label() -> void:
	if _label == null:
		return
	var dots := ""
	for _i in range(_dot_count):
		dots += "."
	var display := _base_text + dots
	var font_size := 36
	if HudLayout.needs_pixel_text_raster():
		_lock_loading_label_width()
		HudLayout.apply_raster_pixel_label(_label, display, font_size, Color.WHITE)
	else:
		_label.set_meta("_use_default_font", true)
		HudLayout.apply_locale_font_to_control(_label)
		_label.add_theme_font_size_override("font_size", HudLayout.scaled_font_size(font_size))
		HudLayout.apply_safe_outline(_label, 8)
		_label.text = display
		_lock_loading_label_width()

## Pins the label's minimum width to the widest possible state ("LOADING...") so the
## label never changes width as dots are added, preventing the centering from jittering.
func _lock_loading_label_width() -> void:
	if _label == null:
		return
	var font_size := 36
	var full := _base_text + "..."
	var font: Font = null
	var pad := 8
	if HudLayout.needs_pixel_text_raster():
		font = HudLayout.pixel_font()
		pad = 10
	else:
		font = _label.get_theme_font("font")
		font_size = HudLayout.scaled_font_size(font_size)
	if font == null:
		font = ThemeDB.fallback_font
	var measured := font.get_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	_label.custom_minimum_size = Vector2(ceili(measured.x) + pad, 0)

## Hides all visible CanvasItem children of the current scene (except this overlay)
## to reduce overdraw while the loading screen is active.
func _hide_scene_underlay() -> void:
	_restore_scene_underlay()
	var tree := get_tree()
	if tree == null:
		return
	var scene := tree.current_scene
	if scene == null:
		return
	for child in scene.get_children():
		if child == self:
			continue
		if child is LoadingOverlay:
			continue
		if not (child is CanvasItem):
			continue
		var item := child as CanvasItem
		if not item.visible:
			continue
		_hidden_nodes.append(item)
		item.visible = false

## Restores visibility for every node that was hidden by _hide_scene_underlay.
## Safe to call even if nodes were freed during loading (validity check guards each one).
func _restore_scene_underlay() -> void:
	for node in _hidden_nodes:
		if is_instance_valid(node) and node is CanvasItem:
			(node as CanvasItem).visible = true
	_hidden_nodes.clear()

## Ensure scene nodes are always restored even if the overlay is removed mid-operation.
func _exit_tree() -> void:
	_restore_scene_underlay()
