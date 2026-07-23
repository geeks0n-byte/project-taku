class_name GameConstants
extends RefCounted

enum TileState {
	WALL = -2,
	EMPTY = -1,
	YELLOW = 0,
	BLUE = 1,
	JOKER = 2,
	SHIFTER = 3,
}

const CELL_SIZE := 120
const TOP_HUD_BOTTOM := 195.0
const BOARD_GAP := 40.0
const UNDO_STACK_LIMIT := 5

const ICON_INFINITY := "res://resources/icons/icon_infinity.svg"
const TILE_PURPLE := "res://resources/tiles/tile_purple.svg"
const TILE_GREEN := "res://resources/tiles/tile_green.svg"
const TILE_YELLOW := "res://resources/tiles/tile_yellow.svg"
const TILE_BLUE := "res://resources/tiles/tile_blue.svg"

const CAMPAIGN_DIR := "res://levels/"
const DEV_LEVELS_DIR := "user://levels/"

static func is_basic_tile(state: int) -> bool:
	return state == TileState.YELLOW or state == TileState.BLUE

static func is_solvable_tile(state: int) -> bool:
	return state in [TileState.YELLOW, TileState.BLUE, TileState.JOKER, TileState.SHIFTER]
