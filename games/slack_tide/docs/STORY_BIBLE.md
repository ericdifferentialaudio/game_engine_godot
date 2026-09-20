# SLACK TIDE — Story Bible

Authoritative for **meaning**. `slack_tide_spec.json` stays authoritative for
ids, numbers and structure. Where this document implies a mechanic, the spec
implements it; where they disagree on a number, the spec wins.

All player-facing prose here is drafted and tagged `# NEEDS_HUMAN_WRITING`.

---

## 1. What the game is about

The tide has not turned in a month. The Sallow Reach organised its whole life
around a rhythm — wages, ferries, funerals, when you put bread in — and that
rhythm has stopped answering. This is not a disaster story. It is a story about
**what people do when the thing they trusted goes quiet.**

You are a deckhand. You are nobody. That is the engine: you are the only person
who talks to *everyone*, because everyone has to cross the river, and on the
water people say things they would not say on land.

The player's verb is not *fight* or *explore*. It is **find out** — and then
decide who is owed the truth.

---

## 2. The three reversals

One cause is true per seed. The rumours are identical across seeds; only the
truth moves. What lifts this above a whodunit: **in all three cases the truth
costs the player something they were counting on.**

### Seed A — The Held Gate  (`culprit=A`)

Doon Harrow holds the sluice shut. Her husband Lisle drowned in the Underworks
eleven months ago and was never recovered. When the tide stopped, the Choir
beneath the Weir began to sing — and it sings with his voice.

It is not him. She knows it is not him. She holds the gate anyway.

> "You'll tell me it isn't him. You'll be right. Go on and be right somewhere
> else." # NEEDS_HUMAN_WRITING

Turning the tide silences it forever. The player is correct and it does not
help. The **Bargain** road here is not a trade; it is talking a woman into a
second widowhood, and the game should not pretend that is a clever solution.

*Theme: being right is not the same as being good.*

### Seed B — The Long Cargo  (`culprit=B`)

The Tally House throttled the night sluice for one quarter to hold barge
freight and lift the rate. Routine. Signed off by a middle clerk, Corvin Ash,
who did not think it was interesting. The mechanism silted and jammed. By the
time anyone noticed, admitting it meant admitting everything — so nobody did.

Corvin is bailing out his own cellar. He has not slept. He will lie to your
face for eleven days, and then, if you hold `ev_b_paystub` at 75, he stops:

> "I moved a date. That's all I did. I moved a date two weeks."
> # NEEDS_HUMAN_WRITING

No monster. A signature. The **Word** road ends with a town discovering it
cannot punish anyone in proportion to the harm.

*Theme: catastrophe is usually administrative.*

### Seed C — The Name  (`culprit=C`)

Nobody did it. The Weir was raised four centuries ago by binding something into
the tide-gate and giving it a working-name so it could be commanded. It has
spent four hundred years listening to bell-ringers say that name. It has
finally understood the name is **its own** — and a thing that knows its own
name cannot be commanded, only asked.

Every culprit-rumour in seed C is a person the town needed to blame. The
player's investigative instinct is the trap: the better they are at building a
case, the more likely they are to ruin an innocent person on the way. The
**Word** road here is not an accusation. It is an introduction.

*Theme: the desire for someone to blame is itself the danger.*

---

## 3. The satchel — the whole game in miniature

**Day 2, midday crossing.** Warden-Courier **Lisle Harrow** collapses on your
deck and dies between the mooring and the slip. He leaves a sealed satchel
addressed to Captain Brack at Far Wend.

In every seed it contains something that would have stopped this, had it
arrived. **You are always already too late.** The first real choice lands
before the player understands any of the stakes:

| Choice | Cost | Gain |
|---|---|---|
| **Deliver intact** | You never learn what you carried. Ever. | fidelity +2; Skeleton Seal stays reachable |
| **Open it** | curiosity +1, fidelity -2, `seals_broken = 1`, Skeleton Seal forfeit | a seed-true token at reliability 70 **on day 2** - enormous |

And the sting, eight days later: **Doon Harrow is his widow.** The gated
mercy-5 endgame source is the wife of the man whose bag you did or did not
open. She asks. There is a `check` on candor. Lying to her works.

That is the thesis in one thread: **information has an owner, and the owner has
a face.**

---

## 4. The Ledger of What You Said

`spread` already exists in `slack_tide_boot.gd` (`record_sale`, `_sales`) and is
purely economic today. It becomes moral:

**Every token you sell enters the world's mouth.** From ~3 days after a sale,
NPCs quote it back as common knowledge - *including the false ones*. Sell a
rumour for 8 tallies on day 4 and on day 12 the Assize repeats it to you as
established fact, which you must now argue against with your own name on it.

This turns the information market from a shop into a consequence, at near-zero
implementation cost.

---

## 5. Voice

Dry, salt-worn, quietly funny, never grim for long. Working people with jobs.
Never gothic. The horror is administrative, or domestic, or both.

> "The tide has been out for eleven hours. Hesper says this is a mood."
> "Ma Cobb has three versions and sells all of them. She is not lying. She is
> hedging."
> "The Choir is beautiful, which is the worst thing about it."
> # NEEDS_HUMAN_WRITING

---

## 6. Endings - graded on understanding, not achievement

Two axes: **did you turn the tide**, and **did you know why**.

| | Understood the cause | Acted on a falsehood |
|---|---|---|
| **Tide turned** | *The Long Way Home* - the best ending | *The Cold Answer* - a win that reads as a loss |
| **Tide unturned** | *The Standing Water* - a loss that reads as grace | *Full Slack* - the failure ending |

Plus road-specific colourings (Word/Bargain/Hand) and the Doon variants, giving
the nine endings the design calls for. **Turning the tide while wrong is a
mechanical win and a narrative indictment** - that range is what the current
design lacks.

---

## 7. Cast notes that changed

- **Lisle Harrow** - was an inciting corpse. Now the spine: Doon's husband,
  drowned in the Underworks (seed A), the courier who dies on your deck
  (all seeds). His chart carries the Name (seed C).
- **Doon Harrow** - was a gated source. Now the widow, and the moral centre of
  seed A. Gate stays `s_doon_husband` + mercy 5; the *meaning* of that gate is
  now the satchel.
- **Corvin Ash** - was a liar to catch. Now a tired man who moved a date, and
  the proof that seed B has no villain.
- **The Sunken Choir** - was a monster. Now a voice, and in seed C a person.
