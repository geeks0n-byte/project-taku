extends Node2D

# Root controller for the level editor scene.
# Coordinates the EditorUIManager, PlaytestUIManager, EditorCanvasManager, and
# EditorPlaytestController — acting as the bridge between all editor subsystems.

@onready var editor_ui: EditorUIManager = $EditorUIManager
@onready var pt_ui: PlaytestUIManager = $PlaytestUIManager
@onready var canvas_manager: EditorCanvasManager = $EditorUI/EditorCanvasManager

var playtest_controller: EditorPlaytestController

# Currently selected tile type/brush tool. Determines what is painted on cell click/drag.
var current_brush_state: int = GameConstants.TileState.EMPTY
# Holds the first coordinate selected when using a two-click link brush (shifter or constraint).
# null means no selection is in progress.
var link_first_selection = null
# Stores the required-joker count for the currently edited level.
# -1 means "auto" (derive from grid dimensions); positive values are explicit.
var current_level_required_jokers: int = -1
var editor_undo := UndoStack.new()
# True while the primary mouse/touch button is held down during a paint drag.
var _is_painting: bool = false
# Tracks the last cell painted during a drag to avoid repainting the same cell each motion event.
var _last_painted_coord: Vector2i = Vector2i(-9999, -9999)
var _loading_overlay: LoadingOverlay
# Prevents stacking multiple async generation requests if the user clicks rapidly.
var _is_generating: bool = false

func _enter_tree() -> void:
	# Runs before child _ready — mark English-only editor chrome for Press Start.
	EditorUiPolicy.mark_editor_pixel_roots(self)

func _ready():
	if AdsManager:
		AdsManager.hide_menu_banner()
	_loading_overlay = LoadingOverlay.new()
	add_child(_loading_overlay)
	_apply_background_for_mode(false)
	playtest_controller = EditorPlaytestController.new()
	add_child(playtest_controller)
	playtest_controller.setup(canvas_manager, pt_ui, editor_ui)

	_bind_signals()
	editor_ui.setup_ui(canvas_manager.grid_width, canvas_manager.grid_height)
	canvas_manager.generate_blank_canvas(canvas_manager.grid_width, canvas_manager.grid_height)
	_recenter_editor_layout(canvas_manager.grid_width, canvas_manager.grid_height)
	_update_editor_joker_counter_display()
	editor_undo.max_size = 0  # Unlimited undo/redo while editing.
	# Seed the undo stack with the initial blank state so Ctrl+Z can return to it.
	editor_undo.reset(_create_editor_snapshot())
	editor_ui.update_editor_undo_redo_buttons(false, false)

# Handles raw mouse/touch input for painting tiles via drag. Link brushes use a
# two-click flow routed through canvas_cell_clicked instead, so they are excluded here.
# Each painted cell records its own undo step (same as playtest), so undoing a drag
# does not wipe the whole stroke at once.
func _input(event: InputEvent) -> void:
	if playtest_controller and playtest_controller.is_active:
		return
	if _is_link_brush():
		# Never leave a paint stroke armed while using two-click link tools.
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_is_painting = false
		elif event is InputEventScreenTouch and event.index == 0 and not event.pressed:
			_is_painting = false
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var coord := _coord_from_global(canvas_manager.get_global_mouse_position())
			if not canvas_manager.board_cells.has(coord):
				_is_painting = false
				return
			_is_painting = true
			_last_painted_coord = Vector2i(-9999, -9999)
			_try_paint_at_mouse()
		else:
			_is_painting = false
			_last_painted_coord = Vector2i(-9999, -9999)
	elif event is InputEventMouseMotion and _is_painting:
		_try_paint_at_mouse()
	elif event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			var coord := _coord_from_global(canvas_manager.get_global_mouse_position())
			if not canvas_manager.board_cells.has(coord):
				_is_painting = false
				return
			_is_painting = true
			_last_painted_coord = Vector2i(-9999, -9999)
			_try_paint_at_mouse()
		else:
			_is_painting = false
			_last_painted_coord = Vector2i(-9999, -9999)
	elif event is InputEventScreenDrag and event.index == 0 and _is_painting:
		_try_paint_at_mouse()

# Link brushes (shifter, equals, not-equals) require selecting two cells rather than painting,
# so they are handled separately via canvas_cell_clicked rather than the drag input path.
func _is_link_brush() -> bool:
	return (
		current_brush_state == GameConstants.TileState.SHIFTER
		or current_brush_state == GameConstants.BrushTool.EQUALS
		or current_brush_state == GameConstants.BrushTool.NOT_EQUALS
	)

# Converts a global screen position to integer grid coordinates using the canvas_manager's transform.
func _coord_from_global(global_pos: Vector2) -> Vector2i:
	var local := canvas_manager.to_local(global_pos)
	return Vector2i(floori(local.x / float(GameConstants.CELL_SIZE)), floori(local.y / float(GameConstants.CELL_SIZE)))

func _try_paint_at_mouse() -> void:
	if _is_link_brush():
		return
	var coord := _coord_from_global(canvas_manager.get_global_mouse_position())
	if not canvas_manager.board_cells.has(coord):
		return
	if coord == _last_painted_coord:
		return
	_last_painted_coord = coord
	if _apply_paint_brush(coord, true):
		_update_editor_joker_counter_display()

# Repositions the canvas_manager so the grid is visually centered, then tells the UI
# panels to reflow any elements that depend on where the board sits on screen.
func _recenter_editor_layout(width: int, height: int) -> void:
	var screen_size := get_viewport_rect().size
	var centered_board_x := LevelUtils.center_board_x(width, GameConstants.CELL_SIZE, screen_size.x)
	var centered_board_y := LevelUtils.center_board_y(height, GameConstants.CELL_SIZE, screen_size.y)
	canvas_manager.position = Vector2(centered_board_x, centered_board_y)
	var board_pixel_height := height * GameConstants.CELL_SIZE
	editor_ui.update_dynamic_editor_layout(centered_board_y, board_pixel_height)
	pt_ui.update_dynamic_playtest_layout(centered_board_y, board_pixel_height)

func _bind_signals():
	editor_ui.brush_changed.connect(_on_brush_changed)
	editor_ui.save_requested.connect(_on_save_level)
	editor_ui.load_requested.connect(_on_load_level)
	editor_ui.clear_requested.connect(_on_clear_board)
	editor_ui.random_requested.connect(_on_random_board_requested)
	editor_ui.main_menu_requested.connect(_on_main_menu)
	editor_ui.test_mode_entered.connect(_on_test_mode_entered)
	editor_ui.grid_size_changed.connect(_on_grid_size_changed)
	editor_ui.overwrite_confirmed.connect(_execute_save)
	editor_ui.editor_undo_requested.connect(_on_editor_undo_requested)
	editor_ui.editor_redo_requested.connect(_on_editor_redo_requested)
	editor_ui.allowed_tiles_changed.connect(_on_allowed_tiles_changed)

	pt_ui.test_mode_exited.connect(_on_test_mode_exited)
	pt_ui.playtest_reset_requested.connect(func(): playtest_controller.reset())
	pt_ui.playtest_rules_requested.connect(_on_playtest_rules_requested)
	pt_ui.playtest_hint_requested.connect(func(): playtest_controller.request_hint())
	pt_ui.playtest_undo_requested.connect(func(): playtest_controller.undo())
	pt_ui.playtest_redo_requested.connect(func(): playtest_controller.redo())
	pt_ui.resume_from_tutorial_requested.connect(_on_resume_from_playtest_tutorial)

	canvas_manager.canvas_cell_clicked.connect(_on_canvas_cell_clicked)
	canvas_manager.canvas_cell_played.connect(func(c): playtest_controller.handle_cell_played(c))
	canvas_manager.canvas_cell_hold_cleared.connect(func(c): playtest_controller.handle_cell_hold_cleared(c))
	canvas_manager.canvas_shifter_toggled.connect(func(c): playtest_controller.handle_shifter_toggled(c))

# Captures the complete mutable editor state — cell data, shifter/constraint pairs,
# and the joker count — into a deep-copied dictionary suitable for undo/redo storage.
func _create_editor_snapshot() -> Dictionary:
	var snap := {}
	for coord in canvas_manager.board_cells:
		var cell = canvas_manager.board_cells[coord]
		snap[coord] = {
			"state": cell.state,
			"shifter_direction": cell.shifter_direction,
			"is_locked": cell.is_locked,
			"is_playable": cell.is_playable,
			"is_linked_pair": cell.is_linked_pair
		}
	return {
		"cells": snap,
		"shifters": canvas_manager.loaded_shifter_pairs.duplicate(true),
		"constraints": canvas_manager.loaded_constraint_pairs.duplicate(true),
		"hidden_constraints": canvas_manager.hidden_constraint_pairs.duplicate(true),
		"jokers": current_level_required_jokers
	}

# Restores the editor state from a snapshot produced by _create_editor_snapshot.
# Called by undo and redo; pairs are deep-copied so subsequent edits don't corrupt history.
func _apply_editor_snapshot(snap: Dictionary):
	if snap.is_empty() or not snap.has("cells"):
		return
	var cells: Dictionary = snap["cells"]
	if cells.is_empty():
		return
	for coord in cells:
		if not canvas_manager.board_cells.has(coord):
			continue
		var cell = canvas_manager.board_cells[coord]
		var data: Dictionary = cells[coord]
		cell.state = data["state"]
		cell.shifter_direction = data["shifter_direction"]
		cell.is_locked = data["is_locked"]
		cell.is_playable = data["is_playable"]
		cell.is_linked_pair = data["is_linked_pair"]
		cell.update_visuals()

	canvas_manager.loaded_shifter_pairs = snap.get("shifters", []).duplicate(true)
	canvas_manager.loaded_constraint_pairs = snap.get("constraints", []).duplicate(true)
	canvas_manager.hidden_constraint_pairs = snap.get("hidden_constraints", []).duplicate(true)
	current_level_required_jokers = snap.get("jokers", current_level_required_jokers)
	canvas_manager.trigger_redraw()
	_update_editor_joker_counter_display()

# Saves the current editor state to the undo stack and refreshes the undo/redo buttons.
# Skips no-op records so identical consecutive states cannot create phantom undo steps.
func _record_editor_change():
	var snap := _create_editor_snapshot()
	if not editor_undo.current.is_empty() and snap.hash() == editor_undo.current.hash():
		return
	editor_undo.record(snap)
	editor_ui.update_editor_undo_redo_buttons(editor_undo.can_undo(), editor_undo.can_redo())

func _on_editor_undo_requested():
	if not editor_undo.can_undo():
		return
	_apply_editor_snapshot(editor_undo.undo())
	editor_ui.update_editor_undo_redo_buttons(editor_undo.can_undo(), editor_undo.can_redo())

func _on_editor_redo_requested():
	if not editor_undo.can_redo():
		return
	_apply_editor_snapshot(editor_undo.redo())
	editor_ui.update_editor_undo_redo_buttons(editor_undo.can_undo(), editor_undo.can_redo())

func _on_allowed_tiles_changed():
	if playtest_controller.is_active:
		return
	editor_ui.update_status("", Color.WHITE)
	_update_editor_joker_counter_display()

func _on_random_board_requested():
	if playtest_controller.is_active:
		return
	if _is_generating:
		return
	_is_generating = true

	var target_w = canvas_manager.grid_width
	var target_h = canvas_manager.grid_height
	editor_ui.sync_size_displays(target_w, target_h)

	var lock_walls = editor_ui.is_keep_walls_requested()
	var current_layout := {}
	if lock_walls:
		for c in canvas_manager.board_cells:
			if canvas_manager.board_cells[c].state == GameConstants.TileState.WALL:
				current_layout[c] = GameConstants.TileState.WALL

	var allowed_tiles: Array = editor_ui.get_allowed_tiles()
	var require_unique: bool = editor_ui.is_unique_solution_required()
	var gen_difficulty: int = editor_ui.get_generation_difficulty()
	var layout_copy: Dictionary = current_layout.duplicate(true)
	var generated: Variant = await _loading_overlay.run_async(self, func():
		return PuzzleGenerator.generate_random_layout(
			target_w, target_h, allowed_tiles, layout_copy, require_unique, lock_walls, gen_difficulty
		)
	)
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_is_generating = false
	if typeof(generated) != TYPE_DICTIONARY or (generated as Dictionary).is_empty() or not generated.has("layout"):
		var msg = "ERR_GEN_WALLS" if lock_walls else "ERR_GEN_CONSTRAINTS"
		editor_ui.update_status(msg, Color(1.0, 0.4, 0.4))
		return

	var generated_dict: Dictionary = generated
	current_level_required_jokers = generated_dict.get("total_jokers", 0)
	canvas_manager.generate_blank_canvas(target_w, target_h)
	canvas_manager.load_layout(target_w, target_h, generated_dict["layout"], generated_dict["shifters"], generated_dict["constraints"])
	canvas_manager.hidden_constraint_pairs = generated_dict.get("hidden_hints", []).duplicate(true)
	_recenter_editor_layout(target_w, target_h)
	editor_ui.update_status("", Color.WHITE)
	_update_editor_joker_counter_display()
	_record_editor_change()

func _on_grid_size_changed(new_width: int, new_height: int):
	if playtest_controller.is_active:
		return
	link_first_selection = null
	current_level_required_jokers = -1
	canvas_manager.hidden_constraint_pairs.clear()
	canvas_manager.generate_blank_canvas(new_width, new_height)
	_recenter_editor_layout(new_width, new_height)
	_update_editor_joker_counter_display()
	editor_undo.reset(_create_editor_snapshot())
	editor_ui.update_editor_undo_redo_buttons(false, false)

func _on_brush_changed(state_id: int, _brush_name: String):
	if playtest_controller.is_active:
		return
	_is_painting = false
	_last_painted_coord = Vector2i(-9999, -9999)
	if link_first_selection != null:
		canvas_manager.board_cells[link_first_selection].update_visuals()
		editor_ui.update_status("ERR_PLACEMENT_ABORTED", Color.WHITE)
	else:
		editor_ui.update_status("", Color.WHITE)
	current_brush_state = state_id
	link_first_selection = null

func _on_canvas_cell_clicked(coord: Vector2i):
	if playtest_controller.is_active:
		# Playtest uses Cell press/release + hold-clear; interceptor is ignored.
		return

	if _is_link_brush():
		_handle_link_brush_click(coord)
		return

	if not _is_painting:
		_last_painted_coord = Vector2i(-9999, -9999)
		if _apply_paint_brush(coord, true):
			_update_editor_joker_counter_display()

func _handle_link_brush_click(coord: Vector2i) -> void:
	var cell = canvas_manager.board_cells[coord]
	if link_first_selection == null:
		link_first_selection = coord
		cell.set_mask_color(Color(1.0, 1.0, 1.0, 0.4))
		if current_brush_state == GameConstants.TileState.SHIFTER \
			or current_brush_state == GameConstants.BrushTool.EQUALS \
			or current_brush_state == GameConstants.BrushTool.NOT_EQUALS:
			editor_ui.update_status("SELECT SECOND CELL", Color.WHITE, false)
	else:
		var first_coord = link_first_selection
		link_first_selection = null
		if first_coord == coord:
			canvas_manager.board_cells[first_coord].update_visuals()
			editor_ui.update_status("ERR_PLACEMENT_ABORTED", Color.WHITE)
			return
		var diff = (coord - first_coord).abs()
		if (diff.x == 1 and diff.y == 0) or (diff.x == 0 and diff.y == 1):
			if current_brush_state == GameConstants.TileState.SHIFTER:
				_execute_pair_link_creation(first_coord, coord)
				editor_ui.update_status("PURPLE TILE PLACED", Color.WHITE, false)
			elif current_brush_state == GameConstants.BrushTool.EQUALS:
				_execute_constraint_creation(first_coord, coord, "equals")
				editor_ui.update_status("= LINK PLACED", Color.WHITE, false)
			elif current_brush_state == GameConstants.BrushTool.NOT_EQUALS:
				_execute_constraint_creation(first_coord, coord, "not_equals")
				editor_ui.update_status("× LINK PLACED", Color.WHITE, false)
			_record_editor_change()
			if UiSfx:
				UiSfx.play_click()
		else:
			canvas_manager.board_cells[first_coord].update_visuals()
			editor_ui.update_status("ERR_CELLS_NOT_ADJACENT", Color.WHITE)

func _apply_paint_brush(coord: Vector2i, record_undo: bool) -> bool:
	if _is_link_brush():
		return false
	if not canvas_manager.board_cells.has(coord):
		return false
	var cell = canvas_manager.board_cells[coord]
	var pre_state = cell.state
	var pre_lock = cell.is_locked
	var pre_shifter = canvas_manager.loaded_shifter_pairs.size()
	var pre_const = canvas_manager.loaded_constraint_pairs.size()

	if current_brush_state == GameConstants.TileState.EMPTY:
		_remove_constraint_by_coord(coord)
	if cell.is_linked_pair:
		_remove_pair_by_coord(coord)

	cell.state = current_brush_state
	if current_brush_state == GameConstants.TileState.WALL:
		cell.is_playable = false
		cell.is_locked = true
	elif current_brush_state != GameConstants.TileState.EMPTY:
		cell.is_playable = true
		cell.is_locked = true
	else:
		cell.is_playable = true
		cell.is_locked = false
	cell.update_visuals()
	editor_ui.update_status("", Color.WHITE)

	var changed: bool = (
		cell.state != pre_state
		or cell.is_locked != pre_lock
		or canvas_manager.loaded_shifter_pairs.size() != pre_shifter
		or canvas_manager.loaded_constraint_pairs.size() != pre_const
	)
	if changed and record_undo:
		_record_editor_change()
	if changed and UiSfx:
		UiSfx.play_click()
	return changed

# Refreshes the joker counter shown in the playtest panel.
# The counter is hidden entirely when the board is empty or no jokers are required,
# so it only appears when it carries meaningful information.
# If current_level_required_jokers is -1 (auto), derive the target from the shorter grid dimension.
func _update_editor_joker_counter_display():
	if playtest_controller.is_active:
		return
	var placed_jokers := LevelUtils.count_jokers_on_board(canvas_manager.board_cells)
	var is_empty := true
	for coord in canvas_manager.board_cells:
		if canvas_manager.board_cells[coord].state != GameConstants.TileState.EMPTY:
			is_empty = false
			break
	var total_required := current_level_required_jokers
	if total_required < 0:
		total_required = mini(canvas_manager.grid_width, canvas_manager.grid_height)
	total_required = maxi(0, total_required)
	var has_jokers := total_required > 0 and not is_empty
	pt_ui.set_playtest_joker_counter_visibility(has_jokers)
	pt_ui.update_playtest_joker_counter(placed_jokers, total_required)

# Creates a shifter pair between coord_a (active/home) and coord_b (inactive partner).
# First removes any existing pair that shares coord_a as its active cell, or that already
# links the same two coords, to enforce a one-pair-per-cell invariant.
# All affected cell visuals are recalculated after the array is mutated.
func _execute_pair_link_creation(coord_a: Vector2i, coord_b: Vector2i):
	var pairs_to_remove: Array = []
	for i in range(canvas_manager.loaded_shifter_pairs.size() - 1, -1, -1):
		var p = canvas_manager.loaded_shifter_pairs[i]
		if p["active"] == coord_a:
			pairs_to_remove.append(i)
		elif (p["a"] == coord_a and p["b"] == coord_b) or (p["a"] == coord_b and p["b"] == coord_a):
			if not pairs_to_remove.has(i):
				pairs_to_remove.append(i)
	pairs_to_remove.sort()
	pairs_to_remove.reverse()
	var changed_cells := [coord_a, coord_b]
	for idx in pairs_to_remove:
		var p = canvas_manager.loaded_shifter_pairs[idx]
		if not changed_cells.has(p["a"]):
			changed_cells.append(p["a"])
		if not changed_cells.has(p["b"]):
			changed_cells.append(p["b"])
		canvas_manager.loaded_shifter_pairs.remove_at(idx)
	canvas_manager.loaded_shifter_pairs.append({
		"a": coord_a,
		"b": coord_b,
		"active": coord_a,
		"home": coord_a,
		"inactive": coord_b
	})
	for c in changed_cells:
		_recalculate_cell_pair_state(c)
	canvas_manager.trigger_redraw()

func _remove_pair_by_coord(coord: Vector2i):
	var changed_cells: Array = []
	for i in range(canvas_manager.loaded_shifter_pairs.size() - 1, -1, -1):
		var p = canvas_manager.loaded_shifter_pairs[i]
		if p["a"] == coord or p["b"] == coord:
			if not changed_cells.has(p["a"]):
				changed_cells.append(p["a"])
			if not changed_cells.has(p["b"]):
				changed_cells.append(p["b"])
			canvas_manager.loaded_shifter_pairs.remove_at(i)
	for c in changed_cells:
		_recalculate_cell_pair_state(c)
	canvas_manager.trigger_redraw()

# Re-derives a cell's state from the current loaded_shifter_pairs list.
# A cell is "active" (shows the SHIFTER tile with direction arrow) if it is the "active" key
# of any pair; "target" (appears empty but flagged linked) if it appears as "a" or "b";
# otherwise it is a plain empty cell with no link flags.
func _recalculate_cell_pair_state(c: Vector2i):
	if not canvas_manager.board_cells.has(c):
		return
	var cell = canvas_manager.board_cells[c]
	var is_active_in_any := false
	var is_target_in_any := false
	var new_direction := Vector2i.ZERO
	for p in canvas_manager.loaded_shifter_pairs:
		if p["active"] == c:
			is_active_in_any = true
			var partner = p["b"] if p["a"] == c else p["a"]
			new_direction = partner - c
		elif p["a"] == c or p["b"] == c:
			is_target_in_any = true
	if is_active_in_any:
		cell.is_linked_pair = true
		cell.state = GameConstants.TileState.SHIFTER
		cell.shifter_direction = new_direction
		cell.is_locked = false
	elif is_target_in_any:
		cell.is_linked_pair = true
		cell.state = GameConstants.TileState.EMPTY
		cell.shifter_direction = Vector2i.ZERO
		cell.is_locked = false
	else:
		cell.is_linked_pair = false
		cell.state = GameConstants.TileState.EMPTY
		cell.shifter_direction = Vector2i.ZERO
		cell.is_locked = false
	cell.update_visuals()

# Adds or replaces a constraint between two adjacent cells.
# Any existing constraint between the same pair is removed first so re-clicking toggles type cleanly.
func _execute_constraint_creation(coord_a: Vector2i, coord_b: Vector2i, type: String):
	canvas_manager.board_cells[coord_a].update_visuals()
	for i in range(canvas_manager.loaded_constraint_pairs.size() - 1, -1, -1):
		var p = canvas_manager.loaded_constraint_pairs[i]
		if (p["a"] == coord_a and p["b"] == coord_b) or (p["a"] == coord_b and p["b"] == coord_a):
			canvas_manager.loaded_constraint_pairs.remove_at(i)
	canvas_manager.loaded_constraint_pairs.append({"a": coord_a, "b": coord_b, "type": type})
	canvas_manager.trigger_redraw()

# Removes every constraint that involves `coord`, used when the EMPTY brush is applied
# to a cell that participates in one or more constraint pairs.
func _remove_constraint_by_coord(coord: Vector2i):
	for i in range(canvas_manager.loaded_constraint_pairs.size() - 1, -1, -1):
		var p = canvas_manager.loaded_constraint_pairs[i]
		if p["a"] == coord or p["b"] == coord:
			canvas_manager.loaded_constraint_pairs.remove_at(i)
	canvas_manager.trigger_redraw()

func _on_clear_board():
	if playtest_controller.is_active:
		return
	canvas_manager.loaded_shifter_pairs.clear()
	canvas_manager.loaded_constraint_pairs.clear()
	canvas_manager.hidden_constraint_pairs.clear()
	link_first_selection = null
	current_level_required_jokers = -1
	var keep_walls = editor_ui.is_keep_walls_requested()
	for coord in canvas_manager.board_cells:
		var cell = canvas_manager.board_cells[coord]
		if keep_walls and cell.state == GameConstants.TileState.WALL:
			cell.is_linked_pair = false
			cell.update_visuals()
			continue
		cell.state = GameConstants.TileState.EMPTY
		cell.shifter_direction = Vector2i.ZERO
		cell.is_playable = true
		cell.is_linked_pair = false
		cell.is_locked = false
		cell.update_visuals()
	canvas_manager.trigger_redraw()
	editor_ui.update_status("", Color.WHITE)
	_update_editor_joker_counter_display()
	_record_editor_change()

# Swaps between the opaque editor background and the animated SpaceBackground.
# The editor uses its own solid background so the parallax doesn't distract during design work.
func _apply_background_for_mode(is_playtest: bool) -> void:
	var editor_bg = get_node_or_null("EditorUI/EditorBackground") as ColorRect
	if editor_bg:
		# Anchors alone can be ignored without a layout mode — force full-bleed cover.
		editor_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		editor_bg.offset_left = 0.0
		editor_bg.offset_top = 0.0
		editor_bg.offset_right = 0.0
		editor_bg.offset_bottom = 0.0
		editor_bg.visible = not is_playtest
	if SpaceBackground:
		SpaceBackground.visible = is_playtest

func _on_test_mode_entered():
	_apply_background_for_mode(true)
	link_first_selection = null
	editor_ui.toggle_editor_visibility(true)
	playtest_controller.enter(current_level_required_jokers)
	_recenter_editor_layout(canvas_manager.grid_width, canvas_manager.grid_height)

# Opens the how-to-play overlay while playtesting: hides the board and pauses the timer
# so the player can read the rules without time pressure.
func _on_playtest_rules_requested():
	if not playtest_controller.is_active:
		return
	playtest_controller.pause_timer()
	if canvas_manager:
		canvas_manager.visible = false
	pt_ui.set_playtest_chrome_visible(false)
	pt_ui.show_how_to_play()

# Resumes playtesting after the rules overlay is dismissed.
func _on_resume_from_playtest_tutorial():
	if canvas_manager:
		canvas_manager.visible = true
	pt_ui.set_playtest_chrome_visible(true)
	playtest_controller.resume_timer()

func _on_test_mode_exited():
	playtest_controller.exit()
	link_first_selection = null
	_apply_background_for_mode(false)
	pt_ui.toggle_playtest_visibility(false)
	editor_ui.toggle_editor_visibility(false)
	_update_editor_joker_counter_display()

func _on_save_level():
	if playtest_controller.is_active:
		return
	var level_num = editor_ui.get_level_number()
	if ResourceLoader.exists(GameConstants.DEV_LEVELS_DIR + "level_%d.tres" % level_num):
		editor_ui.show_overwrite_warning()
		return
	_execute_save()

# Runs the solver analysis, constructs a LevelData resource from current editor state,
# and writes it to disk. Shifter cells are stored as EMPTY in the layout because the
# active/inactive state is fully described by shifter_pairs; saving SHIFTER in the layout
# would double-encode the information and confuse the loader.
func _execute_save():
	var level_num = editor_ui.get_level_number()
	var tiles: Array = editor_ui.get_allowed_tiles()
	var analysis := PuzzleSolver.analyze_board_cells(
		canvas_manager.board_cells,
		canvas_manager.grid_width,
		canvas_manager.grid_height,
		tiles,
		canvas_manager.loaded_constraint_pairs,
		canvas_manager.loaded_shifter_pairs,
		editor_ui.is_unique_solution_required()
	)
	if not _accept_save_analysis(analysis):
		return

	var output_layout := {}
	for coord in canvas_manager.board_cells:
		var current_state = canvas_manager.board_cells[coord].state
		output_layout[coord] = GameConstants.TileState.EMPTY if current_state == GameConstants.TileState.SHIFTER else current_state

	var new_level_resource: LevelData = LevelData.new()
	new_level_resource.level_number = level_num
	new_level_resource.width = canvas_manager.grid_width
	new_level_resource.height = canvas_manager.grid_height
	new_level_resource.layout = output_layout
	new_level_resource.required_jokers = current_level_required_jokers
	new_level_resource.required_shifter_moves = LevelUtils.compute_required_shifter_moves(
		canvas_manager.loaded_shifter_pairs
	)
	new_level_resource.shifter_pairs = canvas_manager.loaded_shifter_pairs.duplicate(true)
	new_level_resource.constraint_pairs = canvas_manager.loaded_constraint_pairs.duplicate(true)
	new_level_resource.time_limit = editor_ui.get_time_limit()
	new_level_resource.available_tiles = tiles
	new_level_resource.is_unique_solution = editor_ui.is_unique_solution_required()
	new_level_resource.keep_walls = editor_ui.is_keep_walls_requested()

	if not DirAccess.dir_exists_absolute(GameConstants.DEV_LEVELS_DIR):
		DirAccess.make_dir_absolute(GameConstants.DEV_LEVELS_DIR)

	var target_save_path = GameConstants.DEV_LEVELS_DIR + "level_%d.tres" % level_num
	var save_result = ResourceSaver.save(new_level_resource, target_save_path)
	if save_result == OK:
		editor_ui.update_status(HudLayout.english("ED_MSG_LEVEL_SAVED") % level_num, Color(0.4, 1.0, 0.4), false)
	else:
		editor_ui.update_status(HudLayout.english("ED_MSG_LEVEL_SAVE_FAILED") % [level_num, error_string(save_result).to_upper()], Color(1.0, 0.4, 0.4), false)

# Validates a solver analysis result before allowing a save.
# Blocks saving if the solver timed out (result is ambiguous), the puzzle is unsolvable,
# or a unique-solution requirement is active but multiple solutions were found.
func _accept_save_analysis(analysis: Dictionary) -> bool:
	if bool(analysis.get("timed_out", false)) or int(analysis.get("solution_count", 0)) == PuzzleSolver.SOLUTIONS_UNKNOWN:
		editor_ui.update_status(HudLayout.english("ED_MSG_SOLVE_TIMEOUT"), Color(1.0, 0.4, 0.4), false)
		return false
	if not bool(analysis.get("solvable", false)):
		editor_ui.update_status(HudLayout.english("ED_MSG_UNSOLVABLE"), Color(1.0, 0.4, 0.4), false)
		return false
	if editor_ui.is_unique_solution_required() and not bool(analysis.get("unique", false)):
		editor_ui.update_status(HudLayout.english("ED_MSG_NOT_UNIQUE"), Color(1.0, 0.4, 0.4), false)
		return false
	return true

func _on_load_level():
	if playtest_controller.is_active:
		return
	var level_num = editor_ui.get_level_number()
	var target_load_path = GameConstants.DEV_LEVELS_DIR + "level_%d.tres" % level_num
	if not ResourceLoader.exists(target_load_path):
		editor_ui.update_status(HudLayout.english("ED_MSG_LEVEL_NOT_FOUND") % level_num, Color(1.0, 0.8, 0.2), false)
		return

	var loaded_level = load(target_load_path) as LevelData
	if not loaded_level:
		editor_ui.update_status(HudLayout.english("ED_MSG_LEVEL_READ_FAILED") % level_num, Color(1.0, 0.4, 0.4), false)
		return

	link_first_selection = null
	var dims := LevelUtils.get_dimensions_from_level(loaded_level)
	canvas_manager.generate_blank_canvas(dims.x, dims.y)
	canvas_manager.load_layout(dims.x, dims.y, loaded_level.layout, LevelUtils.get_shifter_pairs(loaded_level), loaded_level.constraint_pairs)
	current_level_required_jokers = loaded_level.get("required_jokers") if "required_jokers" in loaded_level else -1
	_recenter_editor_layout(dims.x, dims.y)
	editor_ui.set_time_limit(loaded_level.time_limit)
	editor_ui.set_unique_solution_required(loaded_level.is_unique_solution)
	editor_ui.set_keep_walls_requested(loaded_level.keep_walls)
	var raw_tiles = loaded_level.available_tiles if loaded_level.available_tiles.size() > 0 else [0, 1, 2]
	var sanitized_tiles: Array = []
	for tile in raw_tiles:
		sanitized_tiles.append(int(tile))
	editor_ui.set_allowed_tiles(sanitized_tiles)
	editor_ui.sync_size_displays(dims.x, dims.y)
	editor_ui.update_status(HudLayout.english("ED_MSG_LEVEL_LOADED") % level_num, Color(0.4, 1.0, 0.4), false)
	_update_editor_joker_counter_display()
	_rebuild_editor_hidden_hints()
	_record_editor_change()

func _on_main_menu():
	if _is_generating or (_loading_overlay and _loading_overlay.is_busy()):
		return
	if SpaceBackground:
		SpaceBackground.visible = true
	GlobalGameManager.go_to_scene("res://scenes/main_menu.tscn")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if GlobalGameManager and GlobalGameManager.consume_system_back():
			_on_main_menu()

# Recomputes the auto-derived hint constraints that are hidden from the player but
# visible to the designer when the editor hint overlay is toggled on.
# Must be called whenever the board or allowed-tiles list changes.
func _rebuild_editor_hidden_hints():
	canvas_manager.hidden_constraint_pairs = HintSystem.rebuild_hidden_hints(
		canvas_manager.board_cells,
		canvas_manager.loaded_constraint_pairs,
		canvas_manager.grid_width,
		canvas_manager.grid_height,
		editor_ui.get_allowed_tiles()
	)
