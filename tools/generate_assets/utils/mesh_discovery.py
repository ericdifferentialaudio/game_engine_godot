"""
scripts/mesh_discovery.py

Resolves which source .glb file feeds which animation state for a subject,
by keyword-matching filenames under a subject's base_mesh/ folder. No `bpy`
dependency — pure pathlib, safe to import/test outside Blender.

Why keyword matching (rather than a strict naming convention or a manifest
file): Meshy exports arrive with inconsistent, often messy names (e.g.
`Meshy_AI_Crimson_Knight_biped_Animation_Walking_withSkin.glb`,
`Meshy_AI_Crimson_Knight_0831032001_texture.glb`), sometimes nested inside
extra folders left over from unzipping. This module recurses through
base_mesh/**/*.glb regardless of nesting depth and classifies each file by
keywords in its filename, so no manual renaming/manifest bookkeeping is
required per-subject as new Meshy exports land.

Meshy's per-animation downloads also routinely arrive as `.zip` archives
(each containing one or more `.glb` files) rather than loose `.glb` files.
`discover_state_meshes()` auto-extracts any `*.zip` sitting directly in
`base_mesh/` before scanning (see `_auto_unzip_base_mesh()`), so dropping a
downloaded zip straight into `base_mesh/` and re-running the pipeline is
enough - no manual unzip step required.

Classification priority (first match wins, per file):
    1. Animation-state keyword (walk, attack, bow, cast, hit, death, defend,
       meditate, idle) -> that file is a candidate CLIP for that state.
    2. "texture"/"withskin"/etc keyword (and no state keyword matched)
       -> STATIC TEXTURED fallback mesh, used for any requested state that
          has no dedicated animated clip (e.g. attack/defend/meditate before
          those clips exist).
    3. Neither -> BASE (untextured) fallback mesh, lowest priority.

If multiple files match the same state, the most-recently-modified one wins
(a warning is printed — this is meant to be a rare/duplicate situation, not
silently swallowed).

"run"/"running" is treated as an alias for "walk" when no dedicated walk
clip exists, since Meshy's default biped animation pack usually ships both
and our ANIM_STATES catalogue has no separate "run" state today.
"""
from __future__ import annotations

import zipfile
from collections import defaultdict
from pathlib import Path
from typing import Optional

# State name -> filename keywords that identify a clip for that state.
STATE_KEYWORDS: dict[str, list[str]] = {
    "walk":     ["walk", "walking"],
    "run":      ["run", "running"],   # alias fallback for "walk", see module docstring
    "attack":   ["attack", "melee", "slash", "strike"],
    "bow":      ["bow", "shoot", "shooting", "draw", "arrow"],
    "cast":     ["cast", "casting", "spell"],
    "death":    ["death", "die", "dying", "dead"],
    "defend":   ["defend", "defending", "block", "guard", "brace"],
    "meditate": ["meditate", "meditation", "pray", "praying"],
    "idle":     ["idle", "breathing", "breathe"],
}

TEXTURE_KEYWORDS = ["texture", "textured", "withskin", "with_skin", "skin"]

# Filenames Meshy bundles into every animation zip alongside the actual clip
# (e.g. "Meshy_AI_..._Character_output.glb") - these are companion/reference
# meshes, not animation content, so folder-name context (see classify_file's
# base_mesh_dir handling) must NOT promote them to a state's dedicated clip
# just because they happen to sit in a folder named after that state.
COMPANION_FILE_KEYWORDS = ["character_output"]


def _matches_any(name_lower: str, keywords: list[str]) -> bool:
    return any(kw in name_lower for kw in keywords)


def classify_file(path: Path, base_mesh_dir: Optional[Path] = None) -> str:
    """
    Returns one of the STATE_KEYWORDS keys, "texture_fallback", or
    "base_fallback" for the given .glb file.

    Checks the file's own name AND, if `base_mesh_dir` is given, every
    subfolder name between `base_mesh_dir` and the file. This matters
    because Meshy names the .glb inside a downloaded zip after its own
    internal pose-library name (e.g. "Animation_Axe_Stance_withSkin.glb"),
    which has no relation to what you actually requested it for — but the
    EXTRACTED FOLDER carries the real intent, since it's named after the zip
    you downloaded (e.g. a zip you got for "meditate" auto-extracts into a
    "..._meditate/" folder per _auto_unzip_base_mesh(), even though the .glb
    inside is called "Axe_Stance"). Without checking folder names too, that
    kind of file would incorrectly fall through to the generic texture/skin
    fallback bucket instead of being recognized as the meditate clip.
    """
    name_lower = path.name.lower()

    # Known companion files (bundled into every zip alongside the real clip)
    # are never promoted by folder context - check the filename ALONE first.
    if not _matches_any(name_lower, COMPANION_FILE_KEYWORDS):
        parts = [path.name]
        if base_mesh_dir is not None:
            try:
                rel = path.relative_to(base_mesh_dir)
                parts = [p for p in rel.parts]  # subfolder names + filename, in order
            except ValueError:
                pass  # path isn't under base_mesh_dir - fall back to filename only
        haystack = " ".join(parts).lower()
    else:
        haystack = name_lower  # filename only - ignore folder context entirely

    for state_name, keywords in STATE_KEYWORDS.items():
        if _matches_any(haystack, keywords):
            return state_name

    if _matches_any(haystack, TEXTURE_KEYWORDS):
        return "texture_fallback"

    return "base_fallback"


def _auto_unzip_base_mesh(base_mesh_dir: Path) -> None:
    """
    Extract any *.zip sitting directly in base_mesh_dir (not recursive - only
    top-level, since that's where downloaded Meshy archives get dropped) into
    a same-named subfolder, then delete the zip on success. Idempotent: skips
    a zip whose extraction target folder already exists. Never raises on a
    corrupt/unreadable zip - warns and leaves it in place so a bad download
    can't take down the whole render plan.
    """
    if not base_mesh_dir.is_dir():
        return

    for zip_path in sorted(base_mesh_dir.glob("*.zip")):
        if not zip_path.is_file():
            # Not a real zip - e.g. a directory that happens to be named
            # "*.zip" (seen in practice from an earlier manual extraction
            # that kept the .zip suffix on the folder). Nothing to do.
            continue

        target_dir = zip_path.with_suffix("")  # strip .zip, same stem as folder name

        if target_dir.exists():
            # Already extracted on a prior run - nothing to do, no need to log.
            continue

        try:
            with zipfile.ZipFile(zip_path) as zf:
                zf.extractall(target_dir)
        except zipfile.BadZipFile:
            print(f"[mesh_discovery] WARNING: {zip_path.name} is not a valid "
                  f"zip file (or is corrupt) - leaving it in place, unextracted")
            continue
        except OSError as e:
            print(f"[mesh_discovery] WARNING: failed to extract {zip_path.name}: "
                  f"{e} - leaving it in place")
            continue

        zip_path.unlink()
        print(f"[mesh_discovery] extracted {zip_path.name} -> {target_dir.name}/")


def discover_glb_files(base_mesh_dir: Path) -> list[Path]:
    """Recursively find all .glb files under base_mesh_dir, any nesting depth.

    Excludes any filename containing "_final" (case-insensitive) -- these
    are always attach_hand_item.py's own generated outputs (e.g.
    "<clan>_<unit_type>_rigged_final.glb"), never genuine Meshy source
    exports. Without this exclusion, a "_final.glb" sitting in base_mesh/
    (which attach_hand_item.py's non "-anim" mode writes right next to the
    original rig) can itself get picked up as a "source" by this function's
    caller for OTHER states -- e.g. an "-anim attack" line resolving its
    source mesh via discover_state_meshes() could pick up a hand-item-
    attached "_rigged_final.glb" (because it's newer than the pristine
    rig) instead of the clean base rig, silently double-attaching a second
    item on top of the first one already baked into that file.
    """
    if not base_mesh_dir.is_dir():
        return []
    _auto_unzip_base_mesh(base_mesh_dir)
    return sorted(
        p for p in base_mesh_dir.rglob("*.glb")
        if "_final" not in p.name.lower()
    )


def _pick_latest(paths: list[Path]) -> Optional[Path]:
    if not paths:
        return None
    return max(paths, key=lambda p: p.stat().st_mtime)


def find_meshy_glb_in_anim_folder(anim_dir: Path, *, verbose: bool = False) -> Optional[Path]:
    """
    Looks directly inside anim_dir (a clans/<clan>/<unit_type>/anim_<state>/
    folder -- NOT recursive, since that folder normally only holds per-
    direction frame-output subfolders) for a .glb whose filename contains
    "meshy" (case-insensitive).

    This supports the workflow of animating a unit in Meshy (starting from
    one of this pipeline own generated <clan>_<unit_type>_..._final.glb
    outputs, or a states plain discovered clip) and then dropping Meshy
    own re-exported, now-animated .glb back into that states anim_<state>/
    folder -- once present, it should be used as the render source for
    that states 6-direction sprite frames instead of whatever
    discover_state_meshes() would otherwise resolve from base_mesh/.

    If multiple matching files exist, the most-recently-modified one wins
    (same convention as _pick_latest()); a warning is printed when verbose
    (this is meant to be a rare/duplicate situation, not silently
    swallowed). Returns None if anim_dir doesnt exist or has no match.
    """
    if not anim_dir.is_dir():
        return None
    candidates = [p for p in anim_dir.glob("*.glb") if "meshy" in p.name.lower()]
    if not candidates:
        return None
    if len(candidates) > 1 and verbose:
        print(
            f"[mesh_discovery] multiple Meshy-named .glb files found in {anim_dir} - "
            f"using most recent: {[c.name for c in candidates]}"
        )
    return _pick_latest(candidates)


def discover_state_meshes(
    base_mesh_dir: Path,
    requested_states: list[str],
    *,
    verbose: bool = False,
) -> dict[str, Optional[Path]]:
    """
    Resolve a source .glb for each name in `requested_states`.

    Fallback chain per state: dedicated animated clip -> static textured
    mesh -> base (untextured) mesh -> None (caller should skip/warn).

    Returns {state_name: Path | None}.
    """
    files = discover_glb_files(base_mesh_dir)

    by_state: dict[str, list[Path]] = defaultdict(list)
    texture_candidates: list[Path] = []
    base_candidates: list[Path] = []

    for f in files:
        category = classify_file(f, base_mesh_dir)
        if category == "texture_fallback":
            texture_candidates.append(f)
        elif category == "base_fallback":
            base_candidates.append(f)
        else:
            by_state[category].append(f)

    # "run" is an alias fallback for "walk" if no dedicated walk clip exists.
    if "walk" not in by_state and "run" in by_state:
        by_state["walk"] = by_state["run"]

    static_fallback = _pick_latest(texture_candidates) or _pick_latest(base_candidates)

    resolved: dict[str, Optional[Path]] = {}
    for state_name in requested_states:
        candidates = by_state.get(state_name, [])
        if candidates:
            if len(candidates) > 1 and verbose:
                print(
                    f"[mesh_discovery] multiple .glb files match state "
                    f"'{state_name}' in {base_mesh_dir} - using most recent: "
                    f"{[c.name for c in candidates]}"
                )
            resolved[state_name] = _pick_latest(candidates)
        elif static_fallback is not None:
            resolved[state_name] = static_fallback
        else:
            if verbose:
                print(
                    f"[mesh_discovery] WARNING: no .glb found for state "
                    f"'{state_name}' (and no texture/base fallback) in "
                    f"{base_mesh_dir}"
                )
            resolved[state_name] = None

    return resolved
