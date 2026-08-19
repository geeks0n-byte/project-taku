"""Rasterize app_icon_cosmos.svg (64x64 pixel art) into Android launcher PNGs."""

from __future__ import annotations



import os

import re

import struct

import zlib



ROOT = os.path.join(os.path.dirname(__file__), "..", "resources", "icons")

STORE_ROOT = os.path.join(os.path.dirname(__file__), "..", "docs", "store-assets")

SVG_PATH = os.path.join(ROOT, "app_icon_cosmos.svg")



# Must match resources/tiles/tile_*.svg (16×16 pixel art).

TILE_YELLOW = [

	((1, 1, 14, 14), "#1a1a1a"),

	((1, 1, 14, 13), "#c49c00"),

	((1, 1, 13, 1), "#ffe066"),

	((1, 2, 1, 11), "#ffe066"),

	((2, 13, 13, 1), "#704700"),

	((14, 2, 1, 12), "#704700"),

	((3, 3, 10, 8), "#ffe066"),

	((4, 4, 8, 7), "#c49c00"),

]

TILE_BLUE = [

	((1, 1, 14, 14), "#1a1a1a"),

	((1, 1, 14, 13), "#29adff"),

	((1, 1, 13, 1), "#abffe6"),

	((1, 2, 1, 11), "#abffe6"),

	((2, 13, 13, 1), "#1d2b53"),

	((14, 2, 1, 12), "#1d2b53"),

	((3, 3, 10, 8), "#abffe6"),

	((4, 4, 8, 7), "#29adff"),

]

TILE_GREEN = [

	((1, 1, 14, 14), "#1a1a1a"),

	((1, 1, 14, 13), "#00e436"),

	((1, 1, 13, 1), "#a1ff00"),

	((1, 2, 1, 11), "#a1ff00"),

	((2, 13, 13, 1), "#1f5125"),

	((14, 2, 1, 12), "#1f5125"),

	((3, 3, 10, 8), "#a1ff00"),

	((4, 4, 8, 7), "#00e436"),

]

TILE_SHIFTER = [

	((1, 1, 14, 14), "#1a1a1a"),

	((1, 1, 14, 13), "#7e2553"),

	((1, 1, 13, 1), "#ff77a8"),

	((1, 2, 1, 11), "#ff77a8"),

	((2, 13, 13, 1), "#1d2b53"),

	((14, 2, 1, 12), "#1d2b53"),

	((3, 3, 10, 8), "#ff77a8"),

	((4, 4, 8, 7), "#7e2553"),

]



ICON_SIZE = 64

ICON_TILE_SRC = 16

ICON_TILE_DST = 26  # 16 × 1.625, snapped via integer edge scaling

ICON_TILE_GAP = 0

ICON_TILE_MARGIN = (ICON_SIZE - 2 * ICON_TILE_DST - ICON_TILE_GAP) // 2  # 6



# Top: purple, yellow — bottom: blue, green (original app icon order).

ICON_TILE_POSITIONS = [

	(ICON_TILE_MARGIN, ICON_TILE_MARGIN, TILE_SHIFTER),

	(ICON_TILE_MARGIN + ICON_TILE_DST + ICON_TILE_GAP, ICON_TILE_MARGIN, TILE_YELLOW),

	(ICON_TILE_MARGIN, ICON_TILE_MARGIN + ICON_TILE_DST + ICON_TILE_GAP, TILE_BLUE),

	(

		ICON_TILE_MARGIN + ICON_TILE_DST + ICON_TILE_GAP,

		ICON_TILE_MARGIN + ICON_TILE_DST + ICON_TILE_GAP,

		TILE_GREEN,

	),

]



# Stars live in outer margins — never on tile edges.

STAR_DIM = [
	(1, 33),
	(2, 22),
	(4, 16),
	(14, 61),
	(25, 0),
	(30, 4),
	(30, 63),
]

STAR_BRIGHT = [
	(0, 26),
	(1, 19),
	(43, 58),
	(44, 0),
	(47, 58),
	(48, 63),
	(59, 39),
	(60, 21),
	(60, 33),
]





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





def stars_to_path(stars: list[tuple[int, int]]) -> str:

	return " ".join(f"M{x} {y}h1v1h-1z" for x, y in stars)





def in_rounded_rect(x: int, y: int, size: int = 64, rx: int = 14) -> bool:

	if x < 0 or y < 0 or x >= size or y >= size:

		return False

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





def scale_rect_edge(

	rx: int, ry: int, rw: int, rh: int, src: int = ICON_TILE_SRC, dst: int = ICON_TILE_DST

) -> tuple[int, int, int, int]:

	"""Scale a source rect by snapping each edge to the destination grid."""

	x1 = rx * dst // src

	y1 = ry * dst // src

	x2 = (rx + rw) * dst // src

	y2 = (ry + rh) * dst // src

	return x1, y1, x2 - x1, y2 - y1





def draw_tile_edge_scaled(

	ox: int,

	oy: int,

	rects: list,

	setp,

	src: int = ICON_TILE_SRC,

	dst: int = ICON_TILE_DST,

) -> None:

	"""Draw one tile using edge-based integer scaling (matches crisp SVG rects)."""

	for (rx, ry, rw, rh), color in rects:

		x, y, w, h = scale_rect_edge(rx, ry, rw, rh, src, dst)

		rgb = hex_rgb(color)

		for yy in range(h):

			for xx in range(w):

				setp(ox + x + xx, oy + y + yy, rgb)





def render_base_64() -> list[tuple[int, int, int, int]]:

	"""Opaque 64x64 icon matching app_icon_cosmos.svg."""

	px = [(0, 0, 0, 0)] * (64 * 64)

	bg = hex_rgb("#00123a")



	def setp(x: int, y: int, rgb: tuple[int, int, int], a: int = 255) -> None:

		if 0 <= x < 64 and 0 <= y < 64 and in_rounded_rect(x, y):

			px[y * 64 + x] = (rgb[0], rgb[1], rgb[2], a)



	for y in range(64):

		for x in range(64):

			if in_rounded_rect(x, y):

				px[y * 64 + x] = (*bg, 255)



	for x, y in STAR_DIM:

		setp(x, y, hex_rgb("#404040"))



	for x, y in STAR_BRIGHT:

		setp(x, y, hex_rgb("#ffffff"))



	for ox, oy, rects in ICON_TILE_POSITIONS:

		draw_tile_edge_scaled(ox, oy, rects, setp)



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

	inner = scale_nn(base64, 64, 64, 288, 288)

	out = [(0, 0, 0, 0)] * (432 * 432)

	ox = (432 - 288) // 2

	oy = (432 - 288) // 2

	for y in range(288):

		for x in range(288):

			out[(oy + y) * 432 + (ox + x)] = inner[y * 288 + x]

	return out





def make_adaptive_bg() -> list[tuple[int, int, int, int]]:

	rgb = hex_rgb("#00123a")

	return [(*rgb, 255)] * (432 * 432)





def main() -> None:

	os.makedirs(ROOT, exist_ok=True)

	os.makedirs(STORE_ROOT, exist_ok=True)

	base = render_base_64()

	icon_192 = scale_nn(base, 64, 64, 192, 192)

	write_png(os.path.join(ROOT, "launcher_192.png"), 192, 192, icon_192)

	write_png(os.path.join(ROOT, "launcher_adaptive_fg_432.png"), 432, 432, make_adaptive_fg(base))

	write_png(os.path.join(ROOT, "launcher_adaptive_bg_432.png"), 432, 432, make_adaptive_bg())

	icon_256 = scale_nn(base, 64, 64, 256, 256)

	write_png(os.path.join(ROOT, "app_icon_cosmos_256.png"), 256, 256, icon_256)

	icon_512 = scale_nn(base, 64, 64, 512, 512)

	write_png(os.path.join(STORE_ROOT, "play_store_icon_512.png"), 512, 512, icon_512)

	print("wrote launcher icons from app_icon_cosmos.svg pixel art")

	print("wrote docs/store-assets/play_store_icon_512.png")





if __name__ == "__main__":

	main()

