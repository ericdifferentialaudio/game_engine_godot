#!/usr/bin/env python3
"""Generate blockout placeholder art (PNG) for a game's terrains, features,
portraits and item icons so the manifest resolves to real files. Pure stdlib
(zlib + struct PNG writer) - no Pillow required.

  * tiles:     hex (pointy/flat) or diamond filled with the terrain colour
  * features:  small circle, colour from feature "color"
  * portraits: 64x64 rounded square with a deterministic hue per key
  * icons:     32x32 rounded square with a deterministic hue per key

Usage:
  python tools/gen_placeholders.py [--game example_realm_iso] [--force]
"""
from __future__ import annotations

import argparse
import colorsys
import json
import math
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def write_png(path: Path, w: int, h: int, pixels: list[list[tuple[int, int, int, int]]]) -> None:
    raw = b"".join(b"\x00" + b"".join(struct.pack("BBBB", *px) for px in row) for row in pixels)

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def hex_to_rgb(s: str) -> tuple[int, int, int]:
    s = s.lstrip("#")
    return int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16)


def key_color(key: str) -> tuple[int, int, int]:
    h = (sum(ord(c) * (i + 7) for i, c in enumerate(key)) % 360) / 360.0
    r, g, b = colorsys.hsv_to_rgb(h, 0.55, 0.85)
    return int(r * 255), int(g * 255), int(b * 255)


def point_in_poly(x: float, y: float, poly: list[tuple[float, float]]) -> bool:
    inside = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi:
            inside = not inside
        j = i
    return inside


def polygon_png(path: Path, w: int, h: int, poly: list[tuple[float, float]], rgb: tuple[int, int, int]) -> None:
    px = []
    for y in range(h):
        row = []
        for x in range(w):
            if point_in_poly(x + 0.5, y + 0.5, poly):
                shade = 1.0 - 0.06 * ((x + y) % 3)
                row.append((int(rgb[0] * shade), int(rgb[1] * shade), int(rgb[2] * shade), 255))
            else:
                row.append((0, 0, 0, 0))
        px.append(row)
    write_png(path, w, h, px)


def hex_poly(w: int, h: int, pointy: bool) -> list[tuple[float, float]]:
    cx, cy, rx, ry = w / 2, h / 2, w / 2 * 0.96, h / 2 * 0.96
    start = -90.0 if pointy else 0.0
    return [(cx + math.cos(math.radians(start + 60 * i)) * rx, cy + math.sin(math.radians(start + 60 * i)) * ry) for i in range(6)]


def diamond_poly(w: int, h: int) -> list[tuple[float, float]]:
    return [(w / 2, 1), (w - 1, h / 2), (w / 2, h - 1), (1, h / 2)]


def circle_png(path: Path, size: int, rgb: tuple[int, int, int]) -> None:
    c, r = size / 2, size * 0.42
    px = [[(*rgb, 255) if math.hypot(x + 0.5 - c, y + 0.5 - c) <= r else (0, 0, 0, 0) for x in range(size)] for y in range(size)]
    write_png(path, size, size, px)


def square_png(path: Path, size: int, rgb: tuple[int, int, int], corner: int = 4) -> None:
    px = []
    for y in range(size):
        row = []
        for x in range(size):
            dx = max(corner - x, x - (size - 1 - corner), 0)
            dy = max(corner - y, y - (size - 1 - corner), 0)
            row.append((*rgb, 255) if math.hypot(dx, dy) <= corner else (0, 0, 0, 0))
        px.append(row)
    write_png(path, size, size, px)


def generate(game: str, force: bool) -> int:
    pkg = ROOT / "games" / game
    game_cfg = json.loads((pkg / "game.json").read_text(encoding="utf-8"))
    manifest = json.loads((pkg / "assets.json").read_text(encoding="utf-8")).get("assets", {})
    terrains = json.loads((pkg / "terrains.json").read_text(encoding="utf-8"))
    grid = game_cfg.get("grid", {})
    topo = grid.get("topology", "hex")
    pointy = grid.get("orientation", "pointy") != "flat"
    ts = grid.get("tile_size", [64, 56] if topo == "hex" else [64, 32])
    w, h = int(ts[0]), int(ts[1])
    made = 0

    def target(key: str, default_rel: str) -> Path:
        res = manifest.get(key, {}).get("path", f"res://{default_rel}")
        return ROOT / res.replace("res://", "", 1)

    for t in terrains.get("terrains", []):
        p = target(f"tile.{t['id']}", f"assets/tiles/placeholder/{t['id']}.png")
        if p.suffix.lower() == ".png" and (force or not p.exists()):
            poly = hex_poly(w, h, pointy) if topo == "hex" else diamond_poly(w, h)
            polygon_png(p, w, h, poly, hex_to_rgb(t.get("color", "#888888")))
            made += 1
    for f in terrains.get("features", []):
        p = target(f"feature.{f['id']}", f"assets/features/{f['id']}.png")
        if p.suffix.lower() == ".png" and (force or not p.exists()):
            circle_png(p, 32, hex_to_rgb(f.get("color", "#446644")))
            made += 1
    for key, entry in manifest.items():
        p = ROOT / entry.get("path", "").replace("res://", "", 1)
        if p.suffix.lower() != ".png" or (p.exists() and not force):
            continue
        if key.startswith("portrait."):
            square_png(p, 64, key_color(key), 8)
            made += 1
        elif key.startswith("icon."):
            square_png(p, 32, key_color(key), 4)
            made += 1
    return made


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--game", default=None, help="game id (default: bootstrap.json default_game)")
    ap.add_argument("--force", action="store_true", help="overwrite existing files")
    args = ap.parse_args(argv)
    game = args.game or json.loads((ROOT / "bootstrap.json").read_text(encoding="utf-8")).get("default_game")
    n = generate(game, args.force)
    print(f"generated {n} placeholder file(s) for {game}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
