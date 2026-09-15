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

Because Godot cannot resolve `res://` outside a project root, a game here is
the **authoritative source** and is copied into its engine layer to run:

```powershell
./tools/sync_game.ps1 -Game <id>            # -> game_api/fps/games/<id>
godot --path game_api/fps -- --game=<id>
```

## Games

| Game | Engine | Notes |
|---|---|---|
| [`hollow_ledger/`](hollow_ledger/README.md) | isometric | Debt-auditing RPG: Weight as a *graph of obligations between named parties*, not a morality meter. Four resolutions (repaid/forgiven/forced/sold) leave different traces on the town. Scaffolded 2026-09-12 from `docs/CONCEPT.md`; needs an Opus architecture pass. Graphics: diegetic data overlay — see `docs/ASSET_MANIFEST.md`. |
| [`chorus/`](chorus/README.md) | isometric | Investigation game where *truth itself is the contested resource*: record/soften/sharpen testimony, and the city visibly becomes whatever you recite. Scaffolded 2026-09-12 from `docs/CONCEPT.md`; needs an Opus architecture pass. Graphics: the city as scoreboard — see `docs/ASSET_MANIFEST.md`. |
| [`wardens/`](wardens/README.md) | fps | A living weapon that grows or starves by how you fight; its shape *is* the UI. Scaffolded 2026-09-12 from `docs/CONCEPT.md`; needs an Opus architecture pass. Graphics: blend-shape morphing driven by `growth_vector` — see `docs/ASSET_MANIFEST.md`. |
| [`zork/`](zork/README.md) | fps | First-person re-imagining of the 1980 text adventure. 15 rooms, troll + thief encounters, dialogue answers checked against the intel journal. |
| [`aevum/`](aevum/README.md) | isometric | 8-of-12 clans race to meditate every shrine, become Avatar, build a Seeker and steal the Dragon's egg. Ported from a Python/pygame project (2026-09-07); all 11 data files are **generated** by `aevum/tools/convert_aevum_data.py`; game-specific rules (clan select, shrine meditation/Avatar, dragon wake, egg carry, victory) live in `aevum_boot.gd` / `aevum_combat_resolver.gd`. `--smoke` passes 37/37 — read `aevum/activeContext.md` for what's left (tests, art, shrine placement). Sync with `-Engine isometric`. |
| [`paragon/`](paragon/README.md) | isometric | Original virtue-RPG: procedurally generated world, 8 virtues drawn per seed, knowledge-driven progression. Full design bible in `paragon/docs/` (29 docs, moved from the standalone `UIV` repo 2026-09-07). Code not yet started — read `paragon/activeContext.md` first. Sync with `-Engine isometric`. |

See `docs/ARCHITECTURE.md` for the full repository layout and the
distinction between `core/`, `game_api/`, and `games/`.
