# Asset manifest — The Hollow Ledger

**Graphics mode:** 2D isometric, turn-based. **Engine:** `game_api/isometric/`

> Template. Fill `Status` and `Path` as art lands. Every key must exist in
> `games/hollow_ledger/assets.json`; unresolved keys use a placeholder, so
> missing art never crashes and gaps stay obvious.

## The defining visual: debt is visible

Tally-Chalk "inscribes a debt directly onto a person, wall, or object, making it
visible and trackable to anyone who can read it." So Weight is **not** a HUD
number — it is rendered on the world.

The test this art must pass: **a collector's Emberreach and a forgiver's
Emberreach should be distinguishable from a single screenshot**, with no UI
visible. That is the whole point of tracking a debt graph instead of a morality
meter, and it is cheap to achieve with decals and tinting.

| Key | Type | Description | Status |
|---|---|---|---|
| `overlay.weight.low` | decal | faint soot on tile/actor | TODO |
| `overlay.weight.mid` | decal | visible tarnish | TODO |
| `overlay.weight.high` | decal | heavy, near-curdling | TODO |
| `overlay.chalk_mark` | decal | Tally-Chalk glyph; persistent | TODO |
| `overlay.resolution.repaid` | icon | settled cleanly | TODO |
| `overlay.resolution.forgiven` | icon | permanent faint trace | TODO |
| `overlay.resolution.forced` | icon | Seal scar + Hollow residue | TODO |
| `overlay.resolution.sold` | icon | transferred to a broker | TODO |

## Hollows

Spectral entities built from unresolved Weight. Forced closures leave fragments
that **accrete in place** — the town becomes a record of your audit style.

| Key | Type | Description | Status |
|---|---|---|---|
| `unit.hollow_fragment` | sprite | residue from a forced closure | TODO |
| `unit.hollow_minor` | sprite | small, recent Hollow | TODO |
| `unit.hollow_generational` | sprite | the Act III town-scale threat | TODO |
| `vfx.hollow_birth` | animation | Weight curdling into a Hollow | TODO |

## Tiles & town (Emberreach)

| Key | Type | Description | Status |
|---|---|---|---|
| `tile.emberreach_street` | tile | fringe-town cobble | TODO |
| `tile.ledgerhouse_floor` | tile | institutional stone | TODO |
| `tile.ash_waste` | tile | outskirts | TODO |
| `site.ledgerhouse` | scene | the Auditors' seat | TODO |
| `site.debt_broker` | scene | black-market stall | TODO |
| `site.debt_free_camp` | scene | the memory-erasing cult | TODO |

## Items

| Key | Type | Description | Status |
|---|---|---|---|
| `icon.item.tally_chalk` | icon | inscribes visible debt | TODO |
| `icon.item.promissory_coin` | icon | minted from forgiven debt | TODO |
| `icon.item.auditors_seal` | icon | forces a ledger entry closed | TODO |
| `icon.item.unspent_name` | icon | uncollected debt; draws Hollows | TODO |

## Actors

| Key | Type | Description | Status |
|---|---|---|---|
| `unit.tallykeeper` | sprite | the player | TODO |
| `unit.high_auditor` | sprite | wants the books balanced, however cruel | TODO |
| `unit.debt_broker` | sprite | treats Weight as a commodity | TODO |
| `unit.debt_free` | sprite | ritually unaccountable | TODO |
| `unit.townsfolk` | sprite | 6–8 debtor variants | TODO |

## Placeholder plan (now)

`game_api/isometric/tools/gen_placeholders.py` generates coloured tiles and
unit sprites. For Weight, three flat alpha levels of a dark overlay carry the
entire read until real art lands — genuinely sufficient for playtesting.

## Production order

1. Weight overlays + chalk marks ← *the core mechanic is invisible without these*
2. Hollow fragments and the birth animation
3. Emberreach tiles and sites
4. Item icons
5. Actor variants
