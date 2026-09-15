# Inter-Clan Sentiment System — Sprint 34

## Purpose

Replaces the flat `encounter_memory` counter with a rich directional sentiment
model.  Each ordered clan-pair `(observer → target)` holds an `InterClanSentiment`
record that drives AI goal-score modulation and diplomacy decisions.

---

## Data Model

`ClanInstance.inter_clan_sentiment: dict[target_clan_id → InterClanSentiment]`

### Dimensions (all 0.0–1.0)

| Dimension    | Meaning                                     | Decay ×/turn |
|--------------|---------------------------------------------|--------------|
| `hostility`  | Want to attack target now                   | ×0.95        |
| `grievance`  | Accumulated harm inflicted by target        | ×0.97        |
| `fear`       | How threatening target is (shrine lead)     | ×0.96 + floor|
| `rivalry`    | Competition for shrine/egg objectives       | ×0.98 + floor|
| `grudge`     | Long-lasting enmity from betrayal           | ×0.992       |
| `appeasement`| Desire to avoid conflict with target        | ×0.93        |
| `opportunity`| Target looks weak — good time to strike     | recalc/turn  |

### Tracking Metadata

- `last_aggression_turn` — turn target last attacked this clan
- `kills_by_them` / `kills_by_us` — kill exchange counters
- `alliances_broken_by_them` — betrayal counter (drives `grudge`)
- `diplomatic_offers_made` — total offers made by target
- `last_updated` — turn record was last touched

---

## Event Triggers

### Combat
| Event                        | Affected dims                                    |
|------------------------------|--------------------------------------------------|
| `x_kills_my_unit`            | hostility+0.25, grievance+0.20, fear+0.10, appeasement−0.15 |
| `i_kill_x_unit`              | hostility+0.10, opportunity+0.15, fear−0.08     |
| `x_attacks_me_no_kill`       | hostility+0.12, fear+0.05, grievance+0.08        |
| `x_attacks_near_enclave`     | fear+0.20, hostility+0.15, appeasement−0.10     |

### Shrine
| Event                          | Affected dims                                  |
|--------------------------------|------------------------------------------------|
| `x_meditates_shrine_i_needed`  | rivalry+0.20, hostility+0.10, grievance+0.05  |
| `x_near_avatar_threshold`      | fear+0.30, hostility+0.20, rivalry floor=0.60 |
| `x_achieves_avatar`            | fear+0.40, hostility+0.30, rivalry floor=0.90 |
| `x_takes_egg`                  | rivalry+0.50, hostility+0.30, fear+0.20        |

### Diplomacy
| Event                      | Affected dims                                          |
|----------------------------|--------------------------------------------------------|
| `alliance_formed_with_x`   | hostility−0.40, grievance−0.20, appeasement+0.30, rivalry−0.15 |
| `x_breaks_alliance_with_me`| grudge+0.60, hostility+0.50, fear+0.15               |
| `x_breaks_nap_with_me`     | grudge+0.40, hostility+0.35, rivalry+0.10             |
| `x_makes_diplomatic_offer` | appeasement+0.08, hostility−0.05                       |

### Intel (per-tick visibility scan)
| Event                        | Affected dims              |
|------------------------------|----------------------------|
| `x_units_spotted_approaching`| fear+0.15, hostility+0.10 |
| `x_units_near_my_shrine`     | rivalry+0.15, hostility+0.08 |

---

## Per-Turn Passive Floors

1. **Fear floor** = `(target_shrines / threshold) × 0.30`  
   Prevents fear from decaying to 0 when a rival is clearly winning.

2. **Rivalry floor** = `shared_unmeditated_shrines × 0.08` (cap 0.40)  
   Clans competing for the same shrines always feel some rivalry.

3. **Opportunity recalc** = derived from `target_alive_units` and `hostility`.  
   Only active when `hostility ≥ 0.15`.

---

## Goal Score Modifiers

Applied by `apply_sentiment_to_goal_scores()` after `evaluate_goal()` scoring.
All additions are **additive** and **capped at +0.25 per goal**.

| Condition                                         | Goal boosted            | Delta             |
|---------------------------------------------------|-------------------------|-------------------|
| hostility[X] > 0.5 AND X is nearest enemy        | `attack_rival`          | +hostility × 0.20 |
| opportunity[X] > 0.5 AND X is nearest enemy      | `attack_rival`          | +opportunity × 0.18|
| fear[X] > 0.6 AND X units ≤10h of enclave        | `defend_enclave`        | +fear × 0.25      |
| rivalry[X] > 0.6 AND X near target shrine        | `contest_shrine_zone`   | +rivalry × 0.20   |
| grievance[X] > 0.5                                | `produce_units`         | +grievance × 0.15 |
| appeasement[X] > 0.5                              | `negotiate_rights`      | +appeasement × 0.12|
| appeasement[X] > 0.5                              | `pursue_alliance`       | +appeasement × 0.15|
| rivalry[X] > 0.7 AND X carrying egg              | `contest_egg_carrier`   | +rivalry × 0.25   |
| grudge[X] > 0.60                                  | *diplomacy only*        | blocks accept     |

---

## Spike Logging

When any dimension crosses **0.70**, a `SENTIMENT_SPIKE` event is appended to
`state.combat_log`:

```json
{
  "event":       "SENTIMENT_SPIKE",
  "turn":        45,
  "clan_id":     "fighter",
  "target_clan": "necromancer",
  "dimension":   "hostility",
  "value":       0.742,
  "trigger":     "x_kills_my_unit"
}
```

---

## Call Sites

| Function                        | Called from                          | When                         |
|---------------------------------|--------------------------------------|------------------------------|
| `init_inter_clan_sentiments()`  | `startup_engine.StartupEngine`       | Game start (after clans set) |
| `update_on_attack()`            | `engine_headless._kill_unit()`       | On every kill                |
| `update_on_shrine_meditated()`  | `engine_headless.complete_meditation()` | On shrine completion      |
| `update_on_diplomacy()`         | `engine_diplomacy` (alliance/NAP)    | On diplomatic events         |
| `update_on_egg_taken()`         | `engine_headless.update_seeker_egg()`| On egg pickup                |
| `update_sentiment_tick()`       | `simulate/runner.py` turn loop       | After auto_combat_hexes      |
| `apply_sentiment_to_goal_scores()` | `engine_ai.process_ai_turn()`    | After evaluate_goal loop     |
| `grudge_blocks_diplomacy()`     | `engine_ai.ai_diplomacy_response()`  | On diplomatic offer receipt  |

---

## Config

Inline constants in `engine_sentiment.py` (`_DECAY`, `_DELTAS`).  
External JSON stub reserved at `assets/data/sentiment_config.json` for future tuning.

---

## Expected Simulation Effects

- **Longer games**: fear + appeasement dampen early all-out rushes, allowing
  building / tech turns to accumulate before decisive conflict.
- **Coalition vs leader**: `fear` + `rivalry` floor from shrine-lead means
  near-Avatar clans attract coordinated intercepts from 2–3 rivals simultaneously.
- **Grudge persistence**: alliances broken ≥ 3 turns ago leave `grudge ≥ 0.60`
  which blocks re-alliance, forcing new diplomatic pairings rather than the same
  clans reuniting every game.
- **Grievance-driven production**: clans that absorb kills invest in unit queues
  rather than purely running the shrine chain, diversifying mid-game activity.
