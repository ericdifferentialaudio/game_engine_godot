# The Hollow Ledger

**Recommended format:** Isometric (turn-based/tactical, hub-and-mission structure)

## Logline

An apprentice debt-auditor for a bureaucracy that magically tracks every unpaid obligation — financial, emotional, and blood — must settle a backlog of unresolved "Weight" in a fringe town before it births something that remembers everything it's owed.

## Setting

Centuries ago, the god of Balance, **Aurelic**, vanished after absorbing every debt ever owed between mortals into himself, trying to end a war fought entirely over broken promises. He never came back. What he left behind is a magical bureaucracy: **Ledgerhouses**, half-religious institutions staffed by **Auditors**, who track *Weight* — a literal, measurable residue that accumulates wherever an obligation goes unresolved. Enough unresolved Weight in one place eventually curdles into a **Hollow**: a spectral entity built from guilt, grudge, debt, or a promise never kept.

The player is a **Tallykeeper** — the lowest rank of Auditor — sent to the fringe town of **Emberreach**, where three generations of unaudited Weight are about to come due at once.

## Core Mechanic: The Ledger, Not a Meter

Where a lot of games (Ultima IV included) track morality as a single internal score, this game tracks Weight as a **graph of individual entries** between the player and dozens of named NPCs, factions, and places. There is no unified "good/evil" axis. Each entry can be resolved differently:

- **Repaid** — costs you time, resources, or a favor owed elsewhere.
- **Forgiven** — costs the other party nothing, but the debt never fully disperses; it lingers as a smaller, permanent trace.
- **Forced closed** — using an Auditor's Seal to cancel a debt by threat or violence. Fast, but always leaves a Hollow fragment behind as residue.
- **Sold** — transferred to a Debt-Broker or rival Auditor, who will collect on your behalf, on their terms, which you don't control.

Two players can both be "excellent Auditors" while playing nothing alike — one a strict collector, one a serial forgiver — and Emberreach's factions will remember and react to *which* debts you chose to enforce, not just a hidden number going up or down.

## Central Tension

The Ledgerhouse's High Auditors want the books balanced completely — every debt collected, however cruel — because unresolved Weight is what feeds the next Hollow. But every forced collection risks generating exactly the resentment that creates new Hollows in turn. There is no version of "doing your job well" that fully avoids this trade-off.

## Notable Items

- **Tally-Chalk** — inscribes a debt directly onto a person, wall, or object, making it visible and trackable to anyone who can read it. Useful; also makes you feared.
- **Promissory Coin** — currency literally minted from forgiven debts. Spending it passes a fragment of the original debt's emotional weight to whoever receives it.
- **The Unspent Name** — a debt no one has ever tried to collect, belonging to someone who vanished long ago. Carrying it draws Hollows to you unnaturally.
- **Auditor's Seal** — forcibly closes a ledger entry on the spot. Always effective. Always leaves something behind.

## Factions

- **The Ledgerhouse** — the bureaucratic order itself, more divided internally than its uniform robes suggest.
- **The Debt-Free** — a fringe cult that ritually erases its own debts *and memories* to become "unaccountable" to anyone, including themselves.
- **Debt-Brokers** — a black market trading in other people's obligations, treating Weight as a commodity rather than a moral fact.

## Story Arc (suggested)

1. **Arrival** — the player audits Emberreach's small, personal debts (a stolen tool, a broken engagement, an unpaid midwife) and learns the ledger mechanic through low-stakes cases with real texture.
2. **Escalation** — a generational debt surfaces: the town's founding families owe something enormous to a group they displaced decades ago, and both sides want the player to rule in their favor.
3. **Reckoning** — the accumulated Weight of the town's founding debt is about to birth a Hollow large enough to consume Emberreach outright. The ending depends on the *pattern* of how the player has been resolving debts all game — collector, forgiver, seller, or some mix — not a single climactic choice.

## Fits the Shared Resource Schema

Every debt, item, and NPC relationship in this game is expressible as a `token` with a `Weight` attribute and a `resolution_state` field — a natural fit for the shared `core/data/tokens/` tree you're building across both engines, and a good stress-test for whether the schema handles relational data (debts *between* two named entities) and not just flat item stats.
