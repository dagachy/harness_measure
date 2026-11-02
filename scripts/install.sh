#!/usr/bin/env bash
# install.sh — measure plugin installer
#
# Copies .claude/agents and .claude/skills from this repo into a target
# .claude directory (defaults to ~/.claude). Supports --symlink mode.
#
# Usage:
#   bash scripts/install.sh
#   bash scripts/install.sh --target /path/to/.claude
#   bash scripts/install.sh --symlink
#   bash scripts/install.sh --target /path/to/.claude --symlink

set -euo pipefail

# --- defaults -----------------------------------------------------------------
TARGET="${HOME}/.claude"
MODE="copy"   # or "symlink"

# --- parse args ---------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="$2"
      shift 2
      ;;
    --symlink)
      MODE="symlink"
      shift
      ;;
    -h|--help)
      cat <<'USAGE'
measure installer

  --target <dir>   target .claude directory (default: ~/.claude)
  --symlink        symlink instead of copy
  -h, --help       show this message
USAGE
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

# --- locate repo root ---------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC="${REPO_ROOT}/.claude"

if [[ ! -d "${SRC}" ]]; then
  echo "error: ${SRC} not found (is this the repo root?)" >&2
  exit 1
fi

mkdir -p "${TARGET}/agents" "${TARGET}/skills"

INSTALLED=()

backup_if_exists() {
  local dst="$1"
  if [[ -e "${dst}" || -L "${dst}" ]]; then
    local bak="${dst}.bak.$(date +%Y%m%d-%H%M%S)"
    mv "${dst}" "${bak}"
    echo "  backup: ${dst} -> ${bak}"
  fi
}

place() {
  local src="$1"
  local dst="$2"
  backup_if_exists "${dst}"
  if [[ "${MODE}" == "symlink" ]]; then
    ln -s "${src}" "${dst}"
  else
    if [[ -d "${src}" ]]; then
      cp -R "${src}" "${dst}"
    else
      cp "${src}" "${dst}"
    fi
  fi
  INSTALLED+=("${dst}")
}

# --- agents (files) -----------------------------------------------------------
if compgen -G "${SRC}/agents/*.md" > /dev/null; then
  for f in "${SRC}"/agents/*.md; do
    name="$(basename "${f}")"
    place "${f}" "${TARGET}/agents/${name}"
  done
fi

# --- skills (directories) -----------------------------------------------------
if [[ -d "${SRC}/skills" ]]; then
  for d in "${SRC}"/skills/*/; do
    [[ -d "${d}" ]] || continue
    name="$(basename "${d}")"
    place "${d%/}" "${TARGET}/skills/${name}"
  done
fi

# --- report -------------------------------------------------------------------
echo
echo "mode: ${MODE}"
echo "target: ${TARGET}"
echo "installed:"
for p in "${INSTALLED[@]}"; do
  echo "  ${p}"
done
echo
echo "done."
