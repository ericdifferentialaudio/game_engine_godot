# CLAUDE.md

Project brief for Claude Code. Keep this file **short and stable** — current
work-in-progress state belongs in `activeContext.md`, not here.

## What this repo is

A game engine platform: **one set of game mechanics, two graphics engines.**

```
core/               shared engine-agnostic platform (game_core addon) + headless harness
game_api/isometric/ 2D hex/iso engine API layer   (own Godot project)
game_api/fps/       3D first-person engine API layer (own Godot project)
games/              playable game packages (slack_tide, paragon, aevum, others)
docs/               API.md · ARCHITECTURE.md · RESOURCE_SCHEMA.md · NARRATIVE.md
tools/              run_tests.ps1 · sync_core.ps1 · sync_game.ps1 · generate_assets.ps1
```

## The one rule

**Core code never references a graphics engine.** Every engine-dependent
question (where is this? who can see it? what time is it?) goes through
`CoreContext.adapter` / `CoreEngineAdapter`. Engines install themselves with
`CoreContext.install(IsoEngineAdapter.new())` or `FpsEngineAdapter.new()`.

If two different renderers would both need it, it belongs in `core/`.

## Non-negotiable workflow

Godot cannot resolve `res://` across project roots, so shared trees are
physically copied. These are not optional:

| After editing…                | Run                                        |
|-------------------------------|--------------------------------------------|
| `core/addons/**`, `core/ink/**` | `./tools/sync_core.ps1`                  |
| `games/<id>/**`               | `./tools/sync_game.ps1 -All`               |
| anything, before "done"       | `./tools/run_tests.ps1`                    |

`games/<id>/` is the **single source of truth**. The copies under
`game_api/*/games/<id>/` are generated artifacts, are gitignored, and must
never be edited directly. Each package declares its target engine with
`"engine": "isometric" | "fps"` in its `game.json`, so `-All` routes every
game to the right layer without anyone having to remember the mapping.
`run_tests.ps1` fails if **any** package is out of sync.

`-Check` on either sync script verifies without copying (non-zero exit if stale).
`run_tests.ps1` runs GUT across all three project roots plus the headless
runtime/boot/playtest checks, and exits non-zero on any failure. `main` is only
ever left in a state where it is fully green.

Godot must be resolvable: `godot` on PATH, `$env:GODOT_BIN`, or
`-GodotPath "C:\path\to\Godot.exe"`.

## Conventions

- Shared platform classes are prefixed `Core*` (`CoreRegistry`, `CoreIntel`,
  `CoreStats`, `CoreInventory`, `CorePlaceDefinition`…). Do **not** add a new
  engine-local duplicate of something the core already owns — extend the `Core*`
  class or add to the adapter.
- Persistence pattern: `to_save_data()` / `from_save_data(d)`.
- Stat modifier sources are namespaced: `equip:weapon`, `status:poison`, `item:relic`.
- Data parsing is deliberately lenient (single-element lists authored as bare
  strings, `equipment` as a slot map). Use `CoreDataLoader.str_array()` /
  `packed_str_array()` — never a raw `PackedStringArray(...)` cast on JSON.
- Time is whatever the host engine reports: turns (iso) vs. game seconds (fps).
  Core only subtracts and compares.
- New core subsystem = `CoreDefinition` subclass in `core/addons/game_core/schema/`
  + `CoreRegistry.register_type(...)` + a GUT test in `core/tests/unit/`.
- Branches: `core/<topic>`, `iso/<topic>`, `fps/<topic>`; squash-merge to `main`.

## Where to look

1. `activeContext.md` — **read first.** Current state, known gaps, next planned
   work. Keep it short and update it in place; never grow it into a changelog.
2. `docs/API.md` — every public core call.
3. `docs/ARCHITECTURE.md` — layering and the engine seam.
4. `docs/RESOURCE_SCHEMA.md` — the data contract.
5. `docs/NARRATIVE.md` — Ink dialogue, knowledge vs. physical assets, standing,
   the conversation-pattern library, the validators, and the window system.
6. `docs/CORE_REQUESTS.md` — needs a game or engine has of `core/`, filed
   rather than patched (see the rule above about shared surfaces).
6. `game_api/<engine>/ENGINE_README.md` — that layer's own notes.

## Skills & agents

Skills in `.claude/skills/` cover the two engine layers (`fps-engine`,
`isometric-engine`), the core platform (`core-platform`), and how to make a
game unpredictable on purpose (`chaos-design`). Subagents in `.claude/agents/`
handle test running, sync checking, architecture review and GDScript review —
prefer delegating verbose work to them to preserve context.

### The game forge

A gated pipeline for improving every game under `games/`. Call `game-forge`:

```
game-forge                enumerate, fan out per game, gate each stage, aggregate
  game-survey             what's actually missing (filesystem, not status docs)
  architect       [OPUS]  design + rulings -> CHAOS_SPEC.md, RULINGS.md
  architect-check         -> VERIFY_DESIGN.md   ALIGNED | NOT_ALIGNED
  implement       [OPUS]  implements; games/<id>/** ONLY
  implement-check         -> VERIFY_IMPL.md
  test            [OPUS]  GUT tests + regression cases
  test-check              -> VERIFY_TEST.md; routes objections back to architect
  playtest                plays as a human; solvability floor
  regression              NEW | REGRESSION | FLAKE | KNOWN
```

Each stage pairs an Opus builder with a Sonnet verifier and is `complete` only
when **both agree** the work serves the objective — the most interesting game
(epistemic > combinatorial > social > mechanical chaos; falsifiable lies, no
counter-gates, deterministic under seed). Otherwise the objections go back to
the same builder and the stage repeats. Stage 3's objectionable results feed
back into `architect` for the next loop. Per-game state lives in
`games/<id>/docs/FORGE_STATE.json`; any stage loop past **10 turns** pauses and
asks the user rather than spinning.

Handoffs are **files**, never conversation state — that is what lets an Opus
builder and a Sonnet verifier work without sharing context.

```powershell
./tools/chaos_run.ps1 -Game <id>          # -> games/<id>/chaos_report.json
./tools/chaos_fanout.ps1 -Games all       # one git worktree per game (real parallelism)
./tools/run_tests.ps1 -LogJson            # -> tools/regressions/*.jsonl + history.sqlite
python tools/regression_hook.py --report  # classify the last run
```

`game-forge` fans out one task per game, so games run **in parallel** — but call
it from the top-level session, because a subagent cannot spawn a subagent. Use
`chaos_fanout.ps1` and separate sessions when you need separate checkouts.
`implement` must never edit `core/` or `game_api/*/framework/` — those are
shared surfaces; core needs are filed as requests and applied once on `main`.

`docs/CLAUDE_CODE_CHEATSHEET.md` is a **human** reference; do not read it.
