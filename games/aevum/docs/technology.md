# technology.md — Technology Tree
*Rewritten 08/24/2026 to match `engine/engine_tech.py::TECH_DATA` (the sole
runtime-authoritative source — `assets/data/technologies.json` is NOT
loaded by any engine code and is orphaned/stale; do not use it as a
reference). Verified field-by-field against `TECH_DATA`, `can_research()`,
`check_tech_gates()`.*

## Overview

Aevum has technologies in **4 tiers**, plus clan-specific Wonders (see
below — **Wonders are documented but `[UNIMPLEMENTED]`** in code, see note
at the end of this file). Research uses a **dedicated slot** separate from
the production queue — researching never delays unit or building
production.

Only one technology can be researched at a time. The research queue holds 1 item.

> **Removed (Sprint 30):** Advanced Trapping, Arcane Trap, Rune Ward,
> Mega-Trap, Tripwire (all trap-related tech effects removed). Diplomat
> unit removed — Scouts and Chieftains now initiate diplomacy directly.
> Lumber Posts / Farms / Mines removed with worker units. **A `logistics`
> tech appeared in older doc/data drafts but does not exist in code and
> was never implemented — do not reference it.**

---

## Research Rules

| Rule | Detail |
|------|--------|
| Research slot | 1 active research at a time, separate from production queue |
| Tier 1 | Available immediately — no prerequisites |
| Tier 2 | Requires any 2 Tier 1 techs completed |
| Tier 3 | Requires any 2 Tier 2 techs completed |
| Tier 4 | Requires any 2 Tier 3 techs completed |
| Clan Wonder `[UNIMPLEMENTED]` | Gate exists (`can_research_wonder`) but no wonder-build/apply code exists anywhere in `engine/` — see closing note |
| Passive effects | Apply immediately on research completion |
| Retroactive passives | Apply to existing units/structures immediately |

**Production acceleration:** 3 production points = −1 research turn (minimum 1 turn always). Research shares the production point pool.

**Tech not lost on enclave destruction:** Researched technologies persist even if the enclave is destroyed. A ghost clan retains all tech bonuses.

---

## The Tech Tree

*Source: `engine/engine_tech.py::TECH_DATA`. `assets/data/technologies.json`
is stale/orphaned — do not use it; it still lists Sprint-30-removed trap
techs and is not loaded by any engine code.*

```
TIER 1 (any 2 required for T2) — no prerequisites
├── Scouting          60g / 5t   → Watch Post; Scouts +1 VIS
├── Engineering       80g / 6t   → Fort; Enclave walls +2 HP
├── Military Doctrine 70g / 5t   → New units +1 HP base
└── Scholarship       60g / 5t   → Diplomat access; Contemplation Hall

TIER 2 (any 2 required for T3)
├── Fortification      120g / 9t   → Fort radius 2, fort hex +2/+2 ATK/DEF [needs: Engineering]
├── Chieftain's Code    100g / 8t   → Alliance system, Chieftain +1 ATK/MOV [needs: Military Doctrine]
├── Arcane Engineering  140g / 10t  → Magic units +1 MP regen/turn [needs: Engineering + Scholarship]
└── Sailing             120g / 8t   → Embark enabled, port +8g/turn, unlocks Port/Galley/Warship [no prereq]

TIER 3 (any 2 required for T4)
├── Grand Strategy      180g / 16t  → Choose +1 global stat, irreversible [needs: Chieftain's Code + Fortification]
├── Master Engineering  160g / 14t  → Fort +4 HP, built 1 turn faster [needs: Fortification]
├── Prophetic Sight      160g / 13t  → Meditation radius 2, see rival shrine progress [needs: Scholarship + Arcane Engineering]
└── Naval Supremacy      150g / 12t  → Warship +1 ATK, naval units +1 MOV, port +3g/turn, amphibious landing, unlocks Privateer [needs: Sailing]

TIER 4 (late-game, gated by clan.can_research_t4; also gates Wonder research)
├── Total War            220g / 22t  → All units +1 ATK; stationary units may attack twice [needs: Grand Strategy + Master Engineering]
├── Eternal Alliance      200g / 20t  → Alliance duration ×2, allied units may co-occupy hexes [needs: Chieftain's Code + Grand Strategy]
├── Enlightenment         250g / 25t  → All units +2 INT_STAT, meditation fully restores MP [needs: Prophetic Sight + Arcane Engineering]
└── Arcane Mastery        230g / 22t  → Magic units +1 more MP regen (stacks), T4/T5 spells −2 MP cost [needs: Arcane Engineering + Prophetic Sight]

CLAN WONDER `[UNIMPLEMENTED]`  — gate exists, no build/apply code exists.
```

---

## Tier 1 Technologies

### Scouting
**60g / 5t — No prerequisites**

*"Reveals the art of elevated observation."*

**Unlocks:** Watch Post field structure (40g / 2t, permanent +2 VIS radius)

**Passive (immediate, permanent):**
- All Scouts in the field +1 VIS right now
- All future Scouts produced with +1 VIS permanently

**Strategic priority:** High. Scouts are the primary gold income source (0.1g/visible tile/turn). +1 VIS on every Scout compounds throughout the game. Watch Posts create permanent observation corridors.

**Synergises with:** Mage clan (VIS shrine bonus stacks), any clan needing Dragon approach pre-scouting.

---

### Engineering
**80g / 6t — No prerequisites**

*"Mechanical mastery."*

**Unlocks:** Fort field structure (80g / 3t, +1 ATK/DEF radius 1)

**Passive (immediate, permanent):**
- Enclave walls +2 HP

**Strategic priority:** High. Gateway tech for Fortification and Arcane Engineering (both T2). The enclave wall bonus is small but the unlock value is enormous.

**Synergises with:** Fighter clan (Siege Engineer path), defensive play, shrine departure defense.

---

### Military Doctrine
**70g / 5t — No prerequisites**

*"Codified warfare."*

**Unlocks:** Chieftain production rebuild (150g / 5t — requires Barracks II also)

> The starting Chieftain is FREE. This tech enables rebuilding after the Chieftain is lost.

**Passive (immediate, permanent):**
- All **new** Clan Units produced gain +1 HP at creation. Does not retroactively affect existing units.

**Strategic priority:** Medium. Priority rises sharply if the Chieftain dies early, or if Chieftain's Code (alliance system) is on the plan.

**Required for:** Chieftain's Code (T2).

---

### Scholarship
**60g / 5t — No prerequisites**

*"Knowledge accelerates discovery."*

**Unlocks:** Diplomat access (negotiate shrine meditation rights); Contemplation Hall access at towns.

**Passive (immediate):**
- Grants `diplomat_access` — enables negotiating shrine meditation rights.
- Unlocks Contemplation Hall interaction at towns.

**Strategic priority:** High for information-focused and diplomatic clans. Free Library is immediate economic value. Contemplation Hall is the entry point to the spiritual economy — trade shrine rights without running the shrine physically.

**Note:** Diplomat unit removed (Sprint 30). Diplomacy is now initiated directly by Scouts (adjacent to rival) and Chieftains (any range).

**Synergises with:** Bard clan (INT shrine bonuses + pub intel), any clan buying shrine rights.

---

## Tier 2 Technologies

*Require any 2 Tier 1 techs completed.*

---

### Fortification
**120g / 9t — Requires: Engineering**

*"Reinforce your positions."*

**Passive (immediate, permanent, retroactive):**
- All existing and future Forts: radius expands from 1 to **2 hexes**
- Units on the fort hex itself receive **+2 ATK/DEF** instead of +1

**Strategic priority:** High once any forts are placed. Retroactive — placing a fort before this tech completes is valid; it upgrades automatically.

**Required for:** Grand Strategy (T3), Master Engineering (T3).

---

### Chieftain's Code
**100g / 8t — Requires: Military Doctrine**

*"Honour between commanders."*

**Unlocks:** Formal Alliance system.

**Passive (immediate, permanent):**
- Chieftain: +1 ATK permanently
- Chieftain: +1 MOV permanently

**Strategic priority:** Essential for any diplomatic strategy. Alliance system entirely gated behind this tech.

**Required for:** Grand Strategy (T3), Eternal Alliance (T4).

---

### Arcane Engineering
**140g / 10t — Requires: Engineering + Scholarship**

*"Magic and mechanism combined."*

**Passive (immediate, permanent):**
- All magic-capable clan units: +1 MP regen/turn, every turn, globally

**Strategic priority:** High for magic-heavy clans (Mage, Shaman, Necromancer, Cleric, Elf, Druid, Bard).

**Note:** Arcane Trap and Rune Ward removed (Sprint 30). MP regen passive retained.

**Required for:** Prophetic Sight (T3), Arcane Mastery (T4), Enlightenment (T4).

---

### Sailing
**120g / 8t — No prerequisites**

*"The sea opens."*

**Unlocks:** Port field structure, Galley, Warship production.

**Passive (immediate, permanent):**
- `embark_enabled` — clan units can embark at owned Ports
- Ports generate +8g/turn

**Strategic priority:** Required gateway for any naval strategy — no other tech unlocks Port/Galley/Warship. Coastal clans should prioritize this over T1→T2 land-only paths if the map has meaningful sea/island content.

**Required for:** Naval Supremacy (T3).

---

## Tier 3 Technologies

*Require any 2 Tier 2 techs completed.*

---

### Grand Strategy
**180g / 16t — Requires: Chieftain's Code + Fortification**

*"Mastery of the whole."*

**Passive (immediate, one-time choice, permanent, irreversible):**
- Choose one stat: all existing AND future units gain +1 to it permanently
- Valid stats: atk, def, mov, vis, hp, arc, stl, res, lck, int_stat

**Stat choice guide:**
- `atk` — strongest combat boost (affects every fight)
- `mov` — mobility across the whole clan (fastest map coverage)
- `vis` — more tiles visible = more gold (economic multiplier)
- `def` — survivability (defensive play)

**Required for:** Total War (T4), Eternal Alliance (T4).

---

### Master Engineering
**160g / 14t — Requires: Fortification**

*"Engineering perfection."*

**Passive (immediate, permanent):**
- All Forts: +4 max HP, built 1 turn faster (min 1 turn)

**Required for:** Total War (T4).

---

### Prophetic Sight
**160g / 13t — Requires: Scholarship + Arcane Engineering**

*"Sight beyond sight."*

**Passive (immediate, permanent):**
- Meditation range +1 (units can meditate from 1 hex further out — radius 2 instead of 1)
- Enemy clan shrine meditation progress becomes visible on the map

**Required for:** Enlightenment (T4), Arcane Mastery (T4).

---

### Naval Supremacy
**150g / 12t — Requires: Sailing**

*"Command of the waves."*

**Passive (immediate, permanent):**
- Warship: +1 ATK
- All naval units: +1 MOV
- Each Port: +3g/turn bonus (stacks with base Sailing bonus)
- Amphibious landing — disembarking units keep full MOV

**Unlocks:** Privateer production.

---

## Tier 4 Technologies

*Require any 2 Tier 3 techs completed. Also gates Clan Wonder research
(`can_research_wonder` — see closing note; the gate exists but wonders
themselves are `[UNIMPLEMENTED]`).*

---

### Total War
**220g / 22t — Requires: Grand Strategy + Master Engineering**

**Passive (immediate, permanent):**
- All clan units: +1 ATK permanently
- Units that have NOT moved this turn may attack twice

---

### Eternal Alliance
**200g / 20t — Requires: Chieftain's Code + Grand Strategy**

**Passive (immediate, affects future alliances only):**
- Alliance duration: ×2
- Allied clan units may occupy the same hex as your units without triggering combat

---

### Enlightenment
**250g / 25t — Requires: Prophetic Sight + Arcane Engineering**

**Passive (immediate, permanent):**
- All clan units: +2 INT_STAT permanently
- Shrine meditation now fully restores MP for magic-capable units (not just partial)

---

### Arcane Mastery
**230g / 22t — Requires: Arcane Engineering + Prophetic Sight**

**Passive (immediate, permanent):**
- All magic units: +1 additional MP regen/turn (stacks with Arcane Engineering, +2 total)
- T4 and T5 spells cost 2 fewer MP to cast

---

## Clan Wonders `[UNIMPLEMENTED]`

**Status:** Documented in `assets/data/technologies.json` and referenced by
`clans.md`/`AEVUM_GAME_REFERENCE.md`, and `ClanInstance.wonders_built` exists
as a dict field (`game_state.py`) — but **no code anywhere in `engine/`
ever builds a wonder, checks the `can_research_wonder` gate for wonder
construction, or applies any wonder's listed effect.** This table describes
the intended design, not current game behavior. Treat any wonder effect
mentioned elsewhere in the docs as aspirational until this is implemented
or the design is formally dropped.

### Wonder Reference Table (design intent, not implemented)

| Clan | Wonder | Effect |
|------|--------|--------|
| **Fighter** | Hall of Champions | All future Clan Units produced with +2 ATK |
| **Mage** | Eye in the Sky | Complete permanent map vision for Mage clan |
| **Cleric** | Cathedral of Mercy | All friendly units in visible territory +2 HP/turn |
| **Dwarf** | The Eternal Forge | All buildings complete in half turns. Production +50% |
| **Ranger** | Pathfinder's Sanctum | All terrain costs 1 for all Ranger clan units |
| **Elf** | Star Observatory | Seeker VIS +10. All Longbowmen RNG +2. Egg detectable r=16+ |
| **Rogue** | Shadow Citadel | All clan units invisible beyond 3 hexes (was 2) |
| **Monk** | Temple of Harmony | Alliance duration ×2 (×4 with Eternal Alliance). No shrine camping virtue debt |
| **Druid** | World Tree | Forest hexes +0.2g/turn. Thornbow MP regen +2 extra |
| **Necromancer** | Throne of Dust | Reanimated units last forever (not 5 turns). Return at full HP |
| **Bard** | Grand Archive | All village intel at Regular tier automatically. Planted rumors identified |
| **Shaman** | Storm Spire | All area spells +2 damage, +1 radius. Lightning Storm → 9 dmg, 5-hex radius |

---

## Optimal Research Paths

*Costs/turns below are approximate sums of `TECH_DATA` base values — actual
turns will be lower with production-point acceleration.*

### Military Path (Fighter, Dwarf)
```
T1: Engineering → Military Doctrine
T2: Fortification → Chieftain's Code
T3: Master Engineering → Grand Strategy
T4: Total War
```
~750g, ~62 turns base

### Diplomatic Path (Monk, Cleric, Bard)
```
T1: Scholarship → Military Doctrine
T2: Chieftain's Code → Arcane Engineering → Fortification
T3: Grand Strategy → Prophetic Sight
T4: Eternal Alliance
```
~930g, ~76 turns base

### Intelligence Path (Mage, Elf, Bard)
```
T1: Scouting → Scholarship
T2: Arcane Engineering → Fortification
T3: Prophetic Sight
T4: Enlightenment → Arcane Mastery
```
~1030g, ~91 turns base

### Naval Path (any coastal clan)
```
T1: Scouting → Engineering
T2: Sailing → Fortification
T3: Naval Supremacy
```
~590g, ~46 turns base

---

## Tech Dependency Graph

```
Scouting ──────────────────────────── (Watch Post, Scout +VIS)

Engineering ──┬── Fortification ──┬── Grand Strategy ──┬── Total War
              │                   │                    └── Eternal Alliance
              │                   └── Master Engineering ── Total War
              │
              └── Arcane Engineering ──┬── Prophetic Sight ──┬── Enlightenment
                        ╲              │                     └── Arcane Mastery
Scholarship ─────────────┘             └── Arcane Mastery

Military Doctrine ── Chieftain's Code ──┬── Grand Strategy
                                        └── Eternal Alliance

Sailing (no prereq) ── Naval Supremacy
```

---

## Research Queue — Code Reference

*Source: `engine/game_state.py`, `engine/engine_tech.py`.*

```python
@dataclass
class ResearchQueueItem:
    tech_id:         str
    gold_cost:       int
    turns_remaining: int
    turns_base:      int
    queued_on_turn:  int

# In ClanInstance:
research_queue:   Optional[ResearchQueueItem]   # None if idle
techs_researched: list[str]                      # completed tech ids
wonders_built:    dict[str, bool]               # wonder_id -> True [UNIMPLEMENTED — nothing writes to this]

# Gate checks (engine_tech.check_tech_gates(), run after every research completion):
clan.can_research_t2     = t1_count >= 2
clan.can_research_t3     = t2_count >= 2
clan.can_research_t4     = t3_count >= 2
clan.can_research_wonder = t3_count >= 2   # gate exists; wonder build/apply code does not
```
