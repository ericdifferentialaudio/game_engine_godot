<#
.SYNOPSIS
    Single entry point to regenerate, validate, sync and launch Slack Tide.

.DESCRIPTION
    Runs the data pipeline in the order that matters:
      1. tools/convert_slack_tide.py  - docs/slack_tide_spec.json -> intel.json
      2. tools/validate_slack_tide.py - content integrity (non-zero on ERROR)
      3. tools/sync_game.ps1          - copies games/slack_tide ->
                                        game_api/isometric/games/slack_tide,
                                        since Godot cannot resolve res://
                                        across project roots
      4. launches the isometric engine layer on the slack_tide package

    Resolves a Godot executable in priority order:
      1. -GodotPath argument, if passed explicitly
      2. $env:GODOT_BIN, if set
      3. `godot` on PATH
      4. C:\Tools\Godot\4.7.2\godot_console.exe (this repo's documented path)

.EXAMPLE
    ./games/slack_tide/run.ps1
    ./games/slack_tide/run.ps1 -Check       # validate only, change nothing
    ./games/slack_tide/run.ps1 -NoSync      # skip the sync step
#>

param(
    [string]$GodotPath = "",
    [switch]$Check,
    [switch]$NoSync
)

$ErrorActionPreference = "Stop"
$gameRoot = $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $gameRoot)

# --- 1. Regenerate intel.json from the spec ---------------------------------
$convert = Join-Path $gameRoot "tools\convert_slack_tide.py"
if ($Check) {
    python $convert --check
    if ($LASTEXITCODE -ne 0) { exit 1 }
} else {
    python $convert
    if ($LASTEXITCODE -ne 0) { exit 1 }
}

# --- 1b. Recompile any .ink whose .ink.json is stale --------------------------
# inklecate is vendored (tools/inklecate/) and the .ink.json IS committed, so
# only writers need it. If it is missing we skip rather than fail.
$inklecate = Join-Path $repoRoot "tools\inklecate\inklecate.exe"
if (Test-Path $inklecate) {
    Get-ChildItem (Join-Path $gameRoot "ink") -Filter "*.ink" |
        Where-Object { $_.Name -ne "patterns.ink" } | ForEach-Object {
            $json = [IO.Path]::ChangeExtension($_.FullName, ".ink.json")
            if ((-not (Test-Path $json)) -or
                ($_.LastWriteTimeUtc -gt (Get-Item $json).LastWriteTimeUtc)) {
                Write-Host "compiling: $($_.Name)" -ForegroundColor Cyan
                & $inklecate -o $json $_.FullName
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "Ink compile failed: $($_.Name)" -ForegroundColor Red
                    exit 1
                }
            }
        }
} else {
    Write-Host "inklecate not found; using committed .ink.json" -ForegroundColor DarkGray
}

# --- 2. Validate content ------------------------------------------------------
# The validator is SHARED (core/tools/), not game-specific: dangling knots,
# unknown token references and unbound Ink EXTERNALs are the same bugs in
# every game, so the logic lives in core and this just points it here.
python (Join-Path $repoRoot "core\tools\validate_narrative.py") $gameRoot
if ($LASTEXITCODE -ne 0) {
    Write-Host "Content validation failed." -ForegroundColor Red
    exit 1
}

if ($Check) {
    Write-Host "slack_tide: data regenerated and valid." -ForegroundColor Green
    exit 0
}

# --- 3. Sync into the engine layer -------------------------------------------
if (-not $NoSync) {
    & (Join-Path $repoRoot "tools\sync_game.ps1") -Game slack_tide -Engine isometric
    if ($LASTEXITCODE -ne 0) { exit 1 }
}

# --- 4. Resolve Godot and launch ---------------------------------------------
function Resolve-Godot {
    if ($GodotPath -and (Test-Path $GodotPath)) { return $GodotPath }
    if ($env:GODOT_BIN -and (Test-Path $env:GODOT_BIN)) { return $env:GODOT_BIN }
    $onPath = Get-Command godot -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }
    $documented = "C:\Tools\Godot\4.7.2\godot_console.exe"
    if (Test-Path $documented) { return $documented }
    return $null
}

$godot = Resolve-Godot
if (-not $godot) {
    Write-Host "Godot not found. Pass -GodotPath, set `$env:GODOT_BIN, or put godot on PATH." -ForegroundColor Red
    exit 1
}

& $godot --path (Join-Path $repoRoot "game_api\isometric") -- --game=slack_tide
exit $LASTEXITCODE
