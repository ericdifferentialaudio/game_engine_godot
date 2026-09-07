## Global, decoupled signal hub.
##
## Systems never reference each other directly for cross-cutting events; they
## emit/connect through EventBus. Keep this file the single source of truth for
## engine-level events so new games can discover what they may hook into.
extends Node

# --- Map lifecycle -----------------------------------------------------------
## Emitted just before a map scene is unloaded. [param map_id] is the MapDefinition id.
signal map_unloading(map_id: String)
## Emitted after a map scene is instanced and its POIs/portals registered.
signal map_loaded(map_id: String, depth: int)
## Emitted when the player traverses a portal (descend into submap or return).
signal map_transition(from_id: String, to_id: String, portal_id: String)

# --- Points of interest ------------------------------------------------------
signal poi_discovered(poi_id: String, map_id: String)
signal poi_focused(poi_id: String)          ## Player is looking at / near a POI.
signal poi_unfocused(poi_id: String)
signal poi_interacted(poi_id: String, interaction_kind: String)

# --- Intel -------------------------------------------------------------------
signal intel_acquired(token_id: String, source_poi: String)
signal intel_updated(token_id: String)      ## Reliability/facts changed.
signal intel_expired(token_id: String)
signal intel_query_unlocked(unlock_id: String) ## A gated thing became available.

# --- Economy / inventory -----------------------------------------------------
signal item_acquired(item_id: String, count: int)
signal item_removed(item_id: String, count: int)
signal currency_changed(currency_id: String, new_amount: int)
signal purchase_completed(shop_id: String, item_id: String, price: int)
signal purchase_failed(shop_id: String, item_id: String, reason: String)

# --- Rewards / progression ---------------------------------------------------
signal reward_granted(reward_id: String, poi_id: String)
signal flag_set(flag: String, value: bool)
signal score_changed(total: int, delta: int)

# --- Player / UI -------------------------------------------------------------
signal player_spawned(player: Node3D)
signal interaction_prompt(text: String, visible: bool)
signal notification(text: String, category: String)
signal game_state_changed(previous: int, current: int)

# --- Game clock --------------------------------------------------------------
signal hour_changed(hour: int)
signal day_changed(day: int)
signal day_phase_changed(phase: String)     ## dawn | day | dusk | night

# --- Actors / combat ---------------------------------------------------------
signal actor_spawned(actor: Node3D)
signal actor_died(actor: Node3D, killer: Node3D)
signal actor_damaged(actor: Node3D, amount: float, damage_type: String, source: Node3D)
signal actor_healed(actor: Node3D, amount: float)
signal status_applied(actor: Node3D, effect_id: String)
signal status_removed(actor: Node3D, effect_id: String)
signal ability_cast(actor: Node3D, ability_id: String)
signal equipment_changed(actor: Node3D, slot: String, item_id: String)  ## "" item_id = unequipped
signal item_identified(item_id: String)
signal noise_emitted(position: Vector3, loudness: float, source: Node3D)  ## Heard by Perception.
signal awareness_changed(actor: Node3D, target: Node3D, level: int)
signal faction_reputation_changed(faction_id: String, value: int)

# --- Persistence -------------------------------------------------------------
signal save_requested(slot: String)
signal save_completed(slot: String)
signal load_completed(slot: String)
