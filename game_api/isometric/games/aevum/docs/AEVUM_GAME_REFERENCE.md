# AEVUM_GAME_REFERENCE.md
# Aevum: Age of Shrines — Complete Game Reference
# Single session-starter file. Load at the start of every Claude Web or Cline session.
# Maintained by Cline. Claude Web can provide input, but the user will maintain status.
# Source: direct Python code analysis + design docs. Stay up to date with code and doc changes, including doc/AI_AUTONOMY_DESIGN.md, the consolidated canonical doc, plus all other docs.
# Maintenance rule, this file should be updated in the same session as any code change that alters documented behavior — do not let it drift again.


#
# Legend: ✅ code-verified  ⚙️ design-locked/not-yet-coded  🔲 partially implemented  ❓ uncertain

---

## 1. GAME OVERVIEW

Aevum is an 8-clan, hex-grid, simultaneous-action strategy game. All clans submit moves
in a shared order window (30s default), then executes over N logical ticks (N = turn_duration_seconds).
Intent-based simultaneous movement with RTS-style sub-tick execution. Orders lock on submission.

**The goal:** Achieve Avatar (meditate all 8 shrines), build a Seeker, steal the Dragon's egg,
carry it to your own shrine, hold it there uncontested for one full round.

**Map:** 100×100 axial hex grid (q,r). 8 active clans per game (from 12). Seed-deterministic.

---

## 2. WIN CONDITIONS & SCORING

| Condition | How |
|-----------|-----|
| **EGG WIN** | Seeker+egg on own shrine, held 1 round, no enemies on hex — egg destroyed BEFORE it ever hatches, no dragon offspring ever lived |
| **DRAGONS WIN** *(renamed + fixed 08/27/2026)* | Every one of the 8 clan enclaves destroyed — dragons torch the map. Monsters never attack enclaves, so total enclave loss can only happen via dragon assault; `all(c.is_eliminated for c in state.clans.values())` |
| **CLANS DEFEAT DRAGONS WIN** *(new 08/27/2026)* | Egg has hatched AND every dragon that ever existed is dead — Guardian, Hunter, and any live `baby_dragon` units, none remain. See `assets/md/dragons.md` §7 |
| **LAST STANDING** | Only one non-eliminated clan remains |
| **STALEMATE T400** | Turn 400 reached — no winner (`STALEMATE_TURN_CEILING`, absolute ceiling) |

See `assets/md/dragons.md` §7 for the full detail + history on the two
dragon-related win conditions, including why `DRAGONS_WIN` was previously
unreachable (near-impossible "zero units in the whole game" bar, and only
checking the legacy Guardian-only `state.dragon` instead of both dragons).

**Why EGG WIN, not dragon-slaying, is the primary/intended win condition:**
destroying the egg does not kill either dragon — Guardian and Hunter are
exactly as alive and dangerous immediately after as immediately before.
It ends dragonkind's *future*, not the dragons themselves: the two adults
have spent three centuries in total stasis specifically because they
learned, at catastrophic cost, that open war with the clans is
unwinnable — their entire strategy is patience, guarding the one clutch
that lets the species continue past them. A shrine fire makes that
patience permanently pointless. See `assets/md/lore.md` ("Why the egg,
and not the dragons" / "How the war ends") for the full narrative, and
`assets/md/dragons.md` §7.1–7.2 for the mechanical-design rationale
(exactly one egg, exactly two dragons, kept deliberately small on
narrative grounds — more eggs dilute the extinction stakes into item
collection, more adult dragons turn "the last two of a dying species"
into "a faction").

Avatar required before Seeker can be built. Avatar is now achievable via **physical meditation** (visits all 8 shrines) OR **virtue spread credits** (Sprint 35). Avatar does NOT end the game.

### Virtue Spread System ✅

Once a shrine is **physically meditated** it radiates its virtue outward through
the landscape. Spread is **terrain-impeded** — fastest along roads, slowest over
mountains — not a uniform radius. When the front reaches a clan's **enclave hex**,
that clan earns an Avatar credit for that shrine, with **no stat bonus** (the
bonuses require physically meditating). A clan reaching the threshold via any
combination of physical meditations and spread credits achieves Avatar.

**Propagation cost per hex** (`movement_engine._VIRTUE_SPREAD_COST`, consumed by a
precomputed Dijkstra in `precompute_virtue_spread_distances`):

| terrain | cost | effective speed |
|---|---|---|
| road (`road_level >= 2`) | 0.5 | **2.00 hex/turn** |
| trail (`road_level == 1`) | 0.67 | 1.50 hex/turn |
| plains · grasslands · sacred | 1.0 | 1.00 hex/turn |
| forest | 2.0 | 0.50 hex/turn |
| swamp | 3.0 | 0.33 hex/turn |
| hills | 4.0 | 0.25 hex/turn |
| sea | 6.0 | 0.17 hex/turn — slow but **crossable** (a 6-hex strait ≈ 36 turns) |
| mountain | 10.0 | 0.10 hex/turn |

**Budget:** `(turn − shrine.virtue_activated_turn) × 1.0` per turn
(`_VIRTUE_BUDGET_PER_TURN`). A clan is credited when its enclave's Dijkstra cost
≤ budget. **Passive fallback** for never-meditated shrines:
`(turn // 20) × 0.5`, so no clan is permanently locked out.

**Spread arrival = discovery (09/06/2026).** A clan does **not** need to have
seen a shrine for spread to credit it. When the virtue front reaches the
enclave of a clan that has no `ShrineRecord` for that shrine, the record is
created via `discover_shrine_for_clan()` (the shrine becomes known/targetable,
`shrine.visible_to[clan]` set) **and** the credit is granted in the same tick —
the locals bring word of the shrine along with its virtue. The `virtue_spread`
event carries `discovered_by_spread: true/false`. This is an in-world
information channel, consistent with the strict no-opacity rule.

> **History 09/06/2026 (VIRTUE_SPREAD_AVATAR_BOTTLENECK).** `sim_09_06_2026_18_07`
> had 20/20 STALEMATE with Avatar in only 3/20 games. First diagnosis blamed
> spread speed + impassable sea; sea was made crossable (9999 → 6.0) and budget
> doubled to 2.0. The 2× run (`sim_09_06_2026_21_58`) only lifted spread
> credits 248 → 335 and Avatars 3 → 7 (still 3/20 games). Real gate: the spread
> loop `continue`d on `rec is None` (undiscovered shrine) — 249/335 credits
> (74%) fired a median **141 turns** (p90 297) after the front had already
> reached the enclave, i.e. only once a unit happened to *see* the shrine.
> Fixed by the discovery rule above; budget reverted to 1.0 to measure it in
> isolation; sea kept crossable.

The distance maps are **rebuilt whenever `road_level` changes**
(`road_wear_tick`), so roads built mid-game really do accelerate spread.

*Worked example (seed 5, `shrine_fighter` at 41,26): fighter's enclave is reached
at ~t17 and mage's at ~t18, but cleric's at ~t91 and ranger's at ~t104 — terrain
dominates the timing.*

> **Doc correction 08/2026.** This section previously said "+1 hex per 3 turns"
> activated / "+1 hex per 20 turns" passive, via `shrine.virtue_radius` and
> `shrine.virtue_passive_radius`. Those fields are not used by the spread code,
> and `virtue_spread_tick`'s own docstring claimed the system was
> "impedance-free… terrain-agnostic… 2.0/turn". All of that was wrong; the code
> has always used the terrain/road Dijkstra above at 1.0/turn.

**Meditation bonus (per shrine).** Physically meditating grants **+1 clan-wide**
(`clan.shrine_bonuses`, applies to current *and* future units) and, for the
**first unit globally** to meditate that shrine, an additional **+1 personal** —
so that unit ends up +2. Later clans meditating the same shrine get the clan-wide
+1 only. Spread credit (`virtue_received`) grants **neither**.

**Clusters cannot meditate.** A cluster must disband first; one unit meditates and
the others protect it, then the group re-forms — see the Clusters section.

Key fields: `shrine.virtue_activated_turn`, `shrine.first_meditation_done`,
`shrine_record.virtue_received`, `shrine_record.virtue_source`,
`clan.virtue_credits_count` (property).

Called every turn after `meditate_at_shrine_tick` as
`virtue_spread_tick(state, analytics)`.

### Scoring — two separate systems ✅

**End-of-game score** (`analytics.score_end_of_game`) — **outcome-driven only**:
EGG WIN +1000 · Avatar +200 · Dragon kill +150 (to killer) · Gold +1/10g (cap 50)
· Units alive +20 each (cap 100) · Alliances +30 each (cap 60) · Eliminated −100.

> **Meditations do NOT score** *(rule change 08/2026)*. This previously awarded
> **+50 per meditation, uncapped** — 8 shrines was +400, more than a third of a
> win. Meditations are a **means** of winning: they unlock Avatar → Seeker → the
> egg race, and the win itself is what scores. Paying for them directly made
> shrine-farming point-positive and would have taught a value-driven AI to
> optimise the proxy instead of the goal.

**Mid-game power ranking** (`analytics._compute_power_score`) — measures who is
winning *right now*: `shrine_count × 30` + units + gold + research + Avatar +
Seeker + structures + vision. **Meditations belong here.** Power rankings are
diagnostic only and never feed end-game scores.

### #195 Discrete Tier Table ⚙️ NOT YET BUILT
Design: +5/+2/+1/0/−1/−2 tiers based on "50% of alive-non-winner avg" threshold.

---

## 3. THE TURN CYCLE  *(Sprint 31 — N-tick model)*

**ORDER WINDOW** (N seconds, default 30 — `config.turn_duration_seconds`):
Human submits intent (MOVE / ATTACK / ACTION). Orders lock immediately on submit. AI waits.

**N-TICK RESOLUTION** (for tick in 1..N, 1 tick = 1 logical second):
- T1: AI submits if `tick ≥ ai_commit_tick` (= base[Easy=15,Med=8,Hard=2,Expert=0] + ceil(units × cost))
- T2: MOVE-order units advance 1 hex at `move_interval = floor(N÷MOV)`. Path recalcs to target's current pos.
- T3: Adjacency/collision combat fires when MOVE unit enters enemy adjacent hex (simultaneous exchange).
- T4: ATTACK(ranged) units fire at their `fire_tick` (Archer=10, Starbow=8, Ranger=12, Shaman=15).
      Moving-target penalty: 0t=×1.0 / 1-3t=×0.85 / 4-7t=×0.65 / 8+t=×0.40.
- T5: Death checks, egg drops, lair claims.
Units freeze at tick N. MOVE and ATTACK orders are mutually exclusive per unit per turn.

**N=30 move schedule:** MOV6→5t MOV5→6t MOV4→8t MOV3→10t MOV2→15t MOV1→30t

**POST-TICK** (once per turn, after all N ticks):
1. Spells  2. Trap triggers  3. Fort bonuses  4. Alliance violations  5. Meditation checks
6. Status ticks  7. MP regen  8. Exhaust HP recovery  9. Economy  10. Production queue
11. Research queue  12. Structure ticks  13. Alliance duration  14. Sentiment drift
15. Monster movement  16. Shrine occupation/virtue · **virtue_spread_tick** (Sprint 35)  17. AI planning  18. Win checks
19. Turn counter  20. Reset queues

### 3.1 SIM TURN SEQUENCE — single shared manifest *(08/2026)*

The N-tick model above describes the **interactive** client. Both simulation
modes — headless (`simulate/headless.py`) and Atlas (`client/atlas_map.py`) —
instead execute one shared, ordered manifest:
**`engine_headless.TURN_SEQUENCE`**, run via a single `run_turn_sequence(state, analytics)` call.

**Headless and Atlas must be equivalent.** Previously each loop listed its own
ticks by hand and they drifted repeatedly. Because runs are *watched* in Atlas but
*regressed* headless, every divergence invalidated the comparison and hid bugs:

| Divergence | Effect |
|---|---|
| `build_port` dispatched in headless only (#154) | no Atlas session could build a port |
| `naval_move_tick` Atlas only | wind never rotated, ports earned no gold in regression |
| `road_wear_tick` Atlas only | headless had no roads → slower movement *and* virtue spread |
| clan elimination headless only | Atlas left 0-unit clans as zombies (fighter: t146→t457) |
| underground economy headless only | Atlas never drained merc gold or decayed influence |
| stacking cap in interactive mover only | sims piled 40+ units on a hex |
| `adjacent_encounter_tick` in **neither** | documented as implemented since Sprint 27; never written |
| entire dragon wake/enrage/enclave-assault subsystem headless only (fixed 08/29/2026) | `DRAGONS_WIN` was unreachable outside headless play |

**Order (32 entries, one flat list — no sentinel).** `town_visit_tick` →
`ai_armory_tick` → `lair_entry_tick` →
`meditate_at_shrine_tick` → `virtue_spread_tick` → `visibility_update` →
`monster_patrol_tick` → `ambush_pre_combat` → `auto_combat_hexes` →
`adjacent_encounter_tick` → `diplomacy_tick` → `update_sentiment_tick` →
`retreat_heal_tick` → `ground_pickup_tick` → `seeker_tick` →
`dark_resonance_tick` → `economy_tick` → `underground_economy_tick` →
`dragon_unit_combat_tick` → `dragon_tick` → `dragon_probabilistic_wake_tick` →
`dragon_threat_enrage_tick` → `dragon_unit_strike_tick` →
`dragon_enclave_assault_tick` → `enforce_carrier_goal_tick` → `unit_tick` →
`road_wear_tick` → `naval_move_tick` →
`sextant_tick` → `spell_cast_tick` → `apply_mp_regen` → `check_second_egg`,
then `eliminate_dead_clans()`, then each mode's `check_win`.
(`enforce_carrier_goal_tick` re-asserts the egg carrier's goal immediately
before movement — backstop for `engine_escort.enforce_carrier_goal()`.)

**Ordering constraints that must not change:**
- `town_visit_tick` before `meditate_at_shrine_tick` — pub intel opens the mantra gate
- `meditate_at_shrine_tick` before `virtue_spread_tick` — a shrine meditated this turn radiates this turn
- `visibility_update` before `economy_tick` — income is `visible_tiles × 0.07`
- combat after movement; `eliminate_dead_clans` before `check_win`
- `dragon_unit_combat_tick` before `dragon_tick` — the same-turn `dragon_tick()`
  must see any HP loss from units striking the dragon when it checks `hp<=0`

**Category B consolidation (08/29/2026):** the dragon subsystem used to be a
`__DRAGON_SPLIT__` sentinel where each loop ran its own ~200-line mode-specific
dragon targeting/assault block (`phase="pre"`, block, `phase="post"`). That
sentinel and split are gone — the five dragon ticks above are ordinary
`TURN_SEQUENCE` entries, called identically by every driver via one
`run_turn_sequence(state, analytics)` call, exactly like every other tick.

**Failures are never swallowed.** `run_turn_sequence` returns `(tick, exception)`
for any step that raised and logs `TICK_ERROR` to `state.combat_log`; a name in the
manifest that no module defines reports `TICK_MISSING`. Atlas's `_safe()` wrapper
likewise reports `ATLAS_TICK_ERROR` / `ATLAS_TICK_MISSING` instead of
`except Exception: pass` — that silent wrapper had been hiding a `TypeError` in
`check_second_egg` (called with 2 args, accepts 1) **every turn**, so the second egg
never spawned in Atlas at all.

**To add or reorder a per-turn engine step, edit `TURN_SEQUENCE` — never a turn
loop.** `tests/engine/test_mode_parity.py` (33 tests) enforces membership,
resolvability, declared arity, and that both loops run both phases.

### 3.2 `world_map.cells` KEY DISCIPLINE — `"q,r"` strings *(08/2026)*

`WorldMap.cells` is **keyed by `"q,r"` strings**, declared in `game_state.py`
(`cells: dict[str, HexCell]`) and chosen for fast JSON serialization.

**Always read cells through `state.world_map.get(q, r)`.**

A tuple lookup — `cells.get((q, r))` — is *not* an error. It returns `None`
silently, and every call site treats `None` as "no such hex", so the failure is
invisible at runtime and produces no log line. Three live bugs of exactly this
shape were found in one pass (08/2026):

| site | silent effect |
|---|---|
| Atlas `_draw_units` fog gate | `None` → **every rival unit hidden whenever fog (`F`) was on** |
| Atlas lair / dragon / egg / tooltip | same — features vanished under fog |
| `engine_sailing.seed_island_loot` | `land_neighbours` always 0, so **every coastal hex passed the "is an island" test** |
| `engine_ai_s39` chieftain coastal check | port-building bonus never applied |

Note `WorldMap.get()` has existed all along — these sites simply bypassed it.
**Interior and enclave maps are different**: `InteriorMap.cells` and
`EnclaveMap.cells` legitimately use `(q, r)` **tuple** keys and have their own
`get_cell()` / `get()` accessors. Only the world map is string-keyed.

Guarded by `tests/engine/test_naval_behaviour.py::test_no_tuple_key_world_map_lookups`.

---

## 4. MAP & TERRAIN

**Terrain types:** plains | grasslands | forest | hills | mountain | swamp | sacred | sea

| Terrain | MOV cost | DEF bonus | Notes |
|---------|----------|-----------|-------|
| Plains | 1 | 0 | Standard. Farmable. |
| Grasslands | 1 | +1 | −1 VIS to units inside. Farmable. |
| Forest | 2 | +1 | FREE for Ranger/Elf/Druid. Lumber Post site. |
| Hills | 2 | +1 | FREE for Ranger. Ranged +1 ATK firing downhill. Mineable. |
| Mountain | ✗ | 0 | Dwarf=2, Ranger=1, all others impassable. Mountain mine (+2 prod). |
| Swamp | 2 | 0 | FREE for Necromancer. No improvements. |
| Sacred | 1 | 0 | Shrine radius 2. No combat in or out. No spells across boundary. |
| Sea | 1 | −2 def | Embarked land units only — **naval hulls are exempt** (`sea_def_modifier()`). Land units: impassable. |

**Movement exceptions by clan:**

| Clan | Forest | Hills | Mountain | Swamp |
|------|--------|-------|----------|-------|
| Ranger | 1 (FREE) | 1 (FREE) | 1 | 1 (FREE) |
| Elf | 1 (FREE) | 2 | ✗ | 2 |
| Druid | 1 (FREE) | 2 | ✗ | 2 |
| Dwarf | 2 | 2 | 2 | 2 |
| Necromancer | 2 | 2 | ✗ | FREE |
| All others | 2 | 2 | ✗ | 2 |

**Road levels (HexCell.road_level):** 0=none, 1=Trail (max terrain/2), 2=Road (cost 1 all),
3=Paved, 4=Ancient. Road level 2+ overrides all terrain costs to 1.

**ZoC:** +1 MOV cost entering hex adjacent to living enemy.
Exceptions: Chieftain ignores ZoC. Monk does NOT trigger ZoC. Ranger Ghost Step:
only adjacent (not distant) enemies trigger ZoC. Scout does not trigger ZoC.
*(Diplomat removed Sprint 30 — Scouts+Chieftains initiate diplomacy directly.)*

**Collision cases:**
1. Attacker arrives at occupied hex → melee
2. Two enemies arrive at same hex simultaneously → simultaneous damage exchange
3. Two friendlies → lower-initiative unit bounces
4. Units swap hexes in same turn → no combat (pass-through)

**Friendly stacking cap (bugfix 08/2026):** Same-clan units may never exceed
`MAX_FRIENDLY_STACK = 6` on a single hex (`movement_engine.py`). Each tick,
before a unit commits its 1-hex step, `_tick_step_move()` checks a live
per-tick occupancy map (`_friendly_occupancy()`); if the destination already
holds 6 of the unit's own clan, `_find_spill_hex()` redirects the step to the
best available (passable, under-cap) neighboring hex that still makes
progress toward the target. If every neighbor is also at/over cap, the unit
simply holds its current hex for that tick rather than over-stacking. This
forces large armies converging on one destination to spread into a
cluster/ring around it instead of collapsing into a single frozen mega-stack
— see also the Sprint rally-ring fix in `_ai_defend_enclave()`
(`engine_ai.py`), which applies the same spreading principle to defenders
converging on an enclave.

**The cap applies in ALL modes (bugfix 08/2026, second pass).** The logic above
originally lived *only* inside `resolve_turn()`, which is the **interactive
client's** mover. Atlas and `simulate/runner.py` never call it — their unit
movement happens directly inside the AI modules — so those four movement sites
assigned `unit.q, unit.r` with no cap, and the cap had never applied to any
headless or Atlas run. That is why sims produced 40+ deep mega-stacks while the
interactive game looked correct.

`movement_engine.commit_step(unit, nq, nr, state, target_q, target_r)` is now the
**single shared, cap-enforcing position writer**, backed by a per-turn cached
occupancy map (`turn_occupancy()`, rebuilt when `state.turn_number` advances and
kept in sync incrementally). It returns `True` if the unit moved, `False` if it
held position rather than over-stack, and deliberately does **not** touch
`has_moved` — each caller owns its own turn/MOV bookkeeping. All four AI movers
route through it:

| Site | Function |
|---|---|
| `engine_ai.py` | `headless_shrine_advance()` — shrine BFS advance |
| `engine_ai_s41.py` | lair-assembly staging hold (worst offender: every member routed to the *same* staging hex) |
| `engine_ai_s41_ext.py` | `execute_cluster_movement()` — solo-goal step |
| `engine_ai_s41_ext.py` | `execute_cluster_movement()` — cluster-lead MOV loop |

**Placement is capped too, and that is where the real stacks came from
(bugfix 08/2026, third pass).** A verification run proved the movement-side cap
above was aimed at the wrong population: the 40+ piles were made of units that
**never move at all**, so no mover was ever consulted.

- **Spawns.** Every produced unit appeared on the exact enclave hex
  (`_spawn_production_unit`). One run put 18 necromancer units on `(32,92)`.
  Spawning now goes through `movement_engine.find_open_hex_near()`, which walks
  outward ring by ring to the first hex under `MAX_FRIENDLY_STACK`, and
  `register_placement()` keeps the cached occupancy map in step so several units
  produced on the same turn do not all pick the same "open" hex.
- **Garrison.** `engine_cluster.garrison_tick()` could only ever *grow* the
  garrison — it returned early on any non-deficit, so recalled units were never
  released, and a unit with an empty goal (`""`) within 5 hexes of home *counted*
  as garrison. That was a ratchet: idle-near-home → counted → never given a field
  goal → stays idle. One clan held 18 units against a target of 2. Now surplus is
  released (healthiest first, logged as `GARRISON_RELEASE`), `""` no longer counts
  as garrison, and `_spread_garrison()` pushes any remaining over-stack into a
  ring around the enclave.

**Never assign `unit.q, unit.r` directly in AI code** — call `commit_step()` to
*move* a unit, or `find_open_hex_near()` + `register_placement()` to *place* one.

### Clusters (redesigned 08/2026)

A **cluster** is an explicit, persistent group of same-clan units standing on one
hex, which **acts as a single unit** for goals, commands and movement, but
**attacks once per member**. Members keep individual HP and stats — there is no
pooled HP bar, so casualties simply remove members and shrink the cluster.

| Property | Rule |
|---|---|
| Max size | `MAX_CLUSTER_SIZE` = `MAX_FRIENDLY_STACK` = **6** (a cluster *is* a stack) |
| Creation | `join_cluster` unit goal, or the player's cluster toggle on a stack |
| Destruction | `disband_cluster` unit goal, or the player's disband toggle |
| Leader | deterministic (lowest `unit_id`) — a stable leader means a stable goal |
| Goal | every member follows the leader's goal (`sync_cluster_goals()`) |
| Movement | the leader steps, the members step onto the leader's hex |
| Combat | one attack per living member (6 members = 6 attacks) |

**Why the previous system was deleted.** Clusters used to be *inferred* every
turn by grouping units that had independently chosen the same
`(goal, target_id)` within a broadcast radius. Identity was rebuilt from scratch
each turn, so a cluster dissolved the moment any member re-scored its goal.
Measured over one real 173-turn run: **1836 missions created, 35 completed —
a 1.9% completion rate**, 10.6 missions churned per turn, stalls from turn 6.
Removed with it: `MissionRecord` filing, satisfaction scoring, stall detection,
the retreat/re-form state machine, conviction-based lead election, the cohesion
pass and lair assembly staging. Replaced by two cheap passes —
`cluster_integrity_tick()` and `sync_cluster_goals()` in `engine_cluster_v2.py`.

### Goal selection: normalized roulette wheel (redesigned 08/2026)

Every decision layer scores its options, normalizes them into a probability
distribution summing to **1.0**, and picks by cumulative walk against one roll
from the seeded `state.rng`:

```
goal A = 10%, goal B = 25%   →   roll ∈ [0.00,0.10) picks A
                                 roll ∈ [0.10,0.35) picks B
```

**Invariant: a goal is blocked only if its score is exactly 0.0.** A zero is a
hard veto (missing prerequisite, wrong unit type, already done); everything else
keeps a real chance every turn.

| Layer | What it decides | k |
|---|---|---|
| **Clan** | strategic intent (`ai_current_goal`), publishes `directive_set` | 2.0 |
| **Enclave** | production stance: `units`/`buildings`/`tech`/`navy`/`defense` | 2.0 |
| **Unit** | per-unit goal, incl. `join_cluster`/`disband_cluster` | 1.5 |

**Why it changed.** Selection was deterministic `argmax`, so a raw score of 1.0
behaved as "always wins" rather than "is strongest" — anything ranked second was
dead code. Measured for the elf clan at its real in-game state: 14 goals scored
non-zero summing to 7.301, `upgrade_units` pinned at **1.000** won every single
turn, and `train_galley` at 0.600 (**8.2%** of total intent, ≈1 turn in 12) was
selected **zero** times across a 173-turn run — while being exactly *tied* with
`construct_building` and losing on dict ordering alone. `upgrade_units` also held
a fixed 12-turn commitment, expired, and won again: a self-reinforcing lock.

Post-change, that same state gives `upgrade_units` 22.9% and every goal a real
share. Inspect any state with:
`python tools/goal_distribution.py --seed 5 --clan elf --sailing --port`

**Supporting mechanics** (all in `engine/engine_goals.py`):

| Mechanic | Effect |
|---|---|
| Randomized commitment | duration rolled from a (min,max) range each selection, scaled by clan genetics — fixed constants made behaviour metronomic |
| Repeat penalty | the just-expired goal is ×0.5 for one draw, breaking the renewal loop |
| Proximity weighting | `score × (1 + max(0,1−d/R)·W)`; a unit 3 hexes from town scores ×1.45 vs ×1.05 at 11 hexes, so it **finishes** journeys instead of abandoning them near the objective |
| Achievement cooldown | a completed goal is suppressed and recovers linearly (`upgrade_at_town`: 12–18 turns, depth 0.8 → ×0.2 the next turn, so a unit does not re-shop at the armoury it just emptied) |

**Naval goals moved to their correct layers** and must not return to `ALL_GOALS`
(a source-guard test enforces this): `build_port`/`train_galley` → enclave
`navy` stance · `research_sailing` → enclave `tech` stance (`navy` scores 0.0
without Sailing, which creates the dependency chain) ·
`explore_islands`/`raid_rival_port` → unit goals, galley-gated.

**A cluster cannot meditate.** Only a single unit may meditate at a shrine (that
is what earns the bonus), so a cluster arriving at its target shrine **must
disband**:

1. `score_disband_cluster()` returns **1.0 — mandatory** once the group is within
   1 hex of its `advance_shrines` target, so it splits itself.
2. `disband_for_meditation()` picks the meditator (nearest to the shrine hex,
   tie-break healthiest), tags the others `ai_shrine_guard_of` so they hold
   position and protect, and records the roster in `ai_reform_group`.
3. Both meditation-start sites block a unit with `ai_cluster_id` set, logging
   `MEDITATION_BLOCKED_CLUSTERED`. Designated guards are blocked too — otherwise
   every ex-member standing on the hex would meditate and burn a 20-turn cooldown
   for a single clan credit.

   ⚠️ **The block now performs the split itself** *(bugfix 08/2026)*. It used to
   only refuse, trusting step 1 to split the group on some later turn — and step
   1 very often never fired, because `score_disband_cluster()` returns 1.0 only
   for the cluster **leader** and only under the `advance_shrines` goal. A stack
   that arrived under any other goal, or whose leader stood elsewhere, blocked
   forever. Measured in `sim_08_17_2026_13_16`: **1,078
   `MEDITATION_BLOCKED_CLUSTERED` against just 322 successful meditations** — a
   3:1 loss rate on the single action that produces Avatars.

   That is the top of the win-path funnel, so it starved everything downstream:
   only **53 of 160 clan-slots ever reached Avatar**, at a median of **turn
   192** of a 400-turn game. (The Sanctum is *not* the bottleneck it was once
   assumed to be — 52 of those 53 avatars built one, a median of 6 turns later.)
   The block now calls `disband_for_meditation()` at the point of need and logs
   `split: true`, and if the blocked unit is itself chosen as meditator it
   proceeds on the same turn rather than losing one to the round trip.
4. On `complete_meditation()`, `try_reform_after_meditation()` re-merges the
   surviving members standing on that hex, so the group continues to its next
   objective together (`CLUSTER_REFORMED_AFTER_MEDITATION`).

### ⚠️ Movers must pathfind, not walk in straight lines *(bugfix 08/2026)*

`engine_ai_s41_ext.execute_cluster_movement()` — the mover that moves **most
units in the game** — stepped with `_step_toward()`, pure linear interpolation,
and `break`-ed on the first mountain or sea hex. A unit whose direct line was
blocked simply **stopped for the whole turn** instead of walking around.

The map is **33.8% impassable** (29.3% sea, 4.5% mountain), so a straight line
to any distant target is usually blocked. Measured in `sim_08_17_2026_19_09`,
units with MOV 3–4:

```
0 hexes 75.4% of turns | 1 hex 12.8% | 2 hex 7.8% | 3+ hex 4%
```

93% of shrine-seekers sat 11+ hexes from their target, closing it at **0.25
hexes/turn**. After routing through `movement_engine.find_path_full()` — a
budget-limited A* that respects terrain, roads and mountains — a probe measured
**3.60 hexes/turn on the same journey, a 14× improvement**.

`engine_ai.py` had already recorded this exact lesson for the *combat* mover
(*"Previously used `_step_toward` … combat never resolved"*). The fix was never
applied to the cluster mover, so the same bug shipped twice. A straight-line
probe survives only as a last resort when no route exists at all, so a walled-in
unit shuffles rather than freezing.

**Landing needs no harbour.** Embarking still requires Sailing tech, a coastal
hex and an adjacent friendly port — but a crossing may end on **any adjacent
non-sea, non-mountain hex**. `disembark_unit()` previously demanded
`is_coastal`, which both rejected valid landing sites *and* allowed a landing
party ashore on a coastal **mountain** (seed 22's (1,26) is exactly that — it
was what the old naval test happened to select).

Guarded by `tests/engine/test_movement_pathfinding.py`.

### 📊 READ FIRST: how to judge whether a change actually did anything *(08/2026)*

**Never compare two run averages.** Use the paired tool:

```
python tools/compare_runs.py <baseline_run> <candidate_run>
python tools/compare_runs.py --latest 2
```

It pairs **seed 1 vs seed 1**, tests the per-seed *differences*, and prints an
explicit noise/significant verdict plus a confidence interval for every metric.

#### Why run averages are the wrong test

EGG_WIN is a **binary** outcome measured 20 times. At a true rate of 20%,
binomial noise alone gives a 95% range of **0.5–7.5 wins out of 20**. Five
successive runs produced **8, 5, 3, 2, 4** — a textbook binomial sample. Those
swings were read as code-caused regressions, two reverts were performed on that
basis, and neither restored the "baseline" because no regression existed.

Running the tool on those two runs retroactively returns `noise` (p = 0.29) for
the 8 → 4 EGG_WIN change. Had it existed, three sessions of wrong analysis would
have been avoided.

#### Smallest effect detectable (80% power, α = 0.05)

| n/arm | EGG_WIN shift | chaos change |
|---|---|---|
| 20 | 35 pp (20%→55%) | 0.060 |
| **40** | **25 pp (20%→45%)** | **0.043** |
| 60 | 20 pp (20%→40%) | 0.035 |
| 100 | 16 pp (20%→36%) | 0.027 |
| 200 | 11 pp (20%→31%) | 0.019 |

**Even n=40 cannot see a 20% → 30% EGG_WIN improvement.** "noise" in the report
means *no detectable effect at this n*, **not** *no effect*.

#### Practical rules

1. **Judge on continuous metrics first.** Measured CVs on the baseline:
   `chaos` 24%, `turns` 26%, `shrines` 42%, `avatars` **97%** (near a zero
   floor — ignore it). A continuous metric carries far more information per game
   than one win/lose bit.
2. **`turns` is CENSORED at 400** — 15 of 20 games hit the cap, so a change that
   makes games *slower* cannot show up there.
3. **Pairing is worth ~1.5× the sample size for free.** Measured seed-to-seed
   correlation between two code versions: r = 0.405.
4. **Use 40–60 seeds as standing default; 100–200 for headline go/no-go.**
   `--seed-range 1-60` (~3.5 min at 20 workers).
5. If the tool reports **20/20 seeds bit-identical**, the change is genuinely
   behaviour-neutral — a real and useful result worth asserting.

The tool's own statistics are unit-tested in `tests/engine/test_compare_runs.py`
(13 tests), including a hand-verified t-table reference, because untested
statistics would simply produce confident wrong answers.

⚠️ **`--seed-range` used to be silently truncated by `--games` (default 5)**, so
`--seed-range 1-60` ran only 5 games and reported success. Fixed 08/2026: an
explicit `--seed-range` is now authoritative.

### 🔴 READ FIRST: the sim was NOT reproducible — `PYTHONHASHSEED` *(08/2026)*

**Every regression comparison made before this fix is suspect.** The same seed
and the same code produced different games in different processes:

```
seed 3, 25 turns, three separate processes:
   (26 turns, 204 combats, 3 shrines, 18 kills)
   (26 turns, 135 combats, 3 shrines, 14 kills)
   (26 turns, 210 combats, 4 shrines, 16 kills)

with PYTHONHASHSEED=0:
   (26, 156, 4, 16)   ×3   ← identical
```

Two runs *inside one process* were always identical, so the variance was
**per-process**, not per-call.

**Cause.** Python randomises `hash(str)` per process (PEP 456), so iteration
order over a **set of strings** differs between runs. The scope is narrow, and
worth stating precisely because guessing at it wasted a lot of effort:

| construct | affected? |
|---|---|
| `dict` iteration | **No** — insertion-ordered since 3.7 |
| `hash(int)`, `hash((int, int))` | **No** — not randomised |
| `set` / `frozenset` of **strings** | **Yes** |

Somewhere in the turn loop such a set is iterated, changing the order in which
the shared `random` stream is consumed. Seed 1 stayed byte-identical through t4,
then a **t5 combat roll** differed and the game went somewhere else entirely.

**What this invalidated.** Four consecutive runs showed EGG_WIN
`8 → 5 → 3 → 2` of 20 and this was read as a code-caused decline. It was four
samples of a noisy distribution (mean ≈ 4.5). Two separate reverts were judged
to have "failed to recover" on that basis, and two elaborate causal stories were
written about mechanics that were never responsible.

**A1 — `PYTHONHASHSEED=0` pinned (belt).** `simulate/cli.py` relaunches itself
once as a child process with the env var set, guarded by an
`AEVUM_HASHSEED_PINNED` sentinel so it cannot loop, and skipped when not invoked
as a real sim entry point. `ProcessPoolExecutor` workers inherit the env.

`os.execve()` cannot be used here: it replaces the process image, which crashes
on Windows (`0xC0000409`) once native extensions are loaded, and `main.py`
imports pygame at module scope.

**A3 — fixed at source (braces). ✅ DONE.** The env var is no longer load-bearing.

Bisected with a per-tick state fingerprint under two `PYTHONHASHSEED` values.
First divergence: **`monster_patrol_tick`, turn 1** —

```python
_dir0 = (state.turn_number + abs(hash(unit.unit_id)) // 997) % 6
```

Every monster's patrol direction was per-process random. Six further sites seeded
`random.Random(... ^ hash(some_id))`. All seven now use the new
**`engine/stable_hash.py::stable_hash()`** (BLAKE2b over the UTF-8 bytes,
returns a non-negative int, stable across processes/platforms/versions):

| file | what it controlled |
|---|---|
| `engine_headless.py` ×2 | monster patrol direction; lair-outcome RNG |
| `engine_enclave.py` ×2 | lair interior generation |
| `engine_items.py` ×2 | blacksmith restock window + stock; organic migration |
| `engine_underground.py` | per-town underground NPC roster |

⚠️ **Never call the builtin `hash()` on a string in game logic.** Use
`stable_hash()`. `game_state.py`'s `hash((self.q, self.r))` is exempt — a tuple
of ints, not randomised, and it feeds no decision.

**Verified.** Whole-game results are now identical under `PYTHONHASHSEED=0` vs
`12345`, and two full 20-game/20-worker production runs were **bit-for-bit
identical**: all 20 seeds matched on every headline field, on `per_clan_end`, on
all 58,076 events, and on MD5 of every raw JSONL log (`ts` stripped). The only
differing field in the entire results file was `elapsed_seconds`.

`tests/engine/test_determinism.py` (4 tests, all passing) enforces this:
same-seed reproducibility, hash-seed independence, a source guard banning
`hash(<string>)` in `engine/`, and a guard that the CLI pin stays in place.
Revert-probed — reintroducing the `monster_patrol_tick` bug fails two of them.

**Keep the A1 pin as well.** Belt and braces: it costs nothing and protects
against a future site that slips past the source guard.

### ⚠️ `--turns` did not reach parallel workers *(bugfix 08/2026)*

`simulate/cli.py` implemented `--turns` by patching
`simulate.runner.MAX_TURNS` **in the parent process only**. Workers are separate
processes (spawn on Windows) that re-import `runner` fresh, so
`--turns 8 --workers 3` silently ran three *full 400-turn* games. It appeared to
work only because a single-seed run forces `workers=1` and stays in-process.
The value is now forwarded explicitly through `run_parallel(max_turns=...)` and
re-applied inside `_worker`.

### ✅ `engine_pub` shares the GLOBAL random stream — FIXED *(08/2026)*

> **RESOLVED.** `engine_pub` now draws exclusively from `state.rng` via the
> module-local `_rng(state)` helper — every `random.choice` / `randint` /
> `sample` call site was converted, and the two cosmetic dialogue helpers
> (`_barkeep_drink_line`, `_intel_reveal_line`) take an explicit `rng=`
> parameter. `test_pub_never_touches_the_global_random_module` fails the build
> if a bare `random.*` draw reappears in that file. The history below is kept
> because it explains why several earlier A/B comparisons were invalid.

**Any change that alters how many random draws a game makes will re-roll that
entire game.** `engine/engine_pub.py` imported the **global `random` module**
(line 13) and used it throughout (`random.choice`, `random.randint`,
`random.sample`), while `simulate/runner.py` seeds that global **once per game**
(`random.seed(seed ^ 0xAEF1)`). One shared stream fed every pub visit.

This invalidated a whole session's worth of A/B comparisons. A pub bugfix that
merely stopped `ai_pub_visit()` from crashing part-way through — letting
`action_bribe` / `action_listen_in` run at all — consumed a different number of
draws and produced completely different games from the same seed:

```
seed 1:   monk wins t156   ->   bard wins t160   ->   stalemate t400
                     (identical mover code, identical seed)
```

Downstream, measured across three runs:

```
                     07:14   08:22   09:06
village_visited       2467    2037     996     (-60%)
intel_token_acquired  6345    5548    4479
MANTRA_GATE_BLOCKED   2051    2665    3401     (monotonic rise)
EGG_WIN                40%     25%     15%
```

Less intel → fewer mantras → fewer meditations → no Avatar → no winner.

**Consequences for how we work:**
- ✅ Done: `engine_pub` draws from `state.rng`. The pub system can now be
  changed without re-rolling unrelated AI, combat and movement decisions, and
  the `.content` shape fix has been re-landed on top of it.
- ⚠️ **Still open for other modules.** `engine_pub` was the worst offender, not
  the only one. Any module making bare `random.*` draws during a turn shares the
  same global stream and has the same hazard. Prefer `state.rng` everywhere.
- Note the related but distinct `stable_hash` fix: builtin `hash(str)` is
  randomised per process, so seeding an RNG with `hash(some_id)` was
  non-reproducible across runs. See `engine/stable_hash.py`.

### ⚠️ The cluster-lead freeze: a REAL defect, but UNVALIDATED *(08/2026)*

> **An earlier version of this section claimed the freeze was "load-bearing".
> That claim was wrong and has been withdrawn** — see "the experiment was
> confounded" below.

The pathfinding fix above was correct but barely moved the aggregate numbers
(units moving 24.6% → 26.8%), because a second defect in the same function
discarded it for most units.

`execute_cluster_movement()` resolved its cluster **leader** and then
`continue`d the whole cluster — skipping *every member for the entire turn* —
whenever any of three things was true of that one unit:

- `lead.has_moved` (an earlier mover — combat, garrison recall, heal — had
  already consumed its turn),
- the lead had no resolvable destination,
- **the lead had already ARRIVED** (`distance == 0`).

The third is the *normal* end-state of every journey, because the leader is by
definition the member nearest the objective. So the standard outcome was: the
leader parks on the target and its 1–5 followers freeze permanently, several
hexes short, forever.

Measured in `sim_08_18_2026_07_14` (seeds 1–5, monsters excluded):

```
upgrade_units unit-turns frozen:  80.5%  (112,261 of 139,494)
clustered units:  5,012 frozen /   510 moved
frozen with HP<=2: 1.3% of frozen samples   <- NOT a damage/heal effect
```

Probed directly on seed 1: leader standing on its target at (66,12), follower at
(59,13) seven hexes away — the follower advanced **0 hexes**. The mover was
healthy *in isolation* (the same unit alone covered 9 hexes in 3 turns); only the
cluster path froze, which is exactly why the 14× probe never showed up in the
aggregate.

#### The experiment was confounded — the revert disproved the diagnosis

In `sim_08_18_2026_08_22` every cluster member was allowed to pathfind
independently when its lead could not act. EGG_WIN fell **40% → 25%** and the
mover was blamed.

`sim_08_18_2026_09_06` then reverted the mover to **byte-equivalent 07:14
behaviour** (verified: guards restored, no independent follower routing, suite
green). EGG_WIN did **not** recover:

| | 07:14 | 08:22 | **09:06 (revert)** |
|---|---|---|---|
| EGG_WIN | 40% (8/20) | 25% (5/20) | **15%** (3/20) |
| STALEMATE | 60% | 75% | **85%** |
| avg turns | 328 | 358 | **384** |
| % units moving | 26.8% | 24.4% | **23.2%** |
| `advance_shrines` hex/turn | 1.26 | 0.88 | **0.71** |

**A correct revert that does not restore the baseline proves the reverted change
was never the cause.** The real culprit was the `engine_pub` RNG perturbation
documented in the section above, shipped in the *same* session and mislabelled
"behaviour-neutral".

The dispersal/attrition explanation previously recorded here was a story fitted
to noise — the headline "efficiency 0.577 → 0.502" figure does not even
reproduce (re-measured: 0.453 / 0.469 / 0.464, essentially flat).

**Both changes were reverted at the time.** The mover keeps its `continue`
guards. *(The pub fix has since been re-landed — see the analytics section
below — once its RNG precondition was met.)*

#### Status: real defect, unknown value

The freeze is **demonstrably real** — a follower 7 hexes behind an arrived leader
provably moves 0 hexes, reproduced directly on seed 1. Whether unfreezing it
helps or hurts the game is **unknown**; it has never been measured cleanly.

Before attempting it again:

1. ✅ **Make the RNG deterministic first** (`engine_pub` → `state.rng`) so an A/B
   comparison means anything at all. **Done 08/2026** — this precondition no
   longer blocks the attempt.
2. **Change one thing per run.**
3. Prefer a narrow first attempt — cohesion-preserving follower routing (converge
   on the leader's hex only), or scoping the unfreeze to win-path goals
   (`advance_shrines`, `seek_egg`) and leaving errands like `upgrade_units`
   frozen.

`tests/engine/test_cluster_lead_freeze.py` holds 4 behavioural tests; 3 are
**xfail** and stand as the spec. Do not delete them. The 4th
(`test_lead_still_advances_normally`) is a live guard.

### ⚠️ Cluster-lead SELECTION bug: escort clusters froze the Seeker itself *(09/2026, FIXED)*

A distinct defect in the same `execute_cluster_movement()` function, found
while root-causing a 100/100 STALEMATE regression batch: leader selection
used `min(members, key=lambda u: u.unit_id)` (lexicographic) unconditionally,
ignoring `ai_cluster_role == "lead"` entirely. `seeker_escort_pass()`
(`engine_ai_s41.py`) explicitly assigns the Seeker `ai_cluster_role = "lead"`
for a clan's `<clan>:seek_egg:egg:escort` cluster — but escort unit_ids like
`..._common_...`/`..._defender_...` sort lexicographically *before*
`..._seeker_...`, so an escort (not the Seeker) became the movement lead.
An escort's own destination (`ai_goal_target_q/r`) is set to the seeker's
*current* position (pure cohesion, not a real destination), so the escort
read "already arrived" every turn and — per the freeze mechanism documented
above — froze the **entire cluster, Seeker included**, indefinitely.

Confirmed live: `monk_seeker_monk_265` (seed 5, `sim_09_04_2026_12_00`) sat
motionless at `(88,56)` for 40+ consecutive turns while the egg sat at
`(32,44)`, never approached. Zero `egg_picked_up` events occurred across the
entire 100-game batch — every game hit turn 400 with the egg never picked
up, guaranteeing STALEMATE.

**Fixed:** leader selection now prefers a member with `ai_cluster_role ==
"lead"` when one exists, falling back to the lexicographic rule only when no
member has an explicit lead role. Regular clusters (`advance_shrines`,
`upgrade_units`, etc.) never set an explicit lead role, so they are
unaffected by this change — only `seek_egg:egg:escort` clusters (and any
future cluster type that assigns an explicit lead) are affected.

NOT YET sim-verified — awaiting the user's next regression run to confirm
`egg_picked_up`/EGG_WIN events start appearing and the STALEMATE rate drops.

### ⚠️ Analytics that silently reported zero *(bugfix 08/2026)*

Three metrics used to judge game health were structurally incapable of being
non-zero:

| metric | defect |
|---|---|
| `meditation_log` / `per_clan_end.meditation_actions` | `simulate/runner.py` filtered `combat_log` for `event == "shrine_meditated"`, but `complete_meditation()` emits **`"SHRINE_MEDITATED"`**. Empty in *every game of every run ever recorded* — 332 real meditations were invisible and the per-clan column read 0.0 for all 12 clans. Now case-insensitive. |
| `dragon_wake_trigger` | hardcoded `None`, so `report.html` always said *"wake trigger: none, 20 games (100%)"* although `_wake_dragon()` records a real `reason`. Now reads it. |
| pub visits | `engine_pub` did `ki.content.intel_type` on `state.clan_intel` entries, but `engine_ai_s39.apply_sextant_effect()` appends a plain **dict**. Any clan holding a Sextant crashed its pub visit (`AttributeError: 'str' object has no attribute 'content'`, seeds 4 and 13) and the visit was abandoned mid-way. `_intel_type()` / `_intel_extra()` / `_intel_id()` now accept both shapes. |

**All three are now live.**

- ✅ **`meditation_log` / `dragon_wake_trigger` — kept.** Verified in
  `sim_08_18_2026_08_22`: `meditation_log` 0 → 300 entries
  (`meditation_actions` non-zero for the first time in project history), and
  `dragon_wake_trigger` now reports `checkpoint_t100…t350`. These are genuinely
  behaviour-neutral: they read `state.combat_log` **after** the game ends and
  consume no randomness. (6 of 20 games still log `None` — a wake path that
  records no `reason`. Worth a look.)
- ✅ **The pub `.content` fix — RE-LANDED 08/2026.** It was reverted once, and
  correctly so: it is *not* behaviour-neutral, because it changes how far
  `ai_pub_visit()` executes and therefore how many draws are taken from the
  shared global RNG. The revert note set an explicit precondition — *re-land
  once `engine_pub` draws from `state.rng`* — and that precondition is now
  satisfied. `ai_pub_visit()` no longer aborts mid-visit for Sextant holders, so
  `action_bribe` and `action_listen_in` run for the first time on those clans.
  Both tests are live (no longer xfail).
  ⚠️ **Expect this to move the numbers.** Pub draws are now isolated from the
  global stream, so this run is not comparable draw-for-draw with the n60
  baseline; judge it on the continuous metrics via `tools/compare_runs.py`.

Guarded by `tests/engine/test_results_instrumentation.py`, which asserts **both
sides** of each contract — the emitter and the reader — so a rename on either
side fails loudly instead of zeroing a metric.

### ⚠️ A goal without a destination freezes the unit *(bugfix 08/2026)*

`_target_pos()` in `engine_ai_s41.py` turns a `(goal, target_id)` pair into a
hex. **A unit goal with no branch there has nowhere to walk, so the unit stands
still — silently, with no error logged anywhere.**

`upgrade_units` is an *enclave production* goal (it spends gold at home) that
was also listed in `UNIT_ELIGIBLE_GOALS`. Units adopted it, got no destination,
and parked. Measured in `sim_08_17_2026_17_38`:

```
upgrade_units = 34,915 of 62,835 unit-turns  (53% of the entire army)
only 15.9% of ALL units moved on any given turn
```

Movement rate by goal — note the top line:

| goal | share | moving |
|---|---|---|
| **idle** *(no goal at all)* | 1% | **99.8%** |
| defend_enclave | 5% | 23.9% |
| **upgrade_units** | **53%** | 16.9% |
| advance_shrines | 25% | 12.2% |
| gather_intel | 6% | 10.1% |

Units with *no* goal moved freely; every purposeful goal suppressed movement.
For `advance_shrines`, 84% of units sat 11+ hexes from their target shrine and
closed distance at **0.146 hexes/turn** against MOV 3–4. That is the root cause
behind the stalemate wall, and it is long-standing — the best-ever run
(`02_36`) measured 14.3%.

**The rule now:** any *discovered* town, castle or village is a valid
`upgrade_units` target (nearest wins, scored down by distance); if the clan has
discovered none, it scores `scout_map` instead and goes looking. Discovery is
permanent per clan via `cell.is_explored[clan_id]`.

> Two traps found while fixing this, both worth remembering:
> `world_map.cells` is keyed by the **string** `"q,r"`, not a `(q, r)` tuple —
> a tuple lookup silently misses every cell. And treating a missing cell as
> "discovered" made the fallback unreachable.

Guarded by `test_goal_reachability.py::test_every_movement_goal_resolves_a_destination`,
which asserts every dispatched unit goal either resolves a hex or is explicitly
listed as destination-free. The pre-existing scoring test passed the whole time
because it only checked *phase anchors*, never whether a destination existed.

**There is no separate cluster *goal* system.** Goals live at the unit level;
`join_cluster` and `disband_cluster` are ordinary unit goals scored alongside the
rest, which is exactly what the player's UI toggle does. `advance_shrines` is
deliberately *cluster-worthy* (travel escorted) but splits **on arrival** — only
one unit may meditate — because treating it as solo-preferred created a
form/disband churn loop where clusters dissolved the same turn they formed.
The single documented exemption is seeker navigation (`engine_ai.py`): one seeker
per clan means it cannot stack with itself. A source-guard test in
`tests/engine/test_stack_cap_sim_movers.py` fails the build if any other direct
position write reappears — it covers `engine_ai.py`, `engine_ai_s41.py`,
`engine_ai_s41_ext.py` **and `engine_headless.py`**. `engine_headless.py` was
missing from that list on the first pass, which is precisely how the uncapped
spawn path and three uncapped monster-patrol writes survived a fully green test
run. Any module that repositions a clan unit must be added to that list.

**Adjacent Encounter ✅ (genuinely implemented 08/2026):** After all movement, enemy
units at hex distance = 1 that are NOT on sacred ground and NOT allied fight an
automatic simultaneous exchange. Creates conflict friction around egg-delivery
routes and shrine approaches. Logged as `adjacent_encounter` in `combat_log`;
`state._adj_encounter_total` feeds the `adjacent_encounters` run statistic.

> **This was a phantom ✅ until 08/2026.** The section was marked implemented and
> `simulate/runner.py` reported an `adjacent_encounters` statistic, but **no such
> function existed** and the counter was never assigned — every report read 0.
>
> Its absence is the main reason no logged run has ever produced a winner.
> `auto_combat_hexes()` fires only when two clans occupy the **exact same hex**
> and resolves one pair per hex per turn. Measured at t457 of seed-5 run
> `atlas_08_10_2026_19_21`: **773 clan units, 198 occupied hexes, only 7
> contested** — a ceiling of ~7 combats/turn against ~4 units produced/turn.
> Armies grew 16 → 745 units, only 38% of production ever died, and no clan
> reached Avatar. Re-measuring that same end state under the new rule gives
> **36 adjacent pairs (5× the combat)** engaging 72 units per turn.

Rules: one encounter **per unit per turn** (a unit ringed by six enemies is not
deleted in a single tick) · monsters never infight but always fight clans ·
alliances and non-aggression pacts are respected · deaths route through
`_kill_unit()` so loot, XP and egg-drop still apply.

Damage uses `combat_engine.effective_atk` / `effective_def`, so **terrain DEF,
forts, shrine bonuses and items finally affect simulated combat**.

Run by **both** turn loops (`simulate/runner.py` and `client/atlas_map.py`) — a
guard test fails the build if either drops it.

**08/30/2026 — `auto_combat_hexes()`/`ambush_pre_combat()`/
`attack_enclave()` now share the same damage math (Category C Sub-problem 2
dedup, damage-formula half).** These three had been the last combat paths
still computing damage from raw `state.effective_stat()` — no terrain DEF,
no fort bonus, no sea DEF modifier, no monster weakness — confirmed by their
own long-standing in-code comment ("auto_combat_hexes uses a raw atk-def and
has never consulted any of them"). All three now route through
`combat_engine.effective_atk()`/`effective_def()` + `sea_def_modifier()` +
`_apply_monster_weakness()`, the same primitives `resolve_hit()` (the
interactive client's N-tick mover) and the already-fixed
`adjacent_encounter_tick()` use. `auto_combat_hexes()`'s cluster multi-attack
feature (N cluster members = N attacks) is unaffected. Guarded by
`tests/engine/test_combat_dedup_terrain.py`.

**Still genuinely separate (not merged this pass, deliberately deferred):**
the full 755-line `combat_engine.py`'s ranged combat, line-of-sight, and
tick-interleaved simultaneous-exchange resolution remain wired only into
`movement_engine.resolve_turn()` — the interactive client's N-tick mover,
which itself has no production caller yet (`client/game_loop.py`'s
`_do_resolve()` calls `run_turn_sequence()`, not `resolve_turn()`). Merging
these fully (removing `auto_combat_hexes()`/`ambush_pre_combat()`/
`adjacent_encounter_tick()` from `TURN_SEQUENCE` and making `resolve_turn()`
the sole combat resolver everywhere) is a larger, still-open change tied to
unmetered cluster/lair movement — see
`doc/ENGINE_CONSOLIDATION_PLAN_2026_08.md` Category C Sub-problem 1/2.

### Mode parity: headless and Atlas MUST be equivalent ✅

The two turn loops are hand-written and repeatedly drifted, so the same seed
produced different games depending on which mode ran it. Confirmed and fixed
08/2026:

| step | was | now |
|---|---|---|
| `road_wear_tick` | Atlas only — headless never built roads, so movement *and* virtue spread were slower there | both |
| clan elimination (0 units) | headless only — Atlas left wiped-out clans as zombies | both |
| `adjacent_encounter_tick`, `diplomacy_tick` | neither | both |

Earlier instances of the same class: `build_port` dispatched only in headless
(#154), `naval_move_tick` only in Atlas, dragon force-wake, seeker spawning.

`tests/engine/test_mode_parity.py` enumerates every shared tick and **fails the
build on divergence** — add new per-turn steps to that list.

### AI decisions + action dispatch ✅ (revised 08/29/2026)

`engine_headless.run_ai_decision_ticks(state, analytics=None, n=None)` is
THE single AI-decision driver for both modes (headless, Atlas) — internally
runs a tick loop (`n` = `state.config.turn_timer_seconds`) pinging every
non-eliminated AI clan's `engine_ai.ai_tick_decide()` every tick. This is
what metering AI difficulty means concretely: each difficulty spends a
different number of ticks per decision (`_AI_TICKS_PER_DECISION`), against
the same shared clock a human player faces. Neither driver calls
`process_ai_turn()` or `execute_clan_actions()` directly anymore — that is
enforced structurally by `tests/engine/test_mode_parity.py::
test_shared_dispatcher_is_used_by_both`.

`engine_headless.execute_clan_actions()` remains the single ACTION dispatch
point underneath — `ai_tick_decide()` calls it internally as each worklist
entry (cluster or solo unit) drains. It handles `move`, `attack`, `produce`,
`train_naval`, `build_camp`, `build_port` and `diplomacy`.

**Movement metering (revised 08/30/2026):** `run_ai_decision_ticks()` also
calls `engine_ai.headless_shrine_advance(clan_id, state, analytics, tick=tick,
n=n)` inside the same per-tick loop (not once after it). With `tick`/`n`
supplied, the shrine/seeker mover is TICK-PACED: each unit advances at most 1
hex per tick, gated by `move_interval = max(1, n // MOV)` and a
`ticks_moved_this_turn` counter reset to 0 for every alive unit once per turn
— the same cadence and field `movement_engine._tick_step_move()`/
`resolve_turn()` use for the interactive client. This is a real behaviour
change from prior sessions where this mover walked a unit's whole MOV budget
in one instantaneous call. `engine_ai_s41_ext.execute_cluster_movement()`
(the cluster/lair mover) is NOT yet metered — it remains a separate instant
per-turn pass, deliberately left alone pending its own dedicated pass (see
Category C Sub-problem 1/2 in `doc/ENGINE_CONSOLIDATION_PLAN_2026_08.md`).

`build`, `research`, `meditate`, `visit_town` and `hold` are deliberately *not*
dispatched — they are resolved by position-based ticks
(`meditate_at_shrine_tick`, `town_visit_tick`) or by the enclave production
stance. Anything else logs **`ACTION_UNHANDLED`** and prints a warning.

> **Why the guard exists:** there was no `else:` branch, so an unhandled action
> vanished silently. An audit found the AI emitted 9 action types while only 3
> were dispatched. Four were accidentally covered by side channels — but
> `diplomacy` was covered by nothing, which silently disabled a 598-line
> subsystem (below).

### Diplomacy ✅ (activated 08/2026)

`engine_diplomacy.py` implements passage rights, meditation rights,
non-aggression pacts, alliances, betrayal and virtue debt. **It was entirely dead
code**: no AI call site reached it (the `diplomacy` actions were dropped, above)
and neither turn loop ran its expiry functions, so pacts and alliances never
lapsed and **betrayal could never occur** — removing one of the game's designed
chaos drivers. Only 2 alliances appeared in a 457-turn run, and those came from
`engine_sentiment`, not this system.

Now: `diplomacy` actions dispatch (`buy_rights` → `make_rights_offer`, `nap` →
`make_nap`, alliance logging), and **`diplomacy_tick()`** runs in both loops
calling `tick_naps()`, `tick_alliances()` and `grace_period_tick()`, logging
`NAP_EXPIRED` / `ALLIANCE_EXPIRED` / `GRACE_PERIOD_ENDED`.

### Garrison ✅ (fixed 08/2026)

The enclave garrison (target 2, up to 5–6 under threat) draws **only from units
that are genuinely free**. Units on `advance_shrines`, `seek_egg`,
`contest_egg_carrier`, `clear_lair` or `attack_rival` — or holding a sticky goal,
meditating, or carrying the egg — are **never recalled**. If the deficit cannot be
met, the enclave **queues a defender** instead, so garrisoning competes for gold
rather than cannibalising the win path.

> **Why:** recall used to target expedition units within 20 hexes, and the
> surplus-release logic made a released unit an instant recall candidate again —
> **458 recalls vs 192 releases**. One traced unit oscillated between two hexes
> for ~90 turns without covering the 21 hexes to its shrine. At t457, 15 of 773
> units were on shrine duty and **none had arrived**, which is why only 20 shrines
> were meditated in 457 turns and no clan ever reached Avatar.

### Buildings ✅ (reconciled 08/2026)

The AI now reads the **full 26-building catalogue from `buildings.json`**
(`BUILDING_CATALOGUE`), honouring the real 5-tier chain, `any_tier2`
prerequisites, `clan_specific` tier-5 buildings (`war_hall`→fighter,
`forge`→dwarf, `arcane_tower`→mage …) and `requires_avatar` (Sanctum).

> **Why:** the AI previously knew only **6** buildings, four of which
> (`bank`, `watchtower`, `counting_house`, `barracks_ii`) **do not exist in
> `buildings.json`** — they were invented in Python. Clans exhausted them by ~t60,
> after which the `buildings` stance scored 0.0 forever and the only thing left to
> buy was units: **1,640 units queued vs 38 buildings (43:1)**, with 6 of 8 clans
> pinned at the 1000 gold cap. The enclave stance commitment also survived item
> completion, so production intent effectively never changed; it now re-scores
> once its item is built (except `navy`, which sees its port→hull chain through).

### HexCell Flags (set at world gen, immutable) ✅
`is_sacred_ground`, `is_egg_zone` (radius 15–20 from center), `is_central_zone` (radius 20),
`is_pass` (mountain carved to hills), `is_shrine`, `is_enclave`, `is_town`, `is_castle`,
`is_coastal` (land adj to sea), `is_island` (#151), `is_port` (#154), `is_ruin` (#151),
`road_level` (0–4)

---

## 5. THE 12 CLANS

✅ Stats from unit_types.json `common_units` section (authoritative). 8 active per game.
**Starting composition:** 1 Chieftain (free, at enclave) + 1 Scout (adjacent). *(was: 1 Common Unit + 2 Scouts)*

**Chieftain (universal):** ATK 6, DEF 4, MOV 5, HP 8, VIS 3. MP = clan tier. Free at start; 250g/6t rebuild, requires War College.
- **Rally Aura**: +1 ATK/DEF to all friendly units within 2 hexes
- **Command Push** (1/turn): push adjacent friendly unit its full MOV; Chieftain cannot move that turn

| Clan | Color | Shrine | MagT | ATK | DEF | MOV | HP | MP | Common Unit |
|------|-------|--------|------|-----|-----|-----|----|----|-----------|
| Fighter | Steel blue | +atk | 0 | 5 | 3 | 3 | 6 | 0 | Fighter |
| Mage | Purple | +vis | 5 | 2 | 1 | 3 | 3 | 24 | Mage |
| Cleric | Rose | +def | 3 | 3 | 5 | 3 | 5 | 14 | Cleric |
| Dwarf | Amber | +hp | 0 | 5 | 5 | 2 | 7 | 0 | Dwarf |
| Ranger | Green | +mov | 1 | 3 | 2 | 5 | 4 | 4 | Ranger |
| Elf | Teal | +arc | 3 | 4 | 2 | 4 | 4 | 14 | Elf |
| Rogue | Brown | +stl | 1 | 5 | 2 | 4 | 4 | 4 | Rogue |
| Monk | Coral | +res | 2 | 4 | 3 | 4 | 5 | 8 | Monk |
| Druid | Green | +lck | 3 | 3 | 3 | 3 | 5 | 14 | Druid |
| Necromancer | Purple | +atk_weak | 4 | 4 | 2 | 3 | 5 | 20 | Necromancer |
| Bard | Gold | +int_stat | 2 | 2 | 2 | 4 | 4 | 8 | Bard |
| Shaman | Grey | +arc | 4 | 3 | 2 | 3 | 5 | 20 | Shaman |

### The three-tier unit ladder *(restructured 08/2026)*

Every clan builds the same ladder, one unit per tier:

```
barracks (T1)  ->  COMMON     120g / 4t
armoury  (T2)  ->  ADVANCED   150g / 5t
clan T5 bldg   ->  SPECIALTY  150-225g / 5-8t
```

Shared, no building required: scout 50g, archer 60g, defender 60g.

### ⚠️ REVERTED EXPERIMENT — do not re-attempt blindly *(08/2026)*

An equalised power-budget rebalance (common 17 / advanced 23 / specialty 29,
with archer raised to 75g and defender to 100g) was implemented and then
**reverted after it measurably regressed the game twice**:

| run | change | EGG_WIN | STALEMATE | chaos |
|---|---|---|---|---|
| `sim_08_15_2026_02_36` | *(this baseline)* | **30%** | **55%** | 0.397 |
| `sim_08_15_2026_11_51` | advanced 200g/7t + power/gold argmax | 20% | 70% | 0.409 |
| `sim_08_16_2026_21_14` | equalised budgets + raised floor | **15%** | **75%** | **0.304** |

The unit data is now back at the `02_36` values, which remain the
best-performing configuration recorded.

**Two real defects survived the revert** and are still open. Both are genuine
and should be fixed *individually, each with its own measured run* — not as
another sweeping rebalance:

1. **Specialty units average LESS martial power than Advanced** while costing
   more and requiring ~730g of cumulative buildings. The Grand Arcanist is
   `1/1/2` — **four** power for 225g.
2. **Power varies 2.29× between clans within a tier** (common: mage 7, dwarf
   16). Part of that is intentional — casters trade body for MP and spell tier
   — but not all of it.

Asserted as *still present* by
`tests/engine/test_unit_ladder.py::test_known_data_defects_are_documented`, so
fixing either one trips the test and forces the doc to be updated with it.

Ladder invariants still guarded by `tests/engine/test_unit_ladder.py`: all 12
clans have every tier, cost is monotonic, Advanced is strictly stronger than
Common, and every Specialty unlocks from a building that actually exists.

### How the AI picks which unit to build

`engine_ai._enclave_build_queue_ai()`. **Offence and defence are scored
separately, then sampled** — never argmax over one number:

```
offence = atk / gold
defence = (def + hp) / gold
score   = w_atk * offence + w_def * defence     (x1.25 for the clan's Common)
```

| Posture | Trigger | w_atk | w_def |
|---|---|---|---|
| defensive | enclave HP below max | 0.25 | 0.75 |
| offensive | goal is attack_rival / clear_lair / contest_shrine_zone / steal_egg | 0.75 | 0.25 |
| balanced | otherwise | 0.50 | 0.50 |

Selection then goes through the shared `select_weighted(..., k=K_ENCLAVE)`
roulette wheel, so a unit twice as good is roughly twice as *likely* — not
certain. Measured mix for a fighter clan with the full chain unlocked:

```
DEFENSIVE   common 32%  specialty 28%  advanced 25%  defender 15%
BALANCED    common 34%  specialty 28%  advanced 26%  defender 12%
OFFENSIVE   common 39%  advanced 32%   specialty 30%   (defender 0%)
```

**Why this matters — two prior argmax attempts both produced a monoculture:**

- ranking by `-cost` ("buy the priciest affordable") gave **2352 advanced vs
  156 common** in `sim_08_15_2026_02_36`;
- ranking by flat `(atk+def+hp)/gold` gave the exact inverse in
  `sim_08_15_2026_11_51` — **zero advanced and zero ranged units built across
  20 games**, plus 7589 defenders, because a 60g/11-power defender had the best
  ratio on the board and argmax awards the winner 100% of production.

An argmax over any single scalar will always collapse to one unit type.
Averaging atk with def+hp also treats a wall as interchangeable with a sword,
which is why the two axes stay separate.

The old hard override that forced `{clan}_defender` whenever the enclave was
damaged has been removed — defensive posture is now a *weight*, so a damaged
clan favours durable units while still fielding something that can fight back.

**There are TWO production paths, and both must sample.** `engine_cluster.
_queue_defender()` builds a unit when the garrison cannot be filled from free
units, and it used to hardcode `templates.get(f"{clan_id}_defender")`. That is
not a rare fallback: in `sim_08_16_2026_21_14` it issued **2311 of 5786 unit
orders (40%)**, so two fifths of all production ignored the sampler entirely and
bought a defender unconditionally. **75.9% of every unit built that run was a
defender**, while a probe of the *other* path predicted a healthy mix that never
materialised — the probe was measuring a path that governed only 60% of output.

Garrison duty does legitimately want durability, so that path keeps a defensive
weighting (0.25 atk / 0.75 def+hp), but it now goes through the same
`select_weighted` sampler. Measured effect on the garrison path alone:

```
before   defender 100%
after    defender 50%  advanced 17%  common 12%  specialty 11%  archer 10%
         (early game, barracks only: defender 59%  common 23%  archer 18%)
```

**Lesson worth keeping:** when auditing a decision, check how many code paths
reach the outcome. A probe that exercises one path can look perfect while the
aggregate behaviour is dominated by another.

**Repriced 08/2026.** Advanced was 150g/5t: +25% gold and +25% turns for
**+40-71% raw power**, i.e. strictly dominant. The AI built **2352 advanced
against 156 common (15:1)** in `sim_08_15_2026_02_36` and produced its first
Advanced *before* its first Common (t129 vs t133) - the bottom of the ladder
was vestigial. At 200g/7t an Advanced costs ~1.7 Commons for ~1.5x the power,
so massing Commons stays viable. Specialty was floored to 225g/8t so the tiers
do not invert (Runesmith/Trapper/Thornweaver were *cheaper* than Advanced).
Guarded by `tests/engine/test_unit_ladder.py`.

The `unit_type` formerly called `"clan"` is now **`"common"`** — every clan has a
*common* unit (a Fighter, a Mage, a Rogue). **`"advanced"`** is new: a veteran
upgrade of the Common unit with **+2 ATK / +1 DEF / +2 HP**, inheriting MOV, VIS,
MP, spell tier and terrain traits unchanged.

⚠️ The old *clan-specific ranged units* (Crossbowman, Longbowman, Bone Caster…)
and *clan-specific defender units* (Sentinel, Shieldwall…) were **deleted from
`unit_types.json` in 08/2026 — they had been dead data for some time.** The
loader builds one **universal Archer** and one **universal Defender** for every
clan from `unit_types.archer` / `unit_types.defender`. Do not re-add per-clan
variants without also changing `startup_engine._build_unit_templates()`.

Shared by all 12 clans: **Scout** 50g/2t · **Defender** 60g/3t · **Archer**
60g/3t · **Seeker** 300g/7t (needs Sanctum; only unit that may carry the egg) ·
**Chieftain** 250g/6t (needs War College). Naval hulls (galley / warship /
privateer) are shared and buildable by any clan.

| Clan | Common (a/d/m/h) | Advanced | Advanced (a/d/m/h) | Specialty | T5 unlock |
|------|------------------|----------|--------------------|-----------|-----------|
| Fighter | Fighter 5/3/3/6 | **Champion** | 7/4/3/8 | Warlord | war_hall |
| Mage | Mage 2/1/3/4 | **Magus** | 4/2/3/6 | Grand Arcanist | arcane_tower |
| Cleric | Cleric 3/5/3/5 | **Templar** | 5/6/3/7 | High Priest | temple |
| Dwarf | Dwarf 5/4/2/7 | **Ironbreaker** | 7/5/2/9 | Runesmith | forge |
| Ranger | Ranger 3/2/4/4 | **Pathfinder** | 5/3/4/6 | Trapper | ranger_post |
| Elf | Elf 4/2/4/4 | **Bladesinger** | 6/3/4/6 | Starbow | archer_range |
| Rogue | Rogue 5/2/4/4 | **Shadowblade** | 7/3/4/6 | Assassin | shadow_den |
| Monk | Monk 4/3/4/5 | **Warrior Monk** | 6/4/4/7 | Iron Fist | monastery |
| Druid | Druid 3/3/3/5 | **Archdruid** | 5/4/3/7 | Thornweaver | grove |
| Necromancer | Necromancer 4/2/3/5 | **Grave Warden** | 6/3/3/7 | Death Knight | crypt |
| Bard | Bard 2/2/4/4 | **Skald** | 4/3/4/6 | Spymaster | thieves_guild |
| Shaman | Shaman 3/2/3/5 | **Spiritspeaker** | 5/3/3/7 | Stormcaller | spirit_lodge |

### Specialty Units (require the clan's tier-5 building)

| Clan | Specialty | ATK/DEF/MOV/HP | Cost | Key Ability |
|------|-----------|----------------|------|-------------|
| Fighter | **Warlord** | 6/4/3/9 | 225g/8t | Rally Command: friendlies within 2 hex +1 ATK/+1 DEF |
| Mage | Grand Arcanist | 1/1/3/2 | 225g/8t | Arcane Relay: teleport friendly 6 hex (1/turn) |
| Cleric | High Priest | 2/6/2/7 | 225g/8t | Instant meditation. Heals 3 HP adj/turn |
| Dwarf | Runesmith | 4/6/1/9 | 225g/8t | Ward Rune: hidden 3-dmg trap, 2-hex range, 3 uses |
| Ranger | Trapper | 3/2/5/4 | 225g/8t | Snare: hidden trap within 3 hex, target loses turn, 4 uses |
| Elf | Starbow | 5/2/3/3 | 225g/8t | True Shot RNG 4, ignores terrain cover. ARC 3, VIS 5 |
| Rogue | Assassin | 7/1/5/3 | 225g/8t | Ambush instant-kill non-specialty from stealth, 2 uses |
| Monk | Iron Fist | 6/4/4/7 | 225g/8t | Stun Strike: target skips next turn, 3 uses |
| Druid | Thornweaver | 2/3/3/6 | 225g/8t | Grow Forest: convert 3 hexes to forest, 2 uses |
| Necromancer | Death Knight | 6/3/3/8 | 225g/8t | Reanimate: revive adj dead unit for 5 turns, 3 uses |
| Bard | Spymaster | 3/2/5/4 | 225g/8t | Steal Gold (10% treasury, 2 uses) + Plant Rumor (3 uses) |
| Shaman | Stormcaller | 3/2/3/6 | 225g/8t | Lightning Storm: 7 dmg, 3-hex AoE, T4 |

> **The Siege Engineer was removed in 08/2026** and replaced by the **Warlord**,
> an elite melee commander. Two bugs went with it: its `unlock_building` pointed
> at `barracks_ii`, **a building that does not exist in `buildings.json`**, so
> the Fighter clan could never build a specialist at all (`engine_ai` skips any
> template whose `requires_building` is not owned). The real gate is `war_hall`.
> The Chieftain was gated on the same phantom building and now requires
> `war_college`.
>
> ⚠️ **All 12 specialty abilities in the table above are defined in JSON but
> unimplemented in the engine** — including Warlord's Rally Command. The
> `rally_aura_atk/def/radius` fields are set on units by `engine_items.py` but
> never read by `combat_engine.py`, so the two aura items (Warlord's Standard,
> Crown of Dominion) do nothing either. Tracked as a follow-up task.

### Key Clan Passives

| Clan | Passive |
|------|---------|
| Fighter | **Charge** — move through occupied hex, trigger combat, continue |
| Mage | Highest mana (30 MP). T5 spell access |
| Cleric | **Free Heal** — +2 HP adjacent friendly, free action, 1/turn |
| Dwarf | Mountain cost 2. No magic (0 MP) — but spells land on Dwarf normally (no immunity). |
| Ranger | Ghost Step ZoC. Forest/hills/mountain/swamp FREE |
| Elf | Meditate from 1 hex OUTSIDE sacred radius |
| Rogue | **Invisible** beyond 2 hexes (breaks on attack). **Assassin Mode** (Sprint 27): night phase (t%40 ∈ 15–25) AI pursues meditating/low-HP targets with +2 ATK. **Egg Theft** (Sprint 27): steal_egg goal (weight 0.9) intercepts enemy seeker carrying egg within 12 hex. |
| Monk | Does NOT trigger ZoC. Units ZoC-immune with Monastery |
| Druid | Forest FREE. Grows 1 forest hex/5 turns |
| Necromancer | **Dark Resonance** — +1 ATK per 3 deaths on map (all deaths, cumulative, permanent) |
| Bard | Reads enemy shrine completion status (visible clans). Rumor detection: min(80%, int_stat×15%) |
| Shaman | All AoE spell damage +1 |

### Wonders (300g/10t, requires any 3 T3 techs)

| Clan | Wonder | Effect |
|------|--------|--------|
| Fighter | Hall of Champions | Future Common/Advanced Units +2 ATK at production |
| Mage | Eye in the Sky | Permanent full map vision for Mage clan |
| Cleric | Cathedral of Mercy | +2 combat HP/turn all visible-territory units |
| Dwarf | The Eternal Forge | All buildings complete in half turns |
| Ranger | Pathfinder's Sanctum | All terrain cost 1 for Ranger clan |
| Elf | Star Observatory | Seeker VIS+10. Archers RNG+2. Egg detectable r=16 |
| Rogue | Shadow Citadel | All clan units invisible beyond 3 hexes |
| Monk | Temple of Harmony | Alliance ×2 duration. No shrine camping virtue debt |
| Druid | World Tree | Forest +0.2g/turn. Lumber Posts +2 MP regen |
| Necromancer | Throne of Dust | Reanimated units last forever, return at full HP |
| Bard | Grand Archive | All village intel at Regular tier. Rumors ID'd |
| Shaman | Storm Spire | All AoE spells +2 dmg, +1 radius |

---

## 6. THE 12 VIRTUES & KINSHIP PAIRS

✅ From virtues.json (code verified)

| Clan | Primary Virtue | Kinship Partner | Secondary Virtue |
|------|----------------|-----------------|------------------|
| Fighter | Valor | Elf | Honour |
| Elf | Honour | Fighter | Valor |
| Cleric | Compassion | Necromancer | Sacrifice |
| Necromancer | Sacrifice | Cleric | Compassion |
| Mage | Wisdom | Bard | Honesty |
| Bard | Honesty | Mage | Wisdom |
| Dwarf | Fortitude | Rogue | Loyalty |
| Rogue | Loyalty | Dwarf | Fortitude |
| Monk | Humility | Druid | Temperance |
| Druid | Temperance | Monk | Humility |
| Ranger | Spirituality | Shaman | Justice |
| Shaman | Justice | Ranger | Spirituality |

Kinship pairs: higher mantra confidence at start (0.55–0.70). Higher AI alliance affinity.

### Companion System (#191) ✅ Ranger only
Companion assigned from terrain of first shrine meditated. Reduces dragon wake probability.
- Forest → Wolf (dragon wake mult: 0.45)
- Hills → Eagle (dragon wake mult: 0.30)
- Swamp → Bear (dragon wake mult: 0.40)
- Plains → Hound (dragon wake mult: 0.50)

---

## 7. SHRINES & MEDITATION *(Sprint 30 — names corrected to virtues; MP restore removed; atk_dark→atk_weak; Dwarf end→hp)*

**8 shrines per game** (one per active clan). Placed 8–12 hexes from owning enclave (seed-determined direction).
`ShrineInstance`: shrine_id, clan_id, q, r, mantra, virtue, meditation_turns_unknown (seeded 10–14).
Sacred radius = 2 hexes. No combat or spells across sacred boundary.

**Mantra pool:** 100 invented words (10 phonetic families). 8 drawn seeded, no repeats.

### Shrine Table (Sprint 30)

| Clan | Shrine Name | Bonus Stat | Effect |
|------|-------------|------------|--------|
| Fighter | Shrine of Valor | **+ATK** | +1 dmg/hit all units |
| Mage | Shrine of Wisdom | **+VIS** | +1 VIS all units, more gold |
| Cleric | Shrine of Compassion | **+DEF** | +1 damage absorption |
| Dwarf | Shrine of Fortitude | **+HP** | +1 max HP all units |
| Ranger | Shrine of Spirituality | **+MOV** | +1 move/turn all units |
| Elf | Shrine of Honour | **+ARC** | +1 arcane, spell dmg +1, resist +1 |
| Rogue | Shrine of Loyalty | **+STL** | Spotted 1 hex later |
| Monk | Shrine of Humility | **+RES** | Status effects land less |
| Druid | Shrine of Temperance | **+LCK** | +5% crit, +5% item find |
| Necromancer | Shrine of Sacrifice | **+ATK(weak)** | +1 dmg vs enemies <50% HP only |
| Bard | Shrine of Honesty | **+INT** | Intel faster, +1 fragment/visit |
| Shaman | Shrine of Justice | **+ARC(elem)** | AoE spells +1 dmg |

**Bonus application:** Meditating unit: **+2**. All other clan units (current + future): **+1**. Applied immediately on completion.

### Meditation Knowledge Tiers ✅ (RETUNED 08/2026)

| Knowledge | Confidence | Turns to meditate |
|-----------|------------|-------------------|
| Direct (hold the word) | 1.0 | **1 turn** |
| Secondhand high | ≥0.70 | **2 turns** |
| Secondhand medium | 0.40–0.69 | **3 turns** |
| Secondhand low | 0.10–0.39 | **4 turns** |
| Unknown | 0.0 | **10–14 turns** (`shrine.meditation_turns_unknown`) |

> **Why these changed.** Sprint 23 (#169) tripled the known tiers to 2/4/6/8.
> That predated the discovery that mantra **supply was broken**:
> `T_MANTRA_VALUE` was never emitted by `build_token_context()`, so no clan
> could learn a word at all and every clan was pinned in the slowest tiers.
> Measured over 60 games: ~2.0 physical meditations per clan-slot against the
> **8 credits Avatar requires**, and 75% STALEMATE. With supply fixed, the tiers
> return to the table `MantraKnowledge` (`game_state.py`) documented all along —
> now the single source of truth, guarded by `test_meditation_tiers`.
>
> The **10–14 unknown tier is deliberately punitive and retained**: it is what
> makes a mantra worth buying. Meditation is no longer hard-BLOCKED at conf 0.0
> in the tier table — the hard gate in `meditate_at_shrine_tick` still applies,
> but a clan that acquires any confidence at all now has a fast route.
> The 20-turn post-meditation cooldown remains the true pacing lever.

**Clan confidence modifiers:** Bard +0.15. Shaman −0.10.

**Starting knowledge per clan:**
Own shrine=1.0. Kinship shrine=0.55–0.70. 1 random=0.55–0.70. 1 random=0.40–0.60. 4 remaining=0.0.

**Meditation state machine:** `unit.is_meditating=True` + `unit.meditation_turns_remaining=N`.
Interrupted by movement or attack. Effect: progress lost, `is_waking=True`, `effective_def=2` for 1 turn.
Virtue debt applied to attacking clan on interrupt. 20-turn cooldown after any shrine meditated.

**#218 Universal shrine bonus** ⚙️ NOT YET CODED — pending Sprint 25:
Every shrine also grants a thematic bonus to ANY clan meditating it (including own clan — confirmed T82).
Confirmed: Fighter/Valor: +2/+1 ATK. Elf/Honour: +1 VIS personal.
10 drafted bonuses for remaining clans — awaiting Claude Web Q7 confirmation.

**#216 Alliance betrayal rollback** ⚙️: Already-earned #218 bonuses from betrayed ally's shrine stripped.
Not-yet-earned permanently denied. Avatar credit (#199) unaffected.

**Contemplation Hall** ⚙️ NOT YET CODED: Scholarship tech required. Buy/sell shrine credits.
Purchased credit = Avatar tick only (no stat bonus).
Sell: 1 contributor=200g, 2=150g, 3=100g, 4+=60g.
Buy: 1=400g, 2=300g, 3=200g, 4+=120g.

---

## 8. AVATAR & SEEKER

**Avatar threshold — ALL 8 VIRTUE CREDITS.** `clan.avatar_status = True` when the
clan holds a credit for every shrine:

```
credits = count(rec.is_meditated OR rec.virtue_received)  >=  8
```

**How a virtue was obtained is irrelevant.** A credit earned by physically
meditating and one received passively through virtue spread are worth exactly the
same for Avatar and the egg race. Set by `simulate/runner.py` and
`client/atlas_map.py` (both `= 8`), read everywhere via `avatar_threshold(state)`.
Does NOT end the game.

Evaluated in **two** places — both are required:
* `engine_headless.complete_meditation()` — on a physical meditation.
* `engine_headless.virtue_spread_tick()` — on a spread credit. Without this a
  clan could accumulate all 8 credits passively and never be granted Avatar,
  silently dead-ending its win path.

### What physical meditation buys instead: combat strength

| case | clan-wide | meditating unit | unit total |
|---|---|---|---|
| **first clan** to meditate that shrine | +1 all units | +2 | **+3** |
| any **later clan**, same shrine | +1 all units | +1 | **+2** |

Applied in `complete_meditation()` against `clan_templates[clan].shrine_bonus_stat`,
logged as `SHRINE_BONUS_APPLIED`. Virtue spread grants **no** stat bonus.

> **Rule change 08/2026 (supersedes the hybrid gate).** The previous rule also
> required `done_phys >= AVATAR_PHYS_MIN` (4). That physical minimum was the hard
> wall on the entire win path: measured physical meditations averaged **~2.3 per
> clan**, because clans are seeded with only 4 of 8 mantras and the intel economy
> that should supply the rest was **completely broken** (see §21.2 — 0 town
> visits, 0 village visits, 0 pub pints across a 20-game regression). Avatar, and
> therefore Seeker and EGG_WIN, was arithmetically unreachable no matter how well
> a clan played. `AVATAR_PHYS_MIN` is retained as `0` for import compatibility and
> must not be reintroduced into the gate.
>
> The old threshold of 7 was itself a tuning workaround for the same broken
> economy. Additionally, `movement_engine.py` carried a **second, contradictory**
> Avatar check (`meditated_count >= 8`, physical-only, bypassing
> `avatar_threshold()`), so the interactive client resolved Avatar by a different
> rule than headless/Atlas; it now routes through the shared rule.
>
> Earlier still, this section claimed *"8 shrines meditated (LOCKED #197)"*, which
> matched neither the code nor the runners. The default was written inline at
> **six** sites and disagreed (`7`, `8`, `len(state.shrines)`); it is now
> single-sourced, with a guard test failing the build if an inline default returns.

**#200 Ward of Last Making:** Auto-satisfied by #198 — Seeker requires Avatar.

**Seeker:** ATK2, DEF2, MOV3, HP3, VIS3. Can carry the egg (`can_carry_egg=True`).
**Max 1 per clan.** MOV 3 with egg (no bonus). Dragon stealth mult 0.5.

**Seeker gating — enforced 08/2026.** `unit_types.json` declares
`requires_avatar: true` and `requires_building: "sanctum"`; **neither was
enforced**, and both spawn paths additionally allowed a pre-Avatar spawn at
`threshold - 2` shrines (= **5**) whenever `egg_urgency > 0.6`. In one seed-5 run
`AVATAR_ACHIEVED` fired only for elf (t115) and rogue (t161), yet seekers were
built by **mage t114** (5/8 shrines, never Avatar), **elf t120 *and* t131** (two
for one clan), and rogue t166.

All seeker production now goes through `engine_ai.can_build_seeker(state, clan)`,
which reads the requirements from the template and returns a distinct refusal
reason (`no_avatar`, `missing_building:sanctum`, `seeker_exists`,
`insufficient_gold`, `template_missing`), logged as `SEEKER_REFUSED`. The
pre-Avatar path is **removed**, not tightened — it contradicted locked spec
#198/#200.

Three supporting defects fixed at the same time:
- **Seekers are per-clan templates** (`mage_seeker`, `elf_seeker`, … 12 of them).
  The old lookup took the first `unit_type == "seeker"` template and returned
  `fighter_seeker` for every clan — visible in the log as
  `fighter_seeker_mage_114`.
- **`sanctum` was missing** from the AI building tables the enclave `buildings`
  stance scores from, so enforcing the building requirement alone would have made
  seekers *impossible* rather than rarer. It is now present, Avatar-gated, and its
  cost is read from `buildings.json`.
- **`engine_structures.can_build_structure()` never existed.** The call sat inside
  a bare `except: pass`, so no building prerequisite was ever validated — the
  comment "no prereq system — build freely" described an accident.

**Sanctum:** **150g / 8 build turns** (`buildings.json`, authoritative), tier 0,
`requires_avatar: true`, +1 DEF to all clan units, unlocks the Seeker.
*Balance change 08/2026: was 200g/20t. Avatar lands late (t115/t161 observed), and
20 build turns plus the Seeker's own build meant 27+ turns after Avatar before any
seeker existed — usually past the point of mattering.*

### The win-path gold reserve *(08/2026)* ✅

The `Avatar → Sanctum → Seeker → egg` chain is **compulsory and its price is
known exactly** (150g + 200g), so a clan approaching Avatar must be *saving for
it* rather than discovering it is broke afterwards.

`engine_ai.win_path_gold_reserve(state, clan_id)` returns the gold to hold back;
`spendable_gold()` is what **every discretionary buyer must consult** instead of
`clan.gold`. Wired into the build-queue AI (units/buildings/tech) and the castle
dragon-gear purchase. The reserve starts **2 virtue credits before Avatar**, so
the money is already banked when the Sanctum unlocks, and shrinks to 0 as each
link is completed.

> **Why:** `sim_08_14_2026_21_21` logged **1,160 `SEEKER_REFUSED` events** across
> 20 games — 831 `missing_building:sanctum` and 329 `insufficient_gold` at a
> **median treasury of 77g** against a 200g Seeker (one game logged 180). The
> Sanctum auto-queue was working fine (57 built); clans were simply spending the
> money elsewhere first — including, as of the previous session, on dragon gear.
>
> `SEEKER_REFUSED` is now also **rate-limited to one line per clan per reason per
> 25 turns**. It fired every turn while the condition held, which is what
> produced 1,160 events of pure noise.

### Sanctum auto-queue (Fix 4, 08/2026) ✅
The win path is a **chain**: `Avatar → Sanctum → Seeker → egg → EGG_WIN`. Every
link is mandatory, so once Avatar lands there is no decision left to make.
`engine_ai.auto_queue_sanctum(state, clan_id)` queues the Sanctum immediately,
logging `SANCTUM_AUTO_QUEUED`. It is called from two places:

1. `engine_headless.complete_meditation()` at the `AVATAR_ACHIEVED` branch —
   the instant the prerequisite is met.
2. `force_fill_production_queue()` every turn, as a **retry**: the one-shot in
   (1) silently no-ops if the clan happens to be short of gold on exactly that
   turn, which would otherwise dead-end the win path permanently.

It is idempotent — no-ops if the clan lacks Avatar, already owns a Sanctum, has
one queued, or cannot afford it, and debits gold exactly once.

**Why:** in the 20-game regression `sim_08_13_2026_17_41` there were 61
`SEEKER_REFUSED` events and **100% were `missing_building:sanctum`**. Clans were
reaching Avatar and then never building the one structure that unlocks the
Seeker, because the Sanctum had to win a scoring contest against every other
building. It frequently lost, and the win path stopped there.

---

## 9. DRAGON SYSTEM

See `assets/md/dragons.md` for the consolidated data-and-mechanics
reference (types, escalation, hatch, and the hatchling->adolescent->adult
growth arc) — this section is the narrative/history companion.

✅ **Two dragons:** Guardian (HP 30+) + Hunter (HP 22+). **Different types per seed.** Guardian weighted toward Gold/Silver; Hunter weighted toward Red/Blue. HP bonuses apply per-type independently.
Guardian: patrol_radius 10, vortex movement. AWAKE/FOCUSED=1 step/t · ANGRY/ENRAGED=2 steps/t.
Hunter: patrol_radius 20. AWAKE/FOCUSED=2 steps/t · ANGRY/ENRAGED=3 steps/t. DESTROYER state if Guardian slain.

### 9.0 DRAGON COMBAT BALANCE TABLE *(measured 08/2026)*

**How many units does it take to kill a dragon?** Ancient Armour absorbs 5
damage **per turn, shared across all attackers**, so damage is
`max(0, N × atk − 5)`. A small force does not kill slowly — it cannot win at all.

Guardian HP 30, **no dragon gear**:

| attackers | atk 2 (clan/ranged/defender) | atk 4 (elite/seeker) | atk 6 (chieftain) |
|---|---|---|---|
| 1 | **never** | **never** | 30 turns |
| 2 | **never** | 10 | 5 |
| 3 | 30 turns | 5 | 3 |
| 4 | 10 | 3 | 2 |
| 6 | **5** | 2 | 1 |

Hard floor: **3 attackers** with standard atk-2 units (2 units deal 4 < 5 and
never break through). A practical assault is **4–6 units**.
Hunter HP 22 is easier; Gold HP 35 is hardest.

**With dragon gear** — one equipped hero replaces a warband:

| force | turns |
|---|---|
| 1 Dragonbreaker Lance alone (atk 8, negates armour) | **4** |
| Lance + 3 clan units | 4 |
| Lance + 5 clan units | 3 |
| **Orb + Lance** (Orb drags the dragon adjacent, +2 ATK) | **3** |

This is the intended Dragonlance dynamic — the Orb's own description reads
*"DANGEROUS alone. Pair with Dragonbreaker Lance."*

Locked by `tests/engine/test_dragon_fight.py` (13 tests), so a change to HP or
the armour pool cannot silently invalidate this table.

### 9.05 EGG PURSUIT — the carrier is stealing the dragon's young

`PURSUIT_SPEED_BONUS` grants extra steps per turn **while pursuing the egg
carrier only** — no other dragon behaviour is faster, so ordinary clan activity
is unaffected.

**Current value: `0` (reverted in Step 8).** Dragons pursue the carrier at their
base speed: guardian 1–2, hunter 2–3, against a MOV-3 seeker.

*History.* The bonus was introduced at `2` in Step 3 because base speeds could
never catch a MOV-3 seeker: in `sim_08_14_2026_21_21`, `EGG_PURSUIT_BEGINS`
fired **24 times and produced zero interceptions**, and seed 4's carrier crossed
the entire map, (64,48) → (2,68), at a constant HP 4, untouched, and won — the
False Clutch never even triggered, because its 12-hex range was never reached.

It was reverted to `0` after `sim_08_15_2026_00_06`. Once the Step-7 carrier
lock stopped carriers stalling, `+2` proved lethal rather than threatening:
**8 of 12 carriers died 1–4 turns after lifting the egg**, with both guardian
and hunter enraging (`reason=egg_carried`) on the pickup turn itself. The
counterplay meant to balance it never materialised — `hunt_dragon` was selected
**0 times in 20 games** because anti-dragon gear is not on the board at the
moment of pickup, so §9.06's escort degraded to screens-only (79 screens, 0
hunters) and **no dragon died all run**.

A bonus should only be restored once anti-dragon gear reliably reaches the
escort *before* the egg is lifted, and then at `1` rather than `2`.

### 9.055 THE SEEKER — escort first, then run *(08/2026)*

**The measured leak.** In `sim_08_17_2026_11_09`, **188 seekers were built and
only 7 ever picked up the egg**. Just 24 died — roughly 130 simply never went.
A snapshot of every seeker's final goal:

```
upgrade_units 44 | defend_enclave 38 | seek_egg 29 | idle 27 | heal 17
contest_egg_carrier 9 | garrison 5 | advance_shrines 4 | ...
```

A 300g win-path unit was being conscripted into garrison duty. §9.06's carrier
lock only protects a seeker **already** holding `seek_egg` — nothing ever put
it there.

**The lock now covers any living seeker**, not just the carrier
(`carrier_goal_is_locked()` / `seeker_goal_is_locked()`), and a seeker has a
three-state lifecycle enforced every turn by `enforce_seeker_goals()`:

| state | when | behaviour |
|---|---|---|
| `form_escort` | on spawn | musters at its enclave and calls bodyguards |
| `seek_egg` | escort ready, or patience expired | travels to the egg |
| `seek_egg` (home) | carrying | §9.06 carrier lock takes over |

**Escort size scales with live threat** (`seeker_escort_target()`):

```
base 2  +1 dragon awake  +1 dragon enraged/pursuing  +1 rival holds the egg
cap 5   (seeker + 5 = MAX_CLUSTER_SIZE 6)
```

`SEEKER_ESCORT_PATIENCE = 15` turns — a clan that can never spare bodyguards
still eventually contests the egg rather than sitting at home forever.

**Escorts count at a distance.** `seeker_escort_count()` counts a unit if it is
within `SEEKER_ESCORT_RADIUS = 6` **or** already under orders to escort *this*
seeker and still inside the muster radius. The radius was originally 3 and
proximity-only, which measured in `sim_08_17_2026_13_16` as:

```
reason=awaiting_escort_0/2   within3=0   within6=6   escorting=6
```

Six units were actively escorting from 4–6 hexes away and the seeker counted
**zero**, so 73 seekers sat out the full patience with a full escort in
attendance. An escort marching toward the seeker *is* escorting.

**One seeker at a time.** `can_build_seeker()` refuses with `seeker_exists`
while a seeker is alive **or in the production queue**, and a clan may rebuild
freely once it dies. Checking the queue as well as live units is what stops a
second being ordered while the first is still building.

**Other clusters may join the operation.** Once a seeker is on `seek_egg`,
`rally_clusters_to_seeker()` gives nearby cluster *leaders* the `defend_seeker`
goal; the existing `sync_cluster_goals()` propagates it to every member, so
whole stacks converge without new cluster machinery. Escorts pulled directly to
a seeker use `escort_seeker`.

All three goals are registered in `UNIT_ELIGIBLE_GOALS` **and** `_target_pos()`
so they track a moving seeker — the pairing `hunt_dragon` originally got wrong.
Guarded by `tests/engine/test_seeker_escort.py` (7 tests) plus the reachability
suite. Logged as `SEEKER_GOAL_RESTORED` and `CLUSTERS_JOINED_EGG_RUN`.

### 9.06 THE CARRIER — an immutable goal, and the escort that protects it

Implemented in `engine/engine_escort.py`.

**The carrier never changes its goal.** From the turn a seeker lifts the egg
until it delivers, dies or drops it, its only goal is `seek_egg` targeting its
own shrine. This is a hard invariant, not a preference:

- `carrier_goal_is_locked(unit)` is the single authoritative guard, consulted by
  every goal-writing site in `engine_cluster.py` and `engine_ai_s41.py`
  (standby, regroup, defend_enclave, garrison recall).
- `enforce_carrier_goal(state)` is an idempotent backstop that *restores* the
  goal rather than trusting each site to behave. It runs in `TURN_SEQUENCE` as
  `enforce_carrier_goal_tick`, immediately **before `unit_tick`**, so the
  invariant holds at the moment movement resolves. Emits
  `CARRIER_GOAL_RESTORED`.
  **Bugfix 08/27/2026:** `enforce_carrier_goal_tick()` was previously a
  completely empty stub (docstring only) — this call never actually ran at
  its documented position. The real call had been accidentally pasted onto
  the end of an unrelated duplicate `town_visit_tick()` definition, so it
  ran much earlier in `TURN_SEQUENCE` (before `process_ai_turn`'s movement
  pass) instead of immediately before `unit_tick`. Fixed by moving the real
  body into `enforce_carrier_goal_tick()`; `town_visit_tick()` is now
  settlement-visit resolution only, as its name says.

The backstop exists because ~20 sites write `ai_current_goal` and only 4 ever
checked `carrying_egg`; garrison/standby/regroup/defend previously stomped the
carrier's goal and stranded it for hundreds of turns.

**Escort doctrine — defend the carrier, not the enclave.** While a dragon
pursues the carrier, `egg_escort_doctrine()` fires and emits
`EGG_ESCORT_MOBILISED`:

| Response | Cap | Who | Purpose |
|---|---|---|---|
| `hunt_dragon` | 3 | units holding anti-dragon gear | engage the dragon directly (§9.0: a lone Dragonbreaker Lance kills a Guardian in 4 turns) |
| `screen_carrier` | 4 | the clan's heaviest fighters | interpose on the pursuit vector — a delaying sacrifice buying the carrier turns |

`clan_is_escorting_carrier()` additionally suppresses garrison recall, so the
clan does not pull units home to an enclave nobody is attacking.

**Three blockers fixed 08/2026 — dragon kills were structurally impossible.**
Across the project's entire recorded history, **no dragon has ever been killed**.
It was not balance; it was three independent defects:

1. **The goals had no target resolver.** `engine_escort` assigned
   `hunt_dragon` / `screen_carrier`, but `_target_pos()` in `engine_ai_s41.py`
   had **no branch for either**, so the target was written once and went stale
   the moment the dragon moved — hunters walked to where it used to be. Both now
   resolve every turn (hunters track the dragon, screens track the carrier).
2. **Hunters were picked who could not deal damage.** A dragon negates
   `ANCIENT_ARMOUR_POOL = 5` damage *per turn*, so any unit with ATK ≤ 5 deals
   literally **zero** forever. The one `hunt_dragon` assignment in
   `sim_08_15_2026_02_36` went to a **2-ATK defender**. Selection requires
   `MIN_DRAGON_SLAYER_ATK = 6` **or** anti-dragon gear; everyone else screens,
   where body-blocking still costs the dragon turns.
3. **The weapon could not be bought until the fight was over.**
   `ai_buy_dragon_gear()` gated on `on_egg_run` (Avatar or live Seeker), but the
   dragon wakes at **t169 average** — long before most clans reach the egg run.
   Gear is now also purchasable **whenever a dragon is awake**, so a Lance can
   exist before the fight rather than after it. (7 gear purchases in 20 games
   under the old gate.)

**A fourth blocker was found and fixed 08/25/2026 — the "fixed" #2 above was
itself silently dead.** `_can_hurt_a_dragon()` in `engine_escort.py` read
`getattr(unit, "atk", 0)`, but `UnitInstance` has **no `.atk` attribute at
all** — only `base_atk` on the unit *template*; the real effective value
requires `state.effective_stat(unit, "atk")`. So the ATK check always
evaluated `0 >= 6` and never passed, leaving anti-dragon **gear** as the only
way any unit could ever become a `hunt_dragon` slayer. Worse, gear-holders
were only considered if already within `ESCORT_RESPONSE_RADIUS` (25 hexes) of
the egg carrier — a Dragonbreaker Lance sitting at home while the carrier was
hunted 40+ hexes away never got summoned. Confirmed in `sim_08_25_2026_18_57`
(20 games): 43 `EGG_ESCORT_MOBILISED` events, **`hunters: 0` on every single
one**, despite `egg_spoof`/`dragonhide_mantle`/`dragonbreaker_lance` all
being bought/looted that same run — dragon deaths stayed 0/0/0 as they always
have. Fixed: `_can_hurt_a_dragon()` now takes `state` and calls
`effective_stat()`; gear-holders anywhere in the clan (no radius cap) are now
added to the `hunt_dragon` candidate pool so lair loot and castle purchases
actually translate into an assignment.

**A fifth blocker was found and fixed 08/26/2026 — even a correctly-assigned,
correctly-qualified `hunt_dragon` unit still could not deal damage.**
`engine_dragon.dragon_receive_hit()` is the only function anywhere in the
codebase that reduces `DragonInstance.hp` from a unit's attack, and it had
**zero production callers** — only `tests/engine/test_dragon.py` called it
directly. The Guardian/Hunter dragons live in `state.dragons`, not
`state.units`, so neither `auto_combat_hexes()` nor `adjacent_encounter_tick()`
(which only ever iterate `state.units`) could ever pit an attacker against
one. A unit could walk onto the dragon's own hex and nothing happened.
Confirmed in `sim_08_26_2026_01_23` (20 games): `hunt_dragon` assigned 12
times across 3 games, `dragon_gear_engage` reason firing correctly, yet
`dragons_slain_count` stayed 0/0/0 as it always has and 260 dragon **kills**
(of clan units) were logged with zero return damage.
Fixed: new `engine_headless.dragon_unit_combat_tick()` tick, added to
`TURN_SEQUENCE` immediately before `dragon_tick()` (originally before the
`__DRAGON_SPLIT__` sentinel, since removed 08/29/2026 — see §3.1) so damage
lands the same turn `dragon_tick()` checks `hp<=0` — any alive non-monster
unit at hex distance ≤1 of an active dragon now lands a hit via `dragon_receive_hit()`,
using `effective_stat(unit, "atk")` so terrain/forts/items/shrine bonuses all
apply and Ancient Armour / Dragonbreaker Lance bypass behave exactly as
`test_dragon_fight.py`'s balance table documents. Covered by
`tests/engine/test_dragon_unit_combat.py` (outcome-based: dragon HP actually
drops, sustained assault actually kills it). Both loops run it — see
`test_mode_parity.py`'s shared-tick manifest. Still needs a fresh sim run to
confirm this finally produces the project's first `DRAGON_WIN`.

⚠️ Still unimplemented: the *abilities* on all 12 specialty units, and
`rally_aura_*` is set by `engine_items.py` but never read by `combat_engine.py`.

### 9.1 ANCIENT ARMOUR — per TURN, not per hit *(bugfix 08/2026)*

```
first ANCIENT_ARMOUR_POOL (5) damage each TURN is negated  —  shared pool
```

`_dragon_apply_armour()` applied **−5 to every individual hit**, while
`monsters.json` declares `"damage_negated_per_turn": 5`. With clan units dealing
2–5 damage, **every single attack resolved to 0** against Guardian HP 30 /
Hunter HP 22. Dragon deaths were **0 in every regression ever run**, while
dragons killed 1,421 clan units. It was never a balance problem — the code and
the authoritative JSON disagreed.

Now a shared per-turn pool refilled by `reset_dragon_armour_pool()` at the top of
`dragon_tick()`: 8 units × 3 dmg = 24 − 5 = **19** net, where the old code gave
**0**. A lone attacker still bounces off.

`_dragon_apply_armour()` is the **dragon's own defence** and must only ever be
applied to damage the dragon *receives*. Four call sites were applying it to
damage the dragon *deals*; those now use `dragon_damage_to_unit()`, which
subtracts the target's `dragon_breath_absorb`.

### 9.2 DRAGON COUNTERPLAY ARSENAL *(implemented 08/2026)*

The full anti-dragon item set existed in `engine_items.ITEM_DATA` with **not one
effect implemented anywhere in the engine**, and was **unobtainable** besides:
`_T4_ITEMS` in `startup_engine.py` contained seven **tier-3** items and no
tier-4 item at all (it was a copy of `_T3_ITEMS`). Across 20 games and 102
cleared lairs, **zero dragon items were ever acquired**.

| item | tier | effect | source |
|---|---|---|---|
| Dragonbreaker Lance | 4 | `negate_dragon_armour` — ignores the pool entirely | advanced lair |
| Dragon Orb | 3 | `dragon_attraction` + 2 ATK when adjacent | lair |
| Dragonhide Mantle | 3 | absorbs 3 dragon damage/turn | lair |
| Scale of the First Dragon | 4 | +3 DEF, absorbs 4/turn | advanced lair |
| Rider's Bind | 3 | dragon cannot flee at 3 stacks | lair |
| Binding Chain | 4 | roots dragon 3 turns | advanced lair |
| Obsidian Bolt Quiver | 4 | `ignore_dragon_def` (archer) | advanced lair |
| **False Clutch** (`egg_spoof`) | 3 | **decoy — dragons chase a false hex 6 turns.** Consumable | lair |

**The Orb + Lance pairing is the intended kill combo** (the Orb's own
description reads *"DANGEROUS alone. Pair with Dragonbreaker Lance"*): the Orb
drags the dragon to you, the Lance negates its armour.

#### How the arsenal is earned *(08/2026)*

**Nothing is ever given away.** Every dragon item costs either blood (a cleared
lair) or gold (a shop). There is no Avatar hand-out.

| source | what it stocks |
|---|---|
| **T2 lairs** | `egg_spoof` ×2 weight, `dragonhide_mantle` — the first real answers |
| **T3 lairs** | `dragon_orb`, `dragonhide_mantle`, `riders_bind`, `egg_spoof` ×2 |
| **T4 lairs** | the full legendary tier incl. `dragonbreaker_lance` |
| **Town armories** | Trinsic/Minoc → Mantle · Jhelom → Rider's Bind · Skara Brae/Moonglow → False Clutch · Buccaneer's Den → Dragon Orb |
| **Castle shop** | `dragonhide_mantle` 360g · `egg_spoof` 420g · **`dragonbreaker_lance` 800g**, gated on already owning Mantle/Bind/Orb |

**Lairs now drop multiple items** — `StartupEngine.LAIR_ITEM_COUNT`:
T1/T2 = 1, **T3 = 2, T4 = 3**. One hard clear can genuinely arm a clan (Orb
*and* Lance) instead of trickling a single trinket. Extras live in
`MonsterEnclave.loot_extra_item_ids`, awarded alongside the primary on clear.

**The AI is incentivised to go and get them.** `_lair_dragon_loot_bonus()`
(`engine_ai_s41.py`) adds up to **+0.45** to `clear_lair` desire for a lair
holding counterplay loot, weighted per item (`dragonbreaker_lance` 0.30,
`egg_spoof` 0.26, `dragon_orb` 0.20 …) and multiplied by win-path urgency —
**×1.6 while actually carrying the egg**, ×1.3 once a Seeker exists.

**Lair TARGET selection also values loot** *(08/2026)*. Previously
`clear_lair` picked the **nearest** uncleared lair unconditionally, so the goal
score raised a clan's appetite for lair-clearing but geography decided which
clan actually earned the counterplay. Selection is now
`score = -distance + loot_value × 25`, so a clan will cross the map for a
Dragonbreaker Lance but still take the near lair when the prizes are equal.

Measured need (`sim_08_14_2026_18_47`): 15 False Clutches were earned, yet of 9
egg pickups only **3** carriers' clans held one — seed 16's clutches went to
ranger and shaman while druid carried the egg.

**Buying is the second earned route.** `engine_castle.ai_buy_dragon_gear()`
fires when a unit visits a castle and the clan is genuinely on the egg run
(Avatar or a live Seeker), buying in priority order **False Clutch → Mantle →
Lance**. It equips onto a unit with a free slot (the Clutch preferring the
seeker), because `pickup_item()` routes weapon *and* utility gear to the single
`item_weapon` slot and would otherwise silently discard each previous purchase.

> **Three latent bugs meant the castle armoury had never been buyable by
> anyone**, by any clan, in any game:
> - `_clan_owns_prereq()` read `unit.item` — an attribute `UnitInstance` does
>   not have — raising `AttributeError` on every *gated* purchase.
> - `castle_shop()` appended to `state.event_log`, which does not exist on
>   `GameState`, raising **after** the gold was debited and the sale recorded.
> - `castle_shop()` never equipped the item on a unit at all.
>
> All three are fixed and guarded by `tests/engine/test_dragon_gear_access.py`.

### 9.3 EGG SPOOF — breaking the pursuit

Both dragons `DRAGON_ENRAGE` (`reason: egg_carried`) the instant the egg is
lifted and begin `EGG_PURSUIT_BEGINS`. They killed **42 of 63 seekers (67%)**,
and 11 pickups produced **zero** deliveries.

`engine_dragon.activate_egg_spoof()` plants a decoy that `_egg_position()`
returns instead of the real location — every pursuit routine reads that one
function, so the whole hunt is misdirected. Available two ways:

* **False Clutch** — T3 consumable lair item. `try_use_egg_spoof()` spends it
  automatically when a dragon closes within `SPOOF_TRIGGER_RANGE` (12) of the
  carrier, planting the decoy *away* from the carrier's route home.
* **Phantom Clutch** — **T4 spell**, `effect_type: dragon_spoof`, available to
  all casting clans, 16 MP / 3 exhaustion.

Logged as `EGG_SPOOF_ACTIVATED` / `EGG_SPOOF_EXPIRED`.

Guarded by `tests/engine/test_dragon_counterplay.py` (16 tests, each verified to
fail when its fix is reverted).

**Dragon states:** dormant → stirring(3-7t rng) → awake → focused → angry → enraged → retreating(1t) → slain

  AWAKE   : standard vortex orbit, base ranges (tail 1, breath len 3, lunge 4 steps)
  FOCUSED : HP ≤ 80% — wider orbit (+1 radius), +1 all ranges, targets Seekers/carrier on lunge
  ANGRY   : HP ≤ 50% — intercepts unit cluster, +2 all ranges, CD 2t (tail/lunge 1t)
  ENRAGED : HP ≤ 12 (Red: ≤66%) — sentinel/assault, +3 all ranges, all CDs=1

**Dragon combat stats (awake):** ATK 9, DEF 6 (ancient armour absorbs first 5 dmg/hit).

### Dragon Types ✅

| Type | HP bonus | Wake mult | Special |
|------|----------|-----------|---------|
| Red | 0 | ×1.5 | Never retreats. Enrages at 66% HP |
| Green | 0 | ×0.7 | Forest prox −30% wake. Retreats at 40%, heals 3/t, returns at 80% |
| Blue | 0 | ×1.0 | Targets Seekers in lunge. Lightning arc on retreat |
| Gold | +5 (G=35, H=27) | ×0.6 | Dragon Orb 50% fail. Noble retreat (egg-safe only) |
| Silver | 0 | ×1.0 | Prox radius −3. Weapons −1 dmg vs Silver. Ice zone r=6 (1 dmg/t) |

### Dragon Wake Schedule (#213) ✅ Checkpoint-only. NO wake before t50.

| Turn | Probability | Notes |
|------|-------------|-------|
| t50 | 2% | × dragon_type random_wake_mult |
| t100 | 4% | × random_wake_mult |
| t150 | 8% | × random_wake_mult |
| t200 | 15% | × random_wake_mult |
| t250 | 25% | × random_wake_mult |
| t300 | 35% | × random_wake_mult |
| t350 | 50% | × random_wake_mult |
| t400 | FORCED | Hard ceiling — guaranteed wake (backstop, T92b) |

Per-dragon tracking: `dragon.wake_checkpoints_fired: set[int]`.
Stirring duration: `rng.randint(3, 7)` turns — dramatic, unpredictable. Logged as `DRAGON_STIRRING_PULSE` each turn.
`_force_dragon_on_avatar()` in simulate.py fires when clan achieves Avatar — overrides checkpoint schedule.

### Dragon Actions ✅

- **Ancient Armour:** Negates first 5 incoming dmg per turn (threshold, resets each turn)
- **Breath cone:** len 3 (AWAKE) / 4 (FOCUSED) / 5 (ANGRY) / 6 (ENRAGED). CD 3t/2t/2t/1t. No hard hex cap — set deduplication. **Preview 1t ahead** (AWAKE/FOCUSED only; ANGRY/ENRAGED strike without warning).
  - Red: 5 fire + burning hex (1 dmg/t, 3t). Green: 2 + entangle rooted 2t. Blue: 4 lightning + chain 2 dmg adj metal-armour. Gold: 4 bypasses armour. Silver: 5 + slowed 2t (−2 MOV).
- **Tail sweep:** 3 dmg, range 1 (AWAKE) / 2 (FOCUSED/ANGRY) / 3 (ENRAGED). CD 2t → 1t (ANGRY/ENRAGED).
- **Lunge:** Move up to 4/5/6 steps (AWAKE/FOCUSED/ANGRY+ENRAGED) + 7 dmg. CD 2t → 1t (ANGRY/ENRAGED). FOCUSED/ANGRY/ENRAGED all types hunt egg carrier > Seekers first. Blue hunts Seekers even in AWAKE.
- **Breath is PHYSICAL, not a spell.** Not blocked by Anti-Magic Field, Ward, or sacred ground. Meditating units NOT protected.

### Dragon Escalation ✅
State transitions triggered by `_enrage_check_one()` each turn:

| State | HP Threshold | Key changes |
|-------|--------------|-------------|
| AWAKE | — | Standard vortex, base ranges |
| FOCUSED | ≤ 80% HP | Wider orbit (+1 radius), +1 ranges, lunge targets Seekers/carrier |
| ANGRY | ≤ 50% HP | Intercepts unit cluster, +2 ranges, tail/lunge CD drops to 1t |
| ENRAGED | ≤ 12 HP (Red: ≤66%) | Sentinel (Guardian) / enclave assault (Hunter), +3 ranges, all CDs=1 |

Log events: `DRAGON_FOCUSED`, `DRAGON_ANGRY`, `DRAGON_ENRAGED` (each with `hp`/`hp_max`).

### Egg Hatch (#118) ✅

| Type | Hatch turns | Baby HP |
|------|-------------|---------|
| Red | 6 | 20 |
| Blue | 6 | 20 |
| Silver | 7 | 20 |
| Green | 8 | 24 |
| Gold | 10 | 30 |

Seeker picking up egg resets countdown.

**Baby dragon growth (08/2026, see `assets/md/dragons.md` §5.3 for full
detail):** a hatched baby dragon advances through three discrete named
stages — HATCHLING (age 0) → ADOLESCENT (age 20) → ADULT (age 50, hard
stat plateau, no further growth). Guardian and Hunter are always adult/
ancient and never go through this — they only escalate combat state (see
"Dragon Escalation" below), which is a completely different mechanic.
Replaces the old unbounded "+2 HP/+1 ATK/+1 MOV every 10 turns forever"
behaviour, which had no stat ceiling.

### Dragon Orb (#119) ✅
Compels nearest non-slain dragon toward holder for 2 turns. Holder rooted 2 turns.
Gold: 50% fail. Holder death: 50% orb shatters.

### Dragon Hoard ✅
Revealed after BOTH slain. primary_gold 1500–3000, secondary_gold 500–1000.
3 T3 monsters spawned per lair. 150–300g/visit, 20% item draw, 8–12 max collections.
Dragon kill reward: 500g (Guardian), 300g (Hunter) to killing clan.

### Hidden Dragon Type (#153) ❓ Partially implemented (token says done T62)
`state.dragon_type_revealed[clan_id]: bool`. UI shows "???" until revealed.
Reveal: VIS on live dragon / Dragonlore Tablet / intel ≥0.70 confidence.
Victory screen always shows actual type.

### Dragon Genetics (#201) ⚙️ NOT YET CODED
Gold/Silver genetically dominant (one or other). Otherwise 50:50 random.

### Dragon Proximity Wake (Sprint 28) ✅ engine_dragon.py
Every turn, for each dormant dragon: any unit within 5 hexes of its lair rolls a 7% wake chance × unit stealth multiplier. No wake before t50. Independent of checkpoint schedule (both run). Logged as `dragon_wake_trigger = "proximity"`.

### Dragon Stealth Multipliers ✅ (unit proximity reduces wake probability)
Scout: 0.6 | Seeker: 0.5 | Ranger: 0.35 | Rogue: 0.25 | Ranger+Wolf companion: 0.45 | +Eagle: 0.30

### Hidden 2nd Egg (Sprint 28) ✅ simulate.py
Independent baby dragon spawned at late-game checkpoints: t300=5%, t350=10%, t400=25%, t450=forced.
Shares 3-concurrent baby dragon cap. Logged as `second_egg_hatches` in result dict.

---

## 10. COMBAT

**Core formula:** `damage = max(1, (ATK − DEF) + luck_roll)`
luck_roll: [−1, 0, +1]. Druid shrine bonus: [0, +1, +2].

**Terrain DEF bonuses (defender's hex):** Plains=0, Grasslands=+1, Forest=+1, Hills=+1.
Hills downhill: ranged attacker +1 ATK.

**Fort bonus:** +1 ATK/+1 DEF radius 1 (2 with Fortification). +2/+2 on fort hex itself.
Multiple forts don't stack (highest wins).

**Simultaneous exchange:** Both compute damage, both apply simultaneously.
Dead units still deal their attack (resolved together).

**HP system:**
- `hp_combat` (green, healable) + `hp_exhaust` (purple, NOT healable except Velmoor 25g/HP)
- Death: `hp_combat + hp_exhaust ≤ 0`. Exhaust floor: cannot die from exhaust alone (min 1 total HP).
- Regen: +1/turn on visible hex, +2 with adjacent Cleric, +2/turn at enclave hex.
- Velmoor healer: 10g/hp_combat, 25g/hp_exhaust. Max 3 uses/clan/game.

**Ranged:** Ranger Archer + Elf Longbowman RNG=4 (best in game). Starbow RNG=4. Most ranged units RNG=2–3.
Mountain blocks LoS. Forest does NOT. Cannot fire into/out of sacred ground.

**Kill reward:** 50% of the dead unit's production gold cost (battlefield salvage, added to killer treasury).
Scout 25g · Ranged 30g · Common unit 60g · Advanced 75g · Specialty 75–100g · Seeker 150g. Fallback 10g.
*(50% of the unit's gold cost — costs are now read from `unit_types.json`.)*

**Special combat:**
- Assassin Ambush: instant kill from stealth on non-specialty units
- Iron Fist Stun: target skips next turn. Cannot be reanimated after.
- Dark Resonance: +1 ATK per 3 deaths on map (design says 3; sim threshold may differ — verify)
- Monster Weakness: +3 dmg if weakness known via pub intel
- Troll regen: +2 HP/turn (not if hit by fire last turn)
- Skeleton Undying: 30% chance to rise at 2 HP on death (not from Soulreaver or holy)

**Enclave walls:** Base HP 5. Walls I → 10. Walls II → 15. Engineering tech +2. Breached at 0 → clan eliminated.
Warlord: 8 HP damage per turn (instant with Master Engineering). Others: 3 turns on hex to breach. *(Unimplemented: no engine code reads `breach_requires`.)*

**Sacred ground:** No combat within radius 2 of any shrine.

---

## 11. MAGIC SYSTEM *(Sprint 30 — 24 spells; specialty-unit tier ladder; no clan immunities; Mend +3HP; Force Pulse; Fireball elf_plus; Entangle 2-hex; Lightning Storm chains; Thornstorm/Mass Charm/Blinding Light new)*

**T4/T5 spells cause exhaustion HP to caster.** Exhaustion unrecoverable except at Velmoor.
**No clan is immune to any spell.** Fighter/Dwarf have no mana and no magic resistance — spells land normally.

### 11.0 TARGETING RULE — `range: 999` MEANS "ANY **VISIBLE** HEX" *(bugfix 08/2026)*

**999 is unlimited DISTANCE, not unlimited KNOWLEDGE.** The AI may only target a
hex its clan can currently see (`_clan_can_see_hex()` in `engine_headless.py`).

`_spell_target()` gated range with `if rng > 0 and rng < 999`, so the two
long-range spells (**Meteor**, **Time Stop**) skipped the filter entirely and
every enemy on the 100×100 map became a candidate — with no visibility test
anywhere. In seed 1 (pangea) a mage at (15,35) opened **turn 1** by dropping
Meteor on fighter's capital at (46,88) — ~53 hexes away, through wholly
unexplored fog — killing the chieftain and scout outright and **eliminating the
clan on turn 1**. This is a large part of why regressions averaged **3.86 of 8
clans eliminated per game**.

The same visibility gate applies to the debuff branch.

**Every spell death must be attributable.** Spell kills previously set
`is_alive = False` inline with **no log entry at all**, so two units simply
vanished with nothing in the combat log or kill attribution — which is why the
wipe above read as a spontaneous elimination. `_log_spell_kill()` now emits a
`SPELL_KILL` record at all three death sites in `engine_magic.py`.

**A caster is never caught in its own AoE.** Friendly units still are — AoE
friendly fire is deliberate — but a mage nuking itself was a bug.

### Specialty-Unit Spell Tier Ladder

Lower-tier magic clans access one tier higher by building their specialty unit. `can_cast()` checks both `clan_id` AND `unit.template_id`.

| Clan | Magic Tier | Base access | Specialty Unit | Specialty spell access |
|------|-----------|-------------|---------------|----------------------|
| Fighter/Dwarf | 0 | — | Siege Eng/Runesmith | — (0 MP) |
| Ranger/Rogue | 1 | T1 | Trapper/Assassin | **T2 spells** (Haste/Ward/Silence/Force Pulse) |
| Monk/Bard | 2 | T1+T2 | Iron Fist/Spymaster | **T3 spells** (Heal+Blink) + exclusive (Mass Charm) |
| Cleric/Druid | 3 | T1+T2+T3 | High Priest/Thornweaver | exclusive spells (Thornstorm) |
| Elf | 3 | T1–T3+Fireball | Starbow | exclusive T4 (Blinding Light) |
| Shaman | 4 | T1–T3+Fireball+**T4** | Stormcaller | Lightning Storm already accessible to base Shaman |
| Necromancer | 4 | T1–T4 | Death Knight | T4 already accessible |
| Mage | 5 | T1–T5 | Grand Arcanist | T5 already accessible |

### Full Spell Reference (24 spells)

| Spell | T | Who | MP | Exh | Rng | Area | Effect |
|-------|---|-----|----|-----|-----|------|--------|
| Reveal | 1 | all_magic | 2 | 0 | — | 4 | Fog clear 4-hex radius |
| Mend | 1 | all_magic | 2 | 0 | 1 | 1 | +3 combat HP adjacent friendly |
| Slow | 1 | all_magic | 2 | 0 | 3 | 1 | Enemy MOV ÷2 for 1 turn. No immunity. |
| Shroud | 1 | all_magic | 3 | 0 | — | 1 | Caster invisible >2 hex, 2 turns |
| Haste | 2 | monk_plus + **Trapper/Assassin** | 4 | 0 | 1 | 1 | Friendly +2 MOV, 2 turns |
| Silence | 2 | monk_plus + **Trapper/Assassin** | 4 | 0 | 4 | 1 | Enemy no spells, 3 turns. No immunity. |
| Ward | 2 | monk_plus + **Trapper/Assassin** | 5 | 0 | — | 1 | Negate next incoming spell |
| Force Pulse | 2 | monk_plus + **Trapper/Assassin** | 4 | 0 | 2 | 1 | 3 physical dmg, no immunity (kinetic) |
| Charm *(Bard only)* | 2 | bard_only | 5 | 0 | 3 | 1 | Enemy moves chosen dir, no attack |
| Heal | 3 | cleric_plus + **Iron Fist/Spymaster** | 6 | 0 | 3 | 1 | +5 combat HP friendly |
| Blink | 3 | cleric_plus + **Iron Fist/Spymaster** | 8 | 0 | 6 | 1 | Teleport self up to 6 hexes |
| Fireball | 3 | elf_plus | 7 | 0 | 5 | 2 | 4 fire dmg AoE 2-hex. Elf/Shaman/Necro/Mage only. |
| **Thornstorm** *(Thornweaver only)* | 3 | thornweaver | 8 | 0 | 4 | 2 | **4 nature dmg AoE 2-hex + −MOV 2t survivors. Combos with Entangle.** |
| Entangle *(Druid only)* | 3 | druid_only | 6 | 0 | 4 | 2 | All in 2-hex radius can't move 2t |
| **Mass Charm** *(Spymaster only)* | 3 | spymaster | 8 | 0 | 4 | 2 | **All enemies 2-hex charmed 1t — no attack.** |
| **Blinding Light** *(Starbow only)* | 4 | starbow | 12 | −1 | 6 | 3 | **All enemies 3-hex cursed (−2 all stats) 2t.** |
| Lightning Storm | 4 | necro_plus | 12 | −2 | 6 | 3 | 6 dmg AoE 3-hex. On kill: +2 chain adj. |
| Reanimate *(Necro only)* | 4 | necro_only | 10 | −1 | 1 | 1 | Revive dead unit as ally, 5 turns |
| Curse | 4 | necro_plus | 10 | −1 | 5 | 1 | Target −2 all stats, 5 turns. No immunity. |
| Mass Haste | 4 | necro_plus | 14 | −2 | — | 3 | All friendlies 3-hex +2 MOV, 2 turns |
| Meteor *(Mage only)* | 5 | mage_only | 20 | −4 | Any | 4 | 8 dmg AoE 4-hex, any visible hex |
| Arcane Gate *(Mage only)* | 5 | mage_only | 18 | −4 | Any | 1 | Teleport any friendly to visible hex |
| Anti-Magic *(Mage only)* | 5 | mage_only | 15 | −3 | — | 4 | No spells in 4-hex, 3 turns |
| Time Stop *(Mage only)* | 5 | mage_only | 25 | −5 | — | All | All enemies skip next turn |

### Spell Availability Groups (engine_magic.py SPELL_AVAILABILITY)
- **all_magic** (T1): all 10 magic clans
- **monk_plus** (T2): Monk/Bard/Cleric/Druid/Elf/Shaman/Necro/Mage + **Trapper + Assassin** (specialty unit template IDs)
- **bard_only**: Bard
- **cleric_plus** (T3 heal/utility): Cleric/Druid/Elf/Shaman/Necro/Mage + **Iron Fist + Spymaster**
- **elf_plus** (T3 offensive): Elf/Shaman/Necro/Mage — Fireball
- **druid_only**: Druid — Entangle
- **thornweaver_only**: Thornweaver template — Thornstorm
- **spymaster_only**: Spymaster template — Mass Charm
- **starbow_only**: Starbow template — Blinding Light
- **necro_plus** (T4): Necro/**Shaman**/Mage — Shaman gets Lightning Storm, Curse, Mass Haste (weather/storm identity, 20 MP)
- **mage_only** (T5): Mage

`can_cast()` checks `unit.clan_id OR unit.template_id` against the eligible list.

**Cleric identity:** Healer-fighter. Heal + Blink (T3) but NOT Fireball.
**Dwarf/Fighter:** 0 MP, cannot cast, not immune to any spell.
**Shaman AoE +1 dmg.** Storm Spire: +2 dmg, +1 radius.
**Dragon breath is physical — not blocked by Anti-Magic Field, Ward, or sacred ground.**

**MP regen:** Base +1/turn. +1 Arcane Engineering tech. +1 per active Lumber Post. Mana Staff +1/turn.
**Exhaust recovery:** +1 exhaust HP/turn not casting T4/T5. Cannot die from exhaust alone.

---

## 12. TECHNOLOGY TREE *(rewritten 08/24/2026 — 4 tiers, matches `engine_tech.py::TECH_DATA`)*

Research slot is SEPARATE from production queue. `assets/data/technologies.json`
is stale/orphaned (still lists Sprint-30-removed trap techs and a fictional
`Logistics` tech that was never implemented) and is **not loaded by any engine
code** — `engine_tech.py::TECH_DATA` is authoritative. *(See `technology.md` for
full detail on every tech, including passives.)*

### Tier 1 (no prerequisites)
| Tech | Cost | Turns | Key unlocks |
|------|------|-------|-------------|
| Scouting | 60g | 5t | Watch Post. Scouts +1 VIS (existing + future) |
| Engineering | 80g | 6t | Fort. Enclave walls +2 HP |
| Military Doctrine | 70g | 5t | New units +1 HP base |
| Scholarship | 60g | 5t | Diplomat access. Contemplation Hall |

### Tier 2 (any 2 T1)
| Tech | Cost | Turns | Requires | Key effect |
|------|------|-------|----------|------------|
| Fortification | 120g | 9t | Engineering | Fort radius 2, fort hex +2/+2 ATK/DEF |
| Chieftain's Code | 100g | 8t | Military Doctrine | Alliance system. Chieftain +1 ATK/+1 MOV |
| Arcane Engineering | 140g | 10t | Engineering + Scholarship | Magic units +1 MP regen/turn |
| Sailing | 120g | 8t | none | Embark enabled, port +8g/turn, unlocks Port/Galley/Warship |

### Tier 3 (any 2 T2)
| Tech | Cost | Turns | Requires | Key effect |
|------|------|-------|----------|------------|
| Grand Strategy | 180g | 16t | Chieftain's Code + Fortification | Choose +1 global stat (permanent) |
| Master Engineering | 160g | 14t | Fortification | Fort +4 HP, built 1 turn faster |
| Prophetic Sight | 160g | 13t | Scholarship + Arcane Engineering | Meditation radius 2, see rival shrine progress |
| Naval Supremacy | 150g | 12t | Sailing | Warship +1 ATK, naval units +1 MOV, port +3g/turn, amphibious landing, unlocks Privateer |

### Tier 4 (any 2 T3; also gates Wonder research)
| Tech | Cost | Turns | Requires | Key effect |
|------|------|-------|----------|------------|
| Total War | 220g | 22t | Grand Strategy + Master Engineering | All units +1 ATK; stationary units may attack twice |
| Eternal Alliance | 200g | 20t | Chieftain's Code + Grand Strategy | Alliance duration ×2, allied units may co-occupy hexes |
| Enlightenment | 250g | 25t | Prophetic Sight + Arcane Engineering | All units +2 INT_STAT, meditation fully restores MP |
| Arcane Mastery | 230g | 22t | Arcane Engineering + Prophetic Sight | Magic units +1 more MP regen (stacks), T4/T5 spells −2 MP |

**Wonder `[UNIMPLEMENTED]`:** Gate exists (`can_research_wonder`, requires any 3
T3 techs) but no wonder-build/apply code exists anywhere in `engine/`. See §5
for the design-locked Wonder table (flavour text only until implemented).

**Removed (Sprint 30):** Advanced Trapping (+ Tripwire, Arcane Trap, Mega-Trap,
Rune Ward), Diplomat tech unlock (Scouts/Chieftains initiate diplomacy
directly now). **A `Logistics` tech appeared in older doc/data drafts but does
not exist in code and was never implemented — do not reference it.**

---

## 13. STRUCTURES & BUILDINGS *(rewritten 08/24/2026 — matches `buildings.json`, 5-tier chain)*

`assets/md/buildings.md` is the authoritative table (rewritten 08/24/2026 from
`buildings.json` directly). Summary below; see that file for full effect text
and the AI-construction two-code-path caveat.

### Enclave Buildings (production queue, 3 slots; 4 after Grand Citadel)

| Tier | Building | Cost | Turns | Requires | Effect |
|------|----------|------|-------|----------|--------|
| 1 | Barracks | 80g | 6t | — | Unlocks scout/archer/common-unit production |
| 1 | Treasury | 100g | 6t | — | +8g/turn; gold cap +200 |
| 1 | Library | 90g | 6t | — | Tech research −2 turns; auto-decode field intel |
| 2 | Armoury | 120g | 10t | Barracks | New units +1 ATK; unlocks Tier-3 military line |
| 2 | Vault | 150g | 10t | Treasury | +15g/turn (replaces Treasury); gold cap +400 |
| 2 | Scriptorium | 120g | 10t | Library | Rival shrine progress visible; pub intel auto-decoded |
| 3 | Meditation Hall | 150g | 14t | any_tier2 | Meditation −1 turn; sacred vision +1 hex |
| 3 | Mana Well | 140g | 12t | Scriptorium | +1 MP regen/turn (magic-capable units) |
| 3 | War College | 160g | 14t | Armoury | New units start w/ 1 XP; Chieftain +1 ATK/+1 MOV |
| 3 | Reinforced Walls | 130g | 12t | any_tier2 | Wall HP 24, self-repair +1/turn, breach needs Warlord |
| 4 | Grand Citadel | 200g | 18t | War College | +1 DEF all units; queue 3→4 slots; unlocks Tier-5 |
| 4 | Vault of Ages | 220g | 18t | Vault | +25g/turn (replaces Vault); gold cap +500 |
| 4 | Sanctuary | 190g | 16t | Meditation Hall | +1 combat HP/turn within 2 hexes of enclave |
| 5 | Clan building (12, one per clan) | 150–200g | 14–16t | Grand Citadel | Specialty unit unlock + passive |
| — | Sanctum (Avatar-gated) | 150g | 8t | requires_avatar | +1 DEF all units; unlocks Seeker (max 1) |

### Map Structures (placed by any unit, not the production queue)

| Structure | Cost | Turns | Requires tech | HP | Effect |
|-----------|------|-------|---------|----|----|
| Watch Post | 40g | 2t | Scouting | 4 | +2 VIS permanent. Unlimited. |
| Fort | 80g | 3t | Engineering | 8 | +1/+1 radius 1 (2 with Fortification) |
| Port | 80g | 3t | Sailing | 3 | Embark/disembark. Coastal hexes only. |

**Removed (Sprint 30):** Trap, Tripwire, Rune Ward, Farms, Mines, Lumber Posts (with worker units).
**Trapping via specialty units:** Dwarf Runesmith Ward Rune (3 uses) · Ranger Trapper Snare (4 uses).

**⚠️ `Watchtower`, `Counting House`, `Barracks II`, `Walls I`/`Walls II` do NOT
exist as buildings in `buildings.json`.** An older stale AI code path
(`_ai_construct_building()`, dead/rarely-reached) still references some of
these invented ids — tracked as an OUTSTANDING defect in `activeContext.md`,
not yet fixed. The **live** AI construction path
(`force_fill_production_queue()`) reads the real 26-building catalogue
correctly.

---

## 14. ECONOMY *(rewritten 08/24/2026 — matches `game_state.py`/`buildings.json`)*

**Gold cap:** 1000g default (`ClanInstance.gold_cap`), +200 with Treasury,
+400 with Vault (replaces Treasury bonus), +500 with Vault of Ages (replaces
Vault bonus) — up to 1900g fully built. **Production cap:** 20 points, 3
production-queue slots (4 after Grand Citadel).
Production spend: 3 points = −1 build turn (min 1 turn always).

### Gold income per turn
- **Visible tiles:** +0.1g/tile (max 500 tiles = 50g/turn) — dominant income source all game
- Treasury: +8g/turn. Vault: +15g/turn (replaces Treasury). Vault of Ages: +25g/turn (replaces Vault).
- Village garrison: +3g/turn per garrisoned village
- Monster lair loot: 100–300g (one-time, on clear)
- Enemy unit kill: 50% of that unit's production cost (battlefield salvage)
- Dragon kill: 500g (Guardian), 300g (Hunter)

### Production income per turn
- Enclave base: +2/turn always

### All costs
| Item | Cost | Turns |
|------|------|-------|
| Scout | 50g | 2t |
| Archer / Defender (universal) | 60g | 3t |
| Common unit | 120g | 4t |
| Advanced unit | 150g | 5t |
| Specialty unit | 150–225g | 5–8t |
| Chieftain rebuild | 250g | 6t |
| Seeker | 300g | 7t |
| T1 tech | 60–80g | 5–6t |
| T2 tech | 100–140g | 8–10t |
| T3 tech | 150–180g | 12–16t |
| T4 tech | 200–250g | 20–25t |
| Wonder `[UNIMPLEMENTED]` | 300g | 10t |
| Watch Post | 40g | 2t |
| Fort | 80g | 3t |
| Port | 80g | 3t |
| Galley | 80g | 3t |
| Privateer | 100g | 4t |
| Warship | 150g | 5t |

*(See §5/units.md for the full common/advanced/specialty per-clan cost table
— specialty costs vary 150–225g by clan, not a flat number.)*

---

## 15. UNITS — FULL STATS *(Sprint 30 — see units.md for full roster)*

### 15.0 UNIT TAXONOMY — three kinds, one rule *(08/2026)*

`assets/data/unit_types.json` has three families, and the boundary between them
is load-bearing:

| family | JSON section | `unit_type` | `clan_id` (instance) |
|---|---|---|---|
| clan / universal / specialty | `clan_units`, `unit_types`, `ranged_units`, `defender_units`, `specialty_units` | `"clan"`, `"scout"`, `"seeker"`, … | owning clan |
| **naval hulls** | **`naval_units`** | `"naval"` | **owning clan** |
| monsters | `monsters` | `"monster"` | `"monster"` |

**Naval hulls are CLAN UNITS.** Galley / warship / privateer used to be defined
*inside* the `"monsters"` section — a pure file accident, but one that made the
whole codebase read as though a galley were a monster. They now have their own
`naval_units` section. They are built by clans, owned by clans, and require a
**Port** (`requires_structure: "port"`, enforced by `queue_naval_unit()` →
`no_port` / `no_launch_hex`). `startup_engine` now **raises** if the section or
any hull is missing instead of silently skipping.

The hull **template** keeps `clan_id=None` deliberately: templates are a global
registry and `queue_naval_unit()` looks up the bare key `"galley"`. One blueprint
is shared by every clan; ownership is set on the spawned instance.

### `unit_type` IS THE MONSTER GATE — never overwrite it

**~47 code sites gate on `unit_type == "monster"` or `clan_id == "monster"`** —
patrol logic, exclusion from clan targeting, lair-clear detection, structure
ticks, sentiment. A monster whose `unit_type` is changed to its creature name
silently drops out of *all* of them: it stops patrolling, is no longer excluded
from clan logic, and **its lair can never be marked cleared**.

Two places were doing exactly that (fixed 08/2026): ocean lair bosses/guards were
assigned `unit_type = "kraken"` / `"reef_shark"`, and island lair bosses
`unit_type = "wyvern"` / `"harpy"`.

**Creature names live in the separate `species` field**
(`species`, `species_name`, `species_trait` on `UnitInstance`).

### 15.0.1 MONSTER SPECIES *(08/2026)*

Rank-and-file lair guards are named by **lair theme**, so a lair's guards, its
interior tile set and its boss all agree. Previously every guard in the game was a
generic `monster_t1/t2/t3` called "Enclave Guard/Warrior/Boss".

| theme | t1 | t2 | t3 | (boss ladder — `lair_bosses.json`) |
|---|---|---|---|---|
| cave | Goblin | Goblin Archer | Cave Troll | Cave Bear → Stone Golem → Ancient Golem |
| crypt | Skeleton | Skeleton Archer | Wight | Skeleton Champion → Lich Acolyte → Lich Lord |
| ruined | Orc | Orc Archer | Orc Berserker | Bandit Lord → Wraith Captain → Death Knight |
| swamp | Bog Lurker | Troll Whelp | Swamp Serpent | Swamp Hag → Bog Troll → Plague Hydra |
| fungal | Spore Thrall | Myconid | Fungal Brute | Spore Shambler → Myconid Elder → Fungal Horror |
| ocean | Reef Shark | Electric Eel | Giant Crab | Giant Octopus → Sea Serpent → Kraken |

Theme is derived from the terrain the lair sits on (`_TERRAIN_THEME` in
`startup_engine`), mirroring `engine_interior_gen._pick_theme()`.

**Species are flavour, not balance.** Each reuses its tier's stat budget from
`monster_t1/t2/t3`; traits are ±1 nudges (`skirmisher`/`swarm` +1 MOV −1 HP,
`brittle` −1 HP, `armoured` +1 DEF −1 MOV) or combat-time behaviours read from
`species_trait` (`regenerate`, `life_drain`, `venom`, `frenzy`, `spore_burst`,
`shock`, `ambusher`, `ranged`). Guarded by
`tests/engine/test_unit_taxonomy.py`.

### Universal Units (all clans)

| Unit | ATK | DEF | MOV | HP | VIS | MP | Cost | Special |
|------|-----|-----|-----|----|----|----|----|---------|
| **Chieftain** | 6 | 4 | 5 | 8 | 3 | clan tier | Free/250g rebuild | Rally Aura +1ATK/DEF r=2. Command Push 1/turn. Ignores ZoC. |
| **Scout** | 1 | 1 | 6 | 2 | 4 | 2 | 50g/2t | No ZoC. Dragon stealth ×0.6 |
| **Seeker** | 2 | 3 | 4 | 6 | 6 | clan tier | 300g/7t | Can carry egg. Cannot attack. Max 1. Dragon stealth ×0.5 |

**Chieftain with Chieftain's Code tech:** +1 ATK (base 6→7), +1 MOV (base 5→6).

**Removed (Sprint 30):** Farmer, Miner, Forester (worker units), Diplomat.
Diplomacy now: Scout (adjacent to rival unit/enclave) or Chieftain (any range).

For clan main units, clan-specific ranged units, and specialty units — see Section 5 and units.md.

### Unit Instance Fields ✅
`xp`, `level` (1–3), `skills_chosen` | `carried_gold` (looted on kill #172) |
`companion_type` "wolf|eagle|bear|hound" (Ranger only, #191) |
`at_sea`, `is_naval` (sailing) |
`is_meditating`, `meditation_turns_remaining`, `meditation_shrine_id`, `is_waking` |
`meditation_cooldown_remaining` (20t after shrine meditated) |
Spell fields: `spell_damage_bonus`, `spell_cost_reduction`, `mp_regen_item_bonus`,
`no_t4_exhaustion`, `passive_shroud`, `ward_active`, `ward_charges`

### Level-Up System (#173) ✅
3 XP → Level 2. 8 XP → Level 3. XP: +1 on kill, +1 on shrine meditation.
Level 2/3: choose skill from `_SKILL_PRIORITY` (atk/def/mov/hp/vis/spell_power etc).
Applied as bonuses: `unit.atk_bonus`, `unit.def_bonus`, etc.

---

## 16. ITEMS & EQUIPMENT  ✅ engine_town.py · engine_castle.py · town_items.json · castle_items.json

### Item Tier Framework  (T103 LOCKED)

| Tier | Source | Bonus | Price | Gate |
|------|--------|-------|-------|------|
| **+1** | Town shops | +1 stat | 30–60g | None |
| **+2** | Castle armoury | +2 stat | 110–170g | Own matching +1 in clan |
| **+3+** | Lair bosses / map drops | +3+ | Not purchasable | Kill or find |

### Town +1 Items  (seed 3–4 per town, shared stock)

| Item | Stat | Price | Gate for |
|------|------|-------|----------|
| short_sword | +1 ATK | 55g | knights_blade |
| buckler | +1 DEF | 45g | tower_shield |
| swift_boots | +1 MOV | 60g | windrunner_boots |
| lantern | +1 VIS | 30g | enhanced_lantern |
| travellers_cloak | +1 DEF | 40g | tower_shield (alt) |
| iron_cap | +1 HP_max | 50g | plate_helm |

### Castle +2 Items  (full pool per castle, prerequisite gated)

| Item | Stat | Price | Prerequisite |
|------|------|-------|--------------|
| knights_blade | +2 ATK | 150g | short_sword or keen_blade |
| tower_shield | +2 DEF | 140g | buckler, iron_shield, or travellers_cloak |
| windrunner_boots | +2 MOV | 170g | swift_boots |
| enhanced_lantern | +2 VIS (torch r=5) | 110g | lantern |
| plate_helm | +2 HP_max | 130g | iron_cap |

Gate: `_clan_owns_prereq()` checks any alive clan unit. +1 NOT consumed. Sale → `castle_item_purchased` event.

### Town Services  (T103 LOCKED)

| Service | Cost | Limit | Notes |
|---------|------|-------|-------|
| Pub | 10–75g | — | Tiers 0–4; intel_exchange_wealth bonus |
| Armory | item price | shared | +1 items, seed 3–4 |
| Healer | 10g/HP | 2/clan/town | Combat HP only |
| Sanctum (Velmoor) | 25g/HP | 3/clan/game | Exhaustion HP |
| Inn | 20g/35g | unlimited | 50%/turn heal; unit rests (cannot move) |
| Notice Board | 30–80g | unlimited | T1 intel; feeds exchange wealth |

### Castle Services  (T103 LOCKED)

| Service | Cost | Limit | Notes |
|---------|------|-------|-------|
| Steward's Hall (Pub) | 10–75g | — | Same tiers; NO exchange bonus |
| Armoury | item price | shared | +2 items; prereq gate |
| Barracks (Inn) | 20g/35g | unlimited | Identical to town inn |
| Chapel | 40g/HP | 2/clan/castle | Exhaustion HP (costlier than Velmoor) |
| Scriptorium | 100–200g | unlimited | T2 intel tokens |
| Gov't Broker | — | — | T3 diplomacy §17 |

### Inn Mechanics  (T103 LOCKED)
`town_inn()` / `castle_inn()` → `unit.resting=True`, `rest_turns_left=N`. `inn_rest_tick()` (Step 22): heals `floor((hp_max − hp_combat) × 0.50)` per turn, min 1. Clears flag on completion.

### Notice Board — T1 Intel Tokens  (T103 LOCKED)

| Token | Price | Intel type | Conf |
|-------|-------|-----------|------|
| shrine_direction | 50g | shrine_direction | 0.60 |
| monster_rumour | 30g | unit_spotted | 0.50 |
| mantra_fragment | 80g | mantra_fragment | 0.40 |

### Scriptorium — T2 Intel Tokens  (T103 LOCKED)

| Token | Price | Intel type | Conf |
|-------|-------|-----------|------|
| shrine_location | 150g | shrine_direction | 0.90 (exact hex) |
| mantra_teaching | 200g | mantra_known | 0.70 |
| monster_weakness | 120g | weakness_known | 0.85 |
| clan_movement_report | 100g | combat_specific | 0.65 |

### Information Exchange Engine  (T103 LOCKED)
`_log_town_visitor()` called by every town service. `town_info_exchange_tick()` recomputes each turn:

| Unique clans / 20t | Wealth | Pub tier bonus |
|---------------------|--------|----------------|
| 0–1 | 0 | None |
| 2–3 | 2 | +1 tier |
| 4+ | 4 | +2 tier |

Castle pubs: plain `effective_pub_tier()` — no wealth bonus. Early game equal; late game towns richer.

### Sacred Space  (T103 LOCKED — extends LOCKED #35)
`is_in_sacred_ground(q, r, state)` returns True within 2 hexes of: shrine (original), **town** (new), **castle** (new). Checked in `can_attack()` and `_step_queue_melee_combat()`. Town approaches and castle gates are safe meeting zones.

---


**Sell economy:** T1 items use specialist/generic/Den rates (40–65% of base_value). T2+ items: town offers perceived_value (50% T2/T3, 60% T4); item enters armory at `perceived_value × 2`. Eligible clans buy from armory at that resale price.

**World-gen pool sizes per game:** T1=all 19 always in shops · T2=6–8 of 14 on map · T3=4–5 of 14 from Tier 1/2 lairs · T4=1–2 of 8 from Tier 3 (advanced) lairs only.

**Class restrictions:** `class_restrict:"melee"` = non-ranged template. `class_restrict:"archer"` = ranged template. `magic_tier_min:N` = spell_tier_max ≥ N required.

### T1 — Shop Items *(simple names; shops/enclaves)*

| ID | Name | Cost | Restriction | Effect |
|----|------|------|-------------|--------|
| `keen_blade` | keen blade | 50g | — | +1 ATK |
| `iron_shield` | iron shield | 40g | melee | +1 DEF |
| `swift_boots` | swift boots | 50g | — | +1 MOV |
| `lantern` | lantern | 30g | — | +2 VIS |
| `healing_draught` | healing draught | 35g | — | +3 combat HP *(consumable)* |
| `shrine_map` | shrine map | 60g | — | Reveals all shrine hexes *(consumable)* |
| `frost_blade` | frost blade | 120g | melee | +1 ATK; on hit: −MOV 1t |
| `leather_armour` | leather armour | 70g | melee | +1 DEF, +1 HP max |
| `travel_rations` | travel rations | 30g | — | +2 HP regen/turn 5t *(consumable)* |
| `trackers_kit` | tracker's kit | 45g | Ranger/Rogue | +1 VIS, +1 INT |
| `longbow` | longbow | 80g | archer | +1 RNG, +1 ATK |
| `storm_bow` | storm bow | 110g | archer | +2 ATK; −1 in forest |
| `hunters_quiver` | hunter's quiver | 45g | archer | +1 ATK in forest/hills terrain |
| `mana_staff` | mana staff | 90g | T2+ magic | +4 MP max, +1 MP regen/turn |
| `focus_crystal` | focus crystal | 100g | T2+ magic | +1 spell damage |
| `spell_scroll` | spell scroll | 80g | T1+ magic | Cast T1 spell once *(consumable)* |
| `runic_axe` | runic axe | 100g | Dwarf | +1 ATK, +2 ATK vs buildings |
| `seeker_talisman` | seeker talisman | 80g | Seeker | +1 MOV |
| `warding_stone` | warding stone | 60g | Seeker (enclave) | Negate 1 incoming spell *(consumable)* |
    | `crystal_lantern` | crystal lantern | 55g | — | **+3 VIS in lair interiors** (VIS = 5). Torch suppressor penalty halved. |
    | `lair_map` | lair map | 40g | — | **Reveals full current lair interior layout** *(consumable)* |
    | `brass_sextant` | Brass Sextant | 175g | — | **At sea: +2 VIS**, reveals all island hexes in range, +1 Oracle intel tier. Coastal towns only. *(T2)* |

### T2 — Navigation Items *(Sprint 39)*

| ID | Name | Cost | Source | Effect |
|----|------|------|--------|--------|
| `brass_sextant` | Brass Sextant | 175g | Coastal shop / map | At sea +2 VIS, reveals island hexes in VIS range, +1 Oracle intel tier per turn unit is at sea. Tracked on unit as `at_sea_vis_bonus`, `reveals_island_hexes`, `oracle_intel_bonus`. Applied each turn by `sextant_tick()` in `engine_ai_s39.py`. |

### T2 — Map Items *(proper names; 6–8 placed on map ground per game)*

| ID | Name | Value | Restriction | Effect |
|----|------|-------|-------------|--------|
| `warlords_standard` | Warlord's Standard | 180g | Fighter/Dwarf/Monk | Aura: friendlies w/in 2 hex +1 ATK/+1 DEF |
| `gale_talisman` | Gale Talisman | 140g | — | All clan +2 MOV 3 turns *(consumable)* |
| `blessed_compendium` | Blessed Compendium | 160g | T2+ magic | +2 MP max, +1 spell dmg |
| `runed_shield` | Rune-Etched Shield | 200g | Fighter/Dwarf/Cleric | +2 DEF; absorbs 1 spell/combat |
| `lost_scholars_journal` | Lost Scholar's Journal | 150g | — | Reveal 1 unknown shrine mantra *(consumable)* |
| `silverleaf_cloak` | Silverleaf Cloak | 160g | Elf/Ranger/Rogue | +1 STL, +1 MOV |
| `heartstone_pendant` | Heartstone Pendant | 140g | — | +2 HP max, +1 RES |
| `forge_whetstone` | Whetstone of the Forge | 100g | melee | +2 ATK for 5 turns *(consumable)* |
| `serenity_vial` | Serenity Vial | 130g | — | +6 combat HP, clears 1 status *(consumable)* |
| `ashpowder_bomb` | Ashpowder Bomb | 120g | Rogue/Ranger | 3-hex AoE: all units invisible 2t *(consumable)* |
| `eldritch_lens` | Eldritch Lens | 200g | T4+ magic | +1 VIS, +1 spell dmg |
| `field_cache` | Field Commander's Cache | 130g | — | +3 HP all friendlies w/in 2 hex *(consumable)* |
| `shadowmarked_coin` | Shadowmarked Coin | 150g | Rogue/Ranger | +1 STL, +1 ATK from stealth |
| `battle_horn` | Battle Horn of the Ancients | 160g | Fighter/Dwarf/Monk | All clan +1 MOV 5 turns *(consumable)* |
| `runelight_orb` | Runelight Orb | 140g | — | **+5 VIS in lair interiors** (VIS = 6). Immune to torch suppressors. Auto-reveals hidden caches. |

### T3 — Lair Items *(4–5 per game, Tier 1/2 monster lairs)*

| ID | Name | Value | Restriction | Effect |
|----|------|-------|-------------|--------|
| `ignis_brand` | Ignis Brand | 300g | melee | +2 ATK; on kill: fire suppresses regen |
| `nightshroud_blade` | Nightshroud Blade | 280g | Rogue | +1 ATK; permanent passive shroud |
| `soulreaver` | Soulreaver | 320g | melee | +2 ATK; kills prevent reanimate |
| `blade_of_valor` | Blade of Valor | 350g | Fighter/Dwarf/Monk/Cleric | +3 ATK |
| `moonsilver_bow` | Moonsilver Bow | 290g | Elf/Ranger archer | +1 RNG; ignores forest DEF |
| `whisperbow` | Whisperbow | 260g | Rogue/Ranger archer | Shooter hex concealed on ranged attack |
| `archmages_rod` | Archmage's Rod | 300g | T3+ magic | −1 MP cost all spells |
| `endurance_sigil` | Endurance Sigil | 280g | T3+ magic | T4 spells: no exhaust HP |
| `seekers_compass` | Seeker's Compass | 260g | Seeker | +3 VIS |
| `wraith_shroud` | Wraith Shroud | 240g | Seeker | Invisible 3 turns *(consumable)* |
| `blooddrinker` | Blooddrinker | 310g | melee | +2 ATK; +2 combat HP on kill |
| `grimoire_of_ancients` | Grimoire of the Ancients | 340g | T3+ magic | +2 spell dmg, +2 MP max |
| `pathfinders_mantle` | Pathfinder's Mantle | 280g | Ranger/Elf/Rogue | +2 MOV, +1 VIS, +1 STL |
| `arcane_vestments` | Arcane Vestments | 300g | Cleric/Druid | +2 DEF, +1 spell dmg, Heal/Mend +2 HP |
| `dragonfire_brand` | Dragonfire Brand | 240g | melee | +2 ATK; fire aura (trolls/bog troll no regen; destroys fire-phylacteries on contact); **+6 VIS in lairs** (immune to suppression). |
| `spelunker_sigil` | Spelunker's Sigil | 200g | — | **+5 VIS in lairs** (suppression halved). +1 MOV in cave/ruined interiors. Rockfall immunity. +1 ATK vs. golem/construct types. |

### T4 — Advanced Lair Items *(1–2 per game, Tier 3 advanced enclaves only)*

| ID | Name | Value | Restriction | Effect |
|----|------|-------|-------------|--------|
| `dragonbreaker_lance` | Dragonbreaker Lance | 800g | melee | +4 ATK; negates dragon Ancient Armour |
| `scale_of_aevum` | Scale of the First Dragon | 700g | — | +3 DEF; absorbs 4 dragon-source dmg/turn |
| `obsidian_bolt_quiver` | Obsidian Bolt Quiver | 750g | archer | +2 ATK; ranged ignores dragon DEF stat |
| `tome_of_the_seraph` | Tome of the Seraph | 700g | T3+ magic | +1 spell dmg; +3 spell dmg vs Dragon |
| `binding_chain` | Binding Chain of Aevum | 600g | — | Root dragon 3t (RNG 4); 2 uses *(consumable)* |
| `crown_of_dominion` | Crown of Dominion | 750g | Chieftain | Aura: friendlies w/in 3 hex +2 ATK/+1 DEF |
| `cloak_of_the_unseen` | Cloak of the Unseen | 650g | Rogue/Ranger | Permanent shroud; +1 ATK/invisible turn stacked (max +4) |
| `philosophers_seal` | Philosopher's Seal | 800g | Mage | T5 spells: −5 MP, no exhaust HP |

### Organic Items ✅
Terrain-based renewables (`OrganicInstance`). Migrate if unharvested after 15 turns.
Tiers: common (respawn 8t), uncommon (15t), rare (25t).

### Celestial Items ✅
One per active clan per game (8 total). Revealed during 12-turn alignment windows.
Wrong clan: can carry/sell, cannot use. Migrate after 3 missed alignment cycles.

---

## 17. DIPLOMACY & ALLIANCES ✅ engine_pub.py · engine_castle.py · engine_diplomacy.py

### World-Map Alliance System ✅
Requires Chieftain's Code tech. 8-turn default duration (×2 Eternal Alliance, ×4 Monk wonder stack).
On formation: mantra knowledge exchanged at conf 0.65. Kinship pairs have higher AI affinity.
Betrayal penalty: −1 shrine stat (×2 with Eternal Alliance).

**#218 betrayal rollback ⚙️:** Already-earned shrine bonuses from betrayed ally's shrine stripped.
**#217 Conquest spoils ⚙️:** Not yet coded.
**Meditation rights trading 🔲:** `rights_sold_to`, `rights_bought_from`, `betrayal_occurred` exist in `ShrineRecord`.

### Pub Diplomacy — T1/T2 Intel ✅ engine_pub.py
Entering a pub interior triggers the pub relationship system. Relationship score tracked per clan per location in `town.pub_relationships[clan_id]`.

**Relationship tiers:**
| Tier | Score threshold | Barkeep opens up |
|------|----------------|-----------------|
| Stranger | 0 | No intel |
| Acquaintance | 3 | T1 vague rumours |
| Regular | 10 | T2 specific intel |
| Trusted | 25 | T2 + monster weakness |
| Confidant | 50 | T2 + monster weakness + bribe access |

**Pub action handlers** (6 total):
- `action_buy_drink(clan_id, pub_id, state)` — +1 rep score, +1 pint this visit
- `action_buy_round(clan_id, pub_id, state)` — +3 rep, +1 pint, logged as `BUY_ROUND`
- `action_listen_in(clan_id, pub_id, state)` — passive T1 intel roll; rogue/bard/ranger bonus
- `action_talk_to_patron(clan_id, npc_id, pub_id, state)` — NPC dialogue trigger; Clan Rep reveals T2 specific intel
- `action_bribe(clan_id, pub_id, gold, state)` — 3 tiers: 20g (T1+), 50g (T2+), 100g (T3 mantra). Charm override bypasses gold check for Bard.
- `action_propose_deal(clan_a, clan_b, pub_id, deal_type, state)` — Clan-to-clan deal via pub mediation (T1/T2 only)

**Pub leak:** After any intel acquisition, `pub_leak_check()` rolls base 15% × bard/rogue 1.8× / shaman 0.6× per pint. On leak: intel propagates to a random clan also present in the pub.

**Clan Rep NPC** (one per clan per active pub location): reveals the clan's shrine progress tier, current movement direction, and one T2 unit-spotted token. Requires Regular tier relationship.

**Bard Charm override** `apply_charm_override(clan_id, pub_id, state)`: Bard can use Charm spell in pub (costs 5 MP) to unlock bribe at any tier without spending gold once per visit.

**NPC warmth modifiers** (pub relationship score multiplier per interaction):

| Clan | Barkeep warmth | Patron warmth |
|------|----------------|---------------|
| Bard | 1.5× | 1.4× |
| Rogue | 1.3× | 1.2× |
| Ranger | 1.2× | 1.15× |
| Elf | 1.15× | 1.1× |
| Mage | 1.1× | 1.0× |
| Cleric | 1.05× | 1.0× |
| Druid/Monk | 1.0× | 1.0× |
| Shaman | 0.95× | 0.95× |
| Fighter | 0.9× | 0.85× |
| Dwarf | 0.85× | 0.9× |
| Necromancer | 0.7× | 0.8× |

**AI pub visit** `ai_pub_visit(state, clan_id)`: AI clans with mantra gaps and ≥50g visit nearest town pub. Buys drinks (1–3), then bribes if ≥ Confidant tier and gold permits. Logged as `AI_PUB_VISIT`.

### Castle Diplomacy — T3 Agreements ✅ engine_castle.py
Requires BOTH clans physically present in the castle's interior hex. Government Broker NPC witnesses all T3 agreements. Broker names seeded: Aldric, Sevra, Tormath, Lenne, Bravik, Syllen.

**6 T3 agreement types:**

| Agreement | Effect | Duration |
|-----------|--------|----------|
| FullAlliance | Mutual defence + mantra share at conf 0.65 | 12 turns |
| MutualShrinePlan | Both clans share unmeditated shrine list + routes | 10 turns |
| JointDragonAssaultPact | Both clans attack same dragon this turn. Kill gold split 60/40 | 5 turns |
| MantraExchange | Bilateral direct mantra transfer (conf 1.0 for specific shrine IDs) | Permanent |
| PassageRights | One clan may cross other's enclave zone without ZoC penalty | 8 turns |
| NonAggressionPact | No auto-combat between parties; adjacent encounter disabled | 6 turns |

**Broker functions:**
- `broker_check_access(clan_a, clan_b, castle_id, state)` → bool (both clans inside?)
- `broker_open_session(clan_a, clan_b, castle_id, state)` → logs `BROKER_SESSION_OPEN`
- `broker_seal_agreement(clan_a, clan_b, agreement_type, terms, state)` → `CastleAgreement`
- `broker_announce_breach(agreement_id, breaching_clan, state)` → applies virtue penalty + strips bonuses
- `check_agreement_expiry(state)` → decrement durations, log `AGREEMENT_EXPIRED`
- `broker_propose_ai(clan_id, castle_id, state)` → AI chooses agreement type based on mantra gap

**MantraExchange** uses `_transfer_mantras(donor, receiver, shrine_ids, state)`: direct transfer sets receiver conf = 1.0 for specified shrines.

**Breach consequences:** Virtue debt applied immediately. shrine stat −1. T3 agreements that breach: logged to `state.virtue_log`. All future T3 sessions with that clan refused for 20 turns.

---

## 18. INTELLIGENCE & FOG OF WAR ✅ engine_intel.py

### Fog of War (base system)
- `HexCell.is_visible[clan_id]` — currently visible (earns gold + heals this turn)
- `HexCell.is_explored[clan_id]` — ever seen (permanent)
- Scout: VIS 4. Scouting tech: +1 VIS all Scouts. Watch Post: +2 VIS permanent.
- Bard passive: reads exact shrine completion status for all visible rival clans.
- Monster weakness: `MonsterEnclave.weak_to`. +3 dmg if known via pub intel.

### Shrine Discovery ✅ (09/2026 fix)
Each clan starts knowing only its **own** shrine (`clan.shrine_records` seeded
with exactly `f"shrine_{clan_id}"` at turn 0 — `startup_engine.
_initialise_clans()`). The other 7 shrines are unknown — no `ShrineRecord`
entry exists for them at all — until discovered via:
  1. **Exploration** — a scout's vision reaches the shrine's hex (`is_explored`
     first becomes True for that clan) → `engine_ai.
     discover_shrines_from_visibility()`, called every turn from both
     `movement_engine._step_update_visibility()` (interactive client) and
     `engine_headless.visibility_update()` (headless/Atlas), identically.
  2. **Intel token** — a `shrine_location` or `mantra_known` token (pub,
     castle, lair, dialogue reward) unlocks the record immediately, not just
     a scoring bonus — see `engine_intel.acquire_intel()`.

**09/03/2026 follow-up fix (SHRINE_PURSUIT_WHILE_UNDISCOVERED):** channel 2
above was dead code for `shrine_location` specifically until this fix.
`IntelContent` never had an `extra` field at all despite several readers
(`acquire_intel()`'s discovery gate, `_intel_advance_shrine_boost()`,
`_intel_shrine_location_known()`, the goal-tree's shrine_location scan)
already reading `getattr(content, "extra", {})` — the attribute silently
resolved to `{}` every time. `shrine_location`'s `location_hint` was also a
composite `"{shrine_id}:{direction}:{dist_est}"` string that never matched
`state.shrines` keys either. Net effect: a `shrine_location` intel token
(pub/castle/lair/dialogue) granted zero discovery, ever — pure flavor text
+ a decorative score bonus. Fixed: `IntelContent.extra: dict` now exists;
`create_shrine_location_intel()`/`create_mantra_known_intel()` populate
`extra["shrine_id"]` (plus `direction`/`dist_band` for shrine_location).
`location_hint` is now a bare shrine_id for both token types. Full pytest
green after the fix.

**09/03/2026 Step 2 (SHRINE_PURSUIT_WHILE_UNDISCOVERED), STRICT NO-OPACITY
RULE for locations (user-clarified, final):** exact-coordinate shrine
discovery (a `ShrineRecord`) may ONLY come from (1) a unit's own vision
reaching the tile (`discover_shrines_from_visibility()`), or (2) an intel
token at **confidence == 1.0**, treated as equivalent to having witnessed
it firsthand. `acquire_intel()`'s discovery gate checks `confidence >= 1.0`
— an intermediate `>= 0.40` gate existed briefly this session and was
corrected; every real caller of `create_shrine_location_intel()`/
`create_mantra_known_intel()` today passes 0.80–0.85 (prisoner, pub bribe,
mantra swap, wisdom fighter), so in practice **no intel source currently
grants instant discovery** — only vision does. This generalises beyond
shrines: the same no-opacity principle applies to towns, villages, and
monster lairs — see the "Location Discovery" section below (implemented
09/03/2026). Castles remain intentionally omniscient (permanent landmarks).
The dragon egg's un-carried ground position is audited against this exact
rule too — see "Egg Ground-Position Discovery" below (implemented 09/2026).

ANY confidence < 1.0 — high or low — still biases exploration DIRECTION,
never coordinates: the token remains in `clan_intel` with its
`direction`/`dist_band` (from `_cardinal_direction()`/`_distance_band()`).
`engine_ai._shrine_region_hint_target()` reads all such hints for shrines
not yet in `clan.shrine_records`, prefers the HIGHEST-confidence one when
several exist, and projects a target hex from `state.map_centre_q/r` using
the same angle/distance convention those functions encoded with.
`_ai_scout_map()` sends scouts there — checked FIRST, ahead of the
pre-existing 50/50 road-follow/map-centre fallback. `evaluate_goal()`'s
`scout_map` floor also gets a confidence-weighted boost (up to +0.10 at
confidence 1.0) so a 0.85 prisoner account pulls the AI toward exploring
that direction meaningfully harder than a 0.15 gossip echo — the AI commits
to the direction proportionally to how much it trusts the rumour, but must
still explore the actual fog until vision confirms the tile; it never reads
a rumour as ground truth. Tests: `tests/engine/test_shrine_region_hint.py`.
Presence of a `shrine_id` key in `clan.shrine_records` **is** the discovery
flag; every AI read site already iterates `clan.shrine_records.items()`
(never `state.shrines` directly for targeting), so this makes shrine
targeting/scoring fog-correct project-wide. `evaluate_goal()`'s `scout_map`
branch floors 0.55–0.90 while any of the 8 shrines remain undiscovered,
independent of tile/fog exploration — scouting is not just for tile-gold
income, it is the only way to learn where the other 7 shrines are.
Before this fix all 8 shrines were seeded omnisciently at turn 0 for every
clan (a STRICT NO-OPACITY RULE violation, same category as the
dragon/egg-carrier omniscience bugs — see CHAOS_REGION_PLAN Phase 2 in
`activeContext.md` history).

### Location Discovery — Towns/Villages/Lairs ✅ (LOCATION_NO_OPACITY_AUDIT, 09/2026)

Generalises Shrine Discovery above: a clan knows the COUNT of each map
feature type from turn 0 ("there are 4 towns, 18 villages, N monster lairs"
— same common knowledge as "there are 8 shrines") but not WHERE any
individual instance is until discovered. Before this fix, towns/villages/
lairs were either fully omniscient by construction (towns had no per-clan
tracking field at all) or had a discovery field (`VillageInstance.
visible_to`/`MonsterEnclave.visible_to`) that existed but was never
consulted by the AI's actual targeting code — every read site iterated
`state.towns`/`state.villages`/`state.monster_enclaves` directly.

**Discovery ledgers** — `ClanInstance.discovered_towns`/`discovered_villages`/
`discovered_lairs: dict[str, True]`, exactly mirroring `shrine_records`
(presence of a key IS the discovery flag). Populated by two paths, same as
shrines:
  1. **Exploration** — `engine_ai.discover_locations_from_visibility()`,
     called every turn from BOTH `movement_engine._step_update_visibility()`
     and `engine_headless.visibility_update()` (plus once at turn 0 from
     `startup_engine._initial_visibility()`), identically across drivers.
  2. **Intel token at confidence == 1.0** — `town_location`/
     `village_location`/`lair_location` tokens (mirroring `shrine_location`),
     created by `engine_intel.create_location_intel()`. Same STRICT
     NO-OPACITY RULE as shrines: confidence < 1.0 biases exploration
     direction only (`engine_ai._location_region_hint_target()`, consulted
     by `_ai_scout_map()` alongside the shrine hint), never grants exact
     coordinates.

**Castles are intentionally excluded** — `CastleInstance.visible_to_all` is
a deliberate design choice (the four castles are permanent, always-known
landmarks), not an omission, and is untouched by this fix.

**AI read sites gated** (previously read hard state unconditionally):
`_best_target_for_unit()`'s settlement branch and its `clear_lair` branch,
`_ai_gather_intel()`, `_ai_upgrade_units()`, `_ai_build_pub_relationship()`,
`_ai_seek_mantra()`'s no-mantra-known branch, and the `upgrade_units`
`near_town` proximity heuristic in `evaluate_goal()`. `_ai_clear_lair()`/
its `evaluate_goal()` branch already correctly checked `enc.visible_to` —
only the `_best_target_for_unit()` picker for the same goal had the leak.

**SEED96-class stagnation guards added** alongside every new gate (matching
the pattern from SHRINE_PURSUIT_WHILE_UNDISCOVERED): `_ai_upgrade_units()`/
`_ai_gather_intel()`/`_ai_build_pub_relationship()` redirect into
`_ai_scout_map()` rather than returning `[]` when nothing is discovered yet.
A related, independently-discovered gap was fixed in the same sweep:
`process_ai_turn()`'s Step 4 secondary-goal dispatch could silently produce
zero actions for a whole clan-turn if the roulette-wheel goal selector
picked a goal whose `execute_goal()` legitimately returns `[]` for the
current game state (e.g. `negotiate_rights` below the gold threshold) —
confirmed via git-worktree bisection against unmodified HEAD that this bug
pre-existed and was merely never exposed by that fixed test seed's RNG
draw before the `near_town` heuristic change (part of this fix) shifted the
draw. `process_ai_turn()` now falls back to `_ai_scout_map()` if it would
otherwise return zero actions with idle units available.

Tests: `tests/engine/test_location_no_opacity.py`.

### Egg Ground-Position Discovery ✅ (EGG_INTEL_AUDIT, 09/2026)

Applies the same STRICT NO-OPACITY RULE to the dragon egg's UN-CARRIED
ground position. Before this fix, `_ai_seek_egg()`, `enforce_seeker_goals()`
(`engine_escort.py`), `_target_pos()` (both `engine_ai_s41.py` and
`engine_cluster.py`), and `_best_target_for_unit()`'s `seek_egg` branch all
read `state.dragon_egg.q/r` directly and unconditionally the instant a
Seeker existed — every clan always knew the egg's exact hex with zero
vision/intel gate, the same class of omniscience bug already fixed for
shrines and towns/villages/lairs. The existing `DragonEgg.
detected_by_clan_ids` field and `EggEngine.check_seeker_detection()`
interface method (documented in `engine_interfaces.py`) were dead — never
implemented or called anywhere.

**Discovery ledger** — `ClanInstance.egg_location_known: bool` (default
`False`), set by `engine_ai.discover_egg_from_visibility()` when a unit's
LIVE vision (`is_visible`, not `is_explored` — the hidden Veil Hex must
actually be seen right now, unlike a shrine's fixed masonry) reaches the
egg's hex. Wired into the same three call sites as shrine/location
discovery: `movement_engine._step_update_visibility()`, `engine_headless.
visibility_update()`, `startup_engine._initial_visibility()`. No-ops once
the egg is carried or already `revealed` (public forever once picked up —
by design, not an opacity question). Reset to `False` for every clan on
drop (`engine_headless.drop_egg_on_seeker_death()`) — the egg lands at a
new hex, so a clan must re-detect it, not retain omniscient tracking
through a fumble.

**Read-side gate** — `engine_ai.egg_ground_target_for_clan(state, clan_id)`
returns the egg's ground `(q, r)` only if `clan.egg_location_known`, else
`None`. Wired into `_ai_seek_egg()` (falls back to map-centre scouting, same
fallback `_ai_scout_map()` uses, rather than beelining to unknown
coordinates), `enforce_seeker_goals()`, `engine_ai_s41._target_pos()` and
`engine_cluster._target_pos()` (both gained a required `clan_id` parameter
for their `seek_egg` branch — callers without a clan_id conservatively get
`None`, never a stale/default coordinate), and `_best_target_for_unit()`'s
`seek_egg` branch. `contest_egg_carrier`/`steal_egg` (which target the
CARRIER UNIT, not the ground) were already correctly vision-gated by
`_ai_contest_egg_carrier()`/`_ai_rogue_steal_egg()` and are unaffected.
Carrying-egg routing (own carrier -> own home shrine) is also unaffected —
a clan always knows its own unit's cargo and its own shrine, no opacity
question there.

`egg_quadrant`/`dragon_spotted` intel tokens were separately audited and
found NOT to grant coordinates anywhere — they only ever apply as goal-score
floor boosts (`_INTEL_GOAL_BOOSTS`, `evaluate_goal()`'s `seek_egg` floor,
`knowledge_goal_modifier()`), so no fix was needed there.

`engine_ai.collect_field_report()`'s egg-proximity block (soft,
distance-based "sensing range" awareness feeding goal-score boosts via
`_field_report_goal_boost()`, NOT hard targeting) still reads `state.
dragon_egg.q/r` directly with no discovery gate — deliberately left alone,
same reasoning as the shrine/location field-report exemption: it is local
sensing-range awareness, not omniscient pathing, and touching it risks
destabilising many already-tuned goal-score boosts across the whole tree.

Tests: `tests/engine/test_egg_intel_audit.py`.

### Goal Commitment — Hard-Lock Phase Interrupt ✅ (POST_AVATAR_STAGNATION_REVIEW, 09/2026)

Clans commit to a goal for N turns (`_COMMITMENT_BASE`/`_COMMITMENT_RANGE_BY_GOAL`,
`process_ai_turn()` Step 3) so behaviour isn't metronomic. The commitment
continuation check only looked at `commitment_remaining > 0` — it never
re-checked whether the committed goal was still scoreable — and
`_check_goal_interrupt()`'s 3 hard-interrupt conditions (dragon awake, enemy
cluster near enclave, near-elimination) didn't cover a win-path phase
transition either. This let a stale commitment survive past a `_hard_lock`
phase change: `_parse_goal_tree()` zeroes every goal except a small
survivor set when the phase becomes `make_seeker` (only `produce_units`
survives) or `carry_home` (only `seek_egg`/`defend_enclave` survive) — see
Win-Path Phases above. A clan mid-commitment to e.g. `advance_shrines`
(6-12 turn commitment range) that achieves Avatar THIS turn flips phase
to `make_seeker` — `advance_shrines` is hard-capped to 0.0 by the new
floors, but the stale commitment kept selecting it anyway until its own
counter expired. `_ai_advance_shrines()` immediately returns `[]` once all
8 shrines are meditated (guaranteed true post-Avatar), so the clan
produced zero actions from its primary goal for however many commitment
turns remained — the same idle-clan failure mode as the SEED96
frontier-exhaustion bug (see below), but triggered by a phase transition
rather than running out of map to explore.

Fixed: `_check_goal_interrupt()` gained a 4th condition and a `hard_lock`
parameter (threaded from `process_ai_turn()`'s already-computed `_hard_lock`
flag) — if `hard_lock` is True and `scores.get(committed_goal, 0.0) == 0.0`,
force an immediate interrupt regardless of remaining commitment turns.
Only fires under a genuine hard-lock phase transition, not any goal that
merely happens to score 0.0 for other reasons (e.g. temporarily out of
targets pre-Avatar) — those legitimately wait out their commitment per the
original design. Tests: `tests/engine/test_ai_goal_tree.py::
TestHardLockInterrupt` (4 tests: direct hard-cap interrupt, surviving-goal
non-interrupt, non-hard-lock zero-score non-interrupt, and a full
`process_ai_turn()` integration test proving a stale `advance_shrines`
commitment is dropped the instant Avatar is achieved).

The other half of this review — `_ai_attack_rival()`/`_ai_defend_enclave()`
"positional payoff" concern (user's rule: slugfests are never stagnation
IF they serve map position/shrine/egg access) — was checked and found
already satisfied: `_ai_attack_rival()` always targets the nearest
*visible* real enemy unit (never aimless — engaging a spotted rival is
itself a legitimate contest), and `_ai_defend_enclave()` always rallies
units to a ring around the enclave or pulls distant units home (inherently
positional). Neither has an aimless-wander-and-fight-nothing path. No fix
needed there.

A broader per-unit idle-detection pass (catching partial idling where some
but not all of a clan's units get no action in a turn) was considered but
NOT implemented this session — unit movement is resolved separately via
`ai_goal_target_q/r` (written by cluster/sticky-goal passes, consumed by
the movement engine), not via the `GameAction` list `process_ai_turn()`
returns, so a unit having no `GameAction` this turn is not itself evidence
of stagnation (it may simply be mid-journey toward an already-set target).
Building a reliable per-unit heuristic on top of that would need its own
dedicated investigation; the existing end-of-turn guard (`if not actions
and units: actions = _ai_scout_map(...)`, SEED96-class, see below) remains
the backstop for the all-actions-empty case.

### Intel Token System ✅ engine_intel.py

**13 token types across 3 tiers.** All stored as `KnownIntel(content, confidence, learned_turn)` in `state.clan_intel[clan_id]: list[KnownIntel]`.

**Tier 1 — Vague / Directional** (confidence 0.30–0.65, validity 15–25t):
| Token type | What it encodes |
|------------|-----------------|
| `shrine_vague` | Cardinal direction to an unmeditated shrine |
| `dragon_vague` | Dragon seen recently, quadrant only |
| `unit_spotted` | Enemy unit seen, approximate location |
| `egg_quadrant` | Egg in one of four quadrants (N/S/E/W) |

**Tier 2 — Specific / Named** (confidence 0.55–0.85, validity 30–50t):
| Token type | What it encodes |
|------------|-----------------|
| `shrine_location` | Exact hex of a specific shrine |
| `mantra_known` | Mantra word for a specific shrine (conf = meditation speed) |
| `combat_specific` | Named clan moving toward specific hex |
| `dragon_spotted` | Dragon exact position + state |
| `spell_cast` | Clan cast specific spell + approximate hex |
| `egg_witnessed` ✅ 09/01/2026 (refactor 09/01/2026) | Precise egg-drop hex, granted to the killer's clan AND any other clan with a unit currently seeing the drop hex (conf 0.90, validity 25t); also injected into nearby (≤15hex) settlement gossip pools at reduced confidence, so it's later eligible for `pub_leak_check()` discovery by clans that neither killed nor witnessed the drop directly |

**Tier 3 — Authoritative / Permanent** (confidence 0.85–1.0, validity 80–∞ turns):
| Token type | What it encodes |
|------------|-----------------|
| `mantra_direct` | Direct mantra teaching (conf 1.0 → 2-turn meditation) |
| `shrine_meditated` | Confirmed shrine meditated by named clan (permanent) |
| `egg_carried` | Named clan's seeker carrying egg (high validity) |
| `prisoner_intel` | Structural layout + T3 specific intel from freed prisoner |

### Intel Generators (engine_intel.py public API)
- `create_shrine_meditated_intel(clan_id, shrine_id, state)` — T3, shrine meditation confirm
- `create_mantra_known_intel(shrine_id, confidence, state)` — T2/T3 depending on conf
- `create_shrine_location_intel(shrine_id, state)` — T2 shrine hex reveal
- `create_combat_intel(attacker_clan, target_hex, state)` — T2 movement warning
- `create_dragon_intel(dragon, tier, state)` — T1 or T2 based on observation range
- `create_spell_cast_intel(caster_clan, spell_id, hex, state)` — T2
- `create_unit_spotted_intel(enemy_unit, observer_clan, state)` — T1
- `create_item_shop_intel(location_id, item_id, state)` — T2 shop stock
- `create_prisoner_intel(npc_id, location_id, state)` — T3
- `create_egg_quadrant_intel(egg, observer_clan, state)` — T1
- `create_egg_witness_intel(clan_id, q, r, state, confidence=0.90)` — T2 low-level token factory only. No eligibility logic; callers must have already decided this clan witnessed the drop.
- `handle_egg_carrier_death(dead_unit, killer_unit, state)` — T2, 09/01/2026 (refactor 09/01/2026): the SINGLE decision point for "an egg-carrying Seeker just died." Lives in `engine_intel.py` (not `engine_headless.py` / `engine_dragon.py` — those two call it identically and contain no branching of their own). Order: reads `state.dragon_egg` pre-drop to capture carrier clan/location, calls `drop_egg_on_seeker_death()`, then grants an `egg_witnessed` token to (1) the killer's clan if different from the victim's (`killer_unit=None` for a dragon kill — dragon has no clan), and (2) any OTHER clan with a unit for which `WorldCell.is_visible[clan_id]` is True at the drop hex that turn (diegetic — their unit was there). Finally calls `_inject_to_nearby_pools()` so villages/towns within 15 hexes of the drop also get the token in their gossip pool at 0.8× confidence, making it eligible for later `pub_leak_check()` discovery (pints-at-a-pub) by clans that neither killed nor witnessed the drop directly. Called from `engine_headless._kill_unit()` (rival-clan kills) and `engine_dragon.dragon_unit_strike_tick()` (dragon kills) — both are thin call sites only.

### Pipeline Functions

> **LIVE as of 08/30/2026 (CHAOS_REGION_PLAN Phase 1).** `intel_propagation_tick`,
> `population_dissemination_tick` and `confidence_decay_tick` are now called
> from `engine_headless.intel_spread_tick()`, a `TURN_SEQUENCE` entry run
> every 5 turns (perf gate — each iterates clan_intel × units/settlements).
> Before this fix intel was acquisition-only: a token was written into
> `state.clan_intel[clan_id]` and stayed there at full confidence permanently,
> never decaying or spreading clan→settlement→rival. That is now fixed for
> all drivers (headless/Atlas/interactive share one `TURN_SEQUENCE`).

- `acquire_intel(clan_id, content, state, learning_pos, learning_unit_id)` — dedup by intel_id, merge conf **(LIVE)**
- `intel_propagation_tick(state)` — **LIVE**, every 5t via `intel_spread_tick()` — advances each clan's intra-clan KnownIntel wave (radius = turns_elapsed × propagation_speed; known_by_all at radius≥45)
- `population_dissemination_tick(state)` — **LIVE**, every 5t via `intel_spread_tick()` — spreads established (≥5t old) intel into settlement gossip pools, 1-2 hex/turn, confidence decays by distance
- `confidence_decay_tick(state)` — **LIVE**, every 5t via `intel_spread_tick()` — decays mutable-intel confidence per `_CONF_DECAY_RATE` once age ≥ validity_turns/2; T3 and item intel never decay
- `pub_gossip_surface(clan_id, pub_id, state)` — surface T1 tokens to pub patrons
- `pub_leak_check(unit_id, pints, pub_id, state)` — random T1 leak to other clans in pub

### Named Leader Intel — `clan_virtue_leader` token (CHAOS_REGION_PLAN Phase 1, 08/30/2026)

> **STRICT NO-OPACITY RULE (08/30/2026, user-clarified, supersedes any
> earlier "PARTIAL opacity" framing below):** a clan's virtue-meditation
> progress — at ANY count 1-8, named or anonymous — must ONLY ever reach a
> rival through the intel token system: witnessing, gossip propagation, pub
> visits, castle visits, diplomatic transfer. There is **no** engine-side
> fallback to hard/ground-truth state, for any of this information, ever.
> An earlier version of this session's fix had two hidden violations of
> this rule (both since fixed): `create_clan_virtue_leader_intel()` used to
> call `acquire_intel()` directly on every rival clan (an unconditional
> free grant, not gated by any intel channel), and
> `_ai_read_virtue_count_token()` used to fall back to a raw
> `sum(state.clans...)` when no token existed. Both are removed.

Root-cause fix for "nobody can gang up on the leader because nothing ever
names the leader": `virtue_count_public` is an **anonymous** T1 count ("N
virtues meditated" — no clan named), itself entirely token-gated (no
fallback). `clan_virtue_leader` is the **named** T2 counterpart: fires on
every change to any clan's `virtue_credits_count` (physical meditations +
spread credits — same measure the win path uses), 1 through 8 — not only a
late-game 6/7/8 threshold. Confidence 0.85, validity 12t (short — a specific
count goes stale fast), seeded into every gossip pool (global reach, not
just settlements within 15 hexes) — but **only** into gossip pools, never
granted directly to a rival's `clan_intel`. A rival still has to actually
visit a pub/castle/village (`pub_gossip_surface`/`pub_leak_check`/
`population_dissemination_tick`) to acquire it. Created by
`engine_intel.create_clan_virtue_leader_intel()`, called from both
`meditate_at_shrine_tick()` (physical) and `virtue_spread_tick()` (spread
credits) in `engine_headless.py`.

Read by `engine_ai._ai_read_virtue_leader_token(clan_id, state) →
(leader_clan_id, meditated_count)`. This is now the **only** source
`compute_clan_sentiment()`'s `contest_leader` field uses — it used to read
`c.shrines_meditated_count` directly on every rival clan every turn (raw hard
state, zero information opacity, confirmed the AI was fully omniscient about
who was closest to Avatar). Clans that never receive/propagate the token get
`contest_leader=""` and behave as they did before this fix.
`evaluate_goal("attack_rival")` applies a 1.6× score boost when a visible
enemy belongs to the known `contest_leader` clan.

### Dragon-State Opacity Fix — CHAOS_REGION_PLAN Phase 2 (08/31/2026)

> **STRICT NO-OPACITY RULE (user-clarified):** dragon awake/angry/enraged
> state is intel like any other — a clan only knows the dragon is active if
> a unit witnessed it (live vision) or it later reached them via
> pub/town/castle gossip (the existing `dragon_still`/`dragon_awake`/
> `dragon_enraged`/`dragon_spotted` tokens, `engine_dragon.py`/`engine_intel.py`).

Audit found this was the **largest omniscience violation in the game** —
bigger than either the virtue-knowledge or egg-carrier bugs fixed earlier —
because it affected every clan's dragon-reaction behavior globally, at all
times:

- **`evaluate_dragon_phase()`** (`engine_ai.py`) — the AI's "emergency
  override": used to read `state.dragon.state`/`.q`/`.r`/
  `.breath_preview_hexes` directly and evacuate/react for EVERY clan the
  instant the dragon woke ANYWHERE on the map. Fixed: now requires either
  live sight of the dragon's own hex (`_clan_sees_hex`) or a live
  `dragon_awake`/`dragon_enraged` token (conf ≥ 0.40, via
  `_ai_read_dragon_awake_token()`) before the clan reacts at all. The
  precise breath-preview micro-dodge additionally requires live sight —
  a gossip token conveys "it's active", not exact real-time breath geometry
  nobody has witnessed.
- **`compute_clan_sentiment()`'s `dragon_bonus`** (+0.3 to `egg_urgency`) —
  same fix: gated on live sight of the dragon's hex or a live token,
  instead of a raw `state.dragon.state` check.
- **`_ai_read_dragon_awake_token()`** — existed since an earlier session but
  had **ZERO callers anywhere** (fully dead/decorative). Now wired into both
  fixes above as the actual gate.
- `collect_field_report()`'s `units_near_dragon` field was also audited —
  confirmed it has zero readers elsewhere (dead data, not currently driving
  any decision), so left as-is rather than gated for no behavioral effect.

### Shrine Meditation Pipeline (Intel → Speed)
Intel system feeds directly into meditation speed via `mantra_knowledge[shrine_id].confidence`:
```
conf ≥ 0.95 (direct)      → 1 turn to meditate
conf ≥ 0.70 (secondhand)  → 2 turns
conf 0.40–0.69            → 3 turns
conf 0.10–0.39            → 4 turns
conf 0.0 (unknown)        → ❌ BLOCKED (hard gate in meditate_at_shrine_tick)
```
**The `MANTRA_VALUE` token is the primary path.** It carries the shrine's real
`mantra` word, is tier-3 (3+ pints, or a bribe / high pub tier), and is written
straight into `clan.mantra_knowledge` at `direct` confidence by
`engine_pub._learn_mantra_tokens()` — so the very next meditation is 1 turn.

Mantras are **game-wide facts**: `startup_engine._assign_mantras()` gives every
clan the same word for a given shrine. The economy is entirely in *how* you
discover it. Both discovery routes are live: an NPC may know a shrine's word
even if nobody has meditated it, **and** knowledge spreads from real meditations.

> **TODO (designed, not built):** the *price* of a mantra should slide with NPC
> trustworthiness, pub relationship tier, and the asking clan's virtue
> ascension. An NPC who knows the word should not give it away cheaply, but can
> be bought. Today the only gate is token tier + pint/bribe level.

### AI Intel Scoring (engine_ai.py Sprint 30)
6 functions boost/suppress goals based on `state.clan_intel[clan_id]`:
- `_intel_advance_shrine_boost(state, clan_id, shrine_id)` — mantra_known: +0.15+conf×0.25 bonus (max +0.50)
- `_intel_dragon_urgency(state, clan_id)` — dragon_spotted: −0.20 suppress risky goals
- `_intel_shrine_location_known(state, clan_id, shrine_id)` — shrine_location unlock pathfinding
- `_intel_egg_direction(state, clan_id)` — egg_quadrant: return (direction, conf) for seeker routing
- `_intel_rival_combat_threat(state, clan_id)` — combat_specific/unit_spotted: +0.30 defend_enclave
- `_intel_pub_bribe_needed(state, clan_id)` — returns True if clan has mantra gap + gold ≥ 50g

### Intel Log
Player can press **I** to open the Intel Log UI — ordered by turn learned, shows token type, confidence, description. Confidence shown as bar (0–100%). Expired tokens shown greyed-out.

---

## 19. NPC SYSTEM ✅ engine_npc.py · engine_pub.py · engine_castle.py · engine_interior_gen.py

**Towns:** 4 per game. Draw 4 from pool of 10 (seeded): Velmoor, Ashfen, Greyhollow, Caldspire, Thornmere, Duskwall, Irenvale, Saltmere, Embervoss, Wraithend.
**Castles:** Always present: Veilkeep, Thornhaven, Embrace, Ironmere.

Village garrison: unit adjacent to town hex → +3g/turn.

### Interior System ✅ engine_interior_gen.py
All interiors use the same axial hex system as the world map. Generated at boot from seeded RNG.

**Interior types:**
- **Town** — fixed `TOWN_BLUEPRINT`: entrance, square, pub, inn, blacksmith, healer, regent shop, contemplation hall, exit (9 rooms)
- **Village** — smaller, pub + shop + 1 service
- **Castle** — fixed `CASTLE_BLUEPRINT`: gatehouse, throne room, great hall, broker chamber, armory, treasury/vault, 3 dungeon cells, garrison, exit
- **Lair** — procgen: hex room growth + hall corridors. 5 themes: cave, swamp, crypt, ruined, fungal. Sizes by tier: T1=12–18 hexes, T2=20–30, T3=35–50, dragon lair=60–80

**Turn timer:** World map gets full `base_turn_s`. Active interiors split `base_turn_s // n_active` (floor 10s). `interior_map_time()`, `get_active_interior_count()`, `get_turn_time_for_map()` in engine_interior_gen.py.

### 19 NPC Types ✅ engine_npc.py
Clan affinity biases (`assign_npc_clan(npc_type, rng)`): each NPC type has weighted clan preferences used at interior-gen time.

| NPC Type | Location | Intel Tier | Loyalty gate | Clan bias |
|----------|----------|------------|--------------|-----------|
| barkeep | pub | T1 | Acquaintance (score ≥ 20) | bard/rogue/ranger |
| patron | pub | T1 | none | bard/rogue/ranger/elf |
| innkeeper | inn | T1 | none | bard/dwarf/cleric |
| merchant | market | T2 | none | dwarf/bard/mage |
| scout | tavern/road | T2 | none | ranger/rogue/elf |
| town_crier | square | T1 | none | bard/cleric/mage |
| guard | entrance | T1 | Allied only | fighter/dwarf/monk |
| herald | castle | T2 | Allied only | bard/cleric/monk |
| lord | throne room | T3 | Allied only | fighter/dwarf/cleric |
| broker | broker chamber | T3 | Allied only | bard/mage/cleric |
| arms_master | armory | T2 | Allied only | fighter/dwarf/ranger |
| keeper | contemplation hall | T3 | none | monk/druid/shaman |
| regent | regent shop | T2 | Acquaintance (score ≥ 20) | cleric/mage/bard |
| prisoner | dungeon cell | T3 | none (rescued) | any |
| survivor | lair entrance | T2 | none | ranger/rogue/fighter |
| wanderer | lair/wilderness | T1 | none | druid/shaman/ranger |
| scholar | library/tower | T3 | none | mage/bard/cleric/elf |
| healer | healer room | T1 | none | cleric/druid/shaman |
| shopkeeper | shop | T1 | none | dwarf/bard/fighter |

### Dialogue Routing ✅ `load_dialogue(npc_type, key, **kwargs)`
- **pub types** → `assets/dialogue/pub_dialogue.json`
- **castle types** → `assets/dialogue/castle_dialogue.json`
- **lair types** → `assets/dialogue/lair_dialogue.json`

JSON structure: `data[npc_type][key]` → str | list[str] (random choice from list).
kwargs substituted via `str.format(**kwargs)`.

**Dialogue files cover:** barkeep (5 relationship tiers × intel/no-intel), bribery (6 outcomes), all patron types (merchant/scout/clan_rep per clan), innkeeper, town crier, herald, broker (7 event types), lord/lady, dungeon prisoner (rescue + intel offer), guards, survivor (T3 intel reveal), ambient for all 5 lair themes.

### Overhear Mechanic ✅ LOCKED #124
Rival units within 3 interior hexes of an NPC dialogue event: 40% chance per unit to acquire same intel at `confidence − 0.25`. Logged as `NPC_OVERHEARD`.

### Willing Fighters — NPC Heroes ✅ engine_npc.py  *(08/2026)*

Full spec: `assets/md/willing_fighters.md`.

12 named heroes, **one per clan virtue**, hidden in interiors at boot. Free to
recruit, far stronger than a produced unit, and gated on a single rule:
**the clan must have completed meditation at the shrine of that hero's virtue.**
Only heroes whose gate clan is active are seeded → **8 of 12 in a standard game**.

| Hero | Virtue | Gate shrine | HP/ATK/DEF | Other | Item |
|---|---|---|---|---|---|
| Sorra the Undaunted | Valor | fighter | +6/+4/+1 | — | Iron Resolve Pendant |
| Alethis of the Long Road | Honour | elf | +5/+3/+4 | — | Vow Blade |
| The Healer of the Crossroads | Compassion | cleric | +8/+1/+2 | — | Restoration Draught |
| The Debt-Keeper | Sacrifice | necromancer | +5/+6/— | — | Necrotic Edge |
| The Broken Scholar | Wisdom | mage | +4/+3/— | +1 VIS, T3 intel | Mantra Codex |
| Pell the Truth-Singer | Honesty | bard | +5/+3/— | +1 VIS, pub bonus | Truth Lyre |
| Aldric the Exile | Justice | shaman | +6/+4/+2 | — | Judgment Blade |
| The Deep Wanderer | Spirituality | ranger | +5/+3/— | +2 MOV, +2 VIS | Spirit Compass |
| The Oathwarden | **Fortitude** | dwarf | +8/+2/+5 | — | Oath Shield |
| The Unnamed | Humility | monk | +5/+3/— | +3 STL | Null Cloak |
| Scratch | **Loyalty** | rogue | +5/+4/— | +2 STL, gold | Pickpocket Dice |
| The Grove-Keeper | Temperance | druid | +6/+3/— | +2 MOV, heal | Root Charm |

**Recruit flow:** `recruit_npc()` — adjacency, then `check_virtue_match()`. Refusal
returns `virtue_required` + a hint naming the shrine. On success the hero converts
to the recruiting clan's unit template, keeps their bonuses (written to
`unit.atk_bonus`/`def_bonus`/`mov_bonus`/`vis_bonus`/`stl_bonus`), gains their item,
and transfers all their intel. No gold cost, no cap per clan.

**Discovery:** `WILLING_FIGHTER_RUMOUR` (T1, virtue + rough area) and
`WILLING_FIGHTER_LOCATION` (T3, exact hero + location) intel tokens.

> **Fixed 08/2026** — the whole feature was dead on arrival: `recruit_npc()` raised
> TypeError on every call (UnitInstance missing 7 required fields); seeding ran
> *before* interiors existed and read a non-existent `interior_type` field, placing
> 0 heroes every game; `generate_all_interiors()` crashed on a 4-vs-5 tuple unpack
> (swallowed by a bare except); bonuses were written to an `extra_stats` dict that
> nothing read; and dwarf/rogue virtues contradicted `virtues.json` ("Truth" is not
> a virtue). Per-unit `atk/def/mov/vis/stl_bonus` are now summed in `effective_stat()`
> — which also activates previously-dead tech and leveling bonuses.
>
> **Balance follow-up (`d67abdf`):** activating those bonuses regressed the game
> (`sim_08_22_19_17`: STALEMATE 33→43 p=0.031, combats +122, turns 313→340,
> shrines flat) because ~1,800 level-ups per run had been silently inert, and all
> tuning was calibrated against that. They are now gated behind
> **`AEVUM_UNIT_BONUSES`** — `off` (default, legacy) / `atkmov` / `on`.
> Willing fighters still receive their bonuses on the unit fields; whether those
> reach `effective_stat()` depends on this toggle.

### Prisoner Rescue ✅ LOCKED #126
Unit adjacent to prisoner NPC: `free_prisoner()` grants dungeon layout T3 intel + all prisoner's intel_pieces at conf 0.85. Prisoner flagged `freed_by` + `freed_on_turn`.

---

## 20. SAILING SYSTEM (LOCKED #149-156)

> **⚠️ Implementation status (audited 2026-08-09).** This section is the
> authoritative *design* spec — `assets/md/` contains no naval content at all.
> But most of it is **specified, not live**. Audit findings:
>
> - **Port construction** — now wired end-to-end at the dispatch layer.
>   `action_type="build_port"` is consumed by
>   `engine_headless.execute_clan_actions()`, which is the **single** dispatch
>   point shared by Atlas (`client/atlas_map.py`) and the headless runner
>   (`simulate/runner.py`). Neither mode keeps its own copy of the action loop
>   any more, so the two can no longer disagree about port rules. Covered by
>   `tests/engine/test_action_dispatch.py`. Still unproven in a real run —
>   awaiting a user log showing `PORT_QUEUED` / `PORT_BUILT`.
> - **Port siting is a clan-level decision.** `build_port_at(clan_id, q, r,
>   state)` takes the target hex from the `GameAction`; no builder unit has to
>   walk to the coast and stand on the site. The legacy `build_port(unit_id,
>   state)` wrapper survives only for the interactive/player path. Gold is
>   debited *after* every gate passes, and each rejection returns a distinct
>   `reason` string.
> - **AI site selection** (`_find_best_port_site()` in `engine_ai_s39.py`) is
>   anchored on the clan's **enclave**, not its unit centroid, and bounded by
>   `max_site_distance_from_enclave` (**18 hexes**, `structures.json` →
>   `engine_sailing.PORT_MAX_SITE_DIST`). The AI picks the closest qualifying
>   coastal hex inside that radius. Centroid anchoring made the "best" site
>   drift every turn as the army moved, and an unbounded search let a clan
>   target coastline it could never reach or defend. Hexes with a port already
>   **queued** in `clan.production_queue` are excluded as well as completed
>   ones, so the AI cannot re-target its own in-progress build (which would be
>   rejected as `port_already_queued` every turn). If no coastal hex qualifies,
>   the goal scores 0 rather than picking a bad site. Covered by
>   `tests/engine/test_port_siting.py`.
> - **Port cap: 2 per clan, one build at a time (bugfix 08/2026).** The per-hex
>   dedup above was insufficient — excluding only the *identical* hex meant the AI
>   simply re-sited one hex over and started another port the next turn. A seed-5
>   run had the elf clan build **6** ports and the rogue clan **3**, burning ~700g
>   that should have funded galleys. Two new gates in `build_port_at()`, both
>   *before* the gold debit:
>   `port_build_in_progress` (the clan already has a port queued on **any** hex)
>   and `port_limit_reached` (the clan already owns
>   `max_active_per_clan` = **2** completed ports — `structures.json` →
>   `engine_sailing.PORT_MAX_PER_CLAN`). `_find_best_port_site()` returns `None`
>   in both situations so the executor emits nothing at all, and the
>   `build_port` floor in `naval_context_floors()` is suppressed while a port is
>   building — otherwise the goal won every turn only to be refused, starving
>   `train_galley` of both goal slots and gold.
> - **Galley construction** — live. `queue_naval_unit(clan_id, template_id,
>   state)` in `engine_sailing.py` is the single queue path, shared by the AI
>   (`train_naval` action → `execute_clan_actions()`) and the player. It reads
>   cost/turns from `unit_types.json` only, and gates on sailing tech, an owned
>   port, an adjacent sea launch hex, affordability and no duplicate queue entry
>   — all *before* debiting gold, so a refused galley costs nothing. On
>   completion the hull spawns on a sea hex adjacent to its port with
>   `at_sea=True`. Covered by `tests/integration/test_naval_pipeline.py`.
> - **Reserved naval production slot + refusal logging (bugfix 08/2026).** A
>   seed-5 run built 9 ports and produced **zero** naval events of any kind. Two
>   compounding causes, both fixed:
>   1. `evaluate_train_galley()` returned `0.0` on **any** non-empty
>      `production_queue`. But `force_fill_production_queue()` runs *before* the
>      goal AI every turn and fills the queue whenever it is empty, so the queue
>      was virtually never empty and the evaluator was structurally pinned at 0 —
>      no clan ever *wanted* a galley regardless of how many ports it owned. It
>      now zeroes only when a hull (`is_naval` template) is already queued.
>   2. Even when the goal fired, `queue_naval_unit()` refused with `queue_full`
>      because the generic build AI had taken every slot. A hull is gated on tech
>      + port + launch hex, so a clan that clears all three now gets **one
>      reserved slot** (`max_slots + 1`) while no naval item is in flight, and
>      `force_fill_production_queue()` additionally yields — returning without
>      queueing — for a clan that has Sailing + a port + no hull.
>
>   Refusals are no longer silent: both paths append `NAVAL_QUEUE_REFUSED` /
>   `PORT_BUILD_REFUSED` to `state.combat_log` (so they reach the JSONL and the
>   per-category log splits) **and** print to the session log with the `reason`
>   string and current gold. Previously the only record was an analytics event,
>   which reached neither — the outage looked like pure silence.
> - **Embark / sea movement** — wired (Sprint 42 Task 4). `effective_move_cost()`
>   now answers sea *per unit*: cost `_SEA_MOVE_COST = 1` if
>   `can_traverse_sea(unit, state)` (naval hull, embarked unit, or dragon), else
>   99. `TERRAIN_MOVE_COST["sea"] = 99` remains as the land-unit answer only —
>   do not read it directly for a hull. A `sea_only` hull is the mirror image:
>   every land hex costs 99, so a galley cannot path up a beach.
>   `naval_move_tick()` now runs in **both** turn loops (`simulate/runner.py`
>   after `unit_tick()`, matching `client/atlas_map.py`), so wind rotates, cannon
>   cooldowns decay, port income/destruction resolve and island loot awards in
>   headless as well as Atlas. Covered by `tests/engine/test_naval_movement.py`.
> - **Warship / cannon / sea-combat DEF−2** — **LIVE as of 08/2026.** (This bullet
>   previously read "deferred, not implemented" — that was accurate until now.)
>   - `GameState` still has **no `warships` field**, and none is being added.
>     `WarshipInstance` is vestigial: naval units are ordinary `UnitInstance`s
>     with `is_naval=True`, created by `spawn_produced_unit()`. `cannon_attack()`
>     now takes a `UnitInstance`, and `warship_cannon_tick()` walks
>     `state.units` — it used to iterate the nonexistent `state.warships`, so it
>     always looped over an empty dict and **no cannon ever reloaded**.
>   - **Sea DEF −2 is applied**, via `combat_engine.sea_def_modifier()`, in
>     **both** `resolve_hit()` and `_resolve_hit_pending()`. Naval hulls are
>     **exempt** — the sea is their native terrain; the penalty models an
>     embarked land unit fighting from a deck it cannot brace on.
>     `TERRAIN_DEF_BONUS` now lists `"sea": 0` explicitly so the lookup is never
>     a silent dict miss that hides the real modifier.
>   - **Cannon routes through the normal combat path.** It previously subtracted
>     HP inline and set `is_alive = False` directly, **bypassing `_check_death()`**
>     — so cannon kills awarded no kill credit and never triggered egg drops or
>     lair claims. Each target now goes through `resolve_hit()` (luck roll, full
>     DEF, `_check_death`). Retained: splash to **every** enemy on the target hex,
>     and a **2-turn** reload. Range/damage read from `unit_types.json`
>     (`cannon: {sea_range: 3, coastal_range: 2, coastal_def_penalty: -2}`) via the
>     new `UnitTemplate.cannon` field — JSON is authoritative (.clinerules §7).
>   - `_fire_cannons()` runs inside `naval_move_tick()` *after* movement, so a hull
>     that closed this turn can fire. It targets the hex holding the **most**
>     enemies, which makes an unescorted transport stack the worst thing to be at
>     sea. Emits `CANNON_FIRED`.
> - **Embarkation — LIVE as of 08/2026.** Land units cross water.
>   - There were **two** embark implementations (`engine_sailing.embark/disembark`
>     and `movement_engine.embark_unit/disembark_unit`) and **neither had a single
>     caller**; `clan.embark_enabled` was set by the Sailing tech and read by
>     nobody. The `movement_engine` pair is now canonical (it alone checks the
>     Sailing tech and an adjacent port); the `engine_sailing` pair delegates to
>     it, exactly as `wind_tick` does.
>   - **`adjacent_port_hex()` now includes the unit's OWN hex.** It checked only
>     the 6 neighbours, so a unit standing squarely on its own port was refused
>     with `no_adjacent_port` while one standing beside it could board. Backwards,
>     and invisible because embark had no callers.
>   - New unit goal **`embark_for_crossing`** targets the clan's nearest own port;
>     `_ai_embark_for_crossing()` emits an `embark` action once the unit is in
>     position. `embark` / `disembark` are dispatched in the shared
>     `execute_clan_actions()` and registered in `_DISPATCHED_ACTION_TYPES`.
>   - `_naval_units_advance()` also moves **embarked land units**, and
>     `_try_disembark_toward()` lands them on the coastal hex nearest their
>     objective — without it a transported army circles forever, since a land goal
>     target is never a sea hex. Emits `EMBARKED` / `DISEMBARKED`.
>   - A `sea_only` hull can never disembark. The **egg carrier can never embark**.
> - **Naval units never cluster with land units.** A galley was absorbed into a
>   LAND cluster at t52 and t157 of the seed-5 run: `_form_clusters()` grouped by
>   `(goal, target)` and `BROADCAST_RADIUS` (**8 hexes**) reaches straight across a
>   coastline, so a fleet could be led by a landlocked unit. The objective key is
>   now `(goal, target, hull_class)`, and `engine_cluster_v2.form_cluster()` /
>   `join_cluster()` refuse to mix classes. **Embarked land units count as LAND** —
>   they are passengers who will disembark and rejoin the land war.
> - **Island loot** — claimable (Sprint 42 Task 4). `_check_island_loot()` used
>   to require `at_sea or is_naval`, but seeded island hexes are **land**: the
>   unit standing on the item had `at_sea=False` and no naval hull, so all 18
>   seeded items were permanently uncollectable. The gate is gone — any clan unit
>   on the hex claims it (a land unit can only get to an island by sea anyway).
>   Monsters/dragons are excluded, having no clan inventory.
> - **Wind** — one implementation, seeded. `movement_engine.wind_tick()` is a
>   delegating shim over `engine_sailing.wind_tick()` (the two used to disagree:
>   6-10 turns ±1 vs 3-10 turns +1). `GameState.rng` now exists —
>   `startup_engine` seeds it as `random.Random(seed ^ 0x57114D)`, excluded from
>   serialization — so wind is seed-reproducible instead of degenerate (period
>   pinned to 8, always counterclockwise) in one path and unreproducible in the
>   other. Exactly **one** wind tick per turn per mode: the interactive path ticks
>   it at Step 0 of `resolve_turn()`; the sim/Atlas paths tick it inside
>   `naval_move_tick()`, and never both.
> - **Naval units actually MOVE** — fixed 08/2026. `naval_move_tick()` did wind,
>   cannon cooldowns, port checks and island loot but **never assigned to a
>   unit's `q`/`r`**. All hull movement lived inside the goal-execution helpers
>   (`_ai_explore_islands_s39`, `_ai_raid_rival_port_s39`), so a hull whose goal
>   was never selected sat on its launch hex forever. A seed-5 Atlas run launched
>   5 galleys and each logged exactly **one** position across up to 111 turns.
>   `naval_move_tick()` now calls `_naval_units_advance()`, which sails every
>   alive hull one wind-budgeted leg toward its `ai_goal_target_q/r` via
>   `_sea_path_toward()` (greedy, sea-only, ≤6 hexes) and falls back to patrolling
>   toward the nearest island-loot hex when it has no target. Emits `naval_move`.
>   NB `ai_goal_target_q/r` default to **0**, not `None` — "no target" is `(0,0)`.
> - **Naval units are IN the goal queue** — fixed 08/2026. The comment in
>   `engine_ai.py` claimed `explore_islands` / `raid_rival_port` were "type-gated
>   in `UNIT_ELIGIBLE_GOALS`". **Correction (08/2026): that table DOES exist**, at
>   `engine_ai_s41.py:216`, and it already carried `"galley"` / `"warship"`
>   entries — an earlier revision of this doc wrongly claimed it had never
>   existed. The real defect was different: `_pick_unit_goal()` never consulted
>   it. Those goals are
>   deliberately excluded from the clan `directive_set`, and `_pick_unit_goal()`
>   only iterates that set — so a hull matched nothing and returned `None` every
>   turn. In the seed-5 run naval goals were chosen **zero** times despite rogue
>   holding a 0.78 `raid_rival_port` weight and owning 4 galleys. Now
>   `_pick_unit_goal()` **replaces** the directive set for any `is_naval` unit
>   with `["raid_rival_port", "explore_islands"]` (rogues raid first, everyone
>   else explores first), and `_best_target_for_unit()` resolves both goals —
>   nearest island-loot hex / unvisited island settlement, and nearest rival port.
> - **Atlas naval rendering** — naval hulls draw as a **filled clan dot on a
>   highlighted hex** (`_highlight_hex()`), identical in weight to land units.
>   They previously drew as a thin hollow ring that was invisible at the zoom
>   levels an Atlas session actually runs at.
> - **Port cost** — normalized to **80g/3t** across `structures.json` and code
>   (2026-08-09); `engine_sailing.PORT_COST` / `PORT_BUILD_TURNS` are read from
>   `structures.json`, not hardcoded. Port **HP** is now **3** everywhere
>   (JSON, `PortInstance` default, and `complete_port()`).
>
> Do not mark any of the above ✅ until a user-provided run log proves it.

**Infrastructure:** `engine/engine_sailing.py`. `HexCell.is_coastal`, `is_port`, `is_island`.
`UnitInstance.at_sea`, `is_naval`.

**Port siting:** Chosen by the clan/enclave, not by a unit standing on the hex. AI candidates
must be coastal land within 18 hexes of the owning enclave
(`max_site_distance_from_enclave` in `structures.json`); closest wins.
**Embark:** Must be at friendly/allied port. `unit.at_sea=True`. Egg carrier: cannot embark.
**Disembark:** Target must be passable coastal land hex.
**Wind budget:** With wind=4 hexes/turn, ±60°=3, ±120°=2, against wind=1.
`wind_tick()` decrements `wind_turns_remaining`; at 0 it rotates one step clockwise
with p=0.7 (else holds) and re-rolls the duration to 3-10 turns, using the seeded
`state.rng`.
**Warship (`WarshipInstance`):** HP 12, always at sea. Cannon: sea r=3, coastal r=2. Sea combat DEF−2.
**Port (`PortInstance`):** HP 3. Build 80g/3t. Destroyed if enemy occupies 2 consecutive turns.
**Dragon:** Can traverse sea hexes without Sailing tech.
**Island loot:** `seed_island_loot()` seeds one item per isolated island hex (≤2 land neighbours) from a
6-item pool (`nautical_chart`, `sea_glass_lens`, `kraken_talisman`, `coral_armor`, `storm_anchor`,
`driftwood_chart`), capped at 18/game. Awarded via `_check_island_loot()` (called from
`naval_move_tick()`) to the first **clan unit** standing on the hex — typically a unit that
just disembarked, so `at_sea` is False by then. One-time: the hex leaves the pool on claim.

### Naval AI Goal Layer ⚠️ PARTIALLY IMPLEMENTED (Sprint 39 — `engine/engine_ai_s39.py`)

> **⚠️ Accuracy note (updated 2026-08-09):** everything in this section
> describes goal *scoring*, which works and is tested. `build_port` is no
> longer dropped on the floor — it is dispatched via
> `engine_headless.execute_clan_actions()` in both Atlas and headless. The
> naval **build** chain is now live end-to-end up to the point of launch:
> `train_naval` joins `build_port` as a dispatched action, naval templates load
> from `unit_types.json`, and a completed galley spawns on a sea hex adjacent to
> its port. Costs come only from JSON — the 60g/4t `_ai_train_galley_s39` used
> to hardcode (against the 80g/3t in JSON) is gone, and that function no longer
> touches gold or the production queue at all. Queue-time gates (tech, port,
> launch hex, affordability) all reject *before* any gold moves, so a refused
> galley no longer destroys gold. Covered by
> `tests/integration/test_naval_pipeline.py` (17 tests).
> As of Sprint 42 Task 4 the *movement* half is wired too: sea is passable per
> unit via `can_traverse_sea()`, `naval_move_tick()` runs in both turn loops, wind
> is single-implementation and seeded, and island loot is claimable — see
> `tests/engine/test_naval_movement.py` (18 tests). What remains is **proof from a
> real run**: no user log yet shows a galley crossing water or an island item
> being picked up, so nothing in §20 is marked ✅. See
> `doc/SPRINT_42_NAVAL_ACTIVATION.md`.
5 new AI goals woven into the unified goal-scoring fabric (not a separate silo):
`research_sailing`, `build_port`, `train_galley`, `explore_islands`, `raid_rival_port`.
Per-clan weight table + phase anchors + commitment/timeout constants defined in
`S39_GOAL_PRIORITY_PATCH` / `S39_GOAL_PHASE_ANCHORS`. Coastal explorers (Ranger/Elf/Bard/Rogue)
weight naval goals highest; landlocked-leaning clans (Monk/Necromancer) lowest.

**Bugfix (08/2026):** the three build-order evaluators (`evaluate_research_sailing`,
`evaluate_build_port`, `evaluate_train_galley`) originally used hard gold gates
(e.g. `if clan.gold < 100: return 0.0`) that almost never passed for AI clans mid-game,
so the entire naval chain (Sailing tech → Port → Galley → island/mainland exploration)
essentially never fired in practice — see `doc/bugfix_plans/03_naval_embark_exploration.md`.
Replaced with a soft affordability ramp (`score = base * (0.15 + 0.85 * min(1.0, gold/threshold))`)
so partial gold still contributes non-zero urgency instead of a flat disqualification.

**Naval context floors** (`naval_context_floors()`): guarantees naval goals compete with
shrine/pub goals under hard conditions — e.g. egg confirmed offshore + no Sailing tech →
`research_sailing` floor 0.78; has Sailing + no port → `build_port` floor 0.68 (0.84 if
egg offshore); has port + no naval unit → `train_galley` floor 0.60.

**Per-unit self-knowledge modifier** (`naval_self_knowledge_mod()`): at-sea units bias toward
naval goals (+0.40) and away from land-access goals (−0.30); warships bias hard toward
`raid_rival_port` (+0.50); a coastal Chieftain biases toward `build_port` (+0.35).

### The Sextant Item ✅ (Sprint 39 — Ultima IV homage)
`brass_sextant` (T2 item, 175g, `engine_items.py`) / `SEXTANT_DATA` in `engine_ai_s39.py`.
Special slot, +1 MOV on sea hexes, not consumed. While holder is at sea OR on a coastal hex
(8-turn cooldown, `_SEXTANT_COOLDOWN`): grants a T2 `egg_quadrant` intel token at confidence 0.95
giving a bearing (`nearby`/`northeast`/`east`/.../`north`) to the Dragon Egg; if the egg sits on
an island hex the direction gets an `_island` suffix, which flips `_egg_direction_favors_sea()`
to True and unlocks the full naval goal chain. AI self-knowledge modifier for the holder:
+0.30 `explore_islands`, +0.22 `seek_egg`, +0.25 `scout_map`, +0.15 `gather_intel`,
+0.20 `research_sailing`. Global per-turn driver: `sextant_tick(state)`.

---


## 21. AI GOALS SYSTEM

| Goal | Key conditions | Per-clan weights |
|------|---------------|-----------------|
| advance_shrines | Always. Dampens if rival at 5+ | Cleric 0.9, Monk 0.9, Ranger/Elf 0.8 |
| attack_rival | Floor 0.2. +30% if shrine contest | Fighter 0.9, Necro 0.8, Dwarf 0.75 |
| defend_enclave | Scaled floor (§20/§21 note below), not a flat "enemy within 5 hex" lock | Cleric 0.7, Shaman 0.6 |
| scout_map | 0 if >70% explored AND all 8 shrines discovered; floors 0.55-0.90 while any shrine undiscovered (§18) | Ranger 0.9, Rogue 0.8, Elf 0.7 |
| seek_egg | 0 if <8 shrines. 1.0 if Avatar+no Seeker | Rogue 0.7, Elf 0.6, Mage 0.6 |
| negotiate_rights | Bard 1.2×. Others: sell unmeditated shrines | Bard 0.9, Cleric 0.7 |
| build_camp | 0 if 3+ camps | Dwarf 0.8 |
| clear_lair | Tier/distance scoring | Dwarf 0.6 |
| seek_mantra | Active when unknown shrines remain (#192) | All clans |
| build_pub_relationship | Active — routes to nearest town, bribes for mantra intel (#193 ✅) | Bard priority |
| pursue_alliance | Kinship pairs preferred (#194) | All clans |
| steal_egg ✅ Sprint 27, gated 08/31/2026 | Rogue only. Egg carried by rival, carrier VISIBLE to this clan, within 20 hex (widened from 12 — see below) | Rogue 0.9 |
| contest_egg_carrier ✅ Sprint 27, gated 08/31/2026 | Egg carried by rival, carrier VISIBLE to this clan → intercept within 20 hex | Fighter/Dwarf/Necro 0.7–0.8; Cleric/Monk 0.6; others 0.5 |
| seek_egg (egg_witnessed override) ✅ 09/01/2026 | Egg on ground, this clan's Seeker already built, holds a fresh (≤25t) `egg_witnessed` token → floor 0.95 (near-hard) | All clans with a Seeker |

> **CHAOS_REGION_PLAN Phase 2 (08/31/2026), STRICT NO-OPACITY RULE
> (user-clarified):** `_ai_rogue_steal_egg()`, `_ai_contest_egg_carrier()`,
> and the `contest_egg_carrier` floor in `_parse_goal_tree()` used to read
> `state.dragon_egg.carrier_q/r`/`carried_by_clan_id` directly — every clan
> always knew exactly where the carrier was and who it belonged to, with
> zero vision/intel gate. All three now require `_clan_sees_hex()` on the
> carrier's current hex before contesting fires; the `steal_egg` distance
> cap widened 12→20 to match `contest_egg_carrier`'s range now that vision
> is the real limiter, not an arbitrary distance. NOTE: `create_unit_spotted_intel()`
> and the `seeker_active` token (intel_token_system.md) both have ZERO
> callers anywhere — there is currently no secondhand/stale-intel channel
> for the carrier, only live sight. Wiring those tokens in is future work.

> **CHAOS_REGION_PLAN Phase 3 (09/01/2026), bimodal-distribution fix:** log
> analysis of `sim_08_31_2026_17_51` (100 games) found the egg already
> changes hands via incidental combat (140 pickups vs 51 deliveries across
> the run — kills routinely drop it), but nothing re-sought a *dropped*
> egg: one confirmed case (seed 60) sat unclaimed t112→t224 (112 turns)
> before a different clan stumbled onto it by chance. This was the actual
> root cause of the bimodal EGG_WIN(t99–220)/STALEMATE(400t) split — no
> middle-length games. Fixed: the killing clan AND any other clan with
> live vision of the drop hex are granted an `egg_witnessed` token via
> the single decision point `engine_intel.handle_egg_carrier_death()`
> (see §Intel Token System) and `_parse_goal_tree()` now floors that
> clan's `seek_egg` to 0.95 while the token is fresh, engaging the
> existing `enforce_seeker_goals()`/`rally_clusters_to_seeker()`
> escort-muster machinery (both already keyed off the `seek_egg` goal) so
> the retrieving seeker travels escorted rather than alone. The drop is
> also seeded into nearby settlement gossip pools for later pub-leak
> discovery by clans that neither killed nor witnessed it directly.
> Refactored 09/01/2026 (same day, user-directed): the eligibility
> decision used to live inline in `engine_headless._kill_unit()` — moved
> entirely into `engine_intel.py` per the "one engine, many drivers,
> engine/ owns all decision logic" standing rule; `engine_headless.py`
> and `engine_dragon.py` now both make one identical thin call. User
> directive honoured: "if an egg-carrying seeker is killed by a clan,
> that clan gets the information token of exactly where the egg is
> now... or another clan that witnesses... we need to ensure seekers are
> escorted."
> Not yet re-run against a fresh regression at time of writing — see
> activeContext.md CURRENT TASK for pending validation.

### 21.1 WIN-PATH PRESSURE — the AI must not drift off the win condition *(08/2026)*

Three linked changes in `_parse_goal_tree()`. All exist because of one measured
failure in the 20-game regression `sim_08_13_2026_17_41`: **17 of 20 games ended
STALEMATE at exactly the turn ceiling.** Clan units pursuing `advance_shrines`
fell **51 → 4 → 0** between t100 and t300 while `defend_enclave` grew to 235 of
484 units; meditations per 50-turn bucket collapsed 161 → 0; and the best clan in
an average game plateaued at 4.4 of 8 shrines from t250 onward. Nothing ever
re-raised the win-path floor once the combat and gold floors took over.

**a) `zeal_turn` — personality-scaled win-path ramp.**
Each clan rolls its own commitment turn at game start from its archetype
(`engine_personality.ZEAL_TURN_BY_ARCHETYPE`, read via `get_zeal_turn(clan)`):
zealot 30–60 · expansionist 40–75 · scholarly 55–95 · pragmatic 60–100 ·
balanced 70–110 · fortified 85–130 · aggressive 100–155 · mercantile 100–160.
Shrines are floored high from t1 regardless (0.90 before t80, 0.80 after); once
past `zeal_turn`, the floor ramps 0.80 → 1.00 over 120 turns **for as long as the
clan is short of `avatar_threshold`**. Deliberately *not* a fixed turn number —
one hard-coded trigger makes all 8 clans pivot in lockstep.

**b) `defend_enclave` is proportional, not a permanent lock.**
`_enclave_defense_floor()` still computes the full-alarm values (0.75 closing /
0.55 holding), but now scales them between `_ENCLAVE_FLOOR_PEACETIME` (0.25) and
that alarm value by a **threat ratio**: attacker count (closing units weighted
double) over `max(2, own_army/6)`. A lone prowler produces a low presence; a real
assault produces full alarm. Peacetime defence is low but never zero.
Intel-token sightings (`unit_spotted` / `rival_position`) were the other half of
the lock — a flat 0.75 from a token up to 5 turns old — and are now damped near
the peacetime baseline and **fade with token age**. Live vision outranks memory.

**c) Gold-cap pressure funds the win path.**
Previously a single `≥65% of cap` step raising only `produce_units` 0.72 /
`research_tech` 0.62 / `construct_building` 0.58 — none of which advance the win
condition, and `produce_units` at 0.72 actively out-competed the shrine spine.
Now a **proportional ramp** from 50% of cap to the cap, applied to:
`construct_building` 0.60→0.92 · `advance_shrines` 0.60→0.88 ·
`research_tech` 0.58→0.82 · `produce_units` 0.55→0.78 · `attack_rival` 0.45→0.70 ·
`upgrade_units` 0.40→0.62 · `build_port`/`train_galley` 0.45→0.72.
Gold is a means, not an end: a full treasury buys buildings, tech and offensives
rather than accumulating. This also resolves the long-standing naval item —
`train_galley`'s 0.60 floor previously lost every tiebreak to the flat 0.72.

Guarded by `tests/engine/test_win_path_pressure.py` (17 tests, each verified to
fail when its fix is reverted).

### 21.2 THE INTEL ECONOMY WAS DEAD — mantras never reached the AI *(08/2026)*

**The single largest defect found to date.** In the 20-game regression
`sim_08_13_2026_19_55` the entire pub/intel subsystem had never executed once:

```
town_visits_total     [0, 0, 0, ...]   every game
village_visits_total  [0, 0, 0, ...]   every game
pub_pints_total       [0, 0, 0, ...]   every game
```

Four independent bugs stacked to produce that:

1. **`generate_pub_npcs()` raised `AttributeError` on every call.** It read
   `clan.name`, but `ClanInstance` has no such attribute (the display name lives
   on the clan *template*). `town_visit_tick()` wrapped the call in a bare
   `except Exception: pass`, so the whole subsystem failed **silently** and
   nothing anywhere reported it. Now fixed, and the three visit branches report
   via `_log_pub_visit_error()` → `PUB_VISIT_ERROR` instead of swallowing.
2. **Villages were never targeted.** There are **18 villages** vs 4 towns;
   `_best_target_for_unit()` considered only towns and castles, so the bulk of
   the map's pubs were invisible to the AI.
3. **Castles always beat towns.** Towns got a distance discount, then castles
   were compared with a bare `d < best_d` against that already-discounted value.
   Castles won nearly every time — `castle_visits` 31–267 per game vs 0 towns.
4. **`_target_pos()` resolved settlement goals against `state.towns` only,** so a
   castle/village id returned `None` and the goal layer and mover disagreed about
   the destination — visible in logs as `goal_id='duskwall'` (a town at 34,11)
   paired with `target=(66,89)` (a castle across the map).

**Why it was fatal:** clans are seeded with exactly 4 of 8 mantras
(`seed_mantra_knowledge`), and a shrine cannot be meditated without its mantra.
With the pub channel dead, the other 4 were unobtainable, physical meditations
capped at ~4 (the distribution peaked *exactly* at 4), and — under the old
`phys >= 4` Avatar gate — the win path was arithmetically closed.

**Also fixed:** `headless_shrine_advance()` filtered its shrine list by mantra
confidence and `return`ed when empty, so a clan that had meditated all its
known-mantra shrines **froze its entire army** — units held `advance_shrines`
while never moving (~90% of units did not change position on any turn after
t200). Movement and meditation-eligibility are now separate concerns: units
travel to any outstanding shrine and hold position; the mantra gate stays where
it belongs, in `meditate_at_shrine_tick()`.

**AI priority:** `gather_intel` now scores on **mantra need** — the count of
unmeditated shrines whose mantra the clan lacks — replacing an `intel_count < 4`
gate that every clan cleared within a few turns and never revisited
(`gather_intel` was 0.9% of all clan goal-turns). The clan-level goal tree floors
`gather_intel` / `seek_mantra` / `build_pub_relationship` proportionally to the
same need, tracking the `zeal_turn` ramp.

Guarded by `tests/engine/test_intel_economy.py` (15 tests, each verified to fail
when its fix is reverted).

**Aggression boost (#163):** Aggressive clans (Fighter, Dwarf, Necromancer): +0.25 attack_rival.
Others: +0.15. Necromancer: night-phase boost (turns 15–25 of 40-turn cycle).
**Opportunistic fight (Sprint 27) ✅:** Any unit adjacent to enemy that hasn't acted issues a combat move (all clans, post-goal).
**Rogue night stealth (Sprint 27) ✅:** t%40∈15–25 → pursues meditating/low-HP targets with +2 ATK bonus regardless of primary goal.

---

## 22. WORLD GENERATION

- 8 enclaves: ring around 100×100 map
- 8 shrines: midpoints between enclaves
- 4 castles: Veilkeep, Thornhaven, Embrace, Ironmere
- 4 towns: 4 drawn from pool of 10 (seeded)
- 4 corner bonuses: ancient_forge (+ATK), arcane_spire (+ARC), sacred_grove (+DEF), rangers_cache (+MOV)
  First clan to hold corner hex uncontested for 1 turn claims permanently. Data: `assets/data/corner_bonuses.json`.
  ⚙️ Claiming effect application pending implementation.
- Dragon egg: Veil Hex, radius 15–20 from center (hidden)
- 2 Dragon lairs: Guardian + Hunter, opposite sides
- Monster enclaves: tier 1/2/3 distributed
- Islands with ruins: re-enabled T60

### 22.1 LAIR / ENCLAVE SPACING — `MIN_LAIR_ENCLAVE_DIST = 8` *(08/2026)*

**No monster lair centre may sit within 8 hex-grid steps of a clan enclave.**

This was unenforced, and it was decisive. `_place_t3_t4_lairs()` built its
`occupied` set from monster enclaves and shrines **only** — clan enclaves were
absent entirely — and the sole test was exact-hex identity (`(pq, pr) in
occupied`), i.e. no distance rule at all. In the seed-5 Atlas run cleric spawned
**4 hexes** from a T3 lair with 3 monsters already inside its starting radius and
was wiped out, chieftain included, **by turn 5**; fighter fell on turn 6. Seed 22
had a lair **2 hexes** from a capital. Three of eight clans died before the game
started, which invalidated every balance figure from those runs.

It was never a matter of luck: pass mouths are chokepoints, and clans are sited on
good terrain near chokepoints, so lair-on-capital is **correlated** and recurs
across seeds.

Three implementation traps, all live at once — worth knowing before touching this:

| trap | consequence |
|---|---|
| `state.clans` is **empty during worldgen** | a guard written against it silently passes for every hex. Read `self._enclave_positions`. |
| **`_hex_dist()` is EUCLIDEAN** despite the name | a lair 6 hex-steps from elf's capital measured 8.49 and slipped through. Use **`_hex_grid_dist()`** — travel time is what endangers a clan. |
| one candidate per sector | rejecting it removed that sector's gatekeeper entirely. Sector selection now keeps **all** eligible pass hexes, outermost first, and falls back (logged as `T3 pass-mouth fallbacks`). |

Applies to both placement paths (`_place_monster_enclaves` and
`_place_t3_t4_lairs`). T4 valley lairs are **skipped** rather than relocated when
too close — a valley is a fixed carved feature. Verified across 8 seeds: minimum
distance ≥ 8, **zero** monsters within 5 hexes of any capital, lair counts steady
at 30–36. Guarded by `tests/engine/test_world_gen.py`.

⚠️ **This changes generated maps for existing seeds.** Runs from before 08/2026 are
not comparable to runs after it.

**Noise params (T60 fix):** 2× octaves, base=0.60, swing=0.38, enclave radius=4.
Natural organic coastline. No perfect-circle artifacts. test_world_gen.py: PASS.

**Map types:** standard | pangea | fractured.

---

## 23. DAY/NIGHT & AUDIO

`client/rendering/day_night.py` + `engine/engine_audio.py`. Visual only (not headless).
**Analytics:** `engine/analytics.py`. Chaos score (0.0–1.0), snapshots, phase transitions, HTML viewer.

### Chaos v2 — "was this game interesting to watch?" *(08/2026)*

Ten independently-normalised terms, each scaled across its **observed** band so
no term is clipped by default. Target band **0.45–0.60**.

| Term | Weight | Band | Source |
|---|---|---|---|
| power volatility | 0.18 | 0.2 → 3.0 | mean power-rank changes between snapshots |
| shrine lead changes | 0.12 | 0 → 8 | `_shrine_lead_changes` |
| combat density | 0.12 | 1.0 → 8.0 /turn | `total_combats / turns` |
| intel economy | 0.10 | 0 → 600 | intel tokens acquired |
| meditation race | 0.10 | entropy | spread of `shrine_meditated` across clans |
| dragon drama | 0.10 | kills 0→2, enrages 0→3 | `dragons_killed`, `dragon_enrages` |
| egg contest | 0.10 | pickups/deliveries/carrier deaths | egg events |
| treasure & items | 0.08 | clears 0→10, items 0→8 | `lair_clears`, `items_found` |
| eliminations | 0.05 | 0 → 5 | `clans_eliminated` |
| upset | 0.05 | binary | winner ≠ shrine leader at t80 |

**Why v1 was replaced.** It had five terms and two were incapable of carrying
information:

- `combat_density` was `min(1.0, combats/turns) * 0.20`, but real rates run
  **1.06–8.5 per turn**, so *every game clipped to the cap* — a literal constant
  across all 20 games of `sim_08_15_2026_00_06`.
- `diplo_turb` divided by `agreements_made`, which **is never incremented
  anywhere in the engine**, so it was always exactly 0.0.

The result inverted the ranking it existed to produce: seed 18 (400-turn
stalemate, 1.06 combats/turn, one lead change) scored **0.443**, while seed 3
(contested shaman egg win at t226, six lead changes) scored **0.337**. Eight
consecutive regressions sat in 0.40–0.44 and never reached the old 0.45–0.65
target, because the instrument could not express the difference.

**Re-scored on the same 20 games:** avg 0.399, range **0.139–0.546**, spread
**0.407** (v1 spread was 0.231), and the ordering is now correct — contested egg
wins on top, dead stalemates at the bottom. `dragon` scores **0.000 in all 20
games** because no dragon has ever been killed; `egg` averages 0.008. Those two
terms are almost pure headroom and are exactly where the game most needs to
improve.

Guarded by `tests/engine/test_chaos_v2.py` (9 tests) — weights must sum to 1.0,
no component may be constant between a dull and an exciting game, and
`combat_density` must not clip across typical rates. **There was no chaos test
at all before v2**, which is how the dead terms shipped.
**Necromancer night boost** (sim): turns 15–25 of each 40-turn cycle = "night phase" combat bonus.

---

## 24. TUTORIAL MODE (#160) ✅

`client/tutorial.py`. Map: 50×50, 4 shrines, Cleric clan, fractal=0.05.
Pre-seeded: 2 of 4 shrine mantras as "direct" knowledge at start.
Dragon: forced stirring at turn 20 if still dormant. Starting gold: 300g. No window penalties.
Friendly Ranger AI clan (mild pressure). Prompts at turns T1/T3/T5/T8/T12/T18/T20/T22/T25.
Completion: EGG_WIN → "Tutorial complete." → `config.tutorial_complete=True`.

---

## 25. SIMULATION SYSTEM  <!-- Last updated T102 2026-07-13 -->

⚠️ **08/28/2026: `simulate/runner.py` is scheduled for a major
consolidation — read `doc/ENGINE_CONSOLIDATION_PLAN_2026_08.md` before
touching this file.** A full audit found `runner.py` contains substantial
game logic that does not belong there per the project's own architectural
rule ("nothing outside engine/ should mutate GameState directly" —
`engine_interfaces.py`): a duplicated game-init sequence (hand-copied
into `client/atlas_map.py` too) and an ENTIRE headless-only dragon wake/
enrage/combat/enclave-assault subsystem with no Atlas equivalent at all
(`DRAGONS_WIN` is consequently unreachable in interactive play today).
Implementation has not started as of this note — the plan doc is the
current source of truth for what will change.

`simulate.py`: Full headless AI-vs-AI. **MAX_TURNS=400** (`simulate/runner.py`).
Win detection order: EGG_WIN → DRAGONS_WIN → CLANS_DEFEAT_DRAGONS_WIN →
LAST_STANDING → STALEMATE. (Renamed 08/27/2026: `DRAGON_WIN` → `DRAGONS_WIN`,
condition fixed from "all units dead" to "all clan enclaves destroyed";
`CLANS_DEFEAT_DRAGONS_WIN` is new — see `assets/md/dragons.md` §7.)

### 25.1 A TURN-LIMIT TIMEOUT IS A STALEMATE *(bugfix 08/2026)*

**`DRAGONS_WIN` requires every clan to be eliminated** (all 8 enclaves
destroyed — see §7 in `assets/md/dragons.md` for the 08/27/2026 fix history).
Reaching the turn ceiling is **never** a dragon win, however awake the
dragon happens to be — this stalemate-vs-dragon-win distinction below is
unaffected by that later fix.

The stalemate branch used to return `"__dragon__"` whenever any dragon was in
`awake|enraged|dominant|destroyer` state at the ceiling. The result was a
regression report reading **`__dragon__ 85.0%`** when in truth **85 of 100 games
never resolved** — every single one at exactly turn 400, several with 4 clans
still alive. Win rates, the scoring table and the chaos score were all computed
over that fiction.

The event now reports `type: "STALEMATE"` with
`subtype: "turn_limit_dragon_active" | "turn_limit"` and a
`dragon_active_at_ceiling` flag — the dragon's state is still recorded, because
"did the dragon wake before the clock ran out" is a useful signal, but it does not
change the outcome. Guarded by `tests/engine/test_spell_targeting.py`.
`_force_dragon_on_avatar()` replaced at T85: on Avatar, each dormant dragon rolls 5% wake (one-time).
Performance: ~20–60s/game. TARGET: avg ≤250t, **chaos 0.45–0.60 (v2 scale)**, EGG_WIN rate >50%.

**T100 Sprint 27 baseline (20 games, seeds 1-20):**
```
Avg turns:    290.6t  ⚠️ (target ≤250t)
Avg chaos:    0.1186  ⚠️ (target 0.45–0.65)
Stalemates:   1/20
Win diversity: 8 different clans won across 20 games ✅
Fighter:      4/20 (20%) ✅  (T83 was 100%)
Rogue:        2/20 (10%) ✅  (T99 was 0 — Sprint 27 fixed)
Cleric:       6/20 (30%) ⚠️  dominant (passive atk floor raised → shrine rush)
Dragon wake:  avg t238  range t100–t350
Kill attr (113 total/20g): dwarf 1.9/g, necro 1.0/g, fighter 0.9/g, rogue 0.35/g ✅
Adjacent encounters: active per-game, logged in result dict
```
Raw: `simulation_results/1783990448_t100_1-20.json`
HTML: `simulation_results/t100_report.html`  (generated by `tools/gen_t100_report.py`)

---

## 26. PENDING WORK (as of T100)

### Fixed since T83
- ✅ Fighter dominance — ATK 4→3, attack_rival 0.9→0.70
- ✅ Baby dragon spawn loop — fixed T99
- ✅ Kill attribution logging — live and tracking in sim output
- ✅ Rogue 0 kills / 0 wins — fixed Sprint 27 (2 wins, 0.35 kills/game)
- ✅ EGG_WIN = 0 — fixed Sprint 26/27 (positive rate in recent runs)
- ✅ Dragon-avatar hard-force → 5% probability roll on Avatar (T85)

### Active issues (T102 — pending full 50-game results)
- **Chaos still low** ⚠️ 0.009–0.153 in early Sprint 28 games. Fast EGG_WINs end before chaos accumulates.
- **EGG_WIN rate** ✅ 6/7 early games are EGG_WIN — dramatic improvement from 0% at T83.
- **Turn length** avg ~175t in EGG_WIN games, 393t in LAST_STANDING outlier (seed 7).
- **Proximity wake firing rate** — pending 50-game data to measure actual dragon wake from proximity.

### Not yet coded (design-locked)
- #218 Universal shrine meditation cross-bonuses (table LOCKED T84, see §7)
- #216 Alliance betrayal + shrine bonus strip
- #217 Conquest spoils
- #195 Discrete tier table
- #204 Dragon Slayer Win
- #188 Diplomacy depth
- #201 Dragon genetics system
- Contemplation Hall, NPC intel teaching
- Interior system ✅ coded T103 (engine_interior_gen.py — see §19)

### Open questions for Claude Web (T101)
Q1: Chaos 0.1186 — is low chaos acceptable when EGG_WINs end games fast?
Q2: Cleric 30% dominant — reduce advance_shrines weight, or add shrine-contest cost?
Q3: Adjacent encounter — correct Sprint 27 interpretation?
Q4: Sprint 28 direction: chaos tuning, #218 shrine bonuses, or Cleric balance?
Q5: Any corrections to this document?

---

## 27. GAME STATE FIELDS QUICK REFERENCE

Key `GameState` fields (✅ from game_state.py):
```
state.clans: dict[str, ClanInstance]       state.units: dict[str, UnitInstance]
state.shrines: dict[str, ShrineInstance]   state.world_map: WorldMap
state.dragon_egg: Optional[DragonEgg]      state.dragons: list[DragonInstance]
state.structures: dict[str, StructureInstance]
state.improvements: dict[str, ImprovementInstance]
state.monster_enclaves: dict[str, MonsterEnclave]
state.villages: dict[str, VillageInstance]
state.turn_number: int                      state.combat_log: list[dict]
state.dragon_wins: bool                     state.egg_hatch_countdown: Optional[int]
state.hoard: Optional[HoardState]           state.dragon_type_revealed: dict[str, bool]
state.effective_stat(unit, stat)  ← base + shrine + item + tech + fort bonuses
```

`ClanInstance` key fields: `avatar_status`, `shrines_meditated_count`, `shrine_bonuses`,
`seeker_built`, `seeker_active_unit_id`, `active_alliances`, `techs_researched`,
`mantra_knowledge: dict[shrine_id, float]`, `alliance_duration_multiplier`.

---

## 29. POSSIBLE LATER — Design-Locked, Low Priority

These features are fully designed and approved but intentionally deferred. Document them here so they are not lost and can be picked up in a future sprint without re-design.

### #218 Universal Shrine Cross-Bonuses
Every shrine grants a secondary bonus to ANY clan that meditates it (including the owning clan). Separate from the primary stat bonus.

**Confirmed bonuses (T84 Q7):**
| Shrine | Primary | Universal secondary |
|--------|---------|---------------------|
| Valor (Fighter) | +ATK | +1 ATK to meditating unit (personal) |
| Honour (Elf) | +ARC | +1 VIS (personal, no allies) |
| Compassion (Cleric) | +DEF | +1 HP max |
| Fortitude (Dwarf) | +HP | +1 DEF |
| Spirituality (Ranger) | +MOV | +1 MOV (personal) |
| Loyalty (Rogue) | +STL | +1 STL (personal) |
| Humility (Monk) | +RES | +1 RES |
| Temperance (Druid) | +LCK | +5% crit (personal) |
| Sacrifice (Necromancer) | +ATK(weak) | Dark Resonance threshold −1 (deaths per +ATK tick: 3→2) |
| Wisdom (Mage) | +VIS | +1 INT (intel faster) |
| Honesty (Bard) | +INT | +1 INT_STAT + bribe costs −5g |
| Justice (Shaman) | +ARC(elem) | AoE radius +1 (personal, stacks with Storm Spire) |

**Implementation note:** Apply in `engine_mantras.py`, `_apply_shrine_bonus()`. Guard with `if clan.#218_enabled`.

### #216 Alliance Betrayal + Shrine Bonus Strip
When Clan A betrays Clan B's alliance:
- Any shrine bonuses Clan A earned from Clan B's shrine are stripped immediately (`state.shrine_bonuses[shrine_id].remove(clan_a_id)`)
- If Eternal Alliance: ×2 penalty: both primary and #218 secondary bonuses stripped
- Any not-yet-earned #218 bonuses permanently denied for that shrine_id

**Implementation note:** `engine_diplomacy.py → _on_alliance_betrayal()`. Avatar credit (#199) is NOT affected.

### #217 Conquest Spoils
When Clan A eliminates Clan B (enclave walls breached, all units dead):
- Clan A receives 30% of Clan B's current gold (minimum 0, maximum gold_cap)
- Clan A receives 1 shrine stat point from Clan B's highest-meditated shrine (permanent)
- Log event `CONQUEST_SPOILS`

**Implementation note:** `engine_gameplay.py → _check_elimination()`. Add `spoils_gold` and `spoils_shrine_id` to elimination result dict.

### #204 Dragon Slayer Win Condition ⚠️ SUPERSEDED 08/27/2026 — see below
This original spec proposed a specific-clan-wins variant (the clan that
landed the killing blow on the last dragon wins outright, +1500 score,
150g tribute to all clans). **What actually shipped is different** — the
user's 08/27/2026 clarification specified a no-single-winner "world saved"
outcome instead: **`CLANS_DEFEAT_DRAGONS_WIN`** (see `assets/md/dragons.md`
§7 and `comms/AEVUM_GAME_REFERENCE.md` §2). It fires when the egg has
hatched AND `all(d.state == "slain" for d in state.dragons)` AND no live
baby dragons remain — no specific clan is credited as "the winner"
(`winner_clan_id` stays unset/None for this outcome), no +1500/tribute
bonus economy, and it is gated on the egg having hatched (destroying the
egg pre-hatch is `EGG_WIN`, a completely different path with its own
existing scoring). The old spec's score/tribute/victory-screen mechanics
below are NOT implemented and are not currently planned — left here only
for historical reference in case that flavor is revisited later.

If BOTH dragons (Guardian AND Hunter) are slain in the same game (OLD,
unimplemented, specific-clan-credit variant):
- The clan that slew the final dragon wins immediately (EGG_WIN is cancelled even if in progress)
- Score: +1500 (instead of EGG_WIN's +1000)
- All clans receive `dragon_slayer_tribute` = 150g (dragon deterrence disbanding)
- Victory screen: "The Dragon Age is over. Aevum breathes free."

**Implementation note:** `simulate.py → _check_win_conditions()`. Add `DRAGON_SLAYER_WIN` to win type enum. Check `all(d.is_dead for d in state.dragons)` before EGG_WIN check.

### #195 Discrete Tier Table
Post-game scoring tier assignment based on Power Score relative to alive non-winner average:

| Multiplier | Tier | Label |
|-----------|------|-------|
| ≥ 2.5× avg | +5 | Legendary |
| 1.5–2.5× | +2 | Dominant |
| 1.0–1.5× | +1 | Above Average |
| 0.5–1.0× | 0 | Average |
| 0.25–0.5× | −1 | Below Average |
| < 0.25× | −2 | Defeated |

**Implementation note:** `simulate.py → _compute_final_scores()`. Apply after all other scoring.

### #188 Diplomacy Depth
Extends world-map alliance system with two new agreement types negotiated by Scout or Chieftain (not requiring pub or castle):

1. **Shared Threat Declaration**: Both clans designate a mutual enemy. While active (8t): +1 ATK to both against designated enemy, auto-share all T1 intel about that enemy.
2. **NAP + Shrine Pass**: Non-aggression for 6 turns + each clan may enter the other's sacred zone (not meditate — observe only). Requires Chieftain present.

**Implementation note:** `engine_diplomacy.py`. New functions `propose_shared_threat()` and `propose_nap_shrine_pass()`. Initiated via Chieftain action or Scout adjacent to rival unit.

### #201 Dragon Genetics
Dragon type for a given game is not purely random — it follows genetic dominance rules:

- If Gold or Silver is one of the two active dragon types → that type is always the **Guardian** (dominant)
- If both Gold and Silver are present (rare: only if both are in the 5-type pool for this seed) → Gold is Guardian, Silver is Hunter
- Otherwise: Guardian and Hunter type chosen 50:50 from the seed pool

**Implementation note:** `engine_game_start.py → _assign_dragon_types()`. Add dominance check before random assignment.

### Contemplation Hall (Scholarship tech)
Buy or sell shrine credits inside a town's Contemplation Hall room.

**Sell:** One clan sells a shrine "credit" (Avatar tick only, no stat bonus) to another clan.
Price tiers: 1 buyer=200g, 2=150g, 3=100g, 4+=60g (paid by buyer).

**Buy:** Clan buys a credit toward Avatar from a seller.
Price tiers: 1 credit=400g, 2=300g, 3=200g, 4+=120g (paid by buyer).

**Rules:** Can only buy credits for shrines the buyer has NOT meditated. Cannot buy own shrine's credit. Max 3 credits purchased per clan per game. Seller gains gold from buyer. Clerk NPC (the Keeper) witnesses and validates the transaction.

**Implementation note:** `engine_interior.py → action_buy_shrine_credit()` / `action_sell_shrine_credit()`. Add `shrine_credits_purchased[shrine_id]` to `ClanInstance`.

### NPC Intel Teaching (Full Simulation)
**#193 COMPLETE** — NPC teaching is now wired into the sim:
- `seed_mantra_gossip_pools()` injects `mantra_fragment` (T1, conf=0.40) into all town/village gossip pools and `mantra_teaching` (T2, conf=0.70) into castle pools at game start (notice board / Scriptorium source).
- `town_visit_tick()` fires each turn: any unit on a town/village/castle hex triggers `ai_pub_visit()` → `action_bribe("shrine")` → surfaces a mantra token → `_sync_mantra_from_intel()` writes conf to `clan.mantra_knowledge`.
- The T104 meditation gate now truly blocks at conf=0.0. The proximity stub has been removed.
- `_ai_seek_mantra()` (#192) routes to nearest settlement when conf=0.0, emitting `visit_town` actions that drive the pub system.

**Design:** In simulation AND player game, mantra intel is distributed exclusively via:
- Pub barkeep (Regular tier+): T1 shrine_vague tokens
- Scholar NPC (town library): T2 mantra_known tokens at conf 0.65
- Keeper NPC (Contemplation Hall): T3 mantra_direct tokens at conf 1.0 (costs 100g)
- Overhear mechanic: conf − 0.25 from adjacent NPC dialogue
- Prisoner rescue: T3 intel for dungeon + T2 intel for 2 shrines

**Simulation note (#193 ✅):** AI `seek_mantra` goal routes to nearest settlement when conf=0.0, bribes for mantra intel (50g, "shrine" topic), then returns to the target shrine with conf ≥ 0.40 once intel is received. Proximity stub removed.

---

## 29. CLAN LORE & INHERENT RIVALRIES ✅

Full canonical lore: `assets/md/clan_lore.md`. Implemented: `engine/engine_sentiment.py`.

### The 3 Inherent Rivalries (seeded at game start)

| Pair | Direction | Starting Sentiment | Lore |
|---|---|---|---|
| **Dwarf ↔ Elf** | Mutual | rivalry 0.50, hostility 0.35, grudge 0.30 (each) | Ancient border dispute over mountain passes vs forest territories. Three generations, no resolution. |
| **Necromancer ↔ Mage** | Mutual (Necro stronger) | Necro: rivalry 0.45, grudge 0.40, hostility 0.30 / Mage: rivalry 0.40, hostility 0.25, grudge 0.30 | The Arcanum expelled the first necromancers for "impure study." Mages say it was safety; necros say it was turf protection. Both are partly right. |
| **Fighter → Rogue** | One-sided (Fighter only) | Fighter: hostility 0.40, rivalry 0.30 / Rogue: nothing | Fighters have a code — fight openly. Rogues stab from behind. Fighters are offended. Rogues are amused. |

### Neutral Clans (hate no one)
**Ranger** — judges terrain, not clans. **Cleric** — compassion is their virtue; hatred is a wound that spreads. **Monk** — sides are ego in political form. **Druid** — grievances are with actions, not identities. **Bard** — grudges are bad for the information network. **Shaman** — observation before judgment; proportionate response always.

### Mechanical Implementation

**`CLAN_INHERENT_RIVALRIES`** dict in `engine_sentiment.py` — maps clan_type → target_clan_type → sentiment dimension values.

**`init_inter_clan_sentiments(state)`** — seeds inherent rivalries at game start. Only applies if both clans are active in this game. Prints `** INHERENT_RIVALRY` to game log.

**`is_inherent_rival(clan_a, clan_b) → bool`** — directional check (fighter→rogue: True; rogue→fighter: False). Used by AI and diplomacy.

**`inherent_rival_aggression_boost(clan_id, target_clan_id) → float`** — returns +0.25 if target is inherent rival. Applied to `attack_rival` goal evaluation. Rival AIs always prefer fighting their nemesis when opportunity exists.

**`rival_alliance_is_blocked(state, clan_a, clan_b) → bool`** — returns True if the pair can't afford peace. Rivals need **8 INF each** (RIVAL_ALLIANCE_INF_COST) to form an alliance. Peace is possible — just expensive. Engine_diplomacy calls this before forming any alliance.

**Sentiment decay floors**: Inherent rivalries floor at 30% of initial value (`_INHERENT_FLOOR_RATIO = 0.30`). Normal decay never fully erodes them.

---

## 30. UNDERGROUND ECONOMY SYSTEM ⚙️ (data layer complete; mechanics pending)

Full spec: `assets/md/underground_economy.md`, `assets/md/underground_npcs.md`.

### Influence Points (INF) ⚙️

Clan-level resource on `ClanInstance.influence_points`. **Gate, not cost** — merc companies require a minimum INF to hire, but INF is not spent on hire. INF decays −1/20 turns (min 0).

| Source | INF Gained |
|---|---|
| Bribe a Politician | +2 |
| Shrine meditation (first time) | +1 |
| Defend allied unit (witnessed) | +1 |
| Broker a trade | +1 |
| Shadow Accord contracted | +1/turn |
| Gilded Fang contracted | +2/turn |

### Guard Suspicion & Shady Rep ⚙️

**`guard_suspicion`** — per-clan, per-town int on `TownInstance`. Tracks guard-specific sketchy behaviour. Threshold ≥3: 30% confrontation check on movement. Threshold ≥5: guards check every turn.

**`shady_rep`** — per-clan, per-town counter. Affects legitimate NPC attitudes. ≥3: stranger tier pricing (+10%). ≥5: Politician refuses. ≥7: Lady of Night refuses new visits.

Both decay naturally. Both reset via 100g goodwill payment to town regent.

### 8 New Underground NPC Types ⚙️

| NPC | Effect | Risk |
|---|---|---|
| **Lady of the Night** | +1 HP to visiting unit | None directly; shady_rep 0.25/visit |
| **Shady Guy** | T1–T2 intel; 30% double-agent roll (false info) | guard_suspicion +1 if guard within 3 hex |
| **Juggler** | Watch → +1 INT, +1 DEX (knowledge bleed eligible) | None |
| **Hackey Sack Person** | Watch → +1 DEX, +1 WIS (knowledge bleed eligible) | None |
| **Dealer** | Sells 6 exclusive items (drugs/reagents) | guard_suspicion +0.5 talk / +1 buy |
| **Fence** | Resells sold shop items at 50–60% off | guard_suspicion +1; 25%+ jail chance |
| **Politician** | +2 INT, +2 WIS, +2 INF per bribe (200–400g scaled) | shady_rep +0.25; won't deal if shady_rep ≥5 |
| **Criminal** | Sells anything; hireable solo mercenary | guard_suspicion +1.5; flees if guard ≤2 hex |

**Knowledge Bleed** (Juggler/Hackey Sack/Politician): INT/DEX/WIS bonuses can spread to adjacent allied units after 3 shared turns (15% roll/turn). HP bonuses (Lady of Night) are NOT bleedable.

**Fence inventory lifecycle**: Items sold to blacksmith → pool → fence (after 5–10 turns). 15% damage chance on entry. Max 5 items per town. Priced 50–60% of base value.

**Jail roll formula**: `base 25% + (suspicion × 5%) − (stealth × 8%)`, clamped 5%–75%.

### 6 Dealer-Only Items ✅ (engine_items.py)

| Item ID | Effect | Price |
|---|---|---|
| `mystery_powder` | +2 ATK for 4t. Consumable. NSFW name: "Rage Dust" | 80g |
| `crimson_tonic` | +2 MOV for 3t. Consumable. | 70g |
| `shadow_dust` | +1 STL + invisible 2t. Consumable. | 90g |
| `clarity_draught` | +1 WIS permanent. Consumable. | 150g |
| `reagent_cache` | High trade value + ritual eligible. | 120g |
| `black_salve` | Clears 1 negative status. Consumable. | 100g |

All have `source: ["dealer"]`. Never appear in shops or on the map. NSFW item names render from `nsfw_name` field when `config.nsfw_dialogue = True`.

---

## 31. MERCENARY COMPANIES ✅ (engine_mercenary.py)

Full spec: `assets/md/mercenary_companies.md`. Module: `engine/engine_mercenary.py`.

INF threshold is a **gate, not a cost** — clan must HAVE the INF, does not spend it.

| Company | INF Gate | Upfront | /Turn | Slots | Phase | Specialty |
|---|---|---|---|---|---|---|
| **The Broken Road Company** | 10 | 150g | 12g | 3 | Any | Generalist |
| **The Thornwood Riders** | 15 | 200g | 18g | 3 | Early (40t max) | Cavalry |
| **The Iron Veil** | 25 | 400g | 28g | 2 | Mid | Siege |
| **The Shadow Accord** | 20 | 300g | 22g | 2 | Any | Stealth |
| **The Ember Tide** | 30 | 500g | 35g | 2 | Mid | Battle Magic |
| **The Gilded Fang** | 40 | 1000g | 60g | **1** | Late | Elite |

**Named captains**: Kael (Broken Road), Liss Thornwood (Thornwood Riders), Commander Aryn (Iron Veil), Voss (Shadow Accord), Archon Drevya (Ember Tide), Marshal Oryn Vel (Gilded Fang).

**Sentiment rate factor**: Company sentiment toward a clan adjusts pricing: ≥+50 → 0.85×; ≥+20 → 0.92×; neutral → 1.00×; −20 to −39 → 1.15×; ≤−40 → 1.30× (and near-refusal).

**Insolvency**: If a clan can't pay per-turn rate, company terminates contract and takes −15 sentiment. Early dismissal: −8 sentiment. Natural expiry: +5 sentiment.

**Gilded Fang exclusivity**: max_contracts = 1. Only one clan can hold them at a time.

**Public API**: `can_hire(state, clan_id, company_id)`, `hire_company(...)`, `dismiss_company(...)`, `merc_gold_drain_tick(state)`, `merc_expiry_check(state)`, `get_active_contracts(state, clan_id)`.

---

## 28. DOCUMENT MAINTENANCE

**Update rule:** When a token arrives from Claude Web, Cline updates only changed sections
and bumps the "Last updated" date at the top. Do NOT rewrite unchanged sections.

**Files verified at T103:** game_state.py, clans.json, virtues.json, engine_mantras.py,
engine_dragon.py, engine_ai.py, simulate.py, clans.md, structures.md, technology.md,
economy.md, combat.md, movement.md, magic.md,
engine_intel.py, engine_pub.py, engine_castle.py, engine_interior_gen.py, engine_npc.py,
assets/dialogue/pub_dialogue.json, assets/dialogue/castle_dialogue.json,
assets/dialogue/lair_dialogue.json, assets/md/intel.md, assets/md/diplomacy.md,
assets/md/interiors.md.

**The ONE file to load:** `comms/AEVUM_GAME_REFERENCE.md`
**Active task list + Q&A:** `comms/AEVUM_TOKEN.md` (current) · archived: `comms/AEVUM_TOKEN_100.md`
