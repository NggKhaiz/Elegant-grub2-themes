# Raven Hub — Technical Notes & Compatibility Decisions

Status: implementation research for the "Raven Hub" rebrand of Elegant-grub2-themes
with first-class Ventoy support. All claims below are backed by the cited sources
(retrieved 2026-08-21) or by direct inspection recorded in `docs/VALIDATION-REPORT.md`.

---

## 1. Product identity

| Item | Value |
| --- | --- |
| Product name | **Raven Hub** |
| Technical slug | `raven-hub` |
| GRUB theme directory name (distro installs) | `Raven-Hub-<background>-<style>-<side>-<color>` |
| Ventoy theme path on USB | `/ventoy/theme/raven-hub/theme.txt` |
| Visual base | Upstream "Elegant" mountain / float / left / dark variant (unchanged art) |
| Attribution | Original theme art, icons and fonts are from `vinceliuice/Elegant-grub2-themes` (GPL-3.0). Credits preserved in `README.md`, `VENTOY.md`, package `README.md` files and theme headers. |

## 2. Ventoy theme plugin — verified facts

Source: official Ventoy documentation, <https://www.ventoy.net/en/plugin_theme.html>
and <https://www.ventoy.net/en/plugin_dual_option.html>.

* `ventoy.json` lives at the root of the Ventoy **data partition**, conventionally
  `/ventoy/ventoy.json`.
* A `theme` object supports (exactly these keys are relevant to us):
  * `file` — string **or** string array of `theme.txt` paths.
  * `default_file` — integer selector when `file` is an array (0 = random, 1..N = pick).
  * `resolution_fit` — 0/1; when `file` is an array and `default_file=0`, Ventoy keeps
    only themes whose **full path contains an `WWWxHHH` string** matching the current
    video mode (the `x` must be lowercase).
  * `gfxmode` — GRUB gfxmode string. **Ventoy default is `1024x768`**; the special
    value `max` selects the maximum available mode at boot.
  * `display_mode` — `GUI` (default), `CLI` (text mode), `serial`, `serial_console`.
    The docs explicitly recommend CLI for machines where the GUI menu cannot render.
  * `ventoy_left` / `ventoy_top` / `ventoy_color` — position/color of the Ventoy
    version string (defaults `5%`, `95%`, `#0000ff`).
  * `fonts` — array of **absolute paths** of `.pf2` files Ventoy `loadfont`s before
    applying the theme.
* Multi-mode keys (official): `theme_legacy`, `theme_uefi`, `theme_ia32`,
  `theme_aa64`, `theme_mips` — per BIOS-mode overrides; a plain `theme` applies to all
  modes, and mode-specific keys win over `theme` for that mode.
* Recovery without editing files: `F7` (or `F5 Tools → Screen Display Mode`) toggles
  text/GUI mode at runtime; `F5 Tools → Resolution Configuration` changes gfxmode;
  `F5 Tools → Check plugin json configuration` validates `ventoy.json` on the USB.
* Ventoy substitutes theme label macros `@VTOY_HOTKEY_TIP@` and `@VTOY_MEM_DISK@`
  (documented hotkey-tips `hbox` snippet).
* Menu icons: with the `menu_class` plugin, entries get a class and the icon is
  `icons/<class>.png` inside the theme directory. Ventoy also assigns built-in
  classes (`vtoyiso`, `vtoydir`, `vtoyret`, `vtoywim`, `vtoyimg`, `vtoyefi`, …) when
  nothing matches. Source: <https://www.ventoy.net/en/plugin_menuclass.html>.

## 3. What Ventoy's GRUB can actually render (source-verified)

From the Ventoy build script `GRUB2/MOD_SRC/grub-2.04/install.sh` on master
(<https://github.com/ventoy/Ventoy/blob/master/GRUB2/MOD_SRC/grub-2.04/install.sh>),
the `grub-mkimage` module lists include, for **every** firmware path we target:

| GRUB modules | x86 Legacy BIOS | x86_64 UEFI | IA32 UEFI | AA64 UEFI | MIPS64 UEFI |
| --- | --- | --- | --- | --- | --- |
| `gfxmenu`, `gfxterm`, `gfxterm_menu`, `gfxterm_background` | yes | yes | yes | yes | yes |
| `png`, `jpeg` | yes | yes | yes | yes | yes |
| `font`, `bitmap`, `bitmap_scale` (deps of gfxmenu) | yes (pulled via gfxmenu deps) | yes (explicit) | yes | yes | yes |
| `vbe` + `all_video` (VESA on BIOS) | yes | n/a (efi_gop/efi_uga) | n/a | n/a | n/a |

Consequences (evidence-based, not assumed):

* **JPEG backgrounds are supported** on all five Ventoy firmware paths — `jpeg` is
  compiled into every image. GRUB's JPEG decoder handles **baseline** JPEG; our
  background files were verified to be baseline (`interlace=None`) 1920×1080 8-bit
  sRGB — see validation round 12.
* **PNG icons and pixmaps are supported** everywhere (`png` in all module lists).
* **gfxmenu themes work in Legacy BIOS** — `gfxmenu`, `vbe` and `all_video` are all
  present in `all_modules_legacy`. We still ship a documented CLI fallback because
  *rendering quality* on old VESA firmware varies (honest limitation, not a hard
  incompatibility).
* IA32/AA64/MIPS64 UEFI get the same theme; only font/asset sizes and gfxmode
  choices differ, and we do **not** advertise hardware test coverage we do not have
  (see §6).

## 4. GRUB theme-engine facts used by the design

Sources: GNU GRUB manual <https://www.gnu.org/software/grub/manual/grub/grub.html>
(`theme` / `gfxmode` / `loadfont` sections), ROSA GRUB2 theme reference
<http://wiki.rosalab.ru/en/index.php/Grub2_theme_/_reference>, and inspection of the
existing (field-proven) theme files in `config/`.

* Theme geometry accepts **percentages**, which scale with any video mode; the
  upstream Elegant configs are already "designed for any resolution" this way.
* `desktop-image` is stretched to the screen by gfxmenu (bitmap scaling); a 1920×1080
  background remains correct (soft) on 1440p/4K and on 4:3 modes (slight aspect
  distortion — documented).
* Fonts referenced in `theme.txt` (`item_font`, `terminal-font`, label `font`) must be
  **loaded** before the theme applies. On Ventoy this is exactly what the theme
  plugin's `fonts` array does; in distro installs the upstream project relies on the
  same pf2 files being shipped in the theme directory. Verified embedded PF2 font
  names (parsed from the `NAME` chunk of each file):
  `Terminus Regular 12/14/16/18`, `Unifont Regular 16/24/32`.
* `selected_item_pixmap_style = "select_*.png"` is a 9-slice-ish wildcard; the
  shipped `select_c/e/w-*.png` (center/east/west slices) match the wildcard — this is
  the proven upstream mechanism.
* gfxmenu `boot_menu` does not wrap or ellipsize long entry titles; mitigation is a
  wide menu column (34% ≈ 81 characters at Unifont-16 on a 1920px mode) plus
  documented `menu_alias` advice. Honest limitation, recorded in VENTOY.md.
* gfxmenu effects are limited to pixmaps, labels, colors and boxes; the design uses
  only those (no unsupported effects, no animation, no transparency beyond PNG alpha).

## 5. Graphics strategy decision

* `gfxmode: "max"` in the shipped `ventoy.json` — Ventoy-native, documented value that
  adapts to every panel from 1024×768 to 3840×2160 without hard-coding a mode that
  some firmware cannot set. Percent-based layout keeps the menu on-screen at every
  mode. (Ventoy's own default is 1024×768, which would look soft on modern panels.)
* Fixed-mode alternative (`1920x1080`) is documented for users who prefer it, together
  with the `F5 → Resolution Configuration` runtime recovery path.
* A `--multires` builder option produces Ventoy's native multi-resolution layout
  (`resolution_fit: 1` with `1920x1080`/`2560x1440`/`3840x2160` path markers plus a
  resolution-neutral fallback entry). This is the only mechanism Ventoy documents for
  auto-selecting per-resolution assets.
* Distro installs keep the upstream `GRUB_GFXMODE=<WxH>,auto` fallback chain.

## 6. Compatibility claims — what we claim and what we do NOT

| Firmware / mode | Claim | Basis |
| --- | --- | --- |
| x86_64 UEFI ( Ventoy ≥ 1.0.18) | GUI theme supported | `png`+`jpeg`+`gfxmenu` in Ventoy's x86_64 module list (source §3) |
| x86 Legacy BIOS (Ventoy) | GUI theme supported; CLI fallback documented | `vbe`+`gfxmenu`+`jpeg`+`png` in `all_modules_legacy`; VESA quality varies → CLI guidance |
| IA32 UEFI / AA64 UEFI (Ventoy) | Should render (same module set) — **not hardware-tested** | module lists §3; explicitly flagged untested in docs |
| MIPS64 (Ventoy) | Not shipped/tested | out of scope, documented |
| Secure Boot | No impact claimed | theme data files only; Ventoy's signed binaries unchanged |
| 1024×768 … 3840×2160 | Layout-safe (percent geometry, stretched background) | theme engine behavior §4 + logical layout review (round 13); **no live-boot hardware test performed in this environment** |

Boot-hardware validation performed: static only (asset-reference checks, JSON
validation, PF2 font-name parsing, JPEG baseline checks, deterministic rebuild
comparison). QEMU/OVMF/SeaBIOS are not available in this environment — exact commands
are provided in `docs/VALIDATION-REPORT.md` (round 17) for reproduction elsewhere.

## 7. USB footprint principles applied

* The Ventoy package contains only files read at boot: one background JPEG
  (~256 KiB), 3 select pixmaps (<1 KiB each), one overlay PNG (~18 KiB), one logo
  (~10 KiB), the minimum font set, and (Standard profile only) the icon set.
* **No runtime writes, caches, logs or state** are produced by the theme or scripts;
  the build/export tool never touches the running OS or the USB — it writes only to
  its `--dest` directory.
* Fonts are the dominant cost. `unifont-16.pf2` is 2.4 MiB (full BMP coverage);
  the **Lite** profile substitutes Terminus fonts (~48 KiB) and drops icons, trading
  non-Latin filename coverage and distro icons for a ~10× smaller package. Both
  profiles' measured sizes are reported in `VENTOY.md` and the validation report.
* No duplicated assets: every file in the package is referenced by `theme.txt` or
  `ventoy.json`, verified automatically at build time.

## 8. References

1. Ventoy theme plugin — https://www.ventoy.net/en/plugin_theme.html
2. Ventoy multi-mode options — https://www.ventoy.net/en/plugin_dual_option.html
3. Ventoy menu_class plugin — https://www.ventoy.net/en/plugin_menuclass.html
4. Ventoy GRUB2 module lists (all firmware paths) —
   https://github.com/ventoy/Ventoy/blob/master/GRUB2/MOD_SRC/grub-2.04/install.sh
5. GNU GRUB manual — https://www.gnu.org/software/grub/manual/grub/grub.html
6. GRUB2 theme reference (ROSA) — http://wiki.rosalab.ru/en/index.php/Grub2_theme_/_reference
7. Upstream project — https://github.com/vinceliuice/elegant-grub2-themes (GPL-3.0)
