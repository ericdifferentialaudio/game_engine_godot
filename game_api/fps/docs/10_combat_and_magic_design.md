# 10 — Combat & Magic: target design (M2–M4)

M1 shipped the **data model and math**; this document fixes the design the
execution pipeline will implement so M1 stubs line up with it.

## Principles
1. **One pipeline for everything.** A sword swing, a firebolt, a potion, and a
   monster's claw are all `AbilityDefinition`s executed by `AbilityCaster`.
2. **Data first.** New spells/weapons/monsters should be JSON-only additions.
3. **Intel is a combat resource.** Weaknesses, safe windows, boss phases and
   item rites are learned; knowing them changes the fight (UI reveals, gates lift).
4. **Deterministic where it matters.** Damage rolls take an RNG so replays/tests
   are stable; loot uses seeded RNG per map + kill.

## Ability execution (M2)
```
cast(id, target)
  ├─ can_cast: known, alive, not stunned/silenced, cooldown, costs, requires (intel), requires_stats
  ├─ spend costs, start cooldown, emit noise
  ├─ cast_time > 0 → wind-up (interruptible) → _finish_cast
  └─ _execute(def, target)
       ├─ resolve TARGETING → list of (Actor, hit_position)
       │    self | melee_arc (radius+arc sweep) | projectile (spawn Projectile node)
       │    beam (raycast) | aoe_self / aoe_target / ground (sphere query) | touch | summon
       ├─ for each target: build DamageInfo
       │    base = def.damage (+ weapon.damage if scale_with_weapon) (+ scaling × caster stats)
       │    crit roll (crit_chance) ; sneak-attack tag if target unaware of caster
       │    target.take_damage(info)      → Damageable → Health
       │    apply_effects (chance, target=enemy|self|ally)
       │    fire procs: caster equipment procs (on_hit/on_crit), target procs (on_damaged)
       ├─ heal / resources / knockback / teleport / spawn / reveal_intel steps in def.effects[]
       └─ VFX/SFX by asset key; animation on view-model / actor
```
Projectiles are pooled `Area3D` nodes on a "Projectile" layer with speed,
gravity, pierce, ammo consumption, and owner faction for friendly-fire rules.

## Damage types & mitigation (implemented)
`physical/slash/pierce/blunt` → armour `a/(a+K)` then resistance; elemental
(`fire frost lightning poison arcane holy shadow`) → resistance only; `true` →
none. Resistances clamp to `[min_resistance, max_resistance]`. Configurable
in `game.json.combat`.

## Status effects (implemented data + ticking)
Stacking modes, GameClock durations, tick damage/heal/resources, stat mods,
resistance mods, flags (`stunned`, `rooted`, `silenced`, `invisible`,
`silent_steps`, `revealed`), immunities, dispel. M2 adds VFX and UI icons.

## First-person feel (M2)
View-model node under the camera: weapon/hands mesh, animation player driven
by ability `animation`; camera kick/hit-stop on hit; blocking (off-hand shield
sets `blocked` on incoming DamageInfo), dodge step (stamina), stagger threshold.

## Monsters & AI (M3)
Utility scoring over `known_abilities()` using `ai_tags`/`ai_weight` and
situation (own HP, ally HP, range, target awareness); patrol/schedule/investigate
from `Perception.last_noise`; group alert propagation; boss `phases[]` swap
ability sets and apply effects at HP thresholds; `weakness_intel` unlocks UI
display of resistances and raises reliability of related tokens on observation.

## Progression & loot (M4)
Loot tables (weighted, level-scaled, seeded), affix pools with prefix/suffix
stat/effect/proc bundles, identification via intel/sage/scroll, XP levels
*or* knowledge unlocks (`learn_ability` when an IntelQuery becomes true) — a
game picks either or both in `game.json.progression`.

## Stealth crossover
Player footsteps emit `noise_emitted` (louder when sprinting, quieter with
`silent_steps`); `Perception` hears within `hearing × loudness`. Unaware targets
take sneak-attack multipliers. Invisibility flag defeats sight checks.
