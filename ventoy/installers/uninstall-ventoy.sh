#!/bin/sh
#
# uninstall-ventoy.sh — remove ONLY the Raven Hub theme from a Ventoy USB.
#
# It removes:
#   * ventoy/theme/raven-hub*            (theme files)
#   * the "theme" object in ventoy.json  (with a timestamped backup first)
#
# It never touches ISO files, persistence files, other themes, or any other
# Ventoy plugin configuration. It never needs root and never uses destructive
# disk commands.
#
# Usage:
#   ./uninstall-ventoy.sh --target /media/$USER/Ventoy          # uninstall
#   ./uninstall-ventoy.sh --target PATH --restore FILE          # restore a backup
#
# Exit codes: 0 success · 1 usage/aborted · 2 target problem
#             3 config could not be edited safely (manual instructions shown)

set -u

say()  { printf '%s\n' "==> $*"; }
err()  { printf '%s\n' "ERROR: $*" >&2; }
usage() { sed -n '3,18p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

TARGET=""
RESTORE=""
ASSUME_YES=0

while [ $# -gt 0 ]; do
  case "$1" in
    --target)  [ $# -ge 2 ] || usage 1; TARGET=$2; shift 2 ;;
    --restore) [ $# -ge 2 ] || usage 1; RESTORE=$2; shift 2 ;;
    --yes|-y)  ASSUME_YES=1; shift ;;
    --help|-h) usage 0 ;;
    *) err "unrecognized option '$1'"; usage 1 ;;
  esac
done

[ -n "$TARGET" ] || { err "--target is required (e.g. --target /media/\$USER/Ventoy)"; exit 1; }
[ -d "$TARGET" ] || { err "target does not exist: $TARGET"; exit 2; }
[ ! -w "$TARGET" ] && { err "target is not writable: $TARGET (see install-ventoy.sh notes)"; exit 2; }

VENTOY_DIR="${TARGET}/ventoy"
[ ! -d "$VENTOY_DIR" ] && [ -f "${TARGET}/ventoy.json" ] && VENTOY_DIR=$TARGET
[ -d "$VENTOY_DIR" ] || { err "no 'ventoy' folder found in $TARGET"; exit 2; }

JSON="${VENTOY_DIR}/ventoy.json"

# ------------------------------------------------------- restore mode -------
if [ -n "$RESTORE" ]; then
  [ -f "$RESTORE" ] || { err "backup file not found: $RESTORE"; exit 2; }
  [ -f "$JSON" ] || { err "no ventoy.json present at $JSON — copy the backup there manually"; exit 2; }
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$RESTORE" 2>/dev/null \
      || { err "backup is not valid JSON: $RESTORE"; exit 2; }
  fi
  cp -p -- "$JSON" "${JSON}.pre-restore-$(date +%Y%m%d-%H%M%S)" || exit 2
  cp -- "$RESTORE" "$JSON"
  say "restored $RESTORE -> $JSON (a copy of the previous state was kept)"
  exit 0
fi

# -------------------------------------------------------- normal uninstall --
THEME_DIRS=$(cd "${VENTOY_DIR}/theme" 2>/dev/null && ls -d raven-hub* 2>/dev/null || true)
printf '%s\n' "" "Raven Hub — uninstall" \
  "  target : $TARGET" \
  "  theme  : ${THEME_DIRS:-<none found>}" \
  "  config : ${JSON}"
printf '%s\n' "ISO files, other themes and unrelated Ventoy plugins are NEVER touched."
[ -z "$THEME_DIRS" ] && [ ! -f "$JSON" ] && { say "nothing to remove — Raven Hub is not installed here."; exit 0; }

if [ "$ASSUME_YES" -ne 1 ]; then
  printf '%s' "Proceed? [y/N] "
  read -r ANSWER || ANSWER=""
  case "$ANSWER" in y|Y|yes|YES) ;; *) say "aborted, nothing was changed"; exit 1 ;; esac
fi

if [ -n "$THEME_DIRS" ]; then
  for d in $THEME_DIRS; do
    rm -rf -- "${VENTOY_DIR}/theme/$d"
    say "removed ventoy/theme/$d"
  done
fi

if [ -f "$JSON" ]; then
  BACKUP="${JSON}.bak-$(date +%Y%m%d-%H%M%S)"
  NEW_CFG=$(mktemp) || exit 2
  trap 'rm -f -- "$NEW_CFG"' EXIT INT TERM
  cp -p -- "$JSON" "$BACKUP"
  if command -v python3 >/dev/null 2>&1; then
    if python3 - "$JSON" "$NEW_CFG" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8-sig") as f:
    data = json.load(f)
out = {k: v for k, v in data.items() if k != "theme"}
with open(sys.argv[2], "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, indent=4)
    f.write("\n")
PY
    then
      cp -- "$NEW_CFG" "$JSON"
      say "removed \"theme\" from ventoy.json (backup: $BACKUP)"
    else
      err "could not edit ventoy.json safely — nothing was overwritten"
      say "manual fix: open $JSON and delete the \"theme\" object"
      exit 3
    fi
  elif command -v jq >/dev/null 2>&1; then
    if jq 'del(.theme)' "$JSON" > "$NEW_CFG" && cp -- "$NEW_CFG" "$JSON"; then
      say "removed \"theme\" from ventoy.json (backup: $BACKUP)"
    else
      err "jq failed — nothing was overwritten; edit $JSON manually"
      exit 3
    fi
  else
    printf '%s\n' "" \
      "NOTICE: ventoy.json was NOT modified (no python3 or jq available)." \
      "The theme files are removed; to finish, open:" "  $JSON" \
      "and delete the \"theme\" object. A backup was saved at $BACKUP" >&2
    exit 3
  fi
fi

printf '%s\n' "" "SUCCESS — Raven Hub removed. Ventoy shows its stock menu again." \
  "Restore the previous config any time: cp \"$BACKUP\" \"$JSON\" (or use --restore)."
exit 0
