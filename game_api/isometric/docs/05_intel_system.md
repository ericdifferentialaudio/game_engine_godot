# 05 · The Intel System (deep dive)

Intel is the engine's signature resource. It is **per faction**, **uncertain**,
**sourced**, **perishable**, **contagious**, **derivable**, **tradeable** and it **gates**
content everywhere.

## 1. Tokens (`intel.json`) — what *could* be known
```
id, title, summary
subject      what it is about (unit/site/faction/tile "q,r"/item/"world")
scope        global | region | tile | site | unit | faction | item
category     rumor | fact | secret | location | password | schedule | military | economic |
             diplomatic | geographic | lore | map | tech
tags[]       free filters
facts{}      machine-readable payload  ({"safe_window": "third_bell"})
reliability  0..1 starting belief         corroboration_step  gain per new independent source
decay_turns  turns until stale (0 never)  conflicts[]        contradicting token ids
secrecy      0..1 resistance to spread/theft/trade
spreadable / tradeable / value
reveals{}    map knowledge granted on acquisition: tiles[], around+radius, sites[], units[]
effects[]    Interaction specs run on acquisition (rewards, flags, debunks…)
```

## 2. Journals — what a faction *does* know
`IntelRegistry.journal_for(faction)` → `IntelJournal{tokens, source_trust, unlock_watchers}`.
A journal token instance carries runtime state:
* `reliability` — starts at `base × lerp(0.5, 1, trust(source))`, or an explicit override.
* `provenance[]` — chain of `Provenance{source_id, channel, turn, trust, via_holder}`.
  Channels: `observed, told, read, traded, stolen, spread, derived, scripted`.
* `acquired_turn / confirmed_turn` → `is_stale(now)` and `age(now)` in turns.
* `known_false` — proven a lie (`IntelRegistry.debunk`); every source that supplied it
  loses `source_trust`, which lowers the starting reliability of *everything else* they say.

### Acquisition flow (`IntelRegistry.acquire(holder, token, source, channel, reliability?, via?)`)
1. New → instance, provenance, `intel_acquired`, apply **reveals** (fog EXPLORED), run
   **effects**, check **contradictions** (weaker of the pair loses `dispute_amount`).
2. Existing → `corroborate()` if the source is new (reliability += step × trust),
   `intel_updated`.
3. Then **derivations** run for the holder and **unlock watchers** are evaluated.

Sources of acquisition already wired: site `intel` interactions, dialogue nodes, items
(`grants_intel` on use), unit sight/defeat/combat (`intel_profile`), abilities, faction
`starting_intel`, rules (derive/spread), trades, scripted `transfer`.

## 3. Rules (`intel_rules.json`) — how knowledge moves
* **derivations** — `{"when": <query>, "grant": token, "reliability", "once"}`: infer C
  from A∧B. Runs after every acquisition and at RESOLVE.
* **spread** — `{"between": all|allies|friendly|peaceful|enemies|trade_partners|neighbors,
  "chance", "max_secrecy", "reliability_loss", "categories"}`: at RESOLVE, for each
  ordered faction pair matching the filter, each eligible token rolls
  `chance × (1 − secrecy)`; the receiver gets it via channel `spread` with reduced
  reliability and `via_holder` set. Seeded RNG.
* **contradiction** — `dispute_amount`, `flag_source_trust_loss`.

## 4. Queries (`IntelQuery`) — gating everything
Evaluated for a **holder** faction; used by sites (`hidden_until`, `enter_requires`),
interactions (`requires`), shop stock, dialogue choices, abilities, items, rules.
```
{"has": id, "min_reliability", "allow_stale", "max_age"}
{"subject"|"tag"|"scope"|"category": x, "count", "min_reliability"}
{"fact": [id, key, value]}   {"provenance": [id, channel]}   {"source": [id, source_id]}
{"contradicted": id}         {"flag": f}   {"faction_flag": f}
{"resource": [res, op, n]}   {"turn": [op, n]}   {"era": id}
{"owns_site": id}            {"unit_count": [def, op, n]}   {"stance": [faction, stance]}
{"all": [...]}  {"any": [...]}  {"not": q}
```
`tools/validate_data.py` validates the identical grammar offline.

## 5. Trading, stealing, sharing
* `IntelRegistry.transfer(from, to, token, channel="traded"|"stolen", price)` copies with
  provenance `via_holder`. `tradeable: false` blocks trades but not theft.
* `Shop.sell_intel(token, faction, exclusive)` — brokers buy at `value × reliability`;
  `exclusive` forgets it from the seller.
* `flag` interaction `share_intel` — scripted leaks between factions.
* `trade_value()` — always scaled by the holder's own belief.

## 6. Reliability & perception
Heroes with a `perception` stat get `rules.intel.perception_reliability_per_point` per
point when receiving told/read intel (`IntelInteraction`). Equipment (`spyglass`) and
artifacts can raise perception.

## 7. UI surface
`intel_journal_panel.gd` (J): grouped by subject, shows reliability %, stale/FALSE flags,
conflicts, provenance chain (`source via channel @Tn → …`) and facts. `EventBus`
notifications announce acquisitions with their reliability.

## 8. Design recipes
* **Triangulation** (reference game): two rumours + an inscription derive `crypt_location`
  at 0.65; or buy the tide chart (needs a password token) and *read* it for 0.8;
  either way the hidden dungeon site appears (`hidden_until` ≥ 0.6) and reveals tiles.
* **Disinformation**: give a token `conflicts` with a truth; whoever the player trusts
  wins ground; the truth's `effects` can `debunk` the lie and punish the liar's trust.
* **Perishable military intel**: `decay_turns: 5` + `category: military` + spread rule
  `between: neighbors` = border chatter that fades.
* **Espionage**: a `stolen` channel transfer from an enemy journal with `secrecy` as the
  difficulty; `provenance` queries let content react to *how* you learned something.
