# Virtues — Catalogue, Draw Rules, Wisdom, and Conflict Pairs

Paragon has a **pool of 15 drawable virtues**. Each seed draws **8** (with constraints) plus the ever-present
meta-virtue **Wisdom**, which is never drawn, never has a shrine, and is never displayed.

Related: `GAME_DESIGN.md §5`, `PROCEDURAL_GENERATION.md §2` (stage 1b), `NAMING_AND_LORE.md`, `CLANS.md`.

## 1. Structure

| Layer | Count | Role |
|---|---|---|
| **Wisdom** (meta-virtue) | 1, always present | Judgment: how well the player balances virtues that conflict. Measured, not practiced. |
| **Humility** (capstone) | 1, always drawn | The corrective: keeps achievement from becoming pride. Always the last-gated shrine. |
| **Anchor** | 1 of {Integrity, Justice}, always drawn | Grounds the honesty-test and fair-dealing mechanics. |
| **Drawn virtues** | 6 of the remaining 12 | Randomized per seed with family and conflict constraints (§4). |

Intelligence is a **stat** (`INT`: capacity to learn — spell circles, reading speed). Wisdom is what you *do*
with what you learned when two goods collide.

**A virtue is *granted* at its shrine by knowledge (mantra + correct shrine), not by its counter**
(`DESIGN_REVIEW_2026-09.md §1`). The hidden counter is the player's *record* in that virtue; it feeds the Seer,
companions, the Chamber and the epilogue and is never a gate. All eight must be granted before the stones.

## 2. Families

| Family | Virtues | Notes |
|---|---|---|
| Truth | Integrity | Anchor candidate |
| Care | Compassion, Kindness, Forgiveness | Max 2 per seed |
| Giving | Selflessness | |
| Justice | Respect, Justice | Justice is anchor candidate |
| Fortitude | Courage, Perseverance, Self-discipline | Max 2 per seed |
| Self-assessment | Humility, Gratitude | Humility always drawn |
| Particular commitment | Loyalty | |
| Intellectual | Open-mindedness | |
| Transcendent | Reverence | |

## 3. The Fifteen (content modules)

Each virtue is a self-contained module at `data/virtues/<id>/` containing: creed, vice (dungeon theme),
companion archetype, town archetype bias, action table (gain/loss with weights), shrine vision, conflict
partners, ≥5 quiz questions, ≥2 conditional twists, synonym name pool (≥5 per flavor).

| ID | Unique contribution | Vice (dungeon) | Companion archetype | Signature gains | Signature violations |
|---|---|---|---|---|---|
| `integrity` | Same person in private and public, over time | Duplicity | the oath-keeper | truthful honesty tests; fair pay to blind vendors; kept promises | lying; theft; broken promise flags |
| `compassion` | Felt pull toward another's suffering | Callousness | the healer | give to beggars; tend the sick; spare the wounded | ignore pleas repeatedly; attack non-evil |
| `kindness` | The habit — acts even when the feeling is absent | Cruelty | the innkeeper's child | small unprompted acts (feed animals, return lost items) | taunt/insult options; drive off beggars |
| `forgiveness` | Releasing resentment toward one who wronged you | Vengeance | the reformed bandit | spare surrendered foes; pardon the thief | kill fleeing; pursue vendetta quests |
| `selflessness` | Downgrading your own claim for another's | Avarice | the almoner | donate blood; give items to those in need | hoard when asked; loot town chests |
| `respect` | Baseline dignity owed without agreement or warmth | Contempt | the herald | bow at shrines; address elders properly | desecrate; mock; enter homes at night |
| `justice` | Impartiality across many people | Corruption | the magistrate | testify truthfully; refuse bribes; split loot evenly | bribe; frame; unequal shares |
| `courage` | Acting against acute fear, now | Cowardice | the veteran | stand ground; face bosses under-leveled | flee battle; refuse duels |
| `perseverance` | Sustained effort against fatigue and delay | Sloth | the pilgrim | finish dungeons entered; complete long chains | abandon dungeons repeatedly; quit quests |
| `self_discipline` | Moment-to-moment regulation of impulse | Gluttony | the ascetic | fast when food is scarce; decline free wine; measured casting | overeat/overdrink; overspend; spell spam |
| `humility` | Accurate read on your own limits | Pride | the shepherd | refuse titles/rewards; admit ignorance | boast options; ostentation at shrines |
| `gratitude` | Accounting of what you didn't earn alone | Ingratitude | the elder | thank helpers; return favors; tend graves | leave without thanks; ignore debts |
| `loyalty` | Commitment to specific people, not everyone equally | Betrayal | the squire | stand by companions; honor faction | dismiss companions cheaply; betray faction |
| `open_mindedness` | Willingness to update beliefs | Dogma | the foreign scholar | change an answer when refuted; hear heretics | refuse to listen; dismiss foreign clans |
| `reverence` | Orientation toward something beyond the self | Profanity | the hermit | meditate without need; observe conjunctions | loot shrines; ignore omens; destroy relics |

**Launch scope (1.0): 12 modules** — all except `gratitude`, `perseverance`, `reverence`, which ship in a
free update (their violations are hardest to detect legibly). The 12 cover all five conflict pairs.

## 4. Draw Algorithm (generation stage 1b)

```
set = { humility }
set += one of { integrity, justice }                      # anchor
repeat until |set| == 8:
    candidate = weighted random from remaining launch modules
    reject if family(candidate) already has 2 members in set
    set += candidate
constraints (else redraw, max 50 tries):
    families represented >= 6
    conflict pairs fully present >= 2                    # both sides drawn
```
Slots `slot.1..8` are assigned by a deterministic order (anchor = slot.1, humility = slot.8). Towns,
companions, dungeons, shrines, clan patrons, and token-graph nodes bind to slots; slots bind to virtue IDs.

## 5. Humility — the Capstone (always drawn, always slot.8)

Humility is the structural heir to the classic "eighth virtue": the one that is *about* the others.
- Its town is always `{village.ruined}` — a city that had every virtue but this one and fell to pride. Its
  intel comes from ghosts.
- Its shrine is the only **guarded** shrine (fiends; needs a warding item) and **cannot be meditated until
  ≥4 other shrines are done** — in fiction, the fiends yield only to one who has something to be humble about.
- Its companion is the mechanically weakest archetype (the shepherd). The last virtue costs something.
- Its dungeon (Pride) is the one that connects to `{end_dungeon}`.
- Humility **conflicts with nothing**. It is the one virtue with no virtuous counterweight — you cannot have
  too much of it — which is why it can be pursued without limit and why it makes pursuing the others safe.

## 6. Wisdom — the Meta-Virtue (never drawn, never shown, never meditated)

**Definition.** Judgment between goods. Wisdom exists only *between* virtues; a single virtue in isolation
gives it nothing to do.

**Scoring** (`VirtueSystem.wisdom()`, hidden 0–100):
- For each active conflict pair (§7), track the *balance* of the player's resolutions: `balance = |gainsA − gainsB| / (gainsA + gainsB)`.
  Low imbalance over many resolutions → Wisdom rises; a run that maxes one side → Wisdom falls.
- Bonus for **integrated resolutions** (dilemma outcomes flagged `both`, e.g. mercy *with* restitution).
- Penalty for **extremes**: any drawn virtue at 99+ while its conflict partner is < 25.
- Humility at "worthy" or above is a multiplier; Wisdom cannot exceed "seeking" while Humility is "lost".

**Bands:** unbalanced / seeking / discerning / whole.

**Feedback (diegetic only):** the `{seer}` says nothing of Wisdom until Humility's shrine is meditated;
then their readout shifts from "how good art thou in each" to "art thou *whole*?" Companions from opposite
sides of a pair argue at camp when imbalance is high. Dreams show both faces of a dilemma.

**End-game role:** the `{end_dungeon}` per-level questions and the final quiz draw from *this seed's*
conflict pairs. Wisdom band decides the epilogue's verdict independent of the 8 virtue results. There is
no Wisdom shrine — the descent is its shrine.

## 7. Conflict Pairs → Dilemma Templates

Active when both sides are drawn. Each dilemma has no answer that scores both virtues fully; Wisdom scores
the *balance* across the run. Dilemma templates live in `data/twists/dilemma_<pair>.json`.

| Pair | Tension | Dilemma template | `both` outcome |
|---|---|---|---|
| Loyalty vs Justice | "my people first" vs "same rule for all" | A companion's kin is the thief: convict or shield | Convict, then personally pay the restitution |
| Compassion/Forgiveness vs Justice | mercy vs accountability | The wronged party demands the pardoned bandit's punishment | Pardon with binding service to the victim |
| Integrity vs Kindness | the true answer vs the kind answer | A dying NPC asks if their child survived (he did not) | Tell the truth *and* stay until the end |
| Selflessness vs Self-discipline | giving vs boundaries | A beggar returns daily; give until you starve or set a limit | Give a fixed share and find him work |
| Open-mindedness vs Integrity | updating vs having convictions | A heretic offers a *true* correction to a mantra you were told | Verify with a second source, then update |

Wisdom is the only arbiter of these; there is no formula shown to the player.

## 8. Rules for a Module to Enter the Draw Pool

A virtue module may be flagged `drawable: true` only when it defines: creed; vice + dungeon theme set; companion
archetype with arc **and Threshold farewell line**; ≥6 actions (≥3 gains, ≥3 losses) with weights; shrine
vision text; ≥1 conflict partner (Humility exempt); ≥5 quiz questions; ≥2 conditional twists; **≥8 scenarios
each with ≥1 in-game question and ≥1 Chamber question template** (`WITNESS_LOG.md §7`); **≥2 side quests that
exercise it** (`SIDE_QUESTS.md`); synonym pool ≥5 per flavor; **one virtue-line per binding principle (12)** —
"how {principle} appears in {this virtue}", ≤2 sentences, plus an affinity 0–3 to each principle
(`QUEST_TREE.md §4.0`; Humility must have ≥1 with all twelve). Enforced by `validate_data.py`.

## 9. Virtue-lines (the Word's meaning, per module)

Each module's `codex_lines.json` holds twelve entries `{ principle_id, affinity, line }`. Example for
`courage`: Measure → *"Courage that knows no measure is only noise. The brave man counts the cost and goes
anyway."*; Mercy → *"It takes more courage to lower the sword than to raise it."* Lines are spoken by statues,
companions, ghosts, dreams and books (`QUEST_TREE.md §4.0.5`) and are the material of the Chamber's second
question. They are content, not lookup: a player must have *heard* a line to answer with it.

