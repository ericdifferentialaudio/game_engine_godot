# 03 — The Intel System

This is the differentiating pillar. Design goal: **information behaves like a
resource with quality**, not a boolean quest flag.

## IntelToken (definition, `intel.json`)
| field                | purpose |
|----------------------|---------|
| `id`, `title`, `summary` | identity & journal text |
| `subject`            | what it's about (NPC, place, faction, item). Enables "what do I know about X?" |
| `category`           | rumor / fact / secret / location / password / schedule / map / lore |
| `tags`               | free grouping, queryable |
| `facts`              | structured payload game logic can read (`{"landmark": "old_mill"}`) |
| `reliability`        | starting confidence 0..1 |
| `corroboration_step` | how much each *independent* source adds |
| `expires_after`      | seconds until stale (schedules, caravan timings) |
| `conflicts`          | ids of contradicting tokens |
| `value`              | sale price to information brokers |

## Runtime (journal instance)
`reliability`, `sources[]`, `acquired_at`. Re-acquiring a token from a *new* POI
calls `corroborate()`; same source twice does nothing. Expired tokens fail
`has` queries and are shown as stale in the journal.

## IntelQuery — gating language
Used by portals (`requires`), POIs (`hidden_until`), interactions, shop stock and
dialogue choices. Pure, side-effect-free, validated offline.

```json
{"has": "rumor_crypt_location", "min_reliability": 0.7}
{"subject": "baron_veyle", "count": 2}
{"tag": "location"}
{"fact": ["rumor_crypt_location", "landmark", "old_mill"]}
{"flag": "asked_rumour"}
{"all": [ ... ]}  {"any": [ ... ]}  {"not": { ... }}
```

## Flows enabled out of the box
- **Rumour → confirmation**: innkeeper (0.4) + millstone (0.7) → corroborated → vault POI (needs ≥0.8) appears.
- **Passwords unlock trade**: Marrow's hidden stock requires `rumor_marrow_smuggles`.
- **Contradictions**: `schedule_ossuary_guard` vs `..._false`; UI can surface both and the player picks whom to trust.
- **Time pressure**: `expires_after` on schedules.
- **Selling intel**: `Shop.sell_intel()` pays `value * reliability`.
- **Unlock watchers**: `IntelRegistry.watch_unlock(id, query)` fires `intel_query_unlocked` once — hook achievements, world changes, NPC reactions.

## Planned extensions (keep in mind when adding data)
1. **Inference rules** — `{"infer": "x", "from": [q1, q2]}` derives new tokens.
2. **Source trust** — per-NPC trust modifier feeding reliability.
3. **Intel decay & leaks** — selling intel lowers its value elsewhere.
4. **Perception stat** — `CharacterStats.perception` scales `discover_radius` and initial reliability.
5. **Relationship graph** — subjects as nodes, tokens as edges → native module when large.
