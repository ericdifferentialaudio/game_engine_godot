# clans.md — Clan Reference

## Overview

12 clans available. **8 active per game** (seed-selected). Each game is an 8-clan world — the missing 4 clans do not appear, their shrines do not exist, their towns are less likely to appear.

Every clan has:
- A **shrine bonus stat** — the stat boosted when any unit meditates that clan's shrine (+1 clan-wide, +2 to meditating unit personally)
- A **magic tier** (0–5) — determines spells available and base mana pool
- A **clan unit** — unique variant of the standard melee fighter
- A **specialty unit** — powerful unique unit requiring Barracks II + clan building
- A **clan building** — unlocks the specialty unit and provides a passive
- A **wonder** `[UNIMPLEMENTED]` — design-intent ultimate late-game power requiring
  all 3 Tier 3 techs + 300g/10t. `ClanInstance.wonders_built` dict field exists but
  nothing in `engine/` ever builds a wonder, checks a wonder gate, or applies a
  wonder effect — see `technology.md` for the full writeup. The tables below are
  kept as design-intent reference only, not a description of current behaviour.

---

## Quick Reference Table

| Clan | Shrine stat | Magic | Clan Unit ATK/DEF/MOV/HP | Specialty | Playstyle |
|------|-------------|-------|--------------------------|-----------|-----------|
| Fighter | +ATK | 0 | 5/3/3/6 | Siege Engineer | Military dominance |
| Mage | +VIS | 5 | 2/1/3/3 | Arcanist | Information + teleportation |
| Cleric | +DEF | 3 | 3/5/3/5 | High Priest | Healing + shrine access |
| Dwarf | +END | 0 | 5/5/2/7 | Runesmith | Production + fortification |
| Ranger | +MOV | 1 | 3/2/5/4 | Trapper | Speed + map control |
| Elf | +ARC | 3 | 4/2/4/4 | Starbow | Ranged + long vision |
| Rogue | +STL | 1 | 5/2/4/4 | Assassin | Stealth + assassination |
| Monk | +RES | 2 | 4/3/4/5 | Iron Fist | Mobility + disruption |
| Druid | +LCK | 3 | 2/3/3/5 | Thornweaver | Terrain manipulation + luck |
| Necromancer | +ATK(dark) | 4 | 4/2/3/5 | Death Knight | Late-game snowball |
| Bard | +INT | 2 | 2/2/4/4 | Spymaster | Information warfare |
| Shaman | +ARC(elem) | 4 | 3/2/3/5 | Stormcaller | Area devastation |

---

## Clan Entries

---

### Fighter
*"We do not negotiate from weakness."*

**Colour:** Steel blue `[74, 144, 217]`  
**Shrine bonus:** `atk` — +1 ATK to all clan units per shrine meditated  
**Magic tier:** 0 — no spells, no mana. Immune to Silence, Curse, Charm  
**Shrine name:** Shrine of Valour

#### Clan Unit — Fighter
| ATK | DEF | MOV | HP | VIS | MP |
|-----|-----|-----|----|-----|----|
| 5 | 3 | 3 | 6 | 2 | 0 |

**Passive — Charge:** Can move through an enemy-occupied hex in one action, triggering combat but not stopping. The Fighter unit passes through — the enemy takes damage — and the Fighter ends on the far side. Enables penetrating defensive lines and reaching Seekers behind escorts.

#### Specialty Unit — Siege Engineer
| ATK | DEF | MOV | HP | Cost |
|-----|-----|-----|----|------|
| 6 | 4 | 1 | 8 | 100g / 5t |

**Unlock:** Barracks II (no clan building — available to Fighter immediately with Barracks II)

**Ability — Demolish:** Destroys any building or enclave wall in 1 turn. Cannot move same turn. The only unit that can directly damage the enclave structure, enabling clan elimination. With Master Engineering tech: demolishes in 0 turns (instant).

**Clan building:** Fighter has no separate clan-specific building — the Siege Engineer requires only Barracks II.

#### Wonder `[UNIMPLEMENTED]` — Hall of Champions
All future Clan Units produced with +2 ATK. Existing units unaffected. Stacks with shrine ATK bonuses.

#### Playstyle
Fighter is the elimination specialist. High ATK units, immune to magic debuffs, Charge ability for penetrating formations, Siege Engineer for destroying enclaves. Weak early game (no magic, no reconnaissance beyond Scouts). Relies on military escort for shrine runs — cannot stealth. Ideal strategy: take corner bonuses early (Ancient Forge is perfect), build military strength, destroy rival enclaves mid-game to reduce Avatar competition, then push for Dragon assault with the strongest army on the map.

**Shrine run approach:** Escort force with Chieftain leading. Charge ability lets Fighter units reach meditating rivals inside sacred radius perimeter before they can escape. Cannot stealth — all shrine runs are overt military operations.

**Dragon approach:** Best Dragon-fighting unit statwise. 6 Fighter units surrounding the Dragon with Chieftain Rally support = the highest sustained DPS in the game.

---

### Mage
*"Sight is the only true power."*

**Colour:** Arcane purple `[186, 104, 200]`  
**Shrine bonus:** `vis` — +1 VIS to all clan units per shrine meditated  
**Magic tier:** 5 — highest. Access to T5 spells (Meteor, Arcane Gate, Time Stop, Anti-Magic)  
**Shrine name:** Shrine of Sight

#### Clan Unit — Mage
| ATK | DEF | MOV | HP | VIS | MP |
|-----|-----|-----|----|-----|----|
| 2 | 1 | 3 | 3 | 3 | 30 |

**Passive — Arcane Depth:** Highest base mana pool (30 MP). T5 spell access. Extremely fragile in melee (HP 3, DEF 1). Must be protected at all costs.

#### Specialty Unit — Arcanist
| ATK | DEF | MOV | HP | Cost |
|-----|-----|-----|----|------|
| 1 | 1 | 3 | 2 | 120g / 5t |

**Unlock:** Barracks II + Arcane Tower (also gives all Mage units +2 max MP)

**Ability — Arcane Relay:** Teleports any single friendly unit to any hex within 6 hexes, once per turn. No line of sight required. Uses: teleport the Seeker out of danger, move Chieftain past a defensive line, reposition a unit after meditation departure, bypass a Trap hex.

#### Wonder `[UNIMPLEMENTED]` — Eye in the Sky
Complete permanent map vision — all hexes visible, fog permanently cleared for Mage clan. Every rival's position visible at all times. The intelligence wonder.

#### Playstyle
Mage is the information and repositioning specialist. VIS shrine bonus makes Scouts see further with each meditation. Eye in the Sky wonder eliminates the fog entirely. Arcanist relay enables surgical repositioning. Fragile in combat — the Mage clan wins by knowing everything while others are guessing.

**Shrine run approach:** Blink spell (T3) for departure — teleports 6 hexes on exit from sacred ground, making departure ambush nearly impossible. Arcane Gate (T5, once per game): teleports any visible unit directly to any visible hex — can drop a unit inside sacred ground instantly.

**Dragon approach:** Lightning weakness exploitable with T4/T5 spells. Eye in the Sky means the Mage clan always knows Dragon position. Arcanist relay repositions Seeker away from breath cone in real time.

---

### Cleric
*"The sacred ground knows its own."*

**Colour:** Rose `[240, 98, 146]`  
**Shrine bonus:** `def` — +1 DEF to all clan units per shrine meditated  
**Magic tier:** 3 — access to Fireball, Heal, Entangle, Blink  
**Shrine name:** Shrine of Faith

#### Clan Unit — Cleric
| ATK | DEF | MOV | HP | VIS | MP |
|-----|-----|-----|----|-----|----|
| 3 | 5 | 3 | 5 | 2 | 14 |

**Passive — Free Heal:** Restores 2 HP to one adjacent friendly unit once per turn as a free action (no action slot consumed). The best passive healer in the game — Cleric units running alongside any force make that force dramatically more durable.

#### Specialty Unit — High Priest
| ATK | DEF | MOV | HP | Cost |
|-----|-----|-----|----|------|
| 2 | 6 | 2 | 7 | 100g / 5t |

**Unlock:** Barracks II + Temple (Temple also gives +1 HP regen to all clan units in visible territory)

**Ability — Instant Meditation:** Shrine meditation completes in 0 turns instead of 1. The High Priest steps onto sacred ground and the bonus applies immediately — no turn spent meditating. The departure ambush problem is completely eliminated for this unit.

#### Wonder `[UNIMPLEMENTED]` — Cathedral of Mercy
All friendly units in visible territory restore +2 combat HP per turn. Stacks with territory healing (+1) and Cleric Free Heal (+2). Units in Cleric-controlled territory are nearly unkillable in sustained skirmishes.

#### Playstyle
Cleric is the shrine-running and durability specialist. DEF shrine bonus means the whole clan gets tougher with each meditation. High Priest eliminates the most dangerous moment of cross-map shrine runs. Cathedral of Mercy creates a healing aura across all visible territory.

**Shrine run approach:** Send a High Priest to distant shrines. Instant meditation means no departure window for rivals to exploit. The safest shrine runner in the game.

**Dragon approach:** Cleric is the essential support for any Dragon fight — free healing keeps the assault force alive through multiple breath cycles. Holy spells deal bonus damage to Demon and Wraith types.

---

### Dwarf
*"The mountain yields to patience."*

**Colour:** Amber `[232, 168, 56]`  
**Shrine bonus:** `end` — +1 END (endurance/max HP) to all clan units per shrine meditated  
**Magic tier:** 0 — no spells. Immune to all magic debuffs (Silence, Curse, Charm, Slow)  
**Shrine name:** Shrine of Stone

#### Clan Unit — Dwarf
| ATK | DEF | MOV | HP | VIS | MP |
|-----|-----|-----|----|-----|----|
| 5 | 5 | 2 | 7 | 2 | 0 |

**Passive — Mountain Movement:** Mountain terrain costs 2 (passable, where all others are blocked). Cannot be moved by Charm or forced movement spells. Unmovable in fortified positions — if a Dwarf unit ends a turn adjacent to a Fort structure, it cannot be displaced by any effect.

**Immunity:** Magic debuffs have no effect. Silence, Curse, Slow, Charm all fail against Dwarf units.

#### Specialty Unit — Runesmith
| ATK | DEF | MOV | HP | Cost |
|-----|-----|-----|----|------|
| 4 | 6 | 1 | 9 | 80g / 4t |

**Unlock:** Barracks II + Forge (Forge also gives enclave walls +1 HP passive repair/turn)

**Ability — Ward Rune (3 uses):** Places a permanent invisible rune on any hex. Enemy unit entering takes 3 damage. Rune consumed on trigger. Three independent runes can be placed. Functionally a more powerful Trap — no Engineering tech required, no maximum active limit beyond the 3-use cap.

#### Wonder `[UNIMPLEMENTED]` — The Eternal Forge
All buildings complete in half turns (rounded up). Production bar acceleration 50% faster. The Dwarf can produce a Seeker faster than any other clan when the Forge wonder is active.

#### Playstyle
Dwarf is the production and fortification powerhouse. Highest HP and DEF clan unit. Mountain mines (+2 production) drive the fastest build queue. Magic immunity makes Dwarf units reliable in mixed-magic environments.

**Shrine run approach:** Slow (MOV 2) but extremely hard to stop. Dwarf Chieftain escorting a meditation run through mountain passes is nearly unkillable — no magic debuffs land, high DEF absorbs hits, mountain movement lets it approach from angles others can't.

**Dragon approach:** Runesmith is the tankiest non-Dragon unit (DEF 6, HP 9). Dwarf clan Dragon assaults use Runesmiths to absorb breath damage while other units deal sustained ATK.

---

### Ranger
*"The land opens for those who know to listen."*

**Colour:** Forest green `[106, 191, 105]`  
**Shrine bonus:** `mov` — +1 MOV to all clan units per shrine meditated  
**Magic tier:** 1 — T1 spells only (Reveal, Mend, Slow, Shroud)  
**Shrine name:** Shrine of the Path

#### Clan Unit — Ranger
| ATK | DEF | MOV | HP | VIS | MP |
|-----|-----|-----|----|-----|----|
| 3 | 2 | 5 | 4 | 2 | 4 |

**Passive — Ghost Step:** Ignores ZoC from non-adjacent enemies (enemies more than 1 hex away do not impose extra movement cost). Forest and hills movement free (cost 1). Mountain cost 1 (passable for Ranger, 2 for Dwarf, impassable for all others).

#### Specialty Unit — Trapper
| ATK | DEF | MOV | HP | Cost |
|-----|-----|-----|----|------|
| 3 | 2 | 5 | 4 | 80g / 4t |

**Unlock:** Barracks II + Ranger Post (Post also makes Ranger-placed traps harder to detect: +2 STL)

**Ability — Snare:** Places a hidden snare on any hex within 3. Enemy unit entering the snare loses their entire next turn (cannot move, attack, cast, meditate). Unlike a standard Trap (3 damage), the Snare causes a full turn loss — devastating on Seekers mid-approach or Chieftains approaching the Dragon.

#### Wonder `[UNIMPLEMENTED]` — Pathfinder's Sanctum
All terrain costs 1 for the entire Ranger clan permanently. Mountain becomes passable at cost 1 for all Ranger units (not just the Clan Unit). The fastest-moving clan in the game once the wonder is built.

#### Playstyle
Ranger is the speed and map control specialist. MOV shrine bonus stacks rapidly — a Ranger clan with 4 MOV shrine meditations gives every unit +4 MOV on top of the Ranger Clan Unit's base MOV 5, creating MOV 9 units. Fastest shrine runner in the game.

**Shrine run approach:** Speed makes everything easy. Ghost Step ignores most ZoC. Forest and hills free means no terrain slows the approach. Ranger Seeker with MOV shrine bonuses is the hardest to catch once it has the egg.

**Dragon approach:** Speed enables Theft Run optimally. Ranger Seeker can grab the egg during the 2-turn Stirring window and outrun Dragon pursuit. Also Mountain access lets Rangers approach the Dragon's Keep from angles other clans cannot.

---

### Elf
*"We see what others overlook."*

**Colour:** Teal `[77, 208, 225]`  
**Shrine bonus:** `arc` — +1 ARC (arcane/magic resistance + spell effectiveness)  
**Magic tier:** 3 — access to Fireball, Heal, Entangle, Blink  
**Shrine name:** Shrine of the Stars

#### Clan Unit — Elf
| ATK | DEF | MOV | HP | VIS | MP |
|-----|-----|-----|----|-----|----|
| 4 | 2 | 4 | 4 | 3 | 14 |

**Passive — Long Sight:** Can meditate a shrine from 1 hex outside the sacred radius (radius 3 instead of 2). Immune to forest cover DEF penalty vs Archers — arrows that would hit a DEF-boosted Elf unit get no forest bonus.

#### Specialty Unit — Starbow
| ATK | DEF | MOV | HP | Cost |
|-----|-----|-----|----|------|
| 5 | 2 | 3 | 3 | 100g / 5t |

**Unlock:** Barracks II + Archer Range (Range also gives all Elf Archers +1 RNG permanently — standard Archers become RNG 4)

**Ability — True Shot:** Arrows ignore all terrain cover bonuses. Can fire into forest hexes without penalty. Range 4 (highest base ranged range in the game). The definitive ranged unit — no terrain modifiers, no cover, long reach.

#### Wonder `[UNIMPLEMENTED]` — Star Observatory
Seeker VIS +10. All Archers RNG +2 (Archers become RNG 5, Starbows become RNG 6). The Elf Seeker can detect the egg from radius 16 — well outside Dragon trigger range (8). Detects the egg safely before committing.

#### Playstyle
Elf is the precision and reconnaissance specialist. ARC shrine bonus enhances spell effectiveness and magic resistance across the clan. Star Observatory makes the Seeker the most capable egg-finder in the game. Starbows negate the terrain system for ranged combat.

**Shrine run approach:** Long Sight means meditating from a safer hex (one step further from the shrine's guardian ring). Lower exposure to departure ambush.

**Dragon approach:** Star Observatory Seeker detects egg at r=16, triggering Dragon at r=8 knowingly. Elf can plan the full approach before the Dragon wakes. Starbows at range deal consistent damage from outside breath cone.

---

### Rogue
*"The seen wall is the easy one to climb."*

**Colour:** Brown `[161, 136, 127]`  
**Shrine bonus:** `stl` — +1 STL (stealth/invisibility threshold) to all clan units  
**Magic tier:** 1 — T1 spells (Shroud is particularly synergistic)  
**Shrine name:** Shrine of Shadows

#### Clan Unit — Rogue
| ATK | DEF | MOV | HP | VIS | MP |
|-----|-----|-----|----|-----|----|
| 5 | 2 | 4 | 4 | 2 | 4 |

**Passive — Stealth:** Invisible to enemies beyond 2 hexes at all times (STL 2 baseline + shrine bonuses). Breaks when the unit attacks. Resumes 1 full turn after the last attack. Rivals cannot see Rogue units approaching until they are adjacent — Watch Posts reveal them only within 2 hexes, not at VIS range.

#### Specialty Unit — Assassin
| ATK | DEF | MOV | HP | Cost |
|-----|-----|-----|----|------|
| 7 | 1 | 5 | 3 | 120g / 5t |

**Unlock:** Barracks II + Shadow Den (Den also gives all Rogue units +1 STL permanently — Rogue Clan Units become invisible beyond 3 hexes)

**Ability — Ambush:** When attacking from invisibility (STL active, target unaware within 2 hexes), instantly defeats any non-specialty unit. No HP roll — immediate kill. The target must not have a friendly Scout or Watch Post within 2 hexes of the Assassin.

#### Wonder `[UNIMPLEMENTED]` — Shadow Citadel
All clan units permanently invisible beyond 3 hexes (extended from 2). The entire Rogue army is invisible to enemies at medium range. The Seeker approaches the Dragon's Keep unseen.

#### Playstyle
Rogue is the stealth specialist. Every unit is harder to see, every shrine run is invisible until adjacent, every Assassin kill bypasses all HP systems. The departure ambush problem is minimal — by the time defenders can see the Rogue meditating, it's already leaving.

**Shrine run approach:** Rogue Clan Units meditate shrines invisibly. Rivals ring the sacred zone but cannot see the Rogue approaching until it's inside. By the time they position to block departure, the Rogue is already gone.

**Dragon approach:** Rogue Seeker is ideal for theft run — invisible approach, grab egg during Stirring window. Dragon doesn't see it coming. Assassination of rival Seekers in the Dragon's Keep disrupts competition for the egg.

---

### Monk
*"The path opens because we do not force it."*

**Colour:** Coral `[255, 138, 101]`  
**Shrine bonus:** `res` — +1 RES (resistance to status effects)  
**Magic tier:** 2 — T1–T2 spells (Ward, Haste, Silence, Charm)  
**Shrine name:** Shrine of Clarity

#### Clan Unit — Monk
| ATK | DEF | MOV | HP | VIS | MP |
|-----|-----|-----|----|-----|----|
| 4 | 3 | 4 | 5 | 2 | 8 |

**Passive — Passing Through:** Enemies must spend their entire action to engage the Monk — cannot move AND attack the Monk in the same turn. The Monk does not trigger ZoC on enemies. It flows through contested spaces without slowing down or being slowed by proximity threats.

#### Specialty Unit — Iron Fist
| ATK | DEF | MOV | HP | Cost |
|-----|-----|-----|----|------|
| 6 | 4 | 4 | 7 | 100g / 4t |

**Unlock:** Barracks II + Monastery (Monastery also removes ZoC triggering entirely for all Monk units)

**Ability — Stun Strike (3 uses):** Target unit skips their entire next turn. Units killed by Stun Strike cannot be reanimated by Necromancer — the discipline destroys the animating force. The direct counter to Necromancer strategy.

#### Wonder `[UNIMPLEMENTED]` — Temple of Harmony
Alliance duration doubled (stacks with Eternal Alliance tech: ×4 total). No virtue debt ever from shrine camping — Monk units can meditate and hold sacred ground indefinitely without triggering departure virtue events.

#### Playstyle
Monk is the control and diplomacy specialist. RES shrine bonus stacks resistance to status effects — Charm, Curse, Slow, and Petrify all have reduced effectiveness against the Monk clan. ZoC immunity enables movement through packed enemy formations. Iron Fist counter-plays Necromancer and stuns Seekers.

**Shrine run approach:** No ZoC means the Monk moves through packed defender formations without paying extra movement. Departure ambush is less threatening — the Monk can walk past defenders rather than around them.

**Dragon approach:** Monk's ZoC immunity means it can position freely around the Dragon without ZoC penalties from Dragon-adjacent units. Useful for precise positioning during the assault.

---

### Druid
*"The luck of the land flows through those who tend it."*

**Colour:** Forest green `[106, 191, 105]`  
**Shrine bonus:** `lck` — +1 LCK (luck roll shifts toward higher damage)  
**Magic tier:** 3 — access to Fireball, Heal, Entangle, Blink  
**Shrine name:** Shrine of the Grove

#### Clan Unit — Druid
| ATK | DEF | MOV | HP | VIS | MP |
|-----|-----|-----|----|-----|----|
| 2 | 3 | 3 | 5 | 2 | 14 |

**Passive — Forest Affinity:** Free forest and grasslands movement (cost 1). Enemies adjacent to a Druid unit in forest hexes move at half speed (the forest resists them). Passive: grows 1 forest hex per 5 turns in the nearest non-forest passable hex (terrain transformation, permanent).

**Luck mechanic:** Druid shrine bonuses shift the combat luck roll from `[-1,0,+1]` to `[0,+1,+2]` for the entire clan. Average damage increases by 1 per hit across the whole clan.

#### Specialty Unit — Thornweaver
| ATK | DEF | MOV | HP | Cost |
|-----|-----|-----|----|------|
| 2 | 3 | 3 | 6 | 80g / 4t |

**Unlock:** Barracks II + Grove (Grove also makes Druid Foresters build Lumber Posts in 1 turn instead of 2)

**Ability — Grow Forest (2 uses):** Permanently converts up to 3 adjacent plains or grasslands hexes to forest. Cannot convert mountain or swamp. Creates new territory where Druid free-movement applies and where Lumber Post improvements can be built.

#### Wonder `[UNIMPLEMENTED]` — World Tree
All forest terrain generates +0.2g/turn for Druid clan. Lumber Posts generate +2 MP regen instead of +1. With extensive forest on the map (natural + Thornweaver growth), the Druid has the highest passive income potential.

#### Playstyle
Druid is the terrain and luck specialist. LCK shrine bonuses make every combat hit deal more damage on average — a fully-meditated Druid clan fights at +1 average damage per hit across every unit and every combat. Entangle is free via the Druid (T3 spell accessible) — freezes Dragon or any unit for 2 turns. World Tree creates an expanding economic engine from forest coverage.

**Shrine run approach:** Forest free movement makes the middle ring (shrine zone) fast to navigate. Entangle is ideal for holding off pursuing defenders after meditation — freeze the nearest threat and walk out.

**Dragon approach:** Druid Entangle on the Dragon (T3 spell): if it lands, Dragon ATK = 0 for 2 turns. Combined with luck shift (all attacks deal higher average damage), Druid is a sleeper Dragon-fighting clan.

---

### Necromancer
*"Everything that falls rises in my service."*

**Colour:** Dark purple `[155, 107, 208]`  
**Shrine bonus:** `atk_dark` — +1 ATK (dark) — applies as bonus ATK overlay to Necromancer Clan Units specifically  
**Magic tier:** 4 — T1–T4 spells (Lightning, Reanimate, Curse, Mass Haste)  
**Shrine name:** Shrine of the Veil

#### Clan Unit — Necromancer
| ATK | DEF | MOV | HP | VIS | MP |
|-----|-----|-----|----|-----|----|
| 4 | 2 | 3 | 5 | 2 | 20 |

**Passive — Dark Resonance:** Gains +1 ATK permanently for every 3 units that die anywhere on the map (any clan, any unit, including monsters). Tracked cumulatively. In a 28-turn game with active combat across 8 clans, total deaths easily reach 30+, giving +10 ATK by the Gauntlet phase. The Necromancer clan unit at turn 25 fights at ATK 14+.

**Note on `atk_dark` stat:** Dark Resonance bonus applies only to Necromancer Clan Units and is tracked separately from regular ATK shrine bonuses. `effective_stat(unit, 'atk_dark')` returns the Dark Resonance bonus; added to base ATK in combat.

#### Specialty Unit — Death Knight
| ATK | DEF | MOV | HP | Cost |
|-----|-----|-----|----|------|
| 6 | 3 | 3 | 8 | 120g / 5t |

**Unlock:** Barracks II + Crypt (Crypt also extends Reanimate spell duration by +2 turns)

**Ability — Reanimate:** Returns any defeated unit on an adjacent hex to life as a friendly allied unit for 5 turns (7 with Crypt). Returns with full base stats (no shrine bonuses). Cannot reanimate the Dragon. Cannot reanimate units killed by Iron Fist Stun Strike.

#### Wonder `[UNIMPLEMENTED]` — Throne of Dust
Reanimated units last forever (not 5 turns). All reanimates return at full HP. A reanimated Chieftain becomes a permanent member of the Necromancer army.

#### Playstyle
Necromancer is the late-game snowball specialist. Weakest early game (Dark Resonance hasn't accumulated yet, low DEF). Strongest late game (30+ deaths = massive ATK bonus). Encourage combat everywhere — every death makes the Necromancer stronger regardless of whose units die.

**Shrine run approach:** Curse spell (T4) on defenders — reduces their ATK/DEF by 2 for 3 turns, making the meditation and departure window safer. Reanimate any killed defender and use it to block the same clan's pursuit.

**Dragon approach:** Dark Resonance means the Necromancer hits hardest in the Dragon fight when the Dragon dies. Reanimate units killed by Dragon breath and re-deploy them immediately. The Dragon fight generates deaths that feed Dark Resonance.

---

### Bard
*"Every rumour has a source. Every source has a price."*

**Colour:** Gold `[184, 152, 72]`  
**Shrine bonus:** `int_stat` — +1 INT (intelligence — pub intel decode speed, barkeep relationship)  
**Magic tier:** 2 — T1–T2 spells (Slow, Shroud, Silence, Charm)  
**Shrine name:** Shrine of Song

#### Clan Unit — Bard
| ATK | DEF | MOV | HP | VIS | MP |
|-----|-----|-----|----|-----|----|
| 2 | 2 | 4 | 4 | 2 | 8 |

**Passive — Shrine Reader:** Once per turn (free action), reads the exact shrine completion status for all rival clans visible on the map — which shrines they have, how close they are to Avatar. Detects planted pub rumors with an INT check: `detection_chance = min(80%, clan.shrine_bonuses["int_stat"] * 15%)`.

#### Specialty Unit — Spymaster
| ATK | DEF | MOV | HP | STL | Cost |
|-----|-----|-----|----|-----|------|
| 3 | 2 | 5 | 4 | 3 | 100g / 4t |

**Unlock:** Barracks II + Thieves Guild (Guild also gives free rumor plant once per 8 turns)

**Abilities:**
- **Steal Gold (2 uses):** Steals 10% of any enemy clan's treasury (vs. 5% for normal unit kill). Can target any clan currently visible to the Spymaster.
- **Plant Rumor (unlimited):** Injects one false intel fragment into any village the Spymaster has visited. Appears as genuine intel at Stranger–Acquaintance tier. Bard clan can detect it at Regular+.

#### Wonder `[UNIMPLEMENTED]` — Grand Archive
All village intel automatically decoded at Regular tier. Planted rumors immediately identified regardless of INT stat. Bard with Grand Archive has Trusted-equivalent intel from turn 1 at any village it visits.

#### Playstyle
Bard is the information warfare specialist. INT shrine bonuses accelerate pub relationship building and improve rumor detection. The natural shrine knowledge broker — deposits knowledge at Contemplation Halls for gold, detects fake credits at Saltmere, and sells planted rumors to misdirect rivals.

**Shrine run approach:** Charm spell (T2) on defenders — target fights for the Bard for 3 turns, blocking its own clan's defenders. Bard Clan Unit's Shrine Reader means you always know exactly which shrines every rival has — plan the most cost-efficient Avatar path.

**Dragon approach:** Bard is least effective in direct Dragon combat (ATK 2). Strategy: sell shrine credits early for gold, use that gold to hire mercenary protection (rights deals that create obligation), and arrive at the Dragon's Keep with allies who fight while the Bard Seeker grabs the egg.

---

### Shaman
*"The storm has always known where it wants to go."*

**Colour:** Storm grey `[155, 142, 160]`  
**Shrine bonus:** `arc_elem` — +1 ARC (elemental) — overlay stat enhancing elemental spell damage  
**Magic tier:** 4 — T1–T4 spells (Lightning, Curse, Mass Haste, Reanimate)  
**Shrine name:** Shrine of the Storm

#### Clan Unit — Shaman
| ATK | DEF | MOV | HP | VIS | MP |
|-----|-----|-----|----|-----|----|
| 3 | 2 | 3 | 5 | 2 | 20 |

**Passive — Area Amplifier:** All AoE spell damage +1 on every cast by this unit. Fireball hits for 5 instead of 4. Lightning Storm hits for 7 instead of 6.

**Note on `arc_elem` stat:** Elemental ARC bonus applies specifically to Lightning-type spells (Lightning, Lightning Storm, Stormcaller ability). `effective_stat(unit, 'arc_elem')` returns the elemental bonus; added to base damage of Lightning spells.

#### Specialty Unit — Stormcaller
| ATK | DEF | MOV | HP | Cost |
|-----|-----|-----|----|------|
| 3 | 2 | 3 | 6 | 120g / 5t |

**Unlock:** Barracks II + Spirit Lodge (Lodge also gives +1 to Lightning Storm base damage for all Shaman units)

**Ability — Lightning Storm Enhanced:** Deals 6 base + 1 (Area Amplifier) = 7 damage to ALL units in a 3-hex radius (including friendlies). T4 spell — causes exhaustion HP. With Storm Spire wonder: 9 damage, 4-hex radius, the most destructive area attack in the game.

#### Wonder `[UNIMPLEMENTED]` — Storm Spire
All area spells deal +2 damage and hit +1 radius larger. Lightning Storm becomes 9 damage, 4-hex radius. Positions the Shaman clan as the area devastation faction in the Gauntlet phase.

#### Playstyle
Shaman is the area destruction specialist. ARC_elem shrine bonuses amplify Lightning spell damage — a fully-meditated Shaman clan's Lightning spells deal massive bonus damage. Storm Spire Lightning Storm at 9 damage/4-hex radius is a Dragon-killing weapon if Lightning is the Dragon's weakness this game.

**Shrine run approach:** Mass Haste (T4) before a shrine run — all friendly units +2 MOV for 3 turns, enabling fast approach and departure. Lightning Storm clears the departure ring if defenders cluster.

**Dragon approach:** Lightning is one of three possible Dragon weaknesses. If Lightning is this game's Dragon weakness (+3 damage per hit), Shaman + Stormcaller Lightning Storm becomes the premier Dragon-fighting combination in the game. Storm Spire makes it devastating.

---

## Stat Key: Shrine Bonus Stat Names

| Clan | Shrine bonus stat key | Meaning |
|------|----------------------|---------|
| Fighter | `atk` | +1 ATK to all clan units |
| Mage | `vis` | +1 VIS to all clan units |
| Cleric | `def` | +1 DEF to all clan units |
| Dwarf | `end` | +1 END (max HP) to all clan units |
| Ranger | `mov` | +1 MOV to all clan units |
| Elf | `arc` | +1 ARC to all clan units |
| Rogue | `stl` | +1 STL to all clan units |
| Monk | `res` | +1 RES to all clan units |
| Druid | `lck` | +1 LCK (luck roll shift) |
| Necromancer | `atk_dark` | +1 ATK overlay to Necromancer Clan Units |
| Bard | `int_stat` | +1 INT (NOT "int" — key is `int_stat`) |
| Shaman | `arc_elem` | +1 elemental ARC to Lightning spells |

**Implementation note:** `atk_dark` and `arc_elem` are overlay bonuses — they apply to specific unit types or spell types rather than to the entire stat. See `effective_stat()` in units.md for full computation.

---

## Avatar Bonus — Physical vs. Purchased

When a unit meditates a shrine physically, it receives:
1. **+2** to the shrine's bonus stat (meditating unit only, personal)
2. **+1** to the shrine's bonus stat (all clan units, clan-wide)
3. Avatar credit checkmark

When credit is purchased at a Contemplation Hall or traded:
1. Avatar credit checkmark only
2. **No stat bonus** — the physical act of discovery is required for the bonus

The gap matters. A clan that physically meditates all 8 shrines has 8 stat bonuses applied to every unit and the Seeker at production. A clan that purchased 4 credits has only 4 bonuses. The Seeker produced by the latter is detectably weaker.