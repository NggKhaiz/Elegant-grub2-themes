# Acceptance report — simple Ventoy delivery (Windows + Linux)

Real results for the cross-platform, beginner-focused delivery layer added on
top of the Raven Hub build system (`build-ventoy.sh` remains the engine; the
new `make-ventoy-release.sh` produces the copy-ready folder).

Environment: Debian-based sandbox, bash 5.2, dash/POSIX sh, Python 3.11,
jq 1.6, ShellCheck 0.11.0, ImageMagick 6. **No Windows OS and no PowerShell
runtime (`pwsh`) are available** — Windows scripts received static validation
only (documented below). No real USB/firmware, so no live boot test.

## Deliverables in `release/` (gitignored build output; regenerate with
`./make-ventoy-release.sh`, downloadable as deterministic zips)

| Path | Purpose |
| --- | --- |
| `Raven-Hub-Ventoy/` | Standard package (3.1 MiB, 97 files) |
| `Raven-Hub-Ventoy-Lite/` | Lite package (~0.4 MiB, 19 files) |
| `Raven-Hub-Ventoy{,-Lite}.zip` | byte-reproducible download archives |
| `install-ventoy.cmd` / `.ps1` / `.sh`, `uninstall-ventoy.ps1` / `.sh` | installers/uninstallers |
| `README.md`, `README-WINDOWS.md`, `README-LINUX.md`, `UNINSTALL.md` | user docs |
| `ventoy/ventoy.json.example` | minimal beginner config (theme-only) |

## Acceptance tests — executed results

| # | Test | Result |
| --- | --- | --- |
| 1 | Build release from clean output dir | **pass** (`rm -rf release && ./make-ventoy-release.sh`) |
| 2 | Build twice; no stale files retained | **pass** (junk files planted in release were removed; zips byte-identical, md5 compared) |
| 3 | Every path referenced by `theme.txt` exists in final package | **pass** (builder validation + independent audit) |
| 4 | All generated JSON valid | **pass** (`json_dup_check.py`; release validator also asserts the example contains **only** the `theme` object, `gfxmode 1024x768`, `GUI`, and shipped font paths) |
| 5 | JSON merge preserves unrelated user plugins | **pass** — run against the user's real config (catppuccin theme + 16-key `control` object): `control` byte-identical after install, only `theme` replaced, key order kept, timestamped backup created |
| 6 | Windows script syntax/logic as far as environment allows | **static only** — `pwsh` unavailable. Naive brace/paren balance check passes; manual review; no destructive cmdlets (see #10); `ConvertTo-Json -Depth 32`, BOM-less UTF-8 write, `-Target`/`-Yes`/`-DryRun` parameters, writable-probe and manual-path mode implemented. **Not executed on Windows — untested runtime behavior is a known limitation.** |
| 7 | Linux shell script syntax/logic directly | **pass** — `sh -n` + ShellCheck (`--shell=sh`, clean) + full behavioral tests below |
| 8 | Target paths containing spaces | **pass** (`--target "/tmp/usb 2"` full install/merge/uninstall/restore cycle) |
| 9a | Missing target path | **pass** — exit 2 |
| 9b | Non-writable path | **pass** — exit 2 with fix suggestions, no sudo |
| 9c | Missing ventoy dir (fresh drive) | **pass** — warning + confirmation (auto-continued with `--yes`); config created from example |
| 9d | Malformed ventoy.json | **pass** — file left **byte-identical**, manual instructions printed, theme copied, exit 3 |
| 9e | Existing theme configuration | **pass** — old catppuccin theme replaced, backup kept; re-install over Raven Hub also idempotent |
| 10 | No destructive commands in scripts | **pass** — grep for `mkfs\|fdisk\|parted\|dd if=\|diskpart\|Format-Volume\|Clear-Disk\|Remove-Partition\|Initialize-Disk\|New-Partition\|Set-Disk\|Ventoy2Disk\|shred\|wipefs`: 0 hits in all installers/uninstallers; `Remove-Item -Recurse` in PS appears only against `$ravenDir`/`$d.FullName` (raven-hub dirs) |
| 11 | Standard and Lite sizes measured | **pass** — Standard 3.1 MiB (97 files), Lite ~0.4 MiB (19 files) incl. docs + installers |
| 12 | No caches/temp/source-only artifacts in release | **pass** — release contains only: installers, 4 docs, `ventoy/ventoy.json.example`, theme assets (jpg/pf2/png), theme README. No `.git`, no logs, no editor backups, no SVG sources |
| 13 | Tests that could NOT be run | listed honestly: Windows execution of `.ps1`/`.cmd` (no Windows/PowerShell), double-click UX, real USB drive behavior, actual firmware boot (no QEMU/OVMF — see VALIDATION-REPORT Round 17) |

Extra behaviors verified beyond the required list:

* **No-parser fallback**: with `python3` and `jq` both hidden from `PATH`, the
  Linux installer copies the theme but leaves `ventoy.json` **untouched**
  (byte-identical) and prints exact manual activation instructions, exit 3.
* **Uninstaller**: removes only `ventoy/theme/raven-hub*` + the `theme` key
  (another backup first); `--restore` round-trips the user's original config
  back to byte-equality (tested with the user's real JSON).
* **Backup naming**: `ventoy.json.bak-YYYYMMDD-HHMMSS` on every modification;
  `--dry-run` makes zero changes (verified).
* **Zips are deterministic** (fixed 1980-01-01 timestamps, sorted walks,
  stable permissions) — md5-identical rebuilds.

## Known limitations (honest)

1. PowerShell scripts were **never executed** (no Windows/pwsh in the build
   environment). They follow Windows PowerShell 5.1-compatible patterns
   (`ConvertFrom-Json`, `-Depth 32`, BOM-less UTF-8, `Get-CimInstance`), but
   treat first real-world use as the actual test — README-WINDOWS.md shows the
   manual fallback path if anything misbehaves.
2. No live boot test on any firmware (unchanged from the 20-round report).
3. The user's supplied `ventoy.json` uses a `control` **object**; Ventoy's
   official control-plugin documentation uses an **array of objects**
   (`"control": [ { … } ]`). The merge preserves the user's form untouched as
   required; users may want to double-check that Ventoy reads their form —
   this is their configuration choice, not something the installer changes.
4. The installer's Ventoy detection is a heuristic (ventoy dir or ISO files);
   on unusual layouts it asks for confirmation instead of failing silently.
