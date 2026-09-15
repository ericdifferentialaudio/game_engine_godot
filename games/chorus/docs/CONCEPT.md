# The Chorus of Unspoken Names

**Recommended format:** Isometric (dialogue-dense investigation, persistent hub-city that visibly changes based on what you tell it)
*(Flexible — could work as a slower first-person exploration game if you want a third 3D entry instead)*

## Logline

An apprentice to the city's official historian must investigate the truth behind seven buried, contradictory catastrophes before their first public Recitation — knowing that whatever version of history they choose to tell will become the truth everyone remembers, whether or not it's the one that actually happened.

## Setting

**Verrow** is a city-state built atop the ruins of seven previous cities, each destroyed by a catastrophe that has never been told the same way twice. Verrow has a strange institution to manage this: the **Namesayers**, legally required to publicly recite the "true" history of the city once a year. No two Namesayers have ever agreed on what that history is — and disagreeing publicly has, more than once, gotten someone killed.

The player is a newly appointed **Namesayer's Apprentice**, tasked with investigating what actually happened before their first Recitation.

## Core Mechanic: Testimony, Not Truth

Instead of a virtue meter, the resource the player manages is **conflicting testimony**. NPCs across Verrow hold different, often incompatible accounts of both historical and present-day events. Using a **Recollection Instrument**, the player can:

- **Record faithfully** — preserve a testimony exactly as given, contradictions and all.
- **Soften** — edit a testimony to be less painful, more comforting, easier for the city to hear.
- **Sharpen** — edit a testimony to provoke a specific reaction, weaponizing it toward an outcome the player wants.

Whatever the player does with a testimony doesn't just affect their own reputation — it **permanently changes what the population of Verrow believes happened**, which changes how factions and individuals behave in every subsequent chapter. There is often no clean, verifiable "true" account underneath it all, only more or less examined ones. The game doesn't track whether the player told the truth. It tracks whether their Recitations left people more able to make good decisions, or more comfortable and less prepared.

## Central Tension

This directly inverts the premise of a single objective virtue score: **truth itself is the contested resource.** A comforting lie can hold a city together for another generation. An inconvenient truth can tear it apart in a week — and still be the right thing to say. The player has to decide, testimony by testimony, which kind of Namesayer they're becoming, with no institution telling them which choice is correct.

## Notable Items

- **Recollection Horn** — the Namesayer's core instrument; records, edits, and later broadcasts testimonies as real in-game events that visibly change the city.
- **Tarnished Ledger-Bead** — small tokens holding a single fragment of memory. Give one to an NPC to restore a forgotten detail to them; destroy one to erase it permanently from the game's own memory of events.
- **The Seventh City's Key** — opens not a door, but a testimony vault beneath Verrow, revealing a history that outright contradicts the city's official founding myth.
- **Apprentice's Chalkboard** — an in-fiction journal for cross-referencing conflicting accounts side by side.

## Factions

- **The Namesayers' Chorus** — the institution itself, more divided internally than its public unity suggests.
- **The Founders' Loyalists** — want the comforting official myth preserved, whatever the cost to accuracy.
- **The Diggers** — want every buried truth exposed, regardless of what it costs the city to hear it.

## Story Arc (suggested)

1. **Apprenticeship** — small, low-stakes testimonies (a marriage dispute, a missing tool, a minor accident) teach the record/soften/sharpen mechanic and show how quickly a "small" edit ripples outward.
2. **The Sixth City** — the player uncovers testimony suggesting the most recent catastrophe wasn't the accident it's remembered as. Factions start actively lobbying the player on how to frame it before the next Recitation.
3. **The Recitation** — the player delivers their first public account of Verrow's history, built entirely from the pattern of choices made all game. The ending is which version of the city's past — and by extension its future — the player has actually built, not a binary win/lose state.

## Fits the Shared Resource Schema

Testimonies are naturally expressible as `token`s carrying a `fidelity` attribute (faithful/softened/sharpened) and links to the NPCs and events they reference — a good test of whether your shared `core/data/tokens/` schema can represent narrative/informational objects, not just physical items, which is worth settling early if this game and the other two are meant to share one resource tree.
