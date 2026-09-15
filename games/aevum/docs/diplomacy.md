# Diplomacy System — Aevum Design Reference
**Sprint 17–30 | engine/engine_diplomacy.py · engine/engine_pub.py · engine/engine_castle.py**
*Verified against engine_castle.py (broker_seal_agreement, broker_announce_breach, _transfer_mantras) 08/24/2026 (batch 2 compaction) — accurate.*

---

## Overview

Diplomacy is tiered by venue. Low-stakes deals happen in pubs over drinks; binding alliances require the formal witness of a Government Broker inside a castle. Each tier has different agreement types, costs, and breach consequences.

No separate "Diplomat" unit type exists — any clan unit can initiate diplomacy at the appropriate venue.

---

## Diplomacy Tiers

| Tier | Venue | Agreements available | Witness | Breach penalty |
|------|-------|---------------------|---------|----------------|
| **T1** | Pub (any) | Open communication, rumour trade, meeting arrangement | None | None (verbal) |
| **T2** | Pub (Trusted+) or world map | Non-Aggression Pact, Knowledge Purchase, Border Arrangement | None | −1 virtue, reputation hit |
| **T3** | Castle (Government Broker) | Full Alliance, Mutual Shrine Plan, Joint Dragon Assault, Mantra Exchange | Broker NPC | Global announcement + −2 rep with castle + −1 virtue |

---

## Pub Diplomacy (T1–T2)

### Requirements
- Unit enters a town or village pub hex (1 move action)
- A rival clan's unit must also be present (Clan Representative NPC spawns automatically)
- Relationship tier must be at least **Acquaintance** for T2 offers

### Pub Actions

**[1] Buy a drink** — 2g  
Increments relationship score (+2). Surfaces gossip intel at current tier. Triggers pub leak check.

**[2] Buy a round** — 8g  
Relationship score +5. Surfaces up to 3 gossip items. Higher pint count = higher leak risk.

**[3] Listen at the bar** — Free  
Surfaces 1 T1 gossip item. No relationship change. No leak risk. Once per visit.

**[4] Talk to a patron** — 0–5g tip  
Interact with a specific NPC. Merchant = item intel free. Scout = combat intel (5g tip). Clan Rep = 5g drink to surface 1 T1 from their clan's pool.

**[5] Offer a bribe** — 20g / 50g / 100g  
- 20g → 1 gossip item at existing confidence
- 50g + topic → best topic-matching item (shrine / dragon / items / rival)
- 100g → confidence of surfaced item boosted +0.20

**[6] Propose terms** — Free  
Offer a T1–T2 agreement to a rival clan representative. T3 deals are refused with a redirect to the castle.

### T1–T2 Agreement Types (Pub)

| Agreement | Terms | Duration | Breach |
|-----------|-------|----------|--------|
| `OpenChannel` | Both clans may exchange T1 intel passively each turn via gossip pool | 10 turns | None |
| `KnowledgePurchase` | One-time transfer: buyer pays N gold, seller provides 1 T2 intel token | Instant | N/A |
| `NonAggressionPact` | Neither clan attacks the other's units | 10 turns | −1 virtue + global report |
| `BorderArrangement` | Agreed hex corridor neither clan contests | 8 turns | −1 virtue |

---

## Clan Representative (Pub NPC)

When a rival clan has a unit in the same town, a **Clan Representative** NPC spawns in the pub. They:
- Carry 1–2 T1/T2 intel tokens from their clan's pool (non-strategic — no mantras, no egg quadrant, no shrine locations)
- Will share intel for a 5g drink, subject to reputation threshold
- Can receive pub-level deal proposals
- Refuse interaction if visiting clan's reputation is below −0.20 (unless Charm override is active)

**Clan Representative appearance** is dynamic — they are present only while their clan's unit is in the same town hex. They disappear the turn the unit leaves.

---

## Castle Diplomacy (T3)

### Requirements
- Both clans must have a living unit **physically inside the castle hex** — same turn, or within 1 turn of each other (the Broker holds the meeting)
- The **Government Broker** NPC is present in the Broker Chamber
- Clan reputation with the castle must be ≥ 0.00 (Neutral) — Rogue and Necromancer clans may be refused unless Charm override is active

### Government Broker

A neutral NPC present in every castle's Broker Chamber. The Broker:
- Validates both clans' presence before opening negotiations
- Records the agreement terms in castle ledger (persisted in `state.castle_ledgers`)
- Announces breaches publicly (all clans receive T2 `diplomatic_intel` token: "[Clan] broke a Castle-sworn agreement")
- Applies permanent −2 reputation with the castle town to the breaching clan

The Broker does **not** facilitate pub-level deals — proposals that fall under T1/T2 are redirected to the pub with a line: *"Small matters like that are better settled over a drink."*

### T3 Agreement Types (Castle)

| Agreement | Terms | AI trigger | Duration |
|-----------|-------|------------|----------|
| `FullAlliance` | Shared vision, shared gossip pools, mutual military support | Both clans ≥ 50% to shrine completion | 8 turns |
| `MutualShrinePlan` | Both clans meditate a named target shrine; neither blocks the other's approach | Both have matching `mantra_known` for target shrine | 10 turns |
| `JointDragonAssaultPact` | Neither attacks the other within 6 hexes of Dragon's Keep; both share `dragon_spotted` intel automatically | Both clans ≥ 50% shrine complete, Dragon awake | Until Dragon dead |
| `MantraExchange` | Bilateral `mantra_known` transfer; both clans gain the other's shrine mantra at conf 0.80 | Each clan has a mantra the other lacks | Instant (permanent) |
| `PassageRights` | One clan may freely move through the other's enclave zone for N turns | Tactical need detected by AI | 6 turns |

### Castle Diplomacy Flow

```
Both clan units arrive at castle hex (same or adjacent turns)
  ↓
Government Broker opens chamber:
┌──────────────────────────────────────────────────────┐
│  CASTLE OF THE GREY KEEP — Broker Aldric             │
│  Present: Ranger clan · Druid clan                   │
│  ────────────────────────────────────────────────    │
│  [1] Full Alliance              (8 turns)            │
│  [2] Mutual Shrine Plan         (name shrine)        │
│  [3] Non-Aggression Pact        (10 turns) [T2 alt]  │
│  [4] Joint Dragon Assault Pact  (until Dragon dead)  │
│  [5] Mantra Exchange            (bilateral, instant)  │
│  [6] Passage Rights             (6 turns)            │
│  [7] Decline all terms                               │
│  ⏱ 10s                                               │
└──────────────────────────────────────────────────────┘
  ↓
Both clans confirm (or one declines)
  ↓
Broker records in castle_ledgers[castle_id]
Agreement becomes active next turn
```

### Breach Consequences (Castle-sworn)

1. **Global intel token**: All clans receive T2 `diplomatic_intel`: *"[Clan] broke a Castle-sworn agreement with [Clan] on turn N."*
2. **Castle reputation**: Breaching clan −2 permanent rep with that castle's town (affects NPC warmth and future diplomacy access)
3. **Virtue penalty**: −1 shrine stat (same as standard breach)
4. **AI response**: All clans reduce trust weight for the breaching clan by −0.20 in their diplomacy scoring

---

## Relationship Tiers (Pub)

Relationship score is tracked per clan per pub venue in `state.pubs[town_id].clan_visits`.

| Tier | Score threshold | Intel access | Bribery discount |
|------|----------------|--------------|-----------------|
| Stranger | 0 | Listen in only (T1) | None |
| Acquaintance | 3 | T1 gossip on drink | Minimal |
| Regular | 10 | T1–T2 on drink/round | 10% |
| Trusted | 25 | T1–T2 on drink; T3 hints on bribe | 20% |
| Confidant | 50 | All tiers; max leak check reduced | 30% |

---

## Clan NPC Reputation Modifiers

NPC warmth at pubs and castles is adjusted by the visiting clan's base reputation. This affects: intel surfacing willingness, bribery cost multiplier, dialogue tone, and Clan Rep interaction threshold.

| Clan | Pub modifier | Castle modifier | Notes |
|------|-------------|-----------------|-------|
| Cleric | +0.30 | +0.25 | Trusted everywhere |
| Monk | +0.25 | +0.20 | |
| Bard | +0.20 | +0.10 | Better at pubs than formal venues |
| Ranger | +0.10 | +0.00 | |
| Druid | +0.10 | +0.05 | |
| Elf | +0.05 | +0.10 | More respected at formal venues |
| Fighter | +0.00 | +0.05 | |
| Dwarf | −0.05 | +0.10 | Poor pub rep, respected at castle |
| Mage | −0.05 | +0.15 | Aloof in pubs; commanding at castles |
| Rogue | −0.10 | −0.15 | Distrusted widely |
| Shaman | −0.15 | −0.10 | |
| Necromancer | −0.35 | −0.30 | **Charm override** raises to +0.50 for this visit only |

**Charm override**: A Charm-capable unit (or adjacent Bard) may cast Charm before entering a pub or castle. This replaces the clan modifier with +0.50 for that visit. One-time use per venue per game — recorded in `state.pubs[town_id].charm_used[clan_id]`.

---

## Intel Spread via Pub

Pubs are the primary vector for intel spreading between clans organically:

1. **Gossip pool**: Settlement gossip pools receive intel from all clans whose units have passed through (via population dissemination). Pubs surface this to visiting units.
2. **Clan Representative**: When rival clan is present, their Rep carries 1–2 T1/T2 tokens. Visiting clan can buy them a drink (5g) to access one.
3. **Pub leak**: Every pint consumed by a unit has a chance to add that clan's intel to the gossip pool (silently). Rivals who visit the same pub later may pick it up.
4. **Propagation chain**: T1 intel that leaks into a pub → enters gossip pool → spreads to next settlement → surfaces at next pub that a rival visits.

---

## AI Diplomacy Heuristics

AI clans evaluate diplomacy offers each turn using `engine_diplomacy.py`. Key weights:

| Condition | Action | Weight |
|-----------|--------|--------|
| Both clans ≥ 50% shrine completion + Dragon awake | Propose `JointDragonAssaultPact` via Castle | +0.40 |
| Clan lacks mantra for shrine X + rival has it | Propose `MantraExchange` via Castle | +0.35 |
| Clan is militarily weak (< 3 alive units) | Accept any `NonAggressionPact` | +0.30 |
| Rival just broke a Castle agreement | Refuse all offers from that clan for 10 turns | −1.00 override |
| Pub visit + rival Clan Rep present + gold available | Buy Clan Rep a drink (5g intel gain) | +0.25 |
| Mantra gap exists + gold ≥ 50 | Bribe barkeep (topic: shrine) | +0.20 |

---

## Castle Locations on World Map

Every castle is a distinct world-map hex. Castle interiors contain:
- **Broker Chamber** — T3 diplomacy (see above)
- **Great Hall** — Clan audience, formal meetings
- **Throne Room** — Lord/Lady NPC; relationship grants passage rights or intel
- **Armory** — T2–T3 items at premium prices
- **Dungeon** — Imprisoned NPCs (rescue = T2–T3 intel)
- **Treasury** — Raidable (200–400g, but triggers guard reinforcement)
- **Garrison** — Castle guards; attack aggressors in town squares and treasury

*See `interiors.md` for full castle interior map specification.*

---

## Key Engine Functions

| Function | File | Purpose |
|----------|------|---------|
| `action_buy_drink()` | engine_pub.py | Buy drink, increment relationship, surface gossip |
| `action_buy_round()` | engine_pub.py | Buy round for table, stronger relationship + gossip |
| `action_listen_in()` | engine_pub.py | Free T1 gossip, no leak risk |
| `action_talk_to_patron()` | engine_pub.py | Patron-specific intel (Merchant/Scout/Clan Rep) |
| `action_bribe()` | engine_pub.py | Gold-gated gossip with topic filtering |
| `action_propose_deal()` | engine_pub.py | Initiate T1–T2 deal; redirect T3 to castle |
| `apply_charm_override()` | engine_pub.py | One-time Charm boost to clan rep |
| `get_pub_menu()` | engine_pub.py | Return pub state dict for UI rendering |
| `get_pub_tier()` | engine_pub.py | Return current relationship tier |
| `effective_rep()` | engine_pub.py | Return NPC warmth modifier (with Charm override) |
| `ai_pub_visit()` | engine_pub.py | AI pub decision tree (same engine, no menu) |
| `broker_open_session()` | engine_castle.py | Validate both clans present, open T3 menu |
| `broker_seal_agreement()` | engine_castle.py | Record agreement, notify clans |
| `broker_announce_breach()` | engine_castle.py | Global T2 intel + rep penalty |
| `diplomatic_intel_transfer()` | engine_intel.py | Ally direct intel share (−0.10 conf) |
