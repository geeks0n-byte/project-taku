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
const TOP_HUD_BOTTOM := 236.0
const BOARD_GAP := 40.0
const UNDO_STACK_LIMIT := 5

const HUD_BUTTON_WIDTH := 140
const HUD_BUTTON_HEIGHT := 140
const HUD_ICON_SIZE := 83
const HUD_BUTTON_SEPARATION := 4
const HUD_TOP_BAR_HEIGHT := 144.0
const HUD_TOP_BAR_EDGE_MARGIN := HUD_BUTTON_SEPARATION
const HUD_CENTER_LABEL_GAP := 0.0
const HUD_CENTER_LABEL_LINE_SEPARATION := 10
const HUD_COUNTER_ROW_TOP := 156.0
const HUD_COUNTER_ROW_HEIGHT := 88.0
const HUD_STATUS_GAP := 20.0
const HUD_STATUS_FONT_SIZE := 48
const HUD_EDITOR_STATUS_FONT_SIZE := 34
const HUD_EDITOR_STATUS_HEIGHT := 72.0
const HUD_STATUS_MIN_HEIGHT := 180.0
const HUD_LEVEL_FONT_SIZE := 35
const HUD_LEVEL_LABEL_Y_NUDGE := 4.0
const HUD_LEVEL_OUTLINE_PAD := 8
const HUD_COUNTER_FONT_SIZE := 32
const HUD_COUNTER_LABEL_FONT_SIZE := 24
const HUD_COUNTER_ICON_SIZE := 52
const HUD_INFINITY_ICON_SIZE := 48
const HUD_TIMER_Y_NUDGE := -6.0
const HUD_COUNTER_LABEL_HALF_W := 230.0
const HUD_COUNTER_LABEL_HALF_H := 42.0
const HUD_COUNTER_GREEN := Color(0.45, 1.0, 0.5, 1.0)
const HUD_COUNTER_SHIFTER := Color(0.82, 0.62, 1.0, 1.0)
const HUD_SIDE_MARGIN := 24.0
const HUD_TOP_BAR_ICON_NUDGE := 2
const LEVEL_PREVIEW_SIZE := 112

## Shared screen headers (Options, Level Select, Credits, Pause, …).
## Vertical slot matches the main menu title label.
const SCREEN_HEADER_FONT_SIZE := 56
const SCREEN_HEADER_OUTLINE := 12
const SCREEN_HEADER_TOP := 280.0
const SCREEN_HEADER_HEIGHT := 100.0
const SCREEN_CONTENT_GAP := 36.0
const SCREEN_HEADER_COLOR := Color(1.0, 0.84, 0.0, 1.0)

const ICON_INFINITY := "res://resources/icons/icon_infinity.svg"
const ICON_HINT_ON := "res://resources/icons/icon_hint_on.svg"
const ICON_HINT_OFF := "res://resources/icons/icon_hint_off.svg"
const TILE_SHIFTER := "res://resources/tiles/tile_shifter.svg"
const TILE_GREEN := "res://resources/tiles/tile_green.svg"
const TILE_YELLOW := "res://resources/tiles/tile_yellow.svg"
const TILE_BLUE := "res://resources/tiles/tile_blue.svg"
const TILE_SHIFTER_UP := "res://resources/tiles/tile_shifter_up.svg"
const TILE_SHIFTER_DOWN := "res://resources/tiles/tile_shifter_down.svg"
const TILE_SHIFTER_LEFT := "res://resources/tiles/tile_shifter_left.svg"
const TILE_SHIFTER_RIGHT := "res://resources/tiles/tile_shifter_right.svg"
const TILE_LOCK := "res://resources/tiles/tile_lock.svg"
const ICON_LOCK := "res://resources/tiles/tile_lock.svg"
const DEFAULT_FONT_SCALE := 1.45
const DISABLED_ICON_MODULATE := Color(0.55, 0.55, 0.55, 1.0)
const TOGGLE_MASK_AMBER := Color(1.0, 0.78, 0.2, 0.4)
const TOGGLE_MASK_LOCK := Color(0.95, 0.28, 0.38, 0.45)
const TOGGLE_MASK_UNIQUE := Color(0.35, 0.9, 0.45, 0.45)

const CAMPAIGN_DIR := "res://levels/"
const CAMPAIGN_TUTORIALS_DIR := "res://levels/tutorials/"
const CAMPAIGN_EASY_DIR := "res://levels/easy/"
const CAMPAIGN_MEDIUM_DIR := "res://levels/medium/"
const CAMPAIGN_HARD_DIR := "res://levels/hard/"
const DEV_LEVELS_DIR := "user://levels/"

static func is_basic_tile(state: int) -> bool:
	return state == TileState.YELLOW or state == TileState.BLUE

static func is_solvable_tile(state: int) -> bool:
	return state in [TileState.YELLOW, TileState.BLUE, TileState.JOKER, TileState.SHIFTER]

## Tiles that can appear in equals/not-equals contractions (Y/B/G/P).
static func is_hintable_tile(state: int) -> bool:
	return is_solvable_tile(state)
