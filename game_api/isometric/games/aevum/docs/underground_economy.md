# Underground Economy — Aevum: Age of Shrines
## Design Reference Document

> **`[UNWIRED]` 08/24/2026**: same status as `underground_npcs.md` and
> `mercenary_companies.md` — the mechanics below (INF, guard suspicion,
> `engine_underground.interact_npc()`) are implemented in `engine/` but have
> no call site reachable from any AI goal, interior menu, or player action.
> `influence_points` exists on `ClanInstance` and decays per-turn in
> `engine_headless.py`, but nothing ever calls `earn_influence()`/
> `spend_influence()` in a live game, so INF sits at 0 for the whole match.
> Treat this document as unreachable design-intent until wired up.

> This document is the **mechanical specification** for all underground economy systems.
> See `underground_npcs.md` for NPC profiles and `mercenary_companies.md` for the full
> company roster. This document covers data flows, formulae, and implementation details.

---

## 1. Influence Points (INF)

### What INF Is

INF is a **clan-level resource** — a number stored on the `ClanInstance`, separate from gold.
It represents diplomatic reach, favours owed, back-channel relationships, and soft power.

INF is not visible to rival clans unless they have T3 intel on that clan. It is not displayed
on the main HUD — it lives in the clan status panel. Players learn to think about it by feeling
its absence when they try to hire a company or access a broker.

### Earning INF

| Source | INF Gained | Notes |
|---|---|---|
| Bribe a Politician | +2 per bribe | Scales: see NPC profile |
| Complete a shrine meditation (first time) | +1 | Spiritual credibility |
| Defend an allied unit (witnessed) | +1 | Someone saw you be honourable |
| Broker a successful trade | +1 | Castle broker service |
| Shadow Accord contract active | +1/turn | They know people |
| Gilded Fang contracted | +2/turn | Prestige effect |
| Win a diplomatic confrontation | +2 | Call-in-a-Favour used successfully |

### Spending INF

| Expenditure | INF Cost | Effect |
|---|---|---|
| Hire Broken Road Company | 10 (threshold) | Gate requirement — not spent |
| Hire Thornwood Riders | 15 (threshold) | Gate requirement — not spent |
| Hire Iron Veil | 25 (threshold) | Gate requirement — not spent |
| Hire Shadow Accord | 20 (threshold) | Gate requirement — not spent |
| Hire Ember Tide | 30 (threshold) | Gate requirement — not spent |
| Hire Gilded Fang | 40 (threshold) | Gate requirement — not spent |
| Call in a Favour | 5 | Prevents 1 clan from attacking for 3 turns |
| Castle broker access discount | 2 | −50g on next broker visit |
| Clan trade terms improvement | 3 | −10% on next inter-clan trade |

**Important**: INF thresholds for merc companies are **gates, not costs**. The INF is not
consumed by hiring — a clan must *have* 10 INF to hire Broken Road, but they still have 10 INF
after signing. This rewards sustained diplomatic play without punishing players for making a
specific hire.

INF decay: −1 per 20 turns (diplomatic relationships require maintenance). Minimum 0.

### INF Storage
```python
# On ClanInstance (game_state.py)
influence_points: int = 0          # current INF balance
influence_history: list[dict] = field(default_factory=list)  # for log/debug
```

---

## 2. Guard Suspicion System

### Overview

`guard_suspicion` is a **per-clan, per-town** integer counter stored on `TownInstance`. It
represents how much the town guard apparatus has noticed a particular clan's sketchy behaviour.
It is independent of the existing `shady_rep` system (which affects legitimate NPC relationships)
— suspicion is specifically about guards, while shady_rep is about social standing.

### Suspicion Sources

| Action | Suspicion Added |
|---|---|
| Talking to Dealer | +0.5 (integer: rounds up after 2nd conversation) |
| Buying from Dealer | +1 |
| Talking to Fence | +0.5 |
| Fence purchase attempted | +1 (regardless of success or jail) |
| Talking to Shady Guy (guard notices) | +1 (only if guard was within 3 hexes at end of convo) |
| Talking to Criminal (guard notices) | +1.5 (Criminal's reputation precedes him) |

### Suspicion Thresholds

| Level | Effect |
|---|---|
| 0–2 | Normal town behaviour. No additional checks. |
| 3–4 | Guards perform a **check on next clan movement** in this town. Roll: 30% confrontation. |
| 5+ | Guards **proactively check** every turn the clan has units in this settlement. |

### Confrontation Roll Result

On a confrontation trigger (suspicion ≥ 3, failed roll):
```
Roll d100:
  1–30: Confrontation occurs
  31–100: Guards pass by; suspicion held
```

On confrontation:
- Player is offered: **Pay 50g bribe** (suspicion resets to 1) or **Submit to detention**
  (VIOLATION_THEFT protocol → 2-turn jail, suspicion resets to 0)
- If the player's unit has STL ≥ 3: +20 to the roll (harder to spot)
- Rogue-type units: +15 to the roll

### Suspicion Decay

- **Natural decay**: −1 per 10 turns (guards get busy, people forget)
- **Active reset**: Paying the goodwill payment to the town regent (100g) resets suspicion to 0
  immediately. The regent doesn't ask. This is understood.

### Storage
```python
# On TownInstance (game_state.py)
guard_suspicion: dict[str, int] = field(default_factory=dict)   # clan_id → int
```

---

## 3. Bad Karma / Shady Reputation System

### Overview

`shady_rep` is a **per-clan, per-town** counter that affects how **legitimate NPCs** treat the
clan. Where suspicion is about guards, shady_rep is about social standing among merchants,
healers, and regents. Buying from a fence doesn't make the guards suspicious immediately —
but enough of it, and the *town* starts to know who you are.

### Shady Rep Sources

| Action | shady_rep Added |
|---|---|
| Purchasing from Fence | +1 |
| Purchasing from Dealer (any item) | +0.5 |
| Hiring Criminal mercenaries | +0.5 (per hire event, not per turn) |
| Jailed for theft/violation in this town | +2 |
| Shady Guy intel purchase | +0.25 |

### Shady Rep Thresholds

| Level | Effect |
|---|---|
| 0–2 | Normal NPC treatment. No effect. |
| 3–4 | Legitimate NPCs (healer, shopkeeper, regent, scholar) treat clan as **stranger tier** regardless of actual relationship; prices +10% |
| 5–6 | Above, plus: **Politician will refuse to deal** with this clan in this town |
| 7+ | Above, plus: **Lady of the Night** will refuse new visits (existing relationship maintained) |

### Shady Rep Decay

- **Natural decay**: −1 per 15 turns
- **Accelerated reset**: Pay 100g goodwill to town regent → −3 shady_rep immediately
  (min 0; regent accepts without comment; this is canon in the world)
- **Hard cap**: shady_rep cannot exceed 10. At 10, the clan is permanently unwelcome in this
  town's legitimate services until decay brings it below 5 (takes a long time)

### Storage
```python
# On TownInstance (game_state.py)
shady_rep: dict[str, int] = field(default_factory=dict)   # clan_id → int (float internally for accumulation)
```

---

## 4. Fence Inventory — Sold Items Pool Lifecycle

### Overview

Every item sold to a town's blacksmith/shop enters a rolling pool. The Fence has access to
this pool after a delay. This creates a believable item economy: things that pass through a
town's hands eventually become available through unofficial channels.

### Lifecycle

```
1. Player sells item to blacksmith  →  item enters TownInstance.sold_items_pool
2. Pool tick (each turn):
     for item in sold_items_pool:
         item.turns_in_pool += 1
         if item.turns_in_pool >= item.fence_delay:    # fence_delay: 5–10 turns (seeded at item add)
             move item to TownInstance.fence_inventory
3. Fence displays items from fence_inventory
4. On purchase: item removed from fence_inventory; item flagged sourced="fence"
```

### Fence Pricing

```python
fence_price = int(item.base_value × fence_discount_factor)
# fence_discount_factor: random between 0.50 and 0.60 at pool-entry time
```

### Damage Roll

On entry to fence_inventory:
```
if random() < 0.15:
    item.damaged = True
    # Find one non-zero bonus in item.effect; reduce by 1
    # E.g. bonus_atk: 2 → bonus_atk: 1
    # If all bonuses are already 1: damaged flag only (cosmetic, no stat effect)
```

Damaged items are displayed in the Fence's shop with a *(worn)* tag. Price is −10% from
the already-discounted fence price. The Fence mentions it without apology.

*Example: "The boots have a heel coming off. Still boots. Fifteen gold."*

### Fence Inventory Cap

`fence_inventory` is capped at **5 items** per town. Oldest items (by pool entry turn) are
dropped when cap is exceeded. This prevents hoarding and ensures the inventory feels
naturally limited.

### Item Flag: sourced = "fence"

Items purchased from a fence carry `sourced: "fence"`. This flag:
- Contributes to the shady_rep calculation for the purchasing clan (+1 per purchase)
- Can be detected by the Politician (he won't deal with clans caught using fence items —
  he checks at interaction time if the most recently bought item is fence-sourced)
- Is NOT visible to the player in the normal inventory view — it's internal state

---

## 5. Dealer Items — Additions to engine_items.py

Six new items sold exclusively by the Dealer NPC. They are not available in any shop and
cannot be found on the map. Source is `["dealer"]` only.

```python
# In ITEM_DATA (engine_items.py):

"mystery_powder": {
    "name": "Mystery Powder",
    "tier": 1,
    "base_value": 80,
    "slot": "utility",
    "source": ["dealer"],
    "consumable": True,
    "effect": {"bonus_atk_4t": 2},
    "desc": "+2 ATK for 4 turns. Consumable. Dealer only.",
    "nsfw_name": "Rage Dust",
},

"crimson_tonic": {
    "name": "Crimson Tonic",
    "tier": 1,
    "base_value": 70,
    "slot": "utility",
    "source": ["dealer"],
    "consumable": True,
    "effect": {"bonus_mov_3t": 2},
    "desc": "+2 MOV for 3 turns. Consumable. Dealer only.",
},

"shadow_dust": {
    "name": "Shadow Dust",
    "tier": 1,
    "base_value": 90,
    "slot": "utility",
    "source": ["dealer"],
    "consumable": True,
    "effect": {"bonus_stl": 1, "invisible_2t": True},
    "desc": "+1 STL, invisible 2 turns. Consumable. Dealer only.",
},

"clarity_draught": {
    "name": "Clarity Draught",
    "tier": 2,
    "base_value": 150,
    "slot": "utility",
    "source": ["dealer"],
    "consumable": True,
    "effect": {"wis_bonus_permanent": 1},
    "desc": "+1 WIS (permanent). Consumable. Dealer only.",
},

"reagent_cache": {
    "name": "Rare Reagent Cache",
    "tier": 2,
    "base_value": 120,
    "slot": "utility",
    "source": ["dealer"],
    "consumable": False,
    "effect": {"trade_value_bonus": 60, "ritual_eligible": True},
    "desc": "High trade value. Used in rituals. Dealer only.",
},

"black_salve": {
    "name": "Black Salve",
    "tier": 1,
    "base_value": 100,
    "slot": "utility",
    "source": ["dealer"],
    "consumable": True,
    "effect": {"clear_one_status": True},
    "desc": "Removes 1 negative status effect. Consumable. Dealer only.",
},
```

**NSFW item names**: When `config.nsfw_dialogue = True`, item names in the Dealer's shop UI
use alternate names from the `nsfw_name` field where provided. The mechanics are identical.

---

## 6. Knowledge Bleed — Implementation Spec

### Trigger Conditions

Each turn, for each interior location with at least 2 clan units present:

```python
def knowledge_bleed_tick(location_id: str, state: GameState) -> None:
    interior = state.interiors.get(location_id)
    if interior is None:
        return

    # Group units by clan
    clan_units = {}
    for uid, unit in state.units.items():
        if unit.current_interior_id == location_id and unit.is_alive:
            clan_units.setdefault(unit.clan_id, []).append(unit)

    for clan_id, units in clan_units.items():
        if len(units) < 2:
            continue

        # Find units with NPC-sourced stat bonuses
        for source_unit in units:
            bonuses = _get_npc_bonuses(source_unit)
            if not bonuses:
                continue

            # Check cohabitation streak (units must share for 3+ turns)
            streak = getattr(source_unit, "cohabitation_turns", {})
            for target_unit in units:
                if target_unit.unit_id == source_unit.unit_id:
                    continue
                tid = target_unit.unit_id
                streak[tid] = streak.get(tid, 0) + 1
                if streak[tid] >= 3:
                    # Roll for knowledge bleed
                    for bonus_key, bonus_val in bonuses.items():
                        npc_source_tag = f"bleed_{bonus_key}"
                        if npc_source_tag not in getattr(target_unit, "inspired_by", []):
                            if random.random() < 0.15:
                                _apply_temporary_bonus(target_unit, bonus_key, bonus_val, turns=3)
                                target_unit.inspired_by.append(npc_source_tag)
            source_unit.cohabitation_turns = streak
```

### Bonus Types Subject to Bleed

| Bonus Field | Bleed Version | Duration |
|---|---|---|
| `int_bonus` | Temporary int_bonus_temp | 3 turns |
| `dex_bonus` | Temporary dex_bonus_temp | 3 turns |
| `wis_bonus` | Temporary wis_bonus_temp | 3 turns |
| `hp +1 (Lady of Night)` | NOT bleedable | — |

HP bonuses are not bleedable — the Lady of Night's effect is explicitly personal and cannot
be passed secondhand. Stat bonuses from Juggler, Hackey Sack, and Politician are bleedable.

---

## 7. Criminal Flee Mechanic — Implementation Spec

```python
def criminal_flee_check(npc: NPCInstance, location_id: str, state: GameState) -> bool:
    """
    Called each interior turn for Criminal-type NPCs.
    Returns True if the Criminal flees (exits interior).
    """
    if npc.npc_type != "criminal":
        return False

    interior = state.interiors.get(location_id)
    if interior is None:
        return False

    # Check for guards within 2 hexes
    for uid, unit in state.units.items():
        if not unit.is_alive or unit.current_interior_id != location_id:
            continue
        if unit.unit_type != "guard" and unit.clan_id not in ("guard", "town_guard"):
            continue
        dist = _hex_dist(unit.interior_q, unit.interior_r, npc.q, npc.r)
        if dist <= 2:
            # Criminal exits interior
            npc.is_in_interior = False
            npc.location_override = "world_map_adjacent"  # placed on adjacent world hex
            print(f"  ** CRIMINAL_FLED: {npc.npc_id} exited {location_id} t={state.turn_number}")
            return True

    return False
```

**Patrol warning** (when Criminal sentiment toward hiring clan ≥ 20):
```python
def criminal_patrol_warning(npc: NPCInstance, clan_id: str, state: GameState) -> Optional[str]:
    """Returns a warning dialogue string if Criminal will warn this clan about an upcoming patrol."""
    sentiment = getattr(npc, "sentiment", {}).get(clan_id, 0)
    if sentiment < 20:
        return None
    # Check if a guard is 3–5 hexes away (close but not yet triggering flee)
    # ... guard proximity check ...
    if guard_nearby:
        return "You've got maybe two minutes before the evening round. Talk fast or come back."
    return None
```

---

## 8. Jail Roll — Fence Purchase Formula

```python
def fence_jail_roll(buying_unit: UnitInstance, town: TownInstance, clan_id: str) -> bool:
    """
    Returns True if the unit is caught and jailed.
    """
    base = 0.25
    suspicion = town.guard_suspicion.get(clan_id, 0)
    stealth = getattr(buying_unit, "stealth", 0) + getattr(buying_unit, "dex_bonus", 0) // 2

    jail_chance = base + (suspicion * 0.05) - (stealth * 0.08)
    jail_chance = max(0.05, min(0.75, jail_chance))  # clamp 5%–75%

    return random.random() < jail_chance
```

**Example outcomes**:
| Scenario | jail_chance |
|---|---|
| Fresh clan, no suspicion, no stealth | 25% |
| Suspicion 3, no stealth | 40% |
| No suspicion, STL 2 | 9% |
| Suspicion 5, STL 0 | 50% |
| Suspicion 5, STL 3 (Rogue) | 26% |

---

## 9. Politician Bribe Pricing Formula

```python
def politician_bribe_cost(state: GameState) -> int:
    """
    Returns the current bribe cost for the Politician interaction.
    Scales with turn number and active rival clan count.
    """
    base = 200
    turn_factor = 1.0 + (state.turn_number / 300)  # +33% at turn 100; +67% at turn 200
    rival_count = sum(1 for c in state.clans.values() if not c.is_eliminated)
    demand_factor = 1.0 + (rival_count - 2) * 0.10  # +10% per rival beyond 2

    raw = base * turn_factor * demand_factor
    return int(min(400, max(200, raw)))  # clamp 200g–400g
```

---

## 10. Mercenary Per-Turn Gold Drain

```python
def merc_gold_drain_tick(state: GameState) -> None:
    """
    Called once per turn. Drains per-turn merc costs from active contracts.
    Handles insolvency (clan runs out of gold mid-contract).
    """
    for company_id, company in state.merc_companies.items():
        for clan_id in list(company.active_contracts):
            clan = state.clans.get(clan_id)
            if clan is None:
                continue

            rate = company.per_turn_rate  # already sentiment-adjusted at sign time
            if clan.gold >= rate:
                clan.gold -= rate
                company.sentiment[clan_id] = company.sentiment.get(clan_id, 0) + 0  # no change — on time
            else:
                # Insolvency: company leaves
                company.active_contracts.remove(clan_id)
                company.contracts_active -= 1
                company.sentiment[clan_id] = company.sentiment.get(clan_id, 0) - 15
                state.combat_log.append({
                    "turn": state.turn_number,
                    "event": "merc_contract_ended_insolvency",
                    "clan_id": clan_id,
                    "company_id": company_id,
                    "sentiment_after": company.sentiment[clan_id],
                })
                print(f"  ** MERC_STIFFED: {clan_id} lost {company_id} contract "
                      f"(insolvency) t={state.turn_number}")
```

---

## 11. New Dialogue Entries Required (town_dialogue.json)

Each NPC type needs the following keys in `assets/dialogue/town_dialogue.json`:

```json
{
  "lady_of_night": {
    "greeting": ["...", "..."],
    "standard": ["...", "..."],
    "post_visit_1": ["...", "..."],
    "post_visit_2": ["...", "..."],
    "intel_t2": ["...", "..."],
    "intel_t3": ["...", "..."],
    "guard_nearby": ["...", "..."],
    "nsfw_greeting": ["...", "..."],
    "nsfw_standard": ["...", "..."]
  },
  "shady_guy": {
    "greeting": ["...", "..."],
    "price_named": ["...", "..."],
    "intel_delivered": ["...", "..."],
    "double_agent": ["...", "..."],
    "guard_nearby": ["...", "..."],
    "nsfw_standard": ["...", "..."]
  },
  "juggler": {
    "performing": ["...", "..."],
    "coin_asked": ["...", "..."],
    "coin_declined_ok": ["...", "..."],
    "post_watch": ["...", "..."],
    "nsfw_double_entendre": ["...", "..."]
  },
  "hackey_sack": {
    "performing": ["...", "..."],
    "post_watch": ["...", "..."],
    "leaving": ["...", "..."]
  },
  "dealer": {
    "greeting": ["...", "..."],
    "inventory_offer": ["...", "..."],
    "post_purchase_intel": ["...", "..."],
    "guard_nearby": ["...", "..."],
    "no_deal": ["...", "..."],
    "nsfw_item_names": {"mystery_powder": "Rage Dust"}
  },
  "fence": {
    "greeting": ["...", "..."],
    "item_offer": ["...", "..."],
    "damaged_item_note": ["...", "..."],
    "guard_nearby": ["...", "..."],
    "after_jail": ["...", "..."],
    "nsfw_hot_goods": ["...", "..."]
  },
  "politician": {
    "greeting": ["...", "..."],
    "pre_deal": ["...", "..."],
    "deal_accepted": ["...", "..."],
    "deal_declined": ["...", "..."],
    "too_shady": ["...", "..."],
    "nsfw_alternate_favour": ["...", "..."]
  },
  "criminal": {
    "greeting": ["...", "..."],
    "shop_offer": ["...", "..."],
    "merc_offer": ["...", "..."],
    "patrol_warning": ["...", "..."],
    "post_transaction": ["...", "..."],
    "stiff_reference": ["...", "..."],
    "nsfw_standard": ["...", "..."]
  }
}
```

Actual dialogue strings are authored in a separate dialogue writing pass.
See `assets/dialogue/second_dialogue_pass.txt` for format reference.

---

## 12. Implementation Sequence (Recommended)

1. **game_state.py** — Add new fields to UnitInstance and TownInstance
2. **engine_npc.py** — Register 8 new NPC types; add personality archetypes
3. **engine_items.py** — Add 6 dealer items to ITEM_DATA
4. **engine_mercenary.py** — New file: MercenaryCompany dataclass + core functions
5. **engine_town_interior.py** — Add suspicion/shady_rep checks; fence jail roll; criminal flee
6. **engine_diplomacy.py** — Add INF to ClanInstance; add spend_influence(), earn_influence()
7. **assets/dialogue/town_dialogue.json** — Dialogue stub entries for all 8 NPC types
8. **engine_dialogue.py** — Add get_underground_npc_dialogue() routing function
9. **engine_npc.py** — Add knowledge_bleed_tick(), criminal_flee_check() functions
10. **engine_headless.py / simulate.py** — Wire new NPCs into simulation ticks

Each step is independently testable. Steps 1–3 have no external dependencies on each other
and can be done in parallel. Steps 4–6 depend on Step 1.
