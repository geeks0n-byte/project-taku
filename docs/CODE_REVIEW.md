# Spaceblox — Code Review

*Fresh audit: September 1, 2026 (evening). **1.0.1** live on Google Play; **1.1.0** in local development.*

## Executive summary

| Area | Verdict |
|------|---------|
| **Puzzle core** | Strong — generator/validator/solver isolated, heavily tested |
| **Platform integrations** | Play Games, cloud save, ads, in-app review wired with pure-logic helpers |
| **Architecture** | Good — controllers/helpers split from monolithic scenes; some large files remain |
| **Automated tests** | **336 passed, 0 failed** (headless, Godot 4.7.2) |
| **Ship readiness** | Code looks merge-ready; **device QA + commit local work** remain before store upload |
| **Repo hygiene** | Clean — generated Play Games sidecars gitignored; orphan UID and empty folder removed |

No new **P0** logic defects found in this pass. Prior high-severity bugs (cloud dismiss, Play pull merge, phantom level badge, achievement toasts, Play Review AAR) appear fixed in the working tree.

---

## Project layout

| Path | Role |
|------|------|
| `scripts/` | 82 GDScript files — gameplay, UI, save, achievements, platform services |
| `scenes/` | 12 runtime scenes (menu, game, level select/editor, overlays) |
| `levels/` | 61 campaign `.tres` (easy 30, medium 20, hard 10, tutorials 1) |
| `resources/` | Art, audio, fonts, localization CSV + `.translation`, Play Games assets |
| `addons/` | AdMob, Play Games, Play Review, android_splash, godot_ai (dev MCP) |
| `tests/` | 9 logic modules + export smoke |
| `tools/` | Godot resolver, export/achievement scripts, ProGuard/R8 |
| `dev/` | Asset-gen renders, localization sync (excluded from Android export) |
| `docs/` | This file, release checklist, privacy policy, store graphics |

**Autoloads (11):** `GlobalGameManager`, `SaveManager`, `AchievementManager`, `CloudSaveManager`, `PlayGamesManager`, `BgmManager`, `UiSfx`, `SpaceBackground`, `AdsManager`, `GodotPlayGameServices`, `InAppReview`, plus dev `_mcp_game_helper`.

---

## Strengths

- **Pure puzzle layer** — `PuzzleGenerator`, `PuzzleSolver`, `PuzzleValidator` with no scene coupling; star bits via `LevelStars`.
- **Data-driven content** — `AchievementCatalog`, `LevelData` resources, `translations.csv` with hygiene checks in CI.
- **Small sync helpers** — `CloudSaveLogic`, `PlayGamesAchievementSyncLogic`, `InAppReviewLogic`, `SessionSerialization`, `LevelUtils.campaign_level_exists()`.
- **Headless gating** — `GameConstants.is_headless_run()` disables BGM, Play Games, toasts, MCP in tests/CI.
- **Scene decomposition** — `GameMain` → session/victory controllers; `main_menu.gd` → boot intro, consent, HTP, credits, badges; `options_menu.gd` → cloud/confirm/debug helpers.
- **Android polish** — safe insets, boot splash plugin, UMP consent, atomic `progression.cfg` writes, export smoke validates AAR + exclude filters.
- **Play Games** — push on unlock, pull merge (`UNLOCKED` only, not `REVEALED`), incremental tier steps, debug unlock can suppress push.

---

## Architecture notes

| Component | Lines (approx.) | Notes |
|-----------|-----------------|-------|
| `hud_layout.gd` | ~2,800 | Central HUD/dialog/font helper — works but is the main maintainability hotspot |
| `main_menu.gd` | ~590 | Reasonable after helper extraction |
| `options_menu.gd` | ~760 | Cloud + confirm flows; debug bar separated |
| `ads_manager.gd` | ~720 | Consent → init → banner/rewarded lifecycle |
| `save_manager.gd` | ~716 | Progression, locale sync, cloud blob fields |

**Patterns:** autoload singletons for cross-scene state; `RefCounted` controllers; signal-driven UI; `GlobalGameManager.go_to_scene()` for navigation.

---

## Code quality findings

### Fixed / verified in working tree (no action)

| Issue | Status |
|-------|--------|
| Cloud merge dismiss stuck `is_syncing` | `OptionsMenuConfirm.hide()` calls `resolve_sync_choice(false)` |
| Play pull treated `REVEALED` as unlocked | `play_achievement_is_unlocked()` checks state `== 0` only |
| Missing `PlayReview-release.aar` | Vendored; export smoke checks |
| Phantom level-61 unseen badge | `campaign_level_exists()` + prune on load |
| Purple Rain / Rules Reader no toast | `_apply_state(true)` on notify |
| Debug unlock-all skipped achievements | `sync_from_progress()` + optional Play push suppress |
| ONE MORE LEVEL / custom-delete i18n drift | Locales synced in uncommitted `translations.csv` |

### Open — low / acceptable

| Item | Severity | Notes |
|------|----------|-------|
| Remote deploy → no audio until manual relaunch | **P3** | Dev-only Godot/Android quirk; production installs OK; workarounds reverted |
| Debug unlock can push to Play Games when signed in | **P3** | Debug-only; suppress flag exists for unlock-all |
| `max_unlocked_level` may be `last + 1` | **P3** | Intentional for folder-complete; phantom levels never get unseen badges |
| No E2E for Play overlay, ads, review | **P2** | Not worth CI for 1.1.0; manual device QA |

### Tech debt — resolved (Sept 1 evening)

| Item | Resolution |
|------|------------|
| Dead `handle_cell_click()` | Removed from `editor_playtest_controller.gd` |
| `legacy_victory_panel` shim + scene node | Removed; playtest end screen uses `PlaytestEndLayer` only |
| Runtime legacy HUD child cleanup | Removed from `options_menu.gd`, `hud_layout.gd`, `options_menu_debug_bar.gd` |
| `BIT_MOVES` / `BIT_GREEN` aliases | Removed from `level_stars.gd` (bit layout unchanged) |

### Optional (1.2.x)

| Item | Severity | Notes |
|------|----------|-------|
| Split `hud_layout.gd` | **P3** | ~2,800 lines — main maintainability hotspot |
| Color-blind tile patterns | **P3** | Accessibility |
| TalkBack pass | **P3** | Android a11y |

---

## Repo hygiene

### Resolved (Sept 1 evening)

- Deleted empty `docs/_achievement_audit/`
- Deleted orphan `tools/_tmp_check_icon.gd.uid`
- Gitignored and untracked `resources/play_games/achievement_import/*.translation` and `*.zip` (source CSVs/PNGs remain in git)
- `play_achievement_ids.csv` superseded by `catalog_id_mapping.csv` ✓

### Generated / duplicate artifacts

These are **editor/build outputs** (now gitignored):

| Path | Notes |
|------|-------|
| `resources/play_games/achievement_import/*.translation` | Godot CSV import sidecars — regenerate when CSVs change |
| `resources/play_games/achievement_import/*.zip` | Build output from `export_play_achievements_zip.py` |
| `resources/play_games/achievement_icons_512/` vs `achievement_import/*.png` | Staging vs import copies — intentional workflow, but duplicates bytes |

Keep source CSVs, PNGs, and `catalog_id_mapping.csv` in git; regenerate zips at release time.

### Intentional templates (keep)

- `export_presets.example.cfg`, `tools/godot.local.env.example`
- `resources/play_games/play_games_achievement_ids.example.json`
- `resources/play_games/game_description_translations.txt` — Play Console copy-paste helper (untracked)

### Unused game code

**No orphan scripts or scenes** in `scripts/` or `scenes/`. All 82 scripts are referenced via scenes, autoloads, `preload()`, `class_name`, or tests. AdMob sample scenes under `addons/admob/gdscript/sample/` are excluded from export.

### Correctly gitignored (do not commit)

`.godot/`, `android/`, `.godot-ci/`, `export_presets.cfg`, keystores, `.cursor/`

---

## Uncommitted local work

Large working tree on `main` (not yet committed after `48dacf1`):

- Achievement/debug Play Games suppress, save pruning, level-select UI, shifter/nav SVGs
- Localization (ONE MORE LEVEL desc, custom-delete toast, Play Console play-desc templates)
- Play Games import CSVs/zips, `play_games_locales.json`
- Docs (`CODE_REVIEW.md`, `ROADMAP.md`)
- Integration test update

**Recommend one or two focused commits before 1.1.0 export** so release tag matches shipped bits.

---

## Security & privacy

- Cloud save: progress-based merge + user choice on tie; mid-level sessions excluded from blobs (`SessionSerialization`).
- Local save: atomic write via temp + rename; format v3 documented in privacy policy.
- Debug tools: `GlobalGameManager.debug_tools_enabled` + credits easter-egg; not persisted.
- Play Games IDs in repo are public Console identifiers, not secrets.
- Signing keys / `export_presets.cfg` correctly excluded.

---

## Testing & CI

**Run locally:**

```powershell
powershell -File tools/run_logic_tests.ps1      # 336 assertions
powershell -File tools/run_export_smoke.ps1
```

**CI:** `.github/workflows/logic-tests.yml` — Godot 4.7.2 import → export smoke → logic tests.

| Suite | Coverage |
|-------|----------|
| `test_puzzle` | Generator, solver, validator, stars |
| `test_save_ui` | Save migration, pseudolocale |
| `test_hints` | Hint system |
| `test_achievements` | Catalog rules, icons |
| `test_integration` | All campaign levels load, translation hygiene |
| `test_scene_smoke` | `main_menu.tscn` load |
| `test_play_games` | Sync logic, UNLOCKED filter |
| `test_session` | Session serialization |
| `test_achievement_manager` | Grant, merge, toasts |

**Not covered:** runtime Play Games overlay, AdMob fill, in-app review dialog, boot intro animation, device audio paths.

Headless exit may log Godot `ObjectDB`/RID leak warnings — pre-existing engine noise; tests still exit 0.

---

## Prioritized actions

1. **Commit** local 1.1.0 polish (or split: gameplay/save vs localization vs Play Games metadata).
2. **Device QA** per `docs/RELEASE_1.1.0.md` — Play sign-in, achievement push/pull, cloud merge, review prompt, boot intro.
3. **Optional (1.2.x)** — split `hud_layout.gd`; color-blind tile patterns; TalkBack pass.

---

## Verdict

**1.1.0 is in good shape for ship** after commit + device QA. Architecture is sound, tests are green, repo hygiene and listed P3 tech debt are resolved. Remaining gaps are process (uncommitted work) and manual validation of Play Games / ads / review on a physical device — not structural code defects.
