# Writer's Guide — Authoring Content for Paragon

Content is authored here as Markdown sheets and transcribed to `data/*.json` once schemas land (P0–P1).
Write so a script can lift it: fixed headings, one ID per row, effects in the `virtue ±n` form.

## 1. Voice

- Early-modern register: *thou / thee / thy / thine / art / dost / hast / didst*. Readable, not pastiche.
- **≤ 3 sentences per NPC line.** Long lore goes in books, signs, ghosts.
- No jokes that break the world; no modern idiom; no fourth wall.
- NPCs speak from their **role and virtue**, not from omniscience. A baker knows bread and the street.
- Companions speak **through their virtue** (`VIRTUES.md §3`). The oath-keeper notices lies; the shepherd
  notices pride; the healer notices pain.

## 2. Names — never write one

Use templates only (`NAMING_AND_LORE.md §6`):

| Want | Write |
|---|---|
| this town | `{town:S}` (S = slot in scope) or `{town:here}` |
| a virtue's label | `{virtue:S}` or `{virtue:integrity}` |
| the ruler / seer | `{ruler}` / `{seer}` |
| a companion | `{companion:S}` / `{companion:justice}` |
| an NPC's own name | `{npc.name}` |
| capitalise / article | `{cap:…}` / `{a:…}` |
| pronouns | `{they:…} {them:…} {their:…}` |
| a place we walked | `{last_town}`, `{dir:X}`, `{coords:X}` |

Capitalised words not on the common-word allowlist fail validation. Generic nouns (orc, troll, dragon,
tavern, shrine) are fine. **Never** any term from the banlist (`data/names/banlist.json`).

## 3. IDs

`role.<archetype>.<name>` · `token.<category>.<slot|virtue>` · `scenario.<virtue>.<name>` ·
`quest.<tier>.<name>` · `dilemma.<a>_vs_<b>` · `event.<verb>_<object>` · `q.<virtue>.<name>` (questions).
Snake_case, ASCII, stable forever.

## 4. Writing a Scenario

```
### scenario.<virtue>.<name>
Placement: <location archetypes>; requires: <virtues drawn / flags>
Situation: 2–4 sentences the player sees/hears.
Choices:
  - <choice_id> — what the player does → `virtue +n / −n` … ; witnesses: <who (reliability)>; public: y/n
  - …
  - avoid — walking away → logged `avoided`
Surfacing: <after N days, where, what>
In-game question (asked by <role>): "…?"      # yes/no/refuse; graded vs event <event_id>
Chamber question (Alone): "…?"                 # human answers about self/companions
Chamber question (Together, to {companion:X}): "…?"   # companion answers from log
```
Rules: ≥2 virtues touched across choices; no choice good for every virtue; at least one witness with
reliability < 0.7 where the scene is public; the *avoid* line always exists.

## 5. Writing a Token Chain

Every mandatory token (mantra, shrine location, sigil location) needs **≥2 true sources in ≥2 locations**
and may have **1 false variant** with a `refuted_by` source discoverable before the token is used.
Sources: NPC line (with the keyword that unlocks it), book/sign, dream, ghost, shrine vision.
Write the *keyword ladder*: which word in one NPC's line leads to the next NPC.

## 6. Writing a Dilemma

Setup · the two virtues and why they pull apart · **≥2 one-sided resolutions** · **≥1 `both` resolution that
costs** (time, gold, item, loyalty) · companion reactions from *both* sides · `WisdomScorer.record_resolution`
tag · Chamber callback · epilogue line. Reviewers reject a dilemma with a "correct" answer.

## 7. Virtue Effects

Weights are 1–10 on the hidden 0–100 counter. Typical: small habit ±1–2; meaningful choice ±3–5; grave act
±6–10. Clan-hall shortcuts cost −2..−4 to the hall's shadow virtue. Killing a non-evil human: −8 to every
Care/Justice virtue drawn, public.

## 8. Checklist Before Submitting

- [ ] No proper nouns; templates only · [ ] ≤3 sentences per line · [ ] IDs stable and namespaced
- [ ] Scenario has avoid + both question types · [ ] Token has 2 true sources · [ ] Dilemma has a costly `both`
- [ ] Nothing here would surprise a player who was paying attention (fair in hindsight)
