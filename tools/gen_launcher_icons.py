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
# Downscale 128→32 preserves bevel strips (128/4 → 2px per strip).
ICON_TILE_DST = 32
ICON_TILE_GAP = 0
ICON_TILE_HALO = 2  # transparent padding on Godot 128→32 rasters
ICON_TILE_STRIDE = ICON_TILE_DST - 2 * ICON_TILE_HALO + ICON_TILE_GAP
ICON_TILE_MARGIN = (ICON_SIZE - (ICON_TILE_STRIDE + ICON_TILE_DST)) // 2

STAR_SEED = 10482937
STAR_DIM_COUNT = 7
STAR_BRIGHT_COUNT = 9
STAR_MIN_DIST = 4
STAR_TILE_PAD = 1


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


def generate_stars(
	seed: int, dim_count: int, bright_count: int
) -> tuple[list[tuple[int, int]], list[tuple[int, int]]]:
	rng = random.Random(seed)
	placed: list[tuple[int, int]] = []

	def place_one() -> tuple[int, int]:
		for _ in range(12000):
			x = rng.randint(0, ICON_SIZE - 1)
			y = rng.randint(0, ICON_SIZE - 1)
			if not in_rounded_rect(x, y):
				continue
			if _on_tile(x, y):
				continue
			if not _far_from_stars(x, y, placed):
				continue
			placed.append((x, y))
			return x, y
		raise RuntimeError("failed to place star field")

	dim = [place_one() for _ in range(dim_count)]
	bright = [place_one() for _ in range(bright_count)]
	return dim, bright


STAR_DIM, STAR_BRIGHT = generate_stars(STAR_SEED, STAR_DIM_COUNT, STAR_BRIGHT_COUNT)


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
	return "\n".join(
		[
			'  <g clip-path="url(#app-clip)">',
			'    <rect width="64" height="64" fill="#00123a" />',
			'    <g fill="#404040">',
			f'      <path d="{stars_to_path(STAR_DIM)}" />',
			"    </g>",
			'    <g fill="#ffffff">',
			f'      <path d="{stars_to_path(STAR_BRIGHT)}" />',
			"    </g>",
			"  </g>",
		]
	)


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
	bg = hex_rgb("#00123a")

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

	for x, y in STAR_DIM:
		setp_bg(x, y, hex_rgb("#404040"))
	for x, y in STAR_BRIGHT:
		setp_bg(x, y, hex_rgb("#ffffff"))

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
	rgb = hex_rgb("#00123a")
	return [(*rgb, 255)] * (432 * 432)


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
	print("synced SVG stars + tiles and wrote launcher PNGs")


if __name__ == "__main__":
	main()
