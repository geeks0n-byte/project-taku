class_name UiHudCounters
extends RefCounted
## HUD counters, timer, level label, status line, and hint button visuals.


var _counter_container: Control
var _timer_label: RichTextLabel
var _joker_counter_label: RichTextLabel
var _move_counter_label: RichTextLabel
var _level_label: RichTextLabel
var _status_label: RichTextLabel
var _hint_button: Button
var _is_tutorial_tools_locked: Callable
var _highlighted_hud_button: Callable

var _status_error_keys: Array = []
var _tutorial_mode: bool = false
var _tutorial_status_body: String = ""
var _hint_remaining: int = GameConstants.HINT_LIMIT_UNLIMITED
var _hint_forced_disabled: bool = false
var _level_display_num: int = 0
var _level_display_custom: bool = false
var _level_display_tutorial: bool = false
var _level_display_set: bool = false
var _joker_current: int = 0
var _joker_required: int = 0
var _move_count: int = 0
var _move_required: int = -1
var _last_timer_text: String = ""


func bind(
	counter_container: Control,
	timer_label: RichTextLabel,
	joker_counter_label: RichTextLabel,
	move_counter_label: RichTextLabel,
	level_label: RichTextLabel,
	status_label: RichTextLabel,
	hint_button: Button,
	is_tutorial_tools_locked: Callable,
	highlighted_hud_button: Callable
) -> void:
	_counter_container = counter_container
	_timer_label = timer_label
	_joker_counter_label = joker_counter_label
	_move_counter_label = move_counter_label
	_level_label = level_label
	_status_label = status_label
	_hint_button = hint_button
	_is_tutorial_tools_locked = is_tutorial_tools_locked
	_highlighted_hud_button = highlighted_hud_button


func setup_status_font() -> void:
	if _status_label:
		HudLayout.apply_status_font(_status_label, GameConstants.HUD_STATUS_FONT_SIZE)


func hide_counters_on_setup() -> void:
	set_joker_counter_visibility(false)
	set_move_counter_visibility(false)
	set_status_visible(false)


func on_locale_changed() -> void:
	if _level_display_set:
		display_level(_level_display_num, _level_display_custom, _level_display_tutorial)
	if _timer_label and not _last_timer_text.is_empty():
		update_timer(_last_timer_text)
	if _joker_counter_label and _joker_counter_label.visible:
		update_joker_counter(_joker_current, _joker_required)
	if _move_counter_label and _move_counter_label.visible:
		update_move_counter(_move_count, _move_required)
	refresh_status_label()


func update_dynamic_layout(board_y: float, board_height: float) -> void:
	HudLayout.position_counter_row(_counter_container)
	if _status_label:
		HudLayout.position_status_below_board(_status_label, board_y, board_height)


func update_joker_counter(current: int, required: int) -> void:
	if not _joker_counter_label:
		return
	_joker_current = current
	_joker_required = required
	HudLayout.prepare_counter_label(_joker_counter_label)
	_joker_counter_label.text = HudLayout.format_icon_ratio_counter(
		GameConstants.TILE_GREEN, current, required, GameConstants.HUD_COUNTER_GREEN, tr("UI_COUNTER_GREEN")
	)


func set_joker_counter_visibility(visible_state: bool) -> void:
	var slot := _joker_counter_label.get_parent() as Control if _joker_counter_label else null
	if slot:
		slot.visible = visible_state
	elif _joker_counter_label:
		_joker_counter_label.visible = visible_state
	_refresh_counter_row_alignment()


func update_move_counter(moves: int, required: int = -1) -> void:
	if not _move_counter_label:
		return
	_move_count = moves
	_move_required = required
	HudLayout.prepare_counter_label(_move_counter_label)
	var target := required if required >= 0 else moves
	_move_counter_label.text = HudLayout.format_icon_ratio_counter(
		GameConstants.TILE_SHIFTER, moves, target, GameConstants.HUD_COUNTER_SHIFTER, tr("UI_MOVES")
	)


func set_move_counter_visibility(visible_state: bool) -> void:
	var slot := _move_counter_label.get_parent() as Control if _move_counter_label else null
	if slot:
		slot.visible = visible_state
	elif _move_counter_label:
		_move_counter_label.visible = visible_state
	_refresh_counter_row_alignment()


func set_hint_remaining(remaining: int) -> void:
	_hint_remaining = remaining
	_refresh_hint_button_visual()


func set_hint_button_disabled(is_disabled: bool) -> void:
	_hint_forced_disabled = is_disabled
	_refresh_hint_button_visual()


func refresh_hint_button_visual() -> void:
	_refresh_hint_button_visual()


func hint_remaining() -> int:
	return _hint_remaining


func show_tutorial_status(bbcode_body: String) -> void:
	_tutorial_status_body = bbcode_body
	refresh_status_label()


func clear_tutorial_status() -> void:
	_tutorial_status_body = ""
	refresh_status_label()


func set_tutorial_mode(active: bool) -> void:
	_tutorial_mode = active
	if not active:
		_tutorial_status_body = ""
	refresh_status_label()


func update_timer(formatted_time: String) -> void:
	if not _timer_label:
		return
	_last_timer_text = formatted_time
	HudLayout.set_timer_raster_text(_timer_label, formatted_time)


func set_timer_visibility(visible_state: bool) -> void:
	var slot := _timer_label.get_parent() as Control if _timer_label else null
	if slot:
		slot.visible = visible_state
	elif _timer_label:
		_timer_label.visible = visible_state
	if _timer_label and not visible_state:
		_timer_label.text = ""
	_refresh_counter_row_alignment()


func display_level(num: int, is_custom: bool = false, is_tutorial: bool = false) -> void:
	if not _level_label:
		return
	_level_display_num = num
	_level_display_custom = is_custom
	_level_display_tutorial = is_tutorial
	_level_display_set = true
	var label_wrap: Control = _level_label.get_parent() as Control
	if label_wrap:
		label_wrap = label_wrap.get_parent() as Control
	if label_wrap:
		label_wrap.visible = true
	_level_label.visible = true
	if is_tutorial:
		_level_label.modulate.a = 0.0
		_level_label.text = ""
		HudLayout.apply_top_bar_mode_label(_level_label)
		return
	_level_label.modulate = Color.WHITE
	var prefix: String
	if is_custom:
		prefix = String(tr("UI_DEV"))
	else:
		prefix = String(tr("UI_LVL"))
	HudLayout.apply_level_label(_level_label, prefix, num)


func show_status_valid() -> void:
	_status_error_keys.clear()
	refresh_status_label()


func show_status_errors(errors: Array) -> void:
	_status_error_keys = errors.duplicate()
	refresh_status_label()


func set_status_visible(should_show: bool) -> void:
	if _status_label:
		_status_label.visible = should_show


func refresh_status_label() -> void:
	if not _status_label:
		return
	_status_label.modulate = Color.WHITE
	HudLayout.apply_status_font(_status_label, GameConstants.HUD_STATUS_FONT_SIZE)
	var lines: PackedStringArray = []
	if _tutorial_mode:
		if not _tutorial_status_body.is_empty():
			lines.append(HudLayout.break_after_sentences(_tutorial_status_body))
	elif not _status_error_keys.is_empty():
		for e in _status_error_keys:
			var translated := HudLayout.translate_status_text(str(e))
			if not translated.is_empty():
				lines.append(translated)
	else:
		lines.append(HudLayout.break_after_sentences(tr("MSG_FILL_EMPTY")))
	_status_label.text = "[center]" + "\n".join(lines) + "[/center]"
	_status_label.visible = true


func _refresh_counter_row_alignment() -> void:
	HudLayout.align_counter_row(_counter_container)


func _refresh_hint_button_visual() -> void:
	var locked := _is_tutorial_tools_locked.is_valid() and bool(_is_tutorial_tools_locked.call())
	var highlighted := ""
	if _highlighted_hud_button.is_valid():
		highlighted = String(_highlighted_hud_button.call())
	if locked and highlighted != "hint":
		HintController.update_button(_hint_button, false, _hint_remaining)
		return
	if locked and highlighted == "hint":
		HintController.update_button(_hint_button, true, _hint_remaining)
		return
	HintController.update_button(_hint_button, not _hint_forced_disabled, _hint_remaining)
