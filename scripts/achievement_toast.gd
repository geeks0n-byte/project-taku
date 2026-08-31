extends CanvasLayer
## Phone-first achievement unlock toast. Queues multiple unlocks and auto-hides.

const SHOW_SEC := 2.6
const FADE_SEC := 0.28

@onready var _root: Control = $Root
@onready var _panel: Panel = $Root/Panel
@onready var _title: Label = $Root/Panel/VBox/TitleLabel
@onready var _name: Label = $Root/Panel/VBox/NameLabel

var _queue: Array[String] = []
var _busy: bool = false
var _tween: Tween

## Pins above gameplay/menus and starts hidden.
func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if _root:
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _panel:
		_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.add_theme_stylebox_override("panel", HudLayout.make_dialog_panel_style())
	_style_labels()
	_layout_panel()
	if not get_viewport().size_changed.is_connected(_layout_panel):
		get_viewport().size_changed.connect(_layout_panel)


## Queues an achievement id for display.
func enqueue(id: String) -> void:
	var clean := str(id).strip_edges()
	if clean.is_empty():
		return
	_queue.append(clean)
	if not _busy:
		_show_next()


## Styles title/name for the current locale.
func _style_labels() -> void:
	if _title:
		_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		HudLayout.apply_popup_label(_title, GameConstants.UI_BODY_FONT_SIZE)
	if _name:
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		HudLayout.apply_popup_label(_name, GameConstants.UI_BODY_FONT_SIZE_LARGE)


## Positions the toast below the safe-area top, capped to phone content width.
func _layout_panel() -> void:
	if _panel == null:
		return
	var top := SafeInsets.padded_top(24.0)
	var width := minf(720.0, HudLayout.max_ui_content_width(HudLayout.UI_SAFE_SIDE_MARGIN))
	_panel.offset_top = top
	_panel.offset_bottom = top + 220.0
	_panel.offset_left = -width * 0.5
	_panel.offset_right = width * 0.5


func _show_next() -> void:
	if _queue.is_empty():
		_busy = false
		visible = false
		return
	_busy = true
	var id: String = _queue.pop_front()
	if _title:
		_title.text = tr("ACH_UNLOCKED")
		HudLayout.apply_popup_label(_title, GameConstants.UI_BODY_FONT_SIZE)
	if _name:
		_name.text = tr(AchievementCatalog.title_key(id))
		HudLayout.apply_popup_label(_name, GameConstants.UI_BODY_FONT_SIZE_LARGE)
	_layout_panel()
	visible = true
	if _panel:
		_panel.modulate.a = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, FADE_SEC)
	_tween.tween_interval(SHOW_SEC)
	_tween.tween_property(_panel, "modulate:a", 0.0, FADE_SEC)
	_tween.tween_callback(_show_next)
