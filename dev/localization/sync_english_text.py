#!/usr/bin/env python3
"""Export / import English game strings between translations.csv and edit/*.txt."""

from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CSV_PATH = ROOT / "resources" / "localization" / "translations.csv"
EDIT_DIR = ROOT / "resources" / "localization" / "edit"

HEADER = """# English game text — edit the lines below each [KEY].
# Do NOT change or remove [KEY] headers. Edit only the text under them.
# Keep placeholders as-is: %s, %d, %d/%d, etc.
# Blank line ends a string block. Use a single blank line inside text if needed.
# Files in this folder are for editing only; the game reads translations.csv.
"""

SECTIONS: list[tuple[str, str, callable]] = [
    (
        "01_tutorial.txt",
        "Tutorial dialogue and step prompts",
        lambda k: k.startswith("TUT") or k == "TUTORIAL_INTRO_PROMPT",
    ),
    (
        "02_how_to_play.txt",
        "How To Play overlay pages",
        lambda k: k.startswith(("HTP_", "UI_HTP_")),
    ),
    (
        "03_levels_and_stars.txt",
        "Level select, difficulty, star goals",
        lambda k: k.startswith(("DIFF_", "STAR_", "STAT_", "UI_STAR_", "UI_STAT_", "UI_LEVEL", "UI_CORE", "UI_CUSTOM", "UI_SELECT", "UI_TAP_STARS", "UI_LEVEL", "UI_LOCKED", "CUSTOM_", "NO_", "UI_TIME", "UI_MOVES", "COUNTER_", "UI_TIMES_UP")),
    ),
    (
        "04_ui_menus.txt",
        "Menus, options, confirmations, consent",
        lambda k: k.startswith(("UI_", "CONFIRM_", "SESSION_", "SAVE_", "UI_CUSTOM_DELETED", "UNLOCK_")),
    ),
    (
        "05_gameplay_hud.txt",
        "In-game HUD labels and hints",
        lambda k: k.startswith(("HINT_", "HUD_", "TOOLBAR_", "PAUSE_", "BTN_")),
    ),
    (
        "06_meta.txt",
        "Splash screen and credits",
        lambda k: k.startswith(("SPLASH_", "UI_SPLASH_", "CREDIT_", "CREDITS_")),
    ),
    (
        "07_game_flow.txt",
        "Victory, pause, completion messages",
        lambda k: k.startswith(("VICTORY_", "WIN_", "LOSE_", "COMPLETE_", "GAME_", "LEVEL_COMPLETE", "ALL_COMPLETE")),
    ),
    (
        "08_other.txt",
        "Misc strings",
        lambda k: True,
    ),
    (
        "09_errors.txt",
        "Puzzle validation error messages",
        lambda k: k.startswith(("ERR_", "ERROR_")),
    ),
    (
        "10_editor.txt",
        "Level editor strings",
        lambda k: k.startswith(("EDITOR_", "EDT_")),
    ),
]

KEY_RE = re.compile(r"^\[([A-Z0-9_]+)\]$")


def read_csv() -> tuple[list[str], dict[str, str]]:
    with CSV_PATH.open(newline="", encoding="utf-8") as f:
        rows = list(csv.reader(f))
    headers = rows[0]
    en_idx = headers.index("en")
    data: dict[str, str] = {}
    for row in rows[1:]:
        if not row or not row[0].strip():
            continue
        key = row[0].strip()
        en = row[en_idx] if en_idx < len(row) else ""
        data[key] = en
    return headers, data


def write_csv(headers: list[str], data: dict[str, str], order: list[str]) -> None:
    en_idx = headers.index("en")
    with CSV_PATH.open(newline="", encoding="utf-8") as f:
        rows = list(csv.reader(f))
    for row in rows[1:]:
        if not row or not row[0].strip():
            continue
        key = row[0].strip()
        if key in data:
            while len(row) <= en_idx:
                row.append("")
            row[en_idx] = data[key]
    with CSV_PATH.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerows(rows)


def format_block(key: str, text: str) -> str:
    lines = text.split("\n") if text else [""]
    body = "\n".join(lines)
    return f"[{key}]\n{body}\n"


def write_txt(path: Path, title: str | None, keys: list[str], data: dict[str, str]) -> None:
    parts = [HEADER.rstrip()]
    if title:
        parts.append(f"\n# Section: {title}")
    for key in keys:
        parts.append("")
        parts.append(format_block(key, data[key]).rstrip())
    parts.append("")
    path.write_text("\n".join(parts), encoding="utf-8")


def export_all() -> int:
    _, data = read_csv()
    keys = list(data.keys())
    order = keys[:]

    assigned: set[str] = set()
    for filename, title, matcher in SECTIONS[:-1]:
        section_keys = [k for k in keys if k not in assigned and matcher(k)]
        if not section_keys:
            continue
        assigned.update(section_keys)
        write_txt(EDIT_DIR / filename, title, section_keys, data)

    other_keys = [k for k in keys if k not in assigned]
    write_txt(EDIT_DIR / "08_other.txt", "Misc strings", other_keys, data)
    assigned.update(other_keys)

    write_txt(EDIT_DIR / "00_all_english.txt", None, keys, data)

    readme = f"""ENGLISH TEXT EDITING GUIDE
==========================

These .txt files contain every English string from the game ({len(keys)} keys).

HOW TO EDIT
-----------
1. Open the file for the section you want to change (or 00_all_english.txt for everything).
2. Find the [KEY_NAME] block.
3. Change the text lines below it (not the [KEY] line itself).
4. Save the file.
5. Ask to update translations.csv from your edits (or run: python dev/localization/sync_english_text.py import).

FORMAT
------
[KEY_NAME]
First line of text
Second line (optional)

[ANOTHER_KEY]
Single-line text

FILES
-----
00_all_english.txt     — everything in one file (good for search)
01_tutorial.txt        — tutorial dialogue and prompts
02_how_to_play.txt     — How To Play overlay pages
03_levels_and_stars.txt — level select, difficulty, star goals
04_ui_menus.txt        — menus, options, confirmations, consent
05_gameplay_hud.txt    — in-game HUD labels and hints
06_meta.txt            — splash screen, credits
07_game_flow.txt       — victory, pause, completion messages
08_other.txt           — misc strings
09_errors.txt          — puzzle validation error messages
10_editor.txt          — level editor (dev tool) strings

NOTES
-----
- %s, %d, %d/%d are placeholders — keep them in the same order/count.
- Some strings use BBCode ([b], [img], [color], etc.) — leave tags intact.
- Tutorial/HTP strings may include %s where tile icons are inserted.
- Editor strings (10_editor.txt) are mostly English-only in the editor UI.

SYNC COMMANDS
-------------
Export from CSV:  python dev/localization/sync_english_text.py export
Import to CSV:    python dev/localization/sync_english_text.py import
Import one file:  python dev/localization/sync_english_text.py import 01_tutorial.txt
"""
    (EDIT_DIR / "README.txt").write_text(readme, encoding="utf-8")
    print(f"Exported {len(keys)} keys to {EDIT_DIR}")
    return len(keys)


def parse_txt(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    out: dict[str, str] = {}
    i = 0
    while i < len(lines):
        line = lines[i]
        m = KEY_RE.match(line.strip())
        if not m:
            i += 1
            continue
        key = m.group(1)
        i += 1
        body_lines: list[str] = []
        while i < len(lines):
            nxt = lines[i]
            if KEY_RE.match(nxt.strip()):
                break
            body_lines.append(nxt)
            i += 1
        while body_lines and body_lines[0].strip() == "":
            body_lines.pop(0)
        while body_lines and body_lines[-1].strip() == "":
            body_lines.pop()
        out[key] = "\n".join(body_lines)
    return out


def import_files(targets: list[Path]) -> int:
    headers, data = read_csv()
    updated = 0
    for path in targets:
        parsed = parse_txt(path)
        for key, value in parsed.items():
            if key not in data:
                print(f"Warning: unknown key {key} in {path.name}", file=sys.stderr)
                continue
            if data[key] != value:
                data[key] = value
                updated += 1
    write_csv(headers, data, list(data.keys()))
    print(f"Updated {updated} English string(s) in {CSV_PATH.name}")
    return updated


def main() -> None:
    EDIT_DIR.mkdir(parents=True, exist_ok=True)
    if len(sys.argv) < 2 or sys.argv[1] == "export":
        export_all()
        return
    if sys.argv[1] == "import":
        if len(sys.argv) > 2:
            paths = [EDIT_DIR / p if not Path(p).is_absolute() else Path(p) for p in sys.argv[2:]]
        else:
            paths = sorted(EDIT_DIR.glob("*.txt"))
            paths = [p for p in paths if p.name not in ("README.txt", "00_all_english.txt")]
        import_files(paths)
        return
    print("Usage: sync_english_text.py [export|import [file ...]]", file=sys.stderr)
    sys.exit(1)


if __name__ == "__main__":
    main()
