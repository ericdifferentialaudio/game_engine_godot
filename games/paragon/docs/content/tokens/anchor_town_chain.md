# Token Chain — The Anchor Town (`slot.1`) · Act I

The anchor virtue is `integrity` or `justice`. This sheet is written for **integrity**; the justice variant
swaps the honesty test for a fair-judgment test and is noted inline. Every mandatory token has **two true
sources in two locations**; one false variant exists with a refutation.

## 1. Roles present (fixed) — `role.town.*` unless noted

| role id | who | holds |
|---|---|---|
| `role.town.innkeeper` | runs the tavern; remembers everything | keyword ladder start; tavern standing; rumours |
| `role.town.mantra_keeper` | scholar/notary | **mantra** (source 1), behind honesty test |
| `role.town.shrine_pointer` | old fisher / shepherd | **shrine location** (source 1) |
| `role.town.sigil_hider` | child or widow | **sigil location** (source 1), indirectly |
| `role.town.honesty_tester` | blind reagent seller | integrity scenario; a **Rule token** ("the blind know weight") |
| `role.town.beggar` | at the gate | Care scenario; after 3 gifts: **shrine location** (source 2) |
| `role.town.signpost` | object | road to the royal seat |
| `role.town.drunk` | tavern | the **false shrine direction** |
| `role.town.priest` | chapel | **Rule token**: how meditation works (the right word at its own shrine — quick; wrong place, nothing); refutes the drunk |
| `role.town.smith` `role.town.baker` `role.town.guard` `role.town.miller` `role.town.tailor` `role.town.midwife` `role.town.boy` `role.town.widow` | flavor; each carries one Lore or Person token and one keyword bridge | |
| `role.royal.ruler` `role.royal.seer` `role.royal.librarian` | royal seat | **mantra** (source 2, the library); Rule tokens |
| `dream.first_camp` | first outdoor camp | **sigil location** (source 2), oblique |

## 2. Keyword ladder

```
innkeeper: JOB → "I keep the {inn}. Pilgrims ask me of the SHRINE; I send them to the old {shrine_pointer.job} by the water."
   └─ SHRINE → "…or ask the PRIEST what a shrine is for. Most don't."
shrine_pointer: SHRINE → "{dir:shrine:1} along the shore, half a day. Look for the standing stones."   [token.location.shrine.slot1 — TRUE #1]
   └─ MANTRA → "The word? Ask the one who WRITES for the town."
mantra_keeper: WRITES/MANTRA → honesty test → "The mantra of {virtue:1} is {token.mantra:slot.1}."   [token.mantra.slot1 — TRUE #1]
   └─ SIGIL → "There was a sigil-stone in the old chapel. The {sigil_hider.job} would know where it went."
sigil_hider (child): SIGIL → "I hid it where the cat sleeps. Cats sleep where it's warm."  → the bakery oven-ledge   [token.location.sigil.slot1 — TRUE #1]
beggar (after 3 gifts): "The stones by the sea. That's where they go to be quiet. {dir:shrine:1}."   [shrine — TRUE #2]
royal.librarian: MANTRA → "It is written here: '{token.mantra:slot.1}', in the book of {virtue:1}."   [mantra — TRUE #2]
dream.first_camp: "A cat asleep on warm brick. Under it, a mark."   [sigil — TRUE #2, oblique]
drunk: SHRINE → "Shrine? Up the hill, past the mill. Everyone knows."   [FALSE — refuted_by: priest, shrine_pointer, beggar]
priest: SHRINE → "Not the hill — that is the old watchtower. The shrine is by the water. And know this: the word opens nothing but at its own stones. Speak it there, and it is done."   [Rule token; refutation]
```

**Justice variant:** the mantra-keeper is the magistrate; the gate is a fair-judgment scene (two claimants to one
lost ring, `scenario.justice.two_claimants`) instead of the honesty test.

## 3. Honesty test (mantra gate) — `q.integrity.anchor_gate`

Mantra-keeper: "Before I give thee a word that opens a shrine — hast thou, since thou came through the gate,
taken anything that was not thine?"  Graded vs log (`kept_mistaken_change`, `keep_purse`, `pay_short`, town chests).
- Truthful *yes* → "Then thou knowest what the word costs. Here it is." `integrity +4` (costly honesty). Token given.
- Truthful *no* → token given. `integrity +1`.
- Lie → "So." Token **withheld**; the keeper never asks again; source #2 (library) remains. `integrity −3`.
- Refuse → "Come back when thou canst answer." Retry next day.

## 4. The first bar-fight seed (Act I)
In the anchor tavern on night 1 or 2: `quest.street.bar_fight` fires in its **mildest** form — two drunks,
no weapons, the innkeeper intervening if the player does nothing after 2 turns. Purpose: teach that taverns
are watched. Purses: one, 6 coin. Witness set as `SIDE_QUESTS.md §5`.

## 5. The general pattern every virtue town follows
| token | source 1 (in town) | source 2 (elsewhere) | false variant | refutation |
|---|---|---|---|---|
| mantra | keeper NPC behind a virtue-flavoured test | royal library / another town's scholar / shrine vision of a *different* shrine | market vendor sells a wrong syllable | keeper, or a companion whose virtue it is |
| shrine location | pointer NPC | beggar-after-gifts / sextant note in a book / dream | drunk / rival pilgrim | priest / sign / observation |
| sigil location | hider NPC (indirect) | dream / ghost / animal behaviour | none (sigils are never lied about — they are *hidden*, not disputed) | — |
Every town also carries: one **Rule** token (how something works), two **Lore** tokens (the fall of the ruin;
the moons), one **Person** token (where a companion or keeper is), and 3–5 **quest hooks**.
