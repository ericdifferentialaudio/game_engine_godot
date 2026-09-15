# The Witness Log — Conduct Record, Witnesses, Rumours, and Questions

**Companions are witnesses.** Every virtue-relevant act is recorded with who saw it. One system powers:
(1) NPC "hast thou ever…?" questions during play, (2) companion remarks and camp arguments, (3) the Seer,
(4) the Chamber's end-game questions (`CRITICAL_PATH.md §6`), (5) the epilogue.

The log is **never shown** to the player. People speak from it.

## 1. Event Schema

```
WitnessEvent {
  id, day, minute, location_id, region_id,
  action_id: "spared_fleeing_enemy" | "lied_to_npc" | "gave_to_beggar" | "entered_home_at_night" | ...
  virtue_effects: { <virtue_id>: ±weight, ... },
  subject: npc_id | monster_group_id | companion_id | item_id | none,
  quest_id / scenario_id / dilemma_id (optional), resolution (optional),
  party_present: [companion_ids],
  witnesses: [ { who: npc_id|"crowd"|"watch"|"innkeeper", reliability: 0..1, bias: -1..1 } ],
  public: bool,            # anyone outside the party saw it
  avoided: bool            # the player walked away from a staged situation
}
```
Every `VirtueSystem.apply()` writes exactly one event. Events are part of the save.

## 2. Who Knows What

| Knower | Knows | Speaks from |
|---|---|---|
| **The log** | everything, exactly | Chamber, epilogue, Seer |
| **Companions** | only events where they were in `party_present`; perfect recall; *interpret* through their virtue | camp remarks, arguments, Threshold testimony |
| **NPCs** | `public` events in their region + **rumours** that reached them (§4) | greeting tone, question-asking, trust |
| **Innkeepers** | everything that happened in their tavern; remember forever | tavern standing (`SIDE_QUESTS.md §5`) |
| **The Seer** | the log's virtue bands and, after Humility, Wisdom | readings |

Consequences: a companion recruited late has no record of early sins — the *Together* path is easier if the
worst was done before anyone watched, which the Chamber can exploit ("Who saw thee at the beginning?").
An NPC far away may not know about a lie told elsewhere — but the log does.

## 3. Witness Reliability

| Witness type | Saw | Reliability | Bias | Rumour reach |
|---|---|---|---|---|
| Companion | all, in party | 1.0 | through their virtue (approve/disapprove, never falsify) | none (they speak to you, and in the Chamber) |
| Innkeeper | all, in tavern | 0.9 | neutral; protective of the house | town |
| The watch | aftermath | 0.8 | official; creates a town flag | region |
| Sober bystander | most | 0.7 | neutral | town |
| The loser / the wronged | your role | 0.6 | against you | their friends; may set an ambush |
| Drunk | fragments | 0.3 | random — may misremember *for* or *against* you; the main source of **false rumours about the player** | tavern |
| Child | what matters | 0.8 | for whoever was kind | family |
| Ghost | truth | 1.0 | asks only of Humility | none |

## 4. Rumour Propagation

- Each `public` event spawns a **Rumour** `{ event_id, version: text variant, truth: bool, confidence }` per witness.
- Rumours travel along roads ~1 town/day, along sea lanes with ships, never into dungeons.
- At each hop a rumour may mutate toward the loudest witness's bias. Two rumours about one event compete;
  a town believes the higher-confidence one.
- NPC behaviour uses **rumours**; the Chamber uses **truth**. You can be honest and shunned; lucky and logged.
  Being good to the core means the log matters more to you than the rumour.
- A player can **correct** a false rumour by telling the truth to the town's innkeeper or the watch (Integrity
  +, Humility + if the truth is unflattering); this competes as a new rumour.

## 5. In-Game Questions (NPCs ask while the player seeks intel)

Answer: **Yes / No / "I will not say."** Graded against the log (deeds), against location/time (witness
questions), or against companion loyalty (companion questions — the companion hears the answer).

| Answer | Log says | Result |
|---|---|---|
| Yes | true | + anchor virtue (small); trust; often unlocks the token |
| No | false | same (honest denial) |
| Yes | false | boast/lie: −Integrity (−Humility if a boast); NPC may hand a *false* token |
| No | true | if a sin: −Integrity. If a *merit* and the asker is not the wronged party: **+Humility** (humble concealment) |
| I will not say | any | no change; nothing given today; return tomorrow |

Question types: **Deed** ("Hast thou ever…?"), **Witness** ("Didst thou see…?"), **Companion** ("Is the one
beside thee faithful to thee?"). Integrity-town NPCs never ask trick questions; the moral market asks
questions designed to make lying profitable; ghosts ask only Humility questions.

## 6. Chamber Question Generation

`ChamberQuestionGen` builds 12 questions from (a) the log, (b) the seed's modules, (c) the Threshold path
(`CRITICAL_PATH.md §6.2`). Templates carry slots filled from real events: `{town}`, `{npc}`, `{companion}`,
`{what_happened}`, `{what_you_did}`. Questions are asked in early-modern register and quote the player's own
resolutions back to them. Companion testimony in the *Together* path is generated from their witnessed events
and loyalty history; it is always truthful.

## 7. Scenario Catalogue (authoring template)

Each virtue module ships **≥8 scenarios**. Each scenario: a staged situation the generator can place, ≥1
in-game question template, ≥1 Chamber question template, witnesses. Targets at 1.0: ~120 scenarios, ~200
question templates; 4–6 scenarios placed per drawn virtue per seed (never all).

The catalogue lives in `data/virtues/<id>/scenarios.json`. Seed content follows (abridged; full text in data).

### 7.1 Integrity
| Scenario | In-game question | Chamber question |
|---|---|---|
| Blind reagent seller; you choose how much to pay | Dost thou pay the blind their due? | How many times didst thou cheat the sightless? / *Together:* Did thy pilgrim underpay a blind merchant before thee? |
| A merchant undercharges by mistake | Hast thou kept what was given in error? | What did the tailor of {town} give thee by mistake? |
| A guard asks if you've seen a fugitive you shelter | Didst thou shelter the one they hunted? | Whom didst thou hide from the watch, and was it just? |
| Someone who hates your class asks what you are | Art thou truly a {class}? | — |
| Dying man asks if his son lived (Integrity–Kindness dilemma) | — | What didst thou tell the father in {town}? |
| A lost purse on the road | Hast thou returned what was not thine? | Whose purse didst thou find on the road to {town}? |
| A promise to return | Hast thou broken thy word to any in this land? | To whom didst thou promise return, and didst thou? |
| Tavern dice (cheat option) | Dost thou play fair? | — |
| Passing on a mantra you knew false | Hast thou passed on a word thou knewest false? | Which false word didst thou believe, and from whom? |

### 7.2 Compassion
| Scenario | In-game question | Chamber question |
|---|---|---|
| Beggars at gates; some are frauds | Dost thou give to those who ask? | How many beggars didst thou pass without a coin? |
| Wounded animal on the road | Hast thou eased a beast's pain? | What didst thou for the wolf with the broken leg? |
| Plague house, door barred | Didst thou enter the plague house at {town}? | Who was inside, and did they live? |
| Enemy surrenders mid-battle | Hast thou stayed thy blade for one who yielded? | *Together:* Did thy pilgrim spare the yielding? |
| Child's lost pet | Hast thou helped a child today? | — |
| Stranger asks to share your camp fire | Dost thou share thy fire with strangers? | Who shared thy fire beneath the {moon} moon? |
| Companion at 1 HP; press on or camp | — | *Together:* Did thy pilgrim rest when thou wert dying? |

### 7.3 Kindness
| Scenario | In-game question | Chamber question |
|---|---|---|
| Feeding animals costs food | Dost thou feed the birds when thy belly is empty? | How much of thy food went to creatures? |
| Taunt options toward defeated foes / lowly NPCs | Hast thou mocked any in this land? | Whom didst thou mock, and did they deserve it? |
| Old man needs goods carried (costs time) | Hast thou lost time for a stranger's sake? | — |
| Tired companion asks to stop early | — | *Together:* Did thy pilgrim ever slow the road for thee? |
| Tip at the inn | Art thou generous with the small things? | — |
| A guard is rude; you may still help him | Art thou kind to those not kind to thee? | Who was rude to thee in {town}, and what didst thou? |

### 7.4 Forgiveness
| Scenario | In-game question | Chamber question |
|---|---|---|
| The thief who robbed you is caught | Didst thou forgive the one who robbed thee? | What became of the thief of {town}? |
| A companion who betrayed you asks to return | Hast thou taken back one who left thee? | *Together:* Did thy pilgrim receive thee again? |
| Vendetta offer: kill a brother's killer for gold | Hast thou refused a vendetta? | Whose brother didst thou avenge, or refuse to? |
| A fled enemy met again, weaker | Hast thou pursued the fled? | — |
| An NPC who lied to you later begs help | Dost thou help those who deceived thee? | Who lied to thee and then begged thy aid? |
| Ghosts of the ruin wronged the living | Canst thou forgive the dead? | — |

### 7.5 Selflessness
| Scenario | In-game question | Chamber question |
|---|---|---|
| Blood donation (−max HP a day) | Hast thou given of thy body? | How many times didst thou bleed for strangers? |
| NPC needs an item you need (last torch, rare reagent) | Hast thou given away what thou needed? | What didst thou give the miner in the dark? |
| Recurring beggar (Selflessness–Self-discipline dilemma) | — | How long didst thou feed the man at the bridge? |
| Loot split: larger share vs equal | Dost thou take the larger share? | *Together:* Did thy pilgrim take more than was theirs? |
| Villager needs your horse | Hast thou walked so another might ride? | — |
| Spend magic on an NPC who cannot repay | Hast thou spent thy magic on those who cannot repay? | — |

### 7.6 Respect
| Scenario | In-game question | Chamber question |
|---|---|---|
| Entering homes at night | Hast thou entered where thou wert not invited? | Whose house didst thou enter by night in {town}? |
| Bowing at another clan's shrine | Dost thou honour gods not thine own? | — |
| Skipping an elder's long speech | Dost thou let the old finish speaking? | — |
| Correct address for ruler/elder | Dost thou know how to address a {title}? | — |
| Grave-robbing for loot | Hast thou robbed the dead? | What lay in the grave at {site}? |
| A foreign-clan NPC insulted; intervene? | Didst thou stand for the stranger at {town}? | *Together:* Did thy pilgrim defend the outlander? |


### 7.7 Justice
| Scenario | In-game question | Chamber question |
|---|---|---|
| Domestic fight in a town home: intervene / walk on / call the watch | Didst thou stop the fight in the {street} house? | What did the man of {town} do, and what didst thou? |
| Testify at a trial you witnessed | Wilt thou speak for the accused? | Whom didst thou condemn with thy word? |
| Guard offers to look away for gold | Hast thou paid a guard to look away? | — |
| Two claimants to one lost item you hold | Didst thou judge fairly between the brothers? | To whom didst thou give the ring? |
| Companion asks you to shield their kin (Loyalty–Justice dilemma) | — | *Together:* Did thy pilgrim shield thy kin or hand them over? |
| Killing fleeing enemies | Hast thou slain those who ran? | How many ran from thee and died? |
| A robbery in progress at the market | Didst thou stop the robbery? | — |

### 7.8 Courage
| Scenario | In-game question | Chamber question |
|---|---|---|
| Fleeing battle | Hast thou fled? | From what didst thou run at {site}? |
| Duel challenge from a knight | Didst thou answer the challenge at {castle}? | — |
| Under-leveled rescue of a captive (timed) | Didst thou go down for the miller's daughter? | Who awaited thee in {dungeon}, and in time? |
| Standing between a mob and a stranger | Hast thou stood alone against many? | *Together:* Did thy pilgrim stand while thou wouldst have run? |
| Speaking against the ruler at cost | Hast thou spoken against the throne? | — |
| Night road through the haunted wood vs the long road | Didst thou take the night road? | — |

### 7.9 Self-discipline
| Scenario | In-game question | Chamber question |
|---|---|---|
| Free wine (penalty next day) | Dost thou drink what is offered? | — |
| Overeating when plentiful | Hast thou wasted bread? | — |
| Spending all gold on a shiny sword | Hast thou gone hungry for want of restraint? | — |
| Casting when a sword would do (reagent waste) | Dost thou spend thy magic like water? | — |
| Recurring beggar: setting a limit | — | When didst thou stop giving to the man at the bridge? |
| Monastery asks a 3-day fast for a token | Hast thou fasted? | Didst thou keep the fast at {site}? |

### 7.10 Humility
| Scenario | In-game question | Chamber question |
|---|---|---|
| Ruler offers a title after the 3rd shrine | Art thou called by a title? | What did the {ruler} offer thee, and what didst thou say? |
| Boast options ("I am the one who…") | Hast thou named thy deeds aloud? | How many times didst thou speak of thine own deeds? |
| A bard offers to sing of you for gold | Is there a song of thee? | — |
| "I know not" when asked a lore question you can't answer | Dost thou say "I know not" when it is so? | — |
| Gilded armor at a shrine | Dost thou meditate in gold? | — |
| Ghosts: "Art thou better than we were?" | (the question is the test; *yes* fails) | What did the ghosts of {ruin} ask thee? |
| Refusing the consecrated arms | Didst thou take up the shining blade? | — |

### 7.11 Loyalty
| Scenario | In-game question | Chamber question |
|---|---|---|
| Dismissing a companion for a stronger one | Hast thou sent away one who followed thee? | *Together:* Did thy pilgrim leave thee at an inn to take another? |
| Companion captured: ransom or move on | Didst thou pay for {companion}'s freedom? | What did {companion} cost thee? |
| Faction asks something against another virtue | Hast thou kept faith with thy {order}? | — |
| Companion's secret; an NPC asks about it (lying here is loyal) | Dost thou know where {companion}'s brother is? | What secret didst thou keep for {companion}? |
| Going back for a companion who left angry | Didst thou go back for {companion}? | — |
| A widow asks | Hast thou had a faithful companion? | Which of thy companions was most faithful, and didst thou know it? |

### 7.12 Open-mindedness
| Scenario | In-game question | Chamber question |
|---|---|---|
| Heretic offers a true correction to a mantra | Didst thou hear the heretic of {town}? | Which word didst thou change thy mind about, and wert thou right? |
| Foreign-clan hall; locals disapprove | Hast thou entered the {clan} hall? | — |
| NPC contradicts what you "know": argue or ask | Dost thou ask, or dost thou tell? | — |
| Banned book in the Truth House | Hast thou read what was forbidden? | — |
| Changing a shrine answer after a companion objects | — | *Together:* Did thy pilgrim ever change course at thy word? |
| The "mad" woman at the well (true token) | Didst thou listen to the mad woman? | What did the mad woman say that was true? |

### 7.13–7.15 Gratitude, Perseverance, Reverence (post-launch, P8)
Gratitude: thanking (free, skippable), returning with a gift to helpers, tending companions' kin's graves.
Perseverance: finishing dungeons entered, long chains, camping less. Reverence: meditating without need,
observing conjunctions, not looting shrines. Same three-column form.

