#!/usr/bin/env python3
"""Generate simple PNG launcher icons for Android export (no Pillow required)."""
import os
import struct
import zlib

ROOT = os.path.join(os.path.dirname(__file__), "..", "resources", "icons")


def write_png(path: str, w: int, h: int, rgba_fn) -> None:
	raw = bytearray()
	for y in range(h):
		raw.append(0)
		for x in range(w):
			raw.extend(rgba_fn(x, y, w, h))

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


def cosmos(x: int, y: int, w: int, h: int):
	cx, cy = w / 2.0, h / 2.0
	dx, dy = x - cx, y - cy
	r2 = dx * dx + dy * dy
	r = (min(w, h) * 0.38) ** 2
	if r2 < r * 0.15:
		return (255, 214, 0, 255)
	if r2 < r * 0.45:
		return (77, 166, 255, 255)
	if r2 < r:
		return (120, 60, 180, 255)
	n = (x * 73856093) ^ (y * 19349663)
	if (n & 0xFFF) < 12:
		return (255, 255, 255, 220)
	return (8, 10, 28, 255)


def main() -> None:
	os.makedirs(ROOT, exist_ok=True)
	write_png(os.path.join(ROOT, "launcher_192.png"), 192, 192, cosmos)
	write_png(os.path.join(ROOT, "launcher_adaptive_fg_432.png"), 432, 432, cosmos)
	write_png(
		os.path.join(ROOT, "launcher_adaptive_bg_432.png"),
		432,
		432,
		lambda x, y, w, h: (8, 10, 28, 255),
	)
	print("wrote launcher icons to", os.path.abspath(ROOT))


if __name__ == "__main__":
	main()
