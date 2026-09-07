# 04 — Points of Interest & Interactions

A **POI** is anything worth walking to. It is an `Area3D` on the *Interactable*
layer built from a `PoiDefinition` (`pois.json`), with:

- **Discovery**: proximity sphere (`discover_radius`) → `poi_discovered`, persisted.
- **Visibility gating**: `hidden_until` IntelQuery — the POI does not exist for the
  player until they know enough (re-evaluated whenever intel is acquired).
- **Interaction**: the player's `InteractionRay` focuses the `Interactable`
  component; pressing *interact* runs the POI's ordered `interactions` list.

## Interaction strategies (`framework/poi/interactions/`)
| kind       | effect | key fields |
|------------|--------|-----------|
| `intel`    | grant tokens | `tokens[]`, `reliability`, `message` |
| `reward`   | items / currency / flags | `items{}`, `currency{}`, `set_flags[]` |
| `shop`     | open shop (stock may be intel-gated) | `shop_id`, `currency`, `stock[]` |
| `dialogue` | branching nodes granting intel/flags | `start`, `nodes{}` |
| `portal`   | map transition via a map portal id | `portal_id` |

Common modifiers on any interaction: `requires` (IntelQuery), `flags[]`, `once`,
`consumes` (default true: stop after this one runs; set false for silent
side-effects like "mark visited" before opening a shop).

Evaluation order matters: the first interaction whose `can_run()` passes runs;
if it `consumes`, evaluation stops. Use this for "first visit gives intel, later
visits open the shop" patterns.

## Adding a new kind
```gdscript
class_name BribeInteraction
extends Interaction
func _on_setup(): kind = "bribe"
func _execute(by):
    if by.get_node("Inventory").spend_currency("gold", spec.get("cost", 10)):
        for t in spec.get("tokens", []): IntelRegistry.acquire(t, poi.definition.id)
```
Register at boot: `InteractionFactory.register("bribe", BribeInteraction)` and add
`"bribe"` to `schemas/pois.schema.json` + `tools/validate_data.py KNOWN_INTERACTIONS`.

## UI contract
Logic never depends on UI. `DialogueInteraction` / `ShopInteraction` look for a
node in group `dialogue_ui` / `shop_ui` with `open(...)`; absent that they run
headless (auto-walk / print), which is what makes them testable.
