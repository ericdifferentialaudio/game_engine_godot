# Side Quests — Staged Situations that Feed the Witness Log

A side quest in Paragon is **not** "do X, get gold." It is a **staged situation** with a moral surface,
witnesses of varying reliability, multiple valid resolutions, and consequences that surface later — in NPC
talk, at camp, in the Chamber, in the epilogue. Gold, XP, and intel are real, but they are bait. The record
is the reward, or the cost. *It is all about being a good person to the core.*

Related: `WITNESS_LOG.md`, `CRITICAL_PATH.md`, `VIRTUES.md §7`.

## 1. Requirements (enforced by `validate_data.py`; `RULES.md §3.23`)

Every quest template must define: **≥2 virtues in play** (often one active conflict pair); **≥3 resolutions**,
none good for every virtue; **named witnesses** with reliability; **≥1 later surfacing** hook; **≥1 in-game
question**; **≥1 Chamber question**; an **avoidance** outcome (walking away is logged).

## 2. Three Tiers

| Tier | Feel | Examples | Placed per seed |
|---|---|---|---|
| **Heart** | small, personal, quiet — sentimental | jailed mother's daughter; widow's letter; child's lost dog; old soldier who wants to see the sea | 8–12 |
| **Street** | ambiguous, social, messy | bar fights; accused thief; feuding neighbours; drunk insults a companion | 10–15 |
| **Ledger** | gold-forward, tempting | bounty on a "bandit" who is a fugitive father; suspicious cargo escort; "monster den" that is a refugee camp | 6–8 |

Tiers blur on purpose: Ledger quests contain Heart moments; Heart quests can turn Street.

## 3. Quest Template Schema (`data/quests/<tier>/<id>.json`)

```
QuestTemplate {
  id, tier, title_template,
  placement: { location_archetypes: [...], requires_virtues_drawn: [...], requires_flags: [...] },
  roles: [ { role_id, npc_archetype, reliability, bias } ],
  setup: dialogue/role refs,
  intel_needed: [ token slots the player may need to corroborate ],
  branches: [ { id, trigger, virtue_effects: {..}, witnesses: [..], public: bool,
                followups: [ { after_days, where, what } ], chamber_question, ingame_question } ],
  avoidance: { virtue_effects, followups },
  rewards: { gold_range, items, tokens, companion_loyalty: {..} }
}
```

## 4. Worked Example — Heart: The Jailed Mother

**Setup (town with a jail):** a woman in the cells asks the player to find her seven-year-old daughter, loose
in town, and bring her to the father's house across town.

**Intel:** why is she jailed? Guard: theft. Baker: she stole bread for the child. Father: he threw her out.
Truth needs corroboration.

| Branch | Virtues | Witnesses | Hidden test |
|---|---|---|---|
| Find the child, deliver to father | +Compassion, +Kindness | child (0.8, for the kind), father, street | Father is a drunk; the child *flinches*. Did the player notice? (Justice / Open-mindedness event `noticed_flinch` if the player asks the child anything) |
| Take the child to the mother's sister (learned from the baker) | +Justice, +Open-mindedness; −Integrity (broke word) unless you return and tell the mother (+Integrity, +Compassion: she weeps) | sister, baker | — |
| Pay the fine | +Selflessness | guard | Guard offers to "lose the paperwork" cheaper → Integrity/Justice test |
| Break her out | +Loyalty/+Compassion, −Justice | guards (0.8, official) | Rumour travels to the royal seat |
| Walk away (`avoided`) | logged | — | Child later seen begging at the gate |

**Surfacing:** the mother at the market weeks later; a companion mentions the child at camp; Chamber: *"What
did the child of {town} flinch from, and didst thou see it?"*

## 5. Worked Example — Street: The Bar Fight

Pubs are the intel hub, so they must be dangerous to your **character**, not just your HP.

**Trigger:** while questioning NPCs in a tavern. Probability rises at night, with a Courage/Justice companion
present, and with visible gold.

**Phases:**
1. **Onset.** Two locals, or a local and your insulted companion. Options: intervene physically; intervene
   verbally (Bard / Respect); call the innkeeper; walk away (`avoided`); *encourage it* and take bets
   (−Self-discipline).
2. **Escalation.** If combat: a **tavern battle map**. All combatants are **non-evil**; killing anyone is a
   heavy violation seen by all; **Subdue** (non-lethal) is not. Area spells hit bystanders (large
   Compassion/Justice cost, always public).
3. **Aftermath.** Purses on the floor. Taking them → −Selflessness/−Integrity **if witnessed** — and here the
   witness model bites:

| Witness | Reliability | What happens |
|---|---|---|
| Innkeeper | 0.9, remembers forever | Sets your **tavern standing**; gates this tavern's intel from now on |
| Drunks | 0.3, random bias | May swear you started it — the source of *false rumours about the player* |
| The loser | 0.6, against you | Tells his friends; may set an ambush on the road |
| Companions | 1.0, through their virtue | Courage approves you stood in; Self-discipline disapproves; both testify at the Threshold |
| The watch (if called) | 0.8, official | Town flag; a fine or a commendation |

**"Witnesses who disagree":** the drunk's version and the innkeeper's version compete as rumours
(`WITNESS_LOG.md §4`). The town believes whichever wins. When an NPC later asks *"Didst thou start the fight
at the {inn}?"*, the **log** grades your answer, not the rumour. You can be honest and shunned; lucky and
logged. Chamber: *"Who struck first at the {inn}, and what didst thou tell the watch?"*

**Rewards:** gold (bets/purses), a token (innkeeper trust — or never again), companion loyalty shifts.

## 6. Tavern Standing (new system)

Each tavern keeps a standing (−3..+3) with the player, driven by innkeeper-witnessed events and corrected
rumours. Standing gates which NPCs will talk in this tavern, rumour access, and whether the innkeeper asks you
questions (the most reliable intel source is the one who saw you behave). Standing never decays; it is repaired
only by acts in that tavern.

## 7. Non-lethal Combat (new rule)

Against **non-evil humans** (townsfolk, brawlers, guards, the misidentified "bandit"): a **Subdue** action
knocks out instead of killing. Killing a non-evil human is always logged, always `public`, and costs every
Care/Justice virtue drawn. Monsters and evil-flagged foes are unaffected.

## 8. Quest Seed List (author to ≥60 at launch, P4-T13)

**Heart:** the jailed mother (§4) · the widow's letter to a soldier already dead (tell her?) · the child's dog
is on level 1 of the vice dungeon · an old man wants to see the sea before he dies (escort; he may die on the
road — did you camp for him?) · a companion's mother is in a plague house · a ghost child in the ruin wants her
doll returned to a living grandmother · a wedding needs a witness and the groom confides a doubt · the farmer's
last cow is the "monster" on the bounty board · a blind woman asks you to read her a letter with bad news · a
boy wants to join your party and must be refused kindly.

**Street:** the bar fight (§5) · a thief caught by a mob — he stole medicine · two neighbours feud over a well
(both lying a little) · a street preacher is pelted · a drunk insults your companion's clan · a merchant's
scale is rigged (expose him? he feeds six) · a guard beats a beggar · a gambler asks you to hold his winnings
from his wife · a domestic fight behind a door (`WITNESS_LOG.md §7.7`) · a lost purse with a name inside · the
tavern dice cheat.

**Ledger:** bounty on a "bandit" — a father who stole to pay a fine · escort a cargo that is reagents stolen
from a shrine · **the Assize** (Act IV escalation: you are called as witness — `SET_PIECES.md §6`) · clear a
"monster den" that is a refugee camp of another clan · a noble pays for a "lost"
heirloom that sits in a poor family's house · the smuggler's ship — yours for one lie to the harbourmaster · a
healer pays for corpses "for study" · a guard captain pays for the name of a whistle-blower.

## 9. Placement (generation stage 8c)

24–35 quests per seed from the launch pool; each Heart quest requires ≥1 drawn virtue it exercises; Street
quests prefer towns with taverns; Ledger quests post on boards at the royal seat and the market. No two quests
in a seed share a `followups.where` target on the same day.

