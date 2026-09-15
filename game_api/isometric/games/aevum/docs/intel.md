# Intel System — Aevum Design Reference
**Sprint 36 | engine/engine_intel.py · engine/engine_intel_tokens.py · engine/engine_pub.py**
*Verified against engine_intel.py function names 08/24/2026 (batch 2 compaction) — accurate.*

---

## Overview

Imperfect, perishable information flows between clans, settlements, and NPCs. Clans never see full world state — they act on what they've learned, rumoured, or bought. Intel is stored as typed tokens with a confidence value, a validity window, and a propagation wave spreading outward from the point of learning.

---

## Intel Tiers

### T1 — Vague / Directional
Low confidence. Fast decay. Sources: overheard pub gossip, Town Crier, distant witness.

| Token type | Description example | Validity | Base conf | Decay/turn |
|------------|---------------------|----------|-----------|------------|
| `combat_vague` | "Fighting reported to the west." | 5t | 0.50 | 0.08 |
| `dragon_vague` | "The Dragon was seen near the northern pass." | 8t | 0.55 | 0.04 |
| `shrine_meditated_anon` | "A shrine was consecrated somewhere to the south." | 20t | 0.55 | 0.02 |
| `item_in_region` | "Rare goods spotted in a market to the east." | 10t | 0.45 | — |

### T2 — Specific / Named
Medium confidence. Requires Trusted+ pub tier or direct witness. Decay begins at validity/2.

| Token type | Description example | Validity | Base conf | Decay/turn |
|------------|---------------------|----------|-----------|------------|
| `combat_specific` | "Ranger and Fighter clashed north-west of Caldspire on turn 14." | 8t | 0.70 | 0.06 |
| `dragon_spotted` | "Dragon seen awake near the Keep's western approach on turn 14." | 10t | 0.75 | 0.05 |
| `shrine_meditated_named` | "Elf clan meditated Shrine of the Wild on turn 12." | 20t | 0.75 | 0.01 |
| `spell_cast_event` | "A T4 Lightning Storm was unleashed near the northern hills on turn 9." | 5t | 0.65 | 0.10 |
| `unit_spotted` | "Mage Seeker spotted moving south on turn 11." | 5t | 0.70 | 0.08 |
| `item_in_shop` | "The Moonsilver Bow is available at Velmoor." | 10t | 0.90 | — |
| `monster_weakness` | "The cave troll at Ironpass is weak to fire." | 999t | 1.00 | — |
| `dungeon_layout` | "A prisoner described the layout of the eastern lair." | 25t | 0.80 | — |

> `spell_cast_event` only fires for T3+ spells — lower tiers are not noteworthy enough to gossip about.

### T3 — Authoritative / Permanent
High confidence. Permanent or very slow decay. These are the most strategically valuable tokens.

| Token type | Description example | Validity | Base conf | Decay |
|------------|---------------------|----------|-----------|-------|
| `mantra_known` | `Mantra of Shrine of Compassion: "Breathe, release, remain."` | 999t | 1.00 direct / 0.80 secondhand / 0.65 pub bribe | None |
| `shrine_location` | "Shrine of the Wild lies to the south-east, approximately 12 hexes from the centre." | 999t | 1.00 scouted / 0.85 prisoner / 0.65 gossip | None |
| `cleric_shrine_rule` | "Cleric clan always meditates the Shrine of Compassion." | 999t | 1.00 | None — common knowledge |
| `egg_quadrant` | "The egg lies to the north." | 999t | 0.85–1.00 | None |
| `diplomatic_intel` | Any intel transferred from an ally (−0.10 confidence penalty). | Same as original | original −0.10 | Same as original |

---

## Sources by Token Type

| Token | Direct meditation | Pub bribe | Prisoner rescue | Mantra swap | Castle broker |
|-------|:-:|:-:|:-:|:-:|:-:|
| `mantra_known` | ✅ (1.00) | ✅ 100g (0.65) | ✅ T3 lair (0.85) | ✅ (0.80) | ✅ (0.80) |
| `shrine_location` | ✅ scouted (1.00) | ✅ 50g (0.65) | ✅ T2+ lair (0.85) | ✅ bundled (0.80) | — |
| `shrine_meditated_anon` | ✅ auto-fires | ✅ | — | — | — |
| `shrine_meditated_named` | ✅ auto-fires | ✅ | — | — | — |
| `combat_specific` | ✅ witness | ✅ | ✅ scout NPC | — | — |
| `dragon_spotted` | ✅ witness | ✅ | — | — | — |
| `egg_quadrant` | — | — | ✅ T3 lair Survivor | — | — |

---

## Shrine Meditation Pipeline

When any clan completes a shrine meditation, `engine_mantras.py` calls `create_shrine_meditated_intel()`:

```
Shrine meditation completes (any clan)
  ↓
T1 token created:  shrine_meditated_anon (conf 0.55, direction only)
T2 token created:  shrine_meditated_named (conf 0.75, clan + shrine + turn)
Both enter gossip pools of nearby settlements (within 15 hexes)
  ↓
T1 surfaces in pubs at Acquaintance+ tier
T2 surfaces only at Trusted+ tier
  ↓
Special case: Cleric + Shrine of Compassion
  → T3 cleric_shrine_rule created for ALL clans immediately
  → known_by_all = True, no decay, no propagation delay
```

**Mantra acquisition** (separate from meditation event):
```
Direct meditation → create_mantra_known_intel(conf=1.0, source='direct_meditation')
Mantra swap (Castle Broker) → conf=0.80, source='mantra_swap'
Pub bribe 100g → conf=0.65, source='pub_bribe'
Prisoner/Survivor rescue → conf=0.85, source='prisoner'
```

---

## Propagation

### Intra-Clan Wave (LOCKED #127)
Intel learned by any unit propagates outward from that unit's position at:
- **3 hex/turn** (standard units)
- **4 hex/turn** (Bard, Diplomat)
- **2 hex/turn** (Rogue)

At radius ≥ 45 hexes: `known_by_all = True` — all living clan units know it.  
**Full-clan propagation: ~5–15 turns** on standard maps.

### Population Dissemination (LOCKED #128)
Intel spreads through civilian population from its origin at **1–2 hex/turn**.  
Confidence decays by distance from origin:

| Distance | Confidence |
|----------|------------|
| ≤ 10 hex | 0.675 |
| ≤ 25 hex | 0.400 |
| ≤ 40 hex | 0.175 |
| > 40 hex | 0.075 |

Intel appears in settlement **gossip pools** once it arrives. It surfaces at pubs based on relationship tier.

### Confidence Decay
Applied each turn after the intel is `validity_turns / 2` old:

| Token type | Decay per turn |
|------------|---------------|
| `spell_cast_event` | −0.10 |
| `combat_vague` | −0.08 |
| `unit_spotted` | −0.08 |
| `combat_specific` | −0.06 |
| `dragon_spotted` | −0.05 |
| `dragon_vague` | −0.04 |
| `shrine_meditated_named` | −0.01 |
| `shrine_meditated_anon` | −0.02 |
| All T3 tokens | 0 (no decay) |

---

## Pub Gossip Surface (LOCKED #128)

Intel enters pubs via gossip pools. Surfacing requires a clan unit to be in the pub. Amount surfaced depends on relationship tier:

| Tier | Min confidence to surface | Max items per visit | Notes |
|------|--------------------------|--------------------|----|
| Stranger | — | 0 | Nothing (listen in only) |
| Acquaintance | 0.50 | 1 | T1 only |
| Regular | 0.40 | 1–2 | T1–T2 |
| Trusted | 0.30 | 2 | T1–T2, some T3 shrine hints |
| Confidant | 0.10 | 2+ | All tiers |

Own clan's intel is never surfaced back to them.

---

## Pub Leak (LOCKED #129)

Each pint consumed by a unit increases the chance the unit inadvertently reveals clan intel into the pub gossip pool. The leak is silent — the player never sees it happen.

| Pints | Base leak % | Notes |
|-------|------------|-------|
| 1 | 5% | Very unlikely |
| 2 | 12% | Low risk |
| 3 | 22% | Moderate |
| 4 | 35% | Real risk |

**Clan modifiers:**
- Bard, Rogue: ×0.5 (more careful, or professionally discreet)
- Shaman: ×1.5 (loose-lipped)
- All others: ×1.0

Leaked intel enters the gossip pool at `confidence − 0.30`. It carries the origin clan's ID so rivals can attribute it.

---

## Intel Log ('I' Key) (LOCKED #130)

Press `I` in-game to open the Intel Log overlay. Displays all known intel for the active clan, sorted newest first.

**Confidence display:**
- **HIGH** (≥ 0.70): Green
- **MED** (0.40–0.69): Yellow
- **LOW** (< 0.40): Red — description is partially obscured ("... rumour ...")

**STALE** flag shown when `current_turn − learned_turn > validity_turns`.

---

## NPC Intel Sources

### Pub Patrons
| NPC type | Intel tier | Cost | Notes |
|----------|------------|------|-------|
| Barkeep | T1–T2 (T3 via 100g bribe) | 2–100g | Relationship-gated |
| Traveling Merchant | T2 `item_in_shop` | Free | Talks about goods freely |
| Wandering Scout | T2 `combat_specific`, `unit_spotted` | 5g tip | |
| Clan Representative | T1 from their clan's pool | 5g drink | Appears when rival clan unit is in town; carries non-strategic intel only |

### Lair NPCs
| NPC type | Intel tier | Source |
|----------|------------|--------|
| Prisoner (T1/T2 lair) | T1–T2 `dungeon_layout`, `shrine_location` | Rescue from cell |
| Prisoner (T3 lair) | T2–T3 | Rescue — includes `shrine_location` |
| Survivor (T3/Dragon lair) | T3 `egg_quadrant` or `mantra_known` | Rare, only T3+ lairs |

### Town & Castle NPCs
| NPC type | Intel tier | Location | Cost |
|----------|------------|----------|------|
| Scholar (Regent's Shop) | T2–T3 (shrine lore, maps) | Town | 25–50g |
| Town Crier | T1 (global events) | Town square | Free (passive) |
| Lord/Lady | T2 | Castle Throne Room | Relationship ≥ Regular |
| Dungeon Prisoner | T2–T3 | Castle dungeon | Rescue |

---

## AI Intel Use

The AI evaluates its known intel each turn to adjust strategic goal weights:

```
mantra_known (shrine X, conf ≥ 0.40):
  → advance_shrines[shrine_X] += 0.15 + (conf × 0.25)
  → full conf (1.0): +0.40    secondhand (0.80): +0.35    pub bribe (0.65): +0.31

shrine_location (shrine X, known):
  → Unlocks pathfinding to shrine X hex
  → Without this: AI will not route to unscouted shrine hexes

dragon_spotted (recent, conf ≥ 0.50):
  → Dragon proximity threat: temporarily reduces shrine-advance weight by 0.20
  → Triggers defensive clustering if threat is within 8 hexes

egg_quadrant (known):
  → If JointDragonAssaultPact is available: +0.30 to diplomat_dispatch goal
```

---

## Diplomatic Intel Transfer

Allies can transfer intel directly via diplomat encounter. Confidence takes a −0.10 hit on transfer (secondhand knowledge). `diplomatic_intel` tokens carry `source_clan_id` for attribution.

See `diplomacy.md` for the Castle Broker mantra swap flow.

---

## Key Engine Functions

| Function | File | Purpose |
|----------|------|---------|
| `acquire_intel()` | engine_intel.py | Register intel for a clan, start propagation wave |
| `intel_propagation_tick()` | engine_intel.py | **LIVE** (08/30/2026) — advances intra-clan wave. Called every 5t by `engine_headless.intel_spread_tick()`, a `TURN_SEQUENCE` entry. |
| `population_dissemination_tick()` | engine_intel.py | **LIVE** (08/30/2026) — spreads intel through civilian settlements. Called every 5t by `intel_spread_tick()`. |
| `confidence_decay_tick()` | engine_intel.py | **LIVE** (08/30/2026) — decays mutable intel confidence. Called every 5t by `intel_spread_tick()`. |
| `create_clan_virtue_leader_intel()` | engine_intel.py | **LIVE** (08/30/2026) — NAMED leader alarm; see below. |

> ### The intel SPREAD layer is now live (CHAOS_REGION_PLAN Phase 1, 08/30/2026)
>
> The three functions above were dead code until this session — zero callers,
> absent from `engine_headless.TURN_SEQUENCE`. They are now wired in via
> `engine_headless.intel_spread_tick()`, a `TURN_SEQUENCE` entry gated to run
> every 5 turns (perf: each iterates clan_intel × units/settlements). All of
> the design below (waves, distance-based confidence decay, and
> clan→settlement→rival spread) is now live behaviour, shared identically by
> headless/Atlas/interactive via the single `TURN_SEQUENCE` manifest.
>
> Before this fix: `acquire_intel()` wrote a token into
> `state.clan_intel[clan_id]` and it stayed there, at full confidence, forever.
> `KnownIntel.learned_at`, `.propagation_speed` (and the per-unit-type
> `_PROP_SPEED` table), the `_POP_CONF` distance table, and the 45-hex
> `known_by_all` threshold were all inert data — now live.

| Function | File | Purpose |
|----------|------|---------|
| `pub_gossip_surface()` | engine_intel.py | Draw intel from pub pool at visit |
| `pub_leak_check()` | engine_intel.py | Check if unit leaks intel while drinking |
| `create_shrine_meditated_intel()` | engine_intel.py | Fired by engine_mantras on shrine completion |
| `create_mantra_known_intel()` | engine_intel.py | Create T3 mantra token (any source) |
| `create_shrine_location_intel()` | engine_intel.py | Create T3 shrine location token |
| `create_combat_intel()` | engine_intel.py | T1+T2 tokens on combat event |
| `create_dragon_intel()` | engine_intel.py | T1 or T2 dragon tokens |
| `create_spell_cast_intel()` | engine_intel.py | T2 spell token (T3+ spells only) |
| `create_prisoner_intel()` | engine_intel.py | Intel from lair prisoner/survivor |
| `diplomatic_intel_transfer()` | engine_intel.py | Ally-to-ally intel share |
| `get_intel_log()` | engine_intel.py | Return sorted log for 'I' overlay |
