# tools/generate_assets/ — Blender batch-render / Meshy animation API

Reusable pipeline for generating clan/dragon/monster/npc sprite frames from
3D meshes via Blender + Meshy. See your asset repo's `blender.md` and
`doc/CLAN_UNIT_ANIMATION_MATRIX.md` for the design spec this implements.

---

## PORTING NOTE — read this first

This tree used to live INSIDE the asset repo, at `assets/graphics/scripts/`,
so every script derived its asset root as "my own parent directory". It now
lives in the **engine** repo (`tools/generate_assets/`) and is invoked
**from your game folder** against **that game's** assets. Consequently:

* **Run it from your game folder** (or pass `--assets-root`). The assets
  root is resolved as:

  `--assets-root <path>` **>** `$AEVUM_ASSETS_ROOT` **>** the current
  working directory

  If the resolved folder holds `graphics/clans/` rather than `clans/`, the
  `graphics/` subfolder is used automatically — so both `cd <game>` and
  `cd <game>/graphics` work. See `utils/asset_paths.py`.

* **`model_definitions.txt` (your unit/item/animation roster)** is looked
  up in your game's assets root first, then one level up, and only then
  falls back to the template shipped here. Copy the template into your
  game's `graphics/` folder and edit it there.

* **The Meshy API key** comes from the `MESHY_API_KEY` environment variable
  if set (preferred — this is a shared, version-controlled tools tree),
  otherwise from line 1 of your game's `model_definitions.txt`. The bundled
  template deliberately holds a placeholder, and the pipeline refuses to
  run against it.

* **`.meshy_cache.json`** (Meshy rig-task ids) is written next to whichever
  `model_definitions.txt` is in use — never into this tools tree — so two
  games never share one cache. Cache entries are keyed by
  `clan/unit_type/model_name`, not a bare model name.

* Nothing in this pipeline reads or writes assets inside `tools/`.

### Quick start

```powershell
$env:MESHY_API_KEY = "msy_..."                # once per shell
cd C:\my_game                                  # your game folder
python C:\game_engine_godot\tools\generate_assets\generate_assets.py --dry-run
python C:\game_engine_godot\tools\generate_assets\generate_assets.py --clan bard --unit-type scout
```

Or use the wrapper: `./tools/generate_assets.ps1 -AssetsRoot C:\my_game\graphics -DryRun`.

---

## The pipeline: one entry point, `generate_assets.py`

This tree is organized into: `generate_assets.py` itself (the single entry
point, at the top), `main_scripts/` (the 4 pipeline-stage scripts it
drives, runnable standalone too), and `utils/` (internal helpers, invoked
automatically). **`generate_assets.py` is the single command you normally
need** — it drives the entire raw-model -> rigged -> item-attached ->
Meshy-animated -> rendered-sprite pipeline in one pass, re-running only the
stages that are actually stale.

The stage scripts (`main_scripts/rig_base_models.py`,
`main_scripts/attach_hand_item.py batch`, `main_scripts/meshy_animate.py`,
`main_scripts/render.py`) and the `utils/` tools (`decimate_items.py`,
`validate_glb.py`, `scaffold_dirs.py`, `preview_batch_items.py`) can each
be invoked standalone by absolute path from your game folder; they all
accept the same `--assets-root` / `--instructions` resolution described
above. Older examples further down this file that assume a bare
`python <script>.py` from inside `scripts/` are historical — prefix them
with this folder's absolute path and run from your game folder instead.

python generate_assets.py --dry-run
python generate_assets.py --clan bard --unit-type scout
python generate_assets.py --clan bard --unit-type scout --model bard_scout_dagger_raised --state attack
python generate_assets.py --skip-render
```

For every model entry selected by `--clan`/`--unit-type`/`--model`/`--state`
(all optional -- omit all four to process the ENTIRE roster), it walks the
full dependency chain top to bottom, and at each stage compares that
stage's own output file's mtime against every one of its input files'
mtimes -- if any input is newer, or the output doesn't exist yet, that
stage regenerates, which naturally makes every DOWNSTREAM stage stale too
on the very same run (a plain cascade, no separate bookkeeping/manifest):

```
clans/<clan>/_items/<item>.glb                          (raw item)
clans/<clan>/_models/<clan>_<unit_type>.glb              (raw base model)
        |  rig_base_models.py:
        |    1. Meshy rig() -> THROWAWAY base_mesh/_meshy_raw/..._rig_raw.glb
        |    2. decimate_for_meshy.py -> base_mesh/<clan>_<unit_type>_optimized.glb
        |    3. bind_meshy_rig.py -> binds Meshy's armature onto the optimized mesh
        v
clans/<clan>/<unit_type>/base_mesh/<clan>_<unit_type>_rigged.glb   (FINAL: optimized mesh + Meshy armature)
        |  attach_hand_item.py (+ item(s) above, per model_definitions.txt)
        v
clans/<clan>/<unit_type>/base_mesh/_models/<model_name>_final.glb
        |  meshy_animate.py:
        |    1. decimate_for_meshy.py -> ..._final_optimized.glb
        |    2. Meshy rig+text-to-motion+animate -> THROWAWAY
        |       base_mesh/_models/_meshy_raw/..._anim_<state>_meshy_raw.glb
        |    3. bind_meshy_rig.py -> binds Meshy's armature/animation onto the optimized mesh
        v
clans/<clan>/<unit_type>/anim_<state>/Meshy_AI_..._anim_<state>.glb  (FINAL: optimized mesh + Meshy armature/animation)
        |  render.py (render_core, already incremental)
        v
clans/<clan>/<unit_type>/anim_<state>/<direction>/NNNN.png
```

**IMPORTANT -- Meshy's own mesh output is a THROWAWAY placeholder, never
shipped:** Meshy's Rigging API has a hard ~200-250 triangle auto-decimation
ceiling on ANY upload (see MESH RESOLUTION note below) -- there is no way to
raise it. So instead of using Meshy's `rigged_character_glb_url` /
`animation_glb_url` mesh directly, this pipeline now: (1) still calls Meshy
to get its armature (skeleton) + animation data, saving that result to a
throwaway `_meshy_raw/` path; (2) separately Blender-decimates the SAME
source mesh down to a much higher, game-ready triangle budget (default
30,000, see `OPTIMIZED_TARGET_TRIANGLES` in `rig_base_models.py` /
`meshy_animate.py`) via `decimate_for_meshy.py`; (3) binds Meshy's
armature/animation onto that optimized mesh via the new
`utils/bind_meshy_rig.py` (reusing the optimized mesh's own vertex groups
when present, since it's a decimated descendant of the same skinned source,
falling back to Blender's automatic weights otherwise). The FINAL output
path at each stage is unchanged, so `attach_hand_item.py` and `render.py`
require no changes at all.

**In practice this means:** replace/update an ITEM `.glb`, re-run
`generate_assets.py` with no extra bookkeeping, and every model that
references that item (directly, or via a `model_definitions.txt` preset)
regenerates all the way through to freshly-rendered sprite frames.
Replace/update a BASE MODEL `.glb`, and every model built on that
`(clan, unit_type)` pair regenerates the same way. Already-up-to-date
stages are always a fast no-op skip -- safe to re-run `generate_assets.py`
as often as you like.

**`--force` is always SCOPED, never a standalone global switch:** it only
affects whatever `(clan, unit_type, model, state)` selection is already
narrowed by `--clan`/`--unit-type`/`--model`/`--state`. Within that
selection, every stage is treated as stale and regenerated regardless of
timestamps; outside the selection, nothing is touched. Examples:

| Command | Effect |
|---|---|
| `generate_assets.py --force` | regenerates the **entire roster** (no filters = full scope) -- expensive (real Meshy credits), rarely what you want |
| `generate_assets.py --clan bard --force` | regenerates all of bard's unit_types/models/anim states |
| `generate_assets.py --clan bard --unit-type scout --force` | regenerates all of bard/scout's models & anim states only |
| `generate_assets.py --clan bard --unit-type scout --state attack --force` | regenerates only bard/scout's `attack`-state pipeline; `idle`/`walk`/etc. for that same unit are untouched (normal timestamp logic) |
| `generate_assets.py --model bard_scout_dagger_raised --force` | regenerates only that one model's full pipeline across all its anim states |

Reasons you might still want `--force` even though the timestamp cascade
usually suffices: Meshy's own outputs are non-deterministic (rerolling a
Text-to-Motion result without touching any source file), or a file's mtime
doesn't reflect a real change (e.g. restored from backup/git with an old
timestamp preserved).

Other flags: `--skip-render` stops after the Meshy animate stage (skip
spending render time while iterating on attachment/animation);
`--mode swift` forwards a faster/cheaper Text-to-Motion mode to
`meshy_animate.py`; `--instructions PATH` / `--assets-root PATH` /
`--blender PATH` override the usual defaults.

### The 4 pipeline stages `generate_assets.py` drives

0. **`rig_base_models.py`** -- rigs the raw, unrigged
   `clans/<clan>/_models/<clan>_<unit_type>.glb` base models (confirmed,
   across all 120 files in this repo, to have zero skins/a single mesh
   node -- plain Meshy exports with no skeleton at all) via Meshy's real
   Rigging API. Meshy's own mesh output is a THROWAWAY placeholder (see
   the callout above) -- only its armature is kept, then bound (via the
   new `utils/bind_meshy_rig.py`) onto a Blender-decimated, game-ready
   mesh (`utils/decimate_for_meshy.py`, default 30,000 triangles) produced
   from the SAME raw base model. The result is written to
   `clans/<clan>/<unit_type>/base_mesh/<clan>_<unit_type>_rigged.glb` --
   the exact rig input `attach_hand_item.py batch` requires, unchanged.
   Also normalizes known filename typos in `_models/` on first scan (e.g.
   `bard_chieftan.glb` -> `bard_chieftain.glb`, `dwaf_embarked.glb` ->
   `dwarf_embarked.glb`, `elf_sout.glb` -> `elf_scout.glb`,
   `necromance_seeker.glb` -> `necromancer_seeker.glb`,
   `chaman_ranged.glb` -> `shaman_ranged.glb`) so every subsequent run
   resolves the canonical `<clan>_<unit_type>.glb` name directly. Now
   requires Blender to be discoverable (same `--blender`/`AEVUM_BLENDER`/
   PATH search order as `render.py`'s `find_blender()`). Can also be run
   standalone:
   ```
   python rig_base_models.py --dry-run
   python rig_base_models.py --clan bard --unit-type scout
   ```
1. **`attach_hand_item.py batch`** -- merges the rigged base mesh + item(s)
   per `model_definitions.txt` into
   `clans/<clan>/<unit_type>/base_mesh/_models/<model_name>_final.glb`,
   auto-validating (`utils/validate_glb.py`) and auto-previewing
   (`utils/preview_batch_items.py` / `utils/render_final_preview.py`) the
   result. Its own `--skip-decimate` flag (an ITEM-file-level safeguard --
   see `utils/decimate_items.py` below, keeping raw item source files'
   own triangle counts and repo size sane) is unrelated to Meshy's rig
   output resolution (see MESH RESOLUTION note below).
2. **`meshy_animate.py`** -- rigs the merged `_final.glb` directly
   (unmodified) via the real Meshy REST API, then animates it via
   Text-to-Motion + Animation. Meshy's own animated mesh output is a
   THROWAWAY placeholder (see the callout above) -- downloaded to a
   `_meshy_raw/` path, then bound (via `utils/bind_meshy_rig.py`) onto a
   Blender-decimated, game-ready mesh (`utils/decimate_for_meshy.py`,
   default 30,000 triangles, produced once per model and reused across all
   of its anim states) -- the FINAL result is written into each subject's
   `anim_<state>/` folder, same path/contract as before.
3. **`render.py`** (via `render_cli.py`) -- renders the final 6-direction
   sprite-frame PNGs, using its own already-incremental
   `RenderJob.needs_render()` check (safe to always invoke).

### MESH RESOLUTION note (real finding, this session)

Meshy's `/openapi/v1/rigging` endpoint returns a rigged character mesh at
a low, roughly-fixed resolution (~200-250 triangles / ~500-600 vertices)
**regardless of the input mesh's own triangle count** -- confirmed across
FOUR real test uploads this session: 10,131 tris -> 242; 4,127 tris -> 226;
1,200 tris (deliberately pre-decimated) -> 197; and the SAME 4,127-tri
mesh re-tested with NO pre-decimation at all -> 226 again. An earlier
version of this pipeline pre-decimated the merged/base mesh before every
rig() call, based on an initial (mistaken) theory that Meshy was silently
auto-decimating dense uploads as a fallback. That theory is now disproven
by the data above (decimating harder did not change the output
resolution at all), and the official Meshy API docs (docs.meshy.ai)
confirm no density-based decimation/quality parameter exists on this
endpoint (only a hard 300,000-face REJECT limit, far above anything this
pipeline uploads). **Conclusion: the low output resolution appears to be
Meshy's own standard auto-rigging topology for any input**, not a bug in
this pipeline and not something pre-decimation can influence -- the
pre-decimation step was reverted from both `meshy_animate.py` and
`rig_base_models.py`; both now upload their respective source meshes
directly, unmodified. Since this ceiling cannot be raised, the pipeline's
strategy shifted instead of trying to work around it: **Meshy's own
rigged/animated mesh is now always a throwaway placeholder**, used only to
extract its armature/animation, which is then bound (`utils/bind_meshy_rig.py`)
onto a separately Blender-decimated, much higher-resolution game-ready mesh
-- see the "IMPORTANT" callout near the top of this file.

### MESH BINDING note (real finding + fix, this session's live test)

A real live test of `rig_base_models.py --force` (real Meshy rig call +
real Blender bind) initially produced a broken final `.glb`: importing it
back showed the armature had degraded into plain Blender `EMPTY` objects
(not a real `ARMATURE`), and the glTF exporter had logged `"mesh_node has
no skin, skipping adding neutral bone data on it"`. Root-caused to TWO
independent real bugs, both now fixed in `bind_meshy_rig.py`:

1. **Coordinate-space mismatch**: the optimized mesh sits in a small,
   mesh-local unit-scale bounding box (observed Z in `[-0.5, 0.5]`), while
   Meshy's own rigged mesh/armature occupies real-world meters (observed Z
   in `[0, 1.7]`, matching the `rig()` call's `height_meters=1.7`) --
   totally non-overlapping spaces. Fixed by `_align_to_meshy_space()`,
   which rescales/repositions the optimized mesh to match Meshy's
   bounding-box height and X/Y/Z-bottom center before any binding is
   attempted.
2. **Meshy's own exported armature has corrupted bone TAIL positions**
   (observed: tails thousands of units away from their heads, unrelated to
   the actual mesh scale) -- this alone makes Blender's automatic
   bone-heat-weighting solver (`ARMATURE_AUTO`) fail for every bone
   regardless of coordinate alignment (`Bone Heat Weighting: failed to
   find solution for one or more bones`), leaving the mesh with zero real
   vertex weights, which the glTF exporter correctly drops as "no skin".
   Fixed by preferring a **Data Transfer** of Meshy's own real, WORKING
   per-vertex bone weights (present on Meshy's own throwaway mesh, which
   is how Meshy itself renders/animates it) onto the optimized mesh via a
   nearest-surface `DATA_TRANSFER` modifier, which only requires the two
   meshes to spatially overlap (fix 1, above) -- not a working bone
   hierarchy. `ARMATURE_AUTO` is retained only as a last-resort fallback
   if Data Transfer also somehow fails.

Confirmed working end-to-end after both fixes: a real `rig_base_models.py
--clan bard --unit-type scout --force` run produced a final
`bard_scout_rigged.glb` whose re-imported mesh has 24 vertex groups
matching the armature's 24 real bones, with 3952/3952 (100%) of its
vertices carrying a real nonzero weight, and the armature survives
export/re-import as a genuine `ARMATURE` object (not degraded to empties).
`bind_meshy_rig.py` now also refuses to export (raises instead) if no real
nonzero vertex weight is ever found, rather than silently shipping an
unskinned mesh again in the future.

### DELETE-THEN-REGENERATE (real robustness improvement, this session)

`generate_assets.py` now deletes each stale stage's own output file(s) --
and every downstream output cascading from them -- BEFORE regenerating,
rather than only comparing timestamps. This guarantees every file present
on disk after a run was genuinely (re)written by that run; if a
regeneration call then fails (e.g. a Meshy API error), the file is simply
left missing (clearly "not done yet" on the next run, which retries it
the same way as any other missing output) instead of silently leaving a
stale file in place. Deletion cascades are always scoped identically to
`--force` (see below) -- a `--state`-scoped run never deletes/touches
another state's outputs, nor another model's `_final.glb` that doesn't
even have the requested state.

## Layout

- `generate_assets.py` — **the single entry point**, directly at `scripts/`
  (see above); orchestrates the 4 pipeline-stage scripts under
  `main_scripts/` by calling into their own `main_with_args()`/`run()`/
  `run_batch()` functions per selected model entry, computing each stage's
  own staleness itself before deciding whether to invoke it.
- `main_scripts/` — the 4 individual pipeline-stage scripts
  `generate_assets.py` drives: `rig_base_models.py`, `attach_hand_item.py`,
  `meshy_animate.py`, `render.py`. Each is also fully runnable standalone
  (see each one's own `--help`/docstring) for manual iteration on a single
  stage without going through `generate_assets.py`.
- `model_definitions.txt` / `.meshy_cache.json` — batch instructions file
  and Meshy rig-cache, at `scripts/` alongside `generate_assets.py`, read/
  written by `generate_assets.py` and the scripts under `main_scripts/`.
- `utils/` — internal helper modules, invoked automatically by
  `main_scripts/` (or run standalone for one-off maintenance/QA — see each
  sub-section below). You normally never need to call anything here
  directly:
  - `meshy_client.py` — `MeshyClient` (rig/text-to-motion/animate REST
    calls + polling) and `download_glb()` (handles Meshy's occasional
    zipped downloads), shared by `meshy_animate.py` and
    `rig_base_models.py` so both use identical request/error-handling
    logic.
  - `decimate_items.py` — plain-Python (no `bpy`) triangle-budget
    enforcement for `clans/<clan>/_items/*.glb`, invoked automatically as
    the first step of `attach_hand_item.py batch`. **Hysteresis by
    design:** files are only decimated once they exceed
    `--threshold-triangles` (default 10000), and always down to
    `--target-triangles` (default 3000) — a wide gap between trigger and
    target, not a single shared number. This is what makes it safe to
    re-run (via every `batch` invocation) against files it has already
    downsampled: an already-processed item sits at ~3000 tris, nowhere
    near the 10000 trigger, so reruns are always a fast no-op skip and
    never re-lossify an already-decimated item. Delegates the actual mesh
    reduction (Blender's Decimate modifier, COLLAPSE type) to
    `decimate_for_meshy.py`. Standalone usage:
    ```
    python utils/decimate_items.py --dry-run
    python utils/decimate_items.py --clan bard
    ```
  - `decimate_for_meshy.py` — runs INSIDE Blender's own Python (`bpy`
    required); the actual Decimate-modifier worker shelled out to by
    `decimate_items.py` (plain item `.glb`s), and now also by
    `rig_base_models.py`/`meshy_animate.py` to produce the real, higher-
    resolution "optimized" game-ready mesh (default 30,000 triangles) that
    Meshy's armature/animation gets bound onto (see the "IMPORTANT" callout
    above).
  - `bind_meshy_rig.py` — **NEW**, runs INSIDE Blender's own Python (`bpy`
    required). Takes Meshy's rigged/animated `.glb` output (throwaway mesh
    + real armature/animation) and a separately Blender-optimized
    game-ready mesh, and binds Meshy's armature onto the optimized mesh
    instead of shipping Meshy's own mesh. Weight source, in priority order:
    (a) the optimized mesh's own vertex groups if it already has ones
    matching the armature's bone names (best fidelity, since it's a
    decimated descendant of the same skinned source); (b) **Data Transfer**
    of Meshy's OWN real per-vertex bone weights from its (temporarily kept,
    not immediately discarded) throwaway mesh onto the optimized mesh via a
    nearest-surface `DATA_TRANSFER` modifier -- confirmed this session as
    the fix that actually works, see MESH BINDING note below; (c) Blender's
    automatic weights (`ARMATURE_AUTO`) as a last resort if (b) also fails.
    Also aligns the optimized mesh's world-space bounding box into Meshy's
    own coordinate space first (`_align_to_meshy_space`) -- REQUIRED, since
    the two files were found this session to sit in totally different
    scales/origins. Validates real, nonzero vertex weights exist before
    exporting, raising instead of silently shipping an unskinned mesh.
    Invoked automatically by both `rig_base_models.py` and
    `meshy_animate.py`; standalone usage:
    ```
    blender --background --python utils/bind_meshy_rig.py -- ^
        --optimized <optimized_mesh>.glb --meshy-anim <meshy_raw>.glb --output <final>.glb
    ```
  - `preview_batch_items.py` — renders a one-shot QA preview PNG for every
    `model` block, invoked automatically after a successful non-dry-run
    `attach_hand_item.py batch` (disable via `--no-preview`).
  - `validate_glb.py` — dependency-free structural compliance checker for
    generated `.glb`s, invoked automatically by `attach_hand_item.py batch`
    right after each merge.
  - `render_final_preview.py` — one-shot single-PNG Blender render used by
    `preview_batch_items.py`.
  - `scaffold_dirs.py` — one-off directory scaffolding for a new
    clan/unit_type (see its own section below); run standalone/manually,
    not part of the automatic 3-script flow.
  - `mesh_discovery.py`, `render_config.py`, `render_core.py`,
    `render_cli.py`, `subjects/` — the render pipeline's own internals,
    described in detail below; `render_cli.py` is what `render.py` (the
    main script) actually invokes inside Blender.

- `render_config.py` — plain dataclasses (`AnimState`, `RenderJob`,
  `SubjectSpec`) and locked pipeline constants (directions, render size,
  camera pitch). No `bpy` dependency; safe to import/test with plain
  `python`. `RenderJob.needs_render()` is the incremental-rebuild check (see
  below).
- `mesh_discovery.py` — resolves which source `.glb` feeds which animation
  state per subject, by keyword-matching filenames under a subject's
  `base_mesh/**/*.glb` (recursive, any nesting depth). No `bpy` dependency.
  Meshy exports one `.glb` per animation clip with inconsistent names (e.g.
  `..._Animation_Walking_withSkin.glb`), so this avoids requiring a strict
  naming convention or a hand-maintained manifest per subject — drop new
  Meshy exports anywhere under `base_mesh/` and the script figures out which
  file is which state. Fallback chain per state: dedicated animated clip ->
  static textured mesh (filename contains `texture`/`withskin`/etc) -> plain
  base mesh -> `None` if nothing at all is found (reported as `no-mesh` and
  skipped, not an error — the subject just doesn't have a mesh yet). Any
  filename containing `_final` (case-insensitive) is excluded from the
  scan entirely — these are always `attach_hand_item.py`'s own generated
  outputs (e.g. `<clan>_<unit_type>_rigged_final.glb`), never genuine
  Meshy source content, so they must never be eligible as a resolved
  source mesh for any state (otherwise a hand-item-attached output sitting
  in `base_mesh/` could get picked up as the "source" for a *different*
  state's own attachment, silently double-attaching items).

  **Meshy-animated re-import:** `find_meshy_glb_in_anim_folder()` looks
  directly inside a subjects `anim_<state>/` folder (not recursive) for
  a `.glb` whose filename contains `meshy` (case-insensitive). This is
  used by `subjects/clans.py`s `build_specs()` as the HIGHEST-priority
  override for that state (above both the plain discovered clip and
  `attach_hand_item.py`s own `_final.glb` override) -- so the workflow
  is: attach an item to a unit ( attach_hand_item.py batch), animate
  the resulting `_final.glb` in Meshy, then drop Meshys own re-exported,
  now-animated `.glb` back into that states `anim_<state>/` folder, and
  it automatically becomes the render source for that states
  6-direction sprite frames.

  **Auto-unzip:** Meshy's per-animation downloads routinely arrive as
  `.zip` archives rather than loose `.glb` files. Any `*.zip` sitting
  directly in a subject's `base_mesh/` folder is automatically extracted
  (into a same-named subfolder) the next time the pipeline scans that
  subject, then the zip is deleted. **Just drop the downloaded zip straight
  into `base_mesh/` and re-run — no manual unzip step needed.** Already-
  extracted zips are skipped (idempotent, safe to leave old zips' target
  folders in place); a corrupt/unreadable zip is warned about and left
  untouched rather than crashing the whole plan.

  **Folder-name context:** Meshy names the `.glb` *inside* a downloaded zip
  after its own internal pose-library name (e.g.
  `Animation_Axe_Stance_withSkin.glb`), which often has no relation to what
  you actually downloaded it for. The *extracted folder* carries the real
  intent instead, since it's named after the zip (e.g. a zip downloaded for
  "meditate" extracts into a `..._meditate/` folder even though the `.glb`
  inside is called "Axe_Stance"). `classify_file()` therefore checks every
  folder name between `base_mesh/` and the file, not just the filename
  itself — with one deliberate exception: known companion files Meshy bundles
  into every zip alongside the real clip (currently just
  `..._Character_output.glb`) are matched by FILENAME ONLY, ignoring folder
  context entirely, so that companion file doesn't get mistaken for the
  actual dedicated clip of whichever state's folder it happens to sit in.
- `attach_hand_item.py` — no `bpy` dependency (reads/writes GLB containers
  directly, numpy only). Two subcommands:
    - `cylinder input.glb output.glb --hand {left,right,both}` — original
      behavior: attaches a placeholder cylinder "handle" proxy to a rigged
      A-pose humanoid GLB's hand joint(s), computing a grip frame from the
      hand's own skinned vertex geometry (works against Meshy's
      Mixamo-style `LeftHand`/`RightHand` joint naming).
    - `batch [--instructions PATH] [--dry-run] [--scale-multiplier N]
      [--skip-decimate] [--no-preview]` — attaches real item meshes per an
      instructions file (default `scripts/model_definitions.txt`; line 1 of
      that file MUST be `MESHY_API_KEY="msy_..."`, used by
      `meshy_animate.py`), one `model` block per attached-item variant of a
      unit. **First auto-decimates** any oversized source item `.glb`(s) in
      scope (`utils/decimate_items.py`, restricted to just the clan(s)
      referenced by the filtered entries — pass `--skip-decimate` to opt
      out; safe/fast to leave on by default thanks to that script's own
      hysteresis, see its `Layout` entry above), THEN attaches/merges:
      `--clan`/`--unit-type`/`--model` (each optional, combinable) restrict
      processing to matching model blocks only, e.g.
      `batch --clan bard --unit-type scout --model bard_scout_dagger_raised`,
      for iterating on a single model without editing the instructions
      file or re-processing every block (the automatic post-batch preview
      step is filtered the same way). `preview_batch_items.py` accepts the
      same three flags standalone. Block format:
      ```
      model <clan> <unit_type> <model_name> left:<item_name|none> [X:<deg> Y:<deg> Z:<deg>] [TX:<m> TY:<m> TZ:<m>] [S:<m>] right:<item_name|none> [X:<deg> Y:<deg> Z:<deg>] [TX:<m> TY:<m> TZ:<m>] [S:<m>] [--flip-left] [--flip-right]
          -- anim <state> anim_text: "<free-form text-to-motion prompt>"
          -- anim <state> anim_text: "<free-form text-to-motion prompt>"
      ```
      e.g.
      ```
      model bard scout bard_scout_dagger_raised right:dagger_raised left:none
          -- anim attack anim_text: "dagger stabbing"
          -- anim defend anim_text: "dagger parrying"
      ```
      Each `model` block is attached/merged EXACTLY ONCE, written to
      `clans/<clan>/<unit_type>/base_mesh/_models/<model_name>_final.glb`,
      then reused by `meshy_animate.py` (see below) for every one of its
      `-- anim <state> anim_text: "..."` lines — so multiple animation
      states sharing the same held-item pose only cost one Meshy rigging
      operation. Any `X:`/`Y:`/`Z:` token rotates (degrees, about the item's own
      grip-aligned local axes — local +Y is the elbow-to-hand grip axis)
      whichever hand's `left:`/`right:` token most recently preceded it on
      the line; defaults to no rotation if omitted. `TX:`/`TY:`/`TZ:`
      tokens (same stateful scanning) set the ROTATION PIVOT POINT in
      METERS (same grip-aligned axes), measured from the item's own
      detected handle end — needed because the hand JOINT's origin (what
      the handle end is placed at) sits at the WRIST, not out at the
      palm/fingers where a fist actually closes around a held grip, so
      rotating about the wrist (`TY:0`, the default) visibly swings the
      item's grip end away from the fist once `X:`/`Y:`/`Z:` is non-zero.
      Set `TY` to roughly the real-world wrist-to-grip distance (a small
      positive number, a few centimeters) so that point — not the wrist —
      stays fixed in place when rotated; defaults to `TX:0 TY:0 TZ:0`
      (pivot at the wrist, matching pre-rotation behavior) if omitted.
      `S:` (same stateful scanning) is a plain SCALAR slide in METERS,
      applied LAST, purely along the item's own grip/blade axis (one
      value, not X/Y/Z, since "slide along its own length" is inherently
      one-dimensional) — unlike `TX:`/`TY:`/`TZ:` (a no-op with no
      rotation), `S:` always moves the item, e.g. to push the handle
      further into the fist (typically negative) after `TY:` has already
      correctly pivoted a rotation but the handle still isn't fully seated
      in the grip; defaults to `S:0` (no change) if omitted.
      Items are attached via proper glTF skinning (rigidly weighted 100%
      to the hand joint, sharing the character's own skin/inverse-bind
      matrices) rather than plain node-parenting, so the output is
      portable to any spec-compliant glTF consumer (Blender, Meshy,
      three.js, Unity, Unreal, etc.) with no tool-specific correction
      needed — see `validate_glb.py` below and its module docstring for
      the interop bug this replaced. Additionally, after attaching,
      `merge_item_into_character_mesh()` MERGES the character and item
      into ONE mesh/material/UV map (a shared texture atlas per PBR
      channel, compositing the item's own texture into a small reserved,
      non-overlapping corner of the atlas, with both sides' UVs remapped
      accordingly) -- REQUIRED for Meshy specifically: Meshy silently
      merges all meshes into one on upload/re-rig, and two
      separately-UV-mapped meshes each spanning the full `[0,1]` range
      collide once merged (an overlapping UV island, which Meshy's own
      docs say breaks texture preservation) -- this is why an item could
      previously appear to inherit the character's texture (or vice
      versa) specifically AFTER re-rigging in Meshy, even though the
      file looked correct on raw import beforehand.
      `validate_glb.py`s `_check_meshy_merge_compliance()` enforces
      this: exactly one mesh-bearing scene node, referencing exactly one
      material. Blank lines and lines starting with `#` are ignored. For
      each non-`none` hand this resolves
      `clans/<clan>/<unit_type>/base_mesh/<clan>_<unit_type>_rigged.glb`
      as the rig and `clans/<clan>/_items/<item_name>.glb` as the item mesh,
      then writes the merged result to
      `clans/<clan>/<unit_type>/base_mesh/_models/<model_name>_final.glb`
      — the original rig file is never overwritten/touched (only this new
      per-model file — animation clips are handled separately, by
      `meshy_animate.py` below). The item mesh's
      geometry/materials/textures are merged in (not a placeholder), scaled
      relative to that character's own hand size (`--scale-multiplier`,
      default 1.3x the hand's bounding-box diagonal). Which end of the item
      is the "handle" (grip end) is auto-detected via PCA long-axis +
      cross-sectional-thickness heuristic (thinner end = handle); pass
      `--flip-left`/`--flip-right` (or `--flip` for both) on a line if the
      guess picks the wrong end for a given item.
      Every write also runs `repair_material_lighting_properties()`,
      which clamps `KHR_materials_specular` values to the spec-valid
      `[0.0, 1.0]` range (a real Meshy export was found authoring
      `[2.0, 2.0, 2.0]`, 200% reflectivity, which reads as washed-out/
      blown-out highlights in a standards-compliant PBR renderer) and
      zeros an unconditional `emissiveFactor: [1,1,1]` on the CHARACTER
      mesh specifically (confirmed not an intentional design choice) --
      both were present in the ORIGINAL untouched Meshy export, not
      introduced by this pipeline, but repaired here since they produce
      an incorrect washed-out/self-glowing look in external viewers.
- `meshy_animate.py` — no `bpy` dependency (plain `python` + `requests`).
  Drives the real Meshy REST API (https://docs.meshy.ai/en/api) to rig
  each `model` block from `model_definitions.txt` EXACTLY ONCE, then
  animate it for every one of that model's `-- anim <state> anim_text:
  "..."` lines via Text-to-Motion + Animation tasks:
  ```
  python meshy_animate.py --dry-run
  python meshy_animate.py --clan bard --unit-type scout
  python meshy_animate.py --model bard_scout_dagger_raised --mode swift
  python meshy_animate.py --force
  ```
  For each selected model: rigs its `_models/<model_name>_final.glb`
  (`POST /openapi/v1/rigging`, base64 data-URI upload), caching the
  resulting `rig_task_id` in `scripts/.meshy_cache.json` keyed by the
  source file's mtime so unchanged models aren't re-rigged on repeat runs
  (`--force` bypasses); then for each `(state, anim_text)` pair, creates a
  Text-to-Motion task (`POST /openapi/v1/text-to-motion`, duration derived
  from `render_config.ANIM_STATES[state]`'s frames/fps, clamped to Meshy's
  2–10s/0.5-step range), polls to completion, creates an Animation task
  (`POST /openapi/v1/animations` with `rig_task_id` + `motion_task_id`),
  polls again, and downloads the result (auto-unzipping if Meshy returns
  a `.zip`) into
  `clans/<clan>/<unit_type>/anim_<state>/Meshy_AI_<clan>_<unit_type>_anim_<state>.glb`
  — the `meshy` substring makes `mesh_discovery.find_meshy_glb_in_anim_folder()`
  automatically pick this up as that state's render source, with no
  further pipeline changes needed. The API key is read from line 1 of the
  instructions file (`MESHY_API_KEY="msy_..."`, via
  `attach_hand_item.read_api_key()`). Run
  `python attach_hand_item.py batch` first so each model's
  `_final.glb` exists before rigging it.
- `preview_batch_items.py` — no `bpy` dependency itself (plain-Python
  wrapper, same Blender-discovery approach as `render.py`). Renders a
  one-shot QA preview PNG for EVERY `model` block in an `attach_hand_item.py`
  instructions file, so you can eyeball a hand-item attachment before
  spending credits animating it:
  ```
  python utils/preview_batch_items.py
  python utils/preview_batch_items.py --dry-run
  ```
  For each model block it resolves the same output `.glb`
  `attach_hand_item.resolve_output_paths()` computes, skips (with a clear
  warning) any model whose `.glb` hasn't been generated yet via
  `attach_hand_item.py batch`, and otherwise invokes
  `render_final_preview.py` to write `<final_stem>_preview.png` right next
  to that `.glb` — e.g.
  `clans/bard/scout/base_mesh/_models/bard_scout_dagger_raised_final_preview.png`.
  Supports `--instructions`, `--blender`, and passthrough
  `--direction`/`--camera-pitch-deg`/`--render-size` flags.
  Both this tool and the main sprite pipeline (`render_core.run_job()`)
  now use `render_core.setup_world_ambient_lighting()` (a rig of several
  sun lamps from opposing angles, approximating shadow-free ambient
  light) and `setup_solid_black_background()` (opaque black, not
  transparent) instead of the old single directional sun lamp +
  transparent-PNG approach -- so a unit renders IDENTICALLY whether
  viewed as a pre-Meshy QA preview or as the actual post-animation
  sprite frames.
- `validate_glb.py` — no `bpy`, no third-party glTF library. Lightweight,
  dependency-free structural compliance checker run automatically at the
  end of every `attach_hand_item.py batch` write (failing the batch run,
  before the auto-preview step, if it finds errors) — also runnable
  standalone:
  ```
  python utils/validate_glb.py clans/bard/scout/base_mesh/bard_scout_rigged_final.glb
  python utils/validate_glb.py <path> --strict   # also fail on warnings
  ```
  Checks accessor/node/skin index validity, that `JOINTS_0`/`WEIGHTS_0`
  are present together with matching counts and weights summing to ~1.0,
  that `JOINTS_0` indexes correctly into a skin's `joints` list (not raw
  scene-node indices), and — the specific regression this tool exists to
  catch — that no `item_`-prefixed node is parented under another node
  (the old, non-portable "plain node parented under a hand joint"
  attachment pattern, which needed a Blender-specific import-time
  correction hack and was NOT interpreted correctly by Meshy's own glTF
  import, silently mispositioning the item and breaking Meshy's auto-fit
  camera framing). This is NOT a full glTF 2.0 spec conformance checker —
  for that, install Node.js and run the official
  `npm install -g gltf-validator` / `gltf-validator <file>` CLI, which
  this script's docstring also documents.
- `scaffold_dirs.py` — no `bpy` dependency. Creates (idempotently, via
  `mkdir(parents=True, exist_ok=True)` — never deletes/renames/touches
  existing files) the full `base_image/`, `base_mesh/`,
  `spritesheet/{image,json}/`, and `anim_<state>/<direction>/` folder tree
  for every `clans/<clan>/<unit_type>/`, per `blender.md` §2. Reuses
  `subjects/clans.py`'s `_states_for()` (the exact same per-unit_type/clan
  animation-state rules the render pipeline itself uses) as its single
  source of truth for which `anim_<state>` folders a given combination
  needs, so its output can never drift from what `render_cli.py` expects to
  render into. Run via:
  ```
  python utils/scaffold_dirs.py --dry-run
  python utils/scaffold_dirs.py --clan bard --unit-type scout
  python utils/scaffold_dirs.py            # all 12 clans x 10 unit_types
  ```
- `render_core.py` — Blender-side execution engine (`bpy`-dependent). Loads a
  mesh, sets up the fixed isometric camera + transparent render settings,
  steps through directions x frames, writes PNGs. **Direction is achieved by
  orbiting the CAMERA around the subject** (`position_camera_for_direction`),
  not by rotating the subject — the subject's own transform/animation is
  never touched. (An earlier version rotated the subject under a fixed
  camera; that was replaced because it risked interacting with whatever
  coordinate-correction rotation the glTF importer bakes onto the armature
  root — orbiting the camera sidesteps that entirely and produces the
  identical per-direction images, reverified with the arrow-marker test.)
  The per-direction camera-orbit base offset has been corrected TWICE this
  project: originally `-90` (naive), corrected to `-150` after real
  renders showed every direction one 60-degree step COUNTER-CLOCKWISE of
  what was requested, then reverted back to `-90` after a later real user
  report showed `-150` had every direction one 60-degree step CLOCKWISE
  instead (e.g. `sw` rendering `w`'s view, `se` rendering `sw`'s view) —
  `-90` is the currently-correct value; see `position_camera_for_direction`'s
  own comment in render_core.py for the full history.
  Camera framing uses a single **fixed `render_core.FIXED_ORTHO_SCALE`**
  shared by every clan subject/state (currently `2.7` — originally `4.5`,
  calibrated against the Crimson Shieldbearer pilot's `meditate` pose, a
  crouching lunge with an outstretched sword that clips at smaller scales,
  but lowered after re-measuring real rendered output across every subject
  with actual frames on disk: worst observed real fill was only ~53% of the
  frame at `4.5`, reported by user as "too small" — lowered to `3.0`
  (mapping that same worst case to ~80% fill with no clipping), then
  lowered again to `2.7` per a later "zoom in slightly" request, still
  comfortably above the `2.6` value observed to clip that same worst-case
  pose — see `FIXED_ORTHO_SCALE`'s own comment in render_core.py) rather
  than a per-job auto-calibrated zoom; a
  per-job/per-state dynamic zoom was tried and rejected because it made the
  same character visibly change size between its own animation states, and
  still clipped on tall/short poses the calibration's sampled frames didn't
  happen to catch. **Incremental by default**:
  `run_jobs` only re-renders a job when `RenderJob.needs_render()` is true —
  i.e. any expected output frame is missing, OR the job's resolved source
  mesh (or the pipeline scripts themselves, via
  `render_config.PIPELINE_SCRIPT_PATHS`) is newer than the oldest existing
  output frame. Jobs with no resolvable mesh are reported as `no-mesh` and
  skipped regardless of `--force`. Pass `--force` to ignore timestamps and
  re-render everything.
- `subjects/` — one module per asset category, each exposing
  `build_specs(assets_root, **filters) -> list[SubjectSpec]`. Each builder
  calls `mesh_discovery.discover_state_meshes()` per subject to populate
  `SubjectSpec.state_meshes` (state name -> resolved `.glb` or `None`):
  - `clans.py` — 12 clans x 10 unit_types, encodes the per-unit_type
    attack/bow/cast/defend/meditate rules from `blender.md` §3.
  - `dragons.py` — 8 colors x 4 growth stages, mood-based single-pose states
    plus idle/walk, 192px render size.
  - `monsters.py` — t1/t2/t3 tiers, idle/walk/attack/hit/death only,
    tier-based render size (64/80/96px).
  - `npc.py` — flat portrait/wander NPCs, idle/walk only.
- `render_cli.py` — the actual Blender entry point, **safe by default**: it
  only prints a plan (see below) unless you pass `--execute`. Must be run
  inside Blender's own Python (`blender --background --python
  render_cli.py -- <args>`) — normally you don't invoke this directly, use
  `render.py` below instead.
- `render.py` — **the command you actually run.** Plain-Python wrapper that
  finds Blender for you (checks `--blender <path>`, then the `AEVUM_BLENDER`
  env var, then `PATH`, then well-known
  `C:\Program Files\Blender Foundation\Blender <version>\blender.exe`
  install locations) and re-invokes it with the correct
  `--background --python render_cli.py --` incantation, forwarding every
  other flag you pass straight through to `render_cli.py`. Run via:

  ```
  cd assets/graphics/scripts/main_scripts
  python render.py --category clans --clan fighter --unit-type common
  ```

  (per this file's top-level convention, run from inside
  `scripts/main_scripts/` itself — path resolution is off each script's own
  file location, not cwd. From the repo root that's
  `python assets/graphics/scripts/main_scripts/render.py ...`.)

  That's the whole command — no need to type the Blender path or `--`
  yourself. If Blender isn't discoverable, `render.py` prints a clear error
  telling you to pass `--blender <path>` or set `AEVUM_BLENDER`, instead of
  a bare `FileNotFoundError` from `subprocess`.

  Confirmed working end-to-end this session against
  `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` (auto-
  discovered, not on `PATH`).

  ### The plan (default, no `--execute`)

  Running the command above with no `--execute` flag resolves every
  requested subject/state and prints a grouped, plain-English report —
  **nothing is rendered and nothing on disk is touched**:

  ```
  ---------------------------------------------------------------------------------------------------------------------
  fighter common (C:\Aevum\assets\graphics\clans\fighter\common\base_mesh, prefix 'Meshy_AI_Crimson_Shieldbearer_...'):
    'idle' will render from ...biped_Animation_Idle_02_withSkin.glb.
    'walk' will render from ...biped_Animation_Walking_withSkin.glb.
    'attack' will render from ...biped_Animation_Right_Hand_Sword_Slash_withSkin.glb.
    'death' will render from fallback ...0831045928_texture.glb.
    'defend' will render from ...biped_Animation_Block3_withSkin.glb.
    'meditate' will render from ...biped_Animation_Axe_Stance_withSkin.glb.

  6 to render, 0 up to date, 0 missing a source asset.
  Nothing rendered - re-run with --execute to render.
  ```

  A `----` separator line (sized to the header's own width) prints above
  every subject, so scanning a multi-subject/whole-clan run is easier — each
  subject's block is visually boxed off from the next. The header itself is
  the subject name plus its `base_mesh/` path plus the longest common
  filename prefix shared by every resolved mesh for that subject (Meshy's
  exports for one subject almost always share a long stem, e.g.
  `Meshy_AI_Crimson_Shieldbearer_...`), followed by one indented line per
  animation state showing only the distinguishing **suffix** of the resolved
  file, not the whole repeated prefix. A subject with no resolved meshes at
  all (nothing downloaded yet) just omits the prefix from its header.

  There is no `hit` animation state (removed - clan units currently only
  get idle/walk/attack-or-bow/cast/death/defend/meditate, per unit_type).

  Four short per-state phrasings:
  - `will render from <file>.` — no output yet, source mesh found.
  - `will re-render from <file> (<reason>).` — output exists but is stale;
    `<reason>` is either `source is Ns newer than the last render` (the
    actual mtime comparison) or `--force` when the flag forced it.
  - `up to date (<file>).` — output exists and is current; skipped.
  - `no source asset yet.` — nothing resolved for this state at all.

  ### Staleness is timestamp-based — use `--force` when timestamps lie

  `needs_render()` compares the resolved source mesh's mtime against the
  existing render's mtime (see `render_config.RenderJob.needs_render()`).
  This is usually right, but filesystem timestamps aren't always
  trustworthy: a `.glb` extracted from a zip can carry an embedded mtime
  from whenever Meshy generated it (which may be hours ahead of/behind the
  actual download time), a file copy can reset mtimes unexpectedly, or
  system clocks can simply be skewed. When that happens a mesh you know
  hasn't meaningfully changed can show `will re-render` forever, or
  conversely a mesh you know DID change can show `up to date`.

  **`--force` (with `--execute`) ignores timestamps entirely and re-renders
  everything selected, regardless of what `needs_render()` thinks:**

  ```
  python render.py --category clans --clan fighter --unit-type common --execute --force
  ```

  The plan preview also explains itself: a `will re-render` line always
  shows why (`source is 10649s newer than the last render`, or `--force` if
  you passed the flag), and whenever anything shows `up to date`, the plan
  prints a one-line reminder that staleness is timestamp-based and `--force`
  is the escape hatch if that ever looks wrong.

  `fallback <file>` (instead of a bare filename) calls out a shared/reused
  mesh explicitly, so a dedicated animated clip is visibly distinct from a
  state quietly falling back to the shared static mesh — without this it's
  impossible to tell from the plan alone whether a real Walking clip was
  found or every state fell back to the same texture mesh.

  (Plain ASCII hyphens rather than an em dash are used deliberately in these
  runtime messages — Windows consoles/`subprocess` pipes don't reliably agree
  on a text encoding, so non-ASCII punctuation in anything printed by
  render_cli.py risked mangling into garbled bytes depending on the host's
  active code page. `render.py`'s subprocess pipe is now also pinned to
  UTF-8 explicitly (`encoding="utf-8"` on `Popen`, `PYTHONIOENCODING=utf-8`
  in the child env) as defense in depth, but avoiding the character
  entirely in these specific strings was the simpler fix.)

  Three sentence forms, one per state:
  - `'<state>' asset doesn't exist yet - will be rendered.` — a source mesh
    was resolved and the output frames don't exist yet; running with
    `--execute` will render them.
  - `'<state>' asset is out of date — will be re-rendered.` — output frames
    exist but the source mesh (or the pipeline scripts themselves) changed
    since they were last rendered.
  - `'<state>' asset is up to date.` — output frames exist and are newer
    than the source mesh; nothing to do, this state is skipped.
  - `'<state>' asset doesn't exist yet.` (no "will be rendered") — no source
    `.glb` has been resolved for this state at all (no Meshy export dropped
    in `base_mesh/` yet); always skipped, even with `--force`, since there's
    nothing to render from.

  ### Actually rendering

  ```
  python render.py --category clans --clan fighter --unit-type common --execute
  ```

  Renders only the states whose sentence says "will be rendered"/"will be
  re-rendered" (prints the same plan first, then executes). Add `--force` to
  re-render everything selected regardless of timestamps:

  ```
  python render.py --category clans --clan fighter --unit-type common --execute --force
  ```

## Adding a new asset category

1. Create `subjects/<category>.py` with a `build_specs(assets_root, **filters)`
   function that returns `list[SubjectSpec]` (mesh path, output root, list of
   `AnimState`s from `render_config.ANIM_STATES` or category-specific ones).
2. Register it in `subjects/__init__.py`'s `CATEGORY_BUILDERS`.
3. Add matching `--<filter>` CLI flags in `render_cli.py` if the category
   needs its own filters (mirroring the `--clan`/`--color`/`--tier` pattern).

## Notes / open questions carried from the design docs

- Camera pitch (`render_config.CAMERA_PITCH_DEG`, default 30°) and render
  size (`render_config.RENDER_SIZE_PX`, now `512` for clan subjects — bumped
  up from an initial `128` pilot value) are the two most expensive things to
  change after a batch render —
  confirm before running a full batch (see ANIMATION_MATRIX §9). Also confirm
  it against whatever pitch/squash the terrain tile pipeline ends up using
  (terrain is currently flat/painted 2D art, not yet 3D-rendered, so there is
  no existing ground-truth projection angle to check against yet).
- **RESOLVED (fighter/common pilot, 08/30/2026):** a real Meshy export
  (`Crimson_Knight`) confirmed Meshy ships **one `.glb` per animation clip**
  (e.g. `..._Animation_Walking_withSkin.glb`, `..._Animation_Running_withSkin.glb`),
  plus separate untextured/textured base meshes — NOT one file with multiple
  named actions. `mesh_discovery.py` now resolves a source file per state by
  filename keyword instead of guessing at a shared action's frame range, and
  `SubjectSpec.state_meshes` / `RenderJob.mesh_path` carry a per-state
  resolved path (or `None`). Per your instruction, states with no dedicated
  animated clip (attack/hit/death/defend/meditate/etc, until those clips are
  authored) fall back to the `*_texture.glb` static mesh.
- `render_core.run_job`'s proportional frame-sampling (state's local frame
  index -> position in the loaded clip's frame range) is now actually
  correct, because `mesh_discovery.py` resolves one `.glb` per state — the
  loaded `action` is that state's own clip, not a shared multi-state action.
  The earlier version of this logic (before mesh_discovery.py existed) was
  flagged as likely-wrong for exactly this reason; that's resolved now.
  Blender 5.2 is installed on this machine and the CLI (via `render.py`) runs
  against it successfully headlessly — confirmed for plan/preview output.
  Actually executing a real `--execute` render of `clans/fighter/common ::
  walk` (to visually check the output frames) hasn't been done yet in this
  session and is the next concrete validation step.
- **Incremental rendering (this session's addition):** `render_cli.py`
  defaults to only rendering `RenderJob`s where `needs_render()` is true —
  comparing the resolved source mesh's mtime (and the pipeline scripts',
  via `render_config.PIPELINE_SCRIPT_PATHS`) against the existing output
  frames' mtimes. Missing frames always count as stale. `--force` bypasses
  the check entirely. The default (no `--execute`) plan output reports
  `RENDER` / `SKIP` / `NO-MESH` counts without rendering or touching bpy.
  Verified end-to-end against the real `clans/fighter/common` files now on
  disk (see git history / session log for the manual mtime-touch tests that
  confirmed both directions of the staleness check).
- **2x frame sampling (this session's addition):** every `AnimState` in
  `render_config.ANIM_STATES` (and dragons' own `idle`/`walk` in
  `subjects/dragons.py`) has both its `frames` and `fps` doubled versus the
  originally-authored `ANIMATION_MATRIX §2` values (e.g. idle 4/8fps ->
  8/16fps), so every animation is sampled at 2x density while keeping the
  same real-time playback duration (doubling frames alone without fps would
  have doubled duration instead). Dragons' single-frame mood poses
  (`frames=1`) are intentionally left alone. Re-rendering after this change
  requires `--force`-free re-run detecting the new frame counts as missing
  (verified against the `clans/fighter/common` pilot: 384 frames now, up
  from 192, all present and correctly sized).
- Most subjects still have no `base_mesh/*.glb` at all (only
  `clans/fighter/common` does, as of this session's pilot). The plan output
  reports these as "asset doesn't exist yet." (no source mesh at all, not
  "will be rendered") rather than erroring; `run_jobs`
  skips them the same way even without `--dry-run`. `render_core.import_mesh`
  will raise `FileNotFoundError` if `run_job` is ever called directly with a
  `None`/missing mesh path.
