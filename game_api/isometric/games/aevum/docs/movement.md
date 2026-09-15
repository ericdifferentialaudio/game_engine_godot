# movement.md — Movement and Resolution System

## Overview

Aevum uses **intent-based simultaneous movement** — all clans commit their action *intent* in a shared time window, then that intent executes over **N logical ticks** (N = turn duration in seconds, default 30). This is the Diplomacy commitment model with RTS-style sub-tick execution.

No clan sees what another is committing during the window. Orders are locked on submission — no changes mid-turn. But movement resolves tick-by-tick, so who moves first (determined by MOV stat) and when the AI reacts (determined by difficulty) creates genuine positional advantage without any player seeing the other's orders.

---

## The Turn Cycle

```
┌───────────────────────────────────────────────────────────┐
│  ORDER WINDOW  (30s default — config.turn_duration_seconds)│
│                                                           │
│  Human players:                                           │
│    • Issue MOVE orders (goal hex or target unit)          │
│    • Issue ATTACK orders (stationary — melee wait or      │
│        ranged fire at unit type's fire_tick)              │
│    • Issue ACTION orders (pub, meditation, lair entry…)   │
│    • Purchase items / queue production                    │
│    • Initiate diplomacy offers                            │
│    Orders lock immediately on submit. No changes after.   │
│                                                           │
│  AI clans:                                                │
│    Orders NOT submitted yet — AI commits at               │
│    ai_commit_tick based on difficulty + unit count.       │
│    (see combat.md → AI reaction budget)                   │
│                                                           │
│  Timer shows for all players. "End Turn" submits early.   │
│  Uncommitted orders discarded when timer expires.         │
└────────────────────────────┬──────────────────────────────┘
                             │
                             ▼
┌───────────────────────────────────────────────────────────┐
│  N-TICK RESOLUTION  (N ticks, 1 per logical second)       │
│                                                           │
│  FOR tick in 1..N:                                        │
│    T1. AI order submission (if tick >= ai_commit_tick)    │
│    T2. Unit movement — each unit with MOVE order and      │
│          tick aligned to their move_interval advances     │
│          1 hex; path recalculates to target's current pos │
│    T3. Adjacency/collision combat — fires immediately     │
│          when a MOVE unit enters enemy adjacent hex       │
│    T4. Ranged fire — ATTACK(ranged) units whose           │
│          fire_tick == this tick fire once (stationary)    │
│    T5. Post-tick: death checks, egg drops, lair claims    │
│  END FOR                                                  │
│                                                           │
│  (units freeze at position when tick 30 expires)          │
└────────────────────────────┬──────────────────────────────┘
                             │  all ticks complete
                             ▼
┌───────────────────────────────────────────────────────────┐
│  POST-TICK RESOLUTION  (once per turn, order unchanged)   │
│                                                           │
│  Step 1:  Spells resolve (declared this turn)             │
│  Step 2:  Trap triggers — check all units that moved      │
│  Step 3:  Fort bonuses update                             │
│  Step 4:  Alliance violation checks                       │
│  Step 5:  Meditation complete checks                      │
│  Step 6:  Status effect ticks (slow, haste, etc.)         │
│  Step 7:  Mana regeneration                               │
│  Step 8:  Exhaustion HP recovery                          │
│  Step 9:  Economy phase (gold, production, improvements)  │
│  Step 10: Production queue ticks                          │
│  Step 11: Research queue ticks                            │
│  Step 12: Structure ticks (Watch Post vision updates)     │
│  Step 13: Alliance duration ticks                         │
│  Step 14: Sentiment drift                                 │
│  Step 15: Monster patrol movement and aggro               │
│  Step 16: Shrine occupation checks (virtue debt)          │
│  Step 17: AI planning for next window                     │
│  Step 18: Win condition checks                            │
│  Step 19: Turn counter advance                            │
│  Step 20: Action queues reset for next window             │
└───────────────────────────────────────────────────────────┘
```

---

## Sub-tick Movement

### Move interval per unit

Each unit with a MOVE order advances **1 hex per move_interval ticks**:

```
move_interval = floor(N / unit.MOV)

N = 30 example:
  MOV 6 → interval  5 → moves at ticks  5, 10, 15, 20, 25, 30
  MOV 5 → interval  6 → moves at ticks  6, 12, 18, 24, 30
  MOV 4 → interval  8 → moves at ticks  8, 16, 24 (+ tick 30 if still has budget)
  MOV 3 → interval 10 → moves at ticks 10, 20, 30
  MOV 2 → interval 15 → moves at ticks 15, 30
  MOV 1 → interval 30 → moves at tick  30 only
```

A faster unit (higher MOV) commits its movement earlier in the window. **The timing of the first hex step is the primary positioning advantage** — a MOV 6 unit that committed at tick 1 is 1 hex further than a MOV 3 unit at tick 10.

### Dynamic path recalculation

After each hex step, the unit recomputes its path toward the **current position** of its goal target. This is not a static A* solved at order submission — it re-runs each tick.

```
Order: "MOVE toward Unit X"
  Tick 5:  Unit A takes 1 step toward Unit X's position at tick 5
  Tick 10: Unit A takes 1 step toward Unit X's position at tick 10
           (Unit X may have moved — path updates)
  ...
```

This means a fast victim that moved BEFORE the attacker locked in their path will have diverged from the attacker's original course. The attacker corrects automatically — but the victim has gained distance equal to their movement head start.

### Evasion window

**Head-start calculation:**
```
head_start_hexes ≈ (attacker_commit_tick − victim_commit_tick) × (victim.MOV / N)
```

If victim committed at tick 0 and attacker committed at tick 10 (reaction delay), victim has a ~1-hex head start for MOV 3, or ~2-hex head start for MOV 6. For a pursuit scenario, attacker must be faster (higher MOV) to close the gap.

### Timer expiry

When tick N expires, **all units freeze at their current hex**. No further movement resolves. No adjacency combat fires after tick N. This means:
- A pursuit that doesn't close to adjacent within N ticks produces no combat this turn
- A stationary ATTACK(melee) unit that sees no enemy enter adjacent range this turn does nothing
- Both outcomes are tactical decisions: the victim successfully evaded; the attacker chose wrong approach angle


---

## Terrain Movement Costs

### Base Costs

| Terrain | Base MOV cost | DEF bonus | Notes |
|---------|--------------|-----------|-------|
| Plains | 1.0 | 0 | Standard. Farm-able. |
| Grasslands | 1.0 | +1 | −1 VIS to units inside (tall grass). Farm-able. |
| Forest | 2.0 | +1 | Forester site. |
| Hills | 2.0 | +1 | Ranged +1 ATK firing downhill. Mine-able. |
| Mountain | Impassable | 0 | Dwarf: 2.0. Ranger: 1.0. Others: blocked. |
| Swamp | 2.0 | 0 | Rare. No improvements. |
| Sacred | 1.0 | 0 | Shrine radius 2. No combat in or out. |

### Per-Clan Movement Exceptions

| Terrain | Ranger | Dwarf | Elf | Druid | Necromancer | All others |
|---------|--------|-------|-----|-------|-------------|-----------|
| Forest | **1.0** | 2.0 | **1.0** | **1.0** | 2.0 | 2.0 |
| Hills | **1.0** | 2.0 | 2.0 | 2.0 | 2.0 | 2.0 |
| Mountain | **1.0** | **2.0** | ✗ | ✗ | ✗ | ✗ |
| Swamp | 1.0 | 2.0 | 2.0 | 2.0 | **1.0** | 2.0 |
| Grasslands | **1.0** | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |

✗ = Impassable (cannot enter hex)

**Ranger notes:** Forest, hills, grasslands, and mountain all cost 1.0. The fastest cross-terrain unit in the game.

**Dwarf notes:** Mountain costs 2.0 (base MOV 2 means ~1 hex/turn through mountains). No other clan except Ranger can enter mountain at all.

**Worker movement exceptions:** Miner workers follow the same mountain restriction as their clan (Dwarf/Ranger Miners can enter mountain; others cannot, so cannot build mountain mines).

### Movement Cost Calculation

```python
def movement_cost(unit: UnitInstance, target_q: int, target_r: int,
                  state: GameState) -> float:
    """
    Returns the movement cost to enter target hex for this unit.
    Returns float('inf') if impassable.
    """
    cell    = state.world_map.cells.get((target_q, target_r))
    if not cell:
        return float('inf')

    terrain  = cell.terrain
    clan_id  = unit.clan_id
    template = state.unit_templates.get(unit.template_id)

    # Get clan movement exceptions from terrain data
    terrain_data = state.terrain_data[terrain]
    base_cost    = terrain_data.get('move_cost')

    if base_cost is None:  # impassable for all (mountain default)
        # Check clan exception
        exceptions = state.terrain_exceptions.get(clan_id, {})
        clan_cost  = exceptions.get(terrain)
        if clan_cost is None:
            return float('inf')
        return clan_cost

    # Check for clan-specific override
    exceptions = state.terrain_exceptions.get(clan_id, {})
    return exceptions.get(terrain, base_cost)
```

---

## Action Queue

Each clan submits a `ClanActionQueue` before the window expires. This is the authoritative record of what the clan committed.

```python
@dataclass
class GameAction:
    action_type:    str           # "move" | "attack" | "spell" | "build" |
                                  # "meditate" | "produce" | "diplomacy" | "end_turn"
    unit_id:        Optional[str]
    target_q:       Optional[int]
    target_r:       Optional[int]
    target_unit_id: Optional[str]
    spell_id:       Optional[str]
    structure_type: Optional[str]
    metadata:       dict          # extra params (item_id, tech_id, etc.)

@dataclass
class ClanActionQueue:
    clan_id:      str
    turn_number:  int
    actions:      list[GameAction]   # ordered list
    submitted:    bool               # True once committed
    submitted_at: float              # time.monotonic() — for latency tracking
```

**Action order within a clan's queue matters:** If a unit moves then attacks, that sequence is honoured. If a unit attacks then tries to move away, the attack fires but movement may be blocked by the combat result (unit killed, ZoC, etc.).

**Uncommitted clans:** If a clan's timer expires without submitting, their `ClanActionQueue.actions` is treated as empty — all their units hold position and take no actions that turn. AI clans always submit before timeout.

---

## Movement Resolution (Step 1)

### Path Validation

Before movement executes, the engine validates each move path:

```python
def validate_move(unit: UnitInstance, path: list[tuple[int,int]],
                  state: GameState) -> list[tuple[int,int]]:
    """
    Validate and trim a move path to what the unit can actually traverse.
    Returns the valid portion of the path (may be shorter than requested).
    """
    mov_remaining = state.effective_stat(unit, 'mov')
    valid_path    = []

    for q, r in path:
        cost = movement_cost(unit, q, r, state)
        if cost == float('inf'):
            break   # impassable — stop here
        if cost > mov_remaining:
            break   # not enough MOV remaining
        mov_remaining -= cost
        valid_path.append((q, r))

    return valid_path
```

### Simultaneous Move Execution

All validated paths execute at once. Units teleport to their final hex positions simultaneously (the engine doesn't animate intermediate hexes for collision purposes — only the final positions matter for collision detection).

```python
def _resolve_movement_all(state: GameState) -> None:
    """Step 1: Move all units to their committed destinations simultaneously."""
    for clan_id, queue in state.action_queues.items():
        for action in queue.actions:
            if action.action_type != "move":
                continue
            unit = state.units.get(action.unit_id)
            if not unit or not unit.is_alive:
                continue

            path = [(action.target_q, action.target_r)]  # simplified: direct move
            valid = validate_move(unit, path, state)
            if valid:
                unit.q, unit.r = valid[-1]
```

---

## Collision Detection and Resolution (Steps 2–3)

After all units have moved to their final positions, the engine scans for shared hexes.

### The Four Collision Cases

**Case 1: Attacker arrives at a hex the defender was already occupying**

The standard attack case. Attacker moved in, defender stayed (or moved to a different hex). Combat resolves normally in Step 3.

```
Before:  A at (5,5)    B at (6,5)
Action:  A moves to (6,5)
After:   A and B both at (6,5) → combat
```

**Case 2: Two units from different clans move INTO the same hex simultaneously**

Both units end on the same hex. Simultaneous damage exchange — both take damage at the same time based on their ATK/DEF. Neither has initiative advantage.

```
Before:  A at (5,5)    B at (7,5)
Action:  A moves to (6,5)  AND  B moves to (6,5)
After:   Both at (6,5) → simultaneous exchange
```

This is the most tactically interesting case: if you know an enemy is moving toward the same hex, you can commit to the collision or try to predict and avoid.

**Case 3: Two friendly units move to the same hex**

Blocked. The second unit (lower initiative: Scout < Archer < Clan Unit < Chieftain) stays on its origin hex. The first unit completes its move. Player sees a "blocked" notification.

**Case 4: Two units pass through each other's hexes (swap)**

If unit A moves from hex X to hex Y, and unit B moves from hex Y to hex X in the same turn, they pass through each other. No collision — they swap positions without combat.

```
Before:  A at (5,5)    B at (6,5)
Action:  A moves to (6,5)  AND  B moves to (5,5)
After:   A at (6,5)    B at (5,5) — no combat
```

This "pass-through" rule enables tactical evasion: if you predict an enemy is charging through your position, you can move through them to avoid combat.

### Collision Processing

```python
def _detect_collisions(state: GameState) -> list[tuple]:
    """
    Step 2: Find all hexes occupied by units from more than one clan.
    Returns list of (q, r, [unit_ids]) for each collision hex.
    """
    hex_occupants: dict[tuple, list[str]] = {}
    for uid, unit in state.units.items():
        if not unit.is_alive:
            continue
        key = (unit.q, unit.r)
        hex_occupants.setdefault(key, []).append(uid)

    collisions = []
    for (q, r), unit_ids in hex_occupants.items():
        clans_present = set(
            state.units[uid].clan_id for uid in unit_ids
            if state.units[uid].clan_id != "monster"
        )
        monster_units = [uid for uid in unit_ids
                         if state.units[uid].clan_id == "monster"]
        # Collision if: 2+ enemy clans, or any clan unit + monster
        if len(clans_present) > 1 or (len(clans_present) >= 1 and monster_units):
            collisions.append((q, r, unit_ids))

    return collisions

def _resolve_melee_combat(state: GameState, collisions: list) -> None:
    """
    Step 3: Resolve all collisions. Simultaneous damage exchange.
    """
    for q, r, unit_ids in collisions:
        units_here = [state.units[uid] for uid in unit_ids if state.units[uid].is_alive]
        # Group by clan
        by_clan: dict[str, list] = {}
        for u in units_here:
            by_clan.setdefault(u.clan_id, []).append(u)

        # Each pair of opposing clans exchanges damage simultaneously
        clan_ids = list(by_clan.keys())
        for i in range(len(clan_ids)):
            for j in range(i + 1, len(clan_ids)):
                _exchange_damage(by_clan[clan_ids[i]],
                                 by_clan[clan_ids[j]], state, q, r)
```

---

## Zone of Control (ZoC)

A unit exerts Zone of Control over all 6 adjacent hexes while it is alive. Moving through a ZoC hex (adjacent to an enemy unit) costs additional movement.

### ZoC Rules

- **Entering** a ZoC hex: +1 MOV cost (on top of terrain cost)
- **Passing through** multiple ZoC hexes: cumulative cost
- **Engaging** (moving onto an enemy's hex): triggers combat regardless of MOV remaining
- **Withdrawing** from a ZoC hex requires spending the extra cost

### ZoC Exceptions

| Unit / Situation | ZoC rule |
|-----------------|---------|
| Monk Clan Unit | Does NOT trigger ZoC on others. Enemies do not pay extra MOV moving adjacent to Monk. |
| Chieftain | Ignores ZoC entirely — moves freely through enemy-adjacent hexes. |
| Diplomat | Ignores ZoC entirely — moves freely through contested territory. |
| Ranger Ghost Step | Ignores ZoC from non-adjacent enemies (enemies more than 1 hex away don't slow the Ranger). |
| Scout | Does not trigger ZoC (too fast/evasive — enemies don't need extra MOV moving adjacent to a Scout). |
| Monster patrols | Trigger ZoC normally. |

```python
def zoc_cost(unit: UnitInstance, from_q: int, from_r: int,
             to_q: int, to_r: int, state: GameState) -> float:
    """
    Additional ZoC movement cost for moving from (from_q,from_r) to (to_q,to_r).
    Returns 0 if no ZoC applies.
    """
    template = state.unit_templates.get(unit.template_id)

    # Units that ignore ZoC entirely
    if getattr(template, 'ignores_zoc', False):
        return 0.0

    # Check destination hex: is it adjacent to any living enemy unit?
    enemy_clans = [cid for cid in state.clans if cid != unit.clan_id]
    for eq, er in hex_disk(to_q, to_r, 1):
        if (eq, er) == (to_q, to_r):
            continue
        occupants = state.units_at(eq, er)
        for occ in occupants:
            if occ.clan_id in enemy_clans and occ.is_alive:
                occ_template = state.unit_templates.get(occ.template_id)
                # Check if occupant triggers ZoC
                if getattr(occ_template, 'triggers_zoc', True):
                    # Ranger Ghost Step: only adjacent enemies trigger ZoC
                    if hasattr(template, 'ghost_step') and template.ghost_step:
                        if hex_dist(from_q, from_r, eq, er) > 1:
                            continue   # non-adjacent enemy — no ZoC for Ranger
                    return 1.0   # +1 MOV cost for this step

    return 0.0
```

---

## Sacred Ground Movement

The sacred radius (2 hexes around any shrine) has special movement rules:

- **Entry:** Any unit can enter sacred ground freely. No MOV penalty.
- **Exit:** Any unit can exit sacred ground freely. Protection ends immediately on exit.
- **Combat:** No combat of any kind within the sacred radius. Attacks targeting units inside or from inside are blocked.
- **Spells:** Cannot be cast into or out of the sacred radius in either direction.
- **Meditation:** Unit must spend 1 full turn stationary inside the sacred radius. Protection is total while meditating.

```python
def is_in_sacred_ground(q: int, r: int, state: GameState) -> bool:
    """Returns True if hex is within radius 2 of any shrine."""
    return any(
        hex_dist(q, r, shrine.q, shrine.r) <= 2
        for shrine in state.shrines.values()
    )

def can_attack(attacker: UnitInstance, defender: UnitInstance,
               state: GameState) -> bool:
    """Returns False if either unit is in sacred ground."""
    if is_in_sacred_ground(attacker.q, attacker.r, state):
        return False
    if is_in_sacred_ground(defender.q, defender.r, state):
        return False
    return True
```

---

## Pass-Through Rule (Swap Prevention Detail)

The pass-through rule requires careful handling: the engine must detect swap-moves before collision resolution runs.

```python
def _detect_swaps(state: GameState,
                  pre_move_positions: dict[str, tuple]) -> set[tuple[str,str]]:
    """
    Detect unit pairs that swapped positions this turn.
    These should NOT trigger combat even though they share hexes mid-move.
    Returns set of (unit_id_a, unit_id_b) pairs that swapped.
    """
    swaps = set()
    unit_ids = list(state.units.keys())
    for i, uid_a in enumerate(unit_ids):
        for uid_b in unit_ids[i+1:]:
            ua, ub = state.units[uid_a], state.units[uid_b]
            if not ua.is_alive or not ub.is_alive:
                continue
            pre_a = pre_move_positions.get(uid_a)
            pre_b = pre_move_positions.get(uid_b)
            # Swap: A moved to where B was, B moved to where A was
            if pre_a == (ub.q, ub.r) and pre_b == (ua.q, ua.r):
                swaps.add((uid_a, uid_b))
    return swaps
```

---

## Simultaneous Movement — Why It Matters

**Shrine departure ambush:** A clan positions units on the ring-3 hexes (just outside sacred ground) while the meditating unit completes. In sequential turns, the defender goes first and perfectly blocks the exit. In simultaneous resolution, the meditating unit commits its departure direction and the defender commits its blocking position at the same time. If both commit, there may be a collision. If the meditator guesses the defender's block direction and moves the other way, they escape cleanly. This is the game's signature recurring tension.

**Seeker approach:** A Seeker approaching the Dragon's Keep from the same direction as a rival Seeker: who gets there first? Both committed their movement at the same time. If they end on the same hex, it's a collision (different clans). If one committed further than the other, no collision. The player must predict rival commitment.

**Dragon breath preview:** Dragon announces breath direction 1 turn ahead (when Awake, not Enraged). All players see the preview cone. In the next commitment window, every unit in that cone's path must decide: stay and take 5 damage, or commit a move out of the cone. The Dragon re-evaluates facing at the start of the resolution phase — so if the Seeker moved last turn, the cone may have shifted. This creates a commitment dilemma: move based on the previewed cone (which might change) or trust the preview.

---

## Input System — Action Types

```python
class ActionType(Enum):
    MOVE_UNIT       = "move"
    ATTACK_UNIT     = "attack"
    BEGIN_MEDITATION= "meditate"
    CAST_SPELL      = "spell"
    BUILD_STRUCTURE = "build_structure"
    PLACE_IMPROVEMENT = "place_improvement"
    QUEUE_UNIT      = "produce_unit"
    QUEUE_BUILDING  = "produce_building"
    QUEUE_RESEARCH  = "research"
    OPEN_DIPLOMACY  = "diplomacy"
    END_TURN        = "end_turn"
    DESELECT        = "deselect"
```

### Key Bindings (default)

| Key | Action |
|-----|--------|
| M | Move unit mode |
| A | Attack unit mode |
| S | Begin meditation (selected unit at shrine) |
| 1–9 | Spell quickcast |
| P | Open Enclave Panel |
| I | Open inventory / items |
| D | Open Diplomacy panel |
| ↩ / Enter | End Turn (submit queue) |
| Esc | Deselect / close panel |
| Arrow keys | Pan camera |
| Scroll wheel | Zoom |

**WASD is NOT used for camera pan** — A and S are action keys. Arrow keys pan camera.

---

## Multiplayer Action Queue Submission

In multiplayer (v2 implementation), the host resolves all state:

```
Host:   Broadcast TURN_START(turn_n, timestamp)
        Set deadline = timestamp + timer_seconds + 2   (2s latency buffer)
        Accept ActionQueue from each client until deadline
        If client hasn't submitted by deadline: treat as empty queue (units hold)
        Resolve all queues simultaneously
        Broadcast TURN_STATE(resolved_GameState)

Client: Receive TURN_START
        Display commitment window (timer_seconds)
        Player queues actions
        Submit ClanActionQueue to host
        Receive TURN_STATE — update display
```

The `ClanActionQueue.submitted_at` timestamp is logged for latency tracking. Games where average latency exceeds 3s should warn players.

---

## Unit Movement Limits Summary

| Unit | MOV | Terrain exceptions | ZoC |
|------|-----|--------------------|-----|
| Scout | 6 | None | Does not trigger |
| Archer | 3 | None | Triggers |
| Clan Unit (base) | 3 | Per clan | Triggers |
| Ranger Clan Unit | 5 | Forest/hills/grasslands/mountain all cost 1 | Ghost Step |
| Chieftain | 5 | None | Ignores ZoC |
| Diplomat | 4 | None | Ignores ZoC |
| Farmer/Miner/Forester | 3 | None | Triggers |
| Seeker | 4 (3 with egg) | None | Triggers |
| Dwarf Clan Unit | 2 | Mountain: 2.0 | Triggers |
| Necromancer | 3 | Swamp: 1.0 | Triggers |

Shrine bonuses apply at unit creation and stack with base MOV. Ranger shrine (+MOV) gives the Ranger clan unit MOV 6 if meditated by a Ranger.