# ai.md — AI System

## Overview

Seven AI clans compete simultaneously against the player. Each AI clan runs an independent **behavior tree** evaluated every turn during Step 21 of the resolution phase. The AI plans for the next commitment window and submits a `ClanActionQueue` just like the player — it just does it programmatically.

The AI is not omniscient. It respects fog of war. It only knows what its own vision covers, pub intel it has purchased, and alliances it has formed. The player and AI operate under the same information constraints.

---

## Architecture

```
AIEngine.process_ai_turn(state, clan_id)
│
├── 1. Evaluate threats (enclave HP, enemies nearby)
├── 2. Score each goal in clan's priority list (0.0–1.0)
├── 3. Select highest-scoring goal
├── 4. Execute goal → generate ClanActionQueue
└── 5. Update ai_goal_stack for UI display ("Mage clan: Advancing shrines")
```

The AI runs once per clan per turn, sequentially. All 7 AI clans plan before the resolution phase executes. This means AI clans do not react to each other's planned moves within the same turn — they react to the **previous turn's outcome**.

---

## Goal Priority Lists

Each clan has a personality-driven priority stack. Goals are evaluated in order; the first goal with score ≥ 0.6 is executed. If no goal reaches 0.6, the highest-scoring goal executes regardless.

```python
GOAL_PRIORITY: dict[str, list[str]] = {
    "fighter":     ["defend_enclave", "produce_units",    "advance_shrines",
                    "attack_enemies",   "scout_map"],
    "mage":        ["defend_enclave", "scout_map",        "advance_shrines",
                    "cast_spells",      "seek_egg"],
    "cleric":      ["defend_enclave", "produce_units",    "advance_shrines",
                    "heal_allies",      "scout_map"],
    "dwarf":       ["defend_enclave", "produce_units",    "advance_shrines",
                    "fortify",          "scout_mountains"],
    "ranger":      ["scout_map",      "advance_shrines",  "seek_egg",
                    "attack_enemies",   "defend_enclave"],
    "elf":         ["scout_map",      "advance_shrines",  "cast_spells",
                    "attack_ranged",    "seek_egg"],
    "rogue":       ["steal_intel",    "advance_shrines",  "stealth_approach",
                    "seek_egg",         "scout_map"],
    "monk":        ["advance_shrines","attack_enemies",   "scout_map",
                    "defend_enclave",   "seek_egg"],
    "druid":       ["grow_forest",    "advance_shrines",  "scout_map",
                    "defend_enclave",   "seek_egg"],
    "necromancer": ["advance_shrines","reanimate_fallen", "attack_enemies",
                    "scout_map",        "seek_egg"],
    "bard":        ["negotiate_rights","plant_rumors",    "advance_shrines",
                    "scout_map",        "seek_egg"],
    "shaman":      ["advance_shrines","cast_area_spells", "scout_map",
                    "defend_enclave",   "seek_egg"],
}
```

---

## Goal Evaluation

Each goal returns a score from 0.0 (no urgency) to 1.0 (critical). Scores are computed from game state — not random.

```python
def evaluate_goal(state: GameState, clan_id: str, goal: str) -> float:
    clan    = state.clans[clan_id]
    shrines = sum(1 for r in clan.shrine_records.values()
                  if r.is_meditated or r.has_credit)

    if goal == "defend_enclave":
        # Urgency increases with nearby enemies and enclave HP damage
        enemy_nearby = sum(
            1 for uid, u in state.units.items()
            if u.clan_id not in (clan_id, "monster") and u.is_alive
            and hex_dist(u.q, u.r, clan.enclave_q, clan.enclave_r) <= 8
        )
        hp_ratio = clan.enclave_hp / clan.enclave_hp_max
        return min(1.0, (enemy_nearby * 0.15) + ((1 - hp_ratio) * 0.8))

    elif goal == "produce_units":
        unit_count = sum(1 for u in state.units.values()
                         if u.clan_id == clan_id and u.is_alive)
        return max(0.0, min(1.0, (6 - unit_count) * 0.15))

    elif goal == "advance_shrines":
        remaining = 8 - shrines
        urgency   = remaining / 8
        # Increases as rivals approach Avatar
        rival_avg = sum(
            sum(1 for r in c.shrine_records.values() if r.is_meditated or r.has_credit)
            for cid, c in state.clans.items() if cid != clan_id
        ) / max(1, len(state.clans) - 1)
        rival_pressure = min(0.4, rival_avg / 8 * 0.4)
        return min(1.0, urgency * 0.6 + rival_pressure)

    elif goal == "scout_map":
        visible_pct = sum(
            1 for cell in state.world_map.cells.values()
            if cell.is_visible.get(clan_id, False)
        ) / 10000
        return max(0.0, min(0.6, (0.3 - visible_pct) * 2))

    elif goal == "seek_egg":
        if not clan.avatar_achieved or not clan.seeker_built:
            return 0.0
        return 0.9   # if Seeker exists and Avatar achieved: always high priority

    elif goal == "attack_enemies":
        aggression = getattr(clan, 'ai_aggression_level', 0.5)
        if clan.enclave_hp < clan.enclave_hp_max * 0.5:
            return 0.0   # too vulnerable to attack
        return aggression * 0.7

    elif goal == "negotiate_rights":
        if shrines >= 6:
            return 0.0   # close to Avatar, stop buying
        needed = [
            sid for sid, record in clan.shrine_records.items()
            if not record.is_meditated and not record.has_credit
        ]
        return min(0.8, len(needed) * 0.12) if clan.gold >= 100 else 0.0

    elif goal == "fortify":
        fort_count = sum(
            1 for s in state.structures.values()
            if s.structure_type == "fort" and s.clan_id == clan_id
        )
        return max(0.0, min(0.7, (3 - fort_count) * 0.25))

    elif goal == "cast_spells":
        magic_units = [
            u for u in state.units.values()
            if u.clan_id == clan_id and u.is_alive
            and state.unit_templates[u.template_id].mp_max > 0
            and u.mp_current >= 4
        ]
        return min(0.7, len(magic_units) * 0.2)

    elif goal == "heal_allies":
        wounded = [
            u for u in state.units.values()
            if u.clan_id == clan_id and u.is_alive
            and u.hp_combat < u.hp_combat_max * 0.5
        ]
        return min(0.8, len(wounded) * 0.25)

    elif goal == "reanimate_fallen":
        dead_nearby = sum(
            1 for u in state.units.values()
            if not u.is_alive and u.clan_id != "monster"
            and any(
                hex_dist(u.q, u.r, live.q, live.r) <= 1
                for live in state.units.values()
                if live.clan_id == clan_id and live.is_alive
                and state.unit_templates.get(live.template_id, {}).template_id == "necromancer"
            )
        )
        return min(0.9, dead_nearby * 0.45)

    elif goal == "plant_rumors":
        spymaster_alive = any(
            u for u in state.units.values()
            if u.clan_id == clan_id and u.is_alive
            and state.unit_templates[u.template_id].template_id == "spymaster"
        )
        return 0.65 if spymaster_alive else 0.0

    elif goal == "grow_forest":
        thornweaver = any(
            u for u in state.units.values()
            if u.clan_id == clan_id and u.is_alive
            and state.unit_templates[u.template_id].template_id == "thornweaver"
        )
        return 0.5 if thornweaver else 0.0

    elif goal == "stealth_approach":
        return 0.6   # Rogue always prefers stealth movement

    elif goal == "steal_intel":
        spymaster = next((
            u for u in state.units.values()
            if u.clan_id == clan_id and u.is_alive
            and state.unit_templates[u.template_id].template_id == "spymaster"
        ), None)
        return 0.55 if spymaster and clan.gold < 100 else 0.0

    elif goal in ("cast_area_spells", "attack_ranged", "scout_mountains"):
        return 0.45   # secondary behaviours, executed when nothing urgent

    return 0.0
```

---

## Goal Execution

### advance_shrines

The most important goal for almost every clan. Drives cross-map movement.

```python
def _execute_advance_shrines(state: GameState, clan_id: str) -> list[GameAction]:
    """
    Select the next shrine to target and move units toward it.
    Priority: own shrine first, then nearest unmeditated shrines,
    then offer rights purchase if shrine is contested.
    """
    clan    = state.clans[clan_id]
    actions = []

    # Find next shrine target
    unmeditated = [
        (sid, shrine)
        for sid, shrine in state.shrines.items()
        if not clan.shrine_records.get(sid, ShrineRecord()).is_meditated
        and not clan.shrine_records.get(sid, ShrineRecord()).has_credit
    ]
    if not unmeditated:
        return actions   # all shrines done

    # Sort by distance from best-positioned unit (typically Chieftain or Clan Unit)
    my_units = [u for u in state.units.values()
                if u.clan_id == clan_id and u.is_alive
                and state.unit_templates[u.template_id].can_meditate]

    if not my_units:
        return actions

    # Pick closest shrine-unit pair
    best_unit, best_shrine_id, best_shrine = None, None, None
    best_dist = float('inf')
    for uid_unit in my_units:
        for sid, shrine in unmeditated:
            d = hex_dist(uid_unit.q, uid_unit.r, shrine.q, shrine.r)
            if d < best_dist:
                best_dist     = d
                best_unit     = uid_unit
                best_shrine_id = sid
                best_shrine   = shrine

    if not best_unit:
        return actions

    # Can we buy rights?
    shrine_owner = best_shrine_id.replace("shrine_", "")
    if (shrine_owner != clan_id
            and not clan.shrine_records.get(best_shrine_id, ShrineRecord()).has_rights
            and clan.gold >= 100
            and best_dist > 8):
        # Attempt rights purchase via Diplomat if available
        diplomat = _find_available_diplomat(clan_id, state)
        if diplomat:
            actions.append(GameAction(
                action_type    = "diplomacy",
                unit_id        = diplomat.unit_id,
                metadata       = {"offer": "rights", "shrine_id": best_shrine_id,
                                  "gold": _rights_offer_amount(clan, state)},
            ))

    # Move best unit toward shrine
    path = _pathfind(best_unit, best_shrine.q, best_shrine.r, state)
    if path:
        next_q, next_r = path[0]
        actions.append(GameAction(
            action_type = "move",
            unit_id     = best_unit.unit_id,
            target_q    = next_q,
            target_r    = next_r,
        ))

    # If already in sacred ground: meditate
    if hex_dist(best_unit.q, best_unit.r, best_shrine.q, best_shrine.r) <= 2:
        actions.append(GameAction(
            action_type = "meditate",
            unit_id     = best_unit.unit_id,
            target_q    = best_shrine.q,
            target_r    = best_shrine.r,
        ))

    return actions
```

### seek_egg

```python
def _execute_seek_egg(state: GameState, clan_id: str) -> list[GameAction]:
    """Move Seeker toward Dragon's Keep. Switch to Dragon fight if enough force."""
    clan    = state.clans[clan_id]
    seeker  = _find_seeker(clan_id, state)
    if not seeker:
        return []

    egg = state.dragon_egg
    dragon = state.dragon

    # Dragon phase evaluation
    if dragon.state in ("stirring", "awake", "enraged"):
        return _execute_dragon_phase(state, clan_id, seeker, dragon, egg)

    if dragon.state == "slain":
        # Race for egg
        path = _pathfind(seeker, egg.q, egg.r, state)
        return [GameAction("move", seeker.unit_id,
                           target_q=path[0][0], target_r=path[0][1])] if path else []

    # DORMANT: move toward Dragon's Keep cautiously
    target_q = state.CENTER_Q + (seeker.q - state.CENTER_Q) // 2
    target_r = state.CENTER_R + (seeker.r - state.CENTER_R) // 2
    path = _pathfind(seeker, target_q, target_r, state)
    return [GameAction("move", seeker.unit_id,
                       target_q=path[0][0], target_r=path[0][1])] if path else []
```

---

## Dragon Phase AI

Evaluated during Step 21 when `dragon.state != "dormant"`. Overrides normal goal priority.

```python
def evaluate_dragon_phase(state: GameState, clan_id: str) -> list[GameAction]:
    """
    Dragon-phase behavior. Called when dragon.state in
    (stirring, awake, enraged, retreating, slain).
    Returns action list for all AI units this turn.
    """
    clan   = state.clans[clan_id]
    dragon = state.dragon
    seeker = _find_seeker(clan_id, state)
    actions = []

    if dragon.state == "stirring":
        # 2-turn window: decide theft vs fight
        if seeker and _can_reach_egg_in_2_turns(seeker, state):
            # Theft run: sprint Seeker to Veil Hex
            egg  = state.dragon_egg
            path = _pathfind(seeker, egg.q, egg.r, state)
            if path:
                actions.append(GameAction("move", seeker.unit_id,
                                          target_q=path[0][0], target_r=path[0][1]))
        elif _have_sufficient_force_in_zone(clan_id, state):
            # Fight: move assault force toward Dragon
            actions += _move_assault_force_toward_dragon(clan_id, state)
        else:
            # Neither: move Seeker toward egg from safe distance
            if seeker:
                safe_approach = _find_safe_approach_hex(seeker, state)
                if safe_approach:
                    actions.append(GameAction("move", seeker.unit_id,
                                              target_q=safe_approach[0],
                                              target_r=safe_approach[1]))

    elif dragon.state in ("awake", "enraged"):
        # Avoid breath preview hexes
        breath_hexes = set(tuple(h) for h in dragon.breath_preview_hexes)
        # Move all units out of breath preview if possible
        for unit in _get_clan_units_in_zone(clan_id, state):
            if (unit.q, unit.r) in breath_hexes:
                escape = _find_escape_from_breath(unit, breath_hexes, state)
                if escape:
                    actions.append(GameAction("move", unit.unit_id,
                                              target_q=escape[0], target_r=escape[1]))

        # Fight if sufficient force
        if _have_sufficient_force_in_zone(clan_id, state):
            actions += _attack_dragon(clan_id, state)
        # Steal if Seeker can reach
        elif seeker and _seeker_can_reach_egg_safely(seeker, state):
            egg  = state.dragon_egg
            path = _pathfind(seeker, egg.q, egg.r, state)
            if path:
                actions.append(GameAction("move", seeker.unit_id,
                                          target_q=path[0][0], target_r=path[0][1]))

    elif dragon.state == "slain":
        # Race for egg — all Seekers sprint
        if seeker:
            egg  = state.dragon_egg
            path = _pathfind(seeker, egg.q, egg.r, state)
            if path:
                actions.append(GameAction("move", seeker.unit_id,
                                          target_q=path[0][0], target_r=path[0][1]))
        # Block rival Seekers if our Seeker isn't in position
        else:
            actions += _intercept_rival_seekers(clan_id, state)

    return actions


def _have_sufficient_force_in_zone(clan_id: str, state: GameState) -> bool:
    """
    True if clan has enough units in the Dragon's Keep zone to win the fight.
    Requires: 4+ units AND 10+ effective DPS (to overcome Ancient Armour per turn).
    """
    zone_units = [
        u for u in state.units.values()
        if u.clan_id == clan_id and u.is_alive
        and hex_dist(u.q, u.r, state.CENTER_Q, state.CENTER_R) <= 20
    ]
    if len(zone_units) < 4:
        return False
    effective_dps = sum(state.effective_stat(u, 'atk') for u in zone_units)
    return effective_dps >= 10


def _can_reach_egg_in_2_turns(seeker: UnitInstance,
                                state: GameState) -> bool:
    """True if Seeker can reach Veil Hex in 2 turns (Stirring window)."""
    egg  = state.dragon_egg
    dist = hex_dist(seeker.q, seeker.r, egg.q, egg.r)
    mov  = state.effective_stat(seeker, 'mov')
    return dist <= mov * 2
```

---

## Diplomatic AI

### Sentiment Thresholds for Decisions

```python
SENTIMENT_THRESHOLDS = {
    "offer_alliance":       +5,   # offer alliance proactively
    "accept_alliance":      +3,   # accept an incoming alliance offer
    "accept_passage":       +1,   # accept peaceful passage
    "offer_rights_sale":    0,    # sell meditation rights
    "accept_rights_buy":    -1,   # buy rights from neutral clan
    "decline_passage":      -4,   # refuse passage, fight instead
    "attack_on_sight":      -6,   # always attack
    "destroy_enclave":      -8,   # prioritise enclave destruction
}

def ai_diplomacy_response(state: GameState, clan_id: str,
                           offer_type: str, from_clan_id: str) -> str:
    """Returns: 'accept' | 'counter' | 'decline'"""
    sentiment = get_sentiment(clan_id, from_clan_id, state)
    clan      = state.clans[clan_id]

    if offer_type == "passage":
        if sentiment >= SENTIMENT_THRESHOLDS["accept_passage"]:
            return "accept"
        return "decline"

    elif offer_type == "alliance":
        if sentiment >= SENTIMENT_THRESHOLDS["accept_alliance"]:
            can, _ = can_research_wonder(clan, state)
            # Already winning: decline entangling alliances
            if can:
                return "decline"
            return "accept"
        elif sentiment >= 0:
            return "counter"   # propose shorter duration
        return "decline"

    elif offer_type == "rights":
        if sentiment >= SENTIMENT_THRESHOLDS["accept_rights_buy"]:
            return "accept" if clan.gold >= 100 else "decline"
        return "decline"

    elif offer_type == "knowledge_trade":
        # Always consider if we need the shrine
        shrine_id = offer_type.get('shrine_id', '')
        already_have = clan.shrine_records.get(shrine_id, ShrineRecord()).has_credit
        if already_have:
            return "decline"
        return "accept" if clan.gold >= 150 else "counter"

    return "decline"
```

### Rights Offer Pricing

```python
def _rights_offer_amount(clan: ClanInstance, state: GameState) -> int:
    """
    How much the AI is willing to pay for meditation rights.
    Scales with how far behind on shrines and available gold.
    """
    shrines_done = sum(1 for r in clan.shrine_records.values()
                       if r.is_meditated or r.has_credit)
    urgency      = (8 - shrines_done) / 8
    base_offer   = 100
    urgency_bonus = int(urgency * 150)
    return min(clan.gold // 2, base_offer + urgency_bonus)
```

### Contemplation Hall Purchasing

```python
def _ai_consider_shrine_credit(state: GameState, clan_id: str) -> list[GameAction]:
    """
    AI purchases shrine Avatar credit from Contemplation Halls when:
    - Shrine is more than 20 hexes away (too costly to run physically)
    - Buy price is <= 200g (affordable)
    - Clan has enough gold (at least buy_price + 100g reserve)
    - Avatar not yet achieved
    """
    clan    = state.clans[clan_id]
    actions = []

    if clan.avatar_achieved:
        return actions

    for shrine_id, market in state.shrine_market.items():
        if not market.available:
            continue
        if clan.shrine_records.get(shrine_id, ShrineRecord()).has_credit:
            continue
        if clan.shrine_records.get(shrine_id, ShrineRecord()).is_meditated:
            continue

        shrine = state.shrines.get(shrine_id)
        if not shrine:
            continue

        # Distance check: only buy if shrine is far away
        nearest_unit = min(
            (u for u in state.units.values()
             if u.clan_id == clan_id and u.is_alive),
            key=lambda u: hex_dist(u.q, u.r, shrine.q, shrine.r),
            default=None
        )
        if not nearest_unit:
            continue

        dist = hex_dist(nearest_unit.q, nearest_unit.r, shrine.q, shrine.r)
        if dist <= 15:
            continue   # close enough to run physically

        buy_price = market.current_buy_price
        if buy_price > 200:
            continue   # too expensive
        if clan.gold < buy_price + 100:
            continue   # need reserve

        # Buy the credit — move Diplomat to nearest active town
        diplomat = _find_available_diplomat(clan_id, state)
        town     = _find_nearest_contemplation_hall(clan_id, state)
        if diplomat and town:
            path = _pathfind(diplomat, town.q, town.r, state)
            if path:
                actions.append(GameAction(
                    action_type = "move",
                    unit_id     = diplomat.unit_id,
                    target_q    = path[0][0],
                    target_r    = path[0][1],
                ))
                actions.append(GameAction(
                    action_type = "diplomacy",
                    unit_id     = diplomat.unit_id,
                    metadata    = {"offer": "buy_shrine_credit",
                                   "shrine_id": shrine_id,
                                   "town_id": town.town_id},
                ))

    return actions
```

### Knowledge Transfer Decisions

```python
def _ai_consider_knowledge_transfer(state: GameState,
                                     clan_id: str) -> list[GameAction]:
    """
    AI shares/sells shrine knowledge under these conditions:
    - Has meditated a shrine
    - Has a Diplomat or Chieftain
    - Sentiment toward target clan >= +2 (gift) or >= 0 (sale)
    - Or: deposits to Contemplation Hall for gold
    """
    clan    = state.clans[clan_id]
    actions = []

    meditated_shrines = [
        sid for sid, r in clan.shrine_records.items()
        if r.is_meditated
    ]
    if not meditated_shrines:
        return actions

    # Deposit to Hall for gold (always beneficial if price is good)
    for shrine_id in meditated_shrines:
        market = state.shrine_market.get(shrine_id)
        sell_price = market.current_sell_price if market else 200
        if sell_price >= 100:   # worthwhile sale
            diplomat = _find_available_diplomat(clan_id, state)
            town     = _find_nearest_contemplation_hall(clan_id, state)
            if diplomat and town and clan.gold < 300:
                path = _pathfind(diplomat, town.q, town.r, state)
                if path:
                    actions.append(GameAction(
                        action_type = "move",
                        unit_id     = diplomat.unit_id,
                        target_q    = path[0][0],
                        target_r    = path[0][1],
                    ))

    return actions
```

---

## Difficulty Levels

```python
DIFFICULTY_MODIFIERS = {
    "easy": {
        "aggression_scale":     0.5,
        "shrine_priority_bias": 0.7,   # less likely to contest your shrines
        "rights_willingness":   0.8,   # more likely to sell rights cheaply
        "adaptive_weights":     False, # no learning from history
        "dragon_phase_delay":   3,     # waits 3 extra turns before engaging Dragon
    },
    "normal": {
        "aggression_scale":     1.0,
        "shrine_priority_bias": 1.0,
        "rights_willingness":   1.0,
        "adaptive_weights":     False,
        "dragon_phase_delay":   0,
    },
    "hard": {
        "aggression_scale":     1.3,
        "shrine_priority_bias": 1.2,   # more likely to contest shrines
        "rights_willingness":   0.6,   # harder to buy rights
        "adaptive_weights":     True,  # learns from historical patterns
        "dragon_phase_delay":   -2,    # proactively moves toward Dragon earlier
    },
}

def _ai_aggression(clan_id: str, difficulty: str) -> float:
    """Base aggression level per clan and difficulty."""
    CLAN_BASE_AGGRESSION = {
        "fighter": 0.8, "mage": 0.4, "cleric": 0.3, "dwarf": 0.5,
        "ranger":  0.6, "elf":  0.5, "rogue":  0.7, "monk":  0.4,
        "druid":   0.4, "necromancer": 0.6, "bard": 0.3, "shaman": 0.7,
    }
    base   = CLAN_BASE_AGGRESSION.get(clan_id, 0.5)
    scale  = DIFFICULTY_MODIFIERS[difficulty]["aggression_scale"]
    return min(1.0, base * scale)
```

---

## Grand Strategy Stat Choice (AI)

When the AI completes Grand Strategy tech, it must choose one stat for the permanent +1 global bonus. Choice depends on clan identity:

```python
GRAND_STRATEGY_STAT_CHOICE = {
    "fighter":     "atk",        # more damage
    "mage":        "vis",        # more visibility (income + Seeker range)
    "cleric":      "def",        # more durability
    "dwarf":       "end",        # more HP (same as shrine bonus)
    "ranger":      "mov",        # faster movement
    "elf":         "arc",        # better spells
    "rogue":       "stl",        # more stealth
    "monk":        "res",        # more status resistance
    "druid":       "lck",        # better combat luck
    "necromancer": "atk",        # more damage (Dark Resonance synergy)
    "bard":        "int_stat",   # more intel speed
    "shaman":      "atk",        # more base ATK (Area spells aren't ATK)
}
```

---

## Pub Visits (AI)

AI clans visit towns on their way to shrines if the route passes within 5 hexes of a town.

```python
def _ai_should_visit_town(unit: UnitInstance, town: TownInstance,
                           clan_id: str, state: GameState) -> bool:
    """Visit if: passing nearby AND relationship below Trusted AND gold available."""
    dist = hex_dist(unit.q, unit.r, town.q, town.r)
    if dist > 5:
        return False
    rel = town.relationships.get(clan_id, PubRelationship(clan_id=clan_id))
    if rel.score >= 65:   # already Trusted — visit still for intel updates
        return rel.score < 85  # not yet Confidant
    return state.clans[clan_id].gold >= 30   # can afford a visit
```

AI buys 1–2 pints per visit (based on gold), asks one keyword per pint. Keyword selection:
- Below Acquaintance: "shrine" keyword
- Acquaintance: rival clan name with most shrines
- Regular: "egg" keyword
- Trusted: "seeker" keyword
- Confidant: "egg" and "alliance" keywords

---

## AI State Fields

```python
# In ClanInstance (AI clans only):
ai_aggression_level:    float      # 0.0–1.0, set at game start by difficulty
ai_goal_stack:          list[str]  # current goals in priority order for UI display
ai_current_goal:        str        # highest-scoring goal this turn
ai_target_shrine:       Optional[str]   # shrine currently being pursued
ai_target_unit:         Optional[str]   # unit currently being tracked for attack
ai_diplomacy_threshold: int        # min gold before AI considers rights purchases (default 150)
```

---

## Pathfinding

The AI uses **A\* pathfinding** with terrain movement costs as the heuristic weight.

```python
def _pathfind(unit: UnitInstance, target_q: int, target_r: int,
               state: GameState) -> list[tuple[int,int]]:
    """
    A* from unit's current position to target.
    Returns list of (q,r) steps (not including start).
    Empty list if no path found.
    Respects terrain impassability for the unit's clan.
    Does NOT avoid enemy units (AI commits blind like player).
    """
    import heapq

    start    = (unit.q, unit.r)
    goal     = (target_q, target_r)
    frontier = [(0, start)]
    came_from = {start: None}
    cost_so_far = {start: 0}

    while frontier:
        _, current = heapq.heappop(frontier)
        if current == goal:
            break
        for nq, nr in hex_disk(current[0], current[1], 1):
            if (nq, nr) not in state.world_map.cells:
                continue
            step_cost = movement_cost(unit, nq, nr, state)
            if step_cost == float('inf'):
                continue
            new_cost = cost_so_far[current] + step_cost
            if (nq, nr) not in cost_so_far or new_cost < cost_so_far[(nq, nr)]:
                cost_so_far[(nq, nr)] = new_cost
                priority = new_cost + hex_dist(nq, nr, target_q, target_r)
                heapq.heappush(frontier, (priority, (nq, nr)))
                came_from[(nq, nr)] = current

    # Reconstruct path
    if goal not in came_from:
        return []
    path, node = [], goal
    while node != start:
        path.append(node)
        node = came_from[node]
    path.reverse()
    return path
```

---

## AI Turn Summary (what Cline must implement)

```
Step 21 of each resolution phase:

For each AI clan (7 total):
  1. If dragon.state != "dormant": run evaluate_dragon_phase() first
  2. Else: evaluate all goals in GOAL_PRIORITY[clan_id]
  3. Select highest-scoring goal
  4. Execute goal → generate list[GameAction]
  5. Optionally: _ai_consider_shrine_credit() if shrines < 8
  6. Optionally: _ai_consider_knowledge_transfer() if has meditated shrines
  7. Submit ClanActionQueue to state.action_queues[clan_id]
  8. Update clan.ai_current_goal for UI tooltip display
```

The AI does not look ahead beyond one turn. It does not simulate the player's likely actions. It responds to current game state. This keeps it legible and fair — the player can predict AI behaviour by reading its clan's goal priority list.