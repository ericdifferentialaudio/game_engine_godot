# Clans

Twelve clans give a second axis of character identity beside **class** (which remains tied to the eight
virtues). At creation the player picks or rolls a clan; every companion and champion also has one.
Clan *names* are pooled per seed (`NAMING_AND_LORE.md`); clan *mechanics* are fixed and keyed by ID.

## 1. Adaptation from the source table

The source table used hex-strategy vocabulary. Mapping to this party RPG:

| Source column | Meaning in Paragon |
|---|---|
| Shrine Bonus | Permanent stat boost granted when the shrine of the clan's **patron virtue** is meditated |
| Passive | Always-on effect on the tactical battle grid and/or exploration |
| Specialty Unit | **Clan Champion**: a recruitable NPC found in the clan homeland; occupies a 9th "champion" party slot (one champion at a time) |
| Specialty Building | **Clan Hall**: a unique-service building placed in the clan's home town (placement randomized) |
| Magic Tier | Maximum spell **circle** (0–5) a member of the clan may cast; circles group the 32 spells by power |

Hex terms translate to our square grid: "hex" → cell; "zone of control" → adjacency stop; "ATK/DEF/VIS/
MOV/STL/RES/LCK/ARC/INT" → existing or new derived stats (see §3).

## 2. Clan Table

| Clan ID | Shrine Bonus | Battle / Exploration Passive | Champion | Clan Hall (service) | Magic Tier |
|---|---|---|---|---|---|
| `clan.fighter` | +ATK | **Charge:** may move through cells occupied by allies | Warlord (AoE taunt) | War Hall — weapon training, +1 STR once | 0 |
| `clan.mage` | +VIS (view range) | Largest MP pool multiplier in the game | Arcanist (double-cast once per battle) | Arcane Tower — reagent identification, spell research | 5 |
| `clan.cleric` | +DEF | **Tend:** heal an adjacent ally as a free action once per turn | High Priest (mass cure) | Temple — resurrection at reduced virtue cost, blood donation | 3 |
| `clan.dwarf` | +HP | Mountain cells cost 2 (others impassable); immune to cave-in traps | Runesmith (enchant weapon in battle) | Forge — repair, upgrade, bind stones to the Sigil Ring without an altar | 0 |
| `clan.ranger` | +MOV | Forest/hills free movement; mountains cost 1; camp ambush chance halved | Trapper (lay snares) | Ranger Post — maps of the region, horse discount | 1 |
| `clan.elf` | +ARC (ranged accuracy) | Ignores forest defence penalty when shooting | Starbow (pierces two targets) | Archer Range — bows, +1 DEX once | 3 |
| `clan.rogue` | +STL (stealth) | Not targetable until within 2 cells of an enemy at battle start | Assassin (backstab crit) | Shadow Den — buy intel tokens (costs gold **and** virtue) | 1 |
| `clan.monk` | +RES (status resist) | Moving past enemies does not stop movement (no adjacency stop) | Iron Fist (stun) | Monastery — meditation practice (retry a failed shrine cycle without a day lost) | 2 |
| `clan.druid` | +LCK | Free forest movement; may **grow forest** on a grass cell once per battle | Thornweaver (entangle) | Grove — wild reagents (incl. moon-only ones) at any phase, limited stock | 3 |
| `clan.necromancer` | +ATK (weak) | +1 ATK per 3 units dead on the battle map | Death Knight (drain) | Crypt — resurrection *without* healer but at a hidden virtue cost | 4 |
| `clan.bard` | +INT | Reveals which virtues an NPC holds dear (dialogue hint) and enemy morale state | Spymaster (reveal false tokens) | Thieves' Guild — rumors (random true token per visit, cooldown) | 2 |
| `clan.shaman` | +ARC (elemental) | Area spells deal +1 damage per target | Stormcaller (chain lightning) | Spirit Lodge — camp dreams on demand (virtue feedback) | 4 |

## 3. Derived Stats Introduced

`ATK`, `DEF` (from weapon/armor + clan), `VIS` (tiles revealed), `MOV` (cells per turn), `STL`, `RES`,
`LCK` (loot & crit), `ARC` (ranged/spell accuracy). All live in `data/clans/clans.json` with numeric values
in `data/virtue/../balance.json`. No magic numbers in code.

## 4. Patron Virtues (per seed)

Each clan draws a patron from **the seed's 8 drawn virtues** (`VIRTUES.md §4`) so that:
- every drawn virtue is patron to at least one clan;
- exactly 4 clans have a **contested** patron (two clans share it); contested patrons are placed
  preferentially on virtues in an *active conflict pair*, so clan rivalry mirrors the run's moral tension;
- `clan.necromancer` and `clan.rogue` can never be patrons of the anchor virtue (Integrity/Justice) or of
  Humility — their halls trade in secrets and pride;
- `clan.monk` and `clan.cleric` are preferred (not required) patrons of Humility.
- Wisdom is never a patron.

## 5. Interaction with Virtue

- Clan hall services that shortcut discovery (Shadow Den, Thieves' Guild, Crypt) **cost virtue**, hidden as
  always. Conduct still matters more than clan.
- Champions have their own loyalty like companions and leave if their clan's patron virtue drops to "lost".
- Magic Tier caps class casting: a Fighter-class character from `clan.mage` can still reach circle 5 with
  a small MP pool; a Mage-class from `clan.dwarf` casts nothing — an intentional, visible trade-off at creation.

## 6. Content Requirements

12 halls (building kit + interior scene), 12 champions (NPC, dialogue, one personal errand each), clan
name pool (≥ 60 names, flavor-tagged), clan crests (UI). Tracked under P1-T12 and P5-T8.
