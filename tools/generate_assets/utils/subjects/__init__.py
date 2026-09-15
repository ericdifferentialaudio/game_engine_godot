"""
scripts/subjects/

Per-asset-category SubjectSpec builders. Each module here knows how to
enumerate the renderable subjects for one asset category (clans, dragons,
monsters, npc, ...) and translate that category's own naming/folder rules
into a flat list of `render_config.SubjectSpec` objects that
`render_core.run_jobs` can execute uniformly.

Add a new asset category by dropping a `<category>.py` module here with a
`build_specs(assets_root: Path, **filters) -> list[SubjectSpec]` function,
then register it in `CATEGORY_BUILDERS` below.
"""
from __future__ import annotations

from pathlib import Path
from typing import Callable

from render_config import SubjectSpec

from . import clans as _clans
from . import dragons as _dragons
from . import monsters as _monsters
from . import npc as _npc

CATEGORY_BUILDERS: dict[str, Callable[..., list[SubjectSpec]]] = {
    "clans": _clans.build_specs,
    "dragons": _dragons.build_specs,
    "monsters": _monsters.build_specs,
    "npc": _npc.build_specs,
}


def build_specs(category: str, assets_root: Path, **filters) -> list[SubjectSpec]:
    try:
        builder = CATEGORY_BUILDERS[category]
    except KeyError:
        raise ValueError(
            f"Unknown asset category '{category}'. "
            f"Available: {sorted(CATEGORY_BUILDERS)}"
        )
    return builder(assets_root, **filters)
