class_name EditorUiPolicy
extends RefCounted
## Editor / playtest UI is English-only and always uses Press Start.
## Mark scene roots early (_enter_tree) so locale font walks keep pixel fonts.

## Tags EditorUI and PlaytestEndLayer so locale font walks keep Press Start.
static func mark_editor_pixel_roots(scene_root: Node) -> void:
	if scene_root == null:
		return
	var editor_ui := scene_root.get_node_or_null("EditorUI")
	if editor_ui:
		HudFonts.mark_force_pixel_subtree(editor_ui)
	var playtest_end := scene_root.get_node_or_null("PlaytestEndLayer")
	if playtest_end:
		HudFonts.mark_force_pixel_subtree(playtest_end)

## Re-applies locale fonts under the editor UI root (still forced pixel).
static func refresh_editor_pixel_fonts(editor_ui_root: Node) -> void:
	if editor_ui_root == null:
		return
	HudLayout.apply_locale_fonts_to_tree(editor_ui_root)
