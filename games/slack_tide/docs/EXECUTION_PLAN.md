# SLACK TIDE — Execution Plan

Companion to `STORY_BIBLE.md` (meaning), `BALANCE.json` (numbers) and
`TODO.md` (the ticked ledger). This file is the **order of work and the gate
at each step**. If a phase's gate is red, the next phase does not start.

---

## 0. Honest state of the build

Audited from the filesystem, not from status docs.

**Working:**

| Piece | Evidence |
|---|---|
| Token graph | 75 tokens, seed-varying truth, 0 validator errors |
| Puzzle layer | `topics.json`, 14 topics, 7 triads, generated from the spec |
| World graph | `maps.json` — 15 locations, **33 hotspots, 27 links**, authored with `requires_slot` gating |
| Rules module | `slack_tide_boot.gd` — tide clock, six-slot day, inflation, decay, culprit |
| Screen | `slack_tide_ui.gd` + `layout.json`, 8/8 GUT tests |
| Balance | competent 0.804 · naive 0.129 · 74 min · 7 endings, gated on held-out seeds |

**Blocking:**

1. **No game loop.** `main.gd` loads the package, seeds the RNG, stops.
   Nothing walks the map graph, opens a conversation, or advances a slot.
   The UI builds in tests and nothing drives it.
2. **Actor cliff.** `actors.json` has **6** actors; `topics.json` references
   **26** speaking sources. The 20 missing include **Doon and Brack, who are
   the endgame**. They exist in `slack_tide_spec.json`; `convert_slack_tide.py`
   writes only `intel.json`, so they were never emitted. This is a converter
   gap, not an authoring job.
3. **Dialogue cliff.** One `.ink` of eighteen.

Skeleton is excellent. There is no muscle. Everything below is muscle.

---

## 1. Phases

Each phase ends green — `run_tests.ps1`, `check_solvable.py`, `regress.py` —
or it is not finished.

### Phase A — close the actor gap
Emit the missing actors from `slack_tide_spec.json` in
`convert_slack_tide.py`, so `actors.json` becomes **generated** like
`intel.json` rather than hand-maintained.

*Gate:* all 26 stance sources resolve; `validate_narrative.py` 0 errors;
`gen_topics.py --check` clean.

### Phase B — the session driver
`slack_tide_game.gd`: current location, slot advance, hotspot -> conversation
routing, topic resolution against `topics.json`, ending selection. Reads
`maps.json`, drives `slack_tide_ui.gd`. **Never touches `core/` or
`framework/`.**

*Gate:* a headless playthrough moves between locations, learns tokens, and
reaches an ending.

### Phase C — the engine cross-check  <- the phase that matters most
`--sim` mode emitting one `ST_EVENT` JSON line per decision and one `ST_RUN`
summary, plus the four scripted policies the Python model uses.

*Gate:* **engine competent win rate within 0.08 of the model's 0.804.**

Until this passes, 0.804 is a *Python model's opinion about a game that does
not exist yet*. If they diverge, the model is wrong and gets corrected — the
engine is the truth. Better to learn that here than at Phase F.

### Phase D — conversations (generator-first)
See `CONVERSATION_GENERATOR.md`. Generate the standing NPCs from
`topics.json` + `patterns.ink`; hand-write only the five who carry the story.

*Gate:* all 14 topics playable; every generated story compiles and binds;
`validate_narrative.py` 0 errors.

### Phase E — consequence and ending
The **Ledger of What You Said** (sold tokens resurface in NPC mouths ~3 days
later, false ones included), the Reckoning scorecard on screen, and the nine
endings split on *turned the tide* x *understood why*.

*Gate:* >= 7 distinct endings reachable **in engine**; a sold falsehood is
observably quoted back.

### Phase F — re-tune on engine numbers
Re-run the sweep against engine data, update `BALANCE.json`, re-verify.

*Gate:* `regress.py` green on engine-derived numbers, not model numbers.

---

## 2. Roles and discipline

The repo's `game-forge` pipeline pairs a builder with a verifier. A subagent
cannot spawn a subagent, and those agents are Claude Code definitions rather
than tools available in this session, so the *discipline* is run directly:

| Role | Work |
|---|---|
| **Plan / coordinate** | Phase goals, diagnosis of what is binding, regression interpretation, go/no-go |
| **Implement** | Straight-line code: converter, session driver, Ink generator, wiring |
| **Verify** | `run_tests.ps1` + `check_solvable.py` + `regress.py` after *every* phase, plus **fault injection on every new gate** |

**A gate nobody has tried to break is a gate nobody should trust.** The
balance gate was fault-injected (making the game *easier* correctly failed as
a regression); every new gate gets the same treatment.

Handoffs are **files** — `TODO.md`, `BALANCE.json`, this plan — never
conversation state. That is what keeps context, and therefore cost, low.

---

## 3. Cost discipline

- **All balance iteration stays in Python.** 10k seeds in seconds, ~free.
  Godot runs to *confirm*, never to search.
- **Generated over authored.** `intel.json`, `topics.json`, `actors.json` and
  the standing-NPC dialogue all derive from one spec. One edit, everything
  downstream follows, nothing drifts.
- **Never re-read the big files.** Tools read `intel.json` (57KB); only their
  summaries are read here.
- Largest single item is Phase D, which is exactly why it is generated.

---

## 4. Stop condition

Stop when **all** of:

1. A full headless playthrough reaches a real ending.
2. Engine and model agree within 0.08.
3. Every gate green, each one fault-injected at least once.
4. The Reckoning score plateaus — under +0.01 for three iterations.

If diminishing returns arrive before that, **say so and stop** rather than
burn credits proving a point. Shipping a tight 74-minute game beats polishing
a number nobody can feel.
