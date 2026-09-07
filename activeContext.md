# Active Context

_Keep this file short. Update in place — do not let it grow into a changelog.
Full history lives in git log; full design lives in docs/ARCHITECTURE.md._

## Last changes
- Renamed `games/` -> `game_api/` (contains `isometric/` and `fps/`, each a
  reusable engine API layer, unchanged internally). Added a new, currently
  empty top-level `games/` folder for actual playable game projects that
  will consume `game_api/isometric/` or `game_api/fps/`.
- Updated all references to the old `games/isometric`, `games/fps` paths:
  `tools/run_tests.ps1`, `docs/ARCHITECTURE.md`, `docs/RESOURCE_SCHEMA.md`,
  `README.md`.
- Scaffolded monorepo: `core/` (shared `game_core` addon + headless test
  harness), `game_api/isometric/`, `game_api/fps/` — each an independent
  Godot 4 project.
- Installed GUT (unit test framework) in all 3 project roots; added smoke
  test suite for the `VirtueSystem` autoload.
- Verified end-to-end on this machine (pre-rename): Godot 4.7.2 found
  locally, all 3 GUT suites passed (12/12) via `tools/run_tests.ps1`;
  re-verification after the rename is the immediate next step.

## In progress
- Re-running Godot `--import` + `tools/run_tests.ps1` for the two moved
  project roots (`game_api/isometric`, `game_api/fps`) to confirm nothing
  broke from the path change.
- Awaiting two existing Python engine paths (isometric + FPS/3D) from the
  user so migration/audit can begin.

## Next planned
- Read + audit both Python codebases; sort logic into: (1) shared -> `core/`,
  (2) genre-specific -> the relevant `game_api/<engine>/`, (3) prototype
  cruft not worth porting.
- Propose a concrete file-by-file migration mapping for review before
  writing any ported code.
- Port shared logic (virtue system, world-state graph, dialogue, AI
  heuristics) into `core/addons/game_core/managers/` (GDScript).
- Port genre-specific logic into `game_api/isometric/scripts/` and
  `game_api/fps/scripts/`.
- Decide + implement the real linking mechanism for
  `game_api/*/addons/game_core` and `game_api/*/data` (currently plain
  file copies as a placeholder; user intends to handle this personally).
- Start the first real game project under `games/` once an engine API
  layer is far enough along to build on.
