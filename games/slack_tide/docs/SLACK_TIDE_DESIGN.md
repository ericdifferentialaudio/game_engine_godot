# SLACK TIDE — Design Document

Package id `slack_tide`. Presentation: **2D with a UI, text-led** (see `SLACK_TIDE_PRESENTATION.md`); the engine target is the isometric/2D side, not fps. Eleven locations are scene cards with clickable hotspots; four (Salt Steps, Arcade, Cistern, Underworks) are small tile maps. Successor to the `zork` package, which has been renamed and replaced by this one: same proven intel-journal mechanic, entirely original world, characters, economy and structure.

Companion files: `slack_tide_spec.json` (machine-readable source of truth, 75 tokens plus cast, gear, gifts, monsters, roads) and `slack_tide_tokens.md` (the deep token list, generated from the spec). If this document and the JSON disagree on an id, number or rule, **the JSON wins**.

---

## 0. Notes for Cline

- I have not seen the engine's `game.json` / intel schema. The JSON uses neutral field names and stable ids. Map them onto the real schema; wherever the schema lacks a field, leave a `TODO(engine)` and list it in `RULINGS.md`.
- Suggested pipeline, like `aevum`: keep the neutral spec as the source and generate the engine JSON with a `tools/convert_slack_tide.py` that supports `--check`.
- Per the scaffold workflow this needs an architecture pass (`CHAOS_SPEC.md`, `RULINGS.md`) before code. Section 9 below is a ready draft of the chaos surface, and Section 12 lists rulings I could not decide.
- Every player-visible string should be tagged `# NEEDS_HUMAN_WRITING` for a later human writing pass. Journal texts in the token list are functional drafts.
- Build order matters (Section 10). Get a headless token graph and the seed harness passing before any presentation work.

---

## 1. Pitch

You are a deckhand on a river ferry where the tide has stopped turning. What your passengers say, carry and owe is worth money and clues, until the day the ferry stops running and you take what you have learned down into the drowned city beneath the river.

Five pillars:

1. **Knowledge is the weapon, reliability is the ammunition.** Every dialogue answer is a `check` against the intel journal (unchanged from `zork`). You can always bluff; it only works if you hold the token at enough reliability.
2. **Work to learn, learn to leave.** Act I is a job that pays wages, tips and secrets. Act II turns that money and knowledge into a kit and a plan. Act III is the quest.
3. **Conduct is character.** Eight original values move with what you do. Old NPCs give magic items only to people whose values align with theirs.
4. **Every seed hides a different truth.** Three possible culprits; exactly one is real per run, so the same rumors are true one run and false the next.
5. **Small and finishable.** Fifteen maps, no open world, a run of roughly 60 to 90 minutes. Text-first: the game must be fully playable with placeholder art.

---

## 2. Setting

**The Sallow Reach** is a wide tidal estuary dividing two banks, west (Sorrel) and east (Far Wend), with an island town (Marl Cross) in the middle. Under the Reach lie the **Drowned Stairs**, the flooded arcades of an older city. The **Weir** at the seaward end is the great tide-gate that has kept the tides on schedule for centuries.

For a month the tide has been **lingering at slack**. The official story is natural drift. It isn't. At slack water the Stairs drain, silt-wights rise, and the ferry's run gets shorter. Once slack lasts a full day (**Full Slack**) the ferry stops, and a sleeping thing under the Weir wakes.

Tone: dry, salt-worn, quietly funny, never grim for long. Sample narration: *"The tide has been out for eleven hours. Hesper says this is a mood."*

The world is a tidal, working-class setting. It deliberately shares nothing with Zork's Great Underground Empire (see the banlist, Section 11).

---

## 3. Structure

### Time model
A day has six slots: **Dawn crossing, Morning, Midday crossing, Afternoon, Dusk crossing, Night.** Crossings are ferry scenes (three per day). The other slots are free time on land. Act I runs about 14 days.

### The Slack Index
A hidden 0 to 100 meter. It rises by +5 per day on days 1 to 5, +8 on days 6 to 10, and +12 from day 11, reaching 100 (Full Slack) on day 13. The seed may shift this by one day. As it rises: ebb windows for the Salt Steps shrink, wights appear more often, passenger counts fall, and shop prices inflate (Section 4.5).

### Act I: The Crossing (days 1 to about 14)
Work the ferry *Patience* for Hesper Quillon. Earn wages, tips and parcel fees, listen to passengers, trade secrets, and make short, risky runs onto the Salt Steps at low ebb. No combat in Act I; danger comes only from the Steps.

**Inciting incident, day 2:** Warden-Courier **Lisle Harrow** collapses aboard the ferry and dies, leaving a **sealed satchel** addressed to Captain Brack at Far Wend. Deliver it intact (fidelity) or open it (curiosity, but a broken seal). What it holds depends on the seed (tokens `c3a/b/c`).

### The Departure
Act I ends one of two ways:

- **Forced:** the Slack Index reaches 100 and the ferry stops.
- **Voluntary:** any time after day 5 you may give notice. Give a full day's notice and finish your parcels and you leave **honorably** (sets flag `left_honorably`, needed for Hesper's gift of the ferry).

### Act II: The Long Way
Ferry stopped. You travel by fare-boat (about 3 tallies a leg) and on foot; board costs 2 tallies a day. Visit the old NPCs (values permitting, they give gifts), convene the Assize, buy your kit, and scout the Steps. **Deadline:** the Choir fully wakes on Full Slack day 8; if the tide has not been turned by then the run ends in the failure ending.

### Act III: The Weir
Three stages: **reach** the Weir, **enter** it, then **settle the cause** by one of three roads and speak the Turning Words at the third bell (Section 4.8).

---

## 4. Mechanics

### 4.1 The intel journal and checks (kept from Zork)
Every dialogue option is a `check` against the journal, not a menu pick. Example (seed B; Corvin is lying, asserting the false triad answer `c1c`):

```
Corvin: "The sluice closes itself. Nobody's touched it."
  [Call it]     check c1b >= 75  -> pass: Corvin flusters and lets slip (c1b +10, candor +1)
  [Bluff]       check c1b >= 40  -> fail: candor -1, Corvin closes up
  [Let it go]   nothing gained or lost
```

Tokens carry a **reliability** (0 to 100). Tokens with a `conflicts` group are mutually exclusive by seed, so **exposing a lie corroborates the truth**.

### 4.2 Reliability, corroboration, decay
- Base reliability by how you learned it: overheard 30, told 55, slip 55, sold 60, document 70, found 70, witnessed 90.
- A second independent source adds +20 (cap 95).
- Rumor mills (Doss, Ma Cobb, passenger gossip) carry **every version** of each triad answer at reliability 25 max. That is where false rumors come from.
- **Hearsay fades:** tokens below 50 lose 5 reliability per day (floor 10) unless corroborated. Information is perishable, so selling early is tempting.
- Doon is a **gated** source: she only speaks once you hold `s_doon_husband` and have mercy 5 or more.

### 4.3 The crossing (the courier loop)
Each crossing is one short ferry-deck scene with a generated **manifest** of 2 to 5 passengers.

| Archetype | Brings |
|---|---|
| Merchant | Tips, economy tokens, parcels |
| Pilgrim | Hints about Sister Wenna (`p_wenna`), values events |
| Customs scribe | Customs tokens, seal talk |
| Smuggler (dusk only) | Look-away tip offers (`e_smuggler_tip`), fidelity/fairness choices |
| Child | Small notes, mercy events |
| Sailor | Gossip, rumors, rumor-mill tokens |
| Warden aide | Brack-side tokens |

Beats per crossing: **listen** (overheard tokens), **talk** (checks), **tip** (0 to 3 tallies, modified by fairness and candor), **parcels**, and occasional **events** (fog forces a slack wait; inspection; someone overboard; a passenger selling a forged chit).

**Parcels and seals.** A parcel has a recipient, a fee (2 to 6 tallies), a deadline and a seal. Delivering intact gives fidelity +1. Opening gives a token from a pool of secrets and economy tokens, curiosity +1, fidelity −2, and sets `seals_broken += 1`. A recipient notices a broken seal 60% of the time. The Skeleton Seal reads parcels with no penalty.

### 4.4 Tides
A tide table drives which places are open: the Salt Steps are dry only in the first hour of dawn and dusk ebb (`t_lowebb`). Wights only rise at slack (`b_wight_slack`). Knowing the tide is itself intel.

### 4.5 Economy
**Income (one 14-day Act I, tallies):** wages 6/day (84), tips about 1.5 per crossing (63 typical), parcels (56 typical), information sales (70 typical), salvage runs (40 typical), minus board 2/day (28). Modelled outcome: **132 low, 285 typical, 494 high.**

**Sinks:** gear (below), bribes (customs 8, gatehouse guard 25 in seed B), Assize fee 10, boat hire 30 (free if given the Patience), fare-boats and board in Act II, and **Slack inflation** (prices rise about 4% a day from day 6, capped at +60%), so buy early or pay more.

**Gear (price in tallies):** storm lantern 10, salt pouch 4, iron nails 5, iron pot 2, felt overshoes 12, rope and grapnel 8, oilskin coat 18, oiled leather jerkin 70, boarding pike 60, ginger tonic 6, tide almanac 6, fresh eels 6, skiff hire 4, boat hire 30.

**The information market.** Ottoline Prewitt (and later other buyers) buys tokens. Price is `base(category) × reliability factor × scarcity factor × Slack inflation`. Hearsay below 50 sells at half. Each sale raises the token's *spread*: later buyers pay less, and the token starts appearing in NPC mouths, which weakens your leverage. Selling a secret about a specific person **alerts them** and can cost you (`ve_sell_harm`). Hoard or sell is a real choice.

**Cheapest purchase-only cost to finish (tallies, from the validator):**

| Road | Seed A | Seed B | Seed C |
|---|---|---|---|
| Word (Assize) | 34 | 34 | 24 |
| Bargain | gift required | 84 | gift required |
| Hand (force) | 166 | 166 | 166 |

A low earner (132) can afford Word but not Hand. A typical earner (285) can afford Hand plus extras. That spread is intended.

### 4.6 Values and gifts
Eight original values, scale 0 to 10, start at 3: **candor, mercy, fairness, nerve, patience, fidelity, curiosity, restraint.** Twenty-three value events move them (full list in the JSON), for example: opening a parcel is curiosity +1 and fidelity −2; a failed bluff is candor −1; waiting out slack is patience +1; killing a pleading creature is mercy −2.

**Gifts.** Seven NPCs give an item if your values align and you have learned what they prize (the `p_*` hint token):

| Giver | Item | Values required | Other | Effect |
|---|---|---|---|---|
| Ansel Croy | Warding Wick | mercy 6, restraint 5 | | 3 charges; banishes wights, sears the Choir |
| Sister Wenna | Bell of Turning | patience 7, nerve 4 | | One use; settles the Choir |
| Dame Vosk | Skeleton Seal | fidelity 7, candor 5 | `seals_broken` = 0 | Read parcels and open the gatehouse door cleanly |
| Toma Reedhand | Eelskin Cloak | fairness 6, curiosity 3 | | Armor; cold and drowning resistance |
| Yarrow Thistle | Truthglass | candor 8 | | Once per scene, reveals if a claim conflicts with your journal |
| Capt. Brack | Lull-Cutter | nerve 7, mercy 4 | | Weapon; never dulls |
| Hesper Quillon | The Patience (loan) | fidelity 6 | `left_honorably` | Free passage to the Lesser Gate (saves 30t) |

Built-in tensions: opening parcels forfeits the Skeleton Seal; repeated bluffing forfeits the Truthglass; nerve-heavy and patience-heavy play pull against each other. **Budget math:** holding all seven needs 49 value points in total; with 16 earned points you can hold about 4 gifts, with 20 about 5, with 24 about 6. Playtest to check that a typical run earns 16 to 20 points.

### 4.7 Monsters
| Creature | Where | Counters | Non-violent route |
|---|---|---|---|
| Silt-wight | Arcade, cistern, Underworks; at slack only | salt, Wick, Cutter, pike | Lead a pleading wight up (mercy) |
| Gulcher | Steps, Arcade | iron nails, pike, Cutter | Scatter iron and walk on |
| Lullhound | Arcade, Underworks | felt overshoes, iron-pot decoy, Cutter, pike | Decoy or silent passage |
| Kelpmother | Reedwick Marsh | fresh eels | Tribute only, not fightable |
| Pale Collector | Salt Steps | three drowned marks | Pay the toll (fairness) |
| Gatehouse guards | Gatehouse, seeds A and B | seal, welcome (A), bribe (B), Cutter, pike | see entry methods |
| Sunken Choir | Underworks | Wick, Cutter, Bell of Turning | Bell, or read its name (seed C) |

Every hostile has a knowledge route and a purchasable counter, so no encounter is a pure combat check.

### 4.8 The finale
**Stage 1, reach:** by boat via the Lesser Gate (needs `t_weir_gates` plus boat hire or the Patience), or under the river through the Bellmaker's cistern (no boat needed).

**Stage 2, enter:**

| Method | Seeds | Needs |
|---|---|---|
| Seal | A, B, C | `r_gate_seal` and the Skeleton Seal |
| Welcome | A | `p_doon`, `s_doon_husband`, mercy 5 |
| Bribe | B | `c1b` and 25 tallies |
| Cistern | A, B, C | `t_cistern_way`, `r_cistern_knock`, lantern, 3 salt, iron pot |

**Stage 3, settle the cause (three roads):**

| | **Word** (convince) | **Bargain** (trade) | **Hand** (force) |
|---|---|---|---|
| **A: the Held Gate** (Doon holds the tide to keep the Choir asleep) | `c1a c4a c5a ev_a_lantern r_assize_call` at reliability 75, 10t fee, candor 5 | `c5a p_doon s_doon_husband`, Bell or Wick, mercy 5, fidelity 5 | weapon, armor, lantern, 2 tonics, nerve 6 |
| **B: the Long Cargo** (Tally House throttles the sluice for profit and it jams) | `c1b c4b c5b ev_b_paystub r_assize_call` at 75, 10t, candor 5 | `c5b p_ottoline s_ottoline_ledger`, Truthglass or 60t, fairness 5 | as A, using `c4b` |
| **C: the Waking Choir** (no one is at fault) | `c1c c3c c4c ev_c_hum` at 75, patience 6 | `c5c r_third_bell`, Bell of Turning, patience 7 | as A plus 3 salt, needs `b_choir_wick b_wight_salt b_lull_sound` |

**Common ending step:** speak the three Turning Words (`r_word_1..3`: Ebb, Hold, Turn) at the third bell (`r_third_bell`) during Full Slack.

**Endings.** Nine road-by-culprit resolutions, plus a failure ending (deadline missed), plus an epilogue line chosen by your highest value (eight variants). A wrong accusation at the Assize (using a false or forged token) costs the fee, fairness −2, and the Assize will not sit again.

---

## 5. Cast

| Id | Name | Role | Location |
|---|---|---|---|
| hesper | Hesper Quillon | Ferrymaster, your employer | Sorrel Landing |
| doss | Doss Pellam | Deckhand, rumor mill, fare skimmer | Ferry deck |
| goldie | Goldie Fenn | Chandler, sells gear | Sorrel Landing |
| cobb | Ma Cobb | Landlady, rumor mill | The Low Lantern |
| fen | Fen Aldous | Old salvager (good before noon, useless after gin) | The Low Lantern |
| ottoline | Ottoline Prewitt | Broker at the counting-house | Tally House |
| corvin | Corvin Ashe | Tally agent, nervous | Tally House |
| wimble | Clerk Wimble | Customs clerk, sells access | Customs House |
| vosk | Dame Perrin Vosk | Retired inspector | Customs House |
| croy | Ansel Croy | Lampwright | Croy's Lamp |
| yarrow | Yarrow Thistle | Tinker-widow | Far Wend |
| brack | Capt. Isolde Brack | Retired Warden | Far Wend |
| toma | Toma Reedhand | Eel-catcher | Reedwick Marsh |
| wenna | Sister Wenna | Bell-hermit | Cormorant Rocks |
| doon | Ilsabet Doon | Weirkeeper | Weir Gatehouse |
| collector | The Pale Collector | Toll-ghost | Salt Steps |
| harrow | Lisle Harrow | Dying courier, day 2 | Ferry deck |
| gatehouse_guard | Gatehouse guards | Oath-guards (A) or hirelings (B) | Gatehouse |

---

## 6. Maps (15)

| Id | Map | Notes |
|---|---|---|
| ferry_deck | The ferry *Patience* | Every crossing scene; manifest generated per leg |
| sorrel_landing | Sorrel Landing | Home dock, Hesper's office, chandlery |
| low_lantern | The Low Lantern | Tavern; gossip hub |
| marl_landing | Marl Cross | Island town; Salt Steps entrance at low ebb |
| tally_house | Tally & Prewitt Counting-House | Broker; ledger under the third stair |
| customs_house | The Customs House | Records; cellar of old sluice ledgers |
| far_wend_landing | Far Wend | Yarrow's wagon, Brack's lodge, Warden post |
| croy_lighthouse | Croy's Lamp | Only working signal lamp |
| reedwick_marsh | Reedwick Marsh | Heron-stone path; kelpmother's pool |
| cormorant_rocks | Cormorant Rocks | Boat only (skiff hire 4t) |
| salt_steps | The Salt Steps | Tidal stair; gulchers; the Pale Collector |
| drowned_arcade | The Drowned Arcade | Wights at slack; gulchers; lullhound |
| bellmakers_cistern | The Bellmaker's Cistern | Password knock leads under the Weir |
| weir_gatehouse | The Weir Gatehouse | Boat via the Lesser Gate |
| weir_underworks | The Weir Underworks | Finale; the Sunken Choir |

Connectivity is in the JSON (`locations.*.links`). Each map is small; the initial pass should be greybox with placeholder art.

---

## 7. What varies per seed

- **The culprit** (A, B or C): decides which answer in each of the five triads (`q1` to `q5`) is true, and which evidence exists (genuine `ev_*`; forged `fg_*` in the seeds where that culprit is not real).
- Manifests per crossing (weighted by day, time and Slack Index).
- Parcel contents and recipients.
- Slack Index timing (±1 day).
- Which rumors circulate (rumor mills carry all versions).

Later, optional: shuffle which of several eligible NPCs holds the second source for a token.

**Harness invariants** (run headless over 1,000 or more seeds; this is the "context-simulation harness" from your design):

1. Every triad has exactly one true answer per seed.
2. Every evidence group has exactly one present member per seed.
3. Every token needed by a road exists, is true in that seed, and has at least two ungated, non-rumor sources (so it can be corroborated to 75).
4. The Word road is feasible in every seed for a player with no gifts and the low-end income (132), and at least two roads are feasible with no gifts at the typical income (285).
5. At least one entry method is feasible in every seed (cistern always is).
6. No gift requires a token whose only source is gated behind that gift.
7. No soft-lock after departure: the player can always afford at least one fare-boat and board to reach Far Wend and an Assize.
8. Value gates: no seed makes every gift unreachable together (budget math in 4.6).
9. Forgeries are never the only source for a road requirement.
10. Scripted bots (Word-bot, Hand-bot, Bargain-bot) reach the finale in every seed where their road is feasible.

The build script that produced the spec already passes invariants 1, 2, 3 and 5 statically (0 errors, 0 warnings). The dynamic ones (4, 6 to 10) need the game to exist.

---

## 8. Design notes on the economy of intel

- Selling a token lowers its future value and spreads it; using it to expose a lie or unlock a gift keeps it valuable to you. Every good token has a "sell now" and "use later" reading.
- Corroboration is a resource: two ungated sources reach 75, which is what the Assize and Bargain roads demand.
- Forgeries are the game's traps. A wrong accusation with a forged chit has a real cost, and Dame Vosk and the Truthglass exist as counters.

---

## 9. Chaos surface (draft for `CHAOS_SPEC.md`)

- **Epistemic:** the seed-dependent truth of five triads and two evidence pairs; false rumors from rumor mills; forged evidence; hearsay decay; corroboration; the Truthglass.
- **Combinatorial:** culprit (3) × road (3) × entry method (up to 4) × which gifts you qualify for (about 4 of 7) × manifest and parcel draws. Plenty of variety from a small authored set.
- **Social:** eight values, seven gift NPCs with different thresholds, gated Doon, fairness with shops, Hesper's honorable-departure gift, alerting people by selling their secrets.
- **Mechanical:** tide windows, Slack Index and inflation, wight activity at slack, sound-hunting lullhound, iron and salt counters, the deadline on Full Slack day 8.

---

## 10. Implementation classes and build order

**Likely data-only** (verify against the real schema): tokens with reliability sources and conflict groups, NPCs and their `check`-driven dialogue, items, shops, gift conditions expressed as stat and flag checks, map layouts, POIs, monster stat blocks.

**Likely a game-specific module** (`slack_tide_boot.gd`): seed truth assignment (culprit, evidence spawn), tide clock and Slack Index, passenger manifest generator, parcel/seal logic, information market pricing and spread, reliability decay, value events, finale checker, ending selector.

**Possible engine requests** (ask before building): a group-exclusive conflict set resolved by seed; scheduled reliability decay on tokens; a market/price-by-token hook. If the engine cannot do these generically, implement them in the module.

**Milestones with acceptance criteria:**

| # | Milestone | Done when |
|---|---|---|
| M0 | Headless token graph and harness | `slack_tide_spec.json` loads; harness invariants 1 to 3, 5 pass for 1,000 seeds; no rendering needed |
| M1 | Days 1 to 3 playable | Ferry deck, three crossings a day, Harrow's death and satchel, intel checks, tips, parcels; greybox art |
| M2 | Economy and values | Shops, information market, value events and the gift gates working |
| M3 | Act II | Salt Steps, Arcade, monsters with counters, Assize |
| M4 | Finale | Three roads, four entries, nine endings, deadline failure |
| M5 | Pass | Art, audio, writing pass, packaging, save/load, settings |

**Ship goal for M1:** a playable Days 1 to 3 slice as early as you can, even if ugly. It is the best guard against the engine trap.

---

## 11. IP hygiene

Banlist (case-insensitive; Cline should grep the shipped package for these before each commit; this design document is excluded because it names the source game by necessity): `zork`, `infocom`, `frobozz`, `flathead`, `grue`, `great underground empire`, `round room`, `mr. chompers`, `greldok`, `tarbel`, `sir reginald`, `odysseus`, `nobby`, `cyclops`, `troll`, and `thief` used as a character or role name. Also avoid any Ultima proper noun (the virtue names here are original). Generic nouns such as lantern, sword and dark are fine.

This world shares no setting, characters, monsters, item names or text with Zork. What is kept is the mechanic (intel journal `check`, reliability, `conflicts`), which is a design idea rather than protected expression. I am not a lawyer; if you plan to sell, a quick review before release is worth it.

---

## 12. Open questions (candidates for `RULINGS.md`)

1. Run length target: 60 to 90 minutes, or longer? This decides how many days Act I needs.
2. Is the Slack Index purely deterministic, or can player actions delay or speed it?
3. Should any early combat exist in Act I, or stay strictly nonviolent?
4. How does a player detect a forgery without the Truthglass? (Suggested: Dame Vosk's smell test, plus the ink-freshness clue.)
5. Do gifts and values persist between runs? (Suggested: no. Each run starts fresh; only a small "seen endings" log persists.)
6. Ferry deck: one scene card reused for every crossing with swapped passenger portraits? (Assumed yes.)
7. Final title. *Slack Tide* is a working name.
8. Voice: the dry Infocom-style narrator from Zork, or a warmer, saltier voice? (Samples in Section 2 lean toward the latter.)
