extends CanvasLayer
## Full-screen achievements list. Authored chrome in the .tscn; rows filled in code.

signal back_requested

@onready var title_label: Label = $ScreenHeaderHost/TitleLabel
@onready var close_btn: Button = $CloseButtonHost/CloseButton
@onready var _header_host: Control = $ScreenHeaderHost
@onready var _close_host: Control = $CloseButtonHost
@onready var _list_host: Control = $ListHost
@onready var _scroll: ScrollContainer = $ListHost/ScrollContainer
@onready var _rows: VBoxContainer = $ListHost/ScrollContainer/Rows

const _ROW_SEP := 18
const _BELOW_TITLE_GAP := 48.0

## Wires close, header style, and safe-area resize.
func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if close_btn and not close_btn.pressed.is_connected(_on_close):
		close_btn.pressed.connect(_on_close)
	_style_header()
	_style_close()
	if not get_viewport().size_changed.is_connected(_on_resized):
		get_viewport().size_changed.connect(_on_resized)
	if SaveManager and not SaveManager.language_changed.is_connected(_on_language_changed):
		SaveManager.language_changed.connect(_on_language_changed)


func _on_resized() -> void:
	if visible:
		_layout()


func _on_language_changed() -> void:
	if visible:
		refresh()


func _style_header() -> void:
	if title_label == null:
		return
	HudLayout._bind_header_translation_key(title_label, "UI_ACHIEVEMENTS")
	HudLayout.apply_screen_header_style(title_label)


func _style_close() -> void:
	if close_btn:
		HudLayout.style_top_bar_close_button(close_btn)


## Rebuilds rows from AchievementManager / SaveManager and relayouts.
func refresh() -> void:
	_style_header()
	_style_close()
	_rebuild_rows()
	_layout()
	call_deferred("_layout")


func _rebuild_rows() -> void:
	if _rows == null:
		return
	for child in _rows.get_children():
		child.queue_free()
	_rows.add_theme_constant_override("separation", _ROW_SEP)
	var ids: Array = AchievementCatalog.ORDERED_IDS
	for id in ids:
		_rows.add_child(_make_row(str(id)))


## One achievement row: gold title when unlocked, dim title + desc when locked.
func _make_row(id: String) -> Control:
	var unlocked := false
	if SaveManager:
		unlocked = SaveManager.achievements_unlocked.has(id)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var name_label := Label.new()
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var title := tr(AchievementCatalog.title_key(id))
	if not unlocked:
		title = "%s — %s" % [tr("ACH_LOCKED"), title]
	name_label.text = title
	var name_color := (
		GameConstants.SCREEN_HEADER_COLOR if unlocked else Color(0.7, 0.7, 0.7, 1.0)
	)
	name_label.add_theme_color_override("font_color", name_color)
	HudLayout.apply_popup_label(name_label, GameConstants.UI_BODY_FONT_SIZE_LARGE)
	var desc := Label.new()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc.text = tr(AchievementCatalog.desc_key(id))
	desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1.0))
	HudLayout.apply_popup_label(desc, GameConstants.UI_BODY_FONT_SIZE)
	box.add_child(name_label)
	box.add_child(desc)
	return box


## Safe-area header, close button, and scroll region below the title.
func _layout() -> void:
	_style_header()
	_style_close()
	if title_label:
		title_label.offset_top = SafeInsets.padded_top(GameConstants.SCREEN_HEADER_TOP)
		title_label.offset_bottom = title_label.offset_top + GameConstants.SCREEN_HEADER_HEIGHT
	if _list_host and title_label:
		_list_host.offset_top = title_label.offset_bottom + _BELOW_TITLE_GAP
		_list_host.offset_bottom = SafeInsets.padded_bottom_offset(
			GameConstants.SCREEN_BOTTOM_NAV_TOP + 40.0
		)
		_list_host.offset_left = GameConstants.HUD_SIDE_MARGIN + SafeInsets.left()
		_list_host.offset_right = -GameConstants.HUD_SIDE_MARGIN - SafeInsets.right()
		HudLayout.cap_stretched_width(_list_host, HudLayout.UI_PHONE_CONTENT_WIDTH)
	if _header_host:
		_header_host.move_to_front()
	if _close_host:
		_close_host.move_to_front()


func _on_close() -> void:
	back_requested.emit()


## Android back closes this overlay.
func handle_system_back() -> bool:
	if not visible:
		return false
	back_requested.emit()
	return true
