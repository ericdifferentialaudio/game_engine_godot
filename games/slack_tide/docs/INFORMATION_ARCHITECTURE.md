# SLACK TIDE — Information & Dialogue Architecture

The answer to three questions: should dialogue be Ink, how many NPCs, and what
makes "conversations open other conversations" actually work.

---

## 1. Ink: yes, but not for the reason usually given

**Verified before recommending** (2026-09-19):

- `tools/inklecate/inklecate.exe` is vendored and **works** — compiled a test
  story with an `EXTERNAL knows(...)` gate, exit 0, valid `.ink.json`.
- `CoreInkBindings` already exposes the exact vocabulary this game needs:
  `knows` · `believes` · `heard_of` · `disbelieves` · `learn(id, trust)` ·
  `has_asset` · `spend_asset` · `give_asset` · `standing_at_least` ·
  `adjust_standing` · `stat_at_least` · `flag` · `set_flag`.
- `core/ink/patterns/patterns.ink` already implements `barter` ·
  `interrogate` · `persuade` · `confide` as tunnels.
- `CoreInkValidator` does **static** checks *and* **context simulation**.

The usual argument for Ink is "nicer to write". That is true, and not the
point. The real reasons are these three:

**(a) `knows()` is already the reliability model.** `CoreKnowledge` is a façade
over `CoreIntel`: a token at reliability 0.3 reads **false** from `knows()`, the
same fact corroborated reads **true**, and a debunked token always reads false.
A writer types `{ knows("c1b") }` and gets the whole 0–100 reliability,
corroboration, decay and `conflicts` system for free. In hand-written JSON I
must repeat `"check": {"has": "c1b", "min_reliability": 0.75}` on every branch
and keep those numbers consistent by hand across twenty NPCs.

**(b) The validator is what makes a deep web survivable.** With 16 NPCs
cross-referencing 75 tokens, the failure mode is not a crash — it is *dead
content*: a knot reachable on paper that no achievable game state can ever
satisfy. `CoreInkValidator`'s context simulation plays the story across a
cross-product of axes and reports what was reachable and under what conditions.
Nothing else catches that class of bug, and at this depth it is the bug you
will actually have.

**(c) Tunnels make "one conversation opens another" composable.** A tunnel
returns to its caller with its result in a global. That is exactly the shape of
"press him on the sluice, and *depending on how that went*, the brother topic
is now available."

### The caveat, stated plainly

Ink is worse than JSON at one thing that matters here: **enumerating** content.
A topic matrix — who will discuss what, at what standing — is data, and data
belongs in JSON where it can be validated, counted and balanced. Writing
16 × 12 stances as Ink knots would be miserable and unauditable.

### So: a hybrid, split on a real seam

| Layer | Format | Why |
|---|---|---|
| **Token graph** (75 tokens, sources, conflicts, truth-by-seed) | `slack_tide_spec.json` → generated `intel.json` | Data. Must be countable and seed-testable. **Already built.** |
| **Topic matrix** (who knows what, what unlocks what, at what standing) | `topics.json` | Data. This is the puzzle. Must be machine-checkable for solvability. |
| **Conversation text and structure** | `.ink` per NPC | Prose. Needs weave, tunnels, sticky choices, patterns. |
| **Systemic beats** (barter/interrogate/persuade/confide) | shared `patterns.ink` | **Already written.** The fiftieth informant should not be bespoke. |

The rule: **`topics.json` decides what is *possible*; Ink decides what it
*sounds like*.** A solvability checker then reads `topics.json` alone and proves
every token is reachable in every seed, without parsing a word of prose.

---

## 2. What actually makes conversations open conversations

Not a dialogue tree. A **topic graph** laid over the token graph. Four rules:

**Rule 1 — Topics are objects, not branches.** A topic is something you can
raise with *anyone*, and each NPC has a *stance* on it. `night_sluice` is one
topic; Corvin flinches, Fen explains, Doss repeats all three rumours, Ottoline
prices it, Wimble sells the paperwork. One topic, five scenes. This is what
makes a world feel like it has a shared subject rather than five unrelated
quizzes.

**Rule 2 — Topics unlock on knowledge, not on flags.** You may raise
`corvin_brother` because you *hold* `s_corvin_brother`, from any source.
There is never one required path: overhear it from Cobb, read it in the customs
cellar, or have Fen mention it drunk. **No counter-gates.**

**Rule 3 — Asking A about B is how you corroborate.** The +20 corroboration
bonus is the engine of the whole game. You hear `c1b` from Doss at 25 —
useless. Fen tells you at 55 — still under the 75 Corvin needs. Corvin's own
chit is a document at 70, and a second independent source pushes it to 90.
*Now* you can say it to his face. **The gameplay loop is triangulation**, and it
emerges directly from the source lists already in the spec.

**Rule 4 — Some doors open only to conduct.** Doon speaks only if you hold
`s_doon_husband` *and* mercy ≥ 5. Gifts require values mostly earned before you
knew the gift existed. This stops the information graph from collapsing into a
pure logistics puzzle.

### One thread, worked through

```
        Ma Cobb (overheard, 30)         "Corvin Ashe lost a brother"
                 │                                  │
                 ▼                                  ▼
        s_corvin_brother @30 ──corroborate──▶ @50 (Fen, told, night)
                 │
                 ▼  unlocks TOPIC corvin_brother
        ┌──────────────────────────────────┐
        │ Corvin: "Who told you about Tam." │
        └──────────────────────────────────┘
             │                         │
      [wait / say sorry]        [use it as leverage]
             │                         │
             ▼                         ▼
     mercy+1, patience+1        fairness−1, consortium−5
     c1c at slip (55)           p_corvin only
     unlocks TOPIC the_hum            │
             │                        └── Corvin closes; the c1c route must
             ▼                            now come from Wenna, or from the
     Wenna corroborates c1c → 75          Underworks witnessed directly
             │
             ▼
     Now sayable to his face → he hands over the chit
```

Two things to notice. The kind route and the cold route **both work** and lead
somewhere different — cruelty is not punished with a dead end, it is charged a
detour. And the same token (`c1c`) is reachable from a person, a hermit, or a
place, so no single NPC is ever a bottleneck.

---

## 3. How many NPCs is optimal

Not 13, and not "more" as a flat number. The right answer is **tiers**, because
depth per character matters far more than character count.

| Tier | Count | Beats each | What they are |
|---|---|---|---|
| **Deep** | 6 | 40–60 | Full bespoke Ink. Own arc, own secret, can be lost. Hesper, Corvin, Fen, Ottoline, Doon, Brack. |
| **Standing** | 10 | 15–25 | Topic-matrix driven, plus 2–3 bespoke scenes. Goldie, Cobb, Doss, Wimble, Vosk, Croy, Yarrow, Toma, Wenna, gatehouse guard. |
| **Passing** | 7 archetypes | 6–10 | Procedural passengers, generated per crossing from the manifest. |
| **Voices** | ~6 | 1–3 | Not really characters. The Pale Collector, a pleading wight, the Choir. |

**Totals: 16 named + 7 archetypes ≈ 23 speaking parts**, but only 6 are
expensive. That is a 60–90 minute run with real density.

### Why not more named NPCs

1. **Corroboration needs overlap, not breadth.** Every token needs 2–3 sources.
   More NPCs means either thinner spread (triangulation gets hard to find) or
   duplicated sources (the world stops feeling specific).
2. **Recognition.** A player holds about 8–10 people in their head over 90
   minutes. Past that, characters become a directory you consult rather than
   people you have feelings about.
3. **The manifest already gives unbounded variety.** 7 archetypes × 3 crossings
   × 14 days ≈ 42 encounters from one small content set. That is where
   *populated* comes from. The named cast is where *meaning* comes from. Those
   are two different budgets and should not be confused.

### Why not fewer

Below ~14 named, you cannot give every token two independent sources without
the same three people knowing everything — which collapses triangulation into
"go and ask Fen".

---

## 4. `topics.json` — the puzzle layer

```json
{
  "topics": {
    "night_sluice": {
      "name": "Who closes the night sluice",
      "unlocked_by": { "any": ["t_slack_grows", "p_hesper"] },
      "resolves_group": "q1",
      "stances": {
        "corvin":   { "mode": "flinch",  "ink": "corvin.ink#sluice",
                      "check_group": "q1", "min_reliability": 0.75,
                      "on_pass": { "unlocks": ["the_chit"] } },
        "fen":      { "mode": "explain", "grants_true": "q1", "method": "told" },
        "doss":     { "mode": "rumor",   "grants_group": "q1", "cap": 0.25 },
        "ottoline": { "mode": "price",   "buys_group": "q1" },
        "wimble":   { "mode": "sell",    "price": 8, "grants": "ev_b_paystub" }
      }
    }
  }
}
```

`mode` selects the pattern (`rumor` → every answer at cap 25; `explain` → the
seed-true answer at that method's reliability; `sell` → `barter` then `learn`).
`ink` points at a bespoke knot where the scene deserves hand-writing. Everything
else is generated, which is how ten standing NPCs cost what two deep ones do.

### The solvability contract

`tools/check_solvable.py` walks `topics.json` per seed and asserts:

1. Every case group has **at least two independent routes** to ≥75 reliability.
2. No route requires an item unaffordable on the *low* income curve (132 tallies).
3. No token is reachable **only** through a single NPC who can be permanently
   lost (no counter-gates).
4. Every gift is obtainable with values reachable from a 3/10 start.

Run across 1,000 seeds, this is design-doc milestone **M0** — and it is worth
far more than any amount of prose written first.

---

## 5. Build order

1. **`topics.json` + solvability checker** — prove the puzzle is winnable in
   1,000 seeds *before* writing prose.
2. **Port Corvin to Ink first**, end to end — he exercises every mechanic
   (check, bluff, debunk group, item grant, values, standing). Run the
   validator on him before touching the other four.
3. **Topic matrix** for the 10 standing NPCs.
4. **Passenger archetype generator.**
5. **Doon and Brack last** — they are the endgame and depend on everything
   above.

The JSON dialogue in `actors.json` stays until its Ink replacement passes the
validator. Nothing is deleted on faith.
