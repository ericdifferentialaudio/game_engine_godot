<#
.SYNOPSIS
    Copies core/addons/game_core into both engine API layers.

.DESCRIPTION
    Godot cannot resolve res:// paths outside a project root, so the shared
    addon must physically exist inside each project. This script is the single
    supported way to propagate a change made in core/ out to
    game_api/isometric/ and game_api/fps/.

    Run it after ANY edit under core/addons/game_core/, then run
    tools/run_tests.ps1 before committing.

.EXAMPLE
    ./tools/sync_core.ps1
    ./tools/sync_core.ps1 -Check      # verify only, non-zero exit if stale
#>

param(
    [switch]$Check
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repoRoot "core\addons\game_core"

if (-not (Test-Path $source)) {
    Write-Host "Source addon not found: $source" -ForegroundColor Red
    exit 1
}

$targets = @(
    (Join-Path $repoRoot "game_api\isometric\addons\game_core"),
    (Join-Path $repoRoot "game_api\fps\addons\game_core")
)

# Hash every .gd/.cfg file in a tree so we can detect drift cheaply.
function Get-TreeHash([string]$path) {
    if (-not (Test-Path $path)) { return "" }
    $parts = Get-ChildItem -Path $path -Recurse -File -Include *.gd, *.cfg |
        Sort-Object FullName |
        ForEach-Object { "$($_.FullName.Substring($path.Length)):$((Get-FileHash $_.FullName).Hash)" }
    return ($parts -join "|")
}

$sourceHash = Get-TreeHash $source
$stale = $false

foreach ($target in $targets) {
    $name = Split-Path (Split-Path (Split-Path $target -Parent) -Parent) -Leaf
    if ((Get-TreeHash $target) -eq $sourceHash) {
        Write-Host "up to date: $name" -ForegroundColor DarkGray
        continue
    }

    if ($Check) {
        Write-Host "STALE: $name (run ./tools/sync_core.ps1)" -ForegroundColor Red
        $stale = $true
        continue
    }

    if (Test-Path $target) { Remove-Item $target -Recurse -Force }
    Copy-Item $source $target -Recurse -Force
    Write-Host "synced: $name" -ForegroundColor Green
}

if ($stale) { exit 1 }
Write-Host "game_core is in sync across both engine API layers." -ForegroundColor Green
