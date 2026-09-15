# Regression — `RunStats` Telemetry and the Headless Regression Suite

(Architecture only: no code exists yet. This document is the specification the Godot
port must satisfy; test IDs here are stable and will be referenced from `tests/regression/`.)

Related: `ARCHITECTURE.md §9`, `WITNESS_LOG.md`, `CRITICAL_PATH.md`, `ITEMS.md`, `DESIGN_REVIEW_2026-09.md`,
`RULES.md §2.8–2.9, §3.5`.

## 1. Purpose

A regression is a **scripted, seeded run through the simulation core** (`core/`, no scenes) whose observable
result is a single `RunStats` record. The suite asserts that record field-by-field against a golden snapshot
and against invariants. Any change to rules, data, or the generator that alters a golden run fails CI until
the snapshot is consciously re-baked.

Two things fall out of one design:

1. **Telemetry** — everything the game must count anyway to drive the Seer, companions, Chamber, and epilogue.
2. **The Pilgrim's Book "Ledger of Days"** — the *public* subset the player may see (§3).

## 2. Ground rules

| Rule | Consequence for this spec |
|---|---|
| Virtue values and conduct counts are hidden (`RULES.md §3.5`, `DESIGN_REVIEW §2`) | `RunStats` is split into `public` and `hidden`. UI code may read `public` only. REG-INV-01 enforces it. |
| Virtue counters gate nothing (`DESIGN_REVIEW §1`) | No test asserts a counter threshold as a *gate*. Gates are knowledge and items: mantra, shrine, 8 virtues, stones, key items, Word. |
| Every `VirtueSystem.apply()` writes exactly one `WitnessEvent` (`WITNESS_LOG.md §1`) | `hidden.virtue.events_total == WitnessLog.size()` always (REG-INV-02). |
| Determinism (`RULES.md §2.9`) | Same seed + same action log ⇒ byte-identical `RunStats` (REG-DET-01). |
| Tokens are binary with category tags (`GAME_DESIGN.md §6`) | Tokens are counted by category and truth; there is no confidence gradient. |
| Data-driven (`RULES.md §3.1`) | Which `action_id` increments which field is a **table** (§4), validated by `validate_data.py`. |

## 3. `RunStats` schema

All integers unless noted. `day`/`minute` from `WorldClock`. Enumerations are closed sets validated by schema.
Fields marked **P** are in the `public` block (visible in the Pilgrim's Book); all others are **hidden**.

### 3.1 Header
```
RunStats {
  schema_version, seed, virtues_drawn: [8 ids], anchor_id, clan_id, class_id,      # P
  started_day, days_elapsed,                                                        # P
  act_entered: { I: day, II: day|null, III: day|null, IV: day|null, V: day|null },  # P
  public: {...}, hidden: {...}
}
```

### 3.2 Gold (`gold`)
| Field | P | Source event |
|---|---|---|
| `gold_now`, `gold_peak` | P | `Inventory.gold_changed` |
| `earned_by: { chest, sell, quest_reward, bounty, bet, theft, gift, found }` | P except `theft` | `gold_changed(delta>0, source)` |
| `spent_by: { shop, inn, healer, stable, ship, fine, ransom, restitution, bribe, donation, tip, upkeep, market_favour }` | P except `bribe` | `gold_changed(delta<0, sink)` |
| `spent_on_self`, `spent_on_others` (donation, ransom, restitution, tip, fine-for-another) | hidden | derived; Wisdom input (`DESIGN_REVIEW §3`) |
| `avarice_bait_taken`, `avarice_bait_refused` | hidden | dungeon temptation floors (`ITEMS.md §6`) |

### 3.3 Combat (`combat`)
| Field | P | Source event |
|---|---|---|
| `battles: { won, lost, fled, avoided }` | P (`won`, `fled` only) | `battle_ended(outcome)` |
| `kills_by: { evil, non_evil_human, animal, fleeing, surrendered, undead, boss }` | hidden | `unit_killed(faction, state)` |
| `subdues` | hidden | `unit_subdued` |
| `spared_fleeing`, `spared_surrendered` | hidden | `battle_ended` scan of marked units alive |
| `party_deaths`, `resurrections` | P | `member_died`, `member_resurrected` |
| `camp_ambushes` | P | `camp_interrupted` |
| `first_strike_on_guardians` (Humility shrine fiends) | hidden | `set.guarded_shrine` |

### 3.4 Intel (`intel`)
| Field | P | Source event |
|---|---|---|
| `tokens_held_by_category: { mantra, shrine_location, town_location, castle_location, dungeon_location, dungeon_stone, magic_item_location, sigil, password, word_syllable, codex, person, lore, recipe, rule }` | P | `token_learned(id)` |
| `tokens_false_held`, `tokens_false_acted_on`, `tokens_refuted` | hidden | `token_learned(truth=false)`, `token_used(truth=false)`, `token_refuted` |
| `sources_by_kind: { npc, book, sign, vision, dream, item, observation, clan_hall, ghost }` | P | `token_learned(source_kind)` |
| `npcs_spoken`, `npcs_spoken_unique`, `conversations_total` | P | `dialogue_started` |
| `keywords_chipped`, `keywords_typed`, `keywords_guessed_correct` | P | `keyword_spoken(method)` |
| `honesty_tests: { truthful, lied, refused }` | hidden | `@honesty_check` |
| `ingame_questions: { truthful, lie, boast, humble_denial, refused }` | hidden | `QuestionGrader.grade` |
| `rumours_about_player: { true, false, corrected }` | hidden | `Rumours` |
| `moon_table_phases_learned` (0–8), `conjunctions_observed` | P | `Gates` |

### 3.5 Travel (`travel`)
| Field | P | Source event |
|---|---|---|
| `steps_total` | P | `step_taken(cell)` |
| `steps_by_terrain: { road, grass, forest, hills, swamp, mountain_pass, desert, beach, town, dungeon }` | P | `step_taken(cell.terrain)` |
| `distance_by_mode: { foot, horse, ship, balloon, gate, whirlpool, wind_ship }` | P | `moved(mode, cells)` |
| `regions_visited` (of 8), `locations_visited_unique`, `minor_sites_found` | P | `map_changed` |
| `gates_used`, `gate_misjumps` (destination not intended) | P / hidden | `Gates.travel` |
| `nights_camped`, `nights_inn`, `nights_dungeon` | P | `camped(where)` |
| `night_roads_taken` | hidden | Courage scenario |
| `tolls_paid`, `tolls_refused` | hidden | route scenarios (`DESIGN_REVIEW §6`) |

### 3.6 Survival (`survival`)
| Field | P | Source event |
|---|---|---|
| `rations_bought`, `rations_consumed`, `rations_given_away` | P / P / hidden | `Food` |
| `nights_hungry` (camp with no rations; no healing) | P | `Food.camp_without_food` |
| `torches_lit`, `dark_steps` | P | `Light` |
| `reagents_gathered_wild`, `spells_mixed`, `spells_cast` | P | `Reagents`, `Spellbook` |

### 3.7 Shrines and mantras (`shrines`, per slot 1..8)
| Field | P | Source event |
|---|---|---|
| `mantra_sources_heard` (true), `mantra_false_heard` | P / hidden | `token_learned(category=mantra)` |
| `shrine_found_day` | P | `map_changed(shrine)` |
| `attempts_wrong_mantra`, `attempts_wrong_shrine` | hidden | `shrine_rejected(reason)` |
| `meditated_day` (null if not) | P | `virtue_granted(slot)` |
| `meditation_order` (1..8) | P | derived |
| `companion_joined_day` | P | `companion_joined` |
| `virtues_granted_total` (0–8) | P | derived; **gate for stones** |

### 3.8 Dungeons (`dungeons`, per slot 1..8 + `end`)
| Field | P | Source event |
|---|---|---|
| `location_token_held` | P | intel |
| `enters`, `exits_early` (left before bottom) | P | `map_changed` |
| `deepest_level` (0–8), `levels_cleared` | P | `dungeon_level_entered` |
| `bottom_reached_day` | P | `dungeon_level_entered(8)` |
| `temptation_floors: { resisted, taken }` | hidden | vice module floors |
| `camps_inside` | P | `camped(dungeon)` |
| `bottom_item_recovered` (`stone` or magic item id; null) | P | `item_found(source=dungeon_bottom)` |
| `stone_taken_day` (null while `virtues_granted_total < 8`) | P | `stone_taken` |
| `ring_bound_day` (altar room binding; Act IV) | P | `ring_bound(slot)` |

### 3.9 Items (`items`) — see `ITEMS.md`
| Field | P | Source event |
|---|---|---|
| `bought_by_tier: { village, town, castle }`, `bought_by_type: { weapon, armor, tool, reagent, consumable, ration, light, magic }` | P | `item_bought(item, seller_tier)` |
| `found_by: { chest, loot, quest, dungeon_bottom, set_piece, hidden_cache }` | P | `item_found(source)` |
| `sold`, `given_away`, `dropped` | P / hidden / P | `item_removed(reason)` |
| `stolen` | hidden | `item_removed(reason=theft)` / `chest_opened(owned=true)` |
| `magic_items: { known_locations, found, used, destroyed }` | P | `ITEMS.md §5` |
| `key_items: { horn, ring, artifacts[3], word_syllables[3], warding_item, temptation, codex_answer }` (day found each) | P | `item_found(key=true)` |
| `equipped_max_tier_weapon`, `equipped_max_tier_armor` | P | `equipped` |
| `gilded_at_shrine` | hidden | Humility scenario |

### 3.10 Virtues (`virtue`) — **hidden entirely**
| Field | Source |
|---|---|
| `counters[8]` (0–100), `bands[8]` (lost/seeking/worthy/exemplary), `band_transitions[8]` list of (day, from, to) | `virtue_changed` |
| `events_total`, `events_by_action_id{}`, `events_public`, `events_avoided` | `WitnessLog.record` |
| `per_scenario_event_count{}` (anti-grind cap; `DESIGN_REVIEW §2.3`) | `WitnessLog` |
| `wisdom: { pair_gains: { <pair>: {a, b, both} }, extremes_hit, humility_multiplier, score, band }` | `WisdomScorer` |
| `seer_visits`, `seer_readings[]` (day, 8 verdicts, wisdom verdict if unlocked) | `Seer` |

### 3.11 Party (`party`, per companion + champion)
| Field | P | Source |
|---|---|---|
| `joined_day`, `left_day[]`, `returned_day[]`, `days_in_party` | P | `companion_*` |
| `events_witnessed`, `events_approved`, `events_disapproved` | hidden | `WitnessLog.party_present` × module lens |
| `loyalty_min`, `loyalty_max`, `loyalty_final` | hidden | `Loyalty` |
| `arc_state` (not_started / active / resolved:<id>) | P | `QuestRuntime` |
| `camp_arguments` (per pair) | hidden | `Camp` |
| `final_judgement` (honest / unseen / none; text id) | hidden | Threshold/Chamber (`DESIGN_REVIEW §4`) |

### 3.12 Quests and set pieces (`quests`, `set_pieces`)
| Field | P | Source |
|---|---|---|
| `per_tier: { heart, street, ledger }: { placed, started, resolved, avoided }` | P (`started`, `resolved`) | `QuestRuntime` |
| `resolutions[]` (quest_id, branch_id, day) | hidden | `QuestRuntime.advance` |
| `followups_fired` | hidden | scheduler |
| `set_pieces{ drowned_court, bell_in_the_deep, corsair_fleet, maelstrom_gate, wind_ship, assize, silent_monastery, mirror_ford, debtors_isle, long_night }: { visited_day, outcome }` | P (visited) / hidden (outcome) | set piece scripts |
| `tavern_standing_min/max` per tavern | hidden | `TavernStanding` |

### 3.13 Endgame (`endgame`)
| Field | P | Source |
|---|---|---|
| `stones_held` (0–8), `ring_bindings` (0–8) | P | §3.8 |
| `horn_found_day`, `artifacts_found` (0–3), `word_syllables` (0–3), `warding_item_day` | P | key items |
| `codex_answer: { principle_id, sources_heard, source_kinds[] ⊆ {ghost, observation, silence}, false_heard, false_bought, held_day, word_road, lines_held (0–8), lines_by_source{} }` | P (held, lines_held) / hidden | `QUEST_TREE.md §4` |
| `chamber.meaning: { asked_pair, answered_pair, correct }` | hidden | Chamber part 2 |
| `party.condition` (fed / weary / starving / famished), `weary_days`, `starving_days`, `famished_days`, `hunger_unconscious`, `hunger_collapses`, `maxhp_lost_to_hunger` | P | `Food` |
| `gold.spent_by.rations`, `gold.spent_by.reagents`, `gold.spent_by.gear` (split of `shop`) | P | `Shop` — the three claimants on monster gold |
| `hermitage: { visited_day, silent_nights (0–3), resets, fed_by_anchorite }` | P (visited) / hidden | Hermitage script |
| `monastery: { saw_abbot_bow_ninth, knelt_before_seeing, knelt_after }` | hidden | Monastery script |
| `boasted_to_dead` | hidden | ruined-city ghosts (Act IV) |
| `reflection` (string, ≤ 3 lines, verbatim) | P after win | Chamber (`CRITICAL_PATH.md §6.4`); never graded |
| `descent_entered_day` | P | `act_entered(V)` |
| `long_night: { companion_questions_asked, answered_truthful, choice: alone|together }` | P (choice) / hidden | L0 script |
| `doors: { level: { opened_by: item|log|testimony|avoidance, attempts } }` (L1–4: Ward / Deed / Witness / Unopened) | hidden | Descent |
| `mirror: { named, fought, rounds }` | hidden | L5 |
| `tension_resolutions[]` (pair, side|both) | hidden | L6–7 → Wisdom |
| `threshold: { path, companions_present, companions_left_behind, temptation: unused|used|destroyed }` | hidden | L8 |
| `chamber: { questions_asked, correct, wrong, refused, enacted_correct }` | hidden | Chamber |
| `final_word: { attempts, correct_day, ejections_to_surface }` | P (day) / hidden | Chamber |
| `epilogue: { wisdom_band, virtue_lines[8], slides_shown[], hidden_slide }` | hidden until win, then P | `Epilogue` |
| `book_of_paragons_written` (bool) | P | `BookOfParagons.record_win` |

## 4. Event → stat mapping

Lives in `data/telemetry/stat_map.json` and is validated: every `EventBus` signal and every `action_id` in
every module's action table must map to ≥1 field, and every hidden field must be reachable from ≥1 event.

```
{ "event": "unit_killed", "when": { "faction": "non_evil_human" },
  "inc": ["hidden.combat.kills_by.non_evil_human"],
  "also_requires": ["WitnessLog.event(public=true)"] }        # REG-INV-04
{ "event": "step_taken", "inc": ["public.travel.steps_total", "public.travel.steps_by_terrain.{terrain}"] }
{ "event": "virtue_granted", "set": ["public.shrines.{slot}.meditated_day=day"],
  "inc": ["public.shrines.virtues_granted_total"] }
{ "action_id": "gave_to_beggar", "inc": ["hidden.virtue.events_by_action_id.gave_to_beggar",
  "hidden.gold.spent_on_others"] }
```

## 5. Harness

```
tests/
  regression/
    ScriptedRun.gd        # loads an action log, drives core/ headless, returns RunStats
    GoldenCompare.gd      # field-wise diff with tolerance classes
    invariants.gd         # REG-INV-*
    test_reg_*.gd         # one file per §6 group
  golden/
    <seed>_<archetype>.actions.json   # the script
    <seed>_<archetype>.stats.json     # the expected RunStats
```

**Action log** — a list of `{ t, action, args }` where `action` ∈ {`move`, `enter`, `talk`, `say`, `answer`,
`buy`, `sell`, `give`, `attack`, `subdue`, `flee`, `cast`, `camp`, `meditate`, `open_chest`, `use_item`,
`take_stone`, `kneel`, `choose` (dilemma/quest branch), `wait_until(moon)`, `wait_until(dawn)`,
`reflect(text)`}. Actions reference archetype IDs, never names, so a script is valid for any seed that draws
the same eight virtues.

**Tolerance classes** — `exact` (every counter, day, order, enum); `band` (virtue counters compare by band,
not value — data tuning may move numbers without failing CI); `set` (order-insensitive lists).

**Hidden-block discipline** — `RunStats.public()` returns a copy of the public block; `hidden` is accessible
only via `RunStatsTestAccess` in `tests/`. A static scan (REG-INV-01) fails if any file under `game/`
references `hidden.`.


## 6. Regression suite

Priority: **A** required for M1 (core), **B** for M2, **C** for M4.

### 6.1 Economy
| ID | Pri | Assertion |
|---|---|---|
| REG-ECO-01 | A | Buying at village/town/castle increments `bought_by_tier` and `spent_by.shop`; gold never negative. |
| REG-ECO-02 | A | Selling increments `earned_by.sell`; sale price < buy price for the same tier (`ITEMS.md §3`). |
| REG-ECO-03 | B | Paying the blind vendor short → `honesty_tests.lied`, one anchor-virtue loss event; paying fair → `truthful`. |
| REG-ECO-04 | B | `spent_on_others` = Σ(donation, ransom, restitution, tip, fine-for-another); `spent_on_self` = Σ(rest). |
| REG-ECO-05 | C | Drowned Court `both` (pay the Magistrate's debt) sets `set_pieces.drowned_court.outcome=freed_all`, `gold_now < 10%` of peak, `wisdom.pair_gains.*.both += 1`. |
| REG-ECO-06 | B | Avarice temptation floor: taking gold → `avarice_bait_taken`, one Selflessness loss event; refusing → `avarice_bait_refused`. |
| REG-ECO-07 | A | `gold_peak ≥ gold_now` always; `Σearned − Σspent == gold_now − starting_gold`. |

### 6.2 Combat
| ID | Pri | Assertion |
|---|---|---|
| REG-CMB-01 | A | Killing an evil unit increments `kills_by.evil` only; no Witness event. |
| REG-CMB-02 | A | Killing a fleeing unit increments `kills_by.fleeing` and writes one event with the module-defined losses. |
| REG-CMB-03 | A | Killing a non-evil human increments `kills_by.non_evil_human` **and** produces a `public=true` event (`RULES.md §3.26`). |
| REG-CMB-04 | A | Subdue is offered in every battle containing a non-evil human; `subdues` increments; no kill counted. |
| REG-CMB-05 | B | Fleeing a battle increments `battles.fled` and writes a Courage-loss event iff Courage is drawn. |
| REG-CMB-06 | B | Party death and resurrection counts round-trip through save/load. |
| REG-CMB-07 | C | Striking the Humility guardians first sets `first_strike_on_guardians` and locks the shrine until the band recovers. |

### 6.3 Intel
| ID | Pri | Assertion |
|---|---|---|
| REG-INT-01 | A | Learning a token increments its category exactly once; relearning from a second source increments `sources_by_kind` but not `tokens_held`. |
| REG-INT-02 | A | A false token increments `tokens_false_held`; using it (shrine/guard) increments `tokens_false_acted_on` and costs the documented penalty (a day / an insulted guard). |
| REG-INT-03 | A | Learning a refutation increments `tokens_refuted` and the false token no longer appears as a keyword chip. |
| REG-INT-04 | A | Typed keyword that matches a hidden topic → `keywords_guessed_correct`; journal records the source. |
| REG-INT-05 | B | Honesty test outcomes route to the anchor virtue module; `lied` writes an Integrity/Justice loss event. |
| REG-INT-06 | B | In-game question grid (`WITNESS_LOG.md §5`): all 5 answer×log combinations produce the documented result; `humble_denial` gains Humility. |
| REG-INT-07 | C | Rumour correction at an innkeeper increments `rumours_about_player.corrected` and spawns a competing rumour. |
| REG-INT-08 | A | Every mandatory token in the generated world has ≥2 true sources in ≥2 locations (per seed). |

### 6.4 Shrines / mantras / virtues granted
| ID | Pri | Assertion |
|---|---|---|
| REG-SHR-01 | A | Meditation with unknown mantra → `attempts_wrong_mantra`, no virtue granted, no counter change. |
| REG-SHR-02 | A | Correct mantra at wrong shrine → `attempts_wrong_shrine`, no grant. |
| REG-SHR-03 | A | Correct mantra at correct shrine → `virtue_granted`, `meditated_day` set, `virtues_granted_total += 1`, companion of that slot becomes recruitable — **regardless of counter value** (run twice: counter = 0 and = 100). |
| REG-SHR-04 | A | Humility shrine refuses before `virtues_granted_total ≥ 4` even with the correct mantra. |
| REG-SHR-05 | A | Once granted, a virtue is never revoked (no path sets `meditated_day` back to null). |
| REG-SHR-06 | B | `meditation_order` is a permutation of 1..k; slot 8 is last when k = 8. |
| REG-SHR-07 | B | Companion join requires `meditated_day != null` for its slot (`RULES.md §3.8`). |


### 6.5 Dungeons and stones
| ID | Pri | Assertion |
|---|---|---|
| REG-DNG-01 | A | Entering a dungeon increments `enters`; leaving before level 8 increments `exits_early`. |
| REG-DNG-02 | A | `deepest_level` is monotone per dungeon; `bottom_reached_day` set on first level-8 entry. |
| REG-DNG-03 | A | Every generated dungeon has its stone at the bottom (generator validator). |
| REG-DNG-04 | A | `take_stone` with `virtues_granted_total < 8` fails: `stone_taken_day` stays null, message logged, no item. |
| REG-DNG-05 | A | With all 8 virtues, `take_stone` succeeds; `stones_held += 1`; the stone appears in `key_items`. |
| REG-DNG-06 | B | Temptation floor accounting per vice (`ITEMS.md §6`); a Cowardice exit taken on a temptation floor counts as `temptation_floors.taken`, not `exits_early`. |
| REG-DNG-07 | B | Ring binding at an altar room requires the stone + the slot's sigil; `ring_bindings` reaches 8 only after slot 8 (Pride) — only then is the end island reachable. |
| REG-DNG-08 | C | A dungeon bottom holding a magic item (`ITEMS.md §5`) records `bottom_item_recovered = <id>` and `magic_items.found += 1`. |

### 6.6 Travel & survival
| ID | Pri | Assertion |
|---|---|---|
| REG-TRV-01 | A | `steps_total == Σ steps_by_terrain`; one `WorldClock.advance(1)` per overworld step. |
| REG-TRV-02 | A | Ship/horse/balloon/gate movement increments `distance_by_mode` and not `steps_total`. |
| REG-TRV-03 | B | Gate travel at each of 8 phases lands at the seed's table destination (bijection); `gate_misjumps` increments when `args.intended != actual`. |
| REG-TRV-04 | B | Camping consumes one ration per member; with none, `nights_hungry += 1`, no HP healed, `party.condition = weary` next day (−1 initiative, `mix_reagents` refused); 2nd consecutive hungry night → `starving` (no MP regen, MaxHP −10 % at dawn); 3rd+ → `famished` (MaxHP −20 %, STR/DEX −1, step cost 2 min); eating any ration resets the state; MaxHP recovers over fed nights. **No per-step food attrition**: `rations_consumed` unchanged over 1000 steps without camping. *(re-baked 2026-09-07)* |
| REG-TRV-05 | B | Villages always stock rations; the wild never does. |
| REG-TRV-07 | A | **Hunger never gates** (`RULES.md §3.29`): 30 consecutive hungry camps → no member's `alive` flag ever false (hunger sets `unconscious`, never death), no move/talk/meditate/door action refused (only `mix_reagents`), no `virtue_changed` event fires from `Food`. Static scan: no `ActGates`, `Shrine`, `Descent`, or `Dialogue` code reads `Inventory.rations` or `party.condition`. *(re-baked 2026-09-07)* |
| REG-TRV-09 | B | **Collapse**: all members unconscious by hunger → party relocated to nearest inn/healer, `hunger_collapses += 1`, `debt_owed > 0` (gold or Ledger errand), days advanced, one `public=true` Witness event (`found_starving`) and a rumour spawned; first ration/inn afterwards revives all. Unconscious members write `hunger_unconscious += 1` and are `carried` (no actions) until fed. |
| REG-TRV-08 | B | Giving a ration to a hungry NPC removes it, increments `rations_given_away`, writes a Compassion/Kindness event; if it was the party's last, `action_id = gave_last_ration` (heavier weight per module). Ration prices by tier equal `prices.json` (2 / 5 / 8 base). |
| REG-TRV-06 | C | Night-road route choice writes a Courage event and increments `night_roads_taken`. |

### 6.7 Items
| ID | Pri | Assertion |
|---|---|---|
| REG-ITM-01 | A | Tier availability: village sellers never stock castle-tier gear; castle sellers stock all tiers (`ITEMS.md §3`). |
| REG-ITM-02 | A | `found_by.chest` increments on chest open; an owned chest additionally increments `stolen` and writes a Justice/Integrity event. |
| REG-ITM-03 | B | Giving an item to an NPC in need increments `given_away` and the module's Selflessness/Compassion event. |
| REG-ITM-04 | B | Magic-item location token → `magic_items.known_locations`; finding it → `found`; every generated magic item has ≥1 location token source. |
| REG-ITM-05 | C | Using the Temptation zeroes all 8 counters, sets `wisdom.band = unbalanced` (locked), sets `threshold.temptation = used`. Destroying it at L8 yields the largest single Wisdom gain in the run. |
| REG-ITM-06 | A | `key_items` day fields are set at most once and never cleared. |

### 6.8 Virtue & Wisdom (hidden)
| ID | Pri | Assertion |
|---|---|---|
| REG-VIR-01 | A | `events_total == WitnessLog.size()`; every event has ≥1 `virtue_effects` entry for a drawn virtue. |
| REG-VIR-02 | A | Counters clamp 0..100; `band()` matches thresholds in `data/virtue/thresholds.json`. |
| REG-VIR-03 | A | Actions for non-drawn virtues are no-ops (no event, no counter). |
| REG-VIR-04 | B | Anti-grind: the Nth repeat of the same `scenario_id` beyond the module cap (default 3) writes an event with weight 0 (`DESIGN_REVIEW §11.2`); the counter is unchanged; `per_scenario_event_count` still increments. |
| REG-VIR-08 | B | Anti-grind is diegetic, not punitive (`RULES.md §3.30`): beyond the cap the recipient's dialogue takes the `@capped` branch (a refusal line exists for every capped scenario — data validator), **no** negative `virtue_effects` are written, and no UI string contains the word "cap" or a number. |
| REG-VIR-05 | B | Wisdom: `balance` formula per pair; `both` bonus; extremes penalty (99+ vs <25); Wisdom ≤ seeking while Humility is lost. |
| REG-VIR-06 | B | `seer_readings` show no Wisdom verdict before Humility is granted and always after. |
| REG-VIR-07 | A | **Counters never gate**: static scan — no `ActGates`, `Shrine`, `Dungeon`, `Companion` code path reads `counters[]` to decide access. |

### 6.9 Party
| ID | Pri | Assertion |
|---|---|---|
| REG-PTY-01 | A | `events_witnessed` for a companion == count of log events with them in `party_present`. |
| REG-PTY-02 | B | Companion leaves at loyalty threshold; `left_day` appended; re-recruit after amends appends `returned_day`. |
| REG-PTY-03 | C | Final judgement: a companion with `events_witnessed < floor` yields `unseen` (never a condemnation); otherwise `honest` text chosen from the module by lens (`DESIGN_REVIEW §4`). |
| REG-PTY-04 | C | Camp argument fires only when both companions of an active pair are present and the pair's imbalance exceeds threshold. |

### 6.10 Quests and set pieces
| ID | Pri | Assertion |
|---|---|---|
| REG-QST-01 | B | Placement counts per tier within `PROCEDURAL_GENERATION.md` stage 8c ranges for every seed. |
| REG-QST-02 | B | Every resolution and the avoidance branch write exactly the template's events; `avoided=true` on walk-away. |
| REG-QST-03 | C | Followups fire at `after_days` in the specified location and not earlier. |
| REG-SET-01 | C | All 10 set pieces are placed in every seed; each records an outcome enum on completion. |
| REG-SET-02 | C | Wind-Ship: refused while Humility band is below the fixed floor; speed scales per `SET_PIECES.md §5`. |


### 6.11 Endgame
| ID | Pri | Assertion |
|---|---|---|
| REG-END-01 | A | Act gates: II ⇐ ruler named the eight; III ⇐ `virtues_granted_total ≥ 4`; IV ⇐ `== 8`; V ⇐ `ring_bindings == 8 ∧ horn ∧ artifacts == 3 ∧ word_syllables == 3`. Each condition is necessary (one negative test per condition). |
| REG-END-02 | A | **Binding Word** (`QUEST_TREE.md §4`): generator places exactly three true sources with `source_kinds == {ghost, observation, silence}` (ruined city / Monastery ninth plinth / Hermitage), plus one false variant at the Drowned Court whose `refuted_by` includes the Anchorite and `{companion:humility}`; `site.hermitage` lies on the far bank of the Mirror Ford. *(re-baked 2026-09-07)* |
| REG-END-03 | B | Long Night: one question per companion present; `choice` recorded; the Threshold later *enacts* the same choice (cannot differ). |
| REG-END-04 | B | The four doors L1–4 record `opened_by ∈ {item, log, testimony, avoidance}` in that fixed order; L1 (Ward) never ejects; L2–4 eject only on a graded `lie`; no door reads a knowledge token; ejection follows `CRITICAL_PATH.md §6.1`. *(re-baked 2026-09-07)* |
| REG-END-05 | B | Mirror: typing the correct vice name dissolves it (`named=true`); fighting to victory sets `fought=true` and grants nothing. |
| REG-END-06 | B | Tension resolutions append to `wisdom.pair_gains`. |
| REG-END-07 | A | Chamber final question: correct iff `codex_answer.held_day != null` and the player types it; wrong → `ejections_to_surface += 1`, act stays V, Humility shrine re-meditation required before retry. |
| REG-END-08 | C | Epilogue order fixed (8 sections); `hidden_slide` iff `wisdom.band == whole ∧ temptation == destroyed ∧ companions_left_behind == 0 ∧ all 8 companions kept`. |
| REG-END-09 | A | `book_of_paragons_written` true exactly once per win; the entry has 8 virtues, wisdom band, threshold path, `word_road`, and `reflection`. |
| REG-END-10 | B | Hermitage (`QUEST_TREE.md §4.3`): `hermitage.silent_nights` increments per camp with zero `talk` actions and no map change; any `talk` or exit resets it to 0; the Word is learned (`source_kind=silence`) iff it reaches 3. Arriving with `rations == 0` sets `fed_by_anchorite` and writes a Kindness event with the player as *subject*. |
| REG-END-11 | B | Monastery ninth plinth: `kneel` before `saw_abbot_bow_ninth` learns nothing; after it, learns the Word (`source_kind=observation`). Ghost road: answering *yes* to the last ruler sets `boasted_to_dead` and learns nothing that night; *no* learns the Word (`source_kind=ghost`), only if `virtues_granted_total == 8`. |
| REG-END-12 | A | The reflection: stored byte-identical to input (≤ 3 lines), never passed to any grader; no `virtue_changed` or `wisdom_changed` event fires between the correct Word and `book_of_paragons_written`. Static scan: no NPC dialogue file references `endgame.reflection`. |
| REG-END-13 | B | Acting on the Court's false Word in the Chamber → `ejections_to_surface += 1`, `tokens_false_acted_on += 1`; after Humility re-meditation, `codex.road.*` Person tokens and all eight `codex.line.*` tokens are held. |
| REG-END-14 | A | **Principle derivation is deterministic and seed-dependent** (`QUEST_TREE.md §4.0.3`): for every seed in the soak, `codex.principle_id` = argmax Σaffinity over eligible principles (affinity ≥1 with ≥6 of the drawn 8); two seeds with the same eight and flavour yield the same principle; `{final_word}` ∈ that principle's labels; the 924 launch draws all have ≥1 eligible principle (else the validator redraws and this test flags the draw). |
| REG-END-15 | A | **Meaning test**: after the correct word the Chamber names virtues A, B (from `wisdom.pair_gains`, else the two most-imbalanced); answering with `codex.line.A` + `codex.line.B` → `chamber.meaning_correct = true`; any other pair, or fewer than two lines held → false and `ejections_to_surface += 1`. The answer chips are exactly the lines with `held_day != null`. |

### 6.12 Invariants, save/load, determinism
| ID | Pri | Assertion |
|---|---|---|
| REG-INV-01 | A | No file under `game/` references `RunStats.hidden` (static scan). |
| REG-INV-02 | A | `hidden.virtue.events_total == WitnessLog.size()` at every checkpoint. |
| REG-INV-03 | A | `stones_held > 0 ⇒ virtues_granted_total == 8`. |
| REG-INV-04 | A | `kills_by.non_evil_human > 0 ⇒ ∃ event with public=true`. |
| REG-INV-05 | A | `ring_bindings == 8 ⇒ ring_bound_day[8] == max(ring_bound_day[])`. |
| REG-INV-06 | A | `Σ tokens_held_by_category ≤ tokens in the seed's graph`; `tokens_false_held ≤ false slots placed`. |
| REG-SAV-01 | A | `RunStats` round-trips `save() → load()` byte-identical; `schema_version` present; migration from N−1 keeps all fields. |
| REG-SAV-02 | B | Save mid-Descent and reload: doors, ejection counters, Long Night choice preserved. |
| REG-DET-01 | A | Same seed + same action log, run twice ⇒ identical `RunStats` (hash). |
| REG-DET-02 | B | Same action log on two seeds with the same drawn eight ⇒ identical `public.shrines.meditation_order` and `virtues_granted_total` (names differ, structure does not). |

## 7. Golden archetype runs

Five scripted runs on **the vertical-slice seed** (`DESIGN_REVIEW §8`; fixed draw: integrity, compassion,
kindness, justice, courage, selflessness, loyalty, humility). Each is a complete start→win script.

| Run | Conduct | Expected hidden outcome |
|---|---|---|
| `saint` | gives, spares, truthful, pays blind vendor fairly, carries and destroys the Temptation, Together; Word by **the Silent** | all bands worthy+; wisdom `whole` or `discerning`; hidden slide iff all companions kept; `word_road == observation` |
| `pragmatist` | trades favours at the Court, **buys the false Word**, fights fair, lies once under duress, Alone; ejected once, then the Word by **the Dead** | wisdom `seeking`/`discerning`; `false_bought = true`, `ejections_to_surface == 1`; anchor companion judgement `honest`; `word_road == ghost` |
| `butcher` | kills fleeing, kills non-evil in the bar fight, uses the Temptation; Word by **the Dead** | all 8 virtues still granted (knowledge gates only), stones still gathered, wisdom `unbalanced`, ≥3 public events, ≥2 companions left |
| `lucky_liar` | lies on every honesty test but is never publicly witnessed; Word by **the Still** (talks to no one for three days — the one road that suits a liar) | rumours `false=0`; log records all lies; Together path fails ≥6 of 8 companion questions; wisdom `seeking` at best; `word_road == silence`; L2 Deed door ejects once |
| `hermit` | minimal talk (exactly the ≥2-source minimum), no quests, dungeon-first, camps hungry often; Word by **the Still**, arriving with no rations | `quests.started == 0`; `nights_hungry ≥ 10`, `famished_days ≥ 1`, `hunger_unconscious ≥ 1`, no member dead; Chamber asks "never tested in {virtue}. Why?" for ≥4 virtues, all pass; `fed_by_anchorite = true`; `word_road == silence` |

Every golden run also collects ≥2 virtue-lines by a different route (`saint`: statues; `pragmatist`: the
Dead; `butcher`: royal library; `lucky_liar` / `hermit`: the Anchorite's dreams), passes the meaning test
(REG-END-15) on the slice seed's principle, and ends by writing a fixed `reflection` string asserted
byte-identical (REG-END-12). `hermit` additionally reaches `famished` once and has one member fall
`unconscious` by hunger without dying (REG-TRV-07).

Golden files are re-baked only by a commit whose message contains `rebake-golden:` with a reason.

## 8. CI

1. `validate_data.py` — includes `stat_map.json` completeness (§4).
2. `tests/regression/` — A-priority on every push; B on main; C nightly.
3. **200-seed soak** (`ARCHITECTURE.md §9`) extended: for each seed run `hermit` (structure-only script) and
   assert REG-INT-08, REG-DNG-03, REG-END-02, REG-INV-*.
4. Report: per-run `RunStats.public` summary table in the CI artefact for eyeballing balance drift.

