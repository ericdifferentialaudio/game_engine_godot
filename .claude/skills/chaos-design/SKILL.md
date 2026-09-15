---
name: chaos-design
description: Designing or tuning a game for maximum interesting unpredictability — the four tiers of chaos, the fairness constraints that keep chaos from becoming noise, the per-engine knob catalogue, and how the chaos score is measured and gated. Use when the task mentions chaos, replayability, unpredictability, emergent behaviour, difficulty tuning, false intel, or making a game more interesting across sessions.
---

# Chaos design

How this repo makes games unpredictable **on purpose**, in a way that stays
fair, measurable, and reproducible.

## The four tiers

Ranked by interest-per-unit-of-unfairness. Spend your budget top-down.

### 1. Epistemic — the player's model is wrong (weight 0.40)
The richest and least-used vein here. `CoreIntel` already implements
reliability, corroboration, provenance, decay, contradiction, debunk, spread
and trade. Chaos is a player confidently acting on a belief that turns out to
be false — **and being able to find that out.**

Levers: token `reliability`; `conflicts` links between true tokens and false
twins; `intel_rules.json` derivation and spread rules; source trust; secrecy;
decay; deliberately contradictory NPC testimony.

Aevum's 30% double-agent roll (a shady informant gives false intel) is the
existing model to copy.

### 2. Combinatorial — the structural draw (weight 0.25)
One draw at world-gen that cascades into everything downstream. Nearly free,
and the strongest replay engine there is. Paragon draws 8 of 15 virtues —
C(12,6)=924 sets at launch — and that single draw determines companions,
dungeons, dilemmas, quiz questions *and* which of 12 principles binds the seed.

Levers: which subset is drawn; constraint rules on the draw; what the draw
selects downstream; procedural placement of *fixed* content.

**Randomise arrangement, not rules.** Players should re-learn *where* things
are and *what they are called*, never *how the world works*.

### 3. Social — conduct has visible consequences (weight 0.25)
The world remembers and reacts. Guards refuse a gate; a wronged party ambushes;
a merchant refuses to sell; a companion leaves. Must be **rumour-driven, never
counter-driven** — the player traces it to a specific act, not to a hidden
number crossing a threshold.

This is the usual fix for a sagging mid-game, where conduct quietly stops
mattering for hours at a time.

### 4. Mechanical — dice (weight 0.10)
Damage rolls, spawn tables, crit chance. **Cap this.** It is the cheapest form
of unpredictability and the least interesting: variance without meaning. A
combat that swings on a roll the player could not influence is not chaos, it is
noise. `combat.randomness: 0.2` is a reasonable ceiling.

## The fairness constraints

Chaos that breaks these is a bug, not a feature.

1. **Falsifiable, not arbitrary.** Every lie needs a discoverable refutation,
   reachable before the point of use. `CoreChaosMetrics.epistemic_score()`
   multiplies wrongness by the refutation rate, so unrefutable lies score
   **zero** — the metric refuses to reward them.
2. **No counter-gates.** Never gate progress on a hidden threshold. Gate on
   items and conduct, which are visible and reasonable-about.
3. **Deterministic under seed.** All randomness via `CoreContext.rng()`. Chaos
   is variance *across* seeds; a seed must always replay identically.
4. **Retro-explicable.** "I was wrong" is good. "I could not have been right"
   is a defect.

## Measuring it

`CoreChaosMetrics` (`core/addons/game_core/analysis/`) scores episode records
from the per-engine chaos harnesses:

| Metric | Question |
|---|---|
| `outcome_entropy` | do runs end differently? |
| `trajectory_divergence` | does one changed choice change the story? |
| `state_coverage` | is the whole world used, or one corridor? |
| `event_rarity_tail` | are there rare events, or the same three every run? |
| `epistemic_score` | were beliefs wrong *and* refutable? |

`scorecard()` returns the weighted score plus **gates**: `solvable`
(competent-policy win rate >= floor, default 0.55) and `deterministic`. A score
that rises while a gate fails is a **regression** — that gate is the only thing
standing between "maximise chaos" and "delete the win condition".

```powershell
./tools/chaos_run.ps1 -Game <id>        # -> games/<id>/chaos_report.json
```

## Knob catalogue

### Isometric (`aevum`, `paragon`, `hollow_ledger`, `chorus`)
| File | Key | Effect |
|---|---|---|
| `intel.json` | `reliability` | how trustworthy a token is |
| `intel.json` | `conflicts` | wires a false twin to its true source |
| `intel_rules.json` | `spread.chance`, `reliability_loss` | rumour drift |
| `intel_rules.json` | `contradiction.dispute_amount` | how hard beliefs collide |
| `ai_profiles.json` | goal weights, `flee_below_health` | AI unpredictability |
| `factions.json` | diplomacy, stance volatility | shifting alliances |
| `terrains.json` / `maps.json` | generator frequency, bands | world variance |
| `sites.json` | `spawns`, `respawn_turns` | encounter pressure |
| `game.json` | `rules.combat.randomness` | **cap this** |

### FPS (`zork`, `wardens`)
| File | Key | Effect |
|---|---|---|
| `actors.json` | aggression, wander, `flee_below_health` | NPC unpredictability |
| `actors.json` | dialogue branches, `check` conditions | knowledge-gated outcomes |
| `pois.json` | interaction branching, state flags | world reactivity |
| `intel.json` | `reliability`, `conflicts` | true tokens vs. false rumours |
| `effects.json` | status interactions, durations | compounding states |
| `game.json` | `combat.*`, `crit_chance` | **cap this** |

## Anti-patterns

- Raising `combat.randomness` and calling it chaos. It is noise.
- A lie with no refutation. Unfair, and scores zero anyway.
- Randomising proper nouns and nothing else — this *weakens* memorability and
  shareability while adding no real variance. Randomise placement instead.
- Hidden thresholds. If the player cannot reason about it, it is not chaos.
- Unseeded randomness. Breaks replay, the harness, and every regression test.
