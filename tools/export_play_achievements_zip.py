#!/usr/bin/env python3
"""Build Play Console achievement bulk-import ZIP for Spaceblox."""
from __future__ import annotations

import argparse
import csv
import json
import shutil
import zipfile
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TRANSLATIONS = ROOT / "resources" / "localization" / "translations.csv"
LOCALES_CONFIG = ROOT / "resources" / "play_games" / "play_games_locales.json"
ICONS_SRC = ROOT / "resources" / "play_games" / "achievement_icons_512"
OUT_DIR = ROOT / "resources" / "play_games" / "achievement_import"

# Short Play Console locale codes (must match Configuration > Manage translations).
DEFAULT_I18N_LOCALES = {
    "es": "es",
    "de": "de",
    "fr": "fr",
    "pl": "pl",
    "ka": "ka",
    "uk": "uk",
}

INCREMENTAL_STEPS = {
    "clears_bronze": 10,
    "clears_silver": 30,
    "clears_gold": 60,
    "no_hint_clear": 10,
    "hint_saver": 30,
    "no_hint_gold": 60,
    "on_time_bronze": 10,
    "on_time_silver": 30,
    "on_time_gold": 60,
}

TIER_LABEL_KEYS = {
    "clears_bronze": "ACH_TIER_BRONZE",
    "clears_silver": "ACH_TIER_SILVER",
    "clears_gold": "ACH_TIER_GOLD",
    "no_hint_clear": "ACH_TIER_BRONZE",
    "hint_saver": "ACH_TIER_SILVER",
    "no_hint_gold": "ACH_TIER_GOLD",
    "on_time_bronze": "ACH_TIER_BRONZE",
    "on_time_silver": "ACH_TIER_SILVER",
    "on_time_gold": "ACH_TIER_GOLD",
}

HIDDEN_IDS = {
    "im_blue",
    "shall_not_pass",
    "rules_reader",
    "purple_rain",
    "yellow_submarine",
    "pause_thinker",
}

# Play Games XP (~300 total): early milestones low, gold tiers and set clears highest.
ACHIEVEMENT_POINTS: dict[str, int] = {
    "first_clear": 5,
    "clears_bronze": 5,
    "clears_silver": 10,
    "clears_gold": 25,
    "first_hard": 10,
    "no_hint_clear": 10,
    "hint_saver": 15,
    "no_hint_gold": 30,
    "on_time_bronze": 5,
    "on_time_silver": 10,
    "on_time_gold": 25,
    "easy_set": 15,
    "medium_set": 25,
    "hard_set": 40,
    "three_star_debut": 10,
    "undo_nothing": 20,
    "ad_friend": 5,
    "im_blue": 5,
    "shall_not_pass": 5,
    "rules_reader": 5,
    "purple_rain": 5,
    "yellow_submarine": 5,
    "pause_thinker": 10,
}


@dataclass(frozen=True)
class AchievementRow:
    catalog_id: str
    play_name: str
    title_key: str
    desc_key: str
    list_order: int

    @property
    def points(self) -> int:
        return ACHIEVEMENT_POINTS[self.catalog_id]


ACHIEVEMENTS: list[AchievementRow] = [
    AchievementRow("first_clear", "FIRST CLEAR", "ACH_FIRST_CLEAR_NAME", "ACH_FIRST_CLEAR_DESC", 1),
    AchievementRow("clears_bronze", "ONE MORE LEVEL BRONZE", "ACH_CLEARS_BRONZE_NAME", "ACH_CLEARS_BRONZE_DESC", 2),
    AchievementRow("clears_silver", "ONE MORE LEVEL SILVER", "ACH_CLEARS_SILVER_NAME", "ACH_CLEARS_SILVER_DESC", 3),
    AchievementRow("clears_gold", "ONE MORE LEVEL GOLD", "ACH_CLEARS_GOLD_NAME", "ACH_CLEARS_GOLD_DESC", 4),
    AchievementRow("first_hard", "HARD START", "ACH_FIRST_HARD_NAME", "ACH_FIRST_HARD_DESC", 5),
    AchievementRow("no_hint_clear", "NO SPOILERS BRONZE", "ACH_NO_HINT_CLEAR_NAME", "ACH_NO_HINT_CLEAR_DESC", 6),
    AchievementRow("hint_saver", "NO SPOILERS SILVER", "ACH_HINT_SAVER_NAME", "ACH_HINT_SAVER_DESC", 7),
    AchievementRow("no_hint_gold", "NO SPOILERS GOLD", "ACH_NO_HINT_GOLD_NAME", "ACH_NO_HINT_GOLD_DESC", 8),
    AchievementRow("on_time_bronze", "TICK TOCK BRONZE", "ACH_ON_TIME_BRONZE_NAME", "ACH_ON_TIME_BRONZE_DESC", 9),
    AchievementRow("on_time_silver", "TICK TOCK SILVER", "ACH_ON_TIME_SILVER_NAME", "ACH_ON_TIME_SILVER_DESC", 10),
    AchievementRow("on_time_gold", "TICK TOCK GOLD", "ACH_ON_TIME_GOLD_NAME", "ACH_ON_TIME_GOLD_DESC", 11),
    AchievementRow("easy_set", "EASY DOES IT", "ACH_EASY_SET_NAME", "ACH_EASY_SET_DESC", 12),
    AchievementRow("medium_set", "MIDDLE MAN", "ACH_MEDIUM_SET_NAME", "ACH_MEDIUM_SET_DESC", 13),
    AchievementRow("hard_set", "HARD KNOCKS", "ACH_HARD_SET_NAME", "ACH_HARD_SET_DESC", 14),
    AchievementRow("three_star_debut", "THREE STAR DEBUT", "ACH_THREE_STAR_DEBUT_NAME", "ACH_THREE_STAR_DEBUT_DESC", 15),
    AchievementRow("undo_nothing", "UNDO NOTHING", "ACH_UNDO_NOTHING_NAME", "ACH_UNDO_NOTHING_DESC", 16),
    AchievementRow("ad_friend", "AD FRIEND", "ACH_AD_FRIEND_NAME", "ACH_AD_FRIEND_DESC", 17),
    AchievementRow("im_blue", "I'M BLUE", "ACH_IM_BLUE_NAME", "ACH_IM_BLUE_DESC", 18),
    AchievementRow("shall_not_pass", "YOU SHALL NOT PASS", "ACH_SHALL_NOT_PASS_NAME", "ACH_SHALL_NOT_PASS_DESC", 19),
    AchievementRow("rules_reader", "RULES READER", "ACH_RULES_READER_NAME", "ACH_RULES_READER_DESC", 20),
    AchievementRow("purple_rain", "PURPLE RAIN", "ACH_PURPLE_RAIN_NAME", "ACH_PURPLE_RAIN_DESC", 21),
    AchievementRow("yellow_submarine", "YELLOW SUBMARINE", "ACH_YELLOW_SUBMARINE_NAME", "ACH_YELLOW_SUBMARINE_DESC", 22),
    AchievementRow("pause_thinker", "PAUSE THINKER", "ACH_PAUSE_THINKER_NAME", "ACH_PAUSE_THINKER_DESC", 23),
]


def _load_translations() -> dict[str, dict[str, str]]:
    out: dict[str, dict[str, str]] = {}
    with TRANSLATIONS.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            key = row.get("keys", "").strip()
            if not key:
                continue
            out[key] = {k: (v or "") for k, v in row.items() if k != "keys"}
    return out


def _load_locale_map() -> dict[str, str]:
    if LOCALES_CONFIG.is_file():
        parsed = json.loads(LOCALES_CONFIG.read_text(encoding="utf-8"))
        locales = parsed.get("locales", parsed)
        if isinstance(locales, dict) and locales:
            return {str(k): str(v) for k, v in locales.items()}
    return {}


def _csv_cell(value: str) -> str:
    if any(ch in value for ch in [",", '"', "\n", "\r"]):
        return '"' + value.replace('"', '""') + '"'
    return value


def _localized_title(row: AchievementRow, game_locale: str, translations: dict[str, dict[str, str]]) -> str:
    base = translations.get(row.title_key, {}).get(game_locale, "").strip()
    tier_key = TIER_LABEL_KEYS.get(row.catalog_id)
    if tier_key:
        tier = translations.get(tier_key, {}).get(game_locale, "").strip()
        if base and tier:
            return f"{base} {tier}"
    return base


def _write_metadata(path: Path, translations: dict[str, dict[str, str]]) -> None:
    lines: list[str] = []
    for row in ACHIEVEMENTS:
        desc = translations.get(row.desc_key, {}).get("en", "")
        incremental = row.catalog_id in INCREMENTAL_STEPS
        steps = str(INCREMENTAL_STEPS[row.catalog_id]) if incremental else ""
        state = "Hidden" if row.catalog_id in HIDDEN_IDS else "Revealed"
        fields = [
            row.play_name,
            desc,
            "True" if incremental else "False",
            steps,
            state,
            str(row.points),
            str(row.list_order),
        ]
        lines.append(",".join(_csv_cell(part) for part in fields))
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _write_localizations(
    path: Path,
    translations: dict[str, dict[str, str]],
    play_locales: dict[str, str],
) -> None:
    lines: list[str] = []
    for row in ACHIEVEMENTS:
        for game_locale, play_locale in play_locales.items():
            title = _localized_title(row, game_locale, translations)
            desc = translations.get(row.desc_key, {}).get(game_locale, "").strip()
            if not title and not desc:
                continue
            fields = [row.play_name, title, desc, play_locale]
            lines.append(",".join(_csv_cell(part) for part in fields))
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _write_icon_mappings(path: Path) -> None:
    lines: list[str] = []
    for row in ACHIEVEMENTS:
        icon_name = f"{row.catalog_id}.png"
        lines.append(f"{_csv_cell(row.play_name)},{icon_name}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _write_catalog_mapping(path: Path) -> None:
    lines = ["catalog_id,play_console_name,icon_file\n"]
    for row in ACHIEVEMENTS:
        lines.append(f"{row.catalog_id},{_csv_cell(row.play_name)},{row.catalog_id}.png\n")
    path.write_text("".join(lines), encoding="utf-8")


def _pack_zip(zip_path: Path, include_localizations: bool) -> None:
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as archive:
        for name in (
            "AchievementsMetadata.csv",
            "AchievementsIconsMappings.csv",
        ):
            archive.write(OUT_DIR / name, arcname=name)
        if include_localizations:
            archive.write(OUT_DIR / "AchievementsLocalizations.csv", arcname="AchievementsLocalizations.csv")
        for row in ACHIEVEMENTS:
            png = OUT_DIR / f"{row.catalog_id}.png"
            archive.write(png, arcname=png.name)


def main() -> int:
    parser = argparse.ArgumentParser(description="Build Play Console achievement import ZIPs.")
    parser.add_argument(
        "--with-i18n",
        action="store_true",
        help="Also build achievements_upload_i18n.zip (enable matching languages in Play Console first).",
    )
    args = parser.parse_args()

    if not ICONS_SRC.is_dir():
        print(f"Missing icons folder: {ICONS_SRC}")
        print("Run: powershell -File tools/run_export_play_achievement_icons.ps1")
        return 1

    translations = _load_translations()
    if OUT_DIR.exists():
        shutil.rmtree(OUT_DIR)
    OUT_DIR.mkdir(parents=True)

    _write_metadata(OUT_DIR / "AchievementsMetadata.csv", translations)
    _write_icon_mappings(OUT_DIR / "AchievementsIconsMappings.csv")
    _write_catalog_mapping(OUT_DIR / "catalog_id_mapping.csv")

    locale_map = _load_locale_map()
    if locale_map:
        _write_localizations(OUT_DIR / "AchievementsLocalizations.csv", translations, locale_map)
    else:
        _write_localizations(
            OUT_DIR / "AchievementsLocalizations.csv",
            translations,
            DEFAULT_I18N_LOCALES,
        )

    missing_icons: list[str] = []
    for row in ACHIEVEMENTS:
        src = ICONS_SRC / f"{row.catalog_id}.png"
        dst = OUT_DIR / f"{row.catalog_id}.png"
        if not src.is_file():
            missing_icons.append(row.catalog_id)
            continue
        shutil.copy2(src, dst)
    if missing_icons:
        print("Missing PNG icons:", ", ".join(missing_icons))
        return 1

    zip_en = OUT_DIR / "achievements_upload.zip"
    _pack_zip(zip_en, include_localizations=False)

    zip_i18n = OUT_DIR / "achievements_upload_i18n.zip"
    if args.with_i18n or locale_map:
        _pack_zip(zip_i18n, include_localizations=True)

    total_points = sum(row.points for row in ACHIEVEMENTS)
    print(f"Wrote {len(ACHIEVEMENTS)} achievements ({total_points} points total)")
    print(f"Folder: {OUT_DIR}")
    print(f"ZIP (English metadata only): {zip_en}")
    if zip_i18n.is_file():
        print(f"ZIP (with localizations):    {zip_i18n}")
    else:
        print("Tip: enable languages in Play Console, edit play_games_locales.json, re-run with --with-i18n")
    print("Reference: catalog_id_mapping.csv (not included in ZIP)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
