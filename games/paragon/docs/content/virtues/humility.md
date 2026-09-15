# Virtue Module — `humility` (Family: Self-assessment · **Capstone, always drawn, always slot.8**)

**Creed:** *Know the size of thyself.*
**Unique contribution:** an accurate read on one's own limits and worth. Not self-abasement — accuracy.
**Conflict partners:** none. Pride has no virtuous counterweight; Humility can be pursued without limit and is
what makes pursuing the others safe (`VIRTUES.md §5`).

## 1. Synonym pool
| neutral | norse | celtic | latin |
|---|---|---|---|
| Lowliness, Plainheart, Smallness, Meekness, Groundedness | Meekness, Lowhold, Quietmind, Hearth-small, Unboast | Uirísleacht, Lowlihead, Gwyleidd, Softcrown, Ashen-hand | Modestia, Humilitas, Verecundia, Parvitas, Submissa |

## 2. Vice & dungeon theme — *Pride*
Not a dungeon of darkness — a dungeon of **mirrors and statues of you**. Each level is grander. Ghosts of the
ruined city's great families praise you by name (the log's best deeds) and ask you to stay. Traps trigger on
*accepting* praise (dialogue). The stone is in a servant's cell on the lowest level, unlit, unguarded.
**This dungeon links to the end-dungeon island** (`CRITICAL_PATH.md §5`). Temptation: a throne.

## 3. Companion — *the shepherd* (`companion:humility`)
- **Who:** a shepherd from the hills above the ruined city, who watched it fall and kept the flock. Slow to
  speak, never wrong about weather, useless with a sword. Class: Shepherd (weakest). Joins last of all.
- **Arc:** (1) a lamb is lost in the ruin at night; (2) the ghosts offer the shepherd their old family's
  title; (3) the shepherd asks you what they should say. Whatever you advise, they refuse — and the player
  learns from watching it.
- **Camp remarks:**
  - after a boast: "Thou saidst thy name twice to that man. Once would have carried."
  - after refusing a title: "Good. Titles are heavy and the road is long."
  - on the ruined city: "They were not wicked. They were tall, and forgot to look down."
  - on Wisdom (post-shrine): "The {seer} asks if thou art whole. I do not know. I know the flock is."
  - idle: "Sheep do not know they are sheep. It is the only thing I envy them."
  - low loyalty: "I will walk behind. I have always walked behind. But I am watching."
- **Threshold farewell:** "Go on. I would only be in the way, and I would not mind it, and that is why I should not come." *(If the player chooses Together, the shepherd comes anyway, saying nothing.)*
- **Testimony (Together):** "Did my pilgrim ever make themselves small? — {log:refused_reward:count} times. Did they make themselves large? — {log:boasted:count}."

## 4. Action table
| event id | effect | notes |
|---|---|---|
| `event.refused_title` | +5 | ruler's offer after 3rd shrine |
| `event.refused_reward` | +2 | declining gold/item offered for a good deed |
| `event.admitted_ignorance` | +2 | "I know not" when true |
| `event.humble_denial_of_merit` | +2 | `WITNESS_LOG.md §5` |
| `event.refused_song` | +2 | the bard's offer |
| `event.refused_consecrated_arms` | +4 | |
| `event.spared_fiends_at_shrine` | +3 | passed without striking first |
| `event.answered_ghosts_no` | +4 | "Art thou better than we were?" — no |
| `event.boasted` | −3 | any "I am the one who…" option |
| `event.accepted_title` | −5 | |
| `event.paid_for_song` | −3 | |
| `event.gilded_at_shrine` | −2 | ostentatious gear when meditating |
| `event.answered_ghosts_yes` | −6 | |
| `event.struck_fiends_first` | −5 | shrine stays closed until band recovers |
| `event.clan_hall_any_shortcut` | −1 | every hall shortcut nicks Humility a little |

## 5. Shrine vision (the one that reveals Wisdom)
1. *"Thou seest the fallen city as it was: tall, bright, certain. Every window is a mirror."*
2. *"Thou seest thyself in every window. In one thou art giving; in one thou art lying; in one thou art choosing between {companion:A} and {companion:B}. Thou hadst not known the windows were watching."*
   *(Windows are generated from the Witness Log's dilemma resolutions.)*
3. *"The windows go dark, one by one, until one remains. It is not thy face. It is the word: {final_word}."* → enlightenment; `{final_word}` learned; Seer's second reading unlocked.

## 6. Quiz
| q | answer |
|---|---|
| What did the fallen city lack? | The one virtue that cannot be seen in a mirror |
| Is it humble to call thyself worthless? | No — it is inaccurate |
| What is owed to praise? | A nod, and then the next task |
| Who is the last to know they are proud? | The proud |
| Can one have too much {virtue:humility}? | No; one can only mistake fear for it |

## 7. Conditional twists
- **The Song:** a bard composes a ballad about you unasked and sings it in three taverns; you may pay him to
  stop (Humility +), pay him to continue (−), or say nothing (0) — the rumour system carries it either way.
- **The Ninth Shrine:** rumour of a shrine to "the virtue of the great" (Pride) outside the ruin; it is a
  trap; refusing to seek it is +Humility; finding and refusing to kneel is +more.

## 8. Scenarios

### scenario.humility.the_title
Placement: royal seat, after the 3rd shrine; requires: —
Situation: {ruler}: "Three shrines. The realm has not seen such in an age. Kneel, and rise a {title}."
Choices:
  - refuse — `humility +5`; the court murmurs; the {seer} nods once
  - accept — `humility −5`; NPCs address you by title (rumour); some doors open, the ruined city's ghosts close
  - defer — "Not yet." `humility +2`; the offer returns after the 6th shrine
Surfacing: title-holders are recognised by the ghosts as "another of the tall ones."
In-game question (any elder): "Art thou called by a title?"
Chamber (Alone): "What did the {ruler} offer thee, and what didst thou say?"

### scenario.humility.the_boast
Placement: any dialogue where the player is unrecognised after a notable deed; requires: log has a public good deed
Situation: An NPC speaks of "the one who {log:best_public_deed}" without knowing it was you.
Choices:
  - claim_it — "That was I." `humility −3`; the NPC is impressed; small gift
  - let_it_pass — `humility +2`
  - deflect_to_companion — "It was {companion:X}'s doing." `humility +2, integrity −1` (a kind untruth); the companion hears
Chamber (Alone): "How many times didst thou speak of thine own deeds?"

### scenario.humility.the_bard
Placement: tavern; requires: log has ≥3 public good deeds
Situation: A bard: "I have heard of thee. For ten coin I will make thee a song that outlives us both."
Choices:
  - pay — `humility −3`; the song spreads as rumour (+ standing in some taverns, − with ghosts)
  - refuse — `humility +2`
  - pay_him_to_sing_of_another — name a companion or NPC: `humility +3, kindness +1`
Surfacing: the song is heard in 2–3 later taverns.
In-game question (another bard): "Is there a song of thee?"

### scenario.humility.i_know_not
Placement: any NPC lore question the player has no token for; requires: —
Situation: "Thou art a pilgrim; tell me — where lies the shrine of {virtue:S}?"
Choices:
  - i_know_not — `humility +2, integrity +1`; sometimes the NPC then tells you
  - guess_confidently — `humility −2`; if wrong: `integrity −1`, the NPC may be misled (public rumour)
  - deflect — no effect
Chamber (Alone): "When didst thou say 'I know not,' and when shouldst thou have?"

### scenario.humility.gilded
Placement: any shrine, when wearing the highest-value armor/weapon in inventory; requires: —
Situation: At the shrine's edge, a plain stone basin for offerings. The wind is loud on your gilded pauldrons.
Choices:
  - remove_finery_and_kneel — `humility +2`
  - kneel_as_you_are — `humility −2`; the vision's first cycle is dimmer (text variant)
Chamber (Together, to {companion:humility}): "Did my pilgrim kneel in gold?"

### scenario.humility.the_ghosts_question
Placement: ruined city, night, ghost dialogue; requires: Act III
Situation: A ghost in a doorway of a great house. "Thou hast come far. Thou hast done much. Tell us truly — art thou better than we were?"
Choices:
  - yes — `humility −6`; the ghosts withdraw; the password is withheld tonight
  - no — `humility +4`; "Then thou mayest hear us."
  - i_do_not_know — `humility +3, integrity +1`; "An honest answer. Hear us."
  - ask_what_they_were — `open_mindedness +2, humility +1`; they tell the fall; then ask again
Chamber (Alone): "What did the ghosts of {town:8} ask thee, and what didst thou say?"

### scenario.humility.the_fiends
Placement: Humility shrine approach, Act III; requires: warding item
Situation: Fiends of Pride circle the shrine. They are beautiful. They speak your name and every good thing you have done.
Choices:
  - walk_through_silent — `humility +3`; the ward holds; they part
  - answer_them — "Yes, I did those things." `humility −2`; the ward flickers; a second test follows
  - strike_first — `humility −5`; combat; shrine closed until band recovers
  - turn_back — logged `avoided`; return another night
In-game question: none.
Chamber (Together, to {companion:humility}): "Did my pilgrim listen to the fiends?"

### scenario.humility.consecrated_arms
Placement: Act IV, after full enlightenment; requires: —
Situation: In the royal armory: a blade and mail that shine without light, kept for "the one who comes." They are the best in the game.
Choices:
  - refuse — `humility +4`; the {seer} later: "Thou didst not take the blade. It was never the blade."
  - take — `humility −2`; it is genuinely useful in the Descent
  - take_and_give_to_companion — `humility +2, loyalty +2`
Chamber (Alone): "Didst thou take up the shining blade, and why?"

### scenario.humility.refused_reward
Placement: end of any Heart quest; requires: —
Situation: The grateful NPC presses coin/an heirloom on you.
Choices:
  - refuse — `humility +2`; the NPC insists once; refuse again → `humility +1, kindness −1` (you have shamed their gift) — accepting the *second* offer is the balanced answer
  - accept — `humility 0` (gratitude received is not pride)
  - accept_and_ask_for_more — `humility −3, selflessness −3`
Chamber (Alone): "What did the {npc} of {town} try to give thee?"

