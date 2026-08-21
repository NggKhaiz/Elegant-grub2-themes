#! /usr/bin/env bash

# Build the release tarballs of Raven Hub GRUB2 themes into ./releases
# This script only builds archives in the repository; it installs nothing.

set -o errexit

OPEN_DIR="$(cd "$(dirname "$0")" && pwd)"

THEME_NAME=Raven-Hub

SCREEN_VARIANTS=('1080p' '2k' '4k')
THEME_VARIANTS=('forest' 'mojave' 'mountain' 'wave')
TYPE_VARIANTS=('window' 'float' 'sharp' 'blur')
SIDE_VARIANTS=('left' 'right')
COLOR_VARIANTS=('dark' 'light')

screens=()
themes=()
types=()
sides=()
colors=()

usage() {
cat << EOF

Usage: $0 [OPTION]...

Build Raven Hub theme release archives into '${OPEN_DIR}/releases'.
With no options, every variant is built (this takes a while).

OPTIONS:
  -t, --theme     Background theme variant(s) [forest|mojave|mountain|wave]
  -p, --type      Theme style variant(s)      [window|float|sharp|blur]
  -i, --side      Picture display side        [left|right]
  -c, --color     Background color variant(s) [dark|light]
  -s, --screen    Screen display variant(s)   [1080p|2k|4k]
  -h, --help      Show this help

EOF
}

while [[ $# -gt 0 ]]; do
  case "${1}" in
    -t|--theme)  shift; while [[ $# -gt 0 && "${1}" != -* ]]; do themes+=("${1}"); shift; done ;;
    -p|--type)   shift; while [[ $# -gt 0 && "${1}" != -* ]]; do types+=("${1}"); shift; done ;;
    -i|--side)   shift; while [[ $# -gt 0 && "${1}" != -* ]]; do sides+=("${1}"); shift; done ;;
    -c|--color)  shift; while [[ $# -gt 0 && "${1}" != -* ]]; do colors+=("${1}"); shift; done ;;
    -s|--screen) shift; while [[ $# -gt 0 && "${1}" != -* ]]; do screens+=("${1}"); shift; done ;;
    -h|--help)   usage; exit 0 ;;
    *)
      echo "ERROR: Unrecognized option '$1'." >&2
      echo "Try '$0 --help' for more information." >&2
      exit 1
      ;;
  esac
done

# Validate requested values against the known variants
validate_values() {
  local value
  for value in "${themes[@]:-${THEME_VARIANTS[@]}}"; do
    [[ " ${THEME_VARIANTS[*]} " == *" ${value} "* ]] || { echo "ERROR: unknown theme '${value}'." >&2; exit 1; }
  done
  for value in "${types[@]:-${TYPE_VARIANTS[@]}}"; do
    [[ " ${TYPE_VARIANTS[*]} " == *" ${value} "* ]] || { echo "ERROR: unknown type '${value}'." >&2; exit 1; }
  done
  for value in "${sides[@]:-${SIDE_VARIANTS[@]}}"; do
    [[ " ${SIDE_VARIANTS[*]} " == *" ${value} "* ]] || { echo "ERROR: unknown side '${value}'." >&2; exit 1; }
  done
  for value in "${colors[@]:-${COLOR_VARIANTS[@]}}"; do
    [[ " ${COLOR_VARIANTS[*]} " == *" ${value} "* ]] || { echo "ERROR: unknown color '${value}'." >&2; exit 1; }
  done
  for value in "${screens[@]:-${SCREEN_VARIANTS[@]}}"; do
    [[ " ${SCREEN_VARIANTS[*]} " == *" ${value} "* ]] || { echo "ERROR: unknown screen '${value}'." >&2; exit 1; }
  done
}
validate_values

[[ "${#screens[@]}" -eq 0 ]] && screens=("${SCREEN_VARIANTS[@]}")
[[ "${#themes[@]}"  -eq 0 ]] && themes=("${THEME_VARIANTS[@]}")
[[ "${#types[@]}"   -eq 0 ]] && types=("${TYPE_VARIANTS[@]}")
[[ "${#sides[@]}"   -eq 0 ]] && sides=("${SIDE_VARIANTS[@]}")
[[ "${#colors[@]}"  -eq 0 ]] && colors=("${COLOR_VARIANTS[@]}")

Tar_themes() {
  local theme type
  for theme in "${themes[@]}"; do
    for type in "${types[@]}"; do
      rm -rf "${THEME_NAME}-${theme}-${type}-grub-themes.tar" \
             "${THEME_NAME}-${theme}-${type}-grub-themes.tar.xz"
      tar -Jcvf "${THEME_NAME}-${theme}-${type}-grub-themes.tar.xz" "${THEME_NAME}-${theme}-${type}-grub-themes"
    done
  done
}

Clear_theme() {
  local theme type
  for theme in "${themes[@]}"; do
    for type in "${types[@]}"; do
      rm -rf "${THEME_NAME}-${theme}-${type}-grub-themes"
    done
  done
}

for theme in "${themes[@]}"; do
  for type in "${types[@]}"; do
    for side in "${sides[@]}"; do
      for color in "${colors[@]}"; do
        if [[ ! -f "${OPEN_DIR}/backgrounds/previews/preview-${theme}-${type}-${side}-${color}.jpg" ]]; then
          echo "ERROR: preview image missing: backgrounds/previews/preview-${theme}-${type}-${side}-${color}.jpg" >&2
          echo "       Generate previews first with: (cd backgrounds && ./render-previews.sh)" >&2
          exit 1
        fi
        for screen in "${screens[@]}"; do
          "${OPEN_DIR}/generate.sh" -d "${OPEN_DIR}/releases/${THEME_NAME}-${theme}-${type}-grub-themes/${side}-${color}-${screen}" \
                                    -t "${theme}" -p "${type}" -i "${side}" -c "${color}" -s "${screen}" -l default
          cp -f "${OPEN_DIR}/releases/install" "${OPEN_DIR}/releases/${THEME_NAME}-${theme}-${type}-grub-themes/${side}-${color}-${screen}/install.sh"
          cp -f "${OPEN_DIR}/backgrounds/previews/preview-${theme}-${type}-${side}-${color}.jpg" \
                "${OPEN_DIR}/releases/${THEME_NAME}-${theme}-${type}-grub-themes/${side}-${color}-${screen}/preview.jpg"
          sed -i "s/grub_theme_name/${THEME_NAME}-${theme}-${type}-${side}-${color}/g" \
                "${OPEN_DIR}/releases/${THEME_NAME}-${theme}-${type}-grub-themes/${side}-${color}-${screen}/install.sh"
        done
      done
    done
  done
done

cd "${OPEN_DIR}/releases"

Tar_themes && Clear_theme
