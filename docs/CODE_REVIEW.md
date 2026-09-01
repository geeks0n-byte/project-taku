# Spaceblox — Project Code Review

*Updated September 1, 2026. **1.0.1** is live on Google Play. **1.1.0** is the next release (1.0.2 skipped). See [`ROADMAP.md`](ROADMAP.md) for active priorities.*

## Executive summary

- **1.0.1 is live** — core campaign puzzle game, stars/unlocks, session save, ads/consent, and Android polish.
- **1.1.0 is feature- and architecture-complete locally** — Play Games sync, in-app review, cloud save with merge-choice UI, and P1 refactors (main menu, options, `main.gd` controllers).
- **Ship blocker is device QA only** — sign-in, achievement sync, review prompt, cloud save merge dialog, boot intro on first launch.
- **Headless test suite** — ~284 assertions across 9 logic modules; CI on every push/PR.

## Strengths

- Puzzle core (`PuzzleGenerator`, `PuzzleSolver`, `PuzzleValidator`) separated and well tested
- `AchievementCatalog` data-driven; tier families, cup icons, hidden/secret ids
- Small pure helpers: `CloudSaveLogic`, `PlayGamesAchievementSyncLogic`, `InAppReviewLogic`, `SessionSerialization`
- `GameConstants.is_headless_run()` gates BGM, Play Games, toasts, MCP, and plugin singletons
- Android UX: safe insets, boot splash handoff, UMP consent, atomic `progression.cfg` writes
- Play Games: typed clients, push on unlock, silent pull via `import_remote_unlock()`
- Main menu split into focused helpers; boot intro isolated in `BootIntroController`

## Architecture (current)

| Area | Status | Notes |
|------|--------|-------|
| `main.gd` (`GameMain`) | ✅ Controllers wired | `GameSessionController` (debounced autosave + restore); `GameVictoryController` (victory, next/replay, review). Pause/system-back remain here |
| `main_menu.gd` | ✅ Refactored | ~584 lines; delegates to `BootIntroController`, `MainMenuDebugBar`, HTP, credits, tutorial, consent, badges |
| `options_menu.gd` | ✅ Refactored | `OptionsMenuCloud`, `OptionsMenuConfirm`, `OptionsMenuDebugBar` |
| `level_select.gd` | ✅ | Difficulty tabs + debug Custom tab; unseen badges |
| `pause_menu.gd` | ✅ | `MainMenuBadges`; badge refit on show |
| `achievement_manager.gd` | ✅ | Grant, pull merge, toasts |
| `play_games_manager.gd` | ✅ | Sign-in, snapshots, achievement push/pull |
| `space_background.gd` | ✅ Split | `space_background_*` modules |
| `save_manager.gd` | ✅ | Session I/O via `SessionSerialization`; atomic progression write |

## Code quality (open)

| Priority | Item | Status |
|----------|------|--------|
| **P0** | Device QA: Play Games, review, cloud merge, boot intro | 🟡 Open |
| **P1** | Main menu / options / `main.gd` refactors | ✅ Done |
| **P1** | Color-blind tile patterns; TalkBack pass | 🟡 Deferred → 1.2.x |
| **P2** | No device/E2E tests (Play Games overlay, review, ads) | 🟡 Open |

## Performance

- Generator wall-clock cap in gameplay + editor overlay *(done)*
- Monochrome achievement scan uses single-pass `uniform_fillable_color` *(done)*

## Testing & CI

**Suites (~284 assertions)** — `test_achievements`, `test_save_ui`, `test_hints`, `test_puzzle`, `test_integration`, `test_achievement_manager`, `test_play_games`, `test_session`, `test_scene_smoke`.

**CI:** `.github/workflows/logic-tests.yml` — Godot 4.7.2 import → export smoke → logic tests.

**Not covered:** UI interaction, Play Games runtime, in-app review plugin, ads, boot intro animation on device.

## Security & privacy

- Cloud save: progress-based merge + tie prompt; mid-level sessions excluded from cloud blobs
- Local save format documented in `docs/privacy-policy.html`
- Debug tools gated by `GlobalGameManager.debug_tools_enabled`
- **Risk:** debug unlock achievements can push to Play Games when signed in

## Prioritized next steps

1. Export signed AAB with `game_id=622640847363`
2. Device QA (achievements, review, cloud, first-launch boot + consent)
3. Ship **1.1.0**
4. **1.2.0** — daily puzzle + stats

See [`ROADMAP.md`](ROADMAP.md) for the full milestone breakdown.
