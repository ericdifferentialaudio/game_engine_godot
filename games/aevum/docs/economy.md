# economy.md — Economy and Production System

## Overview

Aevum uses two separate accumulating resource bars rather than raw numeric balances. Purchases happen when a bar crosses a cost threshold. This makes economic progress visible and satisfying — you watch bars fill, not just numbers increment.

**Gold Bar** → gates what you can purchase  
**Production Bar** → controls how fast things build

---

## The Two Bars

### Gold Bar

```
[Gold Bar]  ████████████░░░░░░░░░░░░░░░  84g
             colour: amber → dark amber → red below 20g
             cap: 1000g (1500g with Vault of Ages building, +500g)
```

- Accumulates from all gold income sources each turn
- Items are purchasable when the bar fills past their cost threshold
- Purchasing immediately deducts the cost — bar drops by that amount
- Gold cannot be spent below zero (no debt)
- Bar cap: **1000g** by default (`game_state.py: gold_cap`). **Vault of Ages
  building raises cap by +500g (1500g total)**
- Visual: pulse animation when a new item becomes affordable

### Production Bar

```
[Prod Bar]  ██████████░░░░░░░░░░░░░░░  14 pts  (+4/turn)
             colour: teal → bright teal when item completes this turn
             cap: 20 points
```

- Accumulates from enclave base rate + active mine improvements
- **Enclave base rate: +2 production/turn always** (no buildings or mines required)
- Pool cap: 20 points — surplus beyond 20 is lost
- Points are spent automatically each turn against the front-of-queue item
- Spend rate: **3 production points = −1 build turn** on current queue item
- Minimum 1 turn always (cannot reduce to 0 turns with production)

### Production Spend Formula

```python
def _tick_production(clan: ClanInstance, state: GameState) -> None:
    if not clan.production_queue:
        return

    item = clan.production_queue[0]

    # How many turns can we reduce this turn?
    reduction      = clan.production_points // 3
    turns_removed  = min(reduction, item.turns_remaining - 1)  # min 1 turn always
    points_spent   = turns_removed * 3

    item.turns_remaining    -= turns_removed
    clan.production_points  -= points_spent

    # Advance the base turn counter
    item.turns_remaining    -= 1   # normal turn tick
    item.turns_remaining     = max(1, item.turns_remaining)

    if item.turns_remaining <= 0:
        _complete_production(clan, item, state)
        clan.production_queue.pop(0)
```

**Example — Seeker (base 6 turns):**

| Production/turn | Points available | Reduction | Effective turns |
|----------------|-----------------|-----------|----------------|
| +2 (base only) | 2/turn | 0/turn | 6 turns |
| +4 (base + 1 hills mine) | 4/turn | 1/turn | 4 turns |
| +6 (base + 2 hills mines) | 6/turn | 2/turn | 3 turns |
| +8 (base + 3 mtn mines, Dwarf) | 8/turn | 2/turn | 3 turns* |

*Pool cap of 20 means you can bank up to 20 points before capping. Spending pattern smooths out over queue items.*

---

## Gold Income Sources

### Primary: Visible Tiles

```
+0.1g per currently visible tile per turn
Cap: 500 tiles = 50g/turn maximum from this source
```

**This is the dominant early-game income.** Map control = gold = healing = strategic advantage. All three are the same concept: visible tiles.

Visibility sources that generate tile income:
- Unit vision radius
- Watch Post permanent vision (+2 radius)
- Mage Eye in the Sky wonder (all tiles visible)

Tiles under fog of war earn **nothing**. Losing Scouts immediately reduces income.

### Farm Improvements

```
+1g/turn per active Farm hex (while visible to owning clan)
Built by: Farmer worker unit (2 turns on plains or grasslands)
```

Farms generate the same income whether on plains or grasslands. One farm = 10 visible tiles in gold value. Five farms (worker cap) = +5g/turn = equivalent to a Bank building, with no gold build cost.

### Passive Buildings

| Building | Gold/turn | Build cost | Build turns | Requires |
|----------|-----------|------------|-------------|---------|
| Bank | +5 | 80g | 3t | — |
| Vault | +10 | 120g | 4t | Bank |

Vault also raises the Gold Bar cap from 500g to 750g.

### Village Garrison

```
+3g/turn per village where a clan unit is adjacent (garrisoning)
```

Garrisoning also extends the friendly territory (healing zone) around the village.

### Combat Income (one-time)

| Source | Amount |
|--------|--------|
| T1 monster kill | 10–15g |
| T2 monster kill | 25–35g |
| T3 monster kill / lair prize | 50g + item |
| Lair prize (cleared) | 100–300g + item |
| Enemy unit kill | 5% of enemy clan treasury |
| Dragon slain | 500g to killing clan |

### Shrine Knowledge Sales

```
Deposit shrine knowledge at Contemplation Hall → receive sell price
1 contributor: 200g sell price
2 contributors: 150g
3 contributors: 100g
4+ contributors: 60g
```

See `diplomacy.md` for full spiritual economy mechanics.

### Selling Meditation Rights

Negotiated gold received when a rival clan purchases rights to meditate your shrine. Typically 100–300g depending on how contested the shrine is and current game state.

---

## Production Income Sources

### Enclave Base

```
+2 production points/turn always
No buildings or mines required. Cannot be reduced.
```

### Mine Improvements

| Terrain | Production/turn | Clan restriction |
|---------|----------------|-----------------|
| Hills | +1 | None |
| Mountain | +2 | Dwarf, Ranger only |

Built by Miner worker units (2 turns on target hex). Active only while hex is visible to owning clan.

---

## The Enclave Panel — Threshold Purchasing

Opening the enclave panel (press **P** or click the enclave hex) shows all purchasable items with their cost thresholds on the Gold Bar.

```
╔══════════════════════════════════════════════════════════════╗
║  ENCLAVE — Ranger Clan          Turn 11   Shrine Wars       ║
╠══════════════════════════════════════════════════════════════╣
║  Gold:        ██████████████░░░░░  84g   +7/turn            ║
║               ▲  ▲         ▲      ▲                         ║
║              20g 30g      60g    80g                         ║
║                                                              ║
║  Production:  ████████░░░░░░░░░░░  14pt  +4/turn            ║
╠══════════════════════════════════════════════════════════════╣
║  UNITS               Cost    Base    Est.    Status          ║
║  Scout               20g     2t      2t      ✓ AVAILABLE     ║
║  Archer              40g     3t      2t      ✓ AVAILABLE     ║
║  Farmer / Miner / Forester  30g  3t  2t     ✓ AVAILABLE     ║
║  Diplomat            60g     3t      2t      ✓ AVAILABLE     ║
║  Clan Unit (Ranger)  50g     3t      2t      ✗ Need Barracks ║
║  Chieftain           150g    5t      4t      ✗ Need 150g     ║
║  Seeker              200g    6t      4t      ✗ Need Avatar   ║
╠══════════════════════════════════════════════════════════════╣
║  BUILDINGS           Cost    Base    Est.    Status          ║
║  Barracks            60g     3t      2t      ✗ Need 60g (−24g)║
║  Bank                80g     3t      2t      ✗ Need 80g      ║
║  Watchtower          50g     2t      1t      ✗ Need 50g      ║
║  Library             70g     3t      2t      ✗ Need 70g      ║
╠══════════════════════════════════════════════════════════════╣
║  RESEARCH            Cost    Turns   Status                  ║
║  Scouting            60g     3t      ✗ Need 60g (−24g)       ║
║  Engineering         80g     4t      ✗ Need 80g              ║
║  Military Doctrine   70g     3t      ✗ Need 70g              ║
║  Scholarship         60g     3t      ✗ Need 60g (−24g)       ║
╠══════════════════════════════════════════════════════════════╣
║  QUEUE (max 3):  [Scout 2t] [Archer 2t] [______]            ║
╚══════════════════════════════════════════════════════════════╝
```

**Column meanings:**
- **Cost** — gold required (deducted from Gold Bar immediately on purchase)
- **Base** — base build turns without production acceleration
- **Est.** — estimated actual turns given current production rate
- **Status** — ✓ AVAILABLE (can purchase now) or ✗ with reason

**Threshold markers** on the Gold Bar show the cost of each available category's cheapest item. Bar filling past a marker lights up that item.

### Purchase Rules

1. Click an AVAILABLE item → enters production queue. Gold deducted immediately.
2. Queue maximum: **3 items** (units, buildings, and research share this limit)
3. Research uses a **separate dedicated slot** — does not count toward the 3-item queue
4. If gold drops below cost after queuing (raid, rights deal): item stays queued — it was already paid
5. Items show estimated completion turn accounting for current production rate
6. Structures (Watch Post, Fort, Trap) are purchased from the queue and become available for unit placement

### The Research Slot

Research operates independently from the 3-item production queue:

```
Production Queue:   [Scout 2t] [Barracks 2t] [Archer 2t]    ← 3 items max
Research Queue:     [Scouting 3t]                             ← separate, 1 at a time
```

Both tick simultaneously each turn. Researching does not delay unit/building production and vice versa.

---

## Sidebar HUD Bars

The Gold Bar and Production Bar are visible in the **left sidebar at all times**, not only in the Enclave Panel.

```
Left sidebar (always visible):
┌────────────────────┐
│ Gold               │
│ ████████░░  84g    │
│ +7/turn            │
│                    │
│ Production         │
│ ██████░░░░  14pt   │
│ +4/turn            │
└────────────────────┘
```

**Bar colour states:**

| Bar | Normal | Warning | Critical |
|-----|--------|---------|---------|
| Gold | Amber | Dark amber (< 30g) | Red pulse (< 15g) |
| Production | Teal | — | Bright teal flash (item completes this turn) |

**One-time income flash:** When a monster kill, lair prize, or rights payment arrives, both bars briefly pulse to indicate the deposit.

---

## ClanInstance Economy Fields

```python
# Gold tracking
gold:                    int      # current gold (Gold Bar fill level)
gold_cap:                int      # 500 default, 750 with Vault
gold_per_turn:           float    # total computed income this turn
gold_per_turn_breakdown: dict     # {"tiles": 4.2, "farms": 2, "bank": 5, ...}

# Production tracking
production_points:       int      # current pool (0–20)
production_per_turn:     int      # base 2 + active mines
production_breakdown:    dict     # {"enclave_base": 2, "hills_mine_1": 1, ...}

# Queue
production_queue:        list[ProductionQueueItem]  # max 3
research_queue:          list[ResearchQueueItem]    # max 1 active
```

---

## Economy Phase — EndOfTurnProcessor Order

Called each turn after all movement and combat resolves:

```python
def _process_economy(self, state: GameState) -> None:
    for clan_id, clan in state.clans.items():
        if clan.is_eliminated:
            continue

        # 1. Count visible tiles → gold
        visible_count = sum(
            1 for cell in state.world_map.cells.values()
            if cell.is_visible.get(clan_id, False)
        )
        tile_gold = min(visible_count, 500) * 0.1

        # 2. Active improvements → gold and production
        farm_gold   = 0
        mine_prod   = 0
        lumber_regen= 0
        for imp in state.improvements.values():
            if imp.clan_id != clan_id or imp.is_pillaged:
                continue
            cell = state.world_map.cells.get((imp.q, imp.r))
            if not cell or not cell.is_visible.get(clan_id, False):
                imp.is_active = False
                continue
            imp.is_active = True
            farm_gold    += imp.gold_per_turn
            mine_prod    += imp.production_per_turn
            lumber_regen += imp.mp_regen_bonus

        # 3. Passive buildings
        building_gold = 0
        if "bank"  in clan.buildings: building_gold += 5
        if "vault" in clan.buildings: building_gold += 10

        # 4. Village garrison
        garrison_gold = sum(
            3 for v in state.villages.values()
            if v.garrisoned_by_clan_id == clan_id
        )

        # 5. Apply gold
        total_gold = tile_gold + farm_gold + building_gold + garrison_gold
        clan.gold  = min(clan.gold + total_gold, clan.gold_cap)
        clan.gold_per_turn = total_gold
        clan.gold_per_turn_breakdown = {
            "tiles":    round(tile_gold, 1),
            "farms":    farm_gold,
            "buildings": building_gold,
            "garrison": garrison_gold,
        }

        # 6. Apply production
        clan.production_points = min(
            clan.production_points + 2 + mine_prod,   # 2 = enclave base
            20   # pool cap
        )
        clan.production_per_turn   = 2 + mine_prod
        clan.production_breakdown  = {
            "enclave_base": 2,
            "mines": mine_prod,
        }

        # 7. Apply MP regen from Lumber Posts
        if lumber_regen > 0:
            for uid in clan.unit_ids:
                unit = state.units.get(uid)
                if unit and unit.is_alive and unit.mp_max > 0:
                    unit.mp_current = min(
                        unit.mp_current + lumber_regen,
                        unit.mp_max
                    )
```

---

## Complete Cost Reference

### Units

| Unit | Gold | Base turns | Requires |
|------|------|-----------|---------|
| Scout | 20g | 2t | — |
| Archer | 40g | 3t | — |
| Farmer | 30g | 3t | — |
| Miner | 30g | 3t | — |
| Forester | 30g | 3t | — |
| Diplomat | 60g | 3t | Scholarship tech |
| Clan Unit | 50g | 3t | Barracks |
| Chieftain | 150g | 5t | Military Doctrine + Barracks II |
| Siege Engineer | 100g | 5t | Fighter + Barracks II + clan building |
| Arcanist | 120g | 5t | Mage + Barracks II + clan building |
| High Priest | 100g | 5t | Cleric + Barracks II + clan building |
| Runesmith | 80g | 4t | Dwarf + Barracks II + clan building |
| Trapper | 80g | 4t | Ranger + Barracks II + clan building |
| Starbow | 100g | 5t | Elf + Barracks II + clan building |
| Assassin | 120g | 5t | Rogue + Barracks II + clan building |
| Iron Fist | 100g | 4t | Monk + Barracks II + clan building |
| Thornweaver | 80g | 4t | Druid + Barracks II + clan building |
| Death Knight | 120g | 5t | Necromancer + Barracks II + clan building |
| Spymaster | 100g | 4t | Bard + Barracks II + clan building |
| Stormcaller | 120g | 5t | Shaman + Barracks II + clan building |
| Seeker | 200g | 6t | Avatar status + Sanctum |

### Buildings

| Building | Gold | Turns | Requires |
|----------|------|-------|---------|
| Barracks | 60g | 3t | — |
| Barracks II | 100g | 4t | Barracks |
| Bank | 80g | 3t | — |
| Vault | 120g | 4t | Bank |
| Watchtower | 50g | 2t | — |
| Library | 70g | 3t | — |
| Walls II | 90g | 4t | — |
| Sanctum | 150g | 5t | Avatar status |
| Clan building (any) | 80–100g | 3–4t | Barracks II |

### Structures (placed by units on map)

| Structure | Gold | Build action | Requires |
|-----------|------|-------------|---------|
| Watch Post | 40g | 1 unit-turn | Scouting tech |
| Fort | 80g | 2 unit-turns | Engineering tech |
| Trap | 20g | Instant action | Engineering tech |
| Tripwire | 25g | Instant action | Advanced Trapping tech |
| Rune Ward | 50g | 1 unit-turn | Arcane Engineering tech |

### Technology Research

| Tech | Gold | Turns | Tier |
|------|------|-------|------|
| Scouting | 60g | 3t | T1 |
| Engineering | 80g | 4t | T1 |
| Military Doctrine | 70g | 3t | T1 |
| Scholarship | 60g | 3t | T1 |
| Advanced Trapping | 100g | 4t | T2 |
| Fortification | 120g | 5t | T2 |
| Chieftain's Code | 100g | 4t | T2 |
| Arcane Engineering | 140g | 5t | T2 |
| Grand Strategy | 180g | 6t | T3 |
| Master Engineering | 160g | 6t | T3 |
| Eternal Alliance | 150g | 5t | T3 |
| Enlightenment | 200g | 7t | T3 |
| Clan Wonder | 300g | 10t | Post-T3 |

### Items (shop purchases)

| Item | Gold | Slot |
|------|------|------|
| Iron Shield | 40g | Any |
| Swift Boots | 50g | Any |
| Keen Blade | 50g | Any |
| Lantern | 30g | Any |
| Healing Potion | 35g | Any (consumable) |
| Shrine Map | 60g | Any (consumable) |
| Spell Scroll | 80–150g | Any (consumable) |
| Frostblade | 120g | Melee |
| Runic Axe | 100g | Melee (Dwarf only) |
| Longbow | 80g | Archer |
| Stormbow | 110g | Archer |
| Mana Staff | 90g | Caster (T2+ magic) |
| Focus Crystal | 100g | Caster (T2+ magic) |
| Amulet of Swiftness | 80g | Seeker |
| Warding Stone | 60g | Seeker |
| Flameblade, Shadowblade, Soulreaver, Elfbow, Shadowbow, Spell Staff, Exhaust Sigil, Seeker's Crystal, Ghost Cloak | Free | Rare lair drops only |

### Shrine Knowledge (Contemplation Hall)

| Contributors | Buy price | Sell price |
|-------------|-----------|------------|
| 1 clan | 400g | 200g |
| 2 clans | 300g | 150g |
| 3 clans | 200g | 100g |
| 4+ clans | 120g | 60g |

---

## Gold Healing Connection

Visible territory is the same as friendly territory is the same as the gold-generating zone. All three are unified:

```python
# Any hex visible to the clan:
is_friendly  = cell.is_visible.get(clan_id, False)
# If friendly: earns 0.1g/turn AND heals units AND is "safe" territory
```

**Healing rates in visible territory:**

| Condition | HP regen/turn |
|-----------|--------------|
| Any visible hex | +1 combat HP |
| + Cleric adjacent | +2 combat HP |
| + Cathedral of Mercy wonder | +2 combat HP (stacks to +3 with Cleric) |
| On enclave hex | +2 combat HP |

Exhaustion HP does NOT heal from territory. Only Velmoor town (25g/HP, 3 uses/clan/game).

---

## Economic Pacing by Phase

| Phase | Turns | Gold income character |
|-------|-------|----------------------|
| Expansion | 1–6 | 10–25g/turn from tiles. First farm/mine coming online. |
| Contact | 7–12 | 20–40g/turn. Bank built. Monster clears add one-time gold. |
| Shrine Wars | 13–22 | 30–60g/turn. Rights deals add income. Vault may be built. |
| Avatar Race | 23–28 | 40–80g/turn. Shrine knowledge selling peaks. |
| Gauntlet | 28+ | Variable. Dragon kill = 500g one-time surge. |

**Gold shortage is intentional.** Every turn requires trade-offs between units, buildings, research, rights deals, and shrine credits. A clan that overinvests in buildings too early has no gold for rights deals. A clan that buys too many rights deals has no buildings. The economy is meant to always feel tight.