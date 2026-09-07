# Example Realm (Isometric) — reference package

Hex overworld (32×22, noise-generated, seed 1337), two civs (Reachfolk = you, Greywood = AI),
a neutral village faction and hostile Wilds. Demonstrates every engine hook:

**Intel chain to the hidden dungeon**
1. Visit **The Old Mill** → observe `rumor_crypt_west` (0.5).
2. Talk to **Elder Maren** in Hollowmere → `rumor_crypt_reeds`; ask about trade → `rumor_marrow_smuggles` (password).
3. Read the **Standing Stones** → `ruin_inscription`.
   → derivation `triangulate_crypt` grants `crypt_location` at 0.65 … which reveals the
   **Sunken Crypt** site (hidden_until ≥ 0.6) and 2 tiles around it.
   *Or* buy the **Smuggler's Tide Chart** (shop stock gated by the password token) and
   *read* it (item `use_requires` the password) for `crypt_location` at 0.8.
4. Enter the crypt (portal, depth 1) → shrine sets `vault_visited` → stairs (depth 2) →
   fight the **Bone Warden**; its defeat grants the true schedule and debunks the drunk's lie.

**Other systems shown**: wolf den with respawns, warrior/scout sighting intel, `on_combat`
intel, trade-partner gossip spread, border chatter spread, faction starting intel, shop
that buys intel, a hero with equipment + perception, eras, sequential turns.

Files: `game.json` · `terrains.json` · `maps.json` · `units.json` · `items.json` ·
`factions.json` · `intel.json` · `intel_rules.json` · `sites.json` · `ai_profiles.json` · `assets.json`.

```
python tools\validate_data.py games\example_realm_iso
tools\godot.ps1 smoke example_realm_iso
tools\godot.ps1 run example_realm_iso
```
