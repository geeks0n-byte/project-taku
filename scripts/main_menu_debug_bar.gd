class_name MainMenuDebugBar
extends RefCounted

const _FX_STAR := preload("res://resources/background/fx_shooting_star.svg")
const _FX_AST_1 := preload("res://resources/background/fx_asteroid_1.svg")
const _FX_AST_2 := preload("res://resources/background/fx_asteroid_2.svg")
const _FX_AST_3 := preload("res://resources/background/fx_asteroid_3.svg")
const _FX_COMET_1 := preload("res://resources/background/fx_comet_1.svg")
const _FX_COMET_2 := preload("res://resources/background/fx_comet_2.svg")
const _FX_COMET_3 := preload("res://resources/background/fx_comet_3.svg")
const _DEBUG_BTN_SIZE := Vector2(96, 96)

var _show_debug_tools: bool = false
var _editor_btn: Button
var _debug_bar: Control
var _debug_star_btn: Button
var _debug_asteroid_btn: Button
var _debug_asteroid_cloud_btn: Button
var _debug_comet_btn: Button
var _debug_comet_shower_btn: Button


func setup(
	show_debug_tools: bool,
	editor_btn: Button,
	debug_bar: Control,
	debug_star_btn: Button,
	debug_asteroid_btn: Button,
	debug_asteroid_cloud_btn: Button,
	debug_comet_btn: Button,
	debug_comet_shower_btn: Button
) -> void:
	_show_debug_tools = show_debug_tools
	_editor_btn = editor_btn
	_debug_bar = debug_bar
	_debug_star_btn = debug_star_btn
	_debug_asteroid_btn = debug_asteroid_btn
	_debug_asteroid_cloud_btn = debug_asteroid_cloud_btn
	_debug_comet_btn = debug_comet_btn
	_debug_comet_shower_btn = debug_comet_shower_btn


func bind_signals() -> void:
	if _debug_star_btn and not _debug_star_btn.pressed.is_connected(_on_debug_star_pressed):
		_debug_star_btn.pressed.connect(_on_debug_star_pressed)
	if _debug_comet_btn and not _debug_comet_btn.pressed.is_connected(_on_debug_comet_pressed):
		_debug_comet_btn.pressed.connect(_on_debug_comet_pressed)
	if _debug_asteroid_btn and not _debug_asteroid_btn.pressed.is_connected(_on_debug_asteroid_pressed):
		_debug_asteroid_btn.pressed.connect(_on_debug_asteroid_pressed)
	if _debug_asteroid_cloud_btn and not _debug_asteroid_cloud_btn.pressed.is_connected(_on_debug_asteroid_cloud_pressed):
		_debug_asteroid_cloud_btn.pressed.connect(_on_debug_asteroid_cloud_pressed)
	if _debug_comet_shower_btn and not _debug_comet_shower_btn.pressed.is_connected(_on_debug_comet_shower_pressed):
		_debug_comet_shower_btn.pressed.connect(_on_debug_comet_shower_pressed)


func set_boot_menu_input_enabled(enabled: bool) -> void:
	var filter := Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for btn in [
		_debug_star_btn,
		_debug_asteroid_btn,
		_debug_asteroid_cloud_btn,
		_debug_comet_btn,
		_debug_comet_shower_btn,
	]:
		if btn:
			btn.mouse_filter = filter


func is_debug_enabled() -> bool:
	return _show_debug_tools or (SaveManager != null and SaveManager.dev_mode_enabled)


func apply_visibility() -> void:
	var enabled := is_debug_enabled()
	GlobalGameManager.debug_tools_enabled = enabled
	if _editor_btn:
		_editor_btn.visible = enabled
	if _debug_bar:
		_debug_bar.visible = enabled


func set_bar_visible(should_show: bool) -> void:
	if _debug_bar:
		_debug_bar.visible = is_debug_enabled() and should_show


func apply_safe_area_layout() -> void:
	if _debug_bar:
		var top := SafeInsets.padded_top(24.0)
		_debug_bar.offset_left = 24.0 + SafeInsets.left()
		_debug_bar.offset_top = top
		_debug_bar.offset_right = -24.0 - SafeInsets.right()
		_debug_bar.offset_bottom = top + 96.0


func fit_buttons() -> void:
	_setup_debug_fx_button(_debug_star_btn, [_FX_STAR])
	_setup_debug_fx_button(_debug_asteroid_btn, [_FX_AST_1])
	_setup_debug_fx_button(_debug_asteroid_cloud_btn, [_FX_AST_1, _FX_AST_2, _FX_AST_3])
	_setup_debug_fx_button(_debug_comet_btn, [_FX_COMET_1])
	_setup_debug_fx_button(_debug_comet_shower_btn, [_FX_COMET_1, _FX_COMET_2, _FX_COMET_3])


func fade_target() -> CanvasItem:
	if _debug_bar and _debug_bar.visible:
		return _debug_bar as CanvasItem
	return null


func _setup_debug_fx_button(button: Button, textures: Array) -> void:
	if button == null:
		return
	button.text = ""
	button.custom_minimum_size = _DEBUG_BTN_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	var host := button.get_node_or_null("IconHost") as Control
	if host == null:
		host = Control.new()
		host.name = "IconHost"
		host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.add_child(host)
	for child in host.get_children():
		child.queue_free()
	var count := textures.size()
	if count <= 0:
		return
	var btn_px := _DEBUG_BTN_SIZE.x
	if count == 1:
		var pad := maxf(10.0, btn_px * 0.14)
		var scale_i := maxi(2, int(floor((btn_px - pad * 2.0) / 16.0)))
		var solo_px := float(16 * scale_i)
		var inset := (btn_px - solo_px) * 0.5
		var icon := TextureRect.new()
		icon.texture = textures[0]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2(inset, inset)
		icon.size = Vector2(solo_px, solo_px)
		host.add_child(icon)
		return
	var s := btn_px / 72.0
	var icon_px := 28.0 * s
	var offsets := [
		Vector2(8, 10) * s,
		Vector2(28, 22) * s,
		Vector2(14, 34) * s,
	]
	for i in count:
		var icon := TextureRect.new()
		icon.texture = textures[i]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = offsets[mini(i, offsets.size() - 1)]
		icon.size = Vector2(icon_px, icon_px)
		host.add_child(icon)


func _on_debug_star_pressed() -> void:
	if SpaceBackground:
		SpaceBackground.debug_spawn_shooting_star()


func _on_debug_comet_pressed() -> void:
	if SpaceBackground:
		SpaceBackground.debug_spawn_comet()


func _on_debug_asteroid_pressed() -> void:
	if SpaceBackground:
		SpaceBackground.debug_spawn_asteroid()


func _on_debug_asteroid_cloud_pressed() -> void:
	if SpaceBackground:
		SpaceBackground.debug_spawn_asteroid_cloud()


func _on_debug_comet_shower_pressed() -> void:
	if SpaceBackground:
		SpaceBackground.debug_spawn_meteor_shower()
