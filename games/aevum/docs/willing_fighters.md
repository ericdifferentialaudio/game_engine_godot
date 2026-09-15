# willing_fighters.md — Willing Fighters (NPC Heroes)

**Module:** `engine/engine_npc.py` · **Seeded by:** `startup_engine.py` (step 16)
**Tests:** `tests/engine/test_willing_fighters.py`
*Last updated 08/2026.*

---

## Overview

Twelve named NPC heroes — one per clan virtue — are hidden in the world at
boot. Each is far stronger than a produced unit, costs **no gold**, and will
join **any** clan that has **meditated the shrine of their virtue**.

The design intent: meditation is the win condition, and heroes make it also the
*recruitment* condition. A clan that ignores shrines can never field one, no
matter how much gold it has.

Three things gate a hero:

1. **Find them.** They are hidden inside town/village/castle/lair interiors.
2. **Meditate their virtue.** The clan must have completed meditation at the
   shrine whose primary virtue matches the hero's.
3. **Stand next to them.** Recruitment is an interior adjacency action.

They appear as ordinary `wanderer` NPCs in conversation — nothing marks them as
special until spoken to. On joining they **convert to the recruiting clan's own
unit type**, so a hero recruited by the dwarf clan fights as a dwarf.

---

## The Twelve

Every hero's virtue is one of the 12 in `assets/data/virtues.json`, and each is
gated on that virtue's **owning clan's shrine** (`shrine_<clan>`).

| Hero | Virtue | Gate shrine | Bias | HP | ATK | DEF | Other | Item (tier) |
|---|---|---|---|---|---|---|---|---|
| **Sorra the Undaunted** | Valor | `shrine_fighter` | lair | +6 | +4 | +1 | — | Iron Resolve Pendant (2) |
| **Alethis of the Long Road** | Honour | `shrine_elf` | town | +5 | +3 | +4 | — | Vow Blade (2) |
| **The Healer of the Crossroads** | Compassion | `shrine_cleric` | town | +8 | +1 | +2 | — | Restoration Draught (2) |
| **The Debt-Keeper** | Sacrifice | `shrine_necromancer` | lair | +5 | +6 | — | — | Necrotic Edge (3) |
| **The Broken Scholar** | Wisdom | `shrine_mage` | castle | +4 | +3 | — | +1 VIS, grants T3 intel | Mantra Codex (3) |
| **Pell the Truth-Singer** | Honesty | `shrine_bard` | town | +5 | +3 | — | +1 VIS, pub bonus | Truth Lyre (2) |
| **Aldric the Exile** | Justice | `shrine_shaman` | lair | +6 | +4 | +2 | — | Judgment Blade (2) |
| **The Deep Wanderer** | Spirituality | `shrine_ranger` | lair | +5 | +3 | — | +2 MOV, +2 VIS | Spirit Compass (2) |
| **The Oathwarden** | Fortitude | `shrine_dwarf` | lair | +8 | +2 | +5 | — | Oath Shield (2) |
| **The Unnamed** | Humility | `shrine_monk` | town | +5 | +3 | — | +3 STL | Null Cloak (2) |
| **Scratch** | Loyalty | `shrine_rogue` | town | +5 | +4 | — | +2 STL, gold bonus | Pickpocket Dice (2) |
| **The Grove-Keeper** | Temperance | `shrine_druid` | lair | +6 | +3 | — | +2 MOV, passive heal | Root Charm (2) |

Bonuses are **added on top of** the recruiting clan's unit template — roughly
double a normal unit's base stats, which is what makes heroes elite.

> **Virtue naming.** Dwarf = **Fortitude**, Rogue = **Loyalty**, per
> `virtues.json`. Earlier builds wrongly listed the Oathwarden as *Loyalty* and
> Scratch as *Truth*; "Truth" is not one of the 12 virtues and no shrine ever
> granted it, so those two heroes were unrecruitable. Fixed 08/2026.

---

## Seeding

`seed_willing_fighters(state, rng)` runs **after** all interiors are generated
(startup step 16 — it must not run before them, or there is nowhere to place
anyone).

- Only heroes whose gate clan is **active this game** are seeded, so a standard
  8-clan game places **8 of the 12**.
- Placement follows `placement_bias` (`lair` / `town` / `castle`), falling back
  to any interior with a free `npc_slot` tile. One hero per location.
- Each is created as an `NPCInstance` with `npc_type="wanderer"`,
  `clan_id=""`, `is_willing_fighter=True`, `virtue_affinity=<virtue>`.
- Each carries one piece of self-referential intel (their `hint_line`) at
  confidence 0.70, so rumours about them can spread.
- Locations are registered in `state.willing_fighter_locations[fighter_id]`
  as `{"location_id", "virtue", "recruited_by"}`.

Log line: `** WILLING_FIGHTERS_SEEDED: N fighters placed across N locations`.

---

## The meditation gate

`check_virtue_match(clan_id, virtue, state)` returns True when either:

- `clan.shrine_records[f"shrine_{gate_clan}"].is_meditated` is True, **or**
- `state.shrines[shrine_id].clan_meditations[clan_id]` is True.

The gate is **per clan** — a rival meditating that shrine does not open it for
you — and it checks *completed* meditation, not merely knowing the mantra.

---

## Recruiting

`recruit_npc(unit_id, npc_id, location_id, state)`; `gold_offer` is accepted
for API compatibility and **ignored — joining is always free**.

Order of checks: unit/interior exist → NPC present → is a willing fighter →
not already recruited (`freed_by`) → within `_NPC_ADJ_RADIUS` → virtue gate.

**On refusal** the hero speaks a random `refuse_lines` entry with their
`hint_line` appended, and the result carries `virtue_required` + `shrine_clan`
so the UI can point the player at the right shrine.

**On success:**

- A new unit is built from `_best_clan_template(clan_id)` — the hero adopts the
  recruiting clan's unit type, keeping their own bonuses.
- `hp_max = template.base_hp + hp bonus`, and the unit starts at full health.
- ATK/DEF/MOV/VIS/STL bonuses are written to `unit.atk_bonus`, `def_bonus`,
  `mov_bonus`, `vis_bonus`, `stl_bonus`. Whether `effective_stat()` reads those
  fields is controlled by **`AEVUM_UNIT_BONUSES`** (`off` default / `atkmov` /
  `on`) — see the note at the top of `engine/game_state.py`. Enabling them
  regressed balance in `sim_08_22_19_17`, because the same fields carry ~1,800
  previously-inert level-up bonuses per run. **With the default `off`, heroes
  keep their HP bonus and item but their ATK/DEF are not yet applied in combat.**
- Their item is created and equipped (see below).
- All of the NPC's `intel_pieces` transfer to the new unit's `known_intel`.
- The Broken Scholar additionally grants a **T3 shrine-location intel token**.
- `unit.extra_stats` and `unit.from_willing_fighter` record provenance only —
  they are **not** read for stat maths.

A clan may recruit **as many heroes as it can qualify for**; there is no cap.

---

## Hero items

Granted automatically on join, via `_grant_wf_item()`.

| Item | Effect |
|---|---|
| Iron Resolve Pendant | +1 DEF, +1 HP |
| Vow Blade | +1 ATK, +1 DEF |
| Restoration Draught | 3 heal uses |
| Necrotic Edge | +2 ATK, life steal |
| Mantra Codex | 3 mantra fragments |
| Truth Lyre | +1 pub intel tier |
| Judgment Blade | +1 ATK, first strike |
| Spirit Compass | +1 MOV, reveal radius 5 |
| Oath Shield | +2 DEF, +1 wall bonus |
| Null Cloak | +2 stealth, reduced reveal |
| Pickpocket Dice | +1 ATK, 25% gold steal |
| Root Charm | +1 HP/turn, +1 MOV |

---

## Finding them — intel tokens

Two token types in `engine_intel_tokens.py` leak hero positions:

| Token | Tier | Reveals |
|---|---|---|
| `WILLING_FIGHTER_RUMOUR:{virtue}:{location_hint}` | T1 | A hero of that virtue exists, roughly where |
| `WILLING_FIGHTER_LOCATION:{fighter_name}:{location_id}` | T3 | Exact hero and exact location |

---

## Dialogue

Each hero carries `join_lines`, `refuse_lines` and a `hint_line`, all naming
their virtue and its owning clan explicitly, so players can infer which shrine
to meditate from conversation alone. Lines live in the roster in
`engine_npc.py`, not in the `assets/dialogue/*.json` files.

---

## State fields

| Field | Where | Meaning |
|---|---|---|
| `state.willing_fighter_locations` | GameState | `fighter_id` → location/virtue/recruited_by |
| `npc.is_willing_fighter` | NPCInstance | Marks a seeded hero |
| `npc.virtue_affinity` | NPCInstance | Gate virtue |
| `npc.freed_by` | NPCInstance | Set once recruited |
| `unit.from_willing_fighter` | UnitInstance | `fighter_id` this unit came from |
| `unit.extra_stats` | UnitInstance | Provenance metadata (not stats) |
| `interior.npcs` | InteriorMap | Live NPCs standing in the interior |

---

## Public API

`check_virtue_match(clan_id, virtue, state)` ·
`is_willing_fighter(npc)` ·
`recruit_npc(unit_id, npc_id, location_id, state)` ·
`get_willing_fighter_status(npc, clan_id, state)` ·
`seed_willing_fighters(state, rng)`
