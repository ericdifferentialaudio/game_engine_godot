# buildings.md — Building Reference
Source of truth: `assets/data/buildings.json`. Machine-readable; numbers below
are read directly from JSON, not narrated. Rewritten 08/24/2026 — the prior
version described a fictional 3-tier chain (Watchtower/Counting House/Forge/
Temple/Barracks II/Grand Exchange, 4-turn builds) that does not exist in the
data; this file was fully out of sync with the game's real economy.

## Chain shape
5 tiers + Sanctum (outside the tier chain, Avatar-gated). One production slot
at a time (unit OR building). Max 3 items queued (4 after Grand Citadel).
Tile improvements and traps removed (legacy, not in current data).
Field structures (Watch Post, Fort) are placed on the map by units, not
queued at the enclave — see bottom table.

`requires: "any_tier2"` = any one Tier-2 building satisfies the prereq (not
a specific one). `clan_specific` = only that clan may build/queue it (all
Tier-5 buildings are clan-specific). All Tier-5 buildings additionally
require Grand Citadel (Tier 4).

## Tier 1 — Foundation (no prereqs)
| id | name | gold | turns | effect |
|---|---|---|---|---|
| `barracks` | Barracks | 80 | 6 | unlocks scout/archer/clan_unit production; unit cap +3 |
| `treasury` | Treasury | 100 | 6 | +8 gold/turn; gold cap +200 |
| `library` | Library | 90 | 6 | tech research −2 turns; field intel fragments auto-decode at enclave (no town visit) |

## Tier 2 — Military & Economy (require any Tier 1)
| id | name | gold | turns | requires | effect |
|---|---|---|---|---|---|
| `armoury` | Armoury | 120 | 10 | barracks | new units +1 ATK base; unlocks Tier-3 military line |
| `vault` | Vault | 150 | 10 | treasury | +15 gold/turn (replaces Treasury bonus); gold cap +400; enclave-breach loot loss −50% |
| `scriptorium` | Scriptorium | 120 | 10 | library | rival shrine-meditation progress visible in UI; pub intel from all villages auto-decoded/turn |

## Tier 3 — Specialisation (require any Tier 2)
| id | name | gold | turns | requires | effect |
|---|---|---|---|---|---|
| `meditation_hall` | Meditation Hall | 150 | 14 | any_tier2 | meditation −1 turn for all clan units; sacred-ground vision +1 hex from outside |
| `mana_well` | Mana Well | 140 | 12 | scriptorium | +1 MP regen/turn to magic-capable units (no effect on Fighter/Dwarf) |
| `war_college` | War College | 160 | 14 | armoury | new units start with 1 XP; Chieftain permanently +1 ATK/+1 MOV |
| `reinforced_walls` | Reinforced Walls | 130 | 12 | any_tier2 | enclave walls 24 HP max, self-repair +1/turn; only a Warlord unit can breach |

## Tier 4 — Power (require any Tier 3)
| id | name | gold | turns | requires | effect |
|---|---|---|---|---|---|
| `grand_citadel` | Grand Citadel | 200 | 18 | war_college | all units +1 DEF permanently; production queue 3→4 slots; **unlocks Tier-5 clan building** |
| `vault_of_ages` | Vault of Ages | 220 | 18 | vault | +25 gold/turn (replaces Vault); gold cap +500; breach loot loss −75% |
| `sanctuary` | Sanctuary | 190 | 16 | meditation_hall | units within 2 hexes of enclave regen +1 combat HP/turn |

## Tier 5 — Clan Buildings (all require `grand_citadel`, one per clan)
| id | name | clan | gold | turns | unlocks unit | other effect |
|---|---|---|---|---|---|---|
| `forge` | Forge | dwarf | 180 | 16 | runesmith | wall self-repair +2/turn (stacks w/ Reinforced Walls); forts −1 build turn |
| `arcane_tower` | Arcane Tower | mage | 200 | 16 | arcanist | all Mage units +3 max MP; T3+ spells −1 MP cost |
| `temple` | Temple | cleric | 180 | 14 | high_priest | Cleric units regen +1 HP/turn while on a currently-visible hex |
| `ranger_post` | Ranger Post | ranger | 160 | 14 | trapper | all Ranger units +2 STL; Watch Posts build in 1 turn |
| `archer_range` | Archer Range | elf | 180 | 14 | starbow | all Elf Archer units +1 RNG |
| `shadow_den` | Shadow Den | rogue | 170 | 14 | assassin | all Rogue units +1 STL; assassination range 2 hexes |
| `monastery` | Monastery | monk | 160 | 14 | iron_fist | Monk units never trigger ZoC; pass-through attack (no movement stop needed) |
| `grove` | Grove | druid | 180 | 14 | thornweaver | forest hexes grow into 1 adjacent non-forest hex every 8 turns, within 3 hexes of a living Druid unit |
| `crypt` | Crypt | necromancer | 190 | 16 | death_knight | Reanimate duration +3 turns; killed enemy units 20% chance to auto-reanimate under Necromancer control |
| `thieves_guild` | Thieves Guild | bard | 170 | 14 | spymaster | free rumor-plant every 10 turns (no pub visit); meditation-rights purchase −20% cost |
| `spirit_lodge` | Spirit Lodge | shaman | 200 | 16 | stormcaller | Lightning Storm base damage +1; area spells +1 hex radius |
| `war_hall` | War Hall | fighter | 170 | 14 | warlord | forts −1 build turn; Warlord can breach enemy Reinforced Walls |

Fighter, Dwarf and Necromancer are the only clans whose Tier-5 building
grants a wall-related or breach-related edge (War Hall/Forge breach+repair,
Crypt has none) — asymmetric by design.

## Sanctum — Avatar-gated (outside the tier chain, tier=0)
| id | gold | turns | requires | effect |
|---|---|---|---|---|
| `sanctum` | 150 | 8 | `requires_avatar: true` (all 8 shrines) | +1 DEF to all clan units permanently; unlocks Seeker (max 1/clan) |

Balance history (in JSON `_cost_note`): was 200g/20t; lowered 08/2026 because
Avatar lands late in practice (t115–t161 in seed-5 runs) and 20 build turns +
Seeker's own 7 meant 27+ turns after Avatar before any Seeker existed —
usually past the point of mattering. Target: Avatar→Sanctum→Seeker completes
in ~15 turns, aiming for 3–4 seekers/game.

## Field Structures (placed on the map by units, not enclave-queued)
| id | gold | turns | requires tech | terrain | effect |
|---|---|---|---|---|---|
| `watch_post` | 40 | 2 | scouting | plains/grasslands/hills/forest | +2 vision radius, HP 4 (destructible) |
| `fort` | 80 | 3 | engineering | plains/grasslands/hills | units within radius 1: +1 ATK/+1 DEF; HP 8; Fortification tech → radius 2, bonus +2/+2 |

## AI construction logic — ⚠️ two code paths, one is dead/stale
- **Live path**: `force_fill_production_queue()` (`engine_ai.py`), runs every
  turn before goal selection. Scores unit/building/tech options via
  `clan.build_personality` weights; building option reads
  `BUILDING_CATALOGUE` (loaded straight from `buildings.json` — full 26-
  building catalogue, correct prereqs via `_building_prereq_met()`, correct
  costs). This is what actually drives AI construction.
- **Dead/stale path**: `_ai_construct_building()`, reached only via the
  `construct_building` goal AND only if the queue is empty when it runs
  (rare, since the live path above usually already filled it). Uses a
  hardcoded 9-building list (`barracks`, `watchtower`, `counting_house`,
  `barracks_ii`, `sanctum`, `forge`, `arcane_tower`, `temple`,
  `ranger_post`) — **4 of these 9 ids do not exist in `buildings.json`**
  (`watchtower`, `counting_house`, `barracks_ii`), and `forge`/
  `arcane_tower`/`temple`/`ranger_post` are also wrong here: those are
  Tier-5 clan-specific buildings in the real data, not generic ones this
  function treats as buildable by any clan. Logged as an OUTSTANDING
  defect in `activeContext.md` — not fixed as part of this doc pass.

## Balance notes
- Games run to t350 max. Buildings must be queued by ~t80 to earn enough
  turns of passive income before the shrine war ends.
- `sanctum` is scored at value 0.95 (tied for highest in the catalogue)
  once Avatar is reached, since it is the only route to a Seeker.
