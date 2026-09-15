# activeContext.md — wardens

> Read first, update last, every session. Keep ≤ 120 lines. Not a changelog.

**Phase:** 0 — Scaffold  **Engine:** fps  **Last updated:** 2026-09-12

## State

Scaffolded 2026-09-12 by `game_api/fps/tools/new_game.py` and moved to
`games/wardens/`. `validate_data.py` passes **0 errors, 0 warnings**. The data
is the generic starter package — it loads, but none of it is this game yet.

- `docs/CONCEPT.md` — the original design brief (moved from `games/others/`)
- `docs/ASSET_MANIFEST.md` — art requirements, all `TODO`

## Now

- [ ] **Opus architecture pass** — this is `GREENFIELD`. Needs `CHAOS_SPEC.md`
      + `RULINGS.md` before any implementation.

## Open design questions for the architect

These are the details the concept leaves unresolved. They are the whole job.

1. **`growth_vector` representation.** A single −1..+1 float, or a 2D
   (aggressive, supportive) vector? The concept implies one axis, but "feral
   overgrowth" may be a third state rather than an extreme of one.
2. **Feral overgrowth mechanics.** The concept says it "biases the player
   toward violence, demanding more kills to stay stable." What is the actual
   pressure — a decaying resource, degrading stats, forced attacks? It must be
   readable and escapable, or it is a counter-gate.
3. **Time is seconds here.** The fps adapter reports game seconds, not turns.
   Feeding/starving cadence must be authored against a real-time clock.
4. **Faction reaction to blade shape.** Factions react to "what the blade looks
   like" — so `growth_vector` must be a public, queryable value. Through the
   adapter, or as a stat?
5. **The Turning's pace.** Is it on a timer, or driven by player action? If it
   is a timer, the game has a hidden clock — which is a counter-gate unless it
   is visible in the world (the canopy/palette shift is the natural place).
6. **Widow Bark memory replacement.** "Slowly begins replacing the player's own
   memories" — mechanically, what is lost? This is the game's epistemic-chaos
   hook and is currently undefined.
7. **Win condition.** The ending is determined by the blade's final state, not
   a dialogue choice. What exactly is measured, and when is it locked in?

## Chaos surface (initial read)

| Tier | Present? | Notes |
|---|---|---|
| epistemic | **weak** | Widow Bark memory bleed is the only hook; needs design |
| combinatorial | **weak** | no structural draw yet — the biggest gap |
| social | medium | factions reacting to blade shape is genuinely good |
| mechanical | n/a | real-time combat; cap the RNG |

The concept is strong on *expression* (the blade records your play) but thin on
*unpredictability*. The architect should add a combinatorial draw — which
factions/regions/corruptions exist this run — or the game will play the same
way every time.
