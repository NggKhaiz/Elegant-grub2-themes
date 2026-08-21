# uninstall-ventoy.ps1 - remove ONLY the Raven Hub theme from a Ventoy USB.
#
# It removes:
#   * ventoy\theme\raven-hub*            (theme files)
#   * the "theme" object in ventoy.json  (with a timestamped backup first)
#
# It NEVER touches ISO files, persistence files, other themes, unrelated
# Ventoy plugins, or disk/partition structure. No Administrator rights needed.
#
# Usage:
#   .\uninstall-ventoy.ps1                       # interactive
#   .\uninstall-ventoy.ps1 -Target E:\           # explicit drive
#   .\uninstall-ventoy.ps1 -Target E:\ -Restore "E:\ventoy\ventoy.json.bak-..."
#
# Exit codes: 0 success, 1 usage/aborted, 2 target problem,
#             3 config not edited (manual instructions shown).

[CmdletBinding()]
param(
    [string]$Target = '',
    [switch]$Yes,
    [string]$Restore = ''
)

$ErrorActionPreference = 'Stop'

function Say($msg)  { Write-Host "==> $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red }

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ($Target -eq '') {
    $Target = Read-Host "Enter the Ventoy USB drive letter or path (e.g. E:\ )"
}
if ($Target -match '^[A-Za-z]:$') { $Target = "$Target\" }
if (-not (Test-Path $Target -PathType Container)) { Fail "target does not exist: $Target"; exit 2 }
$UsbRoot = (Resolve-Path $Target).Path

$VentoyDir = Join-Path $UsbRoot 'ventoy'
if (-not (Test-Path $VentoyDir) -and (Test-Path (Join-Path $UsbRoot 'ventoy.json'))) {
    $VentoyDir = $UsbRoot
}
if (-not (Test-Path $VentoyDir)) { Fail "no 'ventoy' folder found in $UsbRoot"; exit 2 }

$Json = Join-Path $VentoyDir 'ventoy.json'

# ----------------------------------------------------------- restore mode ---
if ($Restore -ne '') {
    if (-not (Test-Path $Restore)) { Fail "backup file not found: $Restore"; exit 2 }
    if (-not (Test-Path $Json))    { Fail "no ventoy.json at $Json - copy the backup there manually"; exit 2 }
    Copy-Item $Json "$Json.pre-restore-$(Get-Date -Format 'yyyyMMdd-HHmmss')" -Force
    Copy-Item $Restore $Json -Force
    Say "restored $Restore -> $Json"
    exit 0
}

# -------------------------------------------------------- normal uninstall --
$themeRoot = Join-Path $VentoyDir 'theme'
$ravenDirs = @()
if (Test-Path $themeRoot) {
    $ravenDirs = @(Get-ChildItem $themeRoot -Directory -Filter 'raven-hub*')
}

Write-Host ""
Write-Host "Raven Hub - uninstall"
Write-Host "    target : $UsbRoot"
Write-Host "    theme  : $(if ($ravenDirs.Count) { ($ravenDirs.Name -join ', ') } else { '<none found>' })"
Write-Host "    config : $Json"
Write-Host "    ISO files, other themes and unrelated plugins are NEVER touched."
if ($ravenDirs.Count -eq 0 -and -not (Test-Path $Json)) {
    Say "nothing to remove - Raven Hub is not installed here."; exit 0
}
if (-not $Yes) {
    $a = Read-Host "Proceed? [y/N]"
    if ($a -notmatch '^(y|Y|yes|YES)$') { Say "aborted, nothing was changed"; exit 1 }
}

foreach ($d in $ravenDirs) {
    Remove-Item $d.FullName -Recurse -Force
    Say "removed ventoy\theme\$($d.Name)"
}

if (Test-Path $Json) {
    $Backup = "$Json.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    try {
        Copy-Item $Json $Backup -Force
        $obj = Get-Content -LiteralPath $Json -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($obj.PSObject.Properties['theme']) {
            $obj.PSObject.Properties.Remove('theme')
        }
        $out = $obj | ConvertTo-Json -Depth 32
        [System.IO.File]::WriteAllText($Json, $out + "`n", (New-Object System.Text.UTF8Encoding($false)))
        $null = Get-Content -LiteralPath $Json -Raw | ConvertFrom-Json   # validate
        Say "removed 'theme' from ventoy.json (backup: $Backup)"
    } catch {
        Fail "could not edit ventoy.json safely - nothing was overwritten"
        Write-Host "Manual fix: open $Json and delete the 'theme' object."
        Write-Host "A backup was saved at $Backup"
        exit 3
    }
}

Write-Host ""
Write-Host "SUCCESS - Raven Hub removed. Ventoy shows its stock menu again." -ForegroundColor Green
Write-Host "Restore the previous config any time:"
Write-Host "    .\uninstall-ventoy.ps1 -Target $UsbRoot -Restore '<backup path>'"
exit 0
