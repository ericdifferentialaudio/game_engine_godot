# Claude Code Cheat Sheet — game_engine_godot

Human reference. Claude is told **not** to read this file (keeps it out of context).

## Context window — what it knows, what it costs

| Command      | What it does |
|--------------|--------------|
| `/context`   | Visual breakdown of what is filling the context window right now |
| `/compact`   | Summarize the conversation and keep going (use at ~70–80% full) |
| `/compact <focus>` | Compact but preserve a specific thread, e.g. `/compact keep the intel refactor plan` |
| `/clear`     | Wipe context entirely — use when switching to an unrelated task |
| `/cost`      | Token/dollar usage for this session |
| `/status`    | Model, version, working dir, account |

Rule of thumb: **`/clear` between tasks, `/compact` within a long task.**

## Steering mid-flight

| Action | Effect |
|---|---|
| `Esc` | Interrupt immediately (keeps context — better than letting it finish wrong) |
| `Esc Esc` | Jump back to edit an earlier message and re-run from there |
| `/rewind` | Restore code and/or conversation to an earlier checkpoint |
| `Shift+Tab` | Cycle Plan mode ⇄ Act ⇄ auto-accept edits |
| `#` prefix | Write a memory, e.g. `# always run sync_core after core edits` |
| `@path` | Inline a file/dir into the prompt, e.g. `@core/addons/game_core/managers/core_intel.gd` |
| `!cmd` | Run a shell command and put its output in context |

## Session management

| Command | Effect |
|---|---|
| `claude --continue` | Resume the most recent session |
| `claude --resume` | Pick a past session from a list |
| `claude -p "..."` | One-shot headless query (scriptable) |
| `/export` | Export the conversation to a file/clipboard |
| `/resume` | Switch sessions from inside Claude |

## Config / capabilities

| Command | Effect |
|---|---|
| `/model` | Switch model (Opus for design, Sonnet for grinding) |
| `/agents` | View/create subagents (`.claude/agents/`) |
| `/permissions` | View/edit allow & deny rules |
| `/hooks` | View/edit hooks |
| `/mcp` | Manage MCP servers |
| `/add-dir <path>` | Give access to another folder (e.g. `C:\Aevum\engine` for the port) |
| `/memory` | Edit `CLAUDE.md` files |
| `/init` | Regenerate a CLAUDE.md |
| `/doctor` | Diagnose the install |

## This repo's own commands

```powershell
./tools/run_tests.ps1                    # GUT x3 roots + smoke/boot/playtest. MUST be green.
./tools/run_tests.ps1 -Import            # force reimport first (fixes "Could not find type")
./tools/sync_core.ps1                    # after ANY edit in core/addons/game_core/
./tools/sync_core.ps1 -Check             # verify only, non-zero exit if stale
./tools/sync_game.ps1 -Game zork         # after ANY edit in games/zork/
./tools/sync_game.ps1 -Game paragon -Engine isometric
godot --headless --path game_api/isometric -- --smoke
godot --headless --path game_api/fps -- --boot-check
godot --headless --path game_api/fps -- --game=zork --playtest
```

## Installed here

**Skills** (`.claude/skills/`) — auto-invoked by topic:
`core-platform` · `fps-engine` · `isometric-engine`

**Subagents** (`.claude/agents/`) — delegate to keep context clean:
`test-runner` · `core-sync-checker` · `architecture-guardian` · `gdscript-reviewer`

Invoke explicitly: *"use the test-runner agent"*, *"have architecture-guardian review this"*.

**Hooks** (`.claude/settings.json`): after any edit under `core/addons/game_core/`
or `games/`, Claude is reminded that a sync is required.

## Efficiency tips for this repo

1. Start a task with **Plan mode** (`Shift+Tab`) for anything touching `core/` —
   the engine seam is easy to break and expensive to un-break.
2. Point at `activeContext.md` first; it is the short, current truth.
3. Delegate test runs to `test-runner` — Godot output is huge and will eat context.
4. `/clear` when moving between `core/`, `fps`, `iso` and a game package.
5. Ask for the sync command to be run in the same turn as the edit, not later.
6. For the Aevum port, `/add-dir C:\Aevum\engine` rather than pasting Python.
