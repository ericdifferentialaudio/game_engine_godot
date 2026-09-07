#!/usr/bin/env python3
"""Audit a game's assets.json: which logical keys resolve to real files, which
are missing (placeholder at runtime), and which res:// files under assets/ are
unreferenced. Also lists the asset keys the *data* references that are absent
from the manifest.

Usage:
  python tools/asset_manifest.py --game example_realm_iso [--json]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KNOWN_TYPES = {"tileset", "tile", "texture", "sprite_frames", "scene", "shader", "audio", "font", "environment"}
ART_EXT = {".png", ".webp", ".jpg", ".svg", ".tres", ".tscn", ".gdshader", ".ogg", ".wav", ".mp3", ".ttf", ".otf"}


def res_to_path(res: str) -> Path:
    return ROOT / res.replace("res://", "", 1)


def data_asset_keys(pkg: Path) -> set[str]:
    keys: set[str] = set()

    def doc(name: str) -> dict:
        p = pkg / f"{name}.json"
        return json.loads(p.read_text(encoding="utf-8")) if p.exists() else {}

    t = doc("terrains")
    for terr in t.get("terrains", []):
        keys.add(terr.get("visual", f"tile.{terr['id']}"))
    for f in t.get("features", []):
        keys.add(f.get("visual", f"feature.{f['id']}"))
    for u in doc("units").get("units", []):
        keys.add(u.get("visual", f"unit.{u['id']}"))
        keys.add(u.get("portrait", f"portrait.{u['id']}"))
    for it in doc("items").get("items", []):
        keys.add(it.get("icon", f"icon.item.{it['id']}"))
    for s in doc("sites").get("sites", []):
        keys.add(s.get("visual", f"site.{s.get('category', 'generic')}"))
    for m in doc("maps").get("maps", []):
        for k in ("environment", "music"):
            if m.get(k):
                keys.add(m[k])
    return keys


def audit(game: str) -> dict:
    pkg = ROOT / "games" / game
    manifest = json.loads((pkg / "assets.json").read_text(encoding="utf-8")).get("assets", {})
    present, missing, bad_type = [], [], []
    referenced_files: set[Path] = set()
    for key, entry in sorted(manifest.items()):
        if entry.get("type", "") not in KNOWN_TYPES:
            bad_type.append(key)
        path = entry.get("path", "")
        if not path:
            continue
        p = res_to_path(path)
        referenced_files.add(p.resolve())
        (present if p.exists() else missing).append(key)
    needed = data_asset_keys(pkg)
    unmanifested = sorted(needed - set(manifest))
    unreferenced = []
    for f in (ROOT / "assets").rglob("*"):
        if f.is_file() and f.suffix.lower() in ART_EXT and f.resolve() not in referenced_files:
            unreferenced.append(str(f.relative_to(ROOT)).replace("\\", "/"))
    return {
        "game": game, "present": present, "missing": missing, "bad_type": bad_type,
        "unmanifested_data_keys": unmanifested, "unreferenced_files": sorted(unreferenced),
    }


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--game", required=True)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    rep = audit(args.game)
    if args.json:
        print(json.dumps(rep, indent=2))
        return 0
    print(f"== {rep['game']}: {len(rep['present'])} present, {len(rep['missing'])} missing (placeholder), "
          f"{len(rep['unmanifested_data_keys'])} data keys not in manifest, {len(rep['unreferenced_files'])} unreferenced files")
    for k in rep["missing"]:
        print(f"  MISSING      {k}")
    for k in rep["bad_type"]:
        print(f"  BAD TYPE     {k}")
    for k in rep["unmanifested_data_keys"]:
        print(f"  UNMANIFESTED {k}")
    for f in rep["unreferenced_files"]:
        print(f"  UNREFERENCED {f}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
