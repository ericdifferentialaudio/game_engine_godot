# Underground NPCs — Aevum: Age of Shrines
## Design Reference Document

> **`[UNWIRED]` 08/24/2026**: `engine/engine_underground.py` fully implements
> `interact_npc()` for all 8 NPC types below with correct mechanics (costs,
> suspicion, jail rolls, knowledge bleed), and `spawn_street_npcs()` does seed
> a roster into every town at world-gen. But **`interact_npc()` is never
> called from anywhere** — no AI goal, no interior menu path, no player
> action reaches it, and there are no tests exercising it. The NPCs exist in
> the world data but are functionally invisible/unreachable in any current
> game. Treat this document as unreachable design-intent until an actual
> call site is added.

> **NSFW Note**: This document describes mature NPC content. All NSFW-flagged interactions are
> gated behind `config.nsfw_dialogue = True`. Non-NSFW mode provides alternate framing for the
> same mechanical outcomes. Nothing in this document requires explicit content — the NSFW flag
> adds *framing*, not different mechanics.

---

## Overview

These 8 NPC types populate the social underside of towns, pubs, and streets. They are not quest
givers, dungeon bosses, or faction leaders. They are people doing their thing in the margins of
a society that has more important problems. Some are dangerous. Some are useful. Some are both.

**Shared rules for all underground NPCs**:
- They spawn in **towns only** (not castles, not lairs) — seeded at world-gen per town
- Spawn chance per town: 30–60% (varies by NPC type — rarer NPCs have lower base chance)
- They occupy **interior NPC slots** alongside existing types (barkeep, merchant, etc.)
- They use the existing `_NPC_ADJ_RADIUS = 1` adjacency system for dialogue triggers
- All have `nsfw_eligible` flags on their personality archetype
- All use `town_dialogue.json` as their dialogue file

### Knowledge Bleed — Stat Spread Mechanic

When a unit receives a **permanent stat bonus** from an underground NPC interaction, the bonus
lives on that specific unit. However:

- If the blessed unit shares an interior location with **other clan units for 3+ consecutive turns**,
  each adjacent clan unit has a **15% chance per turn** of gaining a **3-turn temporary** version
  of the same bonus
- This temporary version is flagged as "inspired" and cannot stack (a unit cannot be doubly inspired
  by the same source)
- A unit cannot receive knowledge bleed from an NPC it has already interacted with directly
  (the bleed is the *secondhand* version of a firsthand experience)
- This creates genuine tactical value in grouping units: your experienced unit sharing space with
  newer units is *worth something*

---

## NPC Type Profiles

---

### 1. Lady of the Night

**NPC type ID**: `lady_of_night`
**Personality archetype**: `streetwise_charmer`
**Intel tier**: T2
**Spawn chance per town**: 35%
**Placement bias**: Town pub interior, occasionally alley-adjacent rooms

**Who she is**: She is the most self-possessed person in any building she's in. She's been
listening to merchants, lords, and desperate clan leaders for years. She notices things other
people miss because she has to. She's warm, direct, and has better information than the barkeep.

The +1 HP isn't magic. It's what rest, genuine attention, and a few hours of not being a
soldier does for a person. The game treats this as real.

**Mechanical effect**:
- Cost: 75g
- Effect: **+1 permanent HP max** on the interacting unit
- Additional: She is a **T2 intel source** — after the first paid visit, she will share location
  intel from the people she's seen. Relationship tier unlocks after 2 visits.
- At Relationship Tier 2 (trusted): She shares T3 intel — the kind that comes from people who
  thought they were in private

**NSFW mode framing**:
- Interaction is clearly implied; dialogue is honest and matter-of-fact about what's happening
- She is not embarrassed. She is professional. The dialogue reflects this.
- Example NSFW line: *"You come back tomorrow. I'll still be here and you'll still feel better
  for having slept. That's the deal and it's a fair one."*

**Non-NSFW mode framing**:
- She is a "Comfort-Giver" — restorative services, warmth, genuine human attention
- Example non-NSFW line: *"You look like you haven't slept in three days. Sit. You're not
  leaving here until you do."*
- The +1 HP is identical either way

**Dialogue style**: Warm, dry, world-weary without being cynical. She's seen a lot but hasn't
stopped caring. Cultural DNA: Mork & Mindy's outsider-observer clarity, applied to someone who
has to understand people to survive.

**Intel dialogue example**:
> *"The lord who came through here last week — the one from the northern castle — he wasn't
> worried about the dragon. He was worried about [rival_clan]. Whatever they're doing near
> [direction], he didn't want to say out loud. Which means it's worth finding out."*

**Guard interaction**: None. She's known to the guards. They leave her alone. The settlement has
reached an accommodation. This is noted in her dialogue if asked.

**Relationship tiers**:
| Visits | Tier | Bonus |
|---|---|---|
| 1 | First | +1 HP, T1 intel |
| 2 | Regular | T2 intel unlocked |
| 3+ | Trusted | T3 intel; she may warn you of danger in the settlement |

---

### 2. Shady Guy

**NPC type ID**: `shady_guy`
**Personality archetype**: `shifty_lookout`
**Intel tier**: T1–T2
**Spawn chance per town**: 50%
**Placement bias**: Corners, doorways, near exits — anywhere with a clear sight line to the street

**Who he is**: He's not one person. He's a type — the guy who's always in the corner, always
watching, always willing to tell you something for a small consideration. Sometimes the
information is accurate. Sometimes he's working for someone else.

**Mechanical effects**:
- Cost: 10–20g per conversation (random; he names his price)
- Effect: Random T1–T2 intel from the location's gossip pool
- **Double-agent roll**: 30% chance the intel is intentionally wrong — a rival clan is paying him
  to misdirect. The roll is hidden; the player gets the intel and can't know if it's real.
- At Relationship 2+ (you've bought from him more than once), the double-agent chance drops to 15%
  — he starts to prefer your coin

**Finding the Shadow Accord**: The Correspondent from the Shadow Accord mercenary company can only
be found by asking a Shady Guy (or a Criminal). This is the *only* in-world discovery path for
that company.

**Dialogue style**: Short, clipped, always looking at the door. Sentences trail off. He implies
more than he says. He never looks directly at you.

**Example dialogue**:
> *"Heard something last week. Might be worth — look, it'll cost you. Standard rate. Don't
> touch my arm when you hand it over. Just — there. Thank you. Right. So. [location_hint].
> Don't tell anyone I said that."*

**Guard interaction**: If a guard enters within 3 hexes while a clan unit is talking to a Shady
Guy, the Shady Guy ends the conversation immediately ("I've got to go") and moves to the farthest
corner. The guard will glance at the clan unit — suspicion +1.

---

### 3. Juggler

**NPC type ID**: `juggler`
**Personality archetype**: `street_performer`
**Intel tier**: None (no intel — this NPC is purely a stat/buff source)
**Spawn chance per town**: 25%
**Placement bias**: Market areas, open interior spaces, pub common rooms

**Who she is**: A street performer who has spent years developing extraordinary physical and mental
coordination. She's not trying to impress anyone in particular. She's just very good at something
and it shows. Watching someone be genuinely excellent at a difficult thing is, it turns out,
actually inspiring.

**Mechanical effects**:
- Cost: Free (watching). She may ask for a coin — declining is fine, no penalty.
- Effect: **+1 INT bonus, +1 DEX bonus** to the watching unit (permanent)
  - INT bonus (`int_bonus` field): improves intel tier received — T1 intel gives the full T2 detail
  - DEX bonus (`dex_bonus` field): contributes to MOV and ATK as a minor fractional bonus
- **Once only per unit**: A unit cannot be inspired twice by watching a juggler
- **Knowledge Bleed eligible**: The INT/DEX bonuses can spread to adjacent clan units (15%/turn,
  temporary version, see Knowledge Bleed above)

**Dialogue style**: Cheerful, distracted, slightly philosophical about juggling as metaphor.
She talks while performing. Her attention is on the balls, not on you.

**Example dialogue**:
> *"People always ask how I keep track of all of them at once. Honestly? I don't. You stop
> tracking them individually and start feeling the whole system. The moment you think about
> one ball specifically is the moment the pattern breaks. I imagine that applies to things
> other than juggling. Probably."*

**Guard interaction**: None. She's permitted. She pays the town a small performance fee.

**NSFW note**: Some mildly double-entendre lines available in NSFW mode ("keep your eyes on
the balls" etc.). Not mechanical; just flavour.

---

### 4. Hackey Sack Person

**NPC type ID**: `hackey_sack`
**Personality archetype**: `street_performer`  *(shared with juggler; different dialogue pool)*
**Intel tier**: None
**Spawn chance per town**: 20%
**Placement bias**: Same as juggler — open spaces, pub areas

**Who he is**: The juggler's philosophical counterpart. Where juggling is dazzle and precision,
the hackey sack is flow — continuous, low-stakes, meditative. He doesn't notice you watching.
He's in a state of focus that just happens to be visible.

**Mechanical effects**:
- Cost: Free
- Effect: **+1 DEX bonus, +1 WIS bonus** to the watching unit (permanent)
  - DEX bonus: same as juggler
  - WIS bonus (`wis_bonus` field): improves meditation speed — shrine lock time reduced by 1 turn
    per WIS point; also gives minor resistance to morale effects
- **Once only per unit**: Same rule as juggler
- **Knowledge Bleed eligible**: WIS/DEX bonuses can spread

**Dialogue style**: Slow, present-tense, not particularly eloquent. He's not trying to teach
you anything. He's just there.

**Example dialogue**:
> *"Yeah. Been at it for about three hours I think. Lose track. Doesn't matter much does it.
> You going somewhere? ... Alright. See you."*

**NSFW note**: Nothing inherent. The character is just very relaxed.

---

### 5. Dealer

**NPC type ID**: `dealer`
**Personality archetype**: `back_alley_dealer`
**Intel tier**: T2 (after a purchase — intel comes with the receipt, so to speak)
**Spawn chance per town**: 30%
**Placement bias**: Back rooms, corners of pubs, near the pub exit

**Who he is**: Not panicked. Not threatening. Just very specific about what he does and doesn't
carry and what things cost. He's a professional. The professional affect is partly genuine and
partly a survival mechanism. He doesn't need you to trust him. He just needs you to decide.

**Inventory** (rotates; 2–3 items available per town visit):

| Item ID | Name | Effect | Cost |
|---|---|---|---|
| `mystery_powder` | Mystery Powder | +2 ATK for 4 turns (consumable) | 80g |
| `crimson_tonic` | Crimson Tonic | +2 MOV for 3 turns (consumable) | 70g |
| `shadow_dust` | Shadow Dust | +1 STL, invisible 2 turns (consumable) | 90g |
| `clarity_draught` | Clarity Draught | +1 WIS permanent (consumable) | 150g |
| `reagent_cache` | Rare Reagent Cache | High-value trade commodity or ritual use | 120g |
| `black_salve` | Black Salve | Removes 1 negative status effect (consumable) | 100g |

**Guard suspicion mechanic**:
- Each item purchased from the Dealer adds **+1 to the town's `guard_suspicion`** counter
  for the buying clan
- At suspicion ≥ 3: guards perform a check on the clan's next movement in this town
- Check result: 30% chance of confrontation → `VIOLATION_ASSAULT` protocol → pay 50g bribe OR
  jail 2 turns (same as `JAIL_TURNS_THEFT`)
- Talking to the Dealer (without buying) adds +0.5 suspicion (rounds up on 2nd conversation)

**Intel mechanic**: After purchasing any item, the Dealer will, without being asked, mention
one thing he's heard recently. This is genuine T2 intel from the gossip pool. He considers it
included in the price. He does not explain why.

**Dialogue style**: Flat affect. Professional. Calm. Pulp Fiction energy — the man who takes
his work seriously even if his work is technically illegal. He's not hiding. He's just quiet.

**Example dialogue**:
> *"I've got three things tonight. You want to hear what they are or do you already know what
> you need. ... Right. The powder's eighty. The tonic is seventy. I'd take the tonic if I were
> you but I'm not, so. Your call."*

**NSFW mode**: Raunchier product names, slightly more explicit about the nature of certain
items. Nothing beyond adult drug-culture framing.

**Guard interaction**: Dealer is not jailable. If a guard approaches within 2 hexes while a
transaction is in progress, the Dealer pockets everything and walks away casually. The item
does not transfer and the gold is not spent. The interaction simply ends. He is faster than
the guards and they both know it.

---

### 6. Fence

**NPC type ID**: `fence`
**Personality archetype**: `nimble_fingers`
**Intel tier**: T1 (stolen gossip — always slightly inaccurate)
**Spawn chance per town**: 40%
**Placement bias**: Near the blacksmith, near market stalls — close to where goods change hands

**Who she is**: She's had these items since last week. She didn't ask where they came from, which
is a professional courtesy everyone in this business extends to each other. She'll sell them to
you for less than they cost new. She's doing you a favour, technically.

**Inventory mechanic — Sold Items Pool**:
- Any item sold TO a town shop enters the town's `sold_items_pool` list on `TownInstance`
- After **5–10 turns** (randomized per item), the item moves to the Fence's available inventory
- Fence sells it at **50–60% of base market value** (randomized per item)
- Items may be **slightly damaged** (15% chance per item): one stat bonus is −1 from listed value
- The item is flagged as `sourced: "fence"` for bad karma tracking

**Bad Karma system** (`shady_rep` counter on TownInstance per clan):
- Each fence purchase: +1 shady_rep for the buying clan in this town
- **At shady_rep ≥ 3**: Legitimate NPCs in this town (healer, shopkeeper, regent) treat the clan
  as "stranger" tier regardless of actual relationship score; prices +10%
- **At shady_rep ≥ 5**: Guards perform proactive suspicion checks every turn the clan is present
- **shady_rep decays**: −1 per 15 turns naturally; can be accelerated by paying a 100g "goodwill"
  payment to the town regent (they don't ask where the money came from)

**Jail roll on purchase**:
```
jail_chance = base_25% + (suspicion × 5%) − (stealth_bonus × 8%)
```
- On jail: `VIOLATION_THEFT` → 2-turn jail
- On success: item is yours, no consequences
- The risk is real but calculable. A Rogue-type unit with stealth ≥ 2 has only a ~9% jail chance.

**Dialogue style**: Casual, bored, always scanning the room. Short sentences. She's done this
ten thousand times. The only thing that makes her nervous is a guard within eyeshot.

**Example dialogue**:
> *"Got some things in. Came in last week, won't ask from where. The boots are yours for
> twenty-five. Shield's thirty. I'll take twenty for the draught but it's been sitting a while.
> Up to you."*

**Guard interaction**:
- If a guard enters within 3 hexes while the Fence is talking to a clan unit, the jail roll
  triggers immediately (even without a purchase completing)
- The Fence herself is never jailed — she has arrangement with the town. Her customers are
  their problem.

**NSFW mode**: Optional additional "hot goods" category — stolen luxury items, personal
possessions. More expensive, better quality, higher jail risk. The Fence is more explicit about
their origins ("Don't look for the original owner" etc.).

---

### 7. Politician

**NPC type ID**: `politician`
**Personality archetype**: `silver_tongued_pol`
**Intel tier**: T3 (he knows what's actually happening, politically — but never says it directly)
**Spawn chance per town**: 20% (towns with Regent service); 35% (castles)
**Placement bias**: Regent offices, castle broker chambers, the nicer pub tables

**Who he is**: He's been doing this for twenty years. He's very good at making you feel like you
just had a productive conversation without being able to identify exactly what was decided. The
bribe isn't a bribe. It's a "campaign contribution." He's very clear about the distinction, which
he will explain at length.

**Mechanical effects**:
- Cost: **200–400g bribe** (scales with current game turn and rival clan count — later game,
  more expensive; more clans competing for influence, higher price)
- Effect (on bribe accepted):
  - **+2 INT bonus** on the interacting unit
  - **+2 WIS bonus** on the interacting unit
  - **+2 INF** added to the clan's diplomacy influence pool
- **INF (Influence)** is a clan-level resource used for:
  - Better trade terms with neutral clans (−10% cost on inter-clan trades)
  - Access to castle broker at lower gold cost (−50g per broker visit)
  - **"Call in a Favour"**: spend 5 INF to prevent one specified rival clan from attacking the
    paying clan's units for 3 turns (diplomatic pressure mechanic)
  - Required for hiring top mercenary companies (see mercenary_companies.md)

**Gating**: Politicians will not deal with clans whose shady_rep ≥ 3 in this town. They know
their own brand. They won't discuss the bribe if a guard is nearby. They will describe it as
"a consultation fee" for "strategic advice services."

**Dialogue style**: Smooth. Never says anything specific. Every statement has 3 interpretations.
Promises things that are technically true and practically useless. The moment you realize you've
been had is the moment he's already out the door.

**Example dialogue**:
> *"I appreciate you stopping by. I've been — let me be direct with you, because I think you
> deserve directness — I've been hearing some things about your clan's activities in this region.
> Good things. Mostly. The sort of things that make certain conversations... worth having.
> I wonder if we could discuss some arrangements that would be mutually advantageous. In a
> general sense. Nothing specific yet."*

**NSFW mode**: Hints at other varieties of political favour available. The "arrangements" are
not purely financial. This is flavour only and doesn't change the mechanic.

**Guard interaction**: Politicians are immune to guard attention. They *are* the political layer
above the guards. They may, however, quietly inform the guards about a clan they've decided
to stop protecting. This is flavour — not a mechanic the player can trigger deliberately.

---

### 8. Criminal

**NPC type ID**: `criminal`
**Personality archetype**: `hardened_criminal`
**Intel tier**: T2–T3 (he's been in places; he knows things that aren't on any official record)
**Spawn chance per town**: 25%
**Placement bias**: Pub back corners, near exits — always with a clear path out

**Who he is**: He's not threatening you. He doesn't need to. He's calm the way that people are
calm when they're very capable of being not calm and have simply chosen not to be, right now.
He sells things. He fights for the right price. He won't be arrested. He will leave before that
becomes a question.

**Interaction 1 — Shop**: His inventory is random T1 and T2 items with **no class restrictions**
(he doesn't care who the original manufacturer said should use it). Price is 120% of market value
(the risk premium). He has 2–3 items per visit. Inventory refreshes every 15 turns.

**Interaction 2 — Hire as Mercenary Company Representative**:
The Criminal NPC is the **solo-hire face** of a small personal network — 1–3 operators
available on short notice. This is the entry-level mercenary hire, cheaper and faster than
the named companies, with lower commitment:

| Package | Cost | Duration | Units |
|---|---|---|---|
| Solo hire | 150g sign + 20g/turn | Negotiable | 1 |
| Small crew | 300g sign + 40g/turn | Negotiable | 3 |

- **Negotiable duration**: Criminal mercenaries don't have fixed contracts. You negotiate turns
  at hire. Extension is possible if sentiment is positive.
- **Sentiment-based rate**: Criminal's personal sentiment toward the hiring clan modifies the rate
  (same formula as company sentiment — 0.75x to 1.40x)
- **He waits outside**: Criminal mercenaries do not enter settlements. They hold position on the
  adjacent world hex. This is not a limitation — it's a feature. He won't get arrested working
  for you. He also won't be there when you need to run a town errand.
- **Stiff penalty**: −20 sentiment. He will specifically mention it next time you interact.
  Personally.

**Guard interaction — Flee mechanic**:
- If a guard enters within **2 hexes** while the Criminal is in an interior, the Criminal
  exits the interior immediately (auto-teleport to the adjacent world hex)
- This makes interacting with him a **time-pressure mechanic**: you have a window before a
  patrol arrives. The guard patrol timing is visible (guards move on known schedules)
- He is not jailable by design. He's too fast. The guards know this and have stopped trying.
- He can **warn the player** about upcoming patrols if his sentiment is ≥ 20:
  *"You've got maybe two minutes before the evening round. You want to talk fast or leave and
  come back."*

**Intel**: After a successful transaction (shop or hire), he mentions one T2–T3 intel piece —
typically about rival clan movements or lair contents. He doesn't explain how he knows.

**Dialogue style**: Laconic. Pulp Fiction hitman calmness. Respectful of competence, indifferent
to anything else. He doesn't make small talk but isn't rude about it.

**Example dialogue**:
> *"What do you need. ... Right. I've got that. Hundred and forty. You want it or not.
> ... Good. Anything else. Because I'm expecting company in about — actually, let's finish
> this outside."*

**NSFW mode**: Slightly rougher dialogue. Past crimes referenced more directly. He uses words
the non-NSFW version implies.

**Mercenary company link**: Finding the Broken Road Company's Harric, or the Shadow Accord's
Correspondent, can be done by asking the Criminal. He knows them. He won't introduce you for
free — that's a 30g favour.

---

## Implementation Notes

### New fields on `UnitInstance` (game_state.py)
```python
int_bonus: int = 0       # intelligence — improves intel tier received
dex_bonus: int = 0       # dexterity — minor MOV/ATK contribution
wis_bonus: int = 0       # wisdom — reduces shrine lock time, morale resistance
inspired_by: list[str] = field(default_factory=list)  # npc_ids already absorbed
```

### New fields on `TownInstance` (game_state.py)
```python
guard_suspicion: dict[str, int] = field(default_factory=dict)  # clan_id -> suspicion level
shady_rep: dict[str, int] = field(default_factory=dict)        # clan_id -> reputation level
sold_items_pool: list[dict] = field(default_factory=list)      # items sold to shops
fence_inventory: list[dict] = field(default_factory=list)      # fenced items available
```

### New entries in `_ALL_NPC_TYPES` (engine_npc.py)
```python
_ALL_NPC_TYPES = frozenset({
    # ... existing types ...
    "lady_of_night", "shady_guy", "juggler", "hackey_sack",
    "dealer", "fence", "politician", "criminal",
})
```

### New personality archetypes in `NPC_PERSONALITIES` (engine_npc.py)
```python
"streetwise_charmer":  {"dialogue_pool": "town_lady_night",  "intel_leak_bonus": 0.20, "info_tier": 2, "nsfw_eligible": True},
"shifty_lookout":      {"dialogue_pool": "town_shady_guy",   "intel_leak_bonus": 0.10, "info_tier": 1, "nsfw_eligible": True},
"street_performer":    {"dialogue_pool": "town_performer",   "intel_leak_bonus": 0.00, "info_tier": 0, "nsfw_eligible": False},
"back_alley_dealer":   {"dialogue_pool": "town_dealer",      "intel_leak_bonus": 0.05, "info_tier": 2, "nsfw_eligible": True},
"nimble_fingers":      {"dialogue_pool": "town_fence",       "intel_leak_bonus": 0.05, "info_tier": 1, "nsfw_eligible": True},
"silver_tongued_pol":  {"dialogue_pool": "town_politician",  "intel_leak_bonus": -0.10,"info_tier": 3, "nsfw_eligible": True},
"hardened_criminal":   {"dialogue_pool": "town_criminal",    "intel_leak_bonus": 0.15, "info_tier": 2, "nsfw_eligible": True},
```

### Dialogue file
All new NPC dialogue goes in `assets/dialogue/town_dialogue.json` under keys matching their type:
`"lady_of_night"`, `"shady_guy"`, `"juggler"`, `"hackey_sack"`, `"dealer"`, `"fence"`,
`"politician"`, `"criminal"` — each with sub-keys for greeting, standard, nsfw, guard_nearby,
and (where applicable) post_transaction.

---

## Tone Reference

The cultural DNA of these NPCs follows the established Aevum voice:

| NPC | Primary Tone | Cultural Reference |
|---|---|---|
| Lady of the Night | Warm, matter-of-fact, world-weary | Mork & Mindy outsider clarity |
| Shady Guy | Paranoid fragments, terse | HHGTTG paranoid android energy |
| Juggler | Philosophical mid-performance | Monty Python absurdist logic |
| Hackey Sack | Zen non-sequiturs | Mork & Mindy stillness |
| Dealer | Flat professional affect | Pulp Fiction pre-hit calm |
| Fence | Bored efficiency | Monty Python "we sell this" normalcy |
| Politician | Plausible deniability, smooth | Pulp Fiction Marsellus Wallace |
| Criminal | Laconic competence | Pulp Fiction hitman calm |
