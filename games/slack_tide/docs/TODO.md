# SLACK TIDE — Build Ledger

Cost-ordered. Python model work is ~free to run; Godot/LLM loops are not.
Tick items in place. Keep this file short.

## P0 — Measurement first (nothing can be tuned until this exists)
- [x] `tools/model.py` — pure-Python sim of clock/economy/tokens/roads, reads
      `docs/slack_tide_spec.json`. 10k seeds in seconds, zero credit cost.
- [x] `tools/gen_topics.py` — derive `topics.json` from token `src`/`rumor`.
- [x] `topics.json` — the puzzle layer (design milestone M0, was missing).
- [x] `tools/check_solvable.py` — 4 solvability contracts over 1000 seeds.
- [x] `tools/score.py` — the Reckoning scorecard (Truth/Conduct/Purse/Mercy).
- [x] `tools/tune.py` — grid search against the win-rate BAND (not max chaos).
- [x] `tools/diagnose.py` — attributes each loss to the requirement that blocked it.
- [x] Gates wired into `tools/run_tests.ps1`; verified by fault injection
      (raising the win rate to 0.882 is reported as a regression).
- [ ] `--sim` headless harness in Godot emitting `ST_EVENT`/`ST_RUN` JSONL.
      (Deferred deliberately: the Python model answers every tuning question
      for free. This is only needed to confirm the engine agrees with the
      model, and should be built when Act I is playable.)

## P1 — Story
- [x] `docs/STORY_BIBLE.md` — three reversals, the satchel, the Ledger.
- [x] Spec re-map: Harrow/Doon widow thread, seed-C false-blame framing.
- [x] Regenerate `intel.json` via `tools/convert_slack_tide.py`.

## P2 — Tuning
- [x] Sweep to the win-rate band: competent 0.75–0.88, naive <= 0.35.
- [x] Duration 60–90 min; >= 6 distinct endings, none > 40%.

## P3 — Regression loop
- [x] `tools/regress.py` — run sweep, compare to baseline, flag regressions.
- [x] `docs/BALANCE.json` — committed baseline numbers.

## Phase A — actor gap  [DONE]
- [x] `tools/gen_actors.py` — merges missing NPCs from the spec into
      `actors.json`. **Hand-authored actors preserved byte-for-byte** (verified
      by diff); only `_generated` entries are ever rewritten.
- [x] 6 -> **19 actors**. Doon and Brack — the endgame — now exist.
- [x] Wired into `run_tests.ps1`; fault-injected (deleting Doon exits 1).

## Phase B — session driver  [DONE]
- [x] `slack_tide_game.gd` — movement over `maps.json` links with
      `requires_slot` gating, topic-driven `ask`/`buy`, the 0-100 reliability
      model over core acquisition, and endings on *turned* x *understood*.
- [x] 9 GUT tests (`test_slack_tide_game.gd`). They caught
      `CoreRegistry.get_definition` not existing (it is `get_def`).
- [x] Proven in test: gossip stays capped at 25, a named source beats it,
      asking the same person twice teaches nothing.

## Phase C — engine cross-check  [DONE]
- [x] `test_slack_tide_sim.gd`: scripted competent policy plays the REAL
      engine (real CoreIntel, real slack_tide_game.gd) over 40 seeds.
- [x] **Found and fixed two real bugs, not tuning drift:**
      1. Nothing ever called `GameClock.advance_turn()` for a narrative
         package -- `TurnManager` only turns the crank when there are
         factions, and Slack Tide has none. Wages would never have landed in
         real play. Fixed: `slack_tide_game.advance_slot()`.
      2. `truth`/`category` on an intel token do not live under
         `CoreIntelToken.facts` (that's for a different payload) -- they are
         unmapped raw JSON, read back via `CoreDefinition.extra()`. Before the
         fix `understood()` always returned false and 100% of engine wins were
         `cold_answer` (won without knowing why). After: `long_way_home`
         correctly dominates for a policy that actually corroborates.
- [x] Engine competent win rate over 40 seeds: **0.925** vs model's 0.804 --
      within the 0.20 tolerance (a 40-seed sample is noisier than the
      Python model's 2000; `tools/regress.py` remains the real gate).
- [x] Determinism verified: same seed -> same outcome.
- [x] Wired into `run_tests.ps1` (part of the isometric GUT suite).

## Phase D — dialogue  [DONE]
- [x] `tools/gen_dialogue.py`: generates Ink for the 12-strong standing cast
      from `topics.json`, matching `corvin.ink`'s proven pattern (explain /
      rumor / price / flinch). Per-NPC voice fragments so generated prose
      does not read as interchangeable.
- [x] **Safety rail, fault-injected twice:** the generator refuses to touch a
      file missing its own generated header. Verified both that a bespoke
      file (Corvin) survives a run untouched, and that hand-editing a
      generated file's header permanently claims it.
- [x] All 17 stories compile (inklecate) and pass `validate_narrative.py`
      with **0 errors** -- 75 tokens, 19 actors, 15 places.
- [x] 5 bespoke, hand-written: **Corvin** (pre-existing), **Doon** (the
      widow -- the moral centre of seed A, gated on mercy 5), **Brack** (the
      satchel's recipient), **Hesper** (the game's voice), **Wenna**
      (seed C's route and the Bell).
- [ ] Passenger archetype generator (crossing-scene manifests) -- deferred,
      not on the critical path to a playable Act I.

## Phase E — consequence  [DONE]
- [x] **The Ledger of What You Said**: `slack_tide_game.sell()` /
      `spread_tokens()` / `is_common_knowledge()`. A sold token -- including a
      false one -- becomes common knowledge `SPREAD_DELAY` (3) days later.
      Turns the information market from a shop into a moral system, at the
      cost of ~60 lines.
- [x] **The Reckoning**: `reckoning()`/`reckoning_text()`, four axes (Truth /
      Conduct / Purse / Mercy) mirroring `tools/model.py`'s scorecard, printed
      at the end of every run. Selling secrets trades Purse for Truth -- the
      tension that makes a second playthrough worth having.
- [x] 4 new GUT tests; full suite still green.

## P5 — UI (task 2)
- [x] `layout.json` wide variant reworked: scene NW + map + status on the top
      band; full-width narration south with the journal as a right rail.
- [x] `slack_tide_ui.gd` builds it, binds all five roles, routes choices and
      hotspots, renders reliability bands and conflict/disproved glyphs.
- [x] 8 GUT tests (`game_api/isometric/tests/unit/test_slack_tide_ui.gd`),
      including a compile test that immediately caught `get_viewport_rect()`
      being unavailable on Node.
- [ ] Instantiate the UI from the boot path (needs a narrative main scene;
      today `main.gd` only runs world/smoke paths for narrative packages).
- [ ] Art: 11 scene cards, portraits, icons. Placeholders are fine to start.

## Filed to core (never edit `core/` from a game package)
- [x] **CR-004** — `CoreChaosMetrics` maximises entropy (a coin flip), has no
      duration metric and no win-variety metric. Band-based objective
      implemented in this package's Python tools as the workaround.
- [x] **CR-005** — hotspot overlay on the `graphics` window; hotspots ride the
      map window until then.

## The objective, restated (why chaos is not the target)

Shannon entropy is maximised when every outcome is equally likely — a coin
flip. That is the opposite of "challenging, but the player usually wins", so
chaos is now a **diagnostic**, not the thing being optimised. The target is a
band, and `tools/regress.py` fails if the game leaves it in *either* direction:

| signal | target | current |
|---|---|---|
| competent win rate | 0.75–0.88 | **0.804** |
| naive win rate | <= 0.35 | **0.129** |
| skill gap | large | **0.675** |
| duration | 60–90 min | **74 min** |
| distinct endings | >= 6, top <= 40% | **7, top 35%** |
