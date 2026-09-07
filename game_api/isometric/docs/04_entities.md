# 04 · Entities: Units, Heroes, NPCs, Monsters, Structures, Items, Factions

## EntityDefinition (`units.json`)
One schema, five `kind`s:

| kind | intent | typical fields |
|---|---|---|
| `hero` | main character(s); persistent, levels, equipment | `equipment_slots`, `level_curve`, `starting_items`, `abilities`, high `perception` |
| `unit` | Civ-style military/civilian | `cost`, `upkeep`, `movement`, `ai_profile` |
| `npc` | informant / trader / quest giver | `intel_profile.carries`, `dialogue`, `shop`, `schedule`, `blocks_tile: false` |
| `monster` | hostile wanderer / guardian | `ai_profile: hunter|guard`, `loot`, `xp_value`, `intel_profile.on_defeat` |
| `structure` | immobile occupant (city centre, outpost) | `moves: 0`, `can_capture` |

Stats are free-form; the engine reads `health, strength, defense, moves, sight, perception`.
`game.json → stats` supplies defaults for any missing stat.

### Runtime `Unit` (Node2D)
`stats: CharacterStats` (base + modifiers from equipment/status/level), `inventory: Inventory`
(items, equipped slots, `use_item` runs effects + grants intel), `statuses: StatusEffects`
(turn-scoped buffs), `abilities: AbilitySet` (AP cost, cooldown, targeting, `requires` query,
effects). Movement via `move_to/move_along` consuming action points; `attack()` delegates to
`CombatResolver.active`. Sprites come from `AssetRegistry.load_sprite_frames(visual)` tinted
by faction colour; a placeholder frame set is generated when art is missing.

Units are **intel sensors**: entering sight of another entity grants its
`intel_profile.on_sight` tokens; defeating one grants `on_defeat` + `carries`; fighting
grants `on_combat` to the defender's faction.

## Abilities (`units.json → abilities`, merged with `ai_profiles.json → abilities`)
`{"cost_ap", "cooldown", "target": self|tile|unit|enemy|ally, "range", "requires", "effects":[Interaction...]}`

## AI (`ai_profiles.json`)
Built-in behaviours: `idle`, `wander`, `guard`, `explore`, `hunt`, `schedule`. Register
more with `AIController.register_behavior`. Faction-level strategy (production, diplomacy)
is a `FactionRegistry.register_faction_ai(profile, Callable)` hook — intentionally thin in v1.

## Items (`items.json`)
`kind`: `equipment` (slot + modifiers), `consumable` (`use_effects`), **`intel`**
(`grants_intel` on use, optionally `use_requires` a query — a map you can't read yet),
`artifact` (passive modifiers while held, `unique`), `resource`, `key`, `misc`.
Heroes/NPCs carry inventories; other units' loot goes to the faction `stockpile`.

## Factions (`factions.json`)
`control: human|ai|neutral|hostile`, colour, `turn_order`, `starting_units`, `start`,
`resources` (must include `game.currencies`), `stances` matrix + `default_stance`,
`trade_partners` (feeds intel spread), `starting_intel`, `starting_items`, `ai.profile`.
Each faction has its **own intel journal** (`IntelRegistry.journal_for(id)`), flags,
stockpile and seeded RNG. `collect_yields()` sums owned-tile yields into currencies and
pays unit upkeep at UPKEEP. Elimination when no units remain (rule-gated); last faction
standing wins (rule-gated).

## Economy
`Shop` (from a `shop` interaction or `EntityDefinition.shop`): intel-gated stock, limited
counts persisted across visits, `sell()` at `rules.economy.sell_ratio`, and **intel
brokering** (`buys_intel`) paying `value × reliability × multiplier`.
