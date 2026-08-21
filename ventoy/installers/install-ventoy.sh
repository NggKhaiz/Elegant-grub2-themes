#!/bin/sh
#
# install-ventoy.sh — install the Raven Hub theme onto a Ventoy USB drive.
#
# What it does (and never does):
#   * copies this folder's ventoy/theme/raven-hub into the USB's ventoy folder
#   * creates /ventoy/ventoy.json from the minimal example when none exists
#   * when a ventoy.json already exists: backs it up with a timestamp and
#     merges ONLY the "theme" object, preserving every other plugin key
#   * validates the resulting JSON before reporting success
#   * never formats, repartitions, touches boot sectors or deletes ISO files
#   * never needs root: if your USB is mounted read-only for your user, the
#     script explains what to fix instead of using sudo
#
# Usage:
#   ./install-ventoy.sh --target /media/$USER/Ventoy        # normal use
#   ./install-ventoy.sh                                     # interactive target
#   ./install-ventoy.sh --target PATH --dry-run             # show the plan only
#   ./install-ventoy.sh --target PATH --yes                 # no confirmation prompt
#
# Exit codes: 0 success · 1 usage · 2 target/environment problem
#             3 theme copied but config could not be merged (instructions shown)

set -u

# shellcheck disable=SC1007  # "CDPATH= cd" is the POSIX idiom for a one-command empty CDPATH
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
THEME_SRC="${SCRIPT_DIR}/ventoy/theme/raven-hub"
EXAMPLE="${SCRIPT_DIR}/ventoy/ventoy.json.example"

say()  { printf '%s\n' "==> $*"; }
err()  { printf '%s\n' "ERROR: $*" >&2; }

usage() {
  sed -n '3,25p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

TARGET=""
ASSUME_YES=0
DRY_RUN=0
FORCE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --target)  [ $# -ge 2 ] || usage 1; TARGET=$2; shift 2 ;;
    --yes|-y)  ASSUME_YES=1; shift ;;
    --dry-run|-n) DRY_RUN=1; shift ;;
    --force|-f) FORCE=1; shift ;;
    --help|-h) usage 0 ;;
    *) err "unrecognized option '$1'"; usage 1 ;;
  esac
done

[ -d "$THEME_SRC" ] || { err "theme folder not found: $THEME_SRC"; exit 2; }
[ -f "$EXAMPLE" ]  || { err "example config not found: $EXAMPLE"; exit 2; }

# ---------------------------------------------------------------- target ----
if [ -z "$TARGET" ]; then
  printf '%s\n' "No --target given. Mount points that may be your Ventoy USB:"
  found=0
  for base in /media/* /run/media/*/*; do
    [ -d "$base" ] || continue
    found=1
    printf '    %s\n' "$base"
  done
  [ "$found" -eq 1 ] || printf '    (nothing found under /media or /run/media)\n'
  printf '%s' "Enter the full path of the Ventoy USB data partition: "
  read -r TARGET || { printf '\n'; exit 1; }
  [ -n "$TARGET" ] || { err "no target given"; exit 1; }
fi

[ -d "$TARGET" ] || { err "target does not exist or is not a folder: $TARGET"; exit 2; }
if [ ! -w "$TARGET" ]; then
  err "target is not writable by your user: $TARGET"
  printf '%s\n' "" \
    "Fix suggestions:" \
    "  * re-mount the USB with write access (file manager 'Mount' usually does this)," \
    "  * or copy this folder's 'ventoy' directory there with your file manager." \
    "This script deliberately does not use sudo." >&2
  exit 2
fi

# The ventoy config dir: <target>/ventoy (create when missing), or the target
# itself when the user pointed straight at it.
VENTOY_DIR="${TARGET}/ventoy"
if [ ! -d "$VENTOY_DIR" ] && [ -f "${TARGET}/ventoy.json" ]; then
  VENTOY_DIR=$TARGET
fi

# Ventoy plausibility check (informational, never blocks silently)
LOOKS_VENTOY=0
if [ -d "$VENTOY_DIR" ] || ls -- "$TARGET"/*.iso >/dev/null 2>&1 || ls -- "$VENTOY_DIR"/*.iso >/dev/null 2>&1; then
  LOOKS_VENTOY=1
fi
if [ "$LOOKS_VENTOY" -eq 0 ] && [ "$FORCE" -eq 0 ]; then
  printf '%s\n' "" \
    "WARNING: no 'ventoy' folder or ISO files were found in:" \
    "         $TARGET" \
    "This may still be correct (e.g. a fresh drive)."
  if [ "$ASSUME_YES" -eq 1 ]; then
    say "no Ventoy markers found — continuing because --yes was given (use --force to silence this warning)."
  else
    printf '%s' "Continue with this target anyway? [y/N] "
    read -r ANSWER || ANSWER=""
    case "$ANSWER" in y|Y|yes|YES) ;; *) say "aborted, nothing was changed"; exit 1 ;; esac
  fi
fi

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
JSON="${VENTOY_DIR}/ventoy.json"
BACKUP="${JSON}.bak-${TIMESTAMP}"

# ------------------------------------------------------------- plan/confirm --
printf '%s\n' "" "Raven Hub — Ventoy theme installation" \
  "  USB target   : $TARGET" \
  "  ventoy dir   : $VENTOY_DIR (created if missing)" \
  "  theme files  : ventoy/theme/raven-hub  (only 'raven-hub*' files are replaced)"
if [ -f "$JSON" ]; then
  printf '%s\n' "  existing cfg : YES — a timestamped backup will be created:" \
                 "                 $BACKUP" \
                 "                 then ONLY the \"theme\" object is replaced;" \
                 "                 all your other plugins stay unchanged."
else
  printf '%s\n' "  existing cfg : none — the minimal Raven Hub config will be created."
fi
printf '%s\n' ""

[ "$DRY_RUN" -eq 1 ] && { say "dry run: nothing was changed."; exit 0; }
if [ "$ASSUME_YES" -ne 1 ]; then
  printf '%s' "Proceed? [y/N] "
  read -r ANSWER || ANSWER=""
  case "$ANSWER" in y|Y|yes|YES) ;; *) say "aborted, nothing was changed"; exit 1 ;; esac
fi

# ------------------------------------------------------------ copy theme ----
say "copying theme files..."
mkdir -p "${VENTOY_DIR}/theme" || { err "cannot create ${VENTOY_DIR}/theme"; exit 2; }
rm -rf -- "${VENTOY_DIR}/theme/raven-hub"
cp -a "$THEME_SRC" "${VENTOY_DIR}/theme/raven-hub" || { err "copying the theme failed"; exit 2; }
say "theme installed: ${VENTOY_DIR}/theme/raven-hub"

# ----------------------------------------------------------- configuration --
validate_json() {  # validate_json FILE -> 0 ok
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$1" 2>/dev/null
  elif command -v jq >/dev/null 2>&1; then
    jq empty "$1" >/dev/null 2>&1
  else
    return 0  # no parser available; only called after a parser-based write
  fi
}

if [ ! -f "$JSON" ]; then
  cp -- "$EXAMPLE" "$JSON" || { err "could not create $JSON"; exit 3; }
  validate_json "$JSON" || { err "created config failed validation (this is a bug)"; exit 3; }
  say "created minimal config: $JSON"
else
  # Back up first, merge after, keep the original untouched on any failure.
  cp -p -- "$JSON" "$BACKUP" || { err "could not back up $JSON — aborting before any change"; exit 2; }
  say "backup created: $BACKUP"

  NEW_CFG=$(mktemp) || { err "mktemp failed"; exit 2; }
  trap 'rm -f -- "$NEW_CFG"' EXIT INT TERM
  MERGED=1

  if command -v python3 >/dev/null 2>&1; then
    # Duplicate keys in the user file are refused (they silently discard
    # configuration in permissive parsers). Key order is preserved; only the
    # value of "theme" is replaced.
    python3 - "$JSON" "$EXAMPLE" "$NEW_CFG" <<'PY' || MERGED=0
import json, sys

class Dup(ValueError):
    pass

def hook(pairs):
    seen = set()
    out = {}
    for k, v in pairs:
        if k in seen:
            raise Dup("duplicate key: %r" % k)
        seen.add(k)
        out[k] = v
    return out

try:
    with open(sys.argv[1], encoding="utf-8-sig") as f:
        user = json.load(f, object_pairs_hook=hook)
    with open(sys.argv[2], encoding="utf-8-sig") as f:
        theme = json.load(f, object_pairs_hook=hook)["theme"]
except (ValueError, OSError) as exc:
    sys.stderr.write("cannot parse JSON safely: %s\n" % exc)
    sys.exit(1)

if not isinstance(user, dict):
    sys.stderr.write("ventoy.json must contain a JSON object\n")
    sys.exit(1)

out = {}
for key, value in user.items():
    out[key] = theme if key == "theme" else value
if "theme" not in out:
    out["theme"] = theme

with open(sys.argv[3], "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, indent=4)
    f.write("\n")
PY
  elif command -v jq >/dev/null 2>&1; then
    jq --slurpfile t "$EXAMPLE" '.theme = $t[0].theme' "$JSON" > "$NEW_CFG" || MERGED=0
  else
    MERGED=0
  fi

  if [ "$MERGED" -ne 0 ] && validate_json "$NEW_CFG" && [ -s "$NEW_CFG" ]; then
    cp -- "$NEW_CFG" "$JSON"
    say "merged Raven Hub theme into: $JSON (other plugins untouched)"
  else
    # Your file stays EXACTLY as it was. Show precise manual instructions.
    printf '%s\n' "" \
      "NOTICE: your ventoy.json was NOT modified." \
      "The theme files are installed, but the theme is not activated yet," \
      "because no JSON tool (python3 or jq) is available to merge safely." >&2
    if [ "$MERGED" -ne 0 ]; then
      err "your existing ventoy.json could not be parsed — please check it (the backup is $BACKUP)"
    fi
    printf '%s\n' "" \
      "Manual activation (any text editor):" \
      "  1. Open ${JSON}" \
      "  2. If a \"theme\" key exists, replace its value; otherwise add:" \
      "     $(cat "$EXAMPLE")" \
      "  3. Keep every other key (control, menu_alias, ...) unchanged." \
      "  Or install python3 or jq and re-run this script." >&2
    printf '%s\n' "" "Install finished, theme NOT activated." >&2
    exit 3
  fi
fi

printf '%s\n' "" \
  "SUCCESS — Raven Hub is installed." \
  "  Installed to : ${VENTOY_DIR}/theme/raven-hub" \
  "  Config file  : $JSON"
if [ -f "$BACKUP" ]; then
  printf '%s\n' "  Backup       : $BACKUP" \
                 "  Rollback     : cp \"$BACKUP\" \"$JSON\""
fi
printf '%s\n' "" \
  "Reboot from the USB — Raven Hub appears in the Ventoy menu." \
  "If the menu is ever unreadable: press F7 for Ventoy's text mode." \
  "Uninstall/rollback help: see UNINSTALL.md in this folder."
exit 0
