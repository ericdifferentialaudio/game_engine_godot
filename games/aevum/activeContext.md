# activeContext.md — Sliding Window of Work

> Read first, update last, every session. Keep ≤ 120 lines. This is **not** a
> backlog or a changelog. Full mapping: `docs/PORT_MAP.md`.

**Phase:** 2 complete — rules wired **Engine:** isometric **Last updated:** 2026-09-07

---

## Now (max 3)

- [ ] **P2-T6 GUT tests** under `games/aevum/tests/` for shrine → Avatar → Seeker → egg; wire
      into `tools/run_tests.ps1` (no game-specific tests exist yet — only the generic smoke
      suite exercises the package).
- [ ] **Enforce real shrine placement** (8–12 hexes from the owning enclave, preferred/avoided
      terrain from `metadata.placement_rule`) — sites are currently `random_land`, i.e.
      anywhere on land, which is looser than the source rule.
- [ ] **`tech_system.gd` production UI/AI hook** — `aevum_boot.gd::can_produce()` is a pure
      query (building/tech/avatar/max_per_clan/afford gate); nothing yet calls it because the
      shared platform has no production-queue UI. Wire it into a build menu or AI planner.

## Next (3–6)

1. **Design pass on the 14 stub items** (tagged `"stub"`, `metadata.needs_design: true`) —
   named by town shop pools but have no upstream stat block.
2. **P3 art import** — 2.4 GB of PNGs at `C:\Aevum\assets\graphics`. Convert only the hex
   tilesheets and unit sprites actually referenced by `assets.json`; skip `clans_backup/`.
3. **Port the deferred subsystems** — sentiment, diplomacy depth, mercenaries, underground
   economy, interiors. Documented in `docs/`, no data/code destination yet.
4. **Clan-select interaction with `EntityRegistry`** — `_select_active_clans()` erases
   `FactionRegistry.definitions` entries before `instantiate_all()`; if the boot-script call
   order in `GameManager.load_game()` ever moves, re-verify this still runs before instantiation.

## Recently Done (last 5–8)

- 2026-09-07 — **Phase 2: game-specific rules wired.** `aevum_boot.gd` (game.json
  `boot_script`, a capability added to `game_api/isometric/autoloads/game_manager.gd` —
  it previously only existed in the fps layer): clan select (seed keeps `active_clans`
  of 12 + the player's own, via a seeded Fisher-Yates over `FactionRegistry.definitions`
  before `instantiate_all()`), shrine meditation (mantra-token reliability picks the
  1/3/12-turn tier, interrupted by leaving the hex, grants clan-wide +1 / meditator +2 via
  `CharacterStats.add_modifier`, inherited by later-spawned units), Avatar status (all
  active shrines meditated), dragon wake (Seeker within `dragon_wake_radius` of the Veil),
  egg pickup (`item_acquired` sets `cannot_attack` + a `moves` malus), and victory
  (`unit_moved` onto the carrier's own enclave, blocked while `_contested()` — a hostile
  unit adjacent). `aevum_combat_resolver.gd` extends the shared `CombatResolver`: no combat
  within any shrine's `sacred_ground_radius`, and the Dragon's ancient-armour damage
  threshold (looked up via `get_nodes_in_group("aevum_boot")`, called through `.call()` to
  avoid a static-typing inference error on a `Node`-typed reference). `can_produce()` is a
  pure tech/building/Avatar/max-per-clan/afford query — deliberately not wired to any UI
  yet, since the shared platform has no production-queue system to hook. Two engine-level
  additions needed to reach parity with the fps layer: `Unit.attack()` now checks a
  `flags.cannot_attack` gate; `GameManager` (isometric) gained the `boot_script` loader.
  Verified: `--game=aevum --smoke` 37/37 (was 36/37 pre-Phase-2, gated by the harness's
  hard-coded example-package check, not a real Aevum failure); `--game=example_realm_iso
  --smoke` still 37/37 (no regression); `tools/run_tests.ps1` — all three GUT suites plus
  the fps zork playtest (48 checks) — **all pass**.
- 2026-09-07 — **Phase 1: all 11 data files generated and validated (0 errors, 0 warnings).**
  `tools/convert_aevum_data.py` reads `C:\Aevum\assets\data\*.json` and emits the whole
  package: 9 terrains, 3 maps, 140 units, 35 abilities, 52 items, 14 factions, 65 intel
  tokens, 39 sites, 351 asset keys, 8 AI profiles. The conversion is a *script*, so it is
  re-runnable (`--check` exits non-zero when stale) and every mapping decision is in one
  auditable place. Package boots in the engine: `--game=aevum --smoke` → **36 passed,
  1 failed**, and that one failure is the engine harness hard-coding the *example*
  package's token ids (`rumor_crypt_west`→`crypt_location`); Aevum's own equivalent check
  (`triangulate_egg` → `egg_location`) passes.
- 2026-09-07 — **Phase 0: scaffold.** 33 design-bible docs copied to `docs/`; new
  `docs/PORT_MAP.md` maps every Python subsystem to its Godot destination; `README.md`
  written; `games/README.md` row added.
- 2026-09-07 — **Decision: port rules, not implementation.** The 60-module Python `engine/`
  (incl. the 354 KB `engine_ai.py`) is not transliterated — the isometric engine layer
  already provides hex movement, simultaneous turns, factions, fog, combat, shops and the
  intel journal. `engine_ai.py` collapses to `ai_profiles.json` + `ai_controller.gd`.
  `client/` and `simulate/` are dropped entirely.

## Notes / gotchas

- **The JSON files are generated.** Never hand-edit them; change the converter and re-run.
  `python games/aevum/tools/convert_aevum_data.py --check` is the staleness gate.
- Stat renames are load-bearing: `atk/def/mov/hp/vis` → `strength/defense/moves/health/sight`.
  Aevum's extra stats (`mana reach stealth arcane luck resilience endurance intellect`) only
  work because they are declared in `game.json.stats`, which is what `CoreStats.define_from`
  reads. Adding a new stat means adding it there too.
- `./tools/sync_game.ps1` is blocked by the machine's execution policy; use
  `powershell -ExecutionPolicy Bypass -File .\tools\sync_game.ps1 -Game aevum -Engine isometric`.
- Godot lives at `C:\Tools\Godot\4.7.2\godot_console.exe` and is not on PATH.
- Redirect Godot output through `cmd /c ... > file 2>&1`; PowerShell turns its stderr into
  `NativeCommandError` noise and hides the real result.
