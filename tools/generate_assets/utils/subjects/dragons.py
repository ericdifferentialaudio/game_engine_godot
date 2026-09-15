"""
scripts/subjects/dragons.py

SubjectSpec builder for assets/graphics/dragons/<color>/.

Dragons are not combat units with the 6-direction/attack-bow-cast state
machine that clan units use — the existing flat art
(assets/graphics/dragons/<color>/<color>_<stage>_<mood>.png) is keyed on
growth stage x mood, e.g. "black_adolescent_aware.png". This builder mirrors
that shape: one subject per (color, stage), rendered across the mood set as
single-pose "states" (frames=1) rather than clan-style multi-frame anims,
plus a directional idle/walk pair for in-world map movement.

Frame width for dragons is 192px (tools/build_spritesheets.py FRAME_WIDTHS),
i.e. dragons render at a larger size class than clan units — override
RenderJob.render_size accordingly via DRAGON_RENDER_SIZE.

Source .glb files live anywhere under
    dragons/<color>/<stage>/base_mesh/**/*.glb
matched to states by filename keyword (see mesh_discovery.py). Frames are
written under
    dragons/<color>/<stage>/anim_<state>/<direction>/NNNN.png
"""
from __future__ import annotations

from pathlib import Path

from mesh_discovery import discover_state_meshes
from render_config import AnimState, SubjectSpec

DRAGON_RENDER_SIZE = 192

COLORS = ["black", "blue", "bronze", "gold", "green", "red", "silver", "white"]

STAGES = ["hatchling", "adolescent", "adult", "ancient"]

# Moods observed in the existing flat asset filenames (normalized — the
# actual files include typos like "engragd"/"anchient"/"andry" which should
# NOT be propagated to the new per-subject folder names).
MOODS = ["awake", "aware", "angry", "enraged"]

# Single-frame "pose" states, one per mood, plus a directional idle/walk pair
# for on-map movement (dragons do move across the world map). idle/walk
# frame counts and fps are doubled TWICE now (matching
# render_config.ANIM_STATES - net 4x the original sampling rate) while
# keeping the same real-time duration; mood poses stay at frames=1 since
# they're static poses, not animations, and doubling a single frame has no
# meaning.
DRAGON_STATES: list[AnimState] = [
    AnimState("idle", 16, 32, loop=True),
    AnimState("walk", 32, 48, loop=True),
    *[AnimState(mood, 1, 1, loop=False, folder=f"anim_{mood}") for mood in MOODS],
]


def build_specs(
    assets_root: Path,
    colors: list[str] | None = None,
    stages: list[str] | None = None,
) -> list[SubjectSpec]:
    dragons_root = assets_root / "dragons"
    selected_colors = colors or COLORS
    selected_stages = stages or STAGES

    specs: list[SubjectSpec] = []
    for color in selected_colors:
        for stage in selected_stages:
            subject_dir = dragons_root / color / stage
            states = list(DRAGON_STATES)
            state_meshes = discover_state_meshes(
                subject_dir / "base_mesh",
                [s.name for s in states],
            )
            specs.append(
                SubjectSpec(
                    subject_id=f"dragons/{color}/{stage}",
                    state_meshes=state_meshes,
                    output_root=subject_dir,
                    states=states,
                    render_size=DRAGON_RENDER_SIZE,
                )
            )
    return specs
