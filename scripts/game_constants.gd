class_name GameConstants
extends RefCounted
## Shared enums, HUD sizes, asset paths, and tile-class helpers used across scenes.

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

# Public URL for the privacy policy page. Opened in the device browser from the consent popup.
# Update this if the URL ever changes — it's referenced in consent_popup.gd.
const PRIVACY_POLICY_URL := "https://geeks0n-byte.github.io/project-taku/privacy-policy.html"

## Deep space void (#00123a) — boot splash, Android window background, parallax base.
const BOOT_VOID_COLOR := Color(0, 0.0705882, 0.227451, 1)
## Android export splash_screen/icon asset width (splash_app_icon_256.png).
const BOOT_SPLASH_ICON_TEX_PX := 256
## Android 12 splash icon slot with a separate windowSplashScreenBackground (no icon bg layer).
const ANDROID_SPLASH_ICON_DP := 288.0
## In-game tile SVG viewBox is 16 units; visible art insets 1 unit on each side.
const BOOT_TILE_VIEWBOX_UNITS := 16.0
const BOOT_TILE_DRAWABLE_UNITS := 14.0
const BOOT_ICON_LOGICAL_PX := 64
const BOOT_TILE_DST := 16
const BOOT_TILE_GAP := 3
const BOOT_TILE_HALO := 1
const BOOT_TILE_STRIDE := BOOT_TILE_DST - 2 * BOOT_TILE_HALO + BOOT_TILE_GAP
const BOOT_TILE_MARGIN := (BOOT_ICON_LOGICAL_PX - (BOOT_TILE_STRIDE + BOOT_TILE_DST)) >> 1
## Typical phone logical width (dp) used when DisplayServer DPI is unavailable.
const ANDROID_PHONE_WIDTH_DP := 411.0

## UI density scale (px per dp). Android matches the OS splash (dpi/160).
## Headless/desktop use viewport width — DisplayServer DPI is often bogus (96).
static func android_ui_density(viewport_width_px: float = 0.0) -> float:
	var viewport_density := 0.0
	if viewport_width_px > 0.0:
		viewport_density = viewport_width_px / ANDROID_PHONE_WIDTH_DP
	var dpi_density := 0.0
	var dpi := float(DisplayServer.screen_get_dpi())
	if dpi > 0.0:
		dpi_density = dpi / 160.0
	if is_headless_run():
		if viewport_density > 0.0:
			return viewport_density
		return 1080.0 / ANDROID_PHONE_WIDTH_DP
	if OS.get_name() == "Android" and dpi_density > 0.0:
		return dpi_density
	if viewport_density > 0.0:
		return viewport_density
	if dpi_density > 0.0:
		return dpi_density
	return 1080.0 / ANDROID_PHONE_WIDTH_DP


## On-screen side length of the centered Android splash icon (px).
static func android_splash_icon_side_px(viewport_size: Vector2) -> float:
	return ANDROID_SPLASH_ICON_DP * android_ui_density(viewport_size.x)


## Boot-intro tile size on a reference phone width (scatter velocity scaling).
static func boot_splash_ref_tile_px(viewport_width_px: float = 1080.0) -> float:
	var side := android_splash_icon_side_px(Vector2(viewport_width_px, 1920.0))
	return 16.0 * side / float(BOOT_ICON_LOGICAL_PX)


## Sprite scale so an imported tile SVG matches one splash-icon tile on screen.
## Each icon cell is tile_px wide (16 logical); opaque art is 14 logical (1px halo).
static func boot_splash_tile_sprite_scale(tile_px: float, texture_width_px: float) -> float:
	return tile_px / maxf(1.0, texture_width_px)


## Visible on-screen width/height of one boot splash tile (excludes 1px halo per side).
static func boot_splash_tile_visible_px(tile_px: float) -> float:
	return tile_px * (BOOT_TILE_DRAWABLE_UNITS / BOOT_TILE_VIEWBOX_UNITS)


## Tile centers for the four app-icon tiles matching the Android splash icon slot.
static func boot_splash_icon_layout(view_rect: Rect2) -> Dictionary:
	var viewport_size := view_rect.size
	var view_origin := view_rect.position
	var side := android_splash_icon_side_px(viewport_size)
	var icon_scale := side / float(BOOT_ICON_LOGICAL_PX)
	var tile_px := float(BOOT_TILE_DST) * icon_scale
	var origin := view_origin + (viewport_size - Vector2.ONE * side) * 0.5
	var centers: Array[Vector2] = []
	var icon_origins: Array[Vector2i] = [
		Vector2i(BOOT_TILE_MARGIN, BOOT_TILE_MARGIN),
		Vector2i(BOOT_TILE_MARGIN + BOOT_TILE_STRIDE, BOOT_TILE_MARGIN),
		Vector2i(BOOT_TILE_MARGIN, BOOT_TILE_MARGIN + BOOT_TILE_STRIDE),
		Vector2i(BOOT_TILE_MARGIN + BOOT_TILE_STRIDE, BOOT_TILE_MARGIN + BOOT_TILE_STRIDE),
	]
	for icon_origin in icon_origins:
		var tile_origin := Vector2(icon_origin) * icon_scale
		centers.append(origin + tile_origin + Vector2.ONE * tile_px * 0.5)
	var cluster_center := Vector2.ZERO
	for center in centers:
		cluster_center += center
	cluster_center /= float(maxi(centers.size(), 1))
	return {
		"side_px": side,
		"tile_px": tile_px,
		"centers": centers,
		"cluster_center": cluster_center,
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
## Wall-clock budget for procedural board generation inside the loading overlay.
const GENERATOR_WALL_CLOCK_SEC := 8.0

## In-app review prompt policy (Google Play).
const REVIEW_MIN_UNIQUE_CLEARS := 5
const REVIEW_MIN_EARNED_STARS := 2
const REVIEW_MAX_PROMPTS := 3
const REVIEW_MIN_DAYS_BETWEEN := 90
const REVIEW_MIN_SESSION_SEC := 300.0

# Interstitial cadence (session-only; see AdsManager).
# First interstitial waits for both a min win count and a min session age so
# short hop-in sessions are not ad-dense. After the first shown ad, every_n
# still grows by 1; short sessions also keep an extra gap until they age out.
const INTERSTITIAL_START_EVERY_N := 3
const INTERSTITIAL_MIN_WINS_BEFORE_FIRST := 4
const INTERSTITIAL_MIN_SESSION_SEC := 90.0
const INTERSTITIAL_SHORT_SESSION_SEC := 180.0
const INTERSTITIAL_SHORT_SESSION_EXTRA_GAP := 1

const HUD_BUTTON_WIDTH := 140
const HUD_BUTTON_HEIGHT := 140
const HUD_ICON_SIZE := 83
const HUD_BUTTON_SEPARATION := 4
const HUD_BUTTON_CLUSTER_WIDTH := HUD_BUTTON_WIDTH * 3 + HUD_BUTTON_SEPARATION * 2
const HUD_TOP_BAR_HEIGHT := 144.0
const HUD_TOP_BAR_EDGE_MARGIN := HUD_BUTTON_SEPARATION
const HUD_CENTER_LABEL_WIDTH := 200
const HUD_CENTER_LABEL_GAP := 0.0
const HUD_CENTER_LABEL_LINE_SEPARATION := 4
const HUD_COUNTER_ROW_TOP := 156.0
const HUD_COUNTER_ROW_HEIGHT := 88.0
const HUD_STATUS_GAP := 20.0
const HUD_STATUS_FONT_SIZE := 48
const HUD_EDITOR_STATUS_FONT_SIZE := 34
const HUD_EDITOR_STATUS_HEIGHT := 72.0
const HUD_STATUS_MIN_HEIGHT := 180.0
const HUD_LEVEL_FONT_SIZE := 32
const HUD_LEVEL_LABEL_Y_NUDGE := 0.0
const HUD_LEVEL_OUTLINE_SIZE := 8
const HUD_LEVEL_OUTLINE_PAD := 0
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

# Shared font size for all screen titles (options, pause, level select, HTP).
# Main menu title uses its own larger size (96) defined in main_menu.gd.
const SCREEN_HEADER_FONT_SIZE := 72
const SCREEN_HEADER_OUTLINE := 12
const SCREEN_HEADER_TOP := 260.0
const SCREEN_HEADER_HEIGHT := 152.0
const SCREEN_CONTENT_GAP := 36.0
const SCREEN_HEADER_COLOR := Color(1.0, 0.84, 0.0, 1.0)

const AD_BANNER_RESERVE := 140.0
## Distance from the physical screen bottom (above home indicator) to the bottom edge of PREV/NEXT rows.
const SCREEN_PAGE_NAV_BOTTOM_INSET := 120.0
const SCREEN_BOTTOM_NAV_TOP := -260.0 - AD_BANNER_RESERVE
const SCREEN_BOTTOM_NAV_BOTTOM := -160.0 - AD_BANNER_RESERVE
const SCREEN_NAV_GAP := 28.0
const HTP_PANEL_TOP := 448.0
const HTP_PANEL_HALF_WIDTH := 475.0
const HTP_PANEL_MIN_HEIGHT := 160.0

const UI_BTN_PRIMARY_SIZE := Vector2(560, 120)
const UI_BTN_PRIMARY_FONT := 32
const UI_BTN_PRIMARY_FONT_MIN := 16

const UI_BTN_SECONDARY_SIZE := Vector2(280, 100)
const UI_BTN_SECONDARY_FONT := 24
const UI_BTN_SECONDARY_FONT_MIN := 14

const UI_BTN_DIALOG_SIZE := Vector2(220, 100)
const UI_BTN_DIALOG_FONT := 24
const UI_BTN_DIALOG_FONT_MIN := 14
# Lift confirm/consent dialogs above true vertical center for easier reach on phones.
const UI_DIALOG_RAISE_PX := 160.0
# Milder lift for the victory screen so the layout stays readable.
const UI_VICTORY_RAISE_PX := 100.0

const UI_BTN_NAV_SIZE := Vector2(124, 130)
const UI_BTN_NAV_GAP := 56.0
const UI_BTN_NAV_FONT := 22
const UI_BTN_NAV_FONT_MIN := 12
const UI_BTN_NAV_ICON_PX := 64.0

const UI_BTN_PANEL_SIZE := Vector2(460, 100)
const UI_BTN_PANEL_FONT := 24
const UI_BTN_PANEL_FONT_MIN := 14

const UI_BTN_TAB_SIZE := Vector2(240, 110)
const UI_BTN_TAB_FONT := 42
const UI_BTN_TAB_FONT_MIN := 26

const MENU_TEXT_OUTLINE := 10

const UI_BODY_FONT_SIZE := 26
const UI_BODY_FONT_SIZE_LARGE := 32
const UI_BODY_TITLE_FONT_SIZE := 46

const ICON_INFINITY := "res://resources/icons/icon_infinity.svg"
const ICON_HINT_ON := "res://resources/icons/icon_hint_on.svg"
const ICON_HINT_OFF := "res://resources/icons/icon_hint_off.svg"
const TILE_SHIFTER := "res://resources/tiles/tile_shifter.svg"
const TILE_GREEN := "res://resources/tiles/tile_green.svg"
const TILE_YELLOW := "res://resources/tiles/tile_yellow.svg"
const TILE_BLUE := "res://resources/tiles/tile_blue.svg"
const TILE_EMPTY := "res://resources/tiles/tile_empty.svg"
const TILE_SHIFTER_UP := "res://resources/tiles/tile_shifter_up.svg"
const TILE_SHIFTER_DOWN := "res://resources/tiles/tile_shifter_down.svg"
const TILE_SHIFTER_LEFT := "res://resources/tiles/tile_shifter_left.svg"
const TILE_SHIFTER_RIGHT := "res://resources/tiles/tile_shifter_right.svg"
const TILE_LOCK := "res://resources/tiles/tile_lock.svg"
const DEFAULT_FONT_SCALE := 1.1
## Georgian / Ukrainian glyphs read large — keep slightly under other locales.
const NON_PIXEL_LOCALE_FONT_SCALE := 0.9
## Alias kept for existing call sites.
const GEORGIAN_FONT_SCALE := NON_PIXEL_LOCALE_FONT_SCALE
const DISABLED_ICON_MODULATE := Color(0.55, 0.55, 0.55, 1.0)
const TOGGLE_MASK_AMBER := Color(1.0, 0.78, 0.2, 0.4)
const TOGGLE_MASK_LOCK := Color(0.95, 0.28, 0.38, 0.45)
const TOGGLE_MASK_WHITE := Color(1.0, 1.0, 1.0, 0.4)

const CAMPAIGN_TUTORIALS_DIR := "res://levels/tutorials/"
const CAMPAIGN_EASY_DIR := "res://levels/easy/"
const CAMPAIGN_MEDIUM_DIR := "res://levels/medium/"
const CAMPAIGN_HARD_DIR := "res://levels/hard/"
const DEV_LEVELS_DIR := "user://levels/"

## True for yellow/blue — the two colours that must stay balanced.
static func is_basic_tile(state: int) -> bool:
	return state == TileState.YELLOW or state == TileState.BLUE

## True for any tile the solver may place (colours, joker, shifter).
static func is_solvable_tile(state: int) -> bool:
	return state in [TileState.YELLOW, TileState.BLUE, TileState.JOKER, TileState.SHIFTER]

## True for tiles the hint system may reveal (same set as solvable).
static func is_hintable_tile(state: int) -> bool:
	return is_solvable_tile(state)

## Starting hint quota for a generated puzzle; hard gets more, easy gets fewer.
static func hint_limit_for_difficulty(difficulty: int) -> int:
	match difficulty:
		PuzzleGenerator.Difficulty.EASY:
			return HINT_LIMIT_EASY
		PuzzleGenerator.Difficulty.HARD:
			return HINT_LIMIT_HARD
		_:
			return HINT_LIMIT_MEDIUM


## True when running without a display (CI, `godot --headless -s`, export pipelines).
## `OS.has_feature("headless")` is not set for `--headless` CLI launches.
static func is_headless_run() -> bool:
	if OS.has_feature("headless"):
		return true
	if DisplayServer.get_name().to_lower() == "headless":
		return true
	var args := OS.get_cmdline_args()
	for i in range(args.size()):
		var arg: String = args[i]
		if arg == "--headless":
			return true
		if arg == "--display-driver" and i + 1 < args.size() and args[i + 1] == "headless":
			return true
		if arg.begins_with("--display-driver=") and arg.get_slice("=", 1) == "headless":
			return true
	return false
