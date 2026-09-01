# Changelog

All notable changes to Spaceblox are documented here.

## [1.1.0] — Unreleased

*Next Play Store release. Skips 1.0.2. Integration polish and Play Games services — daily puzzle and stats are **1.2.0**.*

### Added
- Local achievements (catalog, tiers, hidden/secret, cup icons, toasts, list UI)
- Achievements list header showing unlocked / total count; per-cell NEW badges
- Notification badges on main menu, pause menu, and level select
- Cloud save progress-based merge with tie-breaker prompt
- Play Games achievement sync (incremental tier steps, pull/push logic)
- In-app review flow (autoload + `play_review` plugin)
- `SessionSerialization` helper; session serialize ↔ restore tests
- Pseudolocale (`ǪÀ TEST`) for layout QA
- Main menu / options debug bars; level-select Custom tab (debug builds)
- Space background module splits; CI export smoke; shared Godot resolver (`tools/godot.env`, `ensure_godot.sh`, `resolve_godot.ps1`)
- Root `CHANGELOG.md`; `README.md`

### Changed
- Main menu notification badges: plain red `!` without circular background
- `PlayGamesManager` / `CloudSaveManager` use typed clients (no `.call()` reflection)
- `AchievementManager.maybe_check_monochrome_board` uses single-pass color scan
- `save_progress()` writes via temp file then atomic rename
- Pause menu badge layout refit on show

### Fixed
- Removed `class_name SaveManager` conflict with SaveManager autoload singleton
- Level select Custom debug button placement and width (text label vs icon buttons)
- Pause menu NEW badge position on first open
- `ui_manager.gd` unreachable code in `_refresh_status_label()`

### P0 integration (1.1.0)
- `AchievementManager.import_remote_unlock()` for Play Games pull merge
- `InAppReview.maybe_prompt_after_victory()` wired into `main.gd` victory path
- `play_review` plugin enabled in `project.godot`
- `AchievementManager.unlocked` → `PlayGamesManager.push_catalog_unlock` on local grant

### Architecture (1.1.0 scope, complete)
- Main menu refactor — `BootIntroController`, `MainMenu*` helpers wired into `main_menu.gd`
- Options refactor — `OptionsMenuCloud`, `OptionsMenuConfirm` wired
- `main.gd` dedupe — `GameSessionController` + `GameVictoryController`; `class_name GameMain`
- Removed duplicate `android-export-smoke.yml` CI workflow

## [1.2.0] — Planned

- Daily puzzle (seeded board, streak)
- Stats screen
- Play Games leaderboards (if a competitive metric is defined)

## [1.0.1] — 2026 (Play Store)

- Campaign puzzle gameplay (easy / medium / hard), tutorials, custom level editor
- Stars, level unlocks, mid-level session save/restore
- Google AdMob + UMP consent; menu banner
- Android safe insets, boot splash
- 7-locale i18n

## Skipped

- **1.0.2** — separate branch abandoned; changes folded into 1.1.0
