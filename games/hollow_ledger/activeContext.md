# activeContext.md — hollow_ledger

> Read first, update last, every session. Keep ≤ 120 lines. Not a changelog.

**Phase:** 0 — Scaffold  **Engine:** isometric  **Last updated:** 2026-09-12

## State

Scaffolded 2026-09-12 by `game_api/isometric/tools/new_game.py` (square_iso,
sequential turns) and moved to `games/hollow_ledger/`. `validate_data.py`
passes **0 errors**, 12 asset warnings (all expected — placeholders).
The data is the generic starter package; none of it is this game yet.

- `docs/CONCEPT.md` — the original design brief (moved from `games/others/`)
- `docs/ASSET_MANIFEST.md` — art requirements, all `TODO`

## Now

- [ ] **Opus architecture pass** — `GREENFIELD`. Needs `CHAOS_SPEC.md` +
      `RULINGS.md` first.

## Open design questions for the architect

1. **Weight as a relational token.** The concept proposes a `token` with
   `Weight` + `resolution_state` linking *two named parties*. The core's
   `CoreIntel` tokens are currently held **by** a holder, not **between** two.
   Does this need a core schema change? If so, file it under `## Core requests`
   — this is the concept's own proposed stress-test of the shared schema.
2. **Hollow birth threshold.** "Enough unresolved Weight curdles into a Hollow."
   A threshold is a counter-gate unless the player can *see* Weight
   accumulating — which the Tally-Chalk/soot overlay does. Make the visibility
   mandatory, not optional.
3. **The four resolutions' real costs.** Repaid/forgiven/forced/sold each need
   concrete mechanical consequences, not just flavour. `Sold` is the most
   interesting: a broker collects "on their terms, which you don't control" —
   that is a genuine chaos generator and should be modelled as an autonomous
   agent acting later.
4. **Does the player see Weight numerically?** Recommended: no. Show the
   overlay, hide the number. Keeps it a judgment call, not an optimisation.
5. **Act III scale.** A town-consuming Hollow whose form depends on the
   *pattern* of resolutions — what are the distinct endings, and how few can
   still feel distinct?
6. **The Unspent Name.** "Carrying it draws Hollows unnaturally" — a great
   risk/reward item. What does carrying it actually change?

## Chaos surface (initial read)

| Tier | Present? | Notes |
|---|---|---|
| epistemic | medium | debts can be disputed; who owes what is contestable |
| combinatorial | **strong potential** | which debts exist this run is a natural draw |
| social | **strong** | the whole game is conduct with consequences |
| mechanical | n/a | tactical combat exists but is not the point |

This concept is the best natural fit of the three for the four-tier model: the
debt graph is *already* a combinatorial draw and *already* social. The
architect's main job is making debts **epistemically contested** — two parties
remembering the same obligation differently — which turns a bookkeeping game
into an investigation.
