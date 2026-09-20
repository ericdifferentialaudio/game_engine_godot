# SLACK TIDE — Phase Gates

The checklist each phase must pass. A gate is only trusted once it has been
**deliberately broken** at least once — a gate nobody has tried to break is a
gate nobody should trust.

Status: `[ ]` not started · `[~]` in progress · `[x]` green and fault-injected

---

## Always-on (run after every phase)

```powershell
./tools/run_tests.ps1                    # core + iso + fps + validators + sync
cd games/slack_tide/tools
python check_solvable.py                 # every seed winnable
python regress.py --seeds 2000           # balance inside the band
```

---

## Phase A — actor gap
- [ ] All 26 `topics.json` stance sources resolve to an actor or a declared
      `other_source` (satchel, tide_almanac, pax_gossip, pax_smuggler) or a
      location-as-source (salt_steps, weir_gatehouse, ferry_deck...).
- [ ] `actors.json` is **generated**, with a do-not-edit header.
- [ ] `validate_narrative.py` 0 errors.
- [ ] **Fault injection:** delete an actor from the spec -> converter `--check`
      fails; a topic naming an unknown source is reported.

## Phase B — session driver
- [ ] A headless playthrough moves between locations via `maps.json` links,
      respects `requires_slot`, learns tokens, and reaches an ending.
- [ ] Slot/day advance matches `slack_tide_boot.gd` (6 slots = 1 day).
- [ ] Deterministic: same seed, same transcript.
- [ ] **Fault injection:** break a link target -> caught, not silently stuck.

## Phase C — engine cross-check  (the important one)
- [ ] `--sim --seed=N --policy=<p>` emits `ST_EVENT` JSONL + one `ST_RUN`.
- [ ] Four policies: competent, naive, greedy, honest.
- [ ] **Engine competent win rate within 0.08 of the model's 0.804.**
- [ ] Same seed replays identically (determinism gate).
- [ ] **Fault injection:** perturb a road requirement -> engine and model
      disagree -> the cross-check reports it.

If engine and model disagree, **the model is wrong.** The engine is the truth;
`model.py` gets corrected to match, and `BALANCE.json` is re-derived.

## Phase D — conversations
- [ ] All 14 topics reachable and playable.
- [ ] Every generated `.ink` compiles; **every EXTERNAL is bound**.
- [ ] Hand-written files untouched by the generator.
- [ ] `--check` mode fails when a story is stale against the matrix.
- [ ] **Fault injection:** call an unbound EXTERNAL -> validator exits 1.

## Phase E — consequence and ending
- [ ] >= 7 distinct endings reachable **in engine**.
- [ ] A token sold on day N is quoted back by an NPC around day N+3,
      **including false ones**.
- [ ] Reckoning scorecard renders (Truth / Conduct / Purse / Mercy + total).
- [ ] Endings split correctly on *turned the tide* x *understood why*;
      winning while wrong reads as an indictment, not a victory lap.

## Phase F — re-tune on engine numbers
- [ ] `BALANCE.json` baseline re-derived from **engine** runs.
- [ ] Competent 0.75-0.88 · naive <= 0.35 · 60-90 min · >= 6 endings, top <= 40%.
- [ ] `regress.py` green on held-out seeds.
- [ ] **Fault injection:** make the game easier -> reported as a regression
      ("the player can no longer lose"). *Already verified once at 0.882.*

---

## Definition of done

1. A full headless playthrough reaches a real ending.
2. Engine and model agree within 0.08.
3. Every gate above green **and** fault-injected.
4. Reckoning score plateaus: under +0.01 for three iterations.

Then stop. A tight 74-minute game beats a polished number nobody can feel.
