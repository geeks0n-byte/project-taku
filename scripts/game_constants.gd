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

enum BrushTool {
	EQUALS = 4,
	NOT_EQUALS = 5,
}

const CELL_SIZE := 120
const TOP_HUD_BOTTOM := 236.0
const BOARD_GAP := 40.0
const UNDO_STACK_LIMIT := 0

const HINT_LIMIT_EASY := 2
const HINT_LIMIT_MEDIUM := 3
const HINT_LIMIT_HARD := 5
const HINT_LIMIT_UNLIMITED := -1
const HINTS_FROM_REWARDED_AD := 3

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
const HUD_INFINITY_ICON_SIZE := 80
const EDITOR_INFINITY_ICON_SIZE := 72
const HUD_TIMER_Y_NUDGE := -6.0
const HUD_COUNTER_LABEL_HALF_W := 230.0
const HUD_COUNTER_LABEL_HALF_H := 42.0
const HUD_COUNTER_GREEN := Color(0.45, 1.0, 0.5, 1.0)
const HUD_COUNTER_SHIFTER := Color(0.82, 0.62, 1.0, 1.0)
const HUD_SIDE_MARGIN := 24.0
const HUD_TOP_BAR_ICON_NUDGE := 2
const LEVEL_PREVIEW_SIZE := 112

const SCREEN_HEADER_FONT_SIZE := 64
const SCREEN_HEADER_OUTLINE := 12
const SCREEN_HEADER_TOP := 260.0
const SCREEN_HEADER_HEIGHT := 152.0
const SCREEN_CONTENT_GAP := 36.0
const SCREEN_HEADER_COLOR := Color(1.0, 0.84, 0.0, 1.0)

const AD_BANNER_RESERVE := 140.0
const SCREEN_BOTTOM_NAV_TOP := -260.0 - AD_BANNER_RESERVE
const SCREEN_BOTTOM_NAV_BOTTOM := -160.0 - AD_BANNER_RESERVE

const UI_BTN_PRIMARY_SIZE := Vector2(560, 120)
const UI_BTN_PRIMARY_FONT := 32
const UI_BTN_PRIMARY_FONT_MIN := 16

const UI_BTN_SECONDARY_SIZE := Vector2(280, 100)
const UI_BTN_SECONDARY_FONT := 24
const UI_BTN_SECONDARY_FONT_MIN := 14

const UI_BTN_DIALOG_SIZE := Vector2(220, 100)
const UI_BTN_DIALOG_FONT := 24
const UI_BTN_DIALOG_FONT_MIN := 14

const UI_BTN_NAV_SIZE := Vector2(240, 100)
const UI_BTN_NAV_FONT := 22
const UI_BTN_NAV_FONT_MIN := 12

const UI_BTN_PANEL_SIZE := Vector2(460, 100)
const UI_BTN_PANEL_FONT := 24
const UI_BTN_PANEL_FONT_MIN := 14

const UI_BTN_TAB_SIZE := Vector2(240, 110)
const UI_BTN_TAB_FONT := 42
const UI_BTN_TAB_FONT_MIN := 26

const MENU_TEXT_OUTLINE := 10

const UI_BODY_FONT_SIZE := 26
const UI_BODY_FONT_SIZE_LARGE := 28
const UI_BODY_TITLE_FONT_SIZE := 46

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
const DEFAULT_FONT_SCALE := 1.45
const DISABLED_ICON_MODULATE := Color(0.55, 0.55, 0.55, 1.0)
const TOGGLE_MASK_AMBER := Color(1.0, 0.78, 0.2, 0.4)
const TOGGLE_MASK_LOCK := Color(0.95, 0.28, 0.38, 0.45)
const TOGGLE_MASK_WHITE := Color(1.0, 1.0, 1.0, 0.4)

const CAMPAIGN_TUTORIALS_DIR := "res://levels/tutorials/"
const CAMPAIGN_EASY_DIR := "res://levels/easy/"
const CAMPAIGN_MEDIUM_DIR := "res://levels/medium/"
const CAMPAIGN_HARD_DIR := "res://levels/hard/"
const DEV_LEVELS_DIR := "user://levels/"

static func is_basic_tile(state: int) -> bool:
	return state == TileState.YELLOW or state == TileState.BLUE

static func is_solvable_tile(state: int) -> bool:
	return state in [TileState.YELLOW, TileState.BLUE, TileState.JOKER, TileState.SHIFTER]

static func is_hintable_tile(state: int) -> bool:
	return is_solvable_tile(state)

static func hint_limit_for_difficulty(difficulty: int) -> int:
	match difficulty:
		PuzzleGenerator.Difficulty.EASY:
			return HINT_LIMIT_EASY
		PuzzleGenerator.Difficulty.HARD:
			return HINT_LIMIT_HARD
		_:
			return HINT_LIMIT_MEDIUM
