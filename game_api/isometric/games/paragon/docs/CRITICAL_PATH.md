# Critical Path — How a Run Proceeds to the Win State

The **spine** below is identical in every seed. The **flesh** (names, geography, which eight virtues, who
holds which token, which dilemmas and side quests exist) is generated. Gates between acts may never be
bypassed by data (`RULES.md §3.22`).

Related: `QUEST_TREE.md` (**the full dependency tree of a run — read it with this file**), `VIRTUES.md`,
`WITNESS_LOG.md`, `SIDE_QUESTS.md`, `PROCEDURAL_GENERATION.md`.

## 1. Five Acts

| Act | Name | Gate to enter | Player is doing | Target length |
|---|---|---|---|---|
| I | **The Stranger** | — | Arrives; learns this realm's eight virtues; learns knowledge is currency; first mantra | 1–2 h |
| II | **The Pilgrim** | Ruler has named the eight | Seven virtues (mantra → shrine → meditate), companions, vice dungeons explored in any order; dilemmas and side quests | 12–20 h |
| III | **The Humbled** | ≥4 virtues granted | The ruined city; the guarded shrine; Humility (the 8th); the Seer's second reading | 2–3 h |
| IV | **The Keeper** | All 8 virtues granted | The 8 stones (now takeable); Sigil Ring bindings; the horn; three Houses & artifacts; Word of Passage; the codex answer; the Temptation | 4–6 h |
| V | **The Descent** | Ring bound ×8 + horn + 3 artifacts + Word | The Long Night; conduct doors; the Mirror; Tension; the Threshold; the Chamber | 1–2 h |

Acts II–IV are non-linear inside; act boundaries are hard. **Gates are knowledge and items, never virtue
counters** (`DESIGN_REVIEW_2026-09.md §1`). The counters are read by the Seer, companions, the Chamber and the
epilogue only.

## 2. Act I — The Stranger

1. **Fortune-teller.** Seven dilemmas drawn from *this seed's* eight virtues (active conflict pairs weighted
   higher) → class. Clan pick/roll. First silent lesson: the virtues here differ from last time.
2. **The gate.** Arrival at dual-moon conjunction near the starting town; the gate closes; moon table unknown.
3. **Starting town** = anchor virtue's town (`slot.1`). Fixed roles: innkeeper (explains food/camp in-world);
   a beggar (first Care/Giving test, or Respect if none drawn); blind reagent seller (Integrity test if drawn);
   signpost to the royal seat; a tavern with the first bar-fight seed (`SIDE_QUESTS.md`).
4. **Royal seat.** `{ruler}` names the eight — the *only* time the full list is spoken. Journal Virtues tab
   opens with eight empty sigil slots. `{seer}` first reading: eight one-word verdicts. Mirror shows the
   player faintly (sharpens with each enlightenment).
5. **First mantra.** Anchor town's mantra-keeper is reachable in Act I behind one honesty test; anchor shrine
   within a day's walk. Meditating it = Act I→II. Companion 1 joins.

**Intent:** player leaves Act I knowing the loop (word → place → meditate → virtue → companion) with no tutorial.

## 3. Act II — The Pilgrim

### 3.1 Loop per virtue (×7)
```
learn mantra (≥2 sources) ──┐
learn shrine location ──────┼─► meditate (correct mantra at correct shrine; quick) ─► virtue granted + companion
find the sigil-item ────────┘                                                          (never revoked)
vice dungeon (8 levels) ─► explore; loot; 3 temptation floors; the stone waits at the bottom
                           (takeable only once all 8 virtues are granted — Act IV)
```
Meditation is a **knowledge test**, not a conduct check: wrong mantra or wrong shrine → refused (a day lost);
right mantra at the right shrine → the virtue is granted at once. Conduct is recorded, not gated
(`DESIGN_REVIEW_2026-09.md §1`). Dungeons are seeded set pieces present from the start
(`ITEMS.md §6`): they tempt their vice on three authored floors (Avarice: gold beside a starving prisoner;
Cowardice: an exit ladder). Taking the bait is logged and costs the virtue's record. Dungeon-before-shrine
is legal and yields loot and magic items; the stone itself cannot be lifted until the eighth virtue.

### 3.2 What keeps Act II from being a checklist
- **Dilemmas** fire at structural moments (both companions of a pair first in party; entering the market;
  a set dungeon level) — never at random. Each is a scene.
- **False intel** (10–15% of tokens); the market sells truth for virtue; corroboration becomes habit.
- **Side quests** (24–35 per seed) generate Witness Log events (`SIDE_QUESTS.md`).
- **The Seer** is the only progress bar: eight verdicts per visit.
- **Companions as conscience**: remarks from the log; opposite-pair companions argue at camp when unbalanced.
- **Moon table** as a puzzle; **escalation**: encounter tables scale with shrines meditated, not level.

### 3.3 Soft order from geography
Anchor town central; three virtue towns by road; three across water (ship always obtainable in Act II —
pirates, purchase, or the smuggler quest); the ruined city on a far coast.

## 4. Act III — The Humbled (the hinge; identical every seed)

1. **Rumour of the ruin** after the 4th shrine; the Seer: "There is one virtue thou hast not asked me of."
2. **The ruined city.** No living NPCs; ghosts speak only at night, one fragment each. Story fixed: it had
   every virtue but one.
3. **Warding item** hidden in the city; password from ghosts, given by **dialogue conduct only** (never a
   counter — `DESIGN_REVIEW_2026-09.md §11.6`): boast options are offered and must all be refused. Ghosts ask:
   "Art thou better than we were?" — *yes* fails (the ghost fades until the next night); *no* passes.
4. **Guarded shrine.** Fiends of Pride. Warding item passes them if the player does not strike first. Killing
   them is possible; it costs Humility and the shrine stays shut until the band recovers.
5. **Meditation.** Known mantra, correct shrine, guardians passed → Humility granted, the eighth virtue. The
   vision shows the player *their own run* — dilemmas from the other side — and ends on three images: a city
   of ghosts, a bowing monk, an old one who does not speak — the **three roads to the Binding Word**
   (`QUEST_TREE.md §4`; it is not given here). Wisdom is revealed to exist.
6. **Seer's second reading** from now on: "Thou art good in eight ways. Art thou *whole*?" — and, once:
   "Ask the dead, or watch the silent, or be still."

## 5. Act IV — The Keeper

- **Three Houses** `{castle:f1..f3}` — castles of the seed's three strongest families, each holding one
  artifact behind a **family trial** (templates, one per family; every run has exactly three):
  Fortitude — complete a dungeon without camping · Care — bring a living thing to safety · Truth — answer a
  question whose honest answer costs you (name the false token you believed) · Justice — judge a case with no
  party present · Giving — surrender an item you need · Self-assessment — refuse a reward · Commitment — a
  companion is held; wait three days or leave · Intellectual — read a text that contradicts a mantra you hold.
- **The stones.** With all eight virtues granted, the stone at the bottom of each vice dungeon can now be
  taken (`ITEMS.md §4`). Dungeons explored earlier are revisited; the descent is faster the second time.
- **Sigil Ring.** Given by `{ruler}` when the first stone is shown. Eight altar rooms (level 8 of each vice
  dungeon) each take one stone + its sigil. The 8th binding, in the Pride dungeon, opens the passage to the
  end-dungeon island — *no end without having been humbled*.
- **The horn.** A key item held by one of the sea set pieces (seeded: Bell in the Deep / Silent Monastery /
  Maelstrom Gate); required to enter the Descent.
- **Word of Passage.** Three syllables from three keepers (one per House region); each asks about a virtue
  *other* than their own.
- **The Binding Word** (the codex answer). The Chamber's final question is answered with a token the player
  must *find* by one of **three roads of three kinds** (`QUEST_TREE.md §4`; `DESIGN_REVIEW_2026-09.md
  §11.4`): **the Dead** — the ruined city's ghosts at night, after Humility, to one who answers *no*; **the
  Silent** — the Monastery's empty ninth plinth, seen at dawn and then knelt at; **the Still** — the
  Anchorite beyond the Mirror Ford, after three days without speaking. One false variant: the Magistrate of
  Debts sells it; refuted by the Anchorite, any true source, and `{companion:humility}`. The Word is the label
  of **this seed's binding principle** — one of twelve, derived from the drawn eight at generation
  (`QUEST_TREE.md §4.0`) — and its meaning is taught by eight **virtue-lines** (Monastery statues, Humility
  vision, companions at camp, the Dead, the Anchorite's dreams, the royal library). The Chamber asks for the
  word *and* for its place between two of the run's virtues; the false Word comes with no lines.
- **The Temptation.** Findable from Act II. Using it reveals all tokens and maxes stats, zeroes every virtue,
  and locks Wisdom at "unbalanced". Carrying it unused to Level 8 and destroying it is the single largest
  Wisdom gain in the game.
- **Set pieces** (`SET_PIECES.md`): the Drowned Court, the Bell in the Deep, the Corsair Fleet, the Maelstrom
  Gate, the Wind-Ship, the Assize, the Silent Monastery, the Mirror Ford, the Debtor's Isle — present in every
  seed; they hold Word syllables, House passwords, artifacts, and stones, and each is a different kind of test.

## 6. Act V — The Descent (identical structure every seed)

Generated layout, scripted level-ends. **No fail state anywhere in Act V.**

| Level | Test | On failure |
|---|---|---|
| 0 | **The Long Night** (`SET_PIECES.md §10`). Forced camp on the island shore. Each companion asks one question from the log; the Seer gives the final reading; at dawn the player chooses **Alone** or **Together**. | — |
| 1–4 | **The four doors** (`QUEST_TREE.md §5`): **Ward** (lay down the warding item — cannot fail) · **Deed** (the log asks about thy heaviest act) · **Witness** (a companion states what they saw: "is it so?") · **Unopened** (a situation thou walked away from). No quiz. | **Escalating ejection** (§6.1) on a dishonest answer |
| 5 | **The Mirror.** A copy of the party shaped by the player's worst virtue band. Naming the vice (typed) dissolves it; fighting is allowed and wins nothing. | — |
| 6–7 | **Trials of Tension.** Two live dilemmas from this seed's active conflict pairs, companions present. Resolutions recorded to Wisdom. | never ejects |
| 8 | **The Threshold** (§6.2). Temptation may be destroyed. Word of Passage asked. Loyalty-vs-Humility choice. | — |
| Chamber | **The Final Artifact**: 12 questions (§6.3; 4 of them *enacted* rather than asked), then *"What is the one thing that binds the eight?"* → the **Binding Word** found in Act IV (§5); then *"Where does {word} live between {virtue A} and {virtue B}?"* → two of this seed's **virtue-lines** (`QUEST_TREE.md §4.0.6`). Then, ungraded: *"And what didst thou find it to mean?"* — free text, written verbatim to the Book of Paragons (§6.4). | Returned to the surface; must re-meditate Humility (whose vision now names the three roads and gives all eight lines) |

### 6.1 Escalating ejection (Levels 1–4 only)
Per-door failure counter, reset on an honest answer. 1st dishonest answer → back to that level's door. 2nd →
up one level. Nth (N≥3) → up N−1 levels (capped at the entrance). Only the conduct doors (L1–4) eject; the
Mirror, Tension trials, Threshold and Chamber never do.

### 6.2 The Threshold — Loyalty vs Humility
Companions stop. Each speaks one line from their module (farewell / warning / a question they want answered);
the companion of the player's weakest virtue says something that stings. The **choice itself was made at
dawn in the Long Night** (Level 0); here it is only enacted:

| Path | Chamber asks… | Who answers | Tests |
|---|---|---|---|
| **Alone** (Humility) | 4 questions *about the companions* ("What does `{companion:courage}` fear?", "Which of thy companions left thee, and why?") + 4 about the player's own dilemma choices + 4 virtue knowledge | the **human** | Did you *see* the people you travelled with? |
| **Together** (Loyalty) | 8 questions to the **companions** about the player ("Was thy pilgrim ever false to thee?") answered from the Witness Log — the player only listens; a neglected companion's honest answer counts as wrong — + 4 to the player about the companions | companions + human | Have you been, to eight witnesses, who you claim to be? |

Neither is correct. Wisdom scores the choice against the run: bringing neglected companions is Loyalty
without Humility; going alone past eight faithful witnesses is Humility without Loyalty. Companions recruited
late only testify to what they saw (`WITNESS_LOG.md §3`).

### 6.3 Chamber question generation
All questions are generated from the **Witness Log** and the seed's modules — the Chamber never asks about a
scenario the seed did not place or the player never met. If a virtue's log is thin: *"Thou wert never tested
in {virtue}. Why?"* — any honest answer passes; avoidance is itself the record. Wrong answers in the Chamber
do not eject; they are tallied into the epilogue. Only the final word can send the player back.

### 6.4 The reflection — the one question that is not graded
When the Binding Word has been spoken, the artifact asks once more: *"And what didst thou find it to
mean?"* The player writes up to three lines. Nothing parses it; nothing scores it; the Seer never quotes
it. It is written **verbatim** as the first line of this seed's entry in the Book of Paragons and shown on
the title screen beside the seed. The principle's authored one-line meaning is never displayed. The player
leaves with their own sentence, not ours.

**Win state:** the player acts on `{artifact_end}` (weaves / strikes / sounds). The realm's eight virtues,
Wisdom band, the reflection, and epilogue are written to the **Book of Paragons** (§8).

## 7. Epilogue by Degree (fixed order, variable content)

0. **The reflection** (§6.4) — the player's own words, shown alone on a dark screen before anything else.
1. **Wisdom band** — unbalanced / seeking / discerning / whole — sets the tone.
2. Each of the eight virtues: one line on the fate of its town and companion.
3. Companions kept vs. lost; the Threshold path chosen and what it revealed.
4. False tokens believed (named, with who told them).
5. Side quests: three Heart-tier outcomes the log rates highest and lowest (`SIDE_QUESTS.md`).
6. The Temptation: unused / used / destroyed.
7. The Seer's last line (per Wisdom band).
8. Hidden slide — only for *whole* + Temptation destroyed + all companions kept: the mirror, finally sharp.

## 8. Meta-progression Across Seeds

- **Book of Paragons** (`user://book.json`): per completed seed — **the reflection (verbatim)**, the eight
  virtues, Wisdom band, Threshold path, which road gave the Word (dead / silent / still), epilogue. Title
  screen shows each seed's reflection and which of the 15 virtues have never been drawn for this player.
- **Pilgrim's Vows** unlock after the first win (no inns; companion permadeath; silent Seer; no journal…).
- **No mechanical carryover** — no stats, items, or knowledge cross seeds. Only the record.

