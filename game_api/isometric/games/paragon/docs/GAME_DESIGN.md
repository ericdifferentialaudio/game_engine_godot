# Paragon — Game Design Document

Working title: **Paragon** (original IP; `game_engine_godot/games/paragon/`). Genre: 3D isometric, turn-based party RPG
with knowledge-driven progression and a procedurally generated world. Single player. PC first.

Companion docs: `ULTIMA_IV_DEEP_DIVE.md` (reference analysis of the inspiration — no content reused),
`NAMING_AND_LORE.md`, `PROCEDURAL_GENERATION.md`, `CLANS.md`, `ARCHITECTURE.md`, `DEVELOPMENT_TASKS.md`.

All names below in `{braces}` are archetype IDs resolved from name pools per seed.

---

## 1. Pillars

1. **Discovery** — Knowledge is the progression currency. No quest markers. The journal records what you
   learn; the world rewards asking, reading, and reasoning.
2. **Virtue** — The player's conduct is the plot. Hidden virtue counters shape access, NPC attitude,
   party loyalty, and the ending.
3. **Journey** — An open, coherent continent with real geography, multiple travel modalities, a living
   day/night and dual-moon cycle, and survival pressure that makes distance matter.
4. **Replayability** — Every seed is a new world: geography, names, who-knows-what, dungeon layouts, moon
   tables, and twists are regenerated; the *rules* never change (`PROCEDURAL_GENERATION.md`).

## 2. Presentation

- **Camera:** fixed-angle 3D isometric (≈45° yaw, ≈35° pitch), orthographic or near-ortho, 4 rotation
  stops (90°) with smooth tween, 3 zoom levels. Same camera for overworld, towns, dungeons, battles.
- **Art:** stylized low-poly / hand-painted textures, readable at isometric scale. Grid-based world
  (1 tile = 2 m). Cell-based dungeons.
- **Lighting:** dynamic day/night, torches, spell light; dungeons dark by default.
- **UI:** diegetic-leaning. Left: party portraits. Bottom: message scroll (classic log). Right: context
  actions. Journal (the **Pilgrim's Book**) as a book.

## 3. World

### 3.1 Overworld
A procedurally generated continent (~256×256 cells) per seed: biomes, rivers, coasts, mountains, one
hidden inland lake, 8 virtue regions. All locations placed by the generator with connectivity guarantees.
~12 minor sites per seed drawn from a template pool (hermits, ruins, wayshrines, caves, lighthouse,
monastery, fishing hamlet, bandit camp, stone circle, traveller camp, shipwreck, forgotten tower).

### 3.2 Locations (each a distinct scene/map, from templates)
- 8 towns `{town:slot.1..8}` — one per drawn virtue; `slot.8` (Humility) is always the ruined city
- 1 royal seat `{castle.royal}` + 3 family Houses `{castle:f1..f3}`
- 4–6 villages incl. `{village.market}` (the moral market — intel sold for virtue-costing favors)
- ~12 minor sites
- 8 dungeons × 8 levels `{dungeon:slot.1..8}` (one per vice; slot.8's Pride dungeon links to the end) +
  `{end_dungeon}` (island)
- 8 shrines, 8 gates, 12 clan halls (inside towns)
- ~40 battle maps (terrain × variants) + dungeon rooms as embedded battle maps

### 3.3 Time & Moons
- 1 game-minute per overworld step; a full in-game day ≈ 20 real minutes at normal pace.
- `{moon_gate}` (which gate opens) and `{moon_dest}` (destination): 8 phases each; the phase→gate table is
  shuffled per seed and must be learned by observation/hints.
- NPC schedules: sleep / work / tavern / worship; some NPCs only present at certain times/phases.

## 4. Player & Party

### 4.1 Character creation
A fortune-teller poses 7 dilemmas (drawn from a pool of ~40) pitting two virtues against each other → class.
Then choose or roll a **clan** (`CLANS.md`). Cosmetic: name, portrait.

### 4.2 Classes (8, virtue-aligned)
Mage, Bard, Fighter, Druid, Tinker, Paladin, Ranger, Shepherd (generic nouns) with distinct stat
distributions and MP multipliers, plus one signature passive each (e.g., Bard: better prices & extra
conversation topic; Shepherd: reduced food consumption; Tinker: trap disarm; Ranger: fewer camp ambushes).
Clan adds a second passive, a magic-tier cap, a champion, and a hall.

### 4.3 Stats
STR, DEX, INT, HP, MaxHP, MP, Level 1–8, XP, plus clan-derived ATK/DEF/VIS/MOV/STL/RES/LCK/ARC. Level-up
performed by `{ruler}` **or** at any shrine after partial enlightenment. Max level = 1 + shrines meditated.

### 4.4 Companions & Champions
Eight companions `{companion:slot.1..8}`, one per drawn virtue (archetype fixed per virtue, `VIRTUES.md
§3`), waiting in their virtue's town. **A companion joins only after the shrine of their virtue has been
meditated.** They have **loyalty**: acting against their virtue lowers it; at a threshold they leave
(re-recruitable after amends). Each has a personal side-quest. Companions from opposite sides of an active
conflict pair argue at camp when the player is unbalanced. One **clan champion** may occupy a 9th slot.

## 5. Virtue System (see `VIRTUES.md`)

- **Pool of 15, 8 drawn per seed:** Humility always (capstone, slot.8); Integrity or Justice always
  (anchor); 6 more under family/conflict constraints. Different realms, different eight.
- Eight hidden counters (0–100). Bands: 0–24 "lost", 25–74 "seeking", 75–98 "worthy", 99+ "exemplary".
  Action tables are per-virtue modules; clan-hall costs apply (`CLANS.md §5`). **Counters gate nothing**
  (`DESIGN_REVIEW_2026-09.md §1`): they are the moral record read by the Seer, companions, the Chamber and
  the epilogue.
- **Meditation is a knowledge test.** Know the mantra, stand at the correct shrine → the virtue is granted
  at once and never revoked. All eight must be granted before any stone can be taken (`CRITICAL_PATH.md`).
- **Humility's shrine** is guarded and cannot be meditated until ≥4 others are — it is always effectively
  the last-but-not-least virtue.
- **Wisdom** — the hidden meta-virtue, never drawn, never shown, never meditated. Scores the *balance* of
  the player's resolutions across this seed's conflict pairs (`VIRTUES.md §6`). Revealed by the `{seer}`
  only after Humility is meditated. Decides the end-dungeon questions and the epilogue's verdict.
- **Feedback channels (all diegetic):** `{seer}`; companion remarks and camp arguments; NPC greeting tone;
  camp dreams (both faces of a dilemma); shrine visions; the mirror in `{castle.royal}`.
- A granted virtue gives: the virtue itself (1 of 8 toward the stones), companion unlock, +1 max level,
  clan shrine bonus if patron, unique dialogue everywhere. The **`{sigil_term}`** is a separate item hidden
  in the virtue's town (`ITEMS.md §4`).
- A granted virtue is never revoked. Conduct after the shrine still writes to the Witness Log and shapes
  the Seer, companions, the Chamber and the epilogue.

## 6. Knowledge / Intel Token System

The core innovation, formalized as data:

```
IntelToken {
  id: "token.mantra.slot.1"
  category: Mantra | ShrineLocation | TownLocation | CastleLocation | DungeonLocation | DungeonStone |
            MagicItemLocation | Sigil | Password | WordOfPassage | Codex | Person | Lore | Recipe | Rule
  # A token is binary — held or not — and carries no confidence value (DESIGN_REVIEW_2026-09 §5).
  value: <generated per seed>          # e.g. a mantra syllable
  reveals_keywords: [<value>]          # adds to speakable vocabulary
  prerequisites: ["token.person.slot1_keeper_trust"]   # optional gating
  sources: <assigned per seed to ≥2 NPC/book/dream slots in ≥2 locations>
  truth: true                          # false tokens exist (see twists); false ones carry refuted_by
  redundancy_min: 2
}
```

- **Acquisition:** conversation, books/signs, shrine visions, items, observation (gates), dreams, clan halls.
- **Journal (Pilgrim's Book):** auto-records tokens, cross-links them, shows *where* learned. Never adds
  information the player didn't receive. Tabs: People, Places, Words, Items, Virtues, Bestiary, Spells,
  Moons, Clans.
- **Keywords:** conversation UI shows learned words as chips **and** allows free typing; hidden words are
  discoverable by guessing.
- **Redundancy rule:** every mandatory token has ≥2 independent true sources in ≥2 locations (validated at
  generation).
- **False tokens:** liars, propaganda, ghosts. Corroboration matters. A false mantra at a shrine costs a
  day; a false password insults a guard. NPCs of the truthfulness town never lie; the moral market and the
  deceit dungeon are unreliable. Every false token has a discoverable refutation.
- **Passwords:** gate certain NPCs, doors, and secret societies (one per family House + the market).
- **In-game virtue questions:** NPCs ask *"Hast thou ever…?"* / *"Didst thou see…?"* / *"Is the one beside
  thee faithful?"* while the player seeks intel. Answers (Yes / No / "I will not say") are graded against the
  **Witness Log** (`WITNESS_LOG.md §5`) — not a flag — and often gate the token. Lying about sins costs
  Integrity; boasting costs Humility; humbly denying a merit *gains* Humility.

## 7. Conversation

Per NPC: NAME, JOB, HEALTH, BYE, 3–8 topic keywords, 0–2 yes/no honesty tests, conditional lines (virtue
band, time of day, party members present, tokens known, items carried, clan). Data-driven, **templated**
dialogue (`ARCHITECTURE.md §6`, `NAMING_AND_LORE.md §6`). NPC *roles* are fixed per town archetype; names,
faces, and which tokens they hold are assigned per seed. ~300 NPC roles at launch.

## 8. Combat

- Turn-based, tactical, grid (battle maps 11×11 to 15×15), initiative by DEX.
- Actions: Move, Attack (melee/ranged), Cast, Use item, Defend, Flee (exit map edge), Pass.
- Terrain: forest (cover), swamp (poison/slow), hills (range bonus), water (impassable), lava, bridges.
- Enemies have **morale**: flee when low; fleeing enemies are marked. Killing them violates virtue.
- Non-evil creatures (deer, wolves, villagers) exist; attacking them is a violation.
- **Subdue** (non-lethal) is always available against non-evil humans; killing one is always logged and
  public (`SIDE_QUESTS.md §7`). **Tavern battle maps** exist for bar fights; bystanders can be hit.
- Camp ambush uses the current terrain's battle map.
- Bestiary ~45 creatures: public-domain staples (orc, troll, skeleton, ghost, dragon, hydra, giant
  spider, rat, bat, wolf, pirate, sea serpent…) plus original designs (bog wraith, mirror fiend, penitent
  revenant, sand hydra, lantern-eater, hollow knight…). No inspiration-specific monster names.
- Clan passives apply on the grid (`CLANS.md §2`).
- Loot: chests after battle (gold, reagents, occasionally items); mimics.

## 9. Magic

32 spells in **5 circles** (clan magic tier caps the circle), reagent-mixed in advance; recipes discovered
in-game (spellbook starts with class starter spells). 8 reagents, two of them wild-only at specific moon
phases. **Spell and reagent names are pooled per seed**; effects are fixed by ID (`spell.heal`, `spell.gate`,
`spell.reveal_lie`, …). Recipes are shuffled per seed within balance constraints (so recipe knowledge is
itself intel).

## 10. Survival & Economy

- **Food (decided, `DESIGN_REVIEW_2026-09.md §11.1`) — real survival:** consumed only at camp — one ration
  per member per night, bought with gold (village 2 / town 5 / castle 8; the wild none; Rangers forage in
  forest). No rations → no heal, **Weary** (−1 initiative, no reagent mixing) → **Starving** (−10 % MaxHP at
  dawn, no MP regen) → **Famished** (−20 % MaxHP, STR/DEX −1, slowed) → **unconscious, never dead**; total
  collapse = rescue at the nearest inn for a debt, lost days and a public rumour. **Never gating:** no blocked
  action, door, shrine or dialogue; no counter change. The hungry ask for *bread*; giving thy last ration
  while Starving is a heavy Selflessness event. Torches burn out. Reagents consumable.
- **The gold loop:** monsters and chests → gold → **food** (recurring), **reagents** (magic is consumable),
  **gear** (the only way to better weapons and armour). Every coin has three claimants; the moral sinks
  (ransom, restitution, donation, the Court's debt) are a fourth. Full list: `ITEMS.md §0`.
- **Anti-grind (`DESIGN_REVIEW_2026-09.md §11.2`):** each placed scenario instance has a `repeat_cap`
  (default 3 weighted events). Beyond it the event is logged at weight 0 and the recipient refuses in-world
  ("Give it to another"). No penalty, ever.
- **Gold buys gear** (`ITEMS.md`): tiered sellers (village < town < castle), magic items found not bought,
  key items never traded. Gold from chests, selling, rewards, bets. Prices vary by town, Bard presence, and
  market twists. Moral gold sinks: ransom, restitution, fines, donations, the Debtor's Isle.
- **Ledger of Days** (Pilgrim's Book tab): journey facts only — gold, days, distance, places, tokens held,
  items, companions, virtues granted, stones. Never conduct counts (`REGRESSION.md §3`).
- **Camp:** anywhere outdoors/dungeon; heals over 8 hours; chance of ambush (lower with a Ranger/ranger-clan,
  near roads, or with a ward). Camp **dreams** deliver virtue feedback and occasional intel tokens.
- Inns: full heal, safe, cost. Healers: cure, heal, resurrect, blood donation.
- **Taverns are the intel hub** and keep a **standing** with the player (innkeeper memory; `SIDE_QUESTS.md
  §6`). **Rumours** about the player travel town to town (`WITNESS_LOG.md §4`); NPC tone follows rumour,
  the Chamber follows truth.
- Transport: horses, ship (captured or bought dearly), balloon, gates, whirlpool → hidden lake.

## 11. Twists & Expansion Content

A pool of ~20 twists; 6–8 active per seed (`PROCEDURAL_GENERATION.md §5`). Always-on systems:

1. **Conflict-pair dilemmas** — for every conflict pair with both sides drawn, a scripted dilemma with no
   answer that fully satisfies both (`VIRTUES.md §7`). Wisdom scores balance across the run.
2. **Companion arcs** — a personal quest per virtue (the squire's oath-debt, the shepherd's lost flock, the
   oath-keeper's forbidden tome, …), templated to the seed's names.
3. **Living rumors** — some intel appears only after certain acts (donate blood twice → the healer shares
   a selflessness token).
4. **Consequence world-state** — beggars you helped later appear employed; towns you stole from post guards.
5. **Moon-conjunction secrets** — 4 sites per seed reachable only at specific dual-moon conjunctions.
6. **The Chamber** — 12 questions generated from the **Witness Log** and shaped by the Threshold choice
   (Alone / Together; `CRITICAL_PATH.md §6.2–6.3`); requires understanding, not recall.
7. **Epilogue by degree** — always the `{artifact_end}`, but the epilogue reflects the 8 virtue results,
   the **Wisdom band**, the Threshold path, companions kept, false tokens believed, three Heart quests, clan,
   and whether `{temptation}` was used or destroyed (`CRITICAL_PATH.md §7`).
8. **Clan halls & champions** — 12 optional service buildings and recruits (`CLANS.md`).
9. **Side quests** — 24–35 staged situations per seed in three tiers (Heart / Street / Ledger), every one
   feeding the Witness Log (`SIDE_QUESTS.md`).

## 12. Critical Path

The run proceeds in **five acts** with inviolable gates — *The Stranger → The Pilgrim → The Humbled → The
Keeper → The Descent* — ending at the Threshold (Loyalty vs Humility) and the Chamber. Full specification,
including the escalating-ejection rule, the Alone/Together mixed questioning, the epilogue order, and the
Book of Paragons meta-record: **`CRITICAL_PATH.md`**. The complete dependency tree — every token, item,
virtue and deed between the first mantra and the Binding Word, with what each asks of the player:
**`QUEST_TREE.md`**.

## 13. Open Decisions (resolve before Phase 2)

- Overworld movement: step-based (proposed, with smooth interpolation) vs. free real-time.
- Companion permadeath: proposed **no** by default; available as a Pilgrim's Vow modifier.
- Difficulty modes: proposed one canonical mode + accessibility toggles + Pilgrim's Vows.
- Voice acting: none at launch (templated names make VO impractical anyway).
- Virtues: **pool of 15, 8 drawn per seed** (Humility + anchor + 6); Wisdom as non-drawable meta-virtue —
  adopted. Launch with 12 modules; `gratitude`, `perseverance`, `reverence` in a free update.
- Clans: **12 clans**, patrons drawn from the seed's 8 virtues (option a) — adopted.
- Working title "Paragon": trademark check required (P0-T0).
- **Decided 2026-09** (`DESIGN_REVIEW_2026-09.md`): virtue counters gate nothing; meditation = mantra + shrine;
  8 virtues → stones → key items → Descent; tokens binary with category tags; items/gold as a real system;
  companions judge honestly from what they witnessed; public/hidden telemetry split.
- **Decided 2026-09-07** (`DESIGN_REVIEW_2026-09.md §11`, full tree in `QUEST_TREE.md`): food camp-only and
  never gating; `repeat_cap` = 3, diegetic refusal, no penalty; `spent_on_others` is a Wisdom input; Act V =
  four named doors (Ward / Deed / Witness / Unopened) + 4 enacted Chamber questions; the **Binding Word** has
  three sources of three kinds (the Dead / the Silent / the Still) and a false one sold at the Court; it is
  **seed-derived** — one of twelve binding principles chosen by affinity to the drawn eight, its meaning taught
  by eight virtue-lines and tested by placing it between two of the run's virtues; an ungraded reflection ends
  the Chamber; hunger makes the party Weary but never gates; the vertical-slice seed as proposed (+ the
  Monastery); `RULES.md §3.5` extended to conduct-derived counts.
- **Open (gameplay deep dive 2026-09-07, `GAMEPLAY.md §10`, G1–G12):** two surviving counter-gates (Wind-Ship
  floor; fiends → "band recovers") to be replaced by item/conduct gates; dungeon authoring (shells vs templates);
  Wisdom zero-volume term; Chamber answer format (chips from the Pilgrim's Book) and "I do not remember" at the
  doors; `unseen` scores neutral in Together; hard rumour-driven Act II consequences; shrine brute-force cost;
  `COMBAT.md`; name-randomization scope; a Phase 0 text harness for Witness Log → Chamber.

