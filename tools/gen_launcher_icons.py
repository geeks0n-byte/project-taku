#!/usr/bin/env python3
"""Rasterize app_icon_cosmos.svg (64x64 pixel art) into Android launcher PNGs."""
from __future__ import annotations

import os
import re
import struct
import zlib

ROOT = os.path.join(os.path.dirname(__file__), "..", "resources", "icons")
SVG_PATH = os.path.join(ROOT, "app_icon_cosmos.svg")


def write_png(path: str, w: int, h: int, pixels: list[tuple[int, int, int, int]]) -> None:
	raw = bytearray()
	i = 0
	for _y in range(h):
		raw.append(0)
		for _x in range(w):
			raw.extend(pixels[i])
			i += 1

	def chunk(tag: bytes, data: bytes) -> bytes:
		return (
			struct.pack(">I", len(data))
			+ tag
			+ data
			+ struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
		)

	ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
	data = (
		b"\x89PNG\r\n\x1a\n"
		+ chunk(b"IHDR", ihdr)
		+ chunk(b"IDAT", zlib.compress(bytes(raw), 9))
		+ chunk(b"IEND", b"")
	)
	with open(path, "wb") as f:
		f.write(data)


def hex_rgb(s: str) -> tuple[int, int, int]:
	s = s.lstrip("#")
	return int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16)


def parse_path_pixels(d: str) -> list[tuple[int, int]]:
	pts: list[tuple[int, int]] = []
	for m in re.finditer(r"M(\d+)\s+(\d+)h1v1h-1z", d):
		pts.append((int(m.group(1)), int(m.group(2))))
	return pts


def in_rounded_rect(x: int, y: int, size: int = 64, rx: int = 14) -> bool:
	if x < 0 or y < 0 or x >= size or y >= size:
		return False
	# Corners: outside circle of radius rx centered at (rx,rx) etc.
	corners = [
		(rx, rx, x < rx and y < rx),
		(size - 1 - rx, rx, x > size - 1 - rx and y < rx),
		(rx, size - 1 - rx, x < rx and y > size - 1 - rx),
		(size - 1 - rx, size - 1 - rx, x > size - 1 - rx and y > size - 1 - rx),
	]
	for cx, cy, active in corners:
		if active:
			dx, dy = x - cx, y - cy
			if dx * dx + dy * dy > rx * rx:
				return False
	return True


def render_base_64() -> list[tuple[int, int, int, int]]:
	"""Opaque 64x64 icon matching app_icon_cosmos.svg."""
	px = [(0, 0, 0, 0)] * (64 * 64)
	bg = hex_rgb("#00123a")

	def setp(x: int, y: int, rgb: tuple[int, int, int], a: int = 255) -> None:
		if 0 <= x < 64 and 0 <= y < 64 and in_rounded_rect(x, y):
			px[y * 64 + x] = (rgb[0], rgb[1], rgb[2], a)

	# Base + stars (clipped)
	for y in range(64):
		for x in range(64):
			if in_rounded_rect(x, y):
				px[y * 64 + x] = (*bg, 255)

	dim = hex_rgb("#404040")
	for x, y in parse_path_pixels(
		"M6 10h1v1h-1z M24 5h1v1h-1z M48 12h1v1h-1z M14 28h1v1h-1z M38 25h1v1h-1z "
		"M58 20h1v1h-1z M5 45h1v1h-1z M26 42h1v1h-1z M50 48h1v1h-1z M18 58h1v1h-1z "
		"M44 56h1v1h-1z M34 14h1v1h-1z"
	):
		setp(x, y, dim)

	bright = hex_rgb("#ffffff")
	for x, y in parse_path_pixels(
		"M14 14h1v1h-1z M40 8h1v1h-1z M54 28h1v1h-1z M8 32h1v1h-1z M46 36h1v1h-1z "
		"M22 52h1v1h-1z M60 48h1v1h-1z M10 56h1v1h-1z M32 60h1v1h-1z M28 20h1v1h-1z"
	):
		setp(x, y, bright)

	tiles = [
		(16, 16, [
			((1, 1, 14, 14), "#1a1a1a"),
			((1, 1, 14, 13), "#7e2553"),
			((1, 1, 13, 1), "#ff77a8"),
			((1, 2, 1, 11), "#ff77a8"),
			((2, 13, 13, 1), "#1d2b53"),
			((14, 2, 1, 12), "#1d2b53"),
			((3, 3, 10, 8), "#ff77a8"),
			((4, 4, 8, 7), "#7e2553"),
		]),
		(32, 16, [
			((1, 1, 14, 14), "#1a1a1a"),
			((1, 1, 14, 13), "#c49c00"),
			((1, 1, 13, 1), "#ffe066"),
			((1, 2, 1, 11), "#ffe066"),
			((2, 13, 13, 1), "#704700"),
			((14, 2, 1, 12), "#704700"),
			((3, 3, 10, 8), "#ffe066"),
			((4, 4, 8, 7), "#c49c00"),
		]),
		(16, 32, [
			((1, 1, 14, 14), "#1a1a1a"),
			((1, 1, 14, 13), "#29adff"),
			((1, 1, 13, 1), "#abffe6"),
			((1, 2, 1, 11), "#abffe6"),
			((2, 13, 13, 1), "#1d2b53"),
			((14, 2, 1, 12), "#1d2b53"),
			((3, 3, 10, 8), "#abffe6"),
			((4, 4, 8, 7), "#29adff"),
		]),
		(32, 32, [
			((1, 1, 14, 14), "#1a1a1a"),
			((1, 1, 14, 13), "#00e436"),
			((1, 1, 13, 1), "#a1ff00"),
			((1, 2, 1, 11), "#a1ff00"),
			((2, 13, 13, 1), "#1f5125"),
			((14, 2, 1, 12), "#1f5125"),
			((3, 3, 10, 8), "#a1ff00"),
			((4, 4, 8, 7), "#00e436"),
		]),
	]

	for ox, oy, rects in tiles:
		for (rx, ry, rw, rh), color in rects:
			rgb = hex_rgb(color)
			for yy in range(ry, ry + rh):
				for xx in range(rx, rx + rw):
					setp(ox + xx, oy + yy, rgb)

	return px


def scale_nn(
	src: list[tuple[int, int, int, int]], sw: int, sh: int, dw: int, dh: int
) -> list[tuple[int, int, int, int]]:
	out: list[tuple[int, int, int, int]] = []
	for y in range(dh):
		sy = min(sh - 1, y * sh // dh)
		for x in range(dw):
			sx = min(sw - 1, x * sw // dw)
			out.append(src[sy * sw + sx])
	return out


def make_adaptive_fg(base64: list[tuple[int, int, int, int]]) -> list[tuple[int, int, int, int]]:
	"""432 adaptive FG: place 288px (safe) icon in center on transparent."""
	# Scale 64 -> 288 (nearest), center on 432 canvas.
	inner = scale_nn(base64, 64, 64, 288, 288)
	out = [(0, 0, 0, 0)] * (432 * 432)
	ox = (432 - 288) // 2
	oy = (432 - 288) // 2
	for y in range(288):
		for x in range(288):
			# Drop fully outside rounded corners → keep alpha from source
			out[(oy + y) * 432 + (ox + x)] = inner[y * 288 + x]
	return out


def make_adaptive_bg() -> list[tuple[int, int, int, int]]:
	rgb = hex_rgb("#00123a")
	return [(*rgb, 255)] * (432 * 432)


def main() -> None:
	os.makedirs(ROOT, exist_ok=True)
	base = render_base_64()
	icon_192 = scale_nn(base, 64, 64, 192, 192)
	write_png(os.path.join(ROOT, "launcher_192.png"), 192, 192, icon_192)
	write_png(os.path.join(ROOT, "launcher_adaptive_fg_432.png"), 432, 432, make_adaptive_fg(base))
	write_png(os.path.join(ROOT, "launcher_adaptive_bg_432.png"), 432, 432, make_adaptive_bg())
	# Also write a 256 project icon PNG so Android/editor don't fall back oddly.
	icon_256 = scale_nn(base, 64, 64, 256, 256)
	write_png(os.path.join(ROOT, "app_icon_cosmos_256.png"), 256, 256, icon_256)
	print("wrote launcher icons from app_icon_cosmos.svg pixel art")


if __name__ == "__main__":
	main()
