# Resource Schema

> **Superseded — see [`API.md`](API.md).**
>
> The scaffold classes this file used to document (`UnitDefinition`,
> `ItemDefinition`, `TokenDefinition`, `VirtueDefinition`, `WorldFact`) were
> placeholders written before the two real engines were imported. They have
> been removed: `ItemDefinition` in particular collided with the engines' own
> class of the same name and prevented both projects from booting.

The live data contract is the `Core*` schema classes in
`core/addons/game_core/schema/`:

| Class | Data file | Covers |
|---|---|---|
| `CoreDefinition` | — | shared base: id, display_name, tags, metadata, raw |
| `CoreItemDefinition` | `items.json` | weapons, armour, consumables, artifacts |
| `CoreUnitDefinition` | `units.json` / `actors.json` | players, heroes, NPCs, monsters, structures |
| `CoreIntelToken` | `intel.json` | information tokens |
| `CoreFactionDefinition` | `factions.json` | factions, diplomacy, reputation |
| `CoreProvenance` | — | intel chain of custody |

Every field, helper and signal is documented in [`API.md`](API.md);
`ARCHITECTURE.md` explains how the two graphics engines consume them.

## Changing the schema

1. Edit the relevant `core_*.gd` class in `core/addons/game_core/schema/`.
2. Update the corresponding section of `docs/API.md`.
3. Add or adjust a GUT test in `core/tests/unit/`.
4. Run `./tools/sync_core.ps1` then `./tools/run_tests.ps1` — a schema change
   must leave all three unit suites *and* both runtime integration checks green.
5. If the change is breaking (renamed/removed field or method), call it out
   explicitly so both engine API layers can be updated deliberately.

## A note on lenient parsing

Real authored data is inconsistent: a single-element list is often written as a
bare string, and `equipment` may be a `slot -> item_id` map rather than a list.
`CoreDataLoader.str_array()` / `packed_str_array()` accept all of these, and
every schema class uses them. Prefer them over a raw `PackedStringArray(...)`
cast, which throws on a non-array value and will crash package loading.
