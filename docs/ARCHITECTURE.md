# Architecture

## Overview

This repository is a single monorepo containing a shared, engine-agnostic
gameplay foundation ("core"), two independent Godot **engine API layers**
that each provide their own rendering/gameplay front end on top of that
foundation, and a home for the actual playable games built with them:

- `game_api/isometric/` — turn-based / grid-based isometric engine API
- `game_api/fps/` — first-person 3D engine API
- `games/` — actual playable game projects, each consuming one of the
  `game_api/<engine>/` layers above (currently empty, awaiting the first
  real game)

Both engine API layers share the exact same resource tree (tokens, units,
items, virtues, lore) and the exact same gameplay-logic managers (virtue
system, world-state/consequence graph, dialogue system, AI heuristics).
Only the rendering, input, and genre-specific mechanics differ between
them.

## Directory layout

```
game_engine_godot/
├── core/                        # shared, engine-agnostic platform
│   ├── addons/
│   │   ├── game_core/           # THE PLATFORM (see docs/API.md)
│   │   │   ├── core_context.gd          # autoload: the engine seam
│   │   │   ├── core_engine_adapter.gd   # base class each engine extends
│   │   │   ├── data/                    # CoreDataLoader
│   │   │   ├── schema/                  # CoreDefinition + subclasses
│   │   │   ├── gameplay/                # CoreStats, CoreInventory, intel
│   │   │   └── managers/                # CoreRegistry, CoreIntel, ...
│   │   └── gut/                 # test framework (GUT)
│   ├── data/                    # shared resource instances (.tres/.json)
│   └── tests/unit/              # GUT tests for the platform in isolation
│
├── game_api/
│   ├── isometric/                # Godot project #1 — 2D hex/iso engine
│   │   ├── addons/game_core       # synced copy of core/addons/game_core
│   │   ├── autoloads/             # the iso engine's own singletons
│   │   ├── framework/             # grid/ world/ entities/ intel/ sites/ ...
│   │   ├── scripts/               # IsoEngineAdapter + iso-only glue
│   │   ├── scenes/ assets/ schemas/ tools/ docs/ games/
│   │   ├── project.godot          # active project config
│   │   └── project.reference.godot# original upstream config, for diffing
│   │
│   └── fps/                       # Godot project #2 — 3D first-person engine
│       ├── framework/             # actor/ combat/ items/ map/ poi/ ...
│       ├── scripts/               # FpsEngineAdapter + fps-only glue
│       └── (same shape as isometric/)
│
├── games/                        # actual playable game projects (empty for now)
│
├── docs/                         # API.md, ARCHITECTURE.md, RESOURCE_SCHEMA.md
├── tools/run_tests.ps1           # runs GUT across all three project roots
├── tools/sync_core.ps1           # propagates core/ into both engine layers
└── README.md
```

## Provenance of the two engines

Both engine API layers were imported from existing, working Godot 4 projects:

| Layer | Imported from | Upstream name |
|---|---|---|
| `game_api/fps/` | `C:\game_engine` | IntelForge Engine (Forward+, 3D) |
| `game_api/isometric/` | `C:\game_engine_iso` | IntelForge Iso Engine (Mobile, 2D) |

They share a common ancestor — several files were byte-identical on import —
which is exactly why a single shared platform is viable. Where the two
diverged, the isometric implementation was almost always the richer superset
(turn-based decay, provenance chains, secrecy/spread/trade on intel), so the
core adopted it and folded the FPS variants in as field aliases.

## `game_api/` vs `games/`

- **`game_api/`** holds the engine-specific API layers — `isometric/` and
  `fps/` — each a Godot project that wraps the shared `core/` foundation
  with a genre-specific rendering/gameplay front end (grid movement and
  turn logic for isometric; first-person controller, hitscan, navmesh AI
  for fps). Think of each as a reusable engine/API, not a shippable game
  by itself.
- **`games/`** holds the actual playable game projects you build. Each
  game here is its own Godot project that consumes one of the
  `game_api/<engine>/` layers (and, through it, the shared `core/`
  managers and resource schema). This directory starts empty and grows
  as real games are started; it is not hard-capped to any number of
  games.

## Why three separate Godot project roots (so far)?

Godot projects are self-contained (`project.godot` marks the project root).
There is no supported way to have one Godot project transparently include
scenes/scripts from a sibling folder outside its own root. So "one shared
core, two engine API layers" is implemented as three project roots
(`core`, `game_api/isometric`, `game_api/fps`), where `core` is a minimal
*headless test harness* — not a playable game — used purely to run the
shared addon's own test suite in isolation. Actual games added under
`games/` will become additional project roots of their own.

## How `core/` reaches each engine API layer (and, later, each game)

Each consuming project needs `core/addons/game_core` and `core/data`
present inside its own project root (Godot cannot resolve `res://` paths
outside the project root). Two mechanisms are possible:

1. **Symlink/junction** (preferred long-term): a directory junction/symlink
   at `game_api/<engine>/addons/game_core` -> `core/addons/game_core` (and
   same for `data`), created locally by a bootstrap step, **never committed
   to git as a real symlink** (Windows git symlink support is inconsistent
   without Developer Mode / `core.symlinks=true`).
2. **Plain copy** (current placeholder state of this repo): the folders are
   physically duplicated into each project. This is simple and always
   works, but requires manually re-copying after every `core/` change until
   a sync step or the linking mechanism above is put in place.

> **Status as of this scaffold**: option 2 (plain copy) is in place so the
> projects are immediately runnable/testable. The actual linking mechanism
> is intentionally left to be set up separately.

## The engine seam

This is the load-bearing idea of the whole platform.

Core code must never know whether it is running in a 2D hex grid or a 3D
first-person world. So every engine-dependent question — *what time is it? how
far apart are these? who can see whom? who owns this site?* — is asked through
a single interface, `CoreEngineAdapter`, reached via the `CoreContext`
autoload:

```gdscript
# in the graphics engine's boot scene, exactly once (scenes/main.gd):
CoreContext.install(IsoEngineAdapter.new())   # or FpsEngineAdapter.new()
```

Each engine's `GameManager.load_game()` then feeds the shared registry from the
same package it loads for itself:

```gdscript
CoreContext.configure(cfg)          # rules + deterministic seed
CoreRegistry.load_package(base)     # items, units, intel, factions
```

The FPS engine names its unit file `actors.json`, so it re-points the shared
`units` type at that file rather than renaming anyone's data.

`CoreEngineAdapter`'s default implementation is fully functional and headless,
so the platform and its tests run with **no graphics engine present at all** —
which is precisely what `core/` does as a test harness.

The two live implementations answer the same questions differently:

| Question | Isometric | FPS |
|---|---|---|
| `now()` | turn number | game seconds |
| `distance(a, b)` | hex/iso tiles (`Vector2i`) | metres (`Vector3`) |
| `can_see()` | sight stat vs tile distance | `Perception` raycast |
| `stance()` | faction diplomacy | player reputation |
| `reveal()` | clears fog of war | flags maps/POIs discovered |

Because time is *whatever unit the host engine reports*, an intel token's
`decay_turns: 10` means ten turns in the iso engine and ten seconds of game
time in the FPS engine. Core logic only ever subtracts and compares, so it
never needs to know.

See `docs/API.md` for the full adapter contract.

## Legacy managers (autoloads)

Registered as autoload singletons (see each project's `project.godot`
`[autoload]` section) so game-specific code calls them exactly like any
other Godot singleton:

| Autoload             | Responsibility                                    |
|-----------------------|---------------------------------------------------|
| `VirtueSystem`        | Player/NPC virtue & morality values + signals      |
| `WorldStateManager`   | Shared world-state / consequence fact graph        |
| `DialogueManager`     | Branching dialogue/conversation state              |
| `AIHeuristicManager`  | Shared AI influence-map / heuristic decision logic |

Each engine API layer (isometric, fps) only reacts to these managers'
**signals** and calls their **public API** — the core never references
game-specific scene nodes, cameras, or renderers directly. This keeps the
core reusable without either layer (or any game built on them) leaking
into it.

## Resource schema (data contract)

See `docs/RESOURCE_SCHEMA.md`. The `.gd` classes in
`core/addons/game_core/schema/` define the *shape* of shared data
(`UnitDefinition`, `ItemDefinition`, `TokenDefinition`, `VirtueDefinition`,
`WorldFact`); the actual `.tres`/`.json` instances live in `core/data/`.

## Testing strategy

See `docs/RESOURCE_SCHEMA.md` for the data contract and the root
`README.md` "Testing" section for the day-to-day workflow. In short: GUT
runs three times (once per project root) via `tools/run_tests.ps1`; `main`
should only ever contain a state where all three suites are green.

## Branching / workflow

- `main` — always green (all three GUT suites pass).
- Short-lived task branches: `core/<topic>`, `iso/<topic>`, `fps/<topic>`.
- Squash-merge into `main` once a task's branch passes `tools/run_tests.ps1`.
- Use `git worktree` if working on core and an engine API layer (or a game)
  simultaneously without repeatedly switching branches in the same folder.
- Tag core milestones (`core-v0.1.0`, etc.) and log breaking changes to the
  shared managers/schema in a changelog before bumping either engine API
  layer (or any game consuming them) onto a newer core state.

## Verifying the wiring

Unit tests exercise the platform in isolation; two headless runs prove it is
actually live inside each engine (adapter installed, core clock tracking the
engine clock, real package loaded into `CoreRegistry`). Both are run
automatically by `tools/run_tests.ps1`:

```powershell
godot --headless --path game_api/isometric -- --smoke        # full engine smoke suite
godot --headless --path game_api/fps       -- --boot-check   # platform wiring check
```

## Migration status

The two upstream engines were imported wholesale and still contain their own
copies of classes the platform now owns (`ItemDefinition`, `IntelToken`,
`CharacterStats`/`Stats`, `Inventory`, `IntelQuery`). Those duplicates are
intentionally left in place for now so both projects keep working; they are
being retired one subsystem at a time in favour of the `Core*` equivalents,
keeping all three test suites green at every step. See `activeContext.md` for
the current stopping point.
