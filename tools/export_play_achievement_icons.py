#!/usr/bin/env python3
"""Export Play Console achievement icons (512x512 PNG) from project SVGs."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "resources" / "play_games" / "achievement_icons_512"
SIZE = 512
BADGE_RATIO = 48 / 120  # matches achievements_list.gd (_BADGE_PX / _ICON_PX)

TIER_CUPS: dict[str, str] = {
    "bronze": "icon_achievement_cup_bronze.svg",
    "silver": "icon_achievement_cup_silver.svg",
    "gold": "icon_achievement_cup.svg",
}

CATALOG_TIER: dict[str, str] = {
    "clears_bronze": "bronze",
    "clears_silver": "silver",
    "clears_gold": "gold",
    "no_hint_clear": "bronze",
    "hint_saver": "silver",
    "no_hint_gold": "gold",
    "on_time_bronze": "bronze",
    "on_time_silver": "silver",
    "on_time_gold": "gold",
}

# catalog_id -> SVG filename (matches AchievementCatalog.icon_path)
EXPORTS: list[tuple[str, str]] = [
    ("first_clear", "ach_first_clear.svg"),
    ("clears_bronze", "ach_one_more_level.svg"),
    ("clears_silver", "ach_one_more_level.svg"),
    ("clears_gold", "ach_one_more_level.svg"),
    ("first_hard", "ach_first_hard.svg"),
    ("no_hint_clear", "ach_no_hint_clear.svg"),
    ("hint_saver", "ach_no_hint_clear.svg"),
    ("no_hint_gold", "ach_no_hint_clear.svg"),
    ("on_time_bronze", "ach_on_time.svg"),
    ("on_time_silver", "ach_on_time.svg"),
    ("on_time_gold", "ach_on_time.svg"),
    ("easy_set", "ach_easy_set.svg"),
    ("medium_set", "ach_medium_set.svg"),
    ("hard_set", "ach_hard_set.svg"),
    ("three_star_debut", "ach_three_star_debut.svg"),
    ("undo_nothing", "ach_undo_nothing.svg"),
    ("ad_friend", "ach_ad_friend.svg"),
    ("im_blue", "ach_im_blue.svg"),
    ("shall_not_pass", "ach_shall_not_pass.svg"),
    ("rules_reader", "ach_rules_reader.svg"),
    ("purple_rain", "ach_purple_rain.svg"),
    ("yellow_submarine", "ach_yellow_submarine.svg"),
    ("pause_thinker", "ach_pause_thinker.svg"),
]


def _render_with_cairosvg(svg_path: Path, png_path: Path) -> None:
    import cairosvg

    cairosvg.svg2png(
        url=str(svg_path),
        write_to=str(png_path),
        output_width=SIZE,
        output_height=SIZE,
    )


def _render_with_inkscape(svg_path: Path, png_path: Path) -> None:
    subprocess.run(
        [
            "inkscape",
            str(svg_path),
            "--export-type=png",
            f"--export-filename={png_path}",
            f"--export-width={SIZE}",
            f"--export-height={SIZE}",
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def _render_with_magick(svg_path: Path, png_path: Path) -> None:
    subprocess.run(
        [
            "magick",
            "-background",
            "none",
            "-density",
            "384",
            str(svg_path),
            "-filter",
            "Point",
            "-resize",
            f"{SIZE}x{SIZE}",
            str(png_path),
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def _composite_tier_badge(
    png_path: Path,
    catalog_id: str,
    icons_dir: Path,
    renderer,
) -> None:
    tier = CATALOG_TIER.get(catalog_id)
    if not tier:
        return
    try:
        from PIL import Image
    except ImportError:
        print(
            f"Warning: Pillow not installed; {catalog_id}.png has no cup badge.",
            file=sys.stderr,
        )
        return

    cup_svg = icons_dir / TIER_CUPS[tier]
    if not cup_svg.is_file():
        print(f"Missing cup SVG: {cup_svg}", file=sys.stderr)
        return

    badge_size = round(SIZE * BADGE_RATIO)
    badge_path = png_path.with_suffix(f".{tier}.badge.png")
    renderer(cup_svg, badge_path)

    base = Image.open(png_path).convert("RGBA")
    badge = Image.open(badge_path).convert("RGBA").resize((badge_size, badge_size), Image.NEAREST)
    dst = (SIZE - badge_size, SIZE - badge_size)
    base.alpha_composite(badge, dst)
    base.save(png_path)
    badge_path.unlink(missing_ok=True)


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    icons_dir = ROOT / "resources" / "icons"

    renderer = None
    try:
        import cairosvg  # noqa: F401

        renderer = _render_with_cairosvg
    except ImportError:
        pass
    if renderer is None:
        for cmd, fn in (("inkscape", _render_with_inkscape), ("magick", _render_with_magick)):
            try:
                subprocess.run([cmd, "--version"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                renderer = fn
                break
            except (FileNotFoundError, subprocess.CalledProcessError):
                continue
    if renderer is None:
        print(
            "Need cairosvg (pip install cairosvg), Inkscape, or ImageMagick on PATH.",
            file=sys.stderr,
        )
        return 1

    exported = 0
    for catalog_id, svg_name in EXPORTS:
        svg_path = icons_dir / svg_name
        png_path = OUT_DIR / f"{catalog_id}.png"
        if not svg_path.is_file():
            print(f"Missing {svg_path}", file=sys.stderr)
            return 1
        renderer(svg_path, png_path)
        _composite_tier_badge(png_path, catalog_id, icons_dir, renderer)
        exported += 1

    print(f"play_achievement_icons: {exported} exported -> {OUT_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
