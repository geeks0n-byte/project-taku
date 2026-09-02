class_name UiTutorialHud
extends RefCounted
## Tutorial HUD lock, highlight masks, and reset-button icon mode.


const ICON_RESET: Texture2D = preload("res://resources/icons/icon_reset.svg")
const ICON_RANDOM: Texture2D = preload("res://resources/icons/icon_random.svg")

var _reset_button: Button
var _how_to_play_button: Button
var _hint_button: Button
var _undo_button: Button
var _redo_button: Button
var _pause_button: Button
var _get_hint_remaining: Callable
var _on_tool_state_changed: Callable

var _tutorial_tools_locked: bool = false
var _highlighted_hud_button: String = ""
var _reset_is_restart: bool = false


func bind(
	reset_button: Button,
	how_to_play_button: Button,
	hint_button: Button,
	undo_button: Button,
	redo_button: Button,
	pause_button: Button,
	get_hint_remaining: Callable,
	on_tool_state_changed: Callable
) -> void:
	_reset_button = reset_button
	_how_to_play_button = how_to_play_button
	_hint_button = hint_button
	_undo_button = undo_button
	_redo_button = redo_button
	_pause_button = pause_button
	_get_hint_remaining = get_hint_remaining
	_on_tool_state_changed = on_tool_state_changed


func is_tools_locked() -> bool:
	return _tutorial_tools_locked


func highlighted_button() -> String:
	return _highlighted_hud_button


func set_reset_mode_restart(is_restart: bool) -> void:
	_reset_is_restart = is_restart
	_apply_reset_button_icon()


func set_tutorial_tools_locked(locked: bool) -> void:
	_tutorial_tools_locked = locked
	if not locked:
		_highlighted_hud_button = ""
	apply_tool_state()


func highlight_hud_button(button_id: String) -> void:
	_highlighted_hud_button = button_id
	if button_id == "reset":
		_set_reset_button_texture(ICON_RANDOM)
	else:
		_apply_reset_button_icon()
	apply_tool_state()


func clear_hud_button_highlight() -> void:
	_highlighted_hud_button = ""
	_apply_reset_button_icon()
	apply_tool_state()


func get_hud_button(button_id: String) -> Button:
	match button_id:
		"reset":
			return _reset_button
		"how_to_play":
			return _how_to_play_button
		"hint":
			return _hint_button
		"undo":
			return _undo_button
		"redo":
			return _redo_button
		"pause":
			return _pause_button
		_:
			return null


func apply_tool_state() -> void:
	var hint_remaining := 0
	if _get_hint_remaining.is_valid():
		hint_remaining = int(_get_hint_remaining.call())
	var ids := ["reset", "how_to_play", "hint", "undo", "redo"]
	for id in ids:
		var button := get_hud_button(id)
		if button == null:
			continue
		var is_focus: bool = _highlighted_hud_button == id
		HudLayout.apply_toggle_active_mask(button, is_focus, GameConstants.TOGGLE_MASK_WHITE)
		if is_focus:
			HudLayout.start_toggle_mask_breathe(button)
		else:
			HudLayout.stop_toggle_mask_breathe(button)
		if id == "reset" or id == "how_to_play":
			button.disabled = false
			HudLayout.refresh_button_icon_modulate(button)
			continue
		if not _tutorial_tools_locked:
			if id == "hint":
				HintController.update_button(button, false, hint_remaining)
				continue
			elif id == "undo" or id == "redo":
				pass
			else:
				button.disabled = false
				HudLayout.refresh_button_icon_modulate(button)
			continue
		if id == "hint":
			HintController.update_button(button, is_focus, hint_remaining)
		else:
			button.disabled = not is_focus
			HudLayout.refresh_button_icon_modulate(button)
	if _on_tool_state_changed.is_valid():
		_on_tool_state_changed.call()


func _apply_reset_button_icon() -> void:
	_set_reset_button_texture(ICON_RESET if _reset_is_restart else ICON_RANDOM)


func _set_reset_button_texture(tex: Texture2D) -> void:
	if not _reset_button:
		return
	var icon := _reset_button.get_node_or_null("IconContainer/Icon") as TextureRect
	if icon:
		icon.texture = tex
