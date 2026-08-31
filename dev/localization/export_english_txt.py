"""Export English strings from translations.csv to editable .txt files."""
import csv
import os
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CSV_PATH = os.path.join(ROOT, "resources", "localization", "translations.csv")
OUT_DIR = os.path.join(ROOT, "resources", "localization", "edit")


def categorize(k: str) -> str:
	if k.startswith("TUT"):
		return "01_tutorial"
	if k.startswith("HTP_") or k.startswith("UI_HTP_"):
		return "02_how_to_play"
	if k.startswith(("STAR_", "UI_STAR_", "UI_STAT_", "STAT_")) or k in {
		"UI_LEVEL", "UI_LOCKED", "DIFF_TUTORIALS", "DIFF_EASY", "DIFF_MEDIUM", "DIFF_HARD",
		"UI_CUSTOM_LVL", "UI_NO_PLAYABLE_LEVELS", "UI_NO_CUSTOM_LEVELS", "UI_SELECT_LEVEL",
		"UI_LEVEL_SELECT", "UI_CORE", "UI_CUSTOM", "UI_LEVEL_STAR_GOALS",
		"UI_TAP_STARS_FOR_GOALS", "UI_LEVEL_COMPLETED", "UI_STAT_TIME_LEFT",
		"UI_STAT_GREEN_TILES", "UI_STAT_SHIFTER_MOVES", "UI_TIMES_UP",
	}:
		return "03_levels_and_stars"
	if k.startswith("UI_") or k.startswith("CONFIRM_") or k.startswith("SESSION_") or k in {
		"UI_SAVE_DELETED", "UI_CUSTOM_DELETED", "UI_UNLOCK_ALL_DONE",
	}:
		return "04_ui_menus"
	if k.startswith("MSG_") or k in {"UI_MOVES", "UI_COUNTER_GREEN", "UI_DEV", "UI_LVL", "UI_TIME"}:
		return "05_gameplay_hud"
	if k.startswith("CREDITS") or k.startswith("SPLASH") or k.startswith("UI_SPLASH"):
		return "06_meta"
	if k in {
		"TUTORIAL", "UI_TUTORIAL", "UI_COMPLETED", "UI_YOU_WIN", "UI_PLAY_AGAIN", "UI_NEXT_LEVEL", "UI_ALL_COMPLETED",
		"UI_CUSTOM_COMPLETED", "UI_PUZZLE_SOLVED", "UI_LEVEL_SOLVABLE", "UI_RETURN", "UI_PAUSED",
		"UI_COMPLETION_TIME", "UI_TIMES_UP_UNSOLVED", "UI_USED", "UI_UNLIMITED",
	}:
		return "07_game_flow"
	if k.startswith("ERR_") or k.startswith("ERROR_") or k.startswith("WARN_"):
		return "09_errors"
	if k.startswith(("ED_", "UI_EDIT", "UI_TEST", "UI_LOCK", "UI_UNIQUE", "UI_ALLOW")) or k in {
		"UI_EDIT_MODE", "UI_TEST_MODE", "UI_LOCK_WALLS", "UI_UNIQUE_SOLVE", "UI_ALLOW", "Wall",
		"Empty (Clear)", "Yellow Tile", "Blue Tile", "Joker Tile",
		"Shifter Tile Link Tool", "Equals (=) Link Tool", "Not Equals (×) Link Tool",
		"UI_LEVEL_EXISTS_OVERWRITE", "UI_LEVEL_SOLVABLE",
	}:
		return "10_editor"
	return "08_other"


HEADER = """# English game text — edit the lines below each [KEY].
# Do NOT change or remove [KEY] headers. Edit only the text under them.
# Keep placeholders as-is: %s, %d, %d/%d, etc.
# Blank line ends a string block. Use a single blank line inside text if needed.
# Files in this folder are for editing only; the game reads translations.csv.

"""

README = """ENGLISH TEXT EDITING GUIDE
==========================

These .txt files contain every English string from the game (360 keys).

HOW TO EDIT
-----------
1. Open the file for the section you want to change.
2. Find the [KEY_NAME] block.
3. Change the text lines below it (not the [KEY] line itself).
4. Save the file.
5. Send the edited file(s) back and ask to update translations.csv.

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
- Some strings use BBCode ([b], [img], etc.) — leave tags intact.
- Tutorial/HTP strings may include %s where tile icons are inserted.
- Editor strings (10_editor.txt) are mostly English-only in the editor UI.
"""

LABELS = {
	"01_tutorial": "Tutorial dialogue and step prompts",
	"02_how_to_play": "How To Play overlay",
	"03_levels_and_stars": "Level select, stars, difficulty",
	"04_ui_menus": "Menus, options, dialogs",
	"05_gameplay_hud": "In-game HUD and status",
	"06_meta": "Splash and credits",
	"07_game_flow": "Victory, pause, completion",
	"08_other": "Miscellaneous",
	"09_errors": "Validation error messages",
	"10_editor": "Level editor strings",
}


def format_block(key: str, text: str) -> str:
	block = f"[{key}]\n"
	if text:
		block += text.replace("\r\n", "\n").replace("\r", "\n")
	block += "\n\n"
	return block


def main() -> None:
	with open(CSV_PATH, "r", encoding="utf-8") as f:
		rows = list(csv.reader(f))

	entries: list[tuple[str, str]] = []
	for row in rows[1:]:
		if not row or not row[0].strip():
			continue
		key = row[0].strip()
		en = row[1] if len(row) > 1 else ""
		entries.append((key, en))

	cats: dict[str, list[tuple[str, str]]] = defaultdict(list)
	for key, en in entries:
		cats[categorize(key)].append((key, en))

	os.makedirs(OUT_DIR, exist_ok=True)

	with open(os.path.join(OUT_DIR, "README.txt"), "w", encoding="utf-8", newline="\n") as f:
		f.write(README)

	with open(os.path.join(OUT_DIR, "00_all_english.txt"), "w", encoding="utf-8", newline="\n") as f:
		f.write(HEADER.replace("Files in this folder", "This file lists all keys"))
		for key, en in entries:
			f.write(format_block(key, en))

	for cat in sorted(cats.keys()):
		path = os.path.join(OUT_DIR, f"{cat}.txt")
		with open(path, "w", encoding="utf-8", newline="\n") as f:
			title = LABELS.get(cat, cat)
			f.write(HEADER + f"# Section: {title}\n\n")
			for key, en in cats[cat]:
				f.write(format_block(key, en))

	print(f"Exported {len(entries)} keys to {OUT_DIR}")
	for cat in sorted(cats.keys()):
		print(f"  {cat}.txt — {len(cats[cat])} keys")


if __name__ == "__main__":
	main()
