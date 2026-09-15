# towns.md — Town System
*Town roster verified 08/24/2026 against `engine/startup_engine.py::TOWN_POOL`
+ `TOWN_DATA` (10 towns total, 4 selected/game) — this is the authoritative
source. `assets/data/towns.json` is a DIFFERENT, orphaned, unloaded file
using fictional Ultima IV town names (Skara Brae, Trinsic, Minoc, Yew,
Moonglow, Jhelom, Britain, Buccaneer's Den) that do not exist anywhere in
the actual game — do not use towns.json as a reference for names.*

## Overview

**Ten** Aevum-original towns exist in the world (`TOWN_POOL`). **Four are
active per game**, selected by seed with weighting toward the active clan
roster. Towns are placed at the four map corners (~radius 65 from center at
diagonal angles — outside all clan enclaves).

Towns are the game's primary intelligence layer, equipment upgrade source, and spiritual economy hub. Visiting them early and often is a core strategic investment, not an optional side activity.

---

## The Ten Towns

| Town | Theme | Contemplation Hall | Unique Service | Weighted toward |
|------|-------|-------------------|----------------|-----------------|
| **Irenvale** | Spirituality | ✓ Primary (free) | — | Mage, Cleric, Shaman |
| **Caldspire** | Honour | — | Virtue Restoration (150g) | Fighter, Monk |
| **Thornmere** | Sacrifice | — | Worker Upgrade (60g) | Dwarf |
| **Duskwall** | Justice | ✓ Secondary (15% fee) | — | Bard, Monk, Cleric |
| **Ashfen** | Honesty | ✓ Tertiary (10% fee) | Oracle (80g/question) | Mage, Bard, Ranger |
| **Greyhollow** | Valour | — | — | Fighter, Ranger, Elf |
| **Velmoor** | Compassion | — | Exhaustion Healing (25g/HP) | Cleric, Druid |
| **Saltmere** | Deception | ✓ Unofficial (15% fake) | Fence (40% discount), Rumor Plant (100g) | Rogue, Bard, Necromancer |
| **Embervoss** | Passion | — | — | (unweighted) |
| **Wraithend** | Mystery | ✓ (10% fee) | — | (unweighted) |

### Selection Process

*Illustrative pseudocode only — actual selection logic lives inline in
`startup_engine.py` using `TOWN_POOL`/`TOWN_DATA`, not a `towns_data` JSON
argument (that shape belongs to the orphaned `towns.json`, not real code).*

```python
def select_active_towns(seed: int, active_clan_ids: list[str],
                        towns_data: dict, count: int = 4) -> list[str]:
    """
    Seed-weighted selection of 4 of 8 towns.
    Active clans increase probability of their weighted towns being selected.
    """
    import random
    rng = random.Random(seed + 200)

    town_ids = list(towns_data["towns"].keys())
    clan_set  = set(active_clan_ids)
    weights   = []

    for tid in town_ids:
        weight   = 1.0
        favoured = towns_data["selection"]["clan_weighting"].get(tid, [])
        weight  += sum(1.5 for clan in favoured if clan in clan_set)
        weights.append(weight)

    selected = []
    remaining_ids = list(town_ids)
    remaining_wts = list(weights)

    for _ in range(count):
        total = sum(remaining_wts)
        r     = rng.uniform(0, total)
        cumul = 0.0
        for j, w in enumerate(remaining_wts):
            cumul += w
            if r <= cumul:
                selected.append(remaining_ids[j])
                remaining_ids.pop(j)
                remaining_wts.pop(j)
                break

    return selected
```

---

## Town Entry

A unit moves onto the town hex. The **Town Panel** opens as an overlay.

- World timer continues running — time is the real cost of a visit
- Unit's remaining movement is preserved; it can continue moving after leaving
- The visit itself costs no movement or action points
- Adjacent enemy units can still attack during a visit (the town offers no protection)

---

## The Four Tabs

### Tab 1 — Armory

Weapon and equipment upgrades. Three items in stock, seed-determined at world generation. Stock is **shared across all clans** — first come, first served. Items never restock.

**Display format:**
```
ARMORY — IRENVALE

  Mana Staff       90g    +4 MP, +1 MP regen          [BUY]
  Focus Crystal   100g    +1 spell damage all casts    [BUY]
  ── SOLD ──
  Spell Staff       —     [SOLD — Mage clan, turn 8]
```

The "SOLD" line shows which clan bought it and on which turn. This is genuine intel: you now know the Mage clan visited Irenvale on turn 8 and has the Spell Staff equipped.

**Armory pool by town:**

| Town | Pool |
|------|------|
| Irenvale | mana_staff, spell_staff, focus_crystal, exhaust_sigil, spell_scroll |
| Caldspire | flameblade, soulreaver, runic_axe, keen_blade, iron_shield |
| Thornmere | runic_axe, keen_blade, iron_shield, frostblade |
| Duskwall | shadowblade, shadowbow, elfbow, longbow |
| Ashfen | mana_staff, focus_crystal, longbow, lantern |
| Greyhollow | flameblade, stormbow, longbow, elfbow, keen_blade, frostblade |
| Velmoor | iron_shield, warding_stone, mana_staff |
| Saltmere | shadowblade, shadowbow, flameblade, soulreaver, elfbow |

Greyhollow has the largest armory pool (6 items) — widest combat weapon selection in the game. Irenvale specialises in caster equipment. Saltmere carries rare items that are lair-drops only elsewhere.

**Item slot rule:** One item slot per unit. Buying a weapon replaces the current item (old item is lost). Workers, Scouts, and Farmers cannot equip melee weapons.

---

### Tab 2 — Pub (Relationship-Based Intelligence)

The pub is the game's **primary intelligence layer**. It operates on a cumulative relationship between the clan and this specific barkeep, built across multiple visits.

**The core rule:** You cannot buy trust with gold alone. Deep intel requires prior investment — multiple visits, multiple drinks, over multiple turns.

#### Relationship Score

Each town tracks a `PubRelationship` per clan:

```python
@dataclass
class PubRelationship:
    clan_id:          str
    score:            int    = 0     # 0–100
    visits:           int    = 0
    total_gold_spent: int    = 0
    last_visit_turn:  int    = 0
    pints_this_visit: int    = 0     # reset each visit
    keywords_asked:   list   = field(default_factory=list)
```

**Score gains (engine_pub.py, Sprint 36):**

| Action | visits_score gain |
|--------|-------------------|
| Each pint bought | +2 |
| Buy a round | +5 |
| Charm override (one-time) | +0.50 flat rep bonus |

Score never decays between turns (per-visit model, not per-turn).

#### Relationship Tiers

Engine thresholds (`_TIER_THRESHOLDS` in `engine_pub.py`, Sprint 36):

| visits_score | Tier | Barkeep disposition |
|---|---|---|
| 0-2 | **Stranger** | Polite but guarded. Generic only. |
| 3-9 | **Acquaintance** | Warms up after a drink. Shares gossip. |
| 10-24 | **Regular** | Glad to see you. Real intel flows. |
| 25-49 | **Trusted** | Considers you a friend. Shares confidences. |
| 50+ | **Confidant** | Complete trust. Unguarded truth. |

Score gains: buy_drink +2/pint, buy_round +5. No per-turn decay (per-visit model).
Charm override: one-time +0.50 flat rep bonus per venue.

#### Intel by Tier

**Stranger (0–19)** — generic only:
- Vague egg direction: *"Travellers from the northeast spoke of something strange"*
- Terrain negation: *"Whatever you seek, it's not in the swamp — I've been there"*
- Monster type name near this region: *"There are Wargs to the east. Nasty things."*

**Acquaintance (20–39)** — faction gossip:
- Approximate shrine counts for the leading clan
- Recent combat events: *"Ranger and Necromancer scouts clashed near the northern ruins"*
- Rights deal rumours: *"Fighter clan paid someone well for passage, they say"*
- Monster danger level near lairs

**Regular (40–64)** — real game state:
- **Exact rival shrine counts** this turn for all clans
- **Approximate rival gold** levels: *"Mage clan is flush — over 200 gold if rumours hold"*
- **Approximate rival production** rates
- **Egg terrain** confirmed: *"It rests in hills terrain, I'm fairly certain"*
- **Egg general direction** from center
- **Monster weakness** for 1–2 nearby lairs: *"Fire cracks the Goblins here. Bring a torch."*

**Trusted (65–84)** — detailed intelligence:
- **Exact rival gold** amounts
- **Rival production rate** numbers
- **Rival unit counts and types**
- **Rival research progress**: *"Mage clan hit a third-tier something recently"*
- **Alliance status**: *"Cleric and Elf shook hands last week — they're running together"*
- **Betrayal warnings**: *"Fighter took rights money from three clans. I saw their commander's eyes. Careful."*
- **Egg distance band**: *"Maybe 16–20 hexes from the centre, northeast"*

**Confidant (85–100)** — unguarded truth:
- **Egg quadrant** (NE/NW/SE/SW)
- **Egg distance ±3 hexes**: *"Northeast, 17 or 18 hexes out — a traveller drew a map"*
- **Rival Seeker positions**: *"Mage clan's Seeker was on the road two days ago, moving south"*
- **Exact rival shrine lists** (which shrines each rival has)
- **Recent betrayal details** with clan names and turn
- **Central zone monster weaknesses** (if Confidant with a near-center town)

**The pub NEVER reveals exact egg coordinates.** Seeker vision is the only way to see the Veil Hex.

#### Drink System

| Pint | Cost | Effect this visit |
|------|------|-----------------|
| 1st | 2g | Opens dialogue — T1 token line appended (vague colour) |
| 2nd | 2g | Barkeep loosens up — T2 token line appended (named intel) |
| 3rd | 2g | Barkeep gets candid — T2/T3 token line appended |
| 4th+ | 2g | Very open. 15%+ chance own clan intel leaks to gossip pool |
| Round | 8g | Buys full round (+5 visits_score). Surfaces up to 3 gossip items |

> **Engine values (Sprint 36):** `pint_cost=2`, `round_cost=8` in `engine_pub.py`.
> The design-doc costs (10/15/20/30g) were aspirational. Engine uses 2g flat.
> Relationship score (visits_score) drives tier, not drink price.
>
> **Leak mechanic (Sprint 36b):** At 3+ pints the unit risks a clan intel leak.
> `_broadcast_pub_leak_token()` in `engine_pub.py` picks a T2 token (shrine
> meditated / avatar progress), writes a gossip entry into
> `state.gossip_pools[town_id]` tagged `clan_origin` so it never reflects
> back to the leaking clan. Dialogue line drawn from `PUB_DRINK4_SLIP` pool
> with actual `{clan_name}` and `{virtue_name}` substituted.

**Effective tier this visit = min(relationship_tier, drinks_tier)**

Examples:
- Confidant relationship + 1 drink = Trusted intel (drinks limit it)
- Stranger + 4 drinks = Acquaintance intel (relationship limits it)
- Regular + 3 drinks = Regular intel (relationship already at Regular, drinks match it)

#### Keyword System (Ultima IV style)

After buying a pint, the player types one keyword. The barkeep responds in character (60 words max) drawing from the unlocked intel tier. Claude API call per keyword.

**Valid keywords and what they unlock:**

| Keyword group | Unlocks at tier |
|--------------|----------------|
| `egg`, `dragon`, `veil`, `shimmer` | Regular+ |
| `shrine`, `avatar`, `meditation` | Acquaintance+ |
| `gold`, `wealth`, `treasury` | Trusted+ |
| `production`, `building`, `queue` | Trusted+ |
| `monster`, `lair`, `beast`, `boss` | Regular+ |
| `alliance`, `deal`, `passage`, `rights` | Acquaintance+ |
| `betrayal`, `oath`, `honour`, `trust` | Trusted+ |
| `seeker`, `egg-carrier` | Confidant+ |
| `weapon`, `blade`, `staff`, `bow` | Stranger+ (armory hints) |
| `[clan name]` (e.g. "ranger", "mage") | Acquaintance+ |

If a player types a keyword above their current effective tier, the barkeep deflects in character:
*"That's not something I'd say to someone I've just met."*

#### Claude API Call Structure

```python
def build_pub_prompt(
    town_id:    str,
    relationship: PubRelationship,
    state:      GameState,
    pints:      int,
    keyword:    str,
) -> dict:
    """
    Build the Claude API messages for pub keyword dialogue.
    Context data grows with each tier.
    """
    town_data   = state.town_data[town_id]
    barkeep     = town_data["pub_personality_pool"][0]  # seed-selected at world gen
    tier        = effective_pub_tier(relationship.score, pints)
    player_id   = state.config.player_clan_id

    # Context data assembled by tier
    context = {}

    # Tier 0 (Stranger): rumor fragments only
    context["rumor_fragments"] = town_data.get("rumor_fragments", [])

    # Tier 1 (Acquaintance)+
    if tier >= 1:
        context["faction_shrine_counts"] = {
            c.clan_id: sum(1 for r in c.shrine_records.values() if r.is_meditated)
            for c in state.clans.values()
            if c.clan_id != player_id
        }
        context["recent_events"] = _summarise_recent_events(state, turns=3)

    # Tier 2 (Regular)+
    if tier >= 2:
        context["faction_gold"] = {
            c.clan_id: c.gold
            for c in state.clans.values() if c.clan_id != player_id
        }
        context["faction_production"] = {
            c.clan_id: c.production_per_turn
            for c in state.clans.values() if c.clan_id != player_id
        }
        context["faction_units"] = {
            c.clan_id: len(c.unit_ids)
            for c in state.clans.values() if c.clan_id != player_id
        }
        egg = state.dragon_egg
        context["egg_terrain"]   = egg.terrain_type
        context["egg_direction"] = egg.egg_general_direction
        context["monster_hints"] = _nearby_monster_hints(state, town_id, tier=2)

    # Tier 3 (Trusted)+
    if tier >= 3:
        context["alliances"] = [
            {"clans": [a.clan_a, a.clan_b], "turns_left": a.turns_remaining}
            for a in state.alliances.values()
        ]
        context["betrayals"]        = _recent_betrayals(state, turns=10)
        context["faction_research"] = {
            c.clan_id: c.techs_researched[-1] if c.techs_researched else "none"
            for c in state.clans.values() if c.clan_id != player_id
        }
        context["egg_distance"] = egg.egg_distance_from_center

    # Tier 4 (Confidant)+
    if tier >= 4:
        context["egg_quadrant"]      = egg.egg_quadrant          # "NE"/"NW"/"SE"/"SW"
        context["egg_distance_exact"] = egg.egg_distance_from_center
        context["seeker_locations"]  = {
            c.clan_id: _get_seeker_position(state, c.clan_id)
            for c in state.clans.values()
            if c.seeker_built and c.clan_id != player_id
        }
        context["monster_hints"] = _nearby_monster_hints(state, town_id, tier=4)

    system_prompt = (
        f"You are {barkeep}, a {town_data['pub_personality_pool'][0]} barkeep "
        f"at {town_data['name']} in Aevum. "
        f"Turn {state.turn_number}. Relationship tier: {tier}. "
        f"Never reveal exact egg coordinates. "
        f"Under 60 words. In character. "
        f"Never explicitly say intel is 'planted' vs 'true'. "
        f"Draw from context_data for the keyword: '{keyword}'."
    )

    return {
        "model": "claude-sonnet-4-6",
        "max_tokens": 100,
        "system": system_prompt,
        "messages": [{"role": "user", "content": keyword}],
        "metadata": {"context": context},
    }

def effective_pub_tier(score: int, pints: int) -> int:
    """Effective intel tier = min(relationship_tier, drinks_tier)."""
    if score < 20:   rel_t = 0
    elif score < 40: rel_t = 1
    elif score < 65: rel_t = 2
    elif score < 85: rel_t = 3
    else:            rel_t = 4
    return min(rel_t, min(pints, 4))
```

#### Planted Rumors

The Bard Spymaster can inject false intel into any village's pub knowledge base. Planted rumors appear identical to real intel at Stranger and Acquaintance tier.

At Regular+ tier, the Bard clan player gets a passive INT check per piece of intel received:
- Flag chance = `min(80%, clan.shrine_bonuses["int_stat"] * 15%)`
- Flagged intel shows: *"...seems off"* suffix
- At Confidant tier, all planted rumors are automatically flagged for Bard clan

Planted intel types:
- False rival shrine counts
- False egg direction or terrain
- False alliance status
- False gold levels

---

### Tab 3 — Healer

Restores **combat HP only**. Cannot heal exhaustion HP.

| Property | Value |
|----------|-------|
| Cost | 10g per combat HP |
| Uses per clan per town | 2 (supply runs out) |
| Heals | Combat HP only (green bar) |
| Cannot heal | Exhaustion HP (purple bar) |
| Adjacent units | All adjacent friendly units can be healed in same visit |

The 2-uses-per-clan-per-town limit means you cannot rely on a single town to keep your whole army healthy. Spread visits across multiple towns.

**Velmoor exception:** Velmoor's "Healer's Sanctum" service (Tab 3 variant) heals **exhaustion HP** at 25g per HP, max 3 uses per clan per game. This is the **only place** in the game exhaustion can be healed. If Velmoor is not one of the 4 active towns, there is NO exhaustion healing available.

---

### Tab 4 — General Store

Consumables and utility items. 3 seed-determined items. Stock is NOT shared — each clan can buy from the store independently (items are supplies, not unique equipment).

```
GENERAL STORE — IRENVALE

  Healing Potion   35g   +3 combat HP, single use, cannot cure exhaustion
  Lantern          30g   +2 VIS permanently to carrying unit
  Shrine Map       60g   Reveals all 8 active shrine locations immediately
```

Standard store pool (all towns have access to these regardless of armory pool):
- Healing Potion (35g)
- Lantern (30g)
- Shrine Map (60g)
- Spell Scroll (80–150g, T1–T4 only, T5 never available)

---

## Unique Town Services

### Irenvale — No unique service
Primary Contemplation Hall. No commission. Widest magic item armory.

### Caldspire — Virtue Restoration
Pay 150g to remove one virtue debt record from the end-game summary. Maximum 1 use per clan per game. Requires **Trusted** relationship (score 65+).

**Does NOT restore shrine bonus stats** — virtue debt stat penalties are permanent. This only affects the narrative record shown on the Victory Screen. Strategic use: clean your record before the game ends if you care about how your playthrough looks.

### Thornmere — Artisan Tools
Pay 60g to reduce a specific worker unit's next improvement build time by 1 turn (minimum 1 turn). Maximum 3 uses per clan. Useful for racing to get a mountain mine active before rivals.

### Ashfen — Oracle
Pay 80g for one yes/no question about the egg location answered truthfully. Maximum 2 uses per clan per game. Requires **Trusted** relationship. The Oracle answers from `state.dragon_egg` data directly — no pub relationship inference.

Example questions:
- "Is the egg northeast of center?" → Yes / No
- "Is the egg within 15 hexes of center?" → Yes / No
- "Is the egg in hills terrain?" → Yes / No

Two Oracle uses, combined with pub Confidant intel from another town, can narrow the egg to a 3–4 hex band before sending the Seeker in.

### Velmoor — Exhaustion Healing
25g per exhaustion HP. Max 3 uses per clan per game. The only exhaustion healing in the game.

Heavy T4/T5 casters (Shaman, Mage) can plan their route to include Velmoor for mid-game exhaustion recovery. If Velmoor is not active this game: all exhaustion must rest off naturally (+1/turn of not casting).

### Saltmere — Fence + Rumor Plant

**Fence:** Buy any item in the Den's armory pool at 40% discount. Stock rotates each visit (different from the fixed armory — Fence has seed-randomised rotating inventory). No questions asked about item provenance.

**Rumor Plant (100g, max 2 uses):** Inject one false intel fragment into a named village's pub knowledge base. Requires **Acquaintance** relationship (score 20+). The false intel appears as genuine at Stranger–Acquaintance tier. At Regular+ the Bard clan can detect it.

**Contemplation Hall (unofficial):** Shrine credits sold here have a 15% chance of being fake — a Bard Spymaster has injected misinformation. You pay, your Avatar list shows the credit, but the Avatar system may reject it at validation (implementation: 15% chance credit is flagged `is_planted=True` in `ShrineMarketEntry`, and the credit does not count toward Avatar).

---

## Contemplation Halls — Shrine Enlightenment Market

Three legitimate halls (Irenvale, Duskwall, Ashfen) plus Saltmere (unofficial).

### How to Deposit

A Diplomat or Chieftain visits the town and selects "Deposit Shrine Knowledge" (available under any tab, no visit cost). Gold received immediately at sell price.

```python
def deposit_shrine_knowledge(
    unit:       UnitInstance,
    shrine_id:  str,
    town_id:    str,
    state:      GameState,
) -> int:
    """
    Register shrine knowledge with a Contemplation Hall.
    Returns gold earned. 0 if clan has not meditated this shrine.
    """
    clan = state.clans[unit.clan_id]
    record = clan.shrine_records.get(shrine_id)
    if not record or not record.is_meditated:
        return 0   # cannot sell what you haven't earned

    town = state.towns[town_id]
    if not town.contemplation_hall:
        return 0

    market = state.shrine_market.setdefault(
        shrine_id,
        ShrineMarketEntry(shrine_id=shrine_id)
    )

    if unit.clan_id in market.contributions:
        return 0   # already deposited by this clan

    market.contributions.append(unit.clan_id)
    _update_market_prices(market)

    sell_price = market.current_sell_price
    commission = int(sell_price * (town.contemplation_hall.get('commission_pct', 0) / 100))
    net        = sell_price - commission

    clan.gold = min(clan.gold + net, clan.gold_cap)
    return net

def _update_market_prices(market: ShrineMarketEntry) -> None:
    """Update buy/sell prices based on number of contributors."""
    n = len(market.contributions)
    if n == 1:
        market.current_buy_price  = 400
        market.current_sell_price = 200
    elif n == 2:
        market.current_buy_price  = 300
        market.current_sell_price = 150
    elif n == 3:
        market.current_buy_price  = 200
        market.current_sell_price = 100
    else:
        market.current_buy_price  = 120
        market.current_sell_price = 60
    market.available = True
```

### How to Purchase

Any visiting unit can purchase shrine credit from the hall. Gold deducted. Avatar list updated. **No stat bonus** — credit only.

```python
def purchase_shrine_credit(
    unit:      UnitInstance,
    shrine_id: str,
    town_id:   str,
    state:     GameState,
) -> bool:
    """Purchase Avatar credit for a shrine. Returns True on success."""
    clan   = state.clans[unit.clan_id]
    market = state.shrine_market.get(shrine_id)

    if not market or not market.available:
        return False
    if clan.gold < market.current_buy_price:
        return False

    # Saltmere: 15% fake check
    town = state.towns[town_id]
    hall = town.get('contemplation_hall', {})
    if hall.get('fake_credit_chance', 0) > 0:
        import random
        if random.random() < hall['fake_credit_chance']:
            # Fake credit — deduct gold, no Avatar progress
            clan.gold -= market.current_buy_price
            state.log_event("shrine_credit_fake", clan.clan_id, shrine_id)
            return False   # player doesn't know it failed (no feedback)

    clan.gold -= market.current_buy_price

    # Grant Avatar credit (no stat bonus)
    record = clan.shrine_records.setdefault(
        shrine_id, ShrineRecord(shrine_id=shrine_id)
    )
    record.has_credit      = True
    record.credit_purchased = True
    # is_meditated remains False — this is credit only
    # Avatar check: if all 8 shrines have either is_meditated OR has_credit
    _check_avatar_status(clan, state)
    return True
```

---

## GameState Fields for Town System

```python
@dataclass
class TownInstance:
    town_id:          str
    name:             str
    q:                int
    r:                int
    theme:            str
    relationships:    dict[str, PubRelationship]   # clan_id -> relationship
    armory_stock:     list[str]                    # item_ids remaining
    armory_sold_to:   dict[str, tuple[str, int]]   # item_id -> (clan_id, turn)
    store_stock:      list[str]                    # always refreshes? no — 3 fixed
    healer_uses:      dict[str, int]               # clan_id -> uses remaining
    special_uses:     dict[str, dict[str, int]]    # service_id -> {clan_id: uses}
    contemplation_hall: Optional[dict]             # None if no hall
    barkeep_name:     str                          # seed-generated
    barkeep_personality: str                       # from pub_personality_pool

@dataclass
class ShrineMarketEntry:
    shrine_id:         str
    contributions:     list[str]   # clan_ids that deposited
    current_buy_price: int         # 400/300/200/120
    current_sell_price: int        # 200/150/100/60
    available:         bool        # True if at least 1 contribution
    is_planted:        bool        # True if Saltmere has injected fake
```

---

---

## Sacred Space — No Combat Near Towns or Castles  (T103)

Units within **2 hexes** of any town or castle hex cannot initiate or receive combat.

| Structure | Sacred radius | Effect |
|-----------|---------------|--------|
| Shrine | 2 hexes | Original (LOCKED #35) — meditation zone |
| Town | 2 hexes | Civilian sanctuary — no combat (T103) |
| Castle | 2 hexes | Diplomatic sanctuary — no combat (T103) |

**Strategic implications:**
- Town approaches are safe meeting grounds — rivals can visit the same town without combat
- Clans can use town proximity as a fallback position but cannot camp armies there
- Castle gates are neutral territory — diplomacy can be proposed without fear
- The sacred radius is checked in `movement_engine.is_in_sacred_ground()` (extends shrine check)

---

## Item Tier Framework  (T103)

| Tier | Source | Stat bonus | Price range | Gate |
|------|--------|-----------|-------------|------|
| **+1** | Town shops | +1 to one stat | 30–60g | None |
| **+2** | Castle armoury | +2 to one stat | 110–170g | Own matching +1 |
| **+3+** | Lair bosses, map drops | +3 or better | Not purchasable | Defeat or find |

### Town +1 Items (seed-selected 3–4 per town)

| Item | Stat | Price |
|------|------|-------|
| Short Sword | +1 ATK | 55g |
| Buckler | +1 DEF | 45g |
| Swift Boots | +1 MOV | 60g |
| Lantern | +1 VIS (torch radius 4) | 30g |
| Traveller's Cloak | +1 DEF | 40g |
| Iron Cap | +1 HP_max | 50g |

### Castle +2 Items (full pool, needs +1 prerequisite)

| Item | Stat | Price | Prerequisite |
|------|------|-------|--------------|
| Knight's Blade | +2 ATK | 150g | Short Sword or Keen Blade |
| Tower Shield | +2 DEF | 140g | Buckler, Iron Shield, or Cloak |
| Windrunner Boots | +2 MOV | 170g | Swift Boots |
| Enhanced Lantern | +2 VIS (torch radius 5) | 110g | Lantern |
| Plate Helm | +2 HP_max | 130g | Iron Cap |

The **prerequisite is a clan check**, not a unit check. If *any* alive unit in the clan carries the +1 item, the +2 is unlocked for purchase. The +1 item is **not consumed or replaced** — both coexist.

---

## Inn Service  (T103)

Available at both towns (Innkeeper) and castles (Barracks Captain).

| Option | Cost | Effect |
|--------|------|--------|
| Rest 1 turn | 20g | Unit rests 1 world turn. Heals 50% of missing combat HP. |
| Rest 2 turns | 35g | Unit rests 2 world turns. Heals 50% per turn (total: ~75% effective). |

**While resting:** unit flag `unit.resting = True`. Cannot move or receive orders. Enemies cannot attack into sacred space anyway (town proximity).

**Inn rest tick:** Called by `end_of_turn_cleanup()` each turn. Processes `rest_turns_left`, heals, clears flag on completion. Both towns and castles share the same tick via `engine_town.inn_rest_tick()`.

**Heal formula:** `floor((hp_max - hp_combat) × 0.50)` per rest turn, minimum 1 if injured.

---

## Notice Board — T1 Information Tokens  (T103)

**Every town** has a notice board. Cost is 1 local action.

| Token | Price | Intel type | Confidence | Content |
|-------|-------|-----------|------------|---------|
| Shrine Direction | 50g | shrine_direction | 0.60 | Cardinal direction (N/NE/SE/S/SW/NW) to nearest unmeditated shrine |
| Monster Rumour | 30g | unit_spotted | 0.50 | Approximate hex of nearest active enclave |
| Mantra Fragment | 80g | mantra_fragment | 0.40 | Partial mantra hint for one shrine this clan has no data on |

**Information Exchange Engine:**

The notice board visitor log feeds into `town.intel_exchange_wealth`, computed each turn:

| Unique clans visited (last 20 turns) | intel_exchange_wealth | Pub bonus |
|--------------------------------------|-----------------------|-----------|
| 0–1 | 0 | None |
| 2–3 | 2 | +1 effective pub tier |
| 4+ | 4 | +2 effective pub tier |

This means **towns grow richer intel sources over time** as more clans pass through. By mid-game, a busy town pub may answer Regular keywords at Acquaintance relationship — because travellers have brought in news from across the map.

**Castle pubs do NOT benefit from intel_exchange_wealth.** Castles have fewer travelling merchants and see less information diversity. Early game: equal. Late game: towns are better intel.

---

## Castle Services  (T103)

Castles offer 5 services plus the T3 diplomacy broker:

### 1 — Steward's Hall (Castle Pub)

| Property | Value |
|----------|-------|
| Relationship | Per-castle (separate from any town relationship) |
| Tiers | Same 5 tiers: Stranger → Confidant |
| Pints / keywords | Identical to town pub |
| Intel wealth bonus | **None** — castles don't accumulate traveller intel |
| Late-game quality | Below town pubs with active visitor traffic |

### 2 — Castle Armoury (+2 items)

Stock: full +2 pool (5 items). Shared across clans — first come first served.
Gate: `engine_castle._clan_owns_prereq()` checks all alive units for prerequisite.

### 3 — Barracks (Castle Inn)

Identical to town inn. 20g (1 turn) / 35g (2 turns). Same heal formula.
Unit rest processed by `engine_town.inn_rest_tick()` each turn end.

### 4 — Chapel (Exhaustion Heal)

| Property | Value |
|----------|-------|
| Heals | Exhaustion HP only (purple bar) |
| Cost | 40g per HP |
| Max uses | 2 per clan per castle |
| Comparison | Velmoor = 25g/HP, 3/game — cheaper but only one town |

Castle chapels cost more than Velmoor but exist at every castle. If Velmoor is not active this game, castle chapels are the only exhaustion healing available.

### 5 — Scriptorium (T2 Information Tokens)

| Token | Price | Intel type | Confidence |
|-------|-------|-----------|------------|
| Shrine Location | 150g | shrine_direction | 0.90 (exact hex) |
| Mantra Teaching | 200g | mantra_known | 0.70 |
| Monster Weakness | 120g | weakness_known | 0.85 |
| Clan Movement Report | 100g | combat_specific | 0.65 |

Scriptorium tokens are T2 intel — significantly more accurate than town notice board (T1). The shrine_location token reveals the **exact hex** of the nearest unmeditated shrine (`extra.exact = True`).

### 6 — Government Broker (T3 Diplomacy)

Existing system. See §17 in AEVUM_GAME_REFERENCE.md.

---

## Town vs Castle Intel Comparison

| Feature | Town Pub | Castle Pub |
|---------|----------|------------|
| Tier system | 0–4 (Stranger–Confidant) | 0–4 (Stranger–Confidant) |
| Early game intel | Equal | Equal |
| Late game intel | Grows via info exchange (+1/+2 tier bonus) | Stays at base tier |
| Notice board | T1 tokens (50–80g) | — |
| Scriptorium | — | T2 tokens (100–200g) |
| Relationship scope | Per-town | Per-castle |
| Relationship decay | −1/turn if unvisited 10+ turns | Same |

---

## Town Relationship — Investment Payoff Table

| Visits | Typical score | Tier reached | Best intel available |
|--------|--------------|--------------|---------------------|
| 1 visit, 1 pint | 2 | Stranger | Generic rumour |
| 2 visits, 2 pints each | 8 | Acquaintance (3+) | First gossip unlocked |
| 3 visits, 2 pints each | 12 | Regular (10+) | Exact shrine counts, egg terrain |
| 5 visits, mix of rounds | 25+ | Trusted | Rival gold/production, betrayal warnings |
| 7-8 visits with rounds | 50+ | Confidant | Egg quadrant, Seeker positions |

**Clans that invest in a town by turn 8:** Have Regular tier by turn 16 — right when the shrine wars demand tactical intel. The payoff window aligns with game pacing.

**Clans that wait until turn 20:** Still stuck at Acquaintance when they need Confidant. No shortcut. The relationship must be built.