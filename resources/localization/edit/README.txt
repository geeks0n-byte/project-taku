ENGLISH TEXT EDITING GUIDE
==========================

These .txt files contain every English string from the game (360 keys).

HOW TO EDIT
-----------
1. Open the file for the section you want to change (or 00_all_english.txt for everything).
2. Find the [KEY_NAME] block.
3. Change the text lines below it (not the [KEY] line itself).
4. Save the file.
5. Ask to update translations.csv from your edits (or run: python tools/sync_english_text.py import).

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
Export from CSV:  python tools/sync_english_text.py export
Import to CSV:    python tools/sync_english_text.py import
Import one file:  python tools/sync_english_text.py import 01_tutorial.txt
