# 09 — Items, Equipment & Magic Weapons

Items are **behavioural**: beyond stats they carry passive effects, granted
abilities, and triggered procs. "Finding a new magic weapon changes how you
play" is a data change, not a code change.

## ItemDefinition (`items.json`)
| field | meaning |
|---|---|
| `category` | weapon · armor · accessory · consumable · ammo · key · tome · material · quest · currency · misc |
| `rarity` | common … legendary · unique |
| `equip_slot` | one of `game.json.equip_slots`, or `ring` (first free ring slot) |
| `two_handed` | clears/blocks off_hand |
| `stats` / `stats_percent` | modifiers pushed into `Stats` while equipped (source `equip:<slot>`) |
| `damage` | weapons: `{"slash": [3,6], "holy": [4,6]}` — used by `scale_with_weapon` abilities |
| `resistances` | armour: `{"fire": 0.25}` |
| `effects[]` | EffectDefinitions applied while equipped (e.g. `silent_steps`) |
| `abilities[]` | AbilityDefinitions granted while equipped (weapon attacks, relic spells) |
| `procs[]` | `{"trigger": "on_hit", "chance": 0.25, "effect": "blessed_weapon"}` (execution M2) |
| `use_ability` / `teaches_ability` | consumables cast on use; tomes learn permanently |
| `requires` | **IntelQuery** — you must *know* how to wield it |
| `requires_stats` | `{"agility": 8}` |
| `identified` / `identify_intel` | unidentified until the named intel token is known |
| `lore_intel` | intel granted when inspected — items are intel sources too |

## ItemInstance
Runtime object: `def`, `count`, `affixes[]` (M4 generated modifiers), `identified`,
`durability`, `custom_name`, `uid`. Unidentified items expose only base stats.
`Inventory` holds instances; `Equipment` moves them between inventory and slots.

## Equipment rules
- `can_equip()` checks slot, `requires` (IntelQuery), `requires_stats`; failures
  emit a notification (`"You don't yet understand how to use this."`).
- Equip pushes `stats` → `Stats`, `effects` → `StatusEffects` (permanent while
  equipped), `abilities` → `AbilityCaster.grant()`; unequip removes all by source.
- Two-handed main hand clears off hand and vice-versa.

## Intel ↔ items (the crossover)
- **Identification by knowledge**: `ring_of_stillness` reads as "Unidentified
  Accessory" until `lore_ring_of_stillness` is learned from the innkeeper.
- **Gated wielding**: `relic_ossuary` needs `lore_ossuary_relic` at ≥0.6
  reliability (ledger in the crypt, corroborated). It also grants `bone_ward`
  and is the Bone-Warden's `weakness_intel`.
- **Items as sources**: `crypt_key_fragment.lore_intel` grants the crypt rumour.

## Roadmap hooks
- **M2** — ability execution (weapon damage rolls, procs firing), consumables, view-models.
- **M4** — affix generation (`affix_pool`), loot tables, identification scrolls/sages,
  grimoire learning with intel prerequisites, durability.
