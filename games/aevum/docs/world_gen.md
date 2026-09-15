# world_gen.md — World Generation
**Sprint 36 | engine/engine_map_pipeline.py · engine/startup_engine.py**

> **`[SUPERSEDED SECTION]` 08/24/2026**: the "Hex Coordinate System" through
> "Mountain / Hill Geography Rules" sections below (including `ZONE_DENSITIES`,
> `zone_of()`, and the hard-banded keep/approach/middle/outer radius cutoffs at
> r≤15/25/45) describe an **earlier ring-based generator**. The real generator
> (`engine/engine_map_pipeline.py`, Sprint 23 #166) explicitly abandoned rings:
> its own docstring says "Rings ABANDONED." It instead does FBM-continent
> generation (`generate_fbm_continent`) → rank-based terrain fill by noise score
> (`fill_terrain`, target %s: swamp 8/plains 23/forest 15/hills 15/grasslands
> 25/mountain ~8, not the % tables below) → a radial mountain-distance bias
> (`DRAGON_VALLEY_R=15` kept clear, `MTN_RIDGE_PEAK_R=26`/`MTN_RIDGE_OUTER_R=38`
> is where mountain density peaks) → 8 explicit spoke ridges with pass gaps at
> the 22.5° midpoints between them (`_add_mountain_ridges`), not the "2–4 seeded
> passes" described below. `startup_engine.py`'s placement steps
> (`_place_shrines`/`_place_villages`/`_place_towns`/`_place_monster_enclaves`
> etc.) are real and current — only the terrain-zone generation math below is
> stale. Kept for historical/design-intent reference; do not use it to reason
> about actual terrain distribution.

## Overview

Aevum generates a unique 100×100 hex world from a single integer seed. The generator uses **enforced concentric zone structure with FBM noise variation within each zone** — the structural gradient is always consistent, but terrain shapes, enclave angles, shrine positions, village locations, and monster lair placements vary every game.

All placement is deterministic from the seed. Two players with the same seed get the same world.

---

## Hex Coordinate System

Aevum uses **axial coordinates** (q, r) for the hex grid.

```python
MAP_COLS = 100   # q range: 0–99
MAP_ROWS = 100   # r range: 0–99
CENTER_Q = 50
CENTER_R = 50

def hex_dist(q1, r1, q2, r2) -> int:
    """Cube coordinate distance for axial hex grid."""
    return (abs(q1 - q2) + abs(q1 + r1 - q2 - r2) + abs(r1 - r2)) // 2

def hex_disk(cq, cr, radius) -> list[tuple[int,int]]:
    """All hexes within radius of center."""
    results = []
    for dq in range(-radius, radius + 1):
        for dr in range(max(-radius, -dq - radius),
                        min(radius, -dq + radius) + 1):
            results.append((cq + dq, cr + dr))
    return results

def hex_to_pixel(q, r, tile_w, tile_h) -> tuple[int,int]:
    """Axial → screen pixel (pointy-top hexes)."""
    x = tile_w * (q + r / 2)
    y = tile_h * 0.75 * r
    return int(x), int(y)
```

---

## The Four Zones

```
Dragon's Keep    r  0–15   Mountains dominant. Veil Hex. Dragon lair.
Approach Ring    r 15–25   Hills dominant. Pass entrances. T2 lairs.
Middle Ring      r 25–45   Mixed. Shrines. Villages. T1–T2 lairs.
Outer Ring       r 45–55   Plains/Grasslands. Clan enclaves. Safe.
Map Edge         r 55–70   Sparse plains. No strategic value.
```

### Zone Terrain Density Targets

Densities are soft targets — FBM noise produces organic shapes within these bands. The generator normalises actual output to stay within ±5% of target.

```python
ZONE_DENSITIES = {
    "keep": {
        # Dragon's Keep — mountain amphitheatre, Veil Hex on flat ground
        # 2026-07-28: mountain reduced slightly (0.40→0.35); hills absorb (+0.05)
        "mountain":    0.35,
        "hills":       0.40,
        "plains":      0.25,
        # no forest, grasslands, swamp in keep
    },
    "approach": {
        # Approach Ring — hills with mountain spurs, forest cover for Seekers
        # 2026-07-28: mountain spurs reduced (0.15→0.10); hills absorb (+0.05)
        "hills":       0.45,
        "forest":      0.22,
        "plains":      0.23,
        "mountain":    0.10,   # spurs extending from keep ring (reduced)
    },
    "middle": {
        # Middle Ring — main game world, all terrain types
        # 2026-07-28: swamp halved (0.08→0.04); grasslands+plains absorb
        "forest":      0.25,
        "grasslands":  0.32,
        "plains":      0.27,
        "hills":       0.12,
        "swamp":       0.04,   # less marsh — redistributed to grasslands/plains
        # mountain: 0 (mountain only in keep and approach spurs)
    },
    "outer": {
        # Outer Ring — clan home territory, farming land (no changes)
        "plains":      0.45,
        "grasslands":  0.35,
        "forest":      0.15,
        "hills":       0.05,
        # no mountain, swamp in outer ring
    },
}

def zone_of(q: int, r: int) -> str:
    d = hex_dist(q, r, CENTER_Q, CENTER_R)
    if d <= 15:  return "keep"
    if d <= 25:  return "approach"
    if d <= 45:  return "middle"
    return "outer"
```

---

---

## Mountain / Hill Geography Rules  *(design note — 2026-07-28)*

### The Mountain Buffer Rule

Mountains in Aevum are never isolated. Every mountain hex is surrounded by at least one ring of hills before any other terrain type appears. This is both geologically sensible and strategically intentional:

- **Mountains** = impassable peaks, no movement except Dwarf (see below)
- **Hills (inner ring)** = the foothills that wrap the peak zone; where dragon lairs are placed; Dwarf advantage applies
- **Hills (outer band)** = transition terrain into the Approach Ring; forest begins here

The generator enforces this by running a post-pass after FBM terrain assignment: any non-hill hex within radius 2 of a mountain hex is promoted to hills.

```
Visual cross-section (center outward):
  Mountain → Hills → Hills → Forest/Plains (Approach) → Mixed (Middle Ring)
```

This means the Dragon's Keep zone is:
- A mountain **amphitheatre** at the center
- Wrapped by a **continuous hill belt** (1–3 hexes deep) where ALL dragon lairs spawn
- 2–4 **pass hexes** (see below) cutting through the hill/mountain boundary into the Keep

### Dragon Lair Placement — Hills, Not Peaks

Dragon lairs are placed exclusively in **hill hexes within the Approach Ring** (hex distance 15–25 from center). Specifically:

- Lairs are **never** placed on mountain hexes (too exposed, no shelter)
- Lairs are **never** placed on plains/grasslands (no cover, no concealment)
- Hills provide: shelter at the cave mouth, sightlines down the slope, proximity to the Keep
- The dragon uses the mountain as a **backstop** — it sleeps in the hillside cave, not on the peak

Narratively: the dragons chose the hills because a mountain peak has no roof. A hillside cave does. Three hundred years of sleeping somewhere tends to mean you've made reasonable choices about where.

```
ZONE_LAIR_PLACEMENT = {
    "T1": {"zone": "approach", "terrain": "hills", "dist_range": (15, 22)},
    "T2": {"zone": "approach", "terrain": "hills", "dist_range": (16, 24)},
    "T3": {"zone": "approach", "terrain": "hills", "dist_range": (17, 24)},
    "T4": {"zone": "approach", "terrain": "hills", "dist_range": (18, 25)},
    # Dragon's own lair: center of Keep, not on mountain hex — on the flat
    # ground within the mountain amphitheatre (the "Veil Hex" clearing)
    "dragon": {"zone": "keep", "terrain": "plains", "dist_range": (0, 10)},
}
```

### Mountain Passes — 2 to 4 Per Seed

The mountain ring around the Dragon's Keep is not a wall. Every generated world has **2–4 mountain passes**: specific hexes in the mountain/hill boundary where the terrain drops to hills or plains, creating a traversable corridor into the Keep.

Passes are:
- Seeded deterministically from the game seed
- Placed at least 15 hex-degrees apart (no two passes in the same arc quadrant)
- 1–3 hexes wide (narrow enough to be a chokepoint, wide enough to matter)
- Always connected to Approach Ring terrain (guaranteed path from outer ring → pass → Keep)

Strategic value:
- The only land routes into the Dragon's Keep run through a pass
- Seekers must use a pass to reach the egg
- Dragon lairs are preferentially placed within 5 hexes of a pass mouth (flanking position)
- Clan units blocking a pass can hold the approach indefinitely — until the dragon decides they can't

```python
# Pass generation pseudocode (deterministic from seed)
def generate_passes(seed, n_passes=None):
    rng = random.Random(seed ^ 0xPASS)
    n   = n_passes or rng.randint(2, 4)
    angles = sorted(rng.sample(range(0, 360, 10), n))
    passes = []
    for angle in angles:
        # Walk from dist=20 inward until mountain hex found, mark as pass
        # Widen by 1 hex each side
        passes.append({"angle": angle, "width": rng.randint(1, 3)})
    return passes
```

### Dwarf Terrain Advantage — Hills and Mountains

Dwarves spent three centuries in the mountains when everyone else was on the plains. This is reflected in three documented advantages (design spec — implementation in `engine_structures.py` and `movement_engine.py`):

#### 1. No Terrain Movement Penalty
- Standard units: hills = +1 MOV cost, mountains = impassable
- Dwarf units: hills = normal cost (no penalty), mountains = +1 cost (traversable)
- Dwarf units can cross mountain hexes that no other clan can enter, including through non-pass routes — slowly, but possible

#### 2. Tunnel Network (Dwarf-only Structure)
- Buildable in any **hill hex adjacent to a mountain hex**
- Named: **"Tunnel Entrance"** (build cost: 80g + 3 turns)
- Effect: Dwarf units on a Tunnel Entrance hex gain:
  - +1 hex of vision through the adjacent mountain hex (scout reveal)
  - Flanking bonus (+1 ATK) when attacking units in the pass from tunnel position
  - Emergency retreat: if combat is lost in the pass, Dwarf unit retreats to Tunnel Entrance hex instead of dying (1 use per tunnel per game)
- Maximum 1 Tunnel Entrance per pass per game
- No other clan can build or use Tunnel Entrances

#### 3. Hill Knowledge Intel
- When a Dwarf unit first enters a hill hex in the Approach Ring, they receive a free T1 intel token:
  - `lair_in_range` — "Dwarf instinct says there's something in these hills nearby"
  - Confidence: 0.55 (higher than pub T1 because dwarves actually know hills)
- This reflects their inherent geological intuition — they recognize lair-type formations on sight

```
Dwarf terrain summary:
  Plains:     Normal (no advantage)
  Grassland:  Normal
  Forest:     Normal  
  Swamp:      Normal (slight disadvantage — they don't love water)
  Hills:      ✓ No MOV penalty; +ATK from tunnel position; free lair intel
  Mountain:   ✓ Traversable (+1 cost); can build Tunnel Entrance
```

---

## FBM Noise

```python
import math, random

class FBMNoise:
    """
    Fractal Brownian Motion noise for organic terrain generation.
    Produces values in roughly [-1, 1] range.
    """
    def __init__(self, seed: int, octaves: int = 5,
                 persistence: float = 0.6, lacunarity: float = 2.0):
        self.rng         = random.Random(seed)
        self.octaves     = octaves
        self.persistence = persistence
        self.lacunarity  = lacunarity
        # Pre-generate permutation table
        self._perm = list(range(256))
        self.rng.shuffle(self._perm)
        self._perm *= 2

    def sample(self, x: float, y: float) -> float:
        total, amplitude, frequency, max_val = 0.0, 1.0, 1.0, 0.0
        for _ in range(self.octaves):
            total     += self._noise2d(x * frequency, y * frequency) * amplitude
            max_val   += amplitude
            amplitude *= self.persistence
            frequency *= self.lacunarity
        return total / max_val   # normalise to [-1, 1]

    def _noise2d(self, x: float, y: float) -> float:
        """Simple gradient noise (Perlin-style)."""
        xi, yi   = int(math.floor(x)) & 255, int(math.floor(y)) & 255
        xf, yf   = x - math.floor(x), y - math.floor(y)
        u, v     = self._fade(xf), self._fade(yf)
        aa = self._perm[self._perm[xi]     + yi]
        ab = self._perm[self._perm[xi]     + yi + 1]
        ba = self._perm[self._perm[xi + 1] + yi]
        bb = self._perm[self._perm[xi + 1] + yi + 1]
        return self._lerp(v,
            self._lerp(u, self._grad(aa, xf,   yf),
                          self._grad(ba, xf-1, yf)),
            self._lerp(u, self._grad(ab, xf,   yf-1),
                          self._grad(bb, xf-1, yf-1)))

    @staticmethod
    def _fade(t):  return t * t * t * (t * (t * 6 - 15) + 10)
    @staticmethod
    def _lerp(t, a, b): return a + t * (b - a)
    @staticmethod
    def _grad(h, x, y):
        h &= 3
        if h == 0: return  x + y
        if h == 1: return -x + y
        if h == 2: return  x - y
        return -x - y
```

---

## Main World Generation Function

```python
def generate_world(
    seed:            int,
    active_clan_ids: list[str],
    map_cols:        int = MAP_COLS,
    map_rows:        int = MAP_ROWS,
    data_dir:        str = "assets/data/",
) -> GameState:
    """
    Entry point called by StartupEngine.new_game().
    Returns a fully initialised GameState with all cells, features,
    clans, units, and placements complete.
    """
    rng   = random.Random(seed)
    noise = FBMNoise(seed=seed, octaves=5, persistence=0.6, lacunarity=2.0)
    cx, cy = map_cols // 2, map_rows // 2

    # Step 1: Generate base terrain
    cells = _generate_terrain(rng, noise, map_cols, map_rows, cx, cy)

    # Step 2: Carve mountain passes (8, one per clan angle)
    _carve_passes(cells, cx, cy, seed, active_clan_ids)

    # Step 3: Place Veil Hex (egg location)
    veil_q, veil_r = _place_veil_hex(cells, rng, cx, cy)

    # Step 4: Place Dragon lair (near Veil Hex)
    dragon_q, dragon_r = _place_dragon_lair(cells, rng, veil_q, veil_r)

    # Step 5: Place clan enclaves
    enclave_positions = _place_enclaves(cells, rng, active_clan_ids, cx, cy)

    # Step 6: Place shrines
    shrine_positions = _place_shrines(cells, rng, active_clan_ids,
                                       enclave_positions, cx, cy)

    # Step 7: Place neutral villages (12)
    village_positions = _place_villages(cells, rng, cx, cy,
                                         enclave_positions, shrine_positions)

    # Step 8: Place towns (4 of 8, at corners)
    town_positions = _place_towns(cells, rng, seed, active_clan_ids,
                                   map_cols, map_rows)

    # Step 9: Place monster lairs
    lair_data = _place_lairs(cells, rng, seed, cx, cy, veil_q, veil_r)

    # Step 10: Place artifacts (4–6)
    artifact_positions = _place_artifacts(cells, rng, cx, cy, veil_q, veil_r)

    # Step 11: Place corner bonuses (4)
    corner_bonus_positions = _place_corner_bonuses(cells, rng, map_cols, map_rows)

    # Step 12: Assign monster weakness profiles
    monster_weaknesses = _seed_monster_weaknesses(seed, active_clan_ids)

    # Step 13: Build GameState from all placements
    return _build_game_state(
        seed, active_clan_ids, cells,
        veil_q, veil_r, dragon_q, dragon_r,
        enclave_positions, shrine_positions,
        village_positions, town_positions,
        lair_data, artifact_positions,
        corner_bonus_positions, monster_weaknesses,
    )
```

---

## Step 1: Terrain Generation

```python
def _generate_terrain(
    rng:       random.Random,
    noise:     FBMNoise,
    map_cols:  int,
    map_rows:  int,
    cx:        int,
    cy:        int,
) -> dict[tuple[int,int], HexCell]:
    """
    Generate base terrain for all cells using FBM noise + zone density targets.
    Returns dict of (q,r) -> HexCell with terrain set.
    """
    cells = {}
    for q in range(map_cols):
        for r in range(map_rows):
            zone    = zone_of(q, r)
            density = ZONE_DENSITIES.get(zone, ZONE_DENSITIES["outer"])
            n       = noise.sample(q / map_cols, r / map_rows)
            terrain = _noise_to_terrain(n, density, zone, rng)
            cells[(q, r)] = HexCell(
                q=q, r=r, terrain=terrain,
                is_visible={},   # filled per clan after clan placement
                is_explored={},
                is_sacred=False,
                feature=None,
            )
    return cells

def _noise_to_terrain(
    n:       float,
    density: dict[str, float],
    zone:    str,
    rng:     random.Random,
) -> str:
    """
    Map FBM noise value to terrain type using zone density thresholds.
    Higher noise values → higher terrain (mountain > hills > plains/grasslands/forest).
    """
    # Sort terrain by noise threshold from highest to lowest
    TERRAIN_NOISE_ORDER = {
        "keep":     ["mountain", "hills", "plains"],
        "approach": ["mountain", "hills", "forest", "plains"],
        "middle":   ["hills", "forest", "swamp", "grasslands", "plains"],
        "outer":    ["hills", "forest", "grasslands", "plains"],
    }
    order = TERRAIN_NOISE_ORDER.get(zone, ["plains"])

    # Build cumulative thresholds from density targets
    # n is in [-1, 1]; map to [0, 1] for threshold comparison
    n_norm     = (n + 1) / 2.0
    cumulative = 0.0
    for terrain in order:
        cumulative += density.get(terrain, 0.0)
        if n_norm <= cumulative:
            return terrain
    return order[-1]   # fallback to flattest terrain
```

---

## Step 2: Carve Mountain Passes

```python
def _carve_passes(
    cells:           dict,
    cx:              int,
    cy:              int,
    seed:            int,
    active_clan_ids: list[str],
) -> None:
    """
    Carve 8 mountain passes through the Dragon's Keep ring, one per clan.
    Each pass is aligned to the clan's enclave angle, ensuring equal access.

    Pass design:
      Width:   3–4 hexes (narrow chokepoint)
      Depth:   r=8 through r=16 (full mountain ring + approach spur)
      Terrain: mountain → hills (still costs MOV, defensible)
      is_pass: True flag for visual styling (lighter colour)

    The T2 monster lair at each pass entrance (r=14–16) is placed in Step 9.

    Fair access guarantee: every clan has direct-line equal distance to its pass.
    Pass variation: ±8° from clan angle to prevent perfectly mechanical layout.
    """
    rng = random.Random(seed + 99)

    # 8 clan positions on octagon → angles 0°, 45°, 90°, 135°, 180°, 225°, 270°, 315°
    enclave_angles = [45.0 * i for i in range(len(active_clan_ids))]

    for base_angle in enclave_angles:
        angle = base_angle + rng.uniform(-8, 8)
        width = rng.randint(3, 4)
        rad_q = math.cos(math.radians(angle))
        rad_r = math.sin(math.radians(angle))

        for dist in range(8, 17):    # through mountain ring and into approach
            for w in range(-(width // 2), width // 2 + 1):
                # Perpendicular offset for pass width
                perp_q = -rad_r
                perp_r =  rad_q
                pq = int(round(cx + rad_q * dist + perp_q * w))
                pr = int(round(cy + rad_r * dist + perp_r * w))
                if (pq, pr) in cells:
                    if cells[(pq, pr)].terrain == "mountain":
                        cells[(pq, pr)].terrain = "hills"
                        cells[(pq, pr)].is_pass  = True
```

---

## Step 3: Veil Hex Placement

```python
def _place_veil_hex(
    cells: dict,
    rng:   random.Random,
    cx:    int,
    cy:    int,
) -> tuple[int, int]:
    """
    Place the Veil Hex (dragon egg location) within Dragon's Keep.

    Rules:
      - Always plains terrain (guaranteed passable)
      - Radius 8–14 from map center
      - Never on the exact center hex
      - Not adjacent to any mountain hex (eggs need accessible pickup)
      - Seed-deterministic
    """
    candidates = []
    for q, r in hex_disk(cx, cy, 14):
        d = hex_dist(q, r, cx, cy)
        if d < 8 or d > 14:
            continue
        if (q, r) not in cells:
            continue
        if cells[(q, r)].terrain != "plains":
            continue
        # Check adjacency — no mountain neighbours
        neighbours = hex_disk(q, r, 1)
        if any(cells.get(n, HexCell(terrain="plains")).terrain == "mountain"
               for n in neighbours if n != (q, r)):
            continue
        candidates.append((q, r))

    if not candidates:
        # Fallback: force nearest plains hex in radius
        for q, r in sorted(
            [(q, r) for q, r in hex_disk(cx, cy, 14)
             if 8 <= hex_dist(q, r, cx, cy) <= 14],
            key=lambda h: hex_dist(h[0], h[1], cx, cy)
        ):
            if (q, r) in cells:
                cells[(q, r)].terrain = "plains"
                return q, r

    veil_q, veil_r = rng.choice(candidates)
    # Mark as veil hex (internal flag only — not shown on map until Stage 1 detection)
    cells[(veil_q, veil_r)].is_veil_hex = True
    return veil_q, veil_r
```

---

## Step 4: Dragon Lair Placement

```python
def _place_dragon_lair(
    cells:  dict,
    rng:    random.Random,
    veil_q: int,
    veil_r: int,
) -> tuple[int, int]:
    """
    Place Dragon lair on the highest-ground hex within radius 3 of Veil Hex.

    Priority: mountain > hills > plains
    Dragon lair is distinct from the Veil Hex itself.
    """
    TERRAIN_HEIGHT = {"mountain": 3, "hills": 2, "plains": 1,
                      "grasslands": 1, "forest": 1, "swamp": 0}

    candidates = [
        (q, r) for q, r in hex_disk(veil_q, veil_r, 3)
        if (q, r) in cells and (q, r) != (veil_q, veil_r)
    ]
    if not candidates:
        return veil_q + 1, veil_r   # emergency fallback

    # Sort by terrain height descending, break ties randomly
    rng.shuffle(candidates)
    candidates.sort(
        key=lambda h: TERRAIN_HEIGHT.get(cells[h].terrain, 0),
        reverse=True
    )
    lair_q, lair_r = candidates[0]
    cells[(lair_q, lair_r)].is_dragon_lair = True
    return lair_q, lair_r
```

---

## Step 5: Clan Enclave Placement

```python
def _place_enclaves(
    cells:           dict,
    rng:             random.Random,
    active_clan_ids: list[str],
    cx:              int,
    cy:              int,
    radius:          int = 47,
) -> dict[str, tuple[int,int]]:
    """
    Place 8 clan enclaves on a perfect octagon at radius 47.
    ±5° seed variation per clan to prevent perfect symmetry.

    Guarantees near each enclave:
      - At least 3 plains hexes adjacent (for Farm placement)
      - At least 1 hills hex within radius 5 (for Mine placement)
      - At least 1 forest hex within radius 3 (for Lumber Post)
    """
    positions = {}
    n = len(active_clan_ids)    # 8 clans
    for i, clan_id in enumerate(active_clan_ids):
        base_angle  = 360.0 * i / n
        angle       = base_angle + rng.uniform(-5, 5)
        rad         = math.radians(angle)
        eq          = int(round(cx + radius * math.cos(rad)))
        er          = int(round(cy + radius * math.sin(rad)))

        # Snap to nearest plains hex
        eq, er = _nearest_terrain(cells, eq, er, ["plains"])
        cells[(eq, er)].terrain = "plains"   # force if needed

        # Guarantee terrain variety near enclave
        _ensure_terrain_near(cells, rng, eq, er, "hills",     radius=5, count=1)
        _ensure_terrain_near(cells, rng, eq, er, "forest",    radius=3, count=1)
        _ensure_terrain_near(cells, rng, eq, er, "plains",    radius=1, count=3)

        positions[clan_id] = (eq, er)

    return positions

def _nearest_terrain(
    cells:    dict,
    q:        int,
    r:        int,
    terrains: list[str],
    max_r:    int = 5,
) -> tuple[int, int]:
    """Find nearest hex with one of the given terrain types."""
    for radius in range(0, max_r + 1):
        for hq, hr in hex_disk(q, r, radius):
            if (hq, hr) in cells and cells[(hq, hr)].terrain in terrains:
                return hq, hr
    return q, r   # fallback: return original

def _ensure_terrain_near(
    cells:   dict,
    rng:     random.Random,
    eq:      int,
    er:      int,
    terrain: str,
    radius:  int,
    count:   int,
) -> None:
    """Force at least `count` hexes of `terrain` within `radius` of (eq, er)."""
    existing = [
        (q, r) for q, r in hex_disk(eq, er, radius)
        if (q, r) in cells and cells[(q, r)].terrain == terrain
        and (q, r) != (eq, er)
    ]
    needed = count - len(existing)
    if needed <= 0:
        return
    candidates = [
        (q, r) for q, r in hex_disk(eq, er, radius)
        if (q, r) in cells and cells[(q, r)].terrain not in ["mountain", "sacred"]
        and (q, r) != (eq, er)
        and (q, r) not in existing
    ]
    rng.shuffle(candidates)
    for q, r in candidates[:needed]:
        cells[(q, r)].terrain = terrain
```

---

## Step 6: Shrine Placement

```python
def _place_shrines(
    cells:              dict,
    rng:                random.Random,
    active_clan_ids:    list[str],
    enclave_positions:  dict[str, tuple[int,int]],
    cx:                 int,
    cy:                 int,
    shrine_radius_min:  int = 28,
    shrine_radius_max:  int = 40,
    angular_spread:     int = 30,   # ±degrees from clan enclave angle
    min_shrine_spacing: int = 6,    # minimum hexes between shrines
) -> dict[str, tuple[int,int]]:
    """
    Place each clan's shrine in the Middle Ring, angularly close to their enclave.

    Rules:
      - Radius r=28–40 from center
      - Angular position: within ±30° of clan's enclave angle from center
      - Minimum 6 hexes from any other shrine
      - Always on passable terrain (forced to plains if needed)
      - Sacred ground auto-applied: radius 2 around shrine hex set to terrain="sacred"
    """
    placed: list[tuple[int,int]] = []
    positions: dict[str, tuple[int,int]] = {}
    n = len(active_clan_ids)

    for i, clan_id in enumerate(active_clan_ids):
        eq, er    = enclave_positions[clan_id]
        # Calculate enclave's angle from center
        base_angle = math.degrees(math.atan2(er - cy, eq - cx))

        # Try up to 20 random placements within angular spread
        for attempt in range(20):
            angle     = base_angle + rng.uniform(-angular_spread, angular_spread)
            dist      = rng.randint(shrine_radius_min, shrine_radius_max)
            sq        = int(round(cx + dist * math.cos(math.radians(angle))))
            sr        = int(round(cy + dist * math.sin(math.radians(angle))))

            if (sq, sr) not in cells:
                continue
            if cells[(sq, sr)].terrain in ["mountain"]:
                sq, sr = _nearest_terrain(cells, sq, sr,
                                          ["plains","grasslands","hills","forest"])
            # Check spacing from other shrines
            if any(hex_dist(sq, sr, pq, pr) < min_shrine_spacing
                   for pq, pr in placed):
                continue

            # Place shrine
            placed.append((sq, sr))
            positions[clan_id] = (sq, sr)
            cells[(sq, sr)].is_shrine   = True
            cells[(sq, sr)].shrine_clan = clan_id

            # Apply sacred ground (radius 2)
            for hq, hr in hex_disk(sq, sr, 2):
                if (hq, hr) in cells:
                    cells[(hq, hr)].terrain    = "sacred"
                    cells[(hq, hr)].sacred_shrine_id = f"shrine_{clan_id}"
            break
        else:
            # Fallback: place at clan's own shrine ring without spacing check
            angle = base_angle
            sq    = int(round(cx + 32 * math.cos(math.radians(angle))))
            sr    = int(round(cy + 32 * math.sin(math.radians(angle))))
            sq, sr = _nearest_terrain(cells, sq, sr, ["plains","grasslands","hills"])
            placed.append((sq, sr))
            positions[clan_id] = (sq, sr)

    return positions
```

---

## Step 7: Village Placement

```python
def _place_villages(
    cells:             dict,
    rng:               random.Random,
    cx:                int,
    cy:                int,
    enclave_positions: dict,
    shrine_positions:  dict,
    count:             int = 12,
) -> list[tuple[int,int]]:
    """
    Place 12 neutral villages in the Middle Ring.

    Distribution:
      3 at r=25–32 (inner middle — most valuable for Approach intel)
      6 at r=32–40 (core middle — shrine war area)
      3 at r=40–48 (outer middle — early access)

    Constraints:
      - Minimum 8 hexes from any enclave
      - Minimum 5 hexes from any shrine
      - Minimum 6 hexes from any other village
      - Not on mountain, sacred, or swamp terrain
    """
    RINGS = [
        (25, 32, 3),   # (r_min, r_max, count)
        (32, 40, 6),
        (40, 48, 3),
    ]
    exclude_near = (
        list(enclave_positions.values()) +
        list(shrine_positions.values())
    )
    placed: list[tuple[int,int]] = []

    for r_min, r_max, ring_count in RINGS:
        candidates = [
            (q, r) for q, r in cells
            if r_min <= hex_dist(q, r, cx, cy) <= r_max
            and cells[(q, r)].terrain not in ["mountain", "sacred", "swamp"]
            and all(hex_dist(q, r, eq, er) >= 8 for eq, er in enclave_positions.values())
            and all(hex_dist(q, r, sq, sr) >= 5 for sq, sr in shrine_positions.values())
        ]
        rng.shuffle(candidates)
        added = 0
        for q, r in candidates:
            if added >= ring_count:
                break
            if all(hex_dist(q, r, pq, pr) >= 6 for pq, pr in placed):
                placed.append((q, r))
                cells[(q, r)].is_village = True
                added += 1

    return placed
```

---

## Step 8: Town Placement

```python
def _place_towns(
    cells:           dict,
    rng:             random.Random,
    seed:            int,
    active_clan_ids: list[str],
    map_cols:        int,
    map_rows:        int,
    count:           int = 4,
) -> list[tuple[int,int]]:
    """
    Select 4 of 8 towns. Place at four map corners (~r=65 from center at diagonals).

    Corner positions (approximate):
      NW: (10, 10)   NE: (90, 10)
      SW: (10, 90)   SE: (90, 90)

    Selection: seed-based weighted probability favoring towns relevant
    to active clans. See towns.json selection.weighting.
    """
    import json
    with open("assets/data/towns.json") as f:
        town_data = json.load(f)

    # Build weighted selection
    town_ids      = list(town_data["towns"].keys())
    clan_set      = set(active_clan_ids)
    town_weights  = []
    for tid in town_ids:
        weight    = 1.0
        favoured  = town_data["selection"]["clan_weighting"].get(tid, [])
        weight   += sum(1.5 for clan in favoured if clan in clan_set)
        town_weights.append(weight)

    # Seed-deterministic weighted selection of 4 towns
    town_rng = random.Random(seed + 200)
    selected_towns = []
    remaining_ids     = list(town_ids)
    remaining_weights = list(town_weights)
    for _ in range(count):
        total   = sum(remaining_weights)
        r       = town_rng.uniform(0, total)
        cumul   = 0.0
        for j, w in enumerate(remaining_weights):
            cumul += w
            if r <= cumul:
                selected_towns.append(remaining_ids[j])
                remaining_ids.pop(j)
                remaining_weights.pop(j)
                break

    # Corner positions
    margin   = 8
    corners  = [
        (margin,           margin),
        (map_cols - margin, margin),
        (margin,           map_rows - margin),
        (map_cols - margin, map_rows - margin),
    ]
    town_rng.shuffle(corners)

    placed = []
    for i, town_id in enumerate(selected_towns):
        tq, tr = corners[i]
        tq, tr = _nearest_terrain(cells, tq, tr,
                                   ["plains","grasslands"], max_r=8)
        cells[(tq, tr)].is_town   = True
        cells[(tq, tr)].town_id   = town_id
        placed.append((tq, tr))

    return placed
```

---

## Step 9: Monster Lair Placement

```python
def _place_lairs(
    cells:  dict,
    rng:    random.Random,
    seed:   int,
    cx:     int,
    cy:     int,
    veil_q: int,
    veil_r: int,
) -> list[dict]:
    """
    Place monster lairs. Distribution:

    Zone          Tier   Count   Notes
    ─────────────────────────────────────────────────────────────
    Dragon's Keep  T3     4      r=10–14, guard Veil Hex approaches
    Approach Ring  T2     6      r=15–24, 1 at each pass entrance
    Middle Ring    T1–T2  8      r=25–45, scattered

    Pass entrance lairs: placed at r=14–16 in each pass corridor.
    Dragon lair is separate (handled in Step 4).

    Each lair:
      - Not within 3 hexes of any other lair
      - Not within 5 hexes of any shrine, village, or enclave
      - Not on mountain or sacred terrain
      - Tier determines patrol unit stats and prize table
    """
    import json
    with open("assets/data/monsters.json") as f:
        monster_data = json.load(f)

    outer_pool   = monster_data["outer_pool"]
    central_pool = monster_data["central_pool"]
    lair_rng     = random.Random(seed + 77)

    # Seed-pick 4 outer types and 4 central types from pools
    active_outer   = lair_rng.sample(outer_pool,   min(4, len(outer_pool)))
    active_central = lair_rng.sample(central_pool, min(4, len(central_pool)))

    lairs        = []
    placed_lairs : list[tuple[int,int]] = []

    LAIR_PLANS = [
        # (zone, r_min, r_max, tier, count, pool)
        ("keep",     10, 14,  3, 4, active_central),
        ("approach", 15, 24,  2, 6, active_central + active_outer),
        ("middle",   25, 45,  1, 4, active_outer),
        ("middle",   25, 45,  2, 4, active_outer),
    ]

    for zone, r_min, r_max, tier, count, pool in LAIR_PLANS:
        candidates = [
            (q, r) for q, r in cells
            if r_min <= hex_dist(q, r, cx, cy) <= r_max
            and cells[(q, r)].terrain not in ["mountain","sacred","swamp"]
            and hex_dist(q, r, veil_q, veil_r) >= 4   # not too close to egg
        ]
        lair_rng.shuffle(candidates)
        added = 0
        for q, r in candidates:
            if added >= count:
                break
            if all(hex_dist(q, r, lq, lr) >= 3 for lq, lr in placed_lairs):
                monster_type = lair_rng.choice(pool)
                placed_lairs.append((q, r))
                cells[(q, r)].is_lair = True
                lairs.append({
                    "q": q, "r": r,
                    "monster_type": monster_type,
                    "tier": tier,
                    "zone": zone,
                    "prize_gold": lair_rng.randint(
                        *{"1":(50,100),"2":(100,200),"3":(200,300)}[str(tier)]
                    ),
                })
                added += 1

    return lairs
```

---

## Step 10: Artifact Placement

```python
def _place_artifacts(
    cells:  dict,
    rng:    random.Random,
    cx:     int,
    cy:     int,
    veil_q: int,
    veil_r: int,
    count:  int = 5,
) -> list[tuple[int,int]]:
    """
    Place 4–6 artifacts in the Middle Ring and Approach Ring.
    Artifacts are items on hexes — first unit to reach them claims the item.
    Not terrain-dependent. Not on sacred, mountain, or lair hexes.
    """
    import json
    with open("assets/data/items.json") as f:
        items = json.load(f)
    artifact_ids = [a["id"] for a in items["artifacts"]]
    rng.shuffle(artifact_ids)

    candidates = [
        (q, r) for q, r in cells
        if 20 <= hex_dist(q, r, cx, cy) <= 42
        and cells[(q, r)].terrain not in ["mountain","sacred"]
        and not cells[(q, r)].is_lair
        and not cells[(q, r)].is_shrine
        and not cells[(q, r)].is_village
        and hex_dist(q, r, veil_q, veil_r) >= 8
    ]
    rng.shuffle(candidates)

    placed = []
    for i, (q, r) in enumerate(candidates[:count]):
        artifact_id = artifact_ids[i % len(artifact_ids)]
        cells[(q, r)].artifact_id = artifact_id
        cells[(q, r)].is_artifact  = True
        placed.append((q, r))

    return placed
```

---

## Step 11: Corner Bonus Placement

```python
def _place_corner_bonuses(
    cells:    dict,
    rng:      random.Random,
    map_cols: int,
    map_rows: int,
) -> dict[str, tuple[int,int]]:
    """
    Place 4 corner bonuses at map corners.
    First clan to reach and hold for 1 turn claims permanently.
    """
    BONUS_IDS = ["ancient_forge", "arcane_spire", "sacred_grove", "rangers_cache"]
    rng.shuffle(BONUS_IDS)

    margin  = 5
    corners = [
        ("nw", margin,           margin),
        ("ne", map_cols - margin, margin),
        ("sw", margin,           map_rows - margin),
        ("se", map_cols - margin, map_rows - margin),
    ]

    positions = {}
    for i, (label, q, r) in enumerate(corners):
        q, r = _nearest_terrain(cells, q, r, ["plains","grasslands"], max_r=5)
        cells[(q, r)].corner_bonus_id = BONUS_IDS[i]
        cells[(q, r)].is_corner_bonus  = True
        positions[BONUS_IDS[i]] = (q, r)

    return positions
```

---

## Step 12: Monster Weakness Seeding

```python
def _seed_monster_weaknesses(
    seed:            int,
    active_clan_ids: list[str],
) -> dict[str, dict]:
    """
    For each active monster type, seed-pick one weakness and one resistance
    from the type's fixed pool. Called once at world gen; stored in GameState.
    """
    import json
    with open("assets/data/monsters.json") as f:
        monster_data = json.load(f)

    rng      = random.Random(seed + 7)
    result   = {}

    # Determine active monster types from lair placement
    # (all non-dragon active types get weakness profiles)
    all_types = (
        monster_data["outer_pool"] +
        monster_data["central_pool"] +
        monster_data["unique"]
    )

    for mtype in all_types:
        mdef  = monster_data["monsters"].get(mtype)
        if not mdef:
            continue

        weak_pool  = mdef.get("weakness_pool", [])
        resist_pool= mdef.get("resistance_pool", [])

        # Elemental special: pick variant first
        if mtype == "elemental":
            variant  = rng.choice(["fire", "ice", "lightning"])
            vdata    = mdef["variants"][variant]
            weak_to  = vdata["weak_to"]
            resists  = vdata["immune_to"]
            result[mtype] = {
                "weak_to":  weak_to,
                "resists":  resists,
                "variant":  variant,
                "hint":     mdef["pub_hints"].get("counter_element", ""),
            }
        else:
            weak_to = rng.choice(weak_pool)  if weak_pool  else "nothing"
            resists = rng.choice(resist_pool) if resist_pool else "nothing"
            hints   = mdef.get("pub_hints", {})
            result[mtype] = {
                "weak_to": weak_to,
                "resists": resists,
                "hint":    hints.get(weak_to, hints.get("confidant", "")),
            }

    return result
```

---

## HexCell Flags Reference

All boolean flags set during world generation:

```python
@dataclass
class HexCell:
    q:                int
    r:                int
    terrain:          str       # plains|grasslands|forest|hills|mountain|swamp|sacred

    # Feature flags (set during generation)
    is_shrine:        bool = False
    shrine_clan:      str  = ""
    is_sacred:        bool = False        # within radius 2 of any shrine
    sacred_shrine_id: str  = ""

    is_veil_hex:      bool = False        # egg location (hidden until detected)
    is_dragon_lair:   bool = False        # Dragon lair hex

    is_village:       bool = False
    is_town:          bool = False
    town_id:          str  = ""

    is_lair:          bool = False        # monster lair hex

    is_artifact:      bool = False
    artifact_id:      str  = ""

    is_corner_bonus:  bool = False
    corner_bonus_id:  str  = ""

    is_pass:          bool = False        # carved mountain pass hex (visual flag)

    is_enclave:       bool = False
    enclave_clan:     str  = ""

    # Vision state (per clan, populated at game start then updated each turn)
    is_visible:       dict = field(default_factory=dict)   # clan_id -> bool
    is_explored:      dict = field(default_factory=dict)   # clan_id -> bool
```

---

## Generation Summary — What Cline Must Implement

| Step | Function | Output |
|------|----------|--------|
| 1 | `_generate_terrain` | All 10,000 HexCell objects with terrain |
| 2 | `_carve_passes` | 8 hill-carved corridors through mountain ring |
| 3 | `_place_veil_hex` | Single plains hex, r=8–14, is_veil_hex=True |
| 4 | `_place_dragon_lair` | Single hex near Veil, is_dragon_lair=True |
| 5 | `_place_enclaves` | 8 clan enclave hexes on octagon |
| 6 | `_place_shrines` | 8 shrine hexes + sacred ground radius 2 |
| 7 | `_place_villages` | 12 village hexes distributed in Middle Ring |
| 8 | `_place_towns` | 4 town hexes at map corners |
| 9 | `_place_lairs` | 14–18 lair hexes, tiered by zone |
| 10 | `_place_artifacts` | 4–6 artifact hexes in Middle/Approach Ring |
| 11 | `_place_corner_bonuses` | 4 corner bonus hexes |
| 12 | `_seed_monster_weaknesses` | Dict of monster_type → {weak_to, resists, hint} |

All steps use the same `seed` (via `random.Random(seed + offset)` for each step). Offsets prevent correlated randomness between steps.

---

## Validation Checks (run after generation)

```python
def _validate_world(state: GameState, cx: int, cy: int) -> list[str]:
    """
    Post-generation sanity checks. Returns list of warning strings.
    Critical failures should abort and regenerate with seed+1.
    """
    warnings = []

    # Veil Hex reachable (not surrounded by impassable terrain)
    egg = state.dragon_egg
    veil_neighbours = hex_disk(egg.q, egg.r, 1)
    passable_neighbours = [
        h for h in veil_neighbours
        if state.world_map.cells.get(h, HexCell(terrain="mountain")).terrain != "mountain"
        and h != (egg.q, egg.r)
    ]
    if len(passable_neighbours) < 2:
        warnings.append("CRITICAL: Veil Hex has fewer than 2 passable neighbours")

    # Each clan has a pass within 5 hexes of their enclave angle
    for clan_id, (eq, er) in state.enclave_positions.items():
        angle   = math.atan2(er - cy, eq - cx)
        pass_hexes = [
            (q, r) for (q, r), cell in state.world_map.cells.items()
            if getattr(cell, 'is_pass', False)
        ]
        if not pass_hexes:
            warnings.append(f"CRITICAL: No pass hexes found")
            break

    # All 8 shrines placed
    shrine_count = sum(
        1 for cell in state.world_map.cells.values()
        if cell.is_shrine
    )
    if shrine_count != len(state.config.active_clan_ids):
        warnings.append(f"CRITICAL: {shrine_count} shrines placed, expected {len(state.config.active_clan_ids)}")

    # At least 10 villages placed
    village_count = sum(
        1 for cell in state.world_map.cells.values()
        if cell.is_village
    )
    if village_count < 10:
        warnings.append(f"WARNING: Only {village_count} villages placed (target 12)")

    return warnings
```
---

## Startup Engine Steps (Post World-Gen)  (Sprint 36)

After `generate_world()` returns a `GameState`, `startup_engine.py` runs additional
one-time setup steps before the first turn begins:

| Step | Function | File | Description |
|---|---|---|---|
| 14 | `seed_town_barkeeps()` | startup_engine.py | Assign barkeep name + personality per town from seeded pool |
| 15 | `seed_npc_rosters()` | startup_engine.py | Fill NPC slots in all town/castle interior blueprints |
| 16 | `generate_all_interiors()` | engine_interior_gen.py | Pre-generate all lair/town/castle interior maps from world seed |

Step 16 is the most expensive boot step (~50-200ms depending on lair count).
All interiors are stored in `state.interior_maps` keyed by location hex.
The world map continues to use the same seed-derived RNG state after Step 16.
