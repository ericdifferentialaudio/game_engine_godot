# Paragon — Development Tasks (ordered)

(Lives at `game_engine_godot/games/paragon/`; the legacy standalone `UIV` folder was retired 2026-09-07 — P7-T6 done.)

Phases are sequential; tasks within a phase are ordered by dependency. IDs are stable (`P#-T#`) and are
referenced from `activeContext.md`. Live status is tracked **only** in `activeContext.md` (sliding window);
checkboxes here are ticked when a task is fully done.

Legend: **H** = high-level task, **M** = medium-level sub-task. Sizes are relative (S/M/L/XL).

---

## Phase 0 — Foundation  (goal: an empty but correct skeleton)

- [ ] **P0-T0 (H, S) IP & naming gate** — trademark search for working title "Paragon" (+2 fallbacks);
      confirm no inspiration proper nouns remain in `GAME_DESIGN.md`/`ARCHITECTURE.md`/`RULES.md`; write
      `data/names/banlist.json` (all Ultima terms, real places); approve `NAMING_AND_LORE.md` §4.1 pools.
- [ ] **P0-T1 (H, S) Project bootstrap** — Godot 4.3+ project, folder layout per `ARCHITECTURE.md §3`,
      `.gitignore`, Git LFS, `project.godot` settings (Forward+, 1920×1080 base, canvas stretch).
  - M: Autoloads `Game`, `EventBus`, `Settings`, `Audio` (stubs).
  - M: one passing GUT test (repo standard; `tools/run_tests.ps1`); `tests/` mirrors `core/`.
  - M: `tools/validate_data.py` skeleton (schema check for JSON under `data/`, banlist scan).
- [ ] **P0-T2 (H, S) Core data model** — `GameState` (incl. `seed`, `clan`), `PartyMember`, `Inventory` as
      Resources; JSON round-trip `save()/load()` with `schema_version`; seeded `Game.rng` with sub-streams.
  - M: Tests: round-trip equality, version field, defaults.
- [ ] **P0-T3 (H, M) Isometric camera & grid mover** — `IsoCamera` (4 rotations, 3 zooms);
      `PartyController` grid movement on a test GridMap with walkability, smooth interpolation.
  - M: `EventBus.step_taken(cell)` → `WorldClock.advance(1)`.
- [ ] **P0-T4 (H, S) Map host & transitions** — `MapHost`, `Transitions.request()`, fade, entry points,
      return-context stack. Two test maps linked by a door.
- [ ] **P0-T5 (H, S) HUD & message log** — party portraits/HP/food/gold; scrolling message log with
      classic phrasing; context action bar.

- [ ] **P0-T6 (H, S) RunStats & regression harness skeleton** — `core/state/RunStats.gd` with the
      `public`/`hidden` split and schema from `REGRESSION.md §3`; `data/telemetry/stat_map.json` + validator
      check; `tests/regression/ScriptedRun.gd`, `GoldenCompare.gd`, `invariants.gd`; REG-INV-01 (no `game/`
      read of `hidden`), REG-SAV-01, REG-DET-01 passing on an empty run.

**Milestone M0:** walk between two grey-box maps with a HUD; save/load position; `RunStats` counts the steps.

## Phase 1 — Core RPG Systems (headless-testable)

- [ ] **P1-T1 (H, M) World clock & moons** — minutes/day/night; two 8-phase moons; `MoonTable` per seed
      (bijective phase→gate, phase→destination, conjunction → hidden shrine); tests for all 64 phase pairs.
- [ ] **P1-T2 (H, L) Virtue system: modules, draw, Wisdom** — `pool.json` (families, conflict pairs,
      constraints), `VirtueDraw` (Humility + anchor + 6; tests over 1000 draws for constraint satisfaction),
      `VirtueModule` loader, `VirtueSystem.apply()` against per-module action tables, bands, enlightenment
      set/revoke, Humility gate (≥4 shrines), `WisdomScorer` (balance / integrated / extremes / Humility
      multiplier) with a unit-test matrix of synthetic runs; `virtue_changed`, `wisdom_changed` events.
  - M: Author the first 3 complete modules (`integrity`, `compassion`, `humility`) to drive M1.
  - M: **Binding principles** — `data/codex/principles.json` (12 principles: meaning, affinity to 15 virtues,
        ≥3 labels per flavour, labels unique per flavour); `CodexSelector` (stage 1c: eligible ≥6/8, argmax,
        RNG tie-break); exhaustive test over all 924 launch draws that ≥1 principle is eligible; per-module
        `codex_lines.json` (12 virtue-lines) validated (`VIRTUES.md §9`). Tests REG-END-14.
- [ ] **P1-T3 (H, M) Knowledge base & abstract token graph** — `token_graph.json` schema (nodes, categories,
      redundancy, false-token slots, refutations); `KnowledgeBase.learn()/knows()/keywords()`; source log.
  - M: `tools/token_graph.py` — solvability & redundancy check over the abstract graph.
- [ ] **P1-T4 (H, L) Dialogue system** — `.dlg` parser (templated, role-based), runtime with conditionals,
      `@ask`/honesty check, `@learn` via `{slot.*}`, `@virtue`, `@join`, `@clan`; `ConversationPanel` with
      learned-word chips + free typing.
  - M: 3 sample roles incl. one honesty test and one gated token slot; parser tests on malformed input.
- [ ] **P1-T9 (H, M) Name pools & templating** — `data/names/*.json` seeded with `NAMING_AND_LORE.md §4.1`
      **plus `anchorite`** (Binding Word labels live in `data/codex/principles.json`, P1-T2);
      `NamePools` (flavor selection, tags, uniqueness), `NameResolver` (`{…}` helpers, pronouns),
      `MantraGenerator`; banlist + untemplated-proper-noun check in `validate_data.py`; tests.
- [ ] **P1-T10 (H, L) Continent & placement generator** — `Continent` (noise heightmap, biomes, rivers,
      coast, hidden lake), `Regions` (8), `Placement` (all location classes with distance rules), `RoadsAndSea`
      (connectivity), `Validator` (reachability); `gen_preview.py` renders a PNG; determinism tests.
- [ ] **P1-T11 (H, M) Knowledge-graph binder & twists** — `KnowledgeGraph` assigns tokens to NPC role
      slots / books / dreams (≥2 true sources, ≥2 locations), places false tokens + refutations;
      `TwistSelector` (6–8 of pool); runtime `Validator`; CI seed soak (200 seeds).
- [ ] **P1-T13 (H, L) Witness Log & question grader** — `WitnessLog` (event schema, party_present,
      witnesses, public/avoided), every `VirtueSystem.apply()` writes an event; `QuestionGrader`
      (yes/no/refuse vs log/location/loyalty, incl. humble-concealment rule); `@ask_log` dialogue directive;
      `TavernStanding`; save/load of the log; tests with synthetic histories.
- [ ] **P1-T14 (H, M) Rumours** — `Rumours` (spawn from public events per witness, road propagation
      ~1 town/day, bias mutation, competition, correction by the player); `@rumour` directive; NPC greeting
      tone hook; tests for propagation determinism.
- [ ] **P1-T15 (H, M) Act gates & Book of Paragons** — `ActGates` (five gates, `act_entered`),
      `BookOfParagons` meta save; tests that no state path bypasses a gate.
- [ ] **P1-T16 (H, L) Items & economy** — `ITEMS.md`: `items.json` (types, tiers, class_allow, virtue hooks),
      `prices.json`, `magic_pool.json` (28 templates, `ITEMS.md §5`), the launch item list (`ITEMS.md §3.1`),
      encounter-gold tables by region danger (`ITEMS.md §0`), seller tier rules, key-item flags (never
      sold/dropped/stolen), `Items.gd` + `Shop.gd`/`Prices.gd`; generator stage 7/8 hooks (magic uniques,
      location tokens, dungeon-bottom placement); tests REG-ECO-01/02/07, REG-ITM-01/02/06.
- [ ] **P1-T18 (H, M) Food & condition** — `Food.gd`: camp consumption, `party.condition`
      fed/weary/starving/famished (MaxHP loss at dawn, STR/DEX, step cost), unconscious-never-dead, collapse →
      nearest-inn rescue with debt + public rumour, Ranger forage, give-ration with `gave_last_ration`, tiered
      ration prices; static-scan test that no gate reads rations/condition. Tests REG-TRV-04/07/08/09.
- [ ] **P1-T17 (H, M) Golden regression suite (A-priority)** — all `REG-*` tests marked **A** in
      `REGRESSION.md §6`; scripted `hermit` run on the vertical-slice seed as the first golden; hook into the
      200-seed soak (REG-INT-08, REG-DNG-03, REG-END-02, REG-INV-*). B/C priorities land with M2/M4.
- [ ] **P1-T12 (H, M) Clan system** — `clans.json` (12 clans, `CLANS.md §2`), derived stats, passives
      interface (battle + exploration hooks), magic-tier cap, patron-virtue assignment with constraints,
      shrine bonus on enlightenment; tests.
- [ ] **P1-T5 (H, M) Inventory, items, economy** — weapons/armor/items/reagents data; equip rules per
      class; `Shop` buy/sell; blind-vendor honesty; price modifiers; `ShopUI`.
- [ ] **P1-T6 (H, M) Survival** — food per step, starvation, torches/light radius; `Camp` (8 h, heal,
      ambush roll, dreams hook); inn rest; healer services (cure/heal/resurrect/blood donation).
- [ ] **P1-T7 (H, L) Magic** — 32 spells in 5 circles in `spells.json` (effects by ID; names pooled);
      per-seed recipe shuffle within balance constraints; reagent mixing (failure wastes); MP by class;
      clan magic-tier cap; spell-effect interface shared by exploration and combat; `Spellbook` UI.
- [ ] **P1-T8 (H, S) Journal (Pilgrim's Book) UI** — tabs People/Places/Words/Items/Virtues/Bestiary/
      Spells/Moons/Clans driven by KnowledgeBase; shows source of each token; seed display; zero spoilers.

**Milestone M1:** generate a world from a seed (preview PNG + validated token graph); in a grey-box town
talk to templated NPCs with pooled names, learn a generated mantra, buy food, camp, mix & cast a spell;
all core systems unit-tested; 200-seed soak green.

## Phase 2 — Combat

- [ ] **P2-T1 (H, L) Battle state & turn engine** — grid, units, DEX initiative; actions Move/Attack/
      Cast/Use/Defend/Flee/Pass; hit/damage faithful to original ranges; status effects (poison, sleep,
      jinx, quickness, protection, energy fields).
  - M: Clan battle passives (Charge, Tend, no-adjacency-stop, stealth start, grow-forest, corpse-count ATK).
- [ ] **P2-T2 (H, M) Enemy AI & morale** — melee/ranged/caster behaviours; morale → flee toward edges;
      virtue hooks routed through modules (e.g. kill fleeing → −forgiveness/−compassion/−justice if
      drawn; spare → +; player flees → −courage if drawn).
- [ ] **P2-T3 (H, M) Battle maps** — JSON format + loader; 8 terrain base maps × 3 variants; ship deck;
      camp-ambush maps; dungeon-room template; terrain effects.
- [ ] **P2-T4 (H, M) Encounters** — `encounter_rules.json` → per-seed tables by biome/time/region;
      overworld monster actors that chase; battle transition & return context; post-battle chests/mimics.
- [ ] **P2-T5 (H, M) Bestiary** — `monsters.json` for ~35 creatures (public-domain staples + originals;
      stats, abilities, evil/non-evil, loot); placeholder models; journal entries unlock on first sighting.
- [ ] **P2-T7 (H, M) Non-lethal combat & tavern map** — `Subdue` action vs non-evil humans; killing a
      non-evil human writes a public log event; tavern battle map with bystanders; area-spell bystander hits.
- [ ] **P2-T6 (H, S) Death & resurrection** — corpses/ashes; party wipe → `{ruler}` rescue at the royal seat;
      Resurrect spell/healer.

**Milestone M2:** grey-box overworld with wandering monsters; full tactical battles; morale; loot.

## Phase 3 — World Build I: Templates & Vertical Slice

- [ ] **P3-T1 (H, L) Overworld renderer** — `WorldDefinition` → chunked 3D terrain with biome materials;
      walkability (mountains/ocean impassable, swamp poison, hills slow); rivers/bridges/roads; location
      markers + entrances for every generated site.
- [ ] **P3-T2 (H, M) Transport** — horse; ship (board/sail/wind/cannon); balloon (wind); whirlpool → hidden
      lake; gates with per-seed `MoonTable`; sextant readout.
- [ ] **P3-T3 (H, L) Town assembler & first town archetype** — building kits, layout variants (≥3 for the
      "river town" archetype), doors, signs, chests (theft hooks), NPC role spawns with schedules, day/night
      lighting; slot-generic town roles authored (~20) + the `compassion` module's virtue-specific roles.
- [ ] **P3-T4 (H, M) Royal seat `{castle.royal}`** — `{ruler}` (names this realm's eight; heal/level),
      `{seer}` (per-virtue readout; Wisdom reading unlocked after Humility), mirror, council, jail.
- [ ] **P3-T5 (H, M) Shrine template** — mantra entry, cycles (1/2/3), vision text from module, enlightenment,
      revoke handling, false-mantra behaviour, clan shrine bonus, sigil grant.
- [ ] **P3-T6 (H, M) Dungeon renderer & `DungeonGen` v1** — room templates → 8 levels → GridMap; doors/
      secret doors, ladders, fountains, traps, room triggers → battle rooms, stone pickup, altar rooms.
- [ ] **P3-T7 (H, S) Intro & character creation** — fortune-teller dilemmas drawn from *this seed's* eight
      virtues → class; clan pick/roll; name/portrait; seed entry / random / daily.
- [ ] **P3-T8 (H, S) Companion recruitment** — join gated on shrine meditation; `{companion:compassion}` in
      its town (forced into the M3 test seed); loyalty counter; leave/return rules.
- [ ] **P3-T9 (H, M) First conflict-pair dilemma** — Integrity vs Kindness template end-to-end
      (`VIRTUES.md §7`), `WisdomScorer.record_resolution()`, camp argument between the two companions.
- [ ] **P3-T10 (H, L) First scenarios & side quests** — `QuestRuntime` + `QuestPlacer`; 8 scenarios for
      the three M1 modules with in-game questions live; the **jailed mother** (Heart) and the **bar fight**
      (Street) quests end-to-end incl. witnesses, rumours, tavern standing, followups.
- [ ] **P3-T11 (H, M) Act I script** — fixed anchor-town roles, ruler names the eight, seer first reading,
      mirror, first-mantra path within a day's walk (`CRITICAL_PATH.md §2`).

**Milestone M3 (Vertical Slice):** New seed (forced draw incl. compassion, integrity, kindness) → Act I →
learn a mantra & sigil → raise virtue via scenarios and a Heart quest → an NPC asks "hast thou ever…?" and
grades it → shrine → companion joins → dungeon → stone → one dilemma resolved and scored → a bar fight with
disagreeing witnesses and a rumour reaching the next town. Repeat with a different seed. Placeholder art.

## Writer Track (runs in parallel from Phase 1; authored in `docs/content/`, transcribed to `data/` as schemas land)

- [x] **P3-W1 (H, S) Writer's Guide** — voice, templating, IDs, scenario/token/dilemma formats, checklist. *(2026-09-06)*
- [x] **P3-W2 (H, L) M1 virtue modules authored** — `integrity`, `compassion`, `humility`: companion, arc,
      remarks, farewell, testimony, action tables, visions, quiz, twists, synonyms, ≥8 scenarios each. *(2026-09-06)*
- [x] **P3-W3 (H, M) First dilemma** — `integrity_vs_kindness` (*The Dying Father*) in full. *(2026-09-06)*
- [x] **P3-W4 (H, M) Anchor-town token chain** — roles, keyword ladder, two true sources each, false variant +
      refutation, honesty gate, general town pattern. *(2026-09-06)*
- [x] **P3-W5 (H, M) Two quests in full** — `heart.jailed_mother`, `street.bar_fight`. *(2026-09-06)*
- [ ] **P3-W6 (H, L) Remaining 9 launch modules authored** — kindness, forgiveness, selflessness, respect,
      justice, courage, self_discipline, loyalty, open_mindedness (same completeness as W2).
- [ ] **P3-W7 (H, M) Remaining 4 dilemmas** — loyalty_vs_justice, mercy_vs_justice, selflessness_vs_self_discipline,
      open_mindedness_vs_integrity.
- [ ] **P3-W8 (H, L) Town token chains** — one per town archetype (7) + ruined city ghosts + 3 Houses + market.
- [ ] **P3-W9 (H, XL) Quest pool** — 20 Heart / 25 Street / 15 Ledger from `SIDE_QUESTS.md §8`.
- [ ] **P3-W10 (H, M) Descent scripts** — Mirror, Trials of Tension staging, Threshold farewells collated,
      Chamber templates, epilogue slides text.
- [ ] **P3-W12 (H, L) Set-piece scripts** — dialogue, favour texts, captains, monks' observation tables,
      Mirror Ford figures per companion, Long Night question templates and Seer's final reading variants.
- [ ] **P3-W11 (H, S) Transcription tooling** — `tools/md_to_data.py` converts content sheets to JSON.

## Phase 4 — World Build II: All Templates & Critical Path

- [ ] **P4-T1 (H, XL) Remaining town archetypes** — harbor, walled, hill, forest, mining, monastic, ruin
      (Humility: ghosts, password gating, guarded shrine). Each: ≥3 layout variants, 15–25 templated roles.
- [ ] **P4-T2 (H, L) Family Houses `{castle:f1..f3}`** — one interior template per family (8), selected by
      the seed's top-3 families; artifact keepers; one secret society + password each.
- [ ] **P4-T3 (H, L) Village archetypes** — hidden-lake village (artifact + Word fragment), beggars'
      hamlet, mining camp, **moral market** (`village.market`: intel for virtue-costing favors), fishing hamlet.
- [ ] **P4-T4 (H, L) Remaining shrine behaviours** — conjunction-only shrine (one random slot); Humility
      shrine guarded by fiends, needs warding item, gated on ≥4 shrines.
- [ ] **P4-T5 (H, XL) `DungeonGen` v2 + 12 vice themes** — themed tile/prop sets, theme-specific traps and
      rooms (one per launch module), balloon dungeon; interconnected altar rooms; Sigil Ring binding.
- [ ] **P4-T6 (H, XL) The Descent (Act V)** — per `CRITICAL_PATH.md §6`: Level 0 Long Night; Levels 1–4
      conduct doors (testimony / log / item) with **escalating ejection**; Level 5 Mirror; Levels 6–7 Trials
      of Tension; Level 8 Threshold with companion farewells enacting the **Alone / Together** choice;
      `ChamberQuestionGen` (12 questions from the Witness Log, 4 enacted, companion testimony); `{temptation}`
      destruction; final question answered by the **Binding Word** (`{final_word}` value); the ungraded
      **reflection** (free text → Book of Paragons, title screen); win → Book of Paragons. The four doors are
      Ward / Deed / Witness / Unopened (`QUEST_TREE.md §5`). Tests REG-END-01..13.
- [ ] **P4-T15 (H, L) The three roads to the Word** (`QUEST_TREE.md §4`) — ruined-city last-ruler ghost
      (Act IV night dialogue, *yes/no/silence*); Monastery statue hall with the ninth plinth, dawn bow
      observation event, `kneel` context action; `site.hermitage` + `role.site.anchorite` (silent-nights
      counter, reset on talk/exit, three restaged dreams, `fed_by_anchorite`); the Court's false Word favour and
      its three refutations; Humility-vision road images + `codex.road.*` tokens; Seer line. **Virtue-line
      placement** (statues, Humility vision, companion camp lines, ghosts, dreams, royal library — `QUEST_TREE.md
      §4.0.5`) and the Chamber's two-part test (word, then "where does it live between {A} and {B}?" with line
      chips). Tests REG-END-02/10/11/13/15.
- [ ] **P4-T11 (H, L) Act III & Act IV scripts** — ruined-city ghosts, warding password gated on Humility
      band, guarded shrine, Humility vision that replays the run; 8 **family trial** templates for the
      Houses; Word keepers; epilogue generator with the 8-slide order (`CRITICAL_PATH.md §4–5, §7`).
- [ ] **P4-T7 (H, M) Special items** — 3 family artifacts, temptation item, ship-armor item, warding item,
      sextant, consecrated arms, 8 sigils (Sigil Ring), 8 stones; placement rules and token-slot bindings.
- [ ] **P4-T8 (H, M) Full abstract token graph + twist pool (20) + 5 dilemmas** — all mandatory nodes with
      ≥2 true source slots; false-token slots with refutations; 200-seed soak green end-to-end.
- [ ] **P4-T9 (H, L) 12 clan halls & champions** — hall interiors/services, champion NPCs + errands,
      patron assignment wired to the drawn virtues.
- [ ] **P4-T10 (H, XL) Complete the 12 launch virtue modules** — creed, vice theme, companion + arc +
      Threshold farewell, ≥6 actions, shrine vision, ≥5 quiz, ≥2 conditional twists, synonym pools;
      `drawable: true` gate passed.
- [ ] **P4-T12 (H, XL) Scenario catalogue to ~120** — ≥8 per launch module with in-game + Chamber question
      templates (`WITNESS_LOG.md §7`); placement stage 8b.
- [ ] **P4-T14 (H, XL) Set pieces** — the eleven in `SET_PIECES.md`: Drowned Court (favour economy, Magistrate's
      debt, **false Word favour**), Bell in the Deep (diver choice), Corsair Fleet (deck maps, navy twist),
      Maelstrom Gate, Wind-Ship (Humility floor + speed scaling, wind by moon), Assize (court from log vs
      rumours), Silent Monastery (observation tokens, **ninth plinth**), Mirror Ford (arc figures,
      refuse-to-cross), Debtor's Isle, Long Night (Level 0), **Hermitage** (shared with P4-T15).
- [ ] **P4-T13 (H, XL) Side-quest pool to ≥60** — 20 Heart / 25 Street / 15 Ledger from `SIDE_QUESTS.md §8`;
      all pass §1 requirements; placement stage 8c; followup scheduler.

**Milestone M4 (Content Complete, grey-box):** any valid seed completable start → `{final_word}`;
all 924 launch draws validate.

## Phase 5 — Expansion Content & Replayability

- [ ] **P5-T1 (H, L) Minor-site template pool (≥20) and conjunction-secret sites (≥8).**
- [ ] **P5-T2 (H, L) Companion personal arcs** (12 launch companions, templated).
- [ ] **P5-T3 (H, M) Living rumors & consequence world-state** flags and NPC variants.
- [ ] **P5-T4 (H, M) Twist pool to 20+ fully authored; Pilgrim's Vow modifiers.**
- [ ] **P5-T5 (H, M) Original monsters (~10) and spell/reagent name pools to min size.**
- [ ] **P5-T6 (H, M) Camp dreams** content (virtue feedback + rare tokens).
- [ ] **P5-T7 (H, S) NPC roles to ~300; all name pools to `min_pool`; editorial pass for voice/diction.**
- [ ] **P5-T8 (H, S) Daily Pilgrimage (shared daily seed) + seed sharing UI.**

**Milestone M5:** Feature & content complete.

## Phase 6 — Art, Audio, Polish

- [ ] **P6-T1 (H, XL) Art production** — terrain sets, town tilesets, dungeon sets per vice theme,
      characters (8 classes × gear tiers), ~45 monsters, props, VFX for 32 spells, portraits.
- [ ] **P6-T2 (H, L) Audio** — wholly original score (town / wilderness / dungeon / shrine / battle themes),
      ambience, SFX. No references to any existing game's music.
- [ ] **P6-T3 (H, M) UI polish & accessibility** — fonts, scaling, colorblind-safe virtue colors,
      keyboard/gamepad, text speed.
- [ ] **P6-T4 (H, M) Performance pass** — generation < 10 s, chunk streaming, LOD, 60 FPS target, memory.
- [ ] **P6-T5 (H, M) Localization framework** — externalized strings; templating must survive translation
      (grammar helpers per language); English only at launch.
- [ ] **P6-T6 (H, S) Clan crests, 12 champion portraits, name-pool flavor fonts.**

## Phase 7 — QA, Balance, Release

- [ ] **P7-T1 (H, L) Blind playtests across ≥5 seeds** focused on token discoverability; fix any
      single-point-of-failure intel in the abstract graph or binder.
- [ ] **P7-T2 (H, M) Balance** — economy, encounter rates, virtue tuning, combat curve, clan parity.
- [ ] **P7-T3 (H, M) Bug bash; save-migration tests; seed reproducibility across versions.**
- [ ] **P7-T4 (H, S) Builds** — Windows/Linux/macOS exports; CI release pipeline; store prep.
- [ ] **P7-T5 (H, S) Release 1.0.**
- [x] **P7-T6 (H, S) Rename repository/folder from legacy code name `UIV` to the final title** — done
      2026-09-07: docs moved to `game_engine_godot/games/paragon/`; doc references updated. (Re-check
      CI paths and the package id when the code lands.)

## Phase 8 — Post-Launch (free update)

- [ ] **P8-T1 (H, L) Virtue modules 13–15** — `gratitude`, `perseverance`, `reverence`: full modules,
      companions, vice dungeon themes, quiz, twists; extend conflict-pair coverage where sensible
      (e.g. Perseverance vs Open-mindedness: "finish what you started" vs "admit it was wrong").
- [ ] **P8-T2 (H, S) Draw pool to 15;** re-run 6435-draw validation; bump `schema_version`.

---

## Cross-cutting (continuous)

- Update `activeContext.md` every work session (see `RULES.md`).
- Every `core/` change ships with tests. Every data change passes `validate_data.py` + `token_graph.py`.
- CI: 200-seed soak on every push to main (generation success, validation, timing).
- Weekly: headless smoke test over all template variants.

