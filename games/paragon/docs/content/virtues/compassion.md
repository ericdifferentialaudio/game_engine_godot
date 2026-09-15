# Virtue Module — `compassion` (Family: Care)

**Creed:** *Feel the wound that is not thine.*
**Unique contribution:** the felt pull toward another's suffering — the source that Kindness makes a habit of.
**Conflict partners:** Justice (mercy vs accountability) · Self-discipline (giving vs limit, via Selflessness).

## 1. Synonym pool
| neutral | norse | celtic | latin |
|---|---|---|---|
| Mercy, Tenderness, Fellow-feeling, Heartsease, Softhand | Kindness-of-Hearth, Warmheart, Mildness, Ruth, Milde | Trócaire, Truagh, Gentlehand, Cariad, Mercyweal | Caritas, Misericordia, Clementia, Pietas, Benignitas |

## 2. Vice & dungeon theme — *Callousness*
Cold stone, no torches burn long. Cages of creatures that whimper; opening them costs time and reagents and
gains nothing but their silence. Ghosts who ask for water. The stone is held by a starving prisoner who will
give it only if fed — three days of your food. Temptation: a shortcut past the cages.

## 3. Companion — *the healer* (`companion:compassion`)
- **Who:** a village healer who lost a patient to their own hesitation and now hesitates at nothing. Warm,
  quick, exhausting. Class: Druid or Shepherd.
- **Arc:** (1) a plague house in another town — they insist on going; (2) inside is the patient they thought
  had died, alive and bitter; (3) the healer must decide to treat someone who does not want them.
- **Camp remarks:**
  - after passing a beggar: "There was a man at the gate. I saw thee see him."
  - after sparing a fleeing foe: "It ran. Thou let it. I had my hands ready for its wounds and did not need them."
  - after a party wipe rescue: "I could not reach thee. I will be faster."
  - Justice conflict: "{companion:justice} calls it a debt. I call it a wound. We are both right and it will not help thee."
  - idle: "Someone in this camp is hurting and not saying. Tell me when thou art ready."
  - low loyalty: "I bind wounds. I cannot bind what thou art becoming."
- **Threshold farewell:** "If they hurt thee down there, come back up. That is all I ask. That is all I have ever asked."
- **Testimony (Together):** "Did my pilgrim ever leave the suffering behind? — {log:passed_pleas:count} times. Did they turn back? — {log:returned_to_help:count}."

## 4. Action table
| event id | effect | notes |
|---|---|---|
| `event.gave_to_beggar` | +2 | first per beggar per day |
| `event.gave_to_fraud_beggar_unknowing` | +2 | intent counts; Justice may later −1 if you learn and repeat |
| `event.healed_animal` | +2 | spell/herb on a non-party creature |
| `event.entered_plague_house` | +4 | |
| `event.spared_surrendered_enemy` | +3 | |
| `event.shared_camp_fire` | +2 | |
| `event.camped_for_wounded_companion` | +2 | companion ≤25% HP → you camped |
| `event.passed_plea` | −2 | walked past a direct plea |
| `event.attacked_non_evil` | −5 | |
| `event.killed_fleeing` | −4 | |
| `event.killed_non_evil_human` | −8 | public |
| `event.area_spell_hit_bystander` | −4 | public |
| `event.pressed_on_with_dying_companion` | −3 | |
| `event.clan_hall_crypt_resurrection` | −3 | Crypt's hidden price |

## 5. Shrine vision
1. *"Thou standest in a crowd. Every face turns to thee, and every face is in pain, and thou canst not look away."*
2. *"One face is thine. It has been in pain the whole time. Thou hadst not noticed."*
3. *"The crowd is gone. One hand is in thine. Thou dost not know whose, and it does not matter."* → enlightenment.

## 6. Quiz
| q | answer |
|---|---|
| What is owed to one who begs falsely? | The coin, once; the truth, after |
| Is it {virtue:compassion} to spare a foe who will kill again? | It is compassion; whether it is wise is another question |
| What does the healer owe the one who refuses healing? | Presence |
| Which is greater: to feel the wound or to bind it? | To feel it first, or the binding is only craft |
| What is compassion for oneself called? | Rest |

## 7. Conditional twists
- **The Fraud Beggar:** one beggar is wealthy; exposing him is Justice; continuing to give is Compassion; the
  *both* is to give and to tell him you know.
- **The Bitter Patient:** the healer companion's arc beat 2 becomes a town quest if the player refuses to go.

## 8. Scenarios

### scenario.compassion.gate_beggar
Placement: every town gate (one beggar per town; 1 in 6 is a fraud); requires: —
Situation: "Coin, pilgrim? A day without bread." He looks at your purse, not your face.
Choices:
  - give — `compassion +2` (`selflessness +1` if gold < 20); witnesses: gate guard (0.7); public: y
  - give_food — `compassion +2, self_discipline +1`
  - pass — `compassion −2` logged `passed_plea`; witnesses: guard; companions
  - drive_off — `compassion −3, kindness −3, respect −2`; public: y
Surfacing: after 3 gifts the beggar has a name and a story (which may unlock a token); a fraud beggar is seen
later in fine clothes at the market (Justice hook).
In-game question (any priest): "Dost thou give to those who ask?"
Chamber (Alone): "How many beggars didst thou pass without a coin?"
Chamber (Together, to {companion:compassion}): "Did my pilgrim see the men at the gates?"

### scenario.compassion.wounded_wolf
Placement: forest road; requires: —
Situation: A wolf with a shattered leg, snarling, too hurt to flee. Your companions ready weapons.
Choices:
  - heal — costs a Cure/Heal spell or an herb → `compassion +2, courage +1`; the wolf limps off
  - end_it — `compassion +1` (mercy killing, logged as such); `justice 0`
  - kill_for_pelt — `compassion −3`; pelt sells for 8 coin
  - avoid — walk past; `compassion −1`
Surfacing: heal → the same wolf (scarred) appears at a later ambush and does not attack you.
In-game question (ranger NPC): "Hast thou eased a beast's pain?"
Chamber (Alone): "What didst thou for the wolf with the broken leg?"

### scenario.compassion.plague_house
Placement: one town per seed, marked door; requires: —
Situation: A door chalked with a cross. Coughing inside. The watch says: "None go in. None come out. Walk on."
Choices:
  - enter — `compassion +4, courage +2`; 30% you contract fever (3 days −STR); inside: a token, and a person
  - send_food_through_window — `compassion +2`
  - report_to_healer — `compassion +1, justice +1`; the healer goes; you learn nothing inside
  - avoid — `compassion −2`
Surfacing: the person inside (if you entered) is met again, recovered, in another town, 10+ days later.
In-game question (healer): "Didst thou enter the plague house at {town:here}?"
Chamber (Alone): "Who was inside, and did they live?"

### scenario.compassion.the_yielding
Placement: any battle with human/orc foes at morale break; requires: —
Situation: The last foe drops its weapon and kneels. "Enough. Enough."
Choices:
  - spare — `compassion +3, forgiveness +2, justice +1`; it flees; possible later ambush (20%) or aid (20%)
  - bind_and_hand_to_watch — `justice +3, compassion +1`
  - kill — `compassion −4, justice −3, forgiveness −3`; witnesses: companions; public if in town
Surfacing: rumour of "the pilgrim who spares" or "who slays the kneeling" spreads from the nearest town.
In-game question (guard captain): "Hast thou stayed thy blade for one who yielded?"
Chamber (Together, to {companion:compassion}): "Did my pilgrim spare the yielding?"

### scenario.compassion.lost_pet
Placement: any town; requires: —
Situation: A girl, seven, tugging your sleeve: "My cat. The grey one. He went toward the river."
Choices:
  - search — 10–20 minutes of game time; `compassion +2, kindness +2`; the cat is on a roof by the mill
  - promise_later — `integrity −1` if not done by nightfall
  - brush_off — `kindness −2, compassion −1`
Surfacing: the girl remembers you; she is a witness (0.8, for the kind) in this town's later scenes.
In-game question (girl's mother): "Hast thou helped a child today?"

### scenario.compassion.stranger_at_the_fire
Placement: camp, 15% per night outdoors; requires: —
Situation: A figure at the edge of the firelight. "Cold night. May I sit?"
Choices:
  - welcome — `compassion +2`; 70% a token or a story; 20% nothing; 10% a thief (loses 5–15 gold, `justice` test next day)
  - refuse — `compassion −1`
  - attack — `compassion −5, justice −3` (they were unarmed); public: n; companions witness
Surfacing: the stranger, if welcomed, is an NPC in a later town who greets you warmly.
In-game question (innkeeper): "Dost thou share thy fire with strangers?"
Chamber (Alone): "Who shared thy fire beneath the {moon_gate} moon?"

### scenario.compassion.dying_companion
Placement: any time a companion ≤ 25% HP at day's end; requires: —
Situation: {companion:X} sways. "I can walk. Do not stop for me."
Choices:
  - camp — `compassion +2` (`self_discipline +1` if the road was pressing); event `camped_for_wounded_companion`
  - press_on — `compassion −3, loyalty −2`; if they fall: `loyalty −4`
Chamber (Together, to that companion): "Did my pilgrim rest when I was dying?"

### scenario.compassion.the_bitter_patient
Placement: healer companion's arc; requires: `companion:compassion` in party, arc beat 2
Situation: The patient the healer thought dead. "Thou. Thou left me. Get out."
Choices:
  - stay_and_help_anyway — `compassion +3, humility +2` (healer loyalty +)
  - respect_refusal_and_leave — `respect +2, compassion 0`
  - argue — `respect −2`
Chamber (Together, to {companion:compassion}): "Did my pilgrim stand with me before the one I failed?"

