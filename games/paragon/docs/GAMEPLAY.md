# Gameplay — The Complete Player Experience

This is the **one document that describes what the player actually does**, from the title screen to the Book
of Paragons: the moment-to-moment loop, the full path to the win, and every kind of encounter the world can
put in front of them. It compiles and cross-references the system docs; where they disagree, `§10` says so.
Nothing here introduces a new rule — it explains the existing ones from the player's chair.

Related: `QUEST_TREE.md` (the dependency tree), `CRITICAL_PATH.md` (the five acts), `WITNESS_LOG.md`,
`SET_PIECES.md`, `SIDE_QUESTS.md`, `ITEMS.md`, `VIRTUES.md`, `GAME_DESIGN.md`.

---

## 0. The game in one paragraph

You arrive through a gate into a realm you have never seen, with eight virtues you did not choose. Knowledge
is the only currency that progresses you: a word from one person unlocks a topic with another; a mantra at
the right shrine grants a virtue; eight virtues let you lift eight stones; stones, sigils, a horn and three
artifacts open the Descent; and at its bottom a single word — different in every realm — is asked of you,
together with what you found it to mean. Nobody keeps score where you can see it. But **everything you do
is recorded, and everyone who saw it remembers**, and at the end you are asked by the people who travelled
with you whether you were who you said you were.

## 1. The core loops

### 1.1 Minute-to-minute
```
walk (1 step = 1 game-minute) ─► arrive somewhere ─► TALK / LOOK / TAKE / FIGHT / CAMP
     ▲                                                       │
     └──── journal auto-records what you learned ◄───────────┘
```
- **Talk** — keyword conversation: click a learned word (chip) or type any word. `NAME`, `JOB`, `HEALTH`,
  `BYE` always work; 3–8 topics per NPC; some topics are hidden until you learn the word elsewhere or guess it.
- **Look / examine** — statues, books, signs, altars, bells; some tokens are learned only by *observation*.
- **Take** — chests (town chests = theft, logged), floor items, key items.
- **Fight** — turn-based grid battles (§5).
- **Camp** — heal over 8 hours, eat one ration per member, dream (§6.2).

### 1.2 Hour-to-hour: the pilgrim's loop (×8)
```
hear a rumour ─► find the mantra-keeper ─► pass their test ─► learn MANTRA (corroborate: ≥2 sources)
             ─► find the shrine-pointer ─► learn SHRINE location
             ─► travel ─► MEDITATE (right mantra, right shrine) ─► VIRTUE GRANTED (never revoked)
             ─► companion joins ─► +1 max level ─► new dialogue everywhere
```
Meditation is a **knowledge test**, not a conduct check. Wrong mantra or wrong shrine: refused, a day lost,
logged. Right on both: granted at once.

### 1.3 Run-to-run
Each seed draws a **different eight** of fifteen virtues (Humility always; Integrity *or* Justice always;
six more), generates the continent, names, who-knows-what, the moon table, and the **Binding Word**. Rules
never change. The **Book of Paragons** keeps only your own sentence from each finished realm.

## 2. Beginning: character creation and arrival (Act I — *The Stranger*, 1–2 h)

| Step | What happens | What it teaches |
|---|---|---|
| Fortune-teller | 7 dilemmas from *this seed's* eight virtues (active conflict pairs weighted) → class (Mage / Bard / Fighter / Druid / Tinker / Paladin / Ranger / Shepherd) | the virtues here are not last run's |
| Clan | pick or roll one of 12 (`CLANS.md`): second passive, magic-tier cap, champion, hall | |
| The gate | arrive at a dual-moon conjunction near the anchor town; the gate closes; moon table unknown | moons are a puzzle |
| Anchor town | innkeeper (explains food and camp in-world) · a beggar (first Care test) · blind reagent seller (first Integrity test: pay fair or short) · tavern with a bar-fight seed · signpost to the royal seat | conduct is watched from minute one |
| Royal seat | `{ruler}` **names the eight** — the only time the full list is spoken; journal Virtues tab opens with eight empty sigil slots | listen once, carefully |
| The Seer | first reading: eight one-word verdicts (the only "progress bar" in the game) | |
| The mirror | shows you faintly; sharpens with each enlightenment | |
| First mantra | anchor town's keeper, behind one honesty test; anchor shrine within a day's walk | the loop |
| **Act I → II** | meditate the anchor virtue; companion 1 joins | |

## 3. The path to win — every gate, in order of dependency

Read bottom-up: each row requires the rows below it. `[T]` token (knowledge), `[I]` key item, `[V]` virtue,
`[D]` deed, `[C]` choice. Full tree with the inner road: `QUEST_TREE.md §1–2`.

### 3.1 Act II — *The Pilgrim* (12–20 h, non-linear)
For each of the seven non-Humility virtues:

| Need | How | Sources (≥2 true, ≥2 places) | False twin |
|---|---|---|---|
| Mantra N `[T]` | keeper NPC behind a virtue-flavoured test | keeper · royal library / scholar / another shrine's vision | market vendor / cult (twist 8) |
| Shrine N location `[T]` | pointer NPC | pointer · beggar-after-gifts · book · dream | drunk / rival pilgrim |
| Virtue N `[V]` | meditate at shrine N | — | — |
| Sigil N `[I]` (for Act IV) | hidden in town N; the hider speaks indirectly | hider · dream / ghost / animal | none (hidden, never disputed) |
| Dungeon N location `[T]` | for the stone (Act IV) and loot now | tavern · signpost · companion N · map fragment | none |

Also in Act II: the **ship** (always obtainable: pirates, purchase, or the smuggler quest); dungeons explored
early for loot and magic items (the stone cannot be lifted yet); the **Temptation** found; set pieces 1, 3, 4
open (Drowned Court, Corsair Fleet, Maelstrom); dilemmas fire at structural moments; 24–35 side quests.

### 3.2 Act III — *The Humbled* (2–3 h, identical every seed)
| Need | How |
|---|---|
| ≥4 virtues granted | gate to enter |
| Ruined-city location `[T]` | rumour after the 4th shrine · the Seer ("one virtue thou hast not asked me of") · any town's Lore token |
| Mantra 8 `[T]` | ghost fragments, one per ghost, **at night only** |
| Ghosts' password `[T]` | **dialogue conduct**: refuse every boast; "Art thou better than we were?" → *no* (*yes* → ghost fades until next night) |
| Warding item `[I]` | hidden in the city; the password reveals it |
| Pass the fiends of Pride `[D]` | walk through with the ward **without striking first** |
| Humility `[V]` | meditate → vision shows your own run from the other side + three images (city of ghosts / bowing monk / silent elder) = the three roads to the Word |
| Seer's second reading | "Thou art good in eight ways. Art thou *whole*?" — Wisdom is revealed to exist |

### 3.3 Act IV — *The Keeper* (4–6 h)
| Need | How | Where |
|---|---|---|
| **Stone N `[I]` ×8** | level 8 of dungeon N, behind the third temptation floor — **liftable only with all 8 virtues** | revisit all eight dungeons; faster the second time |
| **Sigil Ring `[I]`** | shown the first stone → `{ruler}` gives it | royal seat |
| **Binding ×8 `[D]`** | stone N + sigil N at altar room N (level 8); the 8th, in the Pride dungeon, opens the end-island passage | |
| **Horn `[I]`** + its location `[T]` | seeded at one of: Bell in the Deep · Silent Monastery · Maelstrom Gate | fisher's song / House chart / bell-table (Court clerk's version is false) |
| **3 House artifacts `[I]`** | House password `[T]` (Court · set pieces · House-region towns) + **family trial `[D]`** | `{castle:f1..f3}` |
| **Word of Passage `[T]` ×3 syllables** | three keepers, one per House region, each asks about a virtue *not* their own | House regions · Court · hidden-lake village |
| **Binding Word `[T]`** | one of three roads (§3.5) | ruined city / Monastery / Hermitage |
| **Virtue-lines `[T]` ≥2 of 8** | the Word's meaning (§3.5) | statues · vision · companions · ghosts · dreams · library · market |
| Temptation `[opt]` | carry unused to L8 and destroy = largest Wisdom gain; use = zero record, Wisdom locked | found Act II |

**Family trials** (templates, one per House; three per run): Fortitude — a dungeon without camping · Care —
bring a living thing to safety · Truth — name the false token you believed · Justice — judge a case with no
party present · Giving — surrender an item you need · Self-assessment — refuse a reward · Commitment — a
companion is held; wait three days or leave · Intellectual — read a text that contradicts a mantra you hold.


### 3.4 Act V — *The Descent* (1–2 h; **no fail state**)
Gate: Ring bound ×8 ∧ Horn ∧ 3 artifacts.

| Level | Encounter | Failure |
|---|---|---|
| 0 | **The Long Night** — forced camp; each companion asks one question from the log; the Seer's final reading; at dawn choose **Alone** or **Together** `[C]` | none |
| 1 | **Door of the Ward** — lay down the warding item ("Below, nothing wards thee from thyself") | cannot fail |
| 2 | **Door of the Deed** — "Hast thou ever…?" built from your heaviest negative event; honest yes/no passes | lie → ejected (§3.6) |
| 3 | **Door of the Witness** — the companion who saw most states one thing: "Is it so?" (no companions: the log reads aloud) | lie → ejected |
| 4 | **Door of the Unopened** — a situation you `avoided`: "What didst thou?" — "I walked on" passes; if nothing avoided, any answer passes | lie → ejected |
| 5 | **The Mirror** — a copy of the party shaped by your worst virtue band; **type the vice's name** to dissolve it; fighting wins nothing | none |
| 6–7 | **Trials of Tension** — two live dilemmas from this seed's conflict pairs, companions present; recorded to Wisdom | never ejects |
| 8 | **The Threshold** — Word of Passage asked; Temptation may be destroyed; companions each speak one line; Alone/Together **enacted** | none |
| Chamber | **12 questions** (8 asked, 4 *enacted* — a past scenario restaged) → shape the epilogue, never gate · *"What is the one thing that binds the eight?"* → **type the Binding Word** · *"Where does {word} live between {A} and {B}?"* → pick **two held virtue-lines** · *"And what didst thou find it to mean?"* → **free text, ungraded** | wrong word or lines → returned to the surface; re-meditate Humility (vision now gives all eight lines and names all three roads); unlimited attempts |
| **Win** | act on `{artifact_end}` (weave / strike / sound) → epilogue → Book of Paragons | |

### 3.5 The Binding Word — three roads (any one suffices)
| Road | Kind | What you do | Cost |
|---|---|---|---|
| **The Dead** | dialogue | ruined city, any night *after* Humility; the last ruler's ghost: "Art thou better than we were?" → *no* | a far journey; a night |
| **The Silent** | observation | Silent Monastery statue hall; be present at **dawn** to see the abbot bow last and longest to the empty ninth plinth (`saw_abbot_bow_ninth`); then **kneel** there — the word is cut under the kneeler's knees | a dawn; a second visit |
| **The Still** | silence | Hermitage, a day upriver on the far bank of the Mirror Ford; **three nights with no `talk` by anyone and without leaving**; three dreams restage your dilemmas; the third dawn the Anchorite speaks the word — once | three days; any word resets |
| ✗ **False** | bought | the Magistrate of Debts sells "the word that opens the bottom" for his costliest favour | refuted by the Anchorite, any true source, `{companion:humility}`; it is another principle's label and comes with **no lines** — it cannot pass by luck |

The Word is one of **12 binding principles** chosen at generation by affinity to the drawn eight
(`QUEST_TREE.md §4.0`). Its *meaning* is never displayed; it is taught only as eight **virtue-lines** ("how
this principle looks as an act of this virtue"): Monastery statues (all 8, carved) · Humility vision (anchor +
Humility) · each companion once at camp in Act IV (their own) · the Dead (the two most imbalanced) · the
Anchorite's dreams (three) · royal library (all 8, word blotted) · market vendor (any one, for a logged favour).

### 3.6 Escalating ejection (Levels 1–4 only)
Per-door counter, reset by an honest answer. 1st lie → back to that door · 2nd → up one level · Nth (≥3) →
up N−1 levels, capped at the entrance. Nothing else in Act V ejects.

### 3.7 Alone vs Together (chosen at L0, enacted at L8, scored by Wisdom)
| Path | Chamber asks | Tests |
|---|---|---|
| **Alone** (Humility) | 4 about the companions · 4 about your dilemma choices · 4 virtue knowledge — *you* answer | did you *see* the people you travelled with? |
| **Together** (Loyalty) | 8 to the **companions** about you, answered from what they witnessed — you only listen · 4 to you about them | have you been, to eight witnesses, who you claim to be? |

Neither is right. Bringing neglected companions is Loyalty without Humility; leaving eight faithful ones is
Humility without Loyalty. Companions at *lost* loyalty refuse the Mirror Ford and cannot come at all.


## 4. Knowledge encounters

| Encounter | How it plays | Record |
|---|---|---|
| **Keyword conversation** | chips + free typing; hidden topics guessable; NPC lines vary by time, tokens held, party, items, clan, rumour | `keywords_typed/guessed` |
| **Honesty test** (0–2 per NPC) | a yes/no question with a true answer the game knows; lying costs the anchor virtue; paying the blind seller short is the same test in coin | hidden |
| **In-game virtue question** | *"Hast thou ever…?"* / *"Didst thou see…?"* / *"Is the one beside thee faithful?"* — Yes / No / "I will not say"; graded against the **Witness Log**, often gates the token. Boasting −Humility; humbly denying a merit **+Humility**; refusing → nothing today, come back tomorrow | hidden |
| **False intel** (10–15 % of tokens) | liars, propaganda, drunks, the moral market, the Deceit dungeon; every false token has a discoverable refutation; a false mantra costs a day, a false password insults a guard | `tokens_false_acted_on` |
| **Corroboration** | every mandatory token has ≥2 true sources in ≥2 places; the journal never marks truth — checking is your habit | |
| **Observation tokens** | bells at moon phases, monks bowing, altar at dawn, statue inscriptions, gate destinations; no dialogue | `sources_by_kind.observation` |
| **Books, signs, visions, dreams** | royal library; shrine visions; camp dreams sometimes carry tokens | |
| **The moral market** (`village.market`) | truth sold for favours that cost virtue; asks questions designed to make lying profitable; prices may rise with virtue (twist 13) | logged favours |
| **The Seer** | eight one-word verdicts per visit; after Humility: "art thou *whole*?" and one hint at the three roads | — |
| **The mirror** (royal seat) | your reflection, sharper per virtue granted; sharp at last in the hidden epilogue slide | — |
| **Clan halls** | 12 optional service buildings: services for standing, a champion, one signature item; every shortcut nicks Humility slightly | |

## 5. Combat encounters

| Kind | Where | Notes |
|---|---|---|
| Wandering monsters | overworld, by terrain and time; **scale with shrines meditated**, not level | gold scales with region danger (Act I 3–12 g) |
| Camp ambush | wilderness/dungeon camp; lower near roads, with a Ranger, or a ward | uses local terrain map |
| Dungeon rooms | embedded battle maps; traps, fountains, mimics | level-6 room 40–120 g |
| Set-piece battles | Corsair deck battles (Subdue vs sink), fiends of Pride, the Mirror (winning gains nothing) | |
| Tavern brawls | bystanders can be hit; innkeeper remembers forever | |
| Non-evil creatures | deer, wolves, villagers, guards, "bandits" who are fathers — attacking is a violation; **Subdue** always available vs non-evil humans; killing one is always logged and **public** | |

**Rules of a turn:** grid 11×11–15×15, initiative by DEX; Move / Attack / Cast / Use / Defend / **Flee** (map
edge) / Pass; terrain (forest cover, swamp, hills, water, lava, bridges); enemy **morale** — low-morale enemies
flee and are *marked*; killing a fleeing enemy is a violation, letting them go is a gain. Fleeing yourself costs
Courage if drawn. Levels 1–8; **max level = 1 + shrines meditated**; level-up at `{ruler}` or any shrine.
Magic: 32 spells in 5 circles (clan caps the circle), mixed in advance from 8 reagents (2 wild-only at moon
phases); recipes are shuffled per seed and are themselves intel.

## 6. Survival, travel, and the world clock

### 6.1 Food (real, never a gate)
Rations bought with gold (village 2 / town 5 / castle 8), eaten **only at camp**, one per member per night.
Without: night 1 **Hungry** → Weary (−1 initiative, no reagent mixing) · night 2 **Starving** (no MP regen,
MaxHP −10 % at dawn) · night 3+ **Famished** (MaxHP −20 %, STR/DEX −1, slowed) · HP 0 → **unconscious, never
dead** · all unconscious → wake at the nearest inn with a debt, days lost, and a public rumour. Any ration
clears every state. Rangers forage in forest; Shepherds eat half. **The hungry ask you for bread** — giving a
ration is a Care event; your *last* ration a heavy one.

### 6.2 Camp
Anywhere outdoors or in a dungeon; 8 hours; heals if fed; ambush chance; **dreams** deliver virtue feedback
(both faces of a dilemma), occasional tokens, and — after Humility — virtue-lines. Companions from opposite
sides of a conflict pair **argue at camp** when your record is unbalanced.

### 6.3 Inns, healers, shops
Inns: full heal, safe, cost, tavern standing. Healers: cure, heal, resurrect, blood donation (Selflessness;
run-wide cap). Shops by tier: village (dagger/leather, cheap rations) < town (sword/chain, reagents) < castle
(halberd/plate, **gilded** armour — a Humility test). Sell = 50 % of buy. Magic items are never sold; their
locations are tokens (`ITEMS.md §5`).

### 6.4 Moons and gates
Two 8-phase moons: one selects **which gate is open**, the other **where it leads**; the table is shuffled per
seed and learned by watching, hints, or `mag.moon_dial` / `mag.wayfinder`. Conjunctions open 4 hidden sites.
Gates are shortcuts, never the only way.

### 6.5 Transport
Foot · horse · **ship** (captured, bought dearly, or the smuggler quest; needed for 3 towns, the ruin, the
Houses, the Court, the Monastery) · whirlpool → hidden lake (one way) · **Wind-Ship** (Pride dungeon; the only
way to conjunction sites and out of the lake) · moon gates.

### 6.6 Time
1 game-minute per step; a day ≈ 20 real minutes. NPC schedules (sleep / work / tavern / worship); ghosts speak
only at night; the abbot bows at dawn; the Court is reachable at low tide only; followups arrive after N days;
rumours travel ~1 town/day by road.


## 7. Moral encounters — the Witness Log's surfaces

Every one of these writes exactly one `WitnessEvent` with `party_present` and named `witnesses`
(companion 1.0 · innkeeper 0.9 · watch 0.8 · child 0.8 · bystander 0.7 · the wronged 0.6 · drunk 0.3 · ghost 1.0).
NPCs act on **rumour**; the Chamber on **truth**.

### 7.1 Staged scenarios (4–6 per drawn virtue per seed, from ~120)
Beggars (some frauds) · blind seller · merchant undercharges by mistake · guard hunting a fugitive you shelter ·
lost purse · a promise to return · tavern dice (cheat option) · wounded animal · plague house · enemy surrenders ·
child's lost pet · stranger asks to share your fire · companion at 1 HP: press on or camp · caged creature ·
defaced altar · bribe offered · gilded arms … (`WITNESS_LOG.md §7`, `content/virtues/*.md`). Each has an in-game
question and a Chamber question; each has a `repeat_cap` (default 3): beyond it the recipient **refuses
in-world** ("Give it to another"), no penalty, still logged.

### 7.2 Conflict-pair dilemmas (when both sides drawn; fire at structural moments, never at random)
| Pair | Scene | The `both` |
|---|---|---|
| Loyalty vs Justice | a companion's kin is the thief | convict, then pay the restitution yourself |
| Care vs Justice | the wronged demand the pardoned bandit's punishment | pardon with binding service to the victim |
| Integrity vs Kindness | a dying father asks if his son lived (he did not) | tell the truth *and* stay until the end |
| Selflessness vs Self-discipline | the beggar returns daily | give a fixed share and find him work |
| Open-mindedness vs Integrity | a heretic offers a *true* correction to your mantra | verify with a second source, then update |

Wisdom scores the **balance** of your resolutions across the run; no answer scores both fully.

### 7.3 Side quests (24–35 per seed; `SIDE_QUESTS.md`)
- **Heart** (8–12): jailed mother's daughter (the child flinches — did you notice?) · widow's letter to a dead
  soldier · child's dog on dungeon level 1 · old man wants to see the sea · companion's mother in a plague
  house · ghost child's doll · wedding witness · farmer's cow is the "monster" · read bad news to a blind
  woman · a boy who must be refused kindly.
- **Street** (10–15): the bar fight (rumours compete; tavern standing) · mob-caught thief who stole medicine ·
  neighbours' well feud · pelted preacher · drunk insults your companion's clan · rigged scale (he feeds six) ·
  guard beats a beggar · gambler's winnings · a domestic fight behind a door · lost purse with a name · dice cheat.
- **Ledger** (6–8): bounty on a "bandit" father · escort stolen shrine reagents · **the Assize** · "monster den"
  that is a refugee camp · noble's "lost" heirloom in a poor house · the smuggler's ship for one lie · corpses
  "for study" · the whistle-blower's name.

Every quest: ≥2 virtues, ≥3 resolutions (none good for all), named witnesses, a later surfacing, an
**avoidance** outcome (walking away is logged and may become the Door of the Unopened).

### 7.4 Dungeon temptation floors (3 per dungeon, authored)
Avarice: gold beside a starving prisoner · Cowardice: an exit ladder · Duplicity: a forged pass · Cruelty: a
caged creature · Contempt: a defaced altar · Corruption: a bribe past a trial room · Callousness: a wounded
scout begging a potion · Pride: gilded arms on a pedestal. Taking *and* resisting are both logged.

### 7.5 Companions (8, one per virtue; join after their shrine)
Loyalty rises/falls by what they witness through their virtue; at a threshold they **leave** (re-recruitable
after amends); each has a personal arc and a figure at the **Mirror Ford**; they remark from the log, argue at
camp, testify at the Threshold and in the Together path — **honestly, never harshly**: below a witnessed floor
they say `unseen`. A late joiner has no record of early sins. One clan champion may take a 9th slot.

### 7.6 Rumour and standing
Public events spawn rumours per witness; they mutate toward the loudest bias, compete, and travel. Towns
greet you by rumour; guards, prices and tavern intel follow it. You can **correct** a false rumour by telling
the truth to the innkeeper or the watch (+Integrity; +Humility if unflattering). Each **tavern** keeps a
standing −3..+3 that never decays and gates that tavern's intel.


### 7.7 Set pieces (11, every seed; `SET_PIECES.md`)
| # | Set piece | Encounter | Holds |
|---|---|---|---|
| 1 | Drowned Court | tokens priced in favours (carry a threat; swear grain is people; witness a sale; collect from beggars); the `both`: pay the Magistrate's own debt | Passage syllable, House password, a ship, the **false Word** |
| 2 | Bell in the Deep | coordinates from 3 sources (one false); pick a **diver** (30 % risk if the sea is rough) | artifact; ledger naming the Magistrate |
| 3 | Corsair Fleet | ship combat → boarding → Subdue or sink (public); one "pirate" is the **navy in disguise** | ships, captains |
| 4 | Maelstrom Gate | sail in knowing it's a door (+Courage) or not (`reckless`, Wisdom −) | the hidden lake |
| 5 | Wind-Ship | Pride dungeon upper hall; wind by moon phase | conjunction sites, the way out of the lake |
| 6 | The Assize | you are called as **witness**; the court has rumours, you have the log; true-against-yourself / true / false (a companion objects aloud) / refuse | verdict follows in 10 days |
| 7 | Silent Monastery | no dialogue; 3 observations → a syllable; eight statues with lines; the **ninth plinth** | syllable, all 8 lines, the Word |
| 8 | Mirror Ford | each companion meets a figure from their arc; you advise (theirs / partner's / "thine to choose") or stay silent; lost-loyalty companions refuse to cross | |
| 9 | Debtor's Isle | give everything / some / nothing for a stone held by the dying | a stone or a Word keeper |
| 10 | The Long Night | Descent L0 (§3.4) | |
| 11 | The Hermitage | the Still (§3.5); feeds a starving party | the Word, three lines |

### 7.8 Twists (6–8 of 20 per seed, always fair in hindsight)
False seer · Shrine-of-Pride trap · corrupt market magistrate · recoverable companion betrayal · plague town
needing sacrifice · stolen artifact (spare or hunt the thief) · water-rights feud · **cult-corrupted mantra**
(three sources disagree) · ghost who lies unless shown mercy · impostor ruler · fake companion (bandit as
knight) · conjunction-only temple · market prices rise with virtue · beggar who is the Seer · cursed ship ·
dungeon that reverses at moon alignment · village that worships the Temptation · child who knows a lost
mantra · inherited oath-debt · (the Silent Monastery, now fixed as set piece 7).

## 8. Feedback the player gets (all diegetic — no numbers, ever)
The Seer's verdicts · companion remarks, arguments, leaving · NPC greeting tone · tavern standing · camp
dreams · shrine visions · the mirror · in-game questions that go badly · guards, prices and ambushes driven by
rumour · the Assize · followups (the child begging at the gate; the freed debtor in a later town) · the Long
Night's questions · the Chamber · the epilogue. The **Ledger of Days** shows journey facts only.

## 9. The end and after
**Epilogue, fixed order:** your reflection alone on a dark screen → Wisdom band (unbalanced / seeking /
discerning / whole) → one line per virtue on its town and companion → companions kept/lost and the Threshold
path → false tokens believed (named, with who told them) → three Heart quests rated highest and lowest → the
Temptation: unused / used / destroyed → the Seer's last line → hidden slide (whole + Temptation destroyed +
all companions kept): the mirror, finally sharp.

**Book of Paragons:** per seed — your sentence (verbatim), the eight, Wisdom, path, which road gave the Word.
Title screen shows every reflection and which of the 15 virtues you have never been dealt. **Pilgrim's Vows**
unlock after the first win (no inns · companion permadeath · silent Seer · no journal · no fleeing). No
mechanical carryover — only the record.


## 10. Open gameplay issues (found in the 2026-09-07 deep dive; **proposals, not rulings**)

| # | Issue | Where | Proposed fix |
|---|---|---|---|
| G1 | **Wind-Ship Humility floor ≥25 is a counter-gate** on the only route to conjunction sites / out of the lake — contradicts `DESIGN_REVIEW §1`, `CRITICAL_PATH §1` | `SET_PIECES §5`, `RULES §3.27`, P4-T14 | lift on the **warding item** (item gate); band = speed only |
| G2 | **"Shrine shut until the band recovers"** after striking the fiends is a counter-gate and reintroduces grinding | `CRITICAL_PATH §4.4`, `humility.md`, REG-CMB-07 | shut until you return with the ward on a later night **and do not strike** (conduct) |
| G3 | Dungeons: deep-dive promises hand-crafted vice levels; generator uses room templates (only 3 of 8 floors authored) | `ULTIMA_IV_DEEP_DIVE §13` vs `PROCEDURAL_GENERATION` stage 7 | authored level *shells* per vice, randomized contents/links |
| G4 | Wisdom `balance = \|gA−gB\| / (gA+gB)` is undefined/perfect at zero volume — avoidance scores as balance | `VIRTUES §6`; `hermit` golden run | minimum-volume term; below it Wisdom cannot exceed *seeking* |
| G5 | Chamber templates ask for **randomized proper nouns** 25 h later ("who shared thy fire", "whose purse") — recall of noise, not understanding; answer format unspecified | `WITNESS_LOG §7`, `CRITICAL_PATH §6.3` | answers as **chips from the Pilgrim's Book**; re-weight templates to *what / why* |
| G6 | Doors L2–4 grade honest **misremembering** as a lie (ejection) | `CRITICAL_PATH §6.1` | add *"I do not remember"* → no ejection; the door tells you; Humility event |
| G7 | Together: a late companion's honest `unseen` "counts as wrong" — contradicts "honest, never harsh" | `CRITICAL_PATH §6.2` vs `DESIGN_REVIEW §4` | `unseen` scores neutral |
| G8 | Act II (12–20 h) has few **hard** consequences of conduct before the Assize | `GAME_DESIGN §5` | rumour-driven (never counter-driven) hard consequences: guards refuse the gate, wronged party's ambush, seller refuses, companion walks |
| G9 | Shrine brute-force is cheap (a day per wrong guess; small syllable pools) | `CRITICAL_PATH §3.1` | a shrine refuses the same wrong mantra permanently; refusal is a Chamber-quotable event |
| G10 | Combat is the most-played, least-specified system (14 lines) | `GAME_DESIGN §8` | `docs/COMBAT.md`: turn economy, spare/kill readability, combat gold anti-grind |
| G11 | Full name randomization weakens memorability, shareability and the Chamber (G5); the real replay engine is the *draw* | `NAMING_AND_LORE.md` | open decision: fixed archetype names, randomized placement |
| G12 | Nothing is playable; the core bet (does a 25-hour-delayed judgment feel fair?) is untested | — | Phase 0 spike: text-only Witness Log → Chamber question harness over the golden runs |

Each item needs a ruling before the affected Phase 1+ task starts; G1/G2/G7 are contradictions and should be
resolved first. Rulings go to `DESIGN_REVIEW_2026-09.md` (new §12) and `GAME_DESIGN.md §13`.

