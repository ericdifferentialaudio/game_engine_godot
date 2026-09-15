# Clan Lore — Aevum: Age of Shrines
## Design Reference Document

> This document records canonical lore for all 12 playable clans, the 3 inherent
> rivalries, and how these manifest in gameplay. Implemented in `engine_sentiment.py`
> via `CLAN_INHERENT_RIVALRIES`. Referenced by pub dialogue, NPC interactions, and
> the AI diplomacy system.

---

## The 12 Clans

### Fighter
*"We fight openly. If you can't say it to my face, you have no business saying it at all."*

The Fighter clans are the oldest military tradition in Aevum. They came before the shrines,
before the Convergence, before the formal clan system. They are warriors by culture, not by
necessity — they choose direct confrontation as a moral stance, not just a tactical one.

**Virtue**: Valor  
**Shrine clan**: Fighters built the Shrine of Valor and consider it their moral centre.  
**Allies**: Natural allies with Dwarves and Clerics — they share the value of standing in
place and holding.  
**Inherent rival**: **Rogues.** The Fighter code says you face your enemy. Rogues stab from
behind and call it tactics. Fighters don't dispute the effectiveness — they dispute the ethics.
A Fighter who loses to a Rogue doesn't feel defeated. They feel insulted.  
**On Rangers**: Respect without warmth. Rangers don't fight the Fighter way, but they fight
for comprehensible reasons and don't lie about it.

---

### Mage
*"The Arcanum exists because power without structure becomes catastrophe. We've seen it happen."*

Mages are the institutional power of the arcane world. The Arcanum — their central body of
knowledge and governance — sets rules for what magic can and can't be studied. This isn't
about morality. It's about not destroying the world by accident. They've been wrong before.
They believe they're mostly right now.

**Virtue**: Wisdom  
**Shrine clan**: The Shrine of Wisdom is their philosophical foundation.  
**Allies**: Natural alignment with Scholars, Bards (knowledge is power, power is knowledge),
and the diplomatic structures of castle towns.  
**Inherent rival**: **Necromancers.** The Arcanum expelled the first necromancers for studying
"impure" magic. Mages maintain the expulsion was correct — the knowledge was dangerous and
the practitioners were reckless. What they won't admit is that some of the expelled work was
brilliant and the Arcanum was also protecting its own monopoly.  
**On Clerics**: Uneasy respect. Clerics got to similar places through different methods.
The Arcanum considers this philosophically suspect and practically workable.

---

### Cleric
*"Everyone suffers. Everyone bleeds. I've stopped asking which clan they're from before I help."*

Cleric clans grew out of the healing traditions around the old shrines. They're not a religion
exactly — they're a practice. They've developed ethics from what they've seen, and what they've
seen is that suffering is distributed without regard to virtue, allegiance, or clan. This has
made them universalists by evidence rather than by doctrine.

**Virtue**: Compassion  
**Shrine clan**: The Shrine of Compassion is theirs, and they've had it longer than most.  
**Hate no one**: Clerics serve everyone. They've set bones for Fighters and Rogues in the same
tent. They've administered last rites to Necromancers. They understand that hatred is a wound
that spreads — they've treated enough of it.  
**Allies**: Wide-ranging. Clerics can work with almost anyone because almost everyone needs
what they offer at some point.  
**On the inherent rivalries**: The Cleric view is that the dwarf/elf hatred is a tragedy that
has cost more than anyone has gained. They're right. Nobody asked them.

---

### Dwarf
*"We were here before the forests. We'll be here after them."*

Dwarf clans are mountain people — patient, stubborn, and deeply connected to the physical
substance of the world. They build things that outlast them. They remember grudges the same way.
Not with heat — with stone. Cold. Permanent. The feud with the Elves started over border
territories three generations back and has never been formally resolved, which means it's
still technically active.

**Virtue**: Loyalty  
**Shrine clan**: Dwarves swear to stone, to lineage, to things that outlast a single life.
Their Shrine of Loyalty reflects this.  
**Inherent rival**: **Elves.** The specific origin of the feud has been told so many different
ways by both sides that the truth is unrecoverable. The functional reality: the mountain passes
at the forest border have been contested for three generations. Each side has raided the other.
Each side has a list of grievances. Neither list has a line at the bottom marked "this settles it."
Dwarves don't hate Elves the way Fighters hate Rogues — they don't despise Elf culture. They
just don't forgive the border raids. That's enough.  
**On Fighters**: Natural allies. Both cultures value standing your ground.

---

### Ranger
*"The forest doesn't take sides. Neither do I."*

Rangers live by a wilderness code that pre-dates clan politics. They read terrain. They track.
They move through the world with minimal disturbance and notice everything. They'll fight anyone
who disrespects the land or blocks their path — but it's professional, not personal. They've
worked with every clan at some point and maintained grievances with none of them, which some
other clans find suspicious. It isn't. It's just discipline.

**Virtue**: Spirituality  
**Shrine clan**: Rangers built the Shrine of Spirituality and approach it as navigation —
finding the space between what's visible and what's real.  
**Hate no one**: Rangers have a principle: the land doesn't care. Neither do they, about clan
flags. What they care about is whether you're useful or a problem. Most clans are neither.  
**Natural affinities**: Rogues (shared stealth capability, practical ethics), Druids (shared
land ethic).

---

### Elf
*"Honour isn't ceremony. It's conduct over time. Ask us in three generations whether we kept it."*

Elf clans think in longer timeframes than anyone else. This has made them patient, occasionally
arrogant, and deeply invested in the concept of honour-as-record rather than honour-as-performance.
They remember everything. They forgive slowly. They hold grudges the way they hold promises:
permanently and quietly.

**Virtue**: Honour  
**Shrine clan**: The Shrine of Honour is theirs — not ceremony, but conduct.  
**Inherent rival**: **Dwarves.** The Elves remember exactly when the border raids started. They
have the date. They have the specific mountain pass. They have the names. What they don't have
is any interest in resolving it until the Dwarves acknowledge what happened — which the Dwarves
won't do because the Dwarves have a different version of events that is also internally
consistent. The feud continues.  
**On other clans**: Elves aren't hostile by default. They're evaluating. Every interaction is
being added to a long record. They treat new clans the way they treat new relationships: with
careful observation before commitment.

---

### Rogue
*"Honour is a story rich people tell about their wins. I get results. That's the whole of it."*

Rogue clans are pragmatists. They're not amoral — they have their own code, built around
honesty about outcomes. They don't romanticize combat. They solve problems with the method
that works. This makes them excellent at certain things and impossible to diplomatically trust
without leverage, because their commitments last as long as their interests align.

**Virtue**: Truth  
**Shrine clan**: Rogues built the Shrine of Truth, which they understand as: knowing exactly
what's real so you can act on it precisely. Not confession — accuracy.  
**Fighter relationship**: Rogues find Fighters mildly amusing. The Fighter code is a rule
Fighters made up about how fights should be fought, and then declared universal. Rogues don't
declare anything universal. They just work. They're not offended by Fighter contempt —
they've profited from it too many times.  
**Natural affinities**: Rangers (shared practical ethics), Bards (shared information trading).

---

### Necromancer
*"The Arcanum threw us out for asking questions they didn't want answered. We kept asking."*

Necromancer clans came out of the Arcanum expulsion with one thing intact: the conviction that
the expelled research was correct and the expulsion was political. They study what happens to
things after death — the residue, the transition, the accounting of what was and what remains.
They don't celebrate death. They study the cost of things. The Shrine of Sacrifice is theirs.

**Virtue**: Sacrifice  
**Shrine clan**: The Shrine of Sacrifice records what things cost. Not punishment — accounting.  
**Inherent rival**: **Mages.** Necromancers resent the Arcanum with a specificity that only
comes from having been inside the institution. They know which rules were genuine safety
measures and which were turf protection. The mages who run the Arcanum now weren't there for
the expulsion, but they inherited the position that the expulsion was correct. Necromancers
inherited the position that it wasn't. Neither side has reason to update.  
**On other clans**: Necromancers are more pragmatic than their reputation suggests. They'll
work with anyone who doesn't insist they stop their research.

---

### Monk
*"The ego is the first obstacle. Remove it and the problem usually solves itself."*

Monk clans practice a discipline built around removing the self from the equation so the
right action can happen. This sounds passive. It isn't. It produces a specific kind of
clarity that makes them effective in situations where everyone else is reacting emotionally.

**Virtue**: Humility  
**Shrine clan**: The Shrine of Humility is theirs — not self-erasure, but removing ego
so the work can happen.  
**Hate no one**: Monks have the same universalist non-attachment as Clerics, but for
different reasons. Clerics serve everyone because everyone suffers. Monks don't take sides
because sides are ego in political form. The result looks similar from the outside.  
**Natural affinities**: Clerics (shared service orientation), Fighters (shared discipline).

---

### Druid
*"The right action at the right time in the right amount. That's all. That's everything."*

Druid clans understand Temperance not as restraint but as calibration — the correct response
to the situation at hand, which is sometimes overwhelming force and sometimes stillness. They
move with the seasons. They fight when it's time to fight. They don't rush.

**Virtue**: Temperance  
**Shrine clan**: The Shrine of Temperance is theirs.  
**Hate no one**: Druids are land-focused rather than clan-focused. Their grievances are with
actions, not identities. Logging a sacred forest is a problem. The clan that does it is a
problem insofar as they're doing it. Elsewhere, neutral.  
**Natural affinities**: Rangers (shared land ethic), Shamans (shared nature-connection).

---

### Bard
*"I'll tell you everything I know honestly — once I've decided you're worth telling."*

Bard clans are information traders who have built a culture around the value of truth in
motion. They collect, curate, and distribute knowledge — pub dialogue, court songs, rumour
networks, formal records. Their Shrine of Honesty is built on a specific understanding: not
confessional honesty, but accuracy. Know what's real. Say what's real. Act on what's real.

**Virtue**: Honesty  
**Shrine clan**: The Shrine of Honesty.  
**Hate no one**: Bards have professional relationships with every clan. Their information
only has value if they can talk to everyone. Grudges are bad for the network.  
**Natural affinities**: Rogues (information trading), Mages (knowledge as power), Rangers
(accurate observation).

---

### Shaman
*"Justice isn't law. It's balance. The difference matters."*

Shaman clans built their culture around balance — the natural kind, not the legal kind. They
understand systems. They watch what happens when a thing is out of proportion. They intervene
with the minimum required force. They've been called difficult because they insist on proportion
when others want maximum force or no force at all.

**Virtue**: Justice  
**Shrine clan**: The Shrine of Justice.  
**Hate no one**: Shamans don't start with hatred. They start with observation. They've been
exiled from groups for demanding proportionate responses. They've learned to be selective
about their affiliations. They're not hostile — they're careful.  
**Natural affinities**: Rangers (shared observation ethics), Monks (shared proportion
discipline), Clerics (shared service orientation).

---

## The Three Inherent Rivalries

### 1. Dwarf ↔ Elf — The Border Feud

**Mechanical expression**:  
Both clans start the game with `rivalry: 0.50`, `hostility: 0.35`, `grudge: 0.30` toward
each other. These are hard-seeded in `init_inter_clan_sentiments()`.

**AI behaviour**:  
When a Dwarf clan evaluates attack targets and an Elf clan is visible, the `attack_rival`
goal receives +0.25 from `inherent_rival_aggression_boost()`. Dwarf AIs will prioritize
attacking Elves over equally-positioned rivals of other clans.

**Alliance restriction**:  
Dwarf and Elf cannot form an alliance unless both clans have ≥ 8 INF. This represents the
political will required to overcome three generations of enmity. It's possible. It's hard.

**Dialogue**:  
Pub NPCs reference the feud as established fact. No clan has to explain it. The barkeep
mentions it the way people mention weather — it's just always been there.

---

### 2. Necromancer ↔ Mage — The Arcanum Split

**Mechanical expression**:  
Necromancer starts with `rivalry: 0.45`, `grudge: 0.40`, `hostility: 0.30` toward Mage.  
Mage starts with `rivalry: 0.40`, `hostility: 0.25`, `grudge: 0.30` toward Necromancer.  
(Mage's hostility is slightly lower — disdain rather than rage.)

**AI behaviour**:  
Necromancer AI prioritizes attacking Mage clans (+0.25 to `attack_rival`). Mage AIs also
get the boost but slightly lower effective hostility floor means they prioritize other threats
first in a crowded game — they'll still go for Necromancers when opportunity exists.

**Alliance restriction**:  
Both clans need 8 INF each to override. The Arcanum position is official. Overriding it
is a political statement.

**Dialogue**:  
Scholar NPCs reference the Arcanum expulsion as historical fact. It's not controversial —
it's documented. What's contested is whether it was right.

---

### 3. Fighter → Rogue — The Honour Dispute

**Mechanical expression**:  
Fighter starts with `hostility: 0.40`, `rivalry: 0.30` toward Rogue.  
Rogue starts with **no inherent values** toward Fighter. One-sided.

**AI behaviour**:  
Fighter AI prioritizes Rogue clans when evaluating attack targets (+0.25). Rogue AI
treats Fighters like any other clan — no special preference.

**Alliance restriction**:  
Fighter needs 8 INF to override their own hostility and form a Rogue alliance.
Rogue needs no INF override — they're not hostile, just not trusting. The restriction
is one-directional because the enmity is one-directional.

**Dialogue**:  
Guard NPCs of Fighter affiliation are notably cold toward Rogue-type units. Fighters
in pub dialogue reference Rogues with contempt when the topic arises. Rogues in pub
dialogue reference Fighters with faint amusement.

---

## Neutral Clans

**Rangers**: Hate no one. Will fight anyone who crosses their path or disrespects the land.
The code is not about avoiding conflict — it's about not personalizing it.

**Clerics**: Hate no one. The Compassion virtue is active, not passive. They've patched up
enough wounds to know that hatred opens more than it closes.

**Monks**: Hate no one. The Humility virtue removes the ego from the calculation.
Sides are ego in political form.

**Druids**: Hate no one. Their grievances are with actions (specific ecological damage),
not clan identities.

**Bards**: Hate no one. Their network requires access. Grudges are bad for business.

**Shamans**: Hate no one. Their justice is about balance, not alignment. They'll call out
any clan for disproportionate action — they won't pre-assign it.

---

## Gameplay Notes

- The inherent rivalries are **seeded at game start** and are permanent floors.
  Normal sentiment decay will never bring them below 30% of initial values
  (`_INHERENT_FLOOR_RATIO = 0.30`).

- If a game does **not** include both clans of a rival pair, the rivalry is simply
  not seeded — it has no effect. A game without Dwarves or Elves is neutral.

- The rivalries create **emergent dynamics** in larger games: if Dwarves and Elves
  are both present, other clans will notice that they're likely to be fighting each
  other and may exploit the distraction.

- **Peace is possible**. 8 INF each is not cheap, but it's achievable mid-game.
  A Dwarf-Elf alliance against a common threat (Avatar-approaching Necromancer,
  for example) is one of the most surprising and strategically interesting outcomes
  the system can produce.
