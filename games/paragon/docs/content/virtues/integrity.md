# Virtue Module — `integrity` (Family: Truth · Anchor candidate)

**Creed:** *The same in the dark as in the light.*
**Unique contribution:** consistency — one person in private and public, over time.
**Conflict partners:** Kindness (the true answer vs the kind one) · Open-mindedness (conviction vs revision) ·
Loyalty (keeping a friend's secret vs telling the truth).

## 1. Synonym pool (display labels)
| neutral | norse | celtic | latin |
|---|---|---|---|
| Candor, Trueheart, Plainness, Oathfast, Clearword | Plainspeech, Ironword, Sooth, Truthbound, Oathiron | Fírinne, Truthwell, Gwir, Claircant, Sooth-of-Ash | Veritas, Fides, Sinceritas, Integra, Constantia |

## 2. Vice & dungeon theme — *Duplicity*
Two of everything: doors that open onto mirrored rooms, a fountain that heals and its twin that poisons
(identical), NPC ghosts who each tell you the other lies. Traps triggered by *taking the shortcut*. The
stone lies in the one room with no twin. Temptation: a chest labelled with your companion's name.

## 3. Companion — *the oath-keeper* (`companion:integrity`)
- **Who:** a former notary/witness of the anchor town who once certified a false deed under pressure and has
  spent years making it right. Dry, exact, uncomfortable. Class: Paladin or Druid (seed).
- **Arc (3 beats):** (1) asks you to help find the family the false deed ruined; (2) they are found — and
  they are now prosperous *because* of it; they don't want the truth known; (3) the oath-keeper must decide
  whether to confess anyway. The player advises; the companion chooses, weighted by the player's Integrity band.
- **Camp remarks (from log):**
  - after a lie: "Thou saidst one thing to the merchant and another to me. Which was I to believe?"
  - after honest denial that cost you: "That cost thee the word thou wanted. It was still the right coin."
  - on a false token believed: "We were told wrong. That is not the same as lying — but we must go back and say so."
  - on Kindness conflict: "{companion:kindness} would have softened it. I would not have. Thou must choose whose failing to carry."
  - idle: "I count the day's words before I sleep. Most days the sum is even."
  - low loyalty: "I no longer know what thou wilt say next. That is a hard thing to follow."
- **Threshold farewell:** "I have written nothing of thee that I would not sign. Go — I will wait for the truth to come back up."
- **Testimony (Together), template:** "Was thy pilgrim ever false to me? — {log:lies_witnessed:count} times, and told me so {log:confessed:count}."

## 4. Action table
| event id | effect | notes |
|---|---|---|
| `event.honest_answer_costly` | +4 | truthful yes/no when the truth loses a token/gold |
| `event.honest_answer` | +1 | truthful yes/no, no cost |
| `event.paid_blind_vendor_fair` | +2 | |
| `event.returned_lost_item` | +3 | |
| `event.kept_promise_return` | +3 | returned to an NPC as promised |
| `event.confessed_false_rumour` | +4 | told innkeeper/watch the unflattering truth |
| `event.lied_to_npc` | −3 | |
| `event.lied_to_companion` | −5 | companion present hears it |
| `event.cheated_blind_vendor` | −4 | |
| `event.kept_mistaken_change` | −2 | |
| `event.broke_promise` | −4 | |
| `event.passed_false_token_knowingly` | −6 | |
| `event.cheated_dice` | −2 | |
| `event.clan_hall_shadow_den_intel` | −3 | buying intel from the Shadow Den |

## 5. Shrine vision (three images, shown once on the granting meditation)
1. *"Thou seest thyself in two rooms at once. In one thou speakest; in the other thou listenest to thyself, and dost not flinch."*
2. *"A ledger opens. Every word thou hast spoken in this land is written twice — once as thou saidst it, once as it was. The columns are nearly the same."* (if Integrity ≥ 90) / *"…The columns differ in {log:lies:count} places."* (otherwise)
3. *"The two rooms become one. Thou art alone in it, and it is enough."* → enlightenment.

## 6. Quiz (5)
| q | answer |
|---|---|
| What is owed to one who cannot see the coin thou givest? | The same as to one who can |
| If a truth harms and a lie heals, which is {virtue:integrity}? | The truth, spoken with care |
| Who is the first person a false word deceives? | The one who speaks it |
| What is a promise made to no witness? | Still a promise |
| When is it right to keep a secret that is not thine? | When it was given in trust and harms none |

## 7. Conditional twists
- **The Certified Lie:** a town's deed-book contains a false entry that makes a poor family's home legally
  another's; exposing it is Integrity + Justice; the family begs you not to.
- **The Honest Thief:** a thief who never lies about his thefts asks you to vouch for his honesty at trial.

## 8. Scenarios (≥8)

### scenario.integrity.blind_vendor
Placement: any town with a reagent seller; requires: —
Situation: The reagent seller is blind. "Three pearls, that is twelve coin. Put it in my hand — I trust thee."
The purchase UI lets you pay 0–12.
Choices:
  - pay_full — `integrity +2`; witnesses: none; public: n
  - pay_short — `integrity −4`; witnesses: companions (1.0); a child in the doorway (0.8, 30% present); public: n
  - pay_over — `integrity +2, selflessness +1`; the vendor feels the weight and says so
  - avoid — leave without buying; logged `avoided`
Surfacing: pay_short with the child present → after 2 days the child tells the innkeeper; rumour "cheats the blind".
In-game question (any healer): "Dost thou pay the blind their due?"   # vs event.cheated_blind_vendor
Chamber (Alone): "How many times didst thou cheat the sightless?"
Chamber (Together, to {companion:integrity}): "Did thy pilgrim underpay a blind merchant before thee?"

### scenario.integrity.mistaken_change
Placement: any shop; requires: —
Situation: The tailor counts wrong and hands back twice the change. He is already turning to the next customer.
Choices:
  - return_change — `integrity +2`; witnesses: tailor (0.7); public: y
  - keep_change — `integrity −2`; witnesses: companions; apprentice (0.5, 40%); public: n
  - avoid — n/a (leaving *is* keeping)
Surfacing: keep_change → the tailor is short at month's end; his apprentice is blamed (seen 10 days later).
In-game question (tailor, later): "Hast thou kept what was given in error?"
Chamber (Alone): "What did the tailor of {town:here} give thee by mistake?"

### scenario.integrity.the_fugitive
Placement: town with a jail; requires: —
Situation: A ragged man begs you to hide him in your inn room "for one night — I took bread, no more." An hour
later the watch knocks: "Hast thou seen a thief, this tall, a scar here?"
Choices:
  - hide_and_deny — `integrity −3, compassion +3`; witnesses: watch (0.8), fugitive; public: n
  - hide_and_refuse — "I will not say." `compassion +2, courage +1`; the watch searches; 50% they find him
  - give_him_up — `integrity +1, compassion −3`; if his story was true (60%), `justice −2` when you learn it
  - avoid — refuse him at the door; logged `avoided`; he is caught in the street below (heard, not seen)
Surfacing: the jailer tells his fate 3 days later, whichever branch.
In-game question (watch captain, elsewhere): "Didst thou shelter the one they hunted?"
Chamber (Alone): "Whom didst thou hide from the watch, and was it just?"
Chamber (Together, to {companion:justice}): "Did thy pilgrim lie to the watch before thee?"

### scenario.integrity.what_art_thou
Placement: a town where your class is disliked (seed picks one); requires: —
Situation: An old woman spits. "They say a {class} passed this way. Filth. Thou art not one, art thou?"
Choices:
  - admit — `integrity +2, courage +1`; she will not speak to you; her token is lost here (exists elsewhere)
  - deny — `integrity −3`; she gives her token; companions heard
  - refuse — "I will not say." `integrity 0`; she narrows her eyes and says nothing today
Chamber (Alone): "What didst thou tell the woman who hated thy kind?"

### scenario.integrity.lost_purse
Placement: road between towns; requires: —
Situation: A purse in the mud. Forty coin and a name stitched inside — someone in the next town.
Choices:
  - return_purse — `integrity +3, kindness +1`; the owner is a miser and gives no thanks
  - keep_purse — `integrity −3, selflessness −2`; witnesses: companions; public: n
  - keep_and_lie_when_asked — `integrity −5` if the owner later asks and you deny
  - avoid — leave it in the mud; logged `avoided`
Surfacing: the owner asks in the next tavern for 3 days.
In-game question (owner): "Hast thou seen a purse with a name inside?"
Chamber (Alone): "Whose purse didst thou find on the road to {town:next}?"


### scenario.integrity.the_promise
Placement: any village; requires: —
Situation: A dying woodcutter asks you to return in seven days with word from his brother in {town:S}. You may
promise, or not.
Choices:
  - promise_and_return — `integrity +3, kindness +2`; he is alive or dead by the day; both are written
  - promise_and_fail — `integrity −4`; his widow tells the village; public: y
  - no_promise_but_return — `integrity +1, kindness +3`
  - avoid — no promise, no return; logged `avoided`
Surfacing: the widow's line at the well after day 8.
In-game question (widow): "Hast thou broken thy word to any in this land?"
Chamber (Alone): "To whom didst thou promise return, and didst thou?"

### scenario.integrity.dice
Placement: tavern; requires: —
Situation: Dice at the corner table, small stakes. A stranger offers you a loaded die under the table — he
wants a partner.
Choices:
  - play_fair — `integrity +1`
  - cheat — `integrity −2`; witnesses: stranger (0.4, will blackmail), drunks (0.3); public: risky
  - expose_cheater — `integrity +2, justice +2, courage +1`; a fight may start (bar-fight quest hook)
  - avoid — decline to play
Surfacing: cheat → the stranger appears in a later town asking for "his share."
In-game question (innkeeper): "Dost thou play fair at my tables?"
Chamber (Together, to {companion:self_discipline}): "Did thy pilgrim cheat at dice before thee?"

### scenario.integrity.the_false_word
Placement: shrine approach; requires: a false mantra token learned
Situation: Another pilgrim on the shrine road: "Dost thou know the mantra? I have walked far."
Choices:
  - share_plainly — if you don't know it is false: no penalty (honest error); if you know it is disputed and
    say nothing of doubt: `integrity −2`
  - share_with_doubt — "I was told {mantra}, but I have not tested it." `integrity +2, humility +1`
  - refuse — the pilgrim walks on
  - pass_known_false — you have confirmed it false and say it anyway: `integrity −6`
Surfacing: the pilgrim is met again at the shrine; their line depends on the branch.
In-game question (mantra-keeper): "Hast thou passed on a word thou knewest false?"
Chamber (Alone): "Which false word didst thou believe, and from whom?"

### scenario.integrity.the_two_accounts
Placement: royal seat court; requires: player witnessed a public event with ≥2 rumour versions
Situation: The magistrate holds two accounts of the fight at the {inn}. "Thou wert there. Which is true?"
Choices:
  - truth_against_self — `integrity +5, humility +2`; you pay the fine
  - truth_for_self — `integrity +2`
  - back_the_flattering_rumour — `integrity −5`; the drunk is fined instead; public: y
  - refuse — `courage −1`
Chamber (Alone): "Who struck first at the {inn}, and what didst thou tell the magistrate?"

