# install-ventoy.ps1 - install the Raven Hub theme onto a Ventoy USB drive.
#
# What it does:
#   * asks which drive is your Ventoy USB (or takes -Target like 'E:' or 'E:\')
#   * copies ventoy\theme\raven-hub into the USB's ventoy folder
#   * creates ventoy\ventoy.json from the minimal example when none exists
#   * when a ventoy.json already exists: makes a timestamped backup and merges
#     ONLY the "theme" object, leaving every other plugin key untouched
#   * validates the final JSON and prints the rollback command
#
# It NEVER formats, repartitions, touches boot sectors, runs Ventoy setup,
# deletes ISO files, or needs Administrator rights.
#
# Usage (normal):      .\install-ventoy.ps1
#   or explicit:       .\install-ventoy.ps1 -Target E:\
#   or no questions:   .\install-ventoy.ps1 -Target E:\ -Yes
#   or plan only:      .\install-ventoy.ps1 -Target E:\ -DryRun
#
# Exit codes: 0 success, 1 usage/aborted, 2 target problem,
#             3 theme copied but config not merged (instructions shown).

[CmdletBinding()]
param(
    [string]$Target = '',
    [switch]$Yes,
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$Script:ExitCode = 0

function Say($msg)  { Write-Host "==> $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "    $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "    $msg" -ForegroundColor Yellow }
function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red }

function Read-YesNo($question) {
    $a = Read-Host "$question [y/N]"
    return ($a -match '^(y|Y|yes|YES)$')
}

# UTF-8 WITHOUT BOM (Windows PowerShell 5.1 'UTF8' would add a BOM; Ventoy
# expects plain UTF-8/ASCII JSON).
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Write-Utf8NoBom($path, $text) {
    [System.IO.File]::WriteAllText($path, $text, $Utf8NoBom)
}

# ---------------------------------------------------------------- sources ---
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ThemeSrc  = Join-Path $ScriptDir 'ventoy\theme\raven-hub'
$Example   = Join-Path $ScriptDir 'ventoy\ventoy.json.example'
if (-not (Test-Path $ThemeSrc)) { Fail "theme folder not found: $ThemeSrc"; exit 2 }
if (-not (Test-Path $Example))  { Fail "example config not found: $Example"; exit 2 }

# ---------------------------------------------------------------- target ----
function Select-Target {
    if ($Target -ne '') {
        if ($Target -match '^[A-Za-z]:$') { $Target = "$Target\" }
        if (-not (Test-Path $Target -PathType Container)) {
            Fail "target does not exist: $Target"; exit 2
        }
        return (Resolve-Path $Target).Path
    }
    Write-Host ""
    Write-Host "Detected drives ('Removable' ones are the usual USB sticks):"
    $drives = @(Get-CimInstance Win32_LogicalDisk -Filter "DriveType = 2 OR DriveType = 3" |
                Sort-Object DriveType, DeviceID)
    $i = 0
    foreach ($d in $drives) {
        $type = if ($d.DriveType -eq 2) { 'Removable' } else { 'Fixed   ' }
        $gb = if ($d.Size) { [math]::Round($d.Size / 1GB, 1) } else { '?' }
        Write-Host ("    [{0}] {1}  {2}  {3} GB  {4}" -f $i, $type, $d.DeviceID, $gb, $d.VolumeName)
        $i++
    }
    Write-Host ("    [{0}]  Enter a folder path manually" -f $i)
    $sel = Read-Host "Select the Ventoy USB drive number (0-$i)"
    if ($sel -eq [string]$i) {
        $p = Read-Host "Enter the full path of the Ventoy USB data partition"
        if (-not (Test-Path $p -PathType Container)) { Fail "path does not exist: $p"; exit 2 }
        return (Resolve-Path $p).Path
    }
    $idx = 0
    if (-not [int]::TryParse($sel, [ref]$idx) -or $idx -lt 0 -or $idx -ge $drives.Count) {
        Fail "invalid selection"; exit 1
    }
    return ($drives[$idx].DeviceID + "\")
}

$UsbRoot = Select-Target

if (-not (Test-Path $UsbRoot)) { Fail "target does not exist: $UsbRoot"; exit 2 }

# writable?
try {
    $probe = Join-Path $UsbRoot ("raven-hub-probe-" + [guid]::NewGuid().ToString('N') + ".tmp")
    [System.IO.File]::WriteAllText($probe, "x")
    Remove-Item $probe -Force
} catch {
    Fail "target is not writable: $UsbRoot"
    Write-Host "    Open the drive in Explorer once, or re-insert the USB and try again."
    Write-Host "    This script deliberately does not ask for Administrator rights."
    exit 2
}

# ventoy dir: <root>\ventoy (created when missing), or the root itself
$VentoyDir = Join-Path $UsbRoot 'ventoy'
if (-not (Test-Path $VentoyDir) -and (Test-Path (Join-Path $UsbRoot 'ventoy.json'))) {
    $VentoyDir = $UsbRoot
}

$looksVentoy = (Test-Path $VentoyDir) -or (Get-ChildItem $UsbRoot -Filter '*.iso' -ErrorAction SilentlyContinue | Select-Object -First 1)
if (-not $looksVentoy -and -not $Force) {
    Warn "no 'ventoy' folder or ISO files found in: $UsbRoot"
    Warn "this may still be correct (for example a fresh drive)."
    if (-not (Read-YesNo "Continue with this target anyway?")) { Say "aborted, nothing was changed"; exit 1 }
}

$Json   = Join-Path $VentoyDir 'ventoy.json'
$Stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$Backup = "$Json.bak-$Stamp"

# ------------------------------------------------------------- plan/confirm -
Write-Host ""
Write-Host "Raven Hub - Ventoy theme installation" -ForegroundColor White
Write-Host "    USB target   : $UsbRoot"
Write-Host "    ventoy dir   : $VentoyDir (created if missing)"
Write-Host "    theme files  : ventoy\theme\raven-hub  (only 'raven-hub*' files are replaced)"
if (Test-Path $Json) {
    Write-Host "    existing cfg : YES - a timestamped backup will be created:"
    Write-Host "                    $Backup"
    Write-Host "                    then ONLY the 'theme' object is replaced;"
    Write-Host "                    all your other plugins stay unchanged."
} else {
    Write-Host "    existing cfg : none - the minimal Raven Hub config will be created."
}
Write-Host ""

if ($DryRun) { Say "dry run: nothing was changed."; exit 0 }
if (-not $Yes -and -not (Read-YesNo "Proceed?")) { Say "aborted, nothing was changed"; exit 1 }

# ------------------------------------------------------------ copy theme ----
Say "copying theme files..."
$themeDir = Join-Path $VentoyDir 'theme'
New-Item -ItemType Directory -Force -Path $themeDir | Out-Null
$ravenDir = Join-Path $themeDir 'raven-hub'
if (Test-Path $ravenDir) { Remove-Item $ravenDir -Recurse -Force }
Copy-Item $ThemeSrc $ravenDir -Recurse -Force
Say "theme installed: $ravenDir"

# ----------------------------------------------------------- configuration --
function Test-JsonFile($path) {
    try {
        Get-Content -LiteralPath $path -Raw | Out-Null
        $null = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        return $true
    } catch {
        return $false
    }
}

if (-not (Test-Path $Json)) {
    Copy-Item $Example $Json
    if (-not (Test-JsonFile $Json)) { Fail "created config failed validation (this is a bug)"; exit 3 }
    Say "created minimal config: $Json"
} else {
    Copy-Item $Json $Backup -Force
    Say "backup created: $Backup"

    try {
        $userJson   = Get-Content -LiteralPath $Json -Raw -Encoding UTF8 | ConvertFrom-Json
        $themeBlock = Get-Content -LiteralPath $Example -Raw -Encoding UTF8 | ConvertFrom-Json |
                      Select-Object -ExpandProperty 'theme'
        if ($null -eq $themeBlock) { throw "example config has no 'theme' object" }

        if ($userJson.PSObject.Properties['theme']) {
            $userJson.theme = $themeBlock          # replace in place (keeps key position)
        } else {
            $userJson | Add-Member -MemberType NoteProperty -Name 'theme' -Value $themeBlock
        }
        $merged = $userJson | ConvertTo-Json -Depth 32
        Write-Utf8NoBom $Json ($merged + "`n")

        if (-not (Test-JsonFile $Json)) { throw "merged JSON failed validation" }
        Say "merged Raven Hub theme into: $Json (other plugins untouched)"
    } catch {
        # restore the untouched backup, then explain exactly what to do
        Copy-Item $Backup $Json -Force
        Write-Host ""
        Fail "ventoy.json was NOT modified (parse/merge failed: $($_.Exception.Message))"
        Write-Host "The theme files are installed, but the theme is not activated yet."
        Write-Host "Manual activation: open"
        Write-Host "    $Json"
        Write-Host "make sure the 'theme' key looks like the one in this file:"
        Write-Host "    $Example"
        Write-Host "(copy the 'theme' object from there), keeping every other key unchanged."
        Write-Host "Install finished, theme NOT activated."
        exit 3
    }
}

Write-Host ""
Write-Host "SUCCESS - Raven Hub is installed." -ForegroundColor Green
Write-Host "    Installed to : $ravenDir"
Write-Host "    Config file  : $Json"
if (Test-Path $Backup) {
    Write-Host "    Backup       : $Backup"
    Write-Host "    Rollback     : Copy-Item '$Backup' '$Json' -Force"
}
Write-Host ""
Write-Host "Reboot from the USB - Raven Hub appears in the Ventoy menu."
Write-Host "If the menu is ever unreadable: press F7 for Ventoy's text mode."
Write-Host "Uninstall/rollback help: see UNINSTALL.md in this folder."
exit 0
