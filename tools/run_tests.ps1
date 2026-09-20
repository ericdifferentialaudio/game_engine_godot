<#
.SYNOPSIS
    Runs the GUT unit test suite for all three Godot project roots in this
    repo (core harness, isometric game, fps game) and fails loudly if any
    of them fail. This is the single command to run before merging to main.

.DESCRIPTION
    Requires a Godot 4.x executable available on PATH as `godot`, or pass
    -GodotPath to point at the executable explicitly.

.EXAMPLE
    ./tools/run_tests.ps1
    ./tools/run_tests.ps1 -GodotPath "C:\Godot\Godot_v4.3-stable_win64.exe"
#>

param(
    [string]$GodotPath = "",
    [switch]$Import,
    [switch]$LogJson
)

# Godot writes push_warning()/push_error() to stderr, and PowerShell surfaces
# native stderr as error records. With ErrorActionPreference "Stop" that would
# abort this script on a perfectly healthy run, so we stay on "Continue" and
# judge success solely by each project's exit code below.
$ErrorActionPreference = "Continue"
$repoRoot = Split-Path -Parent $PSScriptRoot

# Resolve which Godot executable to use, in priority order:
#   1. -GodotPath argument, if passed explicitly
#   2. $env:GODOT_BIN, if set
#   3. `godot` on PATH
#   4. A known fallback location used on this dev machine (best-effort only;
#      the exact folder/filename changes with each Godot version, so this is
#      a convenience, not a guarantee -- prefer options 1-3 when possible).
if (-not $GodotPath) {
    if ($env:GODOT_BIN) {
        $GodotPath = $env:GODOT_BIN
    } elseif (Get-Command "godot" -ErrorAction SilentlyContinue) {
        $GodotPath = "godot"
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

$projects = @(
    @{ Name = "core";      Path = Join-Path $repoRoot "core" },
    @{ Name = "isometric"; Path = Join-Path $repoRoot "game_api\isometric" },
    @{ Name = "fps";       Path = Join-Path $repoRoot "game_api\fps" }
)

$overallExitCode = 0

foreach ($project in $projects) {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host " Running GUT tests: $($project.Name)" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan

    # A project whose .godot/ cache is missing or stale cannot resolve
    # class_name types, which shows up as confusing "Could not find type"
    # parse errors. Import first when asked, or when the cache is absent.
    if ($Import -or -not (Test-Path (Join-Path $project.Path ".godot"))) {
        Write-Host "Importing project first..." -ForegroundColor DarkGray
        cmd /c "`"$GodotPath`" --headless --import --path `"$($project.Path)`" >nul 2>&1"
    }

    # Run through cmd with stderr merged into stdout: Godot's push_warning()
    # output on stderr would otherwise be raised as PowerShell error records.
    if ($LogJson) {
        # Capture as well as display, so tools/regression_hook.py can turn the
        # run into structured records for post-analysis.
        $out = cmd /c "`"$GodotPath`" --headless -s --path `"$($project.Path)`" addons/gut/gut_cmdln.gd -gexit 2>&1"
        $exitCode = $LASTEXITCODE
        $out | Write-Host
        $tmp = Join-Path $env:TEMP "gut_$($project.Name).log"
        $out | Out-File -FilePath $tmp -Encoding utf8
        python (Join-Path $PSScriptRoot "regression_hook.py") --log $tmp --suite $project.Name --engine $project.Name
    } else {
        cmd /c "`"$GodotPath`" --headless -s --path `"$($project.Path)`" addons/gut/gut_cmdln.gd -gexit 2>&1"
        $exitCode = $LASTEXITCODE
    }

    if ($exitCode -ne 0) {
        Write-Host "FAILED: $($project.Name) (exit code $exitCode)" -ForegroundColor Red
        $overallExitCode = 1
    } else {
        Write-Host "PASSED: $($project.Name)" -ForegroundColor Green
    }
}

# Narrative gate. The Ink validator runs as a GUT test too, but a broken story
# should fail the merge gate on its own terms: this is the CLI writers use, and
# it exits non-zero on any ERROR-severity finding.
$inkChecks = @(
    @{
        Name  = "core ink (round_room_fence)"
        Path  = Join-Path $repoRoot "core"
        Args  = "--story=res://ink/round_room_fence.ink.json " +
                "--source=res://ink/round_room_fence.ink " +
                "--source=res://ink/patterns/patterns.ink " +
                "--axes=res://ink/round_room_fence.axes.json"
    },
    @{
        Name  = "iso slack_tide ink (corvin)"
        Path  = Join-Path $repoRoot "game_api\isometric"
        Args  = "--story=res://games/slack_tide/ink/corvin.ink.json " +
                "--source=res://games/slack_tide/ink/corvin.ink " +
                "--source=res://games/slack_tide/ink/patterns.ink " +
                "--axes=res://games/slack_tide/ink/corvin.axes.json " +
                "--package=res://games/slack_tide"
    }
)

foreach ($check in $inkChecks) {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host " Narrative validator: $($check.Name)" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan

    cmd /c "`"$GodotPath`" --headless --path `"$($check.Path)`" -s tools/validate_ink.gd -- $($check.Args) 2>&1"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED: $($check.Name) (exit code $LASTEXITCODE)" -ForegroundColor Red
        $overallExitCode = 1
    } else {
        Write-Host "PASSED: $($check.Name)" -ForegroundColor Green
    }
}

# Unit tests exercise the platform in isolation; these headless runs prove it is
# actually wired into each graphics engine at runtime (adapter installed, clock
# tracking, real game package loaded into CoreRegistry).
$runtimeChecks = @(
    @{ Name = "isometric (smoke)";   Path = Join-Path $repoRoot "game_api\isometric"; Arg = "--smoke" },
    @{ Name = "fps (boot check)";    Path = Join-Path $repoRoot "game_api\fps";       Arg = "--boot-check" },
    @{ Name = "iso slack_tide (smoke)"; Path = Join-Path $repoRoot "game_api\isometric"; Arg = "--game=slack_tide --smoke" }
)

# Game packages under games/ are copied into the engine layer to run; make
# sure NO copy is stale (see tools/sync_game.ps1). This checks every package,
# not a hand-picked one: aevum and paragon silently ran stale data for exactly
# as long as this check named only slack_tide.
Write-Host ""
Write-Host "Checking games/ sync (all packages)..." -ForegroundColor Cyan
& (Join-Path $PSScriptRoot "sync_game.ps1") -All -Check
if ($LASTEXITCODE -ne 0) { $overallExitCode = 1 }

# slack_tide's intel.json is GENERATED from docs/slack_tide_spec.json; a stale
# copy means the tokens on disk no longer match the design source of truth.
Write-Host ""
Write-Host "Checking slack_tide generated data..." -ForegroundColor Cyan
python (Join-Path $repoRoot "games\slack_tide\tools\convert_slack_tide.py") --check
if ($LASTEXITCODE -ne 0) { $overallExitCode = 1 }
python (Join-Path $repoRoot "games\slack_tide\tools\gen_topics.py") --check
if ($LASTEXITCODE -ne 0) { $overallExitCode = 1 }
# topics.json names 26 speaking sources; actors.json once had 6, so most of
# the cast -- including Doon and Brack, who are the endgame -- did not exist.
python (Join-Path $repoRoot "games\slack_tide\tools\gen_actors.py") --check
if ($LASTEXITCODE -ne 0) { $overallExitCode = 1 }
# Standing-cast dialogue is generated from topics.json (see
# CONVERSATION_GENERATOR.md); the 5 story-carrying NPCs are hand-written and
# the generator refuses to touch a file missing its own generated header.
python (Join-Path $repoRoot "games\slack_tide\tools\gen_dialogue.py") --check
if ($LASTEXITCODE -ne 0) { $overallExitCode = 1 }
python (Join-Path $repoRoot "games\slack_tide\tools\remap_story.py") --check
if ($LASTEXITCODE -ne 0) { $overallExitCode = 1 }

# The puzzle must be provably winnable in every seed (design milestone M0), and
# the BALANCE must stay inside its design band. The band matters more than any
# single number: a change that pushes the competent win rate to 0.95 is a
# REGRESSION, not an improvement, because the player stops being able to lose.
# Both run in pure Python -- no Godot, no engine -- so they cost seconds.
Write-Host ""
Write-Host "Checking slack_tide solvability and balance..." -ForegroundColor Cyan
Push-Location (Join-Path $repoRoot "games\slack_tide\tools")
python check_solvable.py --quiet
if ($LASTEXITCODE -ne 0) { $overallExitCode = 1 }
python regress.py --seeds 1500 --quiet
if ($LASTEXITCODE -ne 0) { $overallExitCode = 1 }
Pop-Location

# Narrative validation is SHARED, so it runs over EVERY game package, not just
# the one being worked on. Dangling dialogue knots, references to tokens that
# do not exist and Ink stories calling unbound EXTERNALs are the same class of
# bug everywhere, and a game with no narrative content simply reports zero.
Write-Host ""
Write-Host "Validating narrative content (all games)..." -ForegroundColor Cyan
Get-ChildItem (Join-Path $repoRoot "games") -Directory | ForEach-Object {
    python (Join-Path $repoRoot "core\tools\validate_narrative.py") $_.FullName --quiet
    if ($LASTEXITCODE -ne 0) { $overallExitCode = 1 }
}

# Per-engine data schemas. Both now import the IntelQuery grammar from core
# rather than each declaring their own (they had silently diverged: iso knew
# 20 keys, fps knew 8, core defines 19). See docs/CORE_REQUESTS.md CR-001.
Write-Host ""
Write-Host "Validating package data (per engine)..." -ForegroundColor Cyan
foreach ($engine in @("isometric", "fps")) {
    python (Join-Path $repoRoot "game_api\$engine\tools\validate_data.py") --all
    if ($LASTEXITCODE -ne 0) { $overallExitCode = 1 }
}

foreach ($check in $runtimeChecks) {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host " Runtime integration: $($check.Name)" -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan

    cmd /c "`"$GodotPath`" --headless --path `"$($check.Path)`" -- $($check.Arg) 2>&1"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED: $($check.Name) (exit code $LASTEXITCODE)" -ForegroundColor Red
        $overallExitCode = 1
    } else {
        Write-Host "PASSED: $($check.Name)" -ForegroundColor Green
    }
}

Write-Host ""
if ($overallExitCode -eq 0) {
    Write-Host "All project test suites passed." -ForegroundColor Green
} else {
    Write-Host "One or more project test suites failed. See output above." -ForegroundColor Red
}

exit $overallExitCode
