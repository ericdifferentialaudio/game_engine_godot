# items.md — Item Reference
Sources of truth: `assets/data/items.json`, `town_items.json`, `castle_items.json`.
Rewritten 08/24/2026 — the prior version listed ~60 items (T2 world-map,
T3 dragon-combat, T4 legendary tiers) that do not exist in any data file;
only `items.json` (shop/enclave/rare + island), `town_items.json` (+1 tier)
and `castle_items.json` (+2 tier) are real. Units have 3 real item slots
(see ⚠️ contradiction note below) — the old doc's "3 slots" framing was
right, everything else about it (item roster) was wrong.

## Slot model
`slot` field values seen in data: `any`, `melee`, `archer`, `caster`,
`seeker`. `any` = no restriction. Others gate to that unit archetype.

⚠️ **Data/code contradiction, unresolved**: `items.json.rules` says
`max_items_per_unit: 1`, but `UnitInstance` (`game_state.py`, "Sprint 10 —
3-slot inventory, LOCKED #63") actually has **3 real slots** —
`item_weapon`, `item_organic_1`, `item_organic_2` — and every pickup/AI/
serialization path (`pickup_item()`, `engine_underground.py`,
`engine_ai.py` need-checks) uses all 3. The JSON rule appears stale/wrong,
not the code. Flagged for the user to confirm the intended number before
either is "fixed" to match the other.

## items.json — `standard` (shop/enclave, no prereq)
| id | name | cost | source | effect |
|---|---|---|---|---|
| `iron_shield` | Iron Shield | 40 | shop, enclave | +1 DEF |
| `swift_boots` | Swift Boots | 50 | shop, enclave | +1 MOV |
| `keen_blade` | Keen Blade | 50 | shop, enclave | +1 ATK |
| `lantern` | Lantern | 30 | shop | +2 VIS |
| `heal_potion` | Healing Potion | 35 | shop, enclave | +3 combat HP, single use, does not cure exhaustion |
| `shrine_map` | Shrine Map | 60 | shop | reveals all 8 active shrine locations immediately |
| `spell_scroll` | Spell Scroll | 80–150 | scroll_shop | single cast of one spell up to clan tier+1; T5 never available |

## items.json — `weapons` (melee slot)
| id | name | cost | source | effect |
|---|---|---|---|---|
| `flameblade` | Flameblade | 0 | rare_enclave | +2 ATK; on kill, adjacent enemies take 1 fire dmg |
| `shadowblade` | Shadowblade | 0 | rare_enclave | +1 ATK; passive Shroud (invisible beyond 2 hex) |
| `frostblade` | Frostblade | 120 | shop, enclave | +1 ATK; on hit, target MOV −1 for 1 turn |
| `soulreaver` | Soulreaver | 0 | rare_enclave | +2 ATK; kills cannot be reanimated |
| `runic_axe` | Runic Axe | 100 | shop | +2 ATK vs buildings/walls, +1 ATK vs units — **dwarf only** |

## items.json — `bows` (archer slot)
| id | name | cost | source | effect |
|---|---|---|---|---|
| `longbow` | Longbow | 80 | shop, enclave | +1 RNG (→4), +1 ATK |
| `elfbow` | Elfbow | 0 | rare_enclave | +1 RNG; arrows ignore forest DEF bonus |
| `shadowbow` | Shadowbow | 0 | rare_enclave | firing position not revealed when shooting |
| `stormbow` | Stormbow | 110 | shop | +2 ATK; −1 ATK in forest terrain |

## items.json — `staves` (caster slot, min_tier 2)
| id | name | cost | source | effect |
|---|---|---|---|---|
| `mana_staff` | Mana Staff | 90 | shop | +4 max MP, +1 MP regen/turn |
| `spell_staff` | Spell Staff | 0 | rare_enclave | all spells cost −1 MP (min 1); does not reduce exhaustion |
| `focus_crystal` | Focus Crystal | 100 | shop | +1 spell damage on all casts |
| `exhaust_sigil` | Exhaustion Sigil | 0 | rare_enclave | T4 spells cause no exhaustion for this unit; T5 still full cost |

## items.json — `seeker` (seeker slot)
| id | name | cost | source | effect |
|---|---|---|---|---|
| `seekers_crystal` | Seeker's Crystal | 0 | rare_enclave | +3 VIS permanently |
| `ghost_cloak` | Ghost Cloak | 0 | rare_enclave | invisible 3 turns, single use |
| `amulet_swift` | Amulet of Swiftness | 80 | shop | +1 MOV permanently |
| `warding_stone` | Warding Stone | 60 | enclave | negates next spell targeting this unit, single use |

## items.json — `artifacts` (no cost field; found, not bought)
| id | name | category | effect |
|---|---|---|---|
| `egg_shard` | Egg Shard | intel | reveals one terrain type the egg is NOT in |
| `ancient_map` | Ancient Map | intel | removes fog in 5-hex radius around one shrine |
| `seer_stone` | Seer Stone | intel | one yes/no question about egg location, answered truthfully |
| `war_horn` | War Horn | military | all clan units +1 MOV for 5 turns |
| `warding_rune` | Warding Rune | military | place on any hex — 3 dmg to entering enemies |
| `shadow_cloak` | Shadow Cloak | military | one unit invisible 3 turns, single use |
| `heal_totem` | Healing Totem | military | fully restores all units' combat HP |
| `masons_tools` | Mason's Tools | upgrade | next building completes in 1 turn |
| `scholars_lens` | Scholar's Lens | upgrade | Library decodes all current intel instantly |
| `foresters_axe` | Forester's Axe | upgrade | forest terrain free for entire clan, permanently |

## items.json — `island` (island_explore only, one per island group, free)
| id | name | effect |
|---|---|---|
| `nautical_chart` | Nautical Chart | one-time: reveals all is_coastal hexes for this clan |
| `sea_glass_lens` | Sea Glass Lens | permanent: this clan's at-sea units +2 VIS |
| `kraken_talisman` | Kraken Talisman | one-time: ocean lair guards ignore this clan for 10 turns |
| `coral_armor` | Coral Armor | permanent: carrier +2 DEF while `at_sea == True` |
| `storm_anchor` | Storm Anchor | permanent: carrier always moves at full wind speed (MOV 4), ignores wind direction |
| `driftwood_chart` | Driftwood Chart | one-time: reveals egg's map quadrant + rough distance band from center |

## town_items.json — Tier 1 (+1 stat, no prereq, sold at towns)
Each town stocks a seed-selected 3–4 of this 6-item pool, shared across all
clans (first come, first served). Compatible with the `items.json` standard
items above (`iron_shield`/`keen_blade`/`swift_boots`/`lantern` are also T1).
| id | name | stat | bonus | price | slot |
|---|---|---|---|---|---|
| `short_sword` | Short Sword | atk | +1 | 55 | melee |
| `buckler` | Buckler | def | +1 | 45 | any |
| `swift_boots` | Swift Boots | mov | +1 | 60 | any |
| `lantern` | Lantern | vis | +1 (torch radius 4 in lairs) | 30 | any |
| `travellers_cloak` | Traveller's Cloak | def | +1 | 40 | any |
| `iron_cap` | Iron Cap | hp_max | +1 | 50 | any |

**Notice board tokens** (town intel purchases):
| id | price | intel_type | confidence | tier |
|---|---|---|---|---|
| `shrine_direction` | 50 | shrine_direction | 0.60 | T1 — cardinal direction to one unmeditated shrine |
| `monster_rumour` | 30 | unit_spotted | 0.50 | T1 — approx location of one nearby monster enclave |
| `mantra_fragment` | 80 | mantra_fragment | 0.40 | T1 — partial mantra hint for one shrine |

**Inn**: rest 1 turn = 20g/50% missing-HP heal; rest 2 turns = 35g/50%
per-turn heal. Unit cannot move/act while resting.

## castle_items.json — Tier 2 (+2 stat, requires owning a +1 prerequisite)
The +1 prerequisite item is **not consumed** — both coexist in the clan.
Castle stock is the **full pool always** (not seed-limited like towns),
shared across clans.
| id | name | stat | bonus | price | slot | requires (any of) |
|---|---|---|---|---|---|---|
| `knights_blade` | Knight's Blade | atk | +2 | 150 | melee | short_sword, keen_blade |
| `tower_shield` | Tower Shield | def | +2 | 140 | any | buckler, iron_shield, travellers_cloak |
| `windrunner_boots` | Windrunner Boots | mov | +2 | 170 | any | swift_boots |
| `enhanced_lantern` | Enhanced Lantern | vis | +2 (torch radius 5 in lairs) | 110 | any | lantern |
| `plate_helm` | Plate Helm | hp_max | +2 | 130 | any | iron_cap |

All +3 and higher stat items come exclusively from lair bosses, boss
chests, or map drops — no shop sells them.

**Scriptorium tokens** (castle intel purchases, T2):
| id | price | intel_type | confidence | notes |
|---|---|---|---|---|
| `shrine_location` | 150 | shrine_direction | 0.90 | exact hex for one unmeditated shrine |
| `mantra_teaching` | 200 | mantra_known | 0.70 | named shrine + partial mantra text |
| `monster_weakness` | 120 | weakness_known | 0.85 | weakness revealed for nearest active enclave |
| `clan_movement_report` | 100 | combat_specific | 0.65 | one rival clan's recent movements/activity |

**Chapel**: exhaustion-HP heal 40g/HP, max 2 uses/clan/castle (Velmoor town
is cheaper at 25g/HP but has no per-clan use cap).
**Inn**: identical mechanics to town inn (rest in castle barracks).

## Rules (from `items.json.rules`)
- `max_items_per_unit`: JSON says 1; code implements 3 (see contradiction
  flagged above under Slot model). Treat 3 as authoritative until resolved.
- Spell scrolls: tiers 1–4 only; T5 never available as a scroll.
- Island items: pre-seeded at worldgen on unexplored island hexes; first
  clan unit to enter the hex triggers the reward; one item per island group.
