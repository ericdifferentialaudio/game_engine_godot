# The Way to the Word — Complete Dependency Tree of a Run

This is the **entire game in one tree**. The root is the win; every leaf is a thing the player must *know*,
*hold*, *do*, or *be granted*. Nothing in the tree is optional except where marked `[opt]`. The tree is the
same in every seed; the names, places and who-knows-what are generated (`PROCEDURAL_GENERATION.md`).

Two readings run in parallel throughout: the **outer road** (what the mechanics require) and the **inner
road** (what each step asks of the person playing). The second reading is not decoration — it is why each
gate is shaped the way it is. Reviewers should reject any change to this tree that keeps the outer road and
loses the inner one.

Related: `CRITICAL_PATH.md` (the five acts), `ITEMS.md §4` (key items), `SET_PIECES.md`, `WITNESS_LOG.md`,
`DESIGN_REVIEW_2026-09.md §11` (the rulings that fixed this tree), `REGRESSION.md §6.11`.

## 0. How to read the tree

| Mark | Node type | Gate kind |
|---|---|---|
| `[TOKEN]` | an intel token (`GAME_DESIGN.md §6`); binary; ≥2 true sources in ≥2 locations | knowledge |
| `[ITEM]` | a key item (`ITEMS.md §4`); never sold, dropped, or lost | possession |
| `[VIRTUE]` | a virtue *granted* at its shrine (never revoked) | knowledge (mantra + shrine) |
| `[DEED]` | something the player must *do* in the world; logged | conduct, recorded not scored |
| `[CHOICE]` | a fork with no correct answer; Wisdom reads it | judgment |
| `[opt]` | not required for the win; changes the end | — |

**Three laws hold everywhere in the tree** (`DESIGN_REVIEW_2026-09.md §1, §8`):
1. **Virtue counters gate nothing.** No node below reads a counter. The counters are the record; the
   Seer, the companions, the Chamber and the epilogue read it — never a door.
2. **Gates are knowledge and items.** Every `[TOKEN]` has ≥2 true sources; every `[ITEM]` has a fixed
   location class; every false token has a refutation discoverable before the point of use.
3. **The player can always progress by talking to more people** (`RULES.md §4.2`) — or by watching, or by
   waiting. The Word has a road for each.

## 1. The tree

```
WIN — act on {artifact_end} (weave / strike / sound)
└─ THE CHAMBER
   ├─ speak the BINDING WORD  [TOKEN codex.word]  ─────────────────────────── §4
   │   ├─ THE DEAD    — ruined-city ghosts at night, after Humility is granted; "Art thou better than we were?" → no
   │   ├─ THE SILENT  — the Silent Monastery: see the abbot bow to the empty ninth plinth; kneel there thyself
   │   └─ THE STILL   — the Anchorite beyond the Mirror Ford: three days and nights without speaking
   │       ✗ false variant: the Magistrate of Debts sells "the word that opens the bottom" (refuted by the
   │         Anchorite, by any true source, and by {companion:humility})
   ├─ place the WORD between two virtues  [TOKEN ×2 of 8 codex.line.slot.N]  — this seed's principle, §4.0.3
   │   └─ lines from: Monastery statues · Humility vision · companions at camp · the Dead · Anchorite's dreams · royal library
   ├─ answer *"what didst thou find it to mean?"*  — free text, ungraded, written to the Book of Paragons
   ├─ the 12 questions (8 asked, 4 enacted) — never a gate; they shape the epilogue
   └─ REACH THE CHAMBER — the Descent, L0–L8 (no fail state)
      ├─ L8  THE THRESHOLD
      │   ├─ speak the WORD OF PASSAGE  [TOKEN ×3 syllables]
      │   │   └─ three keepers, one per House region; each asks about a virtue *not* their own
      │   ├─ enact ALONE / TOGETHER  [CHOICE — made at L0, only enacted here]
      │   └─ [opt] destroy the TEMPTATION  [ITEM, carried unused since Act II]
      ├─ L6–7 TRIALS OF TENSION  [CHOICE ×2] — live dilemmas from this seed's conflict pairs
      ├─ L5   THE MIRROR  [DEED] — name thy own vice (typed); fighting wins nothing
      ├─ L1–4 THE FOUR DOORS  [DEED ×4] — Ward · Deed · Witness · Unopened (§5); a lie ejects, escalating
      ├─ L0   THE LONG NIGHT  [CHOICE] — each companion asks one question from the log; the Seer's last reading; dawn
      └─ ENTER THE DESCENT  — gate: Ring bound ×8 ∧ Horn ∧ 3 Artifacts
         ├─ THE HORN  [ITEM] — seeded among: Bell in the Deep · Silent Monastery · Maelstrom Gate
         │   └─ its location  [TOKEN] (fisher's song / House chart / monastery bell-table / …)
         ├─ THREE HOUSE ARTIFACTS  [ITEM ×3] — one per House {castle:f1..f3}
         │   ├─ House password  [TOKEN ×3] — Drowned Court · set pieces · House-region towns
         │   └─ family trial  [DEED ×3] — Fortitude / Care / Truth / Justice / Giving / Self-assessment / Commitment / Intellectual
         └─ THE SIGIL RING bound ×8  [ITEM]
            ├─ the Ring itself — given by {ruler} when the first stone is shown
            └─ per virtue slot N (×8): bind STONE N + SIGIL N at the altar room (level 8 of dungeon N)
               │   (the 8th binding, in the Pride dungeon, opens the passage to the end-island)
               ├─ SIGIL N  [ITEM] — hidden in town N
               │   └─ its location  [TOKEN] — the sigil-hider (indirect) + a dream / ghost / animal
               └─ STONE N  [ITEM] — level 8 of dungeon N, behind the third temptation floor
                  ├─ dungeon N location  [TOKEN]
                  ├─ the descent itself  [DEED] — 3 temptation floors of vice N, each logged either way
                  └─ ★ LIFTABLE ONLY WHEN ALL EIGHT VIRTUES ARE GRANTED  (Act IV gate)
                     ├─ VIRTUE N (×7)  [VIRTUE] — meditate MANTRA N at SHRINE N (quick; wrong → a day lost)
                     │   ├─ MANTRA N  [TOKEN] — keeper behind a virtue-flavoured test + royal library / scholar / vision
                     │   ├─ SHRINE N  [TOKEN] — pointer NPC + beggar-after-gifts / book / dream
                     │   └─ → companion N becomes recruitable (a witness for Together)
                     └─ HUMILITY, the 8th  [VIRTUE] — Act III, the hinge
                        ├─ ≥ 4 virtues granted (the fiends yield only to one with something to be humble about)
                        ├─ the ruined city  [TOKEN location] — rumour after the 4th shrine; the Seer's hint
                        ├─ WARDING ITEM  [ITEM] — hidden in the city
                        │   └─ ghosts' PASSWORD  [TOKEN] — given by dialogue only: every boast refused; "better than we were?" → no
                        ├─ pass the fiends without striking first  [DEED]
                        └─ MANTRA 8  [TOKEN] — ghost fragments, one per ghost, at night
                           └─ ACT I — {ruler} names the eight; the first mantra; the anchor shrine within a day's walk
```

**Transport is the hidden trunk:** three virtue towns, the ruined city, the Houses, the Court and the
Monastery lie across water; a ship is always obtainable in Act II (pirates, purchase, or the smuggler
quest). Moon gates are a shortcut, never the only way (`PROCEDURAL_GENERATION.md §2` stage 5).

## 2. Node sheets — the outer road and the inner road

Each row: what is required · where it comes from · **what it asks of the player**.

### 2.1 Act I — The Stranger
| Node | Requires | Source | Asks of you |
|---|---|---|---|
| The eight named | walk to the royal seat | `{ruler}`; the only time the full list is spoken | *You will be measured by goods you did not choose. Will you listen once, carefully?* |
| First mantra | one honesty test | anchor mantra-keeper; royal library | *What do you know only because someone told you — and did you check?* |
| First shrine | a day's walk | shrine-pointer; the beggar after three gifts | *Where do you go to be quiet?* |

### 2.2 Act II — The Pilgrim (×7)
| Node | Requires | Source | Asks of you |
|---|---|---|---|
| Mantra N `[TOKEN]` | a virtue-flavoured test | keeper in town N; a second source elsewhere; a market vendor sells a wrong one | *Can you tell a true word from a bought one?* |
| Shrine N `[TOKEN]` | — | pointer; beggar; book; dream; a drunk lies | *Whom do you believe, and why them?* |
| Meditation `[VIRTUE]` | mantra + correct shrine | quick; never revoked | *A virtue is given the moment you know where to stand. Living it is a separate matter — and that is what is recorded.* |
| Companion N | virtue N granted | waits in town N | *Who has seen you at your worst and stayed?* |
| Sigil N `[ITEM]` | its location `[TOKEN]` | hider in town N (indirect) + dream/ghost/animal | *The sign of a virtue is kept by the small and the overlooked. Did you speak to the child?* |
| Dungeon N `[DEED]` | its location; light; rations `[opt]` | three temptation floors; the stone waits | *What do you take when no one is looking? (Someone is: the log.)* |

### 2.3 Act III — The Humbled
| Node | Requires | Source | Asks of you |
|---|---|---|---|
| The ruined city | ≥4 virtues | rumour; the Seer: "one virtue thou hast not asked me of" | *The city had every virtue but one. Which one do you lack?* |
| Ghosts' password `[TOKEN]` | dialogue only — refuse every boast; "art thou better than we were?" → *no* | the dead, at night | *Can you say "no" when "yes" is true of your deeds and false of your heart?* |
| Warding item `[ITEM]` | password | hidden in the city | *You are protected from pride only as long as you do not strike first.* |
| Humility `[VIRTUE]` | mantra 8 + fiends passed + shrine | the vision replays *your own run from the other side* | *See yourself as the people you met saw you.* |

### 2.4 Act IV — The Keeper
| Node | Requires | Source | Asks of you |
|---|---|---|---|
| Stone N `[ITEM]` ×8 | **all eight virtues** + dungeon bottom | revisit; faster the second time | *One good held alone hardens into a vice — justice without mercy, courage without humility. You may carry none until you can carry all.* |
| Ring `[ITEM]` | show the first stone | `{ruler}` | *You are now trusted with joining things.* |
| Binding ×8 `[DEED]` | stone N + sigil N at altar N | the 8th in the Pride dungeon opens the end-island | *The stone came from the dark, alone. The sigil came from the town, among people. The Ring makes them one thing — what you are below, and what you are among them.* |
| Horn `[ITEM]` | its location `[TOKEN]` | Bell / Monastery / Maelstrom | *Whom do you call, and who answers?* |
| Artifacts ×3 `[ITEM]` | password `[TOKEN]` + family trial `[DEED]` | the three Houses | *What did your house teach you, and what did it cost?* |
| Word of Passage ×3 `[TOKEN]` | each keeper asks about a virtue *not* their own | House regions | *Can you speak well of a good that is not yours?* |
| The Binding Word `[TOKEN]` | one of three roads (§4) | the dead · the silent · the still | *How do you come to know a thing: by asking, by watching, or by being still?* |
| Temptation `[opt]` | found from Act II | seeded | *Will you carry power you do not use — all the way down?* |

### 2.5 Act V — The Descent
| Node | Requires | Asks of you |
|---|---|---|
| The Long Night | forced camp | *What will the people who love you ask you at the end?* |
| Doors L1–4 (§5) | honest answers about your own record | *Can you stand in front of what you did?* |
| The Mirror | name your vice | *Do you know what you are worst at — by its name?* |
| Trials of Tension | two live dilemmas | *Nothing you learned makes this easy. Choose anyway.* |
| The Threshold | Word of Passage; Alone/Together enacted | *Do you go to the end alone, or with those who saw you? Neither is right.* |
| The Chamber | the Binding Word | *Say the one thing under the eight. Then say what it meant to you.* |

## 3. Mandatory token ledger (every seed)

| Token | Count | Source classes (≥2 in ≥2 places) | False variant |
|---|---|---|---|
| Mantra | 8 | keeper NPC (test) · royal library / other scholar / other shrine's vision · ghosts (slot 8) | market vendor / cult (twist 8) |
| Shrine location | 8 | pointer · beggar-after-gifts · book · dream | drunk / rival pilgrim |
| Sigil location | 8 | hider (indirect) · dream / ghost / animal | none — sigils are hidden, never disputed |
| Dungeon location | 8 | tavern · signpost · companion N · map fragment | none |
| Ruined-city location | 1 | rumour after the 4th shrine · Seer · any town's Lore token | none |
| Ghosts' password | 1 | dialogue with the ghosts (conduct *in dialogue*, not a counter) | — |
| Horn location | 1 | fisher / chart / monk bell-table (seeded with the horn) | Court's clerk (Bell coordinates) |
| House password | 3 | Drowned Court · set pieces · House-region towns | Court favour variant |
| Word of Passage | 3 | keeper (asks of another virtue) · Court · hidden-lake village | — |
| **Binding Word** | 1 | **the dead · the silent · the still** (three source *kinds*) | **the Magistrate of Debts** |
| **Virtue-lines** (the Word's meaning) | 8 (≥2 needed) | Monastery statues · Humility vision · companions · the Dead · Anchorite's dreams · royal library | none — the false Word simply comes with no lines |
| **Total mandatory** | **50** | | |

Optional but life-changing: the moon table (8 phases), magic-item locations (8–12), the Temptation's
location, "the maelstrom is a door", Bell coordinates, House charts.

## 4. The Binding Word — three ways of knowing

**What it is.** `{final_word}` (`NAMING_AND_LORE.md §2`) is the label of this seed's **binding principle**
— the one thing that genuinely holds *these* eight together. Because the eight change every seed, the
answer **must** change with them: the *rule* for deriving it is fixed, the *answer* falls out of the draw
(`RULES.md §3.6`). A player on their third seed knows the twelve principles exist — and must still work out
which one binds *this* realm's eight, from what the realm teaches. Knowing the list is not knowing the answer.

#### 4.0.0 Three things the player must do
1. **Find the word** — by one of three roads (§4.1–4.3). This is a location/knowledge problem.
2. **Hear the lines** — eight short sayings, one per drawn virtue, each showing how *this* principle lives in
   *that* virtue (§4.0.2, §4.0.4). This is an attention problem: they are spoken and carved across Act III–IV.
3. **Place the word** — in the Chamber, between two of the virtues that were in tension in *this run*
   (§4.0.6). This is an understanding problem, and it cannot be brought in from another seed.

#### 4.0.1 The twelve principles (`data/codex/principles.json` — fixed, hand-authored)
Each principle: `id`, an author-facing **meaning** (never displayed), a **shadow** (the failure of the eight
when *not* bound by it — used by the Mirror and the Dead), and labels per flavour (§4.6).

| id | Meaning (author-facing) | Shadow (what the eight become without it) |
|---|---|---|
| `presence` | to be wholly here for what is before thee | virtue performed at a distance; help that never looks up |
| `measure` | to give each thing its due, no more and no less | zealotry — one good swallowing the rest |
| `constancy` | to be tomorrow what thou wert today | fair-weather goodness |
| `mercy` | to hold the wrong and release the one who did it | righteousness without a door out |
| `candor` | to let the inside and the outside be one | a reputation instead of a character |
| `yielding` | to set down thine own claim | goodness that keeps the receipt |
| `regard` | to see the other as one who is owed | charity that condescends |
| `steadfastness` | to stay when leaving is easier | virtue that lasts until it costs |
| `openness` | to let what is true change thee | conviction that has stopped listening |
| `stewardship` | to keep what is given for those who come after | virtue that ends with thee |
| `smallness` | to take the lower place without being asked | the paragon who needs to be seen as one |
| `truthfulness` | to say the thing that is so, and pay for it | kindness that lies |

#### 4.0.2 Affinity matrix (12 × 15, 0–3) — authoritative; data must match

| | int | com | kin | for | sel | res | jus | cou | per | sdi | hum | gra | loy | opn | rev |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| presence | 1 | 3 | 3 | 1 | 1 | 2 | 1 | 1 | 1 | 1 | 2 | 2 | 1 | 3 | 3 |
| measure | 1 | 1 | 1 | 1 | 2 | 2 | 3 | 1 | 1 | 3 | 3 | 1 | 1 | 1 | 1 |
| constancy | 3 | 1 | 1 | 1 | 1 | 1 | 1 | 2 | 3 | 2 | 1 | 2 | 3 | 0 | 1 |
| mercy | 1 | 3 | 2 | 3 | 2 | 1 | 1 | 1 | 0 | 1 | 2 | 1 | 1 | 1 | 1 |
| candor | 3 | 1 | 1 | 1 | 1 | 1 | 2 | 3 | 1 | 1 | 2 | 1 | 1 | 2 | 1 |
| yielding | 1 | 1 | 1 | 2 | 3 | 1 | 1 | 1 | 1 | 2 | 3 | 2 | 1 | 1 | 2 |
| regard | 1 | 1 | 2 | 1 | 1 | 3 | 2 | 0 | 1 | 1 | 1 | 3 | 2 | 1 | 1 |
| steadfastness | 2 | 1 | 1 | 0 | 1 | 1 | 1 | 3 | 3 | 2 | 1 | 1 | 3 | 1 | 1 |
| openness | 1 | 2 | 1 | 2 | 1 | 1 | 1 | 1 | 1 | 1 | 2 | 1 | 0 | 3 | 2 |
| stewardship | 1 | 1 | 2 | 1 | 3 | 1 | 2 | 1 | 2 | 1 | 1 | 3 | 1 | 1 | 1 |
| smallness | 1 | 1 | 2 | 1 | 2 | 1 | 1 | 1 | 1 | 2 | 3 | 2 | 1 | 1 | 2 |
| truthfulness | 3 | 1 | 0 | 1 | 1 | 2 | 3 | 2 | 1 | 1 | 1 | 1 | 1 | 2 | 1 |

Constraints (validator): Humility ≥1 with every principle · every virtue has ≥3 principles at affinity ≥2 ·
each principle has ≤2 zeros, never on Humility or the anchors (Integrity, Justice) · every one of the 924
launch draws has ≥1 eligible principle (REG-END-14). Worst case is a Care-heavy draw {compassion, kindness,
forgiveness…}: `mercy` and `presence` both remain eligible. The table above is the tuning baseline; changing
a cell bumps `schema_version`.

#### 4.0.3 Derivation — generation stage 1c (deterministic per seed)
```
score(p)  = Σ affinity(p, v) for v in drawn_eight
eligible  = { p : affinity(p, v) ≥ 1 for at least 6 of the 8 }      # it must genuinely bind them
principle = argmax score over eligible; ties → rng.derive("codex")
{final_word} = label drawn from principle.labels[flavor]           # unique in the seed
validator : eligible non-empty, else redraw stage 1a
```
The Book of Paragons is **not** an input: the same seed is the same world for everyone (Daily Pilgrimage).
Two seeds with the same eight and flavour get the same principle and may get different labels — structure
fixed, dressing random (`PROCEDURAL_GENERATION.md §3`). REG-END-14.

#### 4.0.4 Virtue-lines — authoring spec (`data/virtues/<id>/codex_lines.json`, 12 per module)
A line says how *this principle* shows up as an **act** of *this virtue* — never the abstraction, never the
word itself. ≤2 sentences, early-modern register, no proper nouns. Each line ships in two registers with the
same content: **spoken** (companions, ghosts, dreams — first or second person) and **carved** (statues, the
library book — third person, terse). The Chamber accepts either.

Worked set — the vertical-slice seed {integrity, compassion, kindness, justice, courage, selflessness,
loyalty, humility}. Scores from §4.0.2: **candor 14** · measure 13 · mercy 13 · constancy 13 · steadfastness 13
· presence 13 · yielding 12 · smallness 12 · stewardship 12 · truthfulness 12 · regard 10 · openness 9. All
twelve are eligible (≥6 of 8 at ≥1); `candor` wins outright — fitting for a slice built on honesty tests.
(Verified by exhaustive script over the matrix; all 924 launch draws have ≥1 eligible principle.) Lines:

| Virtue | Carved | Spoken |
|---|---|---|
| integrity | *Speaks in the dark as in the square.* | "I have one voice. I use it in the dark and in the square." |
| compassion | *Does not hide pity behind help.* | "When I help thee, I will not pretend it costs me nothing, nor that it costs me everything." |
| kindness | *Gives the small thing without the small lie.* | "A kind word that is not true is a coin with no metal in it." |
| justice | *Judges aloud what it judged within.* | "The verdict I give is the one I reached. If I reached none, I say so." |
| courage | *Fears in the open.* | "I am afraid, and I am going. Both are true; I will hide neither." |
| selflessness | *Gives without a second ledger.* | "If I give and keep a count, I have given nothing. Let the giving be the whole of it." |
| loyalty | *Stands with a friend and tells him he is wrong.* | "I am thine. That is why I will not lie to thee." |
| humility | *Says 'I know not' before it is found out.* | "I would rather say I know not than be shown it." |

#### 4.0.5 How the meaning is taught (it is content, not a lookup)
The seed's eight lines are placed as tokens (`category: codex`, `codex.line.slot.N`); each slot ≥2 sources of ≥2 kinds:

| Source | Register | Slots given | Kind |
|---|---|---|---|
| **Silent Monastery** statue hall (§4.2) | carved | all 8 (examine each statue; no dialogue) | observation |
| **Humility vision** (Act III) | spoken | anchor (slot 1) + Humility (slot 8) | vision |
| **Companions** at camp, Act IV | spoken | their own slot, once, unprompted; late joiners too | companion |
| **The Dead** (§4.1) | spoken, as loss | the two virtues with the largest `pair_gains` imbalance | ghost |
| **The Anchorite's three dreams** (§4.3) | spoken | the three virtues of the player's three restaged dilemmas | dream |
| Royal library | carved | all 8, the word blotted out | book |
| **Market vendor** (`village.market`) | carved | sells any *one* line for a favour — true, but the favour is logged | market |

The Court's false favour hands a word and **no lines**. The shadow (§4.0.1) is spoken once by the Mirror
(L5) and once by the last ruler's ghost — never with the word attached.

#### 4.0.6 The Chamber test — exact rules
1. **The word.** *"What is the one thing that binds the eight?"* — typed; must equal `{final_word}`
   (case-insensitive). Wrong → surface (§4.4).
2. **The meaning.** The artifact chooses virtues **A, B**: the active conflict pair with the largest
   `pair_gains` total; if none active, the two drawn virtues with the most imbalanced counters; **never both
   Humility**; A ≠ B. It asks *"Where does {word} live between {A} and {B}?"* The player picks **two chips**
   from the lines they hold (`held_day != null`; spoken or carved). Correct iff `{chips} == {line.A, line.B}`.
   Fewer than two lines held → the question is still asked; the failure is honest.
3. **On failure of either part:** returned to the surface; re-meditate Humility, whose vision now gives all
   eight lines and names all three roads. No limit on attempts; each is logged (`final_word.attempts`).
4. **The false Word cannot pass by luck:** the Court's word is a label of a *different* principle; even a
   player who has heard lines cannot match them to it.
Then the ungraded reflection (§4.7). REG-END-15.

#### 4.0.7 What this teaches
A principle is not learned by reading its definition (the game never shows one). It is found by noticing what
eight goods have in common in *your own* choices — the lines are all "how this looks when done", and the
Chamber asks where it lives between the two goods *you* struggled to hold together. A second playthrough
with a different eight finds a different binding. That is not a randomiser; it is the claim that what holds
a life together depends on which goods that life was asked to carry.

#### 4.0.8 Data schema
```
principles.json: [ { id, meaning, shadow, affinity: { <virtue_id>: 0..3 (15 keys) },
                     labels: { neutral: [..], norse: [..], celtic: [..], latin: [..] } } ]  # ≥3 each, unique per flavour
data/virtues/<id>/codex_lines.json: [ { principle_id, carved, spoken } ]                   # exactly 12
Seed:  codex: { principle_id, final_word, lines: { slot.N: { carved, spoken, sources: [..] } } }
```
Validator: matrix constraints of §4.0.2; 924-draw eligibility; labels unique per flavour and absent from the
banlist; 12 lines per drawable module; each `codex.line.slot.N` has ≥2 sources of ≥2 kinds in the graph.

### 4.1 The Dead — the ruined city, at night (source kind `ghost`)
- **When:** any night after Humility is granted (the ghosts now know the player as one of them: humbled).
- **Who:** the ghost of the city's last ruler, at the shrine steps. One line: *"We had eight. We lacked what
  holds eight. Art thou better than we were?"*
- **Answer *no*** → the word is given. **Answer *yes*** → the ghost fades until the next night
  (`boasted_to_dead`, a Humility loss event). Silence → *"Come back when thou canst answer."*
- **Cost:** a return journey to a far coast; a night. This is the **talker's road** and the `hermit` golden run's.

### 4.2 The Silent — the Silent Monastery (source kind `observation`)
- **Where:** the statue hall — eight statues, the seed's virtues, and an **empty ninth plinth**.
- **Watch:** at dawn the abbot bows to each of the eight — and last, longest, to the empty plinth.
  Observation event `saw_abbot_bow_ninth` (requires being present at dawn; no dialogue; speaking is `respect −1`).
- **Do:** kneel at the ninth plinth (context action) *after* having seen the bow. The word is cut into the
  step beneath the kneeler's knees, readable only from there. Kneeling without having watched reveals nothing.
- **Cost:** a dawn, a second visit, and the humility of copying a monk. This is the **watcher's road**.

### 4.3 The Still — the Anchorite beyond the Mirror Ford (source kind `silence`)
- **Where:** `site.hermitage` — a day's walk upriver on the *far* bank of the Mirror Ford (so the party has
  already been tested there; `SET_PIECES.md §8`). Fixed placement, every seed.
- **Who:** the **Anchorite** (`role.site.anchorite`; not the Reverence companion). Speaks once on arrival:
  *"The word is not told. It is what is left when talking stops. Stay, if thou canst."*
- **Do:** remain three nights without a single `talk` action by anyone in the party and without leaving the
  hermitage cell. Each night a dream restages one of the player's own dilemmas from the *other* side. On the
  third dawn the Anchorite speaks the word — and nothing else, ever. Speaking or leaving resets the count
  (*"Thou hast spoken. Begin again."*).
- **Food:** three nights consume rations; a party with none is fed by the Anchorite — the only time in the
  game a Kindness scenario is done *to* the player (`fed_by_anchorite`, logged; asked about in the Chamber).
- **Cost:** three days (moons turn, followups may lapse, a Commitment trial may expire). Self-discipline /
  Reverence flavoured; works without either drawn. This is the **waiter's road**.

### 4.4 The false word — the Drowned Court
The Magistrate of Debts sells *"the word that opens the bottom"* for his costliest favour (stand witness at
a sale). It is false. **Refuted by:** the Anchorite (*"That is what the Magistrate sells. He has never been
below."*), any true source, and `{companion:humility}` on the road (*"A bought word. Does it weigh right?"*).
Acting on it in the Chamber → returned to the surface; re-meditate Humility, whose vision now names all
three roads plainly. Twist 1 (*False seer*) may hand the same false word.

### 4.5 How the player learns the three roads exist
1. Humility's shrine vision (Act III) shows three images: a city of ghosts, a bowing monk, an old one who
   does not speak — Person tokens `codex.road.dead / .silent / .still`, oblique.
2. The Seer's second reading: *"Ask the dead, or watch the silent, or be still."*
3. Every town's third Lore token is a rumour about the Word (this is also how the Court's offer spreads).
4. Companions of Reverence / Open-mindedness / Self-discipline (if drawn) each know one road.

### 4.6 The label pools (`data/codex/principles.json → labels[flavor]`, P1-T2)
Each of the twelve principles carries ≥3 labels per flavour (neutral / norse / celtic / latin), e.g. Measure →
*Measure, Due, Mete, Modus*; Presence → *Presence, Heed, Regard, Adsum*. Labels are unique across principles
within a flavour, so a word names exactly one principle. The inspiration's own answer and its synonyms are
banned (`RULES.md §3.14`). Wisdom's label pool stays separate.

### 4.7 The last question is not graded
After the correct word: *"And what didst thou find it to mean?"* Free text, up to three lines. Never scored,
never parsed. Written verbatim to the Book of Paragons as the entry's first line and shown on the title
screen beside the seed. The next seed asks again. **This is the game's actual ending** — the player's own
sentence, not ours.

## 5. The four doors (Act V, L1–4) — final design

| Level | Door | Opens on | A lie… |
|---|---|---|---|
| 1 | **Door of the Ward** | *item* — lay down the warding item (*"Below, nothing wards thee from thyself"*) | cannot lie; always opens |
| 2 | **Door of the Deed** | *log* — *"Hast thou ever …?"* built from the player's heaviest negative event; honest *yes* passes; honest *no* (if there is none) passes | ejects (`CRITICAL_PATH.md §6.1` escalation) |
| 3 | **Door of the Witness** | *testimony* — the companion with the most witnessed events states one thing they saw; *"Is it so?"*; with no companions the door reads the log aloud instead | ejects |
| 4 | **Door of the Unopened** | *avoidance* — an `avoided` staged situation: *"In {town} a woman in a cell called to thee. What didst thou?"* — *"I walked on"* passes; if nothing was avoided: *"Thou didst turn from nothing. Was that courage, or pride?"* — any answer passes | ejects |

Grading uses the honesty grid of `WITNESS_LOG.md §5`. No door asks a knowledge question. The four are in
this order on purpose: first you lay down protection, then you own a deed, then you are told by another,
then you face what you never began.

## 6. Optional branches that change the end
- **The Temptation** — use / carry / destroy at L8 (`ITEMS.md §4`). Using it zeroes the record and locks Wisdom.
- **Companions** — each is a witness; the *Together* path is only as strong as what they saw and how they
  were treated. Lost-loyalty companions refuse the Ford.
- **The Assize, the Court's debt, the Debtor's Isle, the navy in disguise** — none required; all read at the end.
- **Repeat visits** — the Anchorite never speaks again; the ghosts do; the monks were never speaking.

## 7. The inner road — the five acts as a life

| Act | Outer | Inner |
|---|---|---|
| I The Stranger | learn the loop | *arrival* — you are measured by a scale you did not choose |
| II The Pilgrim | seven virtues, in any order | *practice* — goods are learned one at a time, and they begin to argue |
| III The Humbled | the eighth, guarded | *the fall* — you meet a city that had everything you have, and fell; you see your own run from the other side |
| IV The Keeper | stones, ring, horn, artifacts, the Word | *integration* — nothing may be carried alone; the dark and the town are joined; you learn how you learn |
| V The Descent | doors, mirror, tension, threshold, chamber | *the reckoning* — not judged by a god but asked, by people who saw you, whether you were who you said |

The game never tells the player what to conclude. It arranges for them to be asked.

## 8. Why this is not a fetch quest (design defences)
1. **Every item on the trunk is behind a deed, not a fight** — temptation floors, family trials, kneeling,
   silence, refusing to boast. Combat never gates the trunk (`RULES.md §4.2`).
2. **Every token has a false twin somewhere** except the ones that are *hidden* rather than *disputed*
   (sigils) — corroboration is the core skill, not collection.
3. **The stones cannot be taken one at a time.** Act IV is a *return* through every dungeon with a different
   heart; the second descent is faster and the temptation floors are still there.
4. **The Word has three roads of three kinds**, so no playstyle is locked out and each road is itself a
   lesson in how that player learns.
5. **The end is answered three times** — the seed's word (knowledge), its place between two of *your*
   virtues (understanding, derived from this seed), and the player's own sentence (meaning, ungraded). Only
   the first two are gates.
6. **Doing good to be counted stops counting** (`repeat_cap`, `DESIGN_REVIEW_2026-09.md §11.2`): the beggar
   turns you away. Virtue that is performed for the log is not virtue, and the world says so in-world.
7. **The answer cannot be memorised across seeds.** Twelve principles, C(12,6)=924 draws, and the same eight
   can wear different labels; the word is only ever earned by hearing what *this* realm's eight say about it.

## 9. Validator and tests
- Generator: stage 1c picks the principle deterministically with ≥6/8 affinity, else redraw (REG-END-14);
  the three Word sources are placed with kinds `{ghost, observation, silence}` (REG-END-02); all eight
  virtue-lines have ≥2 sources (REG-INT-08); `site.hermitage` on the far bank of the Ford (REG-SET-01); the
  false word at the Court with ≥1 refutation reachable before the Chamber (REG-INT-03).
- Runtime: the Anchorite's count resets on any `talk`/leave (REG-END-10); kneeling reveals only after
  `saw_abbot_bow_ninth` (REG-END-11); the reflection text is stored verbatim, never graded (REG-END-12); the
  meaning test accepts exactly the two named virtues' lines (REG-END-15).
- Tree integrity: `tools/token_graph.py` asserts the 50 mandatory tokens and the item chain of §1 for every
  seed in the soak (`RULES.md §3.17`).

