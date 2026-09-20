# SLACK TIDE — Presentation Layer Decision

Companion to `SLACK_TIDE_DESIGN.md` and `slack_tide_spec.json`. Where this document conflicts with the design doc on presentation (engine, 3D maps, greybox), **this document wins**, and the design doc and JSON have been patched to match (Section 9).

---

## 1. Decision

Build **2D with a UI, text-led**, in layers that are each playable on their own:

- **Layer 0: text core.** Headless plus a plain text renderer. This is the seed harness and a permanent fallback and testing mode.
- **Layer 1: UI shell.** Fixed window layout: scene, text, journal, map, status. Placeholder rectangles are fine.
- **Layer 2: illustrated scenes.** Backdrops, portraits, monster cards, item icons; four small tile maps for the danger zones.

**Not 3D.** **Not text-only as the shipped form.** Text-only stays as Layer 0, but the game's own information (journal reliability, conflicts, tide, values, a map) is easier to read and easier to show off on a store page as a UI.

3D is not ruled out forever; it is ruled out for this game.

---

## 2. Options compared

| | Text only | **2D with a UI (recommended)** | 3D first-person |
|---|---|---|---|
| Fit with the core mechanic (journal `check`, reliability, conflicts) | Good | **Best.** Journal and reliability are shown, not remembered | Weak. Walking adds time, not decisions |
| Fit with the design (knowledge-route encounters, not twitch combat) | Good | **Good.** Encounter panel, no real-time combat needed | Poor. First-person invites action combat the design does not want |
| Asset load | Near zero | About 100 pieces (Section 7) | Roughly ten times more, with rigging and animation as the hidden cost |
| Risk for a vibe-coded solo project | Lowest | Low to moderate (UI layout work) | Highest (camera, collision, animation, performance, art consistency) |
| Testable by the seed harness | Yes | Yes (UI sits on the same core) | Harder; the game logic gets entangled with movement |
| Store page and screenshot appeal | Weak | **Good** | Good, but expensive to make good |
| Reuse across your framework | Little | **Yes: first consumer of the shared GUI layout API** | The fps engine is already covered by `zork` |
| Where it fails | Small audience; the journal is a wall of text | The UI can become cluttered | Scope; a mediocre 3D game loses to a strong 2D one |

---

## 3. Why not 3D

1. **The game is conversation- and graph-shaped.** The fun is deciding what you believe, what you can prove, and what to sell. That happens in a journal and a dialogue, not in space.
2. **Zork was 3D because Zork was a room-and-object puzzle.** Slack Tide's spaces are mostly a dock, a tavern, a counting-house. They matter for who is in them, not for how you move through them.
3. **The design is built on non-combat resolution.** Every creature has a knowledge route and a purchasable counter. Turn-based encounters express that directly. First-person real-time combat would either ignore it or fight against it.
4. **Cost.** Fifteen 3D maps, 18 rigged NPCs and 7 animated creatures is an order of magnitude more than the same content in 2D, and art consistency in 3D is much harder to hold.
5. **Market.** A solo 3D first-person game competes on production values you cannot match. A distinctive text-led 2D game competes on ideas, which you have.

Keep the existing `zork` 3D build as a private reference and testbed. If you later want a 3D game, *Wardens of the Verdant Hush* is the natural candidate.

## 4. Why not text-only as the shipped form

Text-only is the right **Layer 0**, and it is how the harness plays the game. As a product it has two problems: the journal (75 tokens with reliabilities and conflict groups) is hard to use as scrolling text, and the tide, Slack Index, values and map are stateful things a player wants to glance at. A UI turns those from memory tasks into visible state.

---

## 5. The recommended design

### 5.1 Screen layout

Window positions are fixed slots. Sizes are player-adjustable at runtime via dividers, per your corrected layout decision. Each window is registered by role in the global window registry.

```
+-----------------------------------------------------------+
| STATUS  Day 6  Midday crossing | Tide: SLACK  ▓▓▓▓▓▓░░ | 42t |
+-------------------------+---------------------------------+
| SCENE                   | TEXT (narration + dialogue)     |
| illustrated backdrop    |                                 |
| + portraits, hotspots   | Corvin: "The sluice closes      |
|                         |   itself."                      |
|                         |                                 |
|                         |  [Call it     c1b 78/75  ✔]     |
|                         |  [Bluff       c1b 78/40  ✔]     |
|                         |  [Let it go]                    |
+-------------------------+----------------+----------------+
| JOURNAL                 | MAP            | VALUES / PACK  |
| tokens, reliability     | Reach node map | 8 value bars   |
| bars, conflict flags    | current place  | items, parcels |
+-------------------------+----------------+----------------+
```

Registry roles: `status`, `scene`, `text`, `journal`, `map`, `values_pack`. Different resolutions can ship different default sizes, and dragging dividers works in-game.

### 5.2 Design rules for the UI

- **Show the check.** Every dialogue option that is a `check` displays required versus held reliability (`c1b 78/75`), so the mechanic reads at a glance and the player understands why they can or cannot bluff.
- **Journal is the hero window.** Tokens grouped by category; reliability bars; conflict groups drawn as linked entries; hearsay that is fading is visibly dimmed; forged tokens are not marked, but a Truthglass or Vosk hint can mark them.
- **Tide and Slack are always visible.** A tide clock and a Slack meter in the status strip. The player should never wonder whether the Steps are open.
- **One-click sell.** From the journal you can offer a token to a buyer and see the price before you commit, including the spread effect.
- **Skim mode.** Recap button that summarises the last conversation into journal changes, so text volume never blocks play.
- **Text scaling and high-contrast** options from the start.

### 5.3 How each location is presented

Fifteen locations, three presentation types.

| Type | Locations | Notes |
|---|---|---|
| **Scene card with hotspots** (11) | ferry_deck, sorrel_landing, low_lantern, marl_landing, tally_house, customs_house, far_wend_landing, croy_lighthouse, reedwick_marsh, cormorant_rocks, weir_gatehouse | One backdrop each; NPCs appear as portraits; clickable hotspots (shop counter, drawer, door). Dawn, dusk and slack are palette shifts, not new art |
| **Small tile map** (4) | salt_steps, drowned_arcade, bellmakers_cistern, weir_underworks | The four danger zones. Small grids with light and sound visibility, so the lullhound's hunt-by-sound and the lantern requirement have somewhere to live |
| **Node travel map** (1) | The Reach | A single illustrated map with the 15 locations as nodes. Travel is choosing a node (and paying fare in Act II) |

The ferry deck is one reused scene; each crossing swaps in that leg's passenger portraits.

### 5.4 Encounters

A turn-based encounter panel, no real-time combat.

1. **Notice.** Creature card appears with the tokens that matter highlighted if you hold them (for example `b_gulcher_iron`).
2. **Approach.** Buttons are the routes the design already defines: knowledge (lead the wight up, decoy the lullhound), item (salt, iron, felt overshoes), gift (Wick, Bell, Cutter), fight, or flee. Unavailable routes are greyed with the reason.
3. **Resolve.** Outcome uses your kit and knowledge; value events fire (mercy, nerve, restraint).

The Kelpmother and Pale Collector have no fight option at all.

---

## 6. Layers, build order and acceptance

| Layer | Contents | Done when |
|---|---|---|
| **L0 Text core** | Token graph, seed truth, reliability and decay, economy, values, finale checker, text renderer | Harness invariants 1, 2, 3, 5 pass on 1,000 seeds; a scripted bot finishes a run in text |
| **L1 UI shell** | The five windows with placeholder rectangles; check display; journal; status strip; node map | Days 1 to 3 playable with no art, entirely by mouse |
| **L2 Art pass** | Backdrops, portraits, monsters, icons, tile maps, palette shifts | Act I looks finished; Act II and III follow |

Ship the L1 Days 1 to 3 slice before commissioning or generating any art. If the slice is not fun with rectangles, art will not fix it.

---

## 7. Asset budget (rough, from the spec)

| Asset | Count | Source in spec |
|---|---|---|
| Scene backdrops | 11, plus 1 Reach map, plus title | `locations` (scene type) |
| Tile maps and one shared tileset | 4 maps | `locations` (tile type) |
| Portraits | about 25 (18 NPCs, 7 passenger archetypes) | `npcs`, manifest table |
| Monster and creature cards | 7 | `monsters` |
| Icons | about 35 (gear, gifts, parcel, satchel, coin, 8 values) | `items`, `gifts`, `values` |
| UI kit | 1 frame and control set | |

Roughly **90 to 100 pieces**. For scale, the Aevum sprite plan is 12 unit types × 10 units × 5 animations × 6 directions, about 3,600 renders. The same content in 3D would need 15 modelled maps, 18 rigged characters, 7 animated creatures and first-person weapon animation.

A constrained palette and one consistent illustrated style (a vintage-print look would be consistent with Aevum) makes mixed art sources far less obvious.

---

## 8. Risks and mitigations

- **The shared GUI layout API is not built yet.** Build only the five windows above first, no more. If that proves harder than expected, fall back to a fixed layout and add resizing later.
- **Engine fit is unverified.** I have not seen the isometric engine's window registry or the fps engine's internals. Cline should confirm the isometric engine (or a scene renderer on the same core) can host a scene window with hotspots, and report if not.
- **Clutter.** Five windows plus dividers can crowd small screens. Provide a compact layout that swaps the map and values panels to tabs.
- **Text volume.** Skim mode and journal-driven play mitigate this; keep every conversation short (under about 10 exchanges).
- **Art consistency.** Fix the style guide and palette before generating anything, and keep the first art pass to Act I.

---

## 9. What changed in the other files

*Corrected 2026-09-19. An earlier version of this section claimed edits that had not actually been made to `slack_tide_spec.json`; they have now been made for real, and verified.*

- `SLACK_TIDE_DESIGN.md`: engine and presentation line at the top; "any 3D work" in Section 0 is now "any presentation work"; pillar 5 and Section 6 speak of locations, scene cards and tile maps; the Section 12 ferry-deck question now concerns a reused scene with swapped portraits.
- `slack_tide_spec.json`: `engine` is now `isometric`, a `presentation` field reads `2d_ui_text_led`, and all 15 locations carry `presentation: scene` (11) or `tile` (4: Salt Steps, Arcade, Cistern, Underworks).
- Unchanged: tokens, economy, values, gifts, roads, seeds, harness invariants. None depended on the presentation.
- The `zork` package has been **renamed to `slack_tide`**, not kept alongside it. Its 15 rooms, props and 3D scenes are deleted; its dialogue structure survives as the pattern this package is built on. The fps copies, playtest and unit tests were removed with it.

---

## 10. Open questions

1. ~~**Which engine hosts it?**~~ **ANSWERED (Cline, 2026-09-19): the isometric layer, and no new core work is required.** The "shared GUI layout API" this document assumed must still be built **already exists** in `core/addons/game_core/ui/`, engine-agnostic, and is documented in `docs/NARRATIVE.md`:
   - `CoreLayoutDefinition` — a layout is a tree of splits with a window at each leaf, chosen at startup from the real viewport aspect (`min_aspect` variants). Positions are fixed by the game; sizes belong to the player and persist in `user://ui_layout.cfg`.
   - `CoreLayoutBuilder` + `CoreWindowRegistry` — an autoload mapping role -> live window. Look windows up **by role**, never hold a reference; a role the layout omits returns `null`, which is the contract that lets shared systems work on any screen.
   - Five window types are already registered in `CoreLayoutDefinition.WINDOW_TYPES`: `text`, `graphics`, `map`, `units`, `icon_text`.

   The five windows map on with **zero core changes**: scene=`graphics` (`set_image`/`set_caption`), narration=`text`, journal=`icon_text`, map=`map`, status=`icon_text`. `games/slack_tide/layout.json` implements exactly this, with `wide` and `tall` variants.

   **Hotspots already exist too.** `CoreMapWindow` carries a marker model — `set_marker(id, normalised_pos, icon)`, `remove_marker`, and a `marker_clicked` signal — which is precisely the clickable-hotspot mechanism the scene cards need. The only possible future core addition is a hotspot overlay on the *graphics* window specifically; until then hotspots ride on the map window. Note that per `CLAUDE.md` a game package must **never** edit `core/` or `game_api/*/framework/` — core needs are filed as requests and applied once on `main`.

   The intel core is likewise already sufficient: `CoreIntelToken` has `base_reliability`, `conflicts`, `decay_turns`, corroboration and `debunk`; `CoreIntel` owns journals, provenance, spread and trade. The spec's 0–100 reliability is scaled to core's 0.0–1.0 in `tools/convert_slack_tide.py`, which is the only place that mapping lives.
2. **Resolution targets** (for the default window layouts).
3. **Art source and policy:** self-made, commissioned, or generated? Decide before the art pass; if any generated art ships, check the storefront's current disclosure rules.
4. **Portrait style:** full-body, bust or vignette? This changes the budget noticeably.
5. **Controller support:** do you want it, given the UI is mouse-first?
6. **Do you want a 3D moment later** (for example the Underworks finale as a short 3D sequence)? I would not plan for it, but it is the only place it would earn its cost.
