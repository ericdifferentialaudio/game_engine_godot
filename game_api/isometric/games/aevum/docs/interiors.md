# Interior Maps — Aevum Design Reference
**Sprint 36 | engine/engine_interior_gen.py · engine/engine_interior.py · engine/engine_pub.py · engine/engine_castle.py · engine/startup_engine.py**

---

## Overview

When a clan unit steps onto a location hex (monster lair, town, village, castle), they enter a separate interior map on the next turn. Interior maps are pre-generated at game boot from a seeded RNG (same world seed) — every game with the same seed produces identical interiors. Interior maps use the same axial hex coordinate system as the world map.

The world map continues to resolve while units are inside interiors. Each interior map resolves on its own time slice. Dragon wake probability is suspended for all units inside any interior.

---

## Map Types

### Monster Lair (Procedural)
Generated fresh each game from the world seed. Layout: organic rooms connected by hall corridors, themed by world biome.

| Tier | Hex count | Rooms | Halls | Chests | Prisoners | Spawn roots | Survivor NPC |
|------|-----------|-------|-------|--------|-----------|-------------|--------------|
| T1 | 12–18 | 2–3 | 1–2 | 1 | 0–1 | 1 | No |
| T2 | 20–30 | 3–5 | 2–4 | 2 | 1 | 2 | No |
| T3 | 35–50 | 5–8 | 3–6 | 3 | 1–2 | 3 | Yes |
| Dragon lair | 60–80 | 8–12 | 5–8 | 4 | 0 | 0 | Yes (rare) |

**Themes** (assigned by world biome):

| Theme | Biomes | Special tile | Effect |
|-------|--------|--------------|--------|
| Cave | Mountain, Plains, Desert | None | Standard |
| Swamp | Swamp, Coast | `bog` | −1 MOV, −1 VIS |
| Crypt | Tundra | `coffin` | Visual; undead biome |
| Ruined | Forest, Desert | `debris` | −1 MOV, −1 VIS |
| Fungal | Forest, Swamp | `spore_vent` | Periodic AoE damage |

**Entry/exit**: Entrance always at axial (0, 0). Exit placed at the furthest floor cell from entrance.

**Item tiers in chests:**

| Lair tier | T1 | T2 | T3 | T4 |
|-----------|----|----|----|----|
| T1 | 100% | — | — | — |
| T2 | 60% | 40% | — | — |
| T3 | 30% | 50% | 20% | — |
| Dragon lair | — | 40% | 40% | 20% |

---

### Town (Blueprint)
Fixed layout, generated from `TOWN_BLUEPRINT` in `engine_interior_gen.py`. Consistent structure across all games. NPC slots filled at world gen from seeded roster.

```
[ENTRANCE] ─ [ENTRANCE PATH]
                  │
        ┌─── [TOWN SQUARE (fountain)] ───┐
        │                                │
  [PUB MAIN]                     [BLACKSMITH]
  [PUB CORNER]                   [HEALER HALL]
  [INN]
        │                                │
  [CONTEMPLATION HALL]         [REGENT SHOP]
                  │
              [EXIT]
```

**Town buildings and NPC slots:**

| Building | Hex offset | NPC slots | Default NPC type | Services |
|----------|-----------|-----------|-----------------|----------|
| Town Square | (0, 0) | 2 | Wanderers (any clan) | Intel T1 (free) |
| Pub | (−3, −1) | 4 | Barkeep + patrons | Intel T1–T2, diplomacy T1–T2 |
| Inn | (−4, 0) | 1 | Innkeeper (any clan) | Rest: +3 HP, T1 gossip |
| Blacksmith | (3, −1) | 1 | Smith (Dwarf/Fighter bias) | T1 weapons/armor |
| Healer's Hall | (3, 2) | 1 | Healer (Cleric/Druid bias) | HP restore, potions |
| Regent's Shop | (0, 3) | 1 | Regent (Mage/Elf bias) | Maps, T1 misc, T2–T3 lore |
| Contemplation Hall | (−3, 3) | 1 | Keeper (Monk/Cleric bias) | Mantra deposit/read |

**Contemplation Hall mechanic**: A clan may deposit a `mantra_known` token here. Other clans who visit the Hall and have Trusted+ reputation may read it (conf 0.70). Creates an organic intel sharing channel without requiring direct contact.

**Combat in towns**: Towns are neutral ground. No forced PvP — units may choose to attack, but town guards reinforce against the aggressor. Aggressor clan receives a global reputation penalty and alert.

---

### Village (Blueprint)
Smaller town variant — pub + inn + 1 general shop. No blacksmith, healer, or contemplation hall. Same neutral ground rules.

| Building | NPC slots | Notes |
|----------|-----------|-------|
| Village Square | 1 | Wanderer NPC |
| Pub | 3 | Barkeep + 2 patrons |
| Inn | 1 | Innkeeper |
| Shop | 1 | General goods (T1 only) |

---

### Castle (Blueprint)
Formal layout with distinct sections. Generated from `CASTLE_BLUEPRINT`. Larger than town, more restricted. Castle pub (great hall) serves as a secondary gossip venue.

```
[GATEHOUSE] ─ [GATE INNER]
                  │
        [THRONE ROOM (Lord/Lady)]
                  │
     ┌─── [GREAT HALL] ───┐
     │                    │
[ARMORY]           [BROKER CHAMBER]
     │                    │
[GARRISON]         [TREASURY / VAULT]
                  │
            [DUNGEON CELLS]
                  │
              [EXIT]
```

**Castle sections:**

| Section | Hex offset | NPC | Function |
|---------|-----------|-----|----------|
| Gatehouse | (0, −5) | Herald | Announces clans, warns of rivals present |
| Throne Room | (0, −3) | Lord/Lady (any clan bias) | Audience: T2 intel, passage rights |
| Great Hall | (0, −2) | Herald + 1 NPC | Formal meetings, ambient intel T1 |
| Broker Chamber | (4, −1) | Government Broker (neutral) | T3 diplomacy only |
| Armory | (−4, −1) | Arms Master (Fighter/Dwarf) | T2–T3 items at premium price |
| Treasury | (4, 1) | Treasury Guard | Raidable: 200–400g; triggers alarm |
| Treasury Vault | (4, 2) | — | Chest: 200–400g gold |
| Dungeon cells | (0,4)–(±1,4) | 1–3 Prisoners (any clan) | Rescue: T2–T3 intel |
| Garrison | (−3, 2) | 2 Guards | Reinforce on alarm; attack treasury raiders |

**Multiple clans in castle simultaneously**: Castle is neutral ground (same as town). Guards enforce peace. Both clans may use the Broker Chamber simultaneously — this is the required condition for T3 diplomacy.

---

## NPC System

### NPC Types

All NPC types can be from any of the 12 clans (or neutral). Clan assignment is seeded at world gen. Clan membership affects: dialogue tone, intel confidence, item preferences, reputation interaction threshold.

| NPC type | Locations | Intel tier | Items | Gold reward |
|----------|-----------|------------|-------|-------------|
| `barkeep` | Pub | T1–T2 (T3 via 100g bribe) | — | — |
| `innkeeper` | Inn | T1 (traveler gossip) | — | — |
| `blacksmith` | Blacksmith | — | T1 weapons/armor | — |
| `healer` | Healer Hall | T1 (local remedies) | Potions, Healing Draught | — |
| `regent` | Regent Shop | T2–T3 (maps, lore) | Maps, Shrine Map, T1 misc | — |
| `keeper` | Contemplation Hall | T3 (mantra read/deposit) | — | — |
| `wanderer` | Town Square | T1 | — | — |
| `traveler` | Pub patron | T1–T2 | — | — |
| `merchant` | Pub patron | T2 `item_in_shop` | — | — |
| `scout` | Pub patron | T2 combat/unit | — | 5g tip |
| `clan_rep` | Pub patron | T1 from clan pool | — | 5g drink |
| `herald` | Castle Gatehouse | T1 | — | — |
| `lord` | Castle Throne | T2 | — | — |
| `broker` | Castle Broker Chamber | T3 (diplomatic) | — | — |
| `arms_master` | Castle Armory | — | T2–T3 items | — |
| `guard` | Castle Garrison | — | — | — |
| `prisoner` | Lair / Castle Dungeon | T1–T3 (by tier) | — | Intel on rescue |
| `survivor` | T3 Lair / Dragon Lair | T3 (`egg_quadrant` or `mantra_known`) | — | Intel on rescue |
| `town_crier` | Town Square | T1 (global events) | — | — |

### NPC Clan Assignment

NPCs are assigned a clan at world gen. Clan biases per role:
- **Blacksmith**: Dwarf 40%, Fighter 30%, others 30%
- **Healer**: Cleric 40%, Druid 30%, Monk 20%, others 10%
- **Regent**: Mage 35%, Elf 30%, others 35%
- **Keeper**: Monk 40%, Cleric 30%, Druid 20%, others 10%
- **Wanderer/Traveler/Scout/Merchant**: equal 1/12 for each clan
- **Prisoner/Survivor**: equal 1/12 (any clan can be captured)
- **Lord/Lady**: Fighter 25%, Elf 20%, Mage 15%, others proportional

### Clan Rep Interactions

NPC warmth to visiting units is determined by the visiting clan's pub/castle reputation modifier (see `diplomacy.md`). Below −0.20 = NPC refuses non-essential interaction. Charm override bypasses this once per venue per game.

---

## Turn Timer System

### World Map
Always receives the full base turn time (30–60 seconds, set at game start).

### Interior Maps
Each active interior map receives a slice of the base turn time:

```python
time_per_interior = max(10, min(base_turn_s, base_turn_s // n_active_interiors))
```

| Active interiors | Base 30s | Base 45s | Base 60s |
|-----------------|----------|----------|----------|
| 0 | 30s (world only) | 45s | 60s |
| 1 | 30s each | 45s | 60s |
| 2 | 15s each | 22s | 30s |
| 3 | 10s each (floor) | 15s | 20s |
| 6 | 10s each (floor) | 10s (floor) | 10s |

The **world map always gets full time**. Interior maps share a fair allocation. Minimum 10 seconds per interior map — games never drop below this threshold.

### AI Time Budget
AI clans use the same time slice as human players. AI actions are pre-weighted:
- Fast branch (move, loot chest): 1 slot
- Standard branch (combat, talk to NPC): 2 slots  
- Complex branch (bribe, negotiate): 3 slots

AI selects actions to fill its time budget without exceeding it.

### UI Notification
When any interior map has active units: `"⏱ Turn extended — units exploring interior locations."` banner shown to all players.

---

## Resolution Order

Per `engine/engine_interior.py` LOCKED #123:

```
Turn resolution priority (highest first):
  DragonLair (100) → T3 lair (90) → Dungeon (80) → T2 lair (70) → T1 lair (60)
  → Castle (50) → Town (40) → Village (30) → World map (resolves last)
```

All units inside the same interior resolve together before moving to the next priority. The renderer updates after the player's current interior resolves (render hook fires via `state.render_callback`).

---

## Torch & Suppression

**LOCKED #131** — Torch effectiveness varies by interior type:

| Location | Torch | Bonfire | Camp |
|----------|-------|---------|------|
| T1 lair | Full | Full | Full |
| T2 lair | Partial | Full | Full |
| T3 lair | None | Partial | Full |
| Dragon lair | Partial | Partial | Full |
| Castle / Town / Village | None | None | None |
| Dungeon | Partial | Full | Full |

`Full` = monsters avoid lit cells + spawns suppressed within radius.
`Partial` = monsters avoid (1-hex buffer only); spawns still fire.
`None` = no monster suppression (torches still grant vision).

---

## Spawn Roots

**LOCKED #132** — Monster spawn roots are destructible objects inside lairs.

| Lair tier | Spawn rate (turns/root) | Root destroy turns |
|-----------|------------------------|--------------------|
| T1 | 1 monster / 4 turns | 2 consecutive |
| T2 | 1 monster / 3 turns | 2 consecutive |
| T3 | 1 monster / 2 turns | 2 consecutive |
| Dragon lair | No roots | — |

T3 permanent clear: once all roots are destroyed and the lair is cleared, `is_cleared = True`. No further spawns. Cleared lairs can be revisited for their gold/items freely.

---

## Chest Gold Ranges

**LOCKED #132:**

| Lair tier | Gold range per chest |
|-----------|---------------------|
| T1 | 50–100g |
| T2 | 100–200g |
| T3 | 200–400g |
| Dragon lair | 300–600g |
| Castle treasury | 200–400g |

---

## Key Engine Functions

| Function | File | Purpose |
|----------|------|---------|
| `generate_all_interiors()` | engine_interior_gen.py | Boot-time generation of all interior maps |
| `generate_lair()` | engine_interior_gen.py | Procgen monster lair by tier + theme |
| `generate_town()` | engine_interior_gen.py | Fixed blueprint town interior |
| `generate_village()` | engine_interior_gen.py | Fixed blueprint village interior |
| `generate_castle()` | engine_interior_gen.py | Fixed blueprint castle interior |
| `interior_map_time()` | engine_interior_gen.py | Turn time slice per interior map |
| `get_active_interior_count()` | engine_interior_gen.py | Count of active interior maps this turn |
| `interior_map_time()` | engine_interior_gen.py | Turn time slice per interior (renamed Sprint 36) |
| `enter_location()` | engine_interior.py | Move unit from world to interior |
| `exit_location()` | engine_interior.py | Return unit to world map |
| `broker_open_session()` | engine_castle.py | Open T3 diplomacy at castle |
| `broker_seal_agreement()` | engine_castle.py | Seal and record T3 agreement |
| `action_buy_drink()` | engine_pub.py | Pub interaction (town/village/castle) |
| `create_prisoner_intel()` | engine_intel.py | Intel from rescued prisoner |
