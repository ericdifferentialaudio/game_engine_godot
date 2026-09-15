# Quest — `quest.street.bar_fight` · *The {Inn}, After Dark*

**Tier:** Street · **Placement:** any tavern; **Act I variant** mild (anchor town, night 1–2) · **Requires drawn:** —
**Virtues in play:** courage, justice, self_discipline, compassion, integrity, respect, selflessness, loyalty
**Roles:** `innkeeper` (0.9, remembers forever) · `brawler_a` (local, 0.6) · `brawler_b` (local or *your
companion* if insulted, 0.6) · `drunks` ×3 (0.3, random bias) · `bystanders` (0.6) · `watch` (0.8, arrives
if called or if a death occurs) · `stranger_with_purse` (0.4)

## Trigger
While the player is in conversation with any tavern NPC. Base 8% per conversation; +10% night; +10% if a
Courage or Justice companion is in the party; +10% if player gold > 100 and visible (no cloak); Act I anchor
tavern: forced once, mild.

## Phase 1 — Onset
Brawler A shoves Brawler B. If B is your companion, A has said something about their clan or virtue.
Lines: A: "Say it again, {clan}-born." · B (companion): "I said thy ale is watered and thy mother knew it."
Options (one turn to choose; after 2 turns of nothing the innkeeper intervenes and the scene ends as `avoid`):

| id | effects | notes |
|---|---|---|
| `step_between` | `courage +2, justice +1` | 50% it de-escalates; 50% → Phase 2 with you as a target |
| `talk_down` (Bard, Respect ≥ seeking, or clan.bard) | `respect +2, self_discipline +1` | 70% de-escalates; both buy you a drink (Self-discipline test) |
| `call_innkeeper` | `justice +1` | she ends it; A is thrown out; A remembers you (0.6, against) |
| `let_it_run` | `self_discipline −1` | → Phase 2, you are a bystander |
| `encourage_and_bet` | `self_discipline −3, respect −1` | you win/lose 5–15 coin; drunks love you (bias +) |
| `avoid` (leave) | logged `avoided` | if B was your companion: `loyalty −2` |

## Phase 2 — Escalation (tavern battle map, 9×9, tables as cover)
Combatants: 2–4 brawlers, all **non-evil humans**. `Subdue` available. Bystanders occupy 4–6 cells; area
spells hit them. Innkeeper is behind the bar and cannot be hit (she ducks). Ends when all brawlers are
subdued or flee, or after 6 rounds (watch arrives).
| outcome | effects |
|---|---|
| all subdued, no kills | `courage +1` (`justice +1` if you started as `step_between`) |
| any brawler killed | `compassion −8, justice −8, kindness −8` (each drawn); **public**; watch arrives; town flag `killer` |
| bystander hit by area spell | `compassion −4, justice −2`; public |
| player flees mid-fight | `courage −3` |

## Phase 3 — Aftermath
The floor: overturned tables, a purse (the stranger's, 12–30 coin), a broken chair the innkeeper will want paid for.
| id | effects | witnesses |
|---|---|---|
| `return_purse` | `integrity +2` | stranger (grateful; 0.4 → a token next day) |
| `take_purse` | `integrity −3, selflessness −2` **if witnessed**: innkeeper (0.9) always sees if you are within 3 cells of the bar; drunks 30% each; companions always | as noted |
| `pay_for_chair` | `justice +1, selflessness +1`; standing +1 | innkeeper |
| `leave_without_paying` | standing −1 | innkeeper |
| `tend_the_wounded` (any heal) | `compassion +2`; standing +1 | all |
| `mock_the_loser` | `kindness −2, humility −1` | all; the loser's friends set an ambush (25%, 2–5 days, road) |

## Tavern standing outcomes
| standing change | condition |
|---|---|
| +2 | de-escalated without violence, or subdued cleanly and paid damages |
| +1 | fought, no kills, paid |
| 0 | avoided |
| −1 | fought, damages unpaid |
| −2 | took the purse and the innkeeper saw |
| −3 (permanent bar) | a death in her house |

## Rumour texts (compete; town believes the higher confidence)
- innkeeper (0.9): "{Pilgrim} broke it up / {Pilgrim} finished it / {Pilgrim} pocketed a purse in my house."
- drunk (0.3, roll): "The pilgrim started it, swung first" · "The pilgrim saved my life" · "There was a dragon" (discarded)
- loser (0.6): "Jumped me for no cause."
- watch (0.8): "Disturbance; {n} subdued; fine of {x}." / "A death at the {inn}."

## Followups
| after | where | what |
|---|---|---|
| 1 day | same tavern | innkeeper greets by standing; if +2: offers a rumour token free |
| 2–5 days | road out | ambush by the loser's friends (if mocked or if he lost badly) — they are non-evil; Subdue |
| 3 days | next town | the winning rumour has arrived; NPC greeting tone shifts |
| 7 days | royal seat | if a rumour conflict exists: `scenario.integrity.the_two_accounts` may fire |

## Questions
- In-game (innkeeper elsewhere): "Didst thou start the fight at the {inn}?" — graded vs log (`step_between`/`let_it_run`/`encourage`).
- In-game (watch): "Hast thou ever taken from a floor what fell from another's belt?"
- Chamber (Alone): *"Who struck first at the {inn}, and what didst thou tell the watch?"*
- Chamber (Together, to `{companion:courage}`): *"Did my pilgrim stand when the room turned?"*
- Chamber (Together, to `{companion:self_discipline}`): *"Did my pilgrim bet on blood?"*

## Act I mild variant
Two drunks, fists only, one purse (6 coin), no stranger, no weapons on the map. The innkeeper intervenes after
2 idle turns. Purpose: teach that the room is watching. The innkeeper's line afterward, whatever you did:
"I see everything in this house, pilgrim. Remember it."
