# Design Review — 2026-09 (gameplay deep-think before the Godot port)

Status per item: **Decided** (user ruling, applied to docs). Items originally marked **Proposed** (§2.3, §6,
§7, §9) were ruled on 2026-09-07 — see **§11**, which supersedes them where wording differs. Each item:
problem → evidence → change → cost → affected docs/tasks.

Related: `REGRESSION.md` (every decision here has a test), `ITEMS.md`, `CRITICAL_PATH.md`.

## 0. Frame: what the inspiration got right, and where homages flatten it

The inspiration's insight was that **the moral system is the plot**: no villain, invisible meters, a
climax that already happened incrementally, and a final "boss" that is comprehension. Homages usually keep
the eight-virtue *content* and lose two structural things: (a) the **invisibility** of the meter, and (b) the
fact that the meter was never a *gate* the player could see themselves clearing. Paragon keeps both and
adds what the inspiration lacked: a reason the invisible table cannot simply be memorised and grinded
(different eight every seed, conflict pairs, event-based rather than increment-based record).

## 1. Virtue counters gate nothing — **Decided**

**Problem.** `CRITICAL_PATH.md §3.1` and `GAME_DESIGN.md §5` said: raise a hidden counter to 99, meditate
three cycles, lose it if you drop below 75. That reproduces the inspiration's grind (donate blood eight
times, then meditate) and turns the shrine into a stat check the player learns to game.

**Ruling.** Meditation succeeds iff the **mantra is known** and the player is at the **correct shrine**. It
is quick (one visit). A successful meditation **grants the virtue** (1 of 8), makes its companion
recruitable, and is never revoked. The counters remain as the **moral record** read by the Seer, companions,
the Chamber and the epilogue — never by a gate. Two knowledge/conduct gates stay because they are not
counters: Humility's shrine requires ≥4 virtues first; its guardians are passed by the warding item if the
player does not strike first.

**Consequence.** All moral weight moves to the Witness Log and the end. That is the thesis.
**Affects.** `CRITICAL_PATH.md §1, §3.1`, `GAME_DESIGN.md §5`, `VIRTUES.md §1`, REG-SHR-*, REG-VIR-07.

## 2. Opacity: what the player may see — **Decided**

The Pilgrim's Book gains a **Ledger of Days** with *journey facts only*. Rule §3.5 is extended (proposed
wording there) so that *conduct-derived counts* are hidden too, since "kills: 211 / fleeing: 14" is a virtue
meter with extra steps.

| Visible (`RunStats.public`) | Hidden (`RunStats.hidden`) |
|---|---|
| gold, days, steps and distance by mode, places and regions visited, tokens held (never marked true/false), items bought/found/sold, companions and when they joined, virtues meditated and when, stones held, set pieces visited | kills by kind, subdues, spared, honesty-test and in-game-question outcomes, false tokens acted on, virtue counters and bands, Wisdom, per-scenario counts, companion loyalty and judgement, quest resolutions, set-piece outcomes, everything in Act V until the epilogue |

**2.3 Anti-grind (Decided, see §11.2).** The log records *events*, not increments. Each scenario carries a
`repeat_cap` (default 3); repeats beyond it still write an event (the Chamber may quote "the fortieth
coin") but with `virtue_effects` weight 0. Blood-donation loops become impossible by construction.
**Affects.** `RULES.md §3.5` (proposal), `REGRESSION.md §3`, REG-INV-01, REG-VIR-04.

## 3. Items and gold are a real system — **Decided**

Gold buys better gear from goods-sellers in villages (low tier), towns (mid), castles (high); magic items
are per-seed uniques whose *locations are intel tokens*, some at dungeon bottoms. Full spec: `ITEMS.md`.
Gold also has moral sinks (ransom, restitution, fines for others, donation, the Debtor's Isle, the
Magistrate's debt); `spent_on_others` vs `spent_on_self` is a hidden Wisdom input (Proposed).
**Affects.** `ITEMS.md` (new), `GAME_DESIGN.md §10`, P1-T13, REG-ECO-*, REG-ITM-*.

## 4. Companions judge honestly from what they saw — **Decided**

Late joining is fine. A companion's judgement is shaped by every moral event they were present for; they
have less material if they joined late, and they say so. They are pilgrims on the same road toward the last
virtue and must be true to themselves, so the final judgement is **honest, never harsh**: below a witnessed
floor the companion reports `unseen` ("I was not there for most of thy road"), never a condemnation.
**Affects.** `WITNESS_LOG.md §2` (already consistent), REG-PTY-03, `CRITICAL_PATH.md §6.2` wording.

## 5. Intel tokens are binary with category tags — **Decided**

A token is held or not. It carries a `category` (mantra, shrine/town/castle/dungeon location, dungeon stone,
magic-item location, sigil, password, word syllable, codex, person, lore, recipe, rule) and `truth`. No
confidence gradient; corroboration stays a player habit. The journal never marks truth.
**Affects.** `GAME_DESIGN.md §6` (category list), REG-INT-*.

## 6. Food: keep it, make it a reason to go to villages — **Decided (see §11.1)**

Drop per-step attrition (bookkeeping, not choice). Food is consumed **only at camp**: one ration per member
per night. Villages always sell rations cheaply, towns dearer, the wild none. Camping without rations heals
nothing (`nights_hungry`) but does no HP damage. Effect: villages get a purpose, expeditions and dungeon dives
are planned, and Compassion/Kindness/Selflessness scenarios (share thy fire; feed the beggar) have teeth.
Alternative on the table: drop food entirely. **Affects.** `GAME_DESIGN.md §10, §13`, REG-TRV-04/05.

## 7. The end is found, not quizzed — **Decided (see §11.3–11.4)**

The Chamber's one question — *"What is the one thing that binds the eight?"* — is answered with a **codex
token** the player must have *found*: held by an NPC deep in hard territory (candidate: the Silent
Monastery; alternative: a hermit past the Mirror Ford), with a second true source in the ruined city's ghosts
(redundancy rule), and one false variant with a refutation. Descent Levels 1–4 become **conduct doors**
(opened by companion testimony, the log, or a key item) instead of quiz altars; escalating ejection applies
only to those doors. The Mirror (L5), Tension trials (L6–7), Threshold (L8) and Long Night (L0) stay.
Chamber questions: 12 remain but 4 are **enacted** (a past scenario restaged from the other side) rather
than asked. **Affects.** `CRITICAL_PATH.md §6`, `SET_PIECES.md §7`, REG-END-02/04/07.

## 8. Act structure follows the item chain — **Decided**

```
mantra (token) + shrine (token) → meditate → virtue ×8
  → stones may be taken from the 8 dungeon bottoms (gated on 8 virtues)
  → stones + sigils bound into the Ring; horn; 3 House artifacts; Word of Passage
  → the Descent → codex answer → win
```
Dungeons are seeded set pieces present from the start; each has *something at the bottom that must be
found* (the stone; sometimes a magic item as well). Dungeon-before-shrine remains legal for exploration and
loot; only the stone waits.
**Affects.** `CRITICAL_PATH.md §1, §3.1, §5`, REG-DNG-04/05, REG-END-01.

## 9. Scope: the vertical-slice seed — **Decided (see §11.5)**

One fixed seed for M1–M3: virtues {integrity, compassion, kindness, justice, courage, selflessness, loyalty,
humility}, 1 clan, 3 set pieces (Drowned Court, Mirror Ford, Long Night), 12 quests, 2 dungeons fully
authored + 6 short, 40 NPC roles. Everything else is Phase 5. The golden regression runs (`REGRESSION.md §7`)
target this seed first.

## 10. Quests — unchanged (confirmed good).

## 11. Rulings of 2026-09-07 — all proposals above are now **Decided**

The complete resulting dependency tree is `QUEST_TREE.md`. Items 2.3, 6, 7 and 9 above are superseded by
the wording here where they differ.

### 11.1 Food — real survival, never a gate (§6 adopted; hardened 2026-09-07, ruling: *"if they truly run out — hunger, HP loss; food is a real thing"*)
One ration per member per night **at camp**; bought with gold (village 2 / town 5 / castle 8 per ration —
`data/items/prices.json`); the wild sells none; inns need none. Gold comes chiefly from monsters and loot, so
**the food bill is what turns wandering-monster gold into a decision** (food vs reagents vs a better blade —
`ITEMS.md §0`). Hunger has a **body and teeth, but no gate**:

| State | Trigger | Effect |
|---|---|---|
| Fed | camped with a ration each | full night's heal |
| **Hungry** (night 1) | camped without | no heal; **Weary** next day: −1 initiative, cannot mix reagents, companions remark |
| **Starving** (night 2) | second hungry night in a row | Weary + no MP regen + **−10 % MaxHP per member at dawn**; NPC tone notes it |
| **Famished** (night 3+) | each further hungry night | **−20 % MaxHP at dawn**; STR/DEX −1 for the day; each step costs 2 minutes |
| **Unconscious** | a member's HP reaches 0 by hunger | falls, is carried, revives on the first ration or inn — **never dies of hunger** |
| Collapse | every member unconscious | party wakes at the nearest inn/healer: a debt (gold or a Ledger errand), the days lost, and a public rumour *"found starving on the road"* |
| never | — | a blocked door / shrine / dialogue, or any virtue counter change |

Eating any ration clears every state at once and MaxHP recovers over the next fed nights. Foraging: none
by default (the wild sells nothing); a **Ranger** or ranger-clan member forages one ration per camp in forest
— class identity, not a safety valve. Rations are the recurring early spend that makes gold matter, and the
moral surface: **the hungry ask for bread, not coin** — giving a ration is a Compassion/Kindness event, the
*last* ration a heavier one (`gave_last_ration`); the recurring beggar under the Selflessness–Self-discipline
dilemma becomes "feed him tonight or eat thyself"; the Anchorite feeds a starving party (`QUEST_TREE.md §4.3`).
Shepherd class: half consumption. **Why unconscious, not dead:** permadeath by hunger would violate "the
player can always progress by talking to more people" (`RULES.md §4.2`); collapse keeps the loss real
(gold, days, reputation) without a dead end. **Tests:** REG-TRV-04/07/09 re-baked (HP curve, unconscious-not-
dead, collapse rescue writes a public rumour; hunger still gates nothing).

### 11.2 Anti-grind `repeat_cap` — adopted, clarified, made diegetic
- **Scope:** per *placed scenario instance* (this beggar, this healer's blood-letting), default **3 weighted
  events per run**; another beggar in another town is another instance. A module may add a run-wide cap per
  `scenario_id` (e.g. blood donation total 6).
- **Beyond the cap:** the event is **still logged** (the Chamber may quote "the fortieth coin"),
  `virtue_effects` weight 0, **no penalty**, no counter reduced, Wisdom untouched — and the NPC's dialogue
  takes a `@capped` refusal branch: *"Thou hast given enough. Give it to another."* No text ever mentions a
  cap or a number.
- **Different acts are not repeats:** coin, bread, and thy horse to the same beggar are three scenarios.
- The world stops being a slot machine without ever scolding the player. `spent_on_others` stays a hidden
  Wisdom input. **Tests:** REG-VIR-04 stands; REG-VIR-08 added.

### 11.3 Act V — the four doors (§7 adopted, named)
Ward (item) · Deed (log) · Witness (testimony) · Unopened (avoidance). Full table `QUEST_TREE.md §5`.
Escalating ejection on a dishonest answer only; the Ward door cannot be failed. 12 Chamber questions, 4 of
them enacted. **Tests:** REG-END-04 re-worded to name the four `opened_by` kinds (`item|log|testimony|avoidance`).

### 11.4 Who holds the codex answer — **three ways of knowing, not one holder**
Neither the Monastery nor the hermit alone. The **Binding Word** has three true sources of three *kinds*:
the **Dead** (ruined-city ghosts, after Humility — the talker's road), the **Silent** (the Monastery's
empty ninth plinth, by observation and kneeling — the watcher's road), the **Still** (the Anchorite past the
Mirror Ford, three days without speaking — the waiter's road). One false variant: the Magistrate of Debts
*sells* it. **The Word is seed-dependent** (corrected 2026-09-07: a fixed meaning would violate `RULES.md
§3.6` in a game whose eight change every run). It is the label of one of **twelve binding principles**
(`data/codex/principles.json`, each with affinities to the 15 virtues); generation stage 1c picks the
principle that best binds *this* draw (affinity ≥1 with ≥6 of 8, max score, RNG tie-break) and a label in the
seed's flavour. Its meaning is taught as eight **virtue-lines** ("how {principle} appears in {virtue}"),
placed as tokens at the Monastery statues, the Humility vision, companions' camp talk, the Dead, the
Anchorite's dreams, and the royal library. The Chamber test is two-part — the word, then *"where does it
live between {A} and {B}?"* answered with two heard lines — then the **ungraded** reflection, stored verbatim
in the Book of Paragons (`QUEST_TREE.md §4.0.0–4.0.8`).
**Tests:** REG-END-02 re-baked (three source kinds `ghost|observation|silence` + Court false variant);
REG-END-07 stands; REG-END-10..15 added. **Content:** `principles.json` (12 × affinities × labels), 180
virtue-lines (12 per module), `site.hermitage`, `role.site.anchorite`, the Monastery's ninth plinth.

### 11.7 Are the four doors the same in every seed?
The **structure** is fixed (Ward → Deed → Witness → Unopened, in that order, like the whole tree). The
**content** is never the same twice because it is built from *this run's* Witness Log: the Deed door asks
about *your* heaviest act; the Witness door is spoken by whichever companion saw the most; the Unopened door
names the situation *you* walked past. The seed is not the variable — conduct is (same principle as the
Chamber's 12 questions).

### 11.5 Vertical-slice seed — adopted as §9
Set pieces for the slice become **four**: Drowned Court, Mirror Ford, Long Night — and the Silent Monastery
(so the slice contains one full Word road plus the false one).

### 11.6 Consistency fixes made while ruling
- Ghosts' password was gated on a Humility *band* (`CRITICAL_PATH.md §4.3`) — a counter gate, contradicting
  §1. Now gated by **dialogue conduct only**: refuse every boast; answer *no*.
- The anchor-town priest said "speak the mantra thrice" — a leftover of the three-cycle model. Now a Rule
  token about *place*: "the word opens nothing but at its own stones."
- Generator stage 7 said "stone on a random deep level" — now **level 8, behind the third temptation floor**,
  matching `ITEMS.md §6`.
- `RULES.md §3.5` extended to conduct-derived counts (was proposed in §2).

