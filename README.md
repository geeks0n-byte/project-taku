# Spaceblox

Mobile puzzle game built with **Godot 4.7.2** (GDScript). Place yellow, blue, and joker tiles on a grid while satisfying row/column balance rules, equals/not-equals constraints, and shifter pairs.

## Requirements

- [Godot 4.7.2](https://godotengine.org/) (Mono build matches `project.godot`)
- Android SDK/NDK for mobile exports (see `export_presets.cfg`)

## Run locally

Open the project in Godot and press Play, or run the main menu scene (`scenes/main_menu.tscn`).

## Tests

Headless logic tests cover puzzle validation, achievements, cloud-save merge rules, localization CSV hygiene, and all campaign levels:

```powershell
powershell -File tools/run_logic_tests.ps1
```

Godot path resolution (in order): `GODOT_EXE`, `tools/godot.local.env` (copy from `godot.local.env.example`), `godot` on `PATH`, cached `.godot-ci/`, or download with `-AllowDownload` / `GODOT_ALLOW_DOWNLOAD=1`. Version pin lives in `tools/godot.env`.

Or directly (when `godot` is on your PATH):

```bash
godot --headless --path . -s res://tests/run_logic_tests.gd
```

CI uses `tools/ensure_godot.sh` and runs the same suites via `$GODOT_EXE` in `.github/workflows/logic-tests.yml`.

## Project layout

| Path | Purpose |
|------|---------|
| `scripts/` | Game logic, HUD, save, achievements |
| `levels/` | Campaign `.tres` level data (easy / medium / hard / tutorials) |
| `scenes/` | Main menu, gameplay, UI overlays |
| `resources/` | Art, audio, localization CSV |
| `tests/` | Headless test runner |
| `addons/` | Android splash, Play Games, editor MCP (dev only) |
| `dev/` | Offline tooling, store assets, local docs (gitignored) |

## Localization

Source strings live in `resources/localization/translations.csv`. Supported locales: `en`, `es`, `de`, `fr`, `pl`, `ka`, `uk`. The editor reloads CSV on play; export builds use imported `.translation` binaries.

## Save data

Player progress is stored in `user://progression.cfg` (unlocks, stars, settings, achievements). Cloud sync uses Google Play Games on Android exports.
