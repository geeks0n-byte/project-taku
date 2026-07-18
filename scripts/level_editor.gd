extends Node2D

const CAMPAIGN_DIR = "res://levels/"
const DEV_LEVELS_DIR = "user://levels/"

@onready var ui_manager: EditorUIManager = $EditorUIManager
@onready var canvas_manager: EditorCanvasManager = $EditorCanvasManager
@onready var core_levels_container = find_child("CoreLevelsContainer", true, false)

var current_brush_state: int = -1 
var is_playtesting: bool = false
var playtest_snapshot: Dictionary = {}

var link_first_selection = null 

var playtest_timer: Timer
var playtest_time_remaining: int = 0
var playtest_shifter_moves: int = 0

var playtest_hidden_constraints: Array = []
var playtest_pending_hints: Array = []
var playtest_required_jokers: int = 0 
var current_level_required_jokers: int = -1 

func _ready():
	_bind_signals()
	
	playtest_timer = Timer.new()
	playtest_timer.wait_time = 1.0
	playtest_timer.timeout.connect(_on_playtest_timer_timeout)
	add_child(playtest_timer)
	
	ui_manager.setup_ui(canvas_manager.grid_width, canvas_manager.grid_height, canvas_manager.CELL_SIZE)
	canvas_manager.generate_blank_canvas(canvas_manager.grid_width, canvas_manager.grid_height)
	_recenter_editor_layout(canvas_manager.grid_width, canvas_manager.grid_height)
	_populate_core_levels_container()

func _recenter_editor_layout(width: int, height: int) -> void:
	var board_pixel_width = width * canvas_manager.CELL_SIZE
	var board_pixel_height = height * canvas_manager.CELL_SIZE
	var screen_width = get_viewport_rect().size.x
	var screen_height = get_viewport_rect().size.y
	
	var centered_board_x = (screen_width - board_pixel_width) / 2.0
	var centered_board_y = (screen_height / 3.0) - (board_pixel_height / 2.0)
	
	canvas_manager.position = Vector2(centered_board_x, centered_board_y)
	
	if ui_manager.has_method("update_dynamic_editor_layout"):
		ui_manager.update_dynamic_editor_layout(centered_board_y, board_pixel_height)
	else:
		if ui_manager.has_node("StatusLabel"):
			ui_manager.get_node("StatusLabel").global_position.y = centered_board_y + board_pixel_height + 30

func _populate_core_levels_container():
	if not core_levels_container: return
		
	for child in core_levels_container.get_children():
		child.queue_free()
		
	var title_lbl = Label.new()
	title_lbl.text = "CORE LEVELS:"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.modulate = Color(0.4, 1.0, 0.4)
	core_levels_container.add_child(title_lbl)
	
	var raw_paths = _scan_directory(CAMPAIGN_DIR)
	raw_paths.sort_custom(func(a, b):
		var num_a = int(a.get_file().get_basename().replace("level_", ""))
		var num_b = int(b.get_file().get_basename().replace("level_", ""))
		return num_a < num_b
	)
	
	var valid_count = 0
	for path in raw_paths:
		var res = load(path) as LevelData
		if res and not _is_layout_empty(res.layout):
			valid_count += 1
			var btn = Button.new()
			btn.text = str(res.level_number)
			btn.custom_minimum_size = Vector2(70, 70)
			btn.add_theme_font_size_override("font_size", 28)
			btn.pressed.connect(func(): _load_core_level(res))
			core_levels_container.add_child(btn)
			
	if valid_count == 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "No playable core levels found."
		core_levels_container.add_child(empty_lbl)

func _load_core_level(res: LevelData):
	if is_playtesting: return
	link_first_selection = null
	
	var actual_w = 3
	var actual_h = 3
	if res.layout.size() > 0:
		var max_x = 0
		var max_y = 0
		for coord in res.layout.keys():
			if coord.x > max_x: max_x = coord.x
			if coord.y > max_y: max_y = coord.y
		actual_w = max_x + 1
		actual_h = max_y + 1
	elif "width" in res and "height" in res:
		actual_w = res.width
		actual_h = res.height
	
	var s_pairs = []
	if "shifter_pairs" in res: s_pairs = res.shifter_pairs
	elif "red_pairs" in res: s_pairs = res.red_pairs
	
	var c_pairs = res.constraint_pairs if "constraint_pairs" in res else []
	current_level_required_jokers = res.get("required_jokers") if "required_jokers" in res else -1
	
	canvas_manager.generate_blank_canvas(actual_w, actual_h)
	canvas_manager.load_layout(actual_w, actual_h, res.layout, s_pairs, c_pairs)
	
	_recenter_editor_layout(actual_w, actual_h)
	
	if "time_limit" in res:
		ui_manager.set_time_limit(res.time_limit)
	
	var raw_tiles = res.available_tiles if "available_tiles" in res and res.available_tiles.size() > 0 else [0, 1, 2]
	var sanitized_tiles: Array = []
	for tile in raw_tiles:
		sanitized_tiles.append(int(tile))
		
	ui_manager.set_allowed_tiles(sanitized_tiles)
	
	ui_manager.sync_size_displays(actual_w, actual_h)
	ui_manager.update_status("SUCCESS: Loaded CORE Level " + str(res.level_number) + " as a template.", Color(0.4, 1.0, 0.4))

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
	
	ui_manager.playtest_reset_requested.connect(_on_playtest_reset_requested)
	ui_manager.playtest_rules_requested.connect(_on_playtest_rules_requested)
	ui_manager.playtest_hint_requested.connect(_on_playtest_hint_requested)
	ui_manager.resume_from_tutorial_requested.connect(_on_resume_from_tutorial)

func _on_random_board_requested():
	if is_playtesting: return
	
	var target_w = canvas_manager.grid_width
	var target_h = canvas_manager.grid_height
	
	ui_manager.sync_size_displays(target_w, target_h)
	
	var keep_walls = false
	if ui_manager.has_method("is_keep_walls_requested"):
		keep_walls = ui_manager.is_keep_walls_requested()
		
	var current_layout = {}
	if keep_walls:
		for c in canvas_manager.board_cells:
			if canvas_manager.board_cells[c].state == -2:
				current_layout[c] = -2
	
	var require_unique = true
	if ui_manager.has_method("is_unique_solution_required"):
		require_unique = ui_manager.is_unique_solution_required()
	
	# UPDATED: We now pass keep_walls to the generator so it knows whether to randomize new walls!
	var generated = PuzzleGenerator.generate_random_layout(target_w, target_h, ui_manager.get_allowed_tiles(), current_layout, require_unique, keep_walls)
	
	if generated.is_empty() or not generated.has("layout"):
		ui_manager.update_status("ERROR: Math conflict! Try removing a few walls or shrinking the grid.", Color(1.0, 0.3, 0.3))
		return
		
	current_level_required_jokers = generated.get("total_jokers", 0)
	
	canvas_manager.generate_blank_canvas(target_w, target_h)
	canvas_manager.load_layout(target_w, target_h, generated["layout"], generated["shifters"], generated["constraints"])
	
	_recenter_editor_layout(target_w, target_h)
	
	var status_text = "Generated %dx%d puzzle keeping existing walls!" % [target_w, target_h]
	if not keep_walls: status_text = "Generated %dx%d with randomized walls!" % [target_w, target_h]
	if not require_unique: status_text = "Generated %dx%d (Multi-Solution Allowed)!" % [target_w, target_h]
	ui_manager.update_status(status_text, Color(0.4, 1.0, 0.4))

func _on_grid_size_changed(new_width: int, new_height: int):
	if is_playtesting: return
	link_first_selection = null
	current_level_required_jokers = -1
	
	canvas_manager.generate_blank_canvas(new_width, new_height)
	_recenter_editor_layout(new_width, new_height)
	ui_manager.update_status("Grid resized to %d x %d" % [new_width, new_height], Color.WHITE)

func _on_brush_changed(state_id: int, brush_name: String):
	if is_playtesting: return
	if link_first_selection != null:
		var cell = canvas_manager.board_cells[link_first_selection]
		cell.update_visuals() 
		
	current_brush_state = state_id
	link_first_selection = null
	ui_manager.update_status("Selected Tool: " + brush_name, Color.WHITE)

func _on_canvas_cell_clicked(coord: Vector2i):
	var cell = canvas_manager.board_cells[coord]
	
	if is_playtesting:
		if cell.is_locked: return 
		var allowed = ui_manager.get_allowed_tiles()
		
		if cell.state == 3:
			for p in canvas_manager.loaded_shifter_pairs:
				if p["a"] == coord and canvas_manager.board_cells.has(p["b"]):
					cell.state = -1
					cell.shifter_direction = Vector2i.ZERO 
					var partner = canvas_manager.board_cells[p["b"]]
					partner.state = 3
					partner.shifter_direction = coord - p["b"] 
					partner.update_visuals()
					
					playtest_shifter_moves += 1
					if ui_manager.has_method("update_playtest_hud"):
						_update_playtest_hud_wrapper()
					canvas_manager.trigger_redraw() 
					break
				elif p["b"] == coord and canvas_manager.board_cells.has(p["a"]):
					cell.state = -1
					cell.shifter_direction = Vector2i.ZERO 
					var partner = canvas_manager.board_cells[p["a"]]
					partner.state = 3
					partner.shifter_direction = coord - p["a"] 
					partner.update_visuals()
					
					playtest_shifter_moves += 1
					if ui_manager.has_method("update_playtest_hud"):
						_update_playtest_hud_wrapper()
					canvas_manager.trigger_redraw() 
					break
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
	else:
		if current_brush_state >= 3 and current_brush_state <= 5:
			if link_first_selection == null:
				link_first_selection = coord
				
				if current_brush_state == 3:
					cell.set_mask_color(Color(0.6, 0.36, 0.9, 0.4))
				else:
					cell.set_mask_color(Color(1.0, 1.0, 1.0, 0.4))
				
				ui_manager.update_status("First cell selected! Click an adjacent neighbor to link.", Color.YELLOW)
			else:
				var first_coord = link_first_selection
				link_first_selection = null
				
				if first_coord == coord:
					var first_cell = canvas_manager.board_cells[first_coord]
					first_cell.update_visuals() 
					ui_manager.update_status("Cancelled: Clicked the same tile twice.", Color.WHITE)
					return
					
				var diff = (coord - first_coord).abs()
				if (diff.x == 1 and diff.y == 0) or (diff.x == 0 and diff.y == 1):
					if current_brush_state == 3:
						_execute_pair_link_creation(first_coord, coord)
					elif current_brush_state == 4:
						_execute_constraint_creation(first_coord, coord, "equals")
					elif current_brush_state == 5:
						_execute_constraint_creation(first_coord, coord, "not_equals")
				else:
					var first_cell = canvas_manager.board_cells[first_coord]
					first_cell.update_visuals() 
					ui_manager.update_status("ERROR: Selected cell must be immediately adjacent!", Color(1.0, 0.3, 0.3))
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

func _execute_pair_link_creation(coord_a: Vector2i, coord_b: Vector2i):
	_remove_pair_by_coord(coord_a)
	_remove_pair_by_coord(coord_b)
	
	var new_pair = {"a": coord_a, "b": coord_b, "active": coord_a}
	canvas_manager.loaded_shifter_pairs.append(new_pair)
	
	canvas_manager.board_cells[coord_a].is_linked_pair = true
	canvas_manager.board_cells[coord_b].is_linked_pair = true
	canvas_manager.board_cells[coord_a].state = 3
	canvas_manager.board_cells[coord_a].shifter_direction = coord_b - coord_a 
	canvas_manager.board_cells[coord_b].state = -1
	canvas_manager.board_cells[coord_b].shifter_direction = Vector2i.ZERO
	
	canvas_manager.board_cells[coord_a].is_locked = false
	canvas_manager.board_cells[coord_b].is_locked = false
	
	canvas_manager.board_cells[coord_a].update_visuals()
	canvas_manager.board_cells[coord_b].update_visuals()
	canvas_manager.trigger_redraw()
	ui_manager.update_status("Linked Shifter Pair successfully created!", Color(0.4, 1.0, 0.4))

func _remove_pair_by_coord(coord: Vector2i):
	for i in range(canvas_manager.loaded_shifter_pairs.size() - 1, -1, -1):
		var p = canvas_manager.loaded_shifter_pairs[i]
		if p["a"] == coord or p["b"] == coord:
			canvas_manager.board_cells[p["a"]].is_linked_pair = false
			canvas_manager.board_cells[p["b"]].is_linked_pair = false
			canvas_manager.board_cells[p["a"]].state = -1
			canvas_manager.board_cells[p["b"]].state = -1
			
			canvas_manager.board_cells[p["a"]].shifter_direction = Vector2i.ZERO 
			canvas_manager.board_cells[p["b"]].shifter_direction = Vector2i.ZERO
			
			canvas_manager.board_cells[p["a"]].is_locked = false
			canvas_manager.board_cells[p["b"]].is_locked = false
			
			canvas_manager.board_cells[p["a"]].update_visuals()
			canvas_manager.board_cells[p["b"]].update_visuals()
			canvas_manager.loaded_shifter_pairs.remove_at(i)
	canvas_manager.trigger_redraw()

func _execute_constraint_creation(coord_a: Vector2i, coord_b: Vector2i, type: String):
	var first_cell = canvas_manager.board_cells[coord_a]
	first_cell.update_visuals() 
	
	for i in range(canvas_manager.loaded_constraint_pairs.size() - 1, -1, -1):
		var p = canvas_manager.loaded_constraint_pairs[i]
		if (p["a"] == coord_a and p["b"] == coord_b) or (p["a"] == coord_b and p["b"] == coord_a):
			canvas_manager.loaded_constraint_pairs.remove_at(i)
			
	var new_constraint = {"a": coord_a, "b": coord_b, "type": type}
	canvas_manager.loaded_constraint_pairs.append(new_constraint)
	
	canvas_manager.trigger_redraw()
	ui_manager.update_status("Constraint successfully linked!", Color(0.4, 1.0, 0.4))

func _remove_constraint_by_coord(coord: Vector2i):
	for i in range(canvas_manager.loaded_constraint_pairs.size() - 1, -1, -1):
		var p = canvas_manager.loaded_constraint_pairs[i]
		if p["a"] == coord or p["b"] == coord:
			canvas_manager.loaded_constraint_pairs.remove_at(i)
	canvas_manager.trigger_redraw()

func _is_shifter_linked(coord: Vector2i) -> bool:
	for p in canvas_manager.loaded_shifter_pairs:
		if p["a"] == coord or p["b"] == coord:
			return true
	return false

func _on_clear_board():
	if is_playtesting: return
	canvas_manager.loaded_shifter_pairs.clear()
	canvas_manager.loaded_constraint_pairs.clear() 
	link_first_selection = null
	current_level_required_jokers = -1
	
	for coord in canvas_manager.board_cells:
		var cell = canvas_manager.board_cells[coord]
		cell.state = -1
		cell.shifter_direction = Vector2i.ZERO 
		cell.is_playable = true
		cell.is_linked_pair = false 
		cell.is_locked = false
		cell.update_visuals()
		
	canvas_manager.trigger_redraw()
	ui_manager.update_status("Board cleared!", Color.WHITE)

func _is_layout_empty(layout: Dictionary) -> bool:
	for coord in layout:
		if layout[coord] != -1:
			return false
	return true

func _scan_directory(path_to_scan: String) -> Array:
	var found_files = []
	if not DirAccess.dir_exists_absolute(path_to_scan):
		return found_files
		
	var dir = DirAccess.open(path_to_scan)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.ends_with(".tres"):
					found_files.append(path_to_scan + file_name)
				elif file_name.ends_with(".tres.remap"):
					found_files.append(path_to_scan + file_name.replace(".remap", ""))
			file_name = dir.get_next()
		dir.list_dir_end()
	return found_files

func _update_playtest_joker_count():
	var count = 0
	for coord in canvas_manager.board_cells:
		if canvas_manager.board_cells[coord].state == 2 and not canvas_manager.board_cells[coord].is_locked:
			count += 1
	ui_manager.update_playtest_joker_counter(count, playtest_required_jokers)

func _on_test_mode_entered():
	is_playtesting = true
	canvas_manager.is_playtesting = true
	playtest_snapshot.clear()
	link_first_selection = null
	
	if core_levels_container:
		core_levels_container.visible = false 
	
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
		cell.update_visuals()
	
	playtest_hidden_constraints = canvas_manager.loaded_constraint_pairs.duplicate()
	canvas_manager.loaded_constraint_pairs.clear()
	
	playtest_pending_hints = playtest_hidden_constraints.duplicate()
	playtest_pending_hints.shuffle()
	ui_manager.update_playtest_hint_count(playtest_pending_hints.size())
		
	playtest_time_remaining = ui_manager.get_time_limit()
	playtest_shifter_moves = 0
	
	var has_shifters = canvas_manager.loaded_shifter_pairs.size() > 0
	ui_manager.set_playtest_move_counter_visibility(has_shifters)
	
	if current_level_required_jokers == -1:
		playtest_required_jokers = min(canvas_manager.grid_width, canvas_manager.grid_height)
	else:
		playtest_required_jokers = current_level_required_jokers
		
	playtest_required_jokers = max(0, playtest_required_jokers - prefilled_jokers)
	
	var has_jokers = (2 in ui_manager.get_allowed_tiles()) and (playtest_required_jokers > 0)
	ui_manager.set_playtest_joker_counter_visibility(has_jokers)
	_update_playtest_joker_count()
	
	if ui_manager.has_method("update_playtest_hud"):
		_update_playtest_hud_wrapper()
	playtest_timer.start()
		
	ui_manager.toggle_playtest_visibility(true)
	if ui_manager.get_time_limit() == 0:
		ui_manager.update_status("PLAYTEST ACTIVE: Take all the time you need!", Color.YELLOW)
	else:
		ui_manager.update_status("PLAYTEST ACTIVE: Solve it before time runs out!", Color.YELLOW)
	
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
		cell.update_visuals()
		
	canvas_manager.loaded_constraint_pairs.clear()
	playtest_pending_hints = playtest_hidden_constraints.duplicate()
	playtest_pending_hints.shuffle()
	ui_manager.update_playtest_hint_count(playtest_pending_hints.size())
	
	playtest_time_remaining = ui_manager.get_time_limit()
	playtest_shifter_moves = 0
	
	var has_shifters = canvas_manager.loaded_shifter_pairs.size() > 0
	ui_manager.set_playtest_move_counter_visibility(has_shifters)
	
	_update_playtest_joker_count()
	
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
	else:
		ui_manager.update_status("Please add the HowToPlayLayer to this scene to use rules.", Color.YELLOW)

func _on_resume_from_tutorial():
	if is_playtesting:
		playtest_timer.start()

func _on_playtest_hint_requested():
	if not is_playtesting: return
	
	if playtest_pending_hints.size() > 0:
		var hint = playtest_pending_hints.pop_back()
		canvas_manager.loaded_constraint_pairs.append(hint)
		canvas_manager.trigger_redraw()
		ui_manager.update_playtest_hint_count(playtest_pending_hints.size())
		_run_playtest_validation_pass()

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
	
	if core_levels_container:
		core_levels_container.visible = true 
	
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
		cell.update_visuals()
		
	canvas_manager.loaded_constraint_pairs = playtest_hidden_constraints.duplicate()
		
	canvas_manager.trigger_redraw()
	ui_manager.toggle_playtest_visibility(false)
	_on_brush_changed(current_brush_state, "Designer Mode Restored")

func _run_playtest_validation_pass():
	canvas_manager.clear_highlights()
	var results = PuzzleValidator.validate_board(canvas_manager.board_cells, canvas_manager.cached_lines, canvas_manager.loaded_constraint_pairs)
	
	if not results["valid"]:
		ui_manager.update_status("\n".join(results["errors"]), Color(1.0, 0.3, 0.3))
	else:
		ui_manager.update_status("Puzzle looks perfectly valid so far!", Color(0.4, 1.0, 0.4))
		
	if results["valid"] and canvas_manager.is_board_full():
		_trigger_playtest_victory()

func _trigger_playtest_victory():
	is_playtesting = false
	playtest_timer.stop()
	ui_manager.update_status("PLAYTEST COMPLETE: Level successfully solved!", Color.GOLD)
	ui_manager.display_victory_overlay("GOOD JOB!\nLEVEL IS SOLVABLE")

func _trigger_playtest_defeat():
	is_playtesting = false
	playtest_timer.stop()
	ui_manager.update_status("PLAYTEST FAILED: Time's Up!", Color(1.0, 0.3, 0.3))
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
		var active_pos = pair["a"]
		if canvas_manager.board_cells.has(pair["b"]) and canvas_manager.board_cells[pair["b"]].state == 3:
			active_pos = pair["b"]
		processed_pairs.append({"a": pair["a"], "b": pair["b"], "active": active_pos})
	
	if "shifter_pairs" in new_level_resource:
		new_level_resource.shifter_pairs = processed_pairs
	else:
		new_level_resource.set("red_pairs", processed_pairs)
	
	if "constraint_pairs" in new_level_resource:
		new_level_resource.constraint_pairs = canvas_manager.loaded_constraint_pairs.duplicate() 
	else:
		new_level_resource.set("constraint_pairs", canvas_manager.loaded_constraint_pairs.duplicate())
	
	new_level_resource.time_limit = ui_manager.get_time_limit()
	new_level_resource.available_tiles = ui_manager.get_allowed_tiles()
	
	if not DirAccess.dir_exists_absolute(DEV_LEVELS_DIR):
		DirAccess.make_dir_absolute(DEV_LEVELS_DIR)
			
	var target_save_path = DEV_LEVELS_DIR + "level_%d.tres" % level_num
	var save_result = ResourceSaver.save(new_level_resource, target_save_path)
	
	if save_result == OK:
		ui_manager.update_status("SUCCESS: Saved custom level to: " + target_save_path, Color(0.4, 1.0, 0.4))
	else:
		ui_manager.update_status("ERROR: Resource save failed: " + error_string(save_result), Color(1.0, 0.3, 0.3))

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
			ui_manager.update_status("SUCCESS: Loaded Custom Level " + str(level_num), Color(0.4, 1.0, 0.4))
		else:
			ui_manager.update_status("ERROR: Failed to parse LevelData resource.", Color(1.0, 0.3, 0.3))
	else:
		ui_manager.update_status("ERROR: No custom data found for Level " + str(level_num), Color(1.0, 0.6, 0.2))

func _on_main_menu():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
