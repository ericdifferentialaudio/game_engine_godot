# Paragon — High-Level Architecture

(Lives at `game_engine_godot/games/paragon/`. Drafted as a standalone project under code name `UIV`;
see the **Monorepo mapping** note in §3 for how the layout below maps onto the shared engine.)

## 1. Engine Decision

### Recommendation: **Godot 4.x** (GDScript for gameplay; C# optional for heavy systems)

| Criterion | Godot 4 | Unity | Unreal 5 | Custom (MonoGame/Bevy) |
|---|---|---|---|---|
| Isometric 3D, grid-based, turn-based | Excellent; lightweight 3D, GridMap | Good | Overkill | Everything from scratch |
| Data-driven RPG content (dialogue, tokens) | Native Resources, JSON, first-class scripting | Good (ScriptableObjects) | Weaker for text-heavy games | Full control, high cost |
| Licensing / cost | MIT, free forever | Runtime-fee history, seat licenses | 5% royalty > $1M | Free |
| Team-size fit (small team / solo) | Ideal | Good | Poor | Poor |
| Iteration speed | Fast (instant reload, tiny binaries) | Medium | Slow | Slow |
| Stylized low-poly art pipeline | Excellent | Excellent | Excellent | Manual |
| Cross-platform export | Win/Linux/macOS/Web (consoles via partners) | All | All | Limited |
| Open source, no vendor risk | Yes | No | Source-available | Yes |

- **Why not Unity:** licensing volatility and heavier overhead for a text/data-heavy game.
- **Why not Unreal:** cinematic pipeline mismatched with a stylized, grid, turn-based, text-driven RPG.
- **Why not custom:** the value is in content and systems, not rendering tech.

Version: Godot **4.3+ stable**. Language: **GDScript** for gameplay/UI, optional **C#** for combat AI /
pathfinding if profiling demands. Renderer: **Forward+** (desktop).

## 2. Architectural Principles

1. **Data-driven everything.** World, NPCs, dialogue, tokens, items, spells, monsters, and battle maps
   live in data files (JSON / `.tres`), not code. Designers edit data; code is generic.
2. **Simulation core separated from presentation.** `core/` has no scene dependencies; it is unit-tested
   headlessly. Scenes render and forward input.
3. **Single source of truth.** One serializable `GameState` holds party, virtues, tokens, flags, time,
   moons, location. Saving = serialize `GameState`.
4. **Events, not polling.** Global `EventBus` autoload (`virtue_changed`, `token_learned`,
   `time_advanced`, `map_changed`, `battle_ended`…).
5. **Grid-first.** Positions are integer cells; 3D presentation interpolates.
6. **Every map is a scene.** Overworld, each town, each dungeon level, each battle map, each shrine —
   instantiated from **templates** and dressed by the generator.
7. **Seed-deterministic.** World = f(seed, schema_version). Saves store seed + state, never the map.
   All randomness goes through `Game.rng` sub-streams.
8. **Names are data, IDs are code.** Content references archetype IDs; `NameResolver` renders display
   names from per-seed pools (`NAMING_AND_LORE.md`). No proper nouns in code or authored text.

## 3. Project Layout

> **Monorepo mapping (2026-09-07).** Paragon is a game package inside `game_engine_godot`, not a standalone
> Godot project. Consequences for the layout below: (a) there is no package-level `project.godot` — the
> package is copied by `tools/sync_game.ps1 -Game paragon -Engine isometric` into
> `game_api/isometric/games/paragon/` and launched from the isometric engine project; (b) the `core/`
> tree below is the *game's* pure-logic layer and must build on, not duplicate, `core/addons/game_core/`
> (registry, items, units, factions, places, stats, inventory, intel/journals, interactions) and
> `game_api/isometric/framework/` (grid, world, entities, combat, economy, sites, ui); (c) tests use **GUT**
> (repo standard, `tools/run_tests.ps1`), not gdUnit4; (d) `addons/` is owned by the engine projects.
> Directory names below are kept as the design vocabulary; resolve overlaps in favour of the engine.

```
games\paragon\            (design-time layout; see mapping note above)
  addons/            provided by the engine project (GUT)
  core/              pure logic, no Node dependencies where possible
    state/           GameState.gd, PartyMember.gd, Inventory.gd, SaveManager.gd,
                     RunStats.gd (public/hidden telemetry, REGRESSION.md §3)
    virtue/          VirtueSystem.gd (8 drawn counters + wisdom()), VirtueDraw.gd, VirtueModule.gd,
                     ConflictPairs.gd, WisdomScorer.gd
    knowledge/       IntelToken.gd, KnowledgeBase.gd
    dialogue/        DialogueParser.gd, DialogueRuntime.gd, KeywordMatcher.gd
    time/            WorldClock.gd, Moons.gd, Gates.gd
    combat/          BattleState.gd, TurnOrder.gd, CombatResolver.gd, Morale.gd, EnemyAI.gd
    magic/           Spell.gd, Reagents.gd, Spellbook.gd
    economy/         Shop.gd, Prices.gd, Items.gd (tiers, key/magic items; ITEMS.md)
    survival/        Food.gd, Camp.gd, Light.gd
    world/           MapDefinition.gd, Transitions.gd, Encounters.gd
    naming/          NamePools.gd, NameResolver.gd (templating), MantraGenerator.gd
    procgen/         WorldGenerator.gd (pipeline), Continent.gd, Regions.gd, Placement.gd,
                     RoadsAndSea.gd, MoonTable.gd, DungeonGen.gd, KnowledgeGraph.gd (token assignment),
                     TwistSelector.gd, Validator.gd
    clans/           Clan.gd, ClanSystem.gd, Champion.gd
    witness/         WitnessLog.gd (events), Witnesses.gd (reliability), Rumours.gd (propagation),
                     QuestionGrader.gd (yes/no/refuse vs log), ChamberQuestionGen.gd, TavernStanding.gd
    quests/          QuestTemplate.gd, QuestRuntime.gd (branches, followups), QuestPlacer.gd
    acts/            ActGates.gd (five-act gates), Threshold.gd, Descent.gd (ejection, trials), Epilogue.gd,
                     BookOfParagons.gd (meta save)
  game/              Node-based presentation & controllers
    autoload/        EventBus.gd, Game.gd, Audio.gd, Settings.gd
    camera/          IsoCamera.gd
    player/          PartyController.gd (grid mover), Interaction.gd
    npc/             NpcActor.gd, Schedule.gd
    maps/            overworld/, towns/, castles/, villages/, dungeons/, shrines/, battles/
    ui/              HUD, MessageLog, ConversationPanel, Journal, Inventory, Spellbook, ShopUI,
                     CampUI, ShrineUI, MainMenu, GypsyIntro
  data/              authored content (JSON / .dlg), validated by tools — templates & pools, not instances
    names/           <category>.json name pools; banlist.json; common_words_allowlist.txt
    world/           biomes.json, generation_params.json, minor_sites/*.json
    templates/       towns/<archetype>/*.json, castles/, villages/, shrines/, building_kits/
    npcs/            roles/<town_archetype>/<role>.json
    dialogue/        <role>.dlg  (templated; no proper nouns)
    tokens/          token_graph.json  (abstract graph: nodes, categories, redundancy, false-token slots)
    twists/          <twist>.json, dilemma_<pair>.json
    quests/          heart/*.json, street/*.json, ledger/*.json  (≥60 templates at launch)
    houses/          trial_<family>.json (8 family trials)
    descent/         levels.json (scripted level-ends), chamber_templates.json, epilogue_slides.json
    items/           weapons.json, armor.json, items.json, reagents.json
    spells/          spells.json (effects by ID; names pooled)
    monsters/        monsters.json, encounter_rules.json
    battles/         battle_maps/*.json
    dungeons/        room_templates/*.json, dungeon_params.json
    clans/           clans.json, champions/*.json, halls/*.json, patron_constraints.json
    virtues/         pool.json (draw constraints, families, conflict pairs), wisdom.json (scoring weights),
                     <virtue_id>/module.json (creed, vice, companion, actions, shrine vision, quiz, twists,
                     synonyms) + <virtue_id>/scenarios.json (≥8 staged situations with in-game + Chamber
                     question templates) — 15 modules, 12 drawable at launch
    virtue/          thresholds.json, balance.json  (shared bands/weights)
    quiz/            questions.json (40 concept questions), dilemmas.json (creation)
  assets/            models/, textures/, materials/, audio/, fonts/, ui/
  tools/             validate_data.py (schema + banlist + template check), token_graph.py, gen_preview.py
  tests/             GUT tests mirroring core/
    regression/      ScriptedRun.gd, GoldenCompare.gd, invariants.gd, test_reg_*.gd (REGRESSION.md §5–6)
    golden/          <seed>_<archetype>.actions.json / .stats.json (REGRESSION.md §7)
  docs/
  activeContext.md
```

## 4. Runtime Structure

```
Main (root scene)
 ├─ Autoloads: Game (GameState), EventBus, Audio, Settings
 ├─ MapHost           ← exactly one map scene at a time (overworld / town / dungeon level / battle)
 │    └─ <MapScene>   ← GridMap/terrain + NpcActor nodes + PartyActor + triggers
 ├─ IsoCamera
 └─ UI (CanvasLayer)  ← HUD, MessageLog, modal panels (Conversation, Journal, Shop, Camp, Shrine…)
```

**Map transitions:** `Transitions.request(map_id, entry_point)` → fade → `MapHost` frees current scene,
instantiates target, places party at entry. Battles push a *return context* (map, position, monster
group) onto a stack and pop it on victory/flee.

## 5. Core Systems (responsibilities)

| System | Owns | Key API |
|---|---|---|
| GameState | seed, party, inventory, virtues, tokens, flags, clock, moons, location, clan | `save()`, `load()` |
| RunStats | every counted thing in the run, split `public` (Pilgrim's Book) / `hidden` (Seer, Chamber, tests); fed by `EventBus` via `data/telemetry/stat_map.json` | `public()`, `record(event)` |
| Items | item catalogue, seller tiers, key-item flags, per-seed magic uniques | `stock(seller)`, `price(item, seller)`, `is_key(item)` |
| WorldGenerator | runs the 11-stage pipeline (`PROCEDURAL_GENERATION.md §2`) → `WorldDefinition` | `generate(seed)` |
| NamePools / NameResolver | per-seed name selection; `{token}` templating | `resolve(text)`, `name(id)` |
| VirtueDraw | selects the seed's 8 virtues from `pool.json` under constraints; maps slots↔IDs; active conflict pairs | `draw(rng)` |
| VirtueSystem | 8 drawn counters, bands, enlightenment set, Humility gate (≥4 shrines) | `apply(action_id, ctx)`, `band(slot)`, `can_meditate(slot)` |
| WisdomScorer | hidden meta-score from conflict-pair balance, integrated resolutions, extremes, Humility multiplier | `wisdom()`, `band()`, `record_resolution(pair, side|both)` |
| WitnessLog | every virtue event with party_present, witnesses, public/avoided flags; saved | `record(event)`, `query(filter)` |
| Rumours | public events → rumours; road propagation ~1 town/day; mutation by bias; competition | `tick_day()`, `believed(town, event_id)` |
| QuestionGrader | grades yes/no/refuse against log / location / loyalty; applies virtue deltas | `grade(question, answer)` |
| ChamberQuestionGen | 12 questions from log + modules + Threshold path; companion testimony | `generate(path)` |
| TavernStanding | per-tavern −3..+3 from innkeeper-witnessed events | `standing(tavern)` |
| QuestRuntime | instantiates placed quest templates; branches; followups over days | `advance(quest, branch)` |
| ActGates | five-act gate evaluation; emits `act_entered` | `current_act()`, `can_enter(act)` |
| Descent | level scripts, escalating ejection counters, Mirror, Trials of Tension, Threshold, Chamber | `answer(altar, text)` |
| BookOfParagons | meta record across seeds (`user://book.json`) | `record_win(summary)` |
| KnowledgeBase | learned tokens, vocabulary, sources | `learn(token_id, source)`, `knows(id)`, `keywords()` |
| DialogueRuntime | executes templated `.dlg` for an NPC role | `start(npc)`, `say(keyword)`, `answer(bool)` |
| WorldClock / Moons | minutes, day/night, two 8-phase moons | `advance(min)`, `phase(moon)` |
| Gates (MoonTable) | per-seed phase→gate/destination table | `active_gate()`, `destination()` |
| ClanSystem | clan passives, shrine bonuses, magic tier, champion, hall services | `passive(clan)`, `max_circle(clan)` |
| Encounters | spawn tables by terrain/time; monster chase on map | `roll(terrain, time)` |
| BattleState | grid, units, turn order, morale, outcome | `start(map, party, enemies)`, `act(unit, action)` |
| Spellbook / Reagents | mixing, casting, MP | `mix(spell, qty)`, `cast(spell, target)` |
| Camp / Food / Light | rest, ambush, hunger, torches | `camp(hours)`, `tick_step()` |
| Shop / Prices | buy/sell, blind-vendor honesty test | `buy(item)`, `pay(amount)` |
| Journal (UI) | renders KnowledgeBase | read-only view |

## 6. Dialogue Format (`.dlg`)

Custom, readable, diff-friendly text format (parser in `core/dialogue`). Files describe an NPC **role**;
names, places, and the tokens the role holds are bound per seed. Roles are either **slot-generic**
(`role: town.mantra_keeper`, instantiated for each slot) or **virtue-specific** (`role: integrity.notary`,
exists only when that virtue is drawn). Example of a slot-generic role bound to slot `S`:

```
role: town.mantra_keeper
name: {npc.name}
job: I am a scholar of {castle:family_of(S)}, studying the virtue of {virtue:S}.
health: I am well, thank thee.
keywords: {virtue:S}, mantra, {castle:family_of(S)}, shrine

[{virtue:S}]
{creed:S}                                  # pulled from the virtue module

[mantra]
@requires token:{slot.trust}
The mantra of {virtue:S} is {token.mantra:S}. Speak it at the shrine {dir:shrine:S} of {town:S}.
@learn token:{slot.primary}          # bound by KnowledgeGraph to token.mantra:S (or a false variant)
@else
I share that only with those I trust. Art thou truthful?
@ask honesty_test

[honesty_test yes]
@honesty_check                       # lying → @virtue anchor -2
Then I trust thee. Ask me again of the mantra.
@learn token:{slot.trust}

[honesty_test no]
Then why dost thou ask? Go.

[shrine]
The shrine lies {dir:shrine:S} of town, at {coords:shrine:S}.
@learn token:{slot.secondary}

[default]
I know nothing of that.
```

Directives: `@requires`, `@else`, `@learn`, `@virtue`, `@flag`, `@give`, `@take`, `@ask`,
`@honesty_check`, `@ask_log <question_id>` (yes/no/refuse graded by `QuestionGrader` against the Witness
Log), `@rumour <event_filter>` (branch on what this town believes), `@standing <op> <n>` (tavern),
`@join`, `@time`, `@moon`, `@clan`. Template helpers: `{dir:}`, `{coords:}`, `{cap:}`,
`{a:}`, pronouns. `{slot.*}` are token slots filled by `KnowledgeGraph` at generation. Validated by
`tools/validate_data.py` (schema, banlist, no untemplated proper nouns).

## 7. Map Data

- **Overworld:** generated heightmap + biome grid (`Continent.gd`) + `WorldDefinition.locations` for
  entrances/triggers; chunked into 16×16 GridMap sections at runtime.
- **Towns/castles/villages:** assembled at load from `data/templates/` (layout variant + building kits) with
  NPC role spawns; the assembled layout is deterministic from the seed.
- **Dungeons:** `DungeonGen` composes `room_templates` into 8 levels (wall/floor/door/secret/ladder/
  fountain/trap/altar/room-trigger) → runtime GridMap builder; rooms reference battle maps.
- **Battle maps:** JSON grid with terrain per cell, party spawn cells, enemy spawn cells, exits (hand-made,
  chosen by terrain).

## 8. Save System

`GameState` → Dictionary → JSON with `schema_version` and `seed`. State includes the full **Witness Log**,
active rumours, quest states, tavern standings, act, and ejection counters. On load the world is regenerated
from the seed, then state is applied. The **Book of Paragons** is a separate meta file (`user://book.json`). Save anywhere. Autosave on map transition. Migrations in `SaveManager`.
Slots in `user://saves/`. **Generator changes bump `schema_version`** (old seeds must still reproduce, or
saves are flagged incompatible).

## 9. Testing & Validation

- **GUT** unit tests (repo standard, run via `tools/run_tests.ps1`) for `core/` (virtue math, token gating, dialogue parser, moon table bijection,
  combat resolution, save round-trip, **generator determinism**: same seed → identical `WorldDefinition`).
- `core/procgen/Validator.gd` (runtime) and `tools/token_graph.py` (CI, over the abstract graph +
  N sample seeds): end reachable, ≥2 true sources per mandatory token in ≥2 locations, refutations exist.
- **Seed soak test** in CI: generate 200 seeds; all must validate; report timing.
- **Regression suite** (`REGRESSION.md`): scripted seeded runs → `RunStats` compared with golden snapshots;
  ~70 `REG-*` tests over economy, combat, intel, shrines, dungeons/stones, travel, items, virtue/Wisdom,
  party, quests, set pieces, endgame, save/load, determinism; invariant scan that `game/` never reads
  `RunStats.hidden`.
- Headless smoke test: assemble every template variant; verify no missing references.

## 10. Performance Targets

60 FPS at 1080p on integrated graphics (Iris Xe / GTX 1050 class). One map scene at a time; overworld uses
16×16-tile chunks with LOD. Binary < 1 GB.

## 11. Tooling

Godot editor (scenes), Blender (models), Krita/Aseprite (textures/UI), Python 3 (data tools).
Git + LFS for binary assets. Conventional commits. CI validates data and runs tests on push.

