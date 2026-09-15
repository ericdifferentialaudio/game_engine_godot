<#
.SYNOPSIS
    Measures how chaotic a game package is and writes games/<id>/chaos_report.json.

.DESCRIPTION
    Runs the engine's chaos harness headlessly over several seeds, feeds the
    episode records to CoreChaosMetrics, and records the scorecard so two
    tuning iterations can be compared numerically instead of by vibes.

    The scorecard carries hard GATES (solvable, deterministic). A chaos score
    that rises while a gate fails is a regression, not progress -- that gate is
    what stops "maximise chaos" from collapsing into "delete the win condition".

.EXAMPLE
    ./tools/chaos_run.ps1 -Game zork
    ./tools/chaos_run.ps1 -Game aevum -Seeds 1,2,3,4,5
    ./tools/chaos_run.ps1 -Game paragon -Compare
#>

param(
    [Parameter(Mandatory = $true)][string]$Game,
    [int[]]$Seeds = @(1, 2, 3, 4, 5),
    [string]$GodotPath = "",
    [switch]$Compare,
    [switch]$SkipSync
)

$ErrorActionPreference = "Continue"
$repoRoot = Split-Path -Parent $PSScriptRoot
$pkg = Join-Path $repoRoot "games\$Game"

if (-not (Test-Path (Join-Path $pkg "game.json"))) {
    Write-Host "No such game package: games/$Game" -ForegroundColor Red
    exit 1
}

# Classify by package contents -- same rule as chaos_fanout.ps1.
$engine = "fps"
if (Test-Path (Join-Path $pkg "terrains.json")) { $engine = "isometric" }
elseif (-not (Test-Path (Join-Path $pkg "abilities.json"))) {
    $cfg = Get-Content (Join-Path $pkg "game.json") -Raw | ConvertFrom-Json
    if ($cfg.PSObject.Properties.Name -contains "grid") { $engine = "isometric" }
}

if (-not $GodotPath) {
    if ($env:GODOT_BIN) { $GodotPath = $env:GODOT_BIN }
    elseif (Get-Command "godot" -ErrorAction SilentlyContinue) { $GodotPath = "godot" }
    else {
        $fallback = Get-ChildItem -Path "$env:USERPROFILE\Downloads" -Recurse -Filter "Godot*_console.exe" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($fallback) { $GodotPath = $fallback.FullName }
        else {
            Write-Host "Could not find Godot. Pass -GodotPath, set `$env:GODOT_BIN, or add 'godot' to PATH." -ForegroundColor Red
            exit 1
        }
    }
}

# A stale copy in the engine layer would measure the OLD data and silently
# report the wrong score -- the most misleading failure this tool can have.
if (-not $SkipSync) {
    & (Join-Path $PSScriptRoot "sync_game.ps1") -Game $Game -Engine $engine | Out-Null
}

$projectPath = Join-Path $repoRoot "game_api\$engine"
$reportPath = Join-Path $pkg "chaos_report.json"

$previous = $null
if ((Test-Path $reportPath) -and $Compare) {
    $previous = Get-Content $reportPath -Raw | ConvertFrom-Json
}

Write-Host "chaos: $Game [$engine] over $($Seeds.Count) seeds" -ForegroundColor Cyan

$logDir = Join-Path $repoRoot "tools\regressions"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$combined = Join-Path $logDir "chaos_$Game.log"
if (Test-Path $combined) { Remove-Item $combined -Force }

foreach ($seed in $Seeds) {
    Write-Host "  seed $seed..." -ForegroundColor DarkGray -NoNewline
    $args = "--game=$Game --chaos --seed=$seed"
    $out = cmd /c "`"$GodotPath`" --headless --path `"$projectPath`" -- $args 2>&1"
    $out | Out-File -FilePath $combined -Encoding utf8 -Append
    if ($LASTEXITCODE -ne 0) { Write-Host " failed (exit $LASTEXITCODE)" -ForegroundColor Yellow }
    else { Write-Host " ok" -ForegroundColor DarkGray }
}

# The harness prints one CHAOS_EPISODE line of JSON per episode.
$episodes = @()
Get-Content $combined -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_ -match 'CHAOS_EPISODE\s+(\{.*\})\s*$') {
        try { $episodes += ($matches[1] | ConvertFrom-Json) } catch { }
    }
}

if ($episodes.Count -eq 0) {
    Write-Host ""
    Write-Host "No episodes recorded. The chaos harness for '$engine' may not be" -ForegroundColor Yellow
    Write-Host "wired into that engine's main scene yet (expects '--chaos')." -ForegroundColor Yellow
    Write-Host "Raw output: $combined" -ForegroundColor DarkGray
    exit 2
}

$wins = ($episodes | Where-Object { $_.won }).Count
$rate = [math]::Round($wins / $episodes.Count, 3)
$outcomes = ($episodes | ForEach-Object { $_.outcome } | Sort-Object -Unique)

$report = [ordered]@{
    game = $Game; engine = $engine
    generated = (Get-Date).ToString("o")
    seeds = $Seeds; episodes = $episodes.Count
    win_rate = $rate
    distinct_outcomes = $outcomes
    scorecard = ($episodes | Where-Object { $_.scorecard } | Select-Object -Last 1).scorecard
    raw_log = "tools/regressions/chaos_$Game.log"
}
$report | ConvertTo-Json -Depth 8 | Set-Content $reportPath -Encoding utf8

Write-Host ""
Write-Host "episodes  $($episodes.Count)" -ForegroundColor Green
Write-Host "win rate  $rate"
Write-Host "outcomes  $($outcomes -join ', ')"
if ($report.scorecard) {
    Write-Host "score     $($report.scorecard.score)"
    $gates = $report.scorecard.gates
    $gateOk = $gates.solvable -and $gates.deterministic
    Write-Host "gates     solvable=$($gates.solvable) deterministic=$($gates.deterministic)" -ForegroundColor ($(if ($gateOk) { "Green" } else { "Red" }))
    if ($previous -and $previous.scorecard) {
        $delta = [math]::Round($report.scorecard.score - $previous.scorecard.score, 4)
        Write-Host "delta     $delta vs previous run"
        if ($delta -gt 0 -and -not $gateOk) {
            Write-Host "REGRESSION: chaos rose but a gate failed. Revert the change." -ForegroundColor Red
        }
    }
}
Write-Host "report    games/$Game/chaos_report.json" -ForegroundColor DarkGray
