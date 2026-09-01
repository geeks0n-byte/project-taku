# Spaceblox — Roadmap

*Updated September 1, 2026. **1.0.1 is live on Google Play.** Next store release: **1.1.0** (skipping 1.0.2). See [`CHANGELOG.md`](../CHANGELOG.md).*

## Live — 1.0.1 (Play Store)

- Campaign puzzle gameplay (easy / medium / hard), tutorials, custom levels (editor)
- Stars, level unlocks, mid-level session save/restore
- Google AdMob + UMP consent; menu banner
- Android polish: safe insets, boot splash
- 7-locale i18n

## Skipped

- **1.0.2** — separate branch abandoned; work folded into **1.1.0** instead of a patch release.

## Next release — 1.1.0 *(ready for device QA)*

Integration polish, Play Games services, architecture refactors, and technical hardening — **not** daily puzzle / stats (those are **1.2.0**).

`project.godot` version is already **1.1.0**.

### Integration & polish

| Area | Status | Notes |
|------|--------|-------|
| **Achievements** | ✅ Done | Local catalog, tiers, cup badges, toasts, list UI, `unlocked / total` header, per-cell `!` badges |
| **Notification badges** | ✅ Done | `MainMenuBadges` on main menu + pause menu; unseen level badges in level select |
| **Play Games achievement sync** | ✅ Code / 🟡 QA | Push on unlock, pull merge, incremental tiers, 23 `Cgk…` ids configured. **Open:** device QA |
| **Play Console achievements** | ✅ Done | 23 achievements imported; tier cup icons; 300 XP total |
| **In-app review** | ✅ Code / 🟡 QA | `play_review` enabled; victory wiring in `GameVictoryController`. **Open:** device test |
| **Cloud save** | ✅ / 🟡 QA | Progress-based merge + tie prompt (`OptionsMenuCloud` + `OptionsMenuConfirm`); atomic saves |
| **Session / save** | ✅ Done | `GameSessionController` (debounced autosave + restore); `SessionSerialization` tests |
| **CI / tests** | ✅ Done | ~284 headless assertions; export smoke in `logic-tests.yml` only (duplicate workflow removed) |
| **Main menu refactor** | ✅ Done | `BootIntroController`, `MainMenuDebugBar`, HTP, credits, tutorial, consent wired; **584 lines** (was ~1631) |
| **Options refactor** | ✅ Done | `OptionsMenuCloud`, `OptionsMenuConfirm`, `OptionsMenuDebugBar` wired |
| **`main.gd` dedupe** | ✅ Done | `GameSessionController` + `GameVictoryController`; `class_name GameMain` |
| **Debug / QA** | ✅ Done | Options debug bar; level-select Custom tab; pseudolocale; Godot resolver tooling |

### Before 1.1.0 store build

**P0 — code** ✅ *complete*

**P0 — Play Console** ✅ *setup complete; QA remains*

1. Confirm Play Games **Game id** `622640847363` in local `export_presets.cfg`
2. **Device test:** sign-in → unlock push/pull → incremental tiers
3. **Device test:** in-app review prompt after strong clears
4. **Device test:** cloud save merge + tie-breaker dialog
5. **Optional:** achievement translations (`achievements_upload_i18n.zip`)

**P1 — architecture** ✅ *complete*

- Main menu, options, and `main.gd` controller migrations done locally

**Release checklist**

See **[`docs/RELEASE_1.1.0.md`](RELEASE_1.1.0.md)** for the full export checklist and device QA script.

1. Export signed **AAB** (version **1.1.0**, version code bumped)
2. Upload to internal/closed track; install on license-tester account
3. Pass device QA above
4. Set `CHANGELOG.md` **1.1.0** release date; publish Play listing notes
5. Promote to production

## 1.2.0 — Content & retention *(next milestone after 1.1.0)*

| Feature | Notes |
|---------|--------|
| **Daily puzzle** | Seeded daily board, streak counter, optional notification |
| **Stats screen** | Clears, stars, hints, time, achievement progress summary |
| **Play Games leaderboards** | Only if a meaningful competitive metric exists (e.g. daily streak, speed) |

## 1.2.x — Polish

| Area | Status |
|------|--------|
| **Accessibility** | Color-blind tile patterns; TalkBack pass beyond pause menu + achievements list |

## 1.3.0+ — Growth

- Play Games events / analytics funnel
- Share solved-board image
- In-app changelog / what's new
- iOS reassessment (no Play Games / Play review today)

## Deferred / low priority

- Online multiplayer / UGC marketplace
- Heavy meta-progression beyond stars and achievements

## How to prioritize

1. **Device QA** on a Play-enabled build → ship **1.1.0**
2. **1.2.0 player value** — daily puzzle + stats (+ leaderboards if metric is defined)
3. **Accessibility & polish** — when it blocks ship or causes bugs

See also [`docs/CODE_REVIEW.md`](CODE_REVIEW.md) for architecture notes.
