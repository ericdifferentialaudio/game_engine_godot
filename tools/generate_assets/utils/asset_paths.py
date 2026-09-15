"""
generate_assets/utils/asset_paths.py

SINGLE SOURCE OF TRUTH for "where do the game's 3D assets live?".

PORTING NOTE (why this module exists): in the original repo this whole
script tree lived INSIDE the asset repo, at assets/graphics/scripts/, so
every script could derive its asset root as "my own parent directory"
(scripts/ -> assets/graphics/). That is no longer true here: this tree
lives in the ENGINE repo (tools/generate_assets/) and is invoked from the
USER'S GAME FOLDER against that game's own assets. Deriving the asset root
from __file__ would silently point every stage at tools/, i.e. rig /
attach / animate / render would all read and write into the engine repo
instead of the game.

Resolution order for the assets root (highest priority first):
    1. an explicit --assets-root passed on any script's command line
    2. the AEVUM_ASSETS_ROOT environment variable
    3. the current working directory (the game folder the user ran from)

If the resolved directory has a "graphics" subfolder but no "clans"
subfolder, "graphics" is used instead -- so both of these work from a game
folder laid out as <game>/graphics/clans/...:
    cd <game> ; python .../generate_assets.py
    cd <game>/graphics ; python .../generate_assets.py

Instructions file (model_definitions.txt) resolution order:
    1. an explicit --instructions path
    2. <assets_root>/model_definitions.txt          (the game's own roster)
    3. <assets_root>/../model_definitions.txt       (game folder, if the
                                                     root resolved to
                                                     <game>/graphics)
    4. the template shipped next to these scripts   (last-resort fallback)
"""
from __future__ import annotations

import os
from pathlib import Path

ASSETS_ROOT_ENV = "AEVUM_ASSETS_ROOT"
INSTRUCTIONS_FILENAME = "model_definitions.txt"
MESHY_CACHE_FILENAME = ".meshy_cache.json"

# tools/generate_assets/ -- the package root of this script tree.
PACKAGE_ROOT = Path(__file__).resolve().parent.parent


def _narrow_to_graphics(root: Path) -> Path:
    """<game>/ -> <game>/graphics/ when that's where clans/ actually is."""
    if (root / "clans").is_dir():
        return root
    graphics = root / "graphics"
    if (graphics / "clans").is_dir():
        return graphics
    return root


def default_assets_root() -> Path:
    """AEVUM_ASSETS_ROOT if set, else the current working directory."""
    env = os.environ.get(ASSETS_ROOT_ENV)
    root = Path(env).expanduser() if env else Path.cwd()
    return _narrow_to_graphics(root.resolve())


def resolve_assets_root(explicit=None) -> Path:
    """Normalizes an --assets-root value (or falls back to the default)."""
    if explicit is None:
        return default_assets_root()
    return _narrow_to_graphics(Path(explicit).expanduser().resolve())


def resolve_instructions(assets_root: Path, explicit=None) -> Path:
    """Locates model_definitions.txt for this run (see module docstring)."""
    if explicit is not None:
        return Path(explicit).expanduser().resolve()
    for candidate in (assets_root / INSTRUCTIONS_FILENAME,
                      assets_root.parent / INSTRUCTIONS_FILENAME,
                      PACKAGE_ROOT / INSTRUCTIONS_FILENAME):
        if candidate.is_file():
            return candidate
    return assets_root / INSTRUCTIONS_FILENAME


def meshy_cache_path(instructions_path: Path) -> Path:
    """Meshy rig-task cache, kept NEXT TO THE GAME'S instructions file
    rather than inside this (shared, possibly read-only, version-
    controlled) tools tree -- two different games must never share one
    cache of rig_task_ids keyed by bare model_name."""
    return Path(instructions_path).resolve().parent / MESHY_CACHE_FILENAME
