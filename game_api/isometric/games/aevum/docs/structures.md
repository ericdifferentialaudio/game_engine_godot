# structures.md — Field Structures
*Last updated: Sprint 30 — Traps, tile improvements, and worker units removed.
Verified 08/24/2026: `assets/data/structures.json` still fully defines
trap/tripwire/rune_ward/improvements (farm/mine/lumber_post, built_by
farmer/miner/forester) — that file is NOT loaded by any engine code
(absent from `data_index.json` load_sequence) and was never pruned after
Sprint 30. `engine/engine_structures.py` (the real implementation) only
supports `watch_post` and `fort`, matching this doc. Do not use
structures.json as a reference.*

---

## Overview

Field structures are map-placed objects built by any unit using a build action. They persist on the hex until destroyed, are visible to all clans once placed, and do not require the enclave production queue.

**Permanent structures:** Watch Post and Fort (placed by build action, persist indefinitely).
**Presence structures:** Torch, Bonfire, and Camp (auto-generated from unit stationary turns).
**Terrain modification:** Road building (via presence) and Dwarf Mountain Breach.

> **Removed (Sprint 30):** Traps, Tripwires, Rune Wards, and tile Improvements (Farms, Mines, Lumber Posts) have been removed from the game along with the worker units (Farmer, Miner, Forester) that built them. The Dwarf Runesmith specialty unit still has a Ward Rune ability (a personal ability, not a placed structure from the tech tree).

---

## Watch Post

Vision anchor. The backbone of any scouting network.

| Property | Value |
|----------|-------|
| Cost | 40g |
| Build time | **2 unit-turns** (unit must remain on hex for 2 turns) |
| Requires tech | Scouting |
| Build terrain | Plains, Grasslands, Hills, Forest |
| HP | 4 |
| Vision bonus | +2 VIS radius, permanent |
| Visible to enemies | Yes — all clans see Watch Post tokens |
| Max per clan | Unlimited |

**Permanent vision:** Scout vision clears fog only while the Scout is alive and present. Watch Post vision is **permanent** — fog stays clear as long as the post stands, regardless of whether any units are nearby. A chain of Watch Posts creates a permanent observation corridor.

**Stacking:** Multiple Watch Posts stack vision independently. Two posts on adjacent hills create a wide permanent vision band.

**Destruction:** Any enemy unit spending 1 full action on the Watch Post hex destroys it. It does not fight back. The destroying unit cannot move the same turn.

**Strategic uses:**
- Chain posts along the Dragon's Keep approach — permanent Dragon trigger warning
- Post on a mountain pass entrance: reveals all units entering the pass
- Post adjacent to a rival shrine: permanent observation of meditation attempts
- Post chain toward rival enclave: economic intelligence (visible tiles = gold estimate)

---

## Fort

Combat multiplier. Makes any position significantly more defensible.

| Property | Value |
|----------|-------|
| Cost | 80g |
| Build time | **3 unit-turns** (unit must remain on hex for 3 consecutive turns) |
| Requires tech | Engineering |
| Build terrain | Plains, Grasslands, Hills |
| HP | 8 |
| Bonus (base) | +1 ATK and +1 DEF to all friendly units within radius 1 |
| Bonus (Fortification tech) | Radius expands to 2; +2/+2 on fort hex itself |
| Visible to enemies | Yes |

**Radius:** Radius 1 = the fort hex + all 6 adjacent hexes (7 hexes total). Any friendly unit on any of those hexes gets the bonus while the fort stands.

**Stacking:** Multiple forts do NOT stack bonuses. Only the highest applicable bonus applies to each unit.

**No garrison required.** The fort provides its bonus passively to all friendly units in range. It is a strategic installation, not a unit.

**Destruction:**
- Siege Engineer: 1 turn (instant with Master Engineering tech)
- Any other unit: 3 turns on the fort hex (spending all actions each turn)
- Dragon breath: does NOT destroy structures — only damages units

**Tech upgrades:**

| Tech | Effect |
|------|--------|
| Fortification (T2) | Radius expands to 2. Fort hex itself: +2 ATK/DEF. Retroactive — affects all existing forts. |
| Master Engineering (T3) | Siege Engineer demolishes forts (and all buildings) in 0 turns (instant). |

**Strategic placement:**
- On pass entrances to Dragon's Keep: rivals using that pass fight at a disadvantage
- On the egg escort path: the carrier and escorts fight at +1/+1 the whole way home
- At the entry hex of a rival shrine: any unit leaving sacred ground is immediately punished
- Across a mountain pass (3 hexes wide): a Fortification-upgraded fort at radius 2 covers the entire pass

---

## Enclave Walls

The enclave hex has a wall HP value separate from unit HP.

| Property | Value |
|----------|-------|
| Base HP | 5 |
| Walls I building | +5 HP (10 total) |
| Walls II building | +10 HP (15 total) |
| Engineering tech | +2 HP bonus |

**Repair:** The Dwarf Forge building provides +1 wall HP/turn passive repair.

**Damage sources:**
- Siege Engineer: −8 HP/turn (instant with Master Engineering tech)
- All other units: cannot damage walls directly — must breach at 0 HP
- Dragon breath: does NOT damage walls

**Enclave breach:** When wall HP ≤ 0, enemy units can step onto the enclave hex. On the turn an enemy unit is on the enclave hex at end of resolution, the clan is eliminated from the win condition. Ghost units persist. Shrine freely mediatable.

---

## Structure Placement Rules

| Structure | Who builds | Build time | Terrain | Max |
|-----------|-----------|------------|---------|-----|
| Watch Post | Any unit | 2 turns on hex | Plains, Grasslands, Hills, Forest | Unlimited |
| Fort | Any unit | 3 turns on hex | Plains, Grasslands, Hills | Unlimited |

**Multi-turn build rule:** A unit must remain on the hex for the full build duration. If the unit is killed or forced off the hex at any point, the build is cancelled and half the gold cost is lost.

**Placing while moving:** A unit can move to a hex and begin building on the same turn, but cannot attack or move further that turn.

---

## Vision Stacking — Watch Post + Scout

| Source | Vision radius |
|--------|---------------|
| Scout on hex | +4 VIS (Scout's own) |
| Watch Post | +2 VIS permanent from post position |
| Scout + Watch Post (same hex) | Scout sees 4 + post sees 2, independently |
| Watch Post on hills | +1 effective VIS (height bonus) |

**Fog persistence:** Vision from Watch Posts persists even when the placing clan has no units nearby. The post "holds" its vision. Only destroying the post removes it.

---

## Presence Structures (Torch / Bonfire / Camp)

Presence structures are **automatically generated** by units that remain stationary on a hex. No build action required, no gold cost. They grant vision and eventually spawn Scouts.

### Generation Rules

| Turns stationary | Structure created | Vision radius |
|------------------|-------------------|---------------|
| 5 turns | **Torch** | 1 hex |
| 10 turns | **Bonfire** | 2 hexes |
| 15 turns | **Camp** | 3 hexes + Scout spawned (once) |

- **Upgrade:** Structures upgrade automatically as the unit continues to hold. Torch → Bonfire → Camp.
- **Contested hex:** If units from two or more clans are stationary on the same hex, no presence structure is built or upgraded.
- **Enemy structure:** A friendly unit holding a hex with an enemy presence structure cannot build over it (only demolish first).
- **Highest turns wins:** On a hex with multiple stationary friendly units, the unit with the most turns_stationary controls the structure tier.

### Camp Scout Spawn

When a unit reaches Camp tier (15 turns stationary), **one Scout is spawned** on an adjacent free hex (once per Camp, stored on the presence structure). The Scout is a normal unit — it can move, fight, die, and costs nothing. If no adjacent hex is free, no Scout spawns (no retry).

### Camp Road Extension

Each turn a unit holds Camp tier (≥15 turns), the engine extends the road **1 hex toward the nearest notable feature** (shrine → town → castle → pass → rival enclave). Road level is set to 3 (Paved) on the extended hex. Does not enter Dragon's Keep (radius < 15 from map center).

### Presence Demolition

An enemy unit on a presence structure hex accumulates demolition progress:

| Structure type | Turns to demolish |
|----------------|-------------------|
| Torch | 1 turn |
| Bonfire | 1 turn |
| Camp | 2 turns |

On demolition, the structure becomes **Cold** (vision_radius = 0, visible to all as a ruined marker).

### Cold Re-light

A friendly unit on a Cold hex held by its own clan can **re-light** it. After 5 turns stationary on the Cold hex, the structure restores to Torch tier (vision 1). It can then be upgraded to Bonfire or Camp again by continuing to hold.

### Presence Dataclass Reference

```python
@dataclass
class PresenceStructure:
    structure_id:   str        # "pres_XXXX"
    type:           str        # "torch" | "bonfire" | "camp" | "cold"
    clan_id:        str
    q:              int
    r:              int
    turns_held:     int        # turns unit has been stationary here
    vision_radius:  int        # 0=cold, 1=torch, 2=bonfire, 3=camp
    scout_spawned:  bool = False
    destroyed_by:   Optional[str] = None
```

---

## Road Building

Roads are built automatically by units generating presence structures. No explicit road build command exists.

| Turns stationary (milestone) | Road level set | Name |
|------------------------------|----------------|------|
| 5 turns | Level 1 | Trail |
| 10 turns | Level 2 | Road |
| 15 turns | Level 3 | Paved |

- Road upgrades apply to the **unit's path_to_current_hex** (the trail of hexes the unit travelled to reach the current position).
- Road level is set to `max(existing, target)` — roads never degrade from building.
- **Mountain hexes** are skipped (no roads on impassable terrain).
- **Dragon's Keep** (radius < 15 from map center) is excluded — no roads inside the Keep.

### Road Movement Effects

| Road Level | Name | Movement cost |
|------------|------|---------------|
| 0 | None | Terrain default |
| 1 | Trail | `max(terrain_cost / 2, 1)` |
| 2 | Road | **1 for all terrain** |
| 3 | Paved | **1 for all terrain** |
| 4 | Ancient | **1 for all terrain** (world-gen only) |

Road level 2+ overrides all terrain costs to 1.

---

## Road Pillaging

An enemy unit on a road hex with a rival presence structure can degrade the road.

**Rule (LOCKED #64):** A unit spending exactly **2 consecutive turns** (`turns_stationary == 2`) on a road hex where a rival clan's presence structure exists reduces that hex's `road_level` by 1 (minimum 0). Fires once per unit per "stationary run" (resets on movement).

```
Example: Rogue holds rival Bonfire hex for 2 turns → road_level 3 → 2 (Paved → Road)
```

---

## Dwarf Mountain Breach (LOCKED #134)

A Dwarf unit (or any unit with `mountain_passable = True`) stationary on a **Mountain** hex for **3 consecutive turns** converts it to a permanent pass.

| Property | Value |
|----------|-------|
| Who | Dwarf clan units (or mountain_passable template) |
| Turns required | 3 consecutive turns stationary on Mountain hex |
| Result | Mountain hex becomes Hills terrain + road_level 2 (Road) |
| Max per clan | **2 passes per game** |
| Visibility | Pass is immediately revealed to **all clans** |

**Effect on terrain:** The hex's `terrain` changes from `mountain` to `hills`, `is_pass = True`, and `road_level = 2`. All clans can traverse it from the next turn at hills cost (MOV 2, or FREE for Ranger).

**Pass limit:** Once a Dwarf clan has created 2 passes in a game, additional Mountain hexes cannot be breached. The unit's `turns_stationary` resets to 0 after a breach to prevent double-firing.

**Strategic uses:**
- Open a second approach to Dragon's Keep that rivals haven't scouted
- Create a shortcut between two separated clan territories
- Deny rivals a defensive mountain chokepoint permanently

---

## Structure Dataclass Reference

```python
@dataclass
class StructureInstance:
    structure_id:   str       # unique instance id
    structure_type: str       # "watch_post" | "fort"
    clan_id:        str
    q:              int
    r:              int
    hp:             int
    hp_max:         int
    is_active:      bool = True
    placed_on_turn: int  = 0
    build_turns_remaining: int = 0  # >0 while under construction

    # Watch Post specific
    vis_radius:     int  = 0   # 2 for watch_post

    # Fort specific
    bonus_atk:      int  = 0
    bonus_def:      int  = 0
    bonus_radius:   int  = 1   # 1 base, 2 with Fortification tech
    is_pass:        bool = False
```

---

## Resolution Order (in Turn Cycle)

```
Step 7:  Fort bonuses applied to all units in range
Step 13: Presence tick
         - units_stationary updated (reset on movement, increment on hold)
         - Presence structures created / upgraded (Torch→Bonfire→Camp)
         - Camp Scout spawned (once per Camp, adjacent free hex)
         - Camp road extension (1 hex toward nearest feature, each ≥15t turn)
         - presence_destroy() on enemy units completing demolition
         - road_pillage_tick() — rival unit at stationary==2 degrades road_level
Step 16: Structure ticks
         - Watch Post vision updates (fog clear applied)
         - Presence structure vision applied (torch=1, bonfire=2, camp=3)
         - Build progress advances (build_turns_remaining -= 1)
         - Structures completing construction become active
         - check_dwarf_mountain_breach() — Dwarf 3t on mountain → permanent pass
```
