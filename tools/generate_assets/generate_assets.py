#!/usr/bin/env python3
"""
scripts/generate_assets.py

SINGLE ENTRY POINT for the whole clan sprite pipeline. Run this one script,
re-run it any time anything upstream changes, and it will only regenerate
exactly the downstream assets that are actually stale -- a pure, mtime-based
dependency cascade, no separate manual bookkeeping required.

DEPENDENCY CHAIN (each stage's OWN output mtime is compared against every
one of its inputs' mtimes; if any input is newer, or the output doesn't
exist yet, that stage re-runs, which in turn makes every downstream stage
stale too on the SAME pass):

    clans/<clan>/_items/<item>.glb                        (raw item)
    clans/<clan>/_models/<clan>_<unit_type>.glb            (raw base model)
            |  rig_base_models.py:
            |    1. Meshy rig() -> THROWAWAY base_mesh/_meshy_raw/..._rig_raw.glb
            |       (Meshy's own mesh output has a hard ~200-250 tri ceiling --
            |       see decimate_for_meshy.py's docstring -- so only its
            |       armature/animation is ever used, never its mesh)
            |    2. decimate_for_meshy.py -> base_mesh/<clan>_<unit_type>_optimized.glb
            |       (Blender-decimated, game-ready mesh, e.g. 30000 tris)
            |    3. bind_meshy_rig.py -> binds Meshy's armature onto the
            |       optimized mesh
            v
    clans/<clan>/<unit_type>/base_mesh/<clan>_<unit_type>_rigged.glb  (FINAL asset:
            |       optimized mesh + Meshy armature -- no downstream change needed)
            |  attach_hand_item.py (+ item(s) above, per model_definitions.txt)
            v
    clans/<clan>/<unit_type>/base_mesh/_models/<model_name>_final.glb
            |  meshy_animate.py:
            |    1. decimate_for_meshy.py -> ..._final_optimized.glb (game-ready
            |       mesh, reused across every anim state of this model)
            |    2. Meshy rig+text-to-motion+animate -> THROWAWAY
            |       base_mesh/_models/_meshy_raw/..._anim_<state>_meshy_raw.glb
            |    3. bind_meshy_rig.py -> binds Meshy's armature/animation onto
            |       the optimized mesh
            v
    clans/<clan>/<unit_type>/anim_<state>/Meshy_AI_..._anim_<state>.glb  (FINAL
            |       asset: optimized mesh + Meshy armature/animation)
            |  render.py (render_core, already incremental)
            v
    clans/<clan>/<unit_type>/anim_<state>/<direction>/NNNN.png

This means: edit/replace an ITEM file, and every model that references it
(directly, or via a model_definitions.txt preset) regenerates. Edit/replace
a BASE MODEL file, and every model built on that (clan, unit_type) pair
regenerates, cascading all the way through to re-rendered sprite frames.

DELETE-THEN-REGENERATE: whenever a stage is determined stale (or --force
scopes it), its own output file(s) -- AND every downstream output that
depends on them -- are deleted FIRST, before regenerating. This guarantees
every file present on disk after a run was genuinely (re)written by that
run, rather than relying purely on mtime comparisons (which are still used
to DECIDE what's stale, just not to decide what's "close enough" to leave
alone). If a regeneration call then fails (e.g. a Meshy API error), the
file is simply left missing -- clearly visible as "not done yet" on the
next run, which will detect and retry it the same way as any other
missing output, rather than silently leaving a stale file in its place.

--force SCOPING: --force is never a standalone/global switch on its own --
it only affects whatever (clan, unit_type, model, state) selection is
already narrowed by --clan/--unit-type/--model/--state. Within that
selection, every stage is treated as stale regardless of what timestamps
say. Outside the selection, nothing is touched. Running --force with NO
filters at all reprocesses the ENTIRE roster -- expensive (real Meshy API
credits) and rarely what you want; always combine --force with at least
one filter unless you genuinely mean "regenerate everything".

WHERE ASSETS COME FROM: this script tree lives in the ENGINE repo
(tools/generate_assets/) and is meant to be invoked FROM YOUR GAME FOLDER
against that game's own assets -- it never reads or writes anything inside
the tools tree itself. The assets root is resolved as:
    --assets-root <path>  >  $AEVUM_ASSETS_ROOT  >  the current directory
(and if the resolved directory contains graphics/clans/ rather than
clans/, the graphics/ subfolder is used). See utils/asset_paths.py.

The roster file (model_definitions.txt, whose first line is the Meshy API
key) is likewise looked up in the game's assets root first, falling back
to the template shipped alongside these scripts. The Meshy rig-task cache
(.meshy_cache.json) is written next to whichever roster file is in use, so
two different games never share one cache.

Usage (run from your game folder):
    cd C:\\my_game
    python C:\\game_engine_godot\\tools\\generate_assets\\generate_assets.py --dry-run
    python ...\\generate_assets.py --clan bard --unit-type scout
    python ...\\generate_assets.py --clan bard --unit-type scout --model bard_scout_dagger_raised --state attack
    python ...\\generate_assets.py --clan bard --unit-type scout --state attack --force
    python ...\\generate_assets.py --skip-render
    python ...\\generate_assets.py --assets-root D:\\other_game\\graphics
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

# This file lives directly at scripts/ (the single entry point) --
# scripts/main_scripts/ (rig_base_models.py, attach_hand_item.py,
# meshy_animate.py, render.py -- the 4 pipeline stages this orchestrates)
# and scripts/utils/ (mesh_discovery.py, render_config.py, etc.) both need
# to be importable regardless of cwd.
_SCRIPT_DIR = Path(__file__).resolve().parent              # scripts/
_MAIN_SCRIPTS_DIR = _SCRIPT_DIR / "main_scripts"
_UTILS_DIR = _SCRIPT_DIR / "utils"
for _p in (_SCRIPT_DIR, _MAIN_SCRIPTS_DIR, _UTILS_DIR):
    if str(_p) not in sys.path:
        sys.path.insert(0, str(_p))

import rig_base_models  # noqa: E402
import attach_hand_item  # noqa: E402
import meshy_animate  # noqa: E402
from attach_hand_item import parse_instructions_file, filter_entries, resolve_output_paths  # noqa: E402
import render as render_module  # noqa: E402
from render import find_blender, _run_filtered  # noqa: E402
from meshy_client import get_credit_total, reset_credit_total  # noqa: E402
from asset_paths import resolve_assets_root, resolve_instructions  # noqa: E402

_RENDER_CLI = _UTILS_DIR / "render_cli.py"


def _item_paths_for_entry(assets_root: Path, entry: dict) -> list[Path]:
    """clans/<clan>/_items/<item>.glb paths referenced by this entry's
    resolved hand slots (entry['hands'] already holds literal item names,
    post-preset-resolution -- see parse_instructions_file)."""
    clan = entry["clan"]
    return [
        assets_root / "clans" / clan / "_items" / f"{item_name}.glb"
        for item_name in entry["hands"].values()
        if item_name
    ]


def _newest_mtime(paths: list[Path]) -> float | None:
    mtimes = [p.stat().st_mtime for p in paths if p.is_file()]
    return max(mtimes) if mtimes else None


def _is_stale(output_path: Path, input_paths: list[Path]) -> bool:
    """True if output_path doesn't exist, or any existing input is newer."""
    if not output_path.is_file():
        return True
    newest_input = _newest_mtime(input_paths)
    if newest_input is None:
        return False
    return newest_input > output_path.stat().st_mtime


def _delete_if_exists(path: Path, *, dry_run: bool) -> None:
    """
    Deletes path if it exists (a no-op, not an error, if it's already
    missing). DELETE-THEN-REGENERATE DESIGN: rather than relying solely on
    mtime comparisons to decide "is this output current", every stage
    below deletes its own stale output (and everything cascading
    downstream of it) BEFORE regenerating, so every file present on disk
    after a run is GUARANTEED freshly written by that run -- never a
    leftover that merely happens to compare newer/older under an mtime
    check. If regeneration then fails (e.g. a Meshy API error), the file
    is simply left missing -- clearly visible as "not done yet" on the
    next run (which will detect it as missing, same as today's "output
    doesn't exist" staleness rule) rather than silently stale.
    """
    if not path.is_file():
        return
    if dry_run:
        print(f"    DRY RUN -- would delete {path}")
        return
    path.unlink()
    print(f"    deleted stale {path}")


def _delete_glob(directory: Path, pattern: str, *, dry_run: bool) -> None:
    """Deletes every file under directory matching pattern (non-recursive
    glob) -- used for cascading deletes of a whole anim_<state>/ folder's
    rendered frames (e.g. pattern="**/*.png" for every direction)."""
    if not directory.is_dir():
        return
    for p in directory.glob(pattern):
        if p.is_file():
            _delete_if_exists(p, dry_run=dry_run)


def _delete_downstream_of_rig(assets_root: Path, clan: str, unit_type: str,
                               all_entries: list[dict], *, state: str | None, dry_run: bool) -> None:
    """Cascading delete for a stale rig stage: every model built on this
    (clan, unit_type)'s own outputs, and every one of those models'
    anim_<state> outputs (Meshy glb + rendered frames) -- restricted to
    `state` if given, so a --state-scoped --force never touches other
    anim states that merely happen to share this (clan, unit_type)'s rig."""
    for entry in all_entries:
        if entry["clan"] != clan or entry["unit_type"] != unit_type:
            continue
        _delete_downstream_of_attach(assets_root, entry, state=state, dry_run=dry_run)


def _delete_downstream_of_attach(assets_root: Path, entry: dict, *, state: str | None, dry_run: bool) -> None:
    """Cascading delete for a stale attach stage: this model's own
    _final*.glb/preview outputs, plus every one of its anim_<state>
    outputs (Meshy glb + rendered frames) -- restricted to `state` if
    given (see _delete_downstream_of_rig). If `state` is given and this
    entry has no anim matching it at all, this model isn't in scope --
    nothing of its is deleted (its _final.glb is shared by OTHER anim
    states that must be left untouched)."""
    if state is not None and not any(a["state"] == state for a in entry["anims"]):
        return
    clan, unit_type, model_name = entry["clan"], entry["unit_type"], entry["model_name"]
    _, final_path = resolve_output_paths(assets_root, entry)
    anims = entry["anims"] if state is None else [a for a in entry["anims"] if a["state"] == state]
    # The model's own _final*.glb/preview is only invalidated if we're
    # regenerating EVERY anim state that depends on it (state=None) --
    # a --state-scoped delete only needs to re-animate that one state,
    # which doesn't require touching (or re-attaching) the shared
    # _final.glb at all.
    if state is None:
        _delete_if_exists(final_path, dry_run=dry_run)
        _delete_if_exists(final_path.with_name(final_path.stem + "_meshy.glb"), dry_run=dry_run)
        _delete_if_exists(final_path.with_name(final_path.stem + "_preview.png"), dry_run=dry_run)
    for anim in anims:
        _delete_downstream_of_animate(assets_root, clan, unit_type, anim["state"], dry_run=dry_run)


def _delete_downstream_of_animate(assets_root: Path, clan: str, unit_type: str, state: str, *, dry_run: bool) -> None:
    """Cascading delete for a stale animate stage: this state's Meshy glb
    output and every rendered frame PNG across all 6 directions."""
    anim_dir = assets_root / "clans" / clan / unit_type / f"anim_{state}"
    out_path = anim_dir / f"Meshy_AI_{clan}_{unit_type}_anim_{state}.glb"
    _delete_if_exists(out_path, dry_run=dry_run)
    _delete_glob(anim_dir, "*/*.png", dry_run=dry_run)


def process_rig_stage(assets_root, instructions_path, clan, unit_type, all_entries, *,
                      state, dry_run, force, blender) -> bool:
    """Stage 0: raw _models/<clan>_<unit_type>.glb -> base_mesh/*_rigged.glb.
    Returns True if this stage's output is now up to date (already was, or
    was just (re)generated) -- False on error."""
    raw_path = assets_root / "clans" / clan / "_models" / f"{clan}_{unit_type}.glb"
    if not raw_path.is_file():
        # No raw base model at all -- nothing for this stage to do; a
        # rigged file may already exist from an earlier/manual run, which
        # is fine (attach_hand_item.py will just use it as-is).
        return True

    rigged_path = assets_root / "clans" / clan / unit_type / "base_mesh" / f"{clan}_{unit_type}_rigged.glb"
    if not force and not rig_base_models.needs_rig(raw_path, rigged_path):
        return True

    # Same path convention as rig_base_models.py's own main_with_args --
    # see that function for the "REVISED STRATEGY" these two extra outputs
    # (Meshy's throwaway rigged mesh + the Blender-decimated game mesh)
    # come from.
    base_mesh_dir = rigged_path.parent
    optimized_path = base_mesh_dir / f"{clan}_{unit_type}_optimized.glb"
    meshy_raw_path = base_mesh_dir / "_meshy_raw" / f"{clan}_{unit_type}_rig_raw.glb"

    print(f"=== [rig] {clan}/{unit_type}: {raw_path.name} -> {rigged_path.name} ===")
    # DELETE-THEN-REGENERATE: this rigged file (and everything downstream
    # of it -- every model/anim state built on this unit) is about to be
    # invalidated, so clear it all first (see _delete_if_exists docstring).
    _delete_if_exists(rigged_path, dry_run=dry_run)
    _delete_downstream_of_rig(assets_root, clan, unit_type, all_entries, state=state, dry_run=dry_run)

    if dry_run:
        rig_base_models.rig_one(None, clan, unit_type, raw_path, rigged_path,
                                 meshy_raw_path=meshy_raw_path, optimized_path=optimized_path,
                                 blender_exe=None, dry_run=True)
        return True

    try:
        blender_exe = find_blender(blender)
    except FileNotFoundError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return False

    # Key comes from the instructions file ACTUALLY in use for this run
    # (the game's own model_definitions.txt), not a module-level default
    # that would point back into the tools tree's template.
    client = meshy_animate.MeshyClient(attach_hand_item.read_api_key(instructions_path))
    return rig_base_models.rig_one(client, clan, unit_type, raw_path, rigged_path,
                                    meshy_raw_path=meshy_raw_path, optimized_path=optimized_path,
                                    blender_exe=blender_exe, dry_run=False)


def process_attach_stage(assets_root, instructions_path, entry, *, state, dry_run, force) -> bool:
    """Stage 1: rigged base + item(s) -> base_mesh/_models/<model>_final.glb."""
    clan, unit_type, model_name = entry["clan"], entry["unit_type"], entry["model_name"]
    if state is not None and not any(a["state"] == state for a in entry["anims"]):
        # This model doesn't even have the requested --state -- --force
        # must never touch it (see module docstring's --force SCOPING).
        return True
    rig_path, final_path = resolve_output_paths(assets_root, entry)
    if rig_path is None:
        if dry_run:
            # Expected in a dry-run cascade: Stage 0 (rig) never actually
            # WROTE anything under --dry-run, so there may legitimately be
            # no rigged file on disk yet for this stage to find -- this is
            # not a real error, just an informational "can't preview this
            # far ahead without actually running it" note.
            print(f"{clan}/{unit_type}/{model_name}: DRY RUN -- no rigged base mesh on disk yet "
                  f"(would exist after a real run of the rig stage above) -- cannot preview attach further")
            return True
        print(f"{clan}/{unit_type}/{model_name}: no rigged base mesh yet -- run rig_base_models.py first -- skipping",
              file=sys.stderr)
        return False

    inputs = [rig_path] + _item_paths_for_entry(assets_root, entry)
    if not force and not _is_stale(final_path, inputs):
        return True

    print(f"=== [attach] {clan}/{unit_type}/{model_name} -> {final_path.name} ===")
    # DELETE-THEN-REGENERATE: this model's own _final*.glb/preview outputs
    # and every anim state built on it are about to be invalidated.
    _delete_downstream_of_attach(assets_root, entry, state=state, dry_run=dry_run)
    ok = attach_hand_item.run_batch(
        assets_root, instructions_path, scale_multiplier=1.0, weight_threshold=0.15,
        dry_run=dry_run, clan=clan, unit_type=unit_type, model=model_name,
    )
    return bool(ok)


def process_animate_stage(assets_root, instructions_path, entry, state, *, dry_run, force, mode, blender) -> bool:
    """Stage 2: _final.glb -> anim_<state>/Meshy_AI_..._anim_<state>.glb."""
    clan, unit_type, model_name = entry["clan"], entry["unit_type"], entry["model_name"]
    _, final_path = resolve_output_paths(assets_root, entry)
    if not final_path.is_file():
        print(f"{clan}/{unit_type}/{model_name}: {final_path} does not exist yet -- skipping animate", file=sys.stderr)
        return False

    out_path = (assets_root / "clans" / clan / unit_type / f"anim_{state}" /
                f"Meshy_AI_{clan}_{unit_type}_anim_{state}.glb")
    if not force and not _is_stale(out_path, [final_path]):
        return True

    print(f"=== [animate] {clan}/{unit_type}/{model_name} -anim {state} -> {out_path.name} ===")
    # DELETE-THEN-REGENERATE: this state's Meshy glb and every rendered
    # frame PNG are about to be invalidated.
    _delete_downstream_of_animate(assets_root, clan, unit_type, state, dry_run=dry_run)
    ok = meshy_animate.run(
        assets_root, instructions_path, clan=clan, unit_type=unit_type, model=model_name, state=state,
        mode=mode, dry_run=dry_run, force=force, blender=blender,
    )
    return bool(ok)


def process_render_stage(assets_root, clan, unit_type, *, state, dry_run, force, blender) -> bool:
    """Stage 3: rendered anim glbs -> sprite PNG frames. render_cli.py has
    no --state filter of its own, so a scoped --state's stale frames were
    already deleted by process_animate_stage above -- render_core's own
    is_file() check picks those up as missing and regenerates them without
    needing --force here (which would otherwise force-rerender EVERY state
    for this unit, violating --force's --state scoping). --force is only
    forwarded to render_cli.py when no --state filter is active (a
    whole-unit-scoped force, where re-rendering everything is correct)."""
    # --assets-root MUST be forwarded: render_cli.py runs inside Blender,
    # where its own default would resolve off this tools tree instead of
    # the game folder being generated (see utils/asset_paths.py).
    base_args = ["--category", "clans", "--assets-root", str(assets_root),
                 "--clan", clan, "--unit-type", unit_type]
    if dry_run:
        print(f"=== [render] {clan}/{unit_type}: DRY RUN -- would invoke render.py (plan-only, no --execute) ===")
        cmd_args = list(base_args)
    else:
        print(f"=== [render] {clan}/{unit_type}: rendering stale frames ===")
        cmd_args = [*base_args, "--execute"]
        if force and state is None:
            cmd_args.append("--force")

    try:
        blender_exe = find_blender(blender)
    except FileNotFoundError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return False

    cmd = [str(blender_exe), "--background", "--python", str(_RENDER_CLI), "--", *cmd_args]
    rc = _run_filtered(cmd)
    return rc == 0


def main_with_args(*, assets_root=None, instructions=None,
                    clan=None, unit_type=None, model=None, state=None,
                    dry_run=False, force=False, skip_render=False, mode="prime", blender=None) -> int:
    # Resolved HERE (not as module-level argparse defaults) so the game
    # folder the user actually invoked this from -- or their explicit
    # --assets-root/AEVUM_ASSETS_ROOT -- wins over anything relative to
    # this tools tree. See utils/asset_paths.py.
    assets_root = resolve_assets_root(assets_root)
    instructions = resolve_instructions(assets_root, instructions)
    if not instructions.is_file():
        print(f"ERROR: instructions file not found: {instructions}\n"
              f"       Create a {instructions.name} in your game's assets folder "
              f"(see the template in {_SCRIPT_DIR}), or pass --instructions.", file=sys.stderr)
        return 1
    if not (assets_root / "clans").is_dir():
        print(f"ERROR: no 'clans/' folder under the resolved assets root: {assets_root}\n"
              f"       Run this from your game's assets folder, or pass "
              f"--assets-root <path-to-graphics>.", file=sys.stderr)
        return 1
    print(f"[generate_assets] assets root:  {assets_root}")
    print(f"[generate_assets] instructions: {instructions}")

    all_entries = parse_instructions_file(instructions)
    entries = filter_entries(all_entries, clan=clan, unit_type=unit_type, model=model)
    if not entries:
        print(f"No entries match the given filter(s) (clan={clan!r}, unit_type={unit_type!r}, model={model!r}) -- "
              f"nothing to do.", file=sys.stderr)
        return 0

    # Single reset for this WHOLE invocation, even though Stage 0 (rig) and
    # Stage 2 (animate) each create their own separate MeshyClient per
    # (clan, unit_type)/model -- meshy_client's credit tally is
    # process-wide/module-level for exactly this reason (see its own
    # docstring), so every real Meshy task across every stage below still
    # contributes to the one end-of-run total printed at the bottom of
    # this function, instead of being reset/reported piecemeal per stage.
    if not dry_run:
        reset_credit_total()

    # Every distinct (clan, unit_type) touched by the selection -- rig
    # stage and render stage both operate at this granularity (a rigged
    # base mesh / a subject's rendered frames are shared across every
    # model variant for that unit).
    clan_unit_pairs = sorted({(e["clan"], e["unit_type"]) for e in entries})

    errors = 0

    # --- Stage 0: rig ---------------------------------------------------
    for c, u in clan_unit_pairs:
        if not process_rig_stage(assets_root, instructions, c, u, entries,
                                 state=state, dry_run=dry_run, force=force, blender=blender):
            errors += 1

    # --- Stage 1: attach --------------------------------------------------
    for entry in entries:
        if not process_attach_stage(assets_root, instructions, entry, state=state, dry_run=dry_run, force=force):
            errors += 1

    # --- Stage 2: animate ---------------------------------------------------
    for entry in entries:
        anims = entry["anims"]
        if state is not None:
            anims = [a for a in anims if a["state"] == state]
        for anim in anims:
            if not process_animate_stage(assets_root, instructions, entry, anim["state"],
                                          dry_run=dry_run, force=force, mode=mode, blender=blender):
                errors += 1

    # --- Stage 3: render ---------------------------------------------------
    if not skip_render:
        for c, u in clan_unit_pairs:
            if not process_render_stage(assets_root, c, u, state=state, dry_run=dry_run, force=force, blender=blender):
                errors += 1
    else:
        print("--skip-render: not invoking render.py")

    print(f"\n=== generate_assets.py done. {len(clan_unit_pairs)} (clan, unit_type) pair(s), "
          f"{len(entries)} model entry(ies), errors={errors} ===")
    if not dry_run:
        print(f"Meshy credits used this run: {get_credit_total()}")
    return 0 if errors == 0 else 1


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--assets-root", type=Path, default=None,
                    help="Path to the game's graphics/ assets folder (default: $AEVUM_ASSETS_ROOT, "
                         "else the current working directory -- i.e. run this from your game folder).")
    p.add_argument("--instructions", type=Path, default=None,
                    help="Path to model_definitions.txt (default: the one in the assets root, else "
                         "the template shipped with these scripts).")
    p.add_argument("--clan", default=None, help="Restrict to this clan (e.g. bard).")
    p.add_argument("--unit-type", default=None, help="Restrict to this unit_type (e.g. scout).")
    p.add_argument("--model", default=None, help="Restrict to this exact model_name (e.g. bard_scout_dagger_raised).")
    p.add_argument("--state", default=None, help="Restrict to this exact anim state (e.g. attack).")
    p.add_argument("--dry-run", action="store_true", help="Report what would happen at every stage without changing anything.")
    p.add_argument("--force", action="store_true",
                    help="Within the current --clan/--unit-type/--model/--state selection, treat every stage as "
                         "stale regardless of timestamps and regenerate it anyway. Scoped to that selection only -- "
                         "never a standalone global switch. Omitting all filters + --force reprocesses the ENTIRE "
                         "roster (expensive, real Meshy credits) -- always pair --force with at least one filter "
                         "unless that is genuinely what you want.")
    p.add_argument("--skip-render", action="store_true", help="Stop after the Meshy animate stage; don't invoke render.py.")
    p.add_argument("--mode", choices=["prime", "swift"], default="prime",
                    help="Text-to-Motion generation mode forwarded to meshy_animate.py (default: prime).")
    p.add_argument("--blender", default=None, help="Explicit path to blender.exe, overriding auto-discovery.")
    return p


def main() -> int:
    args = build_arg_parser().parse_args()
    return main_with_args(
        assets_root=args.assets_root, instructions=args.instructions,
        clan=args.clan, unit_type=args.unit_type, model=args.model, state=args.state,
        dry_run=args.dry_run, force=args.force, skip_render=args.skip_render,
        mode=args.mode, blender=args.blender,
    )


if __name__ == "__main__":
    sys.exit(main())


