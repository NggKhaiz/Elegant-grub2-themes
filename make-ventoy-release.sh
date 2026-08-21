#!/bin/sh
#
# make-ventoy-release.sh — assemble the copy-ready Raven Hub release folders:
#
#   release/Raven-Hub-Ventoy/        (Standard: full Unicode fonts + icons)
#   release/Raven-Hub-Ventoy-Lite/   (Lite: ~9x smaller, no icons)
#
# Each folder is self-contained:
#   ventoy/theme/raven-hub/…      the theme
#   ventoy/ventoy.json.example    minimal beginner configuration
#   install-ventoy.sh/.ps1/.cmd   installers (Linux / Windows)
#   uninstall-ventoy.sh/.ps1      uninstallers
#   README.md, README-WINDOWS.md, README-LINUX.md, UNINSTALL.md
#
# Plus deterministic .zip archives for download (stable byte-for-byte output).
#
# Usage:
#   ./make-ventoy-release.sh                 # both profiles -> release/
#   ./make-ventoy-release.sh --profile lite  # only Lite
#   ./make-ventoy-release.sh --no-zip
#   ./make-ventoy-release.sh --help
#
# Exit codes: 0 success · 1 usage · 2 build/validation failure

set -eu

# shellcheck disable=SC1007  # "CDPATH= cd" is the POSIX idiom for a one-command empty CDPATH
REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OUT="${REPO_DIR}/release"
PROFILES="standard lite"
ZIP=1

say()  { printf '%s\n' "==> $*"; }
err()  { printf '%s\n' "ERROR: $*" >&2; }

usage() { sed -n '3,24p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --profile) shift; case "${1:-}" in standard|lite) PROFILES=$1 ;; *) err "--profile needs standard|lite"; exit 1 ;; esac; shift ;;
    --out)     [ $# -ge 2 ] || usage 1; OUT=$2; shift 2 ;;
    --no-zip)  ZIP=0; shift ;;
    --help|-h) usage 0 ;;
    *) err "unrecognized option '$1'"; usage 1 ;;
  esac
done

command -v python3 >/dev/null 2>&1 || { err "python3 is required to build releases"; exit 2; }

for f in ventoy/installers/install-ventoy.sh ventoy/installers/install-ventoy.ps1 \
         ventoy/installers/install-ventoy.cmd ventoy/installers/uninstall-ventoy.sh \
         ventoy/installers/uninstall-ventoy.ps1 ventoy/release-README.md \
         ventoy/README-WINDOWS.md ventoy/README-LINUX.md ventoy/UNINSTALL.md; do
  [ -f "${REPO_DIR}/$f" ] || { err "missing release source: $f"; exit 2; }
done
sh -n "${REPO_DIR}/ventoy/installers/install-ventoy.sh"   || { err "install-ventoy.sh fails sh -n"; exit 2; }
sh -n "${REPO_DIR}/ventoy/installers/uninstall-ventoy.sh" || { err "uninstall-ventoy.sh fails sh -n"; exit 2; }

case "$OUT" in /|/home|/home/|/media|/tmp|"${REPO_DIR}") err "refusing to use '$OUT' as output"; exit 1 ;; esac

rm -rf -- "$OUT"
mkdir -p -- "$OUT"

for profile in $PROFILES; do
  case "$profile" in
    standard) NAME="Raven-Hub-Ventoy" ;;
    lite)     NAME="Raven-Hub-Ventoy-Lite" ;;
  esac
  DEST="${OUT}/${NAME}"
  say "building ${NAME} (${profile} profile)..."
  "${REPO_DIR}/build-ventoy.sh" -p "$profile" -o "${DEST}/ventoy" >/dev/null

  # release layout: exactly one beginner config — ventoy/ventoy.json.example
  rm -f -- "${DEST}/ventoy/ventoy.json"
  cp -- "${DEST}/ventoy/ventoy.json.example" "${DEST}/ventoy/ventoy.json.example.new"
  mv -f -- "${DEST}/ventoy/ventoy.json.example.new" "${DEST}/ventoy/ventoy.json.example"
  rm -f -- "${DEST}/README.md"          # release root READMEs replace the package stub
  rm -f -- "${DEST}/ventoy/README.md"   # (and its copy inside ventoy/)

  # installers + docs at the release root
  cp -- "${REPO_DIR}/ventoy/installers/install-ventoy.sh"  "${DEST}/"
  cp -- "${REPO_DIR}/ventoy/installers/uninstall-ventoy.sh" "${DEST}/"
  cp -- "${REPO_DIR}/ventoy/installers/install-ventoy.ps1" "${DEST}/"
  cp -- "${REPO_DIR}/ventoy/installers/uninstall-ventoy.ps1" "${DEST}/"
  cp -- "${REPO_DIR}/ventoy/installers/install-ventoy.cmd" "${DEST}/"
  cp -- "${REPO_DIR}/ventoy/release-README.md"  "${DEST}/README.md"
  cp -- "${REPO_DIR}/ventoy/README-WINDOWS.md"  "${DEST}/README-WINDOWS.md"
  cp -- "${REPO_DIR}/ventoy/README-LINUX.md"    "${DEST}/README-LINUX.md"
  cp -- "${REPO_DIR}/ventoy/UNINSTALL.md"       "${DEST}/UNINSTALL.md"
  chmod 755 "${DEST}/install-ventoy.sh" "${DEST}/uninstall-ventoy.sh"

  # every installer the release ships must agree on the package it installs
  python3 - "${DEST}" <<'PY'
import json, os, sys
root = sys.argv[1]
json_example = os.path.join(root, "ventoy", "ventoy.json.example")
theme_txt = os.path.join(root, "ventoy", "theme", "raven-hub", "theme.txt")
assert os.path.isfile(json_example), json_example
assert os.path.isfile(theme_txt), theme_txt
cfg = json.load(open(json_example))
t = cfg["theme"]
assert list(cfg.keys()) == ["theme"], "example must contain only the theme object"
assert t["file"] == "/ventoy/theme/raven-hub/theme.txt"
assert t["gfxmode"] == "1024x768" and t["display_mode"] == "GUI"
for f in t["fonts"]:
    rel = os.path.join(root, f.lstrip("/"))
    assert os.path.isfile(rel), f"missing font in release: {f}"
for extra in ("install-ventoy.sh", "install-ventoy.ps1", "install-ventoy.cmd",
              "uninstall-ventoy.sh", "uninstall-ventoy.ps1", "README.md",
              "README-WINDOWS.md", "README-LINUX.md", "UNINSTALL.md"):
    assert os.path.isfile(os.path.join(root, extra)), f"missing {extra}"
print("    release contents validated")
PY
done

if [ "$ZIP" -eq 1 ]; then
  say "creating deterministic .zip archives..."
  for NAME in $(cd "$OUT" && ls -d */ | tr -d '/'); do
    python3 - "$OUT" "$NAME" <<'PY'
import os, sys, zipfile
root, name = sys.argv[1], sys.argv[2]
src = os.path.join(root, name)
out = os.path.join(root, name + ".zip")
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for dirpath, dirnames, filenames in os.walk(src):
        dirnames.sort()
        for fn in sorted(filenames):
            full = os.path.join(dirpath, fn)
            arc = os.path.relpath(full, root)
            info = zipfile.ZipInfo(arc, date_time=(1980, 1, 1, 0, 0, 0))
            info.external_attr = (0o755 if fn.endswith((".sh", ".cmd")) else 0o644) << 16
            with open(full, "rb") as fh:
                z.writestr(info, fh.read(), zipfile.ZIP_DEFLATED, compresslevel=9)
print(f"    {name}.zip")
PY
  done
fi

say "release ready:"
cd "$OUT" && for d in */; do
  printf '    %-26s %8s  %3d files\n' "$d" "$(du -sh "$d" | cut -f1)" "$(find "$d" -type f | wc -l)"
done
[ "$ZIP" -eq 1 ] && ls -1 ./*.zip 2>/dev/null | sed 's/^/    /'
exit 0
