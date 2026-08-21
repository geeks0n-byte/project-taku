# Localization / translation hygiene
#
# Editor play sessions reload `resources/localization/translations.csv` via
# SaveManager._sync_translations_from_csv() so CSV edits apply without waiting
# for Godot to reimport `.translation` binaries.
#
# Before shipping a build:
# 1. Open the project in Godot so translations.csv reimports (or run Project → Reload).
# 2. Confirm Output has no "translations.csv: … empty cell" warnings from
#    SaveManager._verify_translation_hygiene().
# 3. Spot-check each locale in Options → Language.
#
# Headless logic tests:
#   powershell -File tools/run_logic_tests.ps1
#
# Or:
#   godot --headless --path . -s res://tests/run_logic_tests.gd
#
# CI: .github/workflows/logic-tests.yml
