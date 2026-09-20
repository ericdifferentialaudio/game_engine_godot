# Narrative, Assets & Screen — shared framework

Everything a conversation-driven game needs that is not graphics: an Ink
dialogue engine, two distinct asset systems, per-NPC standing, a context
bundle, a reusable conversation-pattern library, validators, and the window
layout/registry.

All of it lives in `core/addons/game_core/` and reaches both engine layers via
`./tools/sync_core.ps1`.

---

## The shape of it

| Piece | Where | What it is |
|---|---|---|
| `CoreInkEngine` | `narrative/core_ink_engine.gd` | autoload; load/advance/choose/save a story |
| `CoreInkBindings` | `narrative/core_ink_bindings.gd` | the EXTERNAL functions a writer may call |
| `CoreContextBuilder` | `narrative/core_context_builder.gd` | pushes world context into a story |
| `CoreInkValidator` | `narrative/core_ink_validator.gd` | static + context-simulation checks |
| `CoreKnowledge` | `gameplay/core_knowledge.gd` | autoload; **boolean** knowledge |
| `CoreAssets` | `gameplay/core_assets.gd` | autoload; **counted** physical assets |
| `CoreStanding` | `gameplay/core_standing.gd` | autoload; per-NPC relationship |
| `CoreSaveBundle` | `core_save_bundle.gd` | one dict holding every core system's state |
| `CoreWindowRegistry` | `ui/core_window_registry.gd` | autoload; role → live window |
| `CoreLayoutDefinition` / `Builder` | `ui/` | data-driven screen from JSON |
| pattern library | `core/ink/patterns/patterns.ink` | barter · interrogate · persuade · confide |

**inkgd** (`core/addons/inkgd/`) is vendored at a pinned commit — see
`core/addons/inkgd/VENDOR.md`. `CoreInkEngine` is the only file that touches
it, so swapping the runtime is a one-file change.

---

## Two asset systems, deliberately

They are separate because they behave differently.

**Knowledge is boolean.** You know a thing or you don't. It is permanent unless
a game explicitly removes it. Under the hood it is a façade over the existing
`CoreIntel` journal, so it keeps reliability, corroboration, provenance,
decay and `conflicts` — but narrative sees one question: `knows(id)`.

*Hearing a rumour is not knowing it.* A token authored at `reliability: 0.3`
reads **false** from `knows()`. The same fact from a reliable source, or
corroborated by a second independent source, crosses the threshold and reads
true. A debunked token always reads false.

```json
"rules": { "knowledge": { "belief_threshold": 0.5 } }
```

| Call | Means |
|---|---|
| `knows(id)` | believed firmly enough to act on — use this for gates |
| `believes(id, 0.3)` | believed at least this much |
| `heard_of(id)` | encountered at all, however dubious — flavour only |
| `disbelieves(id)` | has proven it is a lie |

**Physical assets are counted.** They can be spent, traded and lost. Currency
and objects share one vocabulary; `CoreItemDefinition.category` decides which
is which, so a writer says `spend_asset("zorkmid", 3)` and
`give_asset("brass_lantern", 1)` without caring.

**Standing is a third, lightweight value** — neither boolean nor spendable. The
core supplies the score, named tiers, optional decay and persistence; each game
defines what the tiers mean:

```json
"rules": { "standing": {
  "min": -100, "max": 100, "decay_per_unit_time": 0, "decay_grace": 10,
  "tiers": [ {"id": "stranger", "at": -100}, {"id": "neutral", "at": 0},
             {"id": "friendly", "at": 25}, {"id": "trusted", "at": 60} ] } }
```

Gate on the **tier**, not the number — `standing_at_least(npc, "trusted")` —
so retuning the numbers does not invalidate the writing. Standing is per-NPC,
with an optional place qualifier (`"fence@round_room"`) for games where the
same person is regarded differently in different towns.

---

## Adding narrative to a new game

**1. Write the .ink.** Put it in `games/<id>/ink/`, include the shared
patterns, and declare the externals you use:

```ink
INCLUDE patterns.ink

VAR location = ""
VAR time_of_day = "day"
VAR npc_id = ""
VAR npc_standing = "neutral"

=== barkeep ===
{ npc_standing == "stranger": He eyes you. | "Evening." }
+ { has_asset("coin", 2) } [Buy a drink.]
    -> barter("ale", 1, "coin", 2, npc_id, "") ->
    { barter_result == BARTER_BOUGHT: He slides it over. }
    -> barkeep
+ [Leave.] -> END
```

> `npc_id`, not `npc` — `npc` is a parameter name in the pattern library, and
> Ink forbids a global sharing a name with a knot argument.

**2. Compile it.** `inklecate` is **not** a build dependency: commit the
`.ink.json` and only writers need the compiler.

```powershell
./tools/inklecate/inklecate.exe -o games/<id>/ink/scene.ink.json games/<id>/ink/scene.ink
```

**3. Define the ids** in the game's own `intel.json` (knowledge) and
`items.json` (assets). The framework hard-codes no content.

**4. Run it:**

```gdscript
CoreInkEngine.load_story("res://games/my_game/ink/scene.ink.json")
var bindings := CoreInkBindings.new("player", "barkeep")
bindings.bind_all(CoreInkEngine)       # keep a reference alive

var ctx := CoreContextBuilder.new()
ctx.npc_id = "barkeep"
ctx.location = "the_anchor"
ctx.stat_bands = {"intellect": [["dull", 0], ["sharp", 12]]}
ctx.push(CoreInkEngine)
ctx.watch()                            # keep the snapshot live

for line in CoreInkEngine.continue_all():
    CoreWindowRegistry.append_line("dialogue", line)
CoreWindowRegistry.get_text_window("dialogue").set_choices(CoreInkEngine.choices())
```

### Why context arrives two ways

Slow-moving scalars (location, time of day, stat bands, standing tier) are
pushed as **Ink variables** — cheap to test, and usable inside text as
`{location}`. Everything volatile is an **external function**, evaluated at the
moment Ink asks, so an asset gained mid-conversation is visible to the very
next condition in the same scene. `ctx.watch()` re-pushes the snapshot on any
change, so the two halves never disagree.

### The pattern library

`barter` · `interrogate` · `persuade` · `confide`. Each is a tunnel that leaves
its outcome in a global (`barter_result` etc.) and returns; the calling file
decides what it *means*. Patterns own the mechanics, your file owns the voice.
Key story beats should still be bespoke — this is for the systemic hundred.

Note `interrogate(..., trust, ...)`: what an NPC tells you is only as credible
as the NPC, so a shifty informant produces a rumour, not a fact.

---

## Windows

A layout is a **tree of splits with a window at each leaf**. Positions are
fixed; sizes are the player's, dragged on the dividers. Define it in
`games/<id>/layout.json` (see `games/zork/layout.json`):

```json
{"id": "mygame", "variants": [
  {"id": "wide", "min_aspect": 1.4, "root": {
    "orientation": "horizontal", "ratio": 0.7, "children": [
      {"role": "dialogue", "type": "text", "min_size": [320, 200]},
      {"role": "status", "type": "icon_text"}
    ]}}]}
```

Variants are chosen at startup from the real viewport: the best match is the
highest `min_aspect` the viewport still satisfies. Types: `text`, `graphics`,
`map`, `units`, `icon_text`.

```gdscript
var builder := CoreLayoutBuilder.new(
        CoreLayoutDefinition.load_file("res://games/mygame/layout.json"))
builder.build(self, get_viewport_rect().size)
builder.load_ratios()      # restore the player's dividers
# ... on exit:
builder.save_ratios()
```

Split ratios live in **user preferences** (`user://ui_layout.cfg`), keyed by
layout, variant and resolution — not in the save file, because they describe
the player's screen, not the game world.

Look windows up by role; never hold a reference:

```gdscript
CoreWindowRegistry.append_line("dialogue", "The door creaks.")
var status := CoreWindowRegistry.get_icon_text_window("status")
if status: status.set_entry("coin", "$", "Coins: 12")
```

Lookups of a role a layout does not include return `null` — that is the
contract, so shared systems work on any screen. Pushing content down is a
direct registry call; player actions come back as registry **signals**
(`choice_selected`, `marker_activated`, `entry_activated`).

> The lookup is `window_for(role)`, not `get_window()` — the latter is a Godot
> built-in on `Node`.

### A new window type

Subclass `CoreWindow`, build contents in `_build()`, override `clear()`, add
your specialised methods, then register the type in
`CoreLayoutDefinition.WINDOW_TYPES`.

---

## Validating a package from the command line

Before the in-engine validators, there is a cheap Python pass that needs no
Godot and works on **any** game package:

```powershell
python core/tools/validate_narrative.py games/<id>
python core/tools/validate_narrative.py games/<id> --quiet
```

It catches the bugs that valid JSON and a *successfully compiling* `.ink`
cannot:

| Finding | Severity | Why it matters |
|---|---|---|
| dialogue choice routes to a knot nobody wrote | ERROR | guaranteed dead end at runtime |
| `check`/`requires` names a token that does not exist | ERROR | a gate no player can ever satisfy |
| actor placed in a location that is not a place | ERROR | the NPC is unreachable |
| place links to a place that is not there | ERROR | broken navigation |
| `.ink` calls an EXTERNAL `CoreInkBindings` never binds | ERROR | **compiles clean, crashes on that line** |
| knot nothing ever routes to | warning | may be staged content |

The last one is worth dwelling on: `inklecate` rejects an *undeclared*
EXTERNAL, but a **declared-but-unbound** one compiles with exit 0 and fails
only when a player reaches that line. This pass is what catches it.

The logic lives in `core/tools/narrative/` — `dialogue_graph.py` for authored
dialogue trees, `ink_inspect.py` for compiled stories — and neither module
knows anything about a particular game. File layout is discovered, not
configured: places may be `places.json`, `maps.json` or `sites.json`, and
actors may be `actors.json` or `units.json`. A package with no narrative
content reports zero and passes.

`tools/run_tests.ps1` runs this over **every** directory under `games/`.

### One query grammar, checked against core

`core/tools/narrative/intel_query.py` holds the **only** offline copy of the
`CoreIntelQuery` grammar. Both engines' `tools/validate_data.py` import it
rather than declaring their own, and `check_keys_match_core()` reads
`CoreIntelQuery.KEYS` straight from the GDScript and fails the build if the
two have drifted.

This guard exists because they *had* drifted. The isometric copy accepted
`era`, `turn` and `faction_flag` — none of which core evaluates, so such a
query silently returns false — while the FPS copy knew only 8 of core's 19
keys and wrongly rejected valid data. A package accepted by one engine could
be rejected by the other.

`faction_flag` is still used by 19 authored queries (aevum, paragon,
example_realm_iso) and still works, because the isometric engine has a
*second* live evaluator at `framework/intel/intel_query.gd`. That is reported
as a **warning** pointing at `docs/CORE_REQUESTS.md` CR-001, not an error:
the data is not broken today, but it will stop working the moment those call
sites move to core.

A game needing extra rules imports the shared pieces rather than
reimplementing them:

```python
from narrative.dialogue_graph import Findings, check_package, load_json

f = Findings()
check_package(actors, known_ids, place_ids, f)
if my_game_specific_problem:
    f.err("...")
raise SystemExit(f.report())
```

---

## Running the validators

Dialogue gates on world state, so a static graph walk is not enough: a knot can
be reachable on paper and still be dead content because no achievable context
satisfies its condition. There are two passes.

```powershell
godot --headless --path game_api/fps -s tools/validate_ink.gd -- `
    --package=res://games/zork `
    --story=res://games/zork/ink/round_room_fence.ink.json `
    --source=res://games/zork/ink/round_room_fence.ink `
    --source=res://ink/patterns/patterns.ink `
    --axes=res://games/zork/ink/round_room_fence.axes.json
```

Exits non-zero on any ERROR-severity finding, so it can gate CI.

- **Static** — unbound `EXTERNAL`s (a guaranteed runtime failure), diverts to
  knots that do not exist, and orphaned knots.
- **Context simulation** — plays the story across the cross-product of the axes
  and reports what was reachable, and under what conditions.

The axes file names the dimensions worth varying. Keep the values few and
meaningful — the boundaries, not exhaustive search:

```json
{ "npc": "fence",
  "assets":    { "zorkmid": [0, 5] },
  "knowledge": { "know_trapdoor": [false, true] },
  "standing":  { "fence": [0, 40] } }
```

Sample output:

```
REACHABLE CONTENT
  Ask about the house on the hill.               always
  Ask what he has for sale.                      4/8 contexts
  Mention what is under the rug.                 4/8 contexts
```

Both passes also run inside the GUT suite
(`core/tests/unit/test_core_ink_validator.gd`).

---

## Saving

Core state travels as one nested dictionary, so an engine `SaveManager` never
needs editing when a core system is added:

```gdscript
save["core"] = CoreSaveBundle.collect()
CoreSaveBundle.apply(save.get("core", {}))
```

This includes the Ink runtime's own JSON state, so a save taken
mid-conversation restores mid-conversation.

---

## The worked example

`games/zork/ink/round_room_fence.ink` — a fence in the Round Room, built
entirely from the pattern library. Its central choice is gated on **three**
systems at once (currency AND knowledge AND standing) and grants **both** a
physical asset and a new piece of knowledge.

Proven end to end in `core/tests/unit/test_core_ink_integration.gd`, where the
conversation renders into the registered dialogue window and the status window
updates — purely through registry look-ups, no direct references.

---

## Remember

After editing `core/addons/**` or `core/ink/**`, run `./tools/sync_core.ps1`.
After editing `games/<id>/**`, run `./tools/sync_game.ps1 -Game <id>`.
Before calling anything done, run `./tools/run_tests.ps1`.
