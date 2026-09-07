# Architecture

## Overview

This repository is a single monorepo containing a shared, engine-agnostic
gameplay foundation ("core") and two independent Godot game projects that
each provide their own rendering/gameplay front end on top of that
foundation:

- `games/isometric/` — turn-based / grid-based isometric game
- `games/fps/` — first-person 3D game

Both games share the exact same resource tree (tokens, units, items,
virtues, lore) and the exact same gameplay-logic managers (virtue system,
world-state/consequence graph, dialogue system, AI heuristics). Only the
rendering, input, and genre-specific mechanics differ between them.

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
├── games/
│   ├── isometric/                # Godot project #1 (has its own project.godot)
│   │   ├── addons/game_core       # copy/link of core/addons/game_core
│   │   ├── addons/gut             # test framework, own copy per project
│   │   ├── data                   # copy/link of core/data
│   │   ├── scenes/, scripts/      # isometric-only logic
│   │   └── tests/unit/            # GUT tests for isometric-only logic
│   │
│   └── fps/                       # Godot project #2, same shape as isometric/
│
├── docs/                         # this file + RESOURCE_SCHEMA.md
├── tools/run_tests.ps1           # runs GUT across all three project roots
└── README.md
```

## The `games/` directory is extensible

`games/` is the container for the base/root of every individual game
project built on top of `core/`. It currently holds `isometric/` and
`fps/`, but it is not hard-capped at two — new games are added the same
way, as `games/<new-game-name>/` with its own `project.godot`, own
`addons/game_core` + `data` (linked/copied from `core/`), own
`scenes/`/`scripts/`, and own `tests/unit/`. Each game folder is an
independent Godot project and can be worked on (or run as its own task)
without affecting the others, as long as it stays on the shared `core/`
contract documented in `docs/RESOURCE_SCHEMA.md`.

## Why three separate Godot project roots?

Godot projects are self-contained (`project.godot` marks the project root).
There is no supported way to have one Godot project transparently include
scenes/scripts from a sibling folder outside its own root. So "one shared
core, two games" is implemented as three project roots (`core`, `isometric`,
`fps`), where `core` is a minimal *headless test harness* — not a playable
game — used purely to run the shared addon's own test suite in isolation.

## How `core/` reaches each game

Each game project needs `core/addons/game_core` and `core/data` present
inside its own project root (Godot cannot resolve `res://` paths outside
the project root). Two mechanisms are possible:

1. **Symlink/junction** (preferred long-term): a directory junction/symlink
   at `games/<game>/addons/game_core` -> `core/addons/game_core` (and same
   for `data`), created locally by a bootstrap step, **never committed to
   git as a real symlink** (Windows git symlink support is inconsistent
   without Developer Mode / `core.symlinks=true`).
2. **Plain copy** (current placeholder state of this repo): the folders are
   physically duplicated into each game project. This is simple and always
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

Each front end (isometric, fps) only reacts to these managers' **signals**
and calls their **public API** — the core never references game-specific
scene nodes, cameras, or renderers directly. This keeps the core reusable
without either game leaking into it.

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
- Use `git worktree` if working on core and a game simultaneously without
  repeatedly switching branches in the same folder.
- Tag core milestones (`core-v0.1.0`, etc.) and log breaking changes to the
  shared managers/schema in a changelog before bumping either game onto a
  newer core state.

## Python migration tooling

`core/tools/migrate_isometric_python/` and `core/tools/migrate_fps_python/`
are placeholders for importer scripts that will read the existing Python
prototypes (isometric and FPS/3D) once their paths are provided, and help
sort logic into: (1) shared -> `core/`, (2) genre-specific -> the relevant
`games/<game>/`, (3) prototype-only cruft that does not get ported.
