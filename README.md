# Raven Hub — elegant GRUB2 themes, now Ventoy-first

**Raven Hub** is a polished, lightweight set of dark-premium GRUB2 boot-menu
themes. It is a rebrand and hardening of the popular
[Elegant-grub2-themes](https://github.com/vinceliuice/elegant-grub2-themes)
project — the artwork, icons and fonts are unchanged and fully credited
(GPL-3.0, see `LICENSE` and `docs/CREDITS` section below).

Two ways to use it:

* **On a Ventoy USB (recommended, first-class support)** — build a
  copy-ready package with `./build-ventoy.sh` and drop it onto the USB data
  partition. Nothing is installed on your computer. → see **[VENTOY.md](VENTOY.md)**
* **On an installed Linux system** — `sudo ./install.sh` as before.

| | |
| --- | --- |
| Variants | 4 backgrounds (forest · mojave · mountain · wave) × 4 styles (window · float · sharp · blur) × left/right × dark/light × 1080p/2k/4k |
| Default look | mountain · float · left · dark (a.k.a. "the Raven") |
| Ventoy package size | **352 KiB (Lite)** · 3.1 MiB (Standard) |
| Runtime writes at boot | none |

## Ventoy USB — quick start

Build the copy-ready release folder with installers for Windows and Linux:

```sh
./make-ventoy-release.sh        # -> release/Raven-Hub-Ventoy (+ -Lite, + .zip)
```

* **Windows:** double-click `release/Raven-Hub-Ventoy/install-ventoy.cmd`,
  pick the USB drive, confirm. No admin rights needed.
* **Linux:** `release/Raven-Hub-Ventoy/install-ventoy.sh --target /media/$USER/Ventoy`
* **Manual:** copy the release's `ventoy` folder to the USB data partition
  root and copy `ventoy/ventoy.json.example` to `ventoy/ventoy.json`.

The installers back up an existing `ventoy.json` (timestamped) and merge only
the `"theme"` object — all other Ventoy plugins are preserved. Uninstallers
and recovery guides are included. Full documentation for power users:
**[VENTOY.md](VENTOY.md)**; acceptance tests for the simple flow:
**[docs/ACCEPTANCE-REPORT.md](docs/ACCEPTANCE-REPORT.md)**.

## Install on a running Linux system

Usage: `./install.sh [OPTIONS...]`

```
  -t, --theme     Background theme variant(s) [forest|mojave|mountain|wave] (default is forest)
  -p, --type      Theme style variant(s)      [window|float|sharp|blur] (default is window)
  -i, --side      Picture display side        [left|right] (default is left)
  -c, --color     Background color variant(s) [dark|light] (default is dark)
  -s, --screen    Screen display variant(s)   [1080p|2k|4k] (default is 1080p)
  -l, --logo      Show a logo on picture      [default|system] (default: a mountain logo)
  -r, --remove    Remove/Uninstall theme      (must add theme options, default is Raven-Hub-forest-window-left-dark;
                  this also removes legacy 'Elegant-…' installs of the same variant)
  -b, --boot      Install theme into '/boot/grub' or '/boot/grub2'
  -h, --help      Show this help
```

_If no options are used, a user interface `dialog` will show up instead_

### Examples

- Install the default mountain ("Raven") theme on a 2k display device:

  ```sh
  sudo ./install.sh -t mountain -s 2k
  ```

- Install the wave theme into `/boot/grub/themes`:

  ```sh
  sudo ./install.sh -b -t wave
  ```

- Uninstall the mountain theme (also removes any legacy `Elegant-mountain-…` copy):

  ```sh
  sudo ./install.sh -r -t mountain
  ```

The installer needs root; it will ask via `sudo` and never runs anything as
root on its own. It edits `/etc/default/grub` (backing it up first) and runs
your distribution's `grub-mkconfig`.

### Generate themes without installing

```sh
./generate.sh -d "/path with spaces/out" -t mountain -p float -c dark -s 1080p
```

### Build release tarballs (maintainers)

```sh
./make-release.sh -t mountain -p float      # or no options for everything
```

## Installation with NixOS

Enable [flakes](https://wiki.nixos.org/wiki/flakes), add this flake as an
input and use the module (option path: `boot.loader.raven-hub-theme`; the old
`boot.loader.elegant-grub2-theme` path keeps working via a rename shim):

```nix
# flake.nix
{
  inputs.raven-hub.url = "github:NggKhaiz/Elegant-grub2-themes";
  # ...
}
```

```nix
# configuration.nix
{ inputs, config, pkgs, lib, ... }:
{
  boot.loader.raven-hub-theme = {
    enable = true;
    theme = "mountain";   # forest | mojave | mountain | wave
    type = "float";       # window | float | sharp | blur
    side = "left";        # left | right
    color = "dark";       # dark | light
    screen = "1080p";     # 1080p | 2k | 4k
    logo = "default";     # default | system
  };
}
```

## Issues / tweaks

### Correcting display resolution

- On the GRUB screen, press `c` to enter the command line
- Enter `vbeinfo` or `videoinfo` to check available resolutions
- Open `/etc/default/grub`, and edit `GRUB_GFXMODE=[width]x[height]x32` to match your resolution
- Finally, run `grub-mkconfig -o /boot/grub/grub.cfg` to update your GRUB config

### Setting a custom background (installed themes)

- Make sure `convert` (ImageMagick) is installed
- Match the resolution of your display (1920×1080 → 1080p, 2560×1440 → 2k, 3840×2160 → 4k)
- Place your custom background in the repository root named `background.jpg`
- Run the installer with `-s [YOUR_RESOLUTION]`

### Ventoy troubleshooting (black screen, wrong resolution, missing font)

See the **recovery guide in [VENTOY.md](VENTOY.md#recovery)** — including the
zero-risk `F7` text-mode fallback that always gets you a bootable menu.

## Contributing

- If you change icons or add new ones: delete the existing icon file, then run
  `cd assets && ./render-all.sh` (requires Inkscape and OptiPNG).
- Create a pull request from your branch or fork.
- If any issues occur, report them on the [issue](issues) page.

## Preview

![preview-01](preview-01.jpg?raw=true)
![preview-02](preview-02.jpg?raw=true)
![preview-03](preview-03.jpg?raw=true)
![preview-04](preview-04.jpg?raw=true)

## Credits and license

- **Raven Hub** rebranding, Ventoy integration, reliability hardening and
  documentation: this repository's contributors.
- **Original artwork, icons, fonts and theme design**:
  [vinceliuice/elegant-grub2-themes](https://github.com/vinceliuice/elegant-grub2-themes)
  and its contributors (see the upstream commit history).
- Fonts: GNU Unifont (GNU Font License, © Roman Czyborra and contributors) and
  Terminus (SIL OFL 1.1, © Dimitar Toshkov Zhekov).
- License: **GPL-3.0** — see [LICENSE](LICENSE).
- GRUB2 theme references:
  [GRUB2 theme reference](https://wiki.rosalab.ru/en/index.php/Grub2_theme_/_reference),
  [GRUB2 theme tutorial](https://wiki.rosalab.ru/en/index.php/Grub2_theme_tutorial),
  [GNU GRUB manual](https://www.gnu.org/software/grub/manual/grub/grub.html).
- Ventoy documentation: <https://www.ventoy.net/en/plugin_theme.html>.

Technical notes and compatibility decisions: [docs/TECH-NOTES.md](docs/TECH-NOTES.md).
Migration & rollback (from Elegant releases): [docs/MIGRATION.md](docs/MIGRATION.md).
Validation report: [docs/VALIDATION-REPORT.md](docs/VALIDATION-REPORT.md).
