# Aevum — Shrine Mantras
# Verified against engine/engine_mantras.py MANTRA_POOL 08/24/2026 (batch 2) — matches exactly.
# 100 invented words across 10 phonetic families.
# World gen draws 8 per game (one per shrine), seeded, no repeats.
# Each mantra is unknown to all clans at game start.
#
# MEDITATION TIERS (turns required):  ← LOCKED #169 (Sprint 23 — tripled from Sprint 22)
#   Direct discovery (NPC teaches in person):  2 turns
#   Secondhand confidence ≥0.70:               4 turns
#   Secondhand confidence 0.40-0.69:           6 turns
#   Secondhand confidence 0.10-0.39:           8 turns
#   Unknown:                                   10-14 turns (seeded per shrine)
#
# DISCOVERY SOURCES (direct):
#   Castle Scholar (keyword: mantra/shrine) — teaches nearest shrine's word
#   Hermit NPC (world map or island) — knows 2-3 mantras
#   Dungeon/ruin scroll — one shrine's mantra
#
# DISCOVERY SOURCES (secondhand):
#   Barkeep (Trusted+ relationship) — conf 0.50-0.75
#   Population gossip (#128)         — conf drifts per distance
#   Diplomat trade                   — conf = traded value
#
# CLAN MODIFIERS:
#   Bard:   secondhand +0.15 confidence
#   Rogue:  pub leak × 0.5 (harder for rivals to overhear)
#   Shaman: secondhand −0.10 confidence
#
# VULNERABILITY: DEF=1 throughout all meditation turns.
#   Any attack interrupts: all progress lost.
#   Unit enters waking state DEF=2 for 1 turn, then full DEF restored.
#   Direct knowledge: never degrades, never overwritten by secondhand.
#   Secondhand: confidence drifts down over time (per #128 dissemination rules).
#
# BAD WILL: Attacking a meditating unit costs +1 virtue debt (same clan as attacking).

---

## Family 1: Ael-
Aevel
Aemos
Aethis
Aelvar
Aendor
Aelith
Aemov
Aethar
Aelvorn
Aendris

## Family 2: Vel-
Velorn
Velmis
Velauth
Veldris
Velkaar
Velnoth
Velsuun
Velaum
Veldoch
Velthis

## Family 3: Cor-
Corath
Corvel
Cornis
Corthem
Corvaal
Corleth
Cornuul
Corvaen
Cortis
Corveth

## Family 4: Sul-
Sulveen
Sulmar
Sulthem
Sulvaen
Sulkith
Suldorn
Sulveth
Sulnaar
Suleim
Sulvaris

## Family 5: Dre-
Dreth
Drevorn
Dremis
Drethaal
Drevlis
Drenmor
Drethuul
Drevaal
Drenmis
Drethis

## Family 6: Om-
Omnavar
Omveth
Omthaas
Omliis
Omvaar
Omthuul
Omnavis
Omvorn
Omtheis
Omlivar

## Family 7: Kai-
Kaiel
Kaivar
Kaithis
Kaidorn
Kailem
Kaiveth
Kaithaal
Kaimuun
Kaivorn
Kaithel

## Family 8: Thu-
Thuris
Thuvel
Thunaar
Thuvorn
Thuleis
Thumaas
Thuvaal
Thuneth
Thuvelis
Thulvar

## Family 9: Orn-
Ornavel
Ornmis
Ornveth
Ornthaas
Ornleis
Ornvaar
Ornthuul
Ornveis
Ornlivar
Ornmath

## Family 10: Myr-
Myrveth
Myraas
Myrleis
Myrvorn
Myrthaas
Myrveis
Myrvaal
Myrlith
Myrthuul
Myrvaris

---

## Shrine Lore: Six New Flavor Texts (T77 — locked)

*Shown when a clan first meditates a shrine or reads a Dragonlore Tablet.*
*Six additional entries below the existing twelve virtue texts in virtues.json.*

### On Shrines Themselves

> The shrines weren't built to remember the virtues. They were built because
> the virtues had almost been forgotten once, and the people who came after
> decided to make them harder to lose the second time.

> Not every shrine looks like one. Some of them are just a stone with a word
> carved into it, in a place where the ground is slightly too still.
> You'll know it when you stand there.

### On Learning the Mantra

> The word isn't the virtue. The word is a door.
> What you find on the other side of the door is the virtue.
> This distinction matters more than it sounds.

> Someone taught someone who taught someone who taught you.
> The word degrades a little each time. If you got it wrong,
> you'll know: the ground won't hold you still.

### On What Meditation Does

> Nothing happens immediately. That's how you know it's real.
> If you felt it the moment you sat down, it was probably just relief.
> The actual thing takes longer and feels like nothing, and then afterward
> you notice something is different.

> There are clans who've meditated every shrine and still don't know
> what they were doing. There are clans who've meditated one shrine and
> understood everything. The process is not the point.
> The point is that you showed up.
