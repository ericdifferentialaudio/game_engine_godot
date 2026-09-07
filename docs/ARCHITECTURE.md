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
│   │   ├── game_core/           # the shared addon (managers + schema)
│   │   └── gut/                 # test framework (GUT)
│   ├── data/                    # the actual shared resource tree (.tres/.json)
│   ├── tools/                   # Python migration/authoring tooling (not runtime)
│   └── tests/unit/              # GUT tests for the shared addon in isolation
│
├── game_api/
│   ├── isometric/                # Godot project #1 (has its own project.godot)
│   │   ├── addons/game_core       # copy/link of core/addons/game_core
│   │   ├── addons/gut             # test framework, own copy per project
│   │   ├── data                   # copy/link of core/data
│   │   ├── scenes/, scripts/      # isometric-only logic
│   │   └── tests/unit/            # GUT tests for isometric-only logic
│   │
│   └── fps/                       # Godot project #2, same shape as isometric/
│
├── games/                        # actual playable game projects (empty for now)
│
├── docs/                         # this file + RESOURCE_SCHEMA.md
├── tools/run_tests.ps1           # runs GUT across all three project roots
└── README.md
```

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

## Shared managers (autoloads)

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

## Python migration tooling

`core/tools/migrate_isometric_python/` and `core/tools/migrate_fps_python/`
are placeholders for importer scripts that will read the existing Python
prototypes (isometric and FPS/3D) once their paths are provided, and help
sort logic into: (1) shared -> `core/`, (2) genre-specific -> the relevant
`game_api/<engine>/`, (3) prototype-only cruft that does not get ported.
