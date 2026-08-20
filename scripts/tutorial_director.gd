# Drives a step-based tutorial sequence for puzzle levels. Controls board input
# (cell whitelisting, highlighting, focus), displays instructional messages, and
# manages special modes like free-discovery and rule-teaching before handing
# control back to the player for the final solve.
class_name TutorialDirector
extends Node

# Emitted when the entire tutorial (including the final solve) is complete.
signal finished
# Emitted when tools become available after being locked during guided steps.
signal tools_unlocked
# Emitted whenever the board grid is rebuilt mid-tutorial (layout/size change).
signal board_layout_changed

var board_manager: BoardManager
var ui_manager: UIManager
# The tile types the player may cycle through on non-tutorial cells; restored when teaching ends.
var available_tiles: Array = [0, 1, 2]

# Step sequencing state
var _steps: Array = []
var _index: int = -1
var _active: bool = false
var _script_id: String = ""

# "Next" button interaction state
var _next_button: Button
var _awaiting_next: bool = false

# Practice step tracking
var _practice_succeeded: bool = false

# HUD/tool locking
var _tools_locked: bool = false
var _highlight_button_id: String = ""

# Completion tracking
var _solved_complete: bool = false

# Cached status text for locale refresh
var _last_status_key: String = ""
var _last_status_icons: Array = []
var _last_status_show_next: bool = false
var _last_status_append_next_prompt: bool = false

# Solve-gating: _block_solve prevents premature solve detection during teaching
var _block_solve: bool = false

# "Discover rules" mode: player experiments freely until a rule violation triggers teaching
var _discover_active: bool = false
# Rule teach shows two explanations in sequence (phase 1 then phase 2)
var _rule_teach_phase: int = 0
var _rule_teach_first_key: String = ""
var _rule_teach_second_key: String = ""
var _rule_teach_first_icons: Array = []
var _rule_teach_second_icons: Array = []

# When true, validation errors are suppressed in the UI (tutorial handles feedback itself)
var _suppress_validation_errors: bool = false
# True once all steps are done and the player is solving freely
var _awaiting_solve: bool = false
# Deferred board rebuild waiting for the player to press Next
var _pending_rebuild: bool = false

# Wires the director to the board and optional UI manager; must be called before start().
func setup(board: BoardManager, ui: UIManager = null) -> void:
	board_manager = board
	ui_manager = ui
	_ensure_next_button()

# True while a tutorial script is running (including the final free-solve phase).
func is_active() -> bool:
	return _active

# When true the caller should skip showing validation error toasts; the tutorial
# provides its own contextual feedback instead.
func suppress_validation_errors() -> bool:
	return _suppress_validation_errors

# Starts a named tutorial script and locks tools until the teaching phase ends.
# Resets any previously running tutorial first to avoid stale state.
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

# Tears down all tutorial state: clears board gates, hides the Next button,
# re-enables tools, and resets every internal flag to its default value.
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

# Called by BoardManager whenever any cell changes. Routes the event to the
# appropriate handler depending on the current step type; ignored during
# discover-rules mode and while waiting for the player to press Next.
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

# Called when a move is rejected. Returns true (and advances the step) if the
# current practice step is specifically waiting for a blocked-shifter error,
# turning an intentional failure into the expected success condition.
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

# Called after each validation pass during the discover-rules phase. If the player
# broke the rule-of-two or balance rule, or filled the board successfully, we
# interrupt free play and begin the two-phase rule-teaching sequence.
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

# Scans the error list for any THREE-in-a-row violation message.
func _errors_include_rule_of_two(errors: Array) -> bool:
	for e in errors:
		var s := String(e)
		if s.find("THREE") >= 0:
			return true
	return false

# Scans the error list for any row/column imbalance error (ERR_UNEQUAL_*).
func _errors_include_balance(errors: Array) -> bool:
	for e in errors:
		if String(e).begins_with("ERR_UNEQUAL_"):
			return true
	return false

# Begins the two-phase rule explanation after a violation during discover-rules.
# The violated rule is shown first; if both fired simultaneously, rule-of-two goes first.
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

# Called when the validator confirms a complete, valid board. Only triggers
# during the final free-solve phase (_awaiting_solve), and only if rule-teaching
# and discover-rules mode are fully finished.
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

# Called when the player taps a HUD button. If the current step is a hud_button
# step expecting exactly this button, the tutorial advances and returns true
# (signalling to the caller that the action was consumed by the tutorial).
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

# Pushes the current lock/highlight state to the UI manager. Called after any
# step transition that might change which HUD buttons should be enabled or highlighted.
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

# Safe accessor for the step at _index; returns an empty dict when out of range.
func _current_step() -> Dictionary:
	if _index < 0 or _index >= _steps.size():
		return {}
	return _steps[_index]

# Moves to the next step, or transitions to the free-solve phase when all steps are done.
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

# Dispatches a step dictionary to the correct handler based on its "type" field.
# Unknown types are skipped so future step types don't hard-break old scripts.
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

# Deferred check used by the "done" step: if the board is already full and valid
# when the free-solve phase starts, complete the tutorial immediately without
# requiring the player to make another move.
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

# Transitions into the final free-solve phase: unlocks tools (emitting
# tools_unlocked if they were previously locked), clears board gates, and
# shows the "play freely" tip message.
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

# Removes all highlight, focus, and click-whitelist restrictions from the board.
# Pass restore_cycles=true to also re-allow all available tile types on every cell.
func _clear_board_gates(restore_cycles: bool) -> void:
	if not board_manager:
		return
	board_manager.clear_click_whitelist()
	board_manager.clear_guide_cells()
	board_manager.clear_focus_cells()
	if restore_cycles:
		board_manager.restore_cell_cycle_tiles(available_tiles)

# Blocks all board cell taps by setting an empty whitelist (no cell is clickable).
func _freeze_board_input() -> void:
	if board_manager:
		board_manager.set_click_whitelist([])

# Applies the visual focus (guide/border highlights) and click-whitelist from a
# step's mask/highlight/red/border fields, plus any per-cell cycle override.
# For practice steps the whitelist is restricted to exactly the highlighted cells
# (plus the shifter "from" cell when applicable).
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

# Re-evaluates the target cell for a practice step and updates the status message
# and error highlight accordingly. Handles three distinct practice modes:
#   wait_blocked_shifter – player must try (and fail) to move a blocked shifter
#   wait_shifter         – player must move a shifter to its "from" neighbor
#   default              – player must set the cell to a specific tile state
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

# Clears the red error highlight from a cell if it supports that method.
func _clear_practice_error(cell) -> void:
	if cell == null:
		return
	if cell.has_method("clear_highlight"):
		cell.clear_highlight()

# Guards against double-triggering (practice steps can fire multiple board events).
# Shows the success message if defined, and either waits for Next or auto-advances
# depending on the step's require_next_after_success flag.
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

# Deferred wrapper around _advance() used after a successful practice step, so
# the success message has a chance to render before the next step is applied.
func _advance_after_practice() -> void:
	if not _active or _solved_complete:
		return
	_advance()

# Deferred re-application of focus after showing an error message: ensures the
# whitelist and highlights are restored once the wrong-key message has been set.
func _reapply_practice_focus() -> void:
	if not _active or _solved_complete or _practice_succeeded:
		return
	var step := _current_step()
	if String(step.get("type", "")) != "practice":
		return
	_apply_focus(step)

# Evaluates the pass condition for wait_cell, wait_shifter, and wait_full_valid
# steps. Advances the step when met, or shows the Next button for wait_full_valid.
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

# Convenience wrapper that extracts text_key and icons from a step dict and
# suppresses the Next button when allow_board is true (player acts to proceed).
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

# Core message display: translates the key, substitutes tile-icon BBCode for each
# "%s" placeholder in the icons array, applies colour-label gluing, strips any
# hardcoded "Tap Next" phrase from the translation (the button handles that), then
# sends the result to the UI. Caches parameters so refresh_for_locale() can re-run
# this after a language change without needing to re-read the current step.
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

# Replaces each "%s" in the translated text with the BBCode image tag for the
# corresponding token in the icons array (yellow, blue, lock, etc.).
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

# Some translation strings end with a locale-specific "Tap Next" call-to-action
# that was added before the Next button existed. This strips those trailing phrases
# so we don't duplicate the prompt when the button is already visible.
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

# Re-displays the current status message using the new locale. Called by the
# parent scene when the player changes language mid-tutorial.
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

# Shows or hides the Next button and starts/stops its attention-pulse animation.
# When shown, also clears guide/focus visuals and freezes board input unless the
# current step is a free_place or hud_button step that needs board access.
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

# Applies the standard dialog-button style to the Next button, removing any
# leftover icon container from a previous style pass.
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

# Handles the player pressing the Next button. The exact action depends on the
# current tutorial sub-state: finishing the tutorial, advancing through the two-phase
# rule-teach, executing a pending board rebuild, or simply moving to the next step.
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

# Resets all non-locked, non-shifter cells back to EMPTY before a board transition.
# Used by free_place message steps so the player starts the next section with a clean slate.
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

# Performs the deferred board rebuild that was queued by a rebuild_board step.
# The rebuild is deferred until Next is pressed so the player can read the
# transition message before the layout changes.
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

# Calls stop() and emits finished if the tutorial was actually running.
# Checking was_active prevents a spurious signal when stop() is called externally.
func _finish() -> void:
	var was_active := _active
	stop()
	if was_active:
		finished.emit()

# Looks up the TutorialNextButton node under the status label's parent and
# connects its pressed signal once. Safe to call repeatedly; bails out if the
# button is already valid.
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

# Positions the Next button at a fixed height above the status area.
# Stays put across steps so longer status copy does not shove it around.
func _position_next_button() -> void:
	if not _next_button:
		return
	_style_tutorial_next_button()
	var btn_size := _next_button.custom_minimum_size
	if btn_size.x <= 0.0 or btn_size.y <= 0.0:
		btn_size = GameConstants.UI_BTN_DIALOG_SIZE
	var half_w := btn_size.x * 0.5
	# One button-height lower than the status-area baseline.
	var bottom_margin := 480.0 + GameConstants.AD_BANNER_RESERVE - btn_size.y
	_next_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_next_button.offset_left = -half_w
	_next_button.offset_right = half_w
	_next_button.offset_top = -(btn_size.y + bottom_margin)
	_next_button.offset_bottom = -bottom_margin
	_next_button.z_index = 8
	_next_button.pivot_offset = btn_size * 0.5
