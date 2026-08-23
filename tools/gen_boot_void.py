# -*- coding: utf-8 -*-
"""Regenerate resources/background/boot_void.png as a dense space starfield."""
from __future__ import annotations

import importlib.util
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS = os.path.join(ROOT, "tools", "gen_launcher_icons.py")

spec = importlib.util.spec_from_file_location("gen_launcher_icons", TOOLS)
mod = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(mod)

# Portrait boot splash (project viewport aspect). Godot stretches with fullsize=true.
W, H = 540, 960
out = mod.render_space_canvas(
	W,
	H,
	seed=mod.STAR_SEED ^ 0xB007,
	density=1.35,
	base_short=mod.ICON_SIZE * 4,
)
path = os.path.join(ROOT, "resources", "background", "boot_void.png")
mod.write_png(path, W, H, out)
print(f"wrote {path} ({W}x{H}, {os.path.getsize(path)} bytes)")
