# 03 · Turns & Time

## Modes (`game.json → turns.mode`)
| mode | who acts when | turn ends when |
|---|---|---|
| `sequential` | one faction at a time in `turn_order` (`EventBus.active_faction_changed`) | last faction commits |
| `simultaneous` | every faction during ACTIONS | all commit, or `timer_seconds` expires |
| `wego` | like simultaneous; games queue orders and resolve them in RESOLVE | same |
| `realtime_pause` | continuous; `GameClock` ticks `seconds_per_tick`; **Space** pauses | `ticks_per_turn` ticks elapsed |

AI factions act inside `Faction.run_ai_turn()` (unit-level `AIController` by default, or a
registered faction-level strategy) and commit immediately. Non-turn-taking factions
(`control: neutral|hostile`) act during RESOLVE.

## Phases
Every turn: `BEGIN → UPKEEP → ACTIONS → RESOLVE → END`, each emitting
`EventBus.turn_phase_changed(turn, phase)`. Hook the phase you need:

| phase | engine work |
|---|---|
| BEGIN | `GameClock.advance_turn()`, `turn_started`; non-turn factions refresh units |
| UPKEEP | intel staleness sweep; faction yields + upkeep; site respawns/yields; unit statuses/AP refresh |
| ACTIONS | player input; AI turns; commits |
| RESOLVE | intel spread + derivations; monsters/neutral units act |
| END | `turn_ended`; victory check |

## GameClock
`turn` (1-based), `tick`, `now()` = fractional turn used for **all** decay/age maths,
calendar labels (`start_year`, `years_per_turn`, BC/AD suffixes), eras (`from_turn`),
`era_changed` signal. Persisted.

## Committing
Human: End Turn button or **Enter** → `TurnManager.commit_faction(player)`. Only
possible while `is_faction_active(player)`. `force_end_turn()` exists for debug/timers.

## Timers
`timer_seconds > 0` in simultaneous/wego counts down during ACTIONS; HUD shows it via
`TurnManager.time_left()`.
