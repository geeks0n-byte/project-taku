"""Build a labeled achievement icon audit PNG from Godot-exported assets."""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("AchievementIconAudit: install Pillow (pip install pillow)", file=sys.stderr)
    sys.exit(1)

ROOT = Path(__file__).resolve().parents[2]
OUT_PNG = ROOT / "docs" / "achievement_icon_audit.png"
AUDIT_DIR = ROOT / "docs" / "_achievement_audit"
MANIFEST = AUDIT_DIR / "manifest.json"
GODOT_ASSETS = ROOT / "dev" / "asset-gen" / "export_achievement_icon_assets.gd"
GODOT_EXE = Path(
    r"C:\Users\Giga\Desktop\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe"
)

BG = (15, 20, 36, 255)
TITLE_COLOR = (255, 255, 255, 255)
META_COLOR = (166, 184, 209, 255)
COLS = 4
CELL_W = 260
CELL_H = 240
ICON_PX = 96
PAD = 24
HEADER_H = 36
TITLE_SIZE = 18
META_SIZE = 13
HEADER_SIZE = 14


def _godot_candidates() -> list[Path]:
    return [
        GODOT_EXE,
        Path.home()
        / "Desktop"
        / "Godot_v4.7.2-stable_mono_win64"
        / "Godot_v4.7.2-stable_mono_win64.exe",
    ]


def _find_godot() -> Path:
    for candidate in _godot_candidates():
        if candidate.is_file():
            return candidate
    raise FileNotFoundError("Godot executable not found")


def _reimport_icons(godot: Path) -> None:
    print("AchievementIconAudit: reimporting changed resources via Godot...")
    subprocess.run(
        [str(godot), "--headless", "--path", str(ROOT), "--import"],
        check=True,
        cwd=ROOT,
    )


def _export_assets(godot: Path) -> None:
    if AUDIT_DIR.is_dir():
        shutil.rmtree(AUDIT_DIR)
    cmd = [
        str(godot),
        "--headless",
        "--path",
        str(ROOT),
        "-s",
        "res://dev/asset-gen/export_achievement_icon_assets.gd",
    ]
    print("AchievementIconAudit: rasterizing icons via Godot...")
    subprocess.run(cmd, check=True, cwd=ROOT)


def _load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in (
        ROOT / "resources" / "fonts" / "NotoSans-Regular.ttf",
        ROOT / "resources" / "fonts" / "PressStart2P-vaV7.ttf",
    ):
        if path.is_file():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def _wrap(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.ImageFont, max_w: int, max_lines: int) -> list[str]:
    lines: list[str] = []
    for raw in text.split("\n"):
        words = raw.split(" ")
        current = ""
        for word in words:
            trial = word if not current else f"{current} {word}"
            if draw.textlength(trial, font=font) <= max_w:
                current = trial
            else:
                if current:
                    lines.append(current)
                current = word
                if len(lines) >= max_lines:
                    return lines
        if current:
            lines.append(current)
        if len(lines) >= max_lines:
            return lines
    return lines


def _draw_centered_lines(
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    width: int,
    lines: list[str],
    font: ImageFont.ImageFont,
    fill: tuple[int, int, int, int],
    line_gap: int = 2,
) -> int:
    ascent, descent = font.getmetrics()
    line_h = ascent + descent + line_gap
    for i, line in enumerate(lines):
        tw = draw.textlength(line, font=font)
        tx = x + max(0, (width - int(tw)) // 2)
        draw.text((tx, y + i * line_h), line, font=font, fill=fill)
    return y + len(lines) * line_h


def _compose(entries: list[dict], generated_at: str) -> Image.Image:
    rows = (len(entries) + COLS - 1) // COLS
    size = (PAD * 2 + COLS * CELL_W, PAD * 2 + HEADER_H + rows * CELL_H)
    sheet = Image.new("RGBA", size, BG)
    draw = ImageDraw.Draw(sheet)
    title_font = _load_font(TITLE_SIZE)
    meta_font = _load_font(META_SIZE)
    header_font = _load_font(HEADER_SIZE)

    header = f"Achievement icon audit — {generated_at} — {len(entries)} icons"
    draw.text((PAD, 8), header, font=header_font, fill=META_COLOR)

    for i, entry in enumerate(entries):
        col = i % COLS
        row = i // COLS
        ox = PAD + col * CELL_W
        oy = PAD + HEADER_H + row * CELL_H

        png_path = ROOT / Path(str(entry["png"]).replace("res://", "").replace("/", os.sep))
        if png_path.is_file():
            icon = Image.open(png_path).convert("RGBA")
            ix = ox + (CELL_W - ICON_PX) // 2
            sheet.paste(icon, (ix, oy + 12), icon)
        else:
            draw.text((ox + CELL_W // 2 - 30, oy + 40), "MISSING", fill=(255, 90, 90, 255), font=meta_font)

        title_lines = _wrap(draw, str(entry["title"]), title_font, CELL_W - 16, 3)
        meta_text = f"{entry['id']}\n{entry['file']}"
        meta_lines = _wrap(draw, meta_text, meta_font, CELL_W - 16, 3)

        y = oy + ICON_PX + 28
        y = _draw_centered_lines(draw, ox + 8, y, CELL_W - 16, title_lines, title_font, TITLE_COLOR)
        _draw_centered_lines(draw, ox + 8, y + 8, CELL_W - 16, meta_lines, meta_font, META_COLOR)

    return sheet


def main() -> int:
    godot = _find_godot()
    _reimport_icons(godot)
    _export_assets(godot)
    if not MANIFEST.is_file():
        print(f"AchievementIconAudit: missing {MANIFEST}", file=sys.stderr)
        return 1
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    entries = data.get("entries", [])
    generated_at = datetime.now().strftime("%Y-%m-%d %H:%M")
    sheet = _compose(entries, generated_at)
    OUT_PNG.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT_PNG, "PNG")
    print(f"AchievementIconAudit: wrote {OUT_PNG} ({sheet.width}x{sheet.height}) at {generated_at}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
