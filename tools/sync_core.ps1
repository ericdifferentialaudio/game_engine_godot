<#
.SYNOPSIS
    Copies the shared addons (game_core, inkgd) and the shared ink pattern
    library into both engine API layers.

.DESCRIPTION
    Godot cannot resolve res:// paths outside a project root, so shared trees
    must physically exist inside each project. This script is the single
    supported way to propagate a change made in core/ out to
    game_api/isometric/ and game_api/fps/.

    Run it after ANY edit under core/addons/ or core/ink/, then run
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

# Every shared tree, as a path relative to a project root. game_core is the
# platform; inkgd is the vendored Ink runtime; ink/patterns is the shared
# conversation-pattern library that game .ink files INCLUDE.
$shared = @(
    "addons\game_core",
    "addons\inkgd",
    "ink\patterns"
)

$engines = @("isometric", "fps")

# Hash every text file in a tree so we can detect drift cheaply. .ink is
# included so a pattern-library edit is caught like any other source change.
function Get-TreeHash([string]$path) {
    if (-not (Test-Path $path)) { return "" }
    $parts = Get-ChildItem -Path $path -Recurse -File -Include *.gd, *.cfg, *.ink, *.json |
        Sort-Object FullName |
        ForEach-Object { "$($_.FullName.Substring($path.Length)):$((Get-FileHash $_.FullName).Hash)" }
    return ($parts -join "|")
}

$stale = $false

foreach ($rel in $shared) {
    $source = Join-Path $repoRoot (Join-Path "core" $rel)
    if (-not (Test-Path $source)) {
        Write-Host "Source tree not found: $source" -ForegroundColor Red
        exit 1
    }
    $sourceHash = Get-TreeHash $source

    foreach ($engine in $engines) {
        $target = Join-Path $repoRoot (Join-Path "game_api\$engine" $rel)
        $label = "$engine/$rel"

        if ((Get-TreeHash $target) -eq $sourceHash) {
            Write-Host "up to date: $label" -ForegroundColor DarkGray
            continue
        }

        if ($Check) {
            Write-Host "STALE: $label (run ./tools/sync_core.ps1)" -ForegroundColor Red
            $stale = $true
            continue
        }

        if (Test-Path $target) { Remove-Item $target -Recurse -Force }
        $parent = Split-Path $target -Parent
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
        Copy-Item $source $target -Recurse -Force
        Write-Host "synced: $label" -ForegroundColor Green
    }
}

if ($stale) { exit 1 }
Write-Host "Shared trees are in sync across both engine API layers." -ForegroundColor Green
