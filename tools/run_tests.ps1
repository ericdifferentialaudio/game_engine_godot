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
    [switch]$Import
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
    cmd /c "`"$GodotPath`" --headless -s --path `"$($project.Path)`" addons/gut/gut_cmdln.gd -gexit 2>&1"

    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        Write-Host "FAILED: $($project.Name) (exit code $exitCode)" -ForegroundColor Red
        $overallExitCode = 1
    } else {
        Write-Host "PASSED: $($project.Name)" -ForegroundColor Green
    }
}

# Unit tests exercise the platform in isolation; these headless runs prove it is
# actually wired into each graphics engine at runtime (adapter installed, clock
# tracking, real game package loaded into CoreRegistry).
$runtimeChecks = @(
    @{ Name = "isometric (smoke)";   Path = Join-Path $repoRoot "game_api\isometric"; Arg = "--smoke" },
    @{ Name = "fps (boot check)";    Path = Join-Path $repoRoot "game_api\fps";       Arg = "--boot-check" }
)

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
