"""
scripts/render_cli.py

Command-line entry point for the Blender batch-render pipeline. Run inside
Blender's own Python interpreter, not a plain `python`:

    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" ^
        --background --python assets\\graphics\\scripts\\render_cli.py -- ^
        --category clans --clan fighter --unit-type common

Everything after `--` is passed through to this script's argparse (Blender
consumes its own args before the `--`).

SAFE BY DEFAULT: running the command above with no `--execute` flag only
PRINTS A PLAN — which subjects/states were found, which source mesh (if any)
feeds each one, whether it's new/changed since the last render, what output
frames would be written, and what gets skipped and why. Nothing is rendered
and nothing on disk is touched. Add `--execute` to actually render.

    # preview only (default) - shows the plan, renders nothing:
    blender --background --python .../render_cli.py -- --category clans --clan fighter

    # actually render whatever the plan marks RENDER:
    blender --background --python .../render_cli.py -- --category clans --clan fighter --execute

    # ignore timestamps, re-render everything selected regardless of staleness:
    blender --background --python .../render_cli.py -- --category clans --clan fighter --execute --force

This file is intentionally thin: it resolves CLI args -> SubjectSpecs (via
scripts/subjects/) -> RenderJobs (render_config.py) -> executes them
(render_core.py). All actual policy (frame counts, per-unit_type rules,
directions, render size) lives in those other modules so this CLI doesn't
need to change when a new asset category or rule is added.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Ensure this script's own directory is importable regardless of Blender's
# cwd (Blender does not add the script's directory to sys.path by default).
_SCRIPT_DIR = Path(__file__).resolve().parent
if str(_SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPT_DIR))

import mesh_discovery  # noqa: E402
import render_config  # noqa: E402
from subjects import build_specs  # noqa: E402
from render_core import run_jobs  # noqa: E402
from asset_paths import resolve_assets_root  # noqa: E402

# Any change to these files invalidates existing renders regardless of mesh
# mtime (e.g. a camera pitch or frame-count change) — see
# render_config.RenderJob.needs_render().
_PIPELINE_SCRIPT_NAMES = [
    "render_config.py", "render_core.py", "mesh_discovery.py", "render_cli.py",
]
render_config.PIPELINE_SCRIPT_PATHS = [_SCRIPT_DIR / name for name in _PIPELINE_SCRIPT_NAMES]


def _blender_argv() -> list[str]:
    """Strip Blender's own args, keeping only what follows `--`."""
    argv = sys.argv
    if "--" in argv:
        return argv[argv.index("--") + 1:]
    return []


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Batch-render clan/dragon/monster/npc sprite frames from 3D meshes."
    )
    p.add_argument("--category", required=True, choices=["clans", "dragons", "monsters", "npc"])
    p.add_argument("--assets-root", type=Path, default=None,
                    help="Path to the game's graphics/ assets folder (default: $AEVUM_ASSETS_ROOT, else the "
                         "directory Blender was launched from). generate_assets.py always passes this "
                         "explicitly -- see utils/asset_paths.py.")

    # clans filters
    p.add_argument("--clan", action="append", dest="clans", default=None,
                    help="Restrict to one clan (repeatable). clans category only.")
    p.add_argument("--unit-type", action="append", dest="unit_types", default=None,
                    help="Restrict to one unit_type (repeatable). clans category only.")

    # dragons filters
    p.add_argument("--color", action="append", dest="colors", default=None,
                    help="Restrict to one dragon color (repeatable). dragons category only.")
    p.add_argument("--stage", action="append", dest="stages", default=None,
                    help="Restrict to one growth stage (repeatable). dragons category only.")

    # monsters filters
    p.add_argument("--tier", action="append", dest="tiers", default=None,
                    help="Restrict to one monster tier, e.g. t1 (repeatable). monsters category only.")
    p.add_argument("--monster", action="append", dest="monsters", default=None,
                    help="Restrict to one monster name (repeatable). monsters category only.")

    # npc filters
    p.add_argument("--name", action="append", dest="names", default=None,
                    help="Restrict to one npc subject name (repeatable). npc category only.")

    p.add_argument("--force", action="store_true",
                    help="Re-render frames even if already present/up to date "
                         "(only takes effect together with --execute).")
    p.add_argument("--execute", action="store_true",
                    help="Actually render. Without this flag the command only "
                         "prints the plan (new/changed inputs, outputs that "
                         "would be written, and what's skipped) and touches "
                         "nothing on disk.")
    return p


def _status_for(job, *, force: bool) -> str:
    if not job.is_renderable():
        return "NO-MESH"
    if not force and not job.needs_render():
        return "SKIP"
    return "RENDER"


def _subject_label(subject_id: str) -> str:
    """
    "clans/fighter/common" -> "fighter common"
    "dragons/red/adult"    -> "red adult"
    "monsters/t1_goblin"   -> "t1_goblin"
    "npc/shopkeep_1"       -> "shopkeep_1"
    Drops the leading category segment; joins the rest with spaces so the
    plan reads as a short plain-English subject name.
    """
    parts = subject_id.split("/")[1:]
    return " ".join(parts) if parts else subject_id


def _is_dedicated_clip(job) -> bool:
    """
    True if mesh_discovery actually classified this file as a clip for this
    specific state (rather than a texture/base fallback file that happened
    to get reused). Delegates to mesh_discovery.classify_file() - the same
    classification discover_state_meshes() used to pick this file in the
    first place - rather than re-deriving it from a naive substring check,
    so this can't disagree with the real logic (e.g. an attack clip matched
    via the "slash" keyword rather than literally containing "attack").
    "walk" also accepts a file classified as "run", since mesh_discovery
    treats "run" as a walk alias when no dedicated walk clip exists.
    """
    if job.mesh_path is None:
        return False
    base_mesh_dir = job.output_root / "base_mesh"
    category = mesh_discovery.classify_file(job.mesh_path, base_mesh_dir)
    if category == job.state.name:
        return True
    if job.state.name == "walk" and category == "run":
        return True
    return False


def _common_mesh_prefix(jobs: list) -> str:
    """
    Longest common filename prefix across every resolved mesh in `jobs`
    (skipping jobs with no mesh). Meshy's exports for one subject almost
    always share a long stem (e.g. "Meshy_AI_Crimson_Shieldbearer_"), so
    printing that once per subject and showing only the per-state suffix
    keeps the plan readable instead of repeating the same ~30-character
    prefix on every line.
    """
    names = [job.mesh_path.name for job in jobs if job.mesh_path is not None]
    if not names:
        return ""
    prefix = names[0]
    for name in names[1:]:
        # Shrink `prefix` until it's actually a prefix of `name`.
        while not name.startswith(prefix):
            prefix = prefix[:-1]
            if not prefix:
                return ""
    return prefix


def _source_suffix(job, prefix: str) -> str:
    """
    Resolved input file's name with the subject's common prefix stripped
    (since that's already printed once in the subject header). "" if there
    is no resolved mesh at all.
    """
    if job.mesh_path is None:
        return ""
    return job.mesh_path.name[len(prefix):] or job.mesh_path.name


def _age_note(job, *, force: bool) -> str:
    """
    Short parenthetical explaining WHY a job is being re-rendered when it's
    due to a timestamp comparison rather than a missing output - without
    this, "will re-render" for a mesh you didn't knowingly touch looks like
    a bug rather than "the source file's mtime is newer than the render's,
    for whatever reason" (a stale/odd embedded timestamp from a zip
    extraction, a copy that reset mtimes, clock skew, etc). Time-based
    staleness detection is inherently at the mercy of the filesystem's
    timestamps being trustworthy - --force exists precisely to sidestep
    this when they aren't.
    """
    if force:
        return " (--force)"
    src = job.source_mtime()
    out = job.output_mtime()
    if src is None or out is None:
        return ""
    age = src - out
    return f" (source is {age:.0f}s newer than the last render)"


def _plain_sentence(job, status: str, prefix: str, *, force: bool) -> str:
    """
    One compact line per state: what will happen (render/re-render/up to
    date/no source yet) and, where relevant, the source file it comes from
    - "fallback" is called out explicitly since a dedicated clip and a
    shared/reused mesh would otherwise look identical. A re-render also
    notes WHY (see _age_note) since that's driven by filesystem timestamps,
    which can be surprising/wrong (see --force below).
    """
    state = job.state.name
    suffix = _source_suffix(job, prefix)
    fallback = suffix and not _is_dedicated_clip(job)
    source = f"fallback ...{suffix}" if fallback else f"...{suffix}"

    if status == "NO-MESH":
        return f"  '{state}' no source asset yet."
    if status == "SKIP":
        return f"  '{state}' up to date ({source})."
    # RENDER
    if job.output_mtime() is None:
        return f"  '{state}' will render from {source}."
    return f"  '{state}' will re-render from {source}{_age_note(job, force=force)}."


def print_plan(jobs, *, force: bool) -> dict[str, int]:
    """
    Print one header line per subject (its base_mesh/ path and the common
    filename prefix shared by its resolved meshes, if any), followed by one
    plain-English line per animation state showing only the per-state
    suffix of the resolved mesh - whether its rendered asset doesn't exist
    yet, is already up to date, or is stale/missing and will be
    (re-)rendered. Returns status counts.
    """
    counts = {"RENDER": 0, "SKIP": 0, "NO-MESH": 0}

    by_subject: dict[str, list] = {}
    for job in jobs:
        by_subject.setdefault(job.subject_id, []).append(job)

    for subject_id, subject_jobs in by_subject.items():
        subject = _subject_label(subject_id)
        prefix = _common_mesh_prefix(subject_jobs)
        base_mesh_dir = subject_jobs[0].output_root / "base_mesh"

        header = f"{subject} ({base_mesh_dir}, prefix '{prefix}...'):" if prefix \
            else f"{subject} ({base_mesh_dir}):"
        print("-" * len(header))
        print(header)

        for job in subject_jobs:
            status = _status_for(job, force=force)
            counts[status] += 1
            print(_plain_sentence(job, status, prefix, force=force))

    print(f"\n{counts['RENDER']} to render, {counts['SKIP']} up to date, "
          f"{counts['NO-MESH']} missing a source asset.")
    if not force and counts["SKIP"] > 0:
        print("(Staleness is timestamp-based - if a mesh you know changed "
              "still shows 'up to date', or you just want everything "
              "re-rendered regardless of timestamps, add --force.)")
    return counts


def main() -> None:
    args = build_arg_parser().parse_args(_blender_argv())
    args.assets_root = resolve_assets_root(args.assets_root)
    print(f"[render_cli] assets root: {args.assets_root}")

    filters = {}
    if args.category == "clans":
        filters = {"clans": args.clans, "unit_types": args.unit_types}
    elif args.category == "dragons":
        filters = {"colors": args.colors, "stages": args.stages}
    elif args.category == "monsters":
        filters = {"tiers": args.tiers, "monsters": args.monsters}
    elif args.category == "npc":
        filters = {"names": args.names}
    filters = {k: v for k, v in filters.items() if v is not None}

    specs = build_specs(args.category, args.assets_root, **filters)
    jobs = [job for spec in specs for job in spec.render_jobs()]

    if not args.execute:
        print_plan(jobs, force=args.force)
        print("Nothing rendered - re-run with --execute to render.")
        return

    print_plan(jobs, force=args.force)
    print()
    results = run_jobs(jobs, force=args.force)
    total_frames = sum(len(v) for v in results.values())
    print(f"Done - {total_frames} frame(s) written.")


if __name__ == "__main__":
    main()
