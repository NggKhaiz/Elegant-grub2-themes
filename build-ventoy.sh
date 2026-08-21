#!/usr/bin/env bash
#
# build-ventoy.sh — build a copy-ready "Raven Hub" GRUB2 theme package for a
# Ventoy USB data partition.
#
# The result is a plain directory tree you copy onto the Ventoy USB (the big
# first partition). This script NEVER touches the running operating system,
# never needs root, and the package itself contains only files that are read
# at boot time — no logs, caches or mutable state go onto the USB.
#
# Package layout (single-resolution build):
#
#   DEST/
#     ventoy.json              <- theme-only drop-in (for fresh Ventoy USBs)
#     ventoy.json.example      <- example incl. optional menu_class section
#     README.md                <- short copy/merge/recovery instructions
#     theme/raven-hub/
#       theme.txt
#       backgrounds/background.jpg
#       icons/...              <- Standard profile only
#       fonts/...
#       select_c.png select_e.png select_w.png info.png logo.png
#       README.md
#
# Exit codes: 0 success · 1 usage error · 2 missing dependency or source asset
#             3 build or validation failure
#
# Raven Hub is a rebrand of Elegant-grub2-themes (art by vinceliuice et al.,
# GPL-3.0). See LICENSE and README.md in the repository root.

set -o errexit
set -o nounset
set -o pipefail

REPO_DIR="$(cd "$(dirname "$(readlink -m "${BASH_SOURCE[0]}")")" && pwd)"

# ---------------------------------------------------------------------------
# Fixed Raven Hub identity: "float" panel style, picture on the left, menu
# column on the right. Art/color/resolution remain selectable below.
# ---------------------------------------------------------------------------
PRODUCT_NAME="Raven Hub"
THEME_SLUG="raven-hub"
STYLE="float"
SIDE="left"
GFXMODE="max"          # Ventoy-documented value: best available mode at boot

THEMES="forest mojave mountain wave"
COLORS="dark light"
PROFILES="standard lite"
SCREENS="1080p 2k 4k"

res_for_screen() {
  case "${1}" in
    1080p) echo "1920x1080" ;;
    2k)    echo "2560x1440" ;;
    4k)    echo "3840x2160" ;;
    *)     return 1 ;;
  esac
}

usage() {
cat << EOF
Usage: $0 [OPTION]...

Build a copy-ready ${PRODUCT_NAME} theme package for a Ventoy USB.
Nothing is installed on this computer; the package is written to --dest only.

OPTIONS:
  -o, --dest DIR       Output directory (default: dist/ventoy).
                       Only the paths this script manages are replaced in it.
  -p, --profile NAME   standard = icons + Unifont font (full Unicode coverage)
                       lite      = Terminus-only fonts, no icons (~10x smaller)
                       (default: standard)
  -t, --theme NAME     Background art: forest|mojave|mountain|wave
                       (default: mountain)
  -c, --color NAME     dark|light (default: dark)
  -s, --screen NAME    Asset resolution: 1080p|2k|4k (default: 1080p)
      --multires       Build per-resolution theme variants (1920x1080,
                       2560x1440, 3840x2160) plus a resolution-neutral fallback
                       and switch ventoy.json to Ventoy's resolution_fit mode.
                       Fonts dominate the size — see VENTOY.md before using.
  -n, --dry-run        Print the build plan and exit without writing anything.
  -h, --help           Show this help.

EXAMPLES
  $0                            # Standard, mountain/dark, 1080p -> dist/ventoy
  $0 -p lite                    # ~10x smaller package (Latin/Greek/Cyrillic)
  $0 -p lite -o "/media/\$USER/VENTOY/ventoy"   # build straight onto the USB
  $0 --multires                 # per-resolution themes via Ventoy resolution_fit

After building: copy 'ventoy.json' (or merge it with tools/ventoy-merge-theme.sh)
and the 'theme/' directory into the 'ventoy' folder of the USB data partition.
Full guide: VENTOY.md in the repository root.
EOF
}

die()  { local code="$1"; shift; echo "ERROR: $*" >&2; exit "${code}"; }
info() { echo "==> $*"; }
warn() { echo "WARNING: $*" >&2; }

# ---------------------------------------------------------------------------
# Argument parsing and validation
# ---------------------------------------------------------------------------
dest="${REPO_DIR}/dist/ventoy"
profile="standard"
theme="mountain"
color="dark"
screen="1080p"
multires="false"
dry_run="false"

while [[ $# -gt 0 ]]; do
  case "${1}" in
    -o|--dest)    dest="${2:-}"; [[ -n "${dest}" ]] || die 1 "--dest needs a directory"; shift 2 ;;
    -p|--profile) profile="${2:-}"; shift 2 ;;
    -t|--theme)   theme="${2:-}"; shift 2 ;;
    -c|--color)   color="${2:-}"; shift 2 ;;
    -s|--screen)  screen="${2:-}"; shift 2 ;;
    --multires)   multires="true"; shift ;;
    -n|--dry-run) dry_run="true"; shift ;;
    -h|--help)    usage; exit 0 ;;
    *)            usage; echo; die 1 "unrecognized option '${1}'" ;;
  esac
done

[[ " ${PROFILES} " == *" ${profile} "* ]] || die 1 "unknown profile '${profile}' (use: ${PROFILES})"
[[ " ${THEMES} "   == *" ${theme} "*   ]] || die 1 "unknown theme '${theme}' (use: ${THEMES})"
[[ " ${COLORS} "   == *" ${color} "*   ]] || die 1 "unknown color '${color}' (use: ${COLORS})"
[[ " ${SCREENS} "  == *" ${screen} "*  ]] || die 1 "unknown screen '${screen}' (use: ${SCREENS})"

# Refuse obviously dangerous output targets.
case "${dest}" in
  /|/home|/home/|/tmp|/media|/run|/dev|/proc|/sys|"${REPO_DIR}") die 1 "refusing to use '${dest}' as output directory" ;;
esac
[[ ! -e "${dest}" || -d "${dest}" ]] || die 1 "'${dest}' exists and is not a directory"

# ---------------------------------------------------------------------------
# Dependencies (coreutils only is mandatory; python3/jq improve validation)
# ---------------------------------------------------------------------------
for dep in cp mkdir rm cat sed du find grep sort mktemp convert identify; do
  command -v "${dep}" >/dev/null 2>&1 || die 2 "missing dependency '${dep}'" \
    "(coreutils + ImageMagick are needed; e.g. 'sudo apt install imagemagick')"
done
have_python3="false"; command -v python3 >/dev/null 2>&1 && have_python3="true"
have_jq="false";      command -v jq      >/dev/null 2>&1 && have_jq="true"
if [[ "${have_python3}" != "true" ]]; then
  warn "python3 not found: JSON duplicate-key and PF2 font-name checks will be skipped."
fi

# ---------------------------------------------------------------------------
# Per-profile/per-resolution theme metrics
# ---------------------------------------------------------------------------
metrics_for() {
  case "${1}:${profile}" in
    1080p:standard) ITEM_FONT="Unifont Regular 16";  ICON=32; ROW=48; SPACE=6;  PAD=3; GAP=6 ;;
    2k:standard)    ITEM_FONT="Unifont Regular 24";  ICON=48; ROW=72; SPACE=8;  PAD=4; GAP=8 ;;
    4k:standard)    ITEM_FONT="Unifont Regular 32";  ICON=64; ROW=96; SPACE=12; PAD=6; GAP=12 ;;
    1080p:lite)     ITEM_FONT="Terminus Regular 16"; ICON=32; ROW=48; SPACE=6;  PAD=3; GAP=6 ;;
    2k:lite|4k:lite) ITEM_FONT="Terminus Regular 18"; ICON=48; ROW=72; SPACE=8;  PAD=4; GAP=8 ;;
    *) die 1 "internal error: no metrics for ${1}/${profile}" ;;
  esac
}

fonts_for() {  # pf2 files needed for a given screen
  case "${1}:${profile}" in
    1080p:standard) echo "unifont-16.pf2 terminus-14.pf2" ;;
    2k:standard)    echo "unifont-24.pf2 terminus-14.pf2" ;;
    4k:standard)    echo "unifont-32.pf2 terminus-14.pf2" ;;
    1080p:lite)     echo "terminus-16.pf2 terminus-14.pf2" ;;
    2k:lite|4k:lite) echo "terminus-18.pf2 terminus-14.pf2" ;;
    *) die 1 "internal error: no fonts for ${1}/${profile}" ;;
  esac
}

# Theme directories a package will contain.
# Multires builds exactly the three resolution-marked dirs (Ventoy's
# resolution_fit matches the "WWWxHHH" string in the theme path). No unmarked
# fallback is shipped because it would have to duplicate 1080p assets; on
# panels with other native modes Ventoy simply shows its default menu
# (documented in VENTOY.md) — use the single-theme package there instead.
package_theme_dirs() {
  if [[ "${multires}" == "true" ]]; then
    echo "${THEME_SLUG}-1920x1080"
    echo "${THEME_SLUG}-2560x1440"
    echo "${THEME_SLUG}-3840x2160"
  else
    echo "${THEME_SLUG}"
  fi
}

# The directory that hosts the shared fonts/ set for the package.
primary_theme_dir() {
  if [[ "${multires}" == "true" ]]; then echo "${THEME_SLUG}-1920x1080"; else echo "${THEME_SLUG}"; fi
}

# Screens the package builds themes for (one per line).
package_screens() {
  if [[ "${multires}" == "true" ]]; then printf '%s\n' 1080p 2k 4k; else echo "${screen}"; fi
}

# Union of font files across the package.
all_font_files() {
  local s out="" f
  for s in $(package_screens); do
    for f in $(fonts_for "${s}"); do out="${out} ${f}"; done
  done
  echo "${out}" | tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ' | sed 's/ $//'
}

validate_sources() {  # validate_sources <screen>
  local scr="$1" f alt=""
  [[ -f "${REPO_DIR}/backgrounds/backgrounds-${theme}/background-${theme}-${STYLE}-${SIDE}-${color}.jpg" ]] \
    || die 2 "missing background: backgrounds/backgrounds-${theme}/background-${theme}-${STYLE}-${SIDE}-${color}.jpg"
  [[ -d "${REPO_DIR}/assets/assets-icons-${color}/icons-${color}-${scr}" ]] \
    || die 2 "missing icon set: assets/assets-icons-${color}/icons-${color}-${scr}"
  [[ "${theme}" == "forest" ]] && alt="-alt"
  [[ -f "${REPO_DIR}/assets/assets-other/other-${scr}/${STYLE}-${SIDE}${alt}.png" ]] \
    || die 2 "missing art overlay: assets/assets-other/other-${scr}/${STYLE}-${SIDE}${alt}.png"
  [[ -f "${REPO_DIR}/assets/assets-other/other-${scr}/Default.png" ]] \
    || die 2 "missing logo asset: assets/assets-other/other-${scr}/Default.png"
  for f in select_c select_e select_w; do
    [[ -f "${REPO_DIR}/assets/assets-other/other-${scr}/${f}-${theme}-${color}.png" ]] \
      || die 2 "missing selection pixmap: assets/assets-other/other-${scr}/${f}-${theme}-${color}.png"
  done
  for f in $(fonts_for "${scr}") Default.png; do
    if [[ "${f}" == *.png ]]; then
      [[ -f "${REPO_DIR}/assets/assets-other/other-${scr}/${f}" ]] || die 2 "missing logo asset: assets/assets-other/other-${scr}/${f}"
    else
      [[ -f "${REPO_DIR}/common/${f}" ]] || die 2 "missing font: common/${f}"
    fi
  done
}

# ---------------------------------------------------------------------------
# Emitters (deterministic: same inputs -> byte-identical outputs)
# ---------------------------------------------------------------------------
emit_theme_txt() {  # emit_theme_txt <screen>
  local scr="$1"
  metrics_for "${scr}"
  local item_color="#efefef" timeout_color="#ffffff" desktop_color="#242424" tip_color="#d8d8d8"
  if [[ "${color}" == "light" ]]; then
    item_color="#333333"; timeout_color="#333333"; desktop_color="#f0f0f0"; tip_color="#404040"
  fi
  cat << THEME
# ${PRODUCT_NAME} — GRUB2 gfxmenu theme for Ventoy
# Variant: ${theme}/${STYLE}/${SIDE}/${color} assets at $(res_for_screen "${scr}")
# Lineage: Elegant-grub2-themes, art and assets by vinceliuice et al. (GPL-3.0).
# Geometry is percent-based so the layout scales with whatever gfxmode Ventoy
# selects; fonts and icons are sized for the $(res_for_screen "${scr}") asset set.

# Global properties
title-text: ""
desktop-image: "backgrounds/background.jpg"
desktop-color: "${desktop_color}"
terminal-font: "Terminus Regular 14"
terminal-left: "0"
terminal-top: "0"
terminal-width: "100%"
terminal-height: "100%"
terminal-border: "0"

# The Ventoy boot menu (ISO list)
+ boot_menu {
  left = 55%
  top = 12%
  width = 34%
  height = 64%
  item_font = "${ITEM_FONT}"
  item_color = "${item_color}"
  selected_item_color = "#ffffff"
  icon_width = ${ICON}
  icon_height = ${ICON}
  item_icon_space = ${SPACE}
  item_height = ${ROW}
  item_padding = ${PAD}
  item_spacing = ${GAP}
  selected_item_pixmap_style = "select_*.png"
}

# (The art overlay and mountain logo are composited INTO background.jpg at
# build time, so they scale with the background at every gfxmode.)

# Timeout message (GRUB substitutes %d; Ventoy shows none without a timeout)
+ label {
  top = 83%
  left = 55%
  width = 34%
  align = "center"
  id = "__timeout__"
  text = "Booting in %d seconds"
  color = "${timeout_color}"
  font = "${ITEM_FONT}"
}

# Ventoy hotkey tips (macros substituted by Ventoy at boot; safe to delete)
+ hbox {
  left = 55%
  top = 95%
  width = 43%
  height = 24
  + label { text = "@VTOY_HOTKEY_TIP@" color = "${tip_color}" align = "left" font = "Terminus Regular 14" }
}
+ hbox {
  left = 87%
  top = 1%
  width = 12%
  height = 24
  + label { text = "@VTOY_MEM_DISK@" color = "${tip_color}" align = "right" font = "Terminus Regular 14" }
}
THEME
}

emit_theme_json_config() {  # shared by ventoy.json and ventoy.json.example
  # (trailing empty lines are squeezed: array_keys is empty in single-res mode)
  local file_value="\"/ventoy/theme/${THEME_SLUG}/theme.txt\""
  local array_keys=""
  local font_dir="/ventoy/theme/${THEME_SLUG}/fonts"
  if [[ "${multires}" == "true" ]]; then
    file_value="[
            \"/ventoy/theme/${THEME_SLUG}-1920x1080/theme.txt\",
            \"/ventoy/theme/${THEME_SLUG}-2560x1440/theme.txt\",
            \"/ventoy/theme/${THEME_SLUG}-3840x2160/theme.txt\"
        ]"
    array_keys="\"default_file\": 0,
        \"resolution_fit\": 1,"
    font_dir="/ventoy/theme/${THEME_SLUG}-1920x1080/fonts"
  fi
  local fonts="" f first="true"
  for f in $(all_font_files); do
    ${first} || fonts+=","
    first="false"
    fonts+="
            \"${font_dir}/${f}\""
  done
  local body
  body="$(cat << JSON
{
    "theme": {
        "file": ${file_value},
        ${array_keys}
        "gfxmode": "${GFXMODE}",
        "display_mode": "GUI",
        "ventoy_left": "2%",
        "ventoy_top": "96%",
        "ventoy_color": "#f0f0f0",
        "fonts": [${fonts}
        ]
    }
}
JSON
)"
  # squeeze the whitespace-only line left behind when array_keys is empty
  printf '%s\n' "${body}" | sed '/^[[:space:]]*$/d'
}

emit_ventoy_json_example() {
  # The optional menu_class section only makes sense when icons are shipped
  # (Standard profile); the Lite profile has no icons directory.
  if [[ "${profile}" != "standard" ]]; then
    emit_theme_json_config
    return
  fi
  # Drop the outer closing brace, then append sibling sections after "theme".
  emit_theme_json_config | sed '\#^}$#d' | sed '\#^    }$#s/$/,/'
  cat << JSON

    "menu_class": [
        { "key": "ubuntu",    "class": "ubuntu" },
        { "key": "Windows",   "class": "windows" },
        { "key": "archlinux", "class": "arch" },
        { "key": "debian",    "class": "debian" },
        { "dir": "/ISO/Linux", "class": "linux" }
    ]
}
JSON
}

install_theme_dir() {  # install_theme_dir <screen> <stage-dir>
  local scr="$1"
  local dir="$2"
  local alt=""
  [[ "${theme}" == "forest" ]] && alt="-alt"

  mkdir -p "${dir}/backgrounds"
  emit_theme_txt "${scr}" > "${dir}/theme.txt"
  composite_background "${scr}" > "${dir}/backgrounds/background.jpg"
  local f
  for f in select_c select_e select_w; do
    cp -a "${REPO_DIR}/assets/assets-other/other-${scr}/${f}-${theme}-${color}.png" "${dir}/${f}.png"
  done
  if [[ "${profile}" == "standard" ]]; then
    cp -a "${REPO_DIR}/assets/assets-icons-${color}/icons-${color}-${scr}" "${dir}/icons"
  fi
  cp -a "${REPO_DIR}/ventoy/theme-README.md" "${dir}/README.md"
}

# Composite the art overlay and the mountain logo into the background JPEG.
# Rationale: GRUB draws `+ image` widgets at their natural pixel size, so a
# separate overlay would misalign with the percent-based menu at any gfxmode
# other than the asset's native 1920x1080. Baking both into the background
# keeps photo, overlay, logo and menu perfectly aligned at every resolution,
# because `desktop-image` scales the whole composite to the active mode.
# Logo position matches the upstream config: left 12%, top 29%.
composite_background() {  # composite_background <screen> -> stdout (jpeg)
  local scr="$1"
  local alt=""
  [[ "${theme}" == "forest" ]] && alt="-alt"
  local bg="${REPO_DIR}/backgrounds/backgrounds-${theme}/background-${theme}-${STYLE}-${SIDE}-${color}.jpg"
  local overlay="${REPO_DIR}/assets/assets-other/other-${scr}/${STYLE}-${SIDE}${alt}.png"
  local logo="${REPO_DIR}/assets/assets-other/other-${scr}/Default.png"

  # sanity: the upstream background source is expected to be 1920x1080;
  # for 2k/4k asset sets it is upscaled (documented trade-off).
  local bg_w bg_h
  bg_w="$(identify -format '%w' "${bg}")"
  bg_h="$(identify -format '%h' "${bg}")"
  [[ "${bg_w}" -eq 1920 && "${bg_h}" -eq 1080 ]] || warn "background source is ${bg_w}x${bg_h}, expected 1920x1080"

  # scale overlay/logo to match the per-screen asset set (2k/4k overlays are
  # native; the background is the 1920x1080 upstream source, upscaled here)
  local out_w out_h
  case "${scr}" in
    1080p) out_w=1920; out_h=1080 ;;
    2k)    out_w=2560; out_h=1440 ;;
    4k)    out_w=3840; out_h=2160 ;;
  esac
  # logo: 448px at 1080p-class, scaled with the asset set, at 12% / 29%
  local logo_size logo_x logo_y
  case "${scr}" in
    1080p) logo_size=448; logo_x=230; logo_y=313 ;;
    2k)    logo_size=672; logo_x=307; logo_y=418 ;;
    4k)    logo_size=896; logo_x=460; logo_y=626 ;;
  esac

  # ImageMagick 6 semantics: an operator applies to every image loaded since
  # the previous operator, so each source is resized inside its own group \( \).
  convert \( "${bg}" -resize "${out_w}x${out_h}!" \) \
          \( "${overlay}" -resize "${out_w}x${out_h}!" \) \
          -composite \
          \( "${logo}" -resize "${logo_size}x${logo_size}!" \) \
          -gravity northwest -geometry "+${logo_x}+${logo_y}" -composite \
          -quality 92 "jpg:-"
}

# ---------------------------------------------------------------------------
# Package validation (run against the staging directory before publishing)
# ---------------------------------------------------------------------------
validate_package() {  # validate_package <package-root>
  local root="$1"
  local failed="false"
  local dir tdir ref glob cls

  info "validating theme asset references..."
  while IFS= read -r dir; do
    tdir="${root}/theme/${dir}"
    [[ -f "${tdir}/theme.txt" ]] || { echo "  MISSING: ${tdir}/theme.txt" >&2; failed="true"; continue; }
    while IFS= read -r ref; do
      [[ -n "${ref}" ]] || continue
      if [[ "${ref}" == *'*'* ]]; then
        # shellcheck disable=SC2086 # intentional glob expansion
        if ! compgen -G "${tdir}/${ref}" >/dev/null; then
          echo "  MISSING (glob '${ref}') in ${tdir}" >&2; failed="true"
        fi
      elif [[ ! -f "${tdir}/${ref}" && ! -d "${tdir}/${ref}" ]]; then
        echo "  MISSING: ${tdir}/${ref}" >&2; failed="true"
      fi
    done < <(sed -n -e 's/^[[:space:]]*desktop-image:[[:space:]]*"\([^"]*\)".*/\1/p' \
                    -e 's/^[[:space:]]*file[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' \
                    "${tdir}/theme.txt" | sort -u)
    for glob in select_c select_e select_w; do
      [[ -f "${tdir}/${glob}.png" ]] || { echo "  MISSING: ${tdir}/${glob}.png" >&2; failed="true"; }
    done
  done < <(package_theme_dirs)

  # The primary theme dir hosts the shared font set for the whole package.
  info "validating fonts..."
  local font_host
  font_host="$(primary_theme_dir)"
  for glob in $(all_font_files); do
    [[ -f "${root}/theme/${font_host}/fonts/${glob}" ]] || { echo "  MISSING font: theme/${font_host}/fonts/${glob}" >&2; failed="true"; }
  done

  info "validating JSON files..."
  local j
  for j in ventoy.json ventoy.json.example; do
    if [[ "${have_python3}" == "true" ]]; then
      python3 "${REPO_DIR}/tools/json_dup_check.py" "${root}/${j}" || failed="true"
    elif [[ "${have_jq}" == "true" ]]; then
      jq empty "${root}/${j}" && echo "  ${root}/${j}: OK (jq only; duplicate-key check skipped)" || failed="true"
    else
      warn "cannot validate ${root}/${j} (no python3/jq available)"
    fi
  done

  info "validating /ventoy/... paths referenced by ventoy.json files..."
  while IFS= read -r ref; do
    [[ -n "${ref}" ]] || continue
    local rel="${ref#/ventoy/}"
    [[ -e "${root}/${rel}" ]] || { echo "  MISSING in package: ${ref}" >&2; failed="true"; }
  done < <(cat "${root}/ventoy.json" "${root}/ventoy.json.example" | grep -o '"/ventoy/[^"]*"' | tr -d '"' | sort -u)

  info "validating menu_class example icons..."
  while IFS= read -r cls; do
    [[ -n "${cls}" ]] || continue
    [[ -f "${root}/theme/$(primary_theme_dir)/icons/${cls}.png" ]] || { echo "  MISSING icon for example class '${cls}'" >&2; failed="true"; }
  done < <(sed -n 's/.*"class":[[:space:]]*"\([^"]*\)".*/\1/p' "${root}/ventoy.json.example" | sort -u)

  if [[ "${have_python3}" == "true" ]]; then
    info "validating PF2 font names referenced by theme.txt..."
    if ! python3 - "${root}" <<'PYEOF'
import struct, sys, re, os, glob
root = sys.argv[1]
names = set()
for pf in glob.glob(os.path.join(root, "theme", "*", "fonts", "*.pf2")):
    with open(pf, "rb") as f:
        head = f.read(4096)
    i = 0
    while i + 8 <= len(head):
        tag = head[i:i+4]
        try:
            ln = struct.unpack(">I", head[i+4:i+8])[0]
        except struct.error:
            break
        if tag == b"NAME" and 0 < ln < 100:
            names.add(head[i+8:i+8+ln].rstrip(b"\0").decode())
            break
        i += 8 + ln
ok = True
for td in sorted(glob.glob(os.path.join(root, "theme", "*"))):
    tt = os.path.join(td, "theme.txt")
    if not os.path.isfile(tt):
        continue
    for m in re.finditer(r'(?:item_font|terminal-font|font)\s*=?\s*"([^"]+)"', open(tt, encoding="utf-8").read()):
        fname = m.group(1)
        if fname not in names:
            print(f"  theme {os.path.basename(td)}: font {fname!r} not present in package fonts", file=sys.stderr)
            ok = False
sys.exit(0 if ok else 1)
PYEOF
    then failed="true"; fi
  fi

  [[ "${failed}" == "false" ]] || die 3 "package validation FAILED (see messages above)"
  info "package validation passed."
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
ALL_FONTS="$(all_font_files)"

if [[ "${dry_run}" == "true" ]]; then
  echo "${PRODUCT_NAME} Ventoy package — dry-run build plan"
  echo "  output     : ${dest}"
  echo "  profile    : ${profile}"
  echo "  art        : ${theme}/${STYLE}/${SIDE}/${color}"
  echo "  single-res assets : ${screen} ($(res_for_screen "${screen}"))"
  echo "  multires   : ${multires}"
  echo "  gfxmode    : ${GFXMODE}"
  echo "  fonts      : ${ALL_FONTS}"
  echo "  theme dirs : $(package_theme_dirs | tr '\n' ' ')"
  echo "Nothing written (dry run)."
  exit 0
fi

while IFS= read -r s; do validate_sources "${s}"; done < <(package_screens)

info "building ${PRODUCT_NAME} Ventoy package (${profile} profile, ${theme}/${color}, $( [[ ${multires} == true ]] && echo multires || echo "${screen}"))"

# Stage everything in a temporary directory; the package is validated there
# and only published to --dest if every check passes.
stage="$(mktemp -d)"
trap 'rm -rf "${stage}"' EXIT

# Primary theme: 1080p assets (marked raven-hub-1920x1080 in multires mode,
# plain raven-hub with the chosen --screen assets otherwise). It also hosts
# the package-wide fonts/ directory.
primary_screen="1080p"
primary_dir="${THEME_SLUG}"
if [[ "${multires}" == "true" ]]; then
  primary_dir="${THEME_SLUG}-1920x1080"
else
  primary_screen="${screen}"
fi
install_theme_dir "${primary_screen}" "${stage}/theme/${primary_dir}"
mkdir -p "${stage}/theme/${primary_dir}/fonts"
for f in ${ALL_FONTS}; do
  cp -a "${REPO_DIR}/common/${f}" "${stage}/theme/${primary_dir}/fonts/"
done

if [[ "${multires}" == "true" ]]; then
  install_theme_dir "2k" "${stage}/theme/${THEME_SLUG}-2560x1440"
  install_theme_dir "4k" "${stage}/theme/${THEME_SLUG}-3840x2160"
fi

emit_theme_json_config > "${stage}/ventoy.json"
emit_ventoy_json_example > "${stage}/ventoy.json.example"
cp -a "${REPO_DIR}/ventoy/package-README.md" "${stage}/README.md"

validate_package "${stage}"

# ---- publish: replace only the paths this script owns inside --dest -------
mkdir -p "${dest}/theme" || die 3 "cannot create '${dest}/theme' (is ${dest} writable?)"
# Every 'raven-hub*' theme directory belongs to this script (including dirs
# left behind by earlier builds with different options); remove them all so no
# stale assets survive a reconfiguration. Anything else in dest/ is untouched.
rm -rf "${dest}"/theme/${THEME_SLUG} "${dest}"/theme/${THEME_SLUG}-*
cp -a "${stage}/theme/." "${dest}/theme/"
for f in ventoy.json ventoy.json.example README.md; do
  cp -a "${stage}/${f}" "${dest}/${f}"
done

echo
info "${PRODUCT_NAME} build complete:"
echo "    package       : ${dest}"
echo "    profile       : ${profile}"
echo "    art           : ${theme}/${STYLE}/${SIDE}/${color}"
echo "    theme dirs    : $(package_theme_dirs | tr '\n' ' ')"
echo "    package size  : $(du -sh "${dest}" | cut -f1) ($(find "${dest}" -type f | wc -l) files)"
echo "    biggest files :"
find "${dest}" -type f -printf '%s\t%p\n' | sort -rn | head -n 5 | awk -F'\t' '{printf "      %8.1f KiB  %s\n", $1/1024, $2}'
echo
echo "Next steps:"
echo "  1. Fresh Ventoy USB: copy 'ventoy.json' and 'theme/' into the USB's 'ventoy' folder."
echo "  2. Existing ventoy.json: merge safely with tools/ventoy-merge-theme.sh."
echo "  3. Full guide: VENTOY.md (recovery + rollback included)."
