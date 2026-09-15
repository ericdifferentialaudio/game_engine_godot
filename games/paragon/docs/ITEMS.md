# Items — Gear, Goods, Key Items, and Magic Items

(New system per `DESIGN_REVIEW_2026-09.md §3`. Data lives in `data/items/*.json`;
names are pooled per seed (`NAMING_AND_LORE.md`); effects are fixed by ID.)

Related: `GAME_DESIGN.md §8, §10`, `CRITICAL_PATH.md §5`, `PROCEDURAL_GENERATION.md §2` (stages 7, 8, 10),
`REGRESSION.md §3.9`, `CLANS.md`.

## 0. The gold loop

```
monsters (kills, chests) · selling loot · quest rewards · bets
        └─► GOLD ─► food (recurring, every night)        ~15–25 % of income, Act I–II
                 ─► reagents (magic is consumable)       ~20–30 %
                 ─► gear (the only route to better arms) ~40–50 %, in steps
                 ─► moral sinks (ransom, restitution, donation, the Court's debt, the Isle)  — the player's choice
```
Encounter gold per kill scales with the *region's* danger, not the player's level; a wandering-monster fight
in Act I yields 3–12 gold, a dungeon level-6 room 40–120. Party of four eats 8–20 gold a night depending on
where it shops. **A player who never fights can still eat** — by selling trade goods, Ledger quests, or
begging (a Humility scenario) — but slowly. Tuning lives in `data/items/prices.json` and `data/encounters/`.

## 1. Principles

1. **Gold is the gear currency.** Better weapons and armour are bought, not found; found gear is mostly
   sellable loot. This gives gold a reason to exist and every Ledger quest a real temptation.
2. **Where you buy decides what you can buy.** Villages < towns < castles. Distance and access are the
   progression, not level.
3. **Magic items are intel.** Each is a per-seed unique; *where it is* is a token in the knowledge graph
   with ≥2 sources. Some sit at dungeon bottoms beside the stone.
4. **Key items gate the acts** (`CRITICAL_PATH.md §1`). They are never sold, never lost, never random.
5. **No item raises a virtue.** Items may *test* virtue (the Temptation, gilded armour, consecrated arms).

## 2. Categories (`type`)

| Type | Examples (effect IDs; names pooled) | Bought | Found | Notes |
|---|---|---|---|---|
| `weapon` | `wpn.dagger`, `wpn.sword`, `wpn.bow`, `wpn.halberd`, `wpn.staff` | yes | rarely | class restrictions; ranged vs melee |
| `armor` | `arm.cloth`, `arm.leather`, `arm.chain`, `arm.plate`, `arm.shield` | yes | rarely | class restrictions; `gilded` variants exist |
| `tool` | torch, rope, lockpicks (Tinker), sextant, spyglass, fishing line | yes | yes | enable actions |
| `ration` | one night's food for one member; consumed only at camp. Going without: Weary → Starving (MaxHP loss) → Famished → unconscious, never dead; **never gates**. Village 2g / town 5g / castle 8g. **Can be given** to the hungry (`gave_ration`; `gave_last_ration` if it was the last) | yes (villages cheapest) | camp loot; Ranger forage | `DESIGN_REVIEW §11.1` |
| `light` | torch, lantern, oil | yes | yes | dungeons dark by default |
| `reagent` | 8 reagents; 2 wild-only at moon phases | yes (reagent seller) | wild | `GAME_DESIGN.md §9` |
| `consumable` | potions, antidotes, scrolls (single-cast spells) | yes (healer/reagent seller) | chests | |
| `trade_good` | pelts, ore, cloth, salt | no (sell only) | loot/quests | price varies by town; Bard bonus |
| `magic` | §5 | never | yes | unique per seed |
| `key` | §4 | never | scripted | never lost |

## 3. Tiers and sellers

| Tier | Where sold | Weapon/armor examples | Price band (gold) | Also stocks |
|---|---|---|---|---|
| **1 village** | `{village.*}` goods-seller, `{village.market}` | dagger, club, sling; cloth, leather | 5–60 | rations (cheap), torches, rope |
| **2 town** | weaponsmith + armorer in each `{town:slot.*}` | sword, axe, bow; chain, shield | 60–600 | rations (dearer), tools, reagents (reagent seller), consumables (healer) |
| **3 castle** | armoury in `{castle.royal}` and `{castle:f1..f3}` | halberd, greatsword, crossbow; plate | 600–4000 | tier 1–2 as well; **gilded** armour (Humility test) |
| — clan hall | 12 halls (`CLANS.md §5`) | one clan-signature item each | clan standing, not gold | |

- **Sell price = 50% of buy price at the seller's tier**, ±town modifier ±Bard/market twists (`Prices.gd`).
  Never ≥ buy price (REG-ECO-02).
- **Tier availability is strict**: a tier-1 seller never stocks tier-2/3 (REG-ITM-01). Castles stock all.
- **Blind vendor** (anchor-virtue honesty test) exists in the anchor town and may be placed elsewhere.
- Prices are data (`data/items/prices.json`); no magic numbers in code (`RULES.md §2.3`).

### 3.1 The item list (launch; effect IDs — names pooled per seed)

**Weapons** (`atk` = damage die bonus; `rng` = ranged range in cells; class restrictions per `class_allow`)

| ID | Tier | Price | atk | Notes |
|---|---|---|---|---|
| `wpn.staff` | 1 | 8 | +1 | all classes; Mage/Druid starter |
| `wpn.dagger` | 1 | 10 | +1 | all; thrown once (rng 3) |
| `wpn.sling` | 1 | 12 | +1 | rng 5; needs no ammo |
| `wpn.club` | 1 | 6 | +2 | Fighter/Shepherd/Tinker; **subdue-only** option: non-lethal by default |
| `wpn.spear` | 1 | 25 | +2 | reach 2; Ranger/Fighter/Paladin |
| `wpn.hand_axe` | 2 | 60 | +3 | Fighter/Ranger/Tinker |
| `wpn.sword` | 2 | 120 | +4 | Fighter/Paladin/Bard/Ranger |
| `wpn.mace` | 2 | 90 | +3 | Paladin/Shepherd; +1 vs undead |
| `wpn.bow` | 2 | 150 | +3 | rng 7; Ranger/Bard/Druid; arrows (bundle 20 = 10g) |
| `wpn.quarterstaff_iron` | 2 | 110 | +3 | Mage/Druid; casting focus (−1 reagent per 5 casts) |
| `wpn.crossbow` | 3 | 600 | +5 | rng 6, reload turn; Fighter/Tinker |
| `wpn.greatsword` | 3 | 900 | +6 | two-handed; Fighter/Paladin |
| `wpn.halberd` | 3 | 1200 | +6 | reach 2; Fighter/Paladin |
| `wpn.longbow` | 3 | 1400 | +5 | rng 9; Ranger only |

**Armour** (`def` = damage reduction; `stl` = stealth/ambush penalty; Mage/Druid cap at leather)

| ID | Tier | Price | def | Notes |
|---|---|---|---|---|
| `arm.cloth` | 1 | 5 | 1 | all |
| `arm.leather` | 1 | 40 | 2 | all |
| `arm.buckler` | 1 | 20 | +1 | off-hand; not with two-handed |
| `arm.studded` | 2 | 150 | 3 | not Mage/Druid |
| `arm.chain` | 2 | 400 | 4 | stl −1 |
| `arm.shield` | 2 | 120 | +2 | off-hand |
| `arm.scale` | 3 | 1200 | 5 | stl −1 |
| `arm.plate` | 3 | 3000 | 6 | stl −2; Fighter/Paladin |
| `arm.tower_shield` | 3 | 700 | +3 | Fighter/Paladin; stl −1 |
| `arm.gilded_plate` | 3 | 4000 | 6 | as plate; **meditating in it costs Humility** (§5) |

**Tools & light** — `tool.torch` 1g (60 min) · `tool.lantern` 40g + `tool.oil` 5g (240 min) · `tool.rope` 8g ·
`tool.lockpicks` 30g (Tinker) · `tool.sextant` 200g (castle; reads coordinates) · `tool.spyglass` 80g ·
`tool.fishing_line` 6g (one ration per hour at water, 30 %) · `tool.shovel` 15g (buried caches) ·
`tool.bedroll` 25g (+10 % camp heal) · `tool.whetstone` 10g (+1 atk next battle).

**Reagents** (`rea.1..8`, names pooled; 2–12g each at reagent sellers; `rea.7`/`rea.8` **wild-only**, found at
specific moon phases in specific biomes — locations are intel). Spells consume 1–3 reagents (`GAME_DESIGN.md §9`).

**Consumables** — `con.potion_heal` 25g · `con.potion_cure` 20g · `con.antidote` 15g · `con.elixir_mp` 40g ·
`con.scroll_<spell>` 60–300g (single cast, castle/healer) · `con.smelling_salts` 30g (revives an unconscious
member, incl. hunger) · `con.hardtack` 12g (a ration that never spoils; counts as a ration; tier 2+).

**Trade goods** (sell-only; price varies by town ±40 %) — pelts, ore, salt, cloth, spice, amber, dye, timber.
A Bard sells at +15 %.

## 4. Key items (`key`) — the act chain

| Key | Count | Where | Gate it serves |
|---|---|---|---|
| **Stone** | 8 | bottom (level 8) of each vice dungeon; **takeable only when all 8 virtues are granted** | Ring bindings |
| **Sigil** | 8 | one per virtue town (the sigil-hider role) | Ring bindings |
| **Sigil Ring** | 1 | given by `{ruler}` when the first stone is shown | binds stone + sigil at each altar room |
| **Horn** | 1 | one of the set pieces (seeded among Bell in the Deep / Silent Monastery / Maelstrom) | needed to enter the Descent |
| **Warding item** | 1 | the ruined city (Act III) | passes Humility's guardians |
| **House artifacts** | 3 | behind the family trials in `{castle:f1..f3}` | Descent |
| **Word of Passage** | 3 syllables (tokens, not items) | three keepers, one per House region | Threshold |
| **Binding Word** (codex answer) | token | three roads of three kinds — the Dead (ghosts), the Silent (ninth plinth), the Still (Anchorite); false variant sold at the Drowned Court (`QUEST_TREE.md §4`) | the Chamber |
| **The Temptation** | 1 | findable from Act II (seeded) | Wisdom test: use / carry / destroy at L8 |

Key items are flagged `key: true`: cannot be sold, dropped, given, or stolen; `RunStats.key_items.<id>` records
the day found (REG-ITM-06).

## 5. Magic items (`magic`)

Per seed the generator instantiates **8–12 uniques** from a template pool (`data/items/magic_pool.json`,
**28 templates** below at launch). Each has a fixed effect ID and a pooled name. Every magic item has a
*moral edge* as well as a mechanical one — the notes column says what it tests.

| Template (effect) | Where placed (stage 7/8) | Notes |
|---|---|---|
| `mag.blade_of_light` — lights dungeons, +dmg vs undead | dungeon bottom | placed beside a stone in 2–3 dungeons |
| `mag.cloak_of_stillness` — no camp ambush | set piece or hidden cache | |
| `mag.truthstone` — glows when an NPC lies | Silent Monastery / market | changes the honesty game; Open-mindedness scenario |
| `mag.wayfinder` — shows moon-gate destination once per day | minor site | moon table shortcut |
| `mag.satchel_of_grain` — one free ration per night | village quest | Kindness scenario (share it?) |
| `mag.mirror_shard` — reveals the Mirror's vice name at L5 | ruined city ghosts | |
| `mag.consecrated_arms` — best weapon in game | castle vault | Humility scenario: *refusing* it is logged |
| `mag.gilded_plate` — best armour; meditating in it costs Humility | castle armoury (buyable, tier 3) | |
| `mag.seer_glass` — one extra Seer reading anywhere | Seer's gift after Act III | |
| `mag.bell_tongue` — calms the sea for one voyage | Bell in the Deep | |
| `mag.ever_loaf` — feeds the whole party one night, once per 3 days | hidden cache / Heart quest | the hunger system's one relief; giving it away is a Selflessness scenario |
| `mag.hollow_purse` — halves prices at one seller per town, once | market twist / Ledger quest | Integrity scenario: the seller does not notice |
| `mag.reagent_pouch` — 1 in 4 casts costs no reagents | dungeon bottom | Mage/Druid; Self-discipline: spell spam still logged |
| `mag.ember_blade` — fire damage; lights the cell around the wielder | dungeon bottom | melee; burns webs/doors |
| `mag.warden_shield` — off-hand; blocks one hit per battle | House vault | Paladin/Fighter |
| `mag.quiet_boots` — no camp ambush in dungeons; stl +2 | minor site (forgotten tower) | Ranger/Tinker/Bard |
| `mag.lantern_of_the_ford` — reveals hidden doors & caches within 3 cells | Mirror Ford figure (companion arc reward) | replaces torch; never burns out |
| `mag.ring_of_tongues` — one extra keyword chip per NPC (their secret topic) | Wind-Ship / conjunction site | Open-mindedness flavour |
| `mag.tidewater_flask` — cures poison & disease, refills at any shrine | healer quest | Compassion scenario: the plague house |
| `mag.oathstone` — a companion who would leave stays one more day | companion arc | Loyalty; using it twice on the same companion is logged |
| `mag.moon_dial` — shows both moons' phases & next conjunction | castle library | halves moon-table learning |
| `mag.penitent_chain` — worn: +2 def, −1 initiative; NPCs treat you as a penitent | Debtor's Isle | Humility scenario; Assize testimony bonus |
| `mag.hunter_horn` — summons one wandering-monster fight on demand | ranger clan hall | for gold; Courage/Kindness: hunting non-evil beasts logged |
| `mag.salt_of_binding` — one use: a fled enemy cannot be pursued (they are gone) | Corsair captain (spared) | Forgiveness flavour |
| `mag.grey_cloak` — enemies with morale < 50 % will not attack the wearer | Silent Monastery | Compassion/Courage tension: stand in front of a companion |
| `mag.almoner_bowl` — gold given to beggars is not deducted 1 time in 3 | Selflessness companion arc | tests whether giving changes when it is cheap (logged) |

Rules: every magic item has **≥1 location token** (`category: magic_item_location`) with ≥2 sources
(REG-ITM-04); none is required for the win; ≥2 must sit at dungeon bottoms (REG-DNG-08); each may be
**used**, and some **destroyed**. (The Temptation is a key item, not a magic item, because it gates Wisdom.)

## 6. Dungeon temptation floors

Each vice dungeon has **three authored temptation floors** (module-defined) among its eight levels; the rest
are generated. Each floor offers the vice as an item or gold choice, logged either way:

| Vice | Floor bait | `taken` effect |
|---|---|---|
| Avarice | chests of gold beside a starving prisoner | Selflessness −; `avarice_bait_taken` |
| Cowardice | an exit ladder on every temptation floor | Courage −; counts as `temptation_floors.taken` |
| Duplicity | a forged pass that skips a guard puzzle | Integrity − |
| Cruelty | a caged creature; free it or leave it | Kindness − if left |
| Contempt | a defaced altar; bow or mock | Respect − |
| Corruption | a bribe to skip a trial room | Justice − |
| Callousness | a wounded scout begging for a potion | Compassion − |
| Pride | gilded arms on a pedestal | Humility − |

The stone is on level 8 behind the third temptation floor. Resisting writes an event too (weight per module).

## 7. Data schema (`data/items/*.json`)

```
Item {
  id: "wpn.sword", type: weapon|armor|tool|ration|light|reagent|consumable|trade_good|magic|key,
  tier: 1|2|3|null, base_price: int, sell_ratio: 0.5,
  class_allow: [class ids] | "all", stats: { atk, def, range, weight }, effect_id: "spell.heal"|null,
  key: bool, unique: bool, name_pool: "weapons.sword" (per-seed name),
  virtue_hooks: [ { on: "equip|use|refuse|meditate_wearing|take", action_id: "took_gilded_arms" } ]
}
Seller { location_archetype, tier_max, stock_rules, price_modifier }
```
Validated by `validate_data.py`: tier ≤ seller `tier_max`; every `virtue_hooks.action_id` exists in a module
action table; every `magic` item has a `magic_item_location` token slot in `token_graph.json`.

## 8. Telemetry

All item flows write to `RunStats.items` (`REGRESSION.md §3.9`): bought by tier and type, found by source,
sold, given, dropped, stolen (hidden), magic items known/found/used/destroyed, key-item days, max equipped
tier. Tests: REG-ECO-01/02, REG-ITM-01..06, REG-DNG-06/08.

