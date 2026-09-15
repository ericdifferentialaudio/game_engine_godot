# Wardens of the Verdant Hush

**Recommended format:** 3D FPS (real-time combat, first-person intimacy with a weapon that visibly changes under your hands)

## Logline

A newly bonded Warden of a dying, sentient forest must decide whether to fight to preserve it as it is, or help it finish transforming into something the world has never seen — armed with a blade that is alive, and that grows or starves based on how they fight.

## Setting

**The Hush** is a continent-spanning living forest, its magic carried through an ancient network of trees called the **Sap-Kin**. A century ago the Hush began **the Turning** — not decay, not disease, but a slow, deliberate, self-directed transformation into an unknown next form. The Hush is not dying by accident. It is choosing to end its current age.

The player is a newly bonded **Warden**, whose weapon — a **Sap-Blade** — is a living organism grown from a seed bonded to their own blood at the moment of initiation. It is not carried. It is raised.

## Core Mechanic: Growth and Decay Instead of Ammo and Mana

The Sap-Blade (and later, armor) must be **fed** specific resources harvested from combat and exploration:

- Feed it aggressively with **Resin Marrow** (harvested from corrupted wildlife) and it grows powerful — but hungrier, and prone to **feral overgrowth**, a state where the weapon mechanically biases the player toward violence, demanding more kills to stay stable rather than just narratively implying bloodlust.
- Starve it deliberately, or feed it **Hush-Milk** instead, and it redirects toward **Bloom forms** — slower, defensive, supportive mutations that can shield or heal allies instead of harming enemies.

The weapon's visible shape is a permanent, wordless record of how you've played — no menu, no meter, just a blade that looks different depending on what you fed it.

## Central Tension

There is no clearly correct side. The core question the game refuses to answer for the player is **preserve or release**:

- Fighting to keep the Hush alive in its current form means freezing an ecosystem that has already chosen to end — a kind of well-intentioned cruelty.
- Helping it complete the Turning means assisting the transformation of the only world its people have ever known into something that might not have room for them in it.

Factions genuinely disagree, and neither is telegraphed by the game as "correct."

## Notable Items

- **Seed of First Bloom** — the player's starting weapon-seed, grown from their own blood; visually and mechanically unique per playthrough based on how it's fed.
- **Resin Marrow** — feeds a weapon toward raw, unstable aggressive Bloom.
- **Hush-Milk** — a rarer resource that redirects growth toward supportive, protective Bloom forms.
- **The Widow Bark** — armor grown from a tree that survived a previous Turning. Wearing it lets the player hear the memories of past Wardens who bonded with it — and slowly begins replacing the player's own memories with theirs.

## Factions

- **The Bough-Wardens** — want to preserve the Hush exactly as it is, by any means necessary.
- **The Turning-Faithful** — believe resisting the Hush's transformation is itself the cruelty, and that Wardens should help it end.
- **The Sapless** — humans who've abandoned living weapons entirely, viewing all Wardens, on either side, as complicit in something monstrous.

## Story Arc (suggested)

1. **Bonding** — the player's Sap-Blade seed takes root; early missions teach the feed/starve mechanic against small corrupted wildlife with low stakes.
2. **Divergence** — the player's weapon has visibly grown one way or another by now, and factions start reacting to *what the blade looks like*, not just what the player says.
3. **The Turning's Edge** — the Hush reaches the final stage of its transformation. The ending isn't a dialogue choice — it's determined by whether the player's own weapon, after however many hours of feeding choices, is closer to a Bloom of preservation or a Bloom of release.

## Fits the Shared Resource Schema

The Sap-Blade's growth state is a natural `unit`-attached resource with a `growth_vector` (aggressive/supportive weighting) rather than a flat stat block — a good test of whether your shared `core/data/units/` schema can carry a *mutable, visually-expressed* state rather than only static definitions.
