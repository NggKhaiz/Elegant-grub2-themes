# Raven Hub on Windows

## Easiest: double-click

1. Plug in the Ventoy USB stick and note its letter in Explorer
   (e.g. `E:`).
2. Double-click **`install-ventoy.cmd`** in this folder.
   * If Windows SmartScreen asks, choose *More info → Run anyway*
     (the script is a plain text file you can inspect first).
   * The launcher starts PowerShell with `-ExecutionPolicy Bypass`.
     That bypass applies to this one process only — your system-wide
     PowerShell policy is never changed.
3. Pick your USB drive from the list (look for *Removable* and its size).
4. Read the plan, type `y` to confirm.
5. Done — reboot from the USB.

## Direct PowerShell (if you prefer)

Right-click Start → *Windows PowerShell* / *Terminal*, then:

```powershell
cd C:\path\to\Raven-Hub-Ventoy
.\install-ventoy.ps1                      # interactive
.\install-ventoy.ps1 -Target E:\          # explicit drive
.\install-ventoy.ps1 -Target E:\ -DryRun  # show the plan only
```

If PowerShell refuses to run the script, use the launcher (`install-ventoy.cmd`)
or run explicitly:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-ventoy.ps1
```

## Manual installation (no scripts)

1. Open this folder and your Ventoy USB drive in Explorer.
2. Copy the `ventoy` folder here onto the USB drive (merge with the existing
   `ventoy` folder if Explorer asks — no files are overwritten except
   `theme\raven-hub`, which Raven Hub owns).
3. If the USB has no `ventoy\ventoy.json`: copy
   `ventoy\ventoy.json.example` to `ventoy\ventoy.json`.
4. If `ventoy\ventoy.json` already exists: do not overwrite it — replace only
   its `"theme"` object as shown in `README.md`.
5. Reboot and select the USB in your boot menu (usually F12 / F11 / Esc).

## Backup and rollback

* Before touching an existing `ventoy.json`, the installer saves
  `ventoy\ventoy.json.bak-YYYYMMDD-HHMMSS` on the USB.
* Rollback with PowerShell:

  ```powershell
  Copy-Item 'E:\ventoy\ventoy.json.bak-20260821-130500' 'E:\ventoy\ventoy.json' -Force
  ```

* Or in Explorer: delete `ventoy.json`, rename the `.bak-…` file to
  `ventoy.json`.

## Uninstall

Double-click is not provided for uninstall on purpose (it should be a
conscious action). In PowerShell:

```powershell
.\uninstall-ventoy.ps1 -Target E:\
```

Or manually: delete `E:\ventoy\theme\raven-hub` and remove the `"theme"`
object from `ventoy.json` (restore the backup instead if you prefer).
ISO files and other Ventoy settings are never touched. See `UNINSTALL.md`.

## Safety notes

* No Administrator rights are required (or used) — the script only writes to
  the USB data partition.
* The scripts contain no formatting, partitioning or boot-sector commands
  (no `Format-Volume`, `diskpart`, `Clear-Disk`, `Remove-Partition`).
* If the drive is not writable, the installer tells you and changes nothing.
