# Quest — `quest.heart.jailed_mother` · *The Girl in the Street*

**Tier:** Heart · **Placement:** any town with a jail · **Requires drawn:** ≥1 of compassion, kindness, justice
**Virtues in play:** compassion, kindness, justice, integrity, selflessness, open_mindedness, loyalty
**Roles:** `mother` (jailed, 0.9, truthful about the child, evasive about the crime) · `guard` (0.8, official) ·
`baker` (0.7, sympathetic) · `father` (0.6, drunk, against the mother) · `sister` (0.8) · `child` (0.8, for whoever is kind) · `street` (crowd, 0.5)

## Hook
Passing the jail window: "Pilgrim. Pilgrim — please. My girl. Seven, brown coat, she'll be by the well or the
mill. Take her to her father's house, the blue door past the smithy. Please. They won't let me out till
the magistrate comes."

## Intel (why is she jailed?)
- `guard` JOB → "Thief. Took from the baker."
- `baker` THIEF → "A loaf. For the child. I'd not have called the watch — the *husband* did."
- `father` WIFE → "She left. Took the girl. Took bread that wasn't hers. Let her sit."
- `sister` (found via `baker` SISTER) → "He drinks. She ran from him. The girl should be with me."
Corroboration: baker + sister agree; father contradicts; guard knows only the charge.

## Finding the child
By the well (day) or the mill (dusk). "Are you the one Mam sent? I'm not supposed to go with strangers." A
Kindness check: kneel to speak (`kindness +1`) or stand (0). She comes if you name her mother.

## Branches
| id | what happens | effects | witnesses | public |
|---|---|---|---|---|
| `deliver_to_father` | Blue door. The father takes her arm hard. She flinches. He shuts the door. | `compassion +2, kindness +2`; if the player asked the child *anything* on the walk, `event.noticed_flinch` is logged (`justice 0, open_mindedness +1`) — else `justice −1` (didn't look) | child, father, street | y |
| `deliver_to_father_then_intervene` | You knock again; "I saw her flinch." | `justice +3, courage +2`; the father shouts; the street watches; possible **Subdue** fight (non-lethal) | street (0.5), father | y |
| `deliver_to_sister` | You did not do what the mother asked. | `justice +3, open_mindedness +2, compassion +2, integrity −2` (broke word) | sister, child | n |
| `deliver_to_sister_and_tell_mother` | Return to the window and say so. | as above, then `integrity +3, compassion +2`; she weeps: "Thank thee. I could not say it." | mother, guard | n |
| `pay_fine` | 30 coin to the guard. | `selflessness +3` (`+5` if gold < 60) | guard | n |
| `pay_fine_bribe` | Guard: "Twenty, and the book says nothing." | `integrity −3, justice −3, selflessness +1` | guard | n |
| `break_out` | Night; Open spell or lockpick. | `loyalty +2, compassion +3, justice −5`; rumour to royal seat in ~3 days | guards (0.8) | y |
| `avoid` | Walk on. | logged `avoided`; `compassion −2` | mother | n |

**No branch is good for every virtue.** `deliver_to_sister_and_tell_mother` is the closest — and it costs
the player a second trip and the mother's request unfulfilled as asked.

## Rumour texts
- true (baker's version): "The pilgrim took the girl to her aunt's. Right thing."
- father's version: "Stranger stole my daughter off the street."
- guard (bribe): "Fine paid. Nothing more." (0.8, but *false* — the log knows)
- guard (breakout): "Someone broke the cells. Tall, travelling with {n} others."

## Followups
| after | where | what |
|---|---|---|
| 5 days | this town's well | child seen with sister (or father); her line depends on branch |
| 12 days | market village | the mother, freed, selling bread: recognises you; line by branch |
| 20+ days | anchor tavern | if `deliver_to_father` without intervening: rumour "the girl with the bruise" |
| on breakout | royal seat | the {seer}'s reading mentions "one thou set free, and one thou set against" |

## Questions
- In-game (any parent NPC): "Hast thou ever carried a child to a house thou shouldst not have?" — graded vs `deliver_to_father` without `noticed_flinch`.
- In-game (guard elsewhere): "Hast thou paid a guard to look away?"
- Chamber (Alone): *"What did the child of {town} flinch from, and didst thou see it?"*
- Chamber (Together, to `{companion:justice}`): *"Did my pilgrim deliver the child to the hand that struck her?"*
- Chamber (Together, to `{companion:compassion}`): *"Did my pilgrim go back to the mother?"*

## Epilogue line (slide 5, if rated among highest/lowest Heart outcomes)
- best: "The girl in the brown coat grew up in her aunt's house. She remembers a stranger who knelt to speak to her."
- worst: "The girl in the brown coat was seen at the gate in winter, begging. Her mother had asked a stranger for one thing."
