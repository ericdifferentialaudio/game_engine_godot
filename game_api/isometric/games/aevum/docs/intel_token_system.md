# Intel Token System — Full Cross-Matrix Reference
**Sprint 36 | engine/engine_intel.py · engine/engine_intel_tokens.py · engine/engine_dialogue.py · engine/engine_pub.py · engine/engine_headless.py**

---

## Overview

Intel tokens are the information currency of Aevum. Every piece of strategic knowledge a clan holds is represented as a typed token with a confidence value, validity window, and propagation history. Clans never access raw game state — they act on what their tokens tell them.

**Token lifecycle:**
```
Event occurs (shrine meditated, dragon wakes, combat, NPC trade)
  ↓
Creator function fires (engine_intel.py / engine_headless.py / engine_dragon.py)
  ↓
Token enters clan_intel[] and/or gossip_pool[]
  ↓
Propagation wave spreads token outward from origin
  ↓
Confidence decays over validity window
  ↓
AI reads tokens via _ai_read_*() functions → adjusts goal scores
  ↓
Player reads tokens via 'I' overlay → dialogue surfaces contextually
```

---

## Full Token Cross-Matrix

### T1 — Vague / Public (fast decay, wide broadcast)

| Token Type | Trigger Event | Creator Function | Broadcast | Conf | Validity | AI Use |
|---|---|---|---|---|---|---|
| `shrine_meditated_anon` | Any clan completes shrine meditation | `create_shrine_meditated_intel()` in engine_headless.py | gossip pools r≤20, global wave | 0.55 | 20t | End-game panic urgency |
| `virtue_count_public` | Any clan completes shrine meditation | `create_virtue_count_intel()` in engine_headless.py | global (all gossip pools) | 0.70 | 30t | `_ai_read_virtue_count_token()` → shrine panic +0.20 |
| `clan_virtue_leader` | Any change to any clan's virtue_credits_count, 1-8 | `create_clan_virtue_leader_intel()` in engine_intel.py, called from `meditate_at_shrine_tick()`/`virtue_spread_tick()` in engine_headless.py | global gossip pools ONLY (not a direct clan_intel grant — see STRICT NO-OPACITY note below) — **T2, not T1** (named, listed here for proximity to virtue_count_public) | 0.85 | 12t | `_ai_read_virtue_leader_token()` → sole source of `compute_clan_sentiment()`'s `contest_leader`; `evaluate_goal("attack_rival")` 1.6× boost vs named leader (CHAOS_REGION_PLAN Phase 1, 08/30/2026 — replaces prior raw-hard-state read) |

> **STRICT NO-OPACITY RULE (08/30/2026, user-clarified):** a clan's virtue
> progress at ANY count (1-8), named or anonymous, must ONLY ever reach a
> rival through this intel token system — witnessing, gossip propagation,
> pub/castle/village visits, diplomatic transfer. No engine-side fallback to
> hard state exists anywhere in this system. `create_clan_virtue_leader_intel()`
> originally (bug, since fixed) called `acquire_intel()` directly on every
> rival — an unconditional free grant that defeated the whole point. It now
> ONLY seeds gossip pools; a rival must still visit a settlement to acquire it.
| `dragon_still` | Dragon dormant checkpoint (every 50t) | `create_dragon_state_intel()` in engine_intel.py | global | 0.65 | 15t | Reduces dragon urgency |
| `dragon_awake` | Dragon STIRRING→AWAKE transition | `create_dragon_state_intel()` in engine_dragon.py | global (all gossip pools) | 0.80 | 30t | `_ai_read_dragon_awake_token()` → goal interrupt |
| `combat_vague` | Any combat resolution | `create_combat_intel()` | gossip pools r≤15 | 0.50 | 5t | Minor enclave defense boost |
| `dragon_vague` | Dragon proximity witness | `create_dragon_intel()` | gossip pools r≤10 | 0.55 | 8t | Dragon urgency suppression |
| `item_in_region` | Item spotted by scout | `create_item_intel()` | gossip pools r≤12 | 0.45 | 10t | Route scout toward region |
| `mantra_fragment` | Notice board / partial pub intel | `create_mantra_fragment_intel()` | gossip pool only | 0.30 | 30t | Seek-mantra urgency |
| `organic` | Legacy organic item intel | (legacy) | gossip | 0.40 | 10t | Minor |

### T2 — Specific / Named (medium decay, settlement broadcast)

| Token Type | Trigger Event | Creator Function | Broadcast | Conf | Validity | AI Use |
|---|---|---|---|---|---|---|
| `shrine_meditated_named` | Any clan completes shrine meditation | `create_shrine_meditated_intel()` in engine_headless.py | gossip pools r≤15, Trusted+ only | 0.75 | 20t | `_ai_read_rival_shrine_tokens()` → block urgency +0.10 |
| `virtue_named` | Witness unit has LOS to meditating clan | `create_virtue_named_intel()` in engine_headless.py | gossip pool witness location | 0.70 | 25t | Rival shrine count tracking |
| `dragon_spotted` | Unit witnesses active dragon within VIS | `create_dragon_intel()` | gossip pools r≤8 | 0.75 | 10t | -0.20 risky goal suppression |
| `dragon_enraged` | Dragon enters ENRAGED state | `create_dragon_state_intel()` in engine_dragon.py | global (all gossip pools) | 0.85 | 20t | Hard interrupt on dragon |
| `combat_specific` | Named clans clash (witnessed) | `create_combat_intel()` | gossip pools r≤12 | 0.70 | 8t | attack_rival / defend_enclave floor |
| `unit_spotted` | Scout / rogue witnesses enemy unit | `create_rival_position_intel()` | gossip pool origin | 0.70 | 5t | contest_egg_carrier, attack boost |
| `spell_cast_event` | T3+ spell cast (witnessed) | `create_spell_cast_intel()` | gossip pools r≤10 | 0.65 | 5t | Area avoidance |
| `item_in_shop` | Unit enters town with item in armory | `create_item_shop_intel()` | gossip pool r≤5 | 0.90 | 10t | Route toward shop |
| `monster_weakness` | Lair boss killed (type revealed) | `create_lair_intel()` | gossip pool origin | 1.00 | 999t | Lair clear efficiency |
| `virtue_count_named` | NPC trade / pub Trusted+ | `create_virtue_named_intel()` | gossip pool | 0.70 | 20t | Rival shrine tracking |
| `virtue_specific_named` | Witness sees specific virtue meditated | `create_virtue_named_intel()` | gossip pool | 0.75 | 25t | Block specific shrine |
| `virtue_blocked` | Enemy unit enters shrine contested zone | `create_virtue_blocked_intel()` | gossip pool r≤10 | 0.60 | 8t | contest_shrine_zone urgency |
| `clan_shrine_count` | Pub Trusted+ / NPC trade | pub gossip surface | gossip pool | 0.70 | 20t | Rival tracking |
| `alliance_known` | Alliance formed (any clan) | `diplomatic_intel_transfer()` | global partial | 0.75 | 30t | Alliance awareness |
| `clan_eliminated` | Clan elimination | auto-broadcast | global | 0.95 | 999t | Threat reassessment |
| `unit_carrying_item` | Scout witnesses seeker with item | `create_rival_position_intel()` | gossip r≤8 | 0.65 | 5t | Intercept routing |
| `seeker_active` | Any clan's seeker moves onto map | auto-broadcast | global partial | 0.80 | 20t | contest_egg_carrier urgency |
| `lair_boss_type` | Unit enters lair, boss visible | `create_lair_intel()` | gossip pool | 0.85 | 50t | Lair clear efficiency |
| `lair_cleared` | Lair boss killed | `create_lair_intel()` | gossip pools r≤25 | 0.90 | 30t | Route away from cleared lair |
| `lair_item_cached` | Scout witnesses item in lair | `create_lair_intel()` | gossip r≤12 | 0.60 | 15t | clear_lair urgency boost |
| `structure_observed` | Enemy building in vision | auto from visibility | gossip pool | 0.85 | 20t | Threat assessment |
| `dungeon_layout` | Prisoner NPC rescued / pub healer | prisoner rescue | unit-held | 0.80 | 25t | Lair routing |
| `rival_position` | Scout reports enemy position | `create_rival_position_intel()` | gossip pool | 0.70 | 5t | attack_rival routing |
| `diplo` | Diplomacy offer witnessed | (legacy) | gossip | 0.60 | 10t | Diplomacy awareness |

### T3 — Authoritative / Permanent (no decay or very slow)

| Token Type | Trigger Event | Creator Function | Broadcast | Conf | Validity | AI Use |
|---|---|---|---|---|---|---|
| `mantra_known` | Direct meditation (own shrine) | `create_mantra_known_intel()` | unit-held | 1.00 | 999t | Unlock advance_shrines for shrine X |
| `mantra_known` | Pub bribe 100g | `create_mantra_known_intel()` | unit-held | 0.65 | 999t | Advance_shrines with reduced conf |
| `mantra_known` | Prisoner/survivor rescue | `create_mantra_known_intel()` | unit-held | 0.85 | 999t | Advance_shrines |
| `mantra_known` | Alliance mantra trade | `_exchange_mantra_knowledge()` | unit-held | 0.65 | 999t | Advance_shrines |
| `mantra_known` | NPC trade (barkeep/scholar) | `resolve_npc_trade()` in engine_dialogue.py | unit-held | 0.75 | 999t | Advance_shrines |
| `shrine_location` | Unit physically visits shrine hex | auto from movement | unit-held | 1.00 | 999t | Unlock pathfinding to shrine |
| `shrine_location` | Pub bribe 50g | pub gossip surface | unit-held | 0.65 | 999t | Advance_shrines routing |
| `shrine_location` | Prisoner rescue (T2+ lair) | prisoner rescue | unit-held | 0.85 | 999t | Advance_shrines routing |
| `shrine_location` | NPC trade (barkeep asks) | `resolve_npc_trade()` | gossip pool | 0.85 | 999t | Advances other clans' routing |
| `cleric_shrine_rule` | Cleric meditates Compassion shrine | auto-broadcast | global (all clans) | 1.00 | 999t | Predict Cleric movement |
| `egg_quadrant` | Survivor rescue (T3/T4 lair) | `create_prisoner_intel()` | unit-held | 0.85 | 999t | seek_egg routing |
| `egg_quadrant` | Pub Trusted+ | pub gossip surface | unit-held | 0.70 | 999t | seek_egg routing |
| `diplomatic_intel` | Ally intel transfer | `diplomatic_intel_transfer()` | unit-held | orig-0.10 | same | All goal types |
| `clan_avatar_status` | Clan achieves Avatar | auto-broadcast | global | 1.00 | 999t | contest_egg_carrier urgent |
| `artifact` | Artifact found by unit | `create_item_intel()` | gossip pool | 0.90 | 999t | Route toward artifact |

---

## Token Confidence by Source

| Source | Confidence Range | Notes |
|---|---|---|
| Direct meditation (own shrine) | 1.00 | Perfect — you were there |
| Physical witness (unit has LOS) | 0.75–0.90 | Eyewitness; decays after 5t |
| Trusted pub (drink 3) | 0.70–0.85 | Reliable gossip source |
| Prisoner rescue (T2 lair) | 0.80–0.85 | Motivated source, recent memory |
| Alliance mantra trade | 0.65 | −0.10 from donor confidence |
| Pub bribe (100g mantra) | 0.65 | Commercial transaction |
| Regular pub (drink 2) | 0.55–0.70 | Secondhand gossip |
| NPC trade (both sides) | 0.75 / 0.85 | Player gives 0.85; player gets NPC's original conf |
| Notice board | 0.30–0.50 | Low reliability, high staleness |
| Acquaintance pub (drink 1) | 0.40–0.55 | Very low reliability |
| Leaked (own clan) | original −0.30 | Inadvertent disclosure |

---

## AI Token Reading Functions

Token-reading functions in `engine_ai.py` (Sprint 36 + CHAOS_REGION_PLAN Phase 1, 08/30/2026):

### `_ai_read_virtue_count_token(clan_id, state) → int`
- Reads `virtue_count_public` tokens from `state.clan_intel[clan_id]`
- Returns the highest `meditated_count` seen, or **0 if no token has been
  acquired yet** — 0 means "no information", full stop.
- **BUGFIX 08/30/2026:** this function used to fall back to a raw
  `sum(state.clans...)` hard-state count when no token existed. Per the
  STRICT NO-OPACITY RULE (user-clarified same session), that fallback was
  itself a hidden omniscience bug and has been removed — there is no
  engine-side fallback here any more, for anonymous OR named virtue intel.
- **Used in:** `evaluate_goal("advance_shrines")` → `score += 0.20` if total count ≥ total_shrines - 2

### `_ai_read_virtue_leader_token(clan_id, state) → (leader_clan_id, meditated_count)`
- Reads `clan_virtue_leader` (NAMED) tokens from `state.clan_intel[clan_id]`
- Returns `("", 0)` if no live token (conf ≥ 0.30) is held — no fallback,
  same as the count reader above post-bugfix.
- **Used in:** `compute_clan_sentiment()` — sole source of `contest_leader`,
  which `evaluate_goal("attack_rival")` reads for a 1.6× score boost against
  the named clan's visible units.

### `_ai_read_dragon_awake_token(clan_id, state) → bool`
- Returns True if clan has `dragon_awake` or `dragon_enraged` token with conf ≥ 0.40
- **BUGFIX 08/31/2026 (CHAOS_REGION_PLAN Phase 2, STRICT NO-OPACITY RULE):**
  this doc previously claimed it was "used in `_check_goal_interrupt()`" —
  that was WRONG; the function actually had **zero callers anywhere**,
  fully dead/decorative, while `evaluate_dragon_phase()` and
  `compute_clan_sentiment()` both read `state.dragon.state` directly
  instead (the largest omniscience violation found in the whole
  CHAOS_REGION_PLAN audit — every clan reacted to the dragon globally, at
  all times, with zero vision/intel requirement).
- **Used in (now, post-fix):** `evaluate_dragon_phase()` (the AI's dragon
  "emergency override" — only fires if the clan has live sight of the
  dragon's hex OR this token, never on raw `state.dragon.state` alone) and
  `compute_clan_sentiment()`'s `dragon_bonus` (+0.3 egg_urgency, same gate).

### `_ai_read_rival_shrine_tokens(clan_id, state) → dict[clan_id: count]`
- Reads `shrine_meditated_named` and `virtue_named` tokens
- Returns rival shrine counts as known through tokens (not raw state)
- **Used in:** `evaluate_goal("advance_shrines")` → `score += 0.10` if token-known rival at 5+ shrines

---

## Gossip Pool Seeding Events

Events that create tokens AND seed gossip pools (causing NPC dialogue to update):

| Event | Token Type | Gossip Pool Radius | NPC Response |
|---|---|---|---|
| Shrine meditated | `shrine_meditated_anon` + `shrine_meditated_named` | 20 hex | Barkeep mentions it at drink 2+ |
| Dragon wakes | `dragon_awake` | Global | Barkeep state comment fires always |
| Dragon enraged | `dragon_enraged` | Global | Barkeep state comment; paranoid patron activates |
| Clan eliminated | `clan_eliminated` | Global | Barkeep state comment; philosophical patron references |
| Avatar achieved | `clan_avatar_status` | Global | Barkeep state + Avatar comment |
| Lair cleared | `lair_cleared` | 25 hex | Wanderer NPC carries this intel |
| NPC trade accepted | trade token | Location pool | Token persists for next player |

---

## Dragon State Token Sequence

```
Dragon dormant (every 50t checkpoint):
  → create_dragon_state_intel("still", q, r, state)
  → T1 dragon_still token → all gossip pools
  → Dialogue: "Dragon's quiet. That word is doing more work than it should."

Dragon STIRRING:
  → No token yet (internal only — 3-7t buildup)
  → Barkeep: mentions "something stirring" if unit has gossip pool intel

Dragon AWAKE (stirring → awake transition):
  → create_dragon_state_intel("awake", dragon.q, dragon.r, state)
  → T1 dragon_awake token → ALL gossip pools
  → Confidence: 0.80
  → Validity: 30t
  → AI: _ai_read_dragon_awake_token() returns True → goal interrupt fires
  → Dialogue: "The dragon's awake. Three separate people said it."

Dragon ENRAGED:
  → T2 dragon_enraged token → all gossip pools
  → Confidence: 0.85
  → Barkeep state comment: always fires on next pub visit

Dragon SLAIN:
  → T1 dragon_slain token → global (planned)
  → Barkeep: "The roads opened up a bit after."
```

---

## Shrine Meditation Token Sequence

```
Clan X completes meditation at shrine Y (turn T):

T1 token created:
  shrine_meditated_anon
  → description: "A virtue has been consecrated somewhere to the {direction}"
  → confidence: 0.55
  → broadcast: gossip pools within r=20 of shrine
  → validity: 20t
  → AI use: minor urgency flag

T2 token created (simultaneously):
  shrine_meditated_named
  → description: "Clan X meditated Shrine Y on turn T"
  → confidence: 0.75
  → broadcast: gossip pools within r=15 (Trusted+ only)
  → validity: 20t
  → AI use: _ai_read_rival_shrine_tokens() → block urgency

virtue_count_public token updated:
  → description: "{N} virtues have been meditated across the realm"
  → confidence: 0.70
  → broadcast: global (all gossip pools)
  → validity: 30t
  → AI use: _ai_read_virtue_count_token() → panic sprint at N ≥ total-2

virtue_named token (if witness unit present):
  → confidence: 0.70
  → broadcast: gossip pool at witness location
  → AI use: rival shrine tracking
```

---

## Pub Intel Token Surface Rules

| Relationship | Confidence Threshold | Max Tokens/Visit | Tiers |
|---|---|---|---|
| Stranger | — | 0 | None |
| Acquaintance | ≥ 0.50 | 1 | T1 only |
| Regular | ≥ 0.40 | 1–2 | T1–T2 |
| Trusted | ≥ 0.30 | 2 | T1–T2, T3 shrine hints |
| Confidant | ≥ 0.10 | 2+ | All tiers |

Own clan's intel is never surfaced back to the owning clan.

---

## Sprint 36b — Pub Token Injection & Leak Broadcast

Added in Sprint 36b (`engine_pub.py`):

### `_inject_token_dialogue(base_dialogue, state, clan_id, pints, nsfw, unit_id, town_id, leaked)`
Called inside `action_buy_drink()` and `action_buy_round()` after the barkeep line is built.
- Calls `get_pub_intel_tokens(state, clan_id, pints, rng, nsfw_ok=nsfw)` from `engine_intel_tokens.py`
- Picks the highest-tier token surfaced this drink (by `TOKEN_TIER` rank)
- Appends variable-substituted dialogue as a second line: `"\n  \"<token_line>\""`
- Pint 1 → T1 token (vague, directional); Pint 2 → T2 (named intel); Pint 3+ → T2/T3 (authoritative)
- If `leaked=True` at 3+ pints, calls `_broadcast_pub_leak_token()` and appends `[Leak]` line

### `_broadcast_pub_leak_token(state, leaking_clan_id, town_id, rng, nsfw)`
The pub leak mechanic — fires when a unit has 3+ pints and `pub_leak_check()` returns True.
1. Builds token context for the **leaking clan's own state** via `build_token_context()`
2. Picks `T_CLAN_AVATAR_PROGRESS` or `T_SHRINE_MEDITATED` token about the leaker's own progress
3. Calls `get_dialogue_for_token()` to generate a variable-substituted line
4. Writes a T2 gossip entry to `state.gossip_pools[town_id]` tagged `clan_origin=leaking_clan_id`
   (so the gossip never surfaces back to the clan that leaked it)
5. Returns a dialogue line from `PUB_DRINK4_SLIP` / `PUB_DRINK4_SLIP_NSFW` pools with
   actual `{clan_name}` and `{virtue_name}` substituted

**Example output:**
```
Barkeep: "Not a quiet week."
  "Word is the Ranger clan have meditated 3 virtues — including the Shrine of Compassion."
  [Leak] "Your companions have been talking. Loudly. The part about the Shrine of Compassion was clear."
```

### Token dialogue pools (engine_intel_tokens.py)

| Function | Purpose |
|---|---|
| `get_pub_intel_tokens(state, clan_id, pints, rng)` | Returns list of `{token_type, dialogue, vars}` for this drink |
| `get_npc_intel_tokens(state, clan_id, npc_type, rng)` | Returns tokens for a specific NPC type interaction |
| `build_token_context(state, clan_id)` | Builds full context dict keyed by `{token_type}:{subject_id}` |
| `get_dialogue_for_token(token_type, vars, rng, nsfw_ok)` | Selects and formats a dialogue string from pool |
