# game_engine_godot

A Godot Engine project repository.

## Getting Started

1. Install [Godot Engine](https://godotengine.org/download) (version 4.x recommended).
2. Clone this repository:
   ```
   git clone https://github.com/ericdifferentialaudio/game_engine_godot.git
   ```
3. Open an engine API layer in Godot via the Project Manager, pointing at:
   - `game_api/isometric/project.godot`
   - `game_api/fps/project.godot`

   `core/project.godot` is a minimal headless test harness for the shared
   addon and is not meant to be opened as a playable game.

## Repository Structure

A game engine platform: **one set of game mechanics, two graphics engines.**

```
core/               the shared platform (game_core addon) + headless harness
game_api/isometric/ 2D hex/isometric engine API layer (own Godot project)
game_api/fps/       3D first-person engine API layer (own Godot project)
games/              actual playable game projects (empty for now)
docs/               API.md · ARCHITECTURE.md · RESOURCE_SCHEMA.md
tools/              run_tests.ps1, sync_core.ps1
```

`core/addons/game_core/` owns everything a game needs that is not graphics:
units, items, NPCs, monsters, factions, stats, inventory, and a deep
information/"intel" system (reliability, corroboration, provenance, decay,
contradiction, spread and trade). It is reached entirely through documented
API calls and never references either graphics engine.

Each engine plugs in by installing one adapter:

```gdscript
CoreContext.install(IsoEngineAdapter.new())   # or FpsEngineAdapter.new()
```

**Start with [`docs/API.md`](docs/API.md)** — it documents every public call.
`docs/ARCHITECTURE.md` explains the layering and the engine seam.

## Keeping the core in sync

Godot cannot resolve `res://` outside a project root, so the shared addon is
physically copied into each engine layer. After any edit under
`core/addons/game_core/`:

```powershell
./tools/sync_core.ps1            # propagate
./tools/sync_core.ps1 -Check     # verify only (non-zero exit if stale)
```

## Testing

Each of the three project roots (`core/`, `game_api/isometric/`,
`game_api/fps/`) has its own copy of [GUT](https://github.com/bitwes/Gut)
installed as an addon and its own `.gutconfig.json`. Run the entire suite
across all three with:

```
./tools/run_tests.ps1
```

(Requires a Godot 4.x executable on PATH as `godot`, or pass
`-GodotPath "C:\path\to\Godot.exe"`.) `main` should only ever be in a
state where all three suites pass.

## Workflow

- `main` stays green (tests pass, both engine API layers open cleanly).
- Work happens on short-lived branches named by scope, e.g. `core/virtue-system`,
  `iso/grid-movement`, `fps/hitscan-weapon`; squash-merge into `main` when done.
- Use `git worktree add` if you need to work on the core and an engine API
  layer (or a game) simultaneously without switching branches back and
  forth in one folder.
- Core milestones are tagged (`core-v0.1.0`, etc.); breaking changes to the
  shared managers or resource schema should be called out explicitly so
  both engine API layers (and any games consuming them) can be updated
  deliberately.

## Contributing

Feel free to open issues or submit pull requests.

## License

TBD.
