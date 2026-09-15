# Vendored: inkgd

**Do not edit anything in this folder.** It is a third-party runtime, vendored
verbatim so that the shared core has a GDScript-only Ink implementation.

| | |
|---|---|
| Upstream | https://github.com/ephread/inkgd |
| Branch | `godot4` (Godot 4.2+; upstream has **no tagged release** for Godot 4 yet) |
| Pinned commit | `fea9098ee18d6cdbe9a5e25f8f0296bcdf0fd96a` |
| License | MIT (see `LICENSE`) |
| Excluded | `mono/` — the C# bridge. We are GDScript-only; `InkPlayerFactory` falls back to the GDScript runtime automatically when `GodotSharp` is absent. |

## Why inkgd and not GodotInk

`godot-ink`/GodotInk wraps the real C# `ink-engine-runtime` and is faster, but
requires .NET/Mono in every project root that consumes it. This repo has three
project roots (`core/`, `game_api/isometric/`, `game_api/fps/`) and none of them
are C# projects. Narrative processing is not a per-frame hot path, so the
performance gap does not matter here.

The trade-off accepted: we pin an *unreleased branch*. To contain that risk,
**`CoreInkEngine` is the only file in the repo that references inkgd**. Swapping
to GodotInk later is a single-file change.

## Updating the pin

```powershell
git clone --branch godot4 --depth 1 https://github.com/ephread/inkgd $env:TEMP\inkgd_vendor
robocopy $env:TEMP\inkgd_vendor\addons\inkgd core\addons\inkgd /E /XD mono
./tools/sync_core.ps1
./tools/run_tests.ps1
```

Then update the pinned commit above.

## Compiling `.ink` -> `.ink.json`

`inklecate` is **not** a build dependency: compiled `.ink.json` files are
committed. Only a writer changing narrative content needs it.

```powershell
inklecate -o games/zork/ink/pub_gathering.ink.json games/zork/ink/pub_gathering.ink
```
