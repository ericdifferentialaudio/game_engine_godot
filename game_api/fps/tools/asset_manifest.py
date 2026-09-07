#!/usr/bin/env python3
"""Audit runtime art assets against the conventions in docs/06_asset_plan.md.

  * lists every glTF/texture under assets/ and checks naming conventions
  * reports which assets.json keys resolve to files that do not exist yet
  * optionally emits a CSV inventory for the art team

Usage:
  python tools/asset_manifest.py                 # audit everything
  python tools/asset_manifest.py --game example_realm --csv out.csv
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
GAMES = ROOT / "games"

MESH_EXT = {".glb", ".gltf"}
TEX_EXT = {".png", ".jpg", ".exr", ".hdr", ".ktx2"}
TEX_SUFFIXES = {"albedo", "normal", "orm", "emissive", "height", "mask", "opacity"}
SNAKE = re.compile(r"^[a-z0-9]+(_[a-z0-9]+)*$")


def res_to_path(res: str) -> Path:
    return ROOT / res.removeprefix("res://")


def audit_files() -> list[dict]:
    rows = []
    if not ASSETS.exists():
        return rows
    for p in sorted(ASSETS.rglob("*")):
        if not p.is_file() or p.suffix.lower() not in MESH_EXT | TEX_EXT:
            continue
        rel = p.relative_to(ROOT).as_posix()
        stem = p.stem
        issues = []
        if p.suffix.lower() in TEX_EXT:
            parts = stem.rsplit("_", 1)
            if len(parts) != 2 or parts[1] not in TEX_SUFFIXES:
                issues.append(f"texture suffix must be one of {sorted(TEX_SUFFIXES)}")
            if not SNAKE.match(parts[0]):
                issues.append("not snake_case")
        else:
            base = re.sub(r"_lod\d$", "", stem)
            if not SNAKE.match(base):
                issues.append("not snake_case")
            if p.parent.name != base:
                issues.append(f"mesh should live in folder named '{base}'")
        rows.append({"path": rel, "kind": "texture" if p.suffix.lower() in TEX_EXT else "mesh",
                     "size_kb": round(p.stat().st_size / 1024, 1), "issues": "; ".join(issues)})
    return rows


def audit_manifest(game: str) -> list[dict]:
    manifest = json.loads((GAMES / game / "assets.json").read_text(encoding="utf-8")).get("assets", {})
    rows = []
    for key, entry in sorted(manifest.items()):
        path = entry.get("path", "")
        exists = res_to_path(path).exists() if path else False
        rows.append({"key": key, "type": entry.get("type", "?"), "path": path,
                     "status": "ok" if exists else "MISSING", "lods": entry.get("lods", ""),
                     "budget_tris": entry.get("budget_tris", "")})
    return rows


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--game", help="also audit games/<id>/assets.json")
    ap.add_argument("--csv", help="write inventory CSV")
    args = ap.parse_args(argv)

    files = audit_files()
    print(f"== assets/: {len(files)} art file(s)")
    for r in files:
        flag = f"  !! {r['issues']}" if r["issues"] else ""
        print(f"  {r['kind']:7} {r['path']} ({r['size_kb']} KB){flag}")

    manifest_rows = []
    if args.game:
        manifest_rows = audit_manifest(args.game)
        missing = [r for r in manifest_rows if r["status"] == "MISSING"]
        print(f"== {args.game}/assets.json: {len(manifest_rows)} key(s), {len(missing)} missing on disk")
        for r in manifest_rows:
            print(f"  {r['status']:7} {r['key']:24} -> {r['path']}")

    if args.csv:
        with open(args.csv, "w", newline="", encoding="utf-8") as fh:
            w = csv.writer(fh)
            w.writerow(["key", "type", "path", "status", "lods", "budget_tris"])
            for r in manifest_rows:
                w.writerow([r["key"], r["type"], r["path"], r["status"], r["lods"], r["budget_tris"]])
        print(f"wrote {args.csv}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
