# combat.md — Combat Resolution

## Overview

Combat in Aevum is fast and brutal. The core formula is simple — ATK minus DEF plus a luck roll — but modifiers from terrain, forts, shrines, items, and special abilities layer on top. All combat resolves simultaneously within each turn's resolution phase. Neither side acts first within a simultaneous exchange.

---

## Turn Resolution — N-Tick Model

Each game turn is divided into **N logical ticks**, where N equals the turn timer duration in seconds (configured in `config.json`, default **30 ticks = 30 seconds**).

Each tick represents 1 logical second. The client renders smooth animation between ticks via linear interpolation — visual framerate and logical tick rate are independent.

### Order types (mutually exclusive per unit per turn)

| Order | Effect | Movement? | Combat? |
|-------|--------|-----------|---------|
| **MOVE** | Unit advances toward a goal hex or target unit | Yes (per tick interval) | Only if adjacency triggers it |
| **ATTACK (ranged)** | Unit stays stationary, fires once at a specific tick | No | Yes — ranged fire at `fire_tick` |
| **ATTACK (melee)** | Unit stays stationary, waits for enemy to enter adjacent | No | Yes — if enemy enters adjacent hex |
| **ACTION** | Non-combat action (pub, meditation, item equip, diplomacy) | No | No |

A unit cannot move AND fire in the same turn. Choosing to fire means giving up repositioning. Choosing to move means losing the ranged attack.

### Unit movement per tick

```
tick_interval = N ÷ unit.MOV   (ticks between each 1-hex step)

N = 30 example:
  MOV 6 → moves at ticks  5, 10, 15, 20, 25, 30   (every 5s)
  MOV 5 → moves at ticks  6, 12, 18, 24, 30        (every 6s)
  MOV 4 → moves at ticks  8, 15, 23, 30            (every 7-8s)
  MOV 3 → moves at ticks 10, 20, 30               (every 10s)
  MOV 2 → moves at ticks 15, 30                   (every 15s)
  MOV 1 → moves at tick  30 only                  (last second only)
```

After each hex step, the unit's path **recalculates** toward its committed goal target's **current position**. If the target moved since last tick, the attacker adjusts course automatically.

### Adjacency-triggered melee combat

When a MOVE-order unit steps into a hex **adjacent to a live enemy**, a simultaneous melee exchange fires immediately at that tick:

- Both units deal damage simultaneously (`resolve_hit()` — unchanged)
- Neither side has first-strike advantage from adjacency alone
- **Timing advantage:** If the victim committed movement earlier and has already moved away, the attacker arrives at an empty hex — no combat fires that tick
- If both survive the exchange, both continue their remaining movement intent in subsequent ticks

A unit with a melee **ATTACK** order (stationary) deals its exchange when any enemy enters its adjacent hex during any tick. This is the "hold position" defensive order.

### Ranged fire tick

Ranged units fire **once per turn** at a fixed tick based on unit type:

| Unit | `fire_tick` (N=30) | Notes |
|------|-------------------|-------|
| Archer | 10 | Standard draw-aim-release |
| Starbow | 8 | Faster specialty unit |
| Ranger (ranged) | 12 | Slower but more accurate |
| Shaman lightning | 15 | Charge time |

The LoS check and target position are evaluated at `fire_tick` — the target's position **at that moment**, not at order submission.

### Moving-target damage penalty

Ranged damage is reduced if the target has moved since the turn started. **Ticks moved before `fire_tick`** determines the multiplier:

| Target ticks moved before fire | Damage multiplier |
|-------------------------------|-------------------|
| 0 (stationary) | ×1.0 (full) |
| 1–3 ticks | ×0.85 |
| 4–7 ticks | ×0.65 |
| 8+ ticks | ×0.40 (minimum) |

A MOV 6 target that committed movement at tick 0 has already moved at tick 5 — the archer fires at tick 10 when the target has moved 2 times → ×0.85 damage. A MOV 3 target that committed early moves at tick 10 → fires exactly as they step → ×0.85. A stationary target takes full damage.

This rewards fast player decision-making: committing movement early protects your units from full ranged volleys.

### AI reaction budget (REVISED 08/29/2026)

⚠️ The flat per-difficulty commit-tick model described here previously
(`engine_ai._get_ai_commit_tick`, `_AI_COMMIT_TICK = {"expert":0, "hard":2,
"normal":5, "medium":8, "easy":15}`) is GONE — it only delayed WHEN a
whole-clan plan was written, but the plan itself was still built instantly
and completely in one call. It has been replaced by
`engine_ai.ai_tick_decide(state, clan_id, tick)`, which METERS the actual
decision computation per tick, per cluster/unit-group — not just the
timing of a single commit.

Each AI clan builds a per-turn worklist (one entry per cluster + one per
solo unit) on the first tick of a new turn, then drains it incrementally,
spending `_AI_TICKS_PER_DECISION[difficulty]` ticks per entry (plus a mild
per-member surcharge):

```
_AI_TICKS_PER_DECISION = {"expert": 1, "hard": 2, "normal": 3, "medium": 5, "easy": 8}
```

If tick N is reached before the worklist empties, the remaining
clusters/units get **no fresh actions dispatched this turn** — the literal
"ran out of time to think" case, and the reason forming fewer/larger
clusters helps a clan decide more of itself before the clock runs out. See
`assets/md/ai_system.md` §"Layer 4" for the full design.

In the **headless simulator**: with a small early-game roster, most clans
still fully drain their worklist most turns even at `easy`, so simulator
chaos remains a floor relative to real play — but a clan managing MANY
small clusters can now genuinely run out of tick budget before every
cluster gets a fresh decision, unlike the old model where every difficulty
decided its whole roster equally fast once its single commit tick arrived.

### Action tick costs (non-combat)

Non-combat actions occupy the unit for a fixed number of ticks (stationary):

| Action | Tick cost |
|--------|-----------|
| Pub conversation (NPC) | 8 ticks |
| Shrine meditation start | 5 ticks (commits the unit) |
| Lair entry | 3 ticks |
| Item equip | 2 ticks |
| Trade with friendly clan | 4 ticks per item |

A unit committed to a pub conversation at tick 1 cannot reposition until tick 9 — a tactical vulnerability against fast-moving enemies.

### Full tick resolution loop (per turn)

```python
# Pseudocode — gameplay_engine.py
# NOTE (08/29/2026): the real per-tick AI call is engine_ai.ai_tick_decide()
# (metered worklist drain, not a single "if tick >= commit_tick" gate) — see
# assets/md/ai_system.md §"Layer 4" for the actual implementation.
for tick in range(1, N + 1):

    # Step 1: AI decision metering (real: ai_tick_decide(state, clan_id, tick))
    for clan in state.ai_clans:
        ai_tick_decide(clan.clan_id, state, tick)

    # Step 2: Unit movement (MOVE-order units only)
    for unit in units_with_move_order_aligned_to_tick(tick, state):
        new_hex = advance_one_hex_toward_goal(unit, state)   # path recalculates
        if enemy_in_adjacent(new_hex, state):
            resolve_simultaneous_exchange(unit, enemy, state)  # adjacency combat
        elif enemy_on_hex(new_hex, state):
            resolve_collision_exchange(unit, enemy, state)     # same-hex combat

    # Step 3: Ranged fire (ATTACK-order ranged units at their fire_tick)
    for unit in ranged_units_firing_this_tick(tick, state):
        target = state.units[unit.attack_target_id]
        ticks_moved = count_ticks_moved(target, tick)
        mult = moving_target_multiplier(ticks_moved)
        if has_line_of_sight(unit, target, state):
            dmg = resolve_hit(unit, target, state) * mult
            apply_damage(target, dmg, state)

    # Step 4: Post-tick checks
    check_deaths(state)
    check_egg_drops(state)
    check_lair_claims(state)

# Post-ticks (once per turn, unchanged)
economy_phase(state)
status_decay(state)
regen(state)
fog_update(state)
```

---

## Core Formula


```
damage = max(1, (attacker_ATK − defender_DEF) + luck_roll)
```

| Component | Value |
|-----------|-------|
| `attacker_ATK` | `effective_stat(attacker, 'atk')` |
| `defender_DEF` | `effective_stat(defender, 'def')` |
| `luck_roll` | Random choice from `[−1, 0, +1]` |
| Minimum damage | **1** — always at least 1 damage lands |

**Druid shrine modification:** If the attacking clan has meditated the Druid shrine (+LCK bonus), the luck roll shifts to `[0, +1, +2]`. Average damage increases by 1.

```python
def resolve_hit(attacker: UnitInstance, defender: UnitInstance,
                state: GameState) -> int:
    """
    Compute damage from one attack. Returns HP lost by defender.
    Called once per attacking unit per combat resolution step.
    """
    import random

    atk      = state.effective_stat(attacker, 'atk')
    def_stat = state.effective_stat(defender, 'def')

    # Luck roll: standard or Druid-boosted
    attacker_clan = state.clans[attacker.clan_id]
    druid_bonus   = attacker_clan.shrine_bonuses.get('lck', 0)
    if druid_bonus > 0:
        luck = random.choice([0, +1, +2])    # Druid shrine shifts luck up
    else:
        luck = random.choice([-1, 0, +1])    # standard

    # Terrain DEF bonus (defender's terrain)
    defender_cell = state.world_map.cells.get((defender.q, defender.r))
    terrain_def   = _terrain_def_bonus(defender_cell.terrain if defender_cell else "plains")

    # Fort bonus (defender in fort radius)
    fort_def = _fort_bonus(defender, state, 'def')

    total_def = def_stat + terrain_def + fort_def

    damage = max(1, (atk - total_def) + luck)

    # Monster weakness bonus
    damage = _apply_monster_weakness(attacker, defender, damage, state)

    return damage
```

---

## Terrain DEF Bonuses

The **defender** gains a DEF bonus based on the terrain of their current hex.

| Terrain | DEF bonus | Notes |
|---------|-----------|-------|
| Plains | +0 | No bonus |
| Grasslands | +1 | Tall grass conceals. Also −1 VIS to units inside. |
| Forest | +1 | Cover. Does NOT block ranged line of sight. |
| Hills | +1 | High ground. Ranged attackers firing downhill get +1 ATK. |
| Mountain | +0 | Combat only allowed for Dwarf/Ranger on mountain hexes. |
| Swamp | +0 | No bonus. |
| Sacred | +0 | No combat permitted in sacred ground radius. |

```python
TERRAIN_DEF_BONUS = {
    "plains":     0,
    "grasslands": 1,
    "forest":     1,
    "hills":      1,
    "mountain":   0,
    "swamp":      0,
    "sacred":     0,
}

def _terrain_def_bonus(terrain: str) -> int:
    return TERRAIN_DEF_BONUS.get(terrain, 0)
```

### Hills Downhill Bonus

When an **archer or ranged unit** fires **downhill** (attacker is on hills, target is on lower ground), the attacker gains **+1 ATK**:

```python
def _ranged_terrain_atk_bonus(attacker: UnitInstance, defender: UnitInstance,
                               state: GameState) -> int:
    """Returns ATK bonus for ranged units firing from hills downhill."""
    TERRAIN_HEIGHT = {"mountain": 3, "hills": 2, "plains": 1,
                      "grasslands": 1, "forest": 1, "swamp": 1, "sacred": 1}
    atk_cell = state.world_map.cells.get((attacker.q, attacker.r))
    def_cell  = state.world_map.cells.get((defender.q, defender.r))
    if not atk_cell or not def_cell:
        return 0
    atk_h = TERRAIN_HEIGHT.get(atk_cell.terrain, 1)
    def_h = TERRAIN_HEIGHT.get(def_cell.terrain, 1)
    if atk_h > def_h and attacker.template_id in ("archer", "starbow"):
        return 1   # downhill bonus
    return 0
```

---

## Fort Bonus

Units within a **Fort's radius** gain +1 ATK and +1 DEF while the fort is active (owned by their clan and not destroyed).

| Tech level | Fort radius | Bonus |
|-----------|-------------|-------|
| Base (Engineering tech) | 1 hex | +1 ATK, +1 DEF |
| Fortification tech | 2 hexes | +1 ATK, +1 DEF in radius 2; +2/+2 on fort hex itself |

**Stacking:** Multiple forts do NOT stack. If a unit is within range of two friendly forts, only the highest applicable bonus applies.

```python
def _fort_bonus(unit: UnitInstance, state: GameState, stat: str) -> int:
    """
    Returns the highest fort bonus applicable to this unit for the given stat.
    stat: 'atk' or 'def'
    """
    best = 0
    for struct in state.structures.values():
        if struct.structure_type != "fort":
            continue
        if struct.clan_id != unit.clan_id:
            continue
        if struct.hp <= 0:
            continue   # destroyed

        dist   = hex_dist(unit.q, unit.r, struct.q, struct.r)
        radius = struct.bonus_radius

        if dist > radius:
            continue

        # On fort hex itself with Fortification tech: higher bonus
        if dist == 0 and struct.bonus_atk > 1:
            bonus = struct.bonus_atk if stat == 'atk' else struct.bonus_def
        else:
            bonus = 1   # standard fort bonus

        best = max(best, bonus)

    return best
```

---

## Simultaneous Exchange

When two units from different clans end on the same hex (Case 2 collision from movement.md), or when both commit attacks against each other in the same resolution phase, both take damage at the same time.

**Sequence:**

1. Compute damage from A → B using `resolve_hit(A, B)`
2. Compute damage from B → A using `resolve_hit(B, A)`
3. Apply both simultaneously — B's HP does not affect A's damage calculation
4. Check for deaths after both are applied

This means a unit that would die from the exchange still deals its damage. A wounded unit attacking a full-HP unit is not disadvantaged in the same turn. Plan accordingly.

```python
def _exchange_damage(group_a: list, group_b: list,
                     state: GameState, q: int, r: int) -> None:
    """
    Simultaneous damage exchange between two groups on the same hex.
    Each unit in group_a attacks each unit in group_b and vice versa.
    For simplicity: strongest unit in each group attacks first within group.
    All damage computed before any HP is applied.
    """
    # Compute all pending damage first
    damage_to_b: list[tuple] = []   # (target_unit, damage)
    damage_to_a: list[tuple] = []

    for a in group_a:
        if not a.is_alive: continue
        # Pick primary target in group_b (lowest HP first)
        target = min((u for u in group_b if u.is_alive),
                     key=lambda u: u.hp_combat, default=None)
        if target:
            dmg = resolve_hit(a, target, state)
            damage_to_b.append((target, dmg))

    for b in group_b:
        if not b.is_alive: continue
        target = min((u for u in group_a if u.is_alive),
                     key=lambda u: u.hp_combat, default=None)
        if target:
            dmg = resolve_hit(b, target, state)
            damage_to_a.append((target, dmg))

    # Apply all damage simultaneously
    for unit, dmg in damage_to_b + damage_to_a:
        unit.hp_combat -= dmg
        _check_death(unit, state)
```

---

## Ranged Combat

Ranged attacks resolve in **Step 4** of the resolution phase, after melee collisions.

### Line of Sight

Ranged attacks require unobstructed line of sight to the target:

| Obstruction | Effect |
|-------------|--------|
| Mountain hex | **Blocks** line of sight completely |
| Forest hex | Does NOT block LoS. Target in forest gains +1 DEF from terrain (not from obstruction). |
| Other units | Do NOT block LoS (arrows fly over heads) |
| Sacred ground | Cannot fire INTO sacred ground or OUT of it (see Sacred Ground section in movement.md) |

```python
def has_line_of_sight(attacker: UnitInstance, defender: UnitInstance,
                      state: GameState) -> bool:
    """
    Returns True if attacker has LoS to defender.
    Traces a hex line from attacker to defender; blocked by mountain.
    """
    # Get hexes on the line between attacker and defender
    line = _hex_line(attacker.q, attacker.r, defender.q, defender.r)
    for q, r in line[1:-1]:   # exclude start and end hexes
        cell = state.world_map.cells.get((q, r))
        if cell and cell.terrain == "mountain":
            return False
    return True

def _hex_line(q0: int, r0: int, q1: int, r1: int) -> list[tuple[int,int]]:
    """Returns hexes along a straight line from (q0,r0) to (q1,r1)."""
    n    = hex_dist(q0, r0, q1, r1)
    if n == 0:
        return [(q0, r0)]
    results = []
    for i in range(n + 1):
        t    = i / n
        # Cube coordinate interpolation
        cx   = q0 + (q1 - q0) * t
        cz   = r0 + (r1 - r0) * t
        cy   = -cx - cz
        rq   = round(cx)
        rr   = round(cz)
        ry   = round(cy)
        # Fix rounding
        q_diff = abs(rq - cx)
        r_diff = abs(rr - cz)
        y_diff = abs(ry - cy)
        if q_diff > r_diff and q_diff > y_diff:
            rq = -rr - ry
        elif r_diff > y_diff:
            rr = -rq - ry
        results.append((rq, rr))
    return results
```

### Ranged Attack Execution

```python
def _resolve_ranged_combat(state: GameState) -> None:
    """Step 4: All ranged units fire at their committed targets."""
    for clan_id, queue in state.action_queues.items():
        for action in queue.actions:
            if action.action_type != "attack":
                continue
            attacker = state.units.get(action.unit_id)
            defender = state.units.get(action.target_unit_id)
            if not attacker or not defender:
                continue
            if not attacker.is_alive or not defender.is_alive:
                continue

            template = state.unit_templates.get(attacker.template_id)
            rng      = state.effective_stat(attacker, 'rng')

            # Must be ranged (rng > 1) for this step
            if rng <= 1:
                continue

            dist = hex_dist(attacker.q, attacker.r, defender.q, defender.r)
            if dist > rng:
                continue   # out of range

            # Sacred ground check
            if not can_attack(attacker, defender, state):
                continue

            # Line of sight check
            if not has_line_of_sight(attacker, defender, state):
                continue

            # Compute damage
            atk_bonus = _ranged_terrain_atk_bonus(attacker, defender, state)
            dmg       = resolve_hit(attacker, defender, state)
            dmg      += atk_bonus

            # Elfbow: ignore forest DEF
            if attacker.item and attacker.item.item_id == "elfbow":
                cell = state.world_map.cells.get((defender.q, defender.r))
                if cell and cell.terrain == "forest":
                    dmg += 1   # cancel the forest DEF bonus it already got

            # Starbow: True Shot — ignore all terrain DEF
            if template and getattr(template, 'true_shot', False):
                cell = state.world_map.cells.get((defender.q, defender.r))
                if cell:
                    dmg += TERRAIN_DEF_BONUS.get(cell.terrain, 0)  # add back what was subtracted

            defender.hp_combat -= dmg
            _check_death(defender, state)
```

---

## Monster Weakness Bonus

When a clan has learned a monster type's weakness through pub intel, attacks exploiting that weakness deal bonus damage.

```python
def _apply_monster_weakness(attacker: UnitInstance, defender: UnitInstance,
                             damage: int, state: GameState) -> int:
    """
    Apply +3 damage if attacking a monster's known weakness.
    Apply −1 damage if attacking a known resistance.
    Does nothing if defender is not a monster or weakness is unknown.
    """
    if defender.clan_id != "monster":
        return damage

    lair = _find_lair_for_unit(defender, state)
    if not lair:
        return damage

    # Check if attacker's clan knows this weakness
    known = lair.weakness_known_by.get(attacker.clan_id, False)
    if not known:
        return damage   # unknown — normal damage

    weakness = lair.weak_to
    resistance = lair.resists

    # Determine attack type
    attack_type = _classify_attack(attacker, state)

    if attack_type == weakness:
        return damage + 3   # known weakness exploited
    elif attack_type == resistance:
        return max(1, damage - 1)   # known resistance — still min 1

    return damage

def _classify_attack(attacker: UnitInstance, state: GameState) -> str:
    """Classify what type of damage this attacker deals."""
    template = state.unit_templates.get(attacker.template_id)
    # Item overrides
    if attacker.item:
        if attacker.item.item_id in ("flameblade",):   return "fire"
        if attacker.item.item_id in ("frostblade",):   return "cold"
        if attacker.item.item_id in ("soulreaver",):   return "soulreaver"
        if attacker.item.item_id in ("longbow","elfbow","stormbow","shadowbow"): return "arrows"
    # Clan / unit type
    if template and template.template_id in ("archer", "starbow"): return "arrows"
    if attacker.clan_id == "cleric":  return "holy"
    if attacker.clan_id == "shaman":  return "lightning"
    return "physical"
```

---

## Dragon Combat Mechanics

The Dragon follows the same `resolve_hit()` formula as all other units, but with two special passives.

### Ancient Armour

The Dragon's Ancient Armour negates the first **5 incoming damage per turn** (threshold, applied before DEF calculation).

```python
def _dragon_take_damage(dragon: DragonInstance, damage: int,
                        state: GameState) -> int:
    """Apply damage to Dragon, accounting for Ancient Armour."""
    armour_remaining = max(0, 5 - dragon.armour_absorbed_this_turn)
    absorbed         = min(armour_remaining, damage)
    net_damage       = damage - absorbed
    dragon.armour_absorbed_this_turn += absorbed
    dragon.hp        = max(0, dragon.hp - net_damage)

    # Check enraged threshold
    if dragon.hp <= dragon.hp_max // 2 and not dragon.enraged:
        dragon.enraged = True
        state.announce("The Dragon is enraged!", event="DRAGON_ENRAGED")

    if dragon.hp <= 0:
        dragon.state = "retreating"

    return net_damage   # actual damage dealt

# Reset per turn
def _reset_dragon_armour(dragon: DragonInstance) -> None:
    """Called at start of each resolution phase."""
    dragon.armour_absorbed_this_turn = 0
```

**Implication:** A single unit dealing 4 damage (strong for a non-Chieftain) contributes 0 net damage against the Dragon in the same turn it hasn't yet been hit. You need **multiple units attacking simultaneously** — 4 units each dealing 4 damage = 16 total, 5 absorbed = 11 net. The Dragon has 25 HP. At this rate: ~3 turns.

### Fire Breath

Resolves at the end of Step 5 (after spells) in the resolution phase. Hits ALL units in the cone — no clan discrimination.

```python
def _dragon_breath(dragon: DragonInstance, state: GameState) -> None:
    """
    Dragon breath: 5-hex directional cone, 5 HP damage, all units.
    Cone faces direction toward dragon.facing target.
    """
    cone = _compute_breath_cone(dragon.q, dragon.r,
                                dragon.facing_q, dragon.facing_r)
    for q, r in cone:
        for unit in state.units_at(q, r):
            if not unit.is_alive:
                continue
            unit.hp_combat = max(0, unit.hp_combat - 5)
            if unit.hp_combat + unit.hp_exhaust <= 0:
                _kill_unit(state, unit, killer="dragon_breath")

def _compute_breath_cone(dq: int, dr: int,
                          fq: int, fr: int) -> list[tuple[int,int]]:
    """
    Returns the 5 hexes in the breath cone.
    Cone: 3 hexes directly ahead + 2 at 60° off-facing.
    facing direction = (fq, fr) unit vector.
    """
    # Primary direction: 3 hexes in facing direction
    cone = []
    for dist in range(1, 4):
        cone.append((dq + fq * dist, dr + fr * dist))
    # Side hexes at 60° offset (hex neighbour directions)
    side_dirs = _hex_side_directions(fq, fr)
    for sd in side_dirs[:2]:
        cone.append((dq + fq + sd[0], dr + fr + sd[1]))
    return [(q, r) for q, r in cone if (q, r) in state.world_map.cells]

# Breath frequency
# AWAKE: fires every 2 turns. Announced 1 turn ahead (preview cone).
# ENRAGED: fires every turn. No preview.
```

### Dragon Fight Summary

| Mechanic | Value |
|----------|-------|
| Dragon ATK | 9 (11 Enraged) |
| Dragon DEF | 6 |
| Dragon HP | 25 |
| Ancient Armour | −5 incoming per turn (threshold before DEF) |
| Breath damage | 5 HP, 5-hex cone, all units |
| Breath frequency | Every 2t (Awake), every 1t (Enraged) |
| Enrage threshold | ≤ 50% HP (≤ 12 HP) |
| Effective HP (sustained) | ~35–40 HP equivalent due to armour |
| Minimum force to kill in 3t | 4+ units, 10+ effective DPS each turn |

Dragon weakness (+3 damage if known): `ice`, `soulreaver`, `ancient` — one of these is active this game, seed-determined. Pub Confidant tier reveals which.

---

## Death and Kill Rewards

```python
def _check_death(unit: UnitInstance, state: GameState,
                 killer: Optional[UnitInstance] = None) -> None:
    """Called after each damage application. Handles death and rewards."""
    if unit.hp_combat + unit.hp_exhaust > 0:
        return   # still alive

    unit.is_alive = False

    # 5% treasury transfer on enemy unit kill
    if killer and killer.clan_id != unit.clan_id:
        killer_clan  = state.clans[killer.clan_id]
        victim_clan  = state.clans.get(unit.clan_id)
        if victim_clan and victim_clan.clan_id != "monster":
            transfer = int(victim_clan.gold * 0.05)
            victim_clan.gold    = max(0, victim_clan.gold - transfer)
            killer_clan.gold    = min(killer_clan.gold + transfer,
                                      killer_clan.gold_cap)

    # Necromancer Dark Resonance: +1 ATK per 3 deaths
    for cid, clan in state.clans.items():
        if cid == "necromancer" or any(
            t.template_id == "necromancer" for t in [
                state.unit_templates.get(u.template_id)
                for u in state.units.values()
                if u.clan_id == cid and u.is_alive
            ]
        ):
            state.total_deaths += 1

    # Gold reward for monster kills
    if unit.clan_id == "monster" and killer:
        lair = _find_lair_for_unit(unit, state)
        if lair:
            _check_lair_cleared(lair, state, killer.clan_id)

    # Egg drop if Seeker carrying it
    if unit.carrying_egg:
        _drop_egg(unit, state)

    # Log kill
    state.current_turn_log.kills.append({
        "victim_unit_id":  unit.unit_id,
        "victim_clan_id":  unit.clan_id,
        "killer_clan_id":  killer.clan_id if killer else "dragon_breath",
        "turn":            state.turn_number,
    })
```

---

## HP System — Two Bars

Every unit has two separate HP pools:

```python
unit.hp_combat:  int   # green bar — healable
unit.hp_exhaust: int   # purple bar — NOT healable (except Velmoor town)
unit.hp_max:     int   # max combat HP
```

**Death condition:** `unit.hp_combat + unit.hp_exhaust <= 0`

**Exhaustion floor:** Exhaustion cannot reduce total HP below 1 alone. If exhaustion would kill the unit without combat damage, stop at 1 total.

**Combat HP recovery:**
- In visible (friendly) territory: +1/turn
- + Cleric adjacent: +2/turn
- + Cathedral of Mercy wonder: +3/turn total (stacks)
- At enclave hex: +2/turn
- Healing Potion: +3 one-time
- Town healer: 10g per HP

**Exhaustion HP recovery:**
- Not casting T4/T5 spells: +1 exhaust HP/turn automatically
- Velmoor town healer: 25g per exhaust HP (only source)

---

## Special Combat Interactions

### Assassin Ambush Kill
When the Rogue Assassin attacks from invisibility (STL > 0, target not aware within 2 hexes): the target is instantly killed, bypassing the damage formula entirely. Only works on non-specialty units. Detected by Scout-adjacent units (if any friendly Scout is within 2 hexes of the Assassin, the attack is not "from invisibility").

### Iron Fist Stun
Target skips their entire next turn. Computed after damage. Units killed by Iron Fist Stun Strike **cannot be reanimated** — the stun destroys the animating force. This is the hard counter to Necromancer strategy.

### Cleric Free Heal
Once per turn, as a free action (no action cost), a Cleric Clan Unit restores 2 combat HP to one adjacent friendly unit. Applied in Step 9 (before economy phase). Does not count as a spell cast.

### Necromancer Dark Resonance
After each unit death anywhere on the map, Necromancer checks: every 3 deaths = +1 ATK to all Necromancer Clan Units permanently. This is applied to `clan.shrine_bonuses['atk']` internally (treated as a stacking bonus). Grows stronger as the game progresses — the Necromancer clan is intentionally weakest early, strongest late.

### Troll Regeneration
At the start of each resolution phase (before combat), any Troll monster unit regenerates 2 HP — unless it was hit by fire or acid damage in the previous resolution. Track `troll.damaged_by_fire_this_turn: bool`. Reset each turn.

### Skeleton Undying
At 0 HP: 30% chance to rise at 2 HP. Checked after `_check_death()`. If rising, set `unit.hp_combat = 2` and cancel death. Does NOT trigger if killed by: Soulreaver item, or any spell classified as "holy" (Cleric spells, Heal spell from Cleric).

---

## Combat Outcome Reference

### Quick Reference: Who Beats What

| Attacker | vs. | Result |
|----------|-----|--------|
| Archer (ATK 3) | Goblin (DEF 0) | 3±1 = 2–4 damage → kills in 1–2 hits |
| Clan Unit (ATK 4) | Orc (DEF 3) | 1±1 = 0–2 → min 1 damage → 4–8 hits |
| Chieftain (ATK 6) | Orc (DEF 3) | 3±1 = 2–4 → kills in 2–4 hits |
| Any unit | Dragon (DEF 6, armour 5) | Most units deal 0–1 net → need many attackers |
| Stormcaller (ATK 3 + AoE) | Group | 7 dmg to all in 3-hex radius |

### Min/Max Damage Table

| ATK | DEF | Min dmg | Avg dmg | Max dmg |
|-----|-----|---------|---------|---------|
| 2 | 0 | 1 (floor) | 2 | 3 |
| 4 | 3 | 1 (floor) | 1 | 2 |
| 6 | 4 | 1 (floor) | 2 | 3 |
| 9 | 3 | 5 | 6 | 7 |
| 9 | 6 | 2 | 3 | 4 |

Dragon with Ancient Armour (−5/turn): Chieftain (ATK 6 + Rally) vs Dragon (DEF 6):
- Raw damage: max(1, (6−6)+luck) = 1 per hit
- Ancient Armour absorbs 5/turn
- Net: 0 damage if only Chieftain attacking
- Need 5 units each hitting for 1 = 5 damage → armour absorbs all → 0 net
- Need 6+ units attacking → 6+ damage → 1+ net after armour

This is why you need sustained multi-unit assault, not a single strong unit.