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
TOOLS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "gen_launcher_icons.py")
OUT = os.path.join(ROOT, "resources", "background", "boot_void.png")

spec = importlib.util.spec_from_file_location("gen_launcher_icons", TOOLS)
mod = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(mod)

W, H = 1080, 1920
OUT_BG = os.path.join(ROOT, "resources", "background", "boot_void_bg.png")
OUT_TILES = os.path.join(ROOT, "resources", "background", "boot_void_tiles.png")


def _blit_center(
	dst: list[tuple[int, int, int, int]],
	src: list[tuple[int, int, int, int]],
	dst_w: int,
	dst_h: int,
	src_w: int,
	src_h: int,
	skip_clear: bool = False,
) -> None:
	ox = (dst_w - src_w) // 2
	oy = (dst_h - src_h) // 2
	for y in range(src_h):
		dst_y = oy + y
		if dst_y < 0 or dst_y >= dst_h:
			continue
		src_row = y * src_w
		dst_row = dst_y * dst_w
		for x in range(src_w):
			dst_x = ox + x
			if 0 <= dst_x < dst_w:
				p = src[src_row + x]
				if skip_clear and p[3] == 0:
					continue
				dst[dst_row + dst_x] = p


def _centered_icon_square(
	icon: list[tuple[int, int, int, int]], w: int, h: int, fill_mask: bool
) -> list[tuple[int, int, int, int]]:
	void = (*mod.hex_rgb(mod.BG_VOID), 255)
	square = [p if p[3] > 0 else void for p in icon] if fill_mask else icon
	side = min(w, h)
	return mod.scale_nn(square, mod.ICON_SIZE, mod.ICON_SIZE, side, side)


def render_launch_splash(w: int, h: int) -> list[tuple[int, int, int, int]]:
	# Portrait sky in the same language as the app icon (not the sparse in-game layers).
	sky = mod.render_space_canvas(w, h, mod.STAR_SEED)
	tiles = mod.render_tiles_via_godot()
	icon = mod.render_base_64(tiles)
	out = list(sky)
	_blit_center(out, _centered_icon_square(icon, w, h, True), w, h, min(w, h), min(w, h))
	return out


def render_background_only(w: int, h: int) -> list[tuple[int, int, int, int]]:
	"""Same splash as boot_void.png, but no tiles."""
	sky = mod.render_space_canvas(w, h, mod.STAR_SEED)
	empty_tiles = [(0, 0, 0, 0)] * (mod.ICON_SIZE * mod.ICON_SIZE)
	icon = mod.render_base_64(empty_tiles)
	out = list(sky)
	_blit_center(out, _centered_icon_square(icon, w, h, True), w, h, min(w, h), min(w, h))
	return out


def render_tiles_only(w: int, h: int) -> list[tuple[int, int, int, int]]:
	"""Just the four tiles, transparent everywhere else (aligned with boot_void.png)."""
	tiles = mod.render_tiles_via_godot()
	if tiles is None:
		tiles = [(0, 0, 0, 0)] * (mod.ICON_SIZE * mod.ICON_SIZE)
	out = [(0, 0, 0, 0)] * (w * h)
	_blit_center(
		out,
		_centered_icon_square(tiles, w, h, False),
		w,
		h,
		min(w, h),
		min(w, h),
		skip_clear=True,
	)
	return out


def main() -> None:
	px = render_launch_splash(W, H)
	mod.write_png(OUT, W, H, px)
	print(f"wrote {OUT} ({W}x{H}, {os.path.getsize(OUT)} bytes)")
	bg = render_background_only(W, H)
	mod.write_png(OUT_BG, W, H, bg)
	print(f"wrote {OUT_BG} ({W}x{H}, {os.path.getsize(OUT_BG)} bytes)")
	tiles = render_tiles_only(W, H)
	mod.write_png(OUT_TILES, W, H, tiles)
	print(f"wrote {OUT_TILES} ({W}x{H}, {os.path.getsize(OUT_TILES)} bytes)")


if __name__ == "__main__":
	main()
