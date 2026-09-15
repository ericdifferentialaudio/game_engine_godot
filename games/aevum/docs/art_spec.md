# art_spec.md — Aevum: Age of Shrines
# Complete Graphic Asset Production Bible

## Version 1.0 — For AI-Assisted Generation (Nano Banana / Stable Diffusion / Midjourney)

---

## Table of Contents

1. [Overview & Approach](#1-overview--approach)
2. [File Format & Naming Convention](#2-file-format--naming-convention)
3. [Spritesheet Assembly](#3-spritesheet-assembly)
4. [Terrain Ground Tiles](#4-terrain-ground-tiles)
5. [Terrain Feature Sprites (3D Elements)](#5-terrain-feature-sprites-3d-elements)
6. [Ambient Creature Sprites](#6-ambient-creature-sprites)
7. [Unit Animation Spec](#7-unit-animation-spec)
8. [Shared Unit Art (All Clans)](#8-shared-unit-art-all-clans)
9. [Unique Unit Art — Per Clan](#9-unique-unit-art--per-clan)
10. [Dragon & Special Entities](#10-dragon--special-entities)
11. [Monsters](#11-monsters)
12. [Spell & Combat FX](#12-spell--combat-fx)
13. [UI Elements](#13-ui-elements)
14. [AI Prompt Templates](#14-ai-prompt-templates)
15. [Priority Build Order](#15-priority-build-order)
16. [Full Frame Count Summary](#16-full-frame-count-summary)

---

## 1. Overview & Approach

### Visual Style
**Civilization VI isometric perspective** — camera at approximately 30° from horizontal,
looking toward the southeast. The world has depth: mountains rise above the hex floor,
forests have visible canopy, units are isometric figures (not flat tokens).

**Art style:** Warm painterly fantasy illustration. Rich colours, dramatic lighting from
upper-left. Clean readable silhouettes at small sizes. NOT pixel art — painted style.

### Clan Colour Tinting (Reduces Art Workload by ~70%)
The GLSL unit shader automatically applies clan colour:
```glsl
token.rgb = mix(token.rgb, clan_color.rgb, 0.65);
```
This means **all units are drawn in NEUTRAL grey/cream tones**. The engine recolours them
per clan at runtime. You never produce 12 coloured versions of the same unit.

Only draw the silhouette, detail, and form. Leave base colouring neutral.

### Individual PNGs → Assembled Spritesheets
- **You produce:** individual PNG frames (one image per animation frame)
- **Build script assembles:** horizontal strip spritesheet per animation state
- **Engine loads:** spritesheets at runtime
- **Advantage:** Regenerate one bad frame without remaking the whole strip

### Design DNA — Three-Way Creative Fusion

Aevum is built at the intersection of three landmark games. Every art decision should
honour all three simultaneously:

| Game | What it contributes to Aevum |
|------|------------------------------|
| **Civilization VI** | The isometric hex map, empire-building strategy layer, animated living world, distinct factions with real personality. The visual *frame* everything exists within. Readable silhouettes at small scale. A world that looks worth exploring from above. |
| **Ultima IV** | The philosophy and soul. The goal is *found* not *fought* — the Dragon Egg is this game's Codex of Ultimate Wisdom. Shrines replace Virtue Shrines. Towns have real characters with real dialogue. The world carries moral weight and mystery. There is no villain to kill; there is a truth to uncover. |
| **World of Warcraft** | Class identity is **iconic and unmistakable**. A Rogue looks like a Rogue at any size. Faction aesthetics are cohesive and deeply characterised — each clan should feel as distinct as a WoW race. Animations have real weight and impact: when a Shaman casts a lightning storm it *feels* like it landed. The Dragon has raid-boss energy wrapped in a strategy game shell. |

**For artists — the three-way test:**
> *"Does this unit's silhouette read clearly at 64×96px? (CIV6 test)*  
> *Does this world feel worth exploring and full of secret meaning? (Ultima IV test)*  
> *Does this class look iconic enough that a player would tattoo it on their arm? (WoW test)"*

If yes to all three: you're on target.

**Colour palette guidance (WoW-informed, Civ6-applied):**
- Saturated but grounded — not pastel, not grimdark
- Warm yellows and golds for sacred/holy elements
- Deep purples and blacks for necromantic/shadow elements
- Rich greens and earth tones for nature/wild elements
- Steel blues and silvers for arcane/elven elements
- Warm reds and oranges for warrior/fire elements
- The world map itself: lush, readable, inviting — like a living illustrated map

---

## 2. File Format & Naming Convention

### Directory Structure
```
assets/graphics/
  terrain/
    ground/          ← hex floor tiles (80×46 px)
    features/        ← tall 3D elements (64×128 px or varied)
  ambient/           ← flying creatures and particles
  units/
    shared/          ← Scout, Archer, Seeker, Workers, Diplomat
    fighter/         ← Chieftain, Clan Unit, Specialty
    mage/
    cleric/
    dwarf/
    ranger/
    elf/
    rogue/
    monk/
    druid/
    necromancer/
    bard/
    shaman/
  dragon/
  monsters/
  fx/                ← spell and combat effects
  ui/                ← interface elements
```

### File Naming Convention
```
{subject}_{state}_{frame:02d}.png

Examples:
  plains_v1.png                     ← terrain variant 1, static
  grasslands_idle_03.png            ← grasslands frame 03 of ambient anim
  ranger_chieftain_walk_se_05.png   ← ranger chieftain walk SE direction frame 5
  shared_scout_attack_02.png        ← shared scout attack frame 2
  dragon_breath_07.png              ← dragon breath FX frame 7
  fx_fireball_03.png                ← fireball impact frame 3
```

### States / Direction Suffixes
| Suffix | Meaning |
|--------|---------|
| `_idle` | Standing/breathing loop |
| `_walk_se` | Walking toward camera-right (SE hex direction) |
| `_walk_e` | Walking right profile (E hex direction) |
| `_walk_ne` | Walking away-right (NE hex direction) |
| `_attack` | Attack animation (played once) |
| `_hit` | Taking damage (played once) |
| `_death` | Death collapse (played once, hold last frame) |
| `_defend` | Defensive stance (loop while defending) |
| `_meditate` | Meditation at shrine (loop) |
| `_cast` | Spell casting gesture (magic units only) |
| `_work` | Build/farm/mine action (workers only) |
| `_gesture` | Diplomat speaking gesture |

**Mirror rule:** The engine automatically mirrors `_walk_se` → `_walk_nw`, `_walk_e` → `_walk_w`,
`_walk_ne` → `_walk_sw`. You never produce the left-direction variants.

> ⚠️ **SUPERSEDED FOR 3D-RENDERED ASSETS (08/2026).** This mirror rule is
> **invalid** when sprites are rendered from Meshy/3D models: those models are
> not bilaterally symmetric, so a horizontal flip swaps the weapon hand and
> jumps asymmetric detail. All **6** hex directions must be rendered
> (`_e _se _sw _w _nw _ne`).
>
> Note also that **this mirroring was never implemented** — there is no
> sprite-flipping code in `engine/` or `tools/`. Every frame-count figure in
> this document is therefore understated for the walk states.
>
> See **`doc/GRAPHICS_PIPELINE_3D_TO_SPRITE.md`** for the corrected direction
> count, canvas size, render/VRAM budgets and the full correction table.
> The rest of this document — art direction, archetypes, clan tinting, terrain
> and feature descriptions — remains current.

---

## 3. Spritesheet Assembly

The `tools/build_spritesheets.py` script (written by the engine team) assembles frames
into horizontal strips automatically based on the naming convention.

**Input:** Individual frame PNGs in the correct directory
**Output:** `{subject}_{state}.png` — all frames in a single horizontal strip

```
ranger_chieftain_walk_se_00.png through _07.png
→ assembles to: spritesheets/ranger_chieftain_walk_se.png
   (512×96 px = 8 frames × 64px wide)
```

The engine reads the spritesheet and knows frame count from the image width ÷ frame width.

---

## 4. Terrain Ground Tiles

**Canvas size: 80×46 px per tile**
**Format: RGBA PNG with transparent corners** (the hex shape, not a rectangle)
**Perspective: Point-top hex, viewed from ~30° above — the "floor" face of the hex**

The ground tile is the flat surface the unit stands on. It should look like
looking down at roughly 30° onto grass/stone/mud/etc.

### Terrain Variants

Each terrain type has multiple STATIC variants. At world generation, each hex is
assigned a variant based on seed — neighbouring hexes never look identical.

#### Plains — 5 variants, 1 frame each
| File | Description |
|------|-------------|
| `plains_v1.png` | Even short grass, soft yellow-green tones |
| `plains_v2.png` | Grass with small wildflowers (white/yellow dots) |
| `plains_v3.png` | Slightly dry grass, more ochre tones, thin soil cracks |
| `plains_v4.png` | Rich green grass, denser, small clover |
| `plains_v5.png` | Wind-flattened look, pale blonde grass |

#### Grasslands — 4 variants × 8 animated frames each
**Animated: 8 fps — wind wave effect**
| File pattern | Description |
|--------------|-------------|
| `grasslands_v1_00.png` – `_07.png` | Tall wildflower meadow, purples and yellows |
| `grasslands_v2_00.png` – `_07.png` | Dense green meadow grass |
| `grasslands_v3_00.png` – `_07.png` | Heather and bracken, purple-brown |
| `grasslands_v4_00.png` – `_07.png` | Mixed meadow with seed heads |

**Total grasslands frames: 32**

#### Forest — 3 variants, 1 frame each (floor only)
The canopy animation is handled by the FEATURE SPRITE above the tile.
The floor tile shows: roots, undergrowth, fallen leaves, forest floor.
| File | Description |
|------|-------------|
| `forest_v1.png` | Dense undergrowth, dark soil, exposed roots |
| `forest_v2.png` | Lighter forest floor, dappled look, leaf litter |
| `forest_v3.png` | Forest edge, mixed undergrowth and grass |

#### Hills — 4 variants, 1 frame each
| File | Description |
|------|-------------|
| `hills_v1.png` | Grey-brown rocky ground, scrub grass |
| `hills_v2.png` | Reddish clay soil, sparse vegetation |
| `hills_v3.png` | Green-topped hill with rocky edges |
| `hills_v4.png` | Dark stone ground, lichen-covered |

#### Mountain — 3 variants, 1 frame each
The floor tile is just the base — the dramatic peak is the FEATURE SPRITE.
| File | Description |
|------|-------------|
| `mountain_v1.png` | Grey shale, frost-edged |
| `mountain_v2.png` | Dark volcanic rock |
| `mountain_v3.png` | Snow-dusted grey stone |

#### Swamp — 3 variants × 6 animated frames each
**Animated: 6 fps — surface ripple and bubble**
| File pattern | Description |
|--------------|-------------|
| `swamp_v1_00.png` – `_05.png` | Dark murky water, algae patches |
| `swamp_v2_00.png` – `_05.png` | Greenish-brown bog, lily pads |
| `swamp_v3_00.png` – `_05.png` | Grey-brown fen, dead reeds |

**Total swamp frames: 18**

#### Sacred — 2 variants × 8 animated frames each
**Animated: 10 fps — magical energy pulse (also enhanced by GLSL shader)**
| File pattern | Description |
|--------------|-------------|
| `sacred_v1_00.png` – `_07.png` | Ancient stone circle, glowing runes |
| `sacred_v2_00.png` – `_07.png` | Ritual ground, carved symbols, purple mist |

**Total sacred frames: 16**

### Terrain Ground Tile Summary
| Terrain | Variants | Frames/variant | Total frames |
|---------|----------|----------------|-------------|
| Plains | 5 | 1 | 5 |
| Grasslands | 4 | 8 | 32 |
| Forest | 3 | 1 | 3 |
| Hills | 4 | 1 | 4 |
| Mountain | 3 | 1 | 3 |
| Swamp | 3 | 6 | 18 |
| Sacred | 2 | 8 | 16 |
| **TOTAL** | **24** | | **81 frames** |

---

## 5. Terrain Feature Sprites (3D Elements)

These are TALL sprites drawn ON TOP of the ground tile, extending upward.
They are isometric — you can see the side/face of the terrain element.
Background: fully transparent.

### Forest Canopy
**Canvas: 80×128 px** (wider than hex to allow canopy overlap into adjacent hexes)
**Animated: 6 fps — gentle canopy sway, 6 frames**

| File pattern | Description |
|--------------|-------------|
| `feature_forest_dense_00.png` – `_05.png` | Dense pine/oak canopy, dark green |
| `feature_forest_medium_00.png` – `_05.png` | Mixed deciduous canopy, medium green |
| `feature_forest_edge_00.png` – `_05.png` | Sparse trees, lighter, visible trunks |

Draw the trees as isometric 3D shapes — visible trunks at base, canopy above.
The bottom 40px anchors to the hex floor; trees extend 88px above.

**Forest feature total: 18 frames**

### Hills Rock Formation
**Canvas: 64×80 px — static, 1 frame**

| File | Description |
|------|-------------|
| `feature_hills_v1.png` | Rounded rocky bump, grey-brown stone |
| `feature_hills_v2.png` | Craggy rock outcropping, reddish |
| `feature_hills_v3.png` | Low grassy hill with rocks at crest |

### Mountain Peak
**Canvas: 96×192 px — static, 1 frame** (extends very high above the hex)

| File | Description |
|------|-------------|
| `feature_mountain_v1.png` | Classic snow-capped grey mountain peak |
| `feature_mountain_v2.png` | Dark volcanic peak, no snow |
| `feature_mountain_v3.png` | Jagged stone peak, pale grey |

These are dramatic — they should be visually dominant. The peak extends well above
the ground tiles in adjacent rows.

### Ruins-Style Artifact Markers
**Ruins is NOT a terrain type (removed v0.8). The ruins art style is repurposed as
artifact hex overlays** — drawn on top of existing terrain (Plains/Hills hexes) to
mark artifact locations. Transparent overlay, anchored at hex center.

**Canvas: 64×96 px — static, 1 frame each**

| File | Description |
|------|-------------|
| `icon_artifact_ruins_v1.png` | Crumbling column, weathered stone |
| `icon_artifact_ruins_v2.png` | Ruined archway fragment, vines |
| `icon_artifact_ruins_v3.png` | Low broken wall section |
| `icon_artifact_ruins_v4.png` | Ancient standing stone, lichen-covered |

These are drawn in the map overlay icon pass (same as `icon_shrine_*.png`), not in
the terrain feature pass. 4 static PNGs — no animation needed.

### Swamp Feature (Dead Trees / Gas Vents)
**Canvas: 64×96 px — 4 animated frames, 6 fps**

| File pattern | Description |
|--------------|-------------|
| `feature_swamp_trees_00.png` – `_03.png` | Dead twisted trees, hanging moss |
| `feature_swamp_mist_00.png` – `_03.png` | Rising murk/gas vent with particles |

### Sacred Ground Pillar
**Canvas: 64×128 px — 8 animated frames, 10 fps**

| File pattern | Description |
|--------------|-------------|
| `feature_sacred_pillar_00.png` – `_07.png` | Glowing ancient monolith, pulsing runes |
| `feature_sacred_circle_00.png` – `_07.png` | Ritual stone circle, rising energy motes |

### Feature Sprite Summary
| Feature | Frames | Total |
|---------|--------|-------|
| Forest canopy (3 variants) | 6 each | 18 |
| Hills rocks (3 variants) | 1 each | 3 |
| Mountain peaks (3 variants) | 1 each | 3 |
| Swamp features (2 variants) | 4 each | 8 |
| Sacred pillars (2 variants) | 8 each | 16 |
| Artifact markers (ruins-style, 4 static) | 1 each | 4 |
| **TOTAL** | | **49 frames** |

---

## 6. Ambient Creature Sprites

Rare atmospheric events that fly across visible terrain.
All on transparent backgrounds. These are SMALL — drawn quickly.
The engine places them at world positions and animates them crossing the screen.

### Small Bird (Plains / Grasslands)
**Canvas: 20×12 px — 4 frames, 16 fps**
Files: `ambient_bird_small_00.png` – `_03.png`
Description: Tiny silhouette bird, wings up/down cycle. Can tint slightly different browns.

### Bird Flock (Plains)
**Canvas: 48×24 px — 4 frames, 14 fps**
Files: `ambient_bird_flock_00.png` – `_03.png`
Description: 5-8 tiny birds in loose formation, all flapping slightly out of sync.

### Eagle / Hawk (Hills)
**Canvas: 52×20 px — 4 frames, 8 fps**
Files: `ambient_eagle_00.png` – `_03.png`
Description: Wide-wingspan raptor in soaring pose. Slow wing beats.

### Forest Bird (Forest)
**Canvas: 18×14 px — 4 frames, 14 fps**
Files: `ambient_forest_bird_00.png` – `_03.png`
Description: Small bright bird, quick flutter.

### Sacred Mote (Sacred ground)
**Canvas: 8×8 px — 4 frames, 10 fps**
Files: `ambient_sacred_mote_00.png` – `_03.png`
Description: Tiny glowing orb, soft pulse. Floats upward slowly.

### Mountain Cloud Shadow
Not a sprite — handled by shader (darkening pass across mountain hexes).
No art needed.

### Ambient Creature Summary
| Creature | Canvas | Frames | Total |
|----------|--------|--------|-------|
| Small bird | 20×12 | 4 | 4 |
| Bird flock | 48×24 | 4 | 4 |
| Eagle/hawk | 52×20 | 4 | 4 |
| Forest bird | 18×14 | 4 | 4 |
| Sacred mote | 8×8 | 4 | 4 |
| **TOTAL** | | | **20 frames** |

---

## 7. Unit Animation Spec

> ⚠️ **PARTIALLY SUPERSEDED FOR 3D-RENDERED ASSETS (08/2026).**
> This section assumes **3 walk directions** plus engine mirroring, and a
> **64×96 px** canvas. For Meshy/3D-sourced sprites both are wrong:
> **6 directions** must be rendered (no mirroring — the models are asymmetric),
> and the render target should be the **128 px** class, downscaled by the GPU
> for the smaller zoom levels.
> Consequently every "N frames per unit" total below is understated.
> See **`doc/GRAPHICS_PIPELINE_3D_TO_SPRITE.md`**.
> The *state definitions, FPS values and play modes* in this section remain
> correct and should still be followed.

### Canvas Size
| Unit Category | Canvas per frame | Anchor point |
|---------------|-----------------|--------------|
| Standard units (all except workers) | **64×96 px** | Bottom-center of canvas = hex floor point |
| Workers (Farmer, Miner, Forester) | **48×72 px** | Bottom-center |
| Chieftains (more detailed) | **64×96 px** | Same as standard |
| Dragon | **192×256 px** | Bottom-center |
| Monsters T1 | **64×96 px** | Standard |
| Monsters T2 | **80×112 px** | Larger |
| Monsters T3 | **96×128 px** | Boss-size |

### Viewing Angle
All units drawn from **isometric 3/4 view**: camera is above-left, looking toward
the lower-right. The unit faces slightly toward camera. This matches the terrain
perspective.

For walk directions:
- `_walk_se`: Unit moving toward lower-right (toward the viewer, slightly right)
- `_walk_e`: Unit moving to the right (profile view, right side visible)
- `_walk_ne`: Unit moving toward upper-right (away from viewer, slightly right)

### Animation States — Full Definition

| State | Frames | FPS | Play mode | Description |
|-------|--------|-----|-----------|-------------|
| `idle` | 6 | 8 | Loop | Relaxed standing, subtle weight shift. Breathing movement. |
| `walk_se` | 8 | 12 | Loop | Walking toward camera+right. Full foot cycle. |
| `walk_e` | 6 | 12 | Loop | Walking right, profile. |
| `walk_ne` | 6 | 12 | Loop | Walking away+right. Slightly foreshortened. |
| `attack` | 8 | 14 | Once | Wind up → strike → follow through → recover. Frame 4-5 = impact. |
| `hit` | 4 | 16 | Once | Recoil backward. Brief flash/stagger. Frame 2 = peak impact. |
| `death` | 8 | 10 | Once+Hold | Collapse to ground. Frame 8 = fully fallen — hold indefinitely. |
| `defend` | 4 | 10 | Loop | Shield/brace up. Hold frame 4 while being attacked. |
| `meditate` | 6 | 6 | Loop | Seated or kneeling, hands together, soft glow. |
| `cast` | 8 | 12 | Once | Hand/staff raises, energy gathers, release at frame 5-6. |
| `work` | 6 | 8 | Loop | Farming/mining/chopping action. Workers only. |
| `gesture` | 6 | 10 | Once | Speaking/diplomacy gesture. Diplomat only. |

### Which States Per Unit Type

| Unit type | idle | walk×3 | attack | hit | death | defend | meditate | cast | work | gesture |
|-----------|------|--------|--------|-----|-------|--------|----------|------|------|---------|
| Chieftain | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | If magic | — | — |
| Clan Unit | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | If magic | — | — |
| Specialty | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | If magic | — | — |
| Scout | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | — | — |
| Archer | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | — | — |
| Seeker | ✓ | ✓ | — | ✓ | ✓ | — | ✓ | ✓ | — | — |
| Farmer | ✓ | ✓ | ✓ | ✓ | ✓ | — | — | — | ✓ | — |
| Miner | ✓ | ✓ | ✓ | ✓ | ✓ | — | — | — | ✓ | — |
| Forester | ✓ | ✓ | ✓ | ✓ | ✓ | — | — | — | ✓ | — |
| Diplomat | ✓ | ✓ | — | ✓ | ✓ | — | — | — | — | ✓ |

### Frame Count Per Unit (Non-magic)
`6 + (8+6+6) + 8 + 4 + 8 + 4 + 6 = 56 frames`

### Frame Count Per Unit (Magic — has cast)
`56 + 8 = 64 frames`

### Frame Count Per Worker
`6 + (8+6+6) + 4 + 4 + 6 = 40 frames`

### Frame Count Seeker
`6 + (8+6+6) + 4 + 8 + 6 + 8 = 52 frames`

---

## 8. Shared Unit Art — 4-Archetype System

Scout, Archer, and Seeker are produced in **4 distinct archetypes** — one per clan
group — so that a Rogue Archer looks nothing like a Mage Archer.

Workers and Diplomat remain fully shared (one art set, clan colour-tinted).

### Clan → Archetype Mapping

| Archetype | Clans | WoW spirit | Aesthetic |
|-----------|-------|-----------|-----------|
| **Warrior** | Fighter, Dwarf, Ranger | Hunter / Warrior | Armoured, physical, grounded, professional soldier |
| **Arcane** | Mage, Cleric, Elf | Mage / Paladin / Elven Ranger | Robes or light mail with arcane trim, glowing equipment |
| **Shadow** | Rogue, Necromancer, Bard | Rogue / Warlock / Death Knight | Dark wrapped clothing, concealed, sinister purpose |
| **Wild** | Druid, Shaman, Monk | Druid / Shaman / Monk | Natural materials, tribal, no manufactured gear |

Engine note: the clan colour shader differentiates the 3 clans within each archetype.
A Fighter Warrior Archer vs a Dwarf Warrior Archer = same silhouette, different colour tint.

### Common Animation States (all Scout / Archer / Seeker archetypes)

| State | Frames | FPS | Notes |
|-------|--------|-----|-------|
| idle | 6 | 8 | Archetype personality visible even at rest |
| walk_se | 8 | 12 | Engine mirrors → walk_nw |
| walk_e | 6 | 12 | Engine mirrors → walk_w |
| walk_ne | 6 | 12 | Engine mirrors → walk_sw |
| attack | 8 | 14 | Scout: knife/lunge; Archer: draw+release; Seeker: (none) |
| hit | 4 | 16 | Recoil — archetype flavour |
| death | 8 | 10 | Collapse — archetype flavour |
| defend | 4 | 10 | Scout + Archer only |
| meditate | 6 | 6 | All three unit types |
| cast | 8 | 12 | Seeker only |

**56 frames per Scout/Archer archetype | 52 frames per Seeker archetype**

---

## 8a. Scout — 4 Archetypes

**Canvas: 64×96 px | 56 frames per archetype × 4 = 224 frames total**

### Warrior Scout
Files: `warrior_scout_{state}_{frame:02d}.png`
**Clans:** Fighter, Dwarf, Ranger

**Design (WoW: Hunter/Scout):** This scout looks like a soldier on a recon mission.
Heavy leather and chain scout armour — studded leather chest over mail coif.
Practical sallet helm or bare-headed with close-cropped hair. Reinforced greaves
and bracers. Short sword on hip, knife on belt, compact tactical pack. Sturdy,
capable build — this person has marched hundreds of miles. Heavy-footed but efficient.

| State | Visual description |
|-------|-------------------|
| idle | Standing at parade rest, scanning with purpose. Weight evenly distributed. |
| walk_se/e/ne | Military march pace — economical, no wasted motion |
| attack | Low knife thrust, tactical — knife hand strike |
| hit | Stagger back, absorb the blow — trained not to fall |
| death | Controlled drop — soldier's death, knees first |
| defend | Combat crouch, knife raised |
| meditate | Kneeling, sword/knife laid before them |

**AI prompt:**
```
Isometric 3/4 view, 64x96 pixel canvas, Civilization VI painterly style,
military scout in heavy leather and chain armour, studded chest piece, 
sallet helm or bare-headed, short sword at hip, tactical pack,
sturdy capable soldier build, no magic elements, neutral grey tones,
transparent background, clean silhouette, [STATE + FRAME DESCRIPTION]
```

### Arcane Scout
Files: `arcane_scout_{state}_{frame:02d}.png`
**Clans:** Mage, Cleric, Elf

**Design (WoW: Arcane Scout / Silver Covenant Ranger):** This scout observes through
knowledge not stealth. Light robes with arcane-trim travelling coat over linen.
No heavy armour — they rely on wards, not leather. A magical monocle or brass
observation lens on a chain. Elegant bearing — they move deliberately, taking in
everything. Slender build, scholar's hands. Small arcane-sigil pack. This person
is cataloguing the world as they cross it.

| State | Visual description |
|-------|-------------------|
| idle | Consulting arcane lens, robes settling — an observer |
| walk_se/e/ne | Deliberate measured stride, lens in hand |
| attack | Arcane light knife from belt — reluctant fighter |
| hit | Stumble, robes tangling — this person doesn't get hit often |
| death | Graceful fall, robes spreading |
| defend | Ward gesture with off-hand while backing away |
| meditate | Cross-legged, hands open, lens floating before them |

**AI prompt:**
```
Isometric 3/4 view, 64x96 pixel canvas, Civilization VI painterly style,
arcane scout in light travelling robes with arcane trim, magical observation lens
on chain, scholar build, elegant bearing, no armour, small arcane sigil pack,
neutral grey tones, transparent background, clean silhouette, 
[STATE + FRAME DESCRIPTION]
```

### Shadow Scout
Files: `shadow_scout_{state}_{frame:02d}.png`
**Clans:** Rogue, Necromancer, Bard

**Design (WoW: Rogue / SI:7 Agent):** This scout is barely visible. Near-black tight
wraps cover face, hands, and neck. No reflective surfaces — matte everything.
Soft-sole footwear. Two daggers (one visible, one hidden). Small flat pack with
lock picks and coded maps. Permanent low crouch — this figure doesn't stand at full
height when there's any chance of being seen. Eyes only visible, always moving.

| State | Visual description |
|-------|-------------------|
| idle | Absolute stillness broken only by eyes scanning — danger in repose |
| walk_se/e/ne | Gliding crouch-walk, near-silent — weight on balls of feet |
| attack | Blur of daggers — too fast to see clearly |
| hit | Backward roll, recover instantly |
| death | Slow crumple — surprised to have been caught |
| defend | Dodge-and-weave, using environment — minimal posture |
| meditate | Seated, wrapped, unreadable |

**AI prompt:**
```
Isometric 3/4 view, 64x96 pixel canvas, Civilization VI painterly style,
shadow scout entirely in dark matte wraps, face wrapped with eyes visible,
two daggers (one prominent, one concealed), permanent low crouch,
flat worn pack, no reflective surfaces, neutral dark grey tones,
transparent background, clean silhouette, [STATE + FRAME DESCRIPTION]
```

### Wild Scout
Files: `wild_scout_{state}_{frame:02d}.png`
**Clans:** Druid, Shaman, Monk

**Design (WoW: Druid / Tracker):** This scout uses natural instinct over equipment.
Minimal clothing — woven plant fibres, bark strips, animal hide wraps. Barefoot or
minimal soft leather sole. No manufactured gear — everything is natural or carved.
Antler or bone token at neck. Body paint markings for camouflage (hand/arm patterns).
Moves with animal grace — this person IS the wilderness they move through.

| State | Visual description |
|-------|-------------------|
| idle | Still as a deer — part of the landscape, reading the wind |
| walk_se/e/ne | Silent, light-footed — nature walk, not march |
| attack | Bone knife, fast and instinctive |
| hit | Animal-like — flinch and recover, never fully off-balance |
| death | Slow fall, returning to the earth |
| defend | Animal dodge, low and fast |
| meditate | Seated in earth-touch pose, hands on ground |

**AI prompt:**
```
Isometric 3/4 view, 64x96 pixel canvas, Civilization VI painterly style,
wild scout in natural fibres and bark wraps, barefoot or minimal leather sole,
bone/antler neck token, body paint camouflage markings on arms,
no manufactured equipment, moves with animal grace, neutral grey-earth tones,
transparent background, clean silhouette, [STATE + FRAME DESCRIPTION]
```

---

## 8b. Archer — 4 Archetypes

**Canvas: 64×96 px | 56 frames per archetype × 4 = 224 frames total**

This is the highest-impact visual differentiation — the Archer's weapon and draw
style immediately signals their clan group.

### Warrior Archer
Files: `warrior_archer_{state}_{frame:02d}.png`
**Clans:** Fighter, Dwarf, Ranger

**Design (WoW: Hunter / Silverpine Ranger):** Military longbow archer. This person
draws a war bow — heavy, powerful, designed for armoured targets. Chest plate with
leather pauldrons. Sturdy quiver with thick military-grade arrows. Wide powerful
stance — they draw with their whole body, not just their arms. The bow is large,
recurve or longbow. Attack = slow powerful draw → full extension → decisive release.
This archer can put an arrow through plate at range.

**AI prompt:**
```
Isometric 3/4 view, 64x96 pixel canvas, Civilization VI painterly style,
military longbow archer in chest plate and leather pauldrons, war recurve bow,
sturdy arrow quiver, military-grade thick arrows, powerful wide draw stance,
soldier build, neutral grey tones, transparent background, clean silhouette,
[STATE + FRAME DESCRIPTION]
```

### Arcane Archer
Files: `arcane_archer_{state}_{frame:02d}.png`
**Clans:** Mage, Cleric, Elf

**Design (WoW: Farstrider / Arcane Shot Hunter / Holy Paladin):** An archer who
channels magic through each arrow. The bow itself is elegant and slightly magical —
the bowstring has a faint glow. Light arm guards over robes (not full armour).
Arrows glow softly at the tip — enchanted ammunition. Draw stance is precise and
upright — a sniper's pose, not a soldier's. Long, controlled breath before release.
The magic is the ammunition, not the archer's fist.

**AI prompt:**
```
Isometric 3/4 view, 64x96 pixel canvas, Civilization VI painterly style,
arcane archer in light robes with arm guards, elegant bow with faintly glowing
bowstring, arrows glowing at tips, precise upright sniper stance, deliberate
controlled draw, scholar-archer build, neutral grey tones with glow accents,
transparent background, clean silhouette, [STATE + FRAME DESCRIPTION]
```

### Shadow Archer
Files: `shadow_archer_{state}_{frame:02d}.png`
**Clans:** Rogue, Necromancer, Bard

**Design (WoW: Outlaw Rogue with crossbow / Warlock with Shadow Bolt):** Not a longbow
— a compact dark crossbow. Fast-loading, silent-firing. The figure is wrapped in dark
material, hood pulled low. They raise the crossbow and fire in one fluid motion — no
long draw, no wide stance. The attack is fast, quiet, and lethal. Bolts are dark
(iron-tipped, no glow). A collapsed spare crossbow on their back. The deadliest
archer at close range.

**AI prompt:**
```
Isometric 3/4 view, 64x96 pixel canvas, Civilization VI painterly style,
shadow crossbow archer in dark wrapped clothing, compact repeating crossbow raised,
hood and face wrap, dark iron bolts, fast fluid ready stance (no long draw),
second crossbow collapsed on back, minimal profile, neutral dark grey tones,
transparent background, clean silhouette, [STATE + FRAME DESCRIPTION]
```

### Wild Archer
Files: `wild_archer_{state}_{frame:02d}.png`
**Clans:** Druid, Shaman, Monk

**Design (WoW: Troll Hunter / Tauren Druid / Pandaren Monk):** A short, powerful
primitive bow — ash wood, gut string, bone-nocked arrows with spirit feathers.
Tribal wraps on the draw arm. Body paint on visible skin. The draw is fast and
instinctive — shorter draw length, rapid cycling. Arrows fly true because of spirit
guidance, not precision mechanics. Totemic charm on the quiver (feathers, bone).
This archer is at one with the shot — intuitive, natural, deadly in the wilderness.

**AI prompt:**
```
Isometric 3/4 view, 64x96 pixel canvas, Civilization VI painterly style,
wild tribal archer in minimal wraps and hides, short primitive ash-wood bow,
gut bowstring, bone-nocked arrows with spirit feathers, totemic charm on quiver,
body paint on arms, fast instinctive release stance, natural earthy tones,
transparent background, clean silhouette, [STATE + FRAME DESCRIPTION]
```

---

## 8c. Seeker — 4 Archetypes

**Canvas: 64×96 px | 52 frames per archetype × 4 = 208 frames total**

The Seeker is the most important shared unit — the egg-finder. Each archetype's
Seeker should feel distinct in HOW they find the egg: military survey vs. arcane
divination vs. shadow intelligence vs. spiritual communion.

**Extra — Seeker Egg Carrier (4 archetypes):**
Files: `{archetype}_seeker_carry_{state}_{frame:02d}.png`
Each archetype has an idle + walk set with the egg visible in their arms/pack.
26 frames × 4 archetypes = **104 frames total**

### Warrior Seeker
Files: `warrior_seeker_{state}_{frame:02d}.png`
**Clans:** Fighter, Dwarf, Ranger

**Design:** Military surveyor. Worn leather armour with a campaign-quality brass
compass and astrolabe. Rolled survey maps on their back, ink-stained hands.
They find the egg through exhaustive methodical coverage — they've walked every
hex. Cast animation = consulting maps + compass in precise triangulation gesture.

### Arcane Seeker
Files: `arcane_seeker_{state}_{frame:02d}.png`
**Clans:** Mage, Cleric, Elf

**Design:** Mystical diviner. Elegant robes with celestial symbols. A crystal
compass or resonance sphere that reacts to the egg's magical signature.
Very slight hover effect during idle — arcane levitation, barely off the ground.
Cast animation = sphere raised, eyes closed, reading magical flows.

### Shadow Seeker
Files: `shadow_seeker_{state}_{frame:02d}.png`
**Clans:** Rogue, Necromancer, Bard

**Design:** Information operative. Cloaked, identity concealed. They find the egg
through networks and intelligence — a bone compass or dark mirror that reads
residual magic. Cast animation = mirror raised, cryptic gesture — reading death
energy or information flows. Most unsettling of the 4 Seeker types.

### Wild Seeker
Files: `wild_seeker_{state}_{frame:02d}.png`
**Clans:** Druid, Shaman, Monk

**Design:** Spiritual guide. Animal companion nearby (a raven on their shoulder,
or spirit wisps orbiting them). Reading nature signs — migration patterns, sacred
ley convergences. Cast animation = hands pressed to earth, communing with the world's
memory. The most mystical-looking Seeker — least technological, most spiritual.

### Workers (Farmer, Miner, Forester)
**Canvas: 48×72 px | ~40 frames each**
These are humble, smaller than combat units.

#### Farmer
Files: `shared_farmer_{state}_{frame:02d}.png`
**Character:** Simple peasant clothing, wide-brimmed hat, hoe or scythe.
| State | Frames |
|-------|--------|
| idle | 6 |
| walk_se | 8 |
| walk_e | 6 |
| walk_ne | 6 |
| attack | 4 |
| hit | 4 |
| death | 6 |
| work | 6 |
**Total: 46 frames**

#### Miner
Files: `shared_miner_{state}_{frame:02d}.png`
**Character:** Stocky build, leather apron, pickaxe, headlamp (small torch).
Work animation: overhead pickaxe swing.
Same states as Farmer. **Total: 46 frames**

#### Forester
Files: `shared_forester_{state}_{frame:02d}.png`
**Character:** Green-brown working clothes, hand axe or saw, rope on belt.
Work animation: axe chopping/planting motion.
Same states as Farmer. **Total: 46 frames**

### Diplomat
**Canvas: 64×96 px | ~48 frames**
Files: `shared_diplomat_{state}_{frame:02d}.png`

**Character:** Distinguished travelling garb — not armour. Long coat, scroll case,
walking stick. Well-dressed but practical. Carries a sealed letter or scroll.

| State | Frames | Notes |
|-------|--------|-------|
| idle | 6 | Dignified posture, scroll in hand |
| walk_se | 8 | Measured stride |
| walk_e | 6 | Profile |
| walk_ne | 6 | Moving away |
| hit | 4 | Startled stumble (not a fighter) |
| death | 6 | Slow dignified collapse |
| gesture | 6 | Presenting scroll / speaking pose |
**Total: 42 frames**

### Shared Unit Summary

#### Combat units — 4 archetypes each (Warrior / Arcane / Shadow / Wild)
| Unit type | Frames/archetype | Archetypes | Total |
|-----------|-----------------|------------|-------|
| Scout | 56 | 4 | 224 |
| Archer | 56 | 4 | 224 |
| Seeker | 52 | 4 | 208 |
| Seeker (egg carrier) | 26 | 4 | 104 |
| **Combat subtotal** | | | **760** |

#### Workers and Diplomat — fully shared (1 art set, clan-tinted)
| Unit | Frames |
|------|--------|
| Farmer | 46 |
| Miner | 46 |
| Forester | 46 |
| Diplomat | 42 |
| **Worker subtotal** | **180** |

| | |
|-|-|
| **SHARED UNIT TOTAL** | **940 frames** |

---

## 9. Unique Unit Art — Per Clan

Each clan has 3 unique unit types:
- **Chieftain** — the named hero/leader
- **Clan Unit** — the main combat production unit
- **Specialty Unit** — the unique powerful unit

All drawn at **64×96 px**, neutral tones, full animation set (56 or 64 frames depending
on whether the clan has magic).

### Magic clans (get `cast` animation): Mage, Cleric, Elf, Monk, Druid, Necromancer, Bard, Shaman
### Non-magic clans (no `cast`): Fighter, Dwarf, Ranger, Rogue

---

### Fighter Clan (non-magic — 56 frames per unit)

#### Chieftain — "War Commander"
Files: `fighter_chieftain_{state}_{frame:02d}.png`
**Design:** Battle-hardened veteran. Full heavy plate armour, ornate pauldrons, 
battle-scarred great sword (slightly oversized). Cloak in neutral grey. Helm with 
crest. Commanding presence — wider stance than Clan Unit.

| State | Description |
|-------|-------------|
| idle | Standing with sword point-down, surveying field |
| walk_se/e/ne | Heavy purposeful stride, sword at side |
| attack | Two-handed sword sweep — wide arc |
| hit | Stagger, armour dented |
| death | Slow heavy fall, sword clattering |
| defend | Raise sword in guard position |
| meditate | Kneeling, sword flat across arms |

#### Clan Unit — "Heavy Infantry"
Files: `fighter_clan_{state}_{frame:02d}.png`
**Design:** Disciplined soldier. Full plate, kite shield (left arm), longsword (right).
Stockier than Chieftain. Less ornate. Classic foot soldier.

#### Specialty — "Siege Engineer"
Files: `fighter_specialty_{state}_{frame:02d}.png`
**Design:** Practical builder-warrior. Leather and chain armour, tool belt, oversized
warhammer (demolition weapon). Blueprints or schematics rolled under one arm.
Work-hardened hands. Attack = hammer slam. Work animation = hammering/building.

---

### Mage Clan (magic — 64 frames per unit)

#### Chieftain — "Grand Archmage"
Files: `mage_chieftain_{state}_{frame:02d}.png`
**Design:** Ancient and powerful sorcerer. Long deep blue star-patterned robes (draw
in neutral grey — engine tints blue). Towering silver staff topped with floating orb.
Flowing silver beard or hair. Slightly levitated/floating stance.

| State | Description |
|-------|-------------|
| idle | Hovering slightly, orb pulsing, robes drifting |
| walk_se/e/ne | Gliding rather than walking, staff extended |
| attack | Staff thrust forward, energy blast |
| cast | Both arms raised, arcane sigils forming around hands |
| hit | Shockwave, robes billowing |
| death | Slow dissolve — fall forward, orb shatters |
| defend | Ward shimmering in front |
| meditate | Floating cross-legged, eyes closed |

#### Clan Unit — "Battle Mage"
Files: `mage_clan_{state}_{frame:02d}.png`
**Design:** Battle-ready mage. Grey arcane robes with armour plates at shoulders/chest.
Glowing spell book (left hand), focusing crystal (right). Active fighting stance.
Younger than Chieftain. Cast gesture involves the spellbook.

#### Specialty — "Archmage Adept"
Files: `mage_specialty_{state}_{frame:02d}.png`
**Design:** More elaborate than Clan Unit. Additional floating arcane objects orbiting
the figure. Taller staff. Longer robes. The premium mage variant.

---

### Cleric Clan (magic — 64 frames per unit)

#### Chieftain — "High Priest"
Files: `cleric_chieftain_{state}_{frame:02d}.png`
**Design:** Elderly priest with serene authority. White and gold ceremonial robes (neutral
grey in art). Radiant halo (soft glow, not garish). Holy symbol staff — ornate.
Strong peaceful presence. Attack = divine strike (staff glows on impact).

#### Clan Unit — "Cleric Warrior"
Files: `cleric_clan_{state}_{frame:02d}.png`
**Design:** Fighting cleric. White robes with armoured sleeves/boots. Round shield with
sun motif. Mace or holy hammer. Protective stance.

#### Specialty — "Healing Acolyte"
Files: `cleric_specialty_{state}_{frame:02d}.png`
**Design:** Support-focused priest. Simpler robes, healing herbs and vials at belt.
Cast animation = hands outstretched, healing energy emanating.

---

### Dwarf Clan (non-magic — 56 frames per unit)

#### Chieftain — "Dwarf King"
Files: `dwarf_chieftain_{state}_{frame:02d}.png`
**Design:** Magnificent compact figure. Forged crown integrated into full plate helm.
Magnificent braided beard with rune-clasps (draw in neutral grey — clan tinting applies).
Great war hammer. Wide powerful stance. Every detail speaks of master craftsmanship.
Runes glow faintly on armour.

#### Clan Unit — "Runic Warrior"
Files: `dwarf_clan_{state}_{frame:02d}.png`
**Design:** Compact dwarven soldier. Full rune-carved plate armour. Battle axe and
reinforced round shield. Short and powerful. Runes on shield catch light.

#### Specialty — "Runesmith"
Files: `dwarf_specialty_{state}_{frame:02d}.png`
**Design:** Master craftsman. Heavy leather apron over chainmail. Runic chisel and
inscription hammer. Blueprint satchel. Work animation = inscribing runes. Attack =
the hammer slam.

---

### Ranger Clan (non-magic — 56 frames per unit)

#### Chieftain — "Ranger Captain"
Files: `ranger_chieftain_{state}_{frame:02d}.png`
**Design:** Weathered veteran scout. Antler-trim leather armour (subtle trophy).
Long elegant recurve bow slung on back. Short sword at hip. Cloak with leaves/nature
camouflage texture. Deeply self-reliant aura. Can move fast.

#### Clan Unit — "Pathfinder"
Files: `ranger_clan_{state}_{frame:02d}.png`
**Design:** Forest-adapted ranger. Green-brown leather armour. Longbow (primary weapon).
Quiver. Short blade backup. Light and quick. Forest-comfortable stance.

#### Specialty — "Trapper"
Files: `ranger_specialty_{state}_{frame:02d}.png`
**Design:** Wiry and cunning. Trap satchel at hip. Snare ropes coiled at belt.
Camouflage netting draped over shoulder. Light crossbow. Work/place animation =
crouching to set a trap.

---

### Elf Clan (magic — 64 frames per unit)

#### Chieftain — "Elf Lord"
Files: `elf_chieftain_{state}_{frame:02d}.png`
**Design:** Tall elegant figure. Ethereal silver plate armour with leaf-pattern embossing.
Long silver hair flowing free. Slender elegant blade (one-handed). Ageless, serene face.
Cast = star energy radiating from hands.

#### Clan Unit — "Star Warrior"
Files: `elf_clan_{state}_{frame:02d}.png`
**Design:** Slender elf soldier. Silver scale armour, leaf motifs throughout. Longbow
(primary) and slender blade (backup). Graceful fighting style.

#### Specialty — "Starbow Archer"
Files: `elf_specialty_{state}_{frame:02d}.png`
**Design:** The iconic Elf archer. Tall with an extraordinarily elegant magical bow
(celestial blue glowing string). Arrows have starlight trails. No armour — speed and
precision only. Attack = slow deliberate aim, near-instant release.

---

### Rogue Clan (non-magic — 56 frames per unit)

#### Chieftain — "Shadow Master"
Files: `rogue_chieftain_{state}_{frame:02d}.png`
**Design:** Almost entirely wrapped in shadow-dark clothing. Half-mask. Twin curved
daggers. Moves like smoke — every pose suggests imminent disappearance. Walk = silent
gliding. Attack = blur of daggers. Minimal reflective surfaces on gear.

#### Clan Unit — "Shadow Operative"
Files: `rogue_clan_{state}_{frame:02d}.png`
**Design:** Dark brown/grey leather armour. Deep hood. Single short blade visible,
second blade hidden. Coin pouch and lock picks at belt. Crouch-walk style.

#### Specialty — "Assassin"
Files: `rogue_specialty_{state}_{frame:02d}.png`
**Design:** Fully cloaked figure. Silent movement — barely touching the ground.
Single black blade (the only visible element against the dark clothing).
Attack = extremely fast single strike from concealment.

---

### Monk Clan (magic — 64 frames per unit)

#### Chieftain — "Iron Fist Master"
Files: `monk_chieftain_{state}_{frame:02d}.png`
**Design:** Bare-chested (or light wraps). Worn prayer beads. Age-weathered face.
Completely unarmoured. Glowing fists (the sole weapon). Disciplined, still stance.
Attack = devastating open-palm/punch. Cast = meditation energy release.

#### Clan Unit — "Monk Warrior"
Files: `monk_clan_{state}_{frame:02d}.png`
**Design:** Simple saffron/off-white robes (neutral grey in art). Staff (simple wooden
pole). Serene fighting pose. Minimalist — no ornamentation.

#### Specialty — "Iron Palm"
Files: `monk_specialty_{state}_{frame:02d}.png`
**Design:** More muscular monk. Bare arms. Glowing palm symbols. Stronger stance
than Clan Unit. Cast = shockwave from palm strike.

---

### Druid Clan (magic — 64 frames per unit)

#### Chieftain — "Grove Elder"
Files: `druid_chieftain_{state}_{frame:02d}.png`
**Design:** Ancient nature spirit-like figure. Living wood armour (bark plates over
robes). Antlers or antler-like branches growing from helm (natural, not trophies —
they ARE the helm). Staff topped with a living glowing branch. Moss-draped cloak.
Nature in personified form.

#### Clan Unit — "Grove Warden"
Files: `druid_clan_{state}_{frame:02d}.png`
**Design:** Bark-plate armour over earth-tone robes. Vine and leaf motifs throughout.
Wooden staff. Forest defender aesthetic.

#### Specialty — "Thornweaver"
Files: `druid_specialty_{state}_{frame:02d}.png`
**Design:** Druid focused on entangle. Robes wrapped with actual vines (living).
Thorned staff. Cast = vines erupting from hands/ground. Work animation = planting
a Lumber Post (touching the earth, brief glow).

---

### Necromancer Clan (magic — 64 frames per unit)

#### Chieftain — "Death Lord"
Files: `necromancer_chieftain_{state}_{frame:02d}.png`
**Design:** Black plate armour trimmed with bone-white. Skull motifs on pauldrons
and helm. Tall necrotic staff topped with a skull (jaw open, faint purple glow).
Tattered dark cape. Eyes glow purple. Cast = spectral energy from staff.

#### Clan Unit — "Necromancer"
Files: `necromancer_clan_{state}_{frame:02d}.png`
**Design:** Black robes with bone motif stitching. Skeletal hand visible on staff.
Purple glowing sigils on robes. Dark aesthetic. Lighter build than Death Lord.

#### Specialty — "Death Knight"
Files: `necromancer_specialty_{state}_{frame:02d}.png`
**Design:** Undead champion. Bone armour over spectral form. Spectral blade (not
physical — it crackles). Purple aura. Somewhere between alive and dead.
Most intimidating unit in the game.

---

### Bard Clan (magic — 64 frames per unit)

#### Chieftain — "Grand Spymaster"
Files: `bard_chieftain_{state}_{frame:02d}.png`
**Design:** Elegant travelling coat — the most well-dressed unit in the game.
Concealed daggers barely visible. Information scroll or coded ledger. Charming
intelligence behind the eyes. Looks like a merchant or noble, not a warrior.
Cast = information/charm energy (musical notes or cipher symbols).

#### Clan Unit — "Bard"
Files: `bard_clan_{state}_{frame:02d}.png`
**Design:** Colorful doublet (neutral grey in art, engine tints). Lute on back.
Short blade at hip. More performer than soldier. Charming demeanor. Cast = musical
energy waves.

#### Specialty — "Spymaster"
Files: `bard_specialty_{state}_{frame:02d}.png`
**Design:** Deliberately nondescript. Could be anyone. Hidden blades (barely visible
grips). Coded message case. Looks unremarkable — that's the point.

---

### Shaman Clan (magic — 64 frames per unit)

#### Chieftain — "Storm Elder"
Files: `shaman_chieftain_{state}_{frame:02d}.png`
**Design:** Lightning tattoos crackling across bare skin. Bone and feather headdress.
Thunder staff — lightning gathered at the head. Tribal wraps. Wild-eyed intensity.
Cast = lightning exploding outward from raised staff.

#### Clan Unit — "Storm Shaman"
Files: `shaman_clan_{state}_{frame:02d}.png`
**Design:** Tribal wraps and leather. Totemic paint on face/arms. Storm staff.
More energetic stance than Chieftain. Cast = calling storm gesture (arms raised).

#### Specialty — "Storm Caller"
Files: `shaman_specialty_{state}_{frame:02d}.png`
**Design:** Lightning swirling visibly around the figure. Arms permanently partially
raised. Most intense version of Shaman look. Attack/cast = same: lightning erupts.

---

### Per-Clan Unit Summary

| Clan | Magic? | Frames/unit | Units | Total |
|------|--------|-------------|-------|-------|
| Fighter | No | 56 | 3 | 168 |
| Dwarf | No | 56 | 3 | 168 |
| Ranger | No | 56 | 3 | 168 |
| Rogue | No | 56 | 3 | 168 |
| Mage | Yes | 64 | 3 | 192 |
| Cleric | Yes | 64 | 3 | 192 |
| Elf | Yes | 64 | 3 | 192 |
| Monk | Yes | 64 | 3 | 192 |
| Druid | Yes | 64 | 3 | 192 |
| Necromancer | Yes | 64 | 3 | 192 |
| Bard | Yes | 64 | 3 | 192 |
| Shaman | Yes | 64 | 3 | 192 |
| **PER-CLAN TOTAL** | | | **36** | **2,028 frames** |

---

## 10. Dragon & Special Entities

### Dragon
**The centrepiece of the game — most detailed single unit.**
**Canvas: 192×256 px per frame**

The Dragon is viewed from the same isometric angle as other units but rendered at
3× the scale. It should feel ancient, powerful, and genuinely threatening.

**Design:** Classic western dragon. Scaled hide (deep charcoal/grey in neutral — engine
can tint). Vast wings folded or spread depending on state. Long neck, horned head.
Four legs + wings = six limbs. The dragon EGG is implied but not visible (it's
underground/hidden in the Veil Hex).

**IMPORTANT:** Draw the Dragon in SLEEPING state first (most important state for game
atmosphere). The Dragon is sleeping throughout most of the game.

| State | Frames | FPS | Description |
|-------|--------|-----|-------------|
| `dragon_sleeping` | 8 | 6 | Coiled on ground, slow breathing. Chest rises and falls. |
| `dragon_awake` | 8 | 10 | Alert, head raised and tracking. Eyes open. Tail swishing. |
| `dragon_walk_se` | 8 | 12 | Walking toward viewer — dominant, ground shaking feel |
| `dragon_walk_e` | 8 | 12 | Profile walk |
| `dragon_walk_ne` | 8 | 12 | Walking away |
| `dragon_breath` | 12 | 16 | Wind-up → neck extends → fire cone erupts → exhale. |
| `dragon_hit` | 4 | 12 | Recoil from damage — flinch. Even the Dragon can be hurt. |
| `dragon_death` | 14 | 10 | Epic slow collapse. Gradual fall, wings failing, final stillness. |

**Dragon total: 78 frames**

#### Dragon Breath FX (separate sprite)
**Canvas: 256×128 px** — the fire/lightning/acid cone effect
Files: `dragon_breath_fx_00.png` – `_07.png`
**Animated: 8 frames at 16 fps**
Wide fan of fire (or clan-dependent element). Transparent background. Rendered
in front of Dragon, pointed toward target direction.
**Total: 8 frames**

### Dragon Egg
**Canvas: 48×64 px**

The Egg sits on the Veil Hex, partially hidden. Two states:

| File | Description |
|------|-------------|
| `egg_hidden.png` | 1 static frame: subtle shimmer, mostly looks like a glowing rock |
| `egg_revealed_00.png` – `_07.png` | 8 frames at 10 fps: golden pulsing egg in full view |
| `egg_carried.png` | 1 static: egg wrapped in cloth/carried in arms — add to Seeker carry variant |

**Egg total: 10 frames**

---

## 11. Monsters

Three tiers of generic monster types. Not clan-specific. Unique fantasy creatures.

### Monster T1 — "Goblin Raider" (or Warg / Wolf Pack)
**Canvas: 64×96 px | 48 frames**
Files: `monster_t1_{state}_{frame:02d}.png`

**Design:** Small, quick, dangerous in numbers. Goblin: hunched, green-grey, crude
weapons (rusty blade, spiked club). Multiple can appear on one hex.
Alternative: large wolf/warg pack (easier to animate).

| State | Frames |
|-------|--------|
| idle | 6 |
| walk_se | 8 |
| walk_e | 6 |
| walk_ne | 6 |
| attack | 8 |
| hit | 4 |
| death | 8 |
| **T1 Total** | **46 frames** |

### Monster T2 — "Troll Brute"
**Canvas: 80×112 px | 46 frames** (slightly larger canvas)
Files: `monster_t2_{state}_{frame:02d}.png`

**Design:** Massive regenerating troll. Stone-grey hide, oversized limbs, crude
club. Slow but powerful. Regeneration can be implied by a faint glow on the idle frame.

Same states as T1. **Total: 46 frames**

### Monster T3 — "Ancient Lich" (or Demon Boss / Stone Golem)
**Canvas: 96×128 px | Boss-size**
Files: `monster_t3_{state}_{frame:02d}.png`

**Design:** Imposing boss creature. Ancient Lich: skeletal sorcerer floating slightly
above ground, tattered dark robes, crown of bone, crackling death magic.
OR Stone Golem: ancient animated colossus of carved rock. Your choice.

| State | Frames |
|-------|--------|
| idle | 8 |
| walk_se | 8 |
| walk_e | 6 |
| walk_ne | 6 |
| attack | 8 |
| cast | 8 |
| hit | 4 |
| death | 10 |
| **T3 Total** | **58 frames** |

### Monster Summary
| Monster | Frames |
|---------|--------|
| T1 Goblin | 46 |
| T2 Troll | 46 |
| T3 Lich/Boss | 58 |
| **TOTAL** | **150 frames** |

---

## 12. Spell & Combat FX

All FX sprites: transparent background, canvas sized to cover the effect area.
Played once on the target hex and immediately removed.

### Combat FX

| FX | Canvas | Frames | FPS | Description |
|----|--------|--------|-----|-------------|
| `fx_hit_melee` | 48×48 | 4 | 16 | Impact flash, sparks |
| `fx_hit_arrow` | 48×48 | 3 | 16 | Arrow impact burst |
| `fx_death_flash` | 64×64 | 4 | 16 | Unit death glow flash |
| `fx_trap_trigger` | 64×64 | 5 | 16 | Trap snap/explosion |
| `fx_rune_ward_block` | 80×80 | 6 | 14 | Spell blocked by ward — blue energy deflection |
| `fx_shrine_complete` | 96×96 | 8 | 12 | Shrine meditation complete — radiant burst |
| `fx_egg_pickup` | 64×80 | 6 | 16 | Egg picked up — golden shimmer rise |

**Combat FX total: 36 frames**

### Spell FX

| Spell | Canvas | Frames | FPS | Description |
|-------|--------|--------|-----|-------------|
| `fx_reveal` | 128×128 | 6 | 12 | Fog clearing pulse outward |
| `fx_mend` | 48×64 | 5 | 12 | Green healing aura rise |
| `fx_slow` | 48×64 | 4 | 12 | Blue frost wisps around target |
| `fx_shroud` | 64×80 | 5 | 12 | Dark mist wrapping unit |
| `fx_haste` | 48×64 | 5 | 14 | Speed lines / golden trail |
| `fx_silence` | 48×64 | 4 | 12 | Sound wave crushing inward |
| `fx_ward` | 64×64 | 4 | 12 | Magical shield shimmering |
| `fx_charm` | 48×64 | 5 | 12 | Pink heart/spiral effect |
| `fx_fireball` | 96×96 | 8 | 16 | Fire impact explosion, 2-hex area |
| `fx_heal` | 64×80 | 6 | 12 | Radiant golden healing burst |
| `fx_entangle` | 80×80 | 6 | 12 | Vines erupting from ground |
| `fx_blink_depart` | 48×64 | 4 | 16 | Figure dissolving into sparks |
| `fx_blink_arrive` | 48×64 | 4 | 16 | Sparks coalescing into figure |
| `fx_lightning_storm` | 160×160 | 8 | 16 | Lightning bolts radiating (3-hex area) |
| `fx_reanimate` | 64×80 | 6 | 12 | Dark energy rising from ground, figure forming |
| `fx_curse` | 64×80 | 6 | 12 | Dark purple tendrils wrapping around target |
| `fx_mass_haste` | 128×128 | 6 | 14 | Golden wave expanding over area |
| `fx_meteor` | 256×256 | 12 | 16 | Massive rock + fire impact (4-hex area) |
| `fx_arcane_gate` | 96×96 | 8 | 14 | Portal opening, figure stepping through |
| `fx_antimagic` | 160×160 | 6 | 12 | Magic-suppressing grey dampening field |
| `fx_timestop` | 512×512 | 8 | 12 | Time freeze ripple across entire visible area |

**Spell FX total: ~118 frames**

### FX Summary
| Category | Frames |
|----------|--------|
| Combat FX | 36 |
| Spell FX | 118 |
| Dragon breath FX | 8 |
| **FX TOTAL** | **162 frames** |

---

## 13. UI Elements

Static or minimally animated interface graphics. Most are 9-slice scalable panels.

**Style:** Dark medieval fantasy aesthetic. Deep browns, aged leather, iron trim.
Consistent with the world art style — NOT clean modern UI.

| Element | Size | Notes |
|---------|------|-------|
| `ui_sidebar_bg.png` | 160×720 | Left/right sidebar background panel |
| `ui_topbar_bg.png` | 1280×48 | Top bar background |
| `ui_actionbar_bg.png` | 1280×48 | Bottom action bar |
| `ui_button_normal.png` | 120×32 | Action button base state |
| `ui_button_hover.png` | 120×32 | Action button hover state |
| `ui_button_pressed.png` | 120×32 | Action button pressed |
| `ui_panel_bg.png` | 400×500 | Town/production panel background |
| `ui_panel_tab_normal.png` | 96×28 | Tab button normal |
| `ui_panel_tab_active.png` | 96×28 | Tab button selected |
| `ui_hp_bar_bg.png` | 48×6 | HP bar background |
| `ui_hp_bar_combat.png` | 48×6 | Combat HP (green) — stretch to % |
| `ui_hp_bar_exhaust.png` | 48×6 | Exhaustion HP (purple) — stretch |
| `ui_timer_bar_bg.png` | 200×12 | Turn timer background |
| `ui_timer_bar_fill.png` | 200×12 | Timer fill (green → red gradient) |
| `ui_minimap_bg.png` | 200×200 | Minimap border/frame |
| `ui_shrine_dot_empty.png` | 16×16 | Shrine progress dot — not meditated |
| `ui_shrine_dot_credit.png` | 16×16 | Shrine progress — credit (no bonus) |
| `ui_shrine_dot_full.png` | 16×16 | Shrine progress — meditated (bonus) |
| `ui_gold_icon.png` | 16×16 | Gold coin icon |
| `ui_production_icon.png` | 16×16 | Gear/production icon |
| `ui_mp_icon.png` | 16×16 | Magic/mana icon |
| `ui_turn_icon.png` | 16×16 | Turn counter icon |
| `ui_tooltip_bg.png` | 220×80 | Tooltip panel background |
| `ui_selection_ring.png` | 80×46 | Hex selection highlight ring (transparent center) |
| `ui_move_highlight.png` | 80×46 | Reachable hex overlay (blue tint hex) |
| `ui_attack_highlight.png` | 80×46 | Attackable hex overlay (red tint hex) |
| `ui_pub_dialogue_bg.png` | 500×300 | Pub conversation panel |
| `ui_armory_slot_bg.png` | 100×100 | Item slot background |
| `ui_victory_bg.png` | 1280×720 | Victory/end screen background |

**UI Total: ~30 elements (most static)**

### Feature Icons (map overlay)
Small icons shown on map hexes for structures and points of interest.

| Icon | Size |
|------|------|
| `icon_shrine_{clan}.png` (12 total) | 32×32 |
| `icon_village.png` | 32×32 |
| `icon_town.png` | 32×32 |
| `icon_monster_lair_t1.png` | 32×32 |
| `icon_monster_lair_t2.png` | 32×32 |
| `icon_monster_lair_t3.png` | 32×32 |
| `icon_watch_post.png` | 24×24 |
| `icon_fort.png` | 32×32 |
| `icon_trap.png` | 20×20 |
| `icon_farm.png` | 24×24 |
| `icon_mine.png` | 24×24 |
| `icon_lumber_post.png` | 24×24 |
| `icon_artifact.png` | 28×28 |
| `icon_enclave_{clan}.png` (12 total) | 40×40 |

**Icon Total: ~40 images**

---

## 14. AI Prompt Templates

### Style Lock Prompt (include in EVERY generation)
```
Civilization VI art style, isometric 3/4 view (camera elevated at 30 degrees 
looking toward lower-right), warm painterly fantasy illustration, dramatic lighting 
from upper-left, clean readable silhouette at small scale, transparent background, 
no background elements, RGBA PNG
```

### Terrain Ground Tile Prompt Template
```
[STYLE LOCK]
Hex-shaped terrain tile, 80x46 pixels, point-top hexagon shape, 
viewed from 30 degrees above, [TERRAIN DESCRIPTION],
flat ground surface, isometric perspective, seamlessly tileable edges
```

**Example — Plains v1:**
```
Civilization VI art style, isometric 3/4 view (camera elevated at 30 degrees 
looking toward lower-right), warm painterly fantasy illustration, dramatic lighting 
from upper-left, clean readable silhouette, transparent background, RGBA PNG,
hex-shaped terrain tile 80x46 pixels, point-top hexagon, even short grass meadow, 
soft yellow-green tones, flat ground surface, no vertical elements
```

**Example — Mountain feature:**
```
Civilization VI art style, isometric 3/4 view, warm painterly fantasy illustration,
dramatic lighting from upper-left, transparent background, RGBA PNG,
tall mountain peak sprite 96x192 pixels, classic snow-capped grey rocky summit,
visible rocky flanks from isometric side angle, dramatic and imposing,
transparent base, anchored at bottom-center
```

### Unit Reference Sheet Prompt Template
```
[STYLE LOCK]
Fantasy RPG character reference sheet, three views side by side 
(front-facing, right profile, back-facing), white background,
[CHARACTER DESCRIPTION],
neutral grey-cream base colours (no specific colours — will be tinted in engine),
detailed [armour/clothing] visible from all angles,
64x96 pixel proportions per view, isometric fantasy art style
```

### Unit Animation Frame Prompt Template
```
[STYLE LOCK]
Fantasy RPG character sprite, 64x96 pixel canvas, 
[CHARACTER DESCRIPTION],
[ANIMATION STATE AND FRAME DESCRIPTION],
neutral grey-cream colours, isometric 3/4 view,
feet anchored at bottom-center of canvas, figure extends upward,
clean silhouette, no background
```

### Per-Clan Character Prompts

Use these for unique unit generation. Add the animation state description from the
"Animation State and Frame Description" section below.

#### Fighter
```
Veteran warlord in heavy full plate armour, ornate pauldrons, battle-scarred 
greatsword, commanding presence, military bearing, no magic elements
```
Fighter Clan Unit:
```
Disciplined heavy infantry soldier, full plate armour, large kite shield with 
crest, longsword at ready, stocky powerful build, professional soldier
```
Fighter Specialty (Siege Engineer):
```
Practical battle engineer, leather and chain armour, heavy tool belt, oversized 
demolition warhammer, blueprints rolled under arm, craftsman build
```

#### Mage
```
Ancient powerful sorcerer, star-patterned deep robes, silver staff topped with 
floating orb, flowing silver hair, arcane aura, slightly hovering
```
Mage Clan Unit:
```
Battle mage in armoured grey robes with pauldrons, glowing spellbook in left hand,
focusing crystal in right, active fighting stance
```
Mage Specialty (Archmage):
```
Elder archmage, elaborate robes, multiple small arcane objects orbiting figure,
towering staff, powerful magical aura
```

#### Cleric
```
High priest in white ceremonial robes, soft radiant halo, ornate holy symbol staff,
serene authority, elderly but strong
```
#### Dwarf
```
Dwarf king compact powerful figure, magnificent braided beard with rune-clasps,
forged crown integrated into full plate helm, war hammer, master craftsman detail
```
#### Ranger
```
Weathered veteran scout in antler-trim leather armour, longbow on back,
short sword at hip, forest camouflage cloak, deeply self-reliant
```
#### Elf
```
Tall ethereal elf lord, silver plate armour with leaf-pattern embossing,
long silver hair, slender elegant blade, ageless serene face, star magic
```
#### Rogue
```
Shadow master entirely in dark clothing, half-mask, twin curved daggers,
poses suggest imminent disappearance, no reflective surfaces
```
#### Monk
```
Iron fist master, bare-chested with prayer beads, glowing fist aura,
disciplined still stance, completely unarmoured, serenely dangerous
```
#### Druid
```
Grove elder in living wood bark-plate armour, antlers growing naturally from helm,
staff with living glowing branch, moss-draped cloak, ancient nature spirit
```
#### Necromancer
```
Death lord in black plate armour trimmed bone-white, skull motifs on pauldrons,
tall necrotic staff topped with skull, tattered dark cape, purple glowing eyes
```
#### Bard
```
Grand spymaster in elegant travelling coat, concealed daggers barely visible,
coded scroll or information ledger, charming intelligent expression,
looks like a noble not a warrior
```
#### Shaman
```
Storm shaman elder, lightning tattoos crackling across skin, bone and feather 
headdress, thunder staff with gathered lightning, tribal wraps, wild intensity
```

### Animation State Descriptions (add to unit prompts)

| State | Description to append |
|-------|----------------------|
| idle frame 0-2 | standing at ease, weight on right foot, weapon at rest |
| idle frame 3-5 | weight shifting to left, slight head turn, breathing visible |
| walk_se frame 0-7 | walking toward viewer-right, full foot-plant cycle, frame 0=right foot back, frame 4=left foot back |
| walk_e frame 0-5 | walking rightward in profile, frame 0=right foot forward |
| walk_ne frame 0-5 | walking away-right, back view with slight angle, frame 0=right foot forward |
| attack frame 0-1 | weapon wind-up, preparatory stance |
| attack frame 2-3 | peak wind-up, maximum extension before strike |
| attack frame 4-5 | IMPACT moment — weapon at target, maximum power |
| attack frame 6-7 | follow-through and recovery |
| hit frame 0 | impact beginning, head snapping back |
| hit frame 1-2 | full recoil, stagger backward |
| hit frame 3 | recovery beginning, still off-balance |
| death frame 0-2 | beginning to fall, legs giving way |
| death frame 3-5 | mid-collapse, arms out |
| death frame 6-7 | fully fallen, final resting position |
| meditate frame 0-5 | seated or kneeling, hands together, subtle glow, peaceful |
| cast frame 0-2 | hands or staff raising, energy gathering |
| cast frame 3-4 | peak energy concentration, maximum visual charge |
| cast frame 5-6 | RELEASE — energy erupting outward |
| cast frame 7 | cooldown, spent but controlled |

### Dragon Prompts
```
Ancient western dragon, massive scaled body charcoal-grey hide, vast folded wings,
long neck with horned head, four legs plus wings, isometric 3/4 view,
192x256 pixel canvas, Civilization VI art style, dramatic, genuinely threatening,
neutral grey tones, transparent background
```

Dragon sleeping:
```
[DRAGON BASE], coiled in resting position, wings folded tight, eyes closed,
head resting on front claws, chest slowly rising, dormant but dangerous
```

Dragon awake:
```
[DRAGON BASE], head raised alert, neck extended, eyes glowing, wings half-spread,
tail swishing, tracking movement with intense gaze
```

Dragon breath frame 4-5 (peak):
```
[DRAGON BASE], neck fully extended, head forward, jaws open wide,
intense fire/energy erupting from throat in cone, full power release
```

### FX Sprite Prompts
```
Fantasy spell effect sprite, [EFFECT DESCRIPTION],
transparent background, [CANVAS SIZE] pixels,
radially centered, bright and readable on dark terrain,
frame [N] of [TOTAL] animation cycle
```

---

## 15. Priority Build Order

Build in this order to get the game running visually as fast as possible:

### Phase 1 — Minimum Playable (build these first)
1. **Terrain ground tiles** — 1 static variant per terrain × 7 terrains = 7 PNGs
2. **Fighter Chieftain** — idle + walk_se/e/ne only = 20 frames (see the game moving)
3. **Shared Scout** — idle + walk_se only = 14 frames
4. **Dragon** — sleeping only = 8 frames (dramatic centrepiece)
5. **Basic UI** — sidebar, button, hp bar, timer = 8 elements

**Phase 1 total: ~58 files — 1–2 days of AI generation**

### Phase 2 — Full Visual Experience
6. All terrain ground variants (remaining 20 PNGs)
7. All terrain feature sprites (forest, mountain, swamp, sacred) + artifact markers
8. Dragon full animation set
9. All 4 unit archetypes (Fighter, Mage, Ranger, Monk) — full animation
10. Dragon egg

**Phase 2 total: ~250 additional files**

### Phase 3 — Complete Unique Units & All Archetypes
11. All 36 per-clan unique units (Chieftains, Clan Units, Specialties)
12. All 4 Scout archetypes (Warrior / Arcane / Shadow / Wild) — full animation
13. All 4 Archer archetypes — full animation
14. All 4 Seeker archetypes — full animation + egg-carrier variants
15. Workers (Farmer, Miner, Forester) and Diplomat

**Phase 3 total: ~2,900 additional files**

### Phase 4 — FX & Atmosphere
13. Spell FX (prioritise: fireball, lightning, shrine_complete, meteor)
14. Ambient creatures
15. Remaining UI polish

---

## 16. Full Frame Count Summary

| Category | Detail | Frames |
|----------|--------|--------|
| Terrain ground tiles | 7 terrain types × 1–8 frames × 2–5 variants | 81 |
| Terrain feature sprites | forest/mountain/swamp/sacred + artifact markers | 49 |
| Ambient creatures | birds, eagle, forest bird, sacred mote | 20 |
| Scout (4 archetypes × 56 frames) | Warrior / Arcane / Shadow / Wild | 224 |
| Archer (4 archetypes × 56 frames) | Warrior / Arcane / Shadow / Wild | 224 |
| Seeker (4 archetypes × 52 frames) | Warrior / Arcane / Shadow / Wild | 208 |
| Seeker egg carrier (4 archetypes × 26 frames) | idle + walk × 4 | 104 |
| Workers + Diplomat (shared) | Farmer, Miner, Forester, Diplomat | 180 |
| Per-clan unique units (36 types) | Chieftain + Clan Unit + Specialty × 12 clans | 2,028 |
| Dragon + Egg | sleeping/awake/walk/breath/hit/death | 88 |
| Monsters (3 tiers) | T1 Goblin, T2 Troll, T3 Lich | 150 |
| Spell & Combat FX | 28 effect types | 162 |
| UI elements + icons | panels, bars, icons, overlays | 70 |
| **GRAND TOTAL** | | **~3,587 individual PNG frames** |

### Scope vs Original Plan
| Approach | Frames | Scout/Archer/Seeker |
|----------|--------|---------------------|
| Original (1 shared set) | ~3,038 | Identical for all 12 clans |
| **Current (4 archetypes, no Ruins terrain)** | **~3,587** | **Distinct per clan group** |
| Full unique (12 per type) | ~5,600 | Fully unique per clan |

The 4-archetype system adds ~570 frames (+19%) for a major visual improvement.

### Practical Notes for AI Generation
- Most frames are 64×96px or smaller — fast to generate
- Use consistent style prompts across all sessions for visual coherence
- Generate reference sheets FIRST for each unique unit, THEN animate
- The engine applies clan colour tinting — all units in neutral tones
- Workers are simpler than combat units — easier generations
- Dragon and T3 Monster boss are the most complex to get right — allocate extra time
- FX sprites don't need stylistic consistency — they're effects, not characters
- The 4 Archer archetypes are the highest visual payoff per frame — prioritise these

*End of art_spec.md — Version 1.1*
*Design DNA: CIV6 × Ultima IV × WoW | 4-Archetype Scout/Archer/Seeker System*
*For questions about integration with the engine, see engine/engine_graphics.py*
