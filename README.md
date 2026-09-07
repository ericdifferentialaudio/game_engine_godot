# game_engine_godot

A Godot Engine project repository.

## Getting Started

1. Install [Godot Engine](https://godotengine.org/download) (version 4.x recommended).
2. Clone this repository:
   ```
   git clone https://github.com/ericdifferentialaudio/game_engine_godot.git
   ```
3. Open either game in Godot via the Project Manager, pointing at:
   - `games/isometric/project.godot`
   - `games/fps/project.godot`

   `core/project.godot` is a minimal headless test harness for the shared
   addon and is not meant to be opened as a playable game.

## Repository Structure

This is a monorepo containing a shared, engine-agnostic gameplay
foundation and two independent Godot game projects built on top of it.
See `docs/ARCHITECTURE.md` for the full breakdown and `docs/RESOURCE_SCHEMA.md`
for the shared token/unit/item/virtue/world-fact data contract.

```
core/            shared addon (game_core), shared resource data, test harness
games/isometric/ isometric game (own Godot project)
games/fps/       first-person 3D game (own Godot project)
docs/            architecture + schema documentation
tools/           repo-wide tooling (e.g. run_tests.ps1)
```

## Testing

Each of the three project roots (`core/`, `games/isometric/`, `games/fps/`)
has its own copy of [GUT](https://github.com/bitwes/Gut) installed as an
addon and its own `.gutconfig.json`. Run the entire suite across all three
with:

```
./tools/run_tests.ps1
```

(Requires a Godot 4.x executable on PATH as `godot`, or pass
`-GodotPath "C:\path\to\Godot.exe"`.) `main` should only ever be in a
state where all three suites pass.

## Workflow

- `main` stays green (tests pass, both games open cleanly).
- Work happens on short-lived branches named by scope, e.g. `core/virtue-system`,
  `iso/grid-movement`, `fps/hitscan-weapon`; squash-merge into `main` when done.
- Use `git worktree add` if you need to work on the core and a game
  simultaneously without switching branches back and forth in one folder.
- Core milestones are tagged (`core-v0.1.0`, etc.); breaking changes to the
  shared managers or resource schema should be called out explicitly so
  both games can be updated deliberately.

## Contributing

Feel free to open issues or submit pull requests.

## License

TBD.
