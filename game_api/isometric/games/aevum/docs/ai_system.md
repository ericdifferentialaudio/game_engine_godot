# AI System — Aevum: Age of Shrines
**Last updated:** Sprint 36 (2026-07-26)  
**Reference spec:** `comms/AEVUM_TOKEN_117.md` · `assets/md/inter_clan_sentiment.md`

---

## Overview

The AI decision pipeline runs once per clan per turn via `process_ai_turn()`.
It is fully headless (no Pygame), deterministic given a seed, and parameterised
by clan archetype genetics stored in `GOAL_PRIORITY`.

Sprint 32 formalises a four-layer scoring stack so every AI decision is
traceable to concrete game-state evidence.

---

## Architecture: Four Layers

```
Layer 1  compute_clan_sentiment()   → 6-dim posture vector (Tree A)
Layer 2a evaluate_goal()            → 0-1 score per goal (Tree B)
         _clan_sentiment_mod()      → ×1.0–1.5 multiplier from posture
         _info_value_mod()          → +0.0–0.40 additive from intel tokens
         _self_knowledge_mod()      → +0.0–0.50 additive from unit state
Layer 2b headless_shrine_advance()  → BFS-guided movement execution
Layer 4  _ai_tick_observe()         → per-tick enemy sighting (unmetered, every tick)
         ai_tick_decide()           → METERED per-tick worklist drain (see below;
                                       replaces the old flat commit-tick model)
```

---

## Layer 1: Clan Sentiment (6 dims)

Computed by `compute_clan_sentiment(state, clan_id)` at the start of each turn
and stored on `clan.sentiment`. Sprint 32 adds two new dimensions.

| Dimension | Range | Meaning |
|---|---|---|
| `aggression` | 0–1 | Fight vs. shrine-advance bias; rises with rank desperation |
| `egg_urgency` | 0–1 | Avatar race pressure; dragon proximity adds +0.3 |
| `contest_leader` | clan_id\|"" | Clan to intercept when rival has threshold-1 shrines |
| `expansion` | 0–1 | Build camps/territory pressure |
| `econ_focus` | 0–1 | **Sprint 32** — gold high + no queue + techs < 4 |
| `info_hunger` | 0–1 | **Sprint 32** — mantra gaps exist + Avatar not achieved |

---

## Layer 2a: Goal Scoring

### Base Weight

`GOAL_PRIORITY[clan_id][goal]` — genetic archetype weighting.  
Overridden by `clan.build_personality` when present (set at game start, hidden
until learned via pub intel).

### `_clan_sentiment_mod(goal, sentiment)` → float multiplier

Applies sentiment posture as a ×1.0–×1.5 goal multiplier:

| Goal(s) | Multiplier |
|---|---|
| attack_rival, contest_egg_carrier, assassinate, ambush | ×(1 + aggression × 0.4) |
| seek_egg | ×(1 + egg_urgency × 0.5) |
| advance_shrines | ×(1 + egg_urgency × 0.3) |
| scout_map | ×(1 + expansion × 0.3) |
| produce_units, research_tech | ×(1 + econ_focus × 0.4) |
| seek_mantra, build_pub_relationship | ×(1 + info_hunger × 0.4) |

### `_info_value_mod(unit, goal, state)` → float additive (cap: +0.40)

Reads `state.clan_intel[clan_id]` — list of `KnownIntel` tokens:

| Intel type | Condition | Goal boosted | Amount |
|---|---|---|---|
| egg_quadrant | conf ≥ 0.50 | seek_egg | +0.35 |
| rival_position / unit_spotted | within 8 hexes of enclave | defend_enclave | +0.20 |
| rival_position / unit_spotted | within 15 hexes | attack_rival | +0.15 |
| dragon_spotted | conf ≥ 0.50, age ≤ 5 | defend_enclave | +0.15 |
| dragon_spotted | same | seek_egg | +0.10 |
| mantra_knowledge | direct / conf ≥ 0.70 | advance_shrines | +0.25 |
| mantra_knowledge | conf < 0.20 | seek_mantra | +0.30 |
| active_alliances | any ally | attack_rival | +0.15 |
| active_alliances | any ally | advance_shrines | +0.10 |

### `_self_knowledge_mod(unit, goal, state)` → float additive (cap: ±0.50)

Per-unit introspection:

| Condition | Goal | Effect |
|---|---|---|
| HP < 40% | attack_rival | −0.30 |
| HP < 40% | clear_lair | −0.20 |
| HP < 40% | defend_enclave | +0.35 |
| HP > 85% | attack_rival | +0.15 |
| level ≥ 2 | attack_rival | +0.12 |
| level ≥ 2 | clear_lair | +0.10 |
| item bonus_atk ≥ 2 | attack_rival | +0.15 |
| Seeker items | seek_egg | +0.25 |
| Scholar items | advance_shrines | +0.20 |
| `prophetic_sight` researched | advance_shrines | +0.20 |
| `total_war` researched | attack_rival | +0.20 |
| `enlightenment` researched | advance_shrines | +0.15 |
| shrines_meditated ≥ 2 | advance_shrines | +0.15 |

---

## Tech ROI Scoring

`_score_tech_roi(tech_id, clan_id, state)` gates the `research_tech` goal:

```
roi = (roi_value × tier_mult) / turns_base × payback_factor
```

- Won't research if `roi < 1.5` (#T103-A)
- Tier multipliers: T1×1.0, T2×1.8, T3×3.0, T4×5.0
- Used by `_ai_research_tech()` to rank available techs

---

## Goal Commitment (heuristics3.md)

Clans commit to a goal for `_COMMITMENT_BASE[clan_id]` turns before
natural re-evaluation. Soft drift (1/base probability/turn) and hard
interrupts can override early.

**Hard interrupt conditions:**
1. Dragon awake/enraged and goal isn't evasion/combat
2. 3+ enemies within 8 hexes of enclave
3. Only 1 unit remaining (near-elimination)

**Genetics:**
- Fighter/Dwarf: base 9 (stubborn)
- Rogue/Bard: base 3 (opportunistic)

---

## Goal Persistence (Sprint 32)

New fields track goal commitment across turns:

**Per-unit** (`UnitInstance`):
- `ai_current_goal` — committed goal string
- `ai_goal_target_q/r` — target coordinates
- `ai_goal_turns` — turns committed so far
- `ai_goal_timeout` — max turns before forced re-eval

**Per-clan** (`ClanInstance`):
- `clan_goal_id` — strategic posture ("shrine_rush"|"econ_build"|"military_push"|"info_gather"|"dragon_prep")
- `clan_goal_turns` — turns committed
- `clan_goal_timeout` — max 20 turns before re-eval

Goal timeouts per type:

| Goal | Turns |
|---|---|
| seek_egg | 30 |
| advance_shrines | 20 |
| scout_map | 15 |
| clear_lair | 12 |
| defend_enclave | 10 |
| seek_mantra | 10 |
| attack_rival | 8 |
| build_pub_relationship | 8 |
| pursue_alliance | 8 |

---

## Layer 4: Tree C — Per-Tick Reactivity (REVISED 08/29/2026, LIVE same day)

Called by `engine_headless.run_ai_decision_ticks(state, analytics=None, n=None)`
— THE single shared driver for AI decisions, called by every mode
(headless, Atlas; the full interactive game once it has its own turn loop).
No driver calls `ai_tick_decide()`, `process_ai_turn()`, or
`execute_clan_actions()` directly anymore — `run_ai_decision_ticks()` is the
only entry point, enforced by `tests/engine/test_mode_parity.py::
test_shared_dispatcher_is_used_by_both`.

**The old flat "one commit tick per difficulty" model is gone.** It only
delayed WHEN a whole-clan plan was written — the plan itself was still built
instantly and completely in one call, so every difficulty decided its
entire roster equally fast once its commit tick arrived. This did not match
the intended design: *"the game engine time loop pings all AI decision
trees with the time countdown.. each AI decision tree has to make all
choices within the tick countdown. so the AI needs to spread its decision
computation by ticks, and by number of units. this is why clusters help."*

### `_ai_tick_observe(state, clan_id, tick)` — unchanged, unmetered

- Called every tick for every AI clan (not gated on a commit tick anymore)
- Accumulates `state._ai_observations[clan_id]` — visible enemy positions
- Observation is cheap; deciding is the metered resource

### `ai_tick_decide(state, clan_id, tick)` — the metering primitive under `run_ai_decision_ticks()`

Called every tick for every non-eliminated AI clan, exclusively from
`run_ai_decision_ticks()`. No driver calls `ai_tick_decide()`,
`process_ai_turn()`, `_ai_tick_observe()`, worklist internals, or
`execute_clan_actions()` directly — `run_ai_decision_ticks()` is the only
entry point any driver may use for AI turns.

On the first tick of a new turn (unmetered, once per clan-turn — exactly
like a human player instantly deciding overall strategy):
1. Calls `compute_clan_sentiment()` on live positions.
2. Calls `_check_goal_interrupt()` — may clear committed goal.
3. Calls `process_ai_turn()` once to get the clan's fully decided action
   list (goal-tree scoring is NOT metered — only turning that decision into
   dispatched actions is).
4. Partitions those actions into a worklist: one entry per cluster
   (`ai_cluster_id`, see `engine_cluster_v2.py`) plus one entry per
   unclustered/solo unit.

Every tick thereafter (including the first), the clan accrues 1 tick of
decision budget and drains worklist entries whose cost has been reached:

| Difficulty | `_AI_TICKS_PER_DECISION` (ticks/entry) |
|---|---|
| Expert | 1 |
| Hard | 2 |
| Normal | 3 |
| Medium | 5 |
| Easy | 8 |

Each entry's cost also scales mildly with member count
(`+0.5 ticks × (member_count − 1)`), so raw unit count still matters, not
just cluster count. Each drained entry's actions are dispatched through
`engine_headless.execute_clan_actions()` (never a direct
`state.action_queues` write — the old `_ai_tick_commit()` bypassed this,
losing action-type validation for `build_port`/`produce_units`/etc.).

**If tick N is reached before the worklist empties, the remaining
clusters/units get NO fresh actions dispatched this turn** — they keep
whatever was already queued, or idle. This is the literal "ran out of time
to think" case, and is exactly why forming fewer/larger clusters helps a
clan facing many enemies/objectives decide more of itself before the clock
runs out.

---

## All Goals

| Goal | Primary clans | Scoring function |
|---|---|---|
| advance_shrines | All | shrine progress + egg_urgency |
| attack_rival | Fighter, Dwarf, Necro | aggression + sentiment |
| defend_enclave | All | wall HP + enemy proximity |
| scout_map | Ranger, Rogue, Elf | fog coverage |
| seek_egg | All (post-Avatar) | avatar_status gate |
| negotiate_rights | Bard, Cleric | un-meditated shrine count |
| clear_lair | All | lair visibility + proximity |
| seek_mantra | Cleric, Monk, Druid | mantra gap count |
| build_pub_relationship | Bard, Rogue | unknown mantra count |
| pursue_alliance | All (kinship pairs) | shrine progress ≥ 3 |
| steal_egg | Rogue only | egg carried by other |
| contest_egg_carrier | Aggressive clans | egg carried by other |
| assassinate | Rogue only | mark score (isolation, HP) |
| ambush | Rogue only | shelter terrain + enemies near |
| produce_units | All | unit count < 5 |
| research_tech | All | ROI gate + gold > 60 |

---

## Data Flow Summary

```
turn start
  └─ process_ai_turn(state, clan_id)
       ├─ compute_clan_sentiment()      [Layer 1: 6-dim vector]
       ├─ _check_goal_interrupt()       [hard conditions]
       ├─ evaluate_goal() × N_goals     [Layer 2a scoring]
       │    ├─ GOAL_PRIORITY[clan][goal]  base
       │    ├─ × _clan_sentiment_mod()    posture mult
       │    ├─ + _info_value_mod()        intel additive
       │    └─ + _self_knowledge_mod()    unit additive
       ├─ goal commitment logic
       ├─ execute_goal(best_goal)        [Layer 2b actions]
       └─ secondary goal + opportunistic combat

run_ai_decision_ticks(state, analytics) — the shared AI-decision driver,
called once per turn by every mode:
  └─ for each tick 1..N:
       ├─ _ai_tick_observe()   [Layer 4: accumulate sightings; tick 1 only
       │                        in headless/Atlas — see perf note below]
       ├─ ai_tick_decide()     [Layer 4: METERED worklist drain — see above]
       └─ headless_shrine_advance(tick=tick, n=N) per clan [Layer 2b,
            movement metering, 08/30/2026: TICK-PACED — advances each unit
            at most 1 hex, on that unit's move_interval = max(1, N // MOV),
            same cadence as movement_engine._tick_step_move() /
            resolve_turn()'s N-tick model. `ticks_moved_this_turn` is reset
            to 0 for every alive unit once per turn by
            run_ai_decision_ticks(), same field resolve_turn() uses. The
            cluster/lair mover (engine_ai_s41_ext.execute_cluster_movement())
            remains a separate, still-unmetered instant pass — see Category C
            Sub-problem 1/2 in doc/ENGINE_CONSOLIDATION_PLAN_2026_08.md]

Perf note (08/29/2026): `_ai_tick_observe()` scans every unit in
`state.units`; even though unit positions now change between ticks within a
turn (headless_shrine_advance is tick-paced as of 08/30/2026), observation
for decision purposes only needs to run once per turn, so it is still only
called on tick 1 to avoid an O(N_ticks × N_units) rescan with zero new
decision-relevant information. `ai_tick_decide()` itself still runs every tick
— it is the metered part.
```

---

## Sprint 33: Token-Parsed Goal Trees

Sprint 33 adds a **deterministic goal-tree layer** that sits between the
sentiment vector and the generic scoring stack.  Every AI decision is now
anchored to a concrete **win-path phase**, and intel tokens are used to
raise or lower *floor scores* that the rest of the scoring stack cannot
undercut.

### Win-Path Phases — `_win_path_phase(state, clan_id) → str`

Returns one of six mutually-exclusive phase strings, evaluated in priority order:

| Phase | Condition |
|---|---|
| `carry_home` | Clan is carrying the dragon egg |
| `seek_egg` | Avatar achieved + seeker built + egg not being carried |
| `make_seeker` | Avatar achieved + seeker **not** yet built |
| `pre_avatar` | `shrines_done ≥ threshold − 2` (2 away from Avatar) |
| `advance` | Default — still accumulating shrines |

The threshold (`state._avatar_shrine_threshold`, default 8) controls when
`pre_avatar` activates.

### Token-Driven Floor Scores — `_parse_goal_tree(state, clan_id) → dict[str, float]`

Returns a `floors` dict mapping goal IDs to minimum scores that
`process_ai_turn()` will honour regardless of genetic weights.

**Phase → baseline floors:**

| Phase | Floors set |
|---|---|
| `advance` | `advance_shrines ≥ 0.80` |
| `pre_avatar` | `advance_shrines ≥ 0.80`, `seek_egg ≥ 0.65` |
| `make_seeker` | `produce_units = 1.0` — all other goals zeroed |
| `seek_egg` | `seek_egg ≥ 0.90` |
| `carry_home` | `seek_egg = 1.0`, `defend_enclave ≥ 0.70` |

**Intel token bonuses (applied additively on top of phase baseline):**

| Token type | Effect |
|---|---|
| `shrine_location` — known unmeditated shrine | `advance_shrines += 0.20` (cap 1.0) |
| `mantra_known` (conf ≥ 0.50) — for unmeditated shrine | `advance_shrines += 0.15` (cap 1.0) |
| `unit_spotted` within 12 hexes of enclave | `defend_enclave += max(0.25, existing)` |
| `egg_quadrant` (conf ≥ 0.50) | `seek_egg += 0.10` (cap 1.0) |

**Floor merge rule** in `process_ai_turn()`:

```python
for goal, floor in floors.items():
    scores[goal] = max(scores.get(goal, 0.0), floor)
```

Floors are a *lower bound* — normal scoring can still raise a goal higher
than the floor; it just cannot go below it.

### `structure_observed` Intel Type (Sprint 33)

Added to `engine_intel.py`. Generated when a scouting unit enters
visibility of a building tile. Carries:
- `location_hint` — `"q,r"` coords of the observed structure
- `description` — structure name/type string

Used by `_info_value_mod()` (future) to suppress camp-building near
already-visible rival fortifications.

### Tests

`tests/engine/test_ai_goal_tree.py` — 14 tests, all green:

| Class | Tests |
|---|---|
| `TestWinPathPhase` | 5 — one per phase |
| `TestParseGoalTree` | 8 — phase floors + token bonuses |
| `TestGoalTreeIntegration` | 1 — `make_seeker` hard-lock in `process_ai_turn()` |

---

## Files

| File | Role |
|---|---|
| `engine/engine_ai.py` | All AI logic: sentiment, scoring, goals, Tree C, Sprint 33 goal trees |
| `engine/engine_intel.py` | Intel generation + `structure_observed` type (Sprint 33) |
| `engine/movement_engine.py` | Tree C wiring in resolve_turn() tick loop |
| `engine/game_state.py` | UnitInstance + ClanInstance persistence fields |
| `tests/engine/test_ai_goal_tree.py` | Sprint 33 — 14 goal tree tests |
| `comms/AEVUM_TOKEN_103.md` | Spec lock with locked decision hashes |
| `assets/md/inter_clan_sentiment.md` | Full sentiment model spec (Sprint 34) |

---

## Sprint 34: Inter-Clan Sentiment Model

Replaces the flat `encounter_memory` counter with a rich directional 7-dimension
sentiment record per clan-pair, tracked in `ClanInstance.inter_clan_sentiment`.

See **`assets/md/inter_clan_sentiment.md`** for the full spec.

### Quick Reference — How Sentiment Drives AI Goals

| Sentiment dimension | Goal(s) boosted | Mechanism |
|---|---|---|
| `hostility` high | `attack_rival`, `assassinate`, `ambush` | `_clan_sentiment_mod()` ×multiplier |
| `fear` high | `defend_enclave` | `_info_value_mod()` additive |
| `rivalry` high | `attack_rival`, `contest_egg_carrier` | `_clan_sentiment_mod()` ×multiplier |
| `appeasement` high | `pursue_alliance`, `negotiate_rights` | `_clan_sentiment_mod()` ×multiplier |
| `opportunity` high | `attack_rival`, `clear_lair` | `_self_knowledge_mod()` additive |
| `grudge` high | prevents `pursue_alliance` with that clan | floor set to 0 for alliance goals |

### `update_sentiment_tick(state, analytics)` — Sprint 34

Called each turn (Step after retreat_heal_tick) in `runner.py`.
- Decays all active sentiment dimensions by their per-turn multipliers
- Recalculates `opportunity` (target's alive unit count relative to observer's)
- Floors `rivalry` and `fear` when rival is near Avatar threshold

### Build Personality System (Sprint 32, expanded Sprint 34)

Each clan rolls a `build_personality` archetype at game start (seeded, deterministic).
Personality weights four goal axes:

| Weight key | Governs |
|---|---|
| `produce_units` | How aggressively the clan builds units |
| `research_tech` | How eagerly the clan pursues technology |
| `attack_rival` | Baseline aggression toward rivals |
| `advance_shrines` | Shrine-first vs. econ-first balance |

Personality archetypes (rolled by `engine_personality.roll_build_personality()`):

| Archetype | produce_units | research_tech | attack_rival | advance_shrines |
|---|---|---|---|---|
| `balanced` | 0.50 | 0.50 | 0.50 | 0.50 |
| `expansionist` | 0.70 | 0.30 | 0.60 | 0.60 |
| `zealot` | 0.40 | 0.20 | 0.30 | 0.90 |
| `pragmatic` | 0.60 | 0.60 | 0.40 | 0.50 |
| `scholarly` | 0.30 | 0.85 | 0.20 | 0.50 |
| `mercantile` | 0.50 | 0.50 | 0.20 | 0.40 |
| `aggressive` | 0.80 | 0.30 | 0.85 | 0.40 |
| `defensive` | 0.60 | 0.40 | 0.20 | 0.60 |

Visible in simulation summaries under **Economy averages (by personality archetype)**.
