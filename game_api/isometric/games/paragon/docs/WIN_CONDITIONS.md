# Win Conditions — What Is Required to Beat the Game

The **checklist view** of the run: the end goal, the minimum required set, the tree in compact form, the
shortest route, and what is *not* required. For the formal tree with the inner-road commentary read
`QUEST_TREE.md`; for the full player experience and every optional encounter read `GAMEPLAY.md`.

Related: `CRITICAL_PATH.md` (the five acts), `ITEMS.md §4` (key items), `SET_PIECES.md`, `WITNESS_LOG.md`.

---

## 1. The end goal

Reach the **Chamber** at the bottom of the end-dungeon island and pass **two graded questions**:

1. *"What is the one thing that binds the eight?"* — **type the Binding Word**: this seed's label for one of
   twelve binding principles, chosen at generation by affinity to the drawn eight (`QUEST_TREE.md §4.0`).
2. *"Where does {word} live between {A} and {B}?"* — pick **two virtue-lines** you have actually heard or read
   (`held_day != null`); they must be the lines of virtues A and B.

Then one **ungraded** question — *"And what didst thou find it to mean?"* — free text, written verbatim to the
Book of Paragons. Then act on `{artifact_end}` (weave / strike / sound). **That is the win.**

Nothing else in the game is graded for the win. The twelve Chamber questions, the four doors, the Mirror, the
Trials of Tension, Wisdom, and every virtue counter shape only the **epilogue** (`CRITICAL_PATH.md §7`).
Failure at the Chamber is never final: you are returned to the surface, re-meditate Humility (whose vision
now gives all eight lines and names the three roads), and may try again without limit.

## 2. Minimum required set (hard requirements)

| # | Requirement | Count | Gate kind | Where |
|---|---|---|---|---|
| 1 | **Virtues granted** — know the mantra, stand at the correct shrine | **8 / 8** | knowledge | 8 shrines |
| 2 | **Stones** lifted from dungeon level 8 (behind the third temptation floor) — liftable **only after #1 is complete** | 8 | item | 8 vice dungeons |
| 3 | **Sigils** hidden in each virtue's town | 8 | item | 8 towns |
| 4 | **Sigil Ring** (show the first stone to `{ruler}`) + **8 bindings** (stone N + sigil N at altar room N) — the 8th, in the Pride dungeon, opens the end-island passage | 1 + 8 | item + deed | royal seat; 8 altar rooms |
| 5 | **The Horn** | 1 | item | Bell in the Deep / Silent Monastery / Maelstrom Gate (seeded) |
| 6 | **House artifacts** — House password + family trial each | 3 | token + deed | `{castle:f1..f3}` |
| 7 | **Word of Passage** syllables — three keepers, each asks about a virtue *not* their own | 3 | token | House regions / Court / hidden-lake village |
| 8 | **Warding item** — passes Humility's fiends; laid down at Door 1 | 1 | item | the ruined city |
| 9 | **Ghosts' password** — refuse every boast; *"Art thou better than we were?"* → *no* | 1 | dialogue conduct | the ruined city, at night |
| 10 | **Binding Word** — by one of three roads (§3.1) | 1 | token | ruin / Monastery / Hermitage |
| 11 | **Virtue-lines heard** — the two the Chamber asks for | **≥ 2** (of 8) | token | statues / vision / companions / ghosts / dreams / library / market |
| 12 | **Honest answers** at Doors 2–4 (a lie ejects; unlimited retries) | 3 | conduct | Descent L2–L4 |
| 13 | **Name your worst vice** at the Mirror (typed) | 1 | knowledge of self | Descent L5 |

**Mandatory tokens: 50** — 8 mantras · 8 shrine locations · 8 sigil locations · 8 dungeon locations · the
ruined city · the ghosts' password · the horn's location · 3 House passwords · 3 Passage syllables · the
Binding Word · 8 virtue-lines. Every one has ≥2 true sources in ≥2 places (`RULES.md §3.3`); every false
variant has a discoverable refutation.

**Act gates (hard, never bypassable by data):** Act II ← ruler has named the eight · Act III ← ≥4 virtues ·
Act IV ← all 8 virtues · Act V ← Ring bound ×8 ∧ Horn ∧ 3 artifacts.

### 2.1 Explicitly NOT required
- Any **virtue counter** value or band (`DESIGN_REVIEW_2026-09.md §1`).
- Any **side quest**, dilemma, or scenario — all read only at the end.
- Any **set piece** except the **Long Night** (forced camp) and the **Mirror Ford** (the only land approach
  to the island; it tests companions, not you — with no companions it is a crossing).
- **Companions.** The Alone path works with zero; Door 3 reads the log aloud instead.
- **Wisdom**, **food**, the **Temptation**, the moon table, magic items, gold beyond rations.
- **Killing anything.** No node on the trunk is behind a fight (`RULES.md §4.2`).

## 3. The tree (compact)

```
WIN — act on {artifact_end}
└─ THE CHAMBER: type the WORD ✓ · pick the two LINES ✓ · (reflection, ungraded)
   ├─ BINDING WORD [TOKEN] ← THE DEAD   ruined city, night, after Humility; "better than we were?" → no
   │                        | THE SILENT Monastery: watch the abbot bow to the 9th plinth at dawn → kneel there
   │                        | THE STILL  Hermitage past the Mirror Ford: 3 nights, no one speaks, no one leaves
   │                        ✗ FALSE: sold by the Magistrate of Debts (another principle's label; has no lines)
   ├─ 2 VIRTUE-LINES [TOKEN] ← Monastery statues (all 8) · Humility vision (2) · companions at camp (own)
   │                            · the Dead (2) · Anchorite's dreams (3) · royal library (all 8) · market (1)
   └─ THE DESCENT L0–L8  ← gate: RING BOUND ×8 ∧ HORN ∧ 3 ARTIFACTS
      │  L0 Long Night · L1 Ward · L2 Deed · L3 Witness · L4 Unopened · L5 Mirror · L6–7 Tension · L8 Threshold
      ├─ HORN [ITEM] ← its location [TOKEN] (fisher's song / House chart / bell-table)
      ├─ 3 ARTIFACTS [ITEM] ← House password [TOKEN] + family trial [DEED], per House
      ├─ WORD OF PASSAGE [TOKEN ×3] ← 3 keepers (asked at the Threshold)
      └─ SIGIL RING bound ×8 [ITEM]
         ├─ the Ring ← {ruler}, when shown the first stone
         └─ per virtue N: bind STONE N + SIGIL N at altar room N (dungeon N, level 8)
            ├─ SIGIL N [ITEM] ← hidden in town N (hider speaks indirectly; dream / ghost / animal)
            └─ STONE N [ITEM] ← dungeon N level 8, past 3 temptation floors
               └─ ★ LIFTABLE ONLY WHEN ALL 8 VIRTUES ARE GRANTED
                  ├─ VIRTUE 1–7 [VIRTUE] ← MANTRA N [TOKEN] + SHRINE N [TOKEN] → meditate (any order)
                  └─ HUMILITY, the 8th [VIRTUE]
                     ├─ ≥ 4 virtues granted
                     ├─ the ruined city [TOKEN] ← rumour after the 4th shrine / the Seer / any Lore token
                     ├─ MANTRA 8 [TOKEN] ← ghost fragments, one per ghost, at night
                     ├─ ghosts' PASSWORD [TOKEN] ← refuse every boast; answer "no"
                     ├─ WARDING ITEM [ITEM] ← hidden in the city, revealed by the password
                     └─ pass the fiends without striking first [DEED] → meditate
                        └─ ACT I: {ruler} names the eight · anchor mantra (one honesty test) · anchor shrine
```

### 3.1 The three roads to the Word (any one suffices)
| Road | What you must do | Suits |
|---|---|---|
| **The Dead** | after Humility, return to the ruin at night; the last ruler's ghost asks *"Art thou better than we were?"* — say **no** | the talker |
| **The Silent** | be in the Monastery statue hall at **dawn** to see the abbot bow last to the empty ninth plinth; then **kneel** there | the watcher |
| **The Still** | cross the Mirror Ford, walk a day upriver to the Hermitage; **three nights** with no `talk` action and no leaving; the third dawn the Anchorite speaks the word | the waiter |

## 4. How to get there — the critical route

1. **Act I (1–2 h).** Walk to the royal seat; hear the eight (said once — write them down). Back in the anchor
   town: pass the keeper's honesty test → mantra; ask the pointer → shrine; meditate. Companion 1 joins.
2. **Act II (12–20 h).** For each of the other seven: mantra from **two sources** (10–15 % of tokens are false;
   a wrong mantra costs a day), shrine location, meditate. **Pocket the sigil** while you are in each town;
   **note each dungeon's location**. Get a **ship** early (pirates, purchase, or the smuggler quest) — three
   towns, the ruin, the Houses, the Court and the Monastery are across water. Dive dungeons now for loot if you
   like; the stone waits.
3. **Act III (2–3 h).** After the fourth shrine, follow the rumour to the ruined city. At night: collect the
   mantra fragments; **refuse every boast**; answer *no*. Take the warding item. Walk through the fiends
   **without striking first**. Meditate Humility. The vision shows the three roads.
4. **Act IV (4–6 h).** Show a stone → **Ring**. Return through all eight dungeons to level 8 and **bind**; the
   eighth opens the island. In parallel: the **horn** (learn where first), the **three Houses** (password +
   trial), the **three Passage keepers**, **one Word road**, and **hear the lines** — the Monastery statues give
   all eight at once and the Monastery is also a Word road, so it is the efficient stop.
5. **Act V (1–2 h).** Long Night → four doors (**just be honest**) → Mirror (type your worst vice) → two live
   dilemmas → Threshold (speak the Passage word) → Chamber: the word, the two lines, your own sentence.

**Shape of the shortest run:** ~all knowledge, ~zero conduct. That is by design — the counters were never meant
to gate — and it is also the design's chief risk (§6.1, §6.7).


## 5. Where it can go wrong (dead ends that are not dead)

| Trap | What happens | Way out |
|---|---|---|
| Believed a false mantra | shrine refuses; a day lost; logged | the second source; the refutation |
| Said *yes* to the ghosts | ghost fades | come back the next night |
| Struck the fiends first | Humility loss; shrine stays shut (see §6.3) | return with the ward, do not strike |
| Bought the Court's Word | Chamber rejects it (wrong principle, no lines) | any true road; re-meditate Humility |
| Spoke at the Hermitage | count resets | begin the three nights again |
| Knelt before watching the abbot | nothing | be present at dawn first |
| Companions at *lost* loyalty | refuse the Mirror Ford | go on alone, or spend a day on amends |
| Lied at a door | ejected, escalating | an honest answer resets the counter |
| Starved | unconscious, never dead; collapse = inn rescue + debt + rumour | eat anything |
| Fewer than two lines held | Chamber still asks; honest failure | surface → Humility vision gives all eight |

## 6. Suggestions to improve the win path

Drawn from the 2026-09-07 deep dive (`GAMEPLAY.md §10`, G1–G12), focused here on the trunk. **Proposals,
not rulings.**

| # | Suggestion | Why |
|---|---|---|
| 6.1 | **Make the meaning test need lines from a source tied to your own run.** Statues and the library give all eight with no test, so the Chamber's second question is a lookup for anyone who visits the Monastery. Option: since the pair (A,B) is the pair *you* struggled with, require ≥1 of the two lines from a run-bound source (ghosts / Anchorite's dreams / companion / vision); carved sources may supply only the other. | keeps "understanding, not recall" honest |
| 6.2 | **Add *"I do not remember"* at Doors 2–4** → no ejection; the door tells you; a Humility event. | honest forgetting is graded as a lie today |
| 6.3 | **Replace the two surviving counter-gates:** Wind-Ship Humility floor ≥25 → lifts on the warding item, band = speed only; fiends "shut until the band recovers" → shut until you return with the ward and do not strike. | both contradict "counters gate nothing"; the second re-creates the grind |
| 6.4 | **`unseen` scores neutral in Together.** | a late companion's honest "I was not there" currently counts as wrong |
| 6.5 | **Chamber answers as chips from the Pilgrim's Book**; re-weight templates toward *what/why* over *who/where*. | randomized names 25 h later are noise |
| 6.6 | **A shrine refuses the same wrong mantra permanently**, and the refusal is a Chamber-quotable event. | brute force costs a day per guess with small syllable pools |
| 6.7 | **Give Act II three hard, rumour-driven consequences** (gate refused, wronged party's ambush, seller refuses, companion walks). | the trunk is all knowledge; conduct has no teeth until the Assize |
| 6.8 | **Wisdom needs a minimum-volume term.** `\|gA−gB\| / (gA+gB)` is perfect at 0/0: avoiding every dilemma scores as *whole*. | the `hermit` golden run would reach the best band by avoidance |
| 6.9 | **Build a text-only Witness Log → Chamber harness before Phase 1.** | the thesis (a 25-hour-delayed judgment feels earned) is untested; the golden runs already spec it |
| 6.10 | **Decide dungeon authoring** (authored shells per vice vs room templates) before P1. | 64 template-assembled 3D levels is the blandness the deep-dive warned against |

## 7. Cross-reference

| Question | Doc |
|---|---|
| What does each node *ask of the player*? | `QUEST_TREE.md §2` |
| What are the 12 principles and how is the Word chosen? | `QUEST_TREE.md §4.0` |
| What happens on each Descent level, exactly? | `CRITICAL_PATH.md §6`, `QUEST_TREE.md §5` |
| Every encounter, optional or not? | `GAMEPLAY.md §4–7` |
| Which tests prove the tree holds for every seed? | `REGRESSION.md §6.11`, `QUEST_TREE.md §9` |

