## Global, decoupled signal hub.
##
## Systems never reference each other directly for cross-cutting events; they
## emit/connect through EventBus. Keep this file the single source of truth for
## engine-level events so new games can discover what they may hook into.
extends Node

# --- Game / turn lifecycle -----------------------------------------------------
signal game_state_changed(previous: int, current: int)
signal game_started(game_id: String)
## A new turn begins. [param turn] is 1-based.
signal turn_started(turn: int)
signal turn_ended(turn: int)
## Turn phase changed (see TurnManager.Phase). Emitted every time a phase advances.
signal turn_phase_changed(turn: int, phase: int)
## In sequential mode, the faction whose turn it is changed.
signal active_faction_changed(faction_id: String)
## A faction signalled it has finished its actions for this turn.
signal faction_turn_committed(faction_id: String, turn: int)
## GameClock ticked (time-based modes). [param delta_ticks] is usually 1.
signal clock_tick(tick: int, delta_ticks: int)
signal clock_paused(paused: bool)
signal era_changed(era_id: String)

# --- World / map ----------------------------------------------------------------
signal world_generating(map_id: String)
## World map model is populated and the renderer has drawn it.
signal world_loaded(map_id: String, depth: int)
signal world_unloading(map_id: String)
## Descended into / returned from a site sub-map (dungeon, city interior...).
signal map_transition(from_id: String, to_id: String, portal_id: String)
signal tile_changed(coord: Vector2i, field: String)
signal tile_owner_changed(coord: Vector2i, old_faction: String, new_faction: String)
signal tile_hovered(coord: Vector2i)
signal tile_selected(coord: Vector2i)
signal tile_commanded(coord: Vector2i)               ## Right-click / secondary action.
## Fog-of-war changed for a faction: coords that became visible/explored.
signal visibility_changed(faction_id: String, revealed: Array)

# --- Sites (POIs on tiles) -------------------------------------------------------
signal site_discovered(site_id: String, faction_id: String)
signal site_entered(site_id: String, unit_id: String)
signal site_interacted(site_id: String, interaction_kind: String)

# --- Entities: units / heroes / npcs / monsters ----------------------------------
signal unit_spawned(unit_id: String, faction_id: String, coord: Vector2i)
signal unit_moved(unit_id: String, from: Vector2i, to: Vector2i)
signal unit_selected(unit_id: String)
signal unit_deselected(unit_id: String)
signal unit_damaged(unit_id: String, amount: int, source_id: String)
signal unit_healed(unit_id: String, amount: int)
signal unit_died(unit_id: String, killer_id: String)
signal unit_removed(unit_id: String)
signal unit_stat_changed(unit_id: String, stat: String, value: float, max_value: float)
signal unit_leveled(unit_id: String, level: int)
signal unit_status_applied(unit_id: String, status_id: String)
signal unit_status_removed(unit_id: String, status_id: String)
signal unit_action_points_changed(unit_id: String, remaining: float)
signal ability_used(unit_id: String, ability_id: String, target)

# --- Combat -----------------------------------------------------------------------
signal combat_started(attacker_id: String, defender_id: String)
signal combat_resolved(attacker_id: String, defender_id: String, result: Dictionary)

# --- Factions / diplomacy / economy ----------------------------------------------
signal faction_resource_changed(faction_id: String, resource_id: String, new_amount: float)
signal diplomacy_changed(faction_a: String, faction_b: String, stance: String)
signal faction_eliminated(faction_id: String)
signal victory(faction_id: String, condition_id: String)

# --- Intel --------------------------------------------------------------------------
## [param holder] is a faction id (faction journals) — every acquisition is scoped.
signal intel_acquired(holder: String, token_id: String, source: String)
signal intel_updated(holder: String, token_id: String)     ## Reliability/facts changed.
signal intel_expired(holder: String, token_id: String)
signal intel_derived(holder: String, token_id: String, rule_id: String)
signal intel_spread(from_holder: String, to_holder: String, token_id: String)
signal intel_traded(from_holder: String, to_holder: String, token_id: String, price: int)
signal intel_contradiction(holder: String, token_a: String, token_b: String)
signal intel_query_unlocked(holder: String, unlock_id: String) ## A gated thing became available.

# --- Items / inventory / shops ---------------------------------------------------
signal item_acquired(owner_id: String, item_id: String, count: int)
signal item_removed(owner_id: String, item_id: String, count: int)
signal item_equipped(owner_id: String, item_id: String, slot: String)
signal item_unequipped(owner_id: String, item_id: String, slot: String)
signal item_used(owner_id: String, item_id: String)
signal currency_changed(owner_id: String, currency_id: String, new_amount: int)
signal purchase_completed(shop_id: String, item_id: String, price: int)
signal purchase_failed(shop_id: String, item_id: String, reason: String)

# --- Rewards / progression -------------------------------------------------------
signal reward_granted(reward_id: String, source_id: String)
signal flag_set(flag: String, value: bool)
signal quest_flag_changed(quest_id: String, stage: String)

# --- Dialogue / UI --------------------------------------------------------------------
signal dialogue_started(npc_id: String)
signal dialogue_ended(npc_id: String)
signal notification(text: String, category: String)
signal camera_focus_requested(coord: Vector2i)

# --- Persistence ----------------------------------------------------------------------
signal save_requested(slot: String)
signal save_completed(slot: String)
signal load_completed(slot: String)
