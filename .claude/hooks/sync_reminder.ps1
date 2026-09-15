<#
.SYNOPSIS
    PostToolUse hook: reminds Claude to run the required sync script.

.DESCRIPTION
    Godot cannot resolve res:// across project roots, so core/addons/game_core
    and games/<id> are physically copied into each engine API layer. Forgetting
    the copy step produces confusing "works in tests, broken in engine" states.

    Claude Code passes the tool payload as JSON on stdin. We read the edited
    file path out of it and, if it lives in a tree that must be synced, emit a
    reminder on stdout (exit 0 = advisory, never blocks the edit).
#>

$ErrorActionPreference = "SilentlyContinue"

$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }

try { $payload = $raw | ConvertFrom-Json } catch { exit 0 }

$path = $payload.tool_input.file_path
if (-not $path) { exit 0 }

$norm = ($path -replace '\\', '/')

if ($norm -match 'core/addons/game_core/') {
    Write-Output "SYNC REQUIRED: you edited core/addons/game_core/. Run './tools/sync_core.ps1' now (then './tools/run_tests.ps1')."
    exit 0
}

if ($norm -match '(^|/)games/([^/]+)/') {
    $game = $Matches[2]
    $engine = if ($game -eq 'zork') { 'fps' } else { 'isometric' }
    Write-Output "SYNC REQUIRED: you edited games/$game/. Run './tools/sync_game.ps1 -Game $game -Engine $engine' now (then './tools/run_tests.ps1')."
    exit 0
}

exit 0
