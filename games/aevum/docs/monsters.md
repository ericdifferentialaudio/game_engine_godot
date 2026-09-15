# monsters.md — Monster System

## Overview

Monsters in Aevum are not dungeon encounters. They are **world-map units** that patrol hexes near their lair and fight using the same combat resolution as clan units. There is no separate combat panel, no monster encounter screen.

To claim a lair's prize: kill all patrol units on the world map. Step on the lair hex. Done.

---

## Core Principles

- Monster patrol units are `UnitInstance` objects with `clan_id = "monster"`
- They fight using `resolve_hit()` exactly like clan vs. clan combat
- Passives (Berserk, Regeneration, Undying, etc.) are applied in the resolution phase
- When `lair.all_defeated == True`, any unit stepping onto the lair hex claims the prize automatically — no input required
- The Dragon is a monster but with a separate state machine — see Dragon section below

---

## Monster Selection Per Game

12 types available. 8 active per game (seed-selected), plus the Dragon (always present).

```
Outer pool (6 types): goblin, orc, warg, harpy, skeleton, basilisk
Central pool (5 types): troll, wraith, elemental, demon, drake

Active per game:
  4 drawn from outer pool  → placed in Middle Ring and Approach Ring
  4 drawn from central pool → placed in Dragon's Keep and Approach Ring
  Dragon → always in Dragon's Keep (unique, separate from pools)
```

Seed picks from each pool without replacement. The combination changes every game — a world might have goblin/warg/harpy/basilisk in the outer ring, troll/elemental/demon/drake in the central zone, or any other combination.

---

## The 12 Monster Types

### Goblin *(T1, outer pool)*

| Stat | ATK | DEF | MOV | HP | VIS | MP |
|------|-----|-----|-----|----|-----|----|
| Value | 2 | 0 | 4 | 3 | 2 | 0 |

**Passive — Pack Bonus:** Each additional goblin on the same hex adds +1 ATK to all goblins there. A single goblin is harmless. Three goblins on the same hex each fight at ATK 4.

**Patrol:** radius 3, 2–3 units depending on lair tier

**Weakness pool:** arrows, fire, holy  
**Resistance pool:** poison, cold, darkness

*The swarm monster. Dangerous in numbers, trivial alone. Archers at range before they close.*

---

### Orc *(T1, outer pool)*

| Stat | ATK | DEF | MOV | HP | VIS | MP |
|------|-----|-----|-----|----|-----|----|
| Value | 4 | 3 | 2 | 8 | 2 | 0 |

**Passive — Berserk:** When HP drops below 50% (≤4 HP), ATK permanently increases by +2 for the rest of that combat. An injured Orc hits harder.

```python
def _apply_orc_berserk(orc: UnitInstance, pre_hp: int, state: GameState) -> None:
    """Check and apply berserk after taking damage."""
    if (not getattr(orc, 'berserk_active', False) and
            orc.hp_combat <= orc.hp_combat_max // 2):
        orc.berserk_active = True
        orc.atk_override   = orc.base_atk + 2
```

**Patrol:** radius 3, 2–3 units

**Weakness pool:** magic, arrows, silver  
**Resistance pool:** physical, cold

*Don't let it get wounded and then leave it alive. Kill it before berserk or after berserk — not during.*

---

### Warg *(T1, outer pool)*

| Stat | ATK | DEF | MOV | HP | VIS | MP |
|------|-----|-----|-----|----|-----|----|
| Value | 3 | 1 | 5 | 5 | 4 | 0 |

**Passive — Hunt:** If the Warg attacked a unit last turn and that unit is still alive, the Warg gains +2 MOV directly toward it this turn. MOV becomes 7 while hunting.

**Patrol:** radius 4, 2–3 units

**Weakness pool:** fire, blunt, light  
**Resistance pool:** ranged, cold

*Fast (MOV 5+hunting). Wide vision (VIS 4). Will track wounded units across multiple turns. Keep a healthy decoy unit forward to break the hunt.*

---

### Harpy *(T1, outer pool)*

| Stat | ATK | DEF | MOV | HP | VIS | MP |
|------|-----|-----|-----|----|-----|----|
| Value | 3 | 2 | 5 | 4 | 3 | 4 |

**Passive — Aerial:** Ignores all terrain movement costs. Forest, hills, mountain all cost 1. Cannot be slowed by terrain-based effects or the Entangle spell.

**Passive — Shroud:** Becomes invisible (STL 3) between attacks. Breaks on next attack action.

**Patrol:** radius 5, 2–3 units

**Weakness pool:** arrows, lightning, wind  
**Resistance pool:** melee, entangle

*Harpy ignores terrain — it reaches your backline faster than expected. Archers are the counter. Entangle does nothing.*

---

### Skeleton *(T2, outer pool)*

| Stat | ATK | DEF | MOV | HP | VIS | MP |
|------|-----|-----|-----|----|-----|----|
| Value | 3 | 2 | 2 | 6 | 2 | 0 |

**Passive — Undying:** At 0 HP, 30% chance to rise at 2 HP. Does NOT trigger if killed by Soulreaver item or any Holy-classified spell. Necromancer's Reanimate works on Skeletons.

```python
def _check_skeleton_undying(skeleton: UnitInstance,
                             killer_item: Optional[str],
                             killer_spell: Optional[str],
                             state: GameState) -> bool:
    """Returns True if skeleton rises instead of dying."""
    import random
    if killer_item == "soulreaver":
        return False
    if killer_spell and "holy" in _classify_spell(killer_spell, state):
        return False
    if random.random() < 0.30:
        skeleton.hp_combat = 2
        skeleton.is_alive  = True
        return True
    return False
```

**Patrol:** radius 3, 2–4 units

**Weakness pool:** holy, blunt, fire  
**Resistance pool:** ranged, poison, dark

*Kill it with a Cleric or Soulreaver to prevent rising. Otherwise keep a unit in reserve for the potential re-kill.*

---

### Basilisk *(T2, outer pool)*

| Stat | ATK | DEF | MOV | HP | VIS | MP |
|------|-----|-----|-----|----|-----|----|
| Value | 4 | 3 | 1 | 10 | 2 | 0 |

**Passive — Petrifying Gaze:** On every hit, the target unit **cannot act next turn** (cannot move, attack, cast, or meditate). Applies to the resolution phase *after* combat damage. Both damage and freeze happen simultaneously.

```python
def _apply_basilisk_gaze(target: UnitInstance, state: GameState) -> None:
    """Apply petrifying gaze after successful basilisk hit."""
    target.status['petrified'] = target.status.get('petrified', 0) + 1
    # Petrified status: unit skips next full action
    # Applied in Step 10 (status tick): reduce petrified by 1 each turn
```

**Patrol:** radius 2, 1–2 units

**Weakness pool:** cold, blunt, mirror  
**Resistance pool:** fire, magic, ranged

*MOV 1 — it barely moves. But anything it hits loses their next turn. Use multiple units to divide its attention. If it freezes your Seeker mid-approach, you've lost a critical turn.*

---

### Troll *(T2, central pool)*

| Stat | ATK | DEF | MOV | HP | VIS | MP |
|------|-----|-----|-----|----|-----|----|
| Value | 5 | 2 | 2 | 12 | 2 | 0 |

**Passive — Regeneration:** +2 HP per turn. Suppressed if the Troll took fire or acid damage during the previous resolution phase.

```python
def _apply_troll_regen(troll: UnitInstance, state: GameState) -> None:
    """Applied in Step 10 (status tick), after combat."""
    if troll.damaged_by_fire_this_turn:
        troll.damaged_by_fire_this_turn = False  # reset for next turn
        return   # regen suppressed
    troll.hp_combat = min(troll.hp_combat + 2, troll.hp_combat_max)

def _mark_fire_damage(target: UnitInstance, damage_type: str) -> None:
    if damage_type in ("fire", "acid"):
        target.damaged_by_fire_this_turn = True
```

**Patrol:** radius 4, 3–4 units

**Weakness pool:** fire, acid, lightning  
**Resistance pool:** physical, cold, ranged

*It heals faster than most units can damage it unless you bring fire. Flameblade, Fireball, or Shaman Lightning all suppress regen. Kill it the same turn you hit it with fire.*

---

### Wraith *(T2, central pool)*

| Stat | ATK | DEF | MOV | HP | VIS | MP |
|------|-----|-----|-----|----|-----|----|
| Value | 4 | 1 | 4 | 7 | 3 | 8 |

**Passive — Incorporeal:** Ignores ZoC entirely. Passes through occupied hexes without triggering combat (unless it chooses to attack). Immune to Trap damage. Cannot be entangled.

**Special — Sunlight Bonus:** On even turns (representing dawn light), all attacks against the Wraith deal +2 damage. Coordinate your assault on even turns.

**Passive — Spell casting (T2):** Wraith casts Silence and Shroud from its 8 MP pool.

**Patrol:** radius 5, 2–3 units

**Weakness pool:** holy, soulreaver, sunlight  
**Resistance pool:** physical, ranged, cold, dark

*Steel doesn't hurt it meaningfully (DEF 1 but resists physical). Cleric Clan Units are the primary counter. Attack on even turns for the dawn bonus.*

---

### Elemental *(T3, central pool)*

| Stat | ATK | DEF | MOV | HP | VIS | MP |
|------|-----|-----|-----|----|-----|----|
| Value | 5 | 3 | 3 | 10 | 3 | 8 |

**Variant system:** Seed picks one variant per game from three options. The variant determines immunity, weakness, and on-hit effect. Pub intel at Regular+ reveals which variant this game's elemental is.

| Variant | Immune to | Weak to | On-hit effect |
|---------|-----------|---------|---------------|
| **Fire** | Fire | Cold | Adjacent units take 1 fire splash damage on each attack |
| **Ice** | Cold | Lightning | Target MOV −2 next turn on hit |
| **Lightning** | Lightning | Physical | Damage chains to 1 adjacent unit for 2 additional damage |

```python
def _apply_elemental_on_hit(elemental: UnitInstance,
                             target: UnitInstance,
                             state:  GameState) -> None:
    variant = getattr(elemental, 'elemental_variant', 'fire')
    if variant == "fire":
        # Splash to adjacent units
        for q, r in hex_disk(target.q, target.r, 1):
            if (q, r) != (target.q, target.r):
                for u in state.units_at(q, r):
                    if u.is_alive and u.unit_id != elemental.unit_id:
                        u.hp_combat = max(0, u.hp_combat - 1)
    elif variant == "ice":
        target.status['slowed'] = max(target.status.get('slowed', 0), 1)
    elif variant == "lightning":
        # Chain to nearest other unit
        adjacent = [u for u in state.units_at_hex_group(
                        hex_disk(target.q, target.r, 1))
                    if u.unit_id not in (elemental.unit_id, target.unit_id)
                    and u.is_alive]
        if adjacent:
            adjacent[0].hp_combat = max(0, adjacent[0].hp_combat - 2)
```

**Patrol:** radius 5, 4 units (T3 lairs only)

**Weakness pool:** counter_element (determined by variant)  
**Resistance pool:** own_element

---

### Demon *(T3, central pool)*

| Stat | ATK | DEF | MOV | HP | VIS | MP |
|------|-----|-----|-----|----|-----|----|
| Value | 6 | 4 | 2 | 14 | 4 | 20 |

**Passive — Spell Ward:** Reduces all incoming spell damage by 2 (minimum 0). Magic attacks are significantly weakened against the Demon.

**Spells (T3):** Fireball, Curse, Mass Haste. Uses 20 MP pool. Prioritises Curse on Chieftain/Seeker, Mass Haste on self when outnumbered.

**Patrol:** radius 5, 4 units

**Weakness pool:** holy, soulreaver, silver  
**Resistance pool:** fire, dark, physical

*The hardest non-Dragon monster to kill. High stats + Spell Ward + spellcasting. Bring a Cleric (holy weakness), Soulreaver item, or Chieftain with Rally support. Mage is ineffective (Spell Ward neutering spells).*

---

### Drake *(T3, central pool)*

| Stat | ATK | DEF | MOV | HP | VIS | MP |
|------|-----|-----|-----|----|-----|----|
| Value | 7 | 4 | 3 | 16 | 4 | 0 |

**Passive — Breath Splash:** On each melee attack, adjacent units to the target also take 3 damage. Spread your units — don't cluster.

```python
def _apply_drake_breath_splash(drake: UnitInstance,
                               primary_target: UnitInstance,
                               state:          GameState) -> None:
    for q, r in hex_disk(primary_target.q, primary_target.r, 1):
        if (q, r) == (primary_target.q, primary_target.r):
            continue
        for u in state.units_at(q, r):
            if u.is_alive and u.unit_id != drake.unit_id:
                u.hp_combat = max(0, u.hp_combat - 3)
```

**Patrol:** radius 5, 3 units

**Weakness pool:** ice, piercing, magic  
**Resistance pool:** fire, blunt

*The Drake's splash damage punishes clustering. Keep your assault units spread by 2+ hexes. Archers at range are ideal — they avoid splash entirely.*

---

## The Dragon

**Two dragons per game** (Sprint 30 Phase 1 genetics): Guardian + Hunter. Each is a **different type** per seed (Red, Blue, Green, Gold, Silver). HP and behaviour vary by type. Not drawn from the central monster pool.

### Dragon Roles

| Dragon | HP base | Lair placement | Behaviour |
|--------|---------|----------------|-----------|
| **Guardian** | 30+ (type bonus) | Near Veil Hex (r=4-12 from center) | Patrols radius 10, vortex movement around egg |
| **Hunter** | 22+ (type bonus) | 8-15 hex from Guardian lair | Moves 2 hex/turn, patrol radius 20. Becomes DESTROYER if Guardian slain. |

### Dragon Types

| Type | HP bonus | Wake mult | Special behaviour |
|------|----------|-----------|-------------------|
| Red | 0 | ×1.5 | Never retreats. Enrages at 66% HP. |
| Green | 0 | ×0.7 | Forest proximity −30% wake. Retreats at 40%, heals 3/t, returns at 80%. |
| Blue | 0 | ×1.0 | Targets Seekers in lunge. Lightning arc on retreat. |
| Gold | +5 | ×0.6 | Dragon Orb 50% fail. Noble retreat (egg-safe only). |
| Silver | 0 | ×1.0 | Proximity radius −3. Weapons −1 dmg vs Silver. Ice zone r=6 (1 dmg/t). |

**Guardian type weighted toward:** Gold > Silver > Green > Blue > Red (protective).  
**Hunter type weighted toward:** Red > Blue > Green > Silver > Gold (aggressive).  
Always different types per seed.

### Egg Hatch Countdown (by type)

| Type | Hatch turns | Baby HP |
|------|-------------|---------|
| Red | 5 | 10 |
| Blue | 6 | 10 |
| Silver | 7 | 10 |
| Green | 8 | 12 |
| Gold | 10 | 15 |

Seeker picking up the egg resets the countdown. Baby dragon spawns at the egg's last position.

### Hidden Clutch — Second Egg (Phase 3)

A second clutch is hidden inside the **central T3 monster lair** designated at game start (`state._second_egg_lair_id`). It hatches when:

1. The lair boss is defeated **AND**
2. Any alive non-monster unit stands on the boss hex.

This triggers `check_second_egg()` → `_spawn_second_clutch()` → a baby dragon of the **Hunter's type** spawns at the boss hex.

**Fallback:** If still unhatched at t450, a baby dragon is force-spawned. Shares the 3-concurrent baby dragon cap.

### State Machine

```
DORMANT → STIRRING (2 turns) → AWAKE → ENRAGED → RETREATING → SLAIN (permanent)
```

### States in Detail

**DORMANT:**
- Not on the world map. No token visible.
- Completely invisible by any means — Watch Posts, Mage wonder, no detection.
- Triggered when any Seeker enters radius 8 of the Veil Hex.

**STIRRING (2 turns):**
- Dragon token appears globally — all clans see it simultaneously.
- Dragon is stationary. Does not attack.
- Fog clears radius 4 around Dragon.
- Global announcement: *"The Dragon stirs."* Audio: `DRAGON_STIRS`.
- 2-turn countdown shown on all UIs.
- This is the theft window — a fast Seeker can reach the Veil Hex and grab the egg before the Dragon acts.

**AWAKE:**
- Dragon moves toward nearest Seeker (egg-carrier priority over proximity).
- ATK 9, DEF 6, MOV 4, HP = base + type bonus.
- **Ancient Armour:** first 5 incoming damage per turn negated.
- **Fire Breath:** every 2 turns. 5-hex directional cone, 5 damage, all units hit. **Announced 1 turn ahead** — players see the preview cone and can move out.
- Dragon faces toward its current priority target each turn.

**ENRAGED** (≤50% HP, ≤12 HP):
- ATK becomes 11. MOV becomes 5.
- Fire Breath fires **every turn** with **no advance warning**.
- Dragon becomes more aggressive in target selection.

**RETREATING** (HP = 0):
- One-tick transitional state for animation.
- Dragon plays death animation. Cannot be attacked during this tick.
- Transitions to SLAIN on the following tick.

**SLAIN (permanent):**
- Dragon token removed forever.
- 500g awarded to killing clan immediately.
- Central zone fog lifts entirely for all clans permanently.
- Veil Hex revealed globally (Stage 2 egg reveal).
- Virtue dialogue fires for killing clan.
- Dragon-Slayer title on unit that dealt killing blow: +2 ATK permanent.
- Audio: `DRAGON_SLAIN` — plays once per game, ever.
- Dragon does NOT regenerate. Does NOT return. This is final.

### Dragon State Machine Code

```python
@dataclass
class DragonInstance:
    q:                          Optional[int]   = None
    r:                          Optional[int]   = None
    lair_q:                     int             = 0
    lair_r:                     int             = 0
    state:                      str             = "dormant"
    hp:                         int             = 25
    hp_max:                     int             = 25
    enraged:                    bool            = False
    is_dead:                    bool            = False
    breath_ready:               bool            = False
    breath_cooldown:            int             = 0      # turns until next breath
    breath_preview_hexes:       list            = field(default_factory=list)
    stirring_turns_remaining:   int             = 0
    armour_absorbed_this_turn:  int             = 0
    triggered_by:               Optional[str]   = None  # clan_id
    slain_by:                   Optional[str]   = None
    slain_on_turn:              Optional[int]   = None
    killing_unit_id:            Optional[str]   = None
    death_gold_awarded:         bool            = False
    virtue_choice:              Optional[str]   = None  # "worth_it"|"necessary"
    facing_q:                   int             = 0     # direction facing (unit vector)
    facing_r:                   int             = 1
    weak_to:                    str             = ""    # seed-determined
    resists:                    str             = ""

def _process_dragon(dragon: DragonInstance, state: GameState) -> None:
    """Called in Step 19 (monster phase) each resolution."""
    if dragon.is_dead:
        return

    if dragon.state == "dormant":
        _check_dragon_trigger(dragon, state)

    elif dragon.state == "stirring":
        dragon.stirring_turns_remaining -= 1
        if dragon.stirring_turns_remaining <= 0:
            dragon.state         = "awake"
            dragon.breath_cooldown = 2

    elif dragon.state in ("awake", "enraged"):
        _dragon_move(dragon, state)
        _dragon_breath_tick(dragon, state)
        _check_dragon_enrage(dragon, state)

    elif dragon.state == "retreating":
        dragon.state  = "slain"
        dragon.is_dead = True
        _resolve_dragon_death(dragon, state)

def _check_dragon_trigger(dragon: DragonInstance, state: GameState) -> None:
    """Check if any Seeker has entered radius 8 of the Veil Hex."""
    egg = state.dragon_egg
    for uid, unit in state.units.items():
        template = state.unit_templates.get(unit.template_id)
        if not template or template.template_id != "seeker":
            continue
        if not unit.is_alive:
            continue
        if hex_dist(unit.q, unit.r, egg.q, egg.r) <= 8:
            dragon.state                   = "stirring"
            dragon.stirring_turns_remaining = 2
            dragon.triggered_by            = unit.clan_id
            dragon.q                       = dragon.lair_q
            dragon.r                       = dragon.lair_r
            dragon.visible_to_all          = True
            state.announce("The Dragon stirs.", event="DRAGON_STIRS")
            return

def _resolve_dragon_death(dragon: DragonInstance, state: GameState) -> None:
    """Handle Dragon slain consequences."""
    # 500g to killing clan
    if not dragon.death_gold_awarded and dragon.slain_by:
        killing_clan = state.clans[dragon.slain_by]
        killing_clan.gold = min(killing_clan.gold + 500, killing_clan.gold_cap)
        dragon.death_gold_awarded = True

    # Dragon-Slayer title
    if dragon.killing_unit_id:
        unit = state.units.get(dragon.killing_unit_id)
        if unit:
            unit.titles.append("dragon_slayer")
            unit.dragon_slayer_atk_bonus = 2

    # Clear central zone fog globally
    for (q, r), cell in state.world_map.cells.items():
        if hex_dist(q, r, state.CENTER_Q, state.CENTER_R) <= 22:
            for clan_id in state.config.active_clan_ids:
                cell.is_visible[clan_id]  = True
                cell.is_explored[clan_id] = True

    # Stage 2 egg reveal
    state.dragon_egg.is_globally_revealed = True
    state.dragon_egg_fully_revealed       = True

    state.announce("The Dragon has fallen.", event="DRAGON_SLAIN")

    # Virtue dialogue (handled by UI — fires on killing clan's next input)
    state.pending_virtue_dialogue = {
        "type": "dragon_slain",
        "clan_id": dragon.slain_by,
    }
```

### Dragon Fire Breath

```python
def _dragon_breath_tick(dragon: DragonInstance, state: GameState) -> None:
    """Handle Dragon breath — preview and firing."""
    dragon.breath_cooldown = max(0, dragon.breath_cooldown - 1)

    freq = 1 if dragon.enraged else 2

    if dragon.breath_cooldown == 1 and not dragon.enraged:
        # Preview cone (1 turn warning, Awake state only)
        dragon.breath_preview_hexes = _compute_breath_cone(
            dragon.q, dragon.r, dragon.facing_q, dragon.facing_r
        )
        state.announce("The Dragon draws breath.", event="DRAGON_BREATH_WARNING",
                       data={"cone": dragon.breath_preview_hexes})

    elif dragon.breath_cooldown == 0:
        # Fire
        cone = _compute_breath_cone(
            dragon.q, dragon.r, dragon.facing_q, dragon.facing_r
        )
        for q, r in cone:
            for unit in state.units_at(q, r):
                if unit.is_alive:
                    unit.hp_combat = max(0, unit.hp_combat - 5)
                    if unit.hp_combat + unit.hp_exhaust <= 0:
                        _kill_unit(state, unit, killer="dragon_breath")
        dragon.breath_preview_hexes = []
        dragon.breath_cooldown      = freq
```

### Egg Reveal — Two Stages

**Stage 1 (private, per-clan):**
When a Seeker's VIS range covers the Veil Hex, that clan alone sees the egg shimmer.

```python
def _check_egg_detection(state: GameState) -> None:
    """Check if any Seeker can now see the Veil Hex."""
    egg = state.dragon_egg
    if egg.is_globally_revealed:
        return   # already known to all

    for uid, unit in state.units.items():
        template = state.unit_templates.get(unit.template_id)
        if not template or template.template_id != "seeker":
            continue
        if not unit.is_alive:
            continue
        seeker_vis = state.effective_stat(unit, 'vis')
        dist       = hex_dist(unit.q, unit.r, egg.q, egg.r)
        if dist <= seeker_vis:
            if not egg.is_revealed_to.get(unit.clan_id, False):
                egg.is_revealed_to[unit.clan_id] = True
                # Private notification to this clan only
                state.notify_clan(unit.clan_id, "Your Seeker senses something.",
                                  event="EGG_DETECTED",
                                  data={"veil_q": egg.q, "veil_r": egg.r})
```

**Stage 2 (global):** Dragon slain → central fog lifts → `dragon_egg.is_globally_revealed = True` → all clans see Veil Hex.

Dragon trigger (radius 8) and egg detection (Seeker VIS, radius 6 base) are **independent events**. A Seeker can trigger the Dragon at r=8 without yet seeing the egg at r=6. Or (with high VIS) can detect the egg before triggering the Dragon.

---

## Monster Lair Structure

```python
@dataclass
class MonsterLair:
    lair_id:           str
    monster_type:      str        # one of the 12 types
    tier:              int        # 1, 2, or 3
    q:                 int        # lair hex
    r:                 int
    zone:              str        # "outer" | "approach" | "keep"
    patrol_unit_ids:   list[str]  # UnitInstance ids — world map units
    all_defeated:      bool = False
    prize_claimed:     bool = False
    prize_gold:        int  = 0
    prize_item_id:     Optional[str] = None
    respawn_timers:    dict = field(default_factory=dict)  # unit_id -> turns remaining
    weak_to:           str  = ""   # seed-determined for this game
    resists:           str  = ""
    weakness_known_by: dict = field(default_factory=dict)  # clan_id -> bool
    variant:           Optional[str] = None   # elemental variant only
```

---

## Patrol Behaviour

Monster patrol units are standard `UnitInstance` objects with `clan_id = "monster"`.

```python
def _process_monster_patrols(state: GameState) -> None:
    """Step 19: Move all monster patrol units."""
    for lair in state.monster_lairs.values():
        if lair.all_defeated or lair.prize_claimed:
            _check_respawn(lair, state)
            continue

        for uid in lair.patrol_unit_ids:
            unit = state.units.get(uid)
            if not unit or not unit.is_alive:
                continue
            _patrol_move(unit, lair, state)

    _check_lair_claims(state)

def _patrol_move(unit: UnitInstance, lair: MonsterLair,
                 state: GameState) -> None:
    """Move a patrol unit: aggro toward nearest clan unit, else random walk."""
    patrol_radius = _get_patrol_radius(lair.monster_type)

    # Find nearest clan unit within patrol radius
    nearest_clan_unit = None
    nearest_dist      = float('inf')
    for uid, target in state.units.items():
        if target.clan_id == "monster" or not target.is_alive:
            continue
        d = hex_dist(unit.q, unit.r, target.q, target.r)
        if d <= patrol_radius and d < nearest_dist:
            nearest_clan_unit = target
            nearest_dist      = d

    if nearest_clan_unit:
        # Move toward clan unit
        _move_toward(unit, nearest_clan_unit.q, nearest_clan_unit.r, state)
    else:
        # Random walk within patrol radius
        _random_walk_in_radius(unit, lair.q, lair.r, patrol_radius, state)

def _check_lair_claims(state: GameState) -> None:
    """Check if all patrol units dead → mark lair claimable."""
    for lair in state.monster_lairs.values():
        if lair.all_defeated or lair.prize_claimed:
            continue
        all_dead = all(
            not state.units[uid].is_alive
            for uid in lair.patrol_unit_ids
            if uid in state.units
        )
        if all_dead:
            lair.all_defeated = True
            # Check if any clan unit is already on the lair hex
            for uid, unit in state.units.items():
                if (unit.q == lair.q and unit.r == lair.r and
                        unit.is_alive and unit.clan_id != "monster"):
                    _claim_lair_prize(lair, unit, state)
                    break

def _claim_lair_prize(lair: MonsterLair, claimer: UnitInstance,
                      state: GameState) -> None:
    """Claim the prize. First clan to step on cleared lair hex wins."""
    if lair.prize_claimed:
        return
    lair.prize_claimed = True
    clan = state.clans[claimer.clan_id]

    # Gold
    clan.gold = min(clan.gold + lair.prize_gold, clan.gold_cap)

    # Item (if any)
    if lair.prize_item_id:
        if not claimer.item:
            claimer.item = ItemInstance(item_id=lair.prize_item_id)
        # else: item stored in clan stash for later equipping

    # T3 bonus: reveal weakness to this clan
    if lair.tier == 3:
        lair.weakness_known_by[claimer.clan_id] = True

    state.announce(
        f"{state.clans[claimer.clan_id].name} cleared the {lair.monster_type} lair.",
        event="LAIR_CLEARED"
    )
```

---

## Respawn

| Lair tier | Guard respawn | Boss respawn | Notes |
|-----------|--------------|-------------|-------|
| T1 | 5 turns | N/A | Only guards |
| T2 | 5 turns | 8 turns | Boss is the last guard killed |
| T3 | 5 turns | 8 turns | Boss is the last guard killed |

Respawn after prize is claimed: smaller patrol only (no boss). Prize gold = 25% of original on re-clear. No item.

```python
def _check_respawn(lair: MonsterLair, state: GameState) -> None:
    """Spawn new patrol units after respawn timer expires."""
    for uid, turns_left in list(lair.respawn_timers.items()):
        lair.respawn_timers[uid] = turns_left - 1
        if turns_left - 1 <= 0:
            # Spawn new unit
            new_unit = _create_monster_unit(lair.monster_type, lair.q, lair.r, lair.lair_id, state)
            state.units[new_unit.unit_id] = new_unit
            lair.patrol_unit_ids.append(new_unit.unit_id)
            if uid in lair.respawn_timers:
                del lair.respawn_timers[uid]
            lair.all_defeated = False
```

---

## Prize Tables

| Tier | Gold range | Item pool |
|------|-----------|-----------|
| T1 | 50–100g | iron_shield, swift_boots, keen_blade, heal_potion, lantern |
| T2 | 100–200g | frostblade, longbow, mana_staff, heal_potion, iron_shield |
| T3 | 200–400g | flameblade, shadowblade, elfbow, focus_crystal, exhaust_sigil, seekers_crystal, ghost_cloak |
| T3 bonus | — | `weakness_known_by[clan_id] = True` for that lair's monster type |

Prize is set at world generation (`lair.prize_gold` and `lair.prize_item_id`). One prize per lair ever.

---

## Weakness System — Combat Summary

| Condition | Damage modifier |
|-----------|----------------|
| Known weakness exploited | +3 damage |
| Known resistance attacked | −1 damage (min 1) |
| Unknown weakness/resistance | Normal |

`weakness_known_by[clan_id]` is set to `True` via:
1. Pub intel at Regular+ relationship (monster weakness nearby)
2. Stepping onto a cleared T3 lair hex (auto-reveals for claiming clan)

The weakness is **game-seed-determined** — one weakness from the pool is active this game. The rest are irrelevant this run.

---

## Interior Lair System ✅ engine_lair.py

### Two-Phase Design

Lairs have two layers:

**Phase 1 — Approach (world map, existing):** Monster patrol units circle the enclave hex. Kill them on the world map → lair is breachable.

**Phase 2 — Interior (new):** When a unit steps onto a cleared or active lair hex, the interior map loads (`enter_lair()`). Navigate rooms, fight interior monsters, claim chests, beat the boss.

T1 lairs: interior is optional — world-map prize is available on clear. Interior gives bonus loot only.  
T2–T3 lairs: full interior clear needed for boss chest (primary prize).

---

### Torch System

Inside all lair interiors, normal world-map VIS is replaced by **torch radius**:

| Source | VIS in lair |
|--------|------------|
| Default torch (every unit carries one) | 2 |
| Scout (trained eyes + torch) | 3 |
| Lantern (T1 item, 30g) | 4 |
| Crystal Lantern (T1 item, 55g) | 5 — suppression halved |
| Spelunker's Sigil (T3 item, 200g) | 5 — suppression halved |
| Runelight Orb (T2 map item, 140g) | 6 — immune to suppression |
| Dragonfire Brand (T3 item, 240g) | 6 — immune + fire aura |

**Torch suppressors** — certain interior monsters reduce torch radius of all units within 2 hex by 1:

| Suppressor | Theme | Penalty |
|-----------|-------|---------|
| Giant Bat | Cave | −1 VIS per bat in range |
| Will-o-Wisp | Swamp | −1 VIS per wisp in range |
| Shadow | Crypt | −1 VIS per shadow in range |
| Phantom Wisp | Fungal | −1 VIS per wisp in range |

Crystal Lantern / Spelunker's Sigil: suppression penalty halved (round down).  
Runelight Orb / Dragonfire Brand: completely immune to suppression.

`torch_vis_for_unit(unit_id, interior_id, state)` computes effective VIS each turn.

---

### Lair Themes

Five themes determine the shape, tile types, and monster population of the interior:

#### Cave
Rocky, tight corridors. Natural formation. Grey stone visuals.

| Special hex | Trigger | Effect |
|-------------|---------|--------|
| Rockfall | Entry | 20% chance: 2 dmg + movement stops. Spelunker's Sigil: immune. |
| Underground pool | — | Impassable. |

#### Swamp
Twisty, organic, wet. Dark green. Many dead ends.

| Special hex | Trigger | Effect |
|-------------|---------|--------|
| Marsh | Movement | MOV cost 2 for most; FREE for Necromancer/Druid/Bog Lurker. |
| Bog pool | — | Impassable. |
| Fungal patch | Entry | −1 ATK 1t. |

#### Crypt
Square rooms, built corridors. Torchlit wall sconces. Coffins line the walls.

| Special hex | Trigger | Effect |
|-------------|---------|--------|
| Coffin | Alarm | On full alert: spawns 1 Skeleton. Once per coffin. |
| Dark altar | Proximity | −1 all stats to units within 1 hex (refreshed while in range). |

#### Ruined
Partially collapsed structures. Rubble everywhere. Ruined stone.

| Special hex | Trigger | Effect |
|-------------|---------|--------|
| Rubble | — | Impassable. |
| Hidden cache | Auto-find | Ranger/Rogue detect automatically. Others miss unless carrying Runelight Orb. Contains 20–60g or T1 item (30% chance). |

#### Fungal
Bioluminescent mushrooms. All units (including monsters) +1 VIS map-wide. Purple/green glow.

| Special hex | Trigger | Effect |
|-------------|---------|--------|
| Spore cloud | Entry | −1 ATK 2t when entered. Expands each turn (Myconid/Fungal Horror alive). |
| Bioluminescent | Global | All units on map +1 VIS. Applies to monsters too. |

#### Universal (T2+)

| Special hex | Trigger | Effect |
|-------------|---------|--------|
| Alarm bell | Entry | Full lair alert: all monsters activate, Coffins spawn (crypt). |
| Locked door | Entry | Blocks passage until key dropped by a specific patrol monster. |
| Boss chamber | Entry | Larger deepest room. Boss spawns here. |
| Phylactery object | Action | Spend 1 action to destroy (action-type phylacteries). |
| Phylactery root | Fire | Fire damage destroys it (Fireball, Dragonfire Brand, Fire Elemental hit). |

---

### Interior Monster Roster

Interior monsters are **theme-native** — separate from the world-map patrol pool:

| Theme | Basic guard | ATK/DEF/MOV/HP | Passive | Suppressor | ATK/DEF/MOV/HP |
|-------|-------------|----------------|---------|-----------|----------------|
| Cave | Cave Crawler | 3/1/3/5 | Poison Bite: −1 ATK 2t on hit | Giant Bat | 2/0/5/3, Torch −1 |
| Swamp | Bog Lurker | 3/1/3/5 | Marsh free movement | Will-o-Wisp | 2/1/4/3, Incorporeal, Torch −1 |
| Crypt | Skeleton | 3/2/2/6 | Undying 30% | Shadow | 2/1/4/4, Incorporeal, Torch −1 |
| Ruined | Bandit | 3/2/3/5 | — (30% are archers: RNG 3) | — | — |
| Fungal | Sporeling | 2/1/3/4 | Spore Death: 2 dmg AoE 2 hex on death | Phantom Wisp | 2/0/5/3, Incorporeal, Torch −1 |

**Spawn counts by tier:**
- T1: 2–4 basic guards, 0–1 suppressor
- T2: 3–6 basic guards, 1–2 suppressors
- T3: 5–8 basic guards, 2–3 suppressors

---

### Boss Table — Theme × Tier

#### Cave Bosses

**Cave Bear (T1)** ATK 5, DEF 2, MOV 3, HP 10  
*Maul* — first attack this combat deals ×2 ATK damage (fires automatically, once per combat).  
Weakness: fire.

**Stone Golem (T2)** ATK 6, DEF 4, MOV 1, HP 14. Immune to ranged attacks.  
*Rockfall* — every turn: 3 dmg on a random occupied hex within 3 hexes (not a spell).  
Weakness: lightning.

**Ancient Golem (T3)** ATK 8, DEF 5, MOV 1, HP 20. Immune to ranged attacks.  
*Quake* — every 3 turns: 5 dmg AoE to all units within 4 hexes. Announced 1 turn ahead.  
**Phylactery** (action-destroy): rune stone in boss room — destroy to give Golem +3 dmg taken/hit.  
Weakness: lightning.

#### Swamp Bosses

**Swamp Hag (T1)** ATK 4, DEF 1, MOV 2, HP 8  
*Hex Curse* — RNG 3: −2 all stats for 3 turns (not a spell; recharges 3t).  
Weakness: fire.

**Bog Troll (T2)** ATK 6, DEF 2, MOV 2, HP 16. Marsh terrain free.  
*Regen+* — +4 HP/turn. Suppressed by fire or acid previous turn.  
Weakness: fire, acid.

**Plague Hydra (T3)** ATK 5, DEF 2, MOV 2, HP 18.  
*Multi-Bite* — 3 separate ATK rolls per turn (each resolved independently).  
*Decapitate* — on kill-blow: one head regrows 2 turns later at 6 HP. Max 2 regrowths.  
**Phylactery** (fire-destroy): nest hex 2 hexes behind Hydra — fire destroys it, preventing regrowth.  
Weakness: fire.

#### Crypt Bosses

**Skeleton Champion (T1)** ATK 4, DEF 2, MOV 2, HP 8  
*Undying Champion* — 40% rise at 3 HP on death (not holy/Soulreaver).  
*Rally Dead* — once per combat: revives 1 adjacent dead Skeleton at 2 HP.  
Weakness: holy, blunt.

**Lich Acolyte (T2)** ATK 4, DEF 2, MOV 2, HP 10. MP 16.  
*Drain Life* — heals 2 HP on every hit.  
*Reanimate* — casts once per combat (nearest dead ally).  
Weakness: holy.

**Lich Lord (T3)** ATK 6, DEF 2, MOV 2, HP 12. MP 24.  
*Phylactery Lich* — on death: revives at 8 HP 3 turns later unless phylactery destroyed first.  
Casts Reanimate + Curse every 2 turns.  
**Phylactery** (action-destroy): soul vessel pedestal in boss room. Destroy BEFORE the Lich dies.  
Weakness: holy.

#### Ruined Bosses

**Bandit Lord (T1)** ATK 5, DEF 2, MOV 3, HP 9  
*Rally* — always-on aura: adjacent Bandits +2 ATK.  
Weakness: magic.

**Wraith Captain (T2)** ATK 5, DEF 1, MOV 4, HP 8. Incorporeal. Dawn bonus: even turns +2 dmg taken.  
*Soul Rend* — on every hit: target permanently loses 2 max HP (`hp_max` reduced; not recoverable).  
Weakness: holy, soulreaver, sunlight.

**Death Knight (T3)** ATK 7, DEF 3, MOV 3, HP 16.  
*Death Aura* — all enemies within 2 hex −1 DEF (always-on).  
*Blood Harvest* — on each kill: +2 ATK permanently for this combat (max +6 total, base 7 → max 13).  
Weakness: holy, soulreaver.

#### Fungal Bosses

**Spore Shambler (T1)** ATK 3, DEF 1, MOV 2, HP 8  
*Spore Burst* — every 2 turns: AoE 2 hex, 2 dmg + −1 ATK 2t to all units (including allies).  
Weakness: fire.

**Myconid Elder (T2)** ATK 4, DEF 2, MOV 2, HP 10.  
*Mind Control* — once per combat (turn 3+): one enemy within RNG 3 attacks nearest ally this turn.  
*Spore Spread* — passive: grows 1 spore cloud hex/turn.  
Weakness: fire.

**Fungal Horror (T3)** ATK 6, DEF 2, MOV 2, HP 18. Regen +2 HP/turn (not fire).  
*Spore Cloud* — every 2 turns: AoE 3 hex, −2 MOV + −1 ATK 3t. Cloud persists and expands 1 hex/turn.  
**Phylactery** (fire-destroy): root hex at network center — fire destroys it (halts expansion, removes regen).  
Weakness: fire.

---

### Treasure System

#### Boss Chest (always at boss location)

| Tier | Gold | Item chance |
|------|------|------------|
| T1 | 50–100g + boss bonus | 20% → T1 item |
| T2 | 100–200g + boss bonus | 35% → T2 (80%) / T3 (20%) |
| T3 | 200–400g + boss bonus | 60% → T3 (75%) / T4 (25%) |

Boss gold bonuses (per theme):
- Cave T2: +25g · Cave T3: +75g · Swamp T2: +25g · Swamp T3: +100g
- Crypt T2: +30g · Crypt T3: +80g · Ruined T2: +40g · Ruined T3: +100g
- Fungal T2: +30g · Fungal T3: +100g


**Item tier boost:** All T3 theme bosses have `item_tier_boost=1` (`loot_bonus.item_tier_boost` in `lair_bosses.json`). The chest item tier distribution is shifted +1 tier on T3 boss kills (T3 boss distributes as if T4/T5 pool; not yet implemented in `_roll_item_tier` — placeholder field).
#### Scattered Chests

| Tier | Count | Gold | Item |
|------|-------|------|------|
| T1 | 1–2 | 10–30g | none |
| T2 | 2–3 | 20–50g | 10% T1 item |
| T3 | 3–4 | 30–80g | 10% T1 item |

#### Locked Chest (T2+)
Key dropped by: T2 — `patrol_monster`, T3 — `elite_monster` (seeded at world gen). Gold: T2 30–80g / T3 60–120g. Item: T2 20% chance (T2 item) / T3 25% chance (T2 item).

#### Hidden Cache (T3 only)
Ranger/Rogue auto-detect. Others miss unless carrying Runelight Orb. Contains T3 item (40% chance).

**Total gold per full lair clear:**
- T1: ~120–230g (world-map prize + interior bonus)
- T2: ~220–450g
- T3: ~420–800g

---

### New Items — Torch & Lair System

#### T1 Shop Additions

| ID | Name | Cost | Effect |
|----|------|------|--------|
| `crystal_lantern` | Crystal Lantern | 55g | +3 VIS in lair (VIS = 5). Torch suppressor penalty halved. |
| `lair_map` | Lair Map | 40g | **Consumable.** Reveals full layout of current lair interior. |

#### T2 Map Addition

| ID | Name | Value | Effect |
|----|------|-------|--------|
| `runelight_orb` | Runelight Orb | 140g | +5 VIS in lair (VIS = 6). Completely immune to torch suppressors. Also auto-reveals hidden caches. |

#### T3 Lair Additions

| ID | Name | Value | Restriction | Effect |
|----|------|-------|-------------|--------|
| `dragonfire_brand` | Dragonfire Brand | 240g | melee | +2 ATK. Fire aura: trolls/bog troll cannot regen, destroys fire phylacteries, auto-destroys phylactery roots on contact. +5 VIS in lairs (immune to suppression). |
| `spelunker_sigil` | Spelunker's Sigil | 200g | any | +3 VIS in lairs (VIS = 5). Suppression halved. +1 MOV in cave/ruined interiors. Rockfall immunity. +1 ATK vs. golem/construct types. |

---

### Public API — engine_lair.py

```python
# Torch & detection
torch_vis_for_unit(unit_id, interior_id, state) -> int
has_fire_aura(unit_id, state) -> bool

# Entry/exit
enter_lair(unit_id, enclave_id, state) -> bool
exit_lair(unit_id, state) -> bool

# Boot-time generation
lair_monster_spawn(enclave_id, interior_id, theme, tier, rng, state) -> list[str]
lair_boss_spawn(enclave_id, interior_id, theme, tier, rng, state) -> Optional[str]
lair_loot_generate(enclave_id, tier, theme, rng) -> dict

# Per-turn pipeline
lair_special_hex_tick(interior_id, state)
lair_boss_ability_tick(boss_unit_id, interior_id, state)
boss_revival_tick(interior_id, state)

# Event resolution
lair_chest_open(unit_id, chest_id, interior_id, state) -> dict
lair_alarm_trigger(interior_id, state)
destroy_phylactery(phylactery_hex_id, destroyer_unit_id, destroy_method, interior_id, state) -> bool
boss_on_death(boss_unit_id, interior_id, state) -> bool

# Boss combat integration
apply_boss_maul_if_needed(boss_unit_id, damage, state) -> int
apply_soul_rend(target_unit_id, state)
apply_blood_harvest(boss_unit_id, state)
```

### Integration Points

- `engine_interior_gen.py` — generates `InteriorMap` at boot; `engine_lair.py` populates monsters/boss/chests into it
- `engine_monster.py` — handles world-map patrol (Phase 1); `engine_lair.py` handles interior (Phase 2)
- `engine_items.py` — torch item VIS values read via `_TORCH_ITEMS` dict; fire aura items checked via `_FIRE_AURA_ITEMS`
- `combat_engine.py` — calls `apply_boss_maul_if_needed`, `apply_soul_rend`, `apply_blood_harvest`, `boss_on_death` during combat resolution
- `engine_npc.py` — survivor NPC in lairs (T2+): 20% chance per lair; freeing grants lair layout T3 intel + temporary ally 3 turns
