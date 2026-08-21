# Initial audit — Elegant-grub2-themes baseline (before Raven Hub changes)

Repository state at the start of this work: branch
`arena/01a02428-elegant-grub2-themes`, single squashed commit `f8a8d41`
("Merge pull request #22 from Kolby11/main"), clean working tree.
This audit was performed **before** any modification; every finding below was
verified by reading the file and, where possible, by executing the code.

## 1. Inventory (baseline)

| Path | Contents |
| --- | --- |
| `install.sh` | interactive/CLI installer for the running OS (dialog TUI, sudo re-exec, edits `/etc/default/grub`) |
| `core.sh` | sourced library: variants, `copy_files`, `install`, `remove`, dialog flow, `updating_grub` |
| `generate.sh` | writes theme directories to `--dest` without installing |
| `make-release.sh` | builds 16 release tarballs into `releases/` |
| `releases/install` | template installer shipped inside release tarballs (`grub_theme_name` sed-replaced) |
| `config/theme-*.txt` | 36 theme definitions (3 styles × 2 sides × 2 colors × 3 resolutions; `blur` reuses `sharp`-dark config) |
| `backgrounds/` | 4 SVG sources + 16 rendered JPEGs each (1920×1080), 4 preview SVGs, render scripts |
| `assets/` | icon sets (dark/light × 1080p/2k/4k, 78 icons each), `other-*` pixmaps (81 each), SVG sources, render scripts |
| `common/` | Terminus 12–18 pf2, Unifont 16/24/32 pf2, `unifont.otf`, `makefont.sh` |
| `flake.nix` | NixOS module `boot.loader.elegant-grub2-theme` (fetches **upstream** vinceliuice source) |
| `README.md`, `LICENSE` (GPL-3.0), `preview-0*.jpg`, `.gitignore` | docs/licensing |

No Ventoy support, no Ventoy packaging, no merge tooling, no validation.

## 2. Bugs and risks found in the baseline (all addressed — see VALIDATION-REPORT)

### Shell reliability

1. **`core.sh: REO_DIR` unquoted** `$(dirname $0)` — breaks for paths with spaces.
2. **`generate.sh: mkdir -p ${dest}` unquoted** — `--dest "path with spaces"` fails or creates wrong dirs.
3. **`install()/remove()` sudo re-exec reconstructs arguments** `-t … -p … -l ${logo}` —
   `${logo}` is unset when `-l` was not given and **loses `-l system`** when it was
   (the resolved distribution logo falls back to `Default` after re-exec).
4. **`prompt()` used `${@/-s/}`** — pattern-replaces the flag *inside message text* and
   mixes string+array (ShellCheck SC2145 in `releases/install`).
5. **`lsb_release -i` parsing assumed** (`cut -d ' ' -f 2`) and no check that
   `lsb_release` exists; silently yields a broken logo name on many distros.
6. **`remove()` backup/cleanup bug**: `sed --in-place='.bak'` then deletes
   `"$grub_config_location".back` — a file that never exists (the real backup is `.bak`);
   the sed pattern also interpolates user-controlled paths (`&`, `|` break it).
7. **`remove()` hard-codes the three theme locations but only the `Elegant-` name**;
   **`[[ -d "${THEME_DIR}" ]]`-style chain mis-reports** "theme does not exist" when a
   dir exists in another location or under the legacy name.
8. **`read -t 20` without `|| true` under `set -o errexit`** — password prompt timeout
   aborts the script silently with no message.
9. **Missing dependency checks**: `convert` (custom background), `dialog`, `sudo`
   absence — raw failures, no actionable message.
10. **`install()` crashes after installing files** when `/etc/default/grub` does not
    exist (`cp -an` raw error) — half-completed state.
11. **`copy_files` copies before validating sources** — a broken repo copy leaves a
    half-written theme dir.
12. **`has_command` unquoted** argument.
13. `make-release.sh`: unquoted expansions throughout, no `--help`, no variant
    validation, silently depends on pre-rendered previews.

### GRUB theme / asset references

14. **All 36 `config/theme-*.txt` reference `terminal-box: "terminal_box_*.png"` —
    no such file exists anywhere in the repository** (dead reference; GRUB silently
    falls back, but every theme validation tool flags it).
15. Fonts: theme references (`Unifont Regular 16/24/32`, `Terminus Regular 12–18`)
    verified to match the `NAME` chunks inside the shipped pf2 files (parsed) — baseline
    correct; `copy_files` ships all Terminus sizes + the one needed Unifont size.

### Branding / packaging

16. `flake.nix` fetches **upstream** `vinceliuice/Elegant-grub2-themes` — a fork's
    module would install the *upstream* theme, not the fork's changes.
17. `.gitignore` enumerates 16 release tarball names individually; nothing ignores
    `dist/` style build outputs (none existed).
18. Documentation had no Ventoy, recovery, merge, migration or rollback content.

## 3. Compatibility constraints identified before changing anything

* Variant CLI (`-t/-p/-i/-c/-s/-l/-r/-b`) is used by downstream tooling
  (incl. the NixOS module invoking `generate.sh`) → option semantics preserved.
* Installed theme directory names change with the rebrand (`Elegant-…` →
  `Raven-Hub-…`) → uninstall handles **both** names (see `docs/MIGRATION.md`).
* `releases/install` template's `grub_theme_name` placeholder consumed by
  `make-release.sh` → placeholder preserved.
* Art assets, fonts and licenses remain untouched (GPL-3.0 attribution kept).
