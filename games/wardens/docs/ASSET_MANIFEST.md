# Asset manifest — Wardens of the Verdant Hush

**Graphics mode:** 3D first-person (Forward+). **Engine:** `game_api/fps/`

> Template. Fill the `Status` and `Path` columns as art lands. Every logical key
> here must exist in `games/wardens/assets.json`; unresolved keys fall back to
> `framework/rendering/placeholder_prop.tscn` (magenta box), so nothing crashes
> and gaps stay visible.

## The one asset decision that defines this game

The Sap-Blade **is the UI**. The concept is explicit: "no menu, no meter, just a
blade that looks different depending on what you fed it." So the blade must not
be a set of swapped meshes — it must be **one base mesh driven by blend shapes**
along a continuous `growth_vector` (aggressive ↔ supportive).

This matters because the blade is described as unique per playthrough. You
cannot author 30 discrete blades; you can author two extremes and interpolate.
Authoring discrete variants instead would quietly kill the core mechanic.

| Requirement | Value |
|---|---|
| Base mesh | one, rigged, first-person scale |
| Blend shapes | `bloom_aggressive`, `bloom_supportive`, `feral_overgrowth` |
| Driven by | `growth_vector` float −1.0 … +1.0 (public; factions read it) |
| Authoring | Blender; two sculpted extremes + a feral variant |

## Weapon & armour

| Key | Type | Description | Status |
|---|---|---|---|
| `weapon.sapblade.base` | mesh+shapes | first-person Sap-Blade, blend-shape driven | TODO |
| `weapon.sapblade.bloom_aggressive` | blendshape | barbed, dark resin, asymmetric | TODO |
| `weapon.sapblade.bloom_supportive` | blendshape | broad, pale, leaf-like | TODO |
| `weapon.sapblade.feral` | blendshape | overgrown, unstable; drives the feral state | TODO |
| `armor.widow_bark` | mesh | bark armour; memory-bleed VFX hook | TODO |
| `vfx.feed.resin_marrow` | particles | dark, viscous feeding | TODO |
| `vfx.feed.hush_milk` | particles | pale, luminous feeding | TODO |
| `vfx.memory_bleed` | shader | Widow Bark overwriting player memory | TODO |

## World — the Turning is a global shader parameter

The Hush's transformation is the act timer, and it should be readable without
any HUD. One global parameter (`turning_progress`, 0…1) should drive canopy
density, palette and light. Cheapest high-impact art in the game.

| Key | Type | Description | Status |
|---|---|---|---|
| `env.hush.early` | environment | desaturated green, dense canopy | TODO |
| `env.hush.mid` | environment | violet bioluminescence creeping in | TODO |
| `env.hush.late` | environment | fully transformed, alien | TODO |
| `prop.sapkin_tree` | scene | the network trees; modular | TODO |
| `prop.sapkin_node` | scene | interactable network node | TODO |
| `terrain.hush_floor` | material | forest floor, `turning_progress`-driven | TODO |

## Actors

| Key | Type | Description | Status |
|---|---|---|---|
| `actor.corrupted_wildlife` | scene | Resin Marrow source; 2–3 variants | TODO |
| `actor.bough_warden` | scene | preservation faction | TODO |
| `actor.turning_faithful` | scene | release faction | TODO |
| `actor.sapless` | scene | anti-Warden humans; no living weapon | TODO |

## Placeholder plan (now)

1. `framework/rendering/placeholder_prop.tscn` for every prop.
2. Sap-Blade: a stretched box whose scale/colour tracks `growth_vector` — ugly,
   but it proves the mechanic end-to-end before any art exists.
3. Environments: three `.tres` presets differing only in colour.

**Do not call the Meshy pipeline** (`tools/generate_assets/`) without explicit
approval — it uses a paid API.

## Production order

1. Sap-Blade base + two blend shapes ← *the game does not read without this*
2. `turning_progress` environment ramp
3. Corrupted wildlife (the feeding loop)
4. Faction actors
5. Widow Bark + memory VFX
