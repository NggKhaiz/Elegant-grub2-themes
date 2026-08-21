# Raven Hub theme (raven-hub)

GRUB2 gfxmenu theme for Ventoy, generated from the Raven Hub source tree.

* Lineage: Elegant-grub2-themes by vinceliuice et al. — GPL-3.0.
* Layout is percent-based: it scales with whatever gfxmode Ventoy selects.
* Fonts: loaded via the `fonts` array in `/ventoy/ventoy.json` — keep those
  entries pointing at this directory's `fonts/` folder.
* Icons appear when a `menu_class` plugin assigns classes to your ISOs
  (see `ventoy.json.example`).
* Nothing here is written to at boot; the whole directory is read-only data.

Files:

| File | Purpose |
| --- | --- |
| `theme.txt` | theme definition (edit colors/layout here) |
| `backgrounds/background.jpg` | background with art overlay + logo composited in (baseline JPEG, GRUB-compatible; scales to any gfxmode) |
| `select_c/e/w.png` | selection highlight slices (`select_*.png` wildcard) |
| `fonts/*.pf2` | Terminus / Unifont fonts referenced by the theme |
| `icons/` | per-distro icons for the `menu_class` plugin (Standard profile) |
