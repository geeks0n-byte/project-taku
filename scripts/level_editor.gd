extends Node2D

@onready var editor_ui: EditorUIManager = $EditorUIManager
@onready var pt_ui: PlaytestUIManager = $PlaytestUIManager
@onready var canvas_manager: EditorCanvasManager = $EditorCanvasManager

var playtest_controller: EditorPlaytestController

var current_brush_state: int = GameConstants.TileState.EMPTY
var link_first_selection = null
var current_level_required_jokers: int = -1
var editor_undo := UndoStack.new()

func _ready():
	playtest_controller = EditorPlaytestController.new()
	add_child(playtest_controller)
	playtest_controller.setup(canvas_manager, pt_ui, editor_ui)

	_bind_signals()
	editor_ui.setup_ui(canvas_manager.grid_width, canvas_manager.grid_height)
	canvas_manager.generate_blank_canvas(canvas_manager.grid_width, canvas_manager.grid_height)
	_recenter_editor_layout(canvas_manager.grid_width, canvas_manager.grid_height)
	_update_editor_joker_counter_display()
	editor_undo.reset(_create_editor_snapshot())
	editor_ui.update_editor_undo_redo_buttons(false, false)

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
	editor_ui.editor_hint_toggled.connect(_on_editor_hint_toggled)
	editor_ui.editor_undo_requested.connect(_on_editor_undo_requested)
	editor_ui.editor_redo_requested.connect(_on_editor_redo_requested)
	editor_ui.allowed_tiles_changed.connect(_on_allowed_tiles_changed)

	pt_ui.test_mode_exited.connect(_on_test_mode_exited)
	pt_ui.playtest_reset_requested.connect(func(): playtest_controller.reset())
	pt_ui.playtest_rules_requested.connect(_on_playtest_rules_requested)
	pt_ui.playtest_hint_requested.connect(func(): playtest_controller.request_hint())
	pt_ui.playtest_undo_requested.connect(func(): playtest_controller.undo())
	pt_ui.playtest_redo_requested.connect(func(): playtest_controller.redo())
	pt_ui.resume_from_tutorial_requested.connect(func(): playtest_controller.resume_timer())

	canvas_manager.canvas_cell_clicked.connect(_on_canvas_cell_clicked)

func _on_editor_hint_toggled(is_on: bool):
	if playtest_controller.is_active:
		return
	canvas_manager.show_editor_hints = is_on
	if is_on:
		_rebuild_editor_hidden_hints()
	canvas_manager.trigger_redraw()

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

func _apply_editor_snapshot(snap: Dictionary):
	for coord in snap["cells"]:
		var cell = canvas_manager.board_cells[coord]
		cell.state = snap["cells"][coord]["state"]
		cell.shifter_direction = snap["cells"][coord]["shifter_direction"]
		cell.is_locked = snap["cells"][coord]["is_locked"]
		cell.is_playable = snap["cells"][coord]["is_playable"]
		cell.is_linked_pair = snap["cells"][coord]["is_linked_pair"]
		cell.update_visuals()

	canvas_manager.loaded_shifter_pairs = snap["shifters"].duplicate(true)
	canvas_manager.loaded_constraint_pairs = snap["constraints"].duplicate(true)
	canvas_manager.hidden_constraint_pairs = snap.get("hidden_constraints", []).duplicate(true)
	current_level_required_jokers = snap["jokers"]
	canvas_manager.trigger_redraw()
	_update_editor_joker_counter_display()

func _record_editor_change():
	if canvas_manager.show_editor_hints:
		_rebuild_editor_hidden_hints()
		canvas_manager.trigger_redraw()
	editor_undo.record(_create_editor_snapshot())
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

	var target_w = canvas_manager.grid_width
	var target_h = canvas_manager.grid_height
	editor_ui.sync_size_displays(target_w, target_h)

	var lock_walls = editor_ui.is_keep_walls_requested()
	var current_layout := {}
	if lock_walls:
		for c in canvas_manager.board_cells:
			if canvas_manager.board_cells[c].state == GameConstants.TileState.WALL:
				current_layout[c] = GameConstants.TileState.WALL

	var generated = PuzzleGenerator.generate_random_layout(
		target_w, target_h, editor_ui.get_allowed_tiles(), current_layout,
		editor_ui.is_unique_solution_required(), lock_walls
	)
	if generated.is_empty() or not generated.has("layout"):
		var msg = "GENERATION FAILED: THE LOCKED WALLS MAKE A VALID SOLUTION IMPOSSIBLE." if lock_walls else "GENERATION FAILED: THE CONSTRAINTS ARE TOO RESTRICTIVE FOR THIS GRID SIZE."
		editor_ui.update_status(msg, Color(1.0, 0.4, 0.4))
		return

	current_level_required_jokers = generated.get("total_jokers", 0)
	canvas_manager.generate_blank_canvas(target_w, target_h)
	canvas_manager.load_layout(target_w, target_h, generated["layout"], generated["shifters"], generated["constraints"])
	canvas_manager.hidden_constraint_pairs = generated.get("hidden_hints", []).duplicate(true)
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
	if link_first_selection != null:
		canvas_manager.board_cells[link_first_selection].update_visuals()
		editor_ui.update_status("PLACEMENT ABORTED.", Color.WHITE)
	else:
		editor_ui.update_status("", Color.WHITE)
	current_brush_state = state_id
	link_first_selection = null

func _on_canvas_cell_clicked(coord: Vector2i):
	if playtest_controller.is_active:
		playtest_controller.handle_cell_click(coord)
		return

	var cell = canvas_manager.board_cells[coord]
	var pre_state = cell.state
	var pre_lock = cell.is_locked
	var pre_shifter = canvas_manager.loaded_shifter_pairs.size()
	var pre_const = canvas_manager.loaded_constraint_pairs.size()

	if current_brush_state >= GameConstants.TileState.SHIFTER and current_brush_state <= 5:
		if link_first_selection == null:
			link_first_selection = coord
			cell.set_mask_color(Color(1.0, 1.0, 1.0, 0.4))
			if current_brush_state == GameConstants.TileState.SHIFTER:
				editor_ui.update_status("SELECT A NEIGHBORING CELL TO PLACE THE SECOND [color=#9c27b0]PURPLE[/color] TILE.", Color.YELLOW)
			elif current_brush_state == 4:
				editor_ui.update_status("SELECT A NEIGHBORING CELL TO PLACE THE EQUALS (=) LINK.", Color.YELLOW)
			elif current_brush_state == 5:
				editor_ui.update_status("SELECT A NEIGHBORING CELL TO PLACE THE NOT-EQUALS (×) LINK.", Color.YELLOW)
		else:
			var first_coord = link_first_selection
			link_first_selection = null
			if first_coord == coord:
				canvas_manager.board_cells[first_coord].update_visuals()
				editor_ui.update_status("PLACEMENT ABORTED.", Color.WHITE)
				return
			var diff = (coord - first_coord).abs()
			if (diff.x == 1 and diff.y == 0) or (diff.x == 0 and diff.y == 1):
				if current_brush_state == GameConstants.TileState.SHIFTER:
					_execute_pair_link_creation(first_coord, coord)
					editor_ui.update_status("[color=#9c27b0]PURPLE[/color] TILE PAIR PLACED SUCCESSFULLY.", Color(0.4, 1.0, 0.4))
				elif current_brush_state == 4:
					_execute_constraint_creation(first_coord, coord, "equals")
					editor_ui.update_status("EQUALS (=) LINK PLACED SUCCESSFULLY.", Color(0.4, 1.0, 0.4))
				elif current_brush_state == 5:
					_execute_constraint_creation(first_coord, coord, "not_equals")
					editor_ui.update_status("NOT-EQUALS (×) LINK PLACED SUCCESSFULLY.", Color(0.4, 1.0, 0.4))
				_record_editor_change()
			else:
				canvas_manager.board_cells[first_coord].update_visuals()
				editor_ui.update_status("PLACEMENT ABORTED: CELLS MUST BE ADJACENT.", Color(1.0, 0.4, 0.4))
		return

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
	_update_editor_joker_counter_display()

	if cell.state != pre_state or cell.is_locked != pre_lock or canvas_manager.loaded_shifter_pairs.size() != pre_shifter or canvas_manager.loaded_constraint_pairs.size() != pre_const:
		_record_editor_change()

func _update_editor_joker_counter_display():
	if playtest_controller.is_active:
		return
	var prefilled_jokers := 0
	var is_empty := true
	for coord in canvas_manager.board_cells:
		var st = canvas_manager.board_cells[coord].state
		if st == GameConstants.TileState.JOKER:
			prefilled_jokers += 1
		if st != GameConstants.TileState.EMPTY:
			is_empty = false
	var total_required := current_level_required_jokers
	if total_required == -1:
		total_required = mini(canvas_manager.grid_width, canvas_manager.grid_height)
	total_required = maxi(0, total_required)
	var has_jokers := total_required > 0 and not is_empty
	pt_ui.set_playtest_joker_counter_visibility(has_jokers)
	pt_ui.update_playtest_joker_counter(prefilled_jokers, total_required)

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
	canvas_manager.loaded_shifter_pairs.append({"a": coord_a, "b": coord_b, "active": coord_a})
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

func _execute_constraint_creation(coord_a: Vector2i, coord_b: Vector2i, type: String):
	canvas_manager.board_cells[coord_a].update_visuals()
	for i in range(canvas_manager.loaded_constraint_pairs.size() - 1, -1, -1):
		var p = canvas_manager.loaded_constraint_pairs[i]
		if (p["a"] == coord_a and p["b"] == coord_b) or (p["a"] == coord_b and p["b"] == coord_a):
			canvas_manager.loaded_constraint_pairs.remove_at(i)
	canvas_manager.loaded_constraint_pairs.append({"a": coord_a, "b": coord_b, "type": type})
	canvas_manager.show_editor_hints = true
	editor_ui.set_editor_hint_toggle(true)
	canvas_manager.trigger_redraw()

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

func _on_test_mode_entered():
	var editor_bg = get_node_or_null("EditorBackground")
	var game_bg = get_node_or_null("GameBackground")
	if editor_bg:
		editor_bg.visible = false
	if game_bg:
		game_bg.visible = true
		if game_bg is Control:
			game_bg.global_position = Vector2.ZERO
			game_bg.size = get_viewport_rect().size
			if game_bg is TextureRect:
				game_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	link_first_selection = null
	editor_ui.toggle_editor_visibility(true)
	playtest_controller.enter(current_level_required_jokers)
	_recenter_editor_layout(canvas_manager.grid_width, canvas_manager.grid_height)

func _on_playtest_rules_requested():
	if not playtest_controller.is_active:
		return
	playtest_controller.pause_timer()
	pt_ui.show_how_to_play()

func _on_test_mode_exited():
	playtest_controller.exit()
	link_first_selection = null
	var editor_bg = get_node_or_null("EditorBackground")
	var game_bg = get_node_or_null("GameBackground")
	if editor_bg:
		editor_bg.visible = true
	if game_bg:
		game_bg.visible = false
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

func _execute_save():
	var level_num = editor_ui.get_level_number()
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
	new_level_resource.shifter_pairs = canvas_manager.loaded_shifter_pairs.duplicate(true)
	new_level_resource.constraint_pairs = canvas_manager.loaded_constraint_pairs.duplicate(true)
	new_level_resource.time_limit = editor_ui.get_time_limit()
	new_level_resource.available_tiles = editor_ui.get_allowed_tiles()

	if not DirAccess.dir_exists_absolute(GameConstants.DEV_LEVELS_DIR):
		DirAccess.make_dir_absolute(GameConstants.DEV_LEVELS_DIR)

	var target_save_path = GameConstants.DEV_LEVELS_DIR + "level_%d.tres" % level_num
	var save_result = ResourceSaver.save(new_level_resource, target_save_path)
	if save_result == OK:
		editor_ui.update_status("CUSTOM LEVEL " + str(level_num) + " SAVED SUCCESSFULLY.", Color(0.4, 1.0, 0.4))
	else:
		editor_ui.update_status("ERROR: CUSTOM LEVEL " + str(level_num) + " SAVE FAILED (" + error_string(save_result).to_upper() + ").", Color(1.0, 0.4, 0.4))

func _on_load_level():
	if playtest_controller.is_active:
		return
	var level_num = editor_ui.get_level_number()
	var target_load_path = GameConstants.DEV_LEVELS_DIR + "level_%d.tres" % level_num
	if not ResourceLoader.exists(target_load_path):
		editor_ui.update_status("NO SAVED DATA FOUND FOR CUSTOM LEVEL " + str(level_num) + ".", Color(1.0, 0.8, 0.2))
		return

	var loaded_level = load(target_load_path) as LevelData
	if not loaded_level:
		editor_ui.update_status("ERROR: FAILED TO READ CUSTOM LEVEL " + str(level_num) + " DATA.", Color(1.0, 0.4, 0.4))
		return

	link_first_selection = null
	var dims := LevelUtils.get_dimensions_from_level(loaded_level)
	canvas_manager.generate_blank_canvas(dims.x, dims.y)
	canvas_manager.load_layout(dims.x, dims.y, loaded_level.layout, LevelUtils.get_shifter_pairs(loaded_level), loaded_level.constraint_pairs)
	current_level_required_jokers = loaded_level.get("required_jokers") if "required_jokers" in loaded_level else -1
	_recenter_editor_layout(dims.x, dims.y)
	editor_ui.set_time_limit(loaded_level.time_limit)
	var raw_tiles = loaded_level.available_tiles if loaded_level.available_tiles.size() > 0 else [0, 1, 2]
	var sanitized_tiles: Array = []
	for tile in raw_tiles:
		sanitized_tiles.append(int(tile))
	editor_ui.set_allowed_tiles(sanitized_tiles)
	editor_ui.sync_size_displays(dims.x, dims.y)
	editor_ui.update_status("CUSTOM LEVEL " + str(level_num) + " LOADED SUCCESSFULLY.", Color(0.4, 1.0, 0.4))
	_update_editor_joker_counter_display()
	_rebuild_editor_hidden_hints()
	_record_editor_change()

func _on_main_menu():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _rebuild_editor_hidden_hints():
	canvas_manager.hidden_constraint_pairs = HintSystem.rebuild_hidden_hints(
		canvas_manager.board_cells,
		canvas_manager.loaded_constraint_pairs,
		canvas_manager.grid_width,
		canvas_manager.grid_height,
		editor_ui.get_allowed_tiles()
	)
