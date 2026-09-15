# Ultima IV: Quest of the Avatar — Deep Dive

> **INTERNAL REFERENCE ANALYSIS ONLY.** This document studies the design of a prior work for inspiration.
> **No name, mantra, place, item, spell, monster name, map layout, or line of text in this file may appear
> in the game.** Paragon is an original IP with randomized, pooled names (`NAMING_AND_LORE.md`). Only the
> abstract mechanics analyzed here are carried forward. Sections 13–14 describe what the *inspiration* did;
> the remake's adaptations are governed by `GAME_DESIGN.md` and `RULES.md §3.14`.

*Origin Systems, designed by Richard Garriott ("Lord British"), released September 1985 (Apple II).*
Often listed among the most important RPGs ever made. This document analyzes what it was, why it worked,
and which elements the remake must preserve, adapt, or expand.

---

## 1. Historical Context

- Ultima I–III were "kill the evil wizard" quests. Garriott received letters complaining that his games
  rewarded theft and murder. Ultima IV was his response: a game with **no villain**.
- Released for Apple II, then C64, Atari 8-bit, DOS, Amiga, Atari ST, Master System, NES (heavily
  altered). Later released as freeware. The open-source **xu4** engine reimplements it and documents its
  data formats.
- Ran on 64 KB machines; its depth came from **design economy**, not asset volume. This is the single most
  important lesson for a remake: **the systems were the content**.

## 2. Core Premise

The player is summoned from Earth through a moongate to Britannia. Lord British has declared an Age of
Enlightenment following the defeat of the Triad of Evil (Mondain, Minax, Exodus). The land needs a moral
exemplar: an **Avatar** who embodies the Eight Virtues. Your goal is to become the Avatar and descend into
the Great Stygian Abyss to read the **Codex of Ultimate Wisdom**.

There is no antagonist. The obstacle is your own conduct and your own ignorance.

## 3. The Virtue System (the heart of the game)

### 3.1 The Eight Virtues and Three Principles

Three Principles: **Truth**, **Love**, **Courage**. Virtues are combinations:

| Virtue | Principles | Town | Mantra | Class | Color | Companion | Dungeon (vice) | Stone |
|---|---|---|---|---|---|---|---|---|
| Honesty | Truth | Moonglow | AHM | Mage | Blue | Mariah | Deceit | Blue |
| Compassion | Love | Britain | MU | Bard | Yellow | Iolo | Despise | Yellow |
| Valor | Courage | Jhelom | RA | Fighter | Red | Geoffrey | Destard | Red |
| Justice | Truth+Love | Yew | BEH | Druid | Green | Jaana | Wrong | Green |
| Sacrifice | Love+Courage | Minoc | CAH | Tinker | Orange | Julia | Covetous | Orange |
| Honor | Truth+Courage | Trinsic | SUMM | Paladin | Purple | Dupre | Shame | Purple |
| Spirituality | Truth+Love+Courage | Skara Brae | OM | Ranger | White | Shamino | Hythloth | White |
| Humility | (none — the absence of pride) | Magincia (ruined) | LUM | Shepherd | Black | Katrina | The Abyss | Black |

### 3.2 Virtue Tracking (hidden karma)

Each virtue is a hidden 0–100 counter. Actions modify it:

| Action | Effect |
|---|---|
| Lying to an NPC who asks a yes/no question | −Honesty |
| Cheating a blind reagent vendor (paying less) | −Honesty; paying fairly +Honesty |
| Giving gold to beggars | +Compassion |
| Fleeing from combat | −Valor |
| Attacking non-evil creatures (e.g., animals, townsfolk) | −Compassion, −Justice, −Honor |
| Killing fleeing enemies | −Compassion, −Justice, −Honor |
| Letting fleeing enemies go | +Compassion, +Justice, +Honor |
| Donating blood at a healer | +Sacrifice |
| Opening chests in towns (stealing) | −Honesty, −Justice, −Honor |
| Using the Skull of Mondain | −all virtues |
| Meditating at a shrine with correct mantra | +that virtue |
| Talking with Hawkwind the seer | readout only, no change |
| Acting against a virtue after achieving Avatarhood in it | lose partial Avatarhood in it |

Key design lesson: **the game never explains the rules of karma**. Players inferred them through
Hawkwind ("Thou art not yet worthy...") and experimentation. The moral system is *itself* a discovery system.

### 3.3 Path to Avatarhood

1. Learn the **mantra** of a virtue (town gossip chain).
2. Learn the **location** of its shrine (gossip, sextant coordinates).
3. Obtain the **rune** of the virtue (hidden item in/near its town; Humility's requires the Silver Horn to
   pass the daemons guarding its shrine).
4. Raise the hidden virtue counter to its threshold (~99).
5. Meditate at the shrine with the correct mantra for 3 cycles → vision → "partial Avatarhood".
6. Achieve all eight → Elevation to Avatar; unlocks Mystic Arms and the Abyss.

### 3.4 Why it worked

- Morality was **mechanical, not narrated**: judged by what you did, not a menu selection.
- It was **discoverable**: rules could be inferred and shared (playground lore, BBSes, Nintendo Power).
- It aligned the *player's* growth with the *character's*. Getting better at the game = becoming a better
  person in the fiction.

## 4. The Knowledge / Intel Token System

The original had no quest log. Progression was gated by **information**, not flags.

### 4.1 Keyword Conversation

Every NPC responded to `NAME`, `JOB`, `HEALTH`, `BYE`, plus 2 custom keywords (usually words appearing in
their JOB response) and an optional yes/no question (which tested Honesty). You *typed* words. Some NPCs
withheld answers until you learned a word elsewhere. Example chain:

> Moonglow: a mage says "Ask Calumny about the mantra" → Calumny: "The mantra of Honesty is AHM."

### 4.2 Categories of Intel Tokens

| Token Type | Count | Source | Used For |
|---|---|---|---|
| Mantra | 8 | Town NPCs | Shrine meditation |
| Shrine location | 8 | NPCs, sextant coordinates | Finding shrines |
| Rune location | 8 | NPC hints | Retrieving runes |
| Stone location | 8 | NPCs, specific dungeon level/room | Altar rooms / Three-Part Key |
| Word of Passage | 3 syllables (VER-AMO-REX) | Three separate keepers | Entering the Codex chamber |
| Passwords | several | Ghosts of Magincia, others | Gated NPCs / doors |
| Item locations | ~10 | NPCs + sextant | Bell, Book, Candle, Skull, Wheel, Horn, Sextant, Mystic Arms |
| Companion locations | 7 | Their own towns | Party recruitment |
| Moongate / moon-phase rules | 1 system | Observation + hints | Fast travel |
| Spell recipes | 26 | Physical reference card | Casting |
| Virtue rules | ~15 | Hawkwind + experimentation | Becoming Avatar |

### 4.3 Why it worked

- Note-taking was **part of play**. The game respected the player's memory.
- The world felt coherent: information in one place referred to another real place.
- No pointer arrows → **exploration was intrinsically rewarding**.

**Remake stance:** Keep keyword input, but add a modern **Codex Notes** journal that records discovered
tokens automatically and cross-links them. Never add a quest arrow.

## 5. World Structure

### 5.1 Overworld

Britannia: one continent (256×256 tiles) with grass, forest, hills, mountains, swamp, rivers, ocean;
8 towns, several villages/keeps (Cove, Paws, Vesper, Buccaneer's Den, Magincia ruins), 4 castles
(Britannia, Lycaeum, Empath Abbey, Serpent's Hold), 8 dungeons, 8 shrines, 8 moongates, the Great Stygian
Abyss (island), and secrets (balloon, whirlpool → Lock Lake, Hythloth beneath Castle Britannia).

### 5.2 Key Places

- **Castle Britannia** — Lord British (heal, level-up), Hawkwind the seer, the council; Hythloth entrance.
- **Lycaeum** (Truth) — library; Book of Truth.
- **Empath Abbey** (Love) — Candle of Love (actually in Cove; the Abbey points there).
- **Serpent's Hold** (Courage) — knights; Bell of Courage is sunk at sea nearby.
- **Buccaneer's Den** — pirates, black market, Skull of Mondain hints.
- **Cove** — hidden village by Lock Lake; Candle of Love; Word of Passage fragments.
- **Paws** — humble village; Shepherds; starving beggars (Compassion).
- **Vesper** — mining/tinkers.
- **Magincia** — destroyed by pride; ghosts and daemons; Humility rune.

### 5.3 Dungeons

Eight dungeons, each 8 levels, first-person wireframe in the original, with rooms that became tactical
combat maps, traps, fountains (heal / poison / cure / power), secret doors, ladders, and one colored
**stone** each. Altar rooms on level 8 (Truth / Love / Courage) interconnect the dungeons. The three
altars accept stones to create the three parts of the Three-Part Key.

### 5.4 The Great Stygian Abyss

Requirements: Bell, Book, Candle (used at the entrance in order), Avatarhood in all eight virtues,
Three-Part Key, Word of Passage. Optional: destroy the Skull of Mondain in the Abyss for a virtue boon.
Each level ends with an altar asking a virtue question; wrong answers eject you. At the bottom the Codex
quizzes you on the virtues, principles, and the axiom that unites them: **Infinity**.

## 6. Party & Companions

- The gypsy intro presents 7 tarot-style dilemmas pitting two virtues against each other; the winning
  virtue determines your class. This is Ultima IV's "personality test".
- Up to 8 party members, one per class. Each companion waits in their virtue's town.
- Original recruitment: they join if your party has a free slot; max party size = number of virtues
  achieved. **Remake decision:** a companion joins only after their virtue's shrine has been meditated.
- Stats: STR, DEX, INT, HP, MP (INT-based, class multiplier), Level (XP, leveled by Lord British), Food,
  Gold, Torches, Gems (peer at map), Keys, Sextant, Reagents, Mixed spells.


## 7. Combat

- Triggered by overworld/dungeon encounters (monsters chase you) or scripted dungeon rooms.
- Switches to a **tactical battle map** chosen by terrain: grass, forest, swamp, hills, bridge, shore,
  ship deck, dungeon room (rooms are hand-made, some with treasure/trigger tiles).
- Turn-based: each party member moves/attacks/casts/uses; enemies act. Ranged weapons and spells.
- Bestiary: orcs, trolls, skeletons, ghosts, zorns, gazers, daemons, dragons, balrons, hydras, sea
  serpents, pirates, gremlins (steal food), rats, bats, spiders, reapers, nixies, squids, whirlpools,
  mimics (fake chests), phantoms, liches, wisps, evil mages, headless, cyclops, lava lizards, insects.
- Enemies **flee** when hurt. Killing fleeing enemies is a virtue violation. Fleeing yourself costs Valor.
- Dead party members remain as corpses/ashes until resurrected (healer or *Resurrect* spell).

## 8. Magic

26 spells (A–Z), each requiring **reagents** mixed in advance with the Mix command. Reagents: Sulfurous
Ash, Ginseng, Garlic, Spider Silk, Blood Moss, Black Pearl, Nightshade, Mandrake Root. Nightshade and
Mandrake are never sold — gathered in specific swamps only at specific moon phases / at night. Failed
mixtures waste reagents. Spells: Awaken, Blink, Cure, Dispel, Energy Field, Fireball, Gate Travel, Heal,
Iceball, Jinx, Kill, Light, Magic Missile, Negate, Open, Protection, Quickness, Resurrect, Sleep, Tremor,
Undead, View, Winds, X-it, Y-up, Z-down.

Design lesson: recipes were knowledge tokens too (printed on the reference card). Magic was **planned
resource management**, not spam.

## 9. Time, Moons, Moongates

- Day/night cycle; NPCs sleep; towns darken; torches / *Light* needed in dungeons.
- Two moons, **Trammel** and **Felucca**, each with 8 phases. Trammel's phase decides **which moongate
  is open**; Felucca's decides **where it leads**. Learned by observation and hints.
- When both moons are new, the gate leads to the Shrine of Spirituality (otherwise unreachable on foot).
- Sextant gives lat/long letter-pairs (e.g. "K'F L'B"); NPCs give coordinates in that format.

## 10. Survival & Economy

- **Food** consumed per step per party member; at 0, HP drains. Bought at taverns.
- **Gold** from chests (dungeons, after combat) — spent on weapons, armor, reagents, food, healing, inns,
  horses, ship repairs.
- **Camp** (Hole up): rests the party; full heal if not ambushed; can be interrupted in dungeons.
- Inns: full rest. Healers: cure poison, heal, resurrect, accept blood donation.
- Transport: horse (fast), ship (captured from pirates — necessary for islands), balloon (found in
  Hythloth, wind-driven), whirlpool (to Lock Lake), moongates.

## 11. Special Items

Bell of Courage, Book of Truth, Candle of Love, Skull of Mondain, Three-Part Key, Wheel of HMS Cape
(ship armor), Silver Horn (repels the daemons at the Shrine of Humility), Sextant, Mystic Armor and Mystic
Sword (Avatar-only), 8 runes, 8 stones, gems, keys, torches.

## 12. What Made It a Classic (synthesis)

1. **Ethical simulation, not moral-choice menus.** Consequences were systemic and invisible.
2. **Knowledge as the progression currency.** The player's notebook was the real save file.
3. **A coherent, cross-referential world.** Every rumor pointed to a real place.
4. **Respect for the player's intelligence.** Moons, stones, Words of Passage — puzzles requiring reasoning.
5. **Economy of systems.** 26 spells, 8×8 everything, deterministic rules; depth from combinatorics.
6. **Personal narrative.** No villain; the protagonist's arc *is* the player's arc.
7. **Party as embodiment of theme.** Each companion literally *is* a virtue.
8. **Survival tension.** Food, torches, reagents, gold — constant meaningful pressure.
9. **Multiple travel modalities** turned the map into a puzzle.
10. **Intro personality test** made the class a reflection of the player's values.

## 13. What Aged Poorly (and how the remake addresses it)

| Problem | Remake Approach |
|---|---|
| Typed keywords without feedback; missable words | Keyword UI with journal auto-recording; clickable learned words **and** free typing |
| Grinding for gold/XP | Fewer, more meaningful encounters; virtue-aligned rewards |
| Hidden karma feels arbitrary | Keep hidden numbers; richer diegetic feedback (Hawkwind, NPC attitude, dreams at camp) |
| Flat NPCs (2 keywords each) | 3–8 topics each, schedules, relationships, sub-arcs; 300+ NPCs |
| Dungeon repetition | Hand-crafted isometric 3D levels themed per vice |
| Slow combat | Faster resolution, terrain, positioning, flanking, morale |
| No save anywhere | Save anywhere; camp/inn for full heal |
| Manual/reference-card dependence | In-game Codex Notes, spellbook, bestiary, revealed progressively |
| Sparse main-quest dependency chain | Same skeleton, many more branches, red herrings, and twists |

## 14. Structural Elements Carried Forward (as mechanics, with original names)

- 8 virtues, 3 principles, mantra ritual, rune/stone equivalents, colors, classes, vice-themed dungeons.
- Gypsy intro with tarot-style dilemmas determining class.
- Hidden virtue counters and Hawkwind's diegetic readout.
- Keyword-driven NPC discovery; intel tokens; no quest markers.
- Two moons, 8 moongates, phase-based travel.
- Shrine meditation (mantra + cycles), all 8 for Avatarhood.
- Reagent-based spellcasting with wild-only reagents.
- Food/gold/torches survival; camp/inn/healer.
- Terrain-based tactical battle maps; fleeing enemies with virtue penalties for slaughter.
- Companions per virtue; party of up to 8.
- Stones + altar rooms + three-part key + word of passage + final descent + concept quiz with a single
  unifying answer (ours is pooled — never "Infinity").

## 15. References

- xu4 (open-source engine; data format docs): https://xu4.sourceforge.net/
- Ultima Codex wiki: https://wiki.ultimacodex.com/wiki/Ultima_IV
- Original manuals: *The History of Britannia*, *The Book of Mystic Wisdom* (freeware release).
- The Digital Antiquarian essay series on Ultima IV.

