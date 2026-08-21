# Validation report — Raven Hub hardening (20 rounds)

Every command below was actually executed in the development sandbox
(bash 5.2.15, Debian-based, ImageMagick 6, jq 1.6, Python 3.11,
ShellCheck 0.11.0 installed via `pip install shellcheck-py`) unless explicitly
marked otherwise. Failures are reported as failures — several rounds *found*
bugs that were then fixed and retested; those are the point of the exercise.

Environment limits, stated up front: **no QEMU/OVMF/SeaBIOS and no real UEFI/BIOS
hardware** — no live boot test was possible. All boot-related conclusions are
static (source inspection of Ventoy's GRUB build + official docs), and the
commands to reproduce a live test elsewhere are given in Round 17.

> Note on the mission's `USER_VENTOY_JSON`: the provided value contained only
> the placeholder text `PASTE_THE_FULL_CONTENT_OF_YOUR_EXISTING_VENTOY_JSON_HERE`
> — no actual user configuration was supplied. Therefore no user file was merged
> or modified; instead the deliverables include a drop-in `ventoy.json`, a full
> `ventoy.json.example`, and `tools/ventoy-merge-theme.sh`, which safely merges
> the theme into any real `ventoy.json` (Round 9 proves plugin preservation on a
> representative config with `control`, `menu_alias`, `persistence`, `menu_class`).

---

## Round 1 — Baseline inventory & build commands

* Recorded repo state (commit `f8a8d41`, clean tree) and the full inventory in
  `docs/AUDIT.md`.
* Baseline build commands identified: `./install.sh`, `./generate.sh`,
  `./make-release.sh`, plus asset renderers (Inkscape/OptiPNG — not available
  here; not needed since rendered assets are committed).
* Baseline `bash -n` of all 12 shell scripts: **pass** (syntax only).

## Round 2 — Manual shell audit

Verified (and fixed) the baseline issues listed in `docs/AUDIT.md` §2:
unquoted `REO_DIR`/`dest`, sudo re-exec losing `-l system`, `prompt()` flag
mangling, `read -t` errexit abort, missing dependency checks, half-written
installs, `remove()` `.back` typo + unsafe sed, legacy-name unawareness,
`/etc/default/grub`-missing crash.

## Round 3 — ShellCheck

`shellcheck --severity=warning` (0.11.0):

| Script | Result |
| --- | --- |
| `build-ventoy.sh` | **clean** |
| `tools/ventoy-merge-theme.sh` | **clean** |
| `generate.sh` | **clean** |
| `core.sh` | **clean** (after real fixes: `grep -q` for SC2069, `${var:?}` guard for SC2115; file-level SC2034 directive for cross-file sourced vars) |
| `make-release.sh` | **clean** (removed an unused var) |
| `install.sh` | **clean** (file-level SC2034 directive justified: `install_boot`/`GRUB_DIR` are consumed by the sourced `core.sh`) |
| `releases/install` | **clean** (fixed real SC2145 in `prompt()`, SC2069, SC2115) |

ShellCheck also caught a **self-inflicted** quoting bug during the SC2155 fix
(unclosed string) and an invalid `readonly`-before-assignment — both fixed
immediately; this is why the loop exists.

## Round 4 — Spaces, unicode, quotes, empty values

| Test | Result |
| --- | --- |
| `generate.sh -d "/tmp/Raven Test Ω"` | **pass** — 90 files generated (after fixes) |
| `build-ventoy.sh -o "/tmp/weird dir 'q' 🐦"` | **pass** — package written & validated |
| `tools/ventoy-merge-theme.sh` with spaced paths | **pass** |
| `--dest ""` | rejected, exit 1 |
| JSON with 10 000-char strings / unicode keys / emoji | parsed OK by `json_dup_check.py` |

## Round 5 — Invalid CLI, missing deps, bad targets

| Test | Result |
| --- | --- |
| `install.sh -t bogus` / `--frobnicate` | error message + **exit 1** |
| `build-ventoy.sh -p ultra` / `-s 720p` | rejected, **exit 1** |
| `build-ventoy.sh -o /tmp` (dangerous root) | refused, **exit 1** |
| `build-ventoy.sh -o /tmp/ro-dir/pkg` (read-only parent) | **exit 1**; improved with an explicit "is … writable?" message |
| hidden `mktemp` (PATH simulation) | `missing dependency 'mktemp' (install coreutils)` + **exit 2** |
| missing source asset (`select_w-mountain-dark.png` removed) | actionable `missing selection pixmap: …` + **exit 2**, **destination untouched** |

## Round 6 — Temp files, traps, idempotency, partial failure

* Builder stages into `mktemp -d` with `trap rm -rf EXIT`; verified no `/tmp/tmp.*`
  residue after successful and failed runs.
* Re-run over existing output: **stale files inside `theme/raven-hub/` removed,
  unrelated user files preserved** (found & fixed a gap: old `raven-hub-*` dirs
  from previous option sets survived; cleanup now covers the whole `raven-hub*`
  prefix — verified by multires→single-reswitch test).
* Validation failure before publish ⇒ destination never created (observed
  directly during the Lite/multires iteration failures).

## Round 7 — GRUB theme syntax & asset references (all variants)

Audited all 36 `config/theme-*.txt` programmatically: every referenced file is
shipped by `copy_files`, every font name exists as a pf2 `NAME` chunk, no
geometry overflow (`left+width ≤ 100%`, `top+height ≤ 100%`). **Result: 0
problems** after removing the dead `terminal-box` reference (documented — the
files never existed; GRUB behavior unchanged).

## Round 8 — Generated themes reference only packaged files

Independent (not the builder's own validator) audit of every built package:
all `desktop-image`/`file` references resolve inside the package; `select_*`
wildcards expand; `ventoy.json` `/ventoy/…` paths map to existing files.
**Result: pass for all four package variants.**

## Round 9 — JSON & merge behavior

* `ventoy.json` / `ventoy.json.example` in every package: **valid JSON, no
  duplicate keys** (`tools/json_dup_check.py`, object-pairs-hook based).
* Merge tool against a representative user config containing `control`,
  `menu_alias`, `persistence`, `theme`, `menu_class`: **all unrelated plugins
  preserved byte-for-value; only `theme` replaced**; diff printed.
* Duplicate-key input: **refused, exit 3**. Invalid JSON input: **refused,
  exit 3**. Missing file: **exit 1**. No-args: usage + **exit 1**.
  Output-file collision: **refused, exit 1**.
* `theme_legacy` present: warning shown (mode-specific override precedence).
* `--in-place`: merged file written, `ventoy.json.bak-YYYYmmdd-HHMMSS` backup
  created (observed), original recoverable.

## Round 10 — Clean-tree build

From a clean `dist/` (removed first): **pass** — all four variants
(standard/lite × single/multires) build and self-validate.

## Round 11 — Determinism (build twice, compare)

`find -type f | sort | xargs sha256sum` after build #1 vs build #2:
**byte-identical for all variants**, including the ImageMagick-composited
backgrounds (deterministic `-quality 92` pipeline; verified again after the
compositing change). No stale files between differing option sets (Round 6 fix
verified by content, not just names).

## Round 12 — Asset audit

| Check | Result |
| --- | --- |
| Background JPEGs | 1920×1080, 8-bit sRGB, **baseline** (`interlace=None`) — GRUB jpeg-module compatible |
| Composited backgrounds | 1920×1080 / 2560×1440 / 3840×2160 as expected; region-diff vs plain background ≈48 kpx changed (overlay+logo applied where intended) |
| PNG pixmaps/logo | sRGB PNG (GRUB png-module compatible), dimensions match design |
| PF2 fonts | `NAME` chunks parsed: `Terminus Regular 12/14/16/18`, `Unifont Regular 16/24/32` — exactly the names `theme.txt` uses |
| Duplicates inside a package | 6 md5 groups — all **upstream icon aliases** (`arch`=`archlinux`, `manjaro` family, `gnu-linux`=`linux`=`unknown`=`lfs`, `pop`=`pop-os`, `opensuse`=`openSUSE`, `memtest`=`driver`) required for `menu_class` matching; ≈40 KiB total; kept intentionally |
| Icons identical to source set | yes (no divergence) |

## Round 13 — Layout at 1024×768 → 3840×2160

Computed pixel geometry at all six target modes (table in transcript):
menu box inside the screen at every mode; ~43–163 characters of menu width;
timeout label and hotkey bar never overlap; select-slice heights match
`item_height` exactly per asset set (48/72/96). **Fix delivered during this
round:** overlay+logo are now composited into `background.jpg` (GRUB draws
`+ image` widgets at natural size, which would misalign at any non-native
mode); composited background scales with `desktop-image` everywhere.
Backgrounds upscale from the 1920×1080 source for 2k/4k sets (documented).

## Round 14 — UEFI x86_64

Config strategy: `gfxmode: "max"` (Ventoy-documented), `display_mode: "GUI"`,
fonts preloaded via the `fonts` array, `F7`/`F5` runtime fallbacks documented.
Module support (`png`, `jpeg`, `gfxmenu`, `font`, `bitmap_scale`) verified from
Ventoy's build script for `x86_64-efi`. No live boot test possible here
(see Round 17) — documented as such.

## Round 15 — Legacy BIOS

Same module set verified for the `i386-pc` image (including `vbe`, `all_video`).
Conservative fallback delivered: `theme_legacy: { "display_mode": "CLI" }`
example in VENTOY.md §4; `F7` one-press fallback documented. No claim of
hardware-tested VESA quality.

## Round 16 — IA32 / AA64

`i386-efi` uses Ventoy's UEFI module list (same theme modules); `arm64-efi`
list verified likewise. Both documented as **expected to work, not
hardware-tested**; per-mode override keys documented. No MIPS64 package.

## Round 17 — Boot-oriented validation attempt

`qemu-system-x86_64`, `qemu-system-aarch64`, OVMF: **not available in this
environment** (checked `command -v` and `/usr/share/OVMF`). grub-mkfont /
grub-mkrescue: not available. Therefore **no emulation boot was executed** —
this is an honest limitation, not a pass. Reproduction recipe for a capable
host (documented, not run here):

```sh
# 1. Install Ventoy on a spare USB image file
sudo ./Ventoy2Disk.sh -i /dev/sdX        # or use a file-backed loop device
# 2. Mount the data partition, copy dist/ventoy/* into its ventoy/ folder
# 3. Boot it in firmware modes:
qemu-system-x86_64 -m 2G -enable-kvm -usb -device usb-storage,drive=d0 \
  -drive if=none,id=d0,format=raw,file=ventoy.img
qemu-system-x86_64 -m 2G -bios /usr/share/OVMF/OVMF_CODE.fd \
  -usb -device usb-storage,drive=d0 -drive if=none,id=d0,format=raw,file=ventoy.img
```

## Round 18 — Configuration abuse

Covered above and verified: malformed JSON (exit 3), duplicate keys (exit 3),
missing assets (exit 2, no partial output), dangerous/empty `--dest` (exit 1),
spaces/quotes/unicode in paths (pass), 10 k-char JSON strings (pass).
`menu_class` example classes are builder-generated (fixed set) and validated
against shipped icons; arbitrary user `menu_class` classes without icons simply
render without an icon (no layout break — spacing is fixed by
`icon_width`/`item_icon_space`).

## Round 19 — Documentation-to-code consistency

Every file referenced by the docs exists; the documented default destination
`dist/ventoy`, package paths (`/ventoy/theme/raven-hub/…`), all option names
and examples in README/VENTOY.md were checked against the actual builder output
(table of checks in transcript). Package sizes in docs updated to measured
values (352 KiB / 3.1 MiB / 1.5 MiB / 16 MiB). Stale "Elegant" branding scan:
only credits/migration/legacy-compat mentions remain.

## Round 20 — Final build, regression review, sizes

* Fresh builds of all four variants from a clean `dist/`: **pass**.

| Package | Size | Files |
| --- | --- | --- |
| `dist/ventoy` (Standard, 1080p) | 3.1 MiB | 89 |
| `dist/ventoy-lite` (Lite, 1080p) | **352 KiB** | 11 |
| `dist/ventoy-multires` (Standard, multires) | 16 MiB | 259 |
| `dist/ventoy-multires-lite` (Lite, multires) | 1.5 MiB | 24 |

* Real install + uninstall executed in the sandbox with `sudo -n`
  (Round transcript): theme tree installed under
  `/usr/share/grub/themes/Raven-Hub-mountain-float-left-dark/`, `GRUB_THEME`/
  `GRUB_BACKGROUND`/`GRUB_GFXMODE` set correctly, uninstall removed **both**
  Raven Hub and legacy `Elegant-*` dirs and commented the theme line out with a
  `.raven-hub.bak` backup; sandbox `/etc/default/grub` restored afterwards.
* `git diff` reviewed: 44 files changed (+483/−358 at review time), no secrets,
  no binary bloat, `dist/` ignored via `.gitignore`.
* Release tarball flow (`make-release.sh`) dry-verified via option validation
  and `--help`; full tarball build not executed (requires pre-rendered previews
  that are gitignored; guarded with an actionable error message).

## Command cheat-sheet (re-run everything)

```sh
bash -n install.sh generate.sh core.sh make-release.sh build-ventoy.sh \
        tools/ventoy-merge-theme.sh releases/install
shellcheck --severity=warning install.sh generate.sh core.sh make-release.sh \
        build-ventoy.sh tools/ventoy-merge-theme.sh releases/install
./build-ventoy.sh -n
./build-ventoy.sh && ./build-ventoy.sh -p lite -o dist/ventoy-lite
python3 tools/json_dup_check.py dist/ventoy/*.json
tools/ventoy-merge-theme.sh --existing <your ventoy.json> --theme dist/ventoy/ventoy.json
```
