# Asset manifest — The Chorus of Unspoken Names

**Graphics mode:** 2D isometric, dialogue-dense investigation.
**Engine:** `game_api/isometric/`

> Template. Fill `Status` and `Path` as art lands. Every key must exist in
> `games/chorus/assets.json`; unresolved keys use a placeholder.

## Why isometric and not first-person

`CONCEPT.md` offers FPS as an alternative. Declined, for a mechanical reason:
the core loop is a *"persistent hub-city that visibly changes based on what you
tell it."* The player must **see the city change**, which means seeing a lot of
it at once. First-person hides civic-scale change behind a 60° cone.

## The city is the scoreboard

Verrow is built atop seven buried cities. Build it in literal strata and use
`max_map_depth` + `CoreMapDefinition` portals (overworld → district → interior
→ vault). The Seventh City's Key opens a testimony vault *beneath* the city —
the vertical structure is the story.

After each Recitation, district dressing is rewritten to match what the city now
believes. This is the game's only scoreboard and it must read at a glance.

| Key | Type | Description | Status |
|---|---|---|---|
| `tile.verrow_street.layer7` | tile | current city surface | TODO |
| `tile.verrow_street.layer6` | tile | the most recent buried city | TODO |
| `tile.vault_floor` | tile | the testimony vault | TODO |
| `dressing.banner.loyalist` | decal | Founders' Loyalists ascendant | TODO |
| `dressing.banner.digger` | decal | Diggers ascendant | TODO |
| `dressing.banner.chorus` | decal | institutional neutrality | TODO |
| `dressing.memorial.true` | prop | plaque matching the examined account | TODO |
| `dressing.memorial.comfortable` | prop | plaque matching the softened account | TODO |
| `dressing.graffiti.dispute` | decal | the city arguing with itself | TODO |

## Testimony fidelity — a visual grammar

The record/soften/sharpen mechanic needs to be legible **without text**. One
grammar, applied consistently to portraits, chalkboard entries and the
Recitation itself:

| Fidelity | Treatment | Key |
|---|---|---|
| Faithful | sharp edges, neutral colour, full detail | `fidelity.faithful` |
| Softened | hazy bloom, warm tint, detail sanded off | `fidelity.softened` |
| Sharpened | high contrast, cold tint, harsh silhouette | `fidelity.sharpened` |

Implement as a shader with one `fidelity` parameter, not three sprite sets.

## The Chalkboard (highest-value UI)

Cross-referencing contradictory accounts side by side is the actual game. It is
UI-heavy, cheap to build, and should be prototyped **before** any world art.

| Key | Type | Description | Status |
|---|---|---|---|
| `ui.chalkboard.frame` | texture | the board itself | TODO |
| `ui.chalkboard.entry` | 9-patch | one testimony card | TODO |
| `ui.chalkboard.link_agree` | line | corroboration between accounts | TODO |
| `ui.chalkboard.link_conflict` | line | contradiction between accounts | TODO |
| `ui.recollection_horn` | icon | record / edit / broadcast instrument | TODO |

## Items & actors

| Key | Type | Description | Status |
|---|---|---|---|
| `icon.item.recollection_horn` | icon | the Namesayer's instrument | TODO |
| `icon.item.ledger_bead` | icon | one memory fragment | TODO |
| `icon.item.seventh_key` | icon | opens the testimony vault | TODO |
| `unit.apprentice` | sprite | the player | TODO |
| `unit.namesayer` | sprite | the divided institution | TODO |
| `unit.loyalist` | sprite | wants the comforting myth | TODO |
| `unit.digger` | sprite | wants every truth exposed | TODO |
| `unit.witness` | sprite | 8–10 testimony-holder variants | TODO |

## Placeholder plan (now)

`gen_placeholders.py` for tiles and units. The fidelity grammar can ship as
three flat colour tints long before final art — it is a shader parameter, so
the mechanic is fully testable immediately.

## Production order

1. Chalkboard UI ← *this is the game; build it first*
2. Fidelity shader (three tints is enough to start)
3. District dressing sets (the visible consequence of a Recitation)
4. Strata tiles + vault
5. Actor variants
