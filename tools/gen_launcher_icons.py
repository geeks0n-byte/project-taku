"""Rasterize app icon pixel art into Android launcher PNGs (single source of truth)."""
from __future__ import annotations

import os
import random
import re
import struct
import subprocess
import sys
import zlib

ROOT = os.path.join(os.path.dirname(__file__), "..", "resources", "icons")
TILES_ROOT = os.path.join(os.path.dirname(__file__), "..", "resources", "tiles")
BG_ROOT = os.path.join(os.path.dirname(__file__), "..", "resources", "background")
STORE_ROOT = os.path.join(os.path.dirname(__file__), "..", "docs", "store-assets")
PROJECT_ROOT = os.path.join(os.path.dirname(__file__), "..")
SVG_COSMOS = os.path.join(ROOT, "app_icon_cosmos.svg")
SVG_FLAT = os.path.join(ROOT, "app_icon.svg")
GODOT_SCENE = os.path.join(os.path.dirname(__file__), "render_icon_tiles.tscn")
GODOT_TILE_RASTER_DIR = os.path.join(ROOT, "_godot_tile_raster")
GODOT_TILE_EXPORTS = {
	"tile_shifter.svg": "tile_shifter.png",
	"tile_yellow.svg": "tile_yellow.png",
	"tile_blue.svg": "tile_blue.png",
	"tile_green.svg": "tile_green.png",
}
GODOT_EXE_CANDIDATES = [
	os.path.join(
		os.path.expanduser("~"),
		"Desktop",
		"Godot_v4.7.1-stable_mono_win64",
		"Godot_v4.7.1-stable_mono_win64.exe",
	),
]

ICON_SIZE = 64
ICON_TILE_SRC = 16
# Godot rasterizes tile SVGs at width/height=128 (see tile_*.svg + .import svg/scale=1.0).
ICON_TILE_GODOT_RASTER = 128
# Downscale 128→16 preserves bevel strips (128/8 → 1px per strip).
ICON_TILE_DST = 16
ICON_TILE_GAP = 3
ICON_TILE_HALO = 1  # transparent padding on Godot 128→16 rasters
ICON_TILE_STRIDE = ICON_TILE_DST - 2 * ICON_TILE_HALO + ICON_TILE_GAP
ICON_TILE_MARGIN = (ICON_SIZE - (ICON_TILE_STRIDE + ICON_TILE_DST)) // 2

# Match space_background layer colors (bg_1 dust, bg_2 stars, bg_3 accents, bg_4 sparklers).
BG_VOID = "#00123a"
BG_DUST = "#404040"
BG_STAR = "#ffffff"
BG_ACCENT_CYAN = "#abffe6"
BG_ACCENT_PINK = "#ff77a8"
ICON_ASTEROID_DST = 8
STAR_SEED = 7369215
STAR_DUST_COUNT = 10
STAR_BRIGHT_COUNT = 8
STAR_ACCENT_CYAN_COUNT = 3
STAR_ACCENT_PINK_COUNT = 2
STAR_SPARKLER_COUNT = 2
STAR_MIN_DIST = 3
STAR_TILE_PAD = 1
# Corner placements keep in-game asteroid sprites in the outer ring only.
ICON_ASTEROID_PLACEMENTS = [
	("fx_asteroid_1.svg", 3, 5),
	("fx_asteroid_2.svg", 50, 47),
]


def load_tile_rects(filename: str) -> list:
	"""Parse crisp-edge rects from a resources/tiles/tile_*.svg file."""
	path = os.path.join(TILES_ROOT, filename)
	text = open(path, encoding="utf-8").read()
	rects: list = []
	for m in re.finditer(
		r'<rect x="(\d+)" y="(\d+)" width="(\d+)" height="(\d+)" fill="(#[0-9a-fA-F]+)"',
		text,
	):
		rects.append(
			((int(m.group(1)), int(m.group(2)), int(m.group(3)), int(m.group(4))), m.group(5))
		)
	if not rects:
		raise RuntimeError(f"no tile rects found in {path}")
	return rects


TILE_SHIFTER = load_tile_rects("tile_shifter.svg")
TILE_YELLOW = load_tile_rects("tile_yellow.svg")
TILE_BLUE = load_tile_rects("tile_blue.svg")
TILE_GREEN = load_tile_rects("tile_green.svg")

ICON_TILE_LAYOUT = [
	("Shifter (purple)", TILE_SHIFTER),
	("Yellow", TILE_YELLOW),
	("Blue", TILE_BLUE),
	("Green (joker)", TILE_GREEN),
]

GODOT_TILE_FILES = [
	"tile_shifter.png",
	"tile_yellow.png",
	"tile_blue.png",
	"tile_green.png",
]

ICON_TILE_ORIGINS = [
	(ICON_TILE_MARGIN, ICON_TILE_MARGIN),
	(ICON_TILE_MARGIN + ICON_TILE_STRIDE, ICON_TILE_MARGIN),
	(ICON_TILE_MARGIN, ICON_TILE_MARGIN + ICON_TILE_STRIDE),
	(ICON_TILE_MARGIN + ICON_TILE_STRIDE, ICON_TILE_MARGIN + ICON_TILE_STRIDE),
]

ICON_TILE_POSITIONS = [
	(ox, oy, ICON_TILE_LAYOUT[i][1]) for i, (ox, oy) in enumerate(ICON_TILE_ORIGINS)
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


def _png_paeth(a: int, b: int, c: int) -> int:
	p = a + b - c
	pa = abs(p - a)
	pb = abs(p - b)
	pc = abs(p - c)
	if pa <= pb and pa <= pc:
		return a
	if pb <= pc:
		return b
	return c


def _png_unfilter(raw: bytes, w: int, h: int, bpp: int = 4) -> bytes:
	stride = w * bpp
	out = bytearray(h * stride)
	prev = bytearray(stride)
	row_in = 1 + stride
	for y in range(h):
		filter_type = raw[y * row_in]
		src = raw[y * row_in + 1 : y * row_in + 1 + stride]
		row = bytearray(stride)
		if filter_type == 0:
			row[:] = src
		elif filter_type == 1:
			for i in range(stride):
				left = row[i - bpp] if i >= bpp else 0
				row[i] = (src[i] + left) & 0xFF
		elif filter_type == 2:
			for i in range(stride):
				row[i] = (src[i] + prev[i]) & 0xFF
		elif filter_type == 3:
			for i in range(stride):
				left = row[i - bpp] if i >= bpp else 0
				row[i] = (src[i] + ((left + prev[i]) // 2)) & 0xFF
		elif filter_type == 4:
			for i in range(stride):
				left = row[i - bpp] if i >= bpp else 0
				up = prev[i]
				up_left = prev[i - bpp] if i >= bpp else 0
				row[i] = (src[i] + _png_paeth(left, up, up_left)) & 0xFF
		else:
			raise ValueError(f"unsupported PNG filter type {filter_type}")
		out[y * stride : (y + 1) * stride] = row
		prev = row
	return bytes(out)


def read_png_rgba(path: str) -> tuple[int, int, list[tuple[int, int, int, int]]]:
	"""Read an RGBA PNG (Godot tile exports + local writes)."""
	data = open(path, "rb").read()
	if data[:8] != b"\x89PNG\r\n\x1a\n":
		raise ValueError(f"not a PNG: {path}")

	pos = 8
	w = h = 0
	idat = bytearray()
	while pos + 8 <= len(data):
		length = struct.unpack(">I", data[pos : pos + 4])[0]
		tag = data[pos + 4 : pos + 8]
		body = data[pos + 8 : pos + 8 + length]
		pos += 12 + length
		if tag == b"IHDR":
			w, h, bit_depth, color_type = struct.unpack(">IIBB", body[:10])
			if bit_depth != 8 or color_type != 6:
				raise ValueError(f"unsupported PNG format in {path}")
		elif tag == b"IDAT":
			idat.extend(body)
		elif tag == b"IEND":
			break

	raw = zlib.decompress(bytes(idat))
	rgba = _png_unfilter(raw, w, h, 4)
	pixels: list[tuple[int, int, int, int]] = []
	for y in range(h):
		for x in range(w):
			i = (y * w + x) * 4
			pixels.append((rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]))
	return w, h, pixels


def _find_godot_exe() -> str | None:
	if exe := os.environ.get("GODOT"):
		if os.path.isfile(exe):
			return exe
	for candidate in GODOT_EXE_CANDIDATES:
		if os.path.isfile(candidate):
			return candidate
	return None


def render_tiles_via_godot() -> list[tuple[int, int, int, int]] | None:
	"""Build the 64×64 tile layer from Godot-imported 128×128 SVG textures."""
	if not _ensure_godot_tile_rasters():
		return None

	px = [(0, 0, 0, 0)] * (ICON_SIZE * ICON_SIZE)
	tile_order = [
		(*ICON_TILE_ORIGINS[i], GODOT_TILE_FILES[i]) for i in range(4)
	]
	for ox, oy, file_name in tile_order:
		path = os.path.join(GODOT_TILE_RASTER_DIR, file_name)
		src_w, src_h, src_px = read_png_rgba(path)
		if src_w != ICON_TILE_GODOT_RASTER or src_h != ICON_TILE_GODOT_RASTER:
			raise RuntimeError(f"unexpected Godot tile raster size for {path}: {src_w}x{src_h}")
		scaled = scale_nn(src_px, src_w, src_h, ICON_TILE_DST, ICON_TILE_DST)
		for y in range(ICON_TILE_DST):
			for x in range(ICON_TILE_DST):
				r, g, b, a = scaled[y * ICON_TILE_DST + x]
				if a > 0:
					px[(oy + y) * ICON_SIZE + (ox + x)] = (r, g, b, a)

	print("gen_launcher_icons: composited Godot-imported tile textures")
	return px


def _godot_tile_rasters_present() -> bool:
	return all(
		os.path.isfile(os.path.join(GODOT_TILE_RASTER_DIR, png_name))
		for png_name in GODOT_TILE_EXPORTS.values()
	)


def _ensure_godot_tile_rasters() -> bool:
	if _godot_tile_rasters_present():
		return True
	godot = _find_godot_exe()
	if not godot:
		print(
			"gen_launcher_icons: Godot not found and cached tile rasters missing; using Python fallback",
			file=sys.stderr,
		)
		return False
	cmd = [
		godot,
		"--headless",
		"--rendering-method",
		"gl_compatibility",
		"--path",
		os.path.abspath(PROJECT_ROOT),
		os.path.abspath(GODOT_SCENE),
	]
	try:
		result = subprocess.run(cmd, capture_output=True, text=True, timeout=180, check=False)
	except (OSError, subprocess.TimeoutExpired) as err:
		print(f"gen_launcher_icons: Godot tile export failed ({err}); using fallback", file=sys.stderr)
		return False
	if result.returncode != 0 or not _godot_tile_rasters_present():
		print("gen_launcher_icons: Godot tile export failed:", file=sys.stderr)
		if result.stdout.strip():
			print(result.stdout, file=sys.stderr)
		if result.stderr.strip():
			print(result.stderr, file=sys.stderr)
		return False
	return True


def _extract_tile_pixels(
	all_pixels: list[tuple[int, int, int, int]], ox: int, oy: int
) -> list[tuple[int, int, int, int]]:
	out: list[tuple[int, int, int, int]] = []
	for y in range(ICON_TILE_DST):
		for x in range(ICON_TILE_DST):
			out.append(all_pixels[(oy + y) * ICON_SIZE + (ox + x)])
	return out


def svg_tile_group_from_pixels(ox: int, oy: int, label: str, pixels: list[tuple[int, int, int, int]]) -> str:
	lines = [f'  <!-- {label} -->', f'  <g transform="translate({ox},{oy})">']
	for x, y, rw, rh, color in buffer_to_svg_rects(pixels, ICON_TILE_DST, ICON_TILE_DST):
		lines.append(f'    <rect x="{x}" y="{y}" width="{rw}" height="{rh}" fill="{color}" />')
	lines.append("  </g>")
	return "\n".join(lines)


def hex_rgb(s: str) -> tuple[int, int, int]:
	s = s.lstrip("#")
	return int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16)


def stars_to_path(stars: list[tuple[int, int]]) -> str:
	return " ".join(f"M{x} {y}h1v1h-1z" for x, y in stars)


def pixels_to_svg_groups(
	pixels: list[tuple[int, int, tuple[int, int, int]]],
) -> list[str]:
	"""Group icon-background pixels by color into SVG path elements."""
	by_color: dict[str, list[tuple[int, int]]] = {}
	for x, y, rgb in pixels:
		by_color.setdefault(_rgb_to_hex(rgb), []).append((x, y))
	lines: list[str] = []
	for color, pts in by_color.items():
		lines.append(f'    <g fill="{color}">')
		lines.append(f'      <path d="{stars_to_path(pts)}" />')
		lines.append("    </g>")
	return lines


def _line_pixels(x0: int, y0: int, x1: int, y1: int) -> list[tuple[int, int]]:
	pts: list[tuple[int, int]] = []
	dx = abs(x1 - x0)
	dy = abs(y1 - y0)
	sx = 1 if x0 < x1 else -1
	sy = 1 if y0 < y1 else -1
	err = dx - dy
	x, y = x0, y0
	while True:
		pts.append((x, y))
		if x == x1 and y == y1:
			break
		e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
	return pts


def rasterize_svg_path_fill(d: str, size: int = 16) -> set[tuple[int, int]]:
	"""Fill a crisp M/h/v/z path into a size×size mask (used for asteroid SVGs)."""
	tokens = re.findall(r"[MmHhVvZz]|-?\d+", d)
	i = 0
	x = y = 0
	start: tuple[int, int] | None = None
	outline: set[tuple[int, int]] = set()

	def mark(px: int, py: int) -> None:
		if 0 <= px < size and 0 <= py < size:
			outline.add((px, py))

	def line_to(nx: int, ny: int) -> None:
		nonlocal x, y
		for px, py in _line_pixels(x, y, nx, ny):
			mark(px, py)
		x, y = nx, ny

	while i < len(tokens):
		t = tokens[i]
		if t in "Mm":
			i += 1
			nx, ny = int(tokens[i]), int(tokens[i + 1])
			i += 2
			if t == "m" and start is not None:
				nx += x
				ny += y
			x, y = nx, ny
			start = (x, y)
			mark(x, y)
		elif t == "h":
			i += 1
			line_to(x + int(tokens[i]), y)
			i += 1
		elif t == "H":
			i += 1
			line_to(int(tokens[i]), y)
			i += 1
		elif t == "v":
			i += 1
			line_to(x, y + int(tokens[i]))
			i += 1
		elif t == "V":
			i += 1
			line_to(x, int(tokens[i]))
			i += 1
		elif t in "Zz":
			if start is not None:
				line_to(*start)
			i += 1
		else:
			i += 1

	from collections import deque

	outside: set[tuple[int, int]] = set()
	q: deque[tuple[int, int]] = deque()
	for ox in range(size):
		for oy in (0, size - 1):
			if (ox, oy) not in outline:
				q.append((ox, oy))
				outside.add((ox, oy))
	for oy in range(size):
		for ox in (0, size - 1):
			if (ox, oy) not in outline and (ox, oy) not in outside:
				q.append((ox, oy))
				outside.add((ox, oy))
	while q:
		cx, cy = q.popleft()
		for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
			if (
				0 <= nx < size
				and 0 <= ny < size
				and (nx, ny) not in outline
				and (nx, ny) not in outside
			):
				outside.add((nx, ny))
				q.append((nx, ny))
	return {
		(px, py)
		for px in range(size)
		for py in range(size)
		if (px, py) not in outside
	}


def load_asteroid_pixels(filename: str, dst: int = ICON_ASTEROID_DST) -> list[tuple[int, int, int, int]]:
	"""Load fx_asteroid_*.svg as a dst×dst RGBA nearest-neighbor stamp."""
	path = os.path.join(BG_ROOT, filename)
	text = open(path, encoding="utf-8").read()
	buf = [(0, 0, 0, 0)] * (16 * 16)
	for m in re.finditer(r'<path d="([^"]+)" fill="(#[0-9a-fA-F]+)"', text):
		rgb = hex_rgb(m.group(2))
		for x, y in rasterize_svg_path_fill(m.group(1), 16):
			buf[y * 16 + x] = (*rgb, 255)
	return scale_nn(buf, 16, 16, dst, dst)


def flip_rgba_h(
	src: list[tuple[int, int, int, int]], w: int, h: int
) -> list[tuple[int, int, int, int]]:
	out: list[tuple[int, int, int, int]] = [(0, 0, 0, 0)] * (w * h)
	for y in range(h):
		for x in range(w):
			out[y * w + (w - 1 - x)] = src[y * w + x]
	return out


def flip_rgba_v(
	src: list[tuple[int, int, int, int]], w: int, h: int
) -> list[tuple[int, int, int, int]]:
	out: list[tuple[int, int, int, int]] = [(0, 0, 0, 0)] * (w * h)
	for y in range(h):
		for x in range(w):
			out[(h - 1 - y) * w + x] = src[y * w + x]
	return out


def load_asteroid_stamp(
	filename: str, dst: int = ICON_ASTEROID_DST, flip_h: bool = False, flip_v: bool = False
) -> list[tuple[int, int, int, int]]:
	stamp = load_asteroid_pixels(filename, dst)
	if flip_h:
		stamp = flip_rgba_h(stamp, dst, dst)
	if flip_v:
		stamp = flip_rgba_v(stamp, dst, dst)
	return stamp


def sparkler_pixels(cx: int, cy: int) -> list[tuple[int, int]]:
	"""bg_4 style + cross (3px arms)."""
	return [
		(cx, cy - 1),
		(cx - 1, cy),
		(cx, cy),
		(cx + 1, cy),
		(cx, cy + 1),
	]


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


def _tile_bounds() -> list[tuple[int, int, int, int]]:
	bounds: list[tuple[int, int, int, int]] = []
	inset = ICON_TILE_HALO
	for ox, oy, _rects in ICON_TILE_POSITIONS:
		bounds.append(
			(
				ox + inset,
				oy + inset,
				ox + ICON_TILE_DST - inset - 1,
				oy + ICON_TILE_DST - inset - 1,
			)
		)
	return bounds


def _on_tile(x: int, y: int, pad: int = STAR_TILE_PAD) -> bool:
	for x1, y1, x2, y2 in _tile_bounds():
		if x1 - pad <= x <= x2 + pad and y1 - pad <= y <= y2 + pad:
			return True
	return False


def _far_from_stars(x: int, y: int, stars: list[tuple[int, int]]) -> bool:
	return all(abs(x - sx) + abs(y - sy) >= STAR_MIN_DIST for sx, sy in stars)


def _asteroid_footprints() -> list[tuple[int, int, int, int]]:
	foot: list[tuple[int, int, int, int]] = []
	for _file, ox, oy in ICON_ASTEROID_PLACEMENTS:
		foot.append((ox, oy, ox + ICON_ASTEROID_DST - 1, oy + ICON_ASTEROID_DST - 1))
	return foot


def _on_asteroid(x: int, y: int, pad: int = 1) -> bool:
	for x1, y1, x2, y2 in _asteroid_footprints():
		if x1 - pad <= x <= x2 + pad and y1 - pad <= y <= y2 + pad:
			return True
	return False


def generate_star_field(
	seed: int,
) -> tuple[
	list[tuple[int, int]],
	list[tuple[int, int]],
	list[tuple[int, int]],
	list[tuple[int, int]],
	list[tuple[int, int]],
]:
	rng = random.Random(seed)
	placed: list[tuple[int, int]] = []

	def place_one() -> tuple[int, int]:
		for _ in range(16000):
			x = rng.randint(0, ICON_SIZE - 1)
			y = rng.randint(0, ICON_SIZE - 1)
			if not in_rounded_rect(x, y):
				continue
			if _on_tile(x, y) or _on_asteroid(x, y):
				continue
			if not _far_from_stars(x, y, placed):
				continue
			placed.append((x, y))
			return x, y
		raise RuntimeError("failed to place star field")

	dust = [place_one() for _ in range(STAR_DUST_COUNT)]
	bright = [place_one() for _ in range(STAR_BRIGHT_COUNT)]
	cyan = [place_one() for _ in range(STAR_ACCENT_CYAN_COUNT)]
	pink = [place_one() for _ in range(STAR_ACCENT_PINK_COUNT)]
	sparklers: list[tuple[int, int]] = []
	for _ in range(STAR_SPARKLER_COUNT):
		for _attempt in range(16000):
			cx = rng.randint(2, ICON_SIZE - 3)
			cy = rng.randint(2, ICON_SIZE - 3)
			pts = sparkler_pixels(cx, cy)
			if any(
				not in_rounded_rect(x, y) or _on_tile(x, y) or _on_asteroid(x, y)
				for x, y in pts
			):
				continue
			if any(not _far_from_stars(x, y, placed) for x, y in pts):
				continue
			for x, y in pts:
				placed.append((x, y))
			sparklers.append((cx, cy))
			break
		else:
			raise RuntimeError("failed to place sparkler")
	return dust, bright, cyan, pink, sparklers


def render_tile_godot_raster(
	rects: list, raster: int = ICON_TILE_GODOT_RASTER, src: int = ICON_TILE_SRC
) -> list[tuple[int, int, int, int]]:
	"""Integer upscale to Godot's imported SVG bitmap size (16→128 = ×8)."""
	if raster % src != 0:
		raise ValueError(f"raster size {raster} must be a multiple of {src}")
	scale = raster // src
	buf = [(0, 0, 0, 0)] * (raster * raster)
	for (rx, ry, rw, rh), color in rects:
		rgb = hex_rgb(color)
		for yy in range(rh * scale):
			for xx in range(rw * scale):
				buf[(ry * scale + yy) * raster + (rx * scale + xx)] = (*rgb, 255)
	return buf


def rasterize_icon_tile(
	rects: list, dst: int = ICON_TILE_DST, raster: int = ICON_TILE_GODOT_RASTER
) -> list[tuple[int, int, int, int]]:
	"""128px Godot import → nearest-neighbor downscale (same as in-game TextureRect)."""
	tile_buf = render_tile_godot_raster(rects, raster)
	return scale_nn(tile_buf, raster, raster, dst, dst)


def draw_tile_godot_scaled(
	ox: int,
	oy: int,
	rects: list,
	setp,
	dst: int = ICON_TILE_DST,
) -> None:
	scaled = rasterize_icon_tile(rects, dst)
	for y in range(dst):
		for x in range(dst):
			r, g, b, a = scaled[y * dst + x]
			if a > 0:
				setp(ox + x, oy + y, (r, g, b))


def _rgb_to_hex(rgb: tuple[int, int, int]) -> str:
	return f"#{rgb[0]:02x}{rgb[1]:02x}{rgb[2]:02x}"


def buffer_to_svg_rects(
	buf: list[tuple[int, int, int, int]], w: int, h: int
) -> list[tuple[int, int, int, int, str]]:
	"""Merge same-color pixels into rects so SVG matches the PNG raster exactly."""
	visited = [[False] * w for _ in range(h)]
	out: list[tuple[int, int, int, int, str]] = []
	for y in range(h):
		x = 0
		while x < w:
			r, g, b, a = buf[y * w + x]
			if visited[y][x] or a == 0:
				x += 1
				continue
			rgb = (r, g, b)
			x2 = x
			while x2 < w and not visited[y][x2] and buf[y * w + x2][:3] == rgb and buf[y * w + x2][3] > 0:
				x2 += 1
			rw = x2 - x
			rh = 1
			while y + rh < h:
				row_ok = True
				for xx in range(x, x2):
					p = buf[(y + rh) * w + xx]
					if visited[y + rh][xx] or p[:3] != rgb or p[3] == 0:
						row_ok = False
						break
				if not row_ok:
					break
				rh += 1
			for yy in range(y, y + rh):
				for xx in range(x, x2):
					visited[yy][xx] = True
			out.append((x, y, rw, rh, _rgb_to_hex(rgb)))
			x = x2
	return out


def svg_tile_group(ox: int, oy: int, label: str, rects: list) -> str:
	scaled = rasterize_icon_tile(rects)
	pixel_rects = buffer_to_svg_rects(scaled, ICON_TILE_DST, ICON_TILE_DST)
	lines = [f'  <!-- {label} -->', f'  <g transform="translate({ox},{oy})">']
	for x, y, rw, rh, color in pixel_rects:
		lines.append(f'    <rect x="{x}" y="{y}" width="{rw}" height="{rh}" fill="{color}" />')
	lines.append("  </g>")
	return "\n".join(lines)


def svg_tile_grid_comment(godot_rendered: bool = False) -> str:
	source = "Godot SVG textures" if godot_rendered else "Python 128px import fallback"
	return (
		f"  <!-- 2×2 tile grid: {ICON_TILE_DST}px tiles ({source}), "
		f"{ICON_TILE_MARGIN}px margin, {ICON_TILE_GAP}px gap -->"
	)


def load_godot_tile_pixels(file_name: str) -> list[tuple[int, int, int, int]]:
	path = os.path.join(GODOT_TILE_RASTER_DIR, file_name)
	src_w, src_h, src_px = read_png_rgba(path)
	if src_w != ICON_TILE_GODOT_RASTER or src_h != ICON_TILE_GODOT_RASTER:
		raise RuntimeError(f"unexpected Godot tile raster size for {path}: {src_w}x{src_h}")
	return scale_nn(src_px, src_w, src_h, ICON_TILE_DST, ICON_TILE_DST)


def build_svg_tile_section(godot_tiles: list[tuple[int, int, int, int]] | None = None) -> str:
	parts = [svg_tile_grid_comment(godot_tiles is not None)]
	positions = [(ox, oy, idx) for idx, (ox, oy) in enumerate(ICON_TILE_ORIGINS)]
	slot_labels = ["Top-Left", "Top-Right", "Bottom-Left", "Bottom-Right"]
	for slot, (ox, oy, idx) in zip(slot_labels, positions):
		name, rects = ICON_TILE_LAYOUT[idx]
		parts.append(f"  <!-- {slot}: {name} -->")
		if godot_tiles is not None:
			tile_px = load_godot_tile_pixels(GODOT_TILE_FILES[idx])
			parts.append(svg_tile_group_from_pixels(ox, oy, name, tile_px))
		else:
			parts.append(svg_tile_group(ox, oy, name, rects))
	return "\n".join(parts)


def build_svg_bg_with_stars_section() -> str:
	lines = [
		'  <g clip-path="url(#app-clip)">',
		f'    <rect width="64" height="64" fill="{BG_VOID}" />',
	]
	# Asteroids first (behind stars), then dust / accents / sparklers / bright stars.
	asteroid_px: list[tuple[int, int, tuple[int, int, int]]] = []
	for ox, oy, stamp in ICON_ASTEROID_STAMPS:
		for y in range(ICON_ASTEROID_DST):
			for x in range(ICON_ASTEROID_DST):
				r, g, b, a = stamp[y * ICON_ASTEROID_DST + x]
				if a > 0:
					asteroid_px.append((ox + x, oy + y, (r, g, b)))
	lines.extend(pixels_to_svg_groups(asteroid_px))
	lines.extend(
		[
			f'    <g fill="{BG_DUST}">',
			f'      <path d="{stars_to_path(STAR_DUST)}" />',
			"    </g>",
			f'    <g fill="{BG_ACCENT_CYAN}">',
			f'      <path d="{stars_to_path(STAR_CYAN)}" />',
			"    </g>",
			f'    <g fill="{BG_ACCENT_PINK}">',
			f'      <path d="{stars_to_path(STAR_PINK)}" />',
			"    </g>",
			f'    <g fill="{BG_STAR}">',
			f'      <path d="{stars_to_path(STAR_BRIGHT)}" />',
			"    </g>",
			f'    <g fill="{BG_STAR}">',
			f'      <path d="{stars_to_path([p for c in STAR_SPARKLERS for p in sparkler_pixels(*c)])}" />',
			"    </g>",
			"  </g>",
		]
	)
	return "\n".join(lines)


def sync_icon_svgs(godot_tiles: list[tuple[int, int, int, int]] | None = None) -> None:
	bg_section = build_svg_bg_with_stars_section()
	cosmos = open(SVG_COSMOS, encoding="utf-8").read()
	cosmos = re.sub(
		r'  <g clip-path="url\(#app-clip\)">.*?</g>\n\n',
		bg_section + "\n\n",
		cosmos,
		count=1,
		flags=re.DOTALL,
	)
	tile_section = build_svg_tile_section(godot_tiles)
	cosmos = re.sub(
		r"  <!-- 2×2 tile grid:.*?(?=</svg>)",
		tile_section + "\n",
		cosmos,
		count=1,
		flags=re.DOTALL,
	)
	with open(SVG_COSMOS, "w", encoding="utf-8", newline="\n") as f:
		f.write(cosmos)

	flat_head = (
		'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" '
		'width="256" height="256" shape-rendering="crispEdges">\n'
		'  <!-- App Icon Background -->\n'
		'  <rect x="0" y="0" width="64" height="64" fill="#2d2d2d" rx="14" />\n\n'
	)
	with open(SVG_FLAT, "w", encoding="utf-8", newline="\n") as f:
		f.write(flat_head + tile_section + "\n</svg>\n")


def render_base_64(godot_tiles: list[tuple[int, int, int, int]] | None = None) -> list[tuple[int, int, int, int]]:
	px = [(0, 0, 0, 0)] * (64 * 64)
	bg = hex_rgb(BG_VOID)

	def setp_bg(x: int, y: int, rgb: tuple[int, int, int], a: int = 255) -> None:
		if 0 <= x < 64 and 0 <= y < 64 and in_rounded_rect(x, y):
			px[y * 64 + x] = (rgb[0], rgb[1], rgb[2], a)

	def setp_tile(x: int, y: int, rgb: tuple[int, int, int], a: int = 255) -> None:
		if 0 <= x < 64 and 0 <= y < 64:
			px[y * 64 + x] = (rgb[0], rgb[1], rgb[2], a)

	for y in range(64):
		for x in range(64):
			if in_rounded_rect(x, y):
				px[y * 64 + x] = (*bg, 255)

	for ox, oy, stamp in ICON_ASTEROID_STAMPS:
		for y in range(ICON_ASTEROID_DST):
			for x in range(ICON_ASTEROID_DST):
				r, g, b, a = stamp[y * ICON_ASTEROID_DST + x]
				if a > 0:
					setp_bg(ox + x, oy + y, (r, g, b), a)

	for x, y in STAR_DUST:
		setp_bg(x, y, hex_rgb(BG_DUST))
	for x, y in STAR_CYAN:
		setp_bg(x, y, hex_rgb(BG_ACCENT_CYAN))
	for x, y in STAR_PINK:
		setp_bg(x, y, hex_rgb(BG_ACCENT_PINK))
	for x, y in STAR_BRIGHT:
		setp_bg(x, y, hex_rgb(BG_STAR))
	for cx, cy in STAR_SPARKLERS:
		for x, y in sparkler_pixels(cx, cy):
			setp_bg(x, y, hex_rgb(BG_STAR))

	if godot_tiles is not None:
		for y in range(ICON_SIZE):
			for x in range(ICON_SIZE):
				r, g, b, a = godot_tiles[y * ICON_SIZE + x]
				if a > 0:
					setp_tile(x, y, (r, g, b), a)
	else:
		for ox, oy, rects in ICON_TILE_POSITIONS:
			draw_tile_godot_scaled(ox, oy, rects, setp_tile)

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


STAR_DUST, STAR_BRIGHT, STAR_CYAN, STAR_PINK, STAR_SPARKLERS = generate_star_field(STAR_SEED)
ICON_ASTEROID_STAMPS = [
	(ox, oy, load_asteroid_pixels(file_name))
	for file_name, ox, oy in ICON_ASTEROID_PLACEMENTS
]


def make_adaptive_fg(base64: list[tuple[int, int, int, int]]) -> list[tuple[int, int, int, int]]:
	inner = scale_nn(base64, 64, 64, 288, 288)
	out = [(0, 0, 0, 0)] * (432 * 432)
	ox = (432 - 288) // 2
	oy = (432 - 288) // 2
	for y in range(288):
		for x in range(288):
			out[(oy + y) * 432 + (ox + x)] = inner[y * 288 + x]
	return out


def make_adaptive_bg() -> list[tuple[int, int, int, int]]:
	rgb = hex_rgb(BG_VOID)
	return [(*rgb, 255)] * (432 * 432)


# Title cluster colors from the main-menu TitleCluster capture (not space accents).
_FEATURE_TITLE_COLORS = {
	(255, 214, 0, 255),  # gold fill
	(0, 0, 0, 255),  # outline
	(0, 228, 54, 255),  # green tile
	(196, 156, 0, 255),  # gold shade
	(41, 173, 255, 255),  # blue tile
	(161, 255, 0, 255),  # green highlight
	(255, 224, 102, 255),  # gold highlight
	(31, 81, 37, 255),  # green shade
	(112, 71, 0, 255),  # gold deep shade
}
# Same hex as BG_ACCENT_CYAN — only keep when inside the title bounds.
_FEATURE_TITLE_CYAN = (*hex_rgb(BG_ACCENT_CYAN), 255)

FEATURE_SPECS = [
	("play_store_feature_graphic_1024x500.png", 1024, 500),
	("play_store_graphic_500x1024.png", 500, 1024),
]


def render_space_canvas(w: int, h: int, seed: int = STAR_SEED) -> list[tuple[int, int, int, int]]:
	"""Full-bleed space void matching the app icon language (no tiles / no round mask).

	Builds at a mid pixel-art resolution (short side ~128), then nearest-neighbor
	scales up. That keeps asteroids chunky while stars stay finer than a 64→full
	upscale would.
	"""
	# Finer than the 64×64 icon so 1px stars don't become huge after upscale.
	base_short = ICON_SIZE * 2
	if w >= h:
		base_h = base_short
		base_w = max(base_short // 2, int(round(base_short * w / h)))
	else:
		base_w = base_short
		base_h = max(base_short // 2, int(round(base_short * h / w)))

	bg = hex_rgb(BG_VOID)
	px = [(*bg, 255)] * (base_w * base_h)
	rng = random.Random(seed ^ (base_w * 7919) ^ (base_h * 104729))
	area = (base_w * base_h) / float(ICON_SIZE * ICON_SIZE)
	# Slightly denser than a pure area scale so the finer grid still reads as space.
	density = 0.55
	dust_n = max(STAR_DUST_COUNT, int(round(STAR_DUST_COUNT * area * density)))
	bright_n = max(STAR_BRIGHT_COUNT, int(round(STAR_BRIGHT_COUNT * area * density)))
	cyan_n = max(STAR_ACCENT_CYAN_COUNT, int(round(STAR_ACCENT_CYAN_COUNT * area * density)))
	pink_n = max(STAR_ACCENT_PINK_COUNT, int(round(STAR_ACCENT_PINK_COUNT * area * density)))
	spark_n = max(2, int(round(STAR_SPARKLER_COUNT * area * density * 0.7)))
	min_dist = max(STAR_MIN_DIST, int(round(STAR_MIN_DIST * base_short / ICON_SIZE)))
	# Keep asteroid on-screen size similar to the old 64-base renders.
	ast_dst = ICON_ASTEROID_DST * 2

	def setp(x: int, y: int, rgb: tuple[int, int, int], a: int = 255) -> None:
		if 0 <= x < base_w and 0 <= y < base_h:
			px[y * base_w + x] = (rgb[0], rgb[1], rgb[2], a)

	# Three corners only — no bottom-right rock.
	# (file, frac_x, frac_y, flip_h, flip_v, stamp_dst)
	placements = [
		("fx_asteroid_1.svg", 0.04, 0.08, False, False, ast_dst),
		("fx_asteroid_2.svg", 0.88, 0.10, False, False, ast_dst + 2),
		("fx_asteroid_3.svg", 0.05, 0.78, False, False, ast_dst),
	]
	asteroid_boxes: list[tuple[int, int, int, int]] = []
	for file_name, fx, fy, flip_h, flip_v, dst in placements:
		dst = max(8, dst)
		ox = max(0, min(base_w - dst, int(round(fx * base_w))))
		oy = max(0, min(base_h - dst, int(round(fy * base_h))))
		stamp = load_asteroid_stamp(file_name, dst, flip_h, flip_v)
		asteroid_boxes.append((ox, oy, ox + dst - 1, oy + dst - 1))
		for y in range(dst):
			for x in range(dst):
				r, g, b, a = stamp[y * dst + x]
				if a > 0:
					setp(ox + x, oy + y, (r, g, b), a)

	def on_asteroid(x: int, y: int, pad: int = 1) -> bool:
		for x1, y1, x2, y2 in asteroid_boxes:
			if x1 - pad <= x <= x2 + pad and y1 - pad <= y <= y2 + pad:
				return True
		return False

	placed: list[tuple[int, int]] = []

	def far(x: int, y: int) -> bool:
		return all(abs(x - sx) + abs(y - sy) >= min_dist for sx, sy in placed)

	def place_dot() -> tuple[int, int]:
		for _ in range(40000):
			x = rng.randint(0, base_w - 1)
			y = rng.randint(0, base_h - 1)
			if on_asteroid(x, y) or not far(x, y):
				continue
			placed.append((x, y))
			return x, y
		raise RuntimeError(f"failed to place star on {base_w}x{base_h} canvas")

	for x, y in (place_dot() for _ in range(dust_n)):
		setp(x, y, hex_rgb(BG_DUST))
	for x, y in (place_dot() for _ in range(cyan_n)):
		setp(x, y, hex_rgb(BG_ACCENT_CYAN))
	for x, y in (place_dot() for _ in range(pink_n)):
		setp(x, y, hex_rgb(BG_ACCENT_PINK))
	for x, y in (place_dot() for _ in range(bright_n)):
		setp(x, y, hex_rgb(BG_STAR))

	for _ in range(spark_n):
		for _attempt in range(40000):
			cx = rng.randint(2, base_w - 3)
			cy = rng.randint(2, base_h - 3)
			pts = sparkler_pixels(cx, cy)
			if any(on_asteroid(x, y) or not far(x, y) for x, y in pts):
				continue
			for x, y in pts:
				placed.append((x, y))
				setp(x, y, hex_rgb(BG_STAR))
			break
		else:
			raise RuntimeError(f"failed to place sparkler on {base_w}x{base_h} canvas")

	return scale_nn(px, base_w, base_h, w, h)


def extract_title_overlay(
	src: list[tuple[int, int, int, int]], w: int, h: int
) -> list[tuple[int, int, int, int]]:
	"""Keep SPACEBLOX title pixels; drop void / stars / asteroids."""
	xs: list[int] = []
	ys: list[int] = []
	for y in range(h):
		for x in range(w):
			if src[y * w + x] in _FEATURE_TITLE_COLORS:
				xs.append(x)
				ys.append(y)
	if not xs:
		raise RuntimeError("no title pixels found in store graphic")
	pad = 6
	x0, x1 = max(0, min(xs) - pad), min(w - 1, max(xs) + pad)
	y0, y1 = max(0, min(ys) - pad), min(h - 1, max(ys) + pad)

	out: list[tuple[int, int, int, int]] = [(0, 0, 0, 0)] * (w * h)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			p = src[y * w + x]
			if p in _FEATURE_TITLE_COLORS or p == _FEATURE_TITLE_CYAN:
				out[y * w + x] = p
	return out


def composite_rgba(
	base: list[tuple[int, int, int, int]],
	overlay: list[tuple[int, int, int, int]],
) -> list[tuple[int, int, int, int]]:
	out: list[tuple[int, int, int, int]] = []
	for b, o in zip(base, overlay):
		if o[3] > 0:
			out.append(o)
		else:
			out.append(b)
	return out


def write_store_feature_graphics() -> None:
	"""Refresh feature graphics with the icon space look; keep SPACEBLOX title."""
	for name, w, h in FEATURE_SPECS:
		path = os.path.join(STORE_ROOT, name)
		if not os.path.isfile(path):
			raise FileNotFoundError(f"missing store graphic to refresh: {path}")
		sw, sh, old = read_png_rgba(path)
		if sw != w or sh != h:
			raise RuntimeError(f"{path} is {sw}x{sh}, expected {w}x{h}")
		title = extract_title_overlay(old, w, h)
		space = render_space_canvas(w, h)
		write_png(path, w, h, composite_rgba(space, title))
		print(f"wrote {path}")


def main() -> None:
	os.makedirs(ROOT, exist_ok=True)
	os.makedirs(STORE_ROOT, exist_ok=True)
	godot_tiles = render_tiles_via_godot()
	sync_icon_svgs(godot_tiles)
	base = render_base_64(godot_tiles)
	icon_192 = scale_nn(base, 64, 64, 192, 192)
	write_png(os.path.join(ROOT, "launcher_192.png"), 192, 192, icon_192)
	write_png(os.path.join(ROOT, "launcher_adaptive_fg_432.png"), 432, 432, make_adaptive_fg(base))
	write_png(os.path.join(ROOT, "launcher_adaptive_bg_432.png"), 432, 432, make_adaptive_bg())
	icon_256 = scale_nn(base, 64, 64, 256, 256)
	write_png(os.path.join(ROOT, "app_icon_cosmos_256.png"), 256, 256, icon_256)
	icon_512 = scale_nn(base, 64, 64, 512, 512)
	write_png(os.path.join(STORE_ROOT, "play_store_icon_512.png"), 512, 512, icon_512)
	write_store_feature_graphics()
	print("synced SVG stars + tiles and wrote launcher + store PNGs")


if __name__ == "__main__":
	main()
