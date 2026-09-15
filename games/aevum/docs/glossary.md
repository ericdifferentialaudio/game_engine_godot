# glossary.md — Aevum Abbreviations & Terms
*Last updated: Sprint 35 — Virtue Spread + Seeker Holy Ward*

---

## Stat Abbreviations

| Abbreviation | Full Name | Meaning |
|-------------|-----------|---------|
| **ATK** | Attack | Damage dealt per hit in combat. Formula: `damage = max(1, ATK − DEF + luck_roll)` |
| **DEF** | Defence | Damage absorbed before HP is lost. Subtracts from incoming ATK. |
| **MOV** | Movement | Number of hexes a unit can move per turn. Terrain costs reduce this. |
| **HP** | Hit Points | Total health. Death when `hp_combat + hp_exhaust ≤ 0`. |
| **VIS** | Vision | Radius in hexes a unit can see. Determines fog of war and gold income. |
| **MP** | Mana Points | Spell fuel. Regenerates +1/turn (base). Zero for non-magic units. |
| **RNG** | Range | Maximum attack range in hexes. 1 = melee only. |
| **ARC** | Arcane | Arcane power. Increases spell damage dealt and reduces spell damage received. |
| **ARC(elem)** | Elemental Arcane | Subtype of ARC that only boosts area-of-effect (AoE) spells. From Shaman shrine. |
| **ATK(weak)** | Attack (Weakened) | Conditional ATK bonus: activates only against enemies below 50% HP. From Necromancer shrine. |
| **STL** | Stealth | Stealth rating. Higher STL = spotted later by enemies. Rogue base STL 3. |
| **LCK** | Luck | Luck modifier. Shifts combat luck roll. +1 LCK shifts roll from [−1,0,+1] toward [0,+1,+2]. |
| **RES** | Resistance | Status effect resistance. Higher RES = Slow/Curse/Silence land less often. |
| **INT** | Intelligence | Intel processing speed. Faster fragment decoding. +1 fragment/village at higher INT. |
| **END** | Endurance | Dwarf shrine bonus stat key (`end`). Adds +1 max HP to all Dwarf clan units per shrine meditated. Still active — `clan.shrine_bonuses["end"]` is the live field. The Sprint-30 note calling this deprecated was incorrect; `end` is distinct from `hp` and remains in use as of Sprint 34. |

---

## Gameplay Abbreviations

| Abbreviation | Full Name | Meaning |
|-------------|-----------|---------|
| **AoE** | Area of Effect | A spell or ability that affects all units within a radius, not just one target. Example: Fireball hits all units in a 2-hex radius. Lightning Storm hits a 3-hex radius. |
| **ZoC** | Zone of Control | A hex costs +1 MOV to enter if it is adjacent to a living enemy unit. Chieftain and Monk ignore ZoC. |
| **LoS** | Line of Sight | Whether ranged attacks can reach a target. Mountains block LoS. Forests do not. |
| **HP** | Hit Points | See Stat Abbreviations. |
| **MP** | Mana Points | See Stat Abbreviations. |
| **NPC** | Non-Player Character | Town inhabitants (barkeeps, healers, sages). Run by the engine. |
| **AI** | Artificial Intelligence | The computer-controlled clan logic in `engine_ai.py`. |

---

## Turn Resolution Terms

| Term | Meaning |
|------|---------|
| **Tick** | One logical second of a turn's resolution window. N ticks = one full turn (N = `config.turn_duration_seconds`, default 30). |
| **N-tick model** | The sub-turn resolution system. Movement, combat, and AI reactions all resolve tick-by-tick within the turn window, not in one instantaneous batch. |
| **Order window** | The input phase where players commit their unit orders. Timer is visible to all players. "End Turn" submits early. Orders lock immediately on submission — no changes after. |
| **MOVE order** | An intent order: unit advances toward a goal hex or target unit over N ticks. Cannot fire ranged in the same turn. |
| **ATTACK order (melee)** | Unit stays stationary. Waits for an enemy to enter an adjacent hex during any tick, then exchanges damage simultaneously. |
| **ATTACK order (ranged)** | Unit stays stationary. Fires once at its type-specific `fire_tick`. Cannot move in the same turn. |
| **ACTION order** | Non-combat order (pub conversation, meditation start, lair entry, item equip, diplomacy). Unit is stationary for the specified tick cost. |
| **move_interval** | Ticks between each 1-hex step: `floor(N ÷ unit.MOV)`. MOV 6 = every 5 ticks; MOV 3 = every 10 ticks. |
| **fire_tick** | The specific tick at which a ranged unit fires its one ranged attack per turn. Archer=10, Starbow=8, Ranger=12, Shaman=15 (at N=30). |
| **ai_tick_decide** | ⚠️ REVISED 08/29/2026 — the single engine API for AI decision-making (`engine_ai.ai_tick_decide()`), called every tick per AI clan. Replaces the old flat `ai_commit_tick` model (single submission tick per difficulty). Builds a per-turn worklist (one entry per cluster + one per solo unit) and drains it incrementally, spending `_AI_TICKS_PER_DECISION[difficulty]` ticks per entry. See `assets/md/ai_system.md` §"Layer 4". |
| **Head start** | Positional advantage gained by a unit that committed movement earlier in the tick window. Equal to the reaction gap × unit.MOV ÷ N hexes. |
| **Moving-target penalty** | Ranged damage multiplier applied when the target moved before the fire_tick: 0 ticks moved = ×1.0; 1-3 = ×0.85; 4-7 = ×0.65; 8+ = ×0.40. |
| **Intent lock** | Once a unit's order is submitted, it cannot be changed mid-turn. The path to the goal updates dynamically each tick, but the goal itself does not. |
| **Evasion** | When a victim's head start (from faster MOV or earlier commit) prevents the attacker from reaching adjacent within N ticks. No combat fires this turn. |
| **Cognitive overload (AI)** | ⚠️ REVISED 08/29/2026 — when an AI clan's decision worklist (one entry per cluster/solo unit) does not fully drain before tick N under `ai_tick_decide()`'s metering, remaining clusters/units get no fresh order and idle/hold stale orders this turn. Scales with difficulty (`_AI_TICKS_PER_DECISION`) and cluster count — a clan with many small clusters is more likely to run out of budget than one with fewer, larger clusters, which is why clustering exists. |

---

## Combat Terms

| Term | Meaning |
|------|---------|
| **Melee** | Hand-to-hand combat between units on adjacent hexes. |
| **Ranged** | Attack from a distance (RNG > 1). Cannot fire into/out of sacred ground. |
| **Simultaneous exchange** | Both attacker and defender deal damage at the same time. Dead units still deal their hit. |
| **Luck roll** | Random modifier [−1, 0, +1] added to each damage calculation. LCK stat shifts this range. |
| **hp_combat** | The green (healable) portion of HP. Can be restored by healing, regen, Cleric, items. |
| **hp_exhaust** | The purple (non-healable) portion of HP. From casting T4/T5 spells. Only recoverable at Velmoor (25g/HP). |
| **Exhaust floor** | A unit cannot die from exhaust damage alone — minimum 1 total HP always. |
| **Dark Resonance** | Necromancer passive: +1 ATK per 3 units that die anywhere on the map (cumulative). |
| **Ancient Armour** | Dragon ability: negates first 5 incoming damage per turn (threshold resets each turn). |

---

## Shrine & Meditation Terms

| Term | Meaning |
|------|---------|
| **Mantra** | The secret word required to meditate a shrine. 100-word pool, 8 drawn per game. |
| **Meditation** | The act of sitting at a shrine for N turns to gain its permanent bonus. Unit is immune while meditating inside sacred ground. |
| **Sacred ground** | The 7 hexes within radius 2 of a shrine. No combat, no spells in or out. |
| **Avatar** | Status achieved when a clan accumulates full shrine credits (via physical meditation, virtue spread, or both). Required before Seeker can be built. |
| **Seeker** | The end-game unit that carries the dragon egg. Requires Avatar + Sanctum building. |
| **Shrine camping** | Remaining on the shrine hex for 3+ consecutive turns. Costs a permanent −1 random stat. |
| **Virtue debt** | Penalty applied to a clan that attacks a meditating unit. −1 ATK to the attacking clan. |
| **Kinship pair** | Two clans with a special affinity (e.g. Fighter/Elf, Cleric/Necromancer). Start with 0.55–0.70 confidence on each other's shrine. |
| **Contemplation Hall** | ⚙️ Not yet implemented. Town building where shrine meditation credits can be bought/sold. Requires Scholarship tech. |
| **Virtue Spread** | Sprint 35 mechanic. When a shrine is physically meditated, it radiates virtue outward at +1 hex per 3 turns (activated radius). Unmeditated shrines also spread passively at +1 hex per 20 turns. A clan whose enclave falls within the radius earns an Avatar credit for that shrine **without a stat bonus** — physical meditation is still required for the +1 clan / +2 personal stat bonuses. |
| **Activated spread** | Virtue radiating from a physically meditated shrine. Budget grows **1.0 point per turn** from `shrine.virtue_activated_turn`, spent against a terrain+road Dijkstra cost — it is NOT a uniform radius. Roads carry virtue 2 hex/turn, plains 1.0, forest 0.5, swamp 0.33, hills 0.25, mountain 0.1; sea is impassable. Corrected 08/2026 (previously documented as "+1 hex per 3 turns" with a `shrine.virtue_radius` field that the code does not use). |
| **Passive spread** | Safety-net virtue from never-meditated shrines, so no clan is permanently locked out. Budget `(turn // 20) * 0.5`, spent against the same terrain-impeded costs. Corrected 08/2026 (previously "+1 hex per 20 turns" via `shrine.virtue_passive_radius`). |
| **Virtue credit** | An Avatar credit granted via spread rather than physical meditation. Tracked in `clan.shrine_records[shrine_id].virtue_received`. Counts toward Avatar threshold; grants **no stat bonus**. |
| **Willing Fighter** | One of the 12 named NPC heroes (Sorra the Undaunted, The Oathwarden, Scratch, …). Hidden in interiors, free to recruit, roughly double a normal unit's stats — but will only join a clan that has **meditated the shrine of their virtue**. See `assets/md/willing_fighters.md`. |
| **Virtue gate** | The recruitment condition on a Willing Fighter: `check_virtue_match()` requires completed meditation at `shrine_<clan>` for that hero's virtue. Per clan; a rival's meditation does not count. |
| **Holy Ward** | Sprint 35 mechanic. When a Seeker picks up the Dragon's Egg, it gains 5 turns of immunity to dragon breath damage. This prevents the dragon from instantly killing the egg carrier before delivery can complete. Tracked on `unit.holy_ward_turns`; decremented each turn in `unit_tick`. |

---

## Tech & Production Terms

| Term | Meaning |
|------|---------|
| **T1/T2/T3** | Technology tiers (Tier 1, 2, 3). Higher tiers require lower tiers completed first. |
| **Wonder** | Clan-unique end-game building. Requires any 3 T3 techs + 300g + 10 turns. |
| **Production queue** | The list of buildings/units being built at the enclave. Default 3 slots, 4 with Logistics tech. |
| **Research slot** | Separate from the production queue. One tech researched at a time. |
| **Production points** | Bonus resource for accelerating builds. 3 points = −1 build turn (minimum 1 turn). |

---

## Map Terms

| Term | Meaning |
|------|---------|
| **Hex** | A single hexagonal map cell. The map is 100×100 axial hex grid. |
| **Axial coordinates** | The (q, r) coordinate system for hex positions. |
| **Fog of war** | The unexplored/unseen areas of the map. Only visible hexes generate gold. |
| **Enclave** | Each clan's home base. Has walls, production queue, gold treasury. |
| **Sacred ground** | See Shrine & Meditation Terms. |
| **Pass** | A mountain hex carved into hills to allow passage. Set at world generation. |
| **Corner bonus** | One of four permanent bonuses at map corners. First clan to hold the corner for 1 turn claims it. See `assets/data/corner_bonuses.json`. |
| **Veil Hex** | The central area (radius 15–20 from map center) where the dragon egg is hidden. |
| **Dragon's Keep** | The area near the dragon lairs. |

---

## Economy Terms

| Term | Meaning |
|------|---------|
| **g** | Gold — the game's currency. |
| **Gold cap** | Maximum gold a clan can hold. Default 500g, 750g with Vault. |
| **Visible tile income** | +0.1g per visible tile per turn. Main income source for all clans. |
| **Battlefield salvage** | Kill reward: 50% of the dead unit's production cost goes to the killer. |

---

## AI Terms

| Term | Meaning |
|------|---------|
| **Goal stack** | The list of AI objectives in priority order (e.g. advance_shrines, attack_rival, scout_map). |
| **Aggression weight** | How strongly a clan prioritises combat. Fighter/Dwarf/Necromancer have higher weights. |
| **Night phase** | Turns 15–25 of each 40-turn cycle. Necromancer and Rogue get combat bonuses. |
| **Kinship affinity** | AI tendency to prefer alliances with the kinship pair clan. |

---

## Magic Tier Reference *(Sprint 30 — 24 spells; specialty-unit tier ladder; no clan immunities)*

| Base Tier | Clans | Base Access | Specialty Unit | Specialty Upgrade |
|-----------|-------|------------|---------------|------------------|
| T0 (none) | Fighter, Dwarf | — (0 MP, not immune) | Siege Eng / Runesmith | — |
| T1 | Ranger, Rogue | T1 spells | **Trapper / Assassin** | **→ T2 spells** |
| T2 | Monk, Bard | T1+T2 | **Iron Fist / Spymaster** | **→ T3 spells + exclusive** |
| T3 | Cleric, Druid, Elf | T1+T2+T3 | **Thornweaver / Starbow** | **→ exclusive T3/T4 spell** |
| T4 | Necromancer, **Shaman** | T1–T4 (Shaman: weather/storm identity, 20 MP) | Death Knight / Stormcaller | Already T4 |
| T5 | Mage | T1–T5 | Grand Arcanist | Already T5 |

### Spell Quick Reference (Sprint 30 — 24 spells)

| Spell | T | MP | Who | Key Effect |
|-------|---|----|-----|-----------|
| Reveal | 1 | 2 | all magic | Fog clear 4-hex radius |
| Mend | 1 | 2 | all magic | +3 combat HP adjacent friendly |
| Slow | 1 | 2 | all magic | Enemy MOV ÷2 for 1 turn. No immunity. |
| Shroud | 1 | 3 | all magic | Caster invisible >2 hex, 2 turns |
| Haste | 2 | 4 | monk+ · **Trapper · Assassin** | Friendly +2 MOV, 2 turns |
| Silence | 2 | 4 | monk+ · **Trapper · Assassin** | Enemy no spells, 3 turns. No immunity. |
| Ward | 2 | 5 | monk+ · **Trapper · Assassin** | Negate next incoming spell |
| Force Pulse | 2 | 4 | monk+ · **Trapper · Assassin** | 3 physical dmg, 1 enemy, RNG 2. No immunity. |
| Charm *(Bard only)* | 2 | 5 | Bard | Enemy moves chosen dir, no attack |
| Heal | 3 | 6 | cleric+ · **Iron Fist · Spymaster** | +5 combat HP friendly, RNG 3 |
| Blink | 3 | 8 | cleric+ · **Iron Fist · Spymaster** | Teleport self up to 6 hexes |
| Fireball | 3 | 7 | elf+ (Elf/Shaman/Necro/Mage) | 4 fire dmg AoE 2-hex |
| Entangle *(Druid only)* | 3 | 6 | Druid | All in 2-hex radius can't move, 2 turns |
| **Thornstorm** *(Thornweaver only)* | 3 | 8 | Thornweaver template | 4 nature dmg AoE 2-hex + −MOV 2t survivors |
| **Mass Charm** *(Spymaster only)* | 3 | 8 | Spymaster template | All enemies in 2-hex charmed 1t (no attack) |
| **Blinding Light** *(Starbow only)* | 4 | 12 | Starbow template | All enemies in 3-hex cursed (−2 all stats) 2t. −1 exhaust |
| Lightning Storm | 4 | 12 | necro+ (**incl. Shaman**) | 6 dmg AoE 3-hex. On kill: +2 chain to adj. −2 exhaust |
| Reanimate *(Necro only)* | 4 | 10 | Necro | Revive dead as ally, 5 turns. −1 exhaust |
| Curse | 4 | 10 | necro+ | −2 all stats, 5 turns. No immunity. −1 exhaust |
| Mass Haste | 4 | 14 | necro+ | All friendlies 3-hex +2 MOV, 2 turns. −2 exhaust |
| Meteor *(Mage only)* | 5 | 20 | Mage | 8 dmg AoE 4-hex, any visible hex. −4 exhaust |
| Arcane Gate *(Mage only)* | 5 | 18 | Mage | Teleport any friendly to visible hex. −4 exhaust |
| Anti-Magic *(Mage only)* | 5 | 15 | Mage | No spells in 4-hex, 3 turns. −3 exhaust |
| Time Stop *(Mage only)* | 5 | 25 | Mage | All enemies skip next turn. −5 exhaust |

**Specialty-unit spell note:** `can_cast()` checks `unit.clan_id OR unit.template_id`. Building the specialty unit (Barracks II + clan building) unlocks the next tier for that unit only — not the whole clan.

**Spell availability groups:** all_magic · monk_plus (+ Trapper/Assassin templates) · cleric_plus (+ Iron Fist/Spymaster templates) · elf_plus · druid_only · thornweaver_only · spymaster_only · starbow_only · **necro_plus (Necro + Shaman + Mage)** · mage_only

---

## File Reference

| File | What it documents |
|------|------------------|
| `assets/md/glossary.md` | This file — abbreviations and terms |
| `assets/md/units.md` | Full unit roster, stats, abilities |
| `assets/md/willing_fighters.md` | The 12 NPC heroes, virtue gates, recruitment |
| `assets/md/structures.md` | Watch Post, Fort, field structures |
| `assets/md/technology.md` | Full tech tree with all effects |
| `assets/data/shrines.json` | Shrine definitions (names, bonuses, placement) |
| `assets/data/corner_bonuses.json` | Corner bonus definitions (4 map corners) |
| `assets/data/clans.json` | Clan stats, shrine bonuses, specials |
| `assets/data/virtues.json` | 12 virtues, kinship pairs, companion terrain |
| `assets/data/unit_types.json` | Unit base stats |
| `comms/AEVUM_GAME_REFERENCE.md` | Master reference — load at start of every session |
