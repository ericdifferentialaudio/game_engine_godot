# Resource Schema

This is the data contract both games are written against. Any field added
to a schema class here is available to both games simultaneously — that
is the entire point of sharing a resource tree instead of maintaining two.

Schema *classes* (the shape) live in `core/addons/game_core/schema/`.
Schema *instances* (actual content, `.tres`/`.json`) live in `core/data/`.

## UnitDefinition (`core/addons/game_core/schema/unit_definition.gd`)

| Field           | Type              | Notes                                   |
|-----------------|-------------------|------------------------------------------|
| `unit_id`       | `StringName`      | Unique identifier                        |
| `display_name`  | `String`          | Human-readable name                      |
| `max_health`    | `float`           |                                           |
| `move_speed`    | `float`           | Generic; each game maps this to its own movement model |
| `base_virtues`  | `Dictionary`      | `virtue_id (StringName) -> float`        |
| `tags`          | `PackedStringArray` | Free-form classification tags          |

Data lives in `core/data/units/`.

## ItemDefinition (`core/addons/game_core/schema/item_definition.gd`)

| Field           | Type              | Notes                    |
|-----------------|-------------------|--------------------------|
| `item_id`       | `StringName`      | Unique identifier        |
| `display_name`  | `String`          |                          |
| `description`   | `String`          |                          |
| `stack_size`    | `int`             | Max stack in inventory   |
| `tags`          | `PackedStringArray` |                        |

Data lives in `core/data/items/`.

## TokenDefinition (`core/addons/game_core/schema/token_definition.gd`)

| Field              | Type                | Notes                                    |
|---------------------|---------------------|--------------------------------------------|
| `token_id`          | `StringName`        | Unique identifier                          |
| `display_name`      | `String`            |                                            |
| `summary`           | `String`            | Short description of the information token |
| `related_fact_ids`  | `PackedStringArray` | Links to `WorldFact.fact_id` entries       |

Data lives in `core/data/tokens/`.

## VirtueDefinition (`core/addons/game_core/schema/virtue_definition.gd`)

| Field           | Type         | Notes                          |
|-----------------|--------------|----------------------------------|
| `virtue_id`     | `StringName` | Unique identifier                |
| `display_name`  | `String`     |                                  |
| `min_value`     | `float`      | Clamp bound                      |
| `max_value`     | `float`      | Clamp bound                      |
| `default_value` | `float`      | Initial value on reset           |

Data lives in `core/data/virtues/`. Runtime values are tracked by the
`VirtueSystem` autoload, not stored on the resource itself.

## WorldFact (`core/addons/game_core/schema/world_fact.gd`)

| Field           | Type      | Notes                                  |
|-----------------|-----------|-------------------------------------------|
| `fact_id`       | `StringName` | Unique identifier                       |
| `description`   | `String`  | Human-readable description of the fact    |
| `default_value` | `Variant` | Initial value if never committed          |

Data lives in `core/data/lore/`. Runtime values are tracked by the
`WorldStateManager` autoload.

## Changing the schema

1. Edit the relevant `.gd` class in `core/addons/game_core/schema/`.
2. Update this document.
3. Add/adjust a GUT test in `core/tests/unit/` if the change affects
   manager behavior (not just a passive data field).
4. Run `tools/run_tests.ps1` — a schema change must not break either
   game's test suite before it lands on `main`.
5. If the change is breaking (renamed/removed field or manager method),
   log it so both games can be updated deliberately rather than silently
   picking up a break next time they're opened.
