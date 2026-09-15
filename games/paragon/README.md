# Paragon

An original 3D isometric, turn-based party RPG in the spirit of the great 1985 virtue-RPG: knowledge-driven
discovery, hidden virtue simulation, dual-moon travel, reagent magic — in a **procedurally generated world
with randomized names and a different set of eight virtues every run**, judged in the end by the one
virtue you cannot grind: Wisdom.

**Home:** `game_engine_godot/games/paragon/` — a game package of the `game_engine_godot` monorepo. It is
rendered by the **isometric engine** (`game_api/isometric/`) and consumes the shared simulation core
(`core/addons/game_core/`). Engine-level docs: `../../docs/ARCHITECTURE.md`, `../../docs/API.md`,
`../../game_api/isometric/docs/`. Run after any edit with `tools/sync_game.ps1 -Game paragon -Engine isometric`.

## First playable slice (this package's current content)

A grey-box, data-only slice authored against the real design docs (`docs/QUEST_TREE.md`,
`docs/content/tokens/anchor_town_chain.md`, `docs/content/virtues/compassion.md`) using the engine's generic
data schema (proven by `game_api/isometric/games/example_realm_iso/`) — no bespoke engine code required yet:

- `anchor_overworld` → `anchor_town` (city) → `compassion_shrine_interior` (shrine), linked by portals.
- The Anchor Town **Integrity token chain**: mantra-keeper (honesty-gated mantra, true source #1),
  shrine-pointer (shrine location, true source #1), beggar (shrine location, true source #2, after 3 gifts),
  drunk (false shrine direction) refuted by the priest's Rule token, sigil-hider (sigil location).
- The **Shrine of Compassion**: the three-part shrine vision from `compassion.md §5`, granting enlightenment
  and spawning the healer companion (`companion.md §3`).
- Virtue counters (`virtue_integrity`, `virtue_compassion`, `virtue_humility`, `wisdom`) are plain custom
  `game.json` stats, moved by `reward` interactions' `stat_delta` — the same generic mechanism
  `example_realm_iso` uses for `health`. No new engine code was needed for this slice.

Files: `game.json` · `terrains.json` · `maps.json` · `units.json` · `items.json` · `factions.json` ·
`intel.json` · `intel_rules.json` · `sites.json` · `ai_profiles.json` · `assets.json`.

```powershell
python tools\validate_data.py games\paragon
tools\sync_game.ps1 -Game paragon -Engine isometric
game_api\isometric\tools\godot.ps1 smoke paragon
game_api\isometric\tools\godot.ps1 run paragon
```

**Not yet implemented** (tracked in `docs/DEVELOPMENT_TASKS.md` Phase 0/1): `VirtueSystem` manager (draw of
8 from 15, Wisdom scoring, bands/enlightenment thresholds beyond this one hard-coded shrine), world clock &
moons, name pools/`NameResolver`, procgen pipeline, `RunStats`/regression harness. This slice hard-codes one
virtue draw (Integrity anchor + Compassion) to prove the data pipeline end-to-end first.
**Engine:** Godot 4.x (decision history in `docs/ARCHITECTURE.md §1`; the monorepo pins the version).
**IP status:** original. No names, text, maps, or assets from any prior game. The design was drafted in a
standalone repo under the legacy code name `UIV`; that folder was retired when the docs moved here
(2026-09-07, closes P7-T6).

## Documentation Map

| File | Purpose |
|------|---------|
| `activeContext.md` | **Living sliding window** of recently completed / current / upcoming work. Read first every session. |
| `docs/ULTIMA_IV_DEEP_DIVE.md` | Internal reference analysis of the inspiration. Nothing in it ships. |
| `docs/GAMEPLAY.md` | **What the player actually does**: core loops, the full path to win act by act (every gate), all encounter kinds (knowledge / combat / survival / moral / set pieces / twists), feedback, the end — and the open gameplay issues G1–G12 from the 2026-09-07 deep dive. |
| `docs/WIN_CONDITIONS.md` | **Checklist view of the win**: end goal, the 13 hard requirements and 50 mandatory tokens, what is *not* required, compact tree, critical route by act, traps and ways out, trunk-focused improvement proposals. |
| `docs/GAME_DESIGN.md` | The game's design: systems, content scope, twists, open decisions. |
| `docs/VIRTUES.md` | Pool of 15 virtues, 8 drawn per seed; Humility capstone; Wisdom meta-virtue; conflict-pair dilemmas. |
| `docs/CRITICAL_PATH.md` | The five acts, the Threshold (Loyalty vs Humility), the Descent, the Chamber, epilogue, Book of Paragons. |
| `docs/QUEST_TREE.md` | **The entire game as one dependency tree**: win ← Binding Word (three roads: the Dead / the Silent / the Still) ← Descent ← Ring×8 + Horn + Artifacts ← stones (need all 8 virtues) ← mantras/shrines/sigils; the Word is one of 12 binding principles **derived from this seed's eight** and taught by eight virtue-lines; 50 mandatory tokens; the four doors; what each step asks of the player. |
| `docs/WITNESS_LOG.md` | Conduct record, witness reliability, rumours, in-game "hast thou ever…?" questions, scenario catalogue. |
| `docs/SET_PIECES.md` | Eleven late-game set pieces common to every seed: Drowned Court, Bell in the Deep, Corsair Fleet, Maelstrom, Wind-Ship, Assize, Silent Monastery, Mirror Ford, Debtor's Isle, Long Night, the Hermitage. |
| `docs/SIDE_QUESTS.md` | Side quests as staged situations (Heart / Street / Ledger); the jailed mother; the bar fight; tavern standing. |
| `docs/NAMING_AND_LORE.md` | Original-IP naming: archetypes, name pools (3 seed sets), templating, lore beats. |
| `docs/PROCEDURAL_GENERATION.md` | World generation pipeline, fixed-vs-random table, twist pool, validator. |
| `docs/CLANS.md` | The 12 clans: shrine bonuses, passives, champions, halls, magic tiers. |
| `docs/ITEMS.md` | Items system: tiered sellers (village/town/castle), key items (stones, sigils, ring, horn, artifacts), per-seed magic uniques, dungeon temptation floors. |
| `docs/REGRESSION.md` | `RunStats` telemetry (public Ledger of Days / hidden conduct), event→stat map, ~70 `REG-*` regression tests, golden archetype runs, CI. |
| `docs/DESIGN_REVIEW_2026-09.md` | Gameplay deep-think, all items now decided: counters gate nothing; mantra+shrine; 8 virtues → stones → key items → Descent; food camp-only & never gating; diegetic anti-grind; four doors; the Binding Word's three roads (§11). |
| `docs/ARCHITECTURE.md` | Engine decision, technical architecture, data model, dialogue format, testing. |
| `docs/DEVELOPMENT_TASKS.md` | Ordered phases, milestones, high- and medium-level tasks with stable IDs. |
| `docs/RULES.md` | Project, code, content, IP, and process rules. |

## Pillars

**Discovery** (knowledge as progression) · **Virtue** (conduct is the plot) · **Journey** (a coherent,
open world) · **Replayability** (randomize names and placement — never rules).
