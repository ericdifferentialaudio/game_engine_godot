<#
.SYNOPSIS
    Runs the 3D asset generation pipeline (tools/generate_assets/) against a
    game's graphics assets.

.DESCRIPTION
    Thin wrapper around tools/generate_assets/generate_assets.py. That script
    attaches items to the hands/back/head of rigged base unit meshes, animates
    the result via Meshy's rig + text-to-motion API, and renders the animated
    meshes into sprite frames -- re-running only the stages that are stale.

    The pipeline lives in the ENGINE repo but always operates on a GAME's
    assets. This wrapper resolves that assets root as:
        -AssetsRoot <path>  >  $env:AEVUM_ASSETS_ROOT  >  the current directory
    and passes it through explicitly, so it is safe to invoke from anywhere.

    The Meshy API key must be available as $env:MESHY_API_KEY, or on line 1 of
    the game's own model_definitions.txt. Never commit a real key into this
    repo -- see tools/generate_assets/README.md.

    Any extra arguments are forwarded verbatim to generate_assets.py
    (--clan, --unit-type, --model, --state, --force, --skip-render, --mode,
    --blender, ...).

.EXAMPLE
    ./tools/generate_assets.ps1 -AssetsRoot C:\my_game\graphics -DryRun
    ./tools/generate_assets.ps1 -AssetsRoot C:\my_game\graphics --clan bard --unit-type scout
    ./tools/generate_assets.ps1 --clan bard --unit-type scout --state attack --force
#>

[CmdletBinding()]
param(
    [string]$AssetsRoot,
    [switch]$DryRun,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Forward
)

$ErrorActionPreference = "Stop"

$entry = Join-Path $PSScriptRoot "generate_assets\generate_assets.py"
if (-not (Test-Path $entry)) {
    throw "generate_assets.py not found at $entry"
}

if (-not $AssetsRoot) {
    $AssetsRoot = if ($env:AEVUM_ASSETS_ROOT) { $env:AEVUM_ASSETS_ROOT } else { (Get-Location).Path }
}
$AssetsRoot = (Resolve-Path -LiteralPath $AssetsRoot).Path

$pyArgs = @($entry, "--assets-root", $AssetsRoot)
if ($DryRun) { $pyArgs += "--dry-run" }
if ($Forward) { $pyArgs += $Forward }

Write-Host "[generate_assets.ps1] assets root: $AssetsRoot"
& python @pyArgs
exit $LASTEXITCODE
