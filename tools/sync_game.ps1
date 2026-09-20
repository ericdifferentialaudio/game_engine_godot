<#
.SYNOPSIS
    Copies game packages from games/<id>/ into the engine API layer they target.

.DESCRIPTION
    Godot cannot resolve res:// paths outside a project root, so a game that
    lives in games/<id>/ (the authoritative source) must be physically copied
    into game_api/<engine>/games/<id>/ to run. Mirrors tools/sync_core.ps1.

    games/<id>/ is the ONLY source of truth. The copies under
    game_api/*/games/ are generated artifacts and are gitignored; never edit
    them. Which engine a game targets is declared by "engine" in its game.json
    ("isometric" | "fps"), so routing is data-driven rather than remembered.

    Run after ANY edit under games/<id>/, then launch with
        godot --path game_api/<engine> -- --game=<id>

.EXAMPLE
    ./tools/sync_game.ps1 -All                     # every game, to its declared engine
    ./tools/sync_game.ps1 -All -Check              # verify only, non-zero exit if stale
    ./tools/sync_game.ps1 -Game slack_tide         # one game, engine from its game.json
    ./tools/sync_game.ps1 -Game wardens -Engine fps   # explicit override
#>

param(
    [string]$Game,
    [ValidateSet('fps', 'isometric')][string]$Engine,
    [switch]$All,
    [switch]$Check
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

if (-not $All -and -not $Game) {
    Write-Host "Specify -Game <id> or -All." -ForegroundColor Red
    exit 1
}

# The engine a package targets is declared in its own game.json. An explicit
# -Engine overrides it; a package that declares nothing defaults to isometric.
function Get-TargetEngine([string]$gameId) {
    if ($Engine) { return $Engine }
    $cfgPath = Join-Path $repoRoot "games\$gameId\game.json"
    if (Test-Path $cfgPath) {
        $declared = (Get-Content $cfgPath -Raw | ConvertFrom-Json).engine
        if ($declared -in @('fps', 'isometric')) { return $declared }
        if ($declared) {
            Write-Host "games/$gameId/game.json declares unknown engine '$declared'" -ForegroundColor Red
            exit 1
        }
    }
    return 'isometric'
}

function Get-TreeHash([string]$path) {
    if (-not (Test-Path $path)) { return "" }
    $parts = Get-ChildItem -Path $path -Recurse -File -Include *.gd, *.json, *.tscn, *.tres, *.md |
        Where-Object { $_.Name -notlike '*.uid' -and $_.Name -notlike '*.import' } |
        Sort-Object FullName |
        ForEach-Object { "$($_.FullName.Substring($path.Length)):$((Get-FileHash $_.FullName).Hash)" }
    return ($parts -join "|")
}

# Sync one package. Returns 0 when in sync (or newly synced), 1 when -Check
# found it stale, so the caller can aggregate an exit code across all games.
function Sync-Package([string]$gameId) {
    $targetEngine = Get-TargetEngine $gameId
    $source = Join-Path $repoRoot "games\$gameId"
    $target = Join-Path $repoRoot "game_api\$targetEngine\games\$gameId"

    if (-not (Test-Path $source)) {
        Write-Host "Game package not found: $source" -ForegroundColor Red
        return 1
    }

    if ((Get-TreeHash $source) -eq (Get-TreeHash $target)) {
        Write-Host "up to date: $targetEngine/games/$gameId" -ForegroundColor DarkGray
        return 0
    }

    if ($Check) {
        Write-Host "STALE: $targetEngine/games/$gameId (run ./tools/sync_game.ps1 -All)" -ForegroundColor Red
        return 1
    }

    # Preserve Godot's generated .uid sidecars so scene/script references stay stable.
    $uids = @{}
    if (Test-Path $target) {
        Get-ChildItem $target -Recurse -File -Filter '*.uid' | ForEach-Object {
            $uids[$_.FullName.Substring($target.Length)] = Get-Content $_.FullName -Raw
        }
        Remove-Item $target -Recurse -Force
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    Copy-Item $source $target -Recurse -Force
    foreach ($rel in $uids.Keys) {
        $dest = Join-Path $target $rel
        $owner = $dest -replace '\.uid$', ''
        if ((Test-Path $owner) -and -not (Test-Path $dest)) { Set-Content -Path $dest -Value $uids[$rel] -NoNewline }
    }
    Write-Host "synced: games/$gameId -> game_api/$targetEngine/games/$gameId" -ForegroundColor Green
    return 0
}

$exitCode = 0
if ($All) {
    # Every package under games/ that is actually a package (has a game.json).
    Get-ChildItem (Join-Path $repoRoot "games") -Directory |
        Where-Object { Test-Path (Join-Path $_.FullName "game.json") } |
        ForEach-Object {
            if ((Sync-Package $_.Name) -ne 0) { $exitCode = 1 }
        }
} else {
    $exitCode = Sync-Package $Game
}
exit $exitCode
