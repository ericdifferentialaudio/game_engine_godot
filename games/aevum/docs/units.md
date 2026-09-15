# units.md — Unit Roster
*Rewritten 08/24/2026 to match `assets/data/unit_types.json` (common_units /
advanced_units / specialty_units / naval_units / monsters) and
`engine/startup_engine.py::_build_unit_templates()`. The prior version
described a pre-08/2026 "clan main unit + clan-specific ranged unit" roster
that no longer exists — ranged units are now one universal Archer/Defender
shared by all clans, and every clan builds a common -> advanced -> specialty
ladder instead of a single flat "clan main unit". See
`comms/AEVUM_GAME_REFERENCE.md` §5 for the authoritative ladder table and the
reverted-rebalance history — do not re-attempt an equalised power-budget
change without reading that section first.*

---

## Unit Categories

Every clan builds through the same ladder, plus two shared universal units
and the two shared ranged/melee-support units (no building required):

| Slot | Unit | Cost | Build | Requires | Limit |
|------|------|------|-------|----------|-------|
| **Starting** | Chieftain | Free (250g rebuild) | 6t rebuild | Free at start; rebuild needs War College | 1 |
| **Shared** | Scout | 50g | 2t | none | Unlimited |
| **Shared** | Archer | 60g | 3t | none | Unlimited |
| **Shared** | Defender | 60g | 3t | none | Unlimited |
| **Common** (tier 1) | Named by clan (Fighter, Mage, Rogue…) | 120g | 4t | Barracks | Unlimited |
| **Advanced** (tier 2) | Veteran upgrade of Common | 150g | 5t | Armoury | Unlimited |
| **Specialty** (tier 3) | Clan-unique | 150–225g | 5–8t | Clan Tier-5 building | Unlimited |
| **End-game** | Seeker | 300g | 7t | Sanctum + Avatar status | 1 |
| **Naval** | Galley / Warship / Privateer | 80–150g | 3–5t | Port (+ Naval Supremacy for Privateer) | Unlimited |

---

## Universal Units

### Chieftain ⭐ *Starting unit*

The most powerful piece on the board. Free at game start; rebuilt for
250g/6t if lost (requires War College; Military Doctrine tech unlocks the
ability to produce a Chieftain at all).

| ATK | DEF | MOV | HP | VIS | MP | RNG |
|-----|-----|-----|----|-----|----|-----|
| 6 | 4 | 5 | 8 | 3 | clan tier | 1 |

**Passives:**
- **Rally Aura**: All friendly units within 2 hexes get +1 ATK and +1 DEF while Chieftain is alive
- **Command Push** (1/turn): Target one adjacent friendly unit — it immediately moves its full MOV (bonus move, in any direction). Chieftain cannot move this turn. The pushed unit cannot attack after the push.
- **Ignores ZoC**: moves freely through enemy zones of control
- Initiates formal alliances, Dragon-Slayer eligible
- Can meditate shrines; can cast spells (clan tier)
- With Chieftain's Code tech: +1 ATK / +1 MOV permanently. With War College: +1 ATK / +1 MOV also (stacks).

---

### Scout

Fast exploration unit. Primary gold income source (0.1g/visible tile/turn).

| ATK | DEF | MOV | HP | VIS | MP | RNG |
|-----|-----|-----|----|-----|----|-----|
| 1 | 1 | 6 | 2 | 4 | 2 | 1 |

- No building required. 50g / 2t.
- Can initiate diplomacy when adjacent to rival unit or enclave
- No ZoC triggered
- Spell tier 0 (2 MP pool regardless of clan tier)
- Terrain free: inherits clan bonuses (Ranger/Elf/Druid get forest free, etc.)

---

### Archer (universal, replaces old per-clan ranged roster)

| ATK | DEF | MOV | HP | VIS | MP | RNG |
|-----|-----|-----|----|-----|----|-----|
| 2 | 1 | 2 | 3 | 2 | 0 | 3 |

- No building required. 60g / 3t. Same stats for all 12 clans — flavour comes
  from clan terrain/STL/MP/ARC modifiers applied elsewhere, not from a
  per-clan template.

### Defender (universal)

| ATK | DEF | MOV | HP | VIS | MP | RNG |
|-----|-----|-----|----|-----|----|-----|
| 2 | 4 | 1 | 5 | 1 | 0 | 2 |

- No building required. 60g / 3t. Garrison/defensive unit; same stats for all
  12 clans.

> ⚠️ **The old *clan-specific ranged units* (Crossbowman, Longbowman, Bone
> Caster…) and *clan-specific defender units* (Sentinel, Shieldwall…) were
> deleted from `unit_types.json` in 08/2026** — they had been dead data for
> some time. Do not reference them; the loader builds one universal Archer
> and one universal Defender for every clan.

---

### Seeker

Egg carrier. One per clan. Requires Avatar status + Sanctum building.

| ATK | DEF | MOV | HP | VIS | MP | RNG |
|-----|-----|-----|----|-----|----|-----|
| 2 | 3 | 4 | 6 | 6 | clan tier | 1 |

- **Cannot attack** (non-combatant). 300g / 7t.
- VIS 6: can detect the dragon egg passively
- Carrying egg: MOV −1, cannot attack
- All Avatar shrine bonuses applied at creation
- No ZoC triggered
- Requires Sanctum building + Avatar status

---

## The Common -> Advanced -> Specialty Ladder

Every clan builds the same three-tier ladder, one unit per tier. Common:
120g/4t (Barracks). Advanced: 150g/5t (Armoury) — always +2 ATK / +1 DEF /
+2 HP over Common, with MOV/VIS/MP/spell tier/terrain traits inherited
unchanged. Specialty: 150–225g/5–8t (clan's own Tier-5 building, which
itself requires Grand Citadel).

| Clan | Common | ATK/DEF/MOV/HP | MP | Spell | Advanced | ATK/DEF/MOV/HP | Specialty | Cost/Turns |
|------|--------|----------------|----|----|----------|----------------|-----------|------------|
| Fighter | Fighter | 5/3/3/6 | 0 | — | Champion | 7/4/3/8 | Warlord | 175g/6t |
| Mage | Mage | 2/1/3/4 | 24 | T5 | Magus | 4/2/3/6 | Grand Arcanist | 225g/8t |
| Cleric | Cleric | 3/5/3/5 | 14 | T3 | Templar | 5/6/3/7 | High Priest | 175g/6t |
| Dwarf | Dwarf | 5/4/2/7 | 0 | — | Ironbreaker | 7/5/2/9 | Runesmith | 150g/5t |
| Ranger | Ranger | 3/2/4/4 | 4 | T1 | Pathfinder | 5/3/4/6 | Trapper | 150g/5t |
| Elf | Elf | 4/2/4/4 | 14 | T3 | Bladesinger | 6/3/4/6 | Starbow | 175g/6t |
| Rogue | Rogue | 5/2/4/4 | 4 | T1 | Shadowblade | 7/3/4/6 | Assassin | 200g/6t |
| Monk | Monk | 4/3/4/5 | 8 | T2 | Warrior Monk | 6/4/4/7 | Iron Fist | 175g/5t |
| Druid | Druid | 3/3/3/5 | 14 | T3 | Archdruid | 5/4/3/7 | Thornweaver | 150g/5t |
| Necromancer | Necromancer | 4/2/3/5 | 20 | T4 | Grave Warden | 6/3/3/7 | Death Knight | 200g/6t |
| Bard | Bard | 2/2/4/4 | 8 | T2 | Skald | 4/3/4/6 | Spymaster | 175g/5t |
| Shaman | Shaman | 3/2/3/5 | 20 | T4 | Spiritspeaker | 5/3/3/7 | Stormcaller | 200g/6t |

**Passives** (unchanged from Common to Advanced tier):
- Fighter — **Charge**: move through enemy hex, trigger combat without stopping
- Mage — Highest mana pool. Very fragile. ARC 3
- Cleric — **Heals 2 HP** to one adjacent friendly as free action/turn. RES 1
- Dwarf — Mountain passable (cost 2). Fortress-tough. RES 2, END 2
- Ranger — **Ghost Step**: ignores ZoC from non-adjacent enemies. Forest/hills/grasslands free. Mountain cost 1
- Elf — **Long Sight**: meditate shrine from 1 hex outside radius. Forest free. ARC 2
- Rogue — **Invisible beyond 2 hexes** at all times. Stealth breaks on attack. STL 3
- Monk — **No ZoC** (Passing Through). Enemies must spend action to engage. RES 2
- Druid — Forest/grasslands free. LCK 2
- Necromancer — **Dark Resonance**: +1 ATK per 3 deaths on map (all deaths, cumulative, permanent, cap +4). Swamp free. STL 1
- Bard — Reads rival shrine completion status. Detects planted rumors. INT 3
- Shaman — **AoE spell damage +1** on all area spells. ARC 2

### Specialty Unit Abilities

| Clan | Specialty | Ability |
|------|-----------|---------|
| Fighter | **Warlord** | **Rally Command**: friendlies within 2 hexes +1 ATK/+1 DEF (passive) |
| Mage | **Grand Arcanist** | **Arcane Relay**: teleport friendly unit within 6 hexes (1/turn) |
| Cleric | **High Priest** | Instant meditation. Heals 3 HP adjacent/turn |
| Dwarf | **Runesmith** | **Ward Rune**: invisible hex trap, 3 dmg, 2-hex range, 3 uses |
| Ranger | **Trapper** | **Snare**: hidden trap within 3 hexes, target loses next turn, 4 uses |
| Elf | **Starbow** | **True Shot**: RNG 4, ignores terrain cover. ARC 3, VIS 5 |
| Rogue | **Assassin** | **Ambush**: instant-kill non-specialty unit from stealth, 2 uses |
| Monk | **Iron Fist** | **Stun Strike**: target skips full next turn, 3 uses |
| Druid | **Thornweaver** | **Grow Forest**: convert up to 3 hexes to forest, 2 uses |
| Necromancer | **Death Knight** | **Reanimate**: revive adjacent dead unit as friendly for 5 turns, 3 uses |
| Bard | **Spymaster** | **Steal Gold** (10% of visible treasury, 2 uses) + **Plant Rumor** (3 uses) |
| Shaman | **Stormcaller** | **Lightning Storm**: 7 dmg (AoE bonus +1), 3-hex radius, hits friendlies. T4 |

> ⚠️ **All 12 specialty abilities above are defined in JSON but unimplemented
> in the engine** — including Warlord's Rally Command (`rally_aura_*` fields
> are set by `engine_items.py` but never read by `combat_engine.py`). See
> `comms/AEVUM_GAME_REFERENCE.md` §5 for the up-to-date implementation status.

---

## Naval Units

Shared across all clans, require a **Port** (`requires_structure: "port"`,
gated by the **Sailing** tech). See `assets/md/movement.md` and
`comms/AEVUM_GAME_REFERENCE.md` §20 for combat/movement detail.

| Unit | Cost | Turns | Notes |
|------|------|-------|-------|
| Galley | 80g | 3t | Basic transport/combat hull |
| Privateer | 100g | 4t | Requires Naval Supremacy tech |
| Warship | 150g | 5t | Heaviest hull; +1 ATK with Naval Supremacy |

---

## Monsters (Neutral)

Spawned from enclaves. Do not scale. Guards respawn every 5 turns, boss every 8.
Rank-and-file guards are re-skinned per lair theme (Goblin/Skeleton/Orc/Bog
Lurker/Spore Thrall/Reef Shark etc.) — see `comms/AEVUM_GAME_REFERENCE.md`
§15.0.1 for the full theme table. Stats below are the underlying
`monster_t1/t2/t3` budget every theme reuses.

| Name | Tier | ATK | DEF | MOV | HP | Spells | Behavior |
|------|------|-----|-----|-----|----|--------|----------|
| **Enclave Guard** | T1 | 2 | 1 | 2 | 4 | None | Patrols r=3 from enclave entry |
| **Enclave Warrior** | T2 | 4 | 3 | 3 | 8 | Slow, Mend | Patrols r=4 from enclave interior |
| **Enclave Boss** | T3 | 7 | 5 | 0 | 15 | Fireball, Heal, Slow, Silence | Stationary guardian. Does not approach egg. |

Kill loot: T1 guard 10–15g · T2 warrior 25–35g · T3 boss 50g (flat)

---

## Recruited Heroes (Willing Fighters)

Not a separate template. The 12 named NPC heroes — **Sorra the Undaunted**
(Valor), **Alethis of the Long Road** (Honour), **The Healer of the Crossroads**
(Compassion), **The Debt-Keeper** (Sacrifice), **The Broken Scholar** (Wisdom),
**Pell the Truth-Singer** (Honesty), **Aldric the Exile** (Justice), **The Deep
Wanderer** (Spirituality), **The Oathwarden** (Fortitude), **The Unnamed**
(Humility), **Scratch** (Loyalty) and **The Grove-Keeper** (Temperance) —
convert to the **recruiting clan's own unit template** when they join, then add
their personal bonuses on top (+4 to +8 HP, +1 to +6 ATK, up to +5 DEF, plus
MOV/VIS/STL where noted).

They cost no gold. The only price is finding them and **meditating the shrine of
their virtue** — an unmeditated clan is refused outright. Full roster, bonuses
and items: `assets/md/willing_fighters.md`.

---

## Starting Composition

Each clan begins the game with:
- **1 Chieftain** — at the enclave hex (free, no production cost)
- **1 Scout** — adjacent to the enclave

---

## Kill Loot

When a clan unit kills an enemy unit: **50% of that unit's production gold
cost** is awarded to the killer's treasury as battlefield salvage. The dead
clan's treasury is NOT reduced (they already spent that gold). Fallback 10g
for templateless units.

| Unit | Production cost | Kill loot |
|------|----------------|-----------|
| Scout | 50g | 25g |
| Archer / Defender | 60g | 30g |
| Common | 120g | 60g |
| Advanced | 150g | 75g |
| Specialty | 150–225g | 75–112g |
| Seeker | 300g | 150g |

---

## Stat Reference

| Stat | Meaning |
|------|---------|
| ATK | Damage per hit |
| DEF | Damage absorption |
| MOV | Hexes per turn |
| HP | Combat hit points |
| VIS | Vision radius |
| MP | Max mana |
| RNG | Attack range (1 = melee only) |
| STL | Stealth (0=visible; higher=harder to spot) |
| ARC | Arcane power (spell effectiveness + magic resist) |
| LCK | Luck (crit chance, item find) |
| RES | Resistance to status effects |
| END | Endurance (Dwarf shrine HP bonus) |
| INT | Intelligence (intel decode, Bard abilities) |
