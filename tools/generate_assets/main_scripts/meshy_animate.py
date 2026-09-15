#!/usr/bin/env python3
"""
scripts/meshy_animate.py

Drives Meshy's REST API (https://docs.meshy.ai/en/api) to rig each 'model'
block from scripts/model_definitions.txt EXACTLY ONCE, then animate it for
every one of that model's listed anim entries, downloading each result back
into this repo's render pipeline layout -- no `bpy` dependency, plain
`python` + `requests`. Each anim entry is EITHER:
  - a free-form Text-to-Motion prompt (`anim_text: "..."`) -- POST
    /openapi/v1/text-to-motion then POST /openapi/v1/animations with the
    resulting motion_task_id; or
  - a fixed Meshy Animation Library preset (`action_id: <int>`, see
    https://docs.meshy.ai/en/api/animation-library and
    utils/list_animation_library.py) -- POST /openapi/v1/animations with
    that action_id directly, skipping text-to-motion entirely (cheaper,
    deterministic). See attach_hand_item.parse_instructions_file's
    docstring for the exact '-- anim' line syntax for each.

WORKFLOW (run from inside scripts/ -- see scripts/README.md's top-level note)
    1. python attach_hand_item.py batch
           -- attaches/merges each model's held item(s) once, writing
              clans/<clan>/<unit_type>/base_mesh/_models/<model_name>_final.glb
    2. python meshy_animate.py [--dry-run] [--clan bard] [--unit-type scout] [--model NAME]
           -- for each selected model:
                a. rigs <model_name>_final.glb directly via POST /openapi/v1/rigging
                   (cached by that file's mtime in scripts/.meshy_cache.json --
                   re-runs skip re-rigging an unchanged model unless --force).
                   NOTE: an earlier version of this script pre-decimated the
                   merged mesh before every rig() call, based on an initial
                   (mistaken) theory that Meshy's rigging endpoint silently
                   auto-decimates dense uploads. Real testing this session
                   disproved that: even a 1,200-triangle input still came back
                   from Meshy rigged at ~200 triangles, AND the official Meshy
                   API docs (docs.meshy.ai) document no density-based
                   decimation/quality parameter at all (only a hard 300,000-face
                   REJECT limit). The low triangle count in Meshy's rigged
                   output therefore appears to be Meshy's own standard
                   auto-rigging output resolution/topology for ANY input, not
                   something this pipeline was causing or can fix by
                   pre-decimating -- so that step was reverted; the original,
                   undecimated _final.glb is uploaded directly again.
                b. for each of that model's (state, anim_text) pairs (TIMESTAMP-
                   DRIVEN, same convention as the rig cache above: skipped if
                   the final anim_<state>/Meshy_AI_..._anim_<state>.glb output
                   already exists and is newer than both the merged
                   _final.glb and the optimized mesh it's bound onto, unless
                   --force -- this avoids burning real Meshy credits
                   re-animating states that haven't actually changed, whether
                   this script is run standalone or via generate_assets.py):
                     - POST /openapi/v1/text-to-motion with anim_text
                     - POST /openapi/v1/animations with rig_task_id + motion_task_id
                     - downloads the resulting animation_glb_url into
                       clans/<clan>/<unit_type>/anim_<state>/Meshy_AI_<clan>_<unit_type>_anim_<state>.glb
                       -- the "meshy" substring makes
                       mesh_discovery.find_meshy_glb_in_anim_folder() pick this
                       up automatically as that state's render source, with NO
                       further pipeline changes needed.

The Meshy API key is read from line 1 of the instructions file (see
attach_hand_item.read_api_key) -- MESHY_API_KEY="msy_...".

USAGE (run from inside scripts/)
    python meshy_animate.py --dry-run
    python meshy_animate.py --clan bard --unit-type scout
    python meshy_animate.py --model bard_scout_dagger_raised --mode swift
    python meshy_animate.py --force
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# This file lives in scripts/main_scripts/ -- scripts/ itself
# (model_definitions.txt, .meshy_cache.json), scripts/main_scripts/ (this
# file's own dir, e.g. attach_hand_item.py/render.py), and scripts/utils/
# (mesh_discovery.py, render_config.py, decimate_items.py, etc.) all need
# to be importable/resolvable regardless of cwd.
_SCRIPT_DIR = Path(__file__).resolve().parent            # scripts/main_scripts/
_SCRIPTS_DIR = _SCRIPT_DIR.parent                         # scripts/
_UTILS_DIR = _SCRIPTS_DIR / "utils"
for _p in (_SCRIPT_DIR, _SCRIPTS_DIR, _UTILS_DIR):
    if str(_p) not in sys.path:
        sys.path.insert(0, str(_p))

from attach_hand_item import parse_instructions_file, filter_entries, resolve_output_paths, read_api_key  # noqa: E402
from render_config import ANIM_STATES  # noqa: E402
from meshy_client import MeshyClient, download_glb, get_credit_total, reset_credit_total  # noqa: E402
from render import find_blender, _run_filtered  # noqa: E402
from asset_paths import resolve_assets_root, resolve_instructions, meshy_cache_path  # noqa: E402

# See "REVISED STRATEGY" above -- Meshy's own animated mesh output is a
# throwaway placeholder; the real in-game mesh is this Blender-decimated
# target instead, reused across every anim state of a given model.
OPTIMIZED_TARGET_TRIANGLES = 30000
_DECIMATE_FOR_MESHY = _UTILS_DIR / "decimate_for_meshy.py"
_BIND_MESHY_RIG = _UTILS_DIR / "bind_meshy_rig.py"

# NOTE ON MESH RESOLUTION: an earlier version of this script pre-decimated
# the merged _final.glb before every rig() call, based on an initial
# (mistaken) theory that Meshy's rigging endpoint silently auto-decimates
# dense uploads down to ~200-250 triangles. Real testing this session
# disproved that theory: even a 1,200-triangle input still came back from
# Meshy rigged at ~200 triangles, and the official Meshy API docs
# (docs.meshy.ai/en/api/rigging) document no density-based decimation or
# quality parameter at all -- only a hard 300,000-face REJECT limit (well
# above anything this pipeline uploads). The low triangle count Meshy
# returns therefore appears to be Meshy's own standard auto-rigging output
# resolution/topology, independent of input density. _final.glb is still
# uploaded to rig()/animate() directly, unmodified, exactly as
# attach_hand_item.py wrote it -- but see REVISED STRATEGY below for what
# happens to the result.
#
# REVISED STRATEGY (Meshy mesh output is a THROWAWAY placeholder): since
# that ~200-250 tri ceiling can't be lifted, Meshy's animation_glb_url is no
# longer written directly to anim_<state>/Meshy_AI_..._anim_<state>.glb.
# Instead, per selected model:
#   1. _final.glb is decimated once (scripts/utils/decimate_for_meshy.py,
#      --target-triangles=OPTIMIZED_TARGET_TRIANGLES, default 30000) to
#      base_mesh/_models/<model_name>_final_optimized.glb -- the real
#      game-ready mesh, reused across every one of that model's anim states.
#   2. For each (state, anim_text): Meshy's rig+motion+animate result is
#      downloaded to a THROWAWAY path under
#      base_mesh/_models/_meshy_raw/<model_name>_anim_<state>_meshy_raw.glb
#      -- only its armature/animation curves are used.
#   3. scripts/utils/bind_meshy_rig.py binds that armature/animation onto
#      the optimized mesh from step 1, writing the FINAL result to the same
#      anim_<state>/Meshy_AI_..._anim_<state>.glb path render.py has always
#      expected -- no downstream changes needed.


def _duration_for_state(state: str) -> float:
    """
    Maps a render_config.ANIM_STATES entry's frames/fps to a Text-to-Motion
    'duration' in seconds, clamped to Meshy's accepted [2, 10] range and
    rounded to the nearest 0.5s step (both hard API requirements).
    """
    anim_state = ANIM_STATES.get(state)
    if anim_state is None:
        seconds = 3.0
    else:
        seconds = anim_state.frames / anim_state.fps
    seconds = max(2.0, min(10.0, seconds))
    return round(seconds * 2) / 2.0


def _load_cache(cache_path: Path) -> dict:
    """Loads the rig-task cache stored NEXT TO THE INSTRUCTIONS FILE in
    use (see asset_paths.meshy_cache_path) -- these scripts are shared
    across games, so the cache must live with the game's roster, not in
    the tools tree, or two games' identically-named models would collide
    on each other's rig_task_ids."""
    if cache_path.is_file():
        try:
            return json.loads(cache_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            return {}
    return {}


def _save_cache(cache_path: Path, cache: dict) -> None:
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    cache_path.write_text(json.dumps(cache, indent=2), encoding="utf-8")


def run(assets_graphics_root: Path, instructions_path: Path, *, clan=None, unit_type=None, model=None,
        state=None, mode="prime", dry_run=False, force=False, blender=None) -> bool:
    entries = parse_instructions_file(instructions_path)
    entries = filter_entries(entries, clan=clan, unit_type=unit_type, model=model)
    if not entries:
        print(f"No models match the given filter(s) (clan={clan!r}, unit_type={unit_type!r}, model={model!r}) -- nothing to do.", file=sys.stderr)
        return True

    client = None if dry_run else MeshyClient(read_api_key(instructions_path))
    cache_path = meshy_cache_path(instructions_path)
    cache = _load_cache(cache_path)

    blender_exe = None
    if not dry_run:
        try:
            blender_exe = find_blender(blender)
        except FileNotFoundError as e:
            print(f"ERROR: {e}", file=sys.stderr)
            return False

    animated = skipped = errors = 0

    for entry in entries:
        clan_, unit_type_, model_name = entry["clan"], entry["unit_type"], entry["model_name"]
        label = f"{clan_}/{unit_type_}/{model_name}"
        _, final_path = resolve_output_paths(assets_graphics_root, entry)

        if not final_path.is_file():
            print(f"{label}: {final_path} does not exist yet -- run "
                  f"'python attach_hand_item.py batch' first -- skipping", file=sys.stderr)
            skipped += 1
            continue

        # Blender-optimized (game-ready) mesh, reused across every anim
        # state of this model -- see module docstring's "REVISED STRATEGY".
        optimized_path = final_path.parent / f"{final_path.stem}_optimized.glb"
        if dry_run:
            print(f"{label}: DRY RUN -- would decimate {final_path} -> {optimized_path} "
                  f"(target={OPTIMIZED_TARGET_TRIANGLES} tris)")
        elif not optimized_path.is_file() or final_path.stat().st_mtime > optimized_path.stat().st_mtime or force:
            print(f"{label}: decimating {final_path} -> {optimized_path} (target={OPTIMIZED_TARGET_TRIANGLES} tris) ...")
            cmd = [
                str(blender_exe), "--background",
                "--python", str(_DECIMATE_FOR_MESHY), "--",
                "--input", str(final_path), "--output", str(optimized_path),
                "--target-triangles", str(OPTIMIZED_TARGET_TRIANGLES),
            ]
            rc = _run_filtered(cmd)
            if rc != 0:
                print(f"{label}: ERROR: decimate_for_meshy.py exited with code {rc}", file=sys.stderr)
                errors += 1
                continue
        else:
            print(f"{label}: {optimized_path} up to date -- skipping decimation")

        anims = entry["anims"]
        if state is not None:
            anims = [a for a in anims if a["state"] == state]
        if not anims:
            print(f"{label}: no '-- anim' lines match state={state!r} -- skipping")
            skipped += 1
            continue

        mtime = final_path.stat().st_mtime
        # Keyed by the FULL clan/unit_type/model triple, not the bare
        # model_name: model_names are only documented as unique within a
        # roster, and a single game can legitimately reuse e.g.
        # "dagger_raised" across clans -- a bare-name key would then hand
        # one unit's rig_task_id to a completely different mesh.
        cache_key = f"{clan_}/{unit_type_}/{model_name}"
        cache_entry = cache.get(cache_key) or cache.get(model_name)
        rig_task_id = None
        if not force and cache_entry and cache_entry.get("mtime") == mtime:
            rig_task_id = cache_entry.get("rig_task_id")
            print(f"{label}: reusing cached rig_task_id={rig_task_id} (source unchanged since last rig)")

        if dry_run:
            print(f"{label}: DRY RUN -- would rig {final_path}"
                  f"{' (cache hit)' if rig_task_id else ''}")
        elif rig_task_id is None:
            print(f"{label}: rigging {final_path} ...")
            try:
                rig_task_id, _ = client.rig(final_path)
            except Exception as e:  # noqa: BLE001 -- one bad model shouldn't abort the run
                print(f"{label}: ERROR rigging: {e}", file=sys.stderr)
                errors += 1
                continue
            cache[cache_key] = {"mtime": mtime, "rig_task_id": rig_task_id}
            _save_cache(cache_path, cache)
            print(f"{label}: rigged -- rig_task_id={rig_task_id}")

        for anim in anims:
            anim_state = anim["state"]
            anim_text, action_id = anim["anim_text"], anim["action_id"]
            # Two mutually-exclusive anim-line forms (see
            # attach_hand_item.parse_instructions_file): a free-form
            # Text-to-Motion prompt, or a fixed Meshy Animation Library
            # action_id (https://docs.meshy.ai/en/api/animation-library) --
            # the latter skips text-to-motion entirely (cheaper, no prompt
            # variance) since Meshy's animate() endpoint accepts it
            # directly alongside rig_task_id.
            duration = _duration_for_state(anim_state) if action_id is None else None
            unit_dir = assets_graphics_root / "clans" / clan_ / unit_type_
            out_path = unit_dir / f"anim_{anim_state}" / f"Meshy_AI_{clan_}_{unit_type_}_anim_{anim_state}.glb"
            meshy_raw_path = final_path.parent / "_meshy_raw" / f"{model_name}_anim_{anim_state}_meshy_raw.glb"

            # TIMESTAMP-DRIVEN SKIP (matches this file's own decimation/rig-
            # cache checks just above, and generate_assets.py's own
            # _is_stale gate on this same out_path when driven through that
            # entry point): out_path is only regenerated if missing, or
            # older than either of its real inputs (the merged _final.glb,
            # or the optimized mesh bind_meshy_rig.py actually binds onto).
            # Without this check, running THIS script standalone (its own
            # documented usage, e.g. `python meshy_animate.py --clan bard`)
            # unconditionally re-ran text-to-motion + animate -- real Meshy
            # API credits -- for every selected state on every invocation,
            # even when nothing had changed since the last successful run;
            # only going through generate_assets.py's own separate
            # _is_stale gate avoided that waste. --force still bypasses
            # this unconditionally, as documented on the --force flag.
            up_to_date = (
                out_path.is_file()
                and out_path.stat().st_mtime >= final_path.stat().st_mtime
                # optimized_path may legitimately not exist yet under
                # --dry-run (the decimation step above never writes
                # anything in dry-run mode) -- only compare against it
                # when it's actually there, same "missing counts as
                # not-yet-produced, not a staleness signal" convention as
                # generate_assets.py's own _is_stale helper.
                and (not optimized_path.is_file() or out_path.stat().st_mtime >= optimized_path.stat().st_mtime)
            )

            if action_id is not None:
                plan_desc = f"animate(action_id={action_id})"
            else:
                plan_desc = f"text-to-motion({anim_text!r}, duration={duration}s, mode={mode}) then animate"

            if dry_run:
                if up_to_date and not force:
                    print(f"{label} -anim {anim_state}: {out_path} up to date -- would skip")
                    skipped += 1
                    continue
                print(f"{label} -anim {anim_state}: DRY RUN -- would {plan_desc} -> {meshy_raw_path} "
                      f"(throwaway), then bind with {optimized_path} -> {out_path}")
                animated += 1
                continue

            if up_to_date and not force:
                print(f"{label} -anim {anim_state}: {out_path} up to date -- skipping animate")
                skipped += 1
                continue

            try:
                if action_id is not None:
                    print(f"{label} -anim {anim_state}: animating with library action_id={action_id} ...")
                    result = client.animate(rig_task_id, action_id=action_id)
                else:
                    print(f"{label} -anim {anim_state}: generating motion for {anim_text!r} "
                          f"(duration={duration}s, mode={mode}) ...")
                    motion_task_id, _ = client.text_to_motion(anim_text, duration, mode=mode)
                    print(f"{label} -anim {anim_state}: motion ready -- motion_task_id={motion_task_id}; animating ...")
                    result = client.animate(rig_task_id, motion_task_id=motion_task_id)
                animation_glb_url = result["animation_glb_url"]
                download_glb(animation_glb_url, meshy_raw_path)
                print(f"{label} -anim {anim_state}: wrote throwaway Meshy output -- {meshy_raw_path}")
            except Exception as e:  # noqa: BLE001 -- one bad state shouldn't abort the run
                print(f"{label} -anim {anim_state}: ERROR: {e}", file=sys.stderr)
                errors += 1
                continue

            print(f"{label} -anim {anim_state}: binding Meshy rig onto optimized mesh -> {out_path} ...")
            cmd = [
                str(blender_exe), "--background",
                "--python", str(_BIND_MESHY_RIG), "--",
                "--optimized", str(optimized_path), "--meshy-anim", str(meshy_raw_path),
                "--output", str(out_path),
            ]
            rc = _run_filtered(cmd)
            if rc != 0:
                print(f"{label} -anim {anim_state}: ERROR: bind_meshy_rig.py exited with code {rc}", file=sys.stderr)
                errors += 1
                continue
            print(f"{label} -anim {anim_state}: wrote {out_path}")
            animated += 1

    print(f"\nDone. animated={animated} skipped={skipped} errors={errors}")
    return errors == 0


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--assets-root", default=None,
                    help="path to the game's graphics/ assets folder (default: $AEVUM_ASSETS_ROOT, else cwd)")
    p.add_argument("--instructions", default=None,
                    help="path to instructions file (default: model_definitions.txt in the assets root)")
    p.add_argument("--clan", default=None, help="restrict to this clan (e.g. bard)")
    p.add_argument("--unit-type", default=None, help="restrict to this unit_type (e.g. scout)")
    p.add_argument("--model", default=None, help="restrict to this exact model_name (e.g. bard_scout_dagger_raised)")
    p.add_argument("--state", default=None,
                    help="restrict to this exact anim state (e.g. attack) -- for re-testing/iterating on a single "
                         "state without re-processing every '-- anim' line for the selected model(s).")
    p.add_argument("--mode", choices=["prime", "swift"], default="prime",
                    help="Text-to-Motion generation mode -- prime (highest quality, FBX, 10 credits) "
                         "or swift (faster/cheaper, BVH, 3 credits). Default: prime.")
    p.add_argument("--dry-run", action="store_true", help="print the planned task graph without calling the API")
    p.add_argument("--force", action="store_true", help="re-rig every selected model even if its cached rig_task_id is still valid")
    p.add_argument("--blender", default=None, help="Explicit path to blender.exe, overriding auto-discovery.")
    return p


def main() -> int:
    args = build_arg_parser().parse_args()
    assets_graphics_root = resolve_assets_root(args.assets_root)
    instructions_path = resolve_instructions(assets_graphics_root, args.instructions)
    print(f"[meshy_animate] assets root:  {assets_graphics_root}")
    print(f"[meshy_animate] instructions: {instructions_path}")
    if not instructions_path.is_file():
        print(f"ERROR: instructions file not found: {instructions_path}", file=sys.stderr)
        return 1

    # Reset here (not inside run()) because run() is also called directly,
    # possibly multiple times, by generate_assets.py's own animate stage --
    # that orchestrator resets/reports the credit total itself, once, for
    # its whole multi-stage invocation (see its own main_with_args). This
    # standalone entry point is the only caller for which "this run" means
    # exactly one run() call, so it owns its own reset+report pair.
    if not args.dry_run:
        reset_credit_total()

    ok = run(
        assets_graphics_root, instructions_path,
        clan=args.clan, unit_type=args.unit_type, model=args.model, state=args.state,
        mode=args.mode, dry_run=args.dry_run, force=args.force, blender=args.blender,
    )
    if not args.dry_run:
        print(f"Meshy credits used this run: {get_credit_total()}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
