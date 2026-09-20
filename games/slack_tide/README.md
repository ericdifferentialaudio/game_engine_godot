# SLACK TIDE

A deckhand on a river ferry where the tide has stopped turning. What your
passengers say, carry and owe is worth money and clues — until the day the
ferry stops running and you take what you have learned down into the drowned
city beneath the river.

Successor to the `zork` package: the same proven intel-journal mechanic, an
entirely original world, and a great deal more depth. Built as a **data
package** on the shared core, presented **2D, text-led, with a UI**.

```
games/slack_tide/            <- authoritative source (edit here)
  game.json                  package config: clock, economy, intel rules
  layout.json                the five windows: scene, narration, journal, map, status
  maps.json                  15 locations: 11 scene cards, 4 tile maps
  intel.json                 75 tokens  *** GENERATED - do not hand-edit ***
  actors.json                NPCs with knowledge-gated dialogue
  items.json                 gear, gifts, evidence
  factions.json              6 standings
  slack_tide_boot.gd         tide clock, wages, Slack inflation, hearsay decay
  docs/
    SLACK_TIDE_DESIGN.md         the design document
    SLACK_TIDE_PRESENTATION.md   why 2D-with-UI and not 3D or text-only
    slack_tide_spec.json         *** source of truth for tokens/economy ***
    slack_tide_tokens.md         generated token list
  ink/
    corvin.ink / .ink.json       dialogue (the Ink port; see docs/)
    corvin.axes.json             axes for CoreInkValidator's simulation
    patterns.ink                 shared library, synced from core/ink/patterns
  tools/
    convert_slack_tide.py        spec -> intel.json (+ --check)
```

Validation is **not** here — it is shared, in `core/tools/`, because every
game has the same bugs. See `docs/NARRATIVE.md`.

## The pipeline

`docs/slack_tide_spec.json` is the source of truth for the information system.
Never hand-edit `intel.json` — edit the spec and regenerate. `run.ps1` does the
whole chain (regenerate → recompile stale `.ink` → validate → sync → launch):

```powershell
./games/slack_tide/run.ps1            # full pipeline, then play
./games/slack_tide/run.ps1 -Check     # regenerate + validate, change nothing

# or the individual steps:
python games/slack_tide/tools/convert_slack_tide.py --check   # spec -> intel
python core/tools/validate_narrative.py games/slack_tide      # SHARED validator
./tools/sync_game.ps1 -Game slack_tide -Engine isometric
```

The shared validator catches what valid JSON and a compiling `.ink` cannot: a
choice routing to a knot nobody wrote, a `check` against a token that does not
exist, an actor in a place that isn't there, and — the one Ink itself misses —
a story calling an EXTERNAL that `CoreInkBindings` will never bind, which
compiles with exit 0 and crashes only when a player reaches that line.

## The core mechanic

Every answer that matters is a **check against the intel journal**, never a
menu pick:

```json
{ "text": "'Men paid in Tally coin close it at the third bell.'",
  "check": { "has": "c1b", "min_reliability": 0.75 },
  "next_pass": "called_it", "next_fail": "bluffed" }
```

* The answer is **always offered as text** — you can always bluff.
* It only **works** if the journal holds the token at enough reliability. The
  UI shows required against held (`c1b 78/75`).
* Reliability comes from *how you learned it*: overheard 30, told 55, slip 55,
  sold 60, document 70, found 70, witnessed 90. A second independent source
  adds +20 (cap 95).
* **Hearsay fades.** Anything under 50 loses 5 a day to a floor of 10 unless
  corroborated. Information is perishable, so selling early is tempting.
* Rumour mills (Doss, Ma Cobb, passenger gossip) carry **every** version of
  every answer at 25 max. That is where false rumours come from, and nobody is
  lying on purpose.

## Every seed hides a different truth

Three possible culprits; exactly **one is real per run**. Triad answers are
mutually exclusive by `conflicts` group, so **exposing a lie corroborates the
truth** — and the same rumour is worth believing on one run and debunking on
the next. `slack_tide_boot.gd` rolls the culprit from the shared
`CoreContext.rng()`, so a seed always replays identically.

## The shape of a run

| Act | What you do |
|---|---|
| **I** (days 1–~13) | The job. Three crossings a day, six tallies, two back for board. Listen, take fares, run parcels, drink at the Low Lantern after the shift. Learn who is worth believing. |
| **II** | Quit, or get sacked, or keep working and spend. Turn money and knowledge into a kit and a plan. Prices rise 4%/day from day 6 (cap +60%), so buying early matters. |
| **III** | Full Slack. The ferry stops. You go down the Salt Steps with whatever you managed to prove. |

Three roads to the ending — **word** (convene the Assize), **bargain** (deal
directly), **hand** (go down armed) — and all three end by speaking the three
Turning Words at the third bell.

## Conduct is character

Eight values, 0–10, starting at 3: candor, mercy, fairness, nerve, patience,
fidelity, curiosity, restraint. They move with what you actually do. Old
people on the Reach give their one irreplaceable item only to someone whose
conduct already matches theirs — so the gifts cannot be farmed. By the time
you learn a gift exists, the conduct that earns it is mostly behind you.

## Every creature has a knowledge route

No enemy is a damage check. Each one has something you can *know* and
something you can *buy*:

| Creature | Know | Buy |
|---|---|---|
| Silt-wight | They rise only at slack; they plead in a voice you'll follow | salt pouch, Warding Wick |
| Gulcher | Will not cross iron | iron nails |
| Lullhound | Hunts on sound alone | felt overshoes, iron pot |
| Kelpmother | Takes tribute, and takes nothing else | fresh eels |
| Pale Collector | Wants three drowned marks | — |
| Sunken Choir | Sleeps at the Bell, rung at the third bell | Bell of Turning |

The boarding pike kills most of them. It costs 60 tallies — ten days' clear
wages — and it is never the best answer.

## Status

Foundation complete and validated: 75 tokens, 15 locations, 25 items,
6 factions, 5 NPCs written in full (Hesper, Corvin, Doss, Fen, Ottoline).
13 NPCs remain; see the warnings from `validate_slack_tide.py`.
