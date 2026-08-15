class_name TutorialDirector
extends Node

signal finished
signal tools_unlocked
signal board_layout_changed

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
var _last_status_append_next_prompt: bool = false
var _block_solve: bool = false
var _discover_active: bool = false
var _rule_teach_phase: int = 0
var _rule_teach_first_key: String = ""
var _rule_teach_second_key: String = ""
var _rule_teach_first_icons: Array = []
var _rule_teach_second_icons: Array = []
var _suppress_validation_errors: bool = false
var _awaiting_solve: bool = false
var _pending_rebuild: bool = false

func setup(board: BoardManager, ui: UIManager = null) -> void:
	board_manager = board
	ui_manager = ui
	_ensure_next_button()

func is_active() -> bool:
	return _active

func suppress_validation_errors() -> bool:
	return _suppress_validation_errors

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
	if ui_manager and ui_manager.has_method("set_tutorial_mode"):
		ui_manager.set_tutorial_mode(true)
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
	_last_status_append_next_prompt = false
	_block_solve = false
	_discover_active = false
	_rule_teach_phase = 0
	_rule_teach_first_key = ""
	_rule_teach_second_key = ""
	_rule_teach_first_icons.clear()
	_rule_teach_second_icons.clear()
	_suppress_validation_errors = false
	_awaiting_solve = false
	_pending_rebuild = false
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
		HudLayout.stop_button_attention_pulse(_next_button)
		HudLayout.stop_toggle_mask_breathe(_next_button)
		HudLayout.apply_toggle_active_mask(_next_button, false)
	if ui_manager:
		ui_manager.clear_tutorial_status()
		ui_manager.clear_hud_button_highlight()
		ui_manager.set_tutorial_tools_locked(false)
		if ui_manager.has_method("set_tutorial_mode"):
			ui_manager.set_tutorial_mode(false)

func on_board_changed(_coord: Vector2i = Vector2i(-1, -1)) -> void:
	if not _active or _solved_complete:
		return
	var step := _current_step()
	var kind := String(step.get("type", ""))
	if kind == "practice":
		_update_practice_feedback(step)
		return
	if kind == "message" and bool(step.get("free_place", false)):
		return
	if _awaiting_next:
		return
	if _discover_active:
		return
	_check_wait_condition()

func on_invalid_move(msg: String) -> bool:
	if not _active or _solved_complete:
		return false
	var step := _current_step()
	if String(step.get("type", "")) != "practice":
		return false
	if not bool(step.get("wait_blocked_shifter", false)):
		return false
	if msg != "ERR_SHIFTER_BLOCKED":
		return false
	_on_practice_success(step)
	return true

func on_validation_result(results: Dictionary) -> void:
	if not _active or _solved_complete or not _discover_active:
		return
	if _awaiting_next or _rule_teach_phase > 0:
		return
	var errors: Array = results.get("errors", [])
	var broke_two := _errors_include_rule_of_two(errors)
	var broke_balance := _errors_include_balance(errors)
	if broke_two or broke_balance:
		_start_rule_teach(broke_two, broke_balance)
		return
	if bool(results.get("valid", false)) and board_manager and board_manager.is_board_full():
		_start_rule_teach(false, false)

func _errors_include_rule_of_two(errors: Array) -> bool:
	for e in errors:
		var s := String(e)
		if s.find("THREE") >= 0:
			return true
	return false

func _errors_include_balance(errors: Array) -> bool:
	for e in errors:
		if String(e).begins_with("ERR_UNEQUAL_"):
			return true
	return false

func _start_rule_teach(broke_two: bool, broke_balance: bool) -> void:
	_discover_active = false
	_block_solve = true
	if board_manager:
		board_manager.set_click_whitelist([])
	var step := _current_step()
	var two_key := String(step.get("rule_two_key", "TUT1_RULE_OF_TWO"))
	var bal_key := String(step.get("balance_key", "TUT1_BALANCE"))
	var two_icons: Array = step.get("rule_two_icons", ["yellow", "blue"])
	var bal_icons: Array = step.get("balance_icons", ["yellow", "blue"])
	if broke_two and not broke_balance:
		_rule_teach_first_key = two_key
		_rule_teach_first_icons = two_icons
		_rule_teach_second_key = bal_key
		_rule_teach_second_icons = bal_icons
	elif broke_balance and not broke_two:
		_rule_teach_first_key = bal_key
		_rule_teach_first_icons = bal_icons
		_rule_teach_second_key = two_key
		_rule_teach_second_icons = two_icons
	else:
		_rule_teach_first_key = two_key
		_rule_teach_first_icons = two_icons
		_rule_teach_second_key = bal_key
		_rule_teach_second_icons = bal_icons
	_rule_teach_phase = 1
	_show_message_key(_rule_teach_first_key, _rule_teach_first_icons, true)

func on_board_solved() -> void:
	if not _active or _solved_complete:
		return
	if not _awaiting_solve:
		return
	if _block_solve or _discover_active or _rule_teach_phase > 0:
		return
	_solved_complete = true
	_awaiting_next = true
	_practice_succeeded = false
	_highlight_button_id = ""
	if board_manager:
		board_manager.set_click_whitelist([])
		board_manager.clear_guide_cells()
		board_manager.clear_focus_cells()
		board_manager.restore_cell_cycle_tiles(available_tiles)
	_tools_locked = true
	refresh_tool_gates()
	_show_message_key("TUT_COMPLETE", [], true)

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
	_suppress_validation_errors = bool(step.get("suppress_errors", false))
	match kind:
		"message":
			var allow_board := bool(step.get("allow_board", false))
			var free_place := bool(step.get("free_place", false))
			var show_next := bool(step.get("show_next", true))
			if allow_board and not free_place:
				show_next = false
			_show_message_from_step(step, show_next)
			var has_focus := (
				step.has("mask")
				or step.has("highlight")
				or step.has("red")
				or step.has("border")
			)
			if has_focus:
				_apply_focus(step)
			elif show_next and not free_place:
				_freeze_board_input()
			else:
				_clear_board_gates(false)
			if (allow_board or free_place) and board_manager:
				board_manager.clear_click_whitelist()
		"apply_locks":
			if board_manager and step.has("layout"):
				board_manager.apply_locked_layout(step["layout"])
				board_layout_changed.emit()
			_show_message_from_step(step, true)
			if (
				step.has("mask")
				or step.has("highlight")
				or step.has("red")
				or step.has("border")
			):
				_apply_focus(step)
			_freeze_board_input()
		"rebuild_board":
			_pending_rebuild = step.has("layout")
			var pending_key := String(step.get("pending_key", ""))
			if pending_key.is_empty():
				pending_key = String(step.get("text_key", ""))
			_show_message_key(pending_key, step.get("icons", []), true, false)
			_clear_board_gates(false)
			_freeze_board_input()
		"discover_rules":
			_discover_active = true
			_block_solve = true
			_rule_teach_phase = 0
			_show_message_from_step(step, false)
			if board_manager:
				board_manager.clear_guide_cells()
				board_manager.clear_focus_cells()
				board_manager.clear_click_whitelist()
				board_manager.restore_cell_cycle_tiles(available_tiles)
			refresh_tool_gates()
		"practice":
			_practice_succeeded = false
			_show_message_from_step(step, false)
			_apply_focus(step)
			_update_practice_feedback(step)
		"hud_button":
			_highlight_button_id = String(step.get("button", ""))
			var hud_next := bool(step.get("show_next", true))
			_show_message_from_step(step, hud_next)
			_clear_board_gates(false)
			_freeze_board_input()
			refresh_tool_gates()
		"wait_cell", "wait_shifter", "wait_full_valid":
			_show_message_from_step(step, false)
			if (
				step.has("mask")
				or step.has("highlight")
				or step.has("red")
				or step.has("border")
			):
				_apply_focus(step)
			elif board_manager:
				board_manager.clear_click_whitelist()
			_check_wait_condition()
		"done":
			_block_solve = false
			_enter_await_solve(String(step.get("text_key", "")), step.get("icons", []))
			call_deferred("_try_complete_if_full")
		_:
			_advance()

func _try_complete_if_full() -> void:
	if not _active or _solved_complete or _block_solve:
		return
	if not board_manager or not board_manager.is_board_full():
		return
	var results := PuzzleValidator.validate_board(
		board_manager.board_cells,
		board_manager.cached_lines,
		board_manager.active_constraint_pairs,
		-1
	)
	if bool(results.get("valid", false)):
		on_board_solved()

func _enter_await_solve(tip_key: String = "", tip_icons: Array = []) -> void:
	_awaiting_solve = true
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

func _freeze_board_input() -> void:
	if board_manager:
		board_manager.set_click_whitelist([])

func _apply_focus(step: Dictionary) -> void:
	if not board_manager:
		return
	board_manager.restore_cell_cycle_tiles(available_tiles)
	var masks: Array = step.get("mask", step.get("highlight", [])).duplicate()
	var borders: Array = step.get("red", step.get("border", [])).duplicate()
	if step.has("coord"):
		var target: Vector2i = step["coord"]
		if not masks.has(target):
			masks.append(target)
		if not borders.has(target):
			borders.append(target)
	if step.has("from"):
		var from_c: Vector2i = step["from"]
		if not masks.has(from_c):
			masks.append(from_c)
		if not borders.has(from_c):
			borders.append(from_c)
	board_manager.set_guide_cells(masks)
	board_manager.set_focus_cells(borders)
	var kind := String(step.get("type", ""))
	if _awaiting_next:
		board_manager.set_click_whitelist([])
	elif kind == "practice":
		var allowed: Array = masks.duplicate() if not masks.is_empty() else []
		if allowed.is_empty() and step.has("coord"):
			allowed = [step["coord"]]
		if (
			(step.get("wait_shifter", false) or step.get("wait_blocked_shifter", false))
			and step.has("from")
		):
			allowed.append(step["from"])
		board_manager.set_click_whitelist(allowed)
	elif kind == "message":
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

	if step.get("wait_blocked_shifter", false):
		_practice_succeeded = false
		_show_message_from_step(step, false)
		_apply_focus(step)
		return

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
		_apply_focus(step)
		return

	if cell.has_method("set_error_highlight"):
		cell.set_error_highlight()
	var wrong_key := String(step.get("wrong_key", ""))
	if wrong_key.is_empty():
		wrong_key = String(step.get("text_key", ""))
	_show_message_key(wrong_key, step.get("wrong_icons", step.get("icons", [])), false)
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
	_freeze_board_input()
	var success_key := String(step.get("success_key", ""))
	var require_next := bool(step.get("require_next_after_success", false))
	if not success_key.is_empty():
		_show_message_key(
			success_key,
			step.get("success_icons", []),
			require_next,
			false
		)
	elif require_next:
		_set_next_visible(true)
	if require_next:
		_freeze_board_input()
		return
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
	elif kind == "wait_full_valid":
		if not board_manager:
			return
		if not board_manager.is_board_full():
			return
		var results := PuzzleValidator.validate_board(
			board_manager.board_cells,
			board_manager.cached_lines,
			board_manager.active_constraint_pairs,
			-1
		)
		if bool(results.get("valid", false)):
			_set_next_visible(true)

func _show_message_from_step(step: Dictionary, show_next: bool) -> void:
	var allow_board := bool(step.get("allow_board", false))
	var free_place := bool(step.get("free_place", false))
	if allow_board and show_next and not free_place:
		show_next = false
	_show_message_key(
		String(step.get("text_key", "")),
		step.get("icons", []),
		show_next,
		false
	)

func _show_message_key(
	key: String,
	icons: Variant,
	show_next: bool,
	append_next_prompt: bool = false
) -> void:
	_last_status_key = key
	_last_status_icons = icons.duplicate() if icons is Array else []
	_last_status_show_next = show_next
	_last_status_append_next_prompt = append_next_prompt
	var text := tr(key) if not key.is_empty() else ""
	text = _apply_icon_placeholders(text, _last_status_icons)
	text = HudLayout.glue_tile_icon_color_labels(text)
	text = _strip_inline_next_prompt(text)
	if ui_manager:
		ui_manager.show_tutorial_status(text)
	_set_next_visible(show_next)
	call_deferred("_position_next_button")

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
			var before := cleaned.substr(0, idx).strip_edges()
			if before.is_empty() or before.ends_with(".") or before.ends_with("!") or before.ends_with("—") or before.ends_with("-"):
				cleaned = before
				break
	return cleaned.strip_edges()

func refresh_for_locale() -> void:
	if not _active:
		return
	if not _last_status_key.is_empty():
		_show_message_key(
			_last_status_key,
			_last_status_icons,
			_last_status_show_next,
			_last_status_append_next_prompt
		)
	elif _awaiting_next:
		_set_next_visible(true)

func _set_next_visible(show_next: bool) -> void:
	_ensure_next_button()
	_awaiting_next = show_next
	if _next_button:
		_next_button.visible = show_next
		if show_next:
			_style_tutorial_next_button()
			_position_next_button()
			var step := _current_step()
			var free_place := (
				String(step.get("type", "")) == "message"
				and bool(step.get("free_place", false))
			)
			var teaching_hud := String(step.get("type", "")) == "hud_button"
			if board_manager:
				board_manager.clear_guide_cells()
				board_manager.clear_focus_cells()
				if free_place:
					board_manager.clear_click_whitelist()
				else:
					board_manager.set_click_whitelist([])
			if not teaching_hud:
				_highlight_button_id = ""
				if ui_manager:
					ui_manager.clear_hud_button_highlight()
			else:
				refresh_tool_gates()
			HudLayout.stop_toggle_mask_breathe(_next_button)
			HudLayout.apply_toggle_active_mask(_next_button, false)
			HudLayout.start_button_attention_pulse(_next_button)
		else:
			HudLayout.stop_button_attention_pulse(_next_button)
			HudLayout.stop_toggle_mask_breathe(_next_button)
			HudLayout.apply_toggle_active_mask(_next_button, false)

func _style_tutorial_next_button() -> void:
	if not _next_button:
		return
	var icon_root := _next_button.get_node_or_null("IconContainer")
	if icon_root:
		icon_root.queue_free()
	_next_button.text = "UI_NEXT"
	_next_button.flat = false
	_next_button.clip_text = true
	_next_button.autowrap_mode = TextServer.AUTOWRAP_OFF
	_next_button.custom_minimum_size = GameConstants.UI_BTN_DIALOG_SIZE
	_next_button.set_meta("_use_default_font", HudLayout.prefer_default_font())
	HudLayout.apply_dialog_button(_next_button)

func _on_next_pressed() -> void:
	if not _active or not _awaiting_next:
		return
	_awaiting_next = false
	if _solved_complete:
		_finish()
		return
	if _rule_teach_phase == 1:
		_rule_teach_phase = 2
		_show_message_key(_rule_teach_second_key, _rule_teach_second_icons, true)
		return
	if _rule_teach_phase == 2:
		_rule_teach_phase = 0
		_block_solve = true
		_advance()
		return
	if _pending_rebuild:
		_execute_pending_rebuild()
		return
	var step := _current_step()
	if String(step.get("type", "")) == "message" and bool(step.get("free_place", false)):
		_clear_unlocked_player_tiles()
	if String(step.get("type", "")) == "practice" and _practice_succeeded:
		_advance()
		return
	_advance()

func _clear_unlocked_player_tiles() -> void:
	if not board_manager:
		return
	for coord in board_manager.board_cells:
		var cell = board_manager.board_cells[coord]
		if cell == null or cell.is_locked:
			continue
		if cell.state == GameConstants.TileState.EMPTY:
			continue
		if cell.state == GameConstants.TileState.SHIFTER:
			continue
		cell.state = GameConstants.TileState.EMPTY
		if cell.has_method("update_visuals"):
			cell.update_visuals()
	board_manager.clear_highlights()
	board_manager.trigger_redraw()

func _execute_pending_rebuild() -> void:
	_pending_rebuild = false
	var step := _current_step()
	if board_manager and step.has("layout"):
		var layout: Dictionary = step.get("layout", {})
		var tiles: Array = step.get("tiles", available_tiles)
		var shifters: Array = step.get("shifter_pairs", [])
		var constraints: Array = step.get("constraint_pairs", [])
		board_manager.build_grid(layout, tiles, shifters, constraints)
		available_tiles = tiles.duplicate()
		board_layout_changed.emit()
	_show_message_from_step(step, true)
	if (
		step.has("mask")
		or step.has("highlight")
		or step.has("red")
		or step.has("border")
	):
		_apply_focus(step)
	else:
		_clear_board_gates(false)
	_freeze_board_input()
	if bool(step.get("allow_board", false)) and board_manager:
		board_manager.clear_click_whitelist()

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
	_style_tutorial_next_button()
	var btn_size := _next_button.custom_minimum_size
	if btn_size.x <= 0.0 or btn_size.y <= 0.0:
		btn_size = GameConstants.UI_BTN_DIALOG_SIZE
	var half_w := btn_size.x * 0.5
	var base_bottom := 480.0 + GameConstants.AD_BANNER_RESERVE
	var bottom_margin := base_bottom
	if ui_manager and ui_manager.status_label:
		var status := ui_manager.status_label
		var content_h := float(status.get_content_height())
		var overflow := maxf(0.0, content_h - GameConstants.HUD_STATUS_MIN_HEIGHT)
		if overflow > 0.0:
			status.offset_bottom = status.offset_top + content_h + 12.0
		bottom_margin = maxf(
			220.0 + GameConstants.AD_BANNER_RESERVE,
			base_bottom - overflow
		)
	_next_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_next_button.offset_left = -half_w
	_next_button.offset_right = half_w
	_next_button.offset_top = -(btn_size.y + bottom_margin)
	_next_button.offset_bottom = -bottom_margin
	_next_button.z_index = 8
	_next_button.pivot_offset = btn_size * 0.5
