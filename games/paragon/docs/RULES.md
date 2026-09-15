# Paragon — Project Rules

(Lives at `game_engine_godot/games/paragon/`; monorepo-wide rules in `../../docs/ARCHITECTURE.md` also apply.)

These rules are binding for all contributors (human or AI agent). Propose changes via PR to this file.

## 1. Process Rules

1. **Read `activeContext.md` first** at the start of every session; update it at the end of every session
   (see §5). Never start work not listed there as Now or Next without adding it first.
2. **Task IDs are canonical.** Refer to work by `P#-T#` from `docs/DEVELOPMENT_TASKS.md`. New tasks get
   the next free ID in their phase; never renumber.
3. **Phases are sequential; milestones gate.** Do not start Phase N+1 tasks before Milestone N is green,
   except spikes explicitly marked `[spike]` in `activeContext.md`.
4. **Small, reviewable commits.** Conventional Commits (`feat:`, `fix:`, `data:`, `docs:`, `test:`,
   `refactor:`, `art:`). Task ID in commit footer: `Task: P1-T2`.
5. **No silent scope creep.** New ideas go to `GAME_DESIGN.md §13 Open Decisions` or a new task, not
   into the current branch.
6. **Docs are code.** Any behaviour change updates `ARCHITECTURE.md` / `GAME_DESIGN.md` in the same PR.

## 2. Code Rules (Godot 4 / GDScript)

1. **Static typing everywhere** (`var hp: int = 0`, `func f(a: int) -> void`); untyped-declaration
   warnings are errors in CI.
2. **`core/` never imports from `game/`.** Core is pure logic, testable headless. Presentation reacts to
   `EventBus` signals or reads `Game.state`.
3. **No magic numbers.** Balance values live in `data/` JSON or a `Balance` constants resource.
4. **Naming:** `PascalCase` classes/files, `snake_case` functions/vars, `SCREAMING_SNAKE` constants,
   signals in past tense (`virtue_changed`).
5. **One class per file; `class_name` declared** for anything referenced elsewhere.
6. **Signals over direct references** across systems; direct calls only within a system.
7. **No `get_node("../../…")` climbing.** Use `%UniqueName`, exported NodePaths, or autoloads.
8. **Every `core/` public function has a GUT test** (repo standard; `tools/run_tests.ps1`). PRs that lower `core/` coverage are rejected.
9. **Determinism:** all randomness through `Game.rng` (seedable) for reproducible tests and bug reports.
10. **Performance:** no per-frame allocations in `_process` for gameplay code; combat/AI are turn-driven.

## 3. Data & Content Rules

1. **Data-driven.** NPCs, items, spells, monsters, tokens, maps are data — never hard-coded.
2. **Schema-validated.** `python tools/validate_data.py` must pass before commit (pre-commit hook).
3. **Token redundancy:** every token on the critical path has **≥ 2 independent true sources** in
   different locations. `tools/token_graph.py` enforces this.
4. **No quest markers, ever.** The journal records only what was said/seen. No arrows, no generated hints.
5. **Virtue values are hidden — and so are conduct-derived counts.** Never display virtue numbers or bands,
   nor any count that is a virtue meter with extra steps (kills by kind, spared, lies, false tokens acted on,
   per-scenario repeats). Only journey facts are shown (`REGRESSION.md §3`, the Ledger of Days). Feedback is
   diegetic (`{seer}` bands, companion remarks, NPC tone, dreams, shrine visions).
6. **Core structure is fixed; dressing is random.** The 15 virtue modules, Wisdom scoring, the draw
   constraints, the token graph shape, the critical path, and the twist/quiz/dilemma *pools* are core and
   may not be altered per seed. Anything randomized must be listed in `PROCEDURAL_GENERATION.md §3`.
   **Randomize placement, names, and the draw — never rules.**
7. **Lies are labeled in data.** False tokens carry `"truth": false` and a `"refuted_by"` list of ≥1 true
   source, so truth is always discoverable.
8. **Companions join only after their virtue's shrine has been meditated.** No exceptions.
9. **Writing style:** early-modern register ("thou/thee/thy"), readable; no anachronisms or fourth-wall
   breaks. ≤ 3 sentences per dialogue line; long lore goes in books/signs.
10. **Every location has a purpose:** at least one token, item, service, or encounter that matters.
11. **Battle maps are fair:** party spawns never adjacent to enemy spawns; ≥1 reachable flee edge.
12. **Content IDs are stable, namespaced, and name-free:** `role.town.beggar`, `role.integrity.notary`,
    `token.mantra.slot.1`, `item.sigil.slot.2`, `dungeon.slot.3`, `virtue.humility`, `clan.rogue`. Never
    rename/reuse an ID once it can be in a save.
13. **No proper nouns in authored text or code.** All display names come from `data/names/` pools via
    `{template}` tokens (`NAMING_AND_LORE.md §6`). `validate_data.py` rejects untemplated capitalized words
    not on the common-word allowlist.
14. **Banned terms.** `data/names/banlist.json` lists every proper noun, mantra, spell, item, and monster
    name specific to Ultima IV (and real-world place names). Nothing in `data/`, `assets/`, UI strings, or
    store copy may contain them. Enforced in CI. Generic fantasy nouns (orc, troll, dragon) are fine.
15. **Pool minimums.** Each name pool holds ≥ 5× the count a single seed consumes; flavor-tagged.
16. **Generator determinism.** Same seed + same `schema_version` ⇒ byte-identical `WorldDefinition`. Any
    change to a generator stage bumps `schema_version`.
17. **Solvability is a CI gate.** Every seed in the soak must validate (end reachable; ≥2 true sources in
    ≥2 locations per mandatory token; every false token refutable before use).
18. **Virtue module completeness.** A virtue may be `drawable: true` only if its module defines creed, vice
    + dungeon theme, companion archetype with arc, ≥6 weighted actions (≥3 gain / ≥3 loss), shrine vision,
    ≥1 conflict partner (Humility exempt), ≥5 quiz questions, ≥2 conditional twists, and synonym pools ≥5
    per flavor (`VIRTUES.md §8`). Enforced by `validate_data.py`.
19. **Humility is always drawn and always slot.8;** its shrine is always guarded and gated on ≥4 shrines.
    An anchor virtue (Integrity or Justice) is always drawn. No data or code may bypass these.
20. **Wisdom is never drawn, never displayed, never meditated, never a clan patron.** It is only ever
    referenced by the seer (after Humility), companion camp arguments, dreams, the end dungeon, and the
    epilogue. No UI element may show its value or band.
21. **Dilemmas have no winning answer.** Every conflict-pair dilemma must have ≥2 resolutions that each
    favor one side and ≥1 `both` resolution that costs the player something real (time, gold, an item, a
    companion's loyalty). Reviewers reject dilemmas with a "correct" option.
22. **Act gates are inviolable.** The five-act gates in `CRITICAL_PATH.md §1` (ruler names the eight; ≥4
    shrines before Humility; all 8 before the Houses; Ring + artifacts + Word before the Descent) may not be
    bypassed by any data, twist, clan hall, or debug flag in a shipping build.
23. **Side quests are staged situations.** Every quest template must have ≥2 virtues in play, ≥3
    resolutions none of which is good for every virtue, named witnesses with reliability, an avoidance
    outcome, ≥1 later surfacing, ≥1 in-game question, ≥1 Chamber question (`SIDE_QUESTS.md §1`).
24. **The Witness Log is truth; rumours are belief.** NPC behaviour may only read rumours; the Seer, the
    Chamber, and the epilogue read the log. Companions testify only to events they witnessed and never
    falsify. The log is never displayed in any UI.
25. **The Descent has no fail state.** The four doors (Levels 1–4: Ward / Deed / Witness / Unopened) open on
    an item, the log, testimony, or an avoidance — **never a knowledge quiz** — and may eject only on a
    dishonest answer, with escalation; the Mirror, the Trials of Tension, the Threshold and the Chamber never
    eject. Chamber questions must be generated from events that actually occurred; the Chamber may not ask
    about an unplaced scenario. The Chamber's last question (the reflection) is never graded, parsed, or shown
    back by any NPC.
26. **Killing non-evil humans is always logged and always public.** A `Subdue` option must exist in every
    battle containing non-evil humans.
27. **The eleven set pieces exist in every seed** (`SET_PIECES.md`); none may be skipped by data. The Wind-Ship
    Humility floor (≥25) is not tunable. The Long Night is the only place Alone/Together is offered.
28. **The Binding Word has three roads of three kinds** (`QUEST_TREE.md §4`): the Dead (dialogue with the
    ghosts, after Humility), the Silent (observation + kneeling at the Monastery), the Still (three days'
    silence at the Hermitage). No data, twist, or seed may remove, merge, or add a fourth; its false variant is
    always sold at the Drowned Court and always refutable before the Chamber. **The Word is derived from the
    draw, never fixed:** the twelve principles, their virtue affinities, and the stage-1c selection rule are
    core; which principle and which label a seed gets is random only through the draw and the flavour. Its
    eight virtue-lines are mandatory tokens (≥2 sources each). The game never displays a principle's authored
    meaning; it is taught only through the lines.
29. **Food is real; hunger never gates.** Rations are consumed only at camp and bought with gold. Going
    without has a body: Weary → Starving (MaxHP loss) → Famished (heavier loss, slowed) → **unconscious, never
    dead** (`DESIGN_REVIEW §11.1`). No code path may kill a member by hunger, block a door, refuse a shrine or
    dialogue, or touch a virtue counter on account of hunger. Rescue after total collapse is always possible
    and always costs gold, days, and a rumour.
30. **Grinding is answered in-world, not punished.** Beyond a scenario's `repeat_cap` the event is logged at
    weight 0 and the recipient refuses diegetically. No counter loss, no message about a cap.

## 4. Design Guardrails

1. Every feature serves **Discovery, Virtue, Journey, or Replayability**; otherwise cut it.
2. The player must always be able to progress by **talking to more people**. Never gate the critical
   path on combat skill alone or a single hidden tile.
3. Virtue penalties must be **inferable** from in-world logic.
4. Rewards for virtue are **access and trust**, not power spikes; the game stays completable with little grinding.
5. Every twist is **fair in hindsight**: clues exist beforehand.
6. Randomness must never make a seed unfair: if a generated arrangement could block progress or make a
   virtue penalty unpredictable, the validator must reject it, not the player.

## 5. `activeContext.md` Rules (sliding window)

1. It is the **only** live status document and stays short (target ≤ 120 lines).
2. Sections, in order: **Now** (1–3 tasks, with sub-checkboxes), **Next** (3–6 tasks), **Recently Done**
   (last 5–8 items with date), **Blockers / Decisions Needed**, **Session Notes** (≤ 10 lines,
   overwritten each session).
3. On completion: move item to Recently Done with date; promote from Next; pull a new item into Next from
   `DEVELOPMENT_TASKS.md`; drop the oldest Recently Done beyond 8 and tick its checkbox in
   `DEVELOPMENT_TASKS.md`.
4. Never a backlog or changelog. Full list: `DEVELOPMENT_TASKS.md`. History: git.
5. Update at the **end of every work session**, even if only Session Notes change.

## 6. Asset Rules

1. Only commercially compatible licenses (CC0, CC-BY with attribution, original). Log in `assets/ATTRIBUTION.md`.
2. **This is an original IP.** No Ultima IV assets, text, names, map layouts, mantras, music, or
   trademarks anywhere in the product or marketing. `ULTIMA_IV_DEEP_DIVE.md` is internal reference analysis
   only. Only abstract *mechanics* (which are not protectable) are shared with the inspiration.
3. Binary assets via Git LFS; source files (`.blend`, `.kra`) in `assets/src/`.

## 7. Definition of Done

- Typed, tested, passes CI (tests + data validation + token graph).
- Docs updated; `activeContext.md` updated; Task ID in commit footer.
- Manually verified in-editor if presentation is touched; screenshot/GIF in PR for UI changes.
