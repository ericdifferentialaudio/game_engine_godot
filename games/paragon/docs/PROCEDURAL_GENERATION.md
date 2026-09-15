# Procedural Generation & Replayability

**Design rule: randomize geography, names, and the *arrangement* of knowledge — never the rules.**
Players re-learn *where* things are and *what they're called*, not *how* the world works.

## 1. Seed

- A 64-bit seed drives every generator via `Game.rng` sub-streams (`rng.derive("continent")`, etc.).
- Shown on the title screen and in the journal; enterable at New Game for sharing.
- **Daily Pilgrimage:** a shared fixed seed per calendar day.
- Seed + `schema_version` stored in the save; the world is regenerated deterministically on load (only
  *state* is saved, not the map).

## 2. Generation Pipeline (in order; each stage validated before the next)

| Stage | Output | Validation |
|---|---|---|
| 1a. Virtue draw | 8 virtues from the pool of 15: Humility (slot.8) + anchor (Integrity/Justice, slot.1) + 6 under family/conflict constraints (`VIRTUES.md §4`); active conflict pairs; top-3 families → Houses | ≥6 families, ≥2 full conflict pairs, ≤2 per family |
| 1b. Names | Flavor choice; all archetype names incl. virtue synonym labels; mantras/passwords (`NAMING_AND_LORE.md`) | uniqueness, banlist |
| **1c. Binding principle** | Score the 12 principles (`data/codex/principles.json`) by Σ affinity over the drawn eight; eligible = affinity ≥1 with ≥6 of 8; pick max (RNG tie-break); `{final_word}` = a label of that principle in the seed's flavor; bind the eight virtue-lines `codex.line.slot.1..8` (`QUEST_TREE.md §4.0.3`) | eligible non-empty, else redraw 1a; label unique in seed |
| 2. Continent | Heightmap (noise + tectonic mask), biomes, rivers, coast, one hidden inland lake, mountain ranges | land ratio 35–50%, ≥1 sea-reachable coast per region |
| 3. Regions | 8 regions (one per drawn virtue), each with a biome bias from the virtue module | contiguous |
| 4. Placement | Anchor town (slot.1) central; 3 virtue towns by road, 3 across water, ruined city (slot.8) on a far coast; royal seat near anchor; 3 Houses one per region cluster with a Word keeper each; 4–6 villages (incl. market); 8 dungeons (Pride dungeon adjacent to the end-dungeon island); 8 shrines (slot.8 guarded; anchor shrine ≤1 day from anchor town); 8 gates; ~12 minor sites; starting gate | min/max distances, walkable/sailable connectivity graph; ship obtainable in Act II |
| 4b. Set pieces | Drowned Court on the strait to the Houses; Debtor's Isle beyond; Corsair Fleet on the strait (navy ship nearest royal seat); Bell wreck ≤1 day's sail from the Court; Maelstrom in inner sea → hidden lake; Silent Monastery adjacent to a House; Mirror Ford on the end-island approach; **Hermitage one day upriver on the Ford's far bank**; Long Night shore; Wind-Ship in the Pride dungeon (`SET_PIECES.md`) | all 11 placed; Court reachable at low tide; Hermitage unreachable without crossing the Ford |
| 5. Transport | Roads between towns, bridges, ship spawn, balloon site, whirlpool → hidden lake | every location reachable by foot / ship / gate |
| 6. Moon table | Gate-phase → open gate; dest-phase → destination; conjunction → hidden shrine | bijective |
| 7. Dungeons | 8 levels each from room templates + corridors; traps/fountains; three authored temptation floors; **stone on level 8 behind the third temptation floor** (`ITEMS.md §6`); altar room on level 8; altar rooms linking dungeons | solvable, stone reachable |
| 8. Knowledge graph | Assign each of the **50 mandatory tokens** (incl. the 8 virtue-lines) (`QUEST_TREE.md §3`) to ≥2 NPC/book/dream sources across ≥2 locations; the Binding Word to exactly three sources of kinds `ghost / observation / silence` plus its false variant at the Court; place other false tokens with refutations | `token_graph` solvable |
| 8b. Scenarios | Place 4–6 Witness-Log scenarios per drawn virtue from `scenarios.json` (never all) into matching locations; bind in-game and Chamber question templates | each drawn virtue ≥4 scenarios |
| 8c. Side quests | Place 24–35 quest templates (8–12 Heart, 10–15 Street, 6–8 Ledger) by location archetype; Ledger quests to boards at royal seat + market; no followup collisions | tier minimums met |
| 9. Twists & dilemmas | Activate one dilemma per fully-present conflict pair (mandatory); choose 6–8 further twists from the pool, preferring the drawn virtues' conditional twists; wire flags/NPCs | no conflicts |
| 10. Encounters & loot | Tables per region/biome/time; reagent spawn sites tied to moon phases | coverage |
| 11. Clans | Assign clan homelands to regions; patron virtues per constrained table (`CLANS.md`) | 12 halls placed |

Generation runs at New Game (< 10 s target), with a progress screen styled as the seer's vision.

## 3. Fixed vs. Random

| Fixed (hand-authored) | Random per seed |
|---|---|
| The 15 virtue modules (meanings, vices, actions, companions), Wisdom scoring, thresholds | **Which 8 virtues** are drawn (Humility + anchor fixed); virtue display labels |
| The 5 conflict-pair dilemma templates | Which are active (depends on draw) |
| The five-act spine, Threshold, Descent level scripts, Chamber question *templates*, epilogue order | Which scenarios/quests occurred → which Chamber questions are generated |
| The dependency tree (`QUEST_TREE.md §1`); the three Word roads and their kinds; the 12 binding principles, their affinities, the 180 virtue-lines, and the stage-1c selection rule | **Which principle** binds this seed (falls out of the draw); its label; who/where each of the 50 mandatory tokens sits; which road the player takes |
| Scenario catalogue (~120) and quest pool (~60) | Which 4–6 scenarios per virtue and 24–35 quests are placed, and where |
| Companion personalities, arcs, dialogue (templated) | Which 8 companions exist; their names; hometowns' names/positions |
| Location *templates* (town archetypes, castle interiors, shrine, dungeon room templates) | Which template variant, position, biome dressing |
| Ruler's / seer's / end-dungeon final chamber scripts | Their names; end-dungeon per-level layout |
| Token *graph* (mantra → shrine → sigil chain, artifacts, key, word) | Which NPC/book holds each token; the mantra syllables; passwords |
| Twist pool content (~20) | Which 6–8 are active |
| Quiz concept pool (40) | Which 12 are asked |
| Bestiary stats | Encounter tables, loot, spawn sites |
| Spell mechanics | Spell/reagent names; wild-reagent sites |

## 4. Location Templates

Each town is assembled from: a **layout template** (harbor / walled / river / hill / forest / mining / ruin;
≥3 variants each), **building kits** (inn, tavern, healer, weaponsmith, armorer, reagent seller, stable,
shrine-house, clan hall, 6–10 homes), and an **NPC roster** (fixed roles per virtue-town: the mantra-keeper,
the shrine-pointer, the sigil-hider, the honesty-tester, the beggar(s), 8–15 flavor NPCs from a role pool).
Roles receive tokens in stage 8.

## 5. Twist Pool (initial 20)

1 False seer • 2 Shrine of Pride trap • 3 Corrupt magistrate in the market village • 4 Companion betrayal
(recoverable) • 5 Plague town needing sacrifice • 6 Stolen artifact — thief must be spared or hunted •
7 Two towns feuding over water rights (fairness) • 8 A mantra deliberately corrupted by a cult; three
sources disagree • 9 Ghost who lies unless shown mercy • 10 Impostor ruler at a castle • 11 Fake companion
(bandit posing as the knight) • 12 Conjunction-only island temple • 13 Moral market raises prices as
virtue rises • 14 Beggar who is the disguised seer • 15 Cursed ship • 16 Dungeon that reverses when
moons align • 17 Village that worships the temptation item • 18 Child who has memorized a lost mantra •
19 Oath-debt inherited by the player • 20 Silent monastery (intel only by observation).

## 6. Solvability Validator (`tools/token_graph.py` + runtime `core/procgen/Validator.gd`)

Builds a graph: start → tokens/items/flags → end. Asserts: every mandatory node has ≥2 true sources in
≥2 distinct locations; no cycle without an alternative; the end is reachable without any false token; each
false token has ≥1 refuting true source discoverable before the point of use. Fails → regenerate stage 8
with a new sub-seed (max 20 attempts, then regenerate from stage 4).

## 7. Replayability Levers Beyond Geography

- **Virtue draw:** C(12,6)=924 possible sets at launch (6435 with all 15); each set changes which
  companions, dungeons, dilemmas, and quiz questions exist, and what the seer measures as Wisdom.
- Class + clan combinations (8 × 12) with distinct passives and halls.
- Companion loyalty paths and arcs resolve differently by conduct.
- Which twists appear; which false intel you believed; epilogue reflects all of it.
- Optional **Pilgrim's Vow** modifiers at New Game (e.g., no inns; no fleeing; permadeath companions).
