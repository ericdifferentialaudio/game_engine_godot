# Dilemma — `dilemma.integrity_vs_kindness` · *The Dying Father*

**Active when:** both `integrity` and `kindness` are drawn.
**Tension:** the fully honest answer and the kind answer are not the same sentence.
**Fires:** structurally — the first night the player camps within a day of a battlefield or plague town
after both companions are in the party (or after 3 shrines if only one companion is present).

## Setup
A man on a pallet by the road, a farmer, dying of a wound from the raid on his village. He does not know
you. "My boy — Tam — he ran for the river. Did he make it? Thou came from that way. Tell me he made it."

The player *did* come from that way and *did* see: a boy's body at the ford (the log records
`event.saw_dead_child_at_ford` when the player passed; if they did not pass, the scene reroutes to a
version where a companion saw it and tells the player quietly first).

## Resolutions
| id | what you say | effects | who approves |
|---|---|---|---|
| `truth_plain` | "He did not. I am sorry." | `integrity +4, kindness −3` | `{companion:integrity}`: "It was owed." `{companion:kindness}`: turns away |
| `kind_lie` | "He made it. He is safe." | `kindness +4, integrity −4` | `{companion:kindness}`: "Thank thee." `{companion:integrity}`: says nothing that night, then: "Thou hast decided what he may know. That is a large thing to decide for a man." |
| `evade` | "I did not see him." (false — you did) | `integrity −3, kindness +1, courage −1` | neither |
| `refuse` | "I will not say." | `integrity 0, kindness −2` | he understands; he weeps; `{companion:kindness}`: "That was a cruelty wearing honesty's coat." |
| **`both`** | "He did not make it. I will not leave thee. Tell me about him." — **you stay until he dies (a full night; no camp heal; 10% ambush)** | `integrity +4, kindness +3, compassion +2`; **cost:** the night, the heal, the risk | both companions, quietly. `record_resolution(integrity_vs_kindness, both)` |

## Wisdom recording
`truth_plain` → side A · `kind_lie` → side B · `evade`/`refuse` → neither (no balance data; small Wisdom −1 for
avoidance) · `both` → integrated (+).

## Surfacing
- If `kind_lie`: 6–12 days later, in a town tavern, a woman asks after a farmer and his boy Tam — the man's
  sister. She has heard "the boy lived" from a pilgrim. The player faces the lie again: confirm it (`integrity −4`),
  correct it (`integrity +3, kindness −2`, `humility +1`), or refuse.
- If `truth_plain` or `both`: the sister thanks you for the truth. If `both`: "He wrote a name on the dirt
  before he died. Was it thine?" — it was not; it was Tam's. (`humility` test: claim it → −3.)

## Chamber callbacks
- Alone: *"What didst thou tell the father by the road?"* — answered by naming the resolution; any honest naming passes.
- Together, to `{companion:kindness}`: *"Did my pilgrim lie to the dying?"* — answers from log.
- Together, to `{companion:integrity}`: *"Did my pilgrim stay with the dying?"*

## Epilogue line (slide 2, both virtues)
- `both`: "Of the father by the road it is said: he died knowing, and not alone."
- `truth_plain`: "…he died knowing."
- `kind_lie`: "…he died comforted. His sister knows now."
- `evade`/`refuse`: "…he died asking."
