# Uninstall & rollback — Raven Hub for Ventoy

All steps touch **only** Raven Hub's own files:

* `ventoy/theme/raven-hub*` on the Ventoy USB
* the `"theme"` object inside `ventoy/ventoy.json`

ISO files, persistence files, other themes and every other Ventoy plugin are
never modified or deleted.

## Easiest: use the uninstaller

**Windows** (PowerShell, in the Raven-Hub folder):

```powershell
.\uninstall-ventoy.ps1 -Target E:\
```

**Linux**:

```sh
./uninstall-ventoy.sh --target /media/$USER/Ventoy
```

Both will remove the theme folder and cleanly delete the `"theme"` object
from `ventoy.json` — after saving another timestamped backup of the file.

## Manual removal (either OS)

1. Delete the folder `ventoy/theme/raven-hub` on the Ventoy USB.
2. Open `ventoy/ventoy.json` and delete the whole `"theme": { … }` object
   (including the braces and trailing comma), leaving everything else as is.
   *Or* simply restore a backup instead (below).
3. Reboot — Ventoy shows its stock menu again.

## Restoring a backup of ventoy.json

The installers keep timestamped backups next to the file, e.g.
`ventoy/ventoy.json.bak-20260821-130500`.

**Windows:**

```powershell
Copy-Item 'E:\ventoy\ventoy.json.bak-20260821-130500' 'E:\ventoy\ventoy.json' -Force
```

or use the uninstaller: `.\uninstall-ventoy.ps1 -Target E:\ -Restore 'E:\ventoy\ventoy.json.bak-…'`

**Linux:**

```sh
cp /media/$USER/Ventoy/ventoy/ventoy.json.bak-20260821-130500 \
   /media/$USER/Ventoy/ventoy/ventoy.json
```

or `./uninstall-ventoy.sh --target /media/$USER/Ventoy --restore /media/$USER/Ventoy/ventoy/ventoy.json.bak-…`

## If the boot menu is broken (black screen, glitches)

You usually do not need to uninstall anything:

1. At the Ventoy screen press **F7** — instant switch to the plain text
   menu (press again to switch back).
2. `F5 → Resolution Configuration` fixes a wrong display mode.
3. `F5 → Check plugin json configuration` validates `ventoy.json` on the USB.
4. For a permanent text-mode fallback, set `"display_mode": "CLI"` in the
   `"theme"` object (see README.md → Advanced).
