# Raven Hub — Ventoy theme, ready to copy

A dark-premium boot-menu theme for your Ventoy USB. One folder, one small
config file, installers for Windows and Linux — no GRUB knowledge needed.

> Raven Hub is a rebrand of the Elegant-grub2-themes project (art by
> vinceliuice et al., GPL-3.0). The theme is only read at boot: it writes
> nothing to the USB and does not affect the life of your drive beyond the
> storage it occupies (Lite: ~0.4 MB, Standard: ~3 MB).

## Install in three steps

**Windows** — double-click `install-ventoy.cmd`, pick your USB drive,
confirm. Done. (Details: `README-WINDOWS.md`.)

**Linux** — open a terminal in this folder:

```sh
chmod +x install-ventoy.sh
./install-ventoy.sh --target /media/$USER/Ventoy
```

(Details: `README-LINUX.md`.)

**Manual (either OS)** — copy this folder's `ventoy` directory to the root of
the Ventoy USB data partition (the big partition that holds your ISO files).
If the USB has no `ventoy/ventoy.json` yet, copy
`ventoy/ventoy.json.example` to `ventoy/ventoy.json`. If a `ventoy.json`
already exists, see "If you already have a ventoy.json" below.

Then reboot from the USB — the Raven Hub menu appears.

## What the installer does

1. Copies the theme to `ventoy/theme/raven-hub` on the USB (replaces only
   Raven Hub's own files).
2. If no `ventoy/ventoy.json` exists, creates one with the minimal Raven Hub
   configuration.
3. If `ventoy.json` exists, saves a timestamped backup and merges **only**
   the `"theme"` object — all your other Ventoy plugins (`control`,
   `menu_alias`, `persistence`, …) are preserved unchanged.
4. Validates the resulting JSON before reporting success.

The installers never format, repartition or touch boot sectors, never run
Ventoy's own installer, never delete ISOs, and never need admin/root rights.

## If you already have a ventoy.json (manual merge)

Open `ventoy/ventoy.json` in any text editor. Find the top-level `"theme"`
key and replace its value — or add this key if there is none:

```json
"theme": {
    "file": "/ventoy/theme/raven-hub/theme.txt",
    "gfxmode": "1024x768",
    "display_mode": "GUI",
    "ventoy_left": "5%",
    "ventoy_top": "95%",
    "ventoy_color": "#8B8B8B",
    "fonts": [
        "/ventoy/theme/raven-hub/fonts/terminus-14.pf2",
        "/ventoy/theme/raven-hub/fonts/unifont-16.pf2"
    ]
}
```

Keep every other key exactly as it is. (The `fonts` entries load the theme's
fonts — without them the menu falls back to a plainer font.)

## Recovery — if the boot menu looks wrong

* **Black screen / unreadable menu:** press **F7** once — Ventoy instantly
  switches to its plain text menu. Everything keeps working.
* **Wrong resolution or tiny/huge UI:** `F5 → Resolution Configuration` at
  the Ventoy menu.
* **Undo everything:** see `UNINSTALL.md` — or simply restore the backup the
  installer made (`ventoy.json.bak-…`) and delete `ventoy/theme/raven-hub`.

The theme can never make the USB unbootable: Ventoy only uses it for drawing.

## Advanced (optional, clearly labelled)

* **Sharper rendering on modern screens** — instead of the safe default
  `"gfxmode": "1024x768"`, advanced users may set `"gfxmode": "1920x1080"`
  or `"max"`. On some old firmware these can render poorly — F7 always
  rescues you.
* **Text mode permanently (very old machines):**

  ```json
  "theme": { "file": "/ventoy/theme/raven-hub/theme.txt", "display_mode": "CLI" }
  ```

* **Distro icons next to ISO names:** add a `menu_class` array (see the
  Ventoy menu_class documentation; icons are in
  `ventoy/theme/raven-hub/icons/`, Standard package only).
* Rebuild/customize the package from source: `build-ventoy.sh --help` in the
  Raven Hub repository.

## What is inside

| File | Purpose |
| --- | --- |
| `install-ventoy.cmd` / `install-ventoy.ps1` | Windows installer (double-click) |
| `install-ventoy.sh` | Linux installer |
| `uninstall-ventoy.ps1` / `uninstall-ventoy.sh` | Clean removal (or see `UNINSTALL.md`) |
| `ventoy/ventoy.json.example` | minimal Raven Hub configuration |
| `ventoy/theme/raven-hub/…` | the theme: background, fonts, icons, highlight |
| `README-WINDOWS.md`, `README-LINUX.md`, `UNINSTALL.md` | platform guides |

This is the **Standard** package (full Unicode fonts + distro icons, ~3 MB).
A **Lite** package (~0.4 MB, Latin/Greek/Cyrillic fonts, no icons) ships
alongside it as `Raven-Hub-Ventoy-Lite` — same installers, same steps.
