<#
.SYNOPSIS
    Copies a game package from games/<id>/ into an engine API layer.

.DESCRIPTION
    Godot cannot resolve res:// paths outside a project root, so a game that
    lives in games/<id>/ (the authoritative source) must be physically copied
    into game_api/<engine>/games/<id>/ to run. Mirrors tools/sync_core.ps1.

    Run after ANY edit under games/<id>/, then launch with
        godot --path game_api/<engine> -- --game=<id>

.EXAMPLE
    ./tools/sync_game.ps1 -Game zork               # fps is the default engine
    ./tools/sync_game.ps1 -Game zork -Check        # verify only, non-zero exit if stale
#>

param(
    [Parameter(Mandatory = $true)][string]$Game,
    [ValidateSet('fps', 'isometric')][string]$Engine = 'fps',
    [switch]$Check
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repoRoot "games\$Game"
$target = Join-Path $repoRoot "game_api\$Engine\games\$Game"

if (-not (Test-Path $source)) {
    Write-Host "Game package not found: $source" -ForegroundColor Red
    exit 1
}

function Get-TreeHash([string]$path) {
    if (-not (Test-Path $path)) { return "" }
    $parts = Get-ChildItem -Path $path -Recurse -File -Include *.gd, *.json, *.tscn, *.tres, *.md |
        Where-Object { $_.Name -notlike '*.uid' -and $_.Name -notlike '*.import' } |
        Sort-Object FullName |
        ForEach-Object { "$($_.FullName.Substring($path.Length)):$((Get-FileHash $_.FullName).Hash)" }
    return ($parts -join "|")
}

if ((Get-TreeHash $source) -eq (Get-TreeHash $target)) {
    Write-Host "up to date: $Engine/games/$Game" -ForegroundColor DarkGray
    exit 0
}

if ($Check) {
    Write-Host "STALE: $Engine/games/$Game (run ./tools/sync_game.ps1 -Game $Game)" -ForegroundColor Red
    exit 1
}

# Preserve Godot's generated .uid sidecars so scene/script references stay stable.
$uids = @{}
if (Test-Path $target) {
    Get-ChildItem $target -Recurse -File -Filter '*.uid' | ForEach-Object {
        $uids[$_.FullName.Substring($target.Length)] = Get-Content $_.FullName -Raw
    }
    Remove-Item $target -Recurse -Force
}
Copy-Item $source $target -Recurse -Force
foreach ($rel in $uids.Keys) {
    $dest = Join-Path $target $rel
    $owner = $dest -replace '\.uid$', ''
    if ((Test-Path $owner) -and -not (Test-Path $dest)) { Set-Content -Path $dest -Value $uids[$rel] -NoNewline }
}
Write-Host "synced: games/$Game -> game_api/$Engine/games/$Game" -ForegroundColor Green
