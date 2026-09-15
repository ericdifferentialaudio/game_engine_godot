# activeContext.md — Sliding Window of Work

> Read first, update last, every session. Rules: `docs/RULES.md §5`. Full task list:
> `docs/DEVELOPMENT_TASKS.md`. Keep ≤ 120 lines. This is **not** a backlog or changelog.

**Phase:** 0 — Foundation **Milestone target:** M0 **Last updated:** 2026-09-07

---

## Now (max 3)

- [x] **First playable data slice landed & engine-verified (2026-09-07)** — `games/paragon/` has a real
  game package (Anchor Town Integrity chain, Shrine of Compassion + healer, per `QUEST_TREE.md`/
  `docs/content/`), virtues as plain `CoreStats`/`reward.stat_delta` — no new engine code needed.
  `validate_data.py` 0/0. Godot 4.7.2 verified: `godot.ps1 check` 65/65, `smoke paragon` **37/37**
  (world/turn loop/`CoreIntel` derivation/pathfinding/save-load). Generalised
  `game_api/isometric/tools/smoke_test.gd`'s triangulation check off the hardcoded `example_realm_iso`
  tokens to whichever package's first `intel_rules.json` derivation (37/37 both packages after). Repo-wide
  `run_tests.ps1`: core 130/130, isometric 71/71+smoke 37/37, fps boot+zork playtest green. One
  **pre-existing, unrelated** `fps` GUT flake (`troll in front takes damage`, `70.0 < 70.0`) untouched by
  this session.
- [ ] **P0-T0 IP & naming gate** (H, S)
  - [ ] Trademark search: "Paragon" + 2 fallback titles; record result in `docs/NAMING_AND_LORE.md §1`
  - [ ] Draft `data/names/banlist.json` (all Ultima IV proper nouns, mantras, spells, items, monsters; real places)
  - [ ] Grep all docs except the deep-dive for banned terms; fix any stragglers
  - [ ] Approve initial pools (`NAMING_AND_LORE.md §4.1`); list categories still needing pools
- [ ] **P0-T1 Project bootstrap** (H, S) — package layout, validator, and smoke test proven working
  (2026-09-07, see above); remaining: Git LFS for `assets/**`; check what `game_api/isometric/autoloads/`
  already provides before adding any Paragon-specific autoload; one Paragon-specific GUT test in `tests/`.
- [ ] **P3-W6 Remaining 9 launch modules** (writer track, H, L) — next up: `kindness`, `justice` (needed by
      the M3 forced draw and the jailed-mother quest), then the other seven

## Next (3–6)

1. **P0-T2 Core data model** — `GameState` (+seed, clan), seeded `Game.rng` sub-streams, save/load + tests
2. **P0-T6 RunStats & regression harness skeleton** — `REGRESSION.md §3, §5` (now incl. `hermitage`,
   `monastery`, `reflection`, `word_road` fields); REG-INV-01/SAV-01/DET-01
3. **P0-T3 Isometric camera & grid mover** — `IsoCamera`, `PartyController`, test GridMap, step signal
4. **P0-T4 Map host & transitions** — `MapHost`, `Transitions`, return-context stack, two linked maps
5. **P3-W7 Remaining 4 dilemmas** (writer) — start with `loyalty_vs_justice`
6. **Writer: the three roads** (feeds P4-T15) — last-ruler ghost dialogue; Monastery dawn observation table
   + plinth text; the Anchorite's two lines + three restaged dreams; Court false-Word favour + refutations

## Recently Done (last 5–8)

- 2026-09-07 — **Gameplay documented end-to-end + deep-dive findings.** New `docs/GAMEPLAY.md`: core loops,
  the full path to win act by act (every `[T]/[I]/[V]/[D]/[C]` gate), the three Word roads, Act V level table,
  Alone/Together, and every encounter kind (knowledge, combat, survival, moral scenarios, dilemmas, side quests,
  temptation floors, companions, rumour, 11 set pieces, 20 twists), feedback channels, epilogue/Book. `§10`
  lists 12 open issues **G1–G12** (two surviving counter-gates: Wind-Ship floor, fiends "band recovers";
  Wisdom zero-volume hole; Chamber = recall of random names; doors punish misremembering; `unseen` counts as
  wrong; thin Act II consequences; cheap shrine brute-force; combat under-specified; name randomization scope;
  no playable harness). Linked from `README`, `GAME_DESIGN §13`. Also new `docs/WIN_CONDITIONS.md`: the
  checklist view — end goal, 13 hard requirements, 50 tokens, what is *not* required, compact tree, critical
  route, traps, trunk-focused proposals 6.1–6.10.
- 2026-09-07 — **All 2026-09 proposals ruled; the whole game as one tree.** New `docs/QUEST_TREE.md`
  (dependency tree win ← Word ← Descent ← Ring/Horn/Artifacts ← stones ← 8 virtues; 50 mandatory tokens;
  outer/inner road per node). Rulings (`DESIGN_REVIEW §11`): food camp-only, **never gating**; `repeat_cap` 3,
  diegetic refusal, no penalty; four doors Ward/Deed/Witness/Unopened; **Binding Word = three roads of three
  kinds** (the Dead / the Silent's ninth plinth / the Still — new set piece 11 *Hermitage* + Anchorite), false
  Word sold at the Court; **Word is seed-derived**: 12 binding principles with virtue affinities, stage 1c
  picks the one binding this draw, meaning taught by 8 virtue-lines (statues/vision/companions/ghosts/dreams/
  library), Chamber test = word + "where does it live between {A} and {B}?" + **ungraded reflection** → Book of
  Paragons + title screen. **Food is real:** gold-bought; Weary → Starving (MaxHP −10 %) → Famished (−20 %,
  slowed) → unconscious-never-dead → collapse = inn rescue + debt + rumour; Ranger forage; still never gates.
  `QUEST_TREE §4.0.0–4.0.8` full spec: 12 principles with shadows, **authoritative 12×15 affinity matrix
  (script-verified: all 924 launch draws eligible; slice seed → `candor`)**, worked 8 lines, placement table,
  exact Chamber rules, schema. `ITEMS §0` gold loop, `§3.1` launch item list (14 weapons, 10 armour, tools,
  reagents, consumables), magic pool 10 → 28.
  Anti-grind clarified (per instance, `@capped` refusal, no penalty). Fixed 3 contradictions. Rules
  §3.5/25/27 updated, §3.28–30 added. REG-END-02/04, TRV-04/07 re-baked; TRV-08, VIR-08, END-10..15 added.
  Tasks P4-T15, P1-T18 new; P1-T2, P1-T9, P4-T6, P4-T14 amended; `VIRTUES §9` virtue-lines.
- 2026-09-07 — **Gameplay review + regression spec.** New `docs/DESIGN_REVIEW_2026-09.md` (decided: virtue
  counters gate nothing; meditation = mantra + correct shrine, quick, never revoked; 8 virtues → stones →
  Ring/horn/artifacts/Word → Descent; tokens binary with category tags; companions judge honestly from what
  they saw; public/hidden telemetry split). New `docs/ITEMS.md` (tiered sellers, key items, magic uniques,
  temptation floors). New `docs/REGRESSION.md` (`RunStats` schema, event→stat map, ~70 `REG-*` tests, 5 golden
  archetype runs, CI). Updated `CRITICAL_PATH` (§1, §3.1, §4.5, §5, §6, §6.1), `GAME_DESIGN` (§5, §6, §10, §13),
  `VIRTUES` (§1), `ARCHITECTURE` (§3, §5, §9), `DEVELOPMENT_TASKS` (P0-T6, P1-T16, P1-T17), `README`.
- 2026-09-06 — **Set pieces.** New `docs/SET_PIECES.md`: ten late-game scenarios common to every seed
  (Drowned Court replaces the pirate den; Bell in the Deep; Corsair Fleet with navy twist; Maelstrom Gate;
  Wind-Ship with Humility floor ≥25 + speed scaling; the Assize; Silent Monastery; Mirror Ford; Debtor's Isle;
  **the Long Night** as Descent Level 0 where Alone/Together is chosen). Decisions: Wind-Ship gate soft with
  hard floor; Long Night fixed every seed. Updated `CRITICAL_PATH`, `PROCEDURAL_GENERATION` (4b), `RULES`
  (§3.27), `SIDE_QUESTS`, `DEVELOPMENT_TASKS` (P4-T14, P3-W12), `README`.
- 2026-09-06 — **Writer track begun (P3-W1..W5 done).** `docs/content/WRITERS_GUIDE.md`; full modules
  `virtues/integrity.md`, `compassion.md`, `humility.md` with companions/arcs/quiz/twists/synonyms;
  `dilemmas/integrity_vs_kindness.md`; `tokens/anchor_town_chain.md`; `quests/heart_jailed_mother.md`,
  `quests/street_bar_fight.md`. `DEVELOPMENT_TASKS.md` P3-W1..W11.

## Blockers / Decisions Needed

- **Gameplay issues G1–G12** (`GAMEPLAY.md §10`) need rulings; **G1/G2/G7 are contradictions** with
  `DESIGN_REVIEW §1/§4` (Wind-Ship Humility floor; fiends "until band recovers"; `unseen` counts as wrong) —
  rule before P4-T14 / REG-CMB-07 / REG-PTY-03. G5/G6 (Chamber answer format, "I do not remember") before
  P4-T15. G12 (text harness spike) proposed for Phase 0.
- **Working title "Paragon"** — trademark check pending (P0-T0). Fallbacks to propose: 2.
- **Overworld movement:** step-based with interpolation (proposed) vs. free real-time — decide before P0-T3.
- **Companion permadeath:** default *no*; offered as a Pilgrim's Vow — confirm before P2-T6.
- Resolved 2026-09-07: **folder rename (P7-T6)** — docs moved from standalone `c:\UIV` into
  `game_engine_godot/games/paragon/`; legacy folder retired.
- Resolved: isometric; 12 clans with patrons from the drawn 8; names from pools; virtue pool of 15 →
  8 per seed; Wisdom = meta-virtue (not drawable); Humility = always-drawn capstone; 12 modules at launch.

## Session Notes (overwritten each session)

- Session 8: docs only (still no code). Gameplay deep dive → `GAMEPLAY.md` (player-facing compilation of the
  whole game + open issues G1–G12). **Read `GAMEPLAY.md §3` for the path to win, `QUEST_TREE.md` for the
  formal tree.** G1–G12 are proposals; nothing else changed in the rules.
- Thesis, final form: **counters gate nothing; the log is truth; the end is found by one of three ways of
  knowing, understood through this seed's eight, then answered in the player's own words.** Food and grinding
  are moral surfaces with a body, never gates.
- Next: P0-T0 → P0-T1 (install Godot 4.3+) → P0-T2 + P0-T6 together. Writer: `kindness.md`, `justice.md`
  (each now needs 12 virtue-lines + affinities), then the three-roads scripts (Next #6).
- **Writer data now unblocked:** affinity matrix is authoritative in `QUEST_TREE.md §4.0.2` (verified over 924
  draws). Still needed: ≥3 labels per principle per flavour (ban the inspiration's answer + synonyms); 12
  virtue-lines per module (`integrity`/`compassion`/`humility` first; slice `candor` set is in §4.0.4).
- Pools still needed: reagents, spells, non-generic monsters, clan names, minor sites, NPC first names,
  virtue synonyms for 12 remaining virtues, Wisdom labels (3 of 4 flavors done).
- Note for transcription: scenario `Choices` lines use `` `virtue ±n` `` inline; parser should split on `;`.
