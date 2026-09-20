# Assets

**This repository is text.** Code, data, design documents, and the small
vendored tools the build needs. Generated art is not committed.

## Why

`games/aevum/graphics/` held **3.0 GB across 3,254 files** — about **99.8%** of
the repository, against roughly **3.5 MB** of everything a human actually
reads or reviews. Binary art is a poor fit for git:

- it is never diffed, so history adds nothing but weight
- it churns on every regeneration, so each pass writes a fresh copy forever
- it made the repo exceed GitHub's **2 GB per-push limit**, so nothing could
  be pushed at all
- every clone, fetch and CI checkout pays for it, permanently

Removing it took the repository from ~2.5 GB to a few megabytes.

## Where the art actually is

Still on disk, exactly where it always was — `.gitignore` stops git tracking
it, it does not delete anything:

```
games/aevum/graphics/
  clans/  clan_icons/  dragons/  egg/  flags/  icons/  monsters/
  monster_lairs/  npc/  roads/  settlements/  shrines/  terrain/  ui/
```

Back this up somewhere that suits binaries — an external drive, object
storage, or Git LFS if you later want it versioned properly.

## Regenerating it

Aevum's art is AI-generated and reproducible from the specs in the repo:

| Source | What it is |
|---|---|
| `games/aevum/docs/art_spec.md` | the prompt and style guide (Nano Banana / Stable Diffusion / Midjourney) |
| `games/aevum/graphics/terrain/scripts/hexagon_cropper.py` | crops renders to hex tiles |
| `games/aevum/docs/ASSET_PLAN.md`, `docs/ASSET_PLAN.md` | what needs to exist |

Because the *specification* is committed and the *output* is not, the art can
always be rebuilt. That is the right split: the spec is reviewable, the output
is derived.

## What is still tracked, and why

| Path | Size | Why it stays |
|---|---|---|
| `tools/inklecate/` | 57 MB | The Ink compiler. The narrative platform depends on it, and a fresh clone must be able to rebuild `.ink` → `.ink.json` without hunting down a download. |
| `core/addons/gut/**.png` | ~1.7 MB | Test-framework UI icons, vendored with the addon. |
| `game_api/isometric/assets/**` | <1 MB | Small placeholder SVGs used by scenes. |

`.ink.json` outputs are committed too, so a clone can *run* the narrative even
without recompiling.

## Adding new art

Do not commit it. `.gitignore` already covers `games/*/graphics/` and the usual
binary formats (`.glb`, `.gltf`, `.fbx`, `.blend`, `.psd`, `.tga`, `.exr`).

If you need a new asset location tracked as text-adjacent — a small `.svg`
placeholder, say — it will be picked up normally. If you find yourself wanting
to commit something large, that is the signal to reach for Git LFS or an asset
store instead.

## If you want versioned binaries later

Git LFS is the standard answer:

```powershell
git lfs install
git lfs track "*.glb" "*.png"
git add .gitattributes
```

LFS keeps pointers in git and blobs on a separate server, so clones stay small
while the art stays versioned. Worth doing when the art stabilises; premature
while it is still being regenerated wholesale.
