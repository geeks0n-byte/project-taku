class_name GameBoardLayout
extends RefCounted
## Shared vertical board centering for gameplay scenes.


static func apply_vertical_center(
	board_manager: BoardManager,
	ui_manager: UIManager,
	grid_height: int,
	viewport_height: float
) -> void:
	if board_manager == null or grid_height <= 0:
		return
	var centered_y := LevelUtils.center_board_y(
		grid_height, GameConstants.CELL_SIZE, viewport_height
	)
	board_manager.position.y = centered_y
	if ui_manager:
		ui_manager.update_dynamic_layout(centered_y, grid_height * GameConstants.CELL_SIZE)


static func apply_from_cells(
	board_manager: BoardManager,
	ui_manager: UIManager,
	cells: Dictionary,
	viewport_height: float
) -> void:
	if cells.is_empty():
		return
	var dims := LevelUtils.get_dimensions_from_cells(cells)
	apply_vertical_center(board_manager, ui_manager, dims.y, viewport_height)


static func apply_from_level(
	board_manager: BoardManager,
	ui_manager: UIManager,
	level: LevelData,
	viewport_height: float
) -> void:
	if level == null:
		return
	var dims := LevelUtils.get_dimensions_from_level(level)
	apply_vertical_center(board_manager, ui_manager, dims.y, viewport_height)
