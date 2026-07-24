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
		HudLayout.apply_toggle_active_mask(_next_button, false)
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
	# Keep HUD tools locked until Next finishes the tutorial (prevents undo after solve).
	_tools_locked = true
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
			# Freeze board while teaching a HUD button.
			if board_manager:
				board_manager.set_click_whitelist([])
			refresh_tool_gates()
		"wait_cell", "wait_shifter":
			_show_message_from_step(step, false)
			_apply_focus(step)
			_check_wait_condition()
		"done":
			_enter_await_solve(String(step.get("text_key", "")), step.get("icons", []))
		_:
			_advance()

func _enter_await_solve(tip_key: String = "", tip_icons: Array = []) -> void:
	_highlight_button_id = ""
	_clear_board_gates(true)
	if _tools_locked:
		_tools_locked = false
		refresh_tool_gates()
		tools_unlocked.emit()
	else:
		refresh_tool_gates()
	var key := tip_key
	if key.is_empty():
		key = "TUT_PLAY_FREE"
	_show_message_key(key, tip_icons, false)

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
	board_manager.restore_cell_cycle_tiles(available_tiles)
	var masks: Array = step.get("mask", step.get("highlight", []))
	var borders: Array = step.get("red", step.get("border", []))
	board_manager.set_guide_cells(masks)
	board_manager.set_focus_cells(borders)
	# Gate clicks: practice → only highlighted cells; message → freeze board.
	var kind := String(step.get("type", ""))
	if kind == "practice":
		var allowed: Array = masks.duplicate() if not masks.is_empty() else []
		if allowed.is_empty() and step.has("coord"):
			allowed = [step["coord"]]
		# Shifter hops from the active purple cell — allow that too.
		if step.get("wait_shifter", false) and step.has("from"):
			allowed.append(step["from"])
		board_manager.set_click_whitelist(allowed)
	elif kind == "message":
		# Read-only tip: no accidental fills while reading.
		board_manager.set_click_whitelist([])
	else:
		board_manager.clear_click_whitelist()
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
			_clear_practice_error(cell)
			_on_practice_success(step)
		else:
			_practice_succeeded = false
			_show_message_from_step(step, false)
		return

	if cell.state == target:
		_clear_practice_error(cell)
		_on_practice_success(step)
		return

	_practice_succeeded = false
	if cell.state == GameConstants.TileState.EMPTY:
		_clear_practice_error(cell)
		_show_message_from_step(step, false)
		# Keep white guides/borders visible while the cell is empty again.
		_apply_focus(step)
		return

	# Wrong tile: keep trying — restore guides after validation clears errors.
	if cell.has_method("set_error_highlight"):
		cell.set_error_highlight()
	var wrong_key := String(step.get("wrong_key", ""))
	if wrong_key.is_empty():
		wrong_key = String(step.get("text_key", ""))
	_show_message_key(wrong_key, step.get("wrong_icons", step.get("icons", [])), false)
	# Re-apply masks/borders next frame so they survive validation clear_highlights.
	call_deferred("_reapply_practice_focus")

func _clear_practice_error(cell) -> void:
	if cell == null:
		return
	if cell.has_method("clear_highlight"):
		cell.clear_highlight()

func _on_practice_success(step: Dictionary) -> void:
	if _practice_succeeded:
		return
	_practice_succeeded = true
	# Lock input briefly, then auto-advance — no Next tap after a correct place.
	if board_manager:
		board_manager.set_click_whitelist([])
	var success_key := String(step.get("success_key", ""))
	if not success_key.is_empty():
		_show_message_key(success_key, step.get("success_icons", []), false)
	# Deferred so a full-board solve can mark _solved_complete first.
	call_deferred("_advance_after_practice")

func _advance_after_practice() -> void:
	if not _active or _solved_complete:
		return
	_advance()

func _reapply_practice_focus() -> void:
	if not _active or _solved_complete or _practice_succeeded:
		return
	var step := _current_step()
	if String(step.get("type", "")) != "practice":
		return
	_apply_focus(step)

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
	text = _apply_icon_placeholders(text, _last_status_icons)
	# Strip leftover "Tap Next" phrases from older translations if present.
	text = _strip_inline_next_prompt(text)
	if ui_manager:
		ui_manager.show_tutorial_status(text)
	_set_next_visible(show_next)

## Replace each `%s` in order with an icon. Avoids leftover `%s` when counts mismatch.
func _apply_icon_placeholders(text: String, icons: Array) -> String:
	var result := text
	for token in icons:
		var needle := "%s"
		var idx := result.find(needle)
		if idx < 0:
			break
		var img := TutorialScripts.icon_bbcode(String(token))
		result = result.substr(0, idx) + img + result.substr(idx + needle.length())
	return result

func _strip_inline_next_prompt(text: String) -> String:
	var cleaned := text.strip_edges()
	# Remove a trailing "Tap Next..." style sentence if a translation still inlines it.
	var markers: Array[String] = [
		"Tap Next",
		"Pulsa Siguiente",
		"Tippe Weiter",
		"Touchez Suivant",
		"Dotknij Dalej",
		"დააჭირეთ შემდეგს",
		"Натисніть Далі",
	]
	for marker in markers:
		var idx := cleaned.rfind(marker)
		if idx >= 0:
			# Only strip when the marker starts the final sentence-ish chunk.
			var before := cleaned.substr(0, idx).strip_edges()
			if before.is_empty() or before.ends_with(".") or before.ends_with("!") or before.ends_with("—") or before.ends_with("-"):
				cleaned = before
				break
	return cleaned.strip_edges()

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
			HudLayout.apply_toggle_active_mask(_next_button, false)
		else:
			HudLayout.apply_toggle_active_mask(_next_button, false)

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

	_next_button = host.get_node_or_null("TutorialNextButton") as Button
	if _next_button == null:
		return
	if not _next_button.pressed.is_connected(_on_next_pressed):
		_next_button.pressed.connect(_on_next_pressed)
	_position_next_button()

func _position_next_button() -> void:
	if not _next_button:
		return
	var half_w := GameConstants.UI_BTN_NAV_SIZE.x * 0.5
	# Lower under the tip, still above bottom chrome / ad banner.
	var bottom_margin := 400.0 + GameConstants.AD_BANNER_RESERVE
	_next_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_next_button.offset_left = -half_w
	_next_button.offset_right = half_w
	_next_button.offset_top = -(GameConstants.UI_BTN_NAV_SIZE.y + bottom_margin)
	_next_button.offset_bottom = -bottom_margin
	_next_button.z_index = 8
