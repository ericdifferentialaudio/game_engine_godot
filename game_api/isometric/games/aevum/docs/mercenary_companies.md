# Mercenary Companies — Aevum: Age of Shrines
## Design Reference Document

> **`[UNWIRED]` 08/24/2026**: `engine/engine_mercenary.py` fully implements the 6
> companies below with correct data (INF gates, gold costs, sentiment, max
> contracts) and a complete API (`can_hire`/`hire_company`/`dismiss_company`/
> `get_active_contracts`). `merc_gold_drain_tick`/`merc_expiry_check` run every
> headless turn. But **nothing in the game can ever call `hire_company`** — no
> AI decision, no interior menu, no UI path exists, and no representative NPC
> is ever seeded into a town/castle (`merc_rep_npc_id`/`merc_rep_company_id`
> below are spec-only; no such fields exist on the real `TownInstance` in
> `game_state.py`). A clan can never actually acquire a mercenary contract in
> any current game. Treat this whole document as unreachable design-intent
> until hiring is wired to an actual player/AI action.

---

## Overview

Mercenary companies are **persistent world entities** — organized bands of professional fighters
who sell their services to any clan that can meet their price and their standards. They are not
desperate individuals. They have reputations to maintain, colleagues to protect, and rates that
reflect their value.

### Core Rules

- Each company tracks **`contracts_active`**: the number of clans currently hiring them
- Most companies accept **2–3 simultaneous contracts** — they split detachments, not loyalty
- Companies will not contract with **directly warring clans simultaneously** (they pick a side when
  forced; refusing the second clan triggers a sentiment drop toward the refused clan)
- **Gate requirements** must ALL be met: gold (signing fee + per-turn rate), INF score, timing window
- Sentiment is persistent per clan across the full game session
- Being **stiffed on payment** (running out of gold while a merc is active) causes the company to
  leave immediately and applies a **−15 sentiment** penalty — they remember

### Timing Windows

| Window | Turn Range | Notes |
|---|---|---|
| Early | 1–60 | All companies available except late-only |
| Mid | 40–120 | Most companies; some exclusions |
| Late | 80+ | Highest-tier companies unlock; some early ones reduce availability |
| Any | All turns | No timing restriction |

### Finding a Company

Companies are not shop items — they are **NPCs in the world**:
- Their **representative** appears in a town or castle interior as a `criminal` or `wanderer` type NPC
- The representative is seeded at world-gen into 1–2 specific locations per company
- After a contract ends, the representative returns to their seeded location after 10–15 turns
- The representative NPC can be **talked to, negotiated with, and contracted** from the interior menu

### Negotiation

```
final_rate = base_rate × sentiment_modifier × demand_modifier × timing_modifier
```

| Factor | Range | Description |
|---|---|---|
| sentiment_modifier | 0.70 – 1.50 | Clan relationship history with this company |
| demand_modifier | 1.00 – 1.25 | +5% per active contract already running |
| timing_modifier | 1.00 – 1.30 | Late-game companies cost more as endgame approaches |

A clan can **offer a signing bonus** (extra upfront gold) to reduce the per-turn rate by up to 20%.
The company will accept if the bonus covers at least 8 turns of the discounted rate.

---

## Company Profiles

---

### 1. The Broken Road Company

> *"We've fought in every terrain on this map. We charge accordingly."*
> — Harric the Blunt, company captain

**Lore**: The oldest active company in the region, founded by veterans of the Convergence Wars who
had nowhere to go after the peace. They've taken bad contracts and survived them. They're not
glamorous. They're reliable.

**Specialty**: Generalist all-rounders. No unit type restriction on hire — they field fighters,
archers, and support equally. Best choice for a clan that needs broad coverage fast.

**Max simultaneous hirers**: **3**
**Timing window**: Any (available from turn 1)
**INF requirement**: 10

**Costs**:
| Package | Signing Fee | Per-Turn Rate | Units |
|---|---|---|---|
| Solo hire (1 merc) | 100g | 15g/turn | 1 |
| Squad deal (3 mercs) | 250g | 35g/turn | 3 |
| Full detachment (5) | 400g | 55g/turn | 5 |

**Combat bonuses per unit**:
- HP: +2, ATK: +1, DEF: +1
- No terrain penalties (they've fought everywhere)

**Roster** (named individuals):

| Name | Role | Personality |
|---|---|---|
| **Harric the Blunt** | Captain, heavy fighter | Gruff, fair, deeply practical. Won't take a contract he thinks will get his people killed for no reason. |
| **Sable** | Scout/Rogue | Slippery, funny, excellent at finding exits. Never where you expect. |
| **The Rector** | Combat support | Formerly religious, now skeptical. Heals people while muttering about the futility of it. |
| **Dust** | Archer | Silent. Communicates primarily through where arrows land. Excellent at their job. |
| **Marra Two-Cups** | Wild support | Always slightly drunk. Inexplicably effective. Has survived things that shouldn't have worked. |

**Sentiment triggers**:
- +5: Paid on time for 10+ turns
- +10: Defended a Company member when they were outnumbered
- −10: Sent a Company detachment into a known suicide position without warning
- −15: Stiffed on payment
- −20: Got a named Company member killed

**Representative NPC**: Harric appears in mid-tier town pubs. Drinks slowly. Watches the room.

---

### 2. The Iron Veil

> *"We don't take every contract. We take the ones worth taking."*
> — Commander Thessaly Vor

**Lore**: A heavy infantry specialist company that built its reputation defending castle sieges. They
are expensive because they do not die cheaply. Three times in the last decade they've held a
fortification against impossible odds. That reputation is baked into their price.

**Specialty**: Siege, defense, fortification holding. Elite heavy units only. Excellent on mountains
and in castle interiors. Slow on open terrain — they're not chasers.

**Max simultaneous hirers**: **2**
**Timing window**: Mid–Late (turn 40+)
**INF requirement**: 25

**Costs**:
| Package | Signing Fee | Per-Turn Rate | Units |
|---|---|---|---|
| Solo hire (1 merc) | 250g | 25g/turn | 1 |
| Squad deal (3 mercs) | 600g | 60g/turn | 3 |

**Combat bonuses per unit**:
- HP: +4, DEF: +3, ATK: +1
- +2 DEF bonus when occupying castle/fortification hex
- −1 MOV on plains and grassland (heavy kit)

**Roster**:

| Name | Role | Personality |
|---|---|---|
| **Thessaly Vor** | Commander | Cold, precise, speaks in tactical assessments. Respects clans that plan. |
| **The Ironborn** | Heavy infantry × 2 | Nameless by choice. Identical equipment. Very unsettling. |
| **Wick** | Engineer/support | Sets traps, repairs fortifications. Cheerful about destruction. |

**Sentiment triggers**:
- +8: Used the Iron Veil specifically for fortification defense (their specialty honored)
- +5: Paid above rate voluntarily
- −10: Used them as expendable front-liners (they will note this)
- −20: Got Thessaly Vor killed (company disbands for 30 turns; reforms without her)

**Representative NPC**: Thessaly appears in castle interiors only. Never pubs.

---

### 3. The Shadow Accord

> *"We find things. We find people. We find ways in. You don't need to know more than that."*

**Lore**: Not a traditional company — the Shadow Accord is a loose network of scouts, rogues, and
information brokers who operate under a shared non-compete agreement. They don't advertise. They
don't have a banner. If you're looking for them, someone told you where to look.

**Specialty**: Intelligence, scouting, stealth operations, assassination (in NSFW/mature mode only).
They increase clan visibility significantly and can reveal fog of war zones for contracted clans.

**Max simultaneous hirers**: **2** (they will not work for opposing clans — ever)
**Timing window**: Any
**INF requirement**: 20

**Costs**:
| Package | Signing Fee | Per-Turn Rate | Notes |
|---|---|---|---|
| Scout contract | 175g | 18g/turn | 2 scouts, +VIS, fog reveal |
| Full accord | 400g | 38g/turn | 5 operators, full intel package |

**Bonuses per unit**:
- STL: +2, MOV: +2, VIS: +3
- Fog reveal: 3-hex radius per operator per turn
- +1 to all intel tier received by contracted clan while active

**Roster**:

| Name | Role | Personality |
|---|---|---|
| **The Correspondent** | Coordinator | Never gives a real name. The contact point. Knows everyone's price. |
| **Nox** | Lead scout | Moves like she's not there. Has been in every settlement on this map at least once. |
| **Pell's Ghost** | Infiltrator | Named after someone else. Won't say who. |
| **Three** | Counter-intel | Specifically watches for rival clans hiring the Accord simultaneously. Paranoid. Accurate. |

**Sentiment triggers**:
- +10: Acted on intel they provided (they measure utility)
- +8: Kept their involvement confidential
- −15: Revealed that the Shadow Accord was working for you to anyone
- −25: Both rival clans discover the Accord is working for you simultaneously

**Representative NPC**: The Correspondent appears as a `wanderer` in towns — blinks into existence
for a turn, then is gone. Hard to find. Ask the Shady Guys.

---

### 4. The Ember Tide

> *"We burn things. That's the whole pitch. You'd be surprised how often that's exactly what's needed."*
> — Cinder-Mage Vorath

**Lore**: A company of battle-mages who specialise in overwhelming offensive force. Expensive to hire,
expensive to house, they eat through magical reagents at a rate that explains the price. But when you
need an enemy position erased, not just contested, the Ember Tide is the call.

**Specialty**: AoE magical damage, area denial, siege-breaking. Terrible in close quarters.
Cannot operate in enclosed interiors without damage to the interior.

**Max simultaneous hirers**: **2**
**Timing window**: Mid–Late (turn 50+)
**INF requirement**: 30

**Costs**:
| Package | Signing Fee | Per-Turn Rate | Notes |
|---|---|---|---|
| Ember squad (2) | 350g | 35g/turn | 2 mages, AoE fire |
| Tide contract (4) | 700g | 65g/turn | Full company; area denial capability |

**Bonuses per unit**:
- ATK: +3, spell_dmg: +2
- Passive: 2-hex fire zone around each unit (enemies entering take 2 dmg)
- Cannot enter castle or town interiors without penalty

**Roster**:

| Name | Role | Personality |
|---|---|---|
| **Vorath** | Cinder-Mage, leader | Theatrical. Everything is a demonstration. Loves the word "elegant" to describe destruction. |
| **Ash** | Fire specialist | Vorath's apprentice. Quieter. More accurate. Slightly afraid of Vorath. |
| **The Pair** | Twin battle mages | Finish each other's sentences. Coordinate without speaking. Unsettling to watch. |

**Sentiment triggers**:
- +8: Used them for high-value magical engagements (target-worthy)
- +5: Praised the results publicly (they like an audience)
- −10: Used them as standard fighters (beneath their talent)
- −15: Ordered them to hold fire on a position they could have obliterated

**Representative NPC**: Vorath appears in castle libraries or scholar NPC rooms. Browsing texts
on combustion chemistry.

---

### 5. The Thornwood Riders

> *"Speed is the only defense that matters. Ask anyone we've run down."*
> — Wren, outrider captain

**Lore**: A mounted scouting and raiding company from the forested border regions. Fast, light,
and unpredictable. They don't hold positions — they strike and vanish. Best used to disrupt
rival clans rather than anchor a front line.

**Specialty**: Mobility, raiding, disruption. Best on open terrain and in forests.
Excellent for intercepting moving enemy units and denying terrain.

**Max simultaneous hirers**: **3**
**Timing window**: Early–Mid (turns 1–100; reduced availability after turn 100)
**INF requirement**: 15

**Costs**:
| Package | Signing Fee | Per-Turn Rate | Notes |
|---|---|---|---|
| Outrider (1) | 150g | 18g/turn | Fast scout unit |
| Raiding party (3) | 350g | 45g/turn | Disruption focused |

**Bonuses per unit**:
- MOV: +3, ATK: +1
- Forest movement free (no terrain cost)
- Can intercept enemy units moving through adjacent hexes (1/turn, uses reaction)

**Roster**:

| Name | Role | Personality |
|---|---|---|
| **Wren** | Outrider captain | Impatient, excellent at reading terrain, bad at sitting still. |
| **Bramble** | Scout rider | Knows every forest path on the map. Learned them personally. |
| **Old Cord** | Veteran outrider | Slow-spoken. Has been doing this for 30 years. The one who actually keeps everyone alive. |

**Sentiment triggers**:
- +5: Used them for movement/disruption (their strength)
- +8: They successfully intercepted a high-value enemy
- −8: Assigned them to hold a static fortification
- −12: Lost Wren in a preventable engagement

**Representative NPC**: Wren appears in town stables. Usually arguing with someone about horse care.

---

### 6. The Gilded Fang

> *"One contract at a time. One clan at a time. That's the whole agreement. If you have to ask why, you can't afford us."*
> — The Factor (company business agent; the fighters don't give names)

**Lore**: Nobody knows where the Gilded Fang came from. They appear when the game is nearly decided,
as if they've been watching and waiting for the moment when their involvement would be decisive.
Their fighters carry no banners. Their equipment is unmarked. They are the best at what they do,
and what they do is end wars.

**Specialty**: Everything. Elite generalists at the peak of individual capability. Each member is
the equivalent of a fully leveled clan unit with veteran bonuses.

**Max simultaneous hirers**: **1 only** — exclusive contract, period. The one clan that secures
the Gilded Fang has a significant military advantage for the duration.

**Timing window**: Late game only (turn 80+)
**INF requirement**: 40 (the highest of any company)

**Costs**:
| Package | Signing Fee | Per-Turn Rate | Notes |
|---|---|---|---|
| Full contract (6) | 1,000g | 60g/turn | Non-negotiable. All or nothing. |

A signing bonus offer will be heard but not discounted — the Factor appreciates the gesture and
notes it positively in sentiment, but the rate does not move. "The rate is the rate."

**Bonuses per unit**:
- HP: +4, ATK: +3, DEF: +2, MOV: +1
- Each unit has one veteran skill active (varies by individual — randomized at world-gen)
- No terrain penalties on any terrain type

**Roster** (6 members; names randomized at world-gen from a list of 20):
Individual members are not named publicly — the Factor introduces them by role only. Over time,
a contracted clan's players may name them themselves.

**Sentiment triggers**:
- +10: Contracted without negotiating (respect for the rate)
- +5: Paid on time without exception
- −10: Attempted to negotiate the rate
- −20: Attempted to find out who else has hired them previously
- −30: Broke the exclusivity by trying to arrange a second contract for a rival (they will leave
  and blacklist the clan permanently)

**Representative NPC**: The Factor appears as a `broker` NPC type in the highest-tier castle
accessible by turn 80+. Impeccably dressed. Unhurried. Has been there a while.

---

## Implementation Reference

### New fields required on TownInstance / CastleInstance
```python
# Per-settlement: tracks company representative spawn
merc_rep_npc_id: Optional[str] = None      # which company has a rep here
merc_rep_company_id: Optional[str] = None  # company this rep belongs to
```

### New fields required on GameState
```python
# Global mercenary company state
merc_companies: dict[str, MercenaryCompany] = field(default_factory=dict)
```

### MercenaryCompany data structure (engine_mercenary.py)
```python
@dataclass
class MercenaryCompany:
    company_id: str               # "broken_road" etc.
    name: str
    contracts_active: int         # current number of hiring clans
    max_contracts: int            # hard cap (1-3)
    available_from_turn: int      # timing window start
    inf_required: int             # minimum INF to contract
    sign_fee: int                 # upfront gold cost
    per_turn_rate: int            # gold drained each turn
    sentiment: dict[str, int]     # clan_id -> relationship score (-100 to +100)
    active_contracts: list[str]   # clan_ids currently holding contracts
    blacklist: list[str]          # clan_ids permanently refused (Gilded Fang only)
    rep_location_ids: list[str]   # town/castle IDs where rep NPC spawns
```

---

## Balance Notes

- Two clans hiring the **Broken Road Company** simultaneously is normal and intended — they're the
  common option. This creates interesting mid-game tension when a third clan tries to hire them
  and the rates are already at demand_modifier 1.10.
- The **Gilded Fang** exclusive contract is the highest-value diplomatic intelligence in the game:
  knowing which clan has them (and when their contract expires) is T3 intel worth trading for.
- A clan with **high INF but low gold** cannot buy top companies — INF is the key, gold is the lock.
  This rewards diplomatic play as a prerequisite for military hiring.
- Companies that have been **stiffed once** won't accept a contract from that clan again until
  sentiment reaches 0+ (requires doing them a favour — helping them in a world-map encounter,
  or paying their previous debt + 50g reparations).
