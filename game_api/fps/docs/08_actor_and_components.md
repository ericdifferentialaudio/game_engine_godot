# 08 — Actors & Components

Every living thing — player, NPC, monster, boss, summon — is an **`Actor`**
(`CharacterBody3D`) composed of child **components**. There is no separate
"player class"; the player is an Actor whose Brain is a `PlayerBrain`. This
guarantees every verb works on everyone: anything can be damaged, poisoned,
robbed, charmed, or talked to through the same API.

```
Actor (CharacterBody3D)  framework/actor/actor.gd
├─ CollisionShape3D
├─ Health          hp, regen (GameClock), died signal
├─ Stats           base + source-tagged modifier stack -> final
├─ Resources       mana / stamina / … pools with real-time regen
├─ StatusEffects   EffectDefinition instances, durations on GameClock, ticks, flags
├─ Inventory       ItemInstance stacks + currencies
├─ Equipment       slots -> stats/effects/abilities; intel & stat gated
├─ AbilityCaster   known abilities, costs, cooldowns, cast() (execution M2)
├─ Perception      sight cone + LOS, hearing (noise events), awareness levels
├─ Faction         faction id, hostility via FactionDefinition + reputation
├─ Damageable      gathers armour/resist/immunities -> DamageCalculator -> Health
└─ Brain           exactly one: PlayerBrain | AIBrain
```

Missing components are **auto-created** (`auto_create_components`), so a bare
`Actor` node with `actor_def_id = "skeleton_soldier"` is fully functional.

## Lifecycle
1. `_ready()` discovers/creates components, calls `component.setup(actor)`.
2. If `actor_def_id` is set, `apply_definition()` pushes `ActorDefinition`
   data into each component (`_definition_applied`): base stats, resources,
   faction, abilities, equipment, inventory, senses, behaviour.
3. `EventBus.actor_spawned` fires.

## Stats model
`final = (base + Σ flat) × (1 + Σ percent)`. Modifiers are keyed by **source**
(`"equip:main_hand"`, `"effect:burning"`), so unequipping or expiry removes a
whole group atomically. Any string is a stat; conventions used by the framework:

| stat | used by |
|---|---|
| `max_health`, `max_<resource>` | Health / Resources maxima |
| `armor` | physical mitigation |
| `dodge`, `crit_chance` | Damageable / attacks |
| `move_speed` | both Brains |
| `resist_<type>` | additional resistance source |
| `perception` | discovery radius / intel reliability (M3) |
| `strength`, `agility`, `intellect` | ability scaling, item requirements |

## Damage flow
`DamageInfo` (typed amounts, source, crit, tags) → `Actor.take_damage()` →
`Damageable.receive()` (hurtbox multiplier, armour, resistances from
definition + equipment + effects, immunities, dodge) → `DamageCalculator.resolve()`
→ `Health.apply_damage()` → `died` / `EventBus.actor_died`. Attacking an NPC
adds the attacker to its `Faction.personal_hostiles`.

## Brains
- **PlayerBrain** — mouse-look, WASD, sprint (stamina), jump, head-bob,
  footstep noise events, hotbar (`attack` = main-hand weapon's first ability
  or `game.json.unarmed_ability`; `cast_1..3` = `default_hotbar`).
- **AIBrain** — state skeleton (IDLE/PATROL/SCHEDULE/INVESTIGATE/CHASE/ATTACK/
  FLEE/RETURN/DEAD), threat from Perception, `flee_below`, `preferred_range`,
  first-castable-offensive-ability attack. M3 replaces `think()` with utility/BT.

## Persistence
`Actor.to_save_data()` aggregates every component's `to_save_data()`. Stats save
only `base`; modifiers are re-applied by their sources (equipment, effects) on load.

## Testing
`tests/godot/test_actor_items.gd`, `test_combat_components.gd` — run with
`.\tools\godot.ps1 test`.
