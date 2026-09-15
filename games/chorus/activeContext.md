# activeContext.md — chorus

> Read first, update last, every session. Keep ≤ 120 lines. Not a changelog.

**Phase:** 0 — Scaffold  **Engine:** isometric  **Last updated:** 2026-09-12

## State

Scaffolded 2026-09-12 by `game_api/isometric/tools/new_game.py` (square_iso,
sequential turns) and moved to `games/chorus/`. `validate_data.py` passes
**0 errors**, 12 asset warnings (expected — placeholders). The data is the
generic starter package; none of it is this game yet.

- `docs/CONCEPT.md` — the original design brief (moved from `games/others/`)
- `docs/ASSET_MANIFEST.md` — art requirements, all `TODO`

**Engine decision:** isometric, not fps. `CONCEPT.md` offers fps as an option;
declined because the core loop is a city that *visibly changes based on what
you tell it*, and civic-scale change cannot be read through a first-person
cone. Rationale in `docs/ASSET_MANIFEST.md`.

## Now

- [ ] **Opus architecture pass** — `GREENFIELD`. Needs `CHAOS_SPEC.md` +
      `RULINGS.md` first.

## Open design questions for the architect

1. **Testimony as a token with `fidelity`.** The concept proposes
   faithful/softened/sharpened plus links to referenced NPCs and events. Can
   `CoreIntel` carry this today (`reliability` + `conflicts` + provenance are
   close), or is a core change needed? File under `## Core requests` if so.
2. **"No true account underneath."** This is the concept's boldest claim and it
   directly tensions with the repo's fairness rule that every lie needs a
   discoverable refutation. **Ruling required.** Suggested resolution: there is
   no single true account, but every account is *checkable against evidence* —
   so the player can always establish which claims are better supported, even
   when no version is wholly true. That keeps it fair without making it simple.
3. **What the game actually measures.** Explicitly *not* truthfulness — it
   tracks "whether Recitations left people more able to make good decisions, or
   more comfortable and less prepared." Needs a concrete, inspectable metric.
4. **Seven catastrophes, one Recitation.** How many must be investigated to
   recite? If all seven, the game is linear; if fewer, which ones you chose
   becomes a combinatorial draw. Prefer the latter.
5. **City state representation.** What the population believes must be
   queryable by NPC behaviour and by district dressing. A per-event belief
   value, or a full belief graph?
6. **Ledger-Bead destruction.** "Erase it permanently from the game's own
   memory of events" — genuinely unusual and worth specifying carefully. This
   is irreversible player-driven data loss and needs a save/load story.

## Chaos surface (initial read)

| Tier | Present? | Notes |
|---|---|---|
| epistemic | **strongest of all six games** | contested testimony *is* the mechanic |
| combinatorial | medium | which catastrophes you investigate; which factions lobby |
| social | **strong** | the city reacts to every Recitation |
| mechanical | **none** | no combat focus — correctly so |

This is the purest Tier-1 game in the repo: the player's model of the world
being wrong, and discoverable, is not a subsystem here — it is the entire
premise. It should score highest on `epistemic_score` of any package, and is
the best test of whether `CoreIntel` can represent narrative objects rather
than just physical facts.
