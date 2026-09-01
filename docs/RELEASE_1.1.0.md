# Spaceblox 1.1.0 — Export checklist & device QA

Use this before uploading **1.1.0** to Google Play. Live store build today is **1.0.1**.

---

## A. Pre-export (local)

### 1. Run automated checks

```powershell
# From repo root
powershell -File tools/run_logic_tests.ps1
powershell -File tools/run_export_smoke.ps1
```

Both must finish without errors.

### 2. Confirm `export_presets.cfg` (gitignored — your machine only)

Copy from `export_presets.example.cfg` if missing. Verify:

| Setting | Expected |
|---------|----------|
| `package/unique_name` | `com.spaceblox.game` |
| `version/name` | `1.1.0` |
| `version/code` | **Higher than Play Console** (example template uses `38` — bump if 1.0.1 already used it) |
| `godot_play_game_services/game_id` | `622640847363` |
| Release keystore | Valid path + passwords (not committed) |
| Preset **Android Play (AAB)** | Export format = AAB, `package/signed=true` |

Also check **Project → Export → Android Play (AAB) → Gradle Build → Play Games Services** shows game id `622640847363`.

### 3. Play Console prerequisites

- [ ] Play Games project linked to `com.spaceblox.game`
- [ ] All **23 achievements published** (not draft)
- [ ] `resources/play_games/play_games_achievement_ids.json` filled with `Cgk…` ids (done locally)
- [ ] Your test Google account is a **license tester** or on **internal/closed testing**

### 4. Editor export

1. **Project → Export…**
2. Select **Android Play (AAB)**
3. **Export Project** → save e.g. `build/spaceblox-1.1.0.aab`
4. Note the **version code** you exported (must monotonically increase)

### 5. Upload to Play Console

1. **Testing → Internal testing** (or Closed) → **Create new release**
2. Upload the AAB
3. Add release notes (short: achievements, Play Games sync, cloud save improvements)
4. **Review release → Start rollout to testers**
5. Open the **opt-in link** on the test device and install/update from Play Store (or use **Internal app sharing** for a faster APK/AAB sideload if you use that flow)

> Prefer installing the **same signed build** testers will get from Play — sideloading a debug APK skips some Play Services integration paths.

---

## B. Device QA script

**Device:** Physical Android phone (emulator Play Games is unreliable)  
**Account:** License tester / internal-track tester, signed into Play Games  
**Build:** 1.1.0 from internal or closed track  
**Time:** ~45–60 minutes for full pass

Record results: `PASS` / `FAIL` / `SKIP` + notes.

---

### B0. Setup

| # | Step | Expected | Result |
|---|------|----------|--------|
| 0.1 | Install 1.1.0 over 1.0.1 (or fresh install) | App opens to main menu | |
| 0.2 | Settings → Apps → Spaceblox → confirm version **1.1.0** | Matches export | |
| 0.3 | Device signed into Google account used as license tester | | |

---

### B1. First launch & main menu (P1 refactor)

Use **fresh install** or **Clear storage** for boot/consent tests.

| # | Step | Expected | Result |
|---|------|----------|--------|
| 1.1 | Cold start after clear data | Boot splash → title intro (or skip with tap after consent) | |
| 1.2 | First launch: privacy consent | Consent dialog before full menu; Accept continues | |
| 1.3 | Tap **How to play** | Overlay opens; prev/next pages work; back closes | |
| 1.4 | Tap **Credits** | Credits overlay; close restores menu | |
| 1.5 | Hold version label ~3s in credits | Dev mode toggle flash (optional; debug only) | |
| 1.6 | Tap **Options** → back | Options open/close; no stuck chrome | |
| 1.7 | System back on main menu (no overlay) | App exits or behaves as before | |

---

### B2. Play Games sign-in & achievements

| # | Step | Expected | Result |
|---|------|----------|--------|
| 2.1 | Play a campaign level → **clear** (first time) | Local achievement toast; **First Clear** (or tier) in app list | |
| 2.2 | Open **Achievements** from main menu | Unlocked count increases; NEW badges on unseen | |
| 2.3 | Open **Google Play Games** app → Spaceblox achievements | Same unlock appears (may take a few seconds) | |
| 2.4 | Clear **10+ unique** campaign levels without hints (or time) | Bronze tier unlocks for relevant families only (not silver/gold early) | |
| 2.5 | **Settings → Apps → Spaceblox → Clear storage** (or uninstall/reinstall), same Google account | Sign in again when prompted | |
| 2.6 | After sign-in, open achievements in-game | Previously unlocked achievements **imported** from Play (pull merge) | |

**FAIL clues:** No Play overlay unlock → check `play_games_achievement_ids.json` in build, game id, SHA-1 in Play Console, tester account.

---

### B3. Cloud save

| # | Step | Expected | Result |
|---|------|----------|--------|
| 3.1 | Main menu → **Options** → cloud row | Shows **Sign in** or **Sync** (not greyed “Play Games needed”) | |
| 3.2 | Tap cloud → sign in if needed | Sign-in succeeds; button shows **Sync** | |
| 3.3 | Clear a few levels, then **Sync** | Success status (green); no crash | |
| 3.4 | *(Optional, two devices)* Different progress on two devices → Sync on second | Merge dialog: local vs cloud stats; choice applies | |
| 3.5 | Mid-level: play halfway → force-stop app → reopen → **Resume** | Session restores board state | |

---

### B4. In-app review

Review only shows when **all** of these are true (`InAppReviewLogic`):

- Campaign level (not tutorial, not custom)
- **≥ 2 stars** on that clear
- **≥ 5 unique** campaign clears total (lifetime)
- **≥ 5 minutes** in current app session
- Fewer than **3** prompts lifetime; **90 days** since last prompt

| # | Step | Expected | Result |
|---|------|----------|--------|
| 4.1 | Play **≥ 5 minutes** in one session | Timer/session accumulates | |
| 4.2 | Clear a campaign level with **2+ stars** (fast + no hints helps) | After victory, Google review UI **may** appear (not guaranteed — Play controls frequency) | |
| 4.3 | If no prompt, repeat on another day or second device | OK to mark **SKIP** if eligibility met but Play didn’t show UI | |

**Tip:** Use a save with 5+ clears already, start a long session, then three-star a medium level.

---

### B5. Regression smoke (quick)

| # | Step | Expected | Result |
|---|------|----------|--------|
| 5.1 | Level select → play → **pause** → resume | NEW badges layout OK; game resumes | |
| 5.2 | Pause → **Options** → back | Returns to pause menu | |
| 5.3 | Banner ad on main menu (if consent allows) | Banner loads or empty slot without crash | |
| 5.4 | Change language in options | UI updates; main menu HTP/credits still work | |
| 5.5 | Tutorial flow from main menu | Tutorial intro or direct launch works | |

---

### B6. Ship gate

All **required** rows must be **PASS** (or documented **SKIP** with reason):

- [ ] B1 boot + consent (fresh install)
- [ ] B2.1–2.3 achievement push
- [ ] B2.6 achievement pull (after clear data)
- [ ] B3.1–3.3 cloud sign-in + sync
- [ ] B5 regression smoke

**Optional but recommended:** B2.4 incremental tiers, B3.4 merge dialog, B4 review.

---

## C. After QA passes

1. Set release date in `CHANGELOG.md` for `[1.1.0]`
2. Play Console → **Production** (or staged rollout) with same AAB
3. Store listing: mention achievements & cloud save if desired
4. Keep **1.0.1** users on upgrade path (same package name, higher version code)

---

## D. Quick troubleshooting

| Symptom | Check |
|---------|--------|
| Play Games sign-in fails | Game id in export preset; app signing cert SHA-1 in Play Console / Firebase if used |
| Achievements don’t sync | `play_games_achievement_ids.json` bundled; achievements **published** in Console |
| Cloud always stub | Real device + Play Games plugin in export; not desktop build |
| Review never shows | Session length, star count, unique clears; Play may still suppress UI |
| Boot intro broken | Clear data test; skip tap only after privacy accepted |

See also [`ROADMAP.md`](ROADMAP.md) and [`CODE_REVIEW.md`](CODE_REVIEW.md).
