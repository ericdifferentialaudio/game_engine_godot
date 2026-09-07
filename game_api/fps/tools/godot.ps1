<#
.SYNOPSIS
  Repo wrapper around the Godot binary.

.DESCRIPTION
  Resolves the Godot executable in this order:
    1. $env:GODOT_BIN
    2. godot.local.json  -> { "godot_bin": "C:\\...\\godot_console.exe" }  (git-ignored, per machine)
    3. 'godot' on PATH
  Then runs a sub-command against the project root.

.EXAMPLE
  .\tools\godot.ps1 import            # headless import, generates .godot/ (first-time setup / CI)
  .\tools\godot.ps1 check             # headless parse of every .gd script (compile validation)
  .\tools\godot.ps1 edit              # open the editor
  .\tools\godot.ps1 run               # run default game (bootstrap.json)
  .\tools\godot.ps1 run example_realm # run a specific game package
  .\tools\godot.ps1 version
  .\tools\godot.ps1 raw -- --headless --quit   # pass anything through
#>
param(
    [Parameter(Position = 0)]
    [ValidateSet('import', 'check', 'test', 'edit', 'run', 'version', 'raw', 'which')]
    [string]$Command = 'version',

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$Rest
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Resolve-Godot {
    if ($env:GODOT_BIN -and (Test-Path $env:GODOT_BIN)) { return $env:GODOT_BIN }
    $local = Join-Path $Root 'godot.local.json'
    if (Test-Path $local) {
        $cfg = Get-Content $local -Raw | ConvertFrom-Json
        if ($cfg.godot_bin -and (Test-Path $cfg.godot_bin)) { return $cfg.godot_bin }
    }
    $cmd = Get-Command godot_console, godot -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    throw "Godot not found. Set GODOT_BIN, create godot.local.json (see godot.local.example.json), or add godot to PATH."
}

$Godot = Resolve-Godot

function Invoke-Godot([string[]]$GodotArgs) {
    Write-Host ">> godot $($GodotArgs -join ' ')" -ForegroundColor DarkGray
    & $Godot @GodotArgs 2>&1 | ForEach-Object { Write-Host $_ }
    return [int]$LASTEXITCODE
}

switch ($Command) {
    'which'   { Write-Output $Godot; exit 0 }
    'version' { exit (Invoke-Godot @('--version')) }
    'edit'    { Start-Process -FilePath $Godot -ArgumentList @('--path', "`"$Root`"", '--editor'); exit 0 }
    'run' {
        $args_ = @('--path', $Root)
        if ($Rest.Count -gt 0 -and $Rest[0] -notlike '--*') { $args_ += @('--', "--game=$($Rest[0])"); $Rest = $Rest[1..($Rest.Count)] }
        exit (Invoke-Godot ($args_ + $Rest))
    }
    'import'  { exit (Invoke-Godot @('--headless', '--path', $Root, '--import') + $Rest) }
    'check' {
        # Import first so class_name globals/UIDs are registered, then compile every
        # script and load every scene inside a real SceneTree (autoloads available).
        $code = Invoke-Godot @('--headless', '--path', $Root, '--import')
        if ($code -ne 0) { exit $code }
        exit (Invoke-Godot @('--headless', '--path', $Root, '-s', 'res://tools/check_scripts.gd'))
    }
    'test' {
        # In-engine unit tests (tests/godot/test_*.gd) via the built-in runner.
        exit (Invoke-Godot @('--headless', '--path', $Root, '-s', 'res://tests/godot/test_runner.gd'))
    }
    'raw'     { exit (Invoke-Godot $Rest) }
}
