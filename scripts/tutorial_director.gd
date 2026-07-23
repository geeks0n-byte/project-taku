class_name TutorialDirector
extends Node

signal finished

var board_manager: BoardManager
var available_tiles: Array = [0, 1, 2]

var _steps: Array = []
var _index: int = -1
var _active: bool = false
var _banner: CanvasLayer
var _panel: Panel
var _label: Label
var _next_button: Button
var _awaiting_next: bool = false

func setup(board: BoardManager) -> void:
	board_manager = board
	_ensure_banner()

func is_active() -> bool:
	return _active

func start(level_number: int, tiles: Array) -> void:
	stop()
	if not TutorialScripts.has_script(level_number):
		return
	available_tiles = tiles.duplicate()
	_steps = TutorialScripts.steps_for(level_number)
	if _steps.is_empty():
		return
	_active = true
	_index = -1
	_advance()

func stop() -> void:
	_active = false
	_awaiting_next = false
	_index = -1
	_steps.clear()
	if board_manager:
		board_manager.clear_click_whitelist()
		board_manager.clear_guide_cells()
		board_manager.restore_cell_cycle_tiles(available_tiles)
	if _banner:
		_banner.visible = false

func on_board_changed(_coord: Vector2i = Vector2i(-1, -1)) -> void:
	if not _active or _awaiting_next:
		return
	_check_wait_condition()

func _advance() -> void:
	_index += 1
	if _index >= _steps.size():
		_finish()
		return
	_apply_step(_steps[_index])

func _apply_step(step: Dictionary) -> void:
	var kind := String(step.get("type", ""))
	match kind:
		"message":
			_show_message(tr(String(step.get("text_key", ""))), true)
			board_manager.clear_click_whitelist()
			board_manager.clear_guide_cells()
			board_manager.restore_cell_cycle_tiles(available_tiles)
			# Block board while reading.
			_block_all_cells()
		"wait_cell", "wait_shifter":
			_show_message(tr(String(step.get("text_key", ""))), false)
			_apply_focus(step)
			_check_wait_condition()
		"done":
			board_manager.clear_click_whitelist()
			board_manager.clear_guide_cells()
			board_manager.restore_cell_cycle_tiles(available_tiles)
			_show_message(tr("TUT_COMPLETE"), true)
		_:
			_advance()

func _apply_focus(step: Dictionary) -> void:
	board_manager.restore_cell_cycle_tiles(available_tiles)
	var whitelist: Array = step.get("whitelist", [])
	if whitelist.is_empty():
		board_manager.clear_click_whitelist()
	else:
		board_manager.set_click_whitelist(whitelist)
	var highlight: Array = step.get("highlight", [])
	board_manager.set_guide_cells(highlight)
	if step.has("cycle") and step.has("coord"):
		board_manager.set_cell_cycle_tiles(step["coord"], step["cycle"])

func _block_all_cells() -> void:
	# Empty whitelist → every cell blocked.
	board_manager.set_click_whitelist([])

func _check_wait_condition() -> void:
	if not _active or _index < 0 or _index >= _steps.size():
		return
	var step: Dictionary = _steps[_index]
	var kind := String(step.get("type", ""))
	if kind == "wait_cell":
		var coord: Vector2i = step["coord"]
		var target: int = int(step["state"])
		if board_manager.board_cells.has(coord) and board_manager.board_cells[coord].state == target:
			_advance()
	elif kind == "wait_shifter":
		var coord: Vector2i = step["coord"]
		if board_manager.board_cells.has(coord) and board_manager.board_cells[coord].state == GameConstants.TileState.SHIFTER:
			_advance()

func _show_message(text: String, show_next: bool) -> void:
	_ensure_banner()
	_label.text = text
	HudLayout.apply_locale_font_to_control(_label)
	_label.add_theme_font_size_override("font_size", HudLayout.scaled_font_size(26))
	_next_button.visible = show_next
	_next_button.text = tr("UI_NEXT")
	HudLayout.fit_text_button(_next_button, 22, 14)
	_awaiting_next = show_next
	_banner.visible = true

func _on_next_pressed() -> void:
	if not _active or not _awaiting_next:
		return
	_awaiting_next = false
	var step: Dictionary = _steps[_index] if _index >= 0 and _index < _steps.size() else {}
	if String(step.get("type", "")) == "done":
		_finish()
	else:
		_advance()

func _finish() -> void:
	var was_active := _active
	stop()
	if was_active:
		finished.emit()

func _ensure_banner() -> void:
	if _banner:
		return
	_banner = CanvasLayer.new()
	_banner.name = "TutorialBannerLayer"
	_banner.layer = 7
	_banner.visible = false
	add_child(_banner)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(root)

	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 40.0
	_panel.offset_right = -40.0
	_panel.offset_top = -360.0
	_panel.offset_bottom = -40.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.14, 0.94)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(20)
	_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 24.0
	vbox.offset_top = 20.0
	vbox.offset_right = -24.0
	vbox.offset_bottom = -20.0
	vbox.add_theme_constant_override("separation", 18)
	_panel.add_child(vbox)

	_label = Label.new()
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98, 1))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	_label.set_meta("_use_default_font", true)
	vbox.add_child(_label)

	_next_button = Button.new()
	_next_button.custom_minimum_size = Vector2(280, 90)
	_next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.22, 0.28, 0.42, 1)
	btn_style.set_corner_radius_all(10)
	btn_style.set_content_margin_all(12)
	_next_button.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = Color(0.30, 0.38, 0.55, 1)
	_next_button.add_theme_stylebox_override("hover", btn_hover)
	_next_button.add_theme_color_override("font_outline_color", Color.BLACK)
	_next_button.add_theme_constant_override("outline_size", 6)
	_next_button.pressed.connect(_on_next_pressed)
	vbox.add_child(_next_button)
