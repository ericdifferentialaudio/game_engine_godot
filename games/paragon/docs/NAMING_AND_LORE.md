# Naming & Lore — Original IP via Randomized Name Pools

**Working title (fixed, original): "Paragon"** — pending trademark check (`DEVELOPMENT_TASKS.md` P0-T0).
The game lives at `game_engine_godot/games/paragon/`; the legacy `UIV` code-name folder was retired (P7-T6 done).

## 1. Principle

The game contains **zero** proper nouns, mantras, spell names, item names, or text from Ultima IV.
Mechanics and structure (8 virtues per run, hidden karma, keyword intel, dual moons, reagent magic)
are design ideas and are retained. Every *name* is drawn at world-generation time from **name pools**, so
each seed produces a unique world. Names are data; all content references **IDs**.

## 2. Archetypes (fixed identities, variable names)

| Archetype ID | Role | Notes |
|---|---|---|
| `world` | The continent / realm | |
| `ruler` | Benevolent monarch who summons the player; heals, levels, gives council | Title/gender pooled |
| `seer` | Blind oracle giving diegetic virtue readouts in bands | |
| `player_title` | In-world title earned at full enlightenment | |
| `artifact_end` | Final object of wisdom; the player *acts* on it (weave / strike / sound) | Verb travels with the name |
| `final_word` | The **Binding Word**: label of this seed's **binding principle** — one of twelve in `data/codex/principles.json`, chosen at generation stage 1c by affinity to the drawn eight; label from the principle's pool in the seed's flavour (`QUEST_TREE.md §4.0`) | Meaning taught only via eight virtue-lines; the inspiration's answer and synonyms banned |
| `anchorite` | The Still: hermit past the Mirror Ford who gives the Word after three silent days | Name pooled; speaks twice |
| `end_dungeon` | The final descent | |
| `moon_gate`, `moon_dest` | One moon selects the open gate, the other the destination | |
| `gate` | The teleport structures | |
| `family.*` | The 8 virtue families (`VIRTUES.md §2`); castles are keyed to families | Names pooled |
| `virtue.<id>` / `slot.1..8` | 8 virtues drawn per seed from 15 (`VIRTUES.md §4`); slot.8 is always Humility | Display name from the virtue's synonym pool |
| `mantra.slot.N` | Generated syllables | Generated (§5) |
| `town.slot.N` | One per drawn virtue; `town.slot.8` is always the ruined city | |
| `castle.f1..f3` | Three "Houses" for the three most-represented families in the seed; each holds an artifact | |
| `village.*` | Incl. `village.market` (the moral market) | |
| `dungeon.slot.N` | One per drawn virtue's vice; each holds a stone-equivalent; slot.8's links to the end dungeon | |
| `companion.slot.N` | One per drawn virtue; archetype/arc fixed per *virtue*, name pooled | |
| `artifact.f1..f3` | Used at the end-dungeon entrance | |
| `sigil_ring` | The 8-part key assembled from the 8 shrines (replaces the three-part key) | |
| `temptation` | Evil item: using it costs all virtues; destroying it grants a boon | |
| `sigil_term`, `stone_term` | Nouns for the rune- and stone-equivalents | |
| `clan.*` | 12 clans (`CLANS.md`); names pooled, mechanics fixed | |

## 3. Virtue Identity vs. Display Name

Virtue *meanings*, vices, companion archetypes, and action tables are fixed per virtue ID
(`VIRTUES.md §3`). Only the **display label** is pooled: each virtue has a synonym pool per flavor, e.g.
`integrity` → Candor / Plainspeech / Veritas / Trueheart / Oathfast. Dialogue is written against the virtue
ID via `{virtue:slot.N}` and reads correctly whatever label the seed drew. Wisdom's label is also pooled
(Discernment / Rede / Sapience …) but is spoken only by the `{seer}` and in the end dungeon.

## 4. Pools (`data/names/<category>.json`)

```json
{ "category": "town", "min_pool": 40,
  "entries": [ { "name": "Glassmere", "flavor": "neutral", "tags": ["coastal"] },
               { "name": "Skaldholm", "flavor": "norse",   "tags": ["cold", "harbor"] } ] }
```
- **Flavors:** `norse`, `celtic`, `latin`, `neutral`. A seed picks 1 primary + optional secondary flavor
  (secondary used for a "border region" — itself a lore hook).
- **Tags** match names to biome/role (coastal, cold, forest, ruined, market…).
- **Minimum pool size = 5× the required count** (towns 40, companions 40, dungeons 35, villages 25…).
- **Banlist:** real-world places, all Ultima terms, profanity — enforced by `tools/validate_data.py`.

### 4.1 Initial pool content (three seed sets; the generator mixes freely within flavor rules)

| Category | Set A (neutral) | Set B (norse) | Set C (celtic / latin) |
|---|---|---|---|
| world | Aldermere | Skerrymoor | Cael Ambrin |
| ruler | Queen Ysolde the Lantern-Bearer | King Halvard the Anvil | the Archon Mirabel |
| seer | Orrin Gray-Eye, the Reckoner | Old Sunniva, the Tide-Reader | Brother Ansel, the Weigher |
| player_title | the Exemplar | the Warden | the Paragon |
| artifact_end | the Loom of Accord (weave) | the Anvil of Truths (strike) | the Concord Bell (sound) |
| final_word | Wholeness | Balance | Unity |
| end_dungeon | the Hollow Under Ash | the Drowning Deep | the Undercroft of Thorns |
| moons | Sael / Vorn | Ymir / Skade | Lumen / Umbra |
| gate | Tidewells | Stormdoors | Wardstones |
| family labels (Truth, Care, Fortitude…) | Clarity, Kindness, Nerve, … | Truth-of-Iron, Warmth, Grit, … | Light, Grace, Steadfastness, … |
| virtue synonyms (examples) | integrity→Candor, compassion→Mercy, courage→Resolve, justice→Equity, selflessness→Gift, loyalty→Fidelity, reverence→Communion, humility→Lowliness | Plainspeech, Kindness, Boldness, Fair-Hand, Giving, Oath, Stillness, Meekness | Veritas, Caritas, Fortitude, Aequitas, Oblation, Fealty, Devotion, Modesty |
| wisdom label | Discernment | Rede | Sapience |
| towns | Glassmere, Kingsreach, Ironhame, Oakhollow, Cinderforge, Whitegate, Fenwick, Sunder | Gullwick, Harrowgate, Skaldholm, Thornby, Coalreach, Brightwater, Mistmere, Wrackhaven | Clairvale, Ambercourt, Stormhold, Elderbough, Kilnmoor, Lindenmere, Hollowfen, Vanithe |
| castles (Houses of families) | Archive of Still Water, Almshouse of Thorn, Bastion Grey | the Rune Library, the Hearth-Hall, Ironwatch | the Scriptorium, the Hospice of Roses, the Bastion Vigilant |
| villages | Lantern Reach, Chaffway, Saltmarrow, the Drowned Court | Netherquay, Sparrowmoor, Saltcask, the Wreckers' Moot | Dovehaven, Thistlecroft, Ashbury, the Tithe-Market |
| dungeons | Guile, Spite, Craven, Twist, Hoard, Stain, the Root | Falsehold, Rancor, Flinch, Crooked, Grasp, Blight, the Wyrmroot | Perfidy, Malice, Timor, Iniquity, Avarice, Disgrace, the Deep Sanctum |
| companions | Bram, Sefa, Halloran, Wren, Idris, Tamsin, Corvin, Maud | Eirik, Solveig, Torvald, Hilde, Runa, Bjorn, Astrid, Kell | Lucan, Rhoswen, Emeric, Ceridwen, Isolde, Gwydion, Anwen, Tobias |
| artifacts p1–p3 | Chime / Ledger / Lamp | Horn / Runestone / Brazier | Censer / Psalter / Lantern |
| temptation | Crown of Vael | the Drowned Crown | the Gilded Mask |
| sigil / stone terms | sigils / eyes | marks / tears | seals / embers |

Reagents, spells, non-generic monsters, and clan names get their own pools (task P1-T9). Pools must be
expanded to their `min_pool` before Milestone M4.

## 5. Mantra / Password Generation

Patterns `CV`, `CVC`, `VC`, `CVCV` (e.g. VEL, ISH, TOR, NAE, OUM, KETH, SIRA, HUL). Rules: 3–5 letters,
pronounceable, unique per seed, not in the word banlist, ≥2 letters different from every other mantra in
the seed. Passwords and the three-part Word of Passage are generated similarly (2–3 syllables).

## 6. Templating in Text

All authored text uses tokens resolved at runtime by `core/naming/NameResolver.gd`:

```
"{ruler} bids thee seek the shrine of {virtue:slot.2} beyond {town:slot.2}."
"{companion:loyalty} swore an oath at {castle:f1}; {they:companion:loyalty} have not forgotten."
```
Virtue-specific dialogue addresses the virtue by **ID** (`{companion:loyalty}`) and only exists in a seed
where that virtue was drawn; slot-generic dialogue uses `{…:slot.N}`.

Helpers: `{a:…}`, `{cap:…}`, `{plural:…}`, pronoun forms `{they:…} {them:…} {their:…}`.
Rule: **no hard-coded proper nouns in `data/dialogue/`**; the validator flags capitalized words not in the
common-word allowlist unless they are template tokens.

## 7. Lore Archetypes (fixed story beats, variable dressing)

- **The Summoning:** the player crosses from a mundane world through a gate at dual-moon conjunction.
- **The Ruler's Charge:** an age of peace needs an exemplar, not a hero; the ruler names *this realm's*
  eight virtues (the seed's draw) — different realms, different eight.
- **The Ruined City:** bound permanently to **Humility** (`slot.8`). A town that had every virtue but this
  one and fell to pride; ghosts guard its shrine, which yields only after four others are meditated.
- **The Seer's Two Readings:** before Humility is meditated the seer reads each virtue; after, the seer
  asks only whether the pilgrim is *whole* (Wisdom).
- **The Moral Market** (`village.market`): true intel is sold for favors that cost virtue — the player
  decides what knowledge is worth. Replaces the "pirate den".
- **The Temptation:** an item of great power whose use unmakes virtue; destroying it at the end is a boon.
- **The Three Houses:** castles of the seed's three strongest virtue *families*, each guarding an artifact
  required for the descent.
- **The Sigil Ring:** each meditated shrine yields one sigil; all eight form the ring that opens the
  end dungeon's final door.
- **The Descent:** four doors that ask about the pilgrim's own record, a mirror, two live dilemmas, the
  Threshold; the artifact at the bottom asks the Binding Word — and then, ungraded, what it meant.
- **The Three Roads to the Word:** the dead tell it to the humbled; the silent show it to the watchful; the
  still give it to those who can wait. A fourth "road" is sold at the Drowned Court, and it is false.

