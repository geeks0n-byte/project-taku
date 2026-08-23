# -*- coding: utf-8 -*-
"""Bake resources/background/boot_void.png — one launch screen.

Combines the Android “big icon” splash and the Godot sky splash:
full-bleed icon-style sky, with the real 64×64 app icon (same stars/tiles/
asteroids) scaled nearest-neighbor and centered. Android splash_screen/icon
is left empty so this image is the only splash.
"""
from __future__ import annotations

import importlib.util
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, "tools", "gen_launcher_icons.py")
OUT = os.path.join(ROOT, "resources", "background", "boot_void.png")

spec = importlib.util.spec_from_file_location("gen_launcher_icons", TOOLS)
mod = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(mod)

W, H = 1080, 1920


def render_launch_splash(w: int, h: int) -> list[tuple[int, int, int, int]]:
	# Portrait sky in the same language as the app icon (not the sparse in-game layers).
	sky = mod.render_space_canvas(w, h, mod.STAR_SEED)
	tiles = mod.render_tiles_via_godot()
	icon = mod.render_base_64(tiles)
	void = (*mod.hex_rgb(mod.BG_VOID), 255)
	# Drop the round launcher mask so the icon is a full square.
	square = [p if p[3] > 0 else void for p in icon]
	side = min(w, h)  # 1080 — fills width, letterbox uses sky above/below.
	scaled = mod.scale_nn(square, mod.ICON_SIZE, mod.ICON_SIZE, side, side)
	ox = (w - side) // 2
	oy = (h - side) // 2
	out = list(sky)
	for y in range(side):
		dst_y = oy + y
		if dst_y < 0 or dst_y >= h:
			continue
		src_row = y * side
		dst_row = dst_y * w
		for x in range(side):
			dst_x = ox + x
			if 0 <= dst_x < w:
				out[dst_row + dst_x] = scaled[src_row + x]
	return out


def main() -> None:
	px = render_launch_splash(W, H)
	mod.write_png(OUT, W, H, px)
	print(f"wrote {OUT} ({W}x{H}, {os.path.getsize(OUT)} bytes)")


if __name__ == "__main__":
	main()
