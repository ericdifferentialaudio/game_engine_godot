# Active Context

_Keep this file short. Update in place — do not let it grow into a changelog.
Full history lives in git log; full design lives in docs/ARCHITECTURE.md._

## Last changes
- Scaffolded monorepo: `core/` (shared `game_core` addon + headless test harness),
  `games/isometric/`, `games/fps/` — each an independent Godot 4 project.
- Installed GUT (unit test framework) in all 3 project roots; added smoke test
  suite for the `VirtueSystem` autoload.
- Verified end-to-end on this machine: Godot 4.7.2 found locally, all 3 GUT
  suites pass (12/12) via `tools/run_tests.ps1`.
- Added Godot executable auto-discovery to `tools/run_tests.ps1`
  (`-GodotPath` -> `$env:GODOT_BIN` -> PATH -> Downloads fallback).
- Confirmed `games/` is an extensible directory: each subfolder (`isometric`,
  `fps`, and any future game) is the independent root of one game project,
  all consuming the same shared `core/`.

## In progress
- Awaiting two existing Python engine paths (isometric + FPS/3D) from the
  user so migration/audit can begin.

## Next planned
- Read + audit both Python codebases; sort logic into: (1) shared -> `core/`,
  (2) genre-specific -> the relevant `games/<game>/`, (3) prototype cruft
  not worth porting.
- Propose a concrete file-by-file migration mapping for review before
  writing any ported code.
- Port shared logic (virtue system, world-state graph, dialogue, AI
  heuristics) into `core/addons/game_core/managers/` (GDScript).
- Port genre-specific logic into `games/isometric/scripts/` and
  `games/fps/scripts/`.
- Decide + implement the real linking mechanism for
  `games/*/addons/game_core` and `games/*/data` (currently plain file
  copies as a placeholder; user intends to handle this personally).
