# Asset plan — all games

What art each game needs, in one place, so generation work can be batched and
prioritised. Per-game detail lives in `games/<id>/docs/ASSET_MANIFEST.md`.

## Policy

1. **Placeholders first, always.** Unresolved asset keys fall back to a
   placeholder (magenta box in fps, flat colour in iso). Nothing crashes, and
   gaps are visible. A game must be fully playable on placeholders before any
   real art is commissioned.
2. **Keys, not paths.** Data references logical keys (`unit.hollow_minor`);
   `assets.json` maps keys to `res://` paths. Art can be swapped without
   touching game data.
3. **The Meshy pipeline costs money.** `tools/generate_assets/` drives Blender
   plus the paid Meshy API. It is **opt-in only** and never run by an agent
   without explicit approval.
4. **Mechanic-critical art first.** In each game one asset carries a mechanic
   that cannot be understood without it. That is always the first thing built.

## Per game

| Game | Engine | Mechanic-critical asset | Generation route |
|---|---|---|---|
| `zork` | fps | rooms + props (largely done) | hand-built `.tscn` |
| `aevum` | isometric | clan unit models (partly done) | Meshy + Blender (existing cache) |
| `paragon` | isometric | shrines, virtue statues | `gen_placeholders.py` → Meshy later |
| `hollow_ledger` | isometric | **Weight overlays / chalk marks** | decals + tint; `gen_placeholders.py` |
| `chorus` | isometric | **the Chalkboard UI** | 2D UI; hand-built |
| `wardens` | fps | **Sap-Blade blend shapes** | Blender sculpt; two extremes |

## The three new games — why these choices

**`wardens` — blend shapes, not swapped meshes.** The blade must be unique per
playthrough and continuously expressive ("no menu, no meter"). Discrete variants
cannot do that; one mesh with a `growth_vector`-driven morph can. Authoring
discrete blades would quietly kill the core mechanic.

**`hollow_ledger` — debt rendered on the world.** Tally-Chalk makes obligations
visible in-fiction, so Weight is decals and tinting, not a HUD number. Target:
a collector's town and a forgiver's town are distinguishable from one
screenshot, with no UI showing.

**`chorus` — the city is the scoreboard.** Recitations rewrite district
dressing. Testimony fidelity (faithful/softened/sharpened) is **one shader
parameter**, not three sprite sets, so the mechanic is testable long before
final art.

## Batch order

1. Placeholder passes for all three new games (script-generated, minutes)
2. `chorus` Chalkboard UI — it *is* the game, and it is cheap
3. `hollow_ledger` Weight overlays — three alpha levels is enough to start
4. `wardens` Sap-Blade base + two blend shapes — the only genuinely 3D-hard item
5. Environment/tile sets
6. Actor variants

## Templates to fill

- `games/wardens/docs/ASSET_MANIFEST.md`
- `games/hollow_ledger/docs/ASSET_MANIFEST.md`
- `games/chorus/docs/ASSET_MANIFEST.md`

Each has a `Status` column (`TODO` / `PLACEHOLDER` / `FINAL`) and a `Path`
column to fill as art lands. Keep them in sync with the package's
`assets.json` — `validate_data.py` warns on every key that has no entry.
