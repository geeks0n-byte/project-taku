class_name LoadingOverlay
extends CanvasLayer
## Full-screen dimmer + animated "LOADING..." label used during async work (e.g. level generation).
## Runs at process mode ALWAYS so it ticks even when the tree is paused.
## Hides visible scene children while active to reduce GPU overdraw and visual confusion.

# How long each dot-animation step lasts (cycles 1, 2, 3, then 0 dots).
const DOT_INTERVAL_SEC := 0.45

# The "LOADING..." text label; text is rebuilt each tick, node is authored.
@onready var _label: Label = $Root/CenterContainer/Label
# Drives the animated dots; wait_time authored, signal wired in _ready.
@onready var _dot_timer: Timer = $DotTimer
var _busy: bool = false     # True while a loading operation is in progress.
var _base_text: String = "LOADING"  # Translated message with trailing dots stripped.
var _dot_count: int = 1    # Current visible dots (1, 2, 3, then 0), advanced by _dot_timer.
var _hidden_nodes: Array = []  # Scene children hidden during loading; restored on hide_loading.

## Pins this overlay above other CanvasLayers and wires the authored dot timer.
func _ready() -> void:
	# Layer 100 puts this above all regular UI CanvasLayers.
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	HudLayout.register_modal_blocker(self)
	var root := get_node_or_null("Root") as Control
	HudLayout.register_modal_blocker(root)
	if _dot_timer and not _dot_timer.timeout.is_connected(_on_dot_tick):
		_dot_timer.timeout.connect(_on_dot_tick)

## Shows the overlay with an animated loading message.
## Hides scene content beneath to reduce visual noise while work is in progress.
func show_loading(message_key: String = "UI_LOADING") -> void:
	_hide_scene_underlay()
	_base_text = _loading_base_text(message_key)
	_dot_count = 1
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

## True while show_loading / run_async is displaying the overlay.
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

## Advances 1-2-3-blank dots and refreshes the label. Do not change the cycle.
func _on_dot_tick() -> void:
	_dot_count = (_dot_count + 1) % 4
	_refresh_loading_label()

## Rebuilds the label as base text plus the current 1-2-3-blank dots.
func _refresh_loading_label() -> void:
	if _label == null:
		return
	var dots := ""
	for _i in range(_dot_count):
		dots += "."
	var display := _base_text + dots
	var font_size := 36
	# Latin "LOADING..." (and digits/symbols) stay Press Start even in ka/uk.
	_lock_loading_label_width()
	HudLayout.apply_raster_pixel_label(_label, display, font_size, Color.WHITE)

## Pins the label's minimum width to the widest possible state ("LOADING...") so the
## label never changes width as dots are added, preventing the centering from jittering.
func _lock_loading_label_width() -> void:
	if _label == null:
		return
	var font_size := 36
	var full := _base_text + "..."
	var font: Font = null
	var pad := 8
	if HudFonts.should_use_press_start_font(full):
		font = HudFonts.pixel_font()
		pad = 10
	else:
		font = HudFonts.default_font()
		font_size = HudLayout.scaled_font_size(font_size)
	if font == null:
		font = HudFonts.default_font()
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
