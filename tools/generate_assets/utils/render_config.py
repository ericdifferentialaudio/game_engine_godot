"""
scripts/render_config.py

Subject-agnostic data model for the Blender 3D->sprite render pipeline.

This module has NO dependency on `bpy` and can be imported/tested with a
plain `python` interpreter. It only describes *what* to render (subjects,
animation states, directions, frame counts, output paths) — the actual
rendering (`render_core.py`) is driven by these plain dataclasses so it can
run headless inside Blender via:

    blender --background --python scripts/render_cli.py -- --subject clans ...

Pipeline parameters locked in doc/GRAPHICS_PIPELINE_3D_TO_SPRITE.md and
doc/CLAN_UNIT_ANIMATION_MATRIX.md:
    - 6 directions, no mirroring: e, se, sw, w, nw, ne
    - 512px render size (fixed, standardized across clan subjects/states)
    - fixed isometric camera, ~30 degrees pitch, orthographic, transparent bg
    - fixed ortho_scale (see render_core.FIXED_ORTHO_SCALE) shared by every
      clan subject/state - NOT computed per-subject, so apparent character
      size stays consistent across the whole roster and across a single
      subject's own animation states
    - variable frame count per animation state (not uniform 8-across)
    - frame filenames use Blender's native 4-digit convention: 0000.png ...
"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

# ============================================================
# Locked pipeline constants
# ============================================================

DIRECTIONS: tuple[str, ...] = ("e", "se", "sw", "w", "nw", "ne")

# Degrees to rotate the subject (or camera, depending on rig) per direction,
# starting at "e" = 0 degrees, going counter-clockwise around Z.
DIRECTION_ANGLES: dict[str, float] = {
    "e": 0.0,
    "ne": 60.0,
    "nw": 120.0,
    "w": 180.0,
    "sw": 240.0,
    "se": 300.0,
}

RENDER_SIZE_PX = 512  # bumped from 128 per user request - higher base fidelity
CAMERA_PITCH_DEG = 30.0  # OPEN QUESTION per doc — lock before batch rendering


@dataclass(frozen=True)
class AnimState:
    """One animation state's render parameters (matches ANIMATION_MATRIX §2)."""
    name: str            # e.g. "idle", "walk", "attack", "bow", "cast", ...
    frames: int          # frame count for this state
    fps: int             # playback fps (informational; engine-side timing)
    loop: bool           # loop vs play-once
    folder: str = ""     # output folder name, defaults to f"anim_{name}"

    def __post_init__(self):
        if not self.folder:
            object.__setattr__(self, "folder", f"anim_{self.name}")


# Canonical animation-state catalogue (frame counts from
# doc/CLAN_UNIT_ANIMATION_MATRIX.md §2). Individual subjects select a subset
# of these per their own rules (see subjects/clans.py etc.).
# Frame counts and fps are now doubled TWICE versus the originally-authored
# ANIMATION_MATRIX §2 values (4/8 -> 8/16 -> 16/32 etc.) per user request -
# first a 2x pass, then another 2x pass on top of that (net 4x the original
# sampling rate). Doubling frames alone (while leaving fps unchanged) would
# have doubled each animation's played-back duration instead of just
# sampling it more densely - doubling both keeps the same real-time
# duration while increasing the number of rendered frames.
ANIM_STATES: dict[str, AnimState] = {
    "idle":     AnimState("idle", 16, 32, loop=True),
    "walk":     AnimState("walk", 32, 48, loop=True),
    "attack":   AnimState("attack", 24, 56, loop=False),
    "bow":      AnimState("bow", 24, 56, loop=False),
    "cast":     AnimState("cast", 24, 48, loop=False),
    "death":    AnimState("death", 24, 40, loop=False),
    "defend":   AnimState("defend", 16, 40, loop=True),
    "meditate": AnimState("meditate", 16, 24, loop=True),
}


# Extra source files (besides the resolved mesh itself) whose mtime should
# also be considered when deciding if a render is stale — i.e. changing the
# pipeline's own render logic invalidates existing frames even if the mesh
# didn't change. Populated by render_cli.py at startup; left here so
# RenderJob.needs_render() doesn't need bpy or a hardcoded script list.
PIPELINE_SCRIPT_PATHS: list[Path] = []


@dataclass
class RenderJob:
    """
    One fully-resolved unit of render work: a single subject, in a single
    animation state, producing frames across all 6 directions.

    `mesh_path`   - source .glb resolved for THIS state (see
                    mesh_discovery.py — different states can come from
                    different source files, e.g. a dedicated walk clip vs.
                    a static textured mesh for hit/death/etc.)
    `output_root` - directory that will contain <direction>/0000.png etc.
    """
    subject_id: str            # e.g. "clans/fighter/chieftain"
    state: AnimState
    mesh_path: Optional[Path]
    output_root: Path
    directions: tuple[str, ...] = DIRECTIONS
    render_size: int = RENDER_SIZE_PX
    camera_pitch_deg: float = CAMERA_PITCH_DEG

    def output_dir(self, direction: str) -> Path:
        return self.output_root / self.state.folder / direction

    def frame_path(self, direction: str, frame_idx: int) -> Path:
        return self.output_dir(direction) / f"{frame_idx:04d}.png"

    def all_frame_paths(self) -> list[Path]:
        return [
            self.frame_path(d, i)
            for d in self.directions
            for i in range(self.state.frames)
        ]

    def is_complete(self) -> bool:
        """True if every expected frame file already exists on disk."""
        return all(p.is_file() for p in self.all_frame_paths())

    def source_mtime(self) -> Optional[float]:
        """
        Latest mtime among this job's source mesh and the pipeline scripts
        that determine how it's rendered. None if the mesh doesn't exist
        (caller should treat that as "cannot render yet", not "stale").
        """
        if self.mesh_path is None or not self.mesh_path.is_file():
            return None
        mtimes = [self.mesh_path.stat().st_mtime]
        for script_path in PIPELINE_SCRIPT_PATHS:
            if script_path.is_file():
                mtimes.append(script_path.stat().st_mtime)
        return max(mtimes)

    def output_mtime(self) -> Optional[float]:
        """Earliest mtime among this job's existing output frames, or None
        if any expected frame is missing (missing always counts as stale)."""
        paths = self.all_frame_paths()
        mtimes = []
        for p in paths:
            if not p.is_file():
                return None
            mtimes.append(p.stat().st_mtime)
        return min(mtimes) if mtimes else None

    def needs_render(self) -> bool:
        """
        True if this job should be (re-)rendered: any expected frame is
        missing, the source mesh doesn't exist yet (nothing to compare —
        treated as "not yet renderable", reported separately by callers),
        or the source mesh / pipeline scripts are newer than the oldest
        existing output frame.
        """
        src_mtime = self.source_mtime()
        if src_mtime is None:
            return False  # no source mesh yet - can't render, not "stale"
        out_mtime = self.output_mtime()
        if out_mtime is None:
            return True   # missing frame(s)
        return src_mtime > out_mtime

    def is_renderable(self) -> bool:
        """True if this job's source mesh currently exists on disk."""
        return self.mesh_path is not None and self.mesh_path.is_file()


@dataclass
class SubjectSpec:
    """
    A renderable subject: identifies its per-state mesh sources, its base
    output directory, and the list of AnimStates it needs rendered.

    `state_meshes` maps state name -> resolved source .glb (or None if none
    could be found - see mesh_discovery.py). Different states legitimately
    come from different files: a dedicated "walk" clip vs. a static textured
    mesh reused for states with no dedicated animation yet (attack/defend/
    meditate/etc, per the fallback chain in mesh_discovery.discover_state_meshes).

    Produced by per-asset-category builders in scripts/subjects/*.py, which
    call mesh_discovery.discover_state_meshes() against each subject's
    base_mesh/ folder to populate `state_meshes`.
    """
    subject_id: str             # unique dotted/slash id, e.g. "clans/fighter/chieftain"
    state_meshes: dict[str, Optional[Path]]   # state name -> resolved .glb or None
    output_root: Path            # directory that owns anim_XXX/ subfolders
    states: list[AnimState] = field(default_factory=list)
    render_size: int = RENDER_SIZE_PX     # override per category, e.g. dragons=192
    camera_pitch_deg: float = CAMERA_PITCH_DEG

    def render_jobs(self) -> list[RenderJob]:
        return [
            RenderJob(
                subject_id=self.subject_id,
                state=state,
                mesh_path=self.state_meshes.get(state.name),
                output_root=self.output_root,
                render_size=self.render_size,
                camera_pitch_deg=self.camera_pitch_deg,
            )
            for state in self.states
        ]
