# games/

This directory is for **actual playable game projects** — the concrete
games you build and ship, as opposed to `game_api/`, which holds the
engine-specific API layers (`game_api/isometric/`, `game_api/fps/`) that
those games consume.

Each game placed here should be its own Godot project (own `project.godot`)
that pulls in whichever `game_api/<engine>/` layer fits its genre (and,
through that layer, the shared `core/` gameplay foundation — virtue
system, world-state manager, dialogue manager, AI heuristics, and the
shared token/unit/item/virtue/world-fact resource schema).

This folder is currently empty and awaiting the first real game project.

See `docs/ARCHITECTURE.md` for the full repository layout and the
distinction between `core/`, `game_api/`, and `games/`.
