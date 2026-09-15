# Dragons

Canonical reference for the dragon system: identity, types, escalation,
egg/hatch mechanics, and the baby-dragon growth arc. Cross-references
`comms/AEVUM_GAME_REFERENCE.md` §9 (narrative/history) — this file is the
data-and-mechanics source of truth; keep both in sync when either changes.

Code: `engine/engine_dragon.py` (mechanics), `engine/game_state.py`
(`DragonInstance` dataclass), `engine/engine_headless.py` (egg-hatch spawn
paths + win-condition check). No dedicated `dragons.json` exists — dragon
type/stage tables live as Python dicts in `engine_dragon.py`
(`DRAGON_TYPE_CONFIG`, `HATCH_TURNS`, `BABY_HP`, `DRAGON_GROWTH_STAGES`).

## 1. Two kinds of dragon in this game

There are **two entirely separate dragon populations**, and they must not be
confused:

1. **Guardian and Hunter** — the two `DragonInstance` objects created at game
   start (`startup_engine.py`). **These are ALWAYS adults/ancients.** They
   never grow and have no growth stage — they only *escalate combat
   intensity* (§3 below) as their HP drops. Guardian defends the egg zone
   (patrol_radius 10); Hunter roams wider (patrol_radius 20) and becomes the
   **Destroyer** if Guardian is slain first.
2. **Baby dragons** — `UnitInstance` objects with `unit_type == "baby_dragon"`,
   hatched mid-game from the dragon egg (or the hidden second clutch). These
   **do** grow, through three named stages (§5). They live in `state.units`,
   not `state.dragons`, and are a completely different code path from
   Guardian/Hunter.

If the dragon egg is never found and hatched before the game ends, no baby
dragon ever exists — Guardian and Hunter are the only dragons in that game.

## 2. Dragon types (5 colors, assigned per-seed)

Guardian and Hunter each independently roll one of 5 types; the roll is
weighted so the two tend to differ (Guardian favours Gold/Silver, Hunter
favours Red/Blue) but any combination is possible.

| Type | HP bonus | Wake mult | Special |
|------|----------|-----------|---------|
| Red | +0 | ×1.5 | Never retreats. Enrages early, at 66% HP (not the usual ≤12 HP). Breath leaves a burning hex (1 dmg/turn, 3 turns). |
| Green | +0 | ×0.7 | −30% wake chance near forest. Retreats at 40% HP, heals 3/turn, returns at 80%. Breath entangles (rooted 2t). |
| Blue | +0 | ×1.0 | Hunts Seekers preferentially, even while merely AWAKE (all other types only prioritise carriers/seekers once FOCUSED+). Lightning breath chains to adjacent metal-armour units. Lightning Arc parting shot on retreat. |
| Gold | +5 (Guardian 35 / Hunter 27) | ×0.6 | Dragon Orb has 50% fail chance against it. "Noble" retreat — will not retreat if a Seeker is within radius 12 of the veil (egg-safe only). Breath bypasses Ancient Armour. |
| Silver | +0 | ×1.0 | Reduced detection radius. Weapons (Dragon Lance/Sword) deal −1 damage against it. Ice zone: radius 6 around its lair deals 1 dmg/turn + slows units 2 turns. |

Base HP: Guardian 30, Hunter 22 (before type HP bonus).

## 3. Combat escalation (Guardian & Hunter only — this is NOT growth)

Both Guardian and Hunter are adults from turn 1. What changes as a fight
progresses is combat *intensity*, driven purely by remaining HP%:

| State | HP threshold | Changes |
|-------|-------------|---------|
| DORMANT | — | Inactive, in lair. Wakes via checkpoint schedule or proximity roll (§4). |
| STIRRING | — | 3–7 turn transitional state after waking, before becoming active. |
| AWAKE | — | Standard vortex patrol orbit, base attack ranges. |
| FOCUSED | ≤ 80% HP | Wider orbit (+1 radius), +1 to all attack ranges, lunge starts prioritising Seekers/carrier. |
| ANGRY | ≤ 50% HP | Intercepts unit clusters, +2 ranges, tail/lunge cooldowns drop to 1 turn. |
| ENRAGED | ≤ 12 HP (Red: ≤66% HP) | All-out assault (Sentinel for Guardian / enclave assault for Hunter), +3 ranges, all cooldowns = 1. |
| RETREATING | HP = 0 | One-tick transitional death animation; cannot be attacked. |
| SLAIN | permanent | Token removed forever. 500g (Guardian) / 300g (Hunter) awarded. Central-zone fog lifts. Dragon-Slayer title (+2 ATK permanent) to the killing blow's unit. Never returns. |

Also enrages immediately (regardless of HP) the instant the egg is picked
up — `reason=egg_carried` — beginning **Egg Pursuit** of the carrier.

**Ancient Armour**: negates the first 5 damage per turn, shared across ALL
attackers that turn (not per-hit) — see `comms/AEVUM_GAME_REFERENCE.md` §9.0
for the full attacker-count balance table and §9.1 for the per-turn-vs-per-hit
bugfix history.

Attacks: **Breath** (cone, type-flavoured extra effect per table above),
**Tail sweep** (adjacent/short-range), **Lunge** (dash + big hit, targets
egg carrier/Seekers once escalated).

## 4. Dragon wake schedule

Dormant until woken. Two independent triggers run every turn:

**Checkpoint schedule** (probability × type's `random_wake_mult`), no wake
before turn 50:

| Turn | Base probability |
|------|-------------------|
| t50 | 2% |
| t100 | 4% |
| t150 | 8% |
| t200 | 15% |
| t250 | 25% |
| t300 | 35% |
| t350 | 50% |
| t400 | FORCED (guaranteed wake) |

**Proximity wake**: any unit within 5 hexes of a dormant dragon's lair rolls
a 7%/turn wake chance × a stealth multiplier (Scout 0.6, Seeker 0.5, Ranger
0.35, Rogue 0.25, Ranger+Wolf 0.45, +Eagle 0.30). No wake before t50 here
either. Runs independently of the checkpoint schedule (both can fire).

**Avatar step-up**: the instant any clan achieves Avatar, each dormant
dragon gets one immediate 5% wake roll.


## 5. The egg, hatching, and the baby-dragon growth arc

### 5.1 Egg hatch timer

The dragon egg is cosmically stable (countdown paused) until the egg is
picked up by a Seeker (countdown resets) **or** at least one clan has
achieved Avatar — no natural hatch can happen before that. Once ticking on
the ground, hatch turns depend on type:

| Type | Hatch turns | Hatchling HP |
|------|-------------|--------------|
| Red | 6 | 20 |
| Blue | 6 | 20 |
| Silver | 7 | 20 |
| Green | 8 | 24 |
| Gold | 10 | 30 |

The egg is **one-shot per game** (`egg_hatched_once` flag) — after the
first hatch it never resets or spawns again via this path. Live baby
dragons are capped at 3 concurrent (further hatch attempts are suppressed,
logged as `EGG_HATCH_SUPPRESSED`).

### 5.2 Hidden second clutch (Hunter's secret egg)

Independent of the primary egg: the Hunter's own clutch is hidden inside a
specific T3 monster lair, chosen at game start. It hatches when **any**
non-monster unit stands on that lair's boss hex after the boss has been
defeated — a "disturbed the nest" trigger. Fallback: forced spawn at turn
450 if never triggered. Shares the same 3-concurrent-baby-dragon cap as the
primary egg. Uses the Hunter's dragon type for its stat table.

### 5.3 Growth stages — HATCHLING → ADOLESCENT → ADULT

This is the process the user asked to have documented explicitly: **a baby
dragon is not "born adult."** It hatches as a fragile hatchling and grows
through two further stages, plateauing at ADULT. This is the ONLY dragon
growth in the game — Guardian and Hunter (§1) never go through this.

`engine.engine_dragon.DRAGON_GROWTH_STAGES` (age is turns since hatching):

| Stage | Min age (turns) | HP multiplier (vs. hatchling base) | ATK bonus | MOV bonus |
|-------|------------------|--------------------------------------|-----------|-----------|
| Hatchling | 0 | ×1.0 | +0 | +0 |
| Adolescent | 20 | ×1.5 | +2 | +1 |
| Adult | 50 | ×2.0 | +4 | +2 (**hard cap — no growth past this stage**) |

Stats are recomputed fresh from `(base_hp_at_hatch, current_stage)` every
time the stage actually changes — not accumulated turn-by-turn — so it is
safe to call the growth tick multiple times per turn and the sequence is
fully deterministic from age alone.

**Breath attack unlock** is a separate milestone, independent of the stage
plateau: at **age 30 turns**, any baby dragon (whatever stage it's in at
that age) gains a breath attack — 3 damage, range 2, 3-turn cooldown.

Stage transitions are logged as `DRAGON_STAGE_PROMOTED` (`from_stage`,
`to_stage`, `age`, `hp_max`) in `state.combat_log`, alongside the existing
`BABY_DRAGON_SPAWNED` (hatch) and `BABY_DRAGON_BREATH_UNLOCKED` (age 30)
events. A promoted baby dragon keeps `unit_type == "baby_dragon"` — the
stage lives in `unit.status["dragon_stage"]`, it does not become a new unit
type or transform into a third `DragonInstance`.

*History*: prior to 08/2026 this tick incremented stats forever in fixed
+2 HP / +1 ATK / +1 MOV steps every 10 turns with no named stage and no
ceiling — a hatchling that survived to turn 300+ would have absurd,
unbounded stats. Replaced with the discrete 3-stage table above, verified
by `tests/engine/test_dragon_growth_stages.py` (stage boundaries, promotion
events, hard plateau past ADULT, idempotent same-turn calls, and
confirmation that Guardian/Hunter `DragonInstance` objects are never
touched by this tick).

## 6. Dragon Orb, Hoard, and other artifacts

- **Dragon Orb**: compels the nearest non-slain dragon toward the holder for
  2 turns; holder is rooted for those 2 turns. Gold dragons resist 50% of
  the time. If the holder dies while compelling, 50% chance the orb
  shatters.
- **Dragon Hoard**: revealed only after BOTH Guardian and Hunter are slain.
  Guardian's lair holds the primary hoard (1500–3000g + 2–4 T3 items);
  Hunter's lair holds the secondary (500–1000g + 1–2 items). Depletes over
  8–12 total collections; 3 T3 monsters guard each lair.
- **Hidden dragon type**: a clan doesn't know a dragon's exact color until
  it's revealed (direct sighting, Dragonlore Tablet, or ≥0.70 confidence
  intel) — shown as "???" until then. The end-of-game victory screen always
  shows the real type regardless.
- Counterplay arsenal (Dragonbreaker Lance, etc.) and the exact attacker-count
  balance table for killing an adult dragon are in
  `comms/AEVUM_GAME_REFERENCE.md` §9.0 and §9.2.

## 7. Dragon-related win conditions (08/27/2026)

Three distinct outcomes involve dragons; do not conflate them:

- **`EGG_WIN`** — a clan's Avatar-status carrier destroys the dragon egg at
  its own home shrine **before it ever hatches**. No dragon offspring ever
  lived; this is purely the standard win path (§5.1). Not new — documented
  here only to contrast with the two below.
- **`DRAGONS_WIN`** — the dragons torch the map: **every one of the 8 clan
  enclaves is destroyed** (`clan.is_eliminated` true for all clans).
  Monsters never attack enclaves — only a dragon's enclave-assault attack
  (or a rival unit's direct `attack_enclave()`) reduces `enclave_hp` to 0
  and calls `destroy_enclave()` — so total enclave loss can only happen via
  dragon involvement. A clan war can eliminate rival army units but never
  their enclave, and "one clan survives an all-out war" is the separate
  `LAST_STANDING` outcome, not this one. Returned internally as the
  `"__dragon__"` sentinel from `check_win()`, classified as `DRAGONS_WIN` by
  `simulate/runner.py`.
  *History*: prior to 08/27/2026 this required a literal zero alive
  non-monster units across the ENTIRE game (near-unreachable — surviving
  clans keep producing new units even while losing) and only checked the
  legacy `state.dragon` attribute (Guardian only, never Hunter) — so a
  Hunter-only rampage could never trigger it. Measured before the fix: in a
  40-game batch, a dragon was awake in 100% of stalemates and enraged in
  53% of them, actively hunting/killing clans every one of those games, yet
  `DRAGON_WIN` was 0/40. Fixed to check `all(c.is_eliminated for c in
  state.clans.values())` against the real dragon roster.
- **`CLANS_DEFEAT_DRAGONS_WIN`** — the egg hatched (so a hatchling dragon
  existed in the world), and every dragon that has ever existed this game
  is now dead: Guardian slain, Hunter slain, and no `baby_dragon` unit
  (from the primary hatch or the hidden second clutch) still alive. This is
  the "world made permanently dragon-free" ending, distinct from `EGG_WIN`
  (destroying the egg before any dragon offspring is born). Returned as the
  `"__dragons_slain__"` sentinel; `state.egg_hatched_once` gates it so a
  same-game pre-hatch double-adult-kill (e.g. via unlucky Dragon Orb play)
  cannot trigger it — that scenario has no hatchling to defeat and isn't a
  "world rid of dragons forever" moment in the same sense.

Guarded by `tests/engine/test_dragon_win_conditions.py` (8 tests): both new
win types fire only under their exact conditions, partial elimination /
un-hatched eggs / surviving baby dragons correctly do NOT trigger them, and
both events reach `state.combat_log` (not just `analytics.events`) so they
are visible in every game's `.jsonl` — the same analytics-vs-combat_log gap
previously found and fixed for `DRAGON_DAMAGED` and `EGG_DELIVERED`.

### 7.1 Why EGG_WIN is the primary, "clean" ending (narrative justification)

A fair question about `EGG_WIN`: destroying the egg does not kill Guardian
or Hunter. Both adults are exactly as alive, and exactly as dangerous, the
moment after the egg burns as they were the moment before. So why does the
game treat this as *the* win — the intended default outcome — rather than
a partial one?

Because `EGG_WIN` was never a victory over the dragons. It is a victory
over *dragon extinction as a threat*. Per `assets/md/lore.md` / the
prologue: Guardian and Hunter are not a species, they are its **last two
members**, and they have spent three hundred years in total stasis doing
nothing but guarding one clutch — because the alternative (open war on
the clans, again) is a fight they learned, the hard way, not to start.
Their entire strategy is patience: outlast the clans' attention, let the
egg hatch quietly, and let dragonkind continue somewhere the clans forgot
to look.

Destroying the egg does not touch their combat capability. It ends their
*future*. Two adults, aging, still guarding — now guarding nothing, with
no possible path to a third dragon ever existing again. That is why it
counts as winning the whole conflict, not just round one: the existential
stakes the clans actually feared — "a second cataclysmic war, but next
time with dragons who out-breed us" — are permanently foreclosed the
instant that shrine fire takes the last egg. The clans did not need to
beat two ancient, battle-scarred predators in a fight the in-game balance
table says a small force cannot win (§9.0) — they found the one point
where the dragons were actually vulnerable: the next generation, sitting
still and undefended. Out-maneuvering an enemy you cannot beat in open
combat is not a lesser victory in a story about avoiding a second
cataclysm — it is the *smarter* one.

This also gives the other two win conditions distinct narrative weight,
not redundancy:

- **`EGG_WIN`** — the clean ending. Fewest lives lost, extinction assured,
  Guardian and Hunter simply... continue, purposeless, forever fewer.
- **`DRAGONS_WIN`** — the clans were too slow, too divided, or provoked
  open war before reaching the egg, and lost the second cataclysm the
  prologue says "would not be survived."
- **`CLANS_DEFEAT_DRAGONS_WIN`** — the egg hatched before the clans acted
  (or they let it, gambling on brute force instead of the clean ending),
  and now the only way to end the threat is the hard way: hunt down and
  kill Guardian, Hunter, and every hatchling in open war. Harder to
  achieve, higher cost, and the war-that-should-have-been-avoided finally
  happens anyway.

### 7.2 Design note: exactly one egg, exactly two dragons — kept deliberately small

Two related questions come up when discussing dragon-population design:
should there be more than one (publicly known) egg, and should there be
more than two adult dragons? Both were considered and rejected, on
narrative grounds, not just scope:

- **One egg, not several.** The power of "the last egg of their kind" is
  that it is singular and irreplaceable — the moment there is a spare, the
  story stops being about ending a lineage and becomes item collection.
  The existing **hidden second clutch** (Hunter's secret nest inside a
  monster lair, §5.2) already gives multi-egg *tension* without diluting
  the stakes: it is framed as the Hunter not trusting the plan enough to
  rely on one egg, which *reinforces* the extinction stakes (even the
  dragons know how thin their margin is) rather than undermining them. Do
  not add a second *publicly known* egg.
- **Two dragons, not more.** Guardian and Hunter are doing real narrative
  work as individuals — one defensive, one aggressive, per their actual
  game-mechanical roles — who survived the war together and chose
  patience over conquest. A third or fourth named adult dragon turns them
  into a faction, which flips "the last two of something ancient and
  doomed" into "a dragon army" and destroys the extinction pathos
  entirely — you cannot be the last of your kind if there are five of you.
  Any desire for more late-game dragon threat variety belongs in the
  **baby-dragon growth arc** (§5.3) instead: a hatchling that grows from
  HATCHLING to ADOLESCENT to ADULT over a long game is the direct,
  mechanical consequence of the clans failing to reach the egg in time,
  which is a better "there could be more of them" threat than bolting on
  another named adult.
