# Migration & rollback guide (Elegant → Raven Hub)

This project was rebranded from **Elegant-grub2-themes** to **Raven Hub**.
This page tells you exactly what changed, how to move existing installs over,
and how to roll everything back. Legacy "Elegant" naming is intentionally kept
only here, in code that cleans up legacy installs, and in the credits.

## What changed

| Before (Elegant) | After (Raven Hub) |
| --- | --- |
| Theme directories `Elegant-<theme>-<type>-<side>-<color>` | `Raven-Hub-<theme>-<type>-<side>-<color>` |
| Installed by `install.sh` (same options) | Same options, new names, plus bug fixes |
| `make-release.sh` → `Elegant-…-grub-themes.tar.xz` | `Raven-Hub-…-grub-themes.tar.xz` |
| NixOS option `boot.loader.elegant-grub2-theme` | `boot.loader.raven-hub-theme` (old path still works, prints a deprecation notice) |
| Nix flake fetched upstream vinceliuice source | Builds **this** repository (`self`) |
| No Ventoy support | `build-ventoy.sh` + `VENTOY.md` + merge tooling |
| `theme.txt` referenced non-existent `terminal_box_*.png` | Dead reference removed (behavior unchanged — the files never existed) |

### Behavioral fixes you get for free

* `install.sh`/`generate.sh`/`make-release.sh`: quoting fixes (paths with
  spaces), actionable dependency errors, `--help` for make-release, safe
  re-exec of the original arguments under sudo (previously `-l system` was
  lost), legacy-aware uninstall, timeout-safe password prompt.
* The uninstaller now also removes legacy `Elegant-*` directories of the same
  variant and creates an explicit backup before editing GRUB config.

## Migrating an installed-system theme

Simply install the Raven Hub variant you want; it lands next to (not over)
any old Elegant theme:

```sh
sudo ./install.sh -t mountain -p float -c dark -s 1080p
```

To retire the old copy afterwards:

```sh
sudo ./install.sh -r -t mountain -p float -c dark
```

(`-r` removes **both** the new `Raven-Hub-…` and legacy `Elegant-…`
directories for that variant, from all three known theme locations.)

## Migrating a Ventoy USB that used an Elegant theme manually

1. Remove the old theme directory (commonly `/ventoy/theme/Elegant-…`).
2. Build the Raven Hub package: `./build-ventoy.sh`.
3. Merge the new `theme` object into your existing `ventoy.json`:
   ```sh
   tools/ventoy-merge-theme.sh --existing /media/$USER/VENTOY/ventoy/ventoy.json \
                               --theme dist/ventoy/ventoy.json --in-place
   ```
4. Reboot. The merge tool left `ventoy.json.bak-YYYYmmdd-HHMMSS` for rollback.

## Migrating the NixOS module

```nix
# before
boot.loader.elegant-grub2-theme = { enable = true; theme = "mojave"; ... };

# after
boot.loader.raven-hub-theme = { enable = true; theme = "mojave"; ... };
```

The old attribute still evaluates (renamed option with a warning) while you
migrate. If you pinned the flake input `elegant-grub2-theme-src`, switch the
input to this repository — the module now builds from the flake itself.

## Rollback

**Installed systems:**

1. `sudo ./install.sh -r -t <theme> -p <type> -i <side> -c <color>` removes
   the Raven Hub (and legacy) directories and comments out `GRUB_THEME` in
   `/etc/default/grub` (a backup `grub.raven-hub.bak` is kept next to it).
2. Restore stock GRUB: restore `/etc/default/grub` from `grub.bak`
   (`sudo cp /etc/default/grub.bak /etc/default/grub`) and re-run
   `grub-mkconfig -o /boot/grub/grub.cfg` (or `grub2-mkconfig`, per distro).
3. To go back to an *Elegant* release, install it from the upstream project —
   the two can also coexist (different directory names).

**Ventoy USB:** see [VENTOY.md §9](../VENTOY.md) — delete
`/ventoy/theme/raven-hub*`, remove the `"theme"` object (or restore the merge
backup), done.

**Releases tarballs:** old `Elegant-*.tar.xz` archives remain valid; new ones
are named `Raven-Hub-*.tar.xz` (`.gitignore` covers both via `releases/*.tar.xz`).
