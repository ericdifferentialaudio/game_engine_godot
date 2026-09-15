<#
.SYNOPSIS
    Single entry point to sync and launch the Zork game package.

.DESCRIPTION
    Wraps tools/sync_game.ps1 (copies games/zork -> game_api/fps/games/zork,
    since Godot cannot resolve res:// across project roots) and then launches
    Godot with the fps engine layer, telling it to boot the zork package.

    Resolves a Godot executable in priority order:
      1. -GodotPath argument, if passed explicitly
      2. $env:GODOT_BIN, if set
      3. `godot` on PATH
      4. C:\Tools\Godot\4.7.2\godot_console.exe (this repo's documented dev path)
      5. Newest Godot*_console.exe under $env:USERPROFILE\Downloads (best-effort)

.EXAMPLE
    ./games/zork/run.ps1
    ./games/zork/run.ps1 -GodotPath "C:\Tools\Godot\4.7.2\godot_console.exe"
    ./games/zork/run.ps1 -Playtest              # headless scripted playtest instead of playing
    ./games/zork/run.ps1 -BootCheck             # headless boot-only sanity check
    ./games/zork/run.ps1 -NoSync                # skip the sync step
#>

param(
    [string]$GodotPath = "",
    [switch]$Playtest,
    [switch]$BootCheck,
    [switch]$NoSync
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$fpsPath = Join-Path $repoRoot "game_api\fps"

if (-not $GodotPath) {
    if ($env:GODOT_BIN) {
        $GodotPath = $env:GODOT_BIN
    } elseif (Get-Command "godot" -ErrorAction SilentlyContinue) {
        $GodotPath = "godot"
    } elseif (Test-Path "C:\Tools\Godot\4.7.2\godot_console.exe") {
        $GodotPath = "C:\Tools\Godot\4.7.2\godot_console.exe"
    } else {
        $fallback = Get-ChildItem -Path "$env:USERPROFILE\Downloads" -Recurse -Filter "Godot*_console.exe" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($fallback) {
            $GodotPath = $fallback.FullName
        } else {
            Write-Host "Could not find a Godot executable. Pass -GodotPath, set `$env:GODOT_BIN`, or add 'godot' to PATH." -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host "Using Godot executable: $GodotPath" -ForegroundColor DarkGray

if (-not $NoSync) {
    Write-Host "Syncing games/zork -> game_api/fps/games/zork..." -ForegroundColor Cyan
    & (Join-Path $repoRoot "tools\sync_game.ps1") -Game zork
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Sync failed." -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

$gameArg = "--game=zork"
if ($Playtest) {
    $gameArg = "--game=zork --playtest"
} elseif ($BootCheck) {
    $gameArg = "--game=zork --boot-check"
}

if ($Playtest -or $BootCheck) {
    Write-Host "Running headless: $gameArg" -ForegroundColor Cyan
    cmd /c "`"$GodotPath`" --headless --path `"$fpsPath`" -- $gameArg 2>&1"
} else {
    Write-Host "Launching Zork..." -ForegroundColor Green
    & $GodotPath --path $fpsPath -- $gameArg
}

exit $LASTEXITCODE
