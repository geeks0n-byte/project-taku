extends CanvasLayer
## Right-side achievement unlock banner. Slides in from off-screen; never blocks input.

const SHOW_SEC := 3.2
const FADE_SEC := 0.28
const SLIDE_PX := 36.0
const CHIP_HEIGHT := 104.0
const CHIP_WIDTH := 420.0
const BELOW_HUD_GAP := 16.0
const NAME_FONT_BASE := 24
const NAME_FONT_MIN := 16

@onready var _root: Control = $Root
@onready var _panel: Panel = $Root/Panel
@onready var _icon_wrap: Control = $Root/Panel/HBox/IconWrap
@onready var _icon: TextureRect = $Root/Panel/HBox/IconWrap/Icon
@onready var _subtitle: Label = $Root/Panel/HBox/TextColumn/SubtitleLabel
@onready var _name: Label = $Root/Panel/HBox/TextColumn/NameLabel

var _queue: Array[String] = []
var _busy: bool = false
var _showing_id: String = ""
var _play_gen: int = 0
var _tween: Tween
var _hold_timer: Timer
var _layout_left: float = 0.0
var _layout_right: float = 0.0
var _layout_top: float = 0.0
var _layout_bottom: float = 0.0
var _chip_width: float = CHIP_WIDTH


## Pins above gameplay/menus and starts hidden. Never captures mouse.
func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_ignore_mouse(_root)
	_ignore_mouse(_panel)
	_ignore_mouse(_icon_wrap)
	_ignore_mouse(_icon)
	_ignore_mouse(_subtitle)
	_ignore_mouse(_name)
	_hold_timer = Timer.new()
	_hold_timer.one_shot = true
	_hold_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_hold_timer.timeout.connect(_on_hold_timer_timeout)
	add_child(_hold_timer)
	if _panel:
		_panel.clip_contents = true
		_panel.add_theme_stylebox_override("panel", _make_chip_style())
	_style_subtitle()
	_layout_panel()
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)


## Re-layout when the viewport changes; vertical position always updates, even mid-toast.
func _on_viewport_resized() -> void:
	_layout_panel()


## Queues a unique achievement id. Skips empty, already-queued, or currently showing ids.
func enqueue(id: String, delay_sec: float = 0.0) -> void:
	var clean := str(id).strip_edges()
	if clean.is_empty():
		return
	if delay_sec > 0.0:
		var timer := get_tree().create_timer(delay_sec, true, false, true)
		timer.timeout.connect(func() -> void: enqueue(clean), CONNECT_ONE_SHOT)
		return
	if _is_queued_or_showing(clean):
		return
	_queue.append(clean)
	if not is_node_ready():
		if not ready.is_connected(_show_next):
			ready.connect(_show_next, CONNECT_ONE_SHOT)
		return
	if not _busy:
		_show_next()


## Showing id plus remaining queue (for headless uniqueness tests).
func snapshot_ids() -> Array:
	var out: Array = []
	if not _showing_id.is_empty():
		out.append(_showing_id)
	for queued in _queue:
		out.append(str(queued))
	return out


## True when this id is on screen or already waiting in the queue.
func _is_queued_or_showing(id: String) -> bool:
	if id == _showing_id:
		return true
	return _queue.has(id)


## Gold header line shared by every toast.
func _style_subtitle() -> void:
	if _subtitle == null:
		return
	HudLayout._bind_header_translation_key(_subtitle, "ACH_UNLOCKED")
	_subtitle.add_theme_color_override("font_color", GameConstants.SCREEN_HEADER_COLOR)
	HudLayout.apply_popup_label(_subtitle, 20)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_OFF
	_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_subtitle.clip_contents = true


## Solid chip with gold border; content stays inside via clip_contents on the panel.
func _make_chip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.09, 0.94)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(0)
	style.border_color = Color(1.0, 0.84, 0.0, 0.55)
	style.set_border_width_all(2)
	return style


## Right-aligned side banner; always sits just under the HUD counter row.
func _layout_panel() -> void:
	if _panel == null:
		return
	var vp_w := get_viewport().get_visible_rect().size.x
	_chip_width = minf(
		CHIP_WIDTH,
		maxf(280.0, vp_w - SafeInsets.left() - SafeInsets.right() - GameConstants.HUD_SIDE_MARGIN * 2.0)
	)
	var side := SafeInsets.right() + GameConstants.HUD_SIDE_MARGIN
	_layout_right = vp_w - side
	_layout_left = _layout_right - _chip_width
	_panel.anchor_left = 0.0
	_panel.anchor_right = 0.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_layout_top = _toast_top()
	_layout_bottom = _layout_top + CHIP_HEIGHT
	if not _busy:
		_apply_layout_offsets(_layout_left, _layout_right)
	elif _panel:
		_panel.offset_top = _layout_top
		_panel.offset_bottom = _layout_bottom


## Shared Y for gameplay and every menu/overlay screen.
func _toast_top() -> float:
	var edge := float(GameConstants.HUD_TOP_BAR_EDGE_MARGIN)
	var shift := SafeInsets.padded_top(edge) - edge
	return (
		GameConstants.HUD_COUNTER_ROW_TOP
		+ GameConstants.HUD_COUNTER_ROW_HEIGHT
		+ shift
		+ BELOW_HUD_GAP
	)


## Positive shift that moves the chip fully off the right edge.
func _offscreen_right_shift() -> float:
	var vp_w := get_viewport().get_visible_rect().size.x
	return vp_w - _layout_left + SLIDE_PX


func _apply_layout_offsets(left: float, right: float) -> void:
	if _panel == null:
		return
	_panel.offset_left = left
	_panel.offset_right = right
	_panel.offset_top = _layout_top
	_panel.offset_bottom = _layout_bottom


## Pops the next unique id, binds copy, and plays a right slide + fade.
func _show_next() -> void:
	_stop_animations()
	if _queue.is_empty():
		_busy = false
		_showing_id = ""
		visible = false
		return
	_busy = true
	var id := str(_queue[0])
	_queue.remove_at(0)
	_showing_id = id
	_play_gen += 1
	var gen := _play_gen
	_apply_chip(id)
	_layout_panel()
	_fit_name_label(id)
	if _icon_wrap:
		_icon_wrap.scale = Vector2.ONE
		_icon_wrap.pivot_offset = Vector2(28.0, 28.0)
	visible = true
	var hide_shift := _offscreen_right_shift()
	if _panel:
		_panel.modulate.a = 0.0
		_apply_layout_offsets(_layout_left + hide_shift, _layout_right + hide_shift)
	_tween = _make_tween()
	_tween.set_parallel(true)
	if _panel:
		_tween.tween_property(_panel, "modulate:a", 1.0, FADE_SEC)
		_tween.tween_property(_panel, "offset_left", _layout_left, FADE_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_panel, "offset_right", _layout_right, FADE_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.set_parallel(false)
	_tween.tween_callback(func() -> void:
		if gen != _play_gen or not _busy:
			return
		_play_unlock_fx()
		_pop_icon(gen)
		_begin_hold()
	)


## Keeps the toast fully visible for SHOW_SEC using a real-time timer.
func _begin_hold() -> void:
	if not _busy:
		return
	_hold_timer.wait_time = SHOW_SEC
	_hold_timer.start()


func _on_hold_timer_timeout() -> void:
	_dismiss_current()


## Slides the current toast off-screen to the right, then presents the next queued id.
func _dismiss_current() -> void:
	if not _busy:
		return
	_hold_timer.stop()
	var gen := _play_gen
	var hide_shift := _offscreen_right_shift()
	_kill_tween()
	_tween = _make_tween()
	_tween.set_parallel(true)
	if _panel:
		_tween.tween_property(_panel, "modulate:a", 0.0, FADE_SEC)
		_tween.tween_property(_panel, "offset_left", _layout_left + hide_shift, FADE_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_tween.tween_property(_panel, "offset_right", _layout_right + hide_shift, FADE_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.set_parallel(false)
	_tween.tween_callback(func() -> void:
		if gen != _play_gen:
			return
		_show_next()
	)


## Tweens that keep running during victory overlays, pause, and scene-tree idle quirks.
func _make_tween() -> Tween:
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tween


func _stop_animations() -> void:
	_kill_tween()
	if _hold_timer:
		_hold_timer.stop()


## Brief icon scale pop after the chip slides in.
func _pop_icon(gen: int) -> void:
	if _icon_wrap == null:
		return
	_icon_wrap.scale = Vector2(0.72, 0.72)
	_icon_wrap.pivot_offset = Vector2(28.0, 28.0)
	var pop := _make_tween()
	pop.tween_property(_icon_wrap, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_callback(func() -> void:
		if gen != _play_gen:
			return
		if _icon_wrap:
			_icon_wrap.scale = Vector2.ONE
	)


func _play_unlock_fx() -> void:
	if UiSfx and UiSfx.has_method("play_achievement_unlock"):
		UiSfx.play_achievement_unlock()


## Sets icon and achievement name from the popped id.
func _apply_chip(id: String) -> void:
	if _icon:
		_icon.texture = _texture_for_id(id)
		_icon.modulate = AchievementCatalog.tier_modulate(id)
	if _name:
		HudLayout._bind_header_translation_key(_name, AchievementCatalog.display_title_key(id, true))
		HudLayout.apply_popup_label(_name, NAME_FONT_BASE)
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_name.autowrap_mode = TextServer.AUTOWRAP_OFF
		_name.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		_name.clip_contents = true
		_fit_name_label(id)


## Shrinks the name line so the full title fits without ellipsis.
func _fit_name_label(id: String) -> void:
	if _name == null:
		return
	var key := AchievementCatalog.display_title_key(id, true)
	var display := String(TranslationServer.translate(key))
	var font: Font = _name.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	if font == null:
		return
	var target_w := maxf(72.0, _chip_width - 56.0 - 14.0 - 32.0)
	var use_pixel := HudLayout.control_uses_pixel_font(_name)
	var size := HudLayout.snap_pixel_font_size(NAME_FONT_BASE) if use_pixel else HudLayout.body_font_size(NAME_FONT_BASE)
	var min_size := HudLayout.snap_pixel_font_size(NAME_FONT_MIN) if use_pixel else HudLayout.body_font_size(NAME_FONT_MIN)
	var step := 8 if use_pixel else 2
	while size > min_size:
		var measured := font.get_string_size(display, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		if measured.x <= target_w + 1.0:
			break
		size = maxi(min_size, size - step)
	if use_pixel:
		var color := _name.get_theme_color("font_color") if _name.has_theme_color_override("font_color") else Color.WHITE
		HudLayout.apply_live_pixel_label_settings(_name, display, size, color)
		return
	_name.text = display
	_name.add_theme_font_size_override("font_size", size)


## Loads the catalog SVG, falling back to the HUD star if the import is missing.
func _texture_for_id(id: String) -> Texture2D:
	var path := AchievementCatalog.icon_path(id)
	if path.is_empty() or not ResourceLoader.exists(path):
		path = AchievementCatalog.icon_path(AchievementCatalog.ID_FIRST_CLEAR)
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


## Drops any in-flight tween so a second enqueue cannot fire a stale callback.
func _kill_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null


func _ignore_mouse(node: Control) -> void:
	if node:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
