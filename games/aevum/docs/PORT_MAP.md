# Port Map — Python Aevum → Godot data package

Where every subsystem of the original `C:\Aevum` project ends up. This is the
document that makes the remaining phases mechanical.

## The governing decision

The original project is ~2.5 MB of Python across 60+ `engine/` modules. It is
**not** transliterated. The `game_api/isometric` layer already implements most
of what those modules do; Aevum's rules are ported as data, and only genuinely
Aevum-specific rules become GDScript.

## Data (Phase 1 — DONE)

| Python source | Godot destination | Notes |
|---|---|---|
| `assets/data/terrain.json` | `terrains.json` | `def_bonus`→`defense_bonus` (×25, engine uses %); `[r,g,b]`→`#rrggbb`; `passable_all:false`→`passable:false`; `grasslands`→`grassland`; ocean/coast added (upstream generated water procedurally) |
| `terrain.json.movement_exceptions` | per-unit `movement.terrain_costs` | Ranger/Dwarf/Elf/Druid/Necromancer terrain flavour survives as real pathfinding cost |
| `assets/data/unit_types.json` | `units.json` (140 units) | 5 universal types × 12 clans, the common→advanced→specialty ladder, naval. Stats renamed `atk/def/mov/hp/vis`→`strength/defense/moves/health/sight`; `mp/rng/stl/arc/lck/res/end/int_stat` kept and declared in `game.json.stats` |
| `monsters.json`, `lair_monsters.json`, `lair_bosses.json` | `units.json` (`kind: monster`) | weakness/resistance pools → `metadata` **and** mirrored as intel tokens |
| specialty `ability` blocks | `units.json.abilities` | 11 named abilities registered in the catalog |
| `spells.json` | `units.json.abilities` (`spell_*`) | 24 spells; mana cost in metadata (engine abilities are AP-based) |
| `items.json`, `castle_items.json`, `town_items.json` | `items.json` (52) | `effect`→`modifiers` (stat keys) + `metadata.effects` (special); `cost`→`value`; `slot:"any"`→`trinket` |
| `clans.json` + `virtues.json` | `factions.json` (14) | 12 clans (1 human + 11 AI) + Wilds + Dragon; magic tier, passive, virtues → `metadata` |
| `shrines.json` | `sites.json` (12 shrines) | `placement: random_land`; bonus stat + sacred radius in `metadata` for the rules module |
| `towns.json` | `sites.json` | shop + pub-intel interactions; Contemplation Halls teach mantras |
| `lair_monsters.json` biomes | `sites.json` + `maps.json` | lair entrance sites with `portal` interactions descending into two shared lair maps |
| `engine_intel_tokens.py`, `intel_token_system.md`, `mantras.md` | `intel.json` (65) + `intel_rules.json` | mantras, shrine locations, weaknesses, sightings, the egg and the lie about it |
| `world_gen.md` | `maps.json` | 64×48 noise overworld with terrain bands |
| `engine_ai*.py` (≈600 KB) | `ai_profiles.json` (8 profiles) | collapses into the engine's `ai_controller.gd` |
| `asset_manifest.json` | `assets.json` (351 keys) | placeholder paths until Phase 3 |

## Rules that need GDScript (Phase 2 — DONE)

These have no engine equivalent. All parameters are read from `game.json`
`rules.aevum.*` and from site/unit `metadata` — nothing here is hard-coded.
Everything lives in two files rather than one-module-per-rule (the modules
below were the plan; in practice `aevum_boot.gd` grew as one boot-script node
since the rules all hang off the same handful of EventBus signals):

| File | Responsibility | Data it reads |
|---|---|---|
| `aevum_boot.gd` | clan select, shrine meditation timer + bonus + Avatar, dragon wake, egg pickup/carry/victory, `can_produce()` tech/building query | `rules.aevum.*`, shrine `metadata`, `mantra_*` tokens, `the_veil`/`dragon_egg`, unit `metadata.requires_*` |
| `aevum_combat_resolver.gd` | sacred-ground no-combat, dragon ancient-armour damage threshold | shrine `metadata.sacred_ground_radius`, `rules.aevum.dragon_damage_negated_per_turn` |

Two small additions were made to the engine layer itself (not Aevum-specific,
but needed to reach parity with the fps layer, which already had them):
`game_api/isometric/autoloads/game_manager.gd` gained the `boot_script`
loader; `Unit.attack()` gained a `flags.cannot_attack` gate.

**Not implemented in Phase 2**: shrine-camping penalty (3 consecutive turns on
a shrine hex costs a random permanent stat) and real shrine placement distance
(8–12 hexes from the owning enclave; sites are currently `random_land`,
anywhere on land). `can_produce()` exists but nothing calls it yet — there is
no production-queue UI/AI in the shared platform to wire it into.

## Deliberately dropped

* `client/` (pygame + Atlas viewer) and `simulate/` (headless CLI) — the engine
  layer and its `--smoke` harness replace both. The upstream "one engine, many
  drivers" invariant is satisfied structurally here.
* `assets/clans_backup/` (224 MB duplicate) and `assets/audio/midi_source/`.
* `tools/gen_midi.py`, render logs, `__pycache__`, `.pytest_cache`.

## Known gaps to resolve

* 14 items named by town armoury/store pools have **no upstream stat block**
  (`healing_potion`, `mana_staff`, `longbow`, `egg_spoof`, …). They are emitted
  as stubs tagged `"stub"` with `metadata.needs_design: true` — they need a
  design pass, not invention.
* Shrine/enclave/town/lair placement is `random_land`; the real distance rules
  (shrine 8–12 hexes from its enclave, preferred/avoided terrain) are carried in
  `metadata.placement_rule` and must be enforced by `shrine_system.gd`.
* Sentiment (`sentiment_config.json`), diplomacy depth, mercenaries, the
  underground economy and interiors are **not yet ported** — they are documented
  in `docs/` but have no data or code destination yet.
