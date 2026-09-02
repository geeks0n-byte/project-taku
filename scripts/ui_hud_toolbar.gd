class_name UiHudToolbar
extends RefCounted
## Top-bar button signals and hold-to-repeat undo/redo.


var _owner: Control
var _hold_repeat := HoldRepeat.new()
var _pause_button: Button
var _reset_button: Button
var _how_to_play_button: Button
var _hint_button: Button
var _undo_button: Button
var _redo_button: Button
var _restart_button: Button
var _main_menu_button: Button
var _tutorial_back_button: Button
var _htp_prev_button: Button
var _htp_next_button: Button
var _play_again_button: Button
var _on_pause: Callable
var _on_reset: Callable
var _on_how_to_play: Callable
var _on_hint: Callable
var _on_undo: Callable
var _on_redo: Callable
var _on_victory_next: Callable
var _on_play_again: Callable
var _on_main_menu: Callable
var _on_tutorial_back: Callable
var _on_htp_prev: Callable
var _on_htp_next: Callable
var _is_tutorial_locked: Callable
var _highlighted_button: Callable


func bind(
	owner: Control,
	pause_button: Button,
	reset_button: Button,
	how_to_play_button: Button,
	hint_button: Button,
	undo_button: Button,
	redo_button: Button,
	restart_button: Button,
	main_menu_button: Button,
	tutorial_back_button: Button,
	htp_prev_button: Button,
	htp_next_button: Button,
	play_again_button: Button,
	on_pause: Callable,
	on_reset: Callable,
	on_how_to_play: Callable,
	on_hint: Callable,
	on_undo: Callable,
	on_redo: Callable,
	on_victory_next: Callable,
	on_play_again: Callable,
	on_main_menu: Callable,
	on_tutorial_back: Callable,
	on_htp_prev: Callable,
	on_htp_next: Callable,
	is_tutorial_locked: Callable,
	highlighted_button: Callable
) -> void:
	_owner = owner
	_pause_button = pause_button
	_reset_button = reset_button
	_how_to_play_button = how_to_play_button
	_hint_button = hint_button
	_undo_button = undo_button
	_redo_button = redo_button
	_restart_button = restart_button
	_main_menu_button = main_menu_button
	_tutorial_back_button = tutorial_back_button
	_htp_prev_button = htp_prev_button
	_htp_next_button = htp_next_button
	_play_again_button = play_again_button
	_on_pause = on_pause
	_on_reset = on_reset
	_on_how_to_play = on_how_to_play
	_on_hint = on_hint
	_on_undo = on_undo
	_on_redo = on_redo
	_on_victory_next = on_victory_next
	_on_play_again = on_play_again
	_on_main_menu = on_main_menu
	_on_tutorial_back = on_tutorial_back
	_on_htp_prev = on_htp_prev
	_on_htp_next = on_htp_next
	_is_tutorial_locked = is_tutorial_locked
	_highlighted_button = highlighted_button


func connect_signals() -> void:
	if _pause_button and not _pause_button.pressed.is_connected(_emit_pause):
		_pause_button.pressed.connect(_emit_pause)
	if _reset_button and not _reset_button.pressed.is_connected(_emit_reset):
		_reset_button.pressed.connect(_emit_reset)
	if _how_to_play_button and not _how_to_play_button.pressed.is_connected(_emit_how_to_play):
		_how_to_play_button.pressed.connect(_emit_how_to_play)
	if _hint_button and not _hint_button.pressed.is_connected(_emit_hint):
		_hint_button.pressed.connect(_emit_hint)
	if _undo_button and not _undo_button.pressed.is_connected(_emit_undo):
		_undo_button.pressed.connect(_emit_undo)
	if _undo_button and not _undo_button.button_down.is_connected(_on_undo_button_down):
		_undo_button.button_down.connect(_on_undo_button_down)
		_undo_button.button_up.connect(_on_undo_button_up)
	if _redo_button and not _redo_button.pressed.is_connected(_emit_redo):
		_redo_button.pressed.connect(_emit_redo)
	if _redo_button and not _redo_button.button_down.is_connected(_on_redo_button_down):
		_redo_button.button_down.connect(_on_redo_button_down)
		_redo_button.button_up.connect(_on_redo_button_up)
	if _restart_button and not _restart_button.pressed.is_connected(_emit_victory_next):
		_restart_button.pressed.connect(_emit_victory_next)
	if _main_menu_button and not _main_menu_button.pressed.is_connected(_emit_main_menu):
		_main_menu_button.pressed.connect(_emit_main_menu)
	if _tutorial_back_button and not _tutorial_back_button.pressed.is_connected(_emit_tutorial_back):
		_tutorial_back_button.pressed.connect(_emit_tutorial_back)
	if _htp_prev_button and not _htp_prev_button.pressed.is_connected(_emit_htp_prev):
		_htp_prev_button.pressed.connect(_emit_htp_prev)
	if _htp_next_button and not _htp_next_button.pressed.is_connected(_emit_htp_next):
		_htp_next_button.pressed.connect(_emit_htp_next)
	if _play_again_button and not _play_again_button.pressed.is_connected(_emit_play_again):
		_play_again_button.pressed.connect(_emit_play_again)


func process(delta: float) -> bool:
	if not _hold_repeat.is_active():
		return false
	if not _hold_repeat.tick(delta):
		return true
	if _hold_repeat.is_undo():
		if UiSfx:
			UiSfx.play_click()
		_emit_undo()
	elif _hold_repeat.is_redo():
		if UiSfx:
			UiSfx.play_click()
		_emit_redo()
	return true


func update_undo_redo_buttons(can_undo: bool, can_redo: bool) -> void:
	var locked := _is_tutorial_locked.is_valid() and bool(_is_tutorial_locked.call())
	var highlighted := ""
	if _highlighted_button.is_valid():
		highlighted = String(_highlighted_button.call())
	if locked and highlighted != "undo" and highlighted != "redo":
		if _undo_button:
			_undo_button.disabled = true
			HudLayout.refresh_button_icon_modulate(_undo_button)
		if _redo_button:
			_redo_button.disabled = true
			HudLayout.refresh_button_icon_modulate(_redo_button)
		return
	if _undo_button:
		var undo_on := can_undo
		if locked and highlighted == "undo":
			undo_on = true
		_undo_button.disabled = not undo_on
		HudLayout.refresh_button_icon_modulate(_undo_button)
	if _redo_button:
		var redo_on := can_redo
		if locked and highlighted == "redo":
			redo_on = true
		_redo_button.disabled = not redo_on
		HudLayout.refresh_button_icon_modulate(_redo_button)


func set_hud_buttons_disabled(is_disabled: bool, hint_remaining: int, refresh_hint: Callable) -> void:
	for button in [_pause_button, _reset_button, _how_to_play_button]:
		if button:
			button.disabled = is_disabled
			HudLayout.refresh_button_icon_modulate(button)
	if is_disabled:
		if _undo_button:
			_undo_button.disabled = true
			HudLayout.refresh_button_icon_modulate(_undo_button)
		if _redo_button:
			_redo_button.disabled = true
			HudLayout.refresh_button_icon_modulate(_redo_button)
		if _hint_button:
			HintController.update_button(_hint_button, false, hint_remaining)
	elif refresh_hint.is_valid():
		refresh_hint.call()


func _emit_pause() -> void:
	if _on_pause.is_valid():
		_on_pause.call()


func _emit_reset() -> void:
	if _on_reset.is_valid():
		_on_reset.call()


func _emit_how_to_play() -> void:
	if _on_how_to_play.is_valid():
		_on_how_to_play.call()


func _emit_hint() -> void:
	if _on_hint.is_valid():
		_on_hint.call()


func _emit_undo() -> void:
	if _on_undo.is_valid():
		_on_undo.call()


func _emit_redo() -> void:
	if _on_redo.is_valid():
		_on_redo.call()


func _emit_victory_next() -> void:
	if _on_victory_next.is_valid():
		_on_victory_next.call()


func _emit_play_again() -> void:
	if _on_play_again.is_valid():
		_on_play_again.call()


func _emit_main_menu() -> void:
	if _on_main_menu.is_valid():
		_on_main_menu.call()


func _emit_tutorial_back() -> void:
	if _on_tutorial_back.is_valid():
		_on_tutorial_back.call()


func _emit_htp_prev() -> void:
	if _on_htp_prev.is_valid():
		_on_htp_prev.call()


func _emit_htp_next() -> void:
	if _on_htp_next.is_valid():
		_on_htp_next.call()


func _on_undo_button_down() -> void:
	_hold_repeat.start_undo()
	if _owner:
		_owner.set_process(true)
	if UiSfx and _undo_button:
		UiSfx.suppress_next_pressed_click(_undo_button)
		UiSfx.play_click()


func _on_undo_button_up() -> void:
	_hold_repeat.stop_undo()
	if UiSfx and _undo_button:
		UiSfx.clear_pressed_click_suppress(_undo_button)
	if _owner and not _hold_repeat.is_active():
		_owner.set_process(false)


func _on_redo_button_down() -> void:
	_hold_repeat.start_redo()
	if _owner:
		_owner.set_process(true)
	if UiSfx and _redo_button:
		UiSfx.suppress_next_pressed_click(_redo_button)
		UiSfx.play_click()


func _on_redo_button_up() -> void:
	_hold_repeat.stop_redo()
	if UiSfx and _redo_button:
		UiSfx.clear_pressed_click_suppress(_redo_button)
	if _owner and not _hold_repeat.is_active():
		_owner.set_process(false)
