#! /usr/bin/env bash
# shellcheck shell=bash disable=SC2034  # install_boot/GRUB_DIR are set here and
# consumed by core.sh (sourced below) — cross-file use is invisible to ShellCheck

# Exit Immediately if a command fails
set -o errexit

REPO_DIR="$(dirname "$(readlink -m "${0}")")"
readonly REPO_DIR
source "${REPO_DIR}/core.sh"

usage() {
cat << EOF

Usage: $0 [OPTION]...

Raven Hub — GRUB2 themes (successor of the Elegant GRUB2 themes)

OPTIONS:
  -t, --theme     Background theme variant(s) [forest|mojave|mountain|wave] (default is forest)
  -p, --type      Theme style variant(s)      [window|float|sharp|blur] (default is window)
  -i, --side      Picture display side        [left|right] (default is left)
  -c, --color     Background color variant(s) [dark|light] (default is dark)
  -s, --screen    Screen display variant(s)   [1080p|2k|4k] (default is 1080p)
  -l, --logo      Show a logo on picture      [default|system] (default: a mountain logo)
  -r, --remove    Remove/Uninstall theme      (must add theme options, default is Raven-Hub-forest-window-left-dark;
                  this also removes legacy 'Elegant-...-left-dark' installs of the same variant)
  -b, --boot      Install theme into '/boot/grub' or '/boot/grub2'
  -h, --help      Show this help

Examples:
  $0 -t mountain -s 2k          install the mountain variant for a 2560x1440 display
  sudo $0 -b -t wave            install the wave variant into /boot/grub/themes
  sudo $0 -r -t mountain        uninstall the mountain variant

Ventoy users: this script installs into the running operating system only.
To prepare a Ventoy USB instead, run './build-ventoy.sh --help'.

EOF
}

#######################################################
#   :::::: A R G U M E N T   H A N D L I N G ::::::   #
#######################################################

while [[ $# -gt 0 ]]; do
  PROG_ARGS+=("${1}")
  dialog='false'
  case "${1}" in
    -r|--remove)
      remove='true'
      shift
      ;;
    -b|--boot)
      install_boot='true'
      if [[ -d "/boot/grub" ]]; then
        GRUB_DIR="/boot/grub/themes"
      elif [[ -d "/boot/grub2" ]]; then
        GRUB_DIR="/boot/grub2/themes"
      fi
      shift
      ;;
    -t|--theme)
      shift
      for theme in "${@}"; do
        case "${theme}" in
          forest)
            themes+=("${THEME_VARIANTS[0]}")
            shift
            ;;
          mojave)
            themes+=("${THEME_VARIANTS[1]}")
            shift
            ;;
          mountain)
            themes+=("${THEME_VARIANTS[2]}")
            shift
            ;;
          wave)
            themes+=("${THEME_VARIANTS[3]}")
            shift
            ;;
          -*)
            break
            ;;
          *)
            prompt -e "ERROR: Unrecognized theme variant '$1'."
            prompt -i "Try '$0 --help' for more information."
            exit 1
            ;;
        esac
      done
      ;;
    -p|--type)
      shift
      for type in "${@}"; do
        case "${type}" in
          window)
            types+=("${TYPE_VARIANTS[0]}")
            shift
            ;;
          float)
            types+=("${TYPE_VARIANTS[1]}")
            shift
            ;;
          sharp)
            types+=("${TYPE_VARIANTS[2]}")
            shift
            ;;
          blur)
            types+=("${TYPE_VARIANTS[3]}")
            shift
            ;;
          -*)
            break
            ;;
          *)
            prompt -e "ERROR: Unrecognized type variant '$1'."
            prompt -i "Try '$0 --help' for more information."
            exit 1
            ;;
        esac
      done
      ;;
    -i|--side)
      shift
      for side in "${@}"; do
        case "${side}" in
          left)
            sides+=("${SIDE_VARIANTS[0]}")
            shift
            ;;
          right)
            sides+=("${SIDE_VARIANTS[1]}")
            shift
            ;;
          -*)
            break
            ;;
          *)
            prompt -e "ERROR: Unrecognized side variant '$1'."
            prompt -i "Try '$0 --help' for more information."
            exit 1
            ;;
        esac
      done
      ;;
    -c|--color)
      shift
      for color in "${@}"; do
        case "${color}" in
          dark)
            colors+=("${COLOR_VARIANTS[0]}")
            shift
            ;;
          light)
            colors+=("${COLOR_VARIANTS[1]}")
            shift
            ;;
          -*)
            break
            ;;
          *)
            prompt -e "ERROR: Unrecognized color variant '$1'."
            prompt -i "Try '$0 --help' for more information."
            exit 1
            ;;
        esac
      done
      ;;
    -s|--screen)
      shift
      for screen in "${@}"; do
        case "${screen}" in
          1080p)
            screens+=("${SCREEN_VARIANTS[0]}")
            shift
            ;;
          2k)
            screens+=("${SCREEN_VARIANTS[1]}")
            shift
            ;;
          4k)
            screens+=("${SCREEN_VARIANTS[2]}")
            shift
            ;;
          -*)
            break
            ;;
          *)
            prompt -e "ERROR: Unrecognized screen variant '$1'."
            prompt -i "Try '$0 --help' for more information."
            exit 1
            ;;
        esac
      done
      ;;
    -l|--logo)
      shift
      for logo in "${@}"; do
        case "${logo}" in
          default)
            logoicon="Default"
            shift
            ;;
          system)
            logoicon="$(detect_system_logo)"
            if [[ -z "${logoicon}" ]]; then
              prompt -w "Could not detect the running distribution; using the default mountain logo."
              logoicon="Default"
            fi
            shift
            ;;
          -*)
            break
            ;;
          *)
            prompt -e "ERROR: Unrecognized logo variant '$1'."
            prompt -i "Try '$0 --help' for more information."
            exit 1
            ;;
        esac
      done
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      prompt -e "ERROR: Unrecognized installation option '$1'."
      prompt -i "Try '$0 --help' for more information."
      exit 1
      ;;
  esac
done

#############################
#   :::::: M A I N ::::::   #
#############################

# Show terminal user interface for better use
if [[ "${dialog:-}" == 'false' ]]; then
  if [[ "${remove:-}" != 'true' ]]; then
    for theme in "${themes[@]-${THEME_VARIANTS[0]}}"; do
      for type in "${types[@]-${TYPE_VARIANTS[0]}}"; do
        for side in "${sides[@]-${SIDE_VARIANTS[0]}}"; do
          for color in "${colors[@]-${COLOR_VARIANTS[0]}}"; do
            for screen in "${screens[@]-${SCREEN_VARIANTS[0]}}"; do
              install "${theme}" "${type}" "${side}" "${color}" "${screen}"
            done
          done
        done
      done
    done
  elif [[ "${remove:-}" == 'true' ]]; then
    for theme in "${themes[@]-${THEME_VARIANTS[0]}}"; do
      for type in "${types[@]-${TYPE_VARIANTS[0]}}"; do
        for side in "${sides[@]-${SIDE_VARIANTS[0]}}"; do
          for color in "${colors[@]-${COLOR_VARIANTS[0]}}"; do
            remove "${theme}" "${type}" "${side}" "${color}"
          done
        done
      done
    done
  fi
else
  dialog_installer
fi

exit 0
