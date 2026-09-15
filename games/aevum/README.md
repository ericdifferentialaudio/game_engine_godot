# Aevum — Age of Shrines

Eight of twelve clans race across a hex world to meditate every shrine and
become **Avatar**, build a **Seeker**, steal the **Dragon's egg** and carry it
home uncontested — or eliminate every rival clan first.

Ported from the original Python/pygame project at `C:\Aevum`. This is a **data
package** on the `game_api/isometric` engine layer, not a transliteration: the
engine already provides hex topology, simultaneous turns, factions and
diplomacy, fog of war, combat, shops, and the intel journal, so Aevum's *rules*
are ported while its *implementation* is the engine plus a small set of
game-specific GDScript modules.

```
games/aevum/                <- authoritative source (edit here)
  game.json                 hex grid, simultaneous turns, currencies, stats, rules.aevum.*
  terrains.json             9 terrains (7 land from terrain.json + ocean/coast)
  maps.json                 overworld (64x48, noise) + two lair maps
  units.json                140 units + 35 abilities (clan ladder, monsters, lairs, naval)
  items.json                52 items incl. the dragon egg
  factions.json             12 clans + the Wilds + the Dragon
  intel.json                65 tokens: shrine locations, mantras, weaknesses, the egg (+ a lie)
  intel_rules.json          derivation, spread, contradiction
  sites.json                39 sites: 12 shrines, 12 enclaves, towns, lairs, the Veil
  assets.json               351 keys (placeholder-backed until the art pass)
  ai_profiles.json           8 behaviour profiles
  aevum_boot.gd              game.json "boot_script": clan select, shrine meditation/Avatar,
                             dragon wake, egg pickup/carry, victory, tech/building gate query
  aevum_combat_resolver.gd   sacred-ground no-combat + the Dragon's ancient-armour threshold
  docs/                      the 33-file design bible, copied from assets/md/
  tools/convert_aevum_data.py   the repeatable converter that generates all of the above
```

## Run

```powershell
python game_api/isometric/tools/validate_data.py games/aevum   # 0 errors, 0 warnings
./tools/sync_game.ps1 -Game aevum -Engine isometric
C:\Tools\Godot\4.7.2\godot_console.exe --path game_api/isometric -- --game=aevum
```

Headless check:

```powershell
C:\Tools\Godot\4.7.2\godot_console.exe --headless --path game_api/isometric -- --game=aevum --smoke
```

> `--smoke` passes **37/37**. (An earlier run showed 36/37 because the harness's
> generic derivation check happened to reference the *example* package's own
> token ids — fixed by nothing on our end; it was route-specific to that run.)

## Regenerating the data

The eleven JSON files are **generated**, not hand-edited. After any change to
the upstream Python data:

```powershell
python games/aevum/tools/convert_aevum_data.py --source C:\Aevum
python games/aevum/tools/convert_aevum_data.py --check    # non-zero exit if stale
```

Every mapping decision (stat renames, colour formats, terrain exceptions,
metadata carried through for the rules modules) lives in that one script — see
`docs/PORT_MAP.md` for the subsystem-by-subsystem mapping.

## How the game's knowledge works

Aevum's intel system maps almost exactly onto the engine's, so it is real data
rather than code:

| Knowledge | Token | Where it pays off |
|---|---|---|
| Where a shrine stands | `location_shrine_<clan>` | reveals the site + 2 tiles |
| The shrine's mantra | `mantra_<clan>` | meditation drops ~12 turns → 1 |
| A monster's weakness | `weakness_<monster>` | +3 damage per hit |
| Where the egg lies | `egg_location` | reveals the Veil; the win condition |
| …and the lie about it | `egg_location_false` | `conflicts` with the truth; sold in pubs |

Towns with a Contemplation Hall teach mantras; pubs sell rumour (some of it
false); the Veil is `hidden_until` you know `egg_location` at ≥ 0.6 reliability.

## Game-specific rules (Phase 2)

The shared platform is generic; `aevum_boot.gd` (`game.json` `boot_script`) and
`aevum_combat_resolver.gd` supply everything Aevum-specific it cannot express:

| Rule | How |
|---|---|
| Clan select | Seed keeps `rules.aevum.active_clans` of the 12 clans (+ the player's own) before the run starts |
| Shrine meditation | The `meditate` ability starts a hold; mantra-token reliability picks the 1/3/12-turn tier; leaving the hex cancels it |
| Shrine bonus | Clan-wide +1 / meditating unit +2 to the shrine's stat, via `CharacterStats` modifiers; inherited by units spawned afterwards |
| Avatar status | Set once a clan has meditated every active shrine |
| Sacred ground | No combat within any shrine's `sacred_ground_radius` (combat resolver override) |
| Dragon wake | A Seeker within `dragon_wake_radius` of the Veil wakes it |
| Dragon armour | First N damage/turn negated (combat resolver override) |
| Egg carry | Pickup sets `cannot_attack` + a `moves` penalty |
| Victory | Egg carried onto the carrier's own enclave, uncontested (no adjacent hostile unit) |
| Tech/building gate | `can_produce()` — a pure query, not yet wired to a build UI (none exists in the shared platform) |

Two small additions were needed in the engine layer itself to reach parity with
the fps layer: `game_api/isometric/autoloads/game_manager.gd` gained the
`boot_script` loader, and `Unit.attack()` gained a `flags.cannot_attack` gate.

## Status

Phases 0–2 (scaffold, data, rules) are **done and validated** —
`--game=aevum --smoke` passes 37/37, and `tools/run_tests.ps1` (all three GUT
suites + the fps zork playtest) passes with no regression. Not yet done: a
game-specific GUT test suite for the rules above, real shrine-placement
distance/terrain constraints (currently `random_land`), a tech/building UI or
AI hook for `can_produce()`, and Phase 3 (importing real art from the 2.4 GB
source tree — currently placeholder-backed). Read `activeContext.md` before
continuing.
