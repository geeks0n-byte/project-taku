extends Node2D

const DEV_LEVELS_DIR = "user://levels/"

@onready var ui_manager: EditorUIManager = $EditorUIManager
@onready var canvas_manager: EditorCanvasManager = $EditorCanvasManager

var current_brush_state: int = -1 
var is_playtesting: bool = false
var playtest_snapshot: Dictionary = {}

var link_first_selection = null 

var playtest_timer: Timer
var playtest_time_remaining: int = 0
var playtest_shifter_moves: int = 0

var playtest_hidden_constraints: Array = []
var solved_solution_reference: Dictionary = {}

var playtest_required_jokers: int = 0 
var current_level_required_jokers: int = -1 

var pt_undo_stack: Array = []
var pt_redo_stack: Array = []
var pt_current_state_record: Dictionary = {}

var editor_undo_stack: Array = []
var editor_redo_stack: Array = []
var editor_current_state: Dictionary = {}

func _ready():
	_bind_signals()
	
	playtest_timer = Timer.new()
	playtest_timer.wait_time = 1.0
	playtest_timer.timeout.connect(_on_playtest_timer_timeout)
	add_child(playtest_timer)
	
	ui_manager.setup_ui(canvas_manager.grid_width, canvas_manager.grid_height, canvas_manager.CELL_SIZE)
	canvas_manager.generate_blank_canvas(canvas_manager.grid_width, canvas_manager.grid_height)
	_recenter_editor_layout(canvas_manager.grid_width, canvas_manager.grid_height)
	
	_update_editor_joker_counter_display()
	solved_solution_reference.clear()
	
	editor_current_state = _create_editor_snapshot()
	ui_manager.update_editor_undo_redo_buttons(false, false)

func _recenter_editor_layout(width: int, height: int) -> void:
	var board_pixel_width = width * canvas_manager.CELL_SIZE
	var board_pixel_height = height * canvas_manager.CELL_SIZE
	var screen_width = get_viewport_rect().size.x
	var screen_height = get_viewport_rect().size.y
	
	var centered_board_x = (screen_width - board_pixel_width) / 2.0
	var centered_board_y = 0.0
	
	var top_hud_bottom = 195.0
	var fixed_gap = 40.0
	
	if height <= 7:
		centered_board_y = (screen_height / 3.0) - (board_pixel_height / 2.0)
		if centered_board_y < (top_hud_bottom + fixed_gap):
			centered_board_y = top_hud_bottom + fixed_gap
	else:
		centered_board_y = top_hud_bottom + fixed_gap
	
	canvas_manager.position = Vector2(centered_board_x, centered_board_y)
	
	if ui_manager.has_method("update_dynamic_editor_layout"):
		ui_manager.update_dynamic_editor_layout(centered_board_y, board_pixel_height)

func _bind_signals():
	ui_manager.brush_changed.connect(_on_brush_changed)
	ui_manager.save_requested.connect(_on_save_level)
	ui_manager.load_requested.connect(_on_load_level) 
	ui_manager.clear_requested.connect(_on_clear_board) 
	ui_manager.random_requested.connect(_on_random_board_requested)
	ui_manager.main_menu_requested.connect(_on_main_menu)
	ui_manager.test_mode_entered.connect(_on_test_mode_entered)
	ui_manager.test_mode_exited.connect(_on_test_mode_exited)
	ui_manager.grid_size_changed.connect(_on_grid_size_changed) 
	ui_manager.overwrite_confirmed.connect(_execute_save)
	canvas_manager.canvas_cell_clicked.connect(_on_canvas_cell_clicked)
	
	ui_manager.editor_hint_toggled.connect(_on_editor_hint_toggled)
	ui_manager.editor_undo_requested.connect(_on_editor_undo_requested)
	ui_manager.editor_redo_requested.connect(_on_editor_undo_requested)
	ui_manager.editor_redo_requested.connect(_on_editor_redo_requested)
	
	ui_manager.playtest_reset_requested.connect(_on_playtest_reset_requested)
	ui_manager.playtest_rules_requested.connect(_on_playtest_rules_requested)
	ui_manager.playtest_hint_requested.connect(_on_playtest_hint_requested)
	ui_manager.playtest_undo_requested.connect(_on_playtest_undo_requested)
	ui_manager.playtest_redo_requested.connect(_on_playtest_redo_requested)
	ui_manager.resume_from_tutorial_requested.connect(_on_resume_from_tutorial)
	ui_manager.allowed_tiles_changed.connect(_on_allowed_tiles_changed) 

func _on_editor_hint_toggled(is_on: bool):
	if is_playtesting: return
	canvas_manager.show_editor_hints = is_on
	if is_on:
		_rebuild_editor_hidden_hints()
	canvas_manager.trigger_redraw()

func _create_editor_snapshot() -> Dictionary:
	var snap = {}
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
	var cells = snap["cells"]
	for coord in cells:
		var cell = canvas_manager.board_cells[coord]
		cell.state = cells[coord]["state"]
		cell.shifter_direction = cells[coord]["shifter_direction"]
		cell.is_locked = cells[coord]["is_locked"]
		cell.is_playable = cells[coord]["is_playable"]
		cell.is_linked_pair = cells[coord]["is_linked_pair"]
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
		
	editor_undo_stack.append(editor_current_state)
	editor_redo_stack.clear()
	editor_current_state = _create_editor_snapshot()
	ui_manager.update_editor_undo_redo_buttons(editor_undo_stack.size() > 0, false)

func _on_editor_undo_requested():
	if editor_undo_stack.is_empty(): return
	editor_redo_stack.append(editor_current_state)
	var prev = editor_undo_stack.pop_back()
	_apply_editor_snapshot(prev)
	editor_current_state = prev
	ui_manager.update_editor_undo_redo_buttons(editor_undo_stack.size() > 0, editor_redo_stack.size() > 0)

func _on_editor_redo_requested():
	if editor_redo_stack.is_empty(): return
	editor_undo_stack.append(editor_current_state)
	var next = editor_redo_stack.pop_back()
	_apply_editor_snapshot(next)
	editor_current_state = next
	ui_manager.update_editor_undo_redo_buttons(editor_undo_stack.size() > 0, editor_redo_stack.size() > 0)

func _on_allowed_tiles_changed():
	if is_playtesting: return
	ui_manager.update_status("", Color.WHITE)
	_update_editor_joker_counter_display()

func _on_random_board_requested():
	if is_playtesting: return
	
	var target_w = canvas_manager.grid_width
	var target_h = canvas_manager.grid_height
	
	ui_manager.sync_size_displays(target_w, target_h)
	
	var lock_walls = false
	if ui_manager.has_method("is_keep_walls_requested"):
		lock_walls = ui_manager.is_keep_walls_requested()
		
	var current_layout = {}
	if lock_walls:
		for c in canvas_manager.board_cells:
			if canvas_manager.board_cells[c].state == -2:
				current_layout[c] = -2
	
	var require_unique = true
	if ui_manager.has_method("is_unique_solution_required"):
		require_unique = ui_manager.is_unique_solution_required()
	
	var generated = PuzzleGenerator.generate_random_layout(target_w, target_h, ui_manager.get_allowed_tiles(), current_layout, require_unique, lock_walls)
	
	if generated.is_empty() or not generated.has("layout"):
		if lock_walls:
			ui_manager.update_status("GENERATION FAILED: THE LOCKED WALLS MAKE A VALID SOLUTION IMPOSSIBLE.", Color(1.0, 0.4, 0.4))
		else:
			ui_manager.update_status("GENERATION FAILED: THE CONSTRAINTS ARE TOO RESTRICTIVE FOR THIS GRID SIZE.", Color(1.0, 0.4, 0.4))
		return
		
	current_level_required_jokers = generated.get("total_jokers", 0)
	
	canvas_manager.generate_blank_canvas(target_w, target_h)
	canvas_manager.load_layout(target_w, target_h, generated["layout"], generated["shifters"], generated["constraints"])
	
	canvas_manager.hidden_constraint_pairs = generated.get("hidden_hints", []).duplicate(true)
	
	_recenter_editor_layout(target_w, target_h)
	ui_manager.update_status("", Color.WHITE)
	_update_editor_joker_counter_display()
	_record_editor_change()

func _on_grid_size_changed(new_width: int, new_height: int):
	if is_playtesting: return
	link_first_selection = null
	current_level_required_jokers = -1
	solved_solution_reference.clear()
	canvas_manager.hidden_constraint_pairs.clear()
	
	canvas_manager.generate_blank_canvas(new_width, new_height)
	_recenter_editor_layout(new_width, new_height)
	_update_editor_joker_counter_display()
	
	editor_undo_stack.clear()
	editor_redo_stack.clear()
	editor_current_state = _create_editor_snapshot()
	ui_manager.update_editor_undo_redo_buttons(false, false)

func _on_brush_changed(state_id: int, _brush_name: String):
	if is_playtesting: return
	
	if link_first_selection != null:
		var cell = canvas_manager.board_cells[link_first_selection]
		cell.update_visuals() 
		ui_manager.update_status("PLACEMENT ABORTED.", Color.WHITE)
	else:
		ui_manager.update_status("", Color.WHITE)
		
	current_brush_state = state_id
	link_first_selection = null

func _on_canvas_cell_clicked(coord: Vector2i):
	var cell = canvas_manager.board_cells[coord]
	
	if is_playtesting:
		canvas_manager.clear_highlights()
		
		if cell.is_locked: return 
		var allowed = ui_manager.get_allowed_tiles()
		
		if cell.state == 3:
			var partner_coord = coord + cell.shifter_direction
			if canvas_manager.board_cells.has(partner_coord):
				var partner = canvas_manager.board_cells[partner_coord]
				
				if partner.state == 3:
					partner.set_error_highlight()
					ui_manager.update_playtest_status("No space to move! The cell is occupied by another [color=#9c27b0]Purple[/color] tile.", Color.WHITE)
					return
					
				cell.state = -1
				cell.shifter_direction = Vector2i.ZERO 
				partner.state = 3
				partner.shifter_direction = coord - partner_coord 
				partner.update_visuals()
				
				playtest_shifter_moves += 1
				if ui_manager.has_method("update_playtest_hud"):
					_update_playtest_hud_wrapper()
				canvas_manager.trigger_redraw() 
		else:
			if cell.state == -1:
				cell.state = allowed[0] 
			else:
				var current_idx = allowed.find(cell.state)
				if current_idx == -1 or current_idx == allowed.size() - 1:
					cell.state = -1 
				else:
					cell.state = allowed[current_idx + 1] 
					
		cell.update_visuals()
		_update_playtest_joker_count()
		_run_playtest_validation_pass()
		
		var new_state = _create_playtest_snapshot()
		pt_undo_stack.append(pt_current_state_record)
		
		if pt_undo_stack.size() > 5:
			pt_undo_stack.pop_front()
			
		pt_redo_stack.clear()
		pt_current_state_record = new_state
		ui_manager.update_undo_redo_buttons(pt_undo_stack.size() > 0, false)

	else:
		var pre_state = cell.state
		var pre_lock = cell.is_locked
		var pre_shifter = canvas_manager.loaded_shifter_pairs.size()
		var pre_const = canvas_manager.loaded_constraint_pairs.size()

		if current_brush_state >= 3 and current_brush_state <= 5:
			if link_first_selection == null:
				link_first_selection = coord
				cell.set_mask_color(Color(1.0, 1.0, 1.0, 0.4))
				
				if current_brush_state == 3:
					ui_manager.update_status("SELECT A NEIGHBORING CELL TO PLACE THE SECOND [color=#9c27b0]PURPLE[/color] TILE.", Color.YELLOW)
				elif current_brush_state == 4:
					ui_manager.update_status("SELECT A NEIGHBORING CELL TO PLACE THE EQUALS (=) LINK.", Color.YELLOW)
				elif current_brush_state == 5:
					ui_manager.update_status("SELECT A NEIGHBORING CELL TO PLACE THE NOT-EQUALS (×) LINK.", Color.YELLOW)
			else:
				var first_coord = link_first_selection
				link_first_selection = null
				
				if first_coord == coord:
					var first_cell = canvas_manager.board_cells[first_coord]
					first_cell.update_visuals() 
					ui_manager.update_status("PLACEMENT ABORTED.", Color.WHITE)
					return
					
				var diff = (coord - first_coord).abs()
				if (diff.x == 1 and diff.y == 0) or (diff.x == 0 and diff.y == 1):
					if current_brush_state == 3:
						_execute_pair_link_creation(first_coord, coord)
						ui_manager.update_status("[color=#9c27b0]PURPLE[/color] TILE PAIR PLACED SUCCESSFULLY.", Color(0.4, 1.0, 0.4))
					elif current_brush_state == 4:
						_execute_constraint_creation(first_coord, coord, "equals")
						ui_manager.update_status("EQUALS (=) LINK PLACED SUCCESSFULLY.", Color(0.4, 1.0, 0.4))
					elif current_brush_state == 5:
						_execute_constraint_creation(first_coord, coord, "not_equals")
						ui_manager.update_status("NOT-EQUALS (×) LINK PLACED SUCCESSFULLY.", Color(0.4, 1.0, 0.4))
					
					_record_editor_change()
				else:
					var first_cell = canvas_manager.board_cells[first_coord]
					first_cell.update_visuals() 
					ui_manager.update_status("PLACEMENT ABORTED: CELLS MUST BE ADJACENT.", Color(1.0, 0.4, 0.4))
			return

		if current_brush_state == -1:
			_remove_constraint_by_coord(coord)
		
		if cell.is_linked_pair: 
			_remove_pair_by_coord(coord)
					
		cell.state = current_brush_state
		if current_brush_state == -2:
			cell.is_playable = false
			cell.is_locked = true
		elif current_brush_state != -1:
			cell.is_playable = true
			cell.is_locked = true
		else:
			cell.is_playable = true
			cell.is_locked = false
		cell.update_visuals()
		
		ui_manager.update_status("", Color.WHITE)
		_update_editor_joker_counter_display()

		if cell.state != pre_state or cell.is_locked != pre_lock or canvas_manager.loaded_shifter_pairs.size() != pre_shifter or canvas_manager.loaded_constraint_pairs.size() != pre_const:
			_record_editor_change()

func _update_editor_joker_counter_display():
	if is_playtesting: return
	var prefilled_jokers = 0
	var is_empty = true
	
	for coord in canvas_manager.board_cells:
		var st = canvas_manager.board_cells[coord].state
		if st == 2:
			prefilled_jokers += 1
		if st != -1: 
			is_empty = false
			
	var total_required = current_level_required_jokers
	if total_required == -1:
		total_required = min(canvas_manager.grid_width, canvas_manager.grid_height)
		
	total_required = max(0, total_required)
	
	var has_jokers = (total_required > 0) and not is_empty
	ui_manager.set_playtest_joker_counter_visibility(has_jokers)
	
	ui_manager.update_playtest_joker_counter(prefilled_jokers, total_required)

func _execute_pair_link_creation(coord_a: Vector2i, coord_b: Vector2i):
	var pairs_to_remove = []
	for i in range(canvas_manager.loaded_shifter_pairs.size() - 1, -1, -1):
		var p = canvas_manager.loaded_shifter_pairs[i]
		if p["active"] == coord_a:
			pairs_to_remove.append(i)
		elif (p["a"] == coord_a and p["b"] == coord_b) or (p["a"] == coord_b and p["b"] == coord_a):
			if not pairs_to_remove.has(i): pairs_to_remove.append(i)
			
	pairs_to_remove.sort()
	pairs_to_remove.reverse()
	
	var changed_cells = [coord_a, coord_b]
	for idx in pairs_to_remove:
		var p = canvas_manager.loaded_shifter_pairs[idx]
		if not changed_cells.has(p["a"]): changed_cells.append(p["a"])
		if not changed_cells.has(p["b"]): changed_cells.append(p["b"])
		canvas_manager.loaded_shifter_pairs.remove_at(idx)
		
	var new_pair = {"a": coord_a, "b": coord_b, "active": coord_a}
	canvas_manager.loaded_shifter_pairs.append(new_pair)
	
	for c in changed_cells:
		_recalculate_cell_pair_state(c)
		
	canvas_manager.trigger_redraw()

func _remove_pair_by_coord(coord: Vector2i):
	var changed_cells = []
	for i in range(canvas_manager.loaded_shifter_pairs.size() - 1, -1, -1):
		var p = canvas_manager.loaded_shifter_pairs[i]
		if p["a"] == coord or p["b"] == coord:
			if not changed_cells.has(p["a"]): changed_cells.append(p["a"])
			if not changed_cells.has(p["b"]): changed_cells.append(p["b"])
			canvas_manager.loaded_shifter_pairs.remove_at(i)
			
	for c in changed_cells:
		_recalculate_cell_pair_state(c)
		
	canvas_manager.trigger_redraw()

func _recalculate_cell_pair_state(c: Vector2i):
	if not canvas_manager.board_cells.has(c): return
	var cell = canvas_manager.board_cells[c]
	var is_active_in_any = false
	var is_target_in_any = false
	var new_direction = Vector2i.ZERO
	
	for p in canvas_manager.loaded_shifter_pairs:
		if p["active"] == c:
			is_active_in_any = true
			var partner = p["b"] if p["a"] == c else p["a"]
			new_direction = partner - c
		elif p["a"] == c or p["b"] == c:
			is_target_in_any = true
			
	if is_active_in_any:
		cell.is_linked_pair = true
		cell.state = 3
		cell.shifter_direction = new_direction
		cell.is_locked = false
	elif is_target_in_any:
		cell.is_linked_pair = true
		cell.state = -1
		cell.shifter_direction = Vector2i.ZERO
		cell.is_locked = false
	else:
		cell.is_linked_pair = false
		cell.state = -1
		cell.shifter_direction = Vector2i.ZERO
		cell.is_locked = false
		
	cell.update_visuals()

func _execute_constraint_creation(coord_a: Vector2i, coord_b: Vector2i, type: String):
	var first_cell = canvas_manager.board_cells[coord_a]
	first_cell.update_visuals() 
	
	for i in range(canvas_manager.loaded_constraint_pairs.size() - 1, -1, -1):
		var p = canvas_manager.loaded_constraint_pairs[i]
		if (p["a"] == coord_a and p["b"] == coord_b) or (p["a"] == coord_b and p["b"] == coord_a):
			canvas_manager.loaded_constraint_pairs.remove_at(i)
			
	var new_constraint = {"a": coord_a, "b": coord_b, "type": type}
	canvas_manager.loaded_constraint_pairs.append(new_constraint)
	
	canvas_manager.show_editor_hints = true
	ui_manager.set_editor_hint_toggle(true)
	canvas_manager.trigger_redraw()

func _remove_constraint_by_coord(coord: Vector2i):
	for i in range(canvas_manager.loaded_constraint_pairs.size() - 1, -1, -1):
		var p = canvas_manager.loaded_constraint_pairs[i]
		if p["a"] == coord or p["b"] == coord:
			canvas_manager.loaded_constraint_pairs.remove_at(i)
	canvas_manager.trigger_redraw()

func _on_clear_board():
	if is_playtesting: return
	canvas_manager.loaded_shifter_pairs.clear()
	canvas_manager.loaded_constraint_pairs.clear() 
	canvas_manager.hidden_constraint_pairs.clear()
	link_first_selection = null
	current_level_required_jokers = -1
	solved_solution_reference.clear()
	
	var keep_walls = false
	if ui_manager.has_method("is_keep_walls_requested"):
		keep_walls = ui_manager.is_keep_walls_requested()
	
	for coord in canvas_manager.board_cells:
		var cell = canvas_manager.board_cells[coord]
		
		if keep_walls and cell.state == -2:
			cell.is_linked_pair = false 
			cell.update_visuals()
			continue
			
		cell.state = -1
		cell.shifter_direction = Vector2i.ZERO 
		cell.is_playable = true
		cell.is_linked_pair = false 
		cell.is_locked = false
		cell.update_visuals()
		
	canvas_manager.trigger_redraw()
	ui_manager.update_status("", Color.WHITE)
	_update_editor_joker_counter_display()
	_record_editor_change()

func _create_playtest_snapshot() -> Dictionary:
	var snap = {}
	for coord in canvas_manager.board_cells:
		var cell = canvas_manager.board_cells[coord]
		snap[coord] = {
			"state": cell.state,
			"shifter_direction": cell.shifter_direction
		}
	return {
		"cells": snap,
		"moves": playtest_shifter_moves
	}

func _apply_playtest_snapshot(snap: Dictionary):
	playtest_shifter_moves = snap["moves"]
	var cells = snap["cells"]
	for coord in cells:
		var cell = canvas_manager.board_cells[coord]
		cell.state = cells[coord]["state"]
		cell.shifter_direction = cells[coord]["shifter_direction"]
		cell.update_visuals()
		
	_update_playtest_joker_count()
	if ui_manager.has_method("update_playtest_hud"):
		_update_playtest_hud_wrapper()
	canvas_manager.trigger_redraw()
	_run_playtest_validation_pass()

func _on_playtest_undo_requested():
	if not is_playtesting or pt_undo_stack.is_empty(): return
	pt_redo_stack.append(pt_current_state_record)
	var prev_state = pt_undo_stack.pop_back()
	_apply_playtest_snapshot(prev_state)
	pt_current_state_record = prev_state
	ui_manager.update_undo_redo_buttons(pt_undo_stack.size() > 0, pt_redo_stack.size() > 0)

func _on_playtest_redo_requested():
	if not is_playtesting or pt_redo_stack.is_empty(): return
	pt_undo_stack.append(pt_current_state_record)
	
	if pt_undo_stack.size() > 5:
		pt_undo_stack.pop_front()
		
	var next_state = pt_redo_stack.pop_back()
	_apply_playtest_snapshot(next_state)
	pt_current_state_record = next_state
	ui_manager.update_undo_redo_buttons(pt_undo_stack.size() > 0, pt_redo_stack.size() > 0)

func _update_playtest_joker_count():
	var count = 0
	for coord in canvas_manager.board_cells:
		if canvas_manager.board_cells[coord].state == 2 and not canvas_manager.board_cells[coord].is_locked:
			count += 1
	ui_manager.update_playtest_joker_counter(count, playtest_required_jokers)

func _get_usable_hints_count() -> int:
	if solved_solution_reference.is_empty(): return 0
	var count = 0
	
	var actual_w = canvas_manager.grid_width
	var actual_h = canvas_manager.grid_height
	
	for y in range(actual_h):
		for x in range(actual_w):
			var c = Vector2i(x, y)
			var right = c + Vector2i(1, 0)
			var down = c + Vector2i(0, 1)
			
			if _is_hint_usable(c, right): count += 1
			if _is_hint_usable(c, down): count += 1
			
	return count

func _is_hint_usable(coord_a: Vector2i, coord_b: Vector2i) -> bool:
	if not solved_solution_reference.has(coord_a) or not solved_solution_reference.has(coord_b): return false
	
	var sol_a = solved_solution_reference[coord_a]
	var sol_b = solved_solution_reference[coord_b]
	
	if not (sol_a in [0, 1] and sol_b in [0, 1]): return false
	
	for active in canvas_manager.loaded_constraint_pairs:
		if (active["a"] == coord_a and active["b"] == coord_b) or (active["a"] == coord_b and active["b"] == coord_a):
			return false
			
	var state_a = canvas_manager.board_cells[coord_a].state
	var state_b = canvas_manager.board_cells[coord_b].state
	
	var a_filled = (state_a == 0 or state_a == 1)
	var b_filled = (state_b == 0 or state_b == 1)
	
	if a_filled and b_filled:
		var type = "equals" if sol_a == sol_b else "not_equals"
		var is_satisfied = false
		if type == "equals" and state_a == state_b: is_satisfied = true
		elif type == "not_equals" and state_a != state_b: is_satisfied = true
		if is_satisfied: return false
		
	return true

func _on_test_mode_entered():
	is_playtesting = true
	canvas_manager.is_playtesting = true
	playtest_snapshot.clear()
	link_first_selection = null
	
	var editor_bg = get_node_or_null("EditorBackground")
	var game_bg = get_node_or_null("GameBackground")
	if editor_bg: editor_bg.visible = false
	if game_bg: 
		game_bg.visible = true
		if game_bg is Control:
			game_bg.global_position = Vector2.ZERO
			game_bg.size = get_viewport_rect().size
			if game_bg is TextureRect:
				game_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	
	var prefilled_jokers = 0
	
	for coord in canvas_manager.board_cells:
		var cell = canvas_manager.board_cells[coord]
		
		playtest_snapshot[coord] = {
			"state": cell.state,
			"shifter_direction": cell.shifter_direction
		}
		
		if cell.state == 2:
			prefilled_jokers += 1
		
		if cell.state == -2:
			cell.is_playable = false
			cell.is_locked = true
		elif cell.state != -1 and cell.state != 3:
			cell.is_playable = true
			cell.is_locked = true
		else:
			cell.is_playable = true
			cell.is_locked = false
		cell.is_editor_mode = false
		cell.update_visuals()
	
	playtest_hidden_constraints = canvas_manager.loaded_constraint_pairs.duplicate(true)
	
	var solve_layout = {}
	var empty_cells = []
	for c in canvas_manager.board_cells:
		var cell = canvas_manager.board_cells[c]
		if cell.state == 3:
			solve_layout[c] = -1
			empty_cells.append(c)
		else:
			solve_layout[c] = cell.state
			if cell.state == -1:
				empty_cells.append(c)
				
	var tiles_list = ui_manager.get_allowed_tiles()
	var test_layout = solve_layout.duplicate()
	var test_empty = empty_cells.duplicate()
	
	if PuzzleGenerator._solve(test_layout, test_empty, canvas_manager.grid_width, canvas_manager.grid_height, tiles_list, canvas_manager.loaded_constraint_pairs, {"count": 0}):
		solved_solution_reference = test_layout
	else:
		solved_solution_reference = {} 
		
	playtest_time_remaining = ui_manager.get_time_limit()
	playtest_shifter_moves = 0
	
	ui_manager.set_playtest_move_counter_visibility(canvas_manager.loaded_shifter_pairs.size() > 0)
	
	if current_level_required_jokers == -1:
		playtest_required_jokers = min(canvas_manager.grid_width, canvas_manager.grid_height)
	else:
		playtest_required_jokers = current_level_required_jokers
		
	playtest_required_jokers = max(0, playtest_required_jokers - prefilled_jokers)
	
	var has_jokers = (2 in ui_manager.get_allowed_tiles()) and (playtest_required_jokers > 0)
	ui_manager.set_playtest_joker_counter_visibility(has_jokers)
	_update_playtest_joker_count()
	
	pt_undo_stack.clear()
	pt_redo_stack.clear()
	pt_current_state_record = _create_playtest_snapshot()
	
	ui_manager.toggle_playtest_visibility(true)
	
	if ui_manager.has_method("update_playtest_hud"):
		_update_playtest_hud_wrapper()
		
	_recenter_editor_layout(canvas_manager.grid_width, canvas_manager.grid_height)
	
	playtest_timer.start()
	canvas_manager.trigger_redraw()
	_run_playtest_validation_pass()

func _on_playtest_reset_requested():
	if not is_playtesting: return
	
	playtest_timer.stop()
	ui_manager.hide_victory_overlay()
	
	for coord in canvas_manager.board_cells:
		var cell = canvas_manager.board_cells[coord]
		cell.clear_highlight()
		
		var restored = playtest_snapshot[coord]
		cell.state = restored["state"]
		cell.shifter_direction = restored["shifter_direction"]
		
		if cell.state == -2:
			cell.is_playable = false
			cell.is_locked = true
		elif cell.state != -1 and cell.state != 3:
			cell.is_playable = true
			cell.is_locked = true
		else:
			cell.is_playable = true
			cell.is_locked = false
		cell.is_editor_mode = false
		cell.update_visuals()
		
	canvas_manager.loaded_constraint_pairs = playtest_hidden_constraints.duplicate(true)
	
	playtest_time_remaining = ui_manager.get_time_limit()
	playtest_shifter_moves = 0
	
	ui_manager.set_playtest_move_counter_visibility(canvas_manager.loaded_shifter_pairs.size() > 0)
	
	_update_playtest_joker_count()
	
	pt_undo_stack.clear()
	pt_redo_stack.clear()
	pt_current_state_record = _create_playtest_snapshot()
	
	if ui_manager.has_method("update_playtest_hud"):
		_update_playtest_hud_wrapper()
	
	playtest_timer.start()
	canvas_manager.trigger_redraw()
	_run_playtest_validation_pass()

func _on_playtest_rules_requested():
	if not is_playtesting: return
	playtest_timer.stop()
	if ui_manager.has_method("show_how_to_play"):
		ui_manager.show_how_to_play()

func _on_resume_from_tutorial():
	if is_playtesting:
		playtest_timer.start()
		ui_manager.update_undo_redo_buttons(pt_undo_stack.size() > 0, pt_redo_stack.size() > 0)
		ui_manager.set_hint_button_disabled(_get_usable_hints_count() == 0)

func _on_playtest_hint_requested():
	if not is_playtesting: return
	if solved_solution_reference.is_empty(): return
	
	var priority_1 = []
	var priority_2 = []
	var priority_3 = []
	
	var actual_w = canvas_manager.grid_width
	var actual_h = canvas_manager.grid_height
	
	for y in range(actual_h):
		for x in range(actual_w):
			var c = Vector2i(x, y)
			var right = c + Vector2i(1, 0)
			var down = c + Vector2i(0, 1)
			
			_evaluate_hint_candidate(c, right, priority_1, priority_2, priority_3)
			_evaluate_hint_candidate(c, down, priority_1, priority_2, priority_3)
			
	var selected_hint = null
	if priority_1.size() > 0:
		selected_hint = priority_1.pick_random()
	elif priority_2.size() > 0:
		selected_hint = priority_2.pick_random()
	elif priority_3.size() > 0:
		selected_hint = priority_3.pick_random()
		
	if selected_hint != null:
		canvas_manager.loaded_constraint_pairs.append(selected_hint)
		canvas_manager.trigger_redraw()
		
		# We do NOT push a state to the undo stack here, so hints are permanent.
		_run_playtest_validation_pass()

func _evaluate_hint_candidate(coord_a: Vector2i, coord_b: Vector2i, p1: Array, p2: Array, p3: Array):
	if not solved_solution_reference.has(coord_a) or not solved_solution_reference.has(coord_b): return
	
	var sol_a = solved_solution_reference[coord_a]
	var sol_b = solved_solution_reference[coord_b]
	
	if not (sol_a in [0, 1] and sol_b in [0, 1]): return
	
	for active in canvas_manager.loaded_constraint_pairs:
		if (active["a"] == coord_a and active["b"] == coord_b) or (active["a"] == coord_b and active["b"] == coord_a):
			return 
			
	var type = "equals" if sol_a == sol_b else "not_equals"
	var candidate = {"a": coord_a, "b": coord_b, "type": type}
	
	var state_a = canvas_manager.board_cells[coord_a].state
	var state_b = canvas_manager.board_cells[coord_b].state
	
	var a_filled = (state_a == 0 or state_a == 1)
	var b_filled = (state_b == 0 or state_b == 1)
	var a_empty = (state_a == -1)
	var b_empty = (state_b == -1)
	
	if (state_a != -1 and not a_filled) or (state_b != -1 and not b_filled):
		p3.append(candidate)
		return
		
	if (a_filled and b_empty) or (b_filled and a_empty):
		p1.append(candidate)
	elif a_empty and b_empty:
		p2.append(candidate)
	elif a_filled and b_filled:
		var is_satisfied = false
		if type == "equals" and state_a == state_b: is_satisfied = true
		elif type == "not_equals" and state_a != state_b: is_satisfied = true
		
		if not is_satisfied:
			p3.append(candidate)

func _on_playtest_timer_timeout():
	if is_playtesting:
		if ui_manager.get_time_limit() == 0:
			return
			
		playtest_time_remaining -= 1
		if ui_manager.has_method("update_playtest_hud"):
			_update_playtest_hud_wrapper()
		
		if playtest_time_remaining <= 0:
			_trigger_playtest_defeat()

func _update_playtest_hud_wrapper():
	if ui_manager.get_time_limit() == 0:
		ui_manager.update_playtest_hud(0, playtest_shifter_moves)
	else:
		ui_manager.update_playtest_hud(playtest_time_remaining, playtest_shifter_moves)

func _on_test_mode_exited():
	is_playtesting = false
	canvas_manager.is_playtesting = false 
	playtest_timer.stop()
	ui_manager.hide_victory_overlay()
	link_first_selection = null
	
	var editor_bg = get_node_or_null("EditorBackground")
	var game_bg = get_node_or_null("GameBackground")
	if editor_bg: editor_bg.visible = true
	if game_bg: game_bg.visible = false
	
	for coord in canvas_manager.board_cells:
		var cell = canvas_manager.board_cells[coord]
		cell.clear_highlight()
		
		var restored = playtest_snapshot[coord]
		cell.state = restored["state"]
		cell.shifter_direction = restored["shifter_direction"]
		
		if cell.state == -2:
			cell.is_playable = false
			cell.is_locked = true
		elif cell.state != -1 and cell.state != 3:
			cell.is_playable = true
			cell.is_locked = true
		else:
			cell.is_playable = true
			cell.is_locked = false
		cell.is_editor_mode = true
		cell.update_visuals()
		
	canvas_manager.loaded_constraint_pairs = playtest_hidden_constraints.duplicate(true)
		
	canvas_manager.trigger_redraw()
	ui_manager.toggle_playtest_visibility(false)
	_update_editor_joker_counter_display()

func _run_playtest_validation_pass():
	canvas_manager.clear_highlights()
	var results = PuzzleValidator.validate_board(canvas_manager.board_cells, canvas_manager.cached_lines, canvas_manager.loaded_constraint_pairs, playtest_required_jokers)
	
	ui_manager.set_hint_button_disabled(_get_usable_hints_count() == 0)
	ui_manager.update_undo_redo_buttons(pt_undo_stack.size() > 0, pt_redo_stack.size() > 0)
	
	if not results["valid"]:
		ui_manager.update_playtest_status("\n".join(results["errors"]), Color.WHITE)
	else:
		ui_manager.update_playtest_status("Fill the empty spaces on the board.", Color.WHITE)
		
	if results["valid"] and canvas_manager.is_board_full():
		_trigger_playtest_victory()

func _trigger_playtest_victory():
	is_playtesting = false
	playtest_timer.stop()
	ui_manager.update_playtest_status("Puzzle solved!", Color(1.0, 0.84, 0.0))
	ui_manager.display_victory_overlay("GOOD JOB!\nLEVEL IS SOLVABLE")

func _trigger_playtest_defeat():
	is_playtesting = false
	playtest_timer.stop()
	ui_manager.update_playtest_status("Time's up! The puzzle remains unsolved.", Color(1.0, 0.3, 0.3))
	ui_manager.display_victory_overlay("DEFEAT!\nTIME RAN OUT")

func _on_save_level():
	if is_playtesting: return
	
	var level_num = ui_manager.get_level_number()
	var dev_path = DEV_LEVELS_DIR + "level_%d.tres" % level_num
	
	if ResourceLoader.exists(dev_path):
		ui_manager.show_overwrite_warning()
		return
			
	_execute_save()

func _execute_save():
	var level_num = ui_manager.get_level_number()
	var output_layout = {}
	
	for coord in canvas_manager.board_cells:
		var current_state = canvas_manager.board_cells[coord].state
		if current_state == 3:
			output_layout[coord] = -1
		else:
			output_layout[coord] = current_state
	
	var level_script_path = "res://level_data.gd"
	if not FileAccess.file_exists(level_script_path) and not ResourceLoader.exists(level_script_path):
		level_script_path = "res://scripts/level_data.gd" 
		
	var level_data_script = load(level_script_path)
	var new_level_resource = level_data_script.new()
	
	new_level_resource.level_number = level_num
	new_level_resource.width = canvas_manager.grid_width
	new_level_resource.height = canvas_manager.grid_height
	new_level_resource.layout = output_layout
	
	new_level_resource.set("required_jokers", current_level_required_jokers)
	
	var processed_pairs: Array = []
	for pair in canvas_manager.loaded_shifter_pairs:
		var active_pos = pair.get("active", pair["a"])
		processed_pairs.append({"a": pair["a"], "b": pair["b"], "active": active_pos})
	
	if "shifter_pairs" in new_level_resource:
		new_level_resource.shifter_pairs = processed_pairs
	else:
		new_level_resource.set("red_pairs", processed_pairs)
	
	if "constraint_pairs" in new_level_resource:
		new_level_resource.constraint_pairs = canvas_manager.loaded_constraint_pairs.duplicate(true) 
	else:
		new_level_resource.set("constraint_pairs", canvas_manager.loaded_constraint_pairs.duplicate(true))
	
	new_level_resource.time_limit = ui_manager.get_time_limit()
	new_level_resource.available_tiles = ui_manager.get_allowed_tiles()
	
	if not DirAccess.dir_exists_absolute(DEV_LEVELS_DIR):
		DirAccess.make_dir_absolute(DEV_LEVELS_DIR)
			
	var target_save_path = DEV_LEVELS_DIR + "level_%d.tres" % level_num
	var save_result = ResourceSaver.save(new_level_resource, target_save_path)
	
	if save_result == OK:
		ui_manager.update_status("CUSTOM LEVEL " + str(level_num) + " SAVED SUCCESSFULLY.", Color(0.4, 1.0, 0.4))
	else:
		ui_manager.update_status("ERROR: CUSTOM LEVEL " + str(level_num) + " SAVE FAILED (" + error_string(save_result).to_upper() + ").", Color(1.0, 0.4, 0.4))

func _on_load_level():
	if is_playtesting: return
	var level_num = ui_manager.get_level_number()
	var target_load_path = DEV_LEVELS_DIR + "level_%d.tres" % level_num

	if ResourceLoader.exists(target_load_path):
		var loaded_level = load(target_load_path) as LevelData
		if loaded_level:
			link_first_selection = null
			
			var actual_w = 3
			var actual_h = 3
			if loaded_level.layout.size() > 0:
				var max_x = 0
				var max_y = 0
				for coord in loaded_level.layout.keys():
					if coord.x > max_x: max_x = coord.x
					if coord.y > max_y: max_y = coord.y
				actual_w = max_x + 1
				actual_h = max_y + 1
			elif "width" in loaded_level and "height" in loaded_level:
				actual_w = loaded_level.width
				actual_h = loaded_level.height
			
			var s_pairs = []
			if "shifter_pairs" in loaded_level: s_pairs = loaded_level.shifter_pairs
			elif "red_pairs" in loaded_level: s_pairs = loaded_level.red_pairs
			
			var c_pairs = loaded_level.constraint_pairs if "constraint_pairs" in loaded_level else []
			current_level_required_jokers = loaded_level.get("required_jokers") if "required_jokers" in loaded_level else -1
			
			canvas_manager.generate_blank_canvas(actual_w, actual_h)
			canvas_manager.load_layout(actual_w, actual_h, loaded_level.layout, s_pairs, c_pairs)
			
			_recenter_editor_layout(actual_w, actual_h)
			
			if "time_limit" in loaded_level:
				ui_manager.set_time_limit(loaded_level.time_limit)
			
			var raw_tiles = loaded_level.available_tiles if "available_tiles" in loaded_level and loaded_level.available_tiles.size() > 0 else [0, 1, 2]
			var sanitized_tiles: Array = []
			for tile in raw_tiles:
				sanitized_tiles.append(int(tile))
				
			ui_manager.set_allowed_tiles(sanitized_tiles)
			ui_manager.sync_size_displays(actual_w, actual_h)
			ui_manager.update_status("CUSTOM LEVEL " + str(level_num) + " LOADED SUCCESSFULLY.", Color(0.4, 1.0, 0.4))
			_update_editor_joker_counter_display()
			
			_rebuild_editor_hidden_hints()
			_record_editor_change()
		else:
			ui_manager.update_status("ERROR: FAILED TO READ CUSTOM LEVEL " + str(level_num) + " DATA.", Color(1.0, 0.4, 0.4))
	else:
		ui_manager.update_status("NO SAVED DATA FOUND FOR CUSTOM LEVEL " + str(level_num) + ".", Color(1.0, 0.8, 0.2))

func _on_main_menu():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _rebuild_editor_hidden_hints():
	var solve_layout = {}
	var empty_cells = []
	for c in canvas_manager.board_cells:
		var cell = canvas_manager.board_cells[c]
		if cell.state == 3:
			solve_layout[c] = -1
			empty_cells.append(c)
		else:
			solve_layout[c] = cell.state
			if cell.state == -1:
				empty_cells.append(c)
				
	var test_layout = solve_layout.duplicate()
	var test_empty = empty_cells.duplicate()
	var tiles_list = ui_manager.get_allowed_tiles()
	
	if PuzzleGenerator._solve(test_layout, test_empty, canvas_manager.grid_width, canvas_manager.grid_height, tiles_list, canvas_manager.loaded_constraint_pairs, {"count": 0}):
		var rebuilt_hidden = []
		for y in range(canvas_manager.grid_height):
			for x in range(canvas_manager.grid_width):
				var c = Vector2i(x, y)
				if test_layout.has(c) and test_layout[c] in [0, 1]:
					var right = c + Vector2i(1, 0)
					var down = c + Vector2i(0, 1)
					
					if test_layout.has(right) and test_layout[right] in [0, 1]:
						var t = "equals" if test_layout[c] == test_layout[right] else "not_equals"
						if not _is_constraint_in_list(c, right, canvas_manager.loaded_constraint_pairs):
							rebuilt_hidden.append({"a": c, "b": right, "type": t})
							
					if test_layout.has(down) and test_layout[down] in [0, 1]:
						var t = "equals" if test_layout[c] == test_layout[down] else "not_equals"
						if not _is_constraint_in_list(c, down, canvas_manager.loaded_constraint_pairs):
							rebuilt_hidden.append({"a": c, "b": down, "type": t})
		canvas_manager.hidden_constraint_pairs = rebuilt_hidden
	else:
		canvas_manager.hidden_constraint_pairs.clear()

func _is_constraint_in_list(a: Vector2i, b: Vector2i, list: Array) -> bool:
	for p in list:
		if (p["a"] == a and p["b"] == b) or (p["a"] == b and p["b"] == a):
			return true
	return false
