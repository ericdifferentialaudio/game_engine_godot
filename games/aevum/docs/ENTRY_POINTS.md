# Aevum — Entry Points Reference
*Last updated: 2026-08-05*

✅ **08/30/2026: the full-graphics entry point now actually resolves real
turns.** `python main.py` (no `--mode`, "full game" row in the table below)
delegates to `client/game_loop.py::run()`; its turn-resolution call
(`_do_resolve()`) used to import a nonexistent
`engine.engine_gameplay.resolve_turn`, silently caught the resulting
`ImportError`, and fell back to a no-op stub (advance turn number + add gold
only — no combat, movement, AI, dragon, or win-check ever ran). Fixed:
`_do_resolve()` now calls the same shared pipeline `--mode headless`/
`--mode atlas` already use — `run_ai_decision_ticks()` (AI decisions +
tick-paced movement) → `run_turn_sequence()` (`TURN_SEQUENCE`) →
`eliminate_dead_clans()` → `check_win()`. `main.py`'s quick-start path
(`_quick_start()`) also now calls `StartupEngine.setup_ai_session()` so its
AI clans have the personality/mantra/distance-precompute state those
functions assume exists (previously only headless/Atlas/tutorial did this).
The dead `engine/engine_gameplay.py` module (a ~2000-line near-duplicate of
`engine/gameplay_engine.py`) was deleted. See
`doc/ENGINE_CONSOLIDATION_PLAN_2026_08.md` for what remains open in Category
C (cluster/lair movement metering) — that document still supersedes any
prior single-file plan.

**08/29/2026: `simulate/runner.py` renamed to `simulate/headless.py`.**
Pure rename (all call sites updated: `simulate/__init__.py`, `simulate/cli.py`,
`simulate/parallel.py`, tests, `tools/diag_seed5.py`); no behavior change.
`client/atlas_map.py` keeps its name (confirmed, no rename). See the
consolidation plan above for the remaining Category A/B/full_game.py work.

There is **one canonical entry point**: `python main.py`.

---

## Quick reference

| Command | What it does |
|---------|-------------|
| `python main.py` | Full game: title screen → clan select → gameplay |
| `python main.py --seed 42` | Skip title; start game with seed 42 |
| `python main.py --mode atlas --seed 83 --speed 2` | Visual world-map viewer; 2 t/s |
| `python main.py --mode headless --seed 42` | Single AI game, verbose output |
| `python main.py --mode headless --seed 42 --turns 50` | Single AI game, capped at 50 turns |
| `python main.py --mode headless --games 100` | Batch 100 games, workers=20 auto |
| `python main.py --mode headless --games 100 --workers 8` | Batch, explicit worker count |
| `python main.py --mode sim --games 20 --workers 20 --full-log` | Batch **with Atlas-grade per-game logs** |
| `python -m pytest tests/` | Full test suite — **parallel by default** (20 workers, ~39s) |
| `python -m pytest tests/engine/test_foo.py -n 0 -v` | One file, **serial** — for debugging |

### Tests are parallel by default (08/2026)

`pytest.ini` carries `-n 20 --dist loadfile`, so plain `python -m pytest tests/`
uses 20 worker processes. **650 passed / 32 skipped in ~39s**, down from **202s**
serially — a 5× speedup, verified to produce identical results.

Requires `pytest-xdist`: `python -m pip install -r requirements-dev.txt`.

To debug serially use **`-n 0`** (runs in-process). Do **not** use
`-p no:xdist` — that unregisters the plugin while `-n` is still in `addopts`,
and pytest aborts with `unrecognized arguments: -n --dist`.

### `--full-log` (08/2026)

Gives each game its own self-contained directory — the same file set an Atlas run
produces — so a batch can be analysed at per-unit / per-turn fidelity:

```
simulation_results/sim_<ts>/
├── summary.md, results.json        ← batch level
└── game_01_seed_1/
    ├── run_01_seed_1.md            ← per-game markdown, moved inside
    ├── session.log                 ← this game's stdout
    ├── game_1_<ts>.jsonl           ← full JSONL event log
    └── summary.md
```

**Why it exists:** `GameAnalytics.log_event()` only appends to an in-memory list —
it never writes a file. So `--mode sim` had **no JSONL log at all**, and a 100-game
regression produced 123 MB of `results.json` with zero per-turn unit data. Every
detailed investigation had to be done from an Atlas run instead.

Both modes now emit these records through **one** function,
`engine.game_log.log_turn_to_jsonl()`. That code previously lived inside
`client/atlas_map.py` — the renderer owned the log format, which is exactly why
sim had none. Guarded by `tests/engine/test_log_parity.py`.

⚠️ ~15 MB per 400-turn game. Opt-in; do not use for 100+ game batches.

---

## Mode: `user` (default — no --mode)

Interactive Pygame game with full graphics, audio, and UI.

```
python main.py                            # title screen
python main.py --seed 42                  # skip title, start with seed 42
python main.py --seed 42 --clan ranger    # skip title, play as ranger
python main.py --pygame-only              # force CPU renderer (skip ModernGL)
python main.py --no-audio                 # disable audio
python main.py --fast-day-night           # 30-second day/night cycle (visual test)
```

**Output:** Pygame window. No files written.

---

## Mode: `atlas`

Mini GUI world-map viewer. Runs the full AI simulation at a configurable
speed while rendering every hex on screen. Single game, all AI.

```
python main.py --mode atlas                            # seed=42, speed=0.5 t/s
python main.py --mode atlas --seed 83 --speed 2       # seed 83, 2 turns/sec
python main.py --mode atlas --seed 83 --speed 0       # paused at start
python main.py --mode atlas --clan ranger             # fog-of-war from ranger POV
python main.py --mode atlas --map pangea              # pangea map (default)
python main.py --mode atlas --map fractured           # fractured map
```

**Controls:** Space=pause · +/- speed · Scroll=zoom · Drag=pan · F=fog · Q=quit

**Output:**

Every Atlas run writes a single self-contained directory:

```
simulation_results/atlas_<MM_DD_YYYY_HH_MM>_seed<N>/
├── session.log             — full mirrored stdout/stderr for the run
├── game_<seed>_<ts>.jsonl  — structured JSONL event log (GameLogger)
├── turns.log               — per-category split: turn header lines
├── units.log               — per-category split: unit count summaries
├── missions.log            — per-category split: per-clan AI goal breakdown
├── combat.log              — per-category split: [combat] lines
├── shrine.log              — per-category split: [shrine] lines
├── training.log            — per-category split: [train] lines
├── kills.log               — per-category split: [kill] lines
├── towns.log               — per-category split: [town] lines
├── lairs.log               — per-category split: [lair] lines
├── intel.log               — per-category split: [intel] lines
├── items.log               — per-category split: [item] lines
├── captures.log            — per-category split: [capture] lines
├── dragon.log              — per-category split: [dragon] lines
├── errors.log              — per-category split: [ERR] lines
└── summary.md              — human-readable post-run summary (seed, map,
                               turns played, winner, per-clan shrine/gold table)
```

Pre-split category files are only created if at least one matching line was
found (empty categories are omitted). Use `session.log` for the full,
unfiltered console output. See `RUNS.md` for the same reference.

**Tick engine:** `client/atlas_map.py:_make_sim_tick()` — accepts an optional
`log_dir` so the internal `GameLogger` JSONL file writes into the run
directory instead of the default `logs/game_{seed}_{ts}.jsonl`.

**Helpers:** `engine/game_log.py` — `build_atlas_run_dir()`,
`split_atlas_log()`, `write_atlas_summary()`.

> ✅ **Closed 08/29/2026 (Category B consolidation):** tick *orchestration*
> parity between Atlas and headless is fully done, including the dragon
> subsystem. Both loops execute the same `engine_headless.TURN_SEQUENCE` via
> a single `run_turn_sequence(state, analytics)` call — no `phase=` split, no
> `__DRAGON_SPLIT__` sentinel. The dragon subsystem (checkpoint/proximity/
> probabilistic wake, HP- and threat-driven enrage, dragon-vs-unit strikes,
> enclave assault) is five plain `TURN_SEQUENCE` entries in
> `engine/engine_dragon.py`, identical in both modes. Previously the
> probabilistic force-wake safety valve (t150+, `DRAGON_FORCE_WAKE`
> reason=`prob_wake`) and the entire enclave-assault mechanic (the only
> enabler of `DRAGONS_WIN`) existed only in headless — see
> `doc/ENGINE_CONSOLIDATION_PLAN_2026_08.md` for the full audit that found
> this, now resolved.

---

## Mode: `headless`

Headless AI-vs-AI simulation.  Size is determined by `--games`:

- **Single game** (`--seed 42` or `--games 1`): verbose output, log-level=medium, 1 worker
- **Batch** (`--games N` where N > 1): one line per game, workers=20 auto

```
python main.py --mode headless --seed 42                   # single game (verbose)
python main.py --mode headless --seed 42 --turns 50        # single game, 50 turns
python main.py --mode headless --games 100                 # batch, 100 games, workers=20
python main.py --mode headless --games 10 --workers 4      # batch, explicit workers
python main.py --mode headless --games 50 --compare-baseline
python main.py --mode headless --save-baseline
python main.py --mode headless --games 20 --note "after session J changes"
```

**Aliases:** `--mode sim` and `--mode regression` are identical to `--mode headless`.

**Flags:**

| Flag | Default | Description |
|------|---------|-------------|
| `--seed N` | None | Fix seed (single game; infers --games 1) |
| `--games N` | 5 | Number of games |
| `--turns N` | 400 | Max turns per game (overrides MAX_TURNS) |
| `--workers N` | **20** | Parallel processes (auto for batch) |
| `--map-type` | standard | Map: standard\|pangea\|fractured |
| `--clans N` | 8 | Clans per game (4–12) |
| `--log-level` | auto | none\|low\|medium\|debug (auto: medium for 1 game, none for batch) |
| `--compare-baseline` | off | Compare chaos score to saved baseline |
| `--save-baseline` | off | Save current run as baseline |
| `--note TEXT` | "" | Tag this run in chaos_history.md |

**Output:**
- stdout: game summary (verbose for single, one-line for batch) + overall stats
- `simulation_results/sim_<timestamp>/` — summary.md, results.json, index.html
- `simulation_results/report.html` — auto-regenerated root report
- `simulation_results/chaos_history.md` — running chaos score history
- `logs/game_<seed>_<ts>.jsonl` — full per-turn JSONL event log (cluster AI events here)

**Chaos score target:** 0.45–0.65

**Tick engine:** `simulate/headless.py:run_game()` → shared `engine_headless.TURN_SEQUENCE` (dragon subsystem lives in `engine/engine_dragon.py`, identical to Atlas).

---

## Logging

The project uses `print()`-based output throughout — no Python `logging` module.

| Layer | Mechanism | Destination |
|-------|-----------|-------------|
| Atlas session | `_Tee` (stdout+stderr mirror) | `simulation_results/atlas_<ts>_seed<N>/session.log` |
| Atlas structured events | `engine/game_log.py:GameLogger` (JSONL), `out_dir=log_dir` | `simulation_results/atlas_<ts>_seed<N>/game_<seed>_<ts>.jsonl` |
| Atlas category splits | `engine/game_log.py:split_atlas_log()` | `simulation_results/atlas_<ts>_seed<N>/*.log` |
| Atlas summary | `engine/game_log.py:write_atlas_summary()` | `simulation_results/atlas_<ts>_seed<N>/summary.md` |
| Headless batch | `_NullWriter` (suppress worker stdout) | suppressed |
| Headless structured events | `engine/game_log.py:GameLogger` (JSONL, default out_dir) | `logs/game_<seed>_<ts>.jsonl` |
| Headless summary | `simulate/cli.py` print statements | stdout |

---

## File map

| File | Role |
|------|------|
| `main.py` | **Single entry point** — routes all modes |
| `simulate/cli.py` | Headless CLI logic (`main(argv=None)`) called by `--mode headless` |
| `simulate/headless.py` | Single-game headless tick loop + analytics |
| `simulate/parallel.py` | Multi-process parallel runner |
| `simulate/report.py` | Summary, win rates, power ranking |
| `client/atlas_map.py` | Atlas visual renderer + semi-headless tick |
| `client/game_loop.py` | Full interactive Pygame game loop |
| `engine/game_log.py` | `GameLogger` (JSONL) + Atlas per-run directory helpers |
| `engine/` | Game engine (shared by ALL modes — never mode-specific) |

---

## Tick loop parity (closed, 08/29/2026)

The game engine (`engine/`) is shared by all modes. Per-turn engine-step
**orchestration** used to be two independently hand-maintained lists (one in
`simulate/headless.py:run_game()`, one in `client/atlas_map.py:_make_sim_tick()`)
and repeatedly drifted — see the divergence table above. That is now fixed
structurally: both functions call the same ordered manifest,
`engine_headless.TURN_SEQUENCE`, via a single `run_turn_sequence(state,
analytics)` call — no `phase=` parameter, no `__DRAGON_SPLIT__` sentinel, no
per-driver dragon block of any kind. **To add or reorder a per-turn engine
step, edit `TURN_SEQUENCE` — never a turn loop.**
`tests/engine/test_mode_parity.py` enforces membership, resolvability,
declared arity, and (new 08/29/2026) that neither driver reintroduces a
hand-rolled dragon block.

**What is still genuinely mode-specific** (deliberately, not by drift):
- Atlas owns rendering/event-feed/window state; headless owns analytics
  snapshotting/verbose printing. Neither belongs in `TURN_SEQUENCE`.

There is no longer any mode-specific per-turn *game logic* — the dragon
subsystem (wake/enrage/enclave-assault) was the last instance and moved into
`engine/engine_dragon.py` as five plain `TURN_SEQUENCE` entries
(`dragon_tick`, `dragon_probabilistic_wake_tick`, `dragon_threat_enrage_tick`,
`dragon_unit_strike_tick`, `dragon_enclave_assault_tick`) on 08/29/2026. See
`doc/ENGINE_CONSOLIDATION_PLAN_2026_08.md` for the full audit history.

---

## Cluster AI events

MISSION_CREATED, DIRECTIVE_COVERAGE, CLUSTER_REGROUPING and other cluster AI
events are written to `state.combat_log` and the JSONL game log. For headless
runs that's `logs/game_<seed>_<ts>.jsonl`; for Atlas runs it's the
`game_<seed>_<ts>.jsonl` file inside the run's
`simulation_results/atlas_<ts>_seed<N>/` directory. They do not appear in
stdout by default.  To inspect them after a sim run:

```
# Windows — headless run
type logs\game_83_*.jsonl | findstr MISSION_CREATED

# Windows — atlas run
type simulation_results\atlas_*_seed83\game_83_*.jsonl | findstr MISSION_CREATED

# Unix
grep MISSION_CREATED logs/game_83_*.jsonl
grep MISSION_CREATED simulation_results/atlas_*_seed83/game_83_*.jsonl
```
