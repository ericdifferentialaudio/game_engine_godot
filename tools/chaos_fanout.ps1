<#
.SYNOPSIS
    Creates one git worktree per game so several chaos agents can work in
    genuine parallel, in separate Claude Code sessions.

.DESCRIPTION
    The game-forge agent fans out one Task per game, which is concurrent within
    a session. Process-level isolation needs separate sessions -- and separate
    checkouts, or they fight over the same files. A subagent also cannot spawn
    another subagent, so a nested forge would run sequentially; this script is
    the escape hatch for both cases.

    This is safe because each games/<id>/ tree is disjoint: six agents editing
    six packages never touch the same file. The shared surfaces (core/,
    game_api/*/framework/, tools/) ARE a collision risk, which is why the
    implement agent is forbidden to edit them -- core changes are filed
    as requests and applied once, serially, on main.

.EXAMPLE
    ./tools/chaos_fanout.ps1 -Games zork,aevum,paragon
    ./tools/chaos_fanout.ps1 -Games all
    ./tools/chaos_fanout.ps1 -Cleanup
#>

param(
    [string[]]$Games = @("all"),
    [string]$Prefix = "..",
    [switch]$Cleanup,
    [switch]$List
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

function Get-AllGames {
    Get-ChildItem (Join-Path $repoRoot "games") -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName "game.json") } |
        Select-Object -ExpandProperty Name
}

function Get-Engine([string]$game) {
    # Classify by what the package actually contains, not by a hardcoded list.
    $pkg = Join-Path $repoRoot "games\$game"
    if (Test-Path (Join-Path $pkg "terrains.json")) { return "isometric" }
    if (Test-Path (Join-Path $pkg "abilities.json")) { return "fps" }
    $cfg = Get-Content (Join-Path $pkg "game.json") -Raw | ConvertFrom-Json
    if ($cfg.PSObject.Properties.Name -contains "grid") { return "isometric" }
    return "fps"
}

if ($List) {
    Write-Host "Games and their engines:" -ForegroundColor Cyan
    foreach ($g in Get-AllGames) {
        "{0,-16} {1}" -f $g, (Get-Engine $g) | Write-Host
    }
    Write-Host "`nActive worktrees:" -ForegroundColor Cyan
    git -C $repoRoot worktree list
    exit 0
}

if ($Cleanup) {
    Write-Host "Removing chaos worktrees..." -ForegroundColor Cyan
    $lines = git -C $repoRoot worktree list --porcelain | Select-String '^worktree (.+)$'
    foreach ($line in $lines) {
        $path = $line.Matches[0].Groups[1].Value
        if ($path -match 'cf-[\w]+$' -and $path -ne $repoRoot.Replace('\', '/')) {
            Write-Host "  removing $path" -ForegroundColor DarkGray
            git -C $repoRoot worktree remove $path --force
        }
    }
    git -C $repoRoot worktree prune
    Write-Host "Done. Branches chaos/* are kept -- delete them manually if unwanted." -ForegroundColor Green
    exit 0
}

if ($Games.Count -eq 1 -and $Games[0] -eq "all") {
    $Games = Get-AllGames
}

# A worktree cannot be created from a repo with no commits on HEAD.
$headOk = $true
try { git -C $repoRoot rev-parse HEAD *> $null } catch { $headOk = $false }
if (-not $headOk -or $LASTEXITCODE -ne 0) {
    Write-Host "This repo has no HEAD commit yet; commit once before fanning out." -ForegroundColor Red
    exit 1
}

$created = @()
foreach ($game in $Games) {
    $pkg = Join-Path $repoRoot "games\$game"
    if (-not (Test-Path (Join-Path $pkg "game.json"))) {
        Write-Host "skip $game (no game.json)" -ForegroundColor Yellow
        continue
    }

    $engine = Get-Engine $game
    $wtPath = Join-Path $repoRoot "$Prefix\cf-$game"
    $branch = "chaos/$game"

    if (Test-Path $wtPath) {
        Write-Host "exists: $wtPath" -ForegroundColor DarkGray
    } else {
        $exists = git -C $repoRoot branch --list $branch
        if ($exists) {
            git -C $repoRoot worktree add $wtPath $branch | Out-Null
        } else {
            git -C $repoRoot worktree add -b $branch $wtPath | Out-Null
        }
        Write-Host "created $wtPath  [$branch]" -ForegroundColor Green
    }
    $created += [pscustomobject]@{ Game = $game; Engine = $engine; Path = (Resolve-Path $wtPath).Path }
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " Run each of these in its OWN terminal / session" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
foreach ($c in $created) {
    Write-Host ""
    Write-Host "# $($c.Game)  [$($c.Engine)]" -ForegroundColor Yellow
    Write-Host "cd `"$($c.Path)`""
    Write-Host "claude `"Run the game-forge pipeline for games/$($c.Game) only. Engine: $($c.Engine). Edit only games/$($c.Game)/**; file any core/ needs as requests in CHAOS_SPEC.md.`""
}

Write-Host ""
Write-Host "When each finishes: squash-merge chaos/<game> into main, then apply" -ForegroundColor DarkGray
Write-Host "batched core requests serially and run ./tools/run_tests.ps1." -ForegroundColor DarkGray
