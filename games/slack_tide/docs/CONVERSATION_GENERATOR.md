# SLACK TIDE — Conversation Generator

How ~16 speaking parts get built for roughly the cost of five.

The seam is the one `INFORMATION_ARCHITECTURE.md` already argues for:
**`topics.json` decides what is POSSIBLE; Ink decides what it SOUNDS LIKE.**
The generator turns the first into the second wherever the scene does not
deserve a human sentence.

---

## 1. Why generation is correct here, not just cheap

1. **The matrix is already the puzzle.** `topics.json` stores, per topic, per
   NPC, a `mode` and what it grants. That is a conversation's *logic* already
   written down. Hand-writing it again in Ink duplicates it in a form no tool
   can check.
2. **Solvability must stay machine-checkable.** `check_solvable.py` proves
   every seed winnable by reading the matrix. If the real routes lived only in
   prose, that proof would quietly stop being true.
3. **Consistency at depth.** 16 NPCs x 14 topics is 224 stances. Hand-written,
   the reliability numbers drift; generated, they cannot.
4. **The fiftieth informant should not be bespoke.** `patterns.ink` already
   implements `barter` / `interrogate` / `persuade` / `confide` as tunnels.

---

## 2. Verified inputs

Confirmed present before planning this (not assumed):

`games/slack_tide/ink/patterns.ink` exposes exactly the vocabulary needed:

```
EXTERNAL knows(id)              EXTERNAL believes(id, min_belief)
EXTERNAL heard_of(id)           EXTERNAL learn(id, trust)
EXTERNAL has_asset(id, amount)  EXTERNAL spend_asset(id, amount)
EXTERNAL standing(npc)          EXTERNAL standing_at_least(npc, tier)
EXTERNAL adjust_standing(npc, delta)
EXTERNAL flag(flag_name)        EXTERNAL set_flag(flag_name)
```

plus the tunnels `barter(...)`, `interrogate(...)`, `persuade(...)`,
`confide(...)`.

`knows()` **is** the reliability model — `CoreKnowledge` is a facade over
`CoreIntel`, so a token at 0.3 reads false and the same token corroborated
reads true. A generated `{ knows("c1b") }` inherits the whole 0-100
reliability, corroboration, decay and `conflicts` system for free.

---

## 3. Mode -> generated shape

`topics.json` already records each NPC's stance mode. The mapping is direct:

| mode | What it generates |
|---|---|
| `explain` | States the seed-true answer. `learn(id, <method>)` at that method's reliability (told 55, document 70, witnessed 90). |
| `rumor` | Offers **every** triad answer, each capped at 25. This is the engine of honest error, and why the player must triangulate. |
| `price` | `barter` tunnel, then `learn` at `sold` (60) on success. |
| `flinch` | `interrogate` tunnel. A passing `knows()` check makes them slip; a failed bluff costs candor. |

A `rumor` NPC is not lying. Ma Cobb has three versions and sells all of them —
she is *hedging*. That distinction is the tone of the whole game.

---

## 4. Split: generated vs. hand-written

**Hand-written (5)** — they carry the story, so they get sentences:

| NPC | Why |
|---|---|
| **Corvin Ashe** | Seed B's whole thesis: a tired man who moved a date. Already ported, and the proven pattern. |
| **Ilsabet Doon** | The widow. Seed A's moral centre, and the candor check about the satchel. |
| **Capt. Brack** | The endgame, and the satchel's intended recipient. |
| **Hesper Quillon** | The voice of the game. "Hesper says this is a mood." |
| **Sister Wenna** | Seed C's route, and the Bell. |

**Generated (the standing cast)** — Doss, Ma Cobb, Fen, Ottoline, Wimble,
Vosk, Croy, Yarrow, Toma, Goldie, plus the passenger archetypes. Functional,
in-voice-ish, and every line tagged `# NEEDS_HUMAN_WRITING` for a later pass.

**Never generated:** any line in the finale, any ending text, anything Doon
says. Those are the moments the game is *for*.

---

## 5. Output contract

- One `.ink` per NPC in `games/slack_tide/ink/`, regenerable, with a header
  marking it generated.
- Compiled via the vendored `inklecate.exe` (as `run.ps1` already does).
- **Must pass `validate_narrative.py`** — that validator catches an Ink story
  calling an EXTERNAL `CoreInkBindings` never binds, which compiles with exit
  0 and crashes only when a player reaches that line.
- A `--check` mode, so CI fails when a story is stale against the matrix,
  exactly like `convert_slack_tide.py` and `gen_topics.py`.
- Hand-written files are **never overwritten**: the generator skips any NPC on
  the bespoke list, and refuses to clobber a file lacking its generated header.

---

## 6. What would make this the wrong call

Stated honestly, so it can be noticed if it happens:

- If generated conversations read as interchangeable, the world stops feeling
  specific. Mitigation: per-NPC voice fragments (a hedge, a tic, a refusal)
  drawn from the spec's `role` line, and the five bespoke characters carrying
  the emotional load.
- If the generator grows conditionals to express one special case, that case
  wants hand-writing instead. **The generator must stay boring.**
