# Changelog

All notable changes to Spaceblox are documented here.

## [1.1.0] — Unreleased

Play Store release after live **1.0.0**.

### Added
- Achievements: catalog with tiers, hidden/secret entries, cup icons, unlock toasts, and a paged list (unlocked / total count, NEW badges)
- Notification badges on the main menu, pause menu, and level select
- Google Play Games achievement sync (unlock push, pull merge, incremental tiers)
- Cloud save with progress-based merge and a tie-breaker prompt when both copies look valid
- Colorblind tile patterns (options toggle; live board and level-select previews)
- TalkBack / screen-reader labels across menus, HUD, pause, level select, achievements, and dialogs
- Tutorial HUD walkthrough (pause, restart, rules, hint, undo, redo)
- In-app review prompt after a campaign victory
- Campaign levels renumbered into continuous easy / medium / hard ranges

### Changed
- Achievement list: hidden locked items show only a lock and `???` (no medal silhouette)
- Colorblind palette: green → lime and blue → royal blue for deuteranopia separation
- Main menu notification badges: plain red `!` (no circular background)
- Tutorial and how-to-play HUD layout; achievement cell descriptions no longer clip descenders
- Level-select NEW badges and card margins
- Secret pause auto-win requires a 3-second hold (same as the credits version hold); does not push to Play Games
- Options debug buttons no longer show a hover tooltip

### Fixed
- Cloud sync dismiss when Play Games pull/merge finishes
- Pause menu NEW badge position on first open
- Shifter direction arrows; Undo Nothing unlocking on easy/medium campaign clears
- Tutorial pause button locked until the last steps; pause menu saying New Puzzle on tutorial
- Popup clicks reaching the board (editor overwrite and other modal overlays)
- Custom editor save rejecting shape-only boards as unsolvable
- Save writes use a temp file then atomic rename

## [1.0.0] — 2026 (Play Store live)

- Campaign puzzle gameplay (easy / medium / hard), tutorials, custom level editor
- Stars, level unlocks, mid-level session save/restore
- Google AdMob + UMP consent; menu banner
- Android safe insets, boot splash
- 7-locale i18n
