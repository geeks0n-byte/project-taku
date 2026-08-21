class_name EditorCanvasManager
extends Node2D

# Owns and manages the grid of Cell nodes used by both the level editor and the playtest view.
# Rendering is delegated to BoardRenderer; this class handles cell pooling, layout loading,
# and emitting click signals that the parent LevelEditor routes to brush/link logic.

# Emitted when a cell interceptor receives a left-click, forwarding the grid coordinate.
signal canvas_cell_clicked(coord: Vector2i)
# Playtest-mode signals from Cell (cycle / hold-clear / shifter), after the cell mutates itself.
signal canvas_cell_played(coord: Vector2i)
signal canvas_cell_hold_cleared(coord: Vector2i)
signal canvas_shifter_toggled(coord: Vector2i)

@export var cell_scene: PackedScene = preload("res://scenes/cell.tscn")

var grid_width: int = 3
var grid_height: int = 3

# Live Cell node lookup by grid coordinate.
var board_cells = {}
# Reusable {cell, interceptor} pairs to avoid instantiating new nodes on every grid resize.
var cell_pool: Array = []
# Pre-computed sorted row/column data used by draw passes.
var cached_lines: Array = []

# Shifter pairs currently loaded on the canvas (mirrors LevelData.shifter_pairs format).
var loaded_shifter_pairs: Array = []
# Visible constraint pairs (shown to the player in both editor and play mode).
var loaded_constraint_pairs: Array = []
# Auto-derived constraint pairs hidden from the player but visible when editor hints are on.
var hidden_constraint_pairs: Array = []

# Separate draw nodes so grid lines and constraint symbols have independent z-order and redraw.
var grid_drawer: Node2D
var constraint_drawer: Node2D

# When true, cells are configured for play (locked tiles, no editor chrome).
var is_playtesting: bool = false
# When true in editor mode, hidden_constraint_pairs are drawn alongside visible ones.
var show_editor_hints: bool = false

func _ready():
	# grid_drawer sits above cells (z=10) so grid lines are never hidden by tile backgrounds.
	grid_drawer = Node2D.new()
	grid_drawer.z_index = 10
	grid_drawer.draw.connect(_draw_grid)
	add_child(grid_drawer)

	# constraint_drawer is at maximum z so symbols always render on top of everything.
	constraint_drawer = Node2D.new()
	constraint_drawer.z_index = 4096
	constraint_drawer.draw.connect(_draw_constraints)
	add_child(constraint_drawer)

# Forces all draw nodes to re-emit their draw signals on the next frame.
func trigger_redraw():
	queue_redraw()
	if grid_drawer:
		grid_drawer.queue_redraw()
	if constraint_drawer:
		constraint_drawer.queue_redraw()

# Resets the canvas to an empty grid of the given size. Reuses pooled cells where possible
# to avoid the cost of instantiating and destroying nodes on every grid resize.
func generate_blank_canvas(new_width: int = 3, new_height: int = 3):
	grid_width = new_width
	grid_height = new_height
	board_cells.clear()
	loaded_shifter_pairs.clear()
	loaded_constraint_pairs.clear()
	hidden_constraint_pairs.clear()

	var pool_index = 0

	for y in range(grid_height):
		for x in range(grid_width):
			var coord = Vector2i(x, y)
			var cell
			var interceptor

			if pool_index < cell_pool.size():
				# Reuse an existing cell/interceptor pair from the pool.
				var cell_data = cell_pool[pool_index]
				cell = cell_data["cell"]
				interceptor = cell_data["interceptor"]
				cell.visible = true
				interceptor.visible = true
				_wire_playtest_cell_signals(cell)
			else:
				cell = cell_scene.instantiate()
				add_child(cell)
				_wire_playtest_cell_signals(cell)

				# Transparent overlay that captures mouse events so the cell node itself
				# doesn't need to handle input, keeping cell logic and input routing separate.
				interceptor = Control.new()
				interceptor.mouse_filter = Control.MOUSE_FILTER_STOP
				add_child(interceptor)

				cell_pool.append({"cell": cell, "interceptor": interceptor})

			cell.coord = coord
			cell.position = Vector2(float(x * GameConstants.CELL_SIZE), float(y * GameConstants.CELL_SIZE))
			cell.state = GameConstants.TileState.EMPTY
			cell.is_playable = true
			cell.is_locked = false
			cell.is_linked_pair = false
			cell.shifter_direction = Vector2i.ZERO
			cell.is_editor_mode = not is_playtesting
			if cell is Control:
				cell.mouse_filter = (
					Control.MOUSE_FILTER_IGNORE if not is_playtesting else Control.MOUSE_FILTER_STOP
				)
			cell.update_visuals()

			# Full-cell hit target so border clicks cannot fall through to Cell
			# (which would cycle EMPTY → YELLOW while a link brush is active).
			interceptor.size = Vector2(GameConstants.CELL_SIZE, GameConstants.CELL_SIZE)
			interceptor.position = cell.position
			interceptor.mouse_filter = (
				Control.MOUSE_FILTER_IGNORE if is_playtesting else Control.MOUSE_FILTER_STOP
			)
			interceptor.z_index = 1
			if cell is CanvasItem:
				cell.z_index = 0

			# Disconnect any previous lambda that captured a stale coord value before reconnecting.
			for conn in interceptor.gui_input.get_connections():
				interceptor.gui_input.disconnect(conn.callable)

			interceptor.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					canvas_cell_clicked.emit(coord)
			)

			board_cells[coord] = cell
			pool_index += 1

	# Hide surplus pool cells from a previous (larger) grid.
	for i in range(pool_index, cell_pool.size()):
		cell_pool[i]["cell"].visible = false
		cell_pool[i]["interceptor"].visible = false

	if not is_playtesting:
		for coord in board_cells:
			var cell = board_cells[coord]
			cell.is_editor_mode = true
			if cell.state == GameConstants.TileState.EMPTY:
				cell.update_visuals()

	# Keep draw nodes on top of all cells at all times.
	move_child(grid_drawer, -1)
	move_child(constraint_drawer, -1)

	cached_lines = BoardRenderer.cache_board_lines(board_cells)
	trigger_redraw()


# Lets Cell handle press/release (hold-to-clear + release-to-cycle) during playtest.
# In edit mode the interceptor stays on top so brush painting keeps working.
func set_playtest_input_mode(enabled: bool) -> void:
	is_playtesting = enabled
	for entry in cell_pool:
		var cell: Node = entry["cell"]
		var interceptor: Control = entry["interceptor"]
		if cell and "is_editor_mode" in cell:
			cell.is_editor_mode = not enabled
		if cell is Control:
			cell.mouse_filter = (
				Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
			)
		if interceptor:
			interceptor.mouse_filter = (
				Control.MOUSE_FILTER_IGNORE if enabled else Control.MOUSE_FILTER_STOP
			)


func _wire_playtest_cell_signals(cell: Node) -> void:
	if cell == null:
		return
	if cell.has_signal("cell_clicked") and not cell.cell_clicked.is_connected(_on_pool_cell_clicked):
		cell.cell_clicked.connect(_on_pool_cell_clicked)
	if cell.has_signal("cell_hold_cleared") and not cell.cell_hold_cleared.is_connected(_on_pool_cell_hold_cleared):
		cell.cell_hold_cleared.connect(_on_pool_cell_hold_cleared)
	if cell.has_signal("shifter_toggled") and not cell.shifter_toggled.is_connected(_on_pool_shifter_toggled):
		cell.shifter_toggled.connect(_on_pool_shifter_toggled)


func _on_pool_cell_clicked(coord: Vector2i) -> void:
	if is_playtesting:
		canvas_cell_played.emit(coord)


func _on_pool_cell_hold_cleared(coord: Vector2i) -> void:
	if is_playtesting:
		canvas_cell_hold_cleared.emit(coord)


func _on_pool_shifter_toggled(coord: Vector2i) -> void:
	if is_playtesting:
		canvas_shifter_toggled.emit(coord)


# Populates the canvas from a saved level layout. Generates a blank canvas first so
# the pool is reset, then applies tile states and reconstructs the shifter visual state.
func load_layout(new_width: int, new_height: int, layout_data: Dictionary, shifter_pairs: Array = [], constraint_pairs: Array = []):
	generate_blank_canvas(new_width, new_height)
	loaded_shifter_pairs = shifter_pairs.duplicate()
	loaded_constraint_pairs = constraint_pairs.duplicate()
	hidden_constraint_pairs.clear()

	for coord in layout_data:
		if board_cells.has(coord):
			var cell = board_cells[coord]
			var saved_state = layout_data[coord]
			cell.state = saved_state
			if saved_state == GameConstants.TileState.WALL:
				cell.is_playable = false
				cell.is_locked = true
			elif saved_state != GameConstants.TileState.EMPTY:
				cell.is_playable = true
				cell.is_locked = true
			else:
				cell.is_playable = true
				cell.is_locked = false
			cell.update_visuals()

	# Restore shifter visuals: the active cell shows the SHIFTER tile with a direction arrow;
	# the inactive (partner) cell appears empty but is flagged as part of the pair.
	for pair in loaded_shifter_pairs:
		if board_cells.has(pair["a"]):
			board_cells[pair["a"]].is_linked_pair = true
		if board_cells.has(pair["b"]):
			board_cells[pair["b"]].is_linked_pair = true
		if board_cells.has(pair["active"]):
			var active_coord = pair["active"]
			var inactive_coord = pair["b"] if active_coord == pair["a"] else pair["a"]
			board_cells[active_coord].state = GameConstants.TileState.SHIFTER
			# Direction vector points from the active cell toward its inactive partner.
			board_cells[active_coord].shifter_direction = inactive_coord - active_coord

	for coord in board_cells:
		board_cells[coord].update_visuals()

	move_child(grid_drawer, -1)
	move_child(constraint_drawer, -1)

	trigger_redraw()

func clear_highlights():
	BoardRenderer.clear_highlights(board_cells)

func is_board_full() -> bool:
	return BoardRenderer.is_board_full(board_cells)

# Called by grid_drawer's draw signal; passes is_playtesting to control full-grid vs play mode drawing.
func _draw_grid():
	BoardRenderer.draw_grid(grid_drawer, board_cells, GameConstants.CELL_SIZE, not is_playtesting)

# In editor mode with hints enabled, appends hidden constraint pairs so the designer can see
# auto-derived constraints without them being visible to the player.
func _draw_constraints():
	var pairs_to_draw = loaded_constraint_pairs.duplicate()
	if not is_playtesting and show_editor_hints:
		pairs_to_draw.append_array(hidden_constraint_pairs)
	BoardRenderer.draw_constraints(constraint_drawer, board_cells, pairs_to_draw, GameConstants.CELL_SIZE)
