# Set Pieces — Late-Game Scenarios Common to Every Seed

Eleven authored situations that give Acts II (late), IV, and V their texture. Each is a different **kind of
test**; names and geography are seeded, the structure is not. All feed the Witness Log.

Related: `CRITICAL_PATH.md`, `WITNESS_LOG.md`, `SIDE_QUESTS.md`, `PROCEDURAL_GENERATION.md §2` (stage 4).

## 0. What each one tests

| Test | Set piece | Act |
|---|---|---|
| Lawlessness | 1. The Drowned Court | II–IV |
| Knowledge, not force | 2. The Bell in the Deep · 7. The Silent Monastery | IV |
| Force at sea, made moral | 3. The Corsair Fleet | II–IV |
| Hazard as door | 4. The Maelstrom Gate | II–IV |
| Freedom with rules | 5. The Wind-Ship | III–IV |
| Witness | 6. The Assize · 8. The Mirror Ford · 10. The Long Night | IV–V |
| Cost | 9. The Debtor's Isle · the Magistrate's debt (1) | IV |
| Stillness | 11. The Hermitage (the Anchorite) | IV |
| The dead / Guardianship / Connection / Temptation / Understanding | ruined city · Humility shrine · Sigil Ring · `{temptation}` · the Chamber | see `CRITICAL_PATH.md` |

---

## 1. The Drowned Court  (`set.drowned_court`) — *the moral market*
**Where:** a half-sunk smuggler city on stilts in a tidal marsh on the **strait to the Houses**; reachable by
ship at **low tide only** (`{moon_dest}` full or new).
**Who:** the **Magistrate of Debts** (0.9, truthful — that is the danger), harbourmaster, debt-clerks, the
sold, the buyers, a child who counts boats.
**Holds:** one Word-of-Passage syllable; one House password; three true tokens no one else has; a ship (if
the player has none) for a price.
**Mechanic:** every true token is priced in **favours**, each a Witness-Log event with the court watching:

| favour | virtue cost | what it really is |
|---|---|---|
| carry a sealed letter to a House | integrity −2 (open it: −3 more, +justice if you then act) | a threat |
| swear before the harbourmaster that a cargo is grain | integrity −4 | it is people |
| stand "witness" while a debtor is sold | justice −4, compassion −3 | complicity |
| collect a debt from the beggars' hamlet | compassion −4, kindness −3 | cruelty |

**The `both`:** pay the Magistrate's *own* debt (near everything the player owns) → all debtors freed, all
tokens given, the court emptied. `selflessness +8, justice +5`; Wisdom integrated. The Descent has no shops;
this is meant to hurt.
**Twist hook:** the Bell's ledger (§2) names the Magistrate as the man who sank the ship.
**Chamber:** *"What didst thou trade at the court on stilts?"* · Together, `{companion:justice}`: *"Did my pilgrim stand witness to a sale?"*

## 2. The Bell in the Deep  (`set.bell_in_the_deep`) — *the sunken artifact*
**Where:** a wreck in open sea; coordinates from **three sources** (a fisher's song, a House chart, the
Court's clerk) — two agree; the third is the false variant.
**Needs:** ship, calm sea (moon), a **diver**. Companions volunteer by virtue: Courage insists; Self-discipline
says wait a tide; Compassion fears for whoever goes. The choice is logged; the diver's loyalty moves by outcome
(30% drowning risk if the sea is not calm).
**Holds:** a family artifact; the drowned crew's **ledger** (Lore token naming the Magistrate; refutes the
Court's account of the wreck).
**Chamber:** *"Whom didst thou send into the deep?"*

## 3. The Corsair Fleet  (`set.corsair_fleet`) — *force at sea*
**Where:** three ships working the strait. Each captain has a name, a crew, a reason (debt to the Court; a
stolen daughter; plain greed).
**Mechanic:** ship combat → boarding → **deck battle map** with `Subdue`. Subduing yields the ship *and* the
captain alive, who begs, bargains, or curses. Sinking is faster, kills all, and is **public** (fishers, 0.6).
**Twist (fixed):** one "pirate" is the realm's **navy in disguise**, testing pilgrims for Justice. Learned only
by sparing its captain: "Thou hast passed a test thou didst not know thou wert set." `justice +4`. Sinking it
is discovered at the royal seat in 3 days: `justice −6`, public.
**Chamber:** Together, `{companion:courage}`: *"Did my pilgrim board, or burn?"*

## 4. The Maelstrom Gate  (`set.maelstrom`) — *hazard as door*
**Where:** a whirlpool in the inner sea. Ships that enter are wrecked; the party is deposited alive on the
shore of the **hidden lake**, home of a House keeper or a Word keeper.
**Mechanic:** entering is `courage +3` **if the player holds the token that says the maelstrom is a door** (a
fisher's tale; a chart note). Entering without it is logged `reckless`: Wisdom −2; the shepherd: "Brave is
when thou knowest." No way out but the Wind-Ship (§5) or a conjunction gate.
**Chamber:** *"Didst thou know the whirlpool was a door before thou sailed into it?"*

## 5. The Wind-Ship  (`set.wind_ship`) — *freedom with rules*
**Where:** the upper hall of the **Pride dungeon** (slot.8).
**Gate — soft with a hard floor:** will not lift unless the party's Humility band ≥ *seeking* (25). Below:
you sit in the basket, nothing happens, `{companion:humility}`: "It knows." Above the floor **speed scales
with band** (seeking ×1, worthy ×1.5, enlightened ×2). At worthy+ the Seer later remarks how lightly you
travel. The Title (−5) alone can never drop a player below the floor.
**Mechanic:** wind-driven; `{moon_gate}` phase → wind direction. The only way to the **conjunction sites**
and out of the hidden lake.
**Chamber:** none — the ship is the question.

## 6. The Assize  (`set.assize`) — *the trial*
**Where:** the royal seat, Act IV. `{ruler}` convenes it when the log contains any of: a pardoned thief, a
sheltered fugitive, a bar-fight with disputed rumours, a spared Corsair captain.
**Mechanic:** the player is called as **witness**. The court has *rumours*; the player has the *log*.

| testimony | effects |
|---|---|
| true, against yourself | integrity +5, humility +2, courage +2; a fine or penance |
| true, for yourself | integrity +2 |
| false | integrity −6, justice −4; a companion who witnessed the event **objects aloud** (loyalty −3) |
| refuse | courage −2; the accused is judged on rumour alone |

The accused's fate follows the verdict (followup, 10 days). This is the Witness Log's mid-game payoff and
the rehearsal for the Chamber.
**Chamber:** *"Whom didst thou condemn with thy word, and whom didst thou spare?"*

## 7. The Silent Monastery  (`set.silent_monastery`) — *intel by observation*
**Where:** adjacent to one House. An order under a vow of silence holds one Word syllable.
**Mechanic:** **no dialogue**. The token assembles from observation events: which bell rings at which moon
phase; which monk bows to which of eight statues (the seed's virtues); what is left on the altar at dawn.
Three observations on three visits → the syllable. Speaking to a monk is `respect −1` (they turn away).
Reverence/Open-mindedness flavoured; works without either drawn.
**The ninth plinth** (`QUEST_TREE.md §4.2`): the statue hall holds the eight statues and an **empty ninth
plinth**. **Each statue bears its virtue's line for this seed's principle** (`codex.line.slot.N`, readable
by examining — no dialogue). At dawn the abbot bows to each of the eight and last, longest, to the empty one
(`saw_abbot_bow_ninth`). A player who has seen this may **kneel** at the plinth; the **Binding Word** is cut
into the step beneath the kneeler, readable only from there. Kneeling before watching reveals nothing.
This is the *watcher's road* to the Word — one of three — and the only place all eight lines stand together.
**Chamber:** *"What did the silent ones teach thee, and how?"*

## 8. The Mirror Ford  (`set.mirror_ford`) — *the party is tested*
**Where:** the river crossing on the approach to the end-dungeon island. Fixed.
**Mechanic:** each companion is met by a **figure from their own arc** (the oath-keeper's ruined family; the
healer's bitter patient; the shepherd's lost lamb; …). Each must decide; the player may **advise** with one
line from three — their virtue's answer, its conflict partner's answer, "It is thine to choose" — or stay
silent. The companion's resolution goes to *their* loyalty and to *your* Wisdom (advising the partner's
answer is integrated if accepted; imposing is Loyalty without Humility).
**Companions at "lost" loyalty fail their figure and refuse to cross.** The player may go on without them
(Together is then impossible for those companions) or spend a day making amends (a final loyalty scenario).
**Chamber:** Together, to each: *"At the ford, what did my pilgrim tell me?"*

## 9. The Debtor's Isle  (`set.debtors_isle`) — *the cost*
**Where:** a prison-colony island **beyond the Drowned Court** for the insolvent — half sent by the Magistrate.
Holds the stone of the Giving/Justice-family vice dungeon the seed maps there, or a Word keeper if none.
**Mechanic:** the colony needs the player's gold more than the player does. Give **everything**
(`selflessness +8`) → the warden gives the stone with thanks. Give some (`+3`) → the stone must be *bought*
from the sick at their price. Give nothing → take it from a dying man's hand (`compassion −6, justice −4`,
public). The Descent has no shops.
**Chamber:** *"What did the Isle cost thee, and who paid?"*

## 10. The Long Night  (`set.long_night`) — *Act V, Level 0* — **fixed, every seed**
**Where:** the shore of the end-dungeon island, the night before the Descent. Camp is forced. No ambush.
**Beats:**
1. **Each companion asks one question** they have carried about you (from the log: the event they most
   disapproved of, or never understood). Answer (graded honest / evasive / lie) or say nothing. Silence is
   logged, not punished.
2. **The Seer appears** — the only time they leave the royal seat. Final reading: eight verdicts, then the
   Wisdom band in one sentence.
3. **Dawn.** *"Who goes down?"* — **Alone** or **Together** (`CRITICAL_PATH.md §6.2`). The choice is made
   here, with the companions' questions still in the air. At the Threshold only the farewells remain.
**Chamber:** answers given in the Long Night are eligible questions in both paths.

## 11. The Hermitage  (`site.hermitage`) — *the still* — **fixed, every seed**
**Where:** a day's walk upriver on the **far bank of the Mirror Ford** (§8) — the party has already been
tested before it arrives. A cell, a spring, a fire, one old figure.
**Who:** the **Anchorite** (`role.site.anchorite`) — not the Reverence companion, not the Seer in disguise
(twist 14 may *not* bind here). Speaks exactly twice in the whole game.
**Mechanic:** on arrival: *"The word is not told. It is what is left when talking stops. Stay, if thou
canst."* The party must remain **three nights** with **no `talk` action by anyone** and without leaving the
cell. Each night's dream restages one of the player's own dilemmas from the other side and closes on one
virtue-line for this seed's principle (three lines in three nights — `codex.line` tokens). Any word spoken or
step outside resets the count (*"Thou hast spoken. Begin again."* — the Anchorite's only other line, reused).
On the third dawn the Anchorite speaks the **Binding Word** and never speaks again.
**Food:** three nights consume rations; a party that arrives with none is fed (`fed_by_anchorite`, logged —
the only Kindness scenario done *to* the player).
**Cost:** three days. Followups may lapse; a Commitment trial may expire; moons turn. Self-discipline /
Reverence flavoured; works without either drawn. This is the *waiter's road* to the Word — one of three.
**Refutation:** the Anchorite is a refuting source for the Court's false word: *"That is what the Magistrate
sells. He has never been below."*
**Chamber:** *"Three days thou wert silent. What did thy own voice say when it had no one to say it to?"*

---

## Placement (generation stage 4 additions)
- Drowned Court on the strait between the anchor region and the Houses; Debtor's Isle beyond it.
- Corsair Fleet patrols that strait; the navy ship is the one nearest the royal seat.
- Bell wreck in open sea within a day's sail of the Court.
- Maelstrom in the inner sea; hidden lake village beside a House or a Word keeper.
- Silent Monastery adjacent to one House (never the Humility-linked region).
- Mirror Ford on the only land approach to the end-island ferry; the Long Night shore is fixed.
- Hermitage one day upriver on the far bank of the Mirror Ford (reachable only by crossing it).
- Wind-Ship always in the Pride dungeon's upper hall (Act III+).
- The Drowned Court's costliest favour always carries the **false** Binding Word (`QUEST_TREE.md §4.4`).

## Rules
- All eleven exist in every seed; none may be skipped by data (`RULES.md §3.27`).
- The three Word sources (ghosts / ninth plinth / Anchorite) are of three different kinds and none may be
  removed or merged by data (`RULES.md §3.28`).
- Every set piece has ≥1 integrated (`both`) path that costs something real.
- The Wind-Ship floor is Humility ≥ 25 and is not tunable per seed.
- The Long Night is the only place the Alone/Together choice is offered.

