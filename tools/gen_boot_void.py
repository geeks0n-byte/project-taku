# -*- coding: utf-8 -*-
"""Bake resources/background/boot_void.png from the in-game starfield SVGs.

Must match SpaceBackground layers (sparse dust/stars/accents/sparkles), not the
dense app-icon star generator. Asteroids are runtime FX and are omitted.
"""
from __future__ import annotations

import importlib.util
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, "tools", "gen_launcher_icons.py")
BG_DIR = os.path.join(ROOT, "resources", "background")

spec = importlib.util.spec_from_file_location("gen_launcher_icons", TOOLS)
mod = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(mod)

# Native SVG artboard (same as bg_*.svg viewBox). Godot boot splash stretches.
VW, VH = 360, 640
VOID = mod.hex_rgb("#00123a")

LAYERS = [
	"bg_1_far_dust.svg",
	"bg_2_medium_stars.svg",
	"bg_3_foreground_accents.svg",
	"bg_4_sparkler_crosses.svg",
]


def _parse_fill_groups(svg: str) -> list[tuple[str, str]]:
	groups: list[tuple[str, str]] = []
	for m in re.finditer(r'<g\s+fill="(#[0-9a-fA-F]+)"\s*>(.*?)</g>', svg, re.S):
		groups.append((m.group(1), m.group(2)))
	return groups


def _parse_dots(body: str) -> list[tuple[int, int]]:
	dots: list[tuple[int, int]] = []
	# SVG paths use "M60 80h1v1h-1z" (no comma).
	for m in re.finditer(r"M(\d+)\s+(\d+)h1v1h-1z", body):
		dots.append((int(m.group(1)), int(m.group(2))))
	return dots


def _parse_rects(body: str) -> list[tuple[int, int, int, int]]:
	rects: list[tuple[int, int, int, int]] = []
	for m in re.finditer(
		r'<rect\s+x="(\d+)"\s+y="(\d+)"\s+width="(\d+)"\s+height="(\d+)"',
		body,
	):
		rects.append((int(m.group(1)), int(m.group(2)), int(m.group(3)), int(m.group(4))))
	return rects


def render_ingame_sky() -> list[tuple[int, int, int, int]]:
	px = [(*VOID, 255)] * (VW * VH)
	plotted = 0

	def plot(x: int, y: int, rgb: tuple[int, int, int]) -> None:
		nonlocal plotted
		if 0 <= x < VW and 0 <= y < VH:
			px[y * VW + x] = (*rgb, 255)
			plotted += 1

	for name in LAYERS:
		path = os.path.join(BG_DIR, name)
		if not os.path.isfile(path):
			raise FileNotFoundError(path)
		svg = open(path, encoding="utf-8").read()
		groups = _parse_fill_groups(svg)
		if not groups:
			raise RuntimeError(f"no fill groups in {name}")
		for fill, body in groups:
			rgb = mod.hex_rgb(fill)
			for x, y in _parse_dots(body):
				plot(x, y, rgb)
			for x, y, w, h in _parse_rects(body):
				for yy in range(y, y + h):
					for xx in range(x, x + w):
						plot(xx, yy, rgb)
	if plotted < 40:
		raise RuntimeError(f"too few star pixels plotted ({plotted}); parser mismatch")
	print(f"plotted {plotted} star pixels from in-game layers")
	return px


def main() -> None:
	art = render_ingame_sky()
	# Same pixel grid as the in-game SVGs (viewBox 360×640, exported 1080×1920).
	# 3× nearest-neighbor keeps 1px stars as 3×3 blocks — identical to Godot's
	# SVG import at width=1080, without inventing extra stars.
	w, h = VW * 3, VH * 3
	out = mod.scale_nn(art, VW, VH, w, h)
	path = os.path.join(BG_DIR, "boot_void.png")
	mod.write_png(path, w, h, out)
	print(f"wrote {path} ({w}x{h}, {os.path.getsize(path)} bytes)")


if __name__ == "__main__":
	main()
