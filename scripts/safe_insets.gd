class_name SafeInsets
extends RefCounted
## Converts DisplayServer safe area / cutouts into layout margins.
##
## Android 15 (target SDK 35+) draws edge-to-edge. Godot 4.7 always calls
## EdgeToEdge.enable(); the export flag only controls whether the engine adds
## its own system-bar padding. When screen/edge_to_edge is on, this helper
## keeps HUD and menus out from under the status bar, cutout, and nav bar.

## Viewport-pixel insets as Vector4(left, top, right, bottom).
static func viewport_margins() -> Vector4:
	var window_size := Vector2(DisplayServer.window_get_size())
	var viewport_size := _viewport_size()
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var win_pos := Vector2(DisplayServer.window_get_position())
	return margins_from(safe, window_size, win_pos, viewport_size)


## Window-pixel insets (native AdMob custom positions, not stretched canvas).
static func screen_margins() -> Vector4:
	var window_size := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var win_pos := Vector2(DisplayServer.window_get_position())
	return margins_from(safe, window_size, win_pos, window_size)


## Pure conversion used by tests: screen-space safe rect → layout margins.
static func margins_from(
	safe_area: Rect2,
	window_size: Vector2,
	window_pos: Vector2,
	viewport_size: Vector2
) -> Vector4:
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return Vector4.ZERO
	var local := Rect2(safe_area.position - window_pos, safe_area.size)
	var left := maxf(0.0, local.position.x)
	var top := maxf(0.0, local.position.y)
	var right := maxf(0.0, window_size.x - local.end.x)
	var bottom := maxf(0.0, window_size.y - local.end.y)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector4(left, top, right, bottom)
	var sx := viewport_size.x / window_size.x
	var sy := viewport_size.y / window_size.y
	return Vector4(left * sx, top * sy, right * sx, bottom * sy)


static func left() -> float:
	return viewport_margins().x


static func top() -> float:
	return viewport_margins().y


static func right() -> float:
	return viewport_margins().z


static func bottom() -> float:
	return viewport_margins().w


## Authored top offset, pushed down only when it would sit under the system bar.
static func padded_top(authored: float) -> float:
	return maxf(authored, top() + float(GameConstants.HUD_TOP_BAR_EDGE_MARGIN))


## Extra pixels added above an authored top offset (0 when already clear).
static func extra_top(authored: float) -> float:
	return padded_top(authored) - authored


## Negative Control.offset_bottom, grown by the nav-bar / home-indicator inset.
static func padded_bottom_offset(authored: float) -> float:
	return authored - bottom()


static func _viewport_size() -> Vector2:
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		var root := (tree as SceneTree).root
		if root:
			var vis := root.get_visible_rect().size
			if vis.x > 0.0 and vis.y > 0.0:
				return vis
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1080)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 1920))
	)
