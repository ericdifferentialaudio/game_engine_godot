# magic.md — Magic System
*Last updated: Sprint 30 — 24 spells; specialty-unit tier ladder; no clan immunities. Verified against engine/engine_magic.py 08/24/2026 (batch 2 compaction) — accurate, prose trimmed only.*

## Overview

Magic in Aevum is tiered by clan. Higher magic tier clans access more powerful spells but suffer exhaustion HP damage when casting T4 and T5 spells. Two clans (Fighter, Dwarf) have 0 MP and cannot cast — but **no clan is immune to any spell**. Spells land on Fighter and Dwarf normally.

Spells are committed during the action window and resolve in **Step 5** of the resolution phase — after melee and ranged combat, before trap triggers.

---

## Magic Tiers by Clan

| Clan | Magic Tier | Max spell | MP pool | Base access | Specialty unit | Specialty access |
|------|-----------|-----------|---------|-------------|----------------|-----------------|
| Fighter | 0 | None | 0 | — (cannot cast, not immune) | Siege Engineer | — |
| Dwarf | 0 | None | 0 | — (cannot cast, not immune) | Runesmith | — |
| Ranger | 1 | T1 | 4 | T1 spells | **Trapper** | **T2 spells** |
| Rogue | 1 | T1 | 4 | T1 spells | **Assassin** | **T2 spells** |
| Monk | 2 | T2 | 8 | T1 + T2 | **Iron Fist** | **T3 Heal + Blink** |
| Bard | 2 | T2 | 8 | T1 + T2 + **Charm** | **Spymaster** | **T3 Heal + Blink + Mass Charm** |
| Cleric | 3 | T3 | 14 | T1 + T2 + Heal + Blink | **High Priest** | Instant meditation |
| Druid | 3 | T3 | 14 | T1 + T2 + Heal + Blink + **Entangle** | **Thornweaver** | **Thornstorm** |
| Elf | 3 | T3 | 14 | T1 + T2 + T3 + **Fireball** | **Starbow** | **Blinding Light (T4)** |
| Shaman | 4 | T4 | 20 | T1–T3 + Fireball + **Lightning Storm + Curse + Mass Haste** | Stormcaller | Already T4 |
| Necromancer | 4 | T4 | 20 | T1–T4 incl. **Reanimate** | Death Knight | Already T4 |
| Mage | 5 | T5 | 30 | All spells | Grand Arcanist | Already T5 |

**Specialty-unit note:** Building the specialty unit (Barracks II + clan building) unlocks the next tier for that **unit only** — not the whole clan. `can_cast()` checks both `unit.clan_id` AND `unit.template_id`.

**Fireball (elf_plus):** Available to Elf, Shaman, Necromancer, Mage only. **Not** available to Cleric or Druid despite being T3.

**No immunity rule:** Fighter and Dwarf have 0 MP and cannot cast spells. They are still valid targets for all spells — Slow, Silence, Curse, etc. land normally.

---

## Mana Points (MP)

Each unit has a current MP and a max MP pool set by clan tier. MP regenerates each turn passively.

```python
def _apply_mp_regen(clan: ClanInstance, state: GameState) -> None:
    """Step 11 of resolution: regenerate MP for all clan magic units."""
    base_regen = 1   # all magic units regen 1 MP/turn
    tech_bonus = getattr(clan, 'mp_regen_bonus', 0)  # Arcane Engineering: +1
    lumber_bonus = sum(
        1 for imp in state.improvements.values()
        if imp.improvement_type == "lumber_post"
        and imp.clan_id == clan.clan_id
        and imp.is_active
    )
    total_regen = base_regen + tech_bonus + lumber_bonus

    for uid in clan.unit_ids:
        unit = state.units.get(uid)
        if not unit or not unit.is_alive:
            continue
        template = state.unit_templates.get(unit.template_id)
        if not template or template.mp_max == 0:
            continue   # no magic
        unit.mp_current = min(
            unit.mp_current + total_regen,
            unit.mp_max
        )
```

**MP sources:**
- Base regen: +1 MP/turn (all magic units)
- Arcane Engineering tech: +1 MP/turn (all magic units)
- Lumber Post improvement: +1 MP/turn per active post (global to all clan magic units)
- Mana Staff item: +4 max MP, +1 MP regen/turn (unit only)
- Archmage's Rod item: −1 MP cost on all spells cast (does not affect exhaustion)

---

## Exhaustion HP

T4 and T5 spells cause **exhaustion HP** damage to the caster. Exhaustion is the purple HP bar — it cannot be healed by any spell, item, or territory.

```python
def _apply_spell_exhaustion(caster: UnitInstance, spell: dict,
                              state: GameState) -> None:
    """Apply exhaustion HP after casting T4/T5 spell."""
    exhaust_cost = spell.get('exhaustion_hp', 0)
    if exhaust_cost <= 0:
        return

    caster.hp_exhaust = max(
        -(caster.hp_combat - 1),   # floor: total HP cannot drop below 1
        caster.hp_exhaust - exhaust_cost
    )
    # Note: exhaustion_hp in spells.json is the cost (positive = damage to caster)
    # hp_exhaust is stored as a negative offset from max HP
    # Death check: if hp_combat + hp_exhaust <= 0, unit dies
    # But exhaustion alone cannot kill (minimum 1 total HP)
```

**Exhaustion recovery:**
- +1 exhaustion HP per turn of NOT casting a T4/T5 spell
- Natural recovery only — cannot be accelerated
- Velmoor town: 25g per exhaustion HP healed (the only external healing, max 3 uses/clan/game)
- Endurance Sigil item (T3): T4 spells cause no exhaustion for the holder (T5 still full cost)

**The exhaustion floor:** A unit cannot die from exhaustion alone. If exhaustion would push total HP (combat + exhaust) to 0, exhaustion stops at the level that leaves 1 total HP. The unit is deeply exhausted but alive — one melee hit kills it.

---

## Sacred Ground Restriction

Spells cannot cross the sacred-ground boundary in either direction: cannot cast **into** it, cannot cast **from** inside it, and an AoE cannot overlap it (`_validate_spell_target`). MP and range are also checked here.

**Dragon breath exception:** physical, not a spell — NOT restricted by sacred ground; meditating units are not protected from it.

---

## Spell Resolution (Step 5)

`_resolve_spells` collects all committed spell actions, validates each (`_validate_spell_target`), sorts by tier descending (T5 first, e.g. Time Stop resolves before others act), then per spell: checks Ward block (`_spell_blocked_by_ward`), deducts MP, applies the effect, applies exhaustion.

---

## All 24 Spells — Reference

Mechanical exceptions only below; full stat table is in the Spell Summary Table further down.

### T1 — all_magic
- **Reveal** (MP2, self, 4-hex, instant) — permanent fog clear, does not reveal hidden units (Rogue stealth/Shroud).
- **Mend** (MP2, adj, instant) — +3 combat HP; cannot cure exhaustion; stacks with Cleric Free Heal (+2) = 5 HP/turn.
- **Slow** (MP2, rng3, 1t) — target MOV halved (round down). No immunity; Monk RES bonuses reduce duration.
- **Shroud** (MP3, self, 2t) — invisible beyond 2 hexes; breaks on attack.

### T2 — monk_plus (+ Trapper/Assassin templates)
- **Haste** (MP4, adj/self, 2t) — +2 MOV.
- **Silence** (MP4, rng4, 3t) — target cannot cast; does not block melee/ranged. No immunity.
- **Ward** (MP5, self, until triggered) — negates next incoming spell; does NOT block exhaustion (physical, not magical).
- **Force Pulse** (MP4, rng2, instant) — 3 physical dmg, no immunity, no exhaustion.
- **Charm** *(Bard only)* (MP5, rng3, 1t) — target moves chosen direction, cannot attack; still triggers ZoC. No immunity except already-Silenced targets.

### T3 — cleric_plus / elf_plus / druid_only / specialty
*Fireball = elf_plus. Heal/Blink = cleric_plus (+ Iron Fist/Spymaster). Entangle = Druid only. Thornstorm = Thornweaver only. Mass Charm = Spymaster only.*
- **Fireball** (MP7, rng5, 2-hex AoE, instant) — 4 fire dmg, hits ALL units incl. friendlies; suppresses Troll regen 1t. Shaman AoE +1 (5 dmg); Storm Spire wonder: 6 dmg/3-hex.
- **Entangle** *(Druid)* (MP6, rng4, 2-hex AoE, 2t) — immobilises all in area (incl. friendlies), can still attack if adjacent. Dragon: high RES, resist check; if it lands Dragon ATK=0 while entangled.
- **Thornstorm** *(Thornweaver)* (MP8, rng4, 2-hex AoE, instant+2t slow) — 4 nature dmg + −MOV 2t on survivors; combos with Entangle.
- **Heal** (MP6, rng3, instant) — +5 combat HP; cannot cure exhaustion. Arcane Vestments item (Cleric/Druid): Heal+Mend each +2.
- **Blink** (MP8, rng6, instant) — teleport self up to 6 hexes; ignores terrain/ZoC/mountains. Cannot blink into sacred ground, enemy-occupied, or already-friendly-occupied hexes.
- **Mass Charm** *(Spymaster)* (MP8, rng4, 2-hex AoE, 1t) — all enemies in radius cannot attack (no forced movement, unlike single Charm).

### T4 — necro_plus (+ Starbow specialty)
*necro_plus = Necromancer/Shaman/Mage. Blinding Light = Starbow only. All T4 spells cause exhaustion.*
- **Blinding Light** *(Starbow)* (MP12, rng6, 3-hex AoE, 2t, −1 exhaust) — −2 all stats (ATK/DEF/MOV/VIS/MP) to all in radius. Largest curse radius in game.
- **Lightning Storm** (MP12, rng6, 3-hex AoE, instant, −2 exhaust) — 6 lightning dmg all in radius (incl. friendlies); on kill +2 chain to adjacent. Shaman AoE +1 (7 dmg); Storm Spire wonder: 9 dmg/4-hex.
- **Reanimate** *(Necromancer only)* (MP10, adj, 5t, −1 exhaust) — revives adjacent defeated unit as ally at base stats (no shrine bonuses); dies permanently after duration. **Cannot reanimate:** the Dragon; units killed by Iron Fist Stun Strike; units killed by Soulreaver. Throne of Dust wonder: reanimates last forever at full HP.
- **Curse** (MP10, rng5, 5t, −1 exhaust) — target −2 all stats. No immunity; Monk RES may reduce.
- **Mass Haste** (MP14, self-origin, 3-hex AoE, 2t, −2 exhaust) — all friendlies in radius +2 MOV.
- **Phantom Clutch** *(all_magic)* (MP16, rng999 LOS, 6t, −3 exhaust) — illusory clutch; pursuing dragons chase a false location for 6 turns. Egg-race counterpart to the False Clutch item, available to every caster clan.

---

### T5 — mage_only
*Heavy exhaustion — Mage has only 3 combat HP.*
- **Meteor** (MP20, any visible hex LOS, 4-hex AoE, instant, −4 exhaust) — 8 dmg all in radius, incl. friendlies; spends whole turn. Eye in the Sky wonder lets Mage see/target anywhere.
- **Arcane Gate** (MP18, any visible hex LOS, instant, −4 exhaust) — teleport any single friendly anywhere visible; effectively once/game (MP cost).
- **Anti-Magic Field** (MP15, self-origin, 4-hex AoE, 3t, −3 exhaust) — no spells castable in area, including by the Mage themself. Dragon breath is physical — not blocked.
- **Time Stop** (MP25, global, all enemies, 1t, −5 exhaust) — all enemy units skip entire next turn (no move/attack/cast); Mage acts normally. Floor prevents death (Mage ends at 1 total HP — one melee hit kills it).

---

## Spell Summary Table (24 spells)

| Spell | Tier | Who | MP | Exhaust | Range | Area | Effect |
|-------|------|-----|----|---------|-------|------|--------|
| Reveal | 1 | all_magic | 2 | 0 | — | 4 | Fog clear 4-hex radius |
| Mend | 1 | all_magic | 2 | 0 | 1 | 1 | **+3** combat HP adjacent friendly |
| Slow | 1 | all_magic | 2 | 0 | 3 | 1 | Target MOV ÷2 for 1 turn. No immunity. |
| Shroud | 1 | all_magic | 3 | 0 | — | 1 | Caster invisible >2 hex for 2 turns |
| Haste | 2 | monk_plus + **Trapper/Assassin** | 4 | 0 | 1 | 1 | Friendly +2 MOV, 2 turns |
| Silence | 2 | monk_plus + **Trapper/Assassin** | 4 | 0 | 4 | 1 | Enemy no spells, 3 turns. No immunity. |
| Ward | 2 | monk_plus + **Trapper/Assassin** | 5 | 0 | — | 1 | Negate next incoming spell |
| Force Pulse | 2 | monk_plus + **Trapper/Assassin** | 4 | 0 | 2 | 1 | 3 physical dmg, 1 enemy, RNG 2. No immunity. |
| Charm *(Bard only)* | 2 | bard_only | 5 | 0 | 3 | 1 | Enemy moves chosen dir, no attack |
| Fireball | 3 | elf_plus | 7 | 0 | 5 | 2 | 4 fire dmg AoE 2-hex (Elf/Shaman/Necro/Mage) |
| Entangle *(Druid only)* | 3 | druid_only | 6 | 0 | 4 | 2 | All in 2-hex radius can't move, 2 turns |
| **Thornstorm** *(Thornweaver only)* | 3 | thornweaver | 8 | 0 | 4 | 2 | 4 nature dmg AoE 2-hex + −MOV 2t survivors |
| Heal | 3 | cleric_plus + **Iron Fist/Spymaster** | 6 | 0 | 3 | 1 | +5 combat HP friendly |
| Blink | 3 | cleric_plus + **Iron Fist/Spymaster** | 8 | 0 | 6 | 1 | Teleport self up to 6 hexes |
| **Mass Charm** *(Spymaster only)* | 3 | spymaster | 8 | 0 | 4 | 2 | All enemies 2-hex charmed 1t — no attack |
| **Blinding Light** *(Starbow only)* | 4 | starbow | 12 | −1 | 6 | 3 | All enemies 3-hex cursed (−2 all stats) 2t |
| Lightning Storm | 4 | necro_plus | 12 | −2 | 6 | 3 | 6 lightning dmg AoE 3-hex. On kill: +2 chain adj. |
| Reanimate *(Necro only)* | 4 | necro_only | 10 | −1 | 1 | 1 | Revive dead unit as ally, 5 turns |
| Curse | 4 | necro_plus | 10 | −1 | 5 | 1 | Target −2 all stats, 5 turns. No immunity. |
| Mass Haste | 4 | necro_plus | 14 | −2 | — | 3 | All friendlies 3-hex +2 MOV, 2 turns |
| Phantom Clutch | 4 | all_magic | 16 | −3 | 999 LOS | 1 | Illusory clutch, dragons chase false location 6t |
| Meteor *(Mage only)* | 5 | mage_only | 20 | −4 | Any | 4 | 8 dmg AoE 4-hex, any visible hex |
| Arcane Gate *(Mage only)* | 5 | mage_only | 18 | −4 | Any | 1 | Teleport any friendly to visible hex |
| Anti-Magic *(Mage only)* | 5 | mage_only | 15 | −3 | — | 4 | No spells in 4-hex, 3 turns |
| Time Stop *(Mage only)* | 5 | mage_only | 25 | −5 | — | All | All enemies skip next turn |

---

## Dragon Spell Interaction

| Spell | Effect on Dragon |
|-------|----------------|
| Slow | Reduces MOV — Dragon cannot reach units as quickly. Useful for extending Theft Run. |
| Entangle | If it lands (RES check): Dragon cannot move for 2 turns, ATK = 0 while entangled. |
| Fireball | 4 damage (−5 armour = 0 net first hit). Useful in Shaman AoE stacking. |
| Thornstorm | 4 nature damage + MOV penalty on Dragon survivors. |
| Blinding Light | −2 all Dragon stats for 2 turns. Dragon ATK drops from 9 to 7 (Awake). |
| Lightning Storm | 6 damage (−5 armour = 1 net, +2 chain if adjacent unit dies). +3 if lightning weakness. |
| Curse | −2 all Dragon stats for 5 turns. Dragon ATK drops from 9 to 7 (Awake). Worth casting. |
| Mass Haste | Affects friendlies only — reposition the assault force without exposing them to Dragon retaliation. |
| Meteor | 8 damage (−5 armour = 3 net). Best single-cast damage vs Dragon. |
| Time Stop | All rival clans and the Dragon freeze — friendly armies advance unopposed. |
| Ward | Blocks one spell-type attack. Dragon doesn't cast spells — Ward is useless against Dragon directly. |
| Anti-Magic Field | Dragon breath is physical, NOT a spell — not blocked by Anti-Magic Field. |

**Dragon breath is physical.** This is the most important rule. No spell blocks it. Anti-Magic Field does not stop it. Ward does not stop it. The only protection is being outside the cone or killing the Dragon.

---

## Spell Availability Implementation

```python
SPELL_AVAILABILITY: dict[str, list[str]] = {
    # clan_ids
    "all_magic":   ["ranger","rogue","monk","bard","cleric","druid","elf",
                    "shaman","necromancer","mage"],
    "monk_plus":   ["monk","bard","cleric","druid","elf","shaman","necromancer","mage",
                    "trapper","assassin"],          # template_ids for specialty units
    "bard_only":   ["bard"],
    "cleric_plus": ["cleric","druid","elf","shaman","necromancer","mage",
                    "iron_fist","spymaster"],       # template_ids
    "elf_plus":    ["elf","shaman","necromancer","mage"],
    "druid_only":  ["druid"],
    "necro_only":  ["necromancer"],
    "necro_plus":  ["necromancer","shaman","mage"],
    "mage_only":   ["mage"],
    # specialty-unit-only (template_id only)
    "thornweaver_only": ["thornweaver"],
    "spymaster_only":   ["spymaster"],
    "starbow_only":     ["starbow"],
}

def can_cast(unit: UnitInstance, spell_id: str, state: GameState) -> bool:
    """Returns True if this unit's clan OR template can cast this spell."""
    spell = state.spell_data.get(spell_id)
    if not spell:
        return False
    avail    = spell.get('available_to', 'none')
    eligible = SPELL_AVAILABILITY.get(avail, [])
    # Check clan_id OR template_id (specialty units access higher tiers)
    return unit.clan_id in eligible or unit.template_id in eligible

def get_available_spells(unit: UnitInstance, state: GameState) -> list[dict]:
    """Return all spells this unit can cast given current MP."""
    spells = []
    for spell in state.spell_data.values():
        if not can_cast(unit, spell['id'], state):
            continue
        if unit.mp_current < spell['mp']:
            continue
        # Check silence status
        if unit.status.get('silenced', 0) > 0:
            continue
        spells.append(spell)
    return spells
```

**Availability groups summary:**
- **all_magic** (T1): all 10 magic clans
- **monk_plus** (T2): all magic clans tier ≥2 + **Trapper** + **Assassin** template IDs
- **bard_only**: Bard clan
- **cleric_plus** (T3 heal/utility): all magic clans tier ≥3 + **Iron Fist** + **Spymaster** template IDs
- **elf_plus** (T3 offensive): Elf / Shaman / Necromancer / Mage — Fireball only
- **druid_only**: Druid — Entangle
- **thornweaver_only**: Thornweaver template — Thornstorm
- **spymaster_only**: Spymaster template — Mass Charm
- **starbow_only**: Starbow template — Blinding Light
- **necro_plus** (T4): Necromancer / **Shaman** / Mage — Lightning Storm, Curse, Mass Haste
- **necro_only**: Necromancer — Reanimate
- **mage_only** (T5): Mage
