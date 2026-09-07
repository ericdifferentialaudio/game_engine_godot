# 06 · Sites & Interactions

## Sites (`sites.json`)
A **Site** is a point of interest bound to a tile: village, city, ruins, shrine, dungeon
entrance, monster camp, resource node, encounter. Per-faction **discovery** (first sight or
entry → `discover_intel`), **visibility gating** (`hidden_until` query; an undiscovered
crypt is not even drawn), **entry gating** (`enter_requires`), **ownership/capture**
(`owner`, `capturable`, `rules.sites.capture_on_enter`), **yields** to the owner at UPKEEP,
**spawns** (`unit, faction, count, radius, respawn_turns`) and an ordered list of
**interactions** that run when a unit enters (`Site.on_unit_entered`).

Placement: `coord` (nudged to nearest land if the generator put water there) or
`placement: random_land`. Visual: `AssetRegistry.instance_scene(visual)` → placeholder
marker if missing; the placeholder shows the site name.

Per-site state (once-flags, owner, discovered_by, shop counts) lives in
`WorldManager.map_states[map]["sites"][site]` and persists across descent and saves.

## Interactions — the universal effect primitive
Interaction specs appear in: site `interactions`, dialogue node `effects`, item
`use_effects`, ability `effects`, intel token `effects`, combat `on_victory`.

Common keys: `requires` (query), `flags`, `faction_flags`, `once`, `once_per_faction`,
`consumes` (stop the chain, default true), `message`.

| kind | does |
|---|---|
| `intel` | grant `tokens` (channel, reliability override, perception bonus); `debunk`; `forget` |
| `reward` | `resources` (faction), `items` (`to: actor|stockpile`), `stat_delta`, `status`, `xp`, `heal_full`, `set_flags`, `set_faction_flags` |
| `shop` | open a `Shop` (intel-gated stock, limited counts, `buys_intel`) for the player |
| `dialogue` | branching nodes; each node may `grant_intel`, `set_flags`, run `effects`; choices gated by `requires`; headless auto-walk for AI |
| `portal` | `descend` to `target_map`/`target_coord` or `ascend`, carrying the acting stack |
| `spawn` | spawn `unit` × `count` for `faction` (or `actor`) within `radius` |
| `combat` | fight `nearest_enemy` or a spawned `guardian`; `on_victory` effects |
| `flag` | set/clear global flags, faction flags, `quest {id, stage}`, diplomacy `stance`, `share_intel` |

Register custom kinds with `InteractionFactory.register(kind, script)`; subclass
`Interaction` and implement `_execute(holder, actor, target)`.

## Dialogue presentation
Logic lives in `DialogueInteraction`; presentation in any node in group `dialogue_ui`
implementing `open(dialogue)`. The reference HUD provides one. Shops likewise use group
`shop_ui` with `open(shop, buyer)`.
