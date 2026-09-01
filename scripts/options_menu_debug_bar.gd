class_name OptionsMenuDebugBar
extends RefCounted

const DEBUG_BTN_SIZE := 96.0
const _DEBUG_ICON_UNLOCK := preload("res://resources/icons/icon_debug_unlock.svg")
const _DEBUG_ICON_CUP := preload("res://resources/icons/icon_achievement_cup.svg")
const _DEBUG_ICON_TRASH := preload("res://resources/icons/icon_clear.svg")
const DEBUG_STATUS_GAP := 8.0
const DEBUG_STATUS_MIN_H := 48.0

var _debug_bar_host: Control
var _debug_buttons: HBoxContainer
var _status_label: Label
var _unlock_all_btn: Button
var _unlock_achievements_btn: Button
var _del_custom_btn: Button
var _show_debug_options: bool = false
var _apply_tile_styles: Callable


func setup(
	debug_bar_host: Control,
	debug_buttons: HBoxContainer,
	status_label: Label,
	unlock_all_btn: Button,
	unlock_achievements_btn: Button,
	del_custom_btn: Button,
	apply_tile_styles: Callable
) -> void:
	_debug_bar_host = debug_bar_host
	_debug_buttons = debug_buttons
	_status_label = status_label
	_unlock_all_btn = unlock_all_btn
	_unlock_achievements_btn = unlock_achievements_btn
	_del_custom_btn = del_custom_btn
	_apply_tile_styles = apply_tile_styles


func set_show_debug_options(show: bool) -> void:
	_show_debug_options = show


func layout() -> void:
	if _debug_bar_host == null:
		return
	if not _debug_bar_host.has_meta("_safe_t"):
		_debug_bar_host.set_meta("_safe_t", _debug_bar_host.offset_top)
	var top := SafeInsets.padded_top(float(_debug_bar_host.get_meta("_safe_t")))
	_debug_bar_host.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_debug_bar_host.offset_top = top
	_debug_bar_host.offset_left = 24.0 + SafeInsets.left()
	_debug_bar_host.offset_right = -24.0 - SafeInsets.right()
	if _debug_bar_host is BoxContainer:
		(_debug_bar_host as BoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	if _debug_buttons:
		_debug_buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if _status_label:
		_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stack_h := DEBUG_BTN_SIZE if _show_debug_options else 0.0
	if _status_label and _status_label.visible:
		if _show_debug_options:
			stack_h += DEBUG_STATUS_GAP
		stack_h += _status_label.custom_minimum_size.y
	_debug_bar_host.offset_bottom = top + stack_h
	_refresh_visibility()


func style_buttons() -> void:
	if not _show_debug_options:
		_refresh_visibility()
		return
	_refresh_visibility()
	var icon_pairs: Array = [
		[_unlock_all_btn, _DEBUG_ICON_UNLOCK, "UI_DEBUG_UNLOCK_ALL"],
		[_unlock_achievements_btn, _DEBUG_ICON_CUP, "UI_DEBUG_UNLOCK_ACHIEVEMENTS"],
		[_del_custom_btn, _DEBUG_ICON_TRASH, "UI_DEBUG_DEL_CUSTOM"],
	]
	for entry in icon_pairs:
		var btn: Button = entry[0]
		if btn == null:
			continue
		btn.visible = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.flat = false
		btn.clip_text = true
		btn.autowrap_mode = TextServer.AUTOWRAP_OFF
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.size_flags_stretch_ratio = 1.0
		if _apply_tile_styles.is_valid():
			_apply_tile_styles.call(btn)
		HudLayout._clear_pixel_raster(btn)
		btn.remove_meta("_tr_key")
		btn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		btn.text = ""
		btn.tooltip_text = tr(String(entry[2]))
		btn.custom_minimum_size = Vector2(DEBUG_BTN_SIZE, DEBUG_BTN_SIZE)
		_apply_debug_icon(btn, entry[1] as Texture2D)
	layout()


func show_status(msg: String, color: Color) -> void:
	if _status_label == null:
		return
	_status_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_status_label.modulate = color
	HudLayout.apply_raster_pixel_label(
		_status_label, msg, GameConstants.UI_BODY_FONT_SIZE, color
	)
	_sync_status_slot()


func _sync_status_slot() -> void:
	if _status_label == null:
		return
	var has_text := not _status_label.text.strip_edges().is_empty()
	_status_label.visible = has_text
	_status_label.custom_minimum_size = (
		Vector2(620, DEBUG_STATUS_MIN_H) if has_text else Vector2.ZERO
	)
	_refresh_visibility()
	layout()


func clear_status() -> void:
	if _status_label:
		_status_label.text = ""
	_sync_status_slot()


func _refresh_visibility() -> void:
	if _debug_bar_host == null:
		return
	var has_status := (
		_status_label != null and not _status_label.text.strip_edges().is_empty()
	)
	_debug_bar_host.visible = _show_debug_options or has_status


func _apply_debug_icon(button: Button, texture: Texture2D) -> void:
	if button == null or texture == null:
		return
	button.text = ""
	var legacy := button.get_node_or_null("IconContainer")
	if legacy:
		legacy.queue_free()
	var host := button.get_node_or_null("IconHost") as Control
	if host == null:
		host = Control.new()
		host.name = "IconHost"
		host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.add_child(host)
	for child in host.get_children():
		child.queue_free()
	var btn_px := DEBUG_BTN_SIZE
	var pad := maxf(10.0, btn_px * 0.14)
	var scale_i := maxi(2, int(floor((btn_px - pad * 2.0) / 16.0)))
	var icon_px := float(16 * scale_i)
	var inset := (btn_px - icon_px) * 0.5
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.position = Vector2(inset, inset)
	icon.size = Vector2(icon_px, icon_px)
	host.add_child(icon)
