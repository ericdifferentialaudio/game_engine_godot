# Core requests

Things a game package or engine layer needs from `core/`, filed rather than
patched. Per `CLAUDE.md`, `implement` must never edit `core/` or
`game_api/*/framework/` directly — those are shared surfaces, and a change
applied from inside one game is how two engines silently drift apart.

Each entry states the evidence, not just the wish.

---

## CR-001 — `IntelQuery` has two live implementations with different grammars

**Status: RESOLVED** 2026-09-19 · **Found:** same day, reconciling `validate_data.py`
**Was:** high — shipped data depended on the discrepancy

### Resolution

Core became the single authority, without breaking a single authored query:

1. **`CoreIntelQuery` gained `era`**, reaching the engine through a new
   `CoreEngineAdapter.era()` (isometric returns `GameClock.current_era`; FPS
   returns `""`, so an `{"era": ...}` query is simply false there).
2. **`CoreIntelQuery.ALIASES`** now maps `faction_flag` → `holder_flag` and
   `turn` → `time`, resolved in `_leaf()` and in `is_valid_shape()`. The 19
   authored queries keep working untouched, in either engine.
3. **The engine-local `IntelQuery` now derives its grammar from core**
   (`const KEYS := CoreIntelQuery.KEYS`) and accepts both spellings, so the
   two evaluators can no longer disagree. It still exists only because it
   reads `IntelJournal` while core reads `CoreIntelJournal` — retiring it is
   part of the wider duplicate-class migration, not a query concern.
4. **`intel_query.py`** mirrors both `KEYS` and `ALIASES`, and
   `check_keys_match_core()` verifies both against the GDScript on every run.
5. Legacy spellings are reported as a **deprecation note**, not an error.

One deliberate behaviour change, documented in the source: `turn` compared the
integer turn counter, while `time` uses the adapter clock
(`turn + tick/ticks_per_turn`). Identical in sequential play; in
`realtime_pause` a `turn` query can now become true mid-turn. No shipped data
uses `turn`.

Verified: core 220/220, isometric 26/26, fps 17/17, iso smoke 40/40,
`run_tests.ps1` exit 0. Nine new tests in
`core/tests/unit/test_core_intel_query_aliases.gd`.

---

## CR-001 (original report, kept for context)

**Severity:** high — shipped data depends on the discrepancy

### What is true today

Two evaluators are both live in the isometric engine:

| | `CoreIntelQuery` (core) | `IntelQuery` (iso `framework/intel/`) |
|---|---|---|
| called by | `core_intel.gd:70` (all three project roots) | `intel_registry.gd:142`, `intel_rules.gd:48` |
| holder flag key | `holder_flag` | `faction_flag` |
| clock key | `time` (`["op", value]`) | `turn` (`["op", value]`) |
| era | — | `era` |
| keys | 19 | 20 |

The FPS engine only ever uses `CoreIntelQuery`.

### Why it matters

`faction_flag`, `turn` and `era` are **not evaluated by core**. A query using
them works through the legacy iso path and silently returns false through the
core path. Because `CoreIntelQuery._leaf()` falls through to `false` for an
unknown key, this fails *quietly*: the content is simply never offered, with
no error anywhere.

Shipped data already relies on the legacy spelling — `--all` reports
**19 occurrences** of `faction_flag`:

- `aevum` — 12 (every class shrine's `requires`)
- `paragon` — 5 (`site_beggar`, including nested `all`/`not`)
- `example_realm_iso` — 2 (one inside a `hidden_until.any`)

### What was done (steps 1 and 2 of 3)

1. ✅ Taught `CoreIntelQuery` the three missing keys — `era` outright, the
   other two as aliases — so existing data keeps working.
2. ✅ Made the engine-local evaluator derive its grammar from core, which
   closes the drift. Fully *retiring* it still waits on the
   `IntelJournal` → `CoreIntelJournal` migration (item 3 of
   `activeContext.md`'s "retire the duplicate classes").
3. ⬜ **Remaining:** migrate the 19 authored occurrences to `holder_flag` and
   drop the aliases. Safe to do at any time now, since both evaluators accept
   either spelling; the deprecation warnings list exactly where they are.

Order mattered: doing (3) first would have broken the evaluator still serving
that data.

---

## CR-002 — `TurnManager.start()` span forever with no factions

**Status: RESOLVED** 2026-09-19 · **Severity:** high — hung the process

Found while booting the first narrative package. `start()` assigned an empty
`turn_order`, and `_activate_faction(0)` then saw `index >= turn_order.size()`,
called `_end_turn()`, which began the next turn, which activated faction 0
again — an infinite loop with no output, presenting as a headless hang.

Unreachable before now because every package had factions. Fixed in
`turn_manager.gd`: an empty turn order leaves the manager idle rather than
starting a turn nobody can take.

---

## CR-003 — the Ink validator only recognised knots, not stitches or gathers

**Status: RESOLVED** 2026-09-19 · **Severity:** medium — false errors

`CoreInkValidator._declared_knots()` matched only `=== name ===`. Ink has two
other legitimate divert targets: stitches (`= name`) and gather labels
(`- (name)`), and a conversation hub is normally written with both. Any such
file reported every internal divert as `broken_divert` — 12 false errors on
the first one written, which would have trained everyone to ignore the tool.

Fixed to recognise all three forms. `corvin.ink` went from 12 errors to 0, and
its detected target count from 5 to 17.

---

## CR-004 — `CoreChaosMetrics` optimises entropy, which fights "usually wins"

**Status: OPEN** · **Severity:** medium — the metric rewards the wrong shape
· Raised by: slack_tide, 2026-09-19

`scorecard()` weights `outcome_entropy` at 0.25 under `combinatorial`. Shannon
entropy is **maximised when every outcome is equally likely** — a coin flip.
For a game that should be *challenging but usually winnable by a competent
player*, maximising that term actively makes the game worse: it pushes the win
rate toward 1/n, not toward the design target.

`solvable` (win rate >= 0.55) is a floor, not a band, so nothing in core
objects to a game that has become trivially easy — arguably the more common
failure in tuning.

Two gaps alongside it: there is **no duration metric** and **no win-variety
metric**, so "is a run the right length?" and "do players reach different
endings?" cannot be scored at all.

**Request** (any subset):
1. An optional target **band** for win rate, e.g.
   `opts.win_rate_band = [lo, hi]`, gated rather than maximised.
2. `avg_duration` / `duration_band` from a `duration` field on episode records.
3. `outcome_variety`: distinct outcomes plus the top outcome's share, which is
   what "many real endings" means — entropy conflates it with a coin flip.

**Workaround in the meantime:** `games/slack_tide/tools/{model,tune,regress}.py`
implement exactly this band-based objective in pure Python, against the same
spec the engine data is generated from. Chaos is still reported, but as a
diagnostic rather than the objective. If the pattern proves out, promoting it
into `CoreChaosMetrics` would let every package share it.

---

## CR-005 — no hotspot overlay on the `graphics` window

**Status: OPEN** · **Severity:** low — a workaround exists
· Raised by: slack_tide, 2026-09-19

Slack Tide's eleven scene cards need **clickable hotspots on an illustration**.
`CoreMapWindow` has the right model already (`set_marker(id, normalised_pos,
icon)`, `remove_marker`, `marker_clicked`), but `CoreGraphicsWindow` has only
`set_image`/`set_caption`.

**Request:** the same normalised-position marker model on `CoreGraphicsWindow`,
reporting through `CoreWindowRegistry.report_marker` so listeners do not care
which window type was clicked.

**Workaround:** hotspots ride the map window, which works but puts the
clickable region in the wrong place on screen for a scene card.
