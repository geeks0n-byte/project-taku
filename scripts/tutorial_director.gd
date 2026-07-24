class_name TutorialDirector
extends Node

signal finished
signal tools_unlocked

var board_manager: BoardManager
var ui_manager: UIManager
var available_tiles: Array = [0, 1, 2]

var _steps: Array = []
var _index: int = -1
var _active: bool = false
var _script_id: String = ""
var _next_button: Button
var _awaiting_next: bool = false
var _practice_succeeded: bool = false
var _tools_locked: bool = false
var _highlight_button_id: String = ""
var _solved_complete: bool = false
var _last_status_key: String = ""
var _last_status_icons: Array = []
var _last_status_show_next: bool = false

func setup(board: BoardManager, ui: UIManager = null) -> void:
	board_manager = board
	ui_manager = ui
	_ensure_next_button()

func is_active() -> bool:
	return _active

func start(script_id: String, tiles: Array) -> void:
	stop()
	if not TutorialScripts.has_script(script_id):
		return
	_script_id = script_id
	available_tiles = tiles.duplicate()
	_steps = TutorialScripts.steps_for(script_id)
	if _steps.is_empty():
		return
	_active = true
	_solved_complete = false
	_tools_locked = true
	_index = -1
	refresh_tool_gates()
	_advance()

func stop() -> void:
	_active = false
	_awaiting_next = false
	_practice_succeeded = false
	_solved_complete = false
	_last_status_key = ""
	_last_status_icons.clear()
	_last_status_show_next = false
	_script_id = ""
	_index = -1
	_steps.clear()
	_highlight_button_id = ""
	_tools_locked = false
	if board_manager:
		board_manager.clear_click_whitelist()
		board_manager.clear_guide_cells()
		board_manager.clear_focus_cells()
		board_manager.restore_cell_cycle_tiles(available_tiles)
	if _next_button:
		_next_button.visible = false
	if ui_manager:
		ui_manager.clear_tutorial_status()
		ui_manager.clear_hud_button_highlight()
		ui_manager.set_tutorial_tools_locked(false)

func on_board_changed(_coord: Vector2i = Vector2i(-1, -1)) -> void:
	if not _active or _solved_complete:
		return
	var step := _current_step()
	var kind := String(step.get("type", ""))
	if kind == "practice":
		_update_practice_feedback(step)
		return
	if _awaiting_next:
		return
	_check_wait_condition()

## Called when the board is valid and full. Shows the complete tip + Next; blocks the board.
func on_board_solved() -> void:
	if not _active or _solved_complete:
		return
	_solved_complete = true
	_awaiting_next = true
	_practice_succeeded = false
	_highlight_button_id = ""
	if board_manager:
		# Only now may the board be locked — tutorial is over except for Next.
		board_manager.set_click_whitelist([])
		board_manager.clear_guide_cells()
		board_manager.clear_focus_cells()
		board_manager.restore_cell_cycle_tiles(available_tiles)
	if _tools_locked:
		_tools_locked = false
		refresh_tool_gates()
		tools_unlocked.emit()
	else:
		refresh_tool_gates()
	_show_message_key("TUT_COMPLETE", [], true)

## Returns true when the HUD action was consumed by the current tutorial step.
func consume_hud_action(button_id: String) -> bool:
	if not _active or _solved_complete:
		return false
	var step := _current_step()
	if String(step.get("type", "")) != "hud_button":
		return false
	if String(step.get("button", "")) != button_id:
		return false
	_awaiting_next = false
	_advance()
	return true

func refresh_tool_gates() -> void:
	if not ui_manager:
		return
	if not _active:
		ui_manager.set_tutorial_tools_locked(false)
		ui_manager.clear_hud_button_highlight()
		return
	ui_manager.set_tutorial_tools_locked(_tools_locked)
	if _highlight_button_id.is_empty():
		ui_manager.clear_hud_button_highlight()
	else:
		ui_manager.highlight_hud_button(_highlight_button_id)

func _current_step() -> Dictionary:
	if _index < 0 or _index >= _steps.size():
		return {}
	return _steps[_index]

func _advance() -> void:
	if _solved_complete:
		return
	_index += 1
	_practice_succeeded = false
	_highlight_button_id = ""
	if _index >= _steps.size():
		_enter_await_solve()
		return
	_apply_step(_steps[_index])

func _apply_step(step: Dictionary) -> void:
	var kind := String(step.get("type", ""))
	match kind:
		"message":
			_show_message_from_step(step, true)
			_apply_focus(step)
		"practice":
			_practice_succeeded = false
			_show_message_from_step(step, false)
			_apply_focus(step)
			_update_practice_feedback(step)
		"hud_button":
			_highlight_button_id = String(step.get("button", ""))
			_show_message_from_step(step, true)
			_clear_board_gates(false)
			refresh_tool_gates()
		"wait_cell", "wait_shifter":
			_show_message_from_step(step, false)
			_apply_focus(step)
			_check_wait_condition()
		"done":
			# Tips finished — keep playing until the board is solved.
			_enter_await_solve()
		_:
			_advance()

func _enter_await_solve() -> void:
	_highlight_button_id = ""
	_clear_board_gates(true)
	if _tools_locked:
		_tools_locked = false
		refresh_tool_gates()
		tools_unlocked.emit()
	else:
		refresh_tool_gates()
	_set_next_visible(false)
	if ui_manager:
		ui_manager.clear_tutorial_status()

func _clear_board_gates(restore_cycles: bool) -> void:
	if not board_manager:
		return
	board_manager.clear_click_whitelist()
	board_manager.clear_guide_cells()
	board_manager.clear_focus_cells()
	if restore_cycles:
		board_manager.restore_cell_cycle_tiles(available_tiles)

func _apply_focus(step: Dictionary) -> void:
	if not board_manager:
		return
	# Never gate clicks during tips — guides/masks only.
	board_manager.clear_click_whitelist()
	board_manager.restore_cell_cycle_tiles(available_tiles)
	# White masks (LinkHighlight) and red focus borders can be used together.
	var masks: Array = step.get("mask", step.get("highlight", []))
	var reds: Array = step.get("red", [])
	board_manager.set_guide_cells(masks)
	board_manager.set_focus_cells(reds)
	if step.has("cycle") and step.has("coord"):
		board_manager.set_cell_cycle_tiles(step["coord"], step["cycle"])
	refresh_tool_gates()

func _update_practice_feedback(step: Dictionary) -> void:
	if not board_manager or not step.has("coord"):
		return
	var coord: Vector2i = step["coord"]
	if not board_manager.board_cells.has(coord):
		return
	var cell = board_manager.board_cells[coord]
	var target := int(step.get("state", -999))

	if step.get("wait_shifter", false):
		if cell.state == GameConstants.TileState.SHIFTER:
			_on_practice_success(step)
		else:
			_practice_succeeded = false
			_show_message_from_step(step, false)
		return

	if cell.state == target:
		_on_practice_success(step)
		return

	_practice_succeeded = false
	if cell.state == GameConstants.TileState.EMPTY:
		_show_message_from_step(step, false)
		return

	var wrong_key := String(step.get("wrong_key", ""))
	if wrong_key.is_empty():
		wrong_key = String(step.get("text_key", ""))
	_show_message_key(wrong_key, step.get("wrong_icons", step.get("icons", [])), false)

func _on_practice_success(step: Dictionary) -> void:
	if _practice_succeeded:
		return
	_practice_succeeded = true
	var success_key := String(step.get("success_key", ""))
	if success_key.is_empty():
		success_key = "TUT_GOOD"
	_show_message_key(success_key, step.get("success_icons", []), true)

func _check_wait_condition() -> void:
	if not _active or _solved_complete or _index < 0 or _index >= _steps.size():
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

func _show_message_from_step(step: Dictionary, show_next: bool) -> void:
	_show_message_key(String(step.get("text_key", "")), step.get("icons", []), show_next)

func _show_message_key(key: String, icons: Variant, show_next: bool) -> void:
	_last_status_key = key
	_last_status_icons = icons.duplicate() if icons is Array else []
	_last_status_show_next = show_next
	var text := tr(key) if not key.is_empty() else ""
	var icon_list: Array = _last_status_icons
	if not icon_list.is_empty():
		var args: Array = []
		for token in icon_list:
			args.append(TutorialScripts.icon_bbcode(String(token)))
		text = text % args
	if ui_manager:
		ui_manager.show_tutorial_status(text)
	_set_next_visible(show_next)

func refresh_for_locale() -> void:
	if not _active:
		return
	if not _last_status_key.is_empty():
		_show_message_key(_last_status_key, _last_status_icons, _last_status_show_next)
	elif _awaiting_next:
		_set_next_visible(true)

func _set_next_visible(show_next: bool) -> void:
	_ensure_next_button()
	_awaiting_next = show_next
	if _next_button:
		_next_button.visible = show_next
		if show_next:
			_next_button.text = tr("UI_NEXT")
			HudLayout.apply_nav_button(_next_button)
			_position_next_button()

func _on_next_pressed() -> void:
	if not _active or not _awaiting_next:
		return
	_awaiting_next = false
	if _solved_complete:
		_finish()
		return
	_advance()

func _finish() -> void:
	var was_active := _active
	stop()
	if was_active:
		finished.emit()

func _ensure_next_button() -> void:
	if _next_button and is_instance_valid(_next_button):
		return
	var host: Control = null
	if ui_manager and ui_manager.status_label:
		host = ui_manager.status_label.get_parent() as Control
	if host == null:
		return

	_next_button = Button.new()
	_next_button.name = "TutorialNextButton"
	_next_button.visible = false
	_next_button.focus_mode = Control.FOCUS_NONE
	_apply_menu_button_styles(_next_button)
	_next_button.add_theme_color_override("font_outline_color", Color.BLACK)
	_next_button.add_theme_constant_override("outline_size", 8)
	HudLayout.apply_nav_button(_next_button)
	_next_button.pressed.connect(_on_next_pressed)
	host.add_child(_next_button)
	_position_next_button()

func _position_next_button() -> void:
	if not _next_button:
		return
	var half_w := GameConstants.UI_BTN_NAV_SIZE.x * 0.5
	_next_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_next_button.offset_left = -half_w
	_next_button.offset_right = half_w
	_next_button.offset_top = -(GameConstants.UI_BTN_NAV_SIZE.y + 24.0)
	_next_button.offset_bottom = -24.0
	_next_button.z_index = 8

func _apply_menu_button_styles(button: Button) -> void:
	var tex := load("res://resources/buttons/button_tile_gray_dark.svg") as Texture2D
	if tex == null:
		return
	for style_name in ["normal", "pressed", "hover", "disabled"]:
		var box := StyleBoxTexture.new()
		box.texture = tex
		box.texture_margin_left = 16.0
		box.texture_margin_top = 16.0
		box.texture_margin_right = 16.0
		box.texture_margin_bottom = 16.0
		box.content_margin_left = 8.0
		box.content_margin_top = 8.0
		box.content_margin_right = 8.0
		box.content_margin_bottom = 8.0
		match style_name:
			"pressed":
				box.modulate_color = Color(0.8, 0.8, 0.8, 1)
			"hover":
				box.modulate_color = Color(1.2, 1.2, 1.2, 1)
			"disabled":
				box.modulate_color = Color(0.5, 0.5, 0.5, 1)
		button.add_theme_stylebox_override(style_name, box)
