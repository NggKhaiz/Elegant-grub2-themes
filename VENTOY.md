# Raven Hub on Ventoy — the complete guide

Raven Hub ships **first-class Ventoy support**: a self-contained theme package
that is copied onto the Ventoy USB **data partition** (the big partition that
holds your ISO files). No files are needed from anywhere else, nothing is
installed on your computer, and nothing is written to the USB at boot time.

Everything below was implemented against the **official Ventoy theme plugin
documentation** (`ventoy.net/en/plugin_theme.html`) and the **Ventoy GRUB2
build configuration** — see [docs/TECH-NOTES.md](docs/TECH-NOTES.md) for the
source-verified details.

---

## 1. Build the package

```sh
./build-ventoy.sh                # Standard profile -> dist/ventoy
./build-ventoy.sh -p lite        # Lite profile     -> dist/ventoy
```

| Option | Values | Default | Meaning |
| --- | --- | --- | --- |
| `-p, --profile` | `standard` \| `lite` | `standard` | see table below |
| `-t, --theme` | `forest` `mojave` `mountain` `wave` | `mountain` | background art |
| `-c, --color` | `dark` \| `light` | `dark` | color scheme |
| `-s, --screen` | `1080p` `2k` `4k` | `1080p` | asset resolution |
| `--multires` | – | off | per-resolution themes via Ventoy `resolution_fit` |
| `-o, --dest` | directory | `dist/ventoy` | output location |
| `-n, --dry-run` | – | off | show the plan, write nothing |

The build is **deterministic** (rebuilding produces identical files), never
uses root, never touches your OS, validates itself (asset references, JSON,
paths, font names) and **refuses to publish** a package that fails validation.

### Standard vs Lite

| | Standard | Lite |
| --- | --- | --- |
| Fonts | Unifont 16 (full Unicode/ISO-name coverage) + Terminus 14 | Terminus 16 + Terminus 14 (Latin, Greek, Cyrillic…) |
| Distro icons (with `menu_class`) | yes (78 icons) | no |
| Measured size (1080p, mountain/dark) | **3.1 MiB** (89 files) | **352 KiB** (11 files) |
| Trade-off | larger (font is 2.4 MiB of it) | non-Latin ISO filenames show missing glyphs; no icons |

> Both use the same artwork. The size difference is almost entirely the Unifont
> font file and the icon set. If in doubt, start with Lite — you can rebuild
> with Standard at any time.

### What the package contains

```
ventoy.json            theme-only configuration (drop-in for fresh Ventoy USBs)
ventoy.json.example    same theme config + an optional menu_class section
README.md              short install/recovery instructions
theme/raven-hub/
  theme.txt            theme definition (percent-based layout, scales anywhere)
  backgrounds/background.jpg   1920×1080 baseline JPEG (GRUB-compatible) with
                       the art overlay and mountain logo composited in, so all
                       visual layers scale together at any gfxmode
  fonts/*.pf2          fonts listed in ventoy.json ("fonts" array)
  select_c/e/w.png     selection highlight slices
  icons/               per-distro icons (Standard profile only)
  README.md            file-by-file notes
```

---

## 2. Install onto the USB

1. Plug in your Ventoy USB and open the **data partition** (the big one with
   your ISOs). It usually contains a `ventoy` folder (create it if missing —
   Ventoy looks for `/ventoy/ventoy.json` at the partition root).
2. **Fresh USB — no `ventoy/ventoy.json` yet:**
   copy `ventoy.json` and the whole `theme/` directory into that `ventoy`
   folder. You end up with:
   ```
   /ventoy/ventoy.json
   /ventoy/theme/raven-hub/theme.txt
   /ventoy/theme/raven-hub/backgrounds/background.jpg
   ...
   ```
   Done. Reboot and boot the USB.
3. **You already have a `ventoy/ventoy.json`:** do **not** overwrite it —
   merge it (next section).

You can also build directly onto the USB:

```sh
./build-ventoy.sh -p lite -o "/media/$USER/VENTOY/ventoy"
```

(the builder only replaces the paths it owns: `ventoy.json`,
`ventoy.json.example`, `README.md`, `theme/raven-hub*` — your ISOs and other
files are never touched).

### Verify on the USB itself

Boot the USB → `F5 Tools → Check plugin json configuration → Check theme
plugin configuration`. Ventoy validates the JSON and reports where the theme
was found. This works even if the theme looks broken.

---

## 3. Safe merge with an existing ventoy.json

Your existing `ventoy.json` may hold `control`, `menu_alias`, `menu_class`,
`persistence`, `auto_install`, `injection`, `password`, `image_list` and other
plugins. **Keep them.** Use the merge tool:

```sh
# 1. Preview (writes a new file next to yours; never overwrites):
tools/ventoy-merge-theme.sh \
    --existing "/media/$USER/VENTOY/ventoy/ventoy.json" \
    --theme    dist/ventoy/ventoy.json

# 2. Review the printed diff, then either copy the *.raven-hub-merged.json
#    file over ventoy.json yourself, or let the tool do it with a backup:
tools/ventoy-merge-theme.sh \
    --existing "/media/$USER/VENTOY/ventoy/ventoy.json" \
    --theme    dist/ventoy/ventoy.json --in-place
```

What the tool guarantees:

* only the `"theme"` key is replaced; **every other key is preserved**;
* both files are validated as JSON first, and **duplicate keys are rejected**
  (a duplicated `theme` key would otherwise silently discard config);
* `--in-place` always saves `ventoy.json.bak-YYYYmmdd-HHMMSS` first;
* it warns if you already use `theme_legacy`/`theme_uefi`/`theme_ia32`/
  `theme_aa64`/`theme_mips` (those override `theme` in their boot modes).

### Manual merge (if you prefer editors)

Copy the `"theme": { … }` object from the package's `ventoy.json` into your
`ventoy.json` as a top-level key. If a `"theme"` key already exists, replace
its value. Keep everything else untouched. Do not create two `"theme"` keys.

### What exactly the theme block changes

| Key | Value | Why |
| --- | --- | --- |
| `file` | `/ventoy/theme/raven-hub/theme.txt` | the theme, at its package path |
| `gfxmode` | `max` | Ventoy-native: use the best mode the firmware offers; works from 1024×768 to 4K without hard-coding a mode some firmware cannot set |
| `display_mode` | `GUI` | graphical menu (default); CLI fallback is one keypress away (F7) |
| `ventoy_left/top/color` | `2%`, `96%`, `#f0f0f0` | Ventoy's version line: bottom-left, light grey on the dark art (default blue would be unreadable) |
| `fonts` | `…/fonts/*.pf2` | Ventoy `loadfont`s these before applying the theme; the names inside `theme.txt` resolve to them |

---

## 4. Architecture modes (Legacy BIOS, IA32, AA64)

Ventoy applies the plain `theme` object in **all** firmware modes. Source
verification (see `docs/TECH-NOTES.md` §3): Ventoy's GRUB binaries for
x86 Legacy BIOS, x86_64 UEFI, IA32 UEFI and AA64 UEFI all embed the `png`,
`jpeg`, `gfxmenu`, `font` and `bitmap_scale` modules — the theme renders
everywhere Ventoy itself does.

* **x86_64 UEFI** — primary target; fully expected to work.
* **Legacy BIOS (CSM)** — supported: Ventoy's legacy GRUB includes VESA
  (`vbe`) plus the same theme modules. On very old VESA implementations
  quality varies; if the menu is unusable, press `F7` for text mode, or pin
  the legacy mode to text permanently by adding to your `ventoy.json`:
  ```json
  "theme_legacy": { "display_mode": "CLI" }
  ```
  (This overrides only Legacy BIOS; UEFI keeps the GUI theme.)
* **IA32 UEFI / AA64 UEFI** — the same module set is compiled in, so the
  theme is expected to render identically. **Not hardware-tested by us** —
  if you hit a problem, override per-mode the same way (`theme_ia32`,
  `theme_aa64`) and please report it.
* **MIPS64** — not shipped or tested.

### Multi-mode example (GUI on UEFI, text on legacy BIOS)

```json
{
    "theme": {
        "file": "/ventoy/theme/raven-hub/theme.txt",
        "gfxmode": "max",
        "fonts": [
            "/ventoy/theme/raven-hub/fonts/unifont-16.pf2",
            "/ventoy/theme/raven-hub/fonts/terminus-14.pf2"
        ]
    },
    "theme_legacy": {
        "display_mode": "CLI"
    }
}
```

---

## 5. Resolution strategy

* Default `gfxmode: "max"` + percent-based layout: safe from 1024×768 to
  3840×2160. The background is scaled by GRUB to the active mode; on non-16:9
  panels it is slightly stretched.
* Fonts/icons are pixel-sized for the chosen asset set (1080p by default). On
  a 1440p/4K panel they appear smaller than on a 1080p panel — perfectly
  readable, just more compact. If you want pixel-perfect sizing:
  ```sh
  ./build-ventoy.sh -s 2k      # or -s 4k — bigger fonts/icons, same layout
  ```
* **`--multires`** builds three per-resolution themes (`raven-hub-1920x1080`,
  `2560x1440`, `3840x2160`) and switches `ventoy.json` to Ventoy's
  `resolution_fit` mode (requires Ventoy ≥ 1.0.86). Caveats, honestly:
  * the package grows (16 MiB Standard / 1.5 MiB Lite) because fonts
    dominate;
  * on panels whose native mode is none of the three (e.g. 1366×768), no
    theme matches and Ventoy shows its **default menu** (fully functional,
    just unthemed) — use the single-theme package on such panels;
  * `resolution_fit` has had reported quirks in some Ventoy versions
    (1.0.95-era forum reports); the single-theme default avoids the feature
    entirely.
* Fixed mode instead of `max`: replace `"gfxmode": "max"` with e.g.
  `"1920x1080"`. You can also change it at runtime with
  `F5 → Resolution Configuration`.

---

## 6. Long ISO filenames and readability

* The menu column is 34% wide (≈ 81 characters at Unifont-16 on a 1920px
  mode) and 64% tall; Ventoy scrolls long lists.
* GRUB's gfxmenu does **not** wrap or ellipsize titles: extremely long ISO
  names are clipped at the panel edge but never overlap other UI elements.
  If your ISOs have huge names, use the `menu_alias` plugin to shorten them
  (Ventoy core plugin, independent of this theme).
* Selected items get a solid highlight bar (`select_*.png` slices) and white
  text; unselected items are `#efefef`; the Ventoy version line and hotkey
  tips are light grey — all chosen for contrast on both dark and light art.

---

## 7. Icons for your ISOs (Standard profile)

Icons appear when a `menu_class` plugin assigns classes. The package's
`ventoy.json.example` shows a working starting point:

```json
"menu_class": [
    { "key": "ubuntu",    "class": "ubuntu" },
    { "key": "Windows",   "class": "windows" },
    { "key": "archlinux", "class": "arch" },
    { "key": "debian",    "class": "debian" },
    { "dir": "/ISO/Linux", "class": "linux" }
]
```

`key` is a case-sensitive substring of the ISO filename; `dir`/`parent`
match directories (no trailing slash). Ventoy also assigns built-in classes
(`vtoyiso`, `vtoydir`, `vtoyret`, …) when nothing matches — those have no
icons in this package, so such entries simply show without an icon (spacing
stays consistent). Full rules:
<https://www.ventoy.net/en/plugin_menuclass.html>.

---

## 8. Recovery <a id="recovery"></a>

**The theme can never make the USB unbootable.** Ventoy reads the theme only
for drawing; boot logic is unaffected. Still, if the menu looks wrong:

| Symptom | Fix |
| --- | --- |
| Black screen / unreadable menu | Press **`F7`** (or `F5 → Screen Display Mode → Force Text Mode`) — instant text menu, no reboot needed |
| Wrong resolution / tiny or huge UI | `F5 → Resolution Configuration`, pick a mode; or edit `gfxmode` in `ventoy.json` |
| Theme not applied (plain Ventoy menu) | `F5 → Check plugin json configuration`; usually a path typo — `/ventoy/theme/raven-hub/theme.txt` must exist on the data partition |
| Missing glyphs (tofu) in ISO names | You are on the Lite profile; rebuild with Standard (`-p standard`) for full Unifont coverage |
| Menu text overlaps art on an odd panel | Set `gfxmode` to your panel's native `WxH`, or try the `-s 2k`/`-s 4k` asset set |
| USB won't show menu at all (very rare) | Boot with the USB removed → plug in → reboot; or use another port. Ventoy's own troubleshooting applies — the theme is not involved in device enumeration |

Any time you want to check the raw JSON on the USB:

```sh
python3 tools/json_dup_check.py /media/$USER/VENTOY/ventoy/ventoy.json
```

---

## 9. Rollback / uninstall the theme

**Temporary (one boot):** press `F7` — text mode ignores the theme.

**Full removal from the USB:**

1. Delete `/ventoy/theme/raven-hub*` (and `/ventoy/README.md` if you copied it).
2. Remove the `"theme"` object from `/ventoy/ventoy.json`.
   * If you merged with the tool: restore the backup it made:
     ```sh
     cp ventoy.json.bak-YYYYmmdd-HHMMSS ventoy.json
     ```
   * If you started fresh and `ventoy.json` contains only the theme object,
     you may delete the file entirely.

Ventoy then shows its stock menu. Your ISOs, plugins and other settings are
untouched.

---

## 10. USB footprint & longevity notes

* The package is **read-only at boot**: no logs, caches, state or update
  checks are written to the USB (nothing in the theme writes anything).
* Sizes: **352 KiB** (Lite) / **3.1 MiB** (Standard) / 1.5 MiB (Lite multires) / 16 MiB (Standard multires) —
  small next to a single ISO, leaving the partition free for what matters.
* No duplicated assets: every shipped file is referenced by `theme.txt` or
  `ventoy.json`, and the build verifies that (see
  [docs/VALIDATION-REPORT.md](docs/VALIDATION-REPORT.md)).
* We make no claims about extending USB lifespan — boot-time reads and the
  absence of writes are the only relevant factors here, and the package
  simply performs none.

---

## 11. Compatibility summary (honest)

| Mode | Status |
| --- | --- |
| x86_64 UEFI (any recent Ventoy) | Supported — primary target; module support source-verified |
| x86 Legacy BIOS (CSM) | Supported — VESA + theme modules source-verified; CLI fallback documented |
| IA32 UEFI, AA64 UEFI | Expected to work (same GRUB module set) — **not hardware-tested here** |
| Secure Boot | Untouched — Ventoy's own signed binaries handle it; a theme adds only data files |
| 1024×768 → 3840×2160 | Layout-safe via percent geometry + `gfxmode: max` |
| Live hardware/QEMU boot test | **Not performed in the build environment** (no QEMU/OVMF available) — static validation only; report real-world results via issues |
